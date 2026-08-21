import SwiftUI
import WebKit

struct FCWebPreview: NSViewRepresentable {
    let htmlContent: String
    let baseURL: URL?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isElementFullscreenEnabled = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: baseURL)
    }
}

struct FCWebPreviewPanel: View {
    @Environment(\.studioTheme) private var theme
    @Binding var htmlContent: String
    @State private var isLivePreview = true
    @State private var zoom: Double = 1.0
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "safari")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                Text("Preview")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.text)
                Spacer()
                Toggle(i18n.t(.fc_live), isOn: $isLivePreview)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                Button(action: { zoom = max(0.25, zoom - 0.25) }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                Text("\(Int(zoom * 100))%")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 35)
                Button(action: { zoom = min(3.0, zoom + 0.25) }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                Button(action: { zoom = 1.0 }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.toolbarBg)

            Divider()

            if htmlContent.isEmpty {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.fc_html_preview_empty))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                FCWebPreview(
                    htmlContent: htmlContent,
                    baseURL: nil
                )
                .scaleEffect(zoom)
            }
        }
    }
}
