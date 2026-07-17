import SwiftUI
import WebKit

/// WKWebView 容器，用于承载 Fusion-Design 画布等 Web 应用
struct WebViewContainer: NSViewRepresentable {
    let url: String
    var onMessage: ((String) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        // 注册消息处理器
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

        // 允许本地文件访问
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
            // 注入 Fusion Studio Bridge API
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
                            type: 'export_code',
                            format: format,
                            data: data
                        });
                        resolve({ status: 'ok' });
                    });
                }
            };
            """
            webView.evaluateJavaScript(bridgeJS)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView 加载失败: \(error.localizedDescription)")
        }
    }
}