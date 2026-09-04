import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct HTMLPreviewView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        // P1 审计0827: htmlContent 来源含 LLM 产物 (ArtifactCreateChatSheet generatedContent),
        // 默认 WKWebView 配置 allowFileAccessFromFileURLs=true, XSS 经 file:// 触达原生层。
        // 复用 DesignPreviewView 沙箱: 关 file:// 访问 + 剥 script/事件/JS-URL (sanitizeHtml)。
        let config = WKWebViewConfiguration()
        config.preferences.setValue(false, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsTransparentBackground")
        artifactsLog.info("HTMLPreviewView: WKWebView created (fileAccess closed, HTML sanitized)")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // P1 审计0827: 渲染前 sanitize 剥不可信脚本/事件处理器/JS-URL, 防 XSS 注入面。
        let sanitized = DesignBridge.sanitizeHtml(htmlContent)
        webView.loadHTMLString(sanitized, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                // SEC-4 (审计product-0905 P2): artifact HTML 不可信, 仅放行 http(s), 拒 file/data/about/自定义 scheme 防 arbitrary launch。
                if url.scheme == "http" || url.scheme == "https" {
                    NSWorkspace.shared.open(url)
                } else {
                    artifactsLog.warning("SEC-4: blocked non-http(s) link scheme=\(url.scheme ?? "?", privacy: .public)")
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - ArtifactTemplate

