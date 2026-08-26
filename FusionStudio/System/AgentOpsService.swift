// ARCH-1 / F-A1: Agent Operations + Lifecycle + marketplaceInstall 从 AgentBridge God-object 抽出, facade extension。
// @Published self.agentState.agents/self.agentState.currentAgent/self.agentState.agentSkills/self.agentState.agentSoul/self.agentState.agentVersionHistory/self.agentState.auditTrail/self.agentState.sessionLogs/
//   self.agentState.activeSessionId/self.agentState.streamingContent/self.agentState.isAgentStreaming/self.agentState.lastToolCalls/self.agentState.dashboardData 仍存 AgentBridge
//   (extension 不可声明存储属性), 本文件只搬方法体, 行为零变。11 个 @Published 集中声明在 AgentBridge
//   header (原散落本域 MARK 中, 抽迁时迁入 header), extension 写 self.<prop>, 观察链不变。
// parseAgentModel (private static, 13 调用方全本域+marketplaceInstall) 随域同迁 — private = 文件作用域,
//   同文件 extension Self.parseAgentModel 可达, 同 #287 parseMarketplaceEntry / Graph parseGraphModel 范式。
//   marketplaceInstall 原留 AgentBridge (cross-domain private static 跨文件不可访问), parseAgentModel 入本文件后
//   marketplaceInstall 同域可访问, 一并迁入。
// agentFetchInFlight/agentFetchLock (F-R4 dedup 静态, 仅 fetchAgents 用) 随域同迁。
// Logger: 主类 private logger file-scoped 不可跨文件, 本文件自有 agentOpsLog 替代 (所有 logger. 处)。

import Foundation
import os.log

private let agentOpsLog = Logger(subsystem: "com.fusion.studio", category: "AgentOpsService")

extension AgentBridge {

    // MARK: - Agent Operations

    func agentCreate(name: String, model: String = "", systemPrompt: String = "", temperature: Double = 0.7, maxTokens: Int = 4096, tools: [String] = [], capabilities: [String] = [], safetyLevel: String = "L1", tags: [String] = [], description: String = "", soul: String = "", memory: String = "", agentsMd: String = "") async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentCreate: name=\(name), soul=\(soul.isEmpty ? "empty" : "set"), memory=\(memory.isEmpty ? "empty" : "set"), agentsMd=\(agentsMd.isEmpty ? "empty" : "set")")
        do {
            let result = try await client.agentCreate(name: name, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags, description: description, soul: soul, memory: memory, agentsMd: agentsMd)
            guard let agent = Self.parseAgentModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse agent.create response")
            }
            self.agentState.agents.append(agent)
            Self.capAgents(&self.agentState.agents)
            self.agentState.currentAgent = agent
            return agent
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func agentGet(agentId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.agentGet(agentId: agentId)
            guard let agent = Self.parseAgentModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse agent.get response")
            }
            self.agentState.currentAgent = agent
            return agent
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    // F-R4: onAppear fetch 风暴去重。快切 View 触发多次同参 fetchAgents, 后端 N 次重算。
    // 同 tags key 已有 in-flight fetch 时直接 await 复用结果, 不发新 RPC。
    private static var agentFetchInFlight: [String: Task<[AgentModel], Error>] = [:]
    private static let agentFetchLock = NSLock()

    func fetchAgents(tags: [String] = []) async throws -> [AgentModel] {
        let key = tags.sorted().joined(separator: ",")
        // 复用 in-flight 同 key Task
        Self.agentFetchLock.lock()
        if let existing = Self.agentFetchInFlight[key] {
            Self.agentFetchLock.unlock()
            agentOpsLog.info("fetchAgents: dedup reuse in-flight key=\(key)")
            return try await existing.value
        }
        let task = Task<[AgentModel], Error> { [weak self] in
            guard let self = self else { throw BridgeError.notConnected }
            defer {
                Self.agentFetchLock.lock()
                Self.agentFetchInFlight.removeValue(forKey: key)
                Self.agentFetchLock.unlock()
            }
            guard let client = self.ipcClient else { throw BridgeError.notConnected }
            let result = try await client.agentList(tags: tags)
            let agentsData = result["self.agentState.agents"] as? [[String: Any]] ?? []
            var parsed: [AgentModel] = []
            for a in agentsData {
                if let agent = Self.parseAgentModel(from: a) {
                    parsed.append(agent)
                }
            }
            self.agentState.agents = parsed
            agentOpsLog.info("fetchAgents: received \(parsed.count) self.agentState.agents")
            return parsed
        }
        Self.agentFetchInFlight[key] = task
        Self.agentFetchLock.unlock()
        do {
            return try await task.value
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func agentUpdate(agentId: String, name: String? = nil, model: String? = nil, systemPrompt: String? = nil, temperature: Double? = nil, maxTokens: Int? = nil, tools: [String]? = nil, capabilities: [String]? = nil, safetyLevel: String? = nil, tags: [String]? = nil, description: String? = nil) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentUpdate: id=\(agentId)")
        do {
            let result = try await client.agentUpdate(agentId: agentId, name: name, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags, description: description)
            guard let agent = Self.parseAgentModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse agent.update response")
            }
            if let idx = self.agentState.agents.firstIndex(where: { $0.id == agentId }) {
                self.agentState.agents[idx] = agent
            }
            self.agentState.currentAgent = agent
            return agent
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func agentDelete(agentId: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentDelete: id=\(agentId)")
        do {
            let result = try await client.agentDelete(agentId: agentId)
            let deleted = result["deleted"] as? Bool ?? false
            if deleted {
                self.agentState.agents.removeAll { $0.id == agentId }
                if self.agentState.currentAgent?.id == agentId {
                    self.agentState.currentAgent = nil
                }
                // PERF-3: 删 agent 时清 self.agentState.agentVersionHistory 该 agent 条目, 否则已删 agent 版本历史孤儿驻留 dict 永不释放。
                self.agentState.agentVersionHistory.removeValue(forKey: agentId)
            }
            return deleted
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    // MARK: - Agent Lifecycle

    func agentPublish(agentId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentPublish: id=\(agentId)")
        let result = try await client.agentPublish(agentId: agentId)
        guard let updated = Self.parseAgentModel(from: result) else {
            throw BridgeError.ipcError("Invalid publish response")
        }
        if let idx = self.agentState.agents.firstIndex(where: { $0.id == agentId }) {
            self.agentState.agents[idx] = updated
        }
        return updated
    }

    func agentArchive(agentId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentArchive: id=\(agentId)")
        let result = try await client.agentArchive(agentId: agentId)
        guard let updated = Self.parseAgentModel(from: result) else {
            throw BridgeError.ipcError("Invalid archive response")
        }
        if let idx = self.agentState.agents.firstIndex(where: { $0.id == agentId }) {
            self.agentState.agents[idx] = updated
        }
        return updated
    }

    func agentUnpublish(agentId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentUnpublish: id=\(agentId)")
        let result = try await client.agentUnpublish(agentId: agentId)
        guard let status = result["status"] as? String, status == "draft" else {
            let msg = (result["message"] as? String) ?? "unpublish failed"
            throw BridgeError.ipcError(msg)
        }
        let updated = try await agentGet(agentId: agentId)
        if let idx = self.agentState.agents.firstIndex(where: { $0.id == agentId }) {
            self.agentState.agents[idx] = updated
        }
        return updated
    }

    func agentClone(agentId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentClone: id=\(agentId)")
        let result = try await client.agentClone(agentId: agentId)
        guard let cloned = Self.parseAgentModel(from: result) else {
            throw BridgeError.ipcError("Invalid clone response")
        }
        self.agentState.agents.append(cloned)
        Self.capAgents(&self.agentState.agents)
        return cloned
    }

    func agentSnapshot(agentId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentSnapshot: id=\(agentId)")
        let result = try await client.call(method: RPCMethod.agentStudioAgentSnapshot, params: ["agent_id": agentId])
        try await fetchAgents()
        return result
    }

    func agentVersions(agentId: String) async throws -> [[String: Any]] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentVersions: id=\(agentId)")
        let result = try await client.call(method: RPCMethod.agentStudioAgentVersions, params: ["agent_id": agentId])
        guard let versions = result as? [[String: Any]] else {
            let items = result["versions"] as? [[String: Any]] ?? []
            self.agentState.agentVersionHistory[agentId] = items
            return items
        }
        self.agentState.agentVersionHistory[agentId] = versions
        return versions
    }

    func agentRestoreVersion(agentId: String, versionId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentRestoreVersion: id=\(agentId) version=\(versionId)")
        let result = try await client.call(method: RPCMethod.agentStudioAgentRestoreVersion, params: ["agent_id": agentId, "version_id": versionId])
        guard let restored = Self.parseAgentModel(from: result) else {
            throw BridgeError.ipcError("Invalid restore response")
        }
        try await fetchAgents()
        return restored
    }

    func fetchDashboard() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.dashboardOverview()
            self.agentState.dashboardData = result
            agentOpsLog.info("Dashboard fetched: \(result.keys.joined(separator: ","))")
        } catch {
            agentOpsLog.debug("Dashboard fetch failed: \(error.localizedDescription)")
        }
    }

    func fetchAuditTrail(agentId: String? = nil, startDate: String? = nil, endDate: String? = nil) async {
        guard let client = ipcClient else { return }
        do {
            var params: [String: Any] = [:]
            if let aid = agentId { params["agent_id"] = aid }
            if let s = startDate { params["start_date"] = s }
            if let e = endDate { params["end_date"] = e }
            let result = try await client.call(method: RPCMethod.agentStudioAuditTrail, params: params)
            let items = result["entries"] as? [[String: Any]] ?? (result as? [[String: Any]] ?? [])
            // F-A2: self.agentState.auditTrail 全量 fetch 无 cap, 服务端返海量条目时内存暴涨。保留最近 500 (LRU)。
            self.agentState.auditTrail = Array(items.suffix(500))
            agentOpsLog.info("Audit trail fetched: \(items.count) entries (capped to 500)")
        } catch {
            agentOpsLog.debug("Audit trail fetch failed: \(error.localizedDescription)")
        }
    }

    func fetchSessionLogs(agentId: String? = nil, startDate: String? = nil, endDate: String? = nil) async {
        guard let client = ipcClient else { return }
        do {
            var params: [String: Any] = [:]
            if let aid = agentId { params["agent_id"] = aid }
            if let s = startDate { params["start_date"] = s }
            if let e = endDate { params["end_date"] = e }
            let result = try await client.call(method: RPCMethod.agentStudioSessionLogs, params: params)
            let items = result["sessions"] as? [[String: Any]] ?? (result as? [[String: Any]] ?? [])
            // F-A2: self.agentState.sessionLogs 全量 fetch 无 cap, 服务端返海量条目时内存暴涨。保留最近 500 (LRU)。
            self.agentState.sessionLogs = Array(items.suffix(500))
            agentOpsLog.info("Session logs fetched: \(items.count) entries (capped to 500)")
        } catch {
            agentOpsLog.debug("Session logs fetch failed: \(error.localizedDescription)")
        }
    }

    func chatStream(agentId: String, message: String, sessionId: String? = nil, onToken: @escaping (String) -> Void) async throws -> String {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("chatStream: agent=\(agentId)")
        var params: [String: Any] = [
            "agent_id": agentId,
            "message": message,
        ]
        if let sid = sessionId { params["session_id"] = sid }

        self.agentState.activeSessionId = sessionId ?? ""
        self.agentState.isAgentStreaming = true
        self.agentState.streamingContent = ""
        self.agentState.lastToolCalls = []
        defer { self.agentState.isAgentStreaming = false }

        do {
            let result = try await client.call(method: RPCMethod.agentStudioAgentChat, params: params)
            let content = result["content"] as? String ?? ""
            let toolCalls = result["tool_calls"] as? [[String: Any]] ?? []
            let sid = result["session_id"] as? String ?? self.agentState.activeSessionId
            self.agentState.activeSessionId = sid
            self.agentState.lastToolCalls = toolCalls
            self.agentState.streamingContent = content
            onToken(content)
            return content
        } catch {
            self.agentState.isAgentStreaming = false
            // F-I10: 裸抛原始 error 含 IPC 路径/方法名, UI 直展示无意义且泄细节。转 BridgeError 走 userMessage 脱敏。
            let bridgeErr = (error as? BridgeError) ?? BridgeError.ipcError(error.localizedDescription)
            agentOpsLog.error("agentChat failed: \(error.localizedDescription, privacy: .public)")
            throw bridgeErr
        }
    }

    func agentConfigure(agentId: String, config: [String: Any]) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentConfigure: id=\(agentId)")
        do {
            let result = try await client.agentConfigure(agentId: agentId, config: config)
            guard let agent = Self.parseAgentModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse agent.configure response")
            }
            if let idx = self.agentState.agents.firstIndex(where: { $0.id == agentId }) {
                self.agentState.agents[idx] = agent
            }
            self.agentState.currentAgent = agent
            return agent
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func agentExecute(agentId: String, input: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentExecute: id=\(agentId)")
        do {
            return try await client.agentExecute(agentId: agentId, input: input)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchAgentSkills(agentId: String) async throws -> [String] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.agentListSkills(agentId: agentId)
            let skills = result["skills"] as? [String] ?? []
            // ARCH-2: 仅当仍是当前选中 agent 时才回写 @Published。
            // 切 agent 后旧 fetch 的回调若仍写 self.agentState.agentSkills = skills -> 跨 agent 残留串台。
            if self.agentState.currentAgent?.id == agentId {
                self.agentState.agentSkills = skills
            } else {
                agentOpsLog.info("fetchAgentSkills: agent 已切换, 丢弃过期 skills agentId=\(agentId) current=\(self.agentState.currentAgent?.id ?? "nil")")
            }
            return skills
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func agentAddSkill(agentId: String, skillName: String, skillDef: [String: Any] = [:]) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentAddSkill: id=\(agentId) skill=\(skillName)")
        do {
            let result = try await client.agentAddSkill(agentId: agentId, skillName: skillName, skillDef: skillDef)
            let added = result["added"] as? Bool ?? true
            if added && self.agentState.currentAgent?.id == agentId {
                if !self.agentState.agentSkills.contains(skillName) {
                    self.agentState.agentSkills.append(skillName)
                    // F-R13: self.agentState.agentSkills 无界 append, cap 100 (LRU), 超额丢弃最旧。
                    if self.agentState.agentSkills.count > 100 {
                        self.agentState.agentSkills.removeFirst(self.agentState.agentSkills.count - 100)
                    }
                }
            }
            return added
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func agentDeleteSkill(agentId: String, skillName: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentDeleteSkill: id=\(agentId) skill=\(skillName)")
        do {
            let result = try await client.agentDeleteSkill(agentId: agentId, skillName: skillName)
            let deleted = result["deleted"] as? Bool ?? false
            if deleted && self.agentState.currentAgent?.id == agentId {
                self.agentState.agentSkills.removeAll { $0 == skillName }
            }
            return deleted
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchAgentSoul(agentId: String) async throws -> String {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.agentGetSoul(agentId: agentId)
            let soul = result["soul"] as? String ?? ""
            // ARCH-2: 仅当仍是当前选中 agent 时才回写 @Published。
            // 切 agent 后旧 fetch 的回调若仍写 self.agentState.agentSoul = soul -> 跨 agent 残留串台。
            if self.agentState.currentAgent?.id == agentId {
                self.agentState.agentSoul = soul
            } else {
                agentOpsLog.info("fetchAgentSoul: agent 已切换, 丢弃过期 soul agentId=\(agentId) current=\(self.agentState.currentAgent?.id ?? "nil")")
            }
            return soul
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func agentUpdateSoul(agentId: String, soul: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("agentUpdateSoul: id=\(agentId)")
        do {
            let result = try await client.agentUpdateSoul(agentId: agentId, soul: soul)
            let updated = result["updated"] as? Bool ?? true
            if updated && self.agentState.currentAgent?.id == agentId {
                self.agentState.agentSoul = soul
            }
            return updated
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    // MARK: - Marketplace Install (cross-domain: 依赖 parseAgentModel, 随 Agent 域同迁)

    func marketplaceInstall(entryId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentOpsLog.info("marketplaceInstall: entryId=\(entryId)")
        do {
            let result = try await client.marketplaceInstall(entryId: entryId)
            guard let agent = Self.parseAgentModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse marketplace.install response")
            }
            self.agentState.agents.append(agent)
            Self.capAgents(&self.agentState.agents)
            return agent
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    // MARK: - Agent Parsing

    private static func parseAgentModel(from dict: [String: Any]) -> AgentModel? {
        guard let agentId = dict["agent_id"] as? String ?? dict["id"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }
        let manifest = dict["manifest"] as? [String: Any] ?? dict
        return AgentModel(
            id: agentId,
            name: name,
            model: manifest["model"] as? String ?? dict["model"] as? String ?? "",
            system_prompt: manifest["system_prompt"] as? String ?? dict["system_prompt"] as? String ?? "",
            temperature: manifest["temperature"] as? Double ?? dict["temperature"] as? Double ?? 0.7,
            max_tokens: manifest["max_tokens"] as? Int ?? dict["max_tokens"] as? Int ?? 4096,
            tools: manifest["tools"] as? [String] ?? dict["tools"] as? [String] ?? [],
            capabilities: manifest["capabilities"] as? [String] ?? dict["capabilities"] as? [String] ?? [],
            safety_level: manifest["safety_level"] as? String ?? dict["safety_level"] as? String ?? "L1",
            tags: manifest["tags"] as? [String] ?? dict["tags"] as? [String] ?? [],
            author: manifest["author"] as? String ?? dict["author"] as? String ?? "",
            description: manifest["description"] as? String ?? dict["description"] as? String ?? "",
            version: manifest["version"] as? String ?? dict["version"] as? String ?? "1.0.0",
            created_at: manifest["created_at"] as? String ?? dict["created_at"] as? String ?? "",
            skills: dict["skills"] as? [String] ?? [],
            has_soul: dict["has_soul"] as? Bool ?? false,
            status: dict["status"] as? String,
            version_int: dict["version_int"] as? Int,
            published_at: dict["published_at"] as? String,
            knowledge_base_ids: dict["knowledge_base_ids"] as? [String],
            visibility: dict["visibility"] as? String,
            rag_strategy: dict["rag_strategy"] as? String,
            web_search_enabled: dict["web_search_enabled"] as? Bool,
            deep_research_enabled: dict["deep_research_enabled"] as? Bool,
            connector_ids: dict["connector_ids"] as? [String],
            style: dict["style"] as? String,
            top_p: dict["top_p"] as? Double,
            context_window: dict["context_window"] as? Int,
            rate_limit_qps: dict["rate_limit_qps"] as? Int
        )
    }

    // F-A2: self.agentState.agents 无界 append, 连续 create/clone/install 不 fetch 时单调增长。保留最近 200 (LRU),
    // 超额丢弃最旧。PERF-3 ragResults 范式。
    static func capAgents(_ arr: inout [AgentModel]) {
        let cap = 200
        if arr.count > cap {
            let dropped = arr.count - cap
            arr.removeFirst(dropped)
            agentOpsLog.info("capAgents: trimmed to \(cap) (dropped \(dropped))")
        }
    }
}
