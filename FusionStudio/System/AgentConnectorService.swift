// ARCH-1: Connector Operations 从 AgentBridge God-object 抽出, facade extension。
// 6 方法 (fetchConnectors/connectorCreate/connectorDelete/connectorConnect/connectorDisconnect/connectorTest),
//   0 private 静态依赖, 0 持久状态, 0 跨域实例调用。叶 silo。
// connectorCreate/connectorDelete 调 await fetchConnectors() (本文件同域, extension 内可达)。
// @Published connectors (L1969) 留主类 (extension 不可声明存储, 有外部 SwiftUI 读 AgentConfigTabs/AgentConfigViews)。
//   extension 写 self.configState.connectors, 观察链不变。
// ipcClient 仍存 AgentBridge, extension 读 self.ipcClient。logger private → 文件级 agentConnectorLog。

import Foundation
import os.log

private let agentConnectorLog = Logger(subsystem: "com.fusion.studio", category: "AgentConnectorService")

extension AgentBridge {

    // MARK: - Connector Operations

    func fetchConnectors() async {
        if let t = connectorsFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        connectorsFetchedAt = Date()
        guard let client = ipcClient else { return }
        do {
            let result = try await client.connectorList()
            self.configState.connectors = result["connectors"] as? [[String: Any]] ?? []
            agentConnectorLog.info("Fetched \(self.configState.connectors.count) connectors")
        } catch {
            agentConnectorLog.debug("fetchConnectors failed: \(error.localizedDescription)")
        }
    }

    func connectorCreate(name: String, type: String, config: [String: Any]) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.connectorCreate(name: name, type: type, config: config)
        connectorsFetchedAt = nil
        await fetchConnectors()
        return result
    }

    func connectorDelete(connectorId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.connectorDelete(connectorId: connectorId)
        connectorsFetchedAt = nil
        await fetchConnectors()
        return result
    }

    func connectorConnect(connectorId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.connectorConnect(connectorId: connectorId)
    }

    func connectorDisconnect(connectorId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.connectorDisconnect(connectorId: connectorId)
    }

    func connectorTest(connectorId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.connectorTest(connectorId: connectorId)
    }
}
