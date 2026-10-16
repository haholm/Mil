# Product groundwork

## First end-to-end milestone

1. Establish that the Forerunner 955 Solar can deliver the chosen sample fields to the iOS app using Garmin's Connect IQ Mobile SDK while a run is in progress.
2. Batch and persist samples on the phone so short disconnects do not lose a run.
3. Upload batches to the server and show a run in the dashboard.
4. Validate derived metrics against known activities before presenting comparisons or coaching.

## Analysis ideas from the initial brief

- Compare performance over terrain segments, especially climbs, while accounting for effort. The effort signal and normalization method remain to be selected and validated; running power is optional in the current contract.
- Compare a runner with their own prior efforts and an appropriately defined group average.
- Find relationships between measurements over time and surface useful points of interest.
- Tailor feedback to a stated goal such as speed or distance. Start with explainable rules and historical summaries; only introduce a neural model after collecting consented, representative data and defining an evaluation method.
- Explore live feedback only after end-to-end delay, reliability, battery cost, and safe interruption behavior are measured.

## Architecture constraints to resolve

- Whether this is a Connect IQ device app or a data field embedded in Garmin's native Run activity. The device app offers a self-contained experience; the data field can accompany the native activity, but has a different lifecycle and API constraints.
- The Connect IQ Mobile SDK's supported message throughput, background behavior, and user pairing flow on current iOS.
- Which sensor readings are actually available and useful on the target watch, and what happens when a reading is missing.
- Account identity, retention, privacy, and hosting before real health data leaves the phone.
