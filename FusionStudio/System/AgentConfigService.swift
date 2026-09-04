// ARCH-1 PR3 (#359 facade-delegate): Config Operations (apikeys + cron) 从 AgentBridge God-object 迁入 ConfigState 域。
//   本文件含 2 extension:
//     1) extension ConfigState — 7 真实方法体 (apikeys fetch/create/revoke/rotate + cron fetch/register/unregister, 自持 ipcClient + TTL)。
//     2) extension AgentBridge — 7 个 1 行 facade stub 委托到 configState.X(), 保外部 call site 签名零变。
//   SwiftUI 仅观察 AgentBridge (82 @EnvironmentObject), 0 直接域观察 → 0 view 改动。永久中间人 stub。
//   apikeys/cronJobs @Published 仍在 ConfigState 域, 外部读经 bridge.configState.X (let 稳定身份), 观察链不变。
// 耦合未迁: styles/hooks/connectors/alerts/analytics/swarmAgents/plazaChannels 行为在各自 Agent*Service.swift extension ConfigState (同 PR 迁)。
//   projectsFetchedAt/tasksFetchedAt 留 AgentBridge (TaskState 域, 未来 PR)。

import Foundation
import os.log

private let agentConfigLog = Logger(subsystem: "com.fusion.studio", category: "AgentConfigService")

// MARK: - API Key + Cron Operations (行为落地 ConfigState 域)
extension ConfigState {

    // MARK: - API Key Operations

    // F-A2子2: 30s TTL 客户端缓存, 防 onAppear fetch 风暴。写操作置 nil 强制下次重拉。
    func fetchApikeys() async {
        if let t = self.apikeysFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        self.apikeysFetchedAt = Date()
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.apikeyList()
            self.apikeys = ConfigState.capConfigArray(result["keys"] as? [[String: Any]] ?? [])
            agentConfigLog.info("Fetched \(self.apikeys.count) API keys")
        } catch {
            agentConfigLog.debug("fetchApikeys failed: \(error.localizedDescription)")
        }
    }

    func apikeyCreate(name: String, permissions: [String] = [], agentIds: [String] = []) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        let result = try await client.apikeyCreate(name: name, permissions: permissions, agentIds: agentIds)
        self.apikeysFetchedAt = nil
        await fetchApikeys()
        return result
    }

    func apikeyRevoke(keyId: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        let result = try await client.apikeyRevoke(keyId: keyId)
        self.apikeysFetchedAt = nil
        await fetchApikeys()
        return result
    }

    func apikeyRotate(keyId: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        // FUNC-1 (审计product-0905 P1): 后端无 agent_studio.apikey.rotate 命名空间; 实现的是 apikey.rotate (infra.py)。
        // 客户端已有正确常量 RPCMethod.apikeyRotate (IPCExtendedMethods:160), 直接用。
        let result = try await client.call(method: RPCMethod.apikeyRotate, params: ["key_id": keyId])
        self.apikeysFetchedAt = nil
        await fetchApikeys()
        agentConfigLog.info("Rotated API key: \(keyId)")
        return result
    }

    // MARK: - Cron Operations

    func fetchCronJobs() async {
        if let t = self.cronJobsFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        self.cronJobsFetchedAt = Date()
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.cronList()
            self.cronJobs = ConfigState.capConfigArray(result["jobs"] as? [[String: Any]] ?? result["crons"] as? [[String: Any]] ?? [])
            agentConfigLog.info("Fetched \(self.cronJobs.count) cron jobs")
        } catch {
            agentConfigLog.debug("fetchCronJobs failed: \(error.localizedDescription)")
        }
    }

    func cronRegister(name: String, schedule: String, agentId: String, input: String = "") async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        let result = try await client.cronRegister(name: name, schedule: schedule, agentId: agentId, input: input)
        self.cronJobsFetchedAt = nil
        await fetchCronJobs()
        return result
    }

    func cronUnregister(cronId: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        let result = try await client.cronUnregister(cronId: cronId)
        self.cronJobsFetchedAt = nil
        await fetchCronJobs()
        return result
    }
}

// MARK: - API Key + Cron Operations (facade-delegate stubs — 行为已迁 ConfigState 域)
// ARCH-1 PR3: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func fetchApikeys() async {
        await configState.fetchApikeys()
    }

    func apikeyCreate(name: String, permissions: [String] = [], agentIds: [String] = []) async throws -> [String: Any] {
        try await configState.apikeyCreate(name: name, permissions: permissions, agentIds: agentIds)
    }

    func apikeyRevoke(keyId: String) async throws -> [String: Any] {
        try await configState.apikeyRevoke(keyId: keyId)
    }

    func apikeyRotate(keyId: String) async throws -> [String: Any] {
        try await configState.apikeyRotate(keyId: keyId)
    }

    func fetchCronJobs() async {
        await configState.fetchCronJobs()
    }

    func cronRegister(name: String, schedule: String, agentId: String, input: String = "") async throws -> [String: Any] {
        try await configState.cronRegister(name: name, schedule: schedule, agentId: agentId, input: input)
    }

    func cronUnregister(cronId: String) async throws -> [String: Any] {
        try await configState.cronUnregister(cronId: cronId)
    }
}
