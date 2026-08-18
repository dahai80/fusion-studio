// Callers: ModuleDetailView routes Module.modelHub -> ModelHubMainView.
// Affected API: Replaces old ModelHubView as primary entry; old view kept for compat.
// Data schemas: ModelHubSection enum (9 cases), ModelHubAPIClient state.
// User instruction: issue #63 — market search, modules, benchmarks, scheduling, QPS

import SwiftUI
import os.log

private let mainLog = Logger(subsystem: "com.fusion.studio", category: "ModelHubMain")

enum ModelHubSection: String, CaseIterable, Identifiable {
    case dashboard = "总览"
    case market = "模型市场"
    case localStorage = "本地存储"
    case convertQuant = "转换量化"
    case schedule = "下载调度"
    case cluster = "集群调度"
    case deployment = "部署管理"
    case permission = "权限管控"
    case monitor = "系统监控"
    case benchmark = "性能评测"
    case security = "安全中心"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:    return "square.grid.2x2"
        case .market:       return "globe"
        case .localStorage: return "internaldrive"
        case .convertQuant: return "arrow.triangle.2.circlepath"
        case .schedule:     return "arrow.down.circle"
        case .cluster:      return "server.rack"
        case .deployment:   return "play.circle"
        case .permission:   return "lock.shield"
        case .monitor:      return "chart.line.uptrend.xyaxis"
        case .benchmark:    return "chart.bar.xaxis"
        case .security:     return "shield.checkered"
        }
    }

    var localLabel: String {
        switch self {
        case .dashboard:    return I18nManager.shared.t(.hub_main_secDashboard)
        case .market:       return I18nManager.shared.t(.hub_main_secMarket)
        case .localStorage: return I18nManager.shared.t(.hub_main_secLocalStorage)
        case .convertQuant: return I18nManager.shared.t(.hub_main_secConvertQuant)
        case .schedule:     return I18nManager.shared.t(.hub_main_secSchedule)
        case .cluster:      return I18nManager.shared.t(.hub_main_secCluster)
        case .deployment:   return I18nManager.shared.t(.hub_main_secDeployment)
        case .permission:   return I18nManager.shared.t(.hub_main_secPermission)
        case .monitor:      return I18nManager.shared.t(.hub_main_secMonitor)
        case .benchmark:    return I18nManager.shared.t(.hub_main_secBenchmark)
        case .security:     return I18nManager.shared.t(.hub_main_secSecurity)
        }
    }
}

struct ModelHubMainView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @StateObject private var client = ModelHubAPIClient.shared
    @State private var selectedSection: ModelHubSection = .dashboard

    private func navigateTo(_ section: ModelHubSection) {
        withAnimation(theme.springSnappy) {
            selectedSection = section
        }
    }

    private var noKeyBanner: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "key.fill")
                .foregroundStyle(.orange)
            Text(i18n.t(.hub_main_noKeyMsg))
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Button(i18n.t(.hub_main_goCreate)) { navigateTo(.permission) }
                .font(.system(size: theme.captionSize, weight: .medium))
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.accent.opacity(0.08))
        .onAppear { mainLog.info("noKeyBanner shown: connected=\(client.isConnected), hasKey=\(!FusionConfig.shared.modelHubApiKey.isEmpty)") }
    }

    var body: some View {
        HStack(spacing: 0) {
            sectionSidebar

            Rectangle().fill(theme.separator).frame(width: 1)

            VStack(spacing: 0) {
                if client.isConnected && FusionConfig.shared.modelHubApiKey.isEmpty {
                    noKeyBanner
                }
                contentArea
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await client.checkConnection()
        }
    }

    private var sectionSidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Circle()
                    .fill(client.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text("Model Hub")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingM)

            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(ModelHubSection.allCases) { section in
                        sectionRow(section)
                    }
                }
            }

            Rectangle().fill(theme.separator).frame(height: 1)

            connectionBar
        }
        .frame(width: 220)
        .background(theme.surfaceSecondary)
    }

    private func sectionRow(_ section: ModelHubSection) -> some View {
        let isActive = selectedSection == section
        return Button(action: {
            withAnimation(theme.springSnappy) {
                selectedSection = section
            }
            mainLog.info("ModelHub section: \(section.rawValue)")
        }) {
            HStack(spacing: theme.spacingS) {
                ZStack(alignment: .leading) {
                    if isActive {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(theme.accent)
                            .frame(width: 3, height: 16)
                            .offset(x: -theme.spacingXS)
                    }
                    Image(systemName: section.icon)
                        .font(.system(size: theme.iconS, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
                        .frame(width: 20)
                }
                Text(section.localLabel)
                    .font(.system(size: theme.textSize, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? theme.text : theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var connectionBar: some View {
        HStack(spacing: theme.spacingXS) {
            Circle()
                .fill(client.isConnected ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(client.isConnected ? i18n.t(.hub_main_connected) : (client.lastError ?? i18n.t(.hub_main_disconnected)))
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
            Spacer()
            Button(action: { Task { await client.checkConnection() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    @ViewBuilder
    private var contentArea: some View {
        if !client.isConnected {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text(i18n.t(.hub_main_serviceNotConnected))
                    .font(.system(size: theme.titleSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(String(format: i18n.t(.hub_main_serviceHintFmt), FusionConfig.shared.modelHubPort))
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textSecondary)
                Button(i18n.t(.hub_main_retry)) {
                    Task { await client.checkConnection() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch selectedSection {
            case .dashboard:
                HubDashboardView(client: client, navigateTo: navigateTo)
            case .market:
                HubMarketView(client: client)
            case .localStorage:
                HubLocalStorageView(client: client)
            case .convertQuant:
                HubConvertQuantView(client: client)
            case .schedule:
                HubScheduleView(client: client)
            case .cluster:
                HubClusterView(client: client)
            case .permission:
                HubPermissionView(client: client)
            case .monitor:
                HubMonitorView(client: client)
            case .benchmark:
                HubBenchmarkView(client: client)
            case .deployment:
                HubDeploymentView(client: client)
            case .security:
                HubSecurityView(client: client)
            }
        }
    }
}
