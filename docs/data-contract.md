# Data contract (v1)

The bridge batches readings to tolerate intermittent connectivity. `session_id` is a client-generated stable ID for one recording. `sample_id` is stable across retries so ingestion can be made idempotent.

```json
{
  "device": "forerunner-955-solar",
  "samples": [
    {
      "sample_id": "01J...",
      "recorded_at": "2026-10-16T10:15:30Z",
      "elapsed_seconds": 42,
      "latitude": 59.33,
      "longitude": 18.06,
      "altitude_m": 21.4,
      "heart_rate_bpm": 148,
      "cadence_spm": 172,
      "speed_mps": 3.1,
      "running_power_w": null
    }
  ]
}
```

All fields except `sample_id`, `recorded_at`, and `elapsed_seconds` are optional. `cadence_spm` is steps per minute, `speed_mps` is metres per second, and `running_power_w` is nullable because source/device availability needs verification. The API does not infer effort from heart rate or elevation yet.

## Endpoints

- `GET /api/v1/health` — server status.
- `POST /api/v1/sessions/{session_id}/samples` — ingest a batch (duplicate sample IDs are ignored).
- `GET /api/v1/sessions` — recent session summaries.
- `GET /api/v1/sessions/{session_id}` — session summary and chronological samples.
- `GET /` — dashboard.
