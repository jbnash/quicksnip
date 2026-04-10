import AppKit
import WebKit

class FeedbackWindowController: NSWindowController {

    private var webView: WKWebView?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Give Feedback"
        window.minSize = NSSize(width: 400, height: 400)
        window.center()
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        // Dark background matching the app's #0f0f11
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(red: 0.059, green: 0.059, blue: 0.067, alpha: 1).cgColor

        let config = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: config)
        web.translatesAutoresizingMaskIntoConstraints = false

        // Keep the webview background dark so there's no white flash while loading
        web.setValue(false, forKey: "drawsBackground")

        contentView.addSubview(web)
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: contentView.topAnchor),
            web.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            web.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        webView = web

        // transparentBackground=1 removes Tally's white page background
        let url = URL(string: "https://tally.so/r/dWDaXq?transparentBackground=1")!
        web.load(URLRequest(url: url))
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        // Reload each time so the form is always fresh
        if let url = URL(string: "https://tally.so/r/dWDaXq?transparentBackground=1") {
            webView?.load(URLRequest(url: url))
        }
    }
}
