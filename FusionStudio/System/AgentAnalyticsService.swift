// ARCH-1: Analytics & Alert Operations 从 AgentBridge God-object 抽出, facade extension。
// @Published analyticsData/alerts + ipcClient 仍存 AgentBridge (extension 不可声明存储), 本文件只搬方法体, 行为零变。
// analyticsData/alerts @Published 有外部 SwiftUI 读 (AgentConfigTabs), @Published 留主类 extension 写 self, 观察链不变。
// 0 private 静态依赖, 0 跨域实例方法调用, 3 方法全自包含 (alertAcknowledge→fetchAlerts 域内调用同 extension 内 self 调用)。

import os.log

private let agentAnalyticsLog = Logger(subsystem: "com.fusion.studio", category: "AgentAnalyticsService")

extension AgentBridge {

    func fetchAnalytics(agentId: String? = nil, range: String = "week") async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.analyticsAgentUsage(agentId: agentId, range: range)
            self.analyticsData = result
            agentAnalyticsLog.info("Analytics fetched")
        } catch {
            agentAnalyticsLog.debug("fetchAnalytics failed: \(error.localizedDescription)")
        }
    }

    func fetchAlerts() async {
        if let t = alertsFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        alertsFetchedAt = Date()
        guard let client = ipcClient else { return }
        do {
            let result = try await client.alertList()
            self.alerts = result["alerts"] as? [[String: Any]] ?? []
            agentAnalyticsLog.info("Fetched \(self.alerts.count) alerts")
        } catch {
            agentAnalyticsLog.debug("fetchAlerts failed: \(error.localizedDescription)")
        }
    }

    func alertAcknowledge(alertId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.alertAcknowledge(alertId: alertId)
        alertsFetchedAt = nil
        await fetchAlerts()
        return result
    }
}
