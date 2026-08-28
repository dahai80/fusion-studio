import Foundation
import os.log

// MARK: - 错误类型

enum IPCError: Error, LocalizedError {
    case disconnected
    case timeout
    case invalidRequest
    case invalidResponse
    case pendingFull
    // 审计0827 §2.6 (P1): 后端连续超时达阈值开路熔断, 新 call fast-fail 不堆 pending。
    case circuitOpen
    case rpcError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .disconnected:      return "IPC 未连接"
        case .timeout:           return "IPC 调用超时"
        case .invalidRequest:    return "无效的请求"
        case .invalidResponse:   return "无效的响应"
        case .pendingFull:       return "IPC 请求队列已满, 请稍后重试"
        case .circuitOpen:       return "IPC 后端熔断中, 请稍后重试"
        case .rpcError(_, let m): return "RPC 错误: \(m)"
        }
    }
}

// MARK: - MLX HTTP API (REST, not JSON-RPC)
extension IPCClient {
    private var mlxHTTPBase: String { FusionConfig.shared.mlxBaseURL }

    func ocr(image: String, model: String, outputFormat: String = "markdown") async throws -> String {
        let url = URL(string: "\(mlxHTTPBase)/v1/ocr")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": model,
            "image": image,
            "output_format": outputFormat
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            ipcLog.error("OCR API failed: status=\(code)")
            throw IPCError.rpcError(code: code, message: "OCR API failed")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let text = results.first?["text"] as? String else {
            ipcLog.error("OCR API: unexpected response format")
            throw IPCError.invalidResponse
        }
        ipcLog.info("OCR: extracted \(text.count) chars from image")
        return text
    }

    func listOCRModels() async throws -> [String] {
        let url = URL(string: "\(mlxHTTPBase)/v1/ocr/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw IPCError.invalidResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }
        let ids = models.compactMap { $0["id"] as? String }
        ipcLog.info("OCR models found: \(ids)")
        return ids
    }
}

// MARK: - FSB (Fusion Small Business) HTTP REST

extension IPCClient {
    private var fsbHTTPBase: String { "\(FusionConfig.shared.mlxBaseURL)/api/v1/fsb" }

    private func fsbRequest(_ method: String, path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        guard let url = URL(string: "\(fsbHTTPBase)\(path)") else {
            throw IPCError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse else {
            throw IPCError.invalidResponse
        }
        guard http.statusCode >= 200 && http.statusCode < 300 else {
            var errMsg = "HTTP \(http.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errMsg = detail
            }
            ipcLog.error("FSB \(method) \(path) failed: status=\(http.statusCode) detail=\(errMsg)")
            throw IPCError.rpcError(code: http.statusCode, message: errMsg)
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return ["items": arr]
        }
        return [:]
    }

    private func fsbRequestArray(_ method: String, path: String, body: [String: Any]? = nil) async throws -> [[String: Any]] {
        guard let url = URL(string: "\(fsbHTTPBase)\(path)") else {
            throw IPCError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode >= 200, http.statusCode < 300 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            ipcLog.error("FSB \(method) \(path) failed: status=\(code)")
            throw IPCError.rpcError(code: code, message: "FSB request failed")
        }
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return arr
        }
        return []
    }

    // MARK: Workspace

    func fsbListWorkspaces(search: String = "", projectId: String = "", offset: Int = 0, limit: Int = 100) async throws -> [[String: Any]] {
        var path = "/workspace?offset=\(offset)&limit=\(limit)"
        if !search.isEmpty { path += "&search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        if !projectId.isEmpty { path += "&projectId=\(projectId)" }
        return try await fsbRequestArray("GET", path: path)
    }

    func fsbGetWorkspace(wsId: String) async throws -> [String: Any] {
        try await fsbRequest("GET", path: "/workspace/\(wsId)")
    }

    func fsbCreateWorkspace(title: String, description: String = "", projectId: String? = nil, bindAgentId: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["title": title, "description": description]
        if let pid = projectId { body["projectId"] = pid }
        if let aid = bindAgentId { body["bindAgentId"] = aid }
        return try await fsbRequest("POST", path: "/workspace", body: body)
    }

    func fsbUpdateWorkspace(wsId: String, title: String? = nil, description: String? = nil, projectId: String? = nil, bindAgentId: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [:]
        if let v = title { body["title"] = v }
        if let v = description { body["description"] = v }
        if let v = projectId { body["projectId"] = v }
        if let v = bindAgentId { body["bindAgentId"] = v }
        return try await fsbRequest("PUT", path: "/workspace/\(wsId)", body: body)
    }

    func fsbDeleteWorkspace(wsId: String) async throws -> [String: Any] {
        try await fsbRequest("DELETE", path: "/workspace/\(wsId)")
    }

    func fsbDuplicateWorkspace(wsId: String) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/\(wsId)/duplicate")
    }

    func fsbExportWorkspace(wsId: String) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/\(wsId)/export")
    }

    func fsbImportWorkspace(data: [String: Any]) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/import", body: data)
    }

    // MARK: Connector

    func fsbListConnectors(wsId: String) async throws -> [[String: Any]] {
        try await fsbRequestArray("GET", path: "/workspace/\(wsId)/connector")
    }

    func fsbCreateConnector(wsId: String, connectorKey: String, authType: String = "oauth2", authConfig: [String: Any] = [:]) async throws -> [String: Any] {
        let body: [String: Any] = ["connectorKey": connectorKey, "authType": authType, "authConfig": authConfig]
        return try await fsbRequest("POST", path: "/workspace/\(wsId)/connector", body: body)
    }

    func fsbUpdateConnector(wsId: String, connId: String, authConfig: [String: Any]? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [:]
        if let v = authConfig { body["authConfig"] = v }
        return try await fsbRequest("PUT", path: "/workspace/\(wsId)/connector/\(connId)", body: body)
    }

    func fsbDisconnectConnector(wsId: String, connId: String) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/\(wsId)/connector/\(connId)/disconnect")
    }

    func fsbRefreshConnector(wsId: String, connId: String) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/\(wsId)/connector/\(connId)/refresh")
    }

    func fsbListConnectorMeta() async throws -> [[String: Any]] {
        try await fsbRequestArray("GET", path: "/connector-meta")
    }

    func fsbGetConnectorMeta(key: String) async throws -> [String: Any] {
        try await fsbRequest("GET", path: "/connector-meta/\(key)")
    }

    // MARK: Skill

    func fsbListSkills(wsId: String) async throws -> [[String: Any]] {
        try await fsbRequestArray("GET", path: "/workspace/\(wsId)/skill")
    }

    func fsbGetSkill(wsId: String, skillId: String) async throws -> [String: Any] {
        try await fsbRequest("GET", path: "/workspace/\(wsId)/skill/\(skillId)")
    }

    func fsbCreateSkill(wsId: String, name: String, displayName: String = "", type: String = "prompt", definition: String = "", inputSchema: [String: Any]? = nil, outputFormat: String? = nil, enabled: Bool = true) async throws -> [String: Any] {
        var body: [String: Any] = ["name": name, "displayName": displayName, "type": type, "definition": definition, "enabled": enabled]
        if let v = inputSchema { body["inputSchema"] = v }
        if let v = outputFormat { body["outputFormat"] = v }
        return try await fsbRequest("POST", path: "/workspace/\(wsId)/skill", body: body)
    }

    func fsbUpdateSkill(wsId: String, skillId: String, name: String? = nil, displayName: String? = nil, definition: String? = nil, inputSchema: [String: Any]? = nil, outputFormat: String? = nil, enabled: Bool? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [:]
        if let v = name { body["name"] = v }
        if let v = displayName { body["displayName"] = v }
        if let v = definition { body["definition"] = v }
        if let v = inputSchema { body["inputSchema"] = v }
        if let v = outputFormat { body["outputFormat"] = v }
        if let v = enabled { body["enabled"] = v }
        return try await fsbRequest("PUT", path: "/workspace/\(wsId)/skill/\(skillId)", body: body)
    }

    func fsbDeleteSkill(wsId: String, skillId: String) async throws -> [String: Any] {
        try await fsbRequest("DELETE", path: "/workspace/\(wsId)/skill/\(skillId)")
    }

    func fsbTestSkill(wsId: String, skillId: String, input: [String: Any] = [:]) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/\(wsId)/skill/\(skillId)/test", body: input)
    }

    // MARK: Workflow

    func fsbListWorkflows(wsId: String) async throws -> [[String: Any]] {
        try await fsbRequestArray("GET", path: "/workspace/\(wsId)/workflow")
    }

    func fsbGetWorkflow(wsId: String, wfId: String) async throws -> [String: Any] {
        try await fsbRequest("GET", path: "/workspace/\(wsId)/workflow/\(wfId)")
    }

    func fsbCreateWorkflow(wsId: String, name: String, displayName: String = "", description: String = "", slashCommand: String? = nil, graphDefinition: [String: Any]? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["name": name, "displayName": displayName, "description": description]
        if let v = slashCommand { body["slashCommand"] = v }
        if let v = graphDefinition { body["graphDefinition"] = v }
        return try await fsbRequest("POST", path: "/workspace/\(wsId)/workflow", body: body)
    }

    func fsbUpdateWorkflow(wsId: String, wfId: String, name: String? = nil, displayName: String? = nil, description: String? = nil, enabled: Bool? = nil, graphDefinition: [String: Any]? = nil, schedule: [String: Any]? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [:]
        if let v = name { body["name"] = v }
        if let v = displayName { body["displayName"] = v }
        if let v = description { body["description"] = v }
        if let v = enabled { body["enabled"] = v }
        if let v = graphDefinition { body["graphDefinition"] = v }
        if let v = schedule { body["schedule"] = v }
        return try await fsbRequest("PUT", path: "/workspace/\(wsId)/workflow/\(wfId)", body: body)
    }

    func fsbDeleteWorkflow(wsId: String, wfId: String) async throws -> [String: Any] {
        try await fsbRequest("DELETE", path: "/workspace/\(wsId)/workflow/\(wfId)")
    }

    func fsbRunWorkflow(wsId: String, wfId: String, inputData: [String: Any] = [:], triggeredBy: String = "") async throws -> [String: Any] {
        var body: [String: Any] = ["inputData": inputData]
        if !triggeredBy.isEmpty { body["triggeredBy"] = triggeredBy }
        return try await fsbRequest("POST", path: "/workspace/\(wsId)/workflow/\(wfId)/run", body: body)
    }

    func fsbSetSchedule(wsId: String, wfId: String, type: String, cron: String? = nil, eventTrigger: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["type": type]
        if let v = cron { body["cron"] = v }
        if let v = eventTrigger { body["eventTrigger"] = v }
        return try await fsbRequest("POST", path: "/workspace/\(wsId)/workflow/\(wfId)/schedule", body: body)
    }

    func fsbDeleteSchedule(wsId: String, wfId: String, scheduleId: String) async throws -> [String: Any] {
        try await fsbRequest("DELETE", path: "/workspace/\(wsId)/workflow/\(wfId)/schedule/\(scheduleId)")
    }

    func fsbExportWorkflow(wsId: String, wfId: String) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/\(wsId)/workflow/\(wfId)/export")
    }

    func fsbImportWorkflow(wsId: String, data: [String: Any]) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/\(wsId)/workflow/import", body: data)
    }

    // MARK: Execution

    func fsbExecutionHistory(wsId: String, workflowId: String? = nil, offset: Int = 0, limit: Int = 100) async throws -> [[String: Any]] {
        var path = "/workspace/\(wsId)/execution/history?offset=\(offset)&limit=\(limit)"
        if let wfId = workflowId { path += "&workflowId=\(wfId)" }
        return try await fsbRequestArray("GET", path: path)
    }

    func fsbGetExecution(wsId: String, runId: String) async throws -> [String: Any] {
        try await fsbRequest("GET", path: "/workspace/\(wsId)/execution/\(runId)")
    }

    func fsbExportExecutionLog(wsId: String) async throws -> [String: Any] {
        try await fsbRequest("GET", path: "/workspace/\(wsId)/execution/export")
    }

    func fsbListPendingTasks(wsId: String) async throws -> [[String: Any]] {
        try await fsbRequestArray("GET", path: "/workspace/\(wsId)/task/pending")
    }

    func fsbApproveTask(wsId: String, taskId: String) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/\(wsId)/task/\(taskId)/approve")
    }

    func fsbDenyTask(wsId: String, taskId: String) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/\(wsId)/task/\(taskId)/deny")
    }

    func fsbEditTask(wsId: String, taskId: String, editContent: [String: Any]) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/workspace/\(wsId)/task/\(taskId)/edit", body: ["editContent": editContent])
    }

    // MARK: External / Events / Webhooks

    func fsbExternalTrigger(wfId: String, inputData: [String: Any] = [:]) async throws -> [String: Any] {
        try await fsbRequest("POST", path: "/external/workflow/\(wfId)/trigger", body: ["inputData": inputData])
    }

    func fsbExternalStatus(wfId: String) async throws -> [String: Any] {
        try await fsbRequest("GET", path: "/external/workflow/\(wfId)/status")
    }

    func fsbPostEvent(eventType: String, source: String = "", payload: [String: Any] = [:], workspaceId: String = "") async throws -> [String: Any] {
        var body: [String: Any] = ["eventType": eventType, "payload": payload]
        if !source.isEmpty { body["source"] = source }
        if !workspaceId.isEmpty { body["workspaceId"] = workspaceId }
        return try await fsbRequest("POST", path: "/external/event", body: body)
    }

    func fsbCreateSubscription(workspaceId: String, workflowId: String, eventType: String, source: String? = nil, enabled: Bool = true) async throws -> [String: Any] {
        var body: [String: Any] = ["workspaceId": workspaceId, "workflowId": workflowId, "eventType": eventType, "enabled": enabled]
        if let v = source { body["source"] = v }
        return try await fsbRequest("POST", path: "/external/event/subscription", body: body)
    }

    func fsbListSubscriptions(wsId: String) async throws -> [[String: Any]] {
        try await fsbRequestArray("GET", path: "/external/event/subscription?wsId=\(wsId)")
    }

    func fsbDeleteSubscription(subId: String) async throws -> [String: Any] {
        try await fsbRequest("DELETE", path: "/external/event/subscription/\(subId)")
    }

    func fsbRegisterWebhook(workspaceId: String, url: String, events: [String] = ["run.completed"], secret: String = "") async throws -> [String: Any] {
        var body: [String: Any] = ["workspaceId": workspaceId, "url": url, "events": events]
        if !secret.isEmpty { body["secret"] = secret }
        return try await fsbRequest("POST", path: "/external/webhook/register", body: body)
    }

    func fsbListWebhooks(wsId: String) async throws -> [[String: Any]] {
        try await fsbRequestArray("GET", path: "/external/webhook?wsId=\(wsId)")
    }

    func fsbDeleteWebhook(webhookId: String) async throws -> [String: Any] {
        try await fsbRequest("DELETE", path: "/external/webhook/\(webhookId)")
    }

    // MARK: Variables / Templates

    func fsbListVariables(wsId: String) async throws -> [[String: Any]] {
        try await fsbRequestArray("GET", path: "/workspace/\(wsId)/variable")
    }

    func fsbUpdateVariables(wsId: String, variables: [[String: Any]]) async throws -> [[String: Any]] {
        guard let url = URL(string: "\(fsbHTTPBase)/workspace/\(wsId)/variable") else {
            throw IPCError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: variables)
        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode >= 200, http.statusCode < 300 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            ipcLog.error("FSB PUT /workspace/\(wsId)/variable failed: status=\(code)")
            throw IPCError.rpcError(code: code, message: "FSB update variables failed")
        }
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return arr
        }
        return []
    }

    func fsbListTemplates(wsId: String) async throws -> [[String: Any]] {
        try await fsbRequestArray("GET", path: "/workspace/\(wsId)/template")
    }

    func fsbCreateTemplate(wsId: String, name: String, data: [String: Any] = [:], category: String? = nil, description: String? = nil, graphDefinition: [String: Any]? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["name": name, "data": data]
        if let v = category { body["category"] = v }
        if let v = description { body["description"] = v }
        if let v = graphDefinition { body["graphDefinition"] = v }
        return try await fsbRequest("POST", path: "/workspace/\(wsId)/template", body: body)
    }

    func fsbDeleteTemplate(wsId: String, templateId: String) async throws -> [String: Any] {
        try await fsbRequest("DELETE", path: "/workspace/\(wsId)/template/\(templateId)")
    }

    // MARK: Integration

    func fsbSendToCanvas(wsId: String, wfId: String, sessionId: String? = nil, outputDir: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [:]
        if let v = sessionId { body["sessionId"] = v }
        if let v = outputDir { body["outputDir"] = v }
        return try await fsbRequest("POST", path: "/workspace/\(wsId)/workflow/\(wfId)/send-to-canvas", body: body.isEmpty ? nil : body)
    }

    func fsbSyncToProject(wsId: String, projectId: String, artifactIds: [String]? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["projectId": projectId]
        if let v = artifactIds { body["artifactIds"] = v }
        return try await fsbRequest("POST", path: "/workspace/\(wsId)/sync-to-project", body: body)
    }

    func fsbCreateArtifact(wsId: String, name: String, type: String = "text", content: String = "", projectId: String? = nil, runId: String? = nil, metadata: [String: Any] = [:]) async throws -> [String: Any] {
        var body: [String: Any] = ["name": name, "type": type, "content": content, "metadata": metadata]
        if let v = projectId { body["projectId"] = v }
        if let v = runId { body["runId"] = v }
        return try await fsbRequest("POST", path: "/workspace/\(wsId)/create-artifact", body: body)
    }

    // MARK: Health

    func fsbHealth() async throws -> [String: Any] {
        guard let url = URL(string: "\(FusionConfig.shared.mlxBaseURL)/health") else {
            throw IPCError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw IPCError.rpcError(code: code, message: "FSB health check failed")
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
