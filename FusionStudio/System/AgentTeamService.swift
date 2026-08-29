// ARCH-1 PR3 (#359 facade-delegate): Team Operations 从 AgentBridge God-object 迁入 ConfigState 域。
//   本文件含 2 extension:
//     1) extension ConfigState — 3 真实方法体 (teamOrchestrate/fetchSwarmAgents/fetchPlazaChannels, 自持 ipcClient, 无 TTL)。
//     2) extension AgentBridge — 3 个 1 行 facade stub 委托到 configState.X(), 保外部 call site 签名零变。
//   0 private 静态依赖, 0 持久状态, 0 跨域实例调用。叶 silo。teamOrchestrate 不写状态 (纯透传 RPC)。
//   MAINT: teamSwarmRegister/Delegate/Stats + teamPlazaCreate/Broadcast 删 (0 前端调用方, UI 只读列表)。后端 RPC 不动 (跨工程)。
//   @Published swarmAgents/plazaChannels 在 ConfigState 域 (外部 SwiftUI 读 AgentConfigTabs), 经 bridge.configState.X 不变。

import os.log

private let agentTeamLog = Logger(subsystem: "com.fusion.studio", category: "AgentTeamService")

// MARK: - Team Operations (行为落地 ConfigState 域)
extension ConfigState {

    func teamOrchestrate(task: String, agentIds: [String], mode: String = "sequential") async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        return try await client.teamOrchestrate(task: task, agentIds: agentIds, mode: mode)
    }

    func fetchSwarmAgents() async {
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.teamSwarmAgents()
            self.swarmAgents = result["agents"] as? [[String: Any]] ?? []
            agentTeamLog.info("Fetched \(self.swarmAgents.count) swarm agents")
        } catch {
            agentTeamLog.debug("fetchSwarmAgents failed: \(error.localizedDescription)")
        }
    }

    // MAINT: teamSwarmRegister/Delegate/Stats 删除 — 0 前端调用方 (UI 只读 swarmAgents 列表, 无 swarm 管理 button)。后端 RPC 不动 (跨工程)。

    func fetchPlazaChannels() async {
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.teamPlazaChannels()
            self.plazaChannels = result["channels"] as? [[String: Any]] ?? []
            agentTeamLog.info("Fetched \(self.plazaChannels.count) plaza channels")
        } catch {
            agentTeamLog.debug("fetchPlazaChannels failed: \(error.localizedDescription)")
        }
    }

    // MAINT: teamPlazaCreate/Broadcast 删除 — 0 前端调用方 (UI 只读 plazaChannels 列表, 无频道创建/广播 button)。后端 RPC 不动 (跨工程)。
}

// MARK: - Team Operations (facade-delegate stubs — 行为已迁 ConfigState 域)
extension AgentBridge {

    func teamOrchestrate(task: String, agentIds: [String], mode: String = "sequential") async throws -> [String: Any] {
        try await configState.teamOrchestrate(task: task, agentIds: agentIds, mode: mode)
    }

    func fetchSwarmAgents() async {
        await configState.fetchSwarmAgents()
    }

    func fetchPlazaChannels() async {
        await configState.fetchPlazaChannels()
    }
}
