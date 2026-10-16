#!/usr/bin/env python3
"""Small standard-library API and dashboard for the Mil prototype."""

from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
DB_PATH = Path(os.environ.get("STRIDELAB_DB", ROOT / "mil.sqlite3"))


def connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    db.execute("""CREATE TABLE IF NOT EXISTS samples (
        session_id TEXT NOT NULL,
        sample_id TEXT NOT NULL,
        device TEXT,
        recorded_at TEXT NOT NULL,
        elapsed_seconds REAL NOT NULL,
        latitude REAL,
        longitude REAL,
        altitude_m REAL,
        heart_rate_bpm REAL,
        cadence_spm REAL,
        speed_mps REAL,
        running_power_w REAL,
        PRIMARY KEY (session_id, sample_id)
    )""")
    db.execute("CREATE INDEX IF NOT EXISTS samples_time_idx ON samples(session_id, recorded_at)")
    return db


def json_response(handler: BaseHTTPRequestHandler, status: int, payload: object) -> None:
    body = json.dumps(payload, separators=(",", ":")).encode()
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def read_json(handler: BaseHTTPRequestHandler) -> object:
    length = int(handler.headers.get("Content-Length", "0"))
    if length > 1_000_000:
        raise ValueError("Payload exceeds 1 MB")
    if length == 0:
        raise ValueError("Expected a JSON body")
    return json.loads(handler.rfile.read(length))


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args: object) -> None:
        print(f"{self.log_date_time_string()} {fmt % args}")

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path.rstrip("/") or "/"
        if path == "/":
            body = (ROOT / "dashboard.html").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif path == "/api/v1/health":
            json_response(self, 200, {"status": "ok", "service": "mil-api"})
        elif path == "/api/v1/sessions":
            with connect() as db:
                rows = db.execute("""SELECT session_id, MIN(recorded_at) AS started_at,
                    MAX(recorded_at) AS last_sample_at, MAX(elapsed_seconds) AS duration_seconds,
                    COUNT(*) AS sample_count, AVG(heart_rate_bpm) AS avg_heart_rate_bpm
                    FROM samples GROUP BY session_id ORDER BY started_at DESC LIMIT 50""").fetchall()
            json_response(self, 200, {"sessions": [dict(row) for row in rows]})
        elif path.startswith("/api/v1/sessions/"):
            session_id = path.removeprefix("/api/v1/sessions/")
            if not session_id or "/" in session_id:
                json_response(self, 404, {"error": "not_found"})
                return
            with connect() as db:
                rows = db.execute("SELECT * FROM samples WHERE session_id = ? ORDER BY recorded_at", (session_id,)).fetchall()
            if not rows:
                json_response(self, 404, {"error": "session_not_found"})
            else:
                json_response(self, 200, {"session_id": session_id, "samples": [dict(row) for row in rows]})
        else:
            json_response(self, 404, {"error": "not_found"})

    def do_POST(self) -> None:  # noqa: N802
        path = urlparse(self.path).path.rstrip("/")
        prefix = "/api/v1/sessions/"
        if not path.startswith(prefix) or not path.endswith("/samples"):
            json_response(self, 404, {"error": "not_found"})
            return
        session_id = path[len(prefix):-len("/samples")].strip("/")
        if not session_id or "/" in session_id:
            json_response(self, 400, {"error": "invalid_session_id"})
            return
        try:
            payload = read_json(self)
            if not isinstance(payload, dict) or not isinstance(payload.get("samples"), list):
                raise ValueError("Body must contain a samples array")
            samples = payload["samples"]
            if len(samples) > 500:
                raise ValueError("A batch may contain at most 500 samples")
            device = payload.get("device")
            prepared = []
            for sample in samples:
                if not isinstance(sample, dict):
                    raise ValueError("Each sample must be an object")
                for required in ("sample_id", "recorded_at", "elapsed_seconds"):
                    if required not in sample:
                        raise ValueError(f"Missing required field: {required}")
                datetime.fromisoformat(str(sample["recorded_at"]).replace("Z", "+00:00"))
                if float(sample["elapsed_seconds"]) < 0:
                    raise ValueError("elapsed_seconds cannot be negative")
                prepared.append((session_id, str(sample["sample_id"]), device,
                    str(sample["recorded_at"]), float(sample["elapsed_seconds"]),
                    sample.get("latitude"), sample.get("longitude"), sample.get("altitude_m"),
                    sample.get("heart_rate_bpm"), sample.get("cadence_spm"),
                    sample.get("speed_mps"), sample.get("running_power_w")))
            with connect() as db:
                before = db.total_changes
                db.executemany("""INSERT OR IGNORE INTO samples
                    (session_id, sample_id, device, recorded_at, elapsed_seconds, latitude,
                     longitude, altitude_m, heart_rate_bpm, cadence_spm, speed_mps, running_power_w)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", prepared)
                stored = db.total_changes - before
            json_response(self, 202, {"received": len(samples), "stored": stored, "duplicates_ignored": len(samples) - stored})
        except (ValueError, TypeError, json.JSONDecodeError) as exc:
            json_response(self, 400, {"error": "invalid_payload", "message": str(exc)})


if __name__ == "__main__":
    connect().close()
    port = int(os.environ.get("PORT", "8000"))
    print(f"Mil listening on http://127.0.0.1:{port} (database: {DB_PATH})")
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
