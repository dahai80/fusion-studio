import Foundation
import os.log

extension IPCClient {
    // MARK: - Agent CRUD

    func agentCreate(name: String, id: String = "", model: String = "", systemPrompt: String = "", temperature: Double = 0.7, maxTokens: Int = 4096, tools: [String] = [], capabilities: [String] = [], safetyLevel: String = "L1", tags: [String] = [], description: String = "", author: String = "", status: String = "draft", versionInt: Int = 1, publishedAt: String? = nil, knowledgeBaseIds: [String] = [], visibility: String = "private", ragStrategy: String = "hybrid", webSearchEnabled: Bool = false, deepResearchEnabled: Bool = false, connectorIds: [String] = [], style: String = "", topP: Double = 1.0, contextWindow: Int = 32768, rateLimitQps: Int = 0, soul: String = "", memory: String = "", agentsMd: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["name": name, "model": model, "system_prompt": systemPrompt, "temperature": temperature, "max_tokens": maxTokens, "tools": tools, "capabilities": capabilities, "safety_level": safetyLevel, "tags": tags, "description": description, "author": author, "status": status, "version_int": versionInt, "knowledge_base_ids": knowledgeBaseIds, "visibility": visibility, "rag_strategy": ragStrategy, "web_search_enabled": webSearchEnabled, "deep_research_enabled": deepResearchEnabled, "connector_ids": connectorIds, "style": style, "top_p": topP, "context_window": contextWindow, "rate_limit_qps": rateLimitQps]
        if !id.isEmpty { params["id"] = id }
        if let v = publishedAt { params["published_at"] = v }
        if !soul.isEmpty { params["soul"] = soul }
        if !memory.isEmpty { params["memory"] = memory }
        if !agentsMd.isEmpty { params["agents_md"] = agentsMd }
        return try await call(method: "agent.create", params: params)
    }

    func agentGet(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.get", params: ["agent_id": agentId])
    }

    func agentList(tags: [String] = [], capabilities: [String] = [], usableInProject: Bool = false, hasRagSupport: Bool = false) async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if !tags.isEmpty { params["tags"] = tags }
        if !capabilities.isEmpty { params["capabilities"] = capabilities }
        if usableInProject { params["usableInProject"] = true }
        if hasRagSupport { params["hasRagSupport"] = true }
        return try await call(method: "agent.list", params: params)
    }

    func agentUpdate(agentId: String, name: String? = nil, model: String? = nil, systemPrompt: String? = nil, temperature: Double? = nil, maxTokens: Int? = nil, tools: [String]? = nil, capabilities: [String]? = nil, safetyLevel: String? = nil, tags: [String]? = nil, description: String? = nil, author: String? = nil, version: String? = nil, status: String? = nil, versionInt: Int? = nil, publishedAt: String? = nil, knowledgeBaseIds: [String]? = nil, visibility: String? = nil, ragStrategy: String? = nil, webSearchEnabled: Bool? = nil, deepResearchEnabled: Bool? = nil, connectorIds: [String]? = nil, style: String? = nil, topP: Double? = nil, contextWindow: Int? = nil, rateLimitQps: Int? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["agent_id": agentId]
        if let v = name { params["name"] = v }
        if let v = model { params["model"] = v }
        if let v = systemPrompt { params["system_prompt"] = v }
        if let v = temperature { params["temperature"] = v }
        if let v = maxTokens { params["max_tokens"] = v }
        if let v = tools { params["tools"] = v }
        if let v = capabilities { params["capabilities"] = v }
        if let v = safetyLevel { params["safety_level"] = v }
        if let v = tags { params["tags"] = v }
        if let v = description { params["description"] = v }
        if let v = author { params["author"] = v }
        if let v = version { params["version"] = v }
        if let v = status { params["status"] = v }
        if let v = versionInt { params["version_int"] = v }
        if let v = publishedAt { params["published_at"] = v }
        if let v = knowledgeBaseIds { params["knowledge_base_ids"] = v }
        if let v = visibility { params["visibility"] = v }
        if let v = ragStrategy { params["rag_strategy"] = v }
        if let v = webSearchEnabled { params["web_search_enabled"] = v }
        if let v = deepResearchEnabled { params["deep_research_enabled"] = v }
        if let v = connectorIds { params["connector_ids"] = v }
        if let v = style { params["style"] = v }
        if let v = topP { params["top_p"] = v }
        if let v = contextWindow { params["context_window"] = v }
        if let v = rateLimitQps { params["rate_limit_qps"] = v }
        return try await call(method: "agent.update", params: params)
    }

    func agentDelete(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.delete", params: ["agent_id": agentId])
    }

    func agentConfigure(agentId: String, config: [String: Any]) async throws -> [String: Any] {
        return try await call(method: "agent.configure", params: ["agent_id": agentId, "config": config])
    }

    func agentExecute(agentId: String, input: String) async throws -> [String: Any] {
        return try await call(method: "agent.execute", params: ["agent_id": agentId, "input": input])
    }

    func agentListSkills(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.list_skills", params: ["agent_id": agentId])
    }

    func agentAddSkill(agentId: String, skillName: String, skillDef: [String: Any] = [:]) async throws -> [String: Any] {
        return try await call(method: "agent.add_skill", params: ["agent_id": agentId, "skill_name": skillName, "skill_def": skillDef])
    }

    func agentDeleteSkill(agentId: String, skillName: String) async throws -> [String: Any] {
        return try await call(method: "agent.delete_skill", params: ["agent_id": agentId, "skill_name": skillName])
    }

    func agentGetSoul(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.get_soul", params: ["agent_id": agentId])
    }

    func agentUpdateSoul(agentId: String, soul: String) async throws -> [String: Any] {
        return try await call(method: "agent.update_soul", params: ["agent_id": agentId, "soul": soul])
    }

    // MARK: - Agent Lifecycle

    func agentPublish(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.publish", params: ["agent_id": agentId])
    }

    func agentArchive(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.archive", params: ["agent_id": agentId])
    }

    func agentHistory(agentId: String, limit: Int = 20) async throws -> [String: Any] {
        return try await call(method: "agent.history", params: ["agent_id": agentId, "limit": limit])
    }

    func agentCoworkList(spaceId: String) async throws -> [String: Any] {
        return try await call(method: "agent.cowork.list", params: ["space_id": spaceId])
    }

    func agentCoworkAdd(spaceId: String, agentId: String, role: String = "member", permission: String = "all_member") async throws -> [String: Any] {
        return try await call(method: "agent.cowork.add", params: [
            "space_id": spaceId, "agent_id": agentId, "role": role, "permission": permission,
        ])
    }

    func agentCoworkRemove(spaceId: String, agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.cowork.remove", params: ["space_id": spaceId, "agent_id": agentId])
    }

    func agentCoworkCall(spaceId: String, agentId: String, callerId: String = "", message: String) async throws -> [String: Any] {
        var params: [String: Any] = ["space_id": spaceId, "agent_id": agentId, "message": message]
        if !callerId.isEmpty { params["caller_id"] = callerId }
        return try await call(method: "agent.cowork.call", params: params)
    }

    func agentCoworkStatus(spaceId: String, agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.cowork.status", params: ["space_id": spaceId, "agent_id": agentId])
    }

    func agentClone(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.clone", params: ["agent_id": agentId])
    }

    func agentGetApiEndpoint(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.get_api_endpoint", params: ["agent_id": agentId])
    }

    func agentExecuteStream(agentId: String, input: String) async throws -> [String: Any] {
        let params: [String: Any] = ["agent_id": agentId, "input": input]
        return try await call(method: "agent.execute_stream", params: params)
    }

    // MARK: - Model Load Status (#46)

    func modelLoadStatus() async throws -> [String: Any] {
        return try await call(method: "model.status", params: [:])
    }

    // MARK: - Knowledge Base Build (#49)

    func kbBuild(path: String, scope: String = "default") async throws -> [String: Any] {
        return try await call(method: "kb.build", params: ["path": path, "scope": scope])
    }

    func kbStatus(kbId: String = "") async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if !kbId.isEmpty { params["kb_id"] = kbId }
        return try await call(method: "kb.status", params: params)
    }

    func kbQuery(query: String, kbId: String = "", limit: Int = 5) async throws -> [String: Any] {
        var params: [String: Any] = ["query": query, "limit": limit]
        if !kbId.isEmpty { params["kb_id"] = kbId }
        return try await call(method: "kb.query", params: params)
    }

    // MARK: - Audit Log (#51)

    func auditList(tool: String = "", targetType: String = "", since: String = "", limit: Int = 100) async throws -> [String: Any] {
        var params: [String: Any] = ["limit": limit]
        if !tool.isEmpty { params["tool"] = tool }
        if !targetType.isEmpty { params["target_type"] = targetType }
        if !since.isEmpty { params["since"] = since }
        return try await call(method: "audit.list", params: params)
    }

    // MARK: - Offline Mode (#52)

    func offlineCheck() async throws -> [String: Any] {
        return try await call(method: "system.offline_status", params: [:])
    }

    func offlineSet(enabled: Bool) async throws -> [String: Any] {
        return try await call(method: "system.set_offline", params: ["enabled": enabled])
    }

    // MARK: - Diff Review Export (#48)

    func diffReviewExport(agentId: String, format: String = "markdown") async throws -> [String: Any] {
        return try await call(method: "agent.diff_review", params: ["agent_id": agentId, "format": format])
    }

    // MARK: - Permission Tags (#47)

    func permissionList(agentId: String = "") async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if !agentId.isEmpty { params["agent_id"] = agentId }
        return try await call(method: "permission.list", params: params)
    }

    func permissionUpdate(agentId: String, tool: String, level: String) async throws -> [String: Any] {
        return try await call(method: "permission.update", params: ["agent_id": agentId, "tool": tool, "level": level])
    }

    // MARK: - Marketplace

    func marketplaceSearch(query: String = "", category: String = "", tags: [String]? = nil, sortBy: String = "name", limit: Int = 50) async throws -> [String: Any] {
        var params: [String: Any] = ["query": query, "category": category, "sort_by": sortBy, "limit": limit]
        if let t = tags { params["tags"] = t }
        return try await call(method: "marketplace.search", params: params)
    }

    func marketplaceGet(entryId: String) async throws -> [String: Any] {
        return try await call(method: "marketplace.get", params: ["entry_id": entryId])
    }

    func marketplacePublish(name: String, author: String = "", description: String = "", category: String = "", tags: [String] = [], version: String = "1.0.0", graphData: [String: Any] = [:]) async throws -> [String: Any] {
        return try await call(method: "marketplace.publish", params: ["name": name, "author": author, "description": description, "category": category, "tags": tags, "version": version, "graph_data": graphData])
    }

    func marketplaceUnpublish(entryId: String) async throws -> [String: Any] {
        return try await call(method: "marketplace.unpublish", params: ["entry_id": entryId])
    }

    func marketplaceListCategories() async throws -> [String: Any] {
        return try await call(method: "marketplace.list_categories")
    }

    func marketplaceInstall(entryId: String, targetDir: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["entry_id": entryId]
        if !targetDir.isEmpty { params["target_dir"] = targetDir }
        return try await call(method: "marketplace.install", params: params)
    }

}
