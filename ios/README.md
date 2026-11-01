# iPhone companion

The iOS app has a Connect IQ receiver, displays the server dashboard in a `WKWebView`, and forwards received `mil_sensor_probe` messages to the server's sample endpoint. Failed uploads remain queued in memory and are retried when the next watch sample arrives; the Watch diagnostics screen shows the upload result.

For a hardware test, install and open Mil on a physical iPhone with Garmin Connect Mobile installed and paired. Tap **Watch test → Choose Garmin watch**, return from Garmin Connect Mobile, and leave Mil in the foreground. Then start a recorded Run activity with the Mil data field displayed. Samples should appear in the diagnostics sheet every five seconds, and the watch should count replies under `ACK`.

The app target must use `ios/Info.plist`, the ConnectIQ package linked with `-ObjC`, and the registered callback URL scheme `mil-8697cb47-b483-4c71-8336-c2806d48aaee`. The SDK's device picker opens Garmin Connect Mobile, so test on an iPhone; the iOS simulator does not provide the required BLE watch connection.

Set `MIL_DASHBOARD_URL` in the Xcode scheme's environment to the server's base URL (for example, `http://192.168.1.25:8000` on the same Wi-Fi, or your HTTPS deployment). The dashboard and watch sample uploads both use this URL. Rebuild and reinstall after changing the scheme environment.
