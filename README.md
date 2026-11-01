# Mil

An early foundation for a running analysis app: Garmin Forerunner 955 Solar → iPhone bridge → server and dashboard.

## What is here

- `server/`: a dependency-free Python API, SQLite storage, and a small responsive dashboard.
- `garmin/Mil/`: Connect IQ Data Field for the Forerunner 955 Solar, with temporary live-metric and BLE diagnostics.
- `ios/`: iOS bridge and in-app dashboard integration notes.
- `docs/`: the shared sample contract and architecture decisions.

## Run the server

Requires Python 3.11 or later. From the repository root:

```sh
python3 server/app.py
```

Open <http://127.0.0.1:8000>. The database is created at `server/mil.sqlite3` on first run. Set `MIL_DB` to choose another location.

The dashboard starts empty. Send sample batches to `POST /api/v1/sessions/{session_id}/samples`; the API accepts JSON and returns the number stored. See `docs/data-contract.md` for the payload.

## Current scope

This is groundwork, not a complete live coaching system. The API stores timestamped samples and exposes recent sessions. The dashboard currently shows session totals and the latest sample. Segment effort normalization, longitudinal comparisons, and coaching feedback need validated definitions and real activity data before they should influence a runner mid-session.

The temporary watch diagnostic sends activity metrics to the iOS app over the Connect IQ BLE link. See [Garmin's Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and [Toybox.Communications](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html).
