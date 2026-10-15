// Zayn's Letter Adventure: a full-screen, kid-safe window around Zayn-Letter-Adventure.html.
// Build it with build.sh (see README.txt). No internet needed.

import Cocoa
import WebKit
import UniformTypeIdentifiers

/// A borderless window that can still take keyboard focus, and never beeps.
final class KioskWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func noResponder(for eventSelector: Selector) {}
}

/// The web view swallows every Command-key shortcut so little hands can't quit,
/// close or hide the app. Grown-ups quit with Control + Option + Command + Q
/// (or the Quit button in the game's settings).
final class KioskWebView: WKWebView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) && flags.contains(.option) && flags.contains(.control)
            && event.charactersIgnoringModifiers?.lowercased() == "q" {
            NSApp.terminate(nil)
            return true
        }
        if flags.contains(.command) { return true }
        return super.performKeyEquivalent(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKUIDelegate {
    var window: KioskWindow!
    var webView: KioskWebView!
    var store: [String: String] = [:]
    let storeURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ZaynLetterAdventure", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("progress.json")
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load saved stars, settings and photos.
        if let data = try? Data(contentsOf: storeURL),
           let saved = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            store = saved
        }
        let json = (try? JSONSerialization.data(withJSONObject: store))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(self, name: "app")
        config.userContentController.addUserScript(WKUserScript(
            source: "window.__nativeStore = \(json);",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let screen = NSScreen.main ?? NSScreen.screens[0]
        var frame = screen.frame
        if #available(macOS 12.0, *) { frame.size.height -= screen.safeAreaInsets.top }   // stay below the camera notch

        window = KioskWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary]

        webView = KioskWebView(frame: NSRect(origin: .zero, size: frame.size), configuration: config)
        webView.uiDelegate = self
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView

        if let page = Bundle.main.url(forResource: "Zayn-Letter-Adventure", withExtension: "html") {
            webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }

        NSApp.activate(ignoringOtherApps: true)
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(webView)
        // Hide the Dock and menu bar, and block Command-Tab, Force Quit and the power-key dialog.
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching,
                                     .disableForceQuit, .disableSessionTermination, .disableHideApplication]
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // Messages from the page: save progress, or quit.
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        if body["quit"] != nil { NSApp.terminate(nil); return }
        if let key = body["save"] as? String {
            if let value = body["value"] as? String { store[key] = value } else { store.removeValue(forKey: key) }
            if let data = try? JSONSerialization.data(withJSONObject: store) {
                try? data.write(to: storeURL, options: .atomic)
            }
        }
    }

    // Recording your own words in the grown-ups page needs the microphone.
    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    // "Add photo" in the grown-ups page.
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.level = .modalPanel
        panel.begin { result in completionHandler(result == .OK ? panel.urls : nil) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
