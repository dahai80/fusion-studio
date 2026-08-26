// ARCH-1: Team Operations 从 AgentBridge God-object 抽出, facade extension。
// 3 方法 (teamOrchestrate/fetchSwarmAgents/fetchPlazaChannels), 0 private 静态依赖, 0 持久状态, 0 跨域实例调用。叶 silo。
// MAINT: teamSwarmRegister/Delegate/Stats + teamPlazaCreate/Broadcast 删 (0 前端调用方, UI 只读列表)。后端 RPC 不动 (跨工程)。
// @Published swarmAgents(L2108)/plazaChannels(L2109) 留主类 (extension 不可声明存储, 有外部 SwiftUI 读 AgentConfigTabs)。
//   extension 写 self.prop, 观察链不变。
// ipcClient 仍存 AgentBridge, extension 读 self.ipcClient。logger private → 文件级 agentTeamLog。

import os.log

private let agentTeamLog = Logger(subsystem: "com.fusion.studio", category: "AgentTeamService")

extension AgentBridge {

    // MARK: - Team Operations

    func teamOrchestrate(task: String, agentIds: [String], mode: String = "sequential") async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.teamOrchestrate(task: task, agentIds: agentIds, mode: mode)
    }

    func fetchSwarmAgents() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.teamSwarmAgents()
            self.configState.swarmAgents = result["agents"] as? [[String: Any]] ?? []
            agentTeamLog.info("Fetched \(self.configState.swarmAgents.count) swarm agents")
        } catch {
            agentTeamLog.debug("fetchSwarmAgents failed: \(error.localizedDescription)")
        }
    }

    // MAINT: teamSwarmRegister/Delegate/Stats 删除 — 0 前端调用方 (UI 只读 swarmAgents 列表, 无 swarm 管理 button)。后端 RPC 不动 (跨工程)。

    func fetchPlazaChannels() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.teamPlazaChannels()
            self.configState.plazaChannels = result["channels"] as? [[String: Any]] ?? []
            agentTeamLog.info("Fetched \(self.configState.plazaChannels.count) plaza channels")
        } catch {
            agentTeamLog.debug("fetchPlazaChannels failed: \(error.localizedDescription)")
        }
    }

    // MAINT: teamPlazaCreate/Broadcast 删除 — 0 前端调用方 (UI 只读 plazaChannels 列表, 无频道创建/广播 button)。后端 RPC 不动 (跨工程)。
}
