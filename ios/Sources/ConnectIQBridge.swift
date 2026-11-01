import Combine
import ConnectIQ
import Foundation

/// Small Connect IQ SDK receiver for the Mil watch diagnostic field.
/// Garmin Connect Mobile must be installed and paired on the same iPhone.
final class ConnectIQBridge: NSObject, ObservableObject, IQDeviceEventDelegate, IQAppMessageDelegate {
    @Published private(set) var status = "Choose a Garmin watch to begin."
    @Published private(set) var lastMessage = "No watch samples received yet."
    @Published private(set) var receivedCount = 0
    @Published private(set) var uploadStatus = "No samples uploaded yet."
    @Published private(set) var uploadedCount = 0

    private let sdk = ConnectIQ.sharedInstance()!
    private let watchAppUUID = UUID(uuidString: "8697cb47-b483-4c71-8336-c2806d48aaee")!
    private var selectedDevice: IQDevice?
    private var watchApp: IQApp?
    private var uploader: SampleUploader?
    private var sessionID: String?
    private var previousElapsedSeconds: Double?
    private var fallbackSequence = 0
    private let serverURL: URL = {
        let configured = ProcessInfo.processInfo.environment["MIL_DASHBOARD_URL"] ?? "http://192.168.1.10:8000"
        return URL(string: configured) ?? URL(string: "http://192.168.1.10:8000")!
    }()

    override init() {
        super.init()
        sdk.initialize(withUrlScheme: "mil-8697cb47-b483-4c71-8336-c2806d48aaee", uiOverrideDelegate: nil)
    }

    func selectWatch() {
        status = "Opening Garmin Connect Mobile device picker…"
        sdk.showDeviceSelection()
    }

    func handleOpenURL(_ url: URL) {
        guard url.scheme == "mil-8697cb47-b483-4c71-8336-c2806d48aaee" else { return }
        guard let devices = sdk.parseDeviceSelectionResponse(from: url) as? [IQDevice],
              let device = devices.first else {
            status = "No watch was selected."
            return
        }

        if let oldDevice = selectedDevice {
            sdk.unregister(forDeviceEvents: oldDevice, delegate: self)
            if let oldApp = watchApp {
                sdk.unregister(forAppMessages: oldApp, delegate: self)
            }
        }
        watchApp = nil
        selectedDevice = device
        status = "Selected \(device.friendlyName ?? device.modelName ?? "Garmin watch"); connecting…"
        sdk.register(forDeviceEvents: device, delegate: self)
    }

    func deviceStatusChanged(_ device: IQDevice!, status: IQDeviceStatus) {
        guard let device, device.uuid == selectedDevice?.uuid else { return }
        DispatchQueue.main.async {
            self.status = "Garmin link: \(String(describing: status))"
        }
    }

    func deviceCharacteristicsDiscovered(_ device: IQDevice!) {
        guard let device, device.uuid == selectedDevice?.uuid else { return }
        DispatchQueue.main.async {
            self.registerForWatchMessages(device)
        }
    }

    func receivedMessage(_ message: Any!, from app: IQApp!) {
        guard let app, app.uuid == watchApp?.uuid else { return }
        let payload = message as? [String: Any] ?? [:]
        DispatchQueue.main.async {
            self.receivedCount += 1
            self.lastMessage = Self.describe(payload.isEmpty ? message : payload)
            self.status = "Receiving watch data (\(self.receivedCount) messages)."
            self.forwardProbe(payload)
        }

        // Echo an acknowledgement to prove the reverse phone-to-watch direction too.
        let sequence = payload["sequence"] as? Int ?? 0
        sdk.sendMessage(
            ["type": "mil_sensor_ack", "received_sequence": sequence],
            to: app,
            progress: nil
        ) { result in
            DispatchQueue.main.async {
                self.status = "Watch sample received; phone reply result: \(result)."
            }
        }
    }

    private func forwardProbe(_ payload: [String: Any]) {
        guard payload["type"] as? String == "mil_sensor_probe" else { return }
        guard let elapsed = Self.metric(payload["elapsed_seconds"]), elapsed >= 0 else {
            uploadStatus = "Watch message received, but it has no valid elapsed time."
            return
        }

        if let previousElapsedSeconds, elapsed + 1 < previousElapsedSeconds {
            sessionID = nil
            uploader = nil
        }
        previousElapsedSeconds = elapsed
        if sessionID == nil {
            let newSessionID = UUID().uuidString.lowercased()
            sessionID = newSessionID
            uploader = SampleUploader(serverURL: serverURL, sessionID: newSessionID)
        }
        fallbackSequence += 1
        let sequence = (payload["sequence"] as? NSNumber)?.intValue ?? fallbackSequence
        let sample = RunSample(
            sampleID: "\(sessionID!)-\(sequence)",
            recordedAt: Date(),
            elapsedSeconds: elapsed,
            latitude: Self.metric(payload["latitude"]),
            longitude: Self.metric(payload["longitude"]),
            altitudeM: Self.metric(payload["altitude_m"]),
            heartRateBpm: Self.metric(payload["heart_rate_bpm"]),
            cadenceSpm: Self.metric(payload["cadence_spm"]),
            speedMps: Self.metric(payload["speed_mps"]),
            runningPowerW: Self.metric(payload["running_power_w"])
        )
        guard let uploader else { return }
        uploadStatus = "Sending sample to \(serverURL.host ?? serverURL.absoluteString)…"
        Task {
            await uploader.enqueue(sample)
            do {
                let stored = try await uploader.uploadPending()
                await MainActor.run {
                    self.uploadedCount += stored
                    self.uploadStatus = "Uploaded \(self.uploadedCount) samples (session \(self.sessionID ?? "unknown"))."
                }
            } catch {
                await MainActor.run {
                    self.uploadStatus = "Upload failed to \(self.serverURL.absoluteString): \(error.localizedDescription). Pending samples will retry with the next watch sample."
                }
            }
        }
    }

    private func registerForWatchMessages(_ device: IQDevice) {
        guard watchApp == nil else { return }
        let app = IQApp.init(uuid: watchAppUUID, store: nil, device: device)
        watchApp = app
        sdk.getAppStatus(app) { [weak self] appStatus in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let appStatus else {
                    self.status = "Could not check Mil on this watch. Check the Bluetooth connection and try again."
                    self.watchApp = nil
                    return
                }
                guard appStatus.isInstalled else {
                    self.status = "Mil is not installed on this watch. Install the data field, then reconnect."
                    self.watchApp = nil
                    return
                }
                self.sdk.register(forAppMessages: app, delegate: self)
                self.status = "Connected to \(device.friendlyName ?? device.modelName ?? "Garmin watch"); waiting for Mil samples."
            }
        }
    }

    private static func describe(_ object: Any?) -> String {
        guard let object else { return "Received an empty message." }
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return String(describing: object)
    }

    private static func metric(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let result = number.doubleValue
        return result >= 0 ? result : nil // The watch uses -1 for unavailable metrics.
    }
}
