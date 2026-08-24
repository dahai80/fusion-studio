import Foundation
import os.log

extension IPCClient {
    // MARK: - MLX Extended

    func restartMLX(model: String = "") async throws -> [String: Any] {
        return try await call(method: "mlx.restart", params: ["model": model])
    }

    func mlxHealth() async throws -> [String: Any] {
        return try await call(method: "mlx.health")
    }

    func mlxSetModel(model: String) async throws -> [String: Any] {
        return try await call(method: "mlx.set_model", params: ["model": model])
    }

    // MARK: - Graph Extended

    func graphGet(graphId: String) async throws -> [String: Any] {
        return try await call(method: "graph.get", params: ["graph_id": graphId])
    }

    // MARK: - Knowledge

    func knowledgeSearch(query: String, limit: Int = 5) async throws -> [String: Any] {
        return try await call(method: "knowledge.search", params: ["query": query, "limit": limit])
    }

    // Callers: FusionProjectManager. Affected API: knowledge.ingest (new).
    // Data schemas: KnowledgeEntry (content, scope, metadata). User instruction: "立即落地fusion projects"
    func knowledgeIngest(content: String, scope: String = "default", metadata: [String: Any]? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["content": content, "scope": scope]
        if let m = metadata { params["metadata"] = m }
        return try await call(method: "knowledge.ingest", params: params)
    }

    // Callers: FusionProjectManager. Affected API: knowledge.delete (new).
    // Data schemas: entry_id string. User instruction: "立即落地fusion projects"
    func knowledgeDelete(entryId: String) async throws -> [String: Any] {
        return try await call(method: "knowledge.delete", params: ["entry_id": entryId])
    }

    // Callers: FusionProjectManager. Affected API: knowledge.list (new).
    // Data schemas: scope string, limit int. User instruction: "立即落地fusion projects"
    func knowledgeList(scope: String = "", limit: Int = 100) async throws -> [String: Any] {
        return try await call(method: "knowledge.list", params: ["scope": scope, "limit": limit])
    }

    func knowledgeCount(scope: String = "") async throws -> [String: Any] {
        return try await call(method: "knowledge.count", params: ["scope": scope])
    }

    // MARK: - Planner

    func plannerCreatePlan(task: String, context: String = "", files: [String]? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["task": task, "context": context]
        if let f = files { params["files"] = f }
        return try await call(method: "planner.create_plan", params: params)
    }

    func plannerGetPlan(planId: String) async throws -> [String: Any] {
        return try await call(method: "planner.get_plan", params: ["plan_id": planId])
    }

    func plannerApprovePlan(planId: String) async throws -> [String: Any] {
        return try await call(method: "planner.approve_plan", params: ["plan_id": planId])
    }

    func plannerRejectPlan(planId: String, reason: String = "") async throws -> [String: Any] {
        return try await call(method: "planner.reject_plan", params: ["plan_id": planId, "reason": reason])
    }

    func plannerExecuteStep(planId: String, stepId: String) async throws -> [String: Any] {
        return try await call(method: "planner.execute_step", params: ["plan_id": planId, "step_id": stepId])
    }

    func plannerExecutePlan(planId: String) async throws -> [String: Any] {
        return try await call(method: "planner.execute_plan", params: ["plan_id": planId])
    }

    func plannerListPlans(status: String = "") async throws -> [String: Any] {
        return try await call(method: "planner.list_plans", params: ["status": status])
    }

    func plannerCancelPlan(planId: String) async throws -> [String: Any] {
        return try await call(method: "planner.cancel_plan", params: ["plan_id": planId])
    }

    // MARK: - RAG

    func ragQuery(query: String, config: [String: Any] = [:], model: String = "", systemPrompt: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["query": query]
        if !config.isEmpty { params["config"] = config }
        if !model.isEmpty { params["model"] = model }
        if !systemPrompt.isEmpty { params["system_prompt"] = systemPrompt }
        return try await call(method: "rag.query", params: params)
    }

    func ragRetrieve(query: String, config: [String: Any] = [:]) async throws -> [String: Any] {
        var params: [String: Any] = ["query": query]
        if !config.isEmpty { params["config"] = config }
        return try await call(method: "rag.retrieve", params: params)
    }

    // MARK: - Memory

    func memoryStore(content: String, scope: String = "default", tags: String = "", importance: Int = 5, metadata: [String: Any]? = nil, tier: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["content": content, "scope": scope, "tags": tags, "importance": importance]
        if let m = metadata { params["metadata"] = m }
        if !tier.isEmpty { params["tier"] = tier }
        return try await call(method: "memory.store", params: params)
    }

    func memoryRecall(query: String, scope: String = "", limit: Int = 10, minImportance: Int = 0, tier: String = "") async throws -> [String: Any] {
        return try await call(method: "memory.recall", params: ["query": query, "scope": scope, "limit": limit, "min_importance": minImportance, "tier": tier])
    }

    func memoryListRecent(scope: String = "", limit: Int = 20, minImportance: Int = 0, tier: String = "") async throws -> [String: Any] {
        return try await call(method: "memory.list_recent", params: ["scope": scope, "limit": limit, "min_importance": minImportance, "tier": tier])
    }

    func memoryGet(entryId: String) async throws -> [String: Any] {
        return try await call(method: "memory.get", params: ["entry_id": entryId])
    }

    func memoryDelete(entryId: String) async throws -> [String: Any] {
        return try await call(method: "memory.delete", params: ["entry_id": entryId])
    }

    func memoryDeleteScope(scope: String) async throws -> [String: Any] {
        return try await call(method: "memory.delete_scope", params: ["scope": scope])
    }

    func memoryCount(scope: String = "", tier: String = "") async throws -> [String: Any] {
        return try await call(method: "memory.count", params: ["scope": scope, "tier": tier])
    }

    // MARK: - Safety

    func safetyCheck(content: String, context: String = "") async throws -> [String: Any] {
        return try await call(method: "safety.check", params: ["content": content, "context": context])
    }

    func safetyEvaluateAction(category: String, content: String = "", context: String = "") async throws -> [String: Any] {
        return try await call(method: "safety.evaluate_action", params: ["category": category, "content": content, "context": context])
    }

    func safetyApproveAction(actionId: String) async throws -> [String: Any] {
        return try await call(method: "safety.approve_action", params: ["action_id": actionId])
    }

    func safetyRejectAction(actionId: String) async throws -> [String: Any] {
        return try await call(method: "safety.reject_action", params: ["action_id": actionId])
    }

    func safetyGetPendingActions() async throws -> [String: Any] {
        return try await call(method: "safety.get_pending_actions")
    }

    func safetyAddPolicy(category: String, description: String = "", defaultLevel: String = "L2", requiresDiff: Bool = false) async throws -> [String: Any] {
        return try await call(method: "safety.add_policy", params: ["category": category, "description": description, "default_level": defaultLevel, "requires_diff": requiresDiff])
    }

    // MARK: - Template

    func templateList(category: String = "") async throws -> [String: Any] {
        return try await call(method: "template.list", params: ["category": category])
    }

    func templateGet(templateId: String) async throws -> [String: Any] {
        return try await call(method: "template.get", params: ["template_id": templateId])
    }

    func templateInstantiate(templateId: String, variables: [String: String]? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["template_id": templateId]
        if let v = variables { params["variables"] = v }
        return try await call(method: "template.instantiate", params: params)
    }

    // MARK: - Deploy

    func deployExport(graphId: String, format: String = "json", filepath: String = "", withServer: Bool = true, port: Int = 8000) async throws -> [String: Any] {
        var params: [String: Any] = ["graph_id": graphId, "format": format]
        if !filepath.isEmpty { params["filepath"] = filepath }
        params["with_server"] = withServer
        params["port"] = port
        return try await call(method: "deploy.export", params: params)
    }

    func deployImport(filepath: String) async throws -> [String: Any] {
        return try await call(method: "deploy.import", params: ["filepath": filepath])
    }

    func deployListFormats() async throws -> [String: Any] {
        return try await call(method: "deploy.list_formats")
    }

}
