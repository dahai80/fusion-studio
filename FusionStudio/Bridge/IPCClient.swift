import Foundation
import Combine
import os.log

private let ipcLog = Logger(subsystem: "com.fusion.studio", category: "IPCClient")

/// IPC 通信客户端 — Unix Domain Socket + JSON-RPC 2.0
class IPCClient: ObservableObject {
    @Published var isConnected = false
    @Published var lastError: String?

    private let socketPath: String
    private var requestId: Int = 0
    private var socketFd: Int32 = -1
    private let queue = DispatchQueue(label: "com.fusion-studio.ipc", qos: .userInitiated)
    private var reconnectTimer: Timer?
    // 续体直接存储：handleResponse / 超时 / 断连 三处 removeValue 取出并 resume，保证恰好一次
    private var pendingRequests: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private let lock = NSLock()

    init(socketPath: String = "/tmp/fusion-studio.sock") {
        self.socketPath = socketPath
        connect()
    }

    // MARK: - 连接管理

    func connect() {
        queue.async { [weak self] in
            self?.performConnect()
        }
    }

    private func performConnect() {
        // 关闭旧连接
        if socketFd >= 0 {
            close(socketFd)
            socketFd = -1
        }

        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            setError("无法创建 socket: \(String(cString: strerror(errno)))")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathCString = socketPath.utf8CString
        let pathLen = min(pathCString.count, MemoryLayout.size(ofValue: addr.sun_path))
        _ = pathCString.withUnsafeBufferPointer { src in
            withUnsafeMutableBytes(of: &addr.sun_path) { dst in
                dst.copyMemory(from: UnsafeRawBufferPointer(
                    start: UnsafeRawPointer(src.baseAddress!),
                    count: pathLen
                ))
            }
        }

        let fd = Darwin.connect(sock, withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        }, socklen_t(MemoryLayout<sockaddr_un>.size))

        guard fd >= 0 else {
            close(sock)
            let errMsg = String(cString: strerror(errno))
            setError("连接失败 (\(errMsg))")
            scheduleReconnect()
            return
        }

        // 设置非阻塞
        var flags = fcntl(sock, F_GETFL, 0)
        fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        socketFd = sock
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = true
            self?.lastError = nil
            self?.reconnectTimer?.invalidate()
            self?.reconnectTimer = nil
        }
        startReading()
    }

    func disconnect() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if self.socketFd >= 0 {
                close(self.socketFd)
                self.socketFd = -1
            }
            DispatchQueue.main.async {
                self.isConnected = false
            }
        }
    }

    private func scheduleReconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                self?.connect()
            }
        }
    }

    // MARK: - JSON-RPC 调用

    /// 调用远程方法
    @discardableResult
    func call(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: IPCError.disconnected)
                    return
                }

                self.requestId += 1
                let reqId = self.requestId

                var request: [String: Any] = [
                    "jsonrpc": "2.0",
                    "id": reqId,
                    "method": method,
                ]
                if !params.isEmpty {
                    request["params"] = params
                }

                guard let data = try? JSONSerialization.data(withJSONObject: request) else {
                    continuation.resume(throwing: IPCError.invalidRequest)
                    return
                }

                guard self.socketFd >= 0 else {
                    continuation.resume(throwing: IPCError.disconnected)
                    return
                }

                // 注册续体
                self.lock.lock()
                self.pendingRequests[reqId] = continuation
                self.lock.unlock()

                // 超时保护：8s 无响应即失败，避免 daemon 不回包时续体泄露、调用永久挂起 (bug3/bug4)
                self.queue.asyncAfter(deadline: .now() + 8) { [weak self] in
                    guard let self = self else { return }
                    self.lock.lock()
                    let pending = self.pendingRequests.removeValue(forKey: reqId)
                    self.lock.unlock()
                    if let pending = pending {
                        ipcLog.warning("IPC call timeout: method=\(method, privacy: .public) id=\(reqId)")
                        pending.resume(throwing: IPCError.timeout)
                    }
                }

                // 发送数据
                var writeBuf = data
                writeBuf.append(0x0A) // 换行符作为消息分隔符
                writeBuf.withUnsafeBytes { ptr in
                    Darwin.write(self.socketFd, ptr.baseAddress, writeBuf.count)
                }
            }
        }
    }

    // MARK: - 读取循环

    private func startReading() {
        queue.async { [weak self] in
            guard let self = self else { return }
            var buffer = Data()

            while self.socketFd >= 0 {
                var byte: UInt8 = 0
                let n = Darwin.read(self.socketFd, &byte, 1)
                if n > 0 {
                    if byte == 0x0A {
                        self.handleResponse(buffer)
                        buffer = Data()
                    } else {
                        buffer.append(byte)
                    }
                } else if n == 0 {
                    self.drainPending()
                    DispatchQueue.main.async {
                        self.isConnected = false
                        self.scheduleReconnect()
                    }
                    break
                } else if errno == EAGAIN {
                    Thread.sleep(forTimeInterval: 0.01)
                } else {
                    self.drainPending()
                    DispatchQueue.main.async {
                        self.isConnected = false
                        self.scheduleReconnect()
                    }
                    break
                }
            }
        }
    }

    private func handleResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? Int else { return }

        lock.lock()
        let cont = pendingRequests.removeValue(forKey: id)
        lock.unlock()
        guard let cont = cont else { return }

        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let msg = error["message"] as? String ?? "未知错误"
            cont.resume(throwing: IPCError.rpcError(code: code, message: msg))
        } else if let result = json["result"] {
            cont.resume(returning: result as? [String: Any] ?? [:])
        } else {
            cont.resume(returning: [:])
        }
    }

    /// 断连时排空所有挂起请求，resume 为 .disconnected，避免续体泄露 (bug3/bug4)
    private func drainPending() {
        lock.lock()
        let pending = pendingRequests
        pendingRequests.removeAll()
        lock.unlock()
        guard !pending.isEmpty else { return }
        ipcLog.warning("IPC drain \(pending.count, privacy: .public) pending requests on disconnect")
        for (_, cont) in pending {
            cont.resume(throwing: IPCError.disconnected)
        }
    }

    // MARK: - 便捷方法

    func healthCheck() async throws -> [String: Any] {
        return try await call(method: "env.health_check")
    }

    func repair(itemId: String) async throws -> [String: Any] {
        return try await call(method: "env.repair", params: ["item_id": itemId])
    }

    func repairAll() async throws -> [String: Any] {
        return try await call(method: "env.repair_all")
    }

    func startMLX(model: String = "") async throws -> [String: Any] {
        return try await call(method: "mlx.start", params: ["model": model])
    }

    func stopMLX() async throws -> [String: Any] {
        return try await call(method: "mlx.stop")
    }

    func mlxStatus() async throws -> [String: Any] {
        return try await call(method: "mlx.status")
    }

    func hardwareMetrics() async throws -> [String: Any] {
        return try await call(method: "hardware.metrics")
    }

    func submitTask(type: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var p = params
        p["type"] = type
        return try await call(method: "task.submit", params: p)
    }

    func ping() async throws -> Bool {
        let result = try await call(method: "ping")
        return result["pong"] as? Bool ?? false
    }

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

    // MARK: - Agent CRUD

    func agentCreate(name: String, model: String = "", systemPrompt: String = "", temperature: Double = 0.7, maxTokens: Int = 4096, tools: [String] = [], capabilities: [String] = [], safetyLevel: String = "L1", tags: [String] = [], description: String = "", soul: String = "", memory: String = "", agentsMd: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["name": name, "model": model, "system_prompt": systemPrompt, "temperature": temperature, "max_tokens": maxTokens, "tools": tools, "capabilities": capabilities, "safety_level": safetyLevel, "tags": tags, "description": description]
        if !soul.isEmpty { params["soul"] = soul }
        if !memory.isEmpty { params["memory"] = memory }
        if !agentsMd.isEmpty { params["agents_md"] = agentsMd }
        return try await call(method: "agent.create", params: params)
    }

    func agentGet(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.get", params: ["agent_id": agentId])
    }

    func agentList(tags: [String] = [], capabilities: [String] = []) async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if !tags.isEmpty { params["tags"] = tags }
        if !capabilities.isEmpty { params["capabilities"] = capabilities }
        return try await call(method: "agent.list", params: params)
    }

    func agentUpdate(agentId: String, name: String? = nil, model: String? = nil, systemPrompt: String? = nil, temperature: Double? = nil, maxTokens: Int? = nil, tools: [String]? = nil, capabilities: [String]? = nil, safetyLevel: String? = nil, tags: [String]? = nil, description: String? = nil) async throws -> [String: Any] {
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

    func agentClone(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.clone", params: ["agent_id": agentId])
    }

    func agentGetApiEndpoint(agentId: String) async throws -> [String: Any] {
        return try await call(method: "agent.get_api_endpoint", params: ["agent_id": agentId])
    }

    func agentExecuteStream(agentId: String, input: String, context: [String: Any] = [:]) async throws -> [String: Any] {
        var params: [String: Any] = ["agent_id": agentId, "input": input]
        if !context.isEmpty { params["context"] = context }
        return try await call(method: "agent.execute_stream", params: params)
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

    // MARK: - Artifacts Engine (HTTP JSON-RPC, config from FusionConfig)

    private var artifactsEngineURL: String {
        FusionConfig.shared.artifactsEngineURL
    }

    func artifactsCall(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int(Date().timeIntervalSince1970 * 1000),
            "method": method,
        ]
        if !params.isEmpty {
            request["params"] = params
        }
        guard let requestData = try? JSONSerialization.data(withJSONObject: request) else {
            throw IPCError.invalidRequest
        }
        guard let url = URL(string: artifactsEngineURL) else {
            throw IPCError.invalidRequest
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IPCError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw IPCError.rpcError(code: httpResponse.statusCode, message: "HTTP \(httpResponse.statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IPCError.invalidResponse
        }
        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let msg = error["message"] as? String ?? "Unknown error"
            throw IPCError.rpcError(code: code, message: msg)
        }
        return json["result"] as? [String: Any] ?? [:]
    }

    func artifactCreate(sessionId: String, name: String, type: String, kind: String? = nil, content: String, summary: String? = nil, projectId: String? = nil, metadata: [String: Any]? = nil) async throws -> [String: Any] {
        var params: [String: Any] = [
            "session_id": sessionId,
            "name": name,
            "type": type,
            "content": content,
        ]
        if let k = kind { params["kind"] = k }
        if let s = summary { params["summary"] = s }
        if let p = projectId { params["project_id"] = p }
        if let m = metadata { params["metadata"] = m }
        return try await artifactsCall(method: "artifact.create", params: params)
    }

    func artifactGet(artifactId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.get", params: ["artifact_id": artifactId])
    }

    func artifactGetContent(artifactId: String, version: Int? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["artifact_id": artifactId]
        if let v = version { params["version"] = v }
        return try await artifactsCall(method: "artifact.get_content", params: params)
    }

    func artifactList(sessionId: String, includeDeleted: Bool = false, projectId: String? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["session_id": sessionId]
        if includeDeleted { params["include_deleted"] = true }
        if let p = projectId { params["project_id"] = p }
        return try await artifactsCall(method: "artifact.list", params: params)
    }

    func artifactDelete(artifactId: String, hard: Bool = false) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.delete", params: ["artifact_id": artifactId, "hard": hard])
    }

    func artifactUpdate(artifactId: String, content: String, changeLog: String? = nil, projectId: String? = nil, metadata: [String: Any]? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["artifact_id": artifactId, "content": content]
        if let cl = changeLog { params["change_log"] = cl }
        if let p = projectId { params["project_id"] = p }
        if let m = metadata { params["metadata"] = m }
        return try await artifactsCall(method: "artifact.update", params: params)
    }

    func artifactVersionList(artifactId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.version_list", params: ["artifact_id": artifactId])
    }

    func artifactVersionRollback(artifactId: String, targetVersion: Int) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.version_rollback", params: ["artifact_id": artifactId, "target_version": targetVersion])
    }

    func artifactInject(messages: [[String: Any]], outputBudget: Int = 8192) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.inject", params: ["messages": messages, "output_budget": outputBudget])
    }

    func artifactCheckSafety(messages: [[String: Any]], outputBudget: Int = 8192) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.check_safety", params: ["messages": messages, "output_budget": outputBudget])
    }

    func artifactExport(artifactId: String, format: String = "json") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.export", params: ["artifact_id": artifactId, "format": format])
    }

    func artifactExportSession(sessionId: String, format: String = "json") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.export_session", params: ["session_id": sessionId, "format": format])
    }

    func artifactImport(data: [String: Any]) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.import", params: ["data": data])
    }

    func artifactPing() async throws -> Bool {
        let result = try await artifactsCall(method: "ping", params: [:])
        return result["pong"] as? Bool ?? false
    }

    func artifactSync(artifactId: String, filePath: String, direction: String = "bidirectional") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.sync", params: [
            "artifact_id": artifactId,
            "file_path": filePath,
            "direction": direction
        ])
    }

    func artifactWatch(artifactId: String, action: String = "register") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.watch", params: [
            "artifact_id": artifactId,
            "action": action
        ])
    }

    func artifactExportCode(artifactId: String, language: String = "swift") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.export_code", params: [
            "artifact_id": artifactId,
            "language": language
        ])
    }

    func artifactImportCode(code: String, language: String, name: String, sessionId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.import_code", params: [
            "code": code,
            "language": language,
            "name": name,
            "session_id": sessionId
        ])
    }

    // MARK: - Artifacts Engine (REST endpoints)

    func artifactTokenCount(text: String, model: String? = nil) async throws -> [String: Any] {
        let baseURL = artifactsEngineURL
        guard let url = URL(string: "\(baseURL)/api/token-count") else {
            throw IPCError.invalidRequest
        }
        var body: [String: Any] = ["text": text]
        if let m = model { body["model"] = m }
        guard let requestData = try? JSONSerialization.data(withJSONObject: body) else {
            throw IPCError.invalidRequest
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IPCError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw IPCError.rpcError(code: httpResponse.statusCode, message: "artifactTokenCount HTTP \(httpResponse.statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IPCError.invalidResponse
        }
        return json
    }

    func artifactRender(content: String, sessionId: String, langHint: String = "", projectId: String? = nil) async throws -> [String: Any] {
        var params: [String: Any] = [
            "content": content,
            "session_id": sessionId,
            "lang_hint": langHint,
        ]
        if let pid = projectId { params["project_id"] = pid }
        return try await artifactsCall(method: "artifact.render", params: params)
    }

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

    private static let ragHTTPBase = "http://127.0.0.1:8901"

    func ragWatch(kbId: String, filePaths: [String], pollInterval: Int = 30) async throws -> [String: Any] {
        let body: [String: Any] = ["file_paths": filePaths, "poll_interval": pollInterval]
        let data = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: URL(string: "\(IPCClient.ragHTTPBase)/kb/bases/\(kbId)/watch")!)
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
        var request = URLRequest(url: URL(string: "\(IPCClient.ragHTTPBase)/kb/bases/\(kbId)/unwatch")!)
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
        var request = URLRequest(url: URL(string: "\(IPCClient.ragHTTPBase)/kb/bases/\(kbId)/watch/status")!)
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
        return try await call(method: "desk.health")
    }

    func deskNodesList() async throws -> [String: Any] {
        return try await call(method: "desk.nodes.list")
    }

    func deskNodesInfo(name: String) async throws -> [String: Any] {
        return try await call(method: "desk.nodes.info", params: ["name": name])
    }

    func deskNodesExecute(name: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var p: [String: Any] = ["name": name]
        if !params.isEmpty { p["params"] = params }
        return try await call(method: "desk.nodes.execute", params: p)
    }

    func deskNodesCategories() async throws -> [String: Any] {
        return try await call(method: "desk.nodes.categories")
    }

    func deskWorkflowList() async throws -> [String: Any] {
        return try await call(method: "desk.workflow.list")
    }

    func deskWorkflowCreate(prompt: String) async throws -> [String: Any] {
        return try await call(method: "desk.workflow.create", params: ["prompt": prompt])
    }

    func deskWorkflowRun(workflow: [String: Any]) async throws -> [String: Any] {
        return try await call(method: "desk.workflow.run", params: ["workflow": workflow])
    }

    func deskWorkflowStatus() async throws -> [String: Any] {
        return try await call(method: "desk.workflow.status")
    }

    func deskWorkflowCancel(executionId: String) async throws -> [String: Any] {
        return try await call(method: "desk.workflow.cancel", params: ["execution_id": executionId])
    }

    func deskAgentList() async throws -> [String: Any] {
        return try await call(method: "desk.agent.list")
    }

    func deskAgentSubmit(task: String) async throws -> [String: Any] {
        return try await call(method: "desk.agent.submit", params: ["task": task])
    }

    func deskAgentStatus(taskId: String) async throws -> [String: Any] {
        return try await call(method: "desk.agent.status", params: ["task_id": taskId])
    }

    func deskAgentCancel(taskId: String) async throws -> [String: Any] {
        return try await call(method: "desk.agent.cancel", params: ["task_id": taskId])
    }

    func deskMlxStatus() async throws -> [String: Any] {
        return try await call(method: "desk.mlx.status")
    }

    func deskMlxStart(model: String = "") async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if !model.isEmpty { params["model"] = model }
        return try await call(method: "desk.mlx.start", params: params)
    }

    func deskMlxStop() async throws -> [String: Any] {
        return try await call(method: "desk.mlx.stop")
    }

    func deskMlxModels() async throws -> [String: Any] {
        return try await call(method: "desk.mlx.models")
    }

    func deskSystemInfo() async throws -> [String: Any] {
        return try await call(method: "desk.system.info")
    }

    func deskEventsSubscribe() async throws -> [String: Any] {
        return try await call(method: "desk.events.subscribe")
    }

    func deskEventsRecent(since: Double = 0.0) async throws -> [String: Any] {
        return try await call(method: "desk.events.recent", params: ["since": since])
    }

    func deskEventsPoll(subId: String) async throws -> [String: Any] {
        return try await call(method: "desk.events.poll", params: ["sub_id": subId])
    }

    func deskSessionList(status: String = "", limit: Int = 20) async throws -> [String: Any] {
        var params: [String: Any] = ["limit": limit]
        if !status.isEmpty { params["status"] = status }
        return try await call(method: "desk.session.list", params: params)
    }

    func deskSessionGet(sessionId: String) async throws -> [String: Any] {
        return try await call(method: "desk.session.get", params: ["session_id": sessionId])
    }

    func deskSessionFork(sessionId: String, fromStep: Int = 0) async throws -> [String: Any] {
        return try await call(method: "desk.session.fork", params: ["session_id": sessionId, "from_step": fromStep])
    }

    func deskSessionCreate(name: String, description: String = "") async throws -> [String: Any] {
        var params: [String: Any] = ["name": name]
        if !description.isEmpty { params["description"] = description }
        return try await call(method: "desk.session.create", params: params)
    }

    func deskSessionUpdate(sessionId: String, updates: [String: Any]) async throws -> [String: Any] {
        return try await call(method: "desk.session.update", params: ["session_id": sessionId, "updates": updates])
    }

    func deskSessionDelete(sessionId: String) async throws -> [String: Any] {
        return try await call(method: "desk.session.delete", params: ["session_id": sessionId])
    }

    func deskPermissionCheck(toolName: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var p: [String: Any] = ["tool_name": toolName]
        if !params.isEmpty { p["params"] = params }
        return try await call(method: "desk.permission.check", params: p)
    }

    func deskPermissionApprove(toolName: String, scope: String = "*") async throws -> [String: Any] {
        return try await call(method: "desk.permission.approve", params: ["tool_name": toolName, "scope": scope])
    }

    func deskPermissionDeny(toolName: String, scope: String = "*") async throws -> [String: Any] {
        return try await call(method: "desk.permission.deny", params: ["tool_name": toolName, "scope": scope])
    }

    func deskPermissionList() async throws -> [String: Any] {
        return try await call(method: "desk.permission.list")
    }

    func deskPermissionReset() async throws -> [String: Any] {
        return try await call(method: "desk.permission.reset")
    }

    func deskTemplateList(category: String = "") async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if !category.isEmpty { params["category"] = category }
        return try await call(method: "desk.template.list", params: params)
    }

    func deskTemplateGet(templateId: String) async throws -> [String: Any] {
        return try await call(method: "desk.template.get", params: ["template_id": templateId])
    }

    func deskTemplateRun(templateId: String, variables: [String: String]? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["template_id": templateId]
        if let v = variables { params["variables"] = v }
        return try await call(method: "desk.template.run", params: params)
    }

    // MARK: - 辅助方法

    private func setError(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastError = msg
            self?.isConnected = false
        }
    }

    deinit {
        reconnectTimer?.invalidate()
        if socketFd >= 0 {
            close(socketFd)
        }
    }
}

// MARK: - 错误类型

enum IPCError: Error, LocalizedError {
    case disconnected
    case timeout
    case invalidRequest
    case invalidResponse
    case rpcError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .disconnected:      return "IPC 未连接"
        case .timeout:           return "IPC 调用超时"
        case .invalidRequest:    return "无效的请求"
        case .invalidResponse:   return "无效的响应"
        case .rpcError(_, let m): return "RPC 错误: \(m)"
        }
    }
}

// MARK: - MLX HTTP API (REST, not JSON-RPC)
extension IPCClient {
    private static let mlxHTTPBase = "http://127.0.0.1:11435"

    func ocr(image: String, model: String, outputFormat: String = "markdown") async throws -> String {
        let url = URL(string: "\(IPCClient.mlxHTTPBase)/v1/ocr")!
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
        let url = URL(string: "\(IPCClient.mlxHTTPBase)/v1/ocr/models")!
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