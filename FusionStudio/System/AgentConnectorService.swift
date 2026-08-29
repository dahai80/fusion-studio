// ARCH-1 PR3 (#359 facade-delegate): Connector Operations 从 AgentBridge God-object 迁入 ConfigState 域。
//   本文件含 2 extension:
//     1) extension ConfigState — 6 真实方法体 (fetchConnectors/connectorCreate/connectorDelete/connectorConnect/connectorDisconnect/connectorTest, 自持 ipcClient + connectorsFetchedAt TTL)。
//     2) extension AgentBridge — 6 个 1 行 facade stub 委托到 configState.X(), 保外部 call site 签名零变。
//   0 private 静态依赖, 0 持久状态, 0 跨域实例调用。叶 silo。connectorCreate/Delete 调 fetchConnectors (同域 extension 内可达)。
//   @Published connectors 在 ConfigState 域 (外部 SwiftUI 读 AgentConfigTabs/AgentConfigViews), 经 bridge.configState.connectors 不变。

import Foundation
import os.log

private let agentConnectorLog = Logger(subsystem: "com.fusion.studio", category: "AgentConnectorService")

// MARK: - Connector Operations (行为落地 ConfigState 域)
extension ConfigState {

    func fetchConnectors() async {
        if let t = self.connectorsFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        self.connectorsFetchedAt = Date()
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.connectorList()
            self.connectors = result["connectors"] as? [[String: Any]] ?? []
            agentConnectorLog.info("Fetched \(self.connectors.count) connectors")
        } catch {
            agentConnectorLog.debug("fetchConnectors failed: \(error.localizedDescription)")
        }
    }

    func connectorCreate(name: String, type: String, config: [String: Any]) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        let result = try await client.connectorCreate(name: name, type: type, config: config)
        self.connectorsFetchedAt = nil
        await fetchConnectors()
        return result
    }

    func connectorDelete(connectorId: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        let result = try await client.connectorDelete(connectorId: connectorId)
        self.connectorsFetchedAt = nil
        await fetchConnectors()
        return result
    }

    func connectorConnect(connectorId: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        return try await client.connectorConnect(connectorId: connectorId)
    }

    func connectorDisconnect(connectorId: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        return try await client.connectorDisconnect(connectorId: connectorId)
    }

    func connectorTest(connectorId: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        return try await client.connectorTest(connectorId: connectorId)
    }
}

// MARK: - Connector Operations (facade-delegate stubs — 行为已迁 ConfigState 域)
extension AgentBridge {

    func fetchConnectors() async {
        await configState.fetchConnectors()
    }

    func connectorCreate(name: String, type: String, config: [String: Any]) async throws -> [String: Any] {
        try await configState.connectorCreate(name: name, type: type, config: config)
    }

    func connectorDelete(connectorId: String) async throws -> [String: Any] {
        try await configState.connectorDelete(connectorId: connectorId)
    }

    func connectorConnect(connectorId: String) async throws -> [String: Any] {
        try await configState.connectorConnect(connectorId: connectorId)
    }

    func connectorDisconnect(connectorId: String) async throws -> [String: Any] {
        try await configState.connectorDisconnect(connectorId: connectorId)
    }

    func connectorTest(connectorId: String) async throws -> [String: Any] {
        try await configState.connectorTest(connectorId: connectorId)
    }
}
