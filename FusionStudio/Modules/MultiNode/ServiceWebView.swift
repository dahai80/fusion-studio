// Importers/callers: ModuleDetailView (routing .serviceWeb)
// Affected API: WebViewContainer for bench-site, security dashboard, doc gateway
// Data schemas: None (WebView embed)
// User verbatim: "做一遍检查，所有需要GUI的都要在fusion-studio落地"

import SwiftUI
import os.log

private let webLog = Logger(subsystem: "com.fusion.studio", category: "ServiceWeb")

struct ServiceWebView: View {
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var selectedTab: WebTab = .masterDocs

    enum WebTab: String, CaseIterable {
        case masterDocs = "Master API"
        case benchSite = "Benchmark"
        case securityDashboard = "Security"
        var localLabel: String {
            switch self {
            case .masterDocs: return I18nManager.shared.t(.mn_web_tab_docs)
            case .benchSite: return I18nManager.shared.t(.mn_web_tab_bench)
            case .securityDashboard: return I18nManager.shared.t(.mn_web_tab_security)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(eyebrow: "Multi-Node", title: i18n.t(.mn_web_title), subtitle: i18n.t(.mn_web_subtitle))

            tabBar

            switch selectedTab {
            case .masterDocs:
                ServiceWebEmbed(
                    title: "Master API Docs",
                    url: "http://\(FusionConfig.shared.modelHubHost):\(FusionConfig.shared.multiNodePort)/docs",
                    description: String(format: i18n.t(.mn_web_docsDescFmt), FusionConfig.shared.multiNodePort)
                )
            case .benchSite:
                ServiceWebEmbed(
                    title: "Fusion-Bench",
                    url: "http://localhost:3000",
                    description: i18n.t(.mn_web_benchDesc)
                )
            case .securityDashboard:
                ServiceWebEmbed(
                    title: "Fusion-Security",
                    url: "http://localhost:3000",
                    description: i18n.t(.mn_web_securityDesc)
                )
            }
        }
        .background(theme.contentBg)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(WebTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(theme.springDefault) { selectedTab = tab }
                } label: {
                    Text(tab.localLabel)
                        .font(.system(size: theme.smallTextSize, weight: tab == selectedTab ? .semibold : .regular))
                        .foregroundStyle(tab == selectedTab ? theme.accent : theme.textSecondary)
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingS)
                        .background(
                            tab == selectedTab ? theme.accentSoft : Color.clear,
                            in: RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingM)
    }
}

struct ServiceWebEmbed: View {
    let title: String
    let url: String
    let description: String
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            WebViewContainer(url: url, isLoading: $isLoading, error: $loadError)

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text(String(format: i18n.t(.mn_web_connectingFmt), title))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                    Text(String(format: i18n.t(.mn_web_loadFailFmt), title))
                        .font(.title2)
                        .bold()
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    FusionButton(i18n.t(.mn_web_retryBtn), style: .secondary, size: .small, isLoading: false, isDisabled: false) {
                        loadError = nil
                        isLoading = true
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
