// Importers/callers: ModuleDetailView (routing .serviceWeb)
// Affected API: WebViewContainer for bench-site, security dashboard, doc gateway
// Data schemas: None (WebView embed)
// User verbatim: "做一遍检查，所有需要GUI的都要在fusion-studio落地"

import SwiftUI
import os.log

private let webLog = Logger(subsystem: "com.fusion.studio", category: "ServiceWeb")

struct ServiceWebView: View {
    @Environment(\.studioTheme) var theme
    @State private var selectedTab: WebTab = .masterDocs

    enum WebTab: String, CaseIterable {
        case masterDocs = "Master API"
        case benchSite = "Benchmark"
        case securityDashboard = "Security"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(eyebrow: "Multi-Node", title: "服务面板", subtitle: "通过 WebView 嵌入外部服务界面")

            tabBar

            switch selectedTab {
            case .masterDocs:
                ServiceWebEmbed(
                    title: "Master API Docs",
                    url: "http://127.0.0.1:9753/docs",
                    description: "FastAPI 自动文档 — 需启动 fusion-multi-node Master 服务 (端口 9753)"
                )
            case .benchSite:
                ServiceWebEmbed(
                    title: "Fusion-Bench",
                    url: "http://localhost:3000",
                    description: "基准测试面板 — 需启动 fusion-bench bench-site (端口 3000, npm run dev)"
                )
            case .securityDashboard:
                ServiceWebEmbed(
                    title: "Fusion-Security",
                    url: "http://localhost:3000",
                    description: "安全审计面板 — 需启动 fusion-security 前端 (端口 3000)"
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
                    Text(tab.rawValue)
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
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            WebViewContainer(url: url, isLoading: $isLoading, error: $loadError)

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text("正在连接 \(title)...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                    Text("无法加载 \(title)")
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
                    FusionButton("重试", style: .secondary, size: .small, isLoading: false, isDisabled: false) {
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
