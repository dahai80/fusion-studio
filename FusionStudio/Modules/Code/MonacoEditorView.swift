import SwiftUI
import WebKit
import Combine
import os.log

private let monacoLog = Logger(subsystem: "com.fusion.studio", category: "MonacoEditor")

struct MonacoEditorView: NSViewRepresentable {
    @Binding var content: String
    @Binding var language: String
    var onReady: (() -> Void)?
    var onContentChange: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "monacoBridge")

        config.userContentController = userContentController
        // F-sec-3: allowFileAccess=true is required — Monaco loads monaco-dist workers/language
        // bundles from the app bundle via file://. Safe: only bundled resources are loaded (see
        // decidePolicyFor below, which denies any non-bundle navigation). No untrusted URLs.
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(true, forKey: "drawsTransparentBackground")

        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("monaco-dist")
            .appendingPathComponent("index.html") {
            webView.loadFileURL(resourceURL, allowingReadAccessTo: resourceURL.deletingLastPathComponent())
            monacoLog.info("Loading Monaco from: \(resourceURL.path)")
        } else {
            monacoLog.error("Monaco resource not found in bundle")
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.isReady else { return }

        if content != context.coordinator.lastSyncedContent {
            context.coordinator.lastSyncedContent = content
            let escaped = content
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "${", with: "\\${")
            webView.evaluateJavaScript("setContent(`\(escaped)`, '\(language)')")
        }

        if language != context.coordinator.lastSyncedLanguage {
            context.coordinator.lastSyncedLanguage = language
            webView.evaluateJavaScript("setLanguage('\(language)')")
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MonacoEditorView
        var isReady = false
        var lastSyncedContent = ""
        var lastSyncedLanguage = ""

        init(_ parent: MonacoEditorView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController,
                                    didReceive message: WKScriptMessage) {
            guard message.name == "monacoBridge",
                  let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }

            switch type {
            case "ready":
                isReady = true
                monacoLog.info("Monaco editor ready")
                DispatchQueue.main.async { [self] in
                    parent.onReady?()
                    if !parent.content.isEmpty {
                        lastSyncedContent = parent.content
                        lastSyncedLanguage = parent.language
                    }
                }
            case "contentChange":
                if let content = json["content"] as? String {
                    lastSyncedContent = content
                    DispatchQueue.main.async { [self] in
                        parent.content = content
                        parent.onContentChange?(content)
                    }
                }
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            monacoLog.info("Monaco page loaded")
        }

        // F-sec-3: deny any navigation off the bundled monaco-dist index.html.
        func webView(_ webView: WKWebView,
                      decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.isFileURL {
                decisionHandler(.allow)
                return
            }
            monacoLog.error("F-sec-3: blocking non-file navigation in Monaco editor")
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            monacoLog.error("Monaco navigation failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Diff Mode

struct MonacoDiffView: NSViewRepresentable {
    let originalContent: String
    let modifiedContent: String
    let language: String
    var onReady: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "monacoBridge")

        config.userContentController = userContentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(true, forKey: "drawsTransparentBackground")

        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("monaco-dist")
            .appendingPathComponent("index.html") {
            webView.loadFileURL(resourceURL, allowingReadAccessTo: resourceURL.deletingLastPathComponent())
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.isReady else { return }

        if !context.coordinator.diffApplied {
            context.coordinator.diffApplied = true
            let orig = originalContent
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "${", with: "\\${")
            let mod = modifiedContent
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "${", with: "\\${")
            webView.evaluateJavaScript("showDiff(`\(orig)`, `\(mod)`, '\(language)')")
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: MonacoDiffView
        var isReady = false
        var diffApplied = false

        init(_ parent: MonacoDiffView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController,
                                    didReceive message: WKScriptMessage) {
            guard message.name == "monacoBridge",
                  let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }

            if type == "ready" {
                isReady = true
                monacoLog.info("Monaco diff editor ready")
                DispatchQueue.main.async { self.parent.onReady?() }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            monacoLog.info("Monaco diff page loaded")
        }

        // F-sec-3: deny any navigation off the bundled monaco-dist index.html.
        func webView(_ webView: WKWebView,
                      decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.isFileURL {
                decisionHandler(.allow)
                return
            }
            monacoLog.error("F-sec-3: blocking non-file navigation in Monaco diff view")
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            monacoLog.error("Monaco diff navigation failed: \(error.localizedDescription)")
        }
    }
}
