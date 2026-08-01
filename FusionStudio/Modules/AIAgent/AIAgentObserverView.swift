import SwiftUI
import os.log

// Callers: SectionContentView routes .aiAgentObserver to this view.
// Affected API: ipc.analyticsAgentUsage/alertList/alertAcknowledge/apikeyCreate/apikeyList/apikeyRevoke/
//   apikeyRotate/connectorList/connectorConnect/connectorCreate/connectorDelete.
// Data schemas: API keys (id,name,prefix,created_at); Connectors (id,name,type,status);
//   Analytics (today_requests,total_tokens,active_agents,error_rate); Alerts (id,level,message).
// User instruction: "按照GUI草图实现fusion-ai-agent... 一定要做的比claude ai agent更有竞争力"

private let observerLog = Logger(subsystem: "com.fusion.studio", category: "AIAgent.Observer")

enum ObserverTab: String, CaseIterable {
    case usage = "用量统计"
    case logs = "执行日志"
    case apikeys = "API 密钥"
    case connectors = "连接器"

    var icon: String {
        switch self {
        case .usage: return "chart.bar"
        case .logs: return "list.bullet.rectangle"
        case .apikeys: return "key"
        case .connectors: return "link"
        }
    }
}

struct AIAgentObserverView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    @State private var selectedTab: ObserverTab = .usage
    @State private var usageData: [String: Any] = [:]
    @State private var alerts: [[String: Any]] = []
    @State private var apiKeys: [[String: Any]] = []
    @State private var connectors: [[String: Any]] = []
    @State private var executionLogs: [ExecLogEntry] = []
    @State private var isLoading = false

    struct ExecLogEntry: Identifiable {
        let id = UUID()
        let agentName: String
        let action: String
        let duration: String
        let timestamp: Date
        let status: String
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            tabBar
            Rectangle().fill(theme.separator).frame(height: 1)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.surfaceElevated)
        .onAppear { loadAll() }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("监控与管理")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text("用量统计 · 执行日志 · API 密钥 · 连接器")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Button(action: { loadAll() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(ObserverTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: tab.icon)
                                .font(.system(size: theme.iconS))
                            Text(tab.rawValue)
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? theme.accentText : theme.textSecondary)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(selectedTab == tab ? theme.accent : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, theme.spacingL)
        }
        .padding(.vertical, theme.spacingXS)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .usage: usageTab
        case .logs: logsTab
        case .apikeys: apiKeysTab
        case .connectors: connectorsTab
        }
    }

    // MARK: - Usage Tab

    private var usageTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                HStack(spacing: theme.spacingM) {
                    usageStatCard("今日请求", value: usageValue("today_requests"), icon: "arrow.up.circle")
                    usageStatCard("总 Token", value: usageValue("total_tokens"), icon: "number.circle")
                    usageStatCard("活跃 Agent", value: usageValue("active_agents"), icon: "brain")
                    usageStatCard("错误率", value: usageValue("error_rate"), icon: "exclamationmark.triangle")
                }

                if !alerts.isEmpty {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        Text("告警")
                            .font(.system(size: theme.footnoteSize, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)

                        ForEach(Array(alerts.enumerated()), id: \.offset) { _, alert in
                            alertRow(alert)
                        }
                    }
                }
            }
            .padding(theme.spacingL)
        }
    }

    private func usageStatCard(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.auxiliary)
                Text(title)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Text(value)
                .font(.system(size: theme.headlineSize, weight: .bold, design: .monospaced))
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
                .strokeBorder(theme.separator, lineWidth: 1)
        )
    }

    private func alertRow(_ alert: [String: Any]) -> some View {
        let level = alert["level"] as? String ?? "info"
        let message = alert["message"] as? String ?? ""
        let alertId = alert["id"] as? String ?? ""

        return HStack(spacing: theme.spacingS) {
            Image(systemName: level == "error" ? "xmark.circle.fill" : level == "warning" ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(level == "error" ? theme.accentDestructive : level == "warning" ? theme.auxiliary : theme.accent)
                .font(.system(size: theme.iconM))

            Text(message)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.text)
                .lineLimit(2)

            Spacer()

            Button("确认") {
                acknowledgeAlert(alertId: alertId)
            }
            .font(.system(size: theme.captionSize))
            .foregroundStyle(theme.accent)
            .buttonStyle(.plain)
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    // MARK: - Logs Tab

    private var logsTab: some View {
        VStack(spacing: 0) {
            if executionLogs.isEmpty {
                emptyState(icon: "list.bullet.rectangle", message: "暂无执行日志")
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(executionLogs) { entry in
                            logEntryRow(entry)
                        }
                    }
                    .padding(theme.spacingL)
                }
            }
        }
    }

    private func logEntryRow(_ entry: ExecLogEntry) -> some View {
        HStack(spacing: theme.spacingS) {
            Text(entry.timestamp, style: .time)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 60, alignment: .leading)

            Text(entry.agentName)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.text)
                .frame(width: 100, alignment: .leading)

            Text(entry.action)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)

            Spacer()

            Text(entry.duration)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.textTertiary)

            Circle()
                .fill(entry.status == "success" ? theme.accent : theme.accentDestructive)
                .frame(width: 8, height: 8)
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    // MARK: - API Keys Tab

    private var apiKeysTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("API 密钥管理")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { createApiKey() }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "plus")
                        Text("创建密钥")
                    }
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.accent)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)

            if apiKeys.isEmpty {
                emptyState(icon: "key", message: "暂无 API 密钥")
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingS) {
                        ForEach(Array(apiKeys.enumerated()), id: \.offset) { _, key in
                            apiKeyRow(key)
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                }
            }
        }
    }

    private func apiKeyRow(_ key: [String: Any]) -> some View {
        let keyId = key["id"] as? String ?? ""
        let keyName = key["name"] as? String ?? "Unnamed Key"
        let prefix = key["prefix"] as? String ?? "fk-****"
        let createdAt = key["created_at"] as? String ?? ""

        return HStack(spacing: theme.spacingM) {
            Image(systemName: "key.fill")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.auxiliary)

            VStack(alignment: .leading, spacing: 2) {
                Text(keyName)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                HStack(spacing: theme.spacingS) {
                    Text(prefix)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    Text("创建于 \(createdAt.prefix(10))")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            Button(action: { rotateApiKey(keyId: keyId) }) {
                Text("轮换")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)

            Button(action: { revokeApiKey(keyId: keyId) }) {
                Text("吊销")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.accentDestructive)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    // MARK: - Connectors Tab

    private var connectorsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("外部连接器")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { createConnector() }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "plus")
                        Text("添加连接器")
                    }
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.accent)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)

            if connectors.isEmpty {
                emptyState(icon: "link", message: "暂无已配置的连接器")
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingS) {
                        ForEach(Array(connectors.enumerated()), id: \.offset) { _, conn in
                            connectorRow(conn)
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                }
            }
        }
    }

    private func connectorRow(_ conn: [String: Any]) -> some View {
        let connId = conn["id"] as? String ?? ""
        let connName = conn["name"] as? String ?? "Unnamed"
        let connType = conn["type"] as? String ?? "unknown"
        let connStatus = conn["status"] as? String ?? "disconnected"

        return HStack(spacing: theme.spacingM) {
            Image(systemName: connectorIcon(connType))
                .font(.system(size: theme.iconL))
                .foregroundStyle(theme.auxiliary)

            VStack(alignment: .leading, spacing: 2) {
                Text(connName)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(connType)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            HStack(spacing: theme.spacingXS) {
                Circle()
                    .fill(connStatus == "connected" ? theme.accent : theme.textTertiary)
                    .frame(width: 8, height: 8)
                Text(connStatus == "connected" ? "已连接" : "未连接")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }

            if connStatus != "connected" {
                Button("连接") {
                    connectConnector(connId: connId)
                }
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.accent)
                .buttonStyle(.plain)
            }

            Button(action: { deleteConnector(connId: connId) }) {
                Image(systemName: "trash")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    // MARK: - Helpers

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text(message)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func usageValue(_ key: String) -> String {
        if let val = usageData[key] {
            if let intVal = val as? Int { return "\(intVal)" }
            if let doubleVal = val as? Double { return String(format: "%.1f", doubleVal) }
            if let strVal = val as? String { return strVal }
            return "\(val)"
        }
        return "-"
    }

    private func connectorIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "github": return "chevron.left.forwardslash.chevron.right"
        case "slack": return "message"
        case "database": return "cylinder"
        case "webhook": return "arrow.up.right"
        default: return "link"
        }
    }

    // MARK: - Data Loading

    private func loadAll() {
        isLoading = true
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await loadUsage() }
                group.addTask { await loadAlerts() }
                group.addTask { await loadApiKeys() }
                group.addTask { await loadConnectors() }
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func loadUsage() async {
        do {
            let result = try await ipc.analyticsAgentUsage(agentId: nil, range: "week")
            await MainActor.run { usageData = result }
        } catch {
            observerLog.error("Load usage failed: \(error.localizedDescription)")
        }
    }

    private func loadAlerts() async {
        do {
            let result = try await ipc.alertList()
            let items = result["alerts"] as? [[String: Any]] ?? (result["data"] as? [[String: Any]] ?? [])
            await MainActor.run { alerts = items }
        } catch {
            observerLog.error("Load alerts failed: \(error.localizedDescription)")
        }
    }

    private func loadApiKeys() async {
        do {
            let result = try await ipc.apikeyList()
            let items = result["keys"] as? [[String: Any]] ?? (result["data"] as? [[String: Any]] ?? [])
            await MainActor.run { apiKeys = items }
        } catch {
            observerLog.error("Load API keys failed: \(error.localizedDescription)")
        }
    }

    private func loadConnectors() async {
        do {
            let result = try await ipc.connectorList()
            let items = result["connectors"] as? [[String: Any]] ?? (result["data"] as? [[String: Any]] ?? [])
            await MainActor.run { connectors = items }
        } catch {
            observerLog.error("Load connectors failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions

    private func acknowledgeAlert(alertId: String) {
        Task {
            do {
                let _ = try await ipc.alertAcknowledge(alertId: alertId)
                observerLog.info("Alert acknowledged: \(alertId)")
                await loadAlerts()
            } catch {
                observerLog.error("Acknowledge alert failed: \(error.localizedDescription)")
            }
        }
    }

    private func createApiKey() {
        Task {
            do {
                let _ = try await ipc.apikeyCreate(name: "API Key \(apiKeys.count + 1)", permissions: ["agent:execute"])
                observerLog.info("API key created")
                await loadApiKeys()
            } catch {
                observerLog.error("Create API key failed: \(error.localizedDescription)")
            }
        }
    }

    private func rotateApiKey(keyId: String) {
        Task {
            do {
                let _ = try await ipc.apikeyRotate(keyId: keyId)
                observerLog.info("API key rotated: \(keyId)")
                await loadApiKeys()
            } catch {
                observerLog.error("Rotate API key failed: \(error.localizedDescription)")
            }
        }
    }

    private func revokeApiKey(keyId: String) {
        Task {
            do {
                let _ = try await ipc.apikeyRevoke(keyId: keyId)
                observerLog.info("API key revoked: \(keyId)")
                await loadApiKeys()
            } catch {
                observerLog.error("Revoke API key failed: \(error.localizedDescription)")
            }
        }
    }

    private func createConnector() {
        Task {
            do {
                let _ = try await ipc.connectorCreate(name: "New Connector", type: "webhook", config: [:])
                observerLog.info("Connector created")
                await loadConnectors()
            } catch {
                observerLog.error("Create connector failed: \(error.localizedDescription)")
            }
        }
    }

    private func connectConnector(connId: String) {
        Task {
            do {
                let _ = try await ipc.connectorConnect(connectorId: connId)
                observerLog.info("Connector connected: \(connId)")
                await loadConnectors()
            } catch {
                observerLog.error("Connect connector failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteConnector(connId: String) {
        Task {
            do {
                let _ = try await ipc.connectorDelete(connectorId: connId)
                observerLog.info("Connector deleted: \(connId)")
                await loadConnectors()
            } catch {
                observerLog.error("Delete connector failed: \(error.localizedDescription)")
            }
        }
    }
}
