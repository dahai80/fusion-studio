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
        return try await call(method: RPCMethod.skillExecute, params: params)
    }

    func researchAdaptive(question: String, maxSteps: Int = 10, webSearch: Bool = true) async throws -> [String: Any] {
        let params: [String: Any] = [
            "question": question,
            "max_steps": maxSteps,
            "web_search": webSearch,
        ]
        return try await call(method: RPCMethod.researchAdaptive, params: params)
    }

    // Callers: UnifiedChatView, ChatSessionStore, RAGPipelineView, ToolBrowserView, MemoryView, SafetyView, VerificationView, TokenBudgetView. Affected APIs: chat.get/switch_branch/branches/message_tree, rag.vector_search, verify.verify, budget.set/status, safety.approve/reject, tool.list/get/dynamic_register/dynamic_unregister, memory.recall_relevant/auto_forget, session.list, graph.update. Data schemas: all return [String: Any] JSON-RPC results matching daemon_server.py handler signatures. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"

    // MARK: - Chat Extended

    func chatGet(sessionId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.chatGet, params: ["session_id": sessionId])
    }

    func chatSwitchBranch(sessionId: String, branchId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.chatSwitchBranch, params: ["session_id": sessionId, "branch_id": branchId])
    }

    func chatBranches(sessionId: String, messageId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.chatBranches, params: ["session_id": sessionId, "message_id": messageId])
    }

    func chatMessageTree(sessionId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.chatMessageTree, params: ["session_id": sessionId])
    }

    // MARK: - RAG Extended

    func ragVectorSearch(query: String, limit: Int = 10, threshold: Double = 0.5) async throws -> [String: Any] {
        return try await call(method: RPCMethod.ragVectorSearch, params: ["query": query, "limit": limit, "threshold": threshold])
    }

    private var ragHTTPBase: String { "http://\(FusionConfig.shared.fusionRagHost):\(FusionConfig.shared.fusionRagPort)" }

    // SEC-7 (审计product-0905 P2): path 段注入防御 — 拒空/含分隔符/遍历符/控制字符的 segment。
    private func isSafePathSegment(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        if s.contains("/") || s.contains("\\") { return false }
        if s.contains("..") { return false }
        if s.unicodeScalars.contains(where: { $0.value < 0x20 || $0 == "?" || $0 == "#" }) { return false }
        return true
    }

    func ragWatch(kbId: String, filePaths: [String], pollInterval: Int = 30) async throws -> [String: Any] {
        // SEC-3 (审计product-0905 P2): guard 替 force-unwrap; SEC-7: kbId 防 path 注入。
        guard isSafePathSegment(kbId),
              let url = URL(string: "\(ragHTTPBase)/kb/bases/\(kbId)/watch") else {
            ipcLog.error("ragWatch: invalid kbId or base URL")
            throw IPCError.invalidResponse
        }
        let body: [String: Any] = ["file_paths": filePaths, "poll_interval": pollInterval]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: url)
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
        // SEC-3 + SEC-7: guard 替 force-unwrap + kbId path 注入防御。
        guard isSafePathSegment(kbId),
              let url = URL(string: "\(ragHTTPBase)/kb/bases/\(kbId)/unwatch") else {
            ipcLog.error("ragUnwatch: invalid kbId or base URL")
            throw IPCError.invalidResponse
        }
        let body: [String: Any] = ["watch_id": watchId]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: url)
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
        // SEC-3 + SEC-7: guard 替 force-unwrap + kbId path 注入防御。
        guard isSafePathSegment(kbId),
              let url = URL(string: "\(ragHTTPBase)/kb/bases/\(kbId)/watch/status") else {
            ipcLog.error("ragWatchStatus: invalid kbId or base URL")
            throw IPCError.invalidResponse
        }
        var request = URLRequest(url: url)
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
        return try await call(method: RPCMethod.verifyVerify, params: params)
    }

    // MARK: - Dashboard

    func dashboardOverview() async throws -> [String: Any] {
        return try await call(method: RPCMethod.dashboardOverview)
    }

    // MARK: - Connector

    func connectorList() async throws -> [String: Any] {
        return try await call(method: RPCMethod.connectorList)
    }

    func connectorCreate(name: String, type: String, config: [String: Any]) async throws -> [String: Any] {
        return try await call(method: RPCMethod.connectorCreate, params: ["name": name, "type": type, "config": config])
    }

    func connectorGet(connectorId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.connectorGet, params: ["connector_id": connectorId])
    }

    func connectorUpdate(connectorId: String, config: [String: Any]) async throws -> [String: Any] {
        var params: [String: Any] = ["connector_id": connectorId]
        params.merge(config) { _, new in new }
        return try await call(method: RPCMethod.connectorUpdate, params: params)
    }

    func connectorDelete(connectorId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.connectorDelete, params: ["connector_id": connectorId])
    }

    func connectorConnect(connectorId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.connectorConnect, params: ["connector_id": connectorId])
    }

    func connectorDisconnect(connectorId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.connectorDisconnect, params: ["connector_id": connectorId])
    }

    func connectorTest(connectorId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.connectorTest, params: ["connector_id": connectorId])
    }

    // MARK: - API Key

    func apikeyCreate(name: String, permissions: [String] = [], agentIds: [String] = [], ipWhitelist: [String] = [], expiresInDays: Int? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["name": name, "permissions": permissions, "agent_ids": agentIds, "ip_whitelist": ipWhitelist]
        if let days = expiresInDays { params["expires_in_days"] = days }
        return try await call(method: RPCMethod.apikeyCreate, params: params)
    }

    func apikeyList() async throws -> [String: Any] {
        return try await call(method: RPCMethod.apikeyList)
    }

    func apikeyRevoke(keyId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.apikeyRevoke, params: ["key_id": keyId])
    }

    func apikeyRotate(keyId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.apikeyRotate, params: ["key_id": keyId])
    }

    func apikeyUpdate(keyId: String, permissions: [String]? = nil, agentIds: [String]? = nil, ipWhitelist: [String]? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["key_id": keyId]
        if let p = permissions { params["permissions"] = p }
        if let a = agentIds { params["agent_ids"] = a }
        if let i = ipWhitelist { params["ip_whitelist"] = i }
        return try await call(method: RPCMethod.apikeyUpdate, params: params)
    }

    // MARK: - Style

    func styleList() async throws -> [String: Any] {
        return try await call(method: RPCMethod.styleList)
    }

    func styleGet(styleId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.styleGet, params: ["style_id": styleId])
    }

    func styleCreate(name: String, template: String, rules: [String: Any] = [:]) async throws -> [String: Any] {
        var params: [String: Any] = ["name": name, "template": template]
        if !rules.isEmpty { params["rules"] = rules }
        return try await call(method: RPCMethod.styleCreate, params: params)
    }

    func styleApply(agentId: String, styleId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.styleApply, params: ["agent_id": agentId, "style_id": styleId])
    }

    func styleDelete(styleId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.styleDelete, params: ["style_id": styleId])
    }

    // MARK: - Analytics

    func analyticsAgentUsage(agentId: String? = nil, range: String = "week") async throws -> [String: Any] {
        var params: [String: Any] = ["range": range]
        if let aid = agentId { params["agent_id"] = aid }
        return try await call(method: RPCMethod.analyticsAgentUsage, params: params)
    }

    // MARK: - Alert

    func alertList() async throws -> [String: Any] {
        return try await call(method: RPCMethod.alertList)
    }

    func alertAcknowledge(alertId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.alertAcknowledge, params: ["alert_id": alertId])
    }

    // MARK: - Budget

    func budgetSet(totalBudget: Int, warnPercent: Int = 80, hardLimit: Bool = true) async throws -> [String: Any] {
        return try await call(method: RPCMethod.budgetSet, params: ["total_budget": totalBudget, "warn_percent": warnPercent, "hard_limit": hardLimit])
    }

    func budgetStatus() async throws -> [String: Any] {
        return try await call(method: RPCMethod.budgetStatus)
    }

    // MARK: - Safety Runtime

    func safetyApprove(actionId: String, reason: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["action_id": actionId]
        if !reason.isEmpty { params["reason"] = reason }
        return try await call(method: RPCMethod.safetyApprove, params: params)
    }

    func safetyReject(actionId: String, reason: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["action_id": actionId]
        if !reason.isEmpty { params["reason"] = reason }
        return try await call(method: RPCMethod.safetyReject, params: params)
    }

    // MARK: - Tool Extended

    func toolList() async throws -> [String: Any] {
        return try await call(method: RPCMethod.toolList)
    }

    func toolGet(name: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.toolGet, params: ["name": name])
    }

    func toolDynamicRegister(name: String, description: String, parameters: [String: Any], code: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["name": name, "description": description, "parameters": parameters]
        if !code.isEmpty { params["code"] = code }
        return try await call(method: RPCMethod.toolDynamicRegister, params: params)
    }

    func toolDynamicUnregister(name: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.toolDynamicUnregister, params: ["name": name])
    }

    // MARK: - Memory Extended

    func memoryRecallRelevant(query: String, context: String = "", limit: Int = 10) async throws -> [String: Any] {
        var params: [String: Any] = ["query": query, "limit": limit]
        if !context.isEmpty { params["context"] = context }
        return try await call(method: RPCMethod.memoryRecallRelevant, params: params)
    }

    func memoryAutoForget(maxAge: Int = 30, minImportance: Int = 3, dryRun: Bool = true) async throws -> [String: Any] {
        return try await call(method: RPCMethod.memoryAutoForget, params: ["max_age": maxAge, "min_importance": minImportance, "dry_run": dryRun])
    }

    // MARK: - Session

    func sessionList() async throws -> [String: Any] {
        return try await call(method: RPCMethod.sessionList)
    }

    // MARK: - Graph Extended

    func graphUpdate(graphId: String, updates: [String: Any]) async throws -> [String: Any] {
        return try await call(method: RPCMethod.graphUpdate, params: ["graph_id": graphId, "updates": updates])
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

    // #217 P1-1: GUI 选定授权工作文件夹后下发沙箱根 (ScopedFolderManager)。
    // desk.system.set_scoped_folder params {folders:[abs], enforce:bool} -> {set:true, folders, enforce}
    func deskSystemSetScopedFolder(folders: [String], enforce: Bool = true) async throws -> [String: Any] {
        return try await spaceCall(method: "desk.system.set_scoped_folder", params: [
            "folders": folders,
            "enforce": enforce,
        ])
    }

    // #217 P1-1: 查询当前已注册授权文件夹 (启动时回填, 已注册则跳过 NSOpenPanel)。
    // desk.system.scoped_folder (GET) -> {folders, enforce}
    func deskSystemGetScopedFolder() async throws -> [String: Any] {
        return try await spaceCall(method: "desk.system.scoped_folder")
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
