# Garmin Connect IQ data field

This project is a **Data Field** (`type="datafield"`) for the native Run activity. That means it reads activity metrics passed to `compute(info)`. The diagnostic displays metrics such as current heart rate, cadence, speed, running power, and altitude when Garmin supplies them. A dash means that metric is not currently available.

## Watch-to-iPhone setup

1. Build and install the `Mil` data field on the Forerunner 955 Solar using the Monkey C extension / Connect IQ SDK.
2. Install and launch the Mil iOS app on a **physical iPhone** with Garmin Connect Mobile installed and paired to the watch. Keep Mil open in the foreground during this first test.
3. In Mil, tap **Watch test → Choose Garmin watch** and allow Garmin Connect Mobile to return to Mil.
4. On the watch, add the Mil data field to a page in the native Run activity. Start recording.
5. The field sends one small activity snapshot every five seconds. The iOS diagnostics screen should show the received dictionary and send an acknowledgement. The watch's `TX` and `ACK` counts should increase.

The data field needs Connect IQ API 5.0.0 for `Toybox.Communications` support; this minimum and the Communications permission are already in the manifest. `TX` reflects successful BLE transmit callbacks. `ACK` reflects a non-empty message received back from the iPhone app. On-watch simulator tests cannot validate the real iPhone BLE path.
