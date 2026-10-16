# iPhone companion

The intended iOS app has two jobs: receive Connect IQ messages using Garmin's Connect IQ Mobile SDK, queue/batch samples for upload, and display the server dashboard in a `WKWebView`.

Garmin publishes the iOS Mobile SDK and sample app from its Connect IQ SDK page. The SDK must be added to an Xcode app target and configured with the Garmin developer credentials/app identifier before watch pairing can work. This repository contains an independent UI shell and shared payload types; it does not claim a working Garmin pairing implementation yet.

Set `STRIDELAB_DASHBOARD_URL` in the Xcode scheme's environment or replace the fallback URL in `MilApp.swift` with your deployed server URL. For a physical phone, `localhost` means the phone itself, not your development computer.

The temporary HTTP localhost URL is for local development only. Use HTTPS for a hosted server. Add the supplied `Info.plist` to the app target so local development requests are allowed by App Transport Security.
