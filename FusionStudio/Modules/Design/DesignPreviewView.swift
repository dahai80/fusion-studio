// Callers: DesignView (renders live HTML preview in WKWebView sandbox).
// Affected API: DesignPreviewView NSViewRepresentable (htmlContent: Binding<String>, deviceMode: PreviewDeviceMode).
// Data schemas: PreviewDeviceMode enum (mobile/tablet/desktop with width values).
// User instruction: "继续" — Phase 2: local Tailwind bundle + offline support

import SwiftUI
import WebKit
import os.log

private let previewLog = Logger(subsystem: "com.fusion.studio", category: "DesignPreviewView")

enum DesignPreviewTrace {
    static func log(_ msg: String) {
        let line = "\(msg)\n"
        let path = NSHomeDirectory() + "/.fusion-design-preview-debug.log"
        if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) { handle.write(data) }
            try? handle.close()
        } else {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

enum PreviewDeviceMode: String, CaseIterable {
    case mobile = "375"
    case tablet = "768"
    case desktop = "100%"

    var label: String {
        switch self {
        case .mobile: return "Mobile"
        case .tablet: return "Tablet"
        case .desktop: return "Desktop"
        }
    }

    var icon: String {
        switch self {
        case .mobile: return "iphone"
        case .tablet: return "ipad"
        case .desktop: return "macbook"
        }
    }

    var width: CGFloat? {
        switch self {
        case .mobile: return 375
        case .tablet: return 768
        case .desktop: return nil
        }
    }
}

struct DesignPreviewView: NSViewRepresentable {
    @Binding var htmlContent: String
    var deviceMode: PreviewDeviceMode = .desktop

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        let sandboxScript = WKUserScript(
            source: """
            window.open = function() { return null; };
            window.alert = function() {};
            window.prompt = function() { return null; };
            window.confirm = function() { return false; };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(sandboxScript)

        if let tailwindSource = loadLocalTailwind() {
            let tailwindScript = WKUserScript(
                source: tailwindSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            contentController.addUserScript(tailwindScript)
            previewLog.info("DesignPreviewView: local Tailwind JS injected (\(tailwindSource.count) chars)")
        } else {
            previewLog.warning("DesignPreviewView: local Tailwind not found, CDN fallback will be used in HTML")
        }

        config.userContentController = contentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsTransparentBackground")
        context.coordinator.webView = webView

        previewLog.info("DesignPreviewView: WKWebView created")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let newHash = htmlContent.hashValue
        if context.coordinator.lastContentHash != newHash {
            context.coordinator.lastContentHash = newHash
            let fullHTML = buildFullHTML(htmlContent)
            webView.loadHTMLString(fullHTML, baseURL: nil)
            previewLog.info("DesignPreviewView: content updated, \(htmlContent.count) chars")
        }
    }

    // MARK: - Local Tailwind Loading

    private func loadLocalTailwind() -> String? {
        guard let url = Bundle.main.url(forResource: "tailwind-play", withExtension: "js", subdirectory: "tailwind") else {
            previewLog.warning("DesignPreviewView: tailwind-play.js not found in bundle")
            return nil
        }
        return try? String(contentsOf: url)
    }

    // MARK: - HTML Building

    func buildFullHTML(_ userCode: String) -> String {
        let hasLocalTailwind = loadLocalTailwind() != nil
        if userCode.contains("<!DOCTYPE") || userCode.contains("<html") {
            return injectTailwindIntoExisting(userCode, hasLocal: hasLocalTailwind)
        }
        let tailwindTag = hasLocalTailwind
            ? ""
            : "<script src=\"https://cdn.tailwindcss.com\"></script>"
        return """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \(tailwindTag)
            <style>
            :root {
              --color-primary: #007AFF;
              --color-secondary: #5856D6;
              --color-success: #34C759;
              --color-warning: #FF9500;
              --color-error: #FF3B30;
              --color-bg: #ffffff;
              --color-surface: #f5f5f7;
              --color-text: #1d1d1f;
              --color-text-secondary: #6e6e73;
              --radius-sm: 6px;
              --radius-md: 10px;
              --radius-lg: 16px;
            }
            body {
              margin: 0;
              padding: 0;
              background: #ffffff;
              color: var(--color-text);
              font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
            }
            </style>
        </head>
        <body>
        \(userCode)
        </body>
        </html>
        """
    }

    private func injectTailwindIntoExisting(_ html: String, hasLocal: Bool) -> String {
        var cleaned = html
        if hasLocal {
            let cdnPatterns = [
                "<script src=\"https://cdn.tailwindcss.com\"></script>",
                "<script src='https://cdn.tailwindcss.com'></script>"
            ]
            for p in cdnPatterns {
                while let r = cleaned.range(of: p) { cleaned.removeSubrange(r) }
            }
            previewLog.info("DesignPreviewView: stripped CDN tailwind, using local tailwind-play injection")
            return cleaned
        }
        if cleaned.contains("tailwindcss") || cleaned.contains("tailwind.min.css") {
            return cleaned
        }

        let tailwindScript = "<script src=\"https://cdn.tailwindcss.com\"></script>"
        if let headRange = cleaned.range(of: "<head>") {
            return String(cleaned[..<headRange.upperBound]) + tailwindScript + String(cleaned[headRange.upperBound...])
        }
        if let htmlRange = cleaned.range(of: "<html") {
            if let insertPoint = cleaned.range(of: ">", range: htmlRange.lowerBound..<cleaned.endIndex) {
                return String(cleaned[..<insertPoint.upperBound]) + "<head>\(tailwindScript)</head>" + String(cleaned[insertPoint.upperBound...])
            }
        }
        return "<head>\(tailwindScript)</head>" + cleaned
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var lastContentHash: Int = 0

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            previewLog.error("DesignPreviewView navigation failed: \(error)")
        }
    }
}
