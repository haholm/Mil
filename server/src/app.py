#!/usr/bin/env python3
"""Mil's FastAPI API and server-rendered HTMX dashboard."""

from __future__ import annotations

import os
from datetime import datetime
from typing import Any

import uvicorn
from fastapi import FastAPI, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.exceptions import RequestValidationError
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates

from models.samples import SampleBatchInput
from models.websockets import DashboardConnections
from db.db import connect
from common import ROOT

templates = Jinja2Templates(directory=str(ROOT / "templates"))

def dashboard_context() -> dict[str, Any]:
    with connect() as db:
        session_rows = db.execute("""SELECT session_id,
                MIN(recorded_at) AS started_at,
                MAX(recorded_at) AS last_sample_at,
                MAX(elapsed_seconds) AS duration_seconds,
                COUNT(*) AS sample_count,
                AVG(heart_rate_bpm) AS avg_heart_rate_bpm
            FROM samples
            GROUP BY session_id
            HAVING MAX(elapsed_seconds) > 0
            ORDER BY started_at DESC
            LIMIT 50""").fetchall()
        latest = db.execute("SELECT * FROM samples ORDER BY recorded_at DESC LIMIT 1").fetchone()

    sessions = [dict(row) for row in session_rows]
    for session in sessions:
        try:
            session["started_display"] = datetime.fromisoformat(
                session["started_at"].replace("Z", "+00:00")
            ).astimezone().strftime("%b %-d, %Y · %-I:%M %p")
        except (ValueError, AttributeError):
            session["started_display"] = session["started_at"]
        seconds = int(session["duration_seconds"] or 0)
        session["duration_display"] = f"{seconds // 60} min"
        avg_hr = session["avg_heart_rate_bpm"]
        session["avg_hr_display"] = f"{round(avg_hr)} bpm avg" if avg_hr is not None else "heart rate —"

    latest_sample = dict(latest) if latest else None
    latest_heart_rate = None
    if latest_sample and latest_sample["heart_rate_bpm"] is not None:
        latest_heart_rate = round(latest_sample["heart_rate_bpm"])
    latest_pace = None
    if latest_sample and latest_sample["speed_mps"] and latest_sample["speed_mps"] > 0:
        latest_pace = f"{(1000 / latest_sample['speed_mps'] / 60):.1f}"

    return {
        "sessions": sessions,
        "total_samples": sum(session["sample_count"] for session in sessions),
        "latest_sample": latest_sample,
        "latest_heart_rate": latest_heart_rate,
        "latest_pace": latest_pace,
        "updated_display": (
            f"{len(sessions)} {'run' if len(sessions) == 1 else 'runs'} recorded"
            if sessions else "Waiting for activity data"
        ),
    }


def render_dashboard_fragment(*, out_of_band: bool = False) -> str:
    return templates.env.get_template("dashboard_fragment.html").render(
        **dashboard_context(), out_of_band=out_of_band
    )


dashboard_connections = DashboardConnections()
app = FastAPI(title="Mil Run API", version="1.0.0")


@app.exception_handler(RequestValidationError)
async def validation_error_as_bad_request(
    _request: Request, exc: RequestValidationError
) -> JSONResponse:
    return JSONResponse(
        status_code=400,
        content={"error": "invalid_payload", "message": str(exc)},
    )


@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(
        request=request,
        name="dashboard.html",
        context=dashboard_context(),
    )


@app.get("/runs/{session_id}", response_class=HTMLResponse)
async def run_detail(request: Request, session_id: str) -> HTMLResponse:
    with connect() as db:
        rows = db.execute(
            "SELECT * FROM samples WHERE session_id = ? AND elapsed_seconds > 0 ORDER BY recorded_at",
            (session_id,),
        ).fetchall()
    if not rows:
        raise HTTPException(status_code=404, detail="session_not_found")
    samples = [dict(row) for row in rows]
    return templates.TemplateResponse(
        request=request,
        name="run_detail.html",
        context={"session_id": session_id, "samples": samples},
    )


@app.get("/api/v1/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "mil-api"}


@app.get("/api/v1/sessions")
async def list_sessions() -> dict[str, list[dict[str, Any]]]:
    context = dashboard_context()
    api_fields = (
        "session_id", "started_at", "last_sample_at", "duration_seconds",
        "sample_count", "avg_heart_rate_bpm",
    )
    return {"sessions": [
        {field: session[field] for field in api_fields}
        for session in context["sessions"]
    ]}


@app.get("/api/v1/sessions/{session_id}")
async def get_session(session_id: str) -> dict[str, Any]:
    with connect() as db:
        rows = db.execute(
            "SELECT * FROM samples WHERE session_id = ? ORDER BY recorded_at",
            (session_id,),
        ).fetchall()
    if not rows:
        raise HTTPException(status_code=404, detail="session_not_found")
    return {"session_id": session_id, "samples": [dict(row) for row in rows]}


@app.post("/api/v1/sessions/{session_id}/samples", status_code=202)
async def receive_samples(
    session_id: str, batch: SampleBatchInput, request: Request
) -> dict[str, int]:
    if int(request.headers.get("content-length", "0")) > 1_000_000:
        raise HTTPException(
            status_code=400,
            detail={"error": "invalid_payload", "message": "Payload exceeds 1 MB"},
        )
    if not session_id.strip() or "/" in session_id:
        raise HTTPException(status_code=400, detail="invalid_session_id")
    if len(batch.samples) > 500:
        raise HTTPException(
            status_code=400,
            detail={"error": "invalid_payload", "message": "A batch may contain at most 500 samples"},
        )

    prepared = []
    try:
        for sample in batch.samples:
            datetime.fromisoformat(sample.recorded_at.replace("Z", "+00:00"))
            prepared.append((
                session_id,
                sample.sample_id,
                batch.device,
                sample.recorded_at,
                sample.elapsed_seconds,
                sample.latitude,
                sample.longitude,
                sample.altitude_m,
                sample.heart_rate_bpm,
                sample.cadence_spm,
                sample.speed_mps,
                sample.running_power_w,
            ))
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail={"error": "invalid_payload", "message": str(exc)},
        ) from exc

    with connect() as db:
        before = db.total_changes
        db.executemany("""INSERT OR IGNORE INTO samples
            (session_id, sample_id, device, recorded_at, elapsed_seconds, latitude,
             longitude, altitude_m, heart_rate_bpm, cadence_spm, speed_mps, running_power_w)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""", prepared)
        stored = db.total_changes - before

    if stored:
        await dashboard_connections.broadcast(render_dashboard_fragment(out_of_band=True))
    return {
        "received": len(batch.samples),
        "stored": stored,
        "duplicates_ignored": len(batch.samples) - stored,
    }


@app.websocket("/ws/dashboard")
async def dashboard_socket(websocket: WebSocket) -> None:
    await dashboard_connections.connect(websocket)
    try:
        await websocket.send_text(render_dashboard_fragment(out_of_band=True))
        while True:
            # The dashboard is a push-only stream; receive keeps the socket alive
            # and detects browser disconnects without polling or client code.
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await dashboard_connections.disconnect(websocket)


if __name__ == "__main__":
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.environ.get("PORT", "8000")),
    )



#Dynamic Live-Coaching Architecture

#A real-time coaching model uses a Hybrid CNN-LSTM or Transformer architecture to evaluate a sliding window of the last 30 to 60 seconds of running metrics.
#• Feature Extraction (CNN): Processes sudden changes in elevation (gradient) and maps it against current pace to calculate real-time "Grade Adjusted Pace."
#• Sequential Prediction (LSTM): Tracks heart rate trends over the last minute. It predicts if your HR is climbing too fast relative to the hill gradient, signalling premature fatigue.
#• The Reward Function (RL): If the goal is speed development, the reinforcement learning agent rewards maintaining target pace while keeping heart rate drift minimal. If the goal is endurance, it rewards a steady, capped heart rate over prolonged durations.