import SwiftUI
import os.log

private let dashLog = Logger(subsystem: "com.fusion.studio", category: "AIAgent.Dashboard")

struct AIAgentDashboardView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var bridge: AgentBridge
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme

    @State private var overview: [String: Any]?
    @State private var isLoading = true
    @State private var recentAgents: [AgentModel] = []
    @State private var showCreateAgent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(
                    eyebrow: "Fusion Agent Studio",
                    title: "控制台总览",
                    subtitle: "Agent 管理控制台 — 全局数据看板与快捷入口"
                )

                statCardsRow
                    .padding(.horizontal, theme.spacingL)
                    .padding(.bottom, theme.spacingL)

                quickActionsRow
                    .padding(.horizontal, theme.spacingL)
                    .padding(.bottom, theme.spacingL)

                recentAgentsSection
                    .padding(.horizontal, theme.spacingL)
                    .padding(.bottom, theme.spacingL)

                alertsSection
                    .padding(.horizontal, theme.spacingL)
                    .padding(.bottom, theme.spacingXL)
            }
        }
        .background(theme.contentBg)
        .onAppear { loadDashboard() }
        .sheet(isPresented: $showCreateAgent) {
            AIAgentConfigView(mode: .create)
        }
    }

    private var statCardsRow: some View {
        HStack(spacing: theme.spacingM) {
            StatCardView(
                title: "今日请求",
                value: "\(intField("today_requests"))",
                icon: "arrow.up.arrow.down",
                color: theme.accent
            )
            StatCardView(
                title: "Token 消耗",
                value: formatTokenCount(intField("total_tokens")),
                icon: "bolt.horizontal",
                color: theme.auxiliary
            )
            StatCardView(
                title: "活跃 Agent",
                value: "\(intField("active_agents"))",
                icon: "person.2.fill",
                color: theme.accentSecondary
            )
            StatCardView(
                title: "异常请求",
                value: "\(intField("error_requests"))",
                icon: "exclamationmark.triangle",
                color: theme.accentDestructive
            )
        }
    }

    private var quickActionsRow: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("快捷入口")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: theme.spacingM) {
                QuickActionCard(
                    title: "创建新 Agent",
                    icon: "plus.circle.fill",
                    color: theme.accent
                ) { createNewAgent() }

                QuickActionCard(
                    title: "新建知识库",
                    icon: "books.vertical.fill",
                    color: theme.auxiliary
                ) { appState.selectedModule = .aiAgentList }

                QuickActionCard(
                    title: "管理连接器",
                    icon: "link.circle.fill",
                    color: theme.accentSecondary
                ) { appState.selectedModule = .aiAgentObserver }

                QuickActionCard(
                    title: "API 文档",
                    icon: "doc.text.fill",
                    color: theme.textTertiary
                ) { dashLog.info("navigate to api docs") }
            }
        }
    }

    private var recentAgentsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text("最近 Agent")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("查看全部") {
                    appState.selectedModule = .aiAgentList
                }
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.accent)
                .buttonStyle(.plain)
            }

            if recentAgents.isEmpty {
                emptyAgentsPlaceholder
            } else {
                VStack(spacing: theme.spacingS) {
                    ForEach(recentAgents.prefix(5), id: \.id) { agent in
                        AgentSummaryRow(agent: agent)
                    }
                }
            }
        }
    }

    private var emptyAgentsPlaceholder: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "person.2")
                .font(.system(size: theme.iconXL))
                .foregroundStyle(theme.textTertiary)
            Text("暂无 Agent，点击上方创建")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing2XL)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("告警通知")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            let alerts = (overview?["alerts"] as? [[String: Any]]) ?? []
            if alerts.isEmpty {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(theme.accent)
                    Text("一切正常，无告警")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(theme.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.accentSoft.opacity(0.15))
                )
            } else {
                VStack(spacing: theme.spacingXS) {
                    ForEach(Array(alerts.prefix(3).enumerated()), id: \.offset) { _, alert in
                        AlertRow(alert: alert)
                    }
                }
            }
        }
    }

    private func intField(_ key: String) -> Int {
        guard let val = overview?[key] else { return 0 }
        if let i = val as? Int { return i }
        if let d = val as? Double { return Int(d) }
        if let s = val as? String, let i = Int(s) { return i }
        return 0
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private func loadDashboard() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.dashboardOverview()
                dashLog.info("Dashboard overview loaded")
                await MainActor.run { overview = result }
            } catch {
                dashLog.error("Dashboard overview failed: \(error.localizedDescription)")
            }
            do {
                try await bridge.fetchAgents()
                await MainActor.run { recentAgents = bridge.agents }
            } catch {
                dashLog.error("Fetch agents failed: \(error.localizedDescription)")
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func createNewAgent() {
        dashLog.info("Create new agent triggered")
        showCreateAgent = true
    }
}

private struct StatCardView: View {
    @Environment(\.studioTheme) private var theme
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            }
            Text(value)
                .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text)
        }
        .padding(theme.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct QuickActionCard: View {
    @Environment(\.studioTheme) private var theme
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: theme.spacingS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconXL))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
            }
            .padding(theme.spacingL)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .fill(theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AgentSummaryRow: View {
    @Environment(\.studioTheme) private var theme
    let agent: AgentModel

    var body: some View {
        HStack(spacing: theme.spacingM) {
            Circle()
                .fill(agentStatusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(agent.model)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            Text(agent.statusLabel)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(agentStatusColor)
                .padding(.horizontal, theme.spacingS)
                .padding(.vertical, theme.spacingXS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(agentStatusColor.opacity(0.12))
                )
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    private var agentStatusColor: Color {
        switch agent.status {
        case "published", "active": return theme.accent
        case "draft", "idle": return theme.textTertiary
        case "archived": return theme.textQuaternary
        default: return theme.auxiliary
        }
    }
}

private struct AlertRow: View {
    @Environment(\.studioTheme) private var theme
    let alert: [String: Any]

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.accentDestructive)
            Text(alert["message"] as? String ?? "未知告警")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.text)
            Spacer()
            Text(alert["time"] as? String ?? "")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.accentDestructive.opacity(0.08))
        )
    }
}
