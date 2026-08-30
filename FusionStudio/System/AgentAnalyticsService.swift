// ARCH-1 PR3 (#359 facade-delegate): Analytics & Alert Operations 从 AgentBridge God-object 迁入 ConfigState 域。
//   本文件含 2 extension:
//     1) extension ConfigState — 3 真实方法体 (fetchAnalytics/fetchAlerts/alertAcknowledge, 自持 ipcClient + alertsFetchedAt TTL)。
//     2) extension AgentBridge — 3 个 1 行 facade stub 委托到 configState.X(), 保外部 call site 签名零变。
//   0 private 静态依赖, 0 跨域实例调用, 3 方法全自包含 (alertAcknowledge→fetchAlerts 同域 extension 内可达)。
//   @Published analyticsData/alerts 在 ConfigState 域 (外部 SwiftUI 读 AgentConfigTabs), 经 bridge.configState.X 不变。

import Foundation
import os.log

private let agentAnalyticsLog = Logger(subsystem: "com.fusion.studio", category: "AgentAnalyticsService")

// MARK: - Analytics & Alert Operations (行为落地 ConfigState 域)
extension ConfigState {

    func fetchAnalytics(agentId: String? = nil, range: String = "week") async {
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.analyticsAgentUsage(agentId: agentId, range: range)
            self.analyticsData = result
            agentAnalyticsLog.info("Analytics fetched")
        } catch {
            agentAnalyticsLog.debug("fetchAnalytics failed: \(error.localizedDescription)")
        }
    }

    func fetchAlerts() async {
        if let t = self.alertsFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        self.alertsFetchedAt = Date()
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.alertList()
            self.alerts = ConfigState.capConfigArray(result["alerts"] as? [[String: Any]] ?? [])
            agentAnalyticsLog.info("Fetched \(self.alerts.count) alerts")
        } catch {
            agentAnalyticsLog.debug("fetchAlerts failed: \(error.localizedDescription)")
        }
    }

    func alertAcknowledge(alertId: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        let result = try await client.alertAcknowledge(alertId: alertId)
        self.alertsFetchedAt = nil
        await fetchAlerts()
        return result
    }
}

// MARK: - Analytics & Alert Operations (facade-delegate stubs — 行为已迁 ConfigState 域)
extension AgentBridge {

    func fetchAnalytics(agentId: String? = nil, range: String = "week") async {
        await configState.fetchAnalytics(agentId: agentId, range: range)
    }

    func fetchAlerts() async {
        await configState.fetchAlerts()
    }

    func alertAcknowledge(alertId: String) async throws -> [String: Any] {
        try await configState.alertAcknowledge(alertId: alertId)
    }
}
