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
    case permission = "权限管控"
    case monitor = "系统监控"
    case benchmark = "性能评测"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:    return "square.grid.2x2"
        case .market:       return "globe"
        case .localStorage: return "internaldrive"
        case .convertQuant: return "arrow.triangle.2.circlepath"
        case .schedule:     return "arrow.down.circle"
        case .cluster:      return "server.rack"
        case .permission:   return "lock.shield"
        case .monitor:      return "chart.line.uptrend.xyaxis"
        case .benchmark:    return "chart.bar.xaxis"
        }
    }
}

struct ModelHubMainView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = ModelHubAPIClient.shared
    @State private var selectedSection: ModelHubSection = .dashboard

    var body: some View {
        HStack(spacing: 0) {
            sectionSidebar

            Rectangle().fill(theme.separator).frame(width: 1)

            contentArea
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
                Text(section.rawValue)
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
            Text(client.isConnected ? "已连接" : (client.lastError ?? "未连接"))
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
                Text("Model Hub 服务未连接")
                    .font(.system(size: theme.titleSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text("请确认 fusion-model-hub 服务已启动（端口 \(FusionConfig.shared.modelHubPort)）")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textSecondary)
                Button("重试连接") {
                    Task { await client.checkConnection() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch selectedSection {
            case .dashboard:
                HubDashboardView(client: client)
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
            }
        }
    }
}
