// ARCH-1: Team Operations 从 AgentBridge God-object 抽出, facade extension。
// 8 方法 (teamOrchestrate/fetchSwarmAgents/teamSwarmRegister/teamSwarmDelegate/teamSwarmStats/
//   fetchPlazaChannels/teamPlazaCreate/teamPlazaBroadcast), 0 private 静态依赖, 0 lastError 写, 0 跨域实例调用。叶 silo。
// teamSwarmRegister 调 await fetchSwarmAgents(), teamPlazaCreate 调 await fetchPlazaChannels() — 同域 extension 内可达。
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
            self.swarmAgents = result["agents"] as? [[String: Any]] ?? []
            agentTeamLog.info("Fetched \(self.swarmAgents.count) swarm agents")
        } catch {
            agentTeamLog.debug("fetchSwarmAgents failed: \(error.localizedDescription)")
        }
    }

    func teamSwarmRegister(agentId: String, role: String = "worker") async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.teamSwarmRegister(agentId: agentId, role: role)
        await fetchSwarmAgents()
        return result
    }

    func teamSwarmDelegate(agentId: String, task: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.teamSwarmDelegate(agentId: agentId, task: task)
    }

    func teamSwarmStats() async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.teamSwarmStats()
    }

    func fetchPlazaChannels() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.teamPlazaChannels()
            self.plazaChannels = result["channels"] as? [[String: Any]] ?? []
            agentTeamLog.info("Fetched \(self.plazaChannels.count) plaza channels")
        } catch {
            agentTeamLog.debug("fetchPlazaChannels failed: \(error.localizedDescription)")
        }
    }

    func teamPlazaCreate(name: String, description: String = "") async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.teamPlazaCreate(name: name, description: description)
        await fetchPlazaChannels()
        return result
    }

    func teamPlazaBroadcast(channelId: String, message: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.teamPlazaBroadcast(channelId: channelId, message: message)
    }
}
