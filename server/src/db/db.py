import os
import sqlite3 as sql
from contextlib import contextmanager
from pathlib import Path
from typing import Generator

from common import ROOT


DB_PATH = Path(os.environ.get("MIL_DB", ROOT / "mil.sqlite3"))


@contextmanager
def connect() -> Generator[sql.Connection, None, None]:
    """Open a database connection and ensure the sample schema exists."""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    db = sql.connect(DB_PATH)
    db.row_factory = sql.Row
    try:
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
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

