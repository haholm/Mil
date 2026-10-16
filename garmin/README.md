# Garmin Connect IQ watch app

Target: Forerunner 955 Solar, Connect IQ device app (Monkey C). Start with activity lifecycle and low-rate sensor snapshots; batch readings before sending through `Toybox.Communications` to Garmin Connect Mobile. The app must be active for live callbacks; verify whether a Data Field is more suitable if the native Garmin running activity must record the workout.

The initial `source/MilApp.mc` is a minimal launcher shell. Install Garmin's Connect IQ SDK and Monkey C extension before compiling. Device/API compatibility and the exact available sensor fields should be confirmed against the installed SDK and the 955 Solar simulator/device.

Never block an activity on network availability. Keep a bounded local queue and expose a visible connection/recording state before enabling live coaching.
