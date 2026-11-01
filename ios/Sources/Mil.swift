import SwiftUI
import WebKit

@main
struct MilApp: App {
    @StateObject private var connectIQ = ConnectIQBridge()

    @available(iOS 27.0, *)
    var body: some Scene {
        WindowGroup {
            DashboardScreen(url: dashboardURL)
                .environmentObject(connectIQ)
                .onOpenURL { connectIQ.handleOpenURL($0) }
                .preferredColorScheme(.dark)
        }
    }

    private var dashboardURL: URL {
        let configured = ProcessInfo.processInfo.environment["MIL_DASHBOARD_URL"]
        return URL(string: configured ?? "http://192.168.1.10:8000")!
    }
}

@available(iOS 27.0, *)
private struct DashboardScreen: View {
    @EnvironmentObject private var connectIQ: ConnectIQBridge
    @State private var showWatchDiagnostics = false
    let url: URL

    var body: some View {
        NavigationStack {
            DashboardWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Mil")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Watch test") { showWatchDiagnostics = true }
                    }
                }
        }
        .tint(Color(red: 0.78, green: 0.95, blue: 0.40))
        .sheet(isPresented: $showWatchDiagnostics) {
            WatchDiagnosticsScreen()
                .environmentObject(connectIQ)
        }
    }
}

@available(iOS 27.0, *)
private struct WatchDiagnosticsScreen: View {
    @EnvironmentObject private var connectIQ: ConnectIQBridge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    Text(connectIQ.status)
                    Button("Choose Garmin watch") { connectIQ.selectWatch() }
                }
                Section("Watch data") {
                    LabeledContent("Messages received", value: "\(connectIQ.receivedCount)")
                    Text(connectIQ.lastMessage)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                Section("Server upload") {
                    LabeledContent("Samples uploaded", value: "\(connectIQ.uploadedCount)")
                    Text(connectIQ.uploadStatus)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                Section {
                    Text("Start a Run activity, add the Mil data field to a page, then begin recording. The field sends a small sample every 5 seconds and this screen replies with an acknowledgement.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Watch diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct DashboardWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isInspectable = true
        webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}
