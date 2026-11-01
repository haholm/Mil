import Foundation

/// Versioned bridge payload mirrored by docs/data-contract.md.
struct RunSample: Codable, Identifiable {
    let sampleID: String
    let recordedAt: Date
    let elapsedSeconds: Double
    var latitude: Double?
    var longitude: Double?
    var altitudeM: Double?
    var heartRateBpm: Double?
    var cadenceSpm: Double?
    var speedMps: Double?
    var runningPowerW: Double?

    var id: String { sampleID }

    enum CodingKeys: String, CodingKey {
        case sampleID = "sample_id"
        case recordedAt = "recorded_at"
        case elapsedSeconds = "elapsed_seconds"
        case latitude, longitude
        case altitudeM = "altitude_m"
        case heartRateBpm = "heart_rate_bpm"
        case cadenceSpm = "cadence_spm"
        case speedMps = "speed_mps"
        case runningPowerW = "running_power_w"
    }
}

struct SampleBatch: Encodable {
    let device: String
    let samples: [RunSample]
}

/// Network delivery is deliberately isolated from Garmin SDK integration.
/// The future Garmin message handler can append samples here and retry failed batches.
actor SampleUploader {
    private let endpoint: URL
    private let sessionID: String
    private var pending: [RunSample] = []
    private var isUploading = false

    init(serverURL: URL, sessionID: String) {
        self.endpoint = serverURL.appending(path: "api/v1/sessions/\(sessionID)/samples")
        self.sessionID = sessionID
    }

    func enqueue(_ sample: RunSample) {
        pending.append(sample)
    }

    func uploadPending() async throws -> Int {
        guard !pending.isEmpty, !isUploading else { return 0 }
        isUploading = true
        defer { isUploading = false }
        let batchSamples = pending
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let batch = SampleBatch(device: "forerunner-955-solar", samples: batchSamples)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(batch)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "No response body"
            throw NSError(domain: "MilUpload", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP \(http.statusCode): \(detail)"])
        }
        let acknowledged = min(batchSamples.count, pending.count)
        pending.removeFirst(acknowledged)
        return acknowledged
    }
}
