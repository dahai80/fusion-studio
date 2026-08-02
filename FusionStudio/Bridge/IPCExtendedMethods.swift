import Foundation
import os.log

extension IPCClient {
    // MARK: - Agent Studio: Skill Execute + Research Adaptive

    func skillExecute(agentId: String, skillName: String, input: String, tools: [String] = []) async throws -> [String: Any] {
        var params: [String: Any] = [
            "agent_id": agentId,
            "skill_name": skillName,
            "input": input,
        ]
        if !tools.isEmpty { params["tools"] = tools }
        return try await call(method: "skill.execute", params: params)
    }

    func researchAdaptive(question: String, maxSteps: Int = 10, webSearch: Bool = true) async throws -> [String: Any] {
        let params: [String: Any] = [
            "question": question,
            "max_steps": maxSteps,
            "web_search": webSearch,
        ]
        return try await call(method: "research.adaptive", params: params)
    }

    // Callers: UnifiedChatView, ChatSessionStore, RAGPipelineView, ToolBrowserView, MemoryView, SafetyView, VerificationView, TokenBudgetView. Affected APIs: chat.get/switch_branch/branches/message_tree, rag.vector_search, verify.verify, budget.set/status, safety.approve/reject, tool.list/get/dynamic_register/dynamic_unregister, memory.recall_relevant/auto_forget, session.list, graph.update. Data schemas: all return [String: Any] JSON-RPC results matching daemon_server.py handler signatures. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"

    // MARK: - Chat Extended

    func chatGet(sessionId: String) async throws -> [String: Any] {
        return try await call(method: "chat.get", params: ["session_id": sessionId])
    }

    func chatSwitchBranch(sessionId: String, branchId: String) async throws -> [String: Any] {
        return try await call(method: "chat.switch_branch", params: ["session_id": sessionId, "branch_id": branchId])
    }

    func chatBranches(sessionId: String, messageId: String) async throws -> [String: Any] {
        return try await call(method: "chat.branches", params: ["session_id": sessionId, "message_id": messageId])
    }

    func chatMessageTree(sessionId: String) async throws -> [String: Any] {
        return try await call(method: "chat.message_tree", params: ["session_id": sessionId])
    }

    // MARK: - RAG Extended

    func ragVectorSearch(query: String, limit: Int = 10, threshold: Double = 0.5) async throws -> [String: Any] {
        return try await call(method: "rag.vector_search", params: ["query": query, "limit": limit, "threshold": threshold])
    }

    private var ragHTTPBase: String { "http://\(FusionConfig.shared.fusionRagHost):\(FusionConfig.shared.fusionRagPort)" }

    func ragWatch(kbId: String, filePaths: [String], pollInterval: Int = 30) async throws -> [String: Any] {
        let body: [String: Any] = ["file_paths": filePaths, "poll_interval": pollInterval]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: "\(ragHTTPBase)/kb/bases/\(kbId)/watch")!)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (responseData, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw IPCError.invalidResponse
        }
        ipcLog.info("ragWatch: kb=\(kbId) files=\(filePaths.count)")
        return json
    }

    func ragUnwatch(kbId: String, watchId: String) async throws -> [String: Any] {
        let body: [String: Any] = ["watch_id": watchId]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: "\(ragHTTPBase)/kb/bases/\(kbId)/unwatch")!)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (responseData, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw IPCError.invalidResponse
        }
        ipcLog.info("ragUnwatch: kb=\(kbId) watch=\(watchId)")
        return json
    }

    func ragWatchStatus(kbId: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "\(ragHTTPBase)/kb/bases/\(kbId)/watch/status")!)
        request.httpMethod = "GET"
        let (responseData, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw IPCError.invalidResponse
        }
        return json
    }

    // MARK: - Verify

    func verifyVerify(content: String, criteria: [String] = [], autoFix: Bool = false) async throws -> [String: Any] {
        var params: [String: Any] = ["content": content, "auto_fix": autoFix]
        if !criteria.isEmpty { params["criteria"] = criteria }
        return try await call(method: "verify.verify", params: params)
    }

    // MARK: - Dashboard

    func dashboardOverview() async throws -> [String: Any] {
        return try await call(method: "dashboard.overview")
    }

    // MARK: - Connector

    func connectorList() async throws -> [String: Any] {
        return try await call(method: "connector.list")
    }

    func connectorCreate(name: String, type: String, config: [String: Any]) async throws -> [String: Any] {
        return try await call(method: "connector.create", params: ["name": name, "type": type, "config": config])
    }

    func connectorGet(connectorId: String) async throws -> [String: Any] {
        return try await call(method: "connector.get", params: ["connector_id": connectorId])
    }

    func connectorUpdate(connectorId: String, config: [String: Any]) async throws -> [String: Any] {
        var params: [String: Any] = ["connector_id": connectorId]
        params.merge(config) { _, new in new }
        return try await call(method: "connector.update", params: params)
    }

    func connectorDelete(connectorId: String) async throws -> [String: Any] {
        return try await call(method: "connector.delete", params: ["connector_id": connectorId])
    }

    func connectorConnect(connectorId: String) async throws -> [String: Any] {
        return try await call(method: "connector.connect", params: ["connector_id": connectorId])
    }

    func connectorDisconnect(connectorId: String) async throws -> [String: Any] {
        return try await call(method: "connector.disconnect", params: ["connector_id": connectorId])
    }

    func connectorTest(connectorId: String) async throws -> [String: Any] {
        return try await call(method: "connector.test", params: ["connector_id": connectorId])
    }

    // MARK: - API Key

    func apikeyCreate(name: String, permissions: [String] = [], agentIds: [String] = [], ipWhitelist: [String] = [], expiresInDays: Int? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["name": name, "permissions": permissions, "agent_ids": agentIds, "ip_whitelist": ipWhitelist]
        if let days = expiresInDays { params["expires_in_days"] = days }
        return try await call(method: "apikey.create", params: params)
    }

    func apikeyList() async throws -> [String: Any] {
        return try await call(method: "apikey.list")
    }

    func apikeyRevoke(keyId: String) async throws -> [String: Any] {
        return try await call(method: "apikey.revoke", params: ["key_id": keyId])
    }

    func apikeyRotate(keyId: String) async throws -> [String: Any] {
        return try await call(method: "apikey.rotate", params: ["key_id": keyId])
    }

    func apikeyUpdate(keyId: String, permissions: [String]? = nil, agentIds: [String]? = nil, ipWhitelist: [String]? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["key_id": keyId]
        if let p = permissions { params["permissions"] = p }
        if let a = agentIds { params["agent_ids"] = a }
        if let i = ipWhitelist { params["ip_whitelist"] = i }
        return try await call(method: "apikey.update", params: params)
    }

    // MARK: - Style

    func styleList() async throws -> [String: Any] {
        return try await call(method: "style.list")
    }

    func styleGet(styleId: String) async throws -> [String: Any] {
        return try await call(method: "style.get", params: ["style_id": styleId])
    }

    func styleCreate(name: String, template: String, rules: [String: Any] = [:]) async throws -> [String: Any] {
        var params: [String: Any] = ["name": name, "template": template]
        if !rules.isEmpty { params["rules"] = rules }
        return try await call(method: "style.create", params: params)
    }

    func styleApply(agentId: String, styleId: String) async throws -> [String: Any] {
        return try await call(method: "style.apply", params: ["agent_id": agentId, "style_id": styleId])
    }

    func styleDelete(styleId: String) async throws -> [String: Any] {
        return try await call(method: "style.delete", params: ["style_id": styleId])
    }

    // MARK: - Analytics

    func analyticsAgentUsage(agentId: String? = nil, range: String = "week") async throws -> [String: Any] {
        var params: [String: Any] = ["range": range]
        if let aid = agentId { params["agent_id"] = aid }
        return try await call(method: "analytics.agent_usage", params: params)
    }

    // MARK: - Alert

    func alertList() async throws -> [String: Any] {
        return try await call(method: "alert.list")
    }

    func alertAcknowledge(alertId: String) async throws -> [String: Any] {
        return try await call(method: "alert.acknowledge", params: ["alert_id": alertId])
    }

    // MARK: - Budget

    func budgetSet(totalBudget: Int, warnPercent: Int = 80, hardLimit: Bool = true) async throws -> [String: Any] {
        return try await call(method: "budget.set", params: ["total_budget": totalBudget, "warn_percent": warnPercent, "hard_limit": hardLimit])
    }

    func budgetStatus() async throws -> [String: Any] {
        return try await call(method: "budget.status")
    }

    // MARK: - Safety Runtime

    func safetyApprove(actionId: String, reason: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["action_id": actionId]
        if !reason.isEmpty { params["reason"] = reason }
        return try await call(method: "safety.approve", params: params)
    }

    func safetyReject(actionId: String, reason: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["action_id": actionId]
        if !reason.isEmpty { params["reason"] = reason }
        return try await call(method: "safety.reject", params: params)
    }

    // MARK: - Tool Extended

    func toolList() async throws -> [String: Any] {
        return try await call(method: "tool.list")
    }

    func toolGet(name: String) async throws -> [String: Any] {
        return try await call(method: "tool.get", params: ["name": name])
    }

    func toolDynamicRegister(name: String, description: String, parameters: [String: Any], code: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["name": name, "description": description, "parameters": parameters]
        if !code.isEmpty { params["code"] = code }
        return try await call(method: "tool.dynamic_register", params: params)
    }

    func toolDynamicUnregister(name: String) async throws -> [String: Any] {
        return try await call(method: "tool.dynamic_unregister", params: ["name": name])
    }

    // MARK: - Memory Extended

    func memoryRecallRelevant(query: String, context: String = "", limit: Int = 10) async throws -> [String: Any] {
        var params: [String: Any] = ["query": query, "limit": limit]
        if !context.isEmpty { params["context"] = context }
        return try await call(method: "memory.recall_relevant", params: params)
    }

    func memoryAutoForget(maxAge: Int = 30, minImportance: Int = 3, dryRun: Bool = true) async throws -> [String: Any] {
        return try await call(method: "memory.auto_forget", params: ["max_age": maxAge, "min_importance": minImportance, "dry_run": dryRun])
    }

    // MARK: - Session

    func sessionList() async throws -> [String: Any] {
        return try await call(method: "session.list")
    }

    // MARK: - Graph Extended

    func graphUpdate(graphId: String, updates: [String: Any]) async throws -> [String: Any] {
        return try await call(method: "graph.update", params: ["graph_id": graphId, "updates": updates])
    }

    // Callers: DeskViewModel. Affected API: desk.* namespace (25 existing + 13 new methods).
    // Data schemas: All return [String: Any] JSON-RPC results matching desk_rpc.py handler signatures.
    // User instruction: "对功能和api进行全量分析检测，看是否都在fusion-studio都有对应的GUI，如果没有需要立即补充GUI"

    // MARK: - Desk (Fusion-Desk 自动化平台)

    func deskHealth() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.health")
    }

    func deskNodesList() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.nodes.list")
    }

    func deskNodesInfo(name: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.nodes.info", params: ["name": name])
    }

    func deskNodesExecute(name: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var p: [String: Any] = ["name": name]
        if !params.isEmpty { p["params"] = params }
        return try await spaceCall(method: "desk.nodes.execute", params: p)
    }

    func deskNodesCategories() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.nodes.categories")
    }

    func deskWorkflowList() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.workflow.list")
    }

    func deskWorkflowCreate(prompt: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.workflow.create", params: ["prompt": prompt])
    }

    func deskWorkflowRun(workflow: [String: Any]) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.workflow.run", params: ["workflow": workflow])
    }

    func deskWorkflowStatus() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.workflow.status")
    }

    func deskWorkflowCancel(executionId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.workflow.cancel", params: ["execution_id": executionId])
    }

    func deskAgentList() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.agent.list")
    }

    func deskAgentSubmit(task: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.agent.submit", params: ["task": task])
    }

    func deskAgentStatus(taskId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.agent.status", params: ["task_id": taskId])
    }

    func deskAgentCancel(taskId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.agent.cancel", params: ["task_id": taskId])
    }

    func deskMlxStatus() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.mlx.status")
    }

    func deskMlxModels() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.mlx.models")
    }

    func deskSystemInfo() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.system.info")
    }

    func deskEventsSubscribe() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.events.subscribe")
    }

    func deskEventsRecent(since: Double = 0.0) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.events.recent", params: ["since": since])
    }

    func deskEventsPoll(subId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.events.poll", params: ["sub_id": subId])
    }

    func deskSessionList(status: String = "", limit: Int = 20) async throws -> [String: Any] {
        var params: [String: Any] = ["limit": limit]
        if !status.isEmpty { params["status"] = status }
        return try await spaceCall(method: "desk.session.list", params: params)
    }

    func deskSessionGet(sessionId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.session.get", params: ["session_id": sessionId])
    }

    func deskSessionFork(sessionId: String, fromStep: Int = 0) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.session.fork", params: ["session_id": sessionId, "from_step": fromStep])
    }

    func deskSessionCreate(name: String, description: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["name": name]
        if !description.isEmpty { params["description"] = description }
        return try await spaceCall(method: "desk.session.create", params: params)
    }

    func deskSessionUpdate(sessionId: String, updates: [String: Any]) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.session.update", params: ["session_id": sessionId, "updates": updates])
    }

    func deskSessionDelete(sessionId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.session.delete", params: ["session_id": sessionId])
    }

    func deskPermissionCheck(toolName: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var p: [String: Any] = ["tool_name": toolName]
        if !params.isEmpty { p["params"] = params }
        return try await spaceCall(method: "desk.permission.check", params: p)
    }

    func deskPermissionApprove(toolName: String, scope: String = "*") async throws -> [String: Any] {
        return try await spaceCall(method: "desk.permission.approve", params: ["tool_name": toolName, "scope": scope])
    }

    func deskPermissionDeny(toolName: String, scope: String = "*") async throws -> [String: Any] {
        return try await spaceCall(method: "desk.permission.deny", params: ["tool_name": toolName, "scope": scope])
    }

    func deskPermissionList() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.permission.list")
    }

    func deskPermissionReset() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.permission.reset")
    }

    func deskTemplateList(category: String = "") async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if !category.isEmpty { params["category"] = category }
        return try await spaceCall(method: "desk.template.list", params: params)
    }

    func deskTemplateGet(templateId: String) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.template.get", params: ["template_id": templateId])
    }

    func deskTemplateRun(templateId: String, variables: [String: String]? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["template_id": templateId]
        if let v = variables { params["variables"] = v }
        return try await spaceCall(method: "desk.template.run", params: params)
    }

}
