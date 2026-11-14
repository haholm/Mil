# Mil

An early foundation for a running analysis app: Garmin Forerunner 955 Solar → iPhone bridge → server and dashboard.

## What is here

- `server/`: a FastAPI JSON API, SQLite storage, and an HTMX/WebSocket dashboard styled with Tailwind CSS.
- `garmin/Mil/`: Connect IQ Data Field for the Forerunner 955 Solar, with temporary live-metric and BLE diagnostics.
- `ios/`: iOS dashboard, Connect IQ receiver, and sample uploader to the server API.
- `docs/`: the shared sample contract and architecture decisions.

## Run the server

Requires Python 3.11 or later. Install the API and template dependencies from the repository root:

```sh
python3 -m pip install -r server/requirements.txt
uvicorn server.app:app --reload --host 0.0.0.0 --port 8000
```

Open <http://127.0.0.1:8000>. The API is built with FastAPI, and the dashboard is rendered by Jinja2 and updated over WebSockets using HTMX. Set `MIL_DB` to choose another SQLite database location. `PORT` is used when starting the app with `python3 server/app.py`.

The dashboard loads HTMX, its WebSocket extension, and Tailwind's Play CDN from public CDNs. There is no application-authored JavaScript; the CDN scripts supply the browser behavior and Tailwind styling for this prototype. Tailwind's Play CDN is intended for development. For a production deployment, compile Tailwind to a static CSS file and serve the HTMX assets locally.

The dashboard starts empty. Send sample batches to `POST /api/v1/sessions/{session_id}/samples`; the API accepts JSON and returns the number stored. See `docs/data-contract.md` for the payload.

## Current scope

This is groundwork, not a complete live coaching system. The API stores timestamped samples and exposes recent sessions. The dashboard shows session totals and the latest sample, refreshing over WebSockets when samples arrive. Segment effort normalization, longitudinal comparisons, and coaching feedback need validated definitions and real activity data before they should influence a runner mid-session.

The temporary watch diagnostic sends activity metrics to the iOS app over the Connect IQ BLE link. See [Garmin's Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) and [Toybox.Communications](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html).
