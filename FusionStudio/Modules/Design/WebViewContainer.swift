import SwiftUI
import WebKit
import Combine

/// WKWebView 容器，用于承载 Fusion-Design 画布等 Web 应用
struct WebViewContainer: NSViewRepresentable {
    let url: String
    var onMessage: ((String) -> Void)?
    @Binding var isLoading: Bool
    @Binding var error: String?

    init(url: String, onMessage: ((String) -> Void)? = nil, isLoading: Binding<Bool> = .constant(true), error: Binding<String?> = .constant(nil)) {
        self.url = url
        self.onMessage = onMessage
        self._isLoading = isLoading
        self._error = error
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "fusionBridge")

        let userScript = WKUserScript(
            source: """
            window.fusionBridge = {
                postMessage: function(msg) {
                    window.webkit.messageHandlers.fusionBridge.postMessage(msg);
                }
            };
            console.log('Fusion Studio Bridge loaded');
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(userScript)
        config.userContentController = userContentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(true, forKey: "drawsTransparentBackground")

        if let url = URL(string: self.url) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebViewContainer

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController,
                                    didReceive message: WKScriptMessage) {
            if message.name == "fusionBridge",
               let body = message.body as? String {
                parent.onMessage?(body)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.error = nil
            let bridgeJS = """
            window.fusionStudio = {
                version: '0.1.0',
                platform: 'macOS',
                sendToNative: function(msg) {
                    window.webkit.messageHandlers.fusionBridge.postMessage(JSON.stringify(msg));
                },
                exportCode: function(format, data) {
                    return new Promise((resolve) => {
                        window.fusionStudio.sendToNative({
                            type: 'export_code', format: format, data: data
                        });
                        resolve({ status: 'ok' });
                    });
                }
            };
            """
            webView.evaluateJavaScript(bridgeJS)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.error = BridgeError.sanitize(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.error = BridgeError.sanitize(error)
        }
    }
}