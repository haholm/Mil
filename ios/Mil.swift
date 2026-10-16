import SwiftUI
import WebKit

@main
struct MilApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardScreen(url: dashboardURL)
                .preferredColorScheme(.dark)
        }
    }

    private var dashboardURL: URL {
        let configured = ProcessInfo.processInfo.environment["STRIDELAB_DASHBOARD_URL"]
        return URL(string: configured ?? "http://127.0.0.1:8000")!
    }
}

private struct DashboardScreen: View {
    let url: URL

    var body: some View {
        NavigationStack {
            DashboardWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Mil")
                .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color(red: 0.78, green: 0.95, blue: 0.40))
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
