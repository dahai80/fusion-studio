// Callers: AgentStudioView, LogPanelView, ProfilerView, TaskQueueView — all module views needing Python backend data.
// Affected API: AgentBridge @MainActor ObservableObject (published properties + async methods).
// Data schemas: AgentGraphModel, AgentEventModel, BridgeError, ExecuteRequest, ModelInfo.
// Communication: UDS JSON-RPC 2.0 via IPCClient (no more HTTP).
// User instruction: "坚各个产品的边界和原则，fusion-studio的GUI基本定稿了，现在把功能做起来，开始吧"

import Foundation
import Combine
import os.log

enum JSONValue: Codable, Equatable {
    case string(String)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode JSONValue")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        }
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
}

struct PositionModel: Codable, Equatable {
    var x: Double
    var y: Double
}

struct NodeConfigModel: Codable, Equatable {
    var id: String
    var type: String
    var config: [String: JSONValue]
    var position: PositionModel?
}

struct EdgeModel: Codable, Equatable {
    var id: String
    var source: String
    var target: String
    var condition: String?
}

struct AgentGraphModel: Codable, Equatable {
    var id: UUID
    var name: String
    var nodes: [NodeConfigModel]
    var edges: [EdgeModel]
    var created_at: String
}

struct AgentEventModel: Codable, Equatable {
    var type: String
    var node_id: String?
    var data: [String: JSONValue]?
    var timestamp: String?
}

struct MLXModelInfo: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var object: String?
    var owned_by: String?
}

enum BridgeError: Error, Equatable {
    case notConnected
    case ipcError(String)
    case decodeError(String)
    case rpcError(code: Int, message: String)
}

struct ExecuteRequest: Codable, Equatable {
    var input: String
}

struct PlanStepModel: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var description: String
    var status: String
    var result: String?
}

struct PlanModel: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var task: String
    var status: String
    var steps: [PlanStepModel]
    var context: String
    var created_at: String
}

struct RAGResultModel: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var answer: String
    var sources: [String]
    var query: String
}

struct MemoryEntryModel: Codable, Equatable, Identifiable {
    var id: String
    var content: String
    var scope: String
    var tags: String
    var importance: Int
    var timestamp: String
    var tier: String
}

struct SafetyCheckModel: Codable, Equatable {
    var level: String
    var violations: [String]
    var approved: Bool
}

struct SafetyActionModel: Codable, Equatable, Identifiable {
    var id: String
    var category: String
    var status: String
    var content: String
    var reason: String = ""
}

struct TemplateModel: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var category: String
    var description: String
    var variables: [String]
}

struct DeployFormatModel: Codable, Equatable, Identifiable {
    var id: String
    var format: String
    var description: String
}

struct AgentModel: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var model: String
    var system_prompt: String
    var temperature: Double
    var max_tokens: Int
    var tools: [String]
    var capabilities: [String]
    var safety_level: String
    var tags: [String]
    var author: String
    var description: String
    var version: String
    var created_at: String
    var skills: [String]
    var has_soul: Bool
}

struct MarketplaceEntryModel: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var author: String
    var description: String
    var category: String
    var tags: [String]
    var version: String
    var rating: Double
    var downloads: Int
    var created_at: String
    var updated_at: String
}

@MainActor
final class AgentBridge: ObservableObject {

    @Published var isConnected: Bool = false
    @Published var graphs: [AgentGraphModel] = []
    @Published var events: [AgentEventModel] = []
    @Published var isExecuting: Bool = false
    @Published var lastError: BridgeError?
    @Published var models: [MLXModelInfo] = []
    @Published var chatMessages: [ChatMessageRecord] = []
    @Published var isInferring: Bool = false

    // MARK: - Module Published Properties

    @Published var plans: [PlanModel] = []
    @Published var currentPlan: PlanModel?
    @Published var ragResults: [RAGResultModel] = []
    @Published var memoryEntries: [MemoryEntryModel] = []
    @Published var memoryCount: Int = 0
    @Published var safetyCheckResult: SafetyCheckModel?
    @Published var safetyPendingActions: [SafetyActionModel] = []
    @Published var templates: [TemplateModel] = []
    @Published var deployFormats: [DeployFormatModel] = []

    // MARK: - Agent & Marketplace Published Properties

    @Published var agents: [AgentModel] = []
    @Published var currentAgent: AgentModel?
    @Published var agentSkills: [String] = []
    @Published var agentSoul: String = ""
    @Published var marketplaceEntries: [MarketplaceEntryModel] = []
    @Published var marketplaceCategories: [String] = []

    // Callers: TokenBudgetView, VectorSearchView, MemoryRelevantView, ToolBrowserView, SafetyView. Affected API: all new IPC bridge methods. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
    private let logger = Logger(subsystem: "com.fusion.studio", category: "AgentBridge")
    var ipcClient: IPCClient?

    func setIPCClient(_ client: IPCClient) {
        self.ipcClient = client
        client.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
        logger.info("AgentBridge connected to IPCClient")
    }

    // MARK: - Health Check

    func checkHealth() async throws -> Bool {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        do {
            let result = try await client.call(method: "ping")
            let pong = result["pong"] as? Bool ?? false
            self.isConnected = pong
            logger.info("checkHealth: connected=\(pong)")
            return pong
        } catch let error as IPCError {
            self.isConnected = false
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("checkHealth: \(error)")
            throw bridgeErr
        }
    }

    func fullHealthCheck() async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        let result = try await client.call(method: "env.health_check")
        self.isConnected = true
        return result
    }

    func repair(itemId: String) async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: "env.repair", params: ["item_id": itemId])
    }

    func repairAll() async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: "env.repair_all")
    }

    // MARK: - Graph Operations

    func fetchGraphs() async throws -> [AgentGraphModel] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        do {
            let result = try await client.call(method: "graph.list")
            let graphsData = result["graphs"] as? [[String: Any]] ?? []
            var parsed: [AgentGraphModel] = []
            for g in graphsData {
                if let model = Self.parseGraphModel(from: g) {
                    parsed.append(model)
                }
            }
            self.graphs = parsed
            logger.info("fetchGraphs: received \(parsed.count) graphs")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("fetchGraphs: \(error)")
            throw bridgeErr
        }
    }

    func createGraph(name: String, nodes: [NodeConfigModel], edges: [EdgeModel]) async throws -> AgentGraphModel {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("createGraph: name=\(name) nodes=\(nodes.count) edges=\(edges.count)")

        var nodesParam: [[String: Any]] = []
        for n in nodes {
            nodesParam.append([
                "id": n.id,
                "type": n.type,
                "label": n.type,
            ])
        }

        var edgesParam: [[String: Any]] = []
        for e in edges {
            var edgeDict: [String: Any] = [
                "source_id": e.source,
                "target_id": e.target,
            ]
            if let cond = e.condition {
                edgeDict["label"] = cond
            }
            edgesParam.append(edgeDict)
        }

        do {
            let result = try await client.call(method: "graph.create", params: [
                "name": name,
                "nodes": nodesParam,
                "edges": edgesParam,
            ])

            guard let model = Self.parseGraphModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse graph.create response")
            }
            logger.info("createGraph: created id=\(model.id)")
            return model
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("createGraph: \(error)")
            throw bridgeErr
        }
    }

    func graphGet(graphId: String) async throws -> AgentGraphModel? {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("graphGet: graphId=\(graphId)")
        do {
            let result = try await client.graphGet(graphId: graphId)
            guard let graphData = result["graph"] as? [String: Any] else {
                return nil
            }
            return Self.parseGraphModel(from: graphData)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("graphGet: \(error)")
            throw bridgeErr
        }
    }

    func deleteGraph(id: UUID) async throws {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("deleteGraph: id=\(id)")
        do {
            _ = try await client.call(method: "graph.delete", params: ["graph_id": id.uuidString])
            logger.info("deleteGraph: deleted id=\(id)")
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("deleteGraph: \(error)")
            throw bridgeErr
        }
    }

    func executeGraph(id: UUID, input: String) async throws {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("executeGraph: id=\(id)")
        self.isExecuting = true
        self.events = []

        do {
            let result = try await client.call(method: "graph.execute", params: [
                "graph_id": id.uuidString,
                "input": input,
            ])

            let eventsData = result["events"] as? [[String: Any]] ?? []
            var parsed: [AgentEventModel] = []
            for ev in eventsData {
                if let model = Self.parseEventModel(from: ev) {
                    parsed.append(model)
                }
            }
            self.events = parsed
            self.isExecuting = false
            logger.info("executeGraph: received \(parsed.count) events")
        } catch let error as IPCError {
            self.isExecuting = false
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("executeGraph: \(error)")
            throw bridgeErr
        } catch {
            self.isExecuting = false
            let bridgeErr = BridgeError.decodeError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("executeGraph decode: \(error)")
            throw bridgeErr
        }
    }

    func cancelExecution() {
        logger.info("cancelExecution")
        self.isExecuting = false
    }

    func updateGraph(id: UUID, name: String? = nil, nodes: [NodeConfigModel]? = nil, edges: [EdgeModel]? = nil) async throws -> AgentGraphModel? {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("updateGraph: id=\(id)")
        var params: [String: Any] = ["graph_id": id.uuidString]
        if let name { params["name"] = name }
        if let nodes {
            params["nodes"] = nodes.map { node -> [String: Any] in
                let label: String
                if case .string(let v) = node.config["label"] { label = v } else { label = "" }
                return ["id": node.id, "type": node.type, "label": label]
            }
        }
        if let edges {
            params["edges"] = edges.map { ["source_id": $0.source, "target_id": $0.target, "label": $0.condition ?? ""] }
        }
        do {
            let result = try await client.call(method: "graph.update", params: params)
            return Self.parseGraphModel(from: result)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("updateGraph: \(error)")
            throw bridgeErr
        }
    }

    func fetchTools() async throws -> [[String: Any]] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("fetchTools")
        do {
            let result = try await client.call(method: "tool.list", params: [:])
            return result["tools"] as? [[String: Any]] ?? []
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("fetchTools: \(error)")
            throw bridgeErr
        }
    }

    func getTool(name: String) async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("getTool: \(name)")
        do {
            return try await client.call(method: "tool.get", params: ["name": name])
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("getTool: \(error)")
            throw bridgeErr
        }
    }

    func listSessions() async throws -> [[String: Any]] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("listSessions")
        do {
            let result = try await client.call(method: "session.list", params: [:]) as [String: Any]
            if let sessions = result["sessions"] as? [[String: Any]] {
                return sessions
            }
            return []
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("listSessions: \(error)")
            throw bridgeErr
        }
    }

    // MARK: - Cron Management

    func cronRegister(id: String = "", name: String, expression: String, graphId: String = "", enabled: Bool = true, inputData: String = "", maxRetries: Int = 0) async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        var params: [String: Any] = [
            "name": name,
            "expression": expression,
            "enabled": enabled,
            "max_retries": maxRetries,
        ]
        if !id.isEmpty { params["id"] = id }
        if !graphId.isEmpty { params["graph_id"] = graphId }
        if !inputData.isEmpty { params["input_data"] = inputData }
        logger.info("cronRegister: \(name) \(expression)")
        do {
            return try await client.call(method: "cron.register", params: params)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func cronUnregister(id: String) async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("cronUnregister: \(id)")
        do {
            return try await client.call(method: "cron.unregister", params: ["id": id])
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func cronList() async throws -> [[String: Any]] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("cronList")
        do {
            let result = try await client.call(method: "cron.list", params: [:]) as [String: Any]
            if let jobs = result["jobs"] as? [[String: Any]] {
                return jobs
            }
            return []
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("cronList: \(error)")
            throw bridgeErr
        }
    }

    func cronListExecutions(jobId: String = "", limit: Int = 20) async throws -> [[String: Any]] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        var params: [String: Any] = ["limit": limit]
        if !jobId.isEmpty { params["job_id"] = jobId }
        logger.info("cronListExecutions: jobId=\(jobId)")
        do {
            let result = try await client.call(method: "cron.list_executions", params: params) as [String: Any]
            if let executions = result["executions"] as? [[String: Any]] {
                return executions
            }
            return []
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func hardwareMetrics() async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("hardwareMetrics")
        do {
            return try await client.hardwareMetrics()
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("hardwareMetrics: \(error)")
            throw bridgeErr
        }
    }

    func knowledgeSearch(query: String, limit: Int = 5) async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("knowledgeSearch: query=\(query)")
        do {
            return try await client.knowledgeSearch(query: query, limit: limit)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("knowledgeSearch: \(error)")
            throw bridgeErr
        }
    }

    // MARK: - MLX Operations

    func fetchModels() async throws -> [MLXModelInfo] {
        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/models") else {
            throw BridgeError.ipcError("Invalid MLX URL: \(baseURL)")
        }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 10
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else {
                throw BridgeError.ipcError("Non-HTTP response from MLX")
            }
            guard httpResp.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                logger.error("fetchModels: HTTP \(httpResp.statusCode) — \(body)")
                throw BridgeError.ipcError("MLX returned HTTP \(httpResp.statusCode)")
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelList = json["data"] as? [[String: Any]] else {
                throw BridgeError.decodeError("Invalid /v1/models response")
            }
            var parsed: [MLXModelInfo] = []
            for m in modelList {
                let id = m["id"] as? String ?? ""
                parsed.append(MLXModelInfo(
                    id: id,
                    name: id,
                    object: m["object"] as? String,
                    owned_by: m["owned_by"] as? String
                ))
            }
            self.models = parsed
            logger.info("fetchModels: received \(parsed.count) models from \(baseURL)")
            return parsed
        } catch let error as BridgeError {
            self.lastError = error
            throw error
        } catch {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("fetchModels: \(error)")
            throw bridgeErr
        }
    }

    func startMLX(model: String = "") async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        var params: [String: Any] = [:]
        if !model.isEmpty {
            params["model"] = model
        }
        return try await client.call(method: "mlx.start", params: params)
    }

    func stopMLX() async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: "mlx.stop")
    }

    func restartMLX(model: String = "") async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        var params: [String: Any] = [:]
        if !model.isEmpty { params["model"] = model }
        return try await client.call(method: "mlx.restart", params: params)
    }

    func mlxStatus() async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: "mlx.status")
    }

    func mlxSetModel(model: String) async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: "mlx.set_model", params: ["model": model])
    }

    // MARK: - Project Chat

    func sendProjectChat(_ userMessage: String) async throws -> String {
        let pm = FusionProjectManager.shared
        guard let project = pm.activeProject else {
            throw BridgeError.notConnected
        }

        if pm.activeSession == nil {
            _ = pm.createSession(projectId: project.id, title: String(userMessage.prefix(40)), model: project.settings.defaultModel)
        }

        let userRecord = ChatMessageRecord(role: "user", content: userMessage)
        chatMessages.append(userRecord)
        if let session = pm.activeSession {
            pm.addMessage(toSession: session.id, role: "user", content: userMessage)
        }

        let systemPrompt = await ContextAssembler.shared.assembleWithRAG(project: pm.activeProject, query: userMessage)
        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for msg in chatMessages {
            messages.append(["role": msg.role, "content": msg.content])
        }

        isInferring = true
        defer { isInferring = false }

        let projectSettings = pm.activeProject?.settings ?? ProjectSettings()
        let response = try await inferStream(
            messages: messages,
            model: projectSettings.defaultModel,
            temperature: projectSettings.temperature,
            maxTokens: projectSettings.maxTokens,
            onToken: { token in
                Task { @MainActor in
                    if let lastIdx = self.chatMessages.indices.last, self.chatMessages[lastIdx].role == "assistant" {
                        self.chatMessages[lastIdx].content += token
                    }
                }
            }
        )

        let assistantRecord = ChatMessageRecord(role: "assistant", content: response)
        chatMessages.append(assistantRecord)
        if let session = pm.activeSession {
            pm.addMessage(toSession: session.id, role: "assistant", content: response)
        }

        return response
    }

    func clearChat() {
        chatMessages = []
        FusionProjectManager.shared.activeSession = nil
    }

    func loadSessionMessages(_ session: ProjectSession) {
        chatMessages = session.messages
    }

    func infer(messages: [[String: String]], model: String = "", temperature: Double = 0.7, maxTokens: Int = 2048, effort: String = "medium", thinking: Bool = false) async throws -> String {
        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw BridgeError.ipcError("Invalid MLX URL: \(baseURL)")
        }
        var body: [String: Any] = [
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
        ]
        if !model.isEmpty {
            body["model"] = model
        }
        if !effort.isEmpty {
            body["reasoning_effort"] = effort
        }
        if thinking {
            body["chat_template_kwargs"] = ["enable_thinking": true]
        }
        guard let requestData = try? JSONSerialization.data(withJSONObject: body) else {
            throw BridgeError.ipcError("Failed to encode request")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw BridgeError.ipcError("Non-HTTP response from MLX")
        }
        guard httpResp.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            logger.error("infer: HTTP \(httpResp.statusCode) — \(responseBody)")
            throw BridgeError.ipcError("MLX inference returned HTTP \(httpResp.statusCode)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw BridgeError.decodeError("Invalid /v1/chat/completions response")
        }
        var content = message["content"] as? String ?? ""
        if thinking, let reasoning = message["reasoning_content"] as? String, !reasoning.isEmpty {
            content = "<think>\n\(reasoning)\n</think>\n\n\(content)"
        }
        logger.info("infer: received \(content.count) chars, effort=\(effort), thinking=\(thinking)")
        return content
    }

    func inferStream(messages: [[String: String]], model: String = "", temperature: Double = 0.7, maxTokens: Int = 2048, effort: String = "medium", thinking: Bool = false, onToken: @escaping (String) -> Void) async throws -> String {
        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw BridgeError.ipcError("Invalid MLX URL: \(baseURL)")
        }
        var body: [String: Any] = [
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": true,
        ]
        if !model.isEmpty {
            body["model"] = model
        }
        if !effort.isEmpty {
            body["reasoning_effort"] = effort
        }
        if thinking {
            body["chat_template_kwargs"] = ["enable_thinking": true]
        }
        guard let requestData = try? JSONSerialization.data(withJSONObject: body) else {
            throw BridgeError.ipcError("Failed to encode request")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw BridgeError.ipcError("MLX streaming returned non-200")
        }

        var fullContent = ""
        var thinkingContent = ""
        var isInThinking = thinking
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let delta = firstChoice["delta"] as? [String: Any] else {
                continue
            }
            if let token = delta["content"] as? String, !token.isEmpty {
                if isInThinking {
                    thinkingContent += token
                } else {
                    fullContent += token
                    onToken(token)
                }
            }
            if let reasoningToken = delta["reasoning_content"] as? String, !reasoningToken.isEmpty {
                thinkingContent += reasoningToken
            }
            if delta["content"] != nil || delta["reasoning_content"] != nil { continue }
            if let finishReason = firstChoice["finish_reason"] as? String, finishReason == "stop" {
                isInThinking = false
            }
        }
        if !thinkingContent.isEmpty {
            fullContent = " phy\n\(thinkingContent)\n \n\n\(fullContent)"
        }
        logger.info("inferStream: received \(fullContent.count) chars total")
        return fullContent
    }

    // MARK: - Planner Operations

    func plannerCreatePlan(task: String, context: String = "", files: [String]? = nil) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("plannerCreatePlan: task=\(task)")
        do {
            let result = try await client.plannerCreatePlan(task: task, context: context, files: files)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.create_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func plannerGetPlan(planId: String) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerGetPlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.get_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func plannerApprovePlan(planId: String) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerApprovePlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.approve_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func plannerRejectPlan(planId: String, reason: String = "") async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerRejectPlan(planId: planId, reason: reason)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.reject_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func plannerExecuteStep(planId: String, stepId: String) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerExecuteStep(planId: planId, stepId: stepId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.execute_step response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func plannerExecutePlan(planId: String) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerExecutePlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.execute_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchPlans(status: String = "") async throws -> [PlanModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerListPlans(status: status)
            let plansData = result["plans"] as? [[String: Any]] ?? []
            var parsed: [PlanModel] = []
            for p in plansData {
                if let plan = Self.parsePlanModel(from: p) {
                    parsed.append(plan)
                }
            }
            self.plans = parsed
            logger.info("fetchPlans: received \(parsed.count) plans")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func plannerCancelPlan(planId: String) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerCancelPlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.cancel_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - RAG Operations

    func ragQuery(query: String, config: [String: Any] = [:], model: String = "", systemPrompt: String = "") async throws -> RAGResultModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("ragQuery: query=\(query)")
        do {
            let result = try await client.ragQuery(query: query, config: config, model: model, systemPrompt: systemPrompt)
            let ragResult = RAGResultModel(
                answer: result["answer"] as? String ?? "",
                sources: result["sources"] as? [String] ?? [],
                query: query
            )
            self.ragResults.append(ragResult)
            return ragResult
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func ragRetrieve(query: String, config: [String: Any] = [:]) async throws -> [String] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.ragRetrieve(query: query, config: config)
            return result["documents"] as? [String] ?? []
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - Memory Operations

    func memoryStore(content: String, scope: String = "default", tags: String = "", importance: Int = 5, metadata: [String: Any]? = nil, tier: String = "") async throws -> MemoryEntryModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("memoryStore: scope=\(scope)")
        do {
            let result = try await client.memoryStore(content: content, scope: scope, tags: tags, importance: importance, metadata: metadata, tier: tier)
            guard let entry = Self.parseMemoryEntry(from: result) else {
                throw BridgeError.decodeError("Failed to parse memory.store response")
            }
            return entry
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func memoryRecall(query: String, scope: String = "", limit: Int = 10, minImportance: Int = 0, tier: String = "") async throws -> [MemoryEntryModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryRecall(query: query, scope: scope, limit: limit, minImportance: minImportance, tier: tier)
            let entriesData = result["entries"] as? [[String: Any]] ?? []
            var parsed: [MemoryEntryModel] = []
            for e in entriesData {
                if let entry = Self.parseMemoryEntry(from: e) {
                    parsed.append(entry)
                }
            }
            self.memoryEntries = parsed
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchRecentMemories(scope: String = "", limit: Int = 20, minImportance: Int = 0, tier: String = "") async throws -> [MemoryEntryModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryListRecent(scope: scope, limit: limit, minImportance: minImportance, tier: tier)
            let entriesData = result["entries"] as? [[String: Any]] ?? []
            var parsed: [MemoryEntryModel] = []
            for e in entriesData {
                if let entry = Self.parseMemoryEntry(from: e) {
                    parsed.append(entry)
                }
            }
            self.memoryEntries = parsed
            logger.info("fetchRecentMemories: received \(parsed.count) entries")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func memoryGet(entryId: String) async throws -> MemoryEntryModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryGet(entryId: entryId)
            guard let entry = Self.parseMemoryEntry(from: result) else {
                throw BridgeError.decodeError("Failed to parse memory.get response")
            }
            return entry
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func memoryDelete(entryId: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryDelete(entryId: entryId)
            return result["deleted"] as? Bool ?? false
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func memoryDeleteScope(scope: String) async throws -> Int {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryDeleteScope(scope: scope)
            return result["count"] as? Int ?? 0
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchMemoryCount(scope: String = "", tier: String = "") async throws -> Int {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryCount(scope: scope, tier: tier)
            let count = result["count"] as? Int ?? 0
            self.memoryCount = count
            return count
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - Safety Operations

    func safetyCheck(content: String, context: String = "") async throws -> SafetyCheckModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("safetyCheck")
        do {
            let result = try await client.safetyCheck(content: content, context: context)
            let check = SafetyCheckModel(
                level: result["level"] as? String ?? "L1",
                violations: result["violations"] as? [String] ?? [],
                approved: result["approved"] as? Bool ?? true
            )
            self.safetyCheckResult = check
            return check
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func safetyEvaluateAction(category: String, content: String = "", context: String = "") async throws -> SafetyActionModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyEvaluateAction(category: category, content: content, context: context)
            return SafetyActionModel(
                id: result["action_id"] as? String ?? UUID().uuidString,
                category: category,
                status: result["status"] as? String ?? "pending",
                content: content
            )
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func safetyApproveAction(actionId: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyApproveAction(actionId: actionId)
            return result["approved"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func safetyRejectAction(actionId: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyRejectAction(actionId: actionId)
            return result["rejected"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchPendingSafetyActions() async throws -> [SafetyActionModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyGetPendingActions()
            let actionsData = result["actions"] as? [[String: Any]] ?? []
            var parsed: [SafetyActionModel] = []
            for a in actionsData {
                parsed.append(SafetyActionModel(
                    id: a["action_id"] as? String ?? a["id"] as? String ?? UUID().uuidString,
                    category: a["category"] as? String ?? "",
                    status: a["status"] as? String ?? "pending",
                    content: a["content"] as? String ?? ""
                ))
            }
            self.safetyPendingActions = parsed
            logger.info("fetchPendingSafetyActions: \(parsed.count) pending")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func safetyAddPolicy(category: String, description: String = "", defaultLevel: String = "L2", requiresDiff: Bool = false) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyAddPolicy(category: category, description: description, defaultLevel: defaultLevel, requiresDiff: requiresDiff)
            return result["added"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - Template Operations

    func fetchTemplates(category: String = "") async throws -> [TemplateModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.templateList(category: category)
            let templatesData = result["templates"] as? [[String: Any]] ?? []
            var parsed: [TemplateModel] = []
            for t in templatesData {
                parsed.append(TemplateModel(
                    id: t["template_id"] as? String ?? t["id"] as? String ?? UUID().uuidString,
                    name: t["name"] as? String ?? "",
                    category: t["category"] as? String ?? "",
                    description: t["description"] as? String ?? "",
                    variables: t["variables"] as? [String] ?? []
                ))
            }
            self.templates = parsed
            logger.info("fetchTemplates: received \(parsed.count) templates")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func templateGet(templateId: String) async throws -> TemplateModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.templateGet(templateId: templateId)
            return TemplateModel(
                id: result["template_id"] as? String ?? result["id"] as? String ?? templateId,
                name: result["name"] as? String ?? "",
                category: result["category"] as? String ?? "",
                description: result["description"] as? String ?? "",
                variables: result["variables"] as? [String] ?? []
            )
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func templateInstantiate(templateId: String, variables: [String: String]? = nil) async throws -> AgentGraphModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("templateInstantiate: templateId=\(templateId)")
        do {
            let result = try await client.templateInstantiate(templateId: templateId, variables: variables)
            guard let graph = Self.parseGraphModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse template.instantiate response")
            }
            return graph
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - Deploy Operations

    func deployExport(graphId: String, format: String = "json", filepath: String = "", withServer: Bool = true, port: Int = 8000) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("deployExport: graphId=\(graphId) format=\(format)")
        do {
            return try await client.deployExport(graphId: graphId, format: format, filepath: filepath, withServer: withServer, port: port)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func deployImport(filepath: String) async throws -> AgentGraphModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("deployImport: filepath=\(filepath)")
        do {
            let result = try await client.deployImport(filepath: filepath)
            guard let graph = Self.parseGraphModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse deploy.import response")
            }
            return graph
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchDeployFormats() async throws -> [DeployFormatModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.deployListFormats()
            let formatsData = result["formats"] as? [[String: Any]] ?? []
            var parsed: [DeployFormatModel] = []
            for f in formatsData {
                parsed.append(DeployFormatModel(
                    id: f["format"] as? String ?? UUID().uuidString,
                    format: f["format"] as? String ?? "",
                    description: f["description"] as? String ?? ""
                ))
            }
            self.deployFormats = parsed
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - Agent Operations

    func agentCreate(name: String, model: String = "", systemPrompt: String = "", temperature: Double = 0.7, maxTokens: Int = 4096, tools: [String] = [], capabilities: [String] = [], safetyLevel: String = "L1", tags: [String] = [], description: String = "", soul: String = "") async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentCreate: name=\(name)")
        do {
            let result = try await client.agentCreate(name: name, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags, description: description, soul: soul)
            guard let agent = Self.parseAgentModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse agent.create response")
            }
            self.agents.append(agent)
            self.currentAgent = agent
            return agent
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
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
            self.currentAgent = agent
            return agent
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchAgents(tags: [String] = []) async throws -> [AgentModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.agentList(tags: tags)
            let agentsData = result["agents"] as? [[String: Any]] ?? []
            var parsed: [AgentModel] = []
            for a in agentsData {
                if let agent = Self.parseAgentModel(from: a) {
                    parsed.append(agent)
                }
            }
            self.agents = parsed
            logger.info("fetchAgents: received \(parsed.count) agents")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func agentUpdate(agentId: String, name: String? = nil, model: String? = nil, systemPrompt: String? = nil, temperature: Double? = nil, maxTokens: Int? = nil, tools: [String]? = nil, capabilities: [String]? = nil, safetyLevel: String? = nil, tags: [String]? = nil, description: String? = nil) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentUpdate: id=\(agentId)")
        do {
            let result = try await client.agentUpdate(agentId: agentId, name: name, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags, description: description)
            guard let agent = Self.parseAgentModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse agent.update response")
            }
            if let idx = self.agents.firstIndex(where: { $0.id == agentId }) {
                self.agents[idx] = agent
            }
            self.currentAgent = agent
            return agent
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func agentDelete(agentId: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentDelete: id=\(agentId)")
        do {
            let result = try await client.agentDelete(agentId: agentId)
            let deleted = result["deleted"] as? Bool ?? false
            if deleted {
                self.agents.removeAll { $0.id == agentId }
                if self.currentAgent?.id == agentId {
                    self.currentAgent = nil
                }
            }
            return deleted
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func agentConfigure(agentId: String, config: [String: Any]) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentConfigure: id=\(agentId)")
        do {
            let result = try await client.agentConfigure(agentId: agentId, config: config)
            guard let agent = Self.parseAgentModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse agent.configure response")
            }
            if let idx = self.agents.firstIndex(where: { $0.id == agentId }) {
                self.agents[idx] = agent
            }
            self.currentAgent = agent
            return agent
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func agentExecute(agentId: String, input: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentExecute: id=\(agentId)")
        do {
            return try await client.agentExecute(agentId: agentId, input: input)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchAgentSkills(agentId: String) async throws -> [String] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.agentListSkills(agentId: agentId)
            let skills = result["skills"] as? [String] ?? []
            self.agentSkills = skills
            return skills
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func agentAddSkill(agentId: String, skillName: String, skillDef: [String: Any] = [:]) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentAddSkill: id=\(agentId) skill=\(skillName)")
        do {
            let result = try await client.agentAddSkill(agentId: agentId, skillName: skillName, skillDef: skillDef)
            let added = result["added"] as? Bool ?? true
            if added {
                if !self.agentSkills.contains(skillName) {
                    self.agentSkills.append(skillName)
                }
            }
            return added
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func agentDeleteSkill(agentId: String, skillName: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentDeleteSkill: id=\(agentId) skill=\(skillName)")
        do {
            let result = try await client.agentDeleteSkill(agentId: agentId, skillName: skillName)
            let deleted = result["deleted"] as? Bool ?? false
            if deleted {
                self.agentSkills.removeAll { $0 == skillName }
            }
            return deleted
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchAgentSoul(agentId: String) async throws -> String {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.agentGetSoul(agentId: agentId)
            let soul = result["soul"] as? String ?? ""
            self.agentSoul = soul
            return soul
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func agentUpdateSoul(agentId: String, soul: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentUpdateSoul: id=\(agentId)")
        do {
            let result = try await client.agentUpdateSoul(agentId: agentId, soul: soul)
            let updated = result["updated"] as? Bool ?? true
            if updated {
                self.agentSoul = soul
            }
            return updated
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - Marketplace Operations

    func marketplaceSearch(query: String = "", category: String = "", tags: [String] = []) async throws -> [MarketplaceEntryModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.marketplaceSearch(query: query, category: category, tags: tags)
            let entriesData = result["entries"] as? [[String: Any]] ?? []
            var parsed: [MarketplaceEntryModel] = []
            for e in entriesData {
                if let entry = Self.parseMarketplaceEntry(from: e) {
                    parsed.append(entry)
                }
            }
            self.marketplaceEntries = parsed
            logger.info("marketplaceSearch: found \(parsed.count) entries")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func marketplaceGet(entryId: String) async throws -> MarketplaceEntryModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.marketplaceGet(entryId: entryId)
            guard let entry = Self.parseMarketplaceEntry(from: result) else {
                throw BridgeError.decodeError("Failed to parse marketplace.get response")
            }
            return entry
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func marketplacePublish(name: String, author: String = "", description: String = "", category: String = "", tags: [String] = [], version: String = "1.0.0", graphData: [String: Any] = [:]) async throws -> MarketplaceEntryModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("marketplacePublish: name=\(name)")
        do {
            let result = try await client.marketplacePublish(name: name, author: author, description: description, category: category, tags: tags, version: version, graphData: graphData)
            guard let entry = Self.parseMarketplaceEntry(from: result) else {
                throw BridgeError.decodeError("Failed to parse marketplace.publish response")
            }
            return entry
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func marketplaceUninstall(entryId: String) async throws -> Bool {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("marketplaceUninstall: \(entryId)")
        do {
            let result = try await client.call(method: "marketplace.uninstall", params: ["entry_id": entryId]) as [String: Any]
            return result["success"] as? Bool ?? false
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("marketplaceUninstall: \(error)")
            throw bridgeErr
        }
    }

    func marketplaceUnpublish(entryId: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.marketplaceUnpublish(entryId: entryId)
            return result["unpublished"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchMarketplaceCategories() async throws -> [String] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.marketplaceListCategories()
            let categories = result["categories"] as? [String] ?? []
            self.marketplaceCategories = categories
            return categories
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func marketplaceInstall(entryId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("marketplaceInstall: entryId=\(entryId)")
        do {
            let result = try await client.marketplaceInstall(entryId: entryId)
            guard let agent = Self.parseAgentModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse marketplace.install response")
            }
            self.agents.append(agent)
            return agent
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - Parsing Helpers

    private static func parseGraphModel(from dict: [String: Any]) -> AgentGraphModel? {
        guard let graphId = dict["graph_id"] as? String ?? dict["id"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }
        let uuid = UUID(uuidString: graphId) ?? UUID()

        var nodes: [NodeConfigModel] = []
        if let nodesDict = dict["nodes"] as? [String: [String: Any]] {
            for (nodeId, nodeData) in nodesDict {
                var config: [String: JSONValue] = [:]
                for (k, v) in nodeData {
                    if let jv = anyToJSONValue(v) {
                        config[k] = jv
                    }
                }
                nodes.append(NodeConfigModel(
                    id: nodeId,
                    type: nodeData["type"] as? String ?? "llm",
                    config: config,
                    position: nil
                ))
            }
        } else if let nodesArray = dict["nodes"] as? [[String: Any]] {
            for nodeData in nodesArray {
                let nodeId = nodeData["id"] as? String ?? UUID().uuidString
                var config: [String: JSONValue] = [:]
                for (k, v) in nodeData {
                    if k != "id" && k != "type" && k != "label", let jv = anyToJSONValue(v) {
                        config[k] = jv
                    }
                }
                nodes.append(NodeConfigModel(
                    id: nodeId,
                    type: nodeData["type"] as? String ?? "llm",
                    config: config,
                    position: nil
                ))
            }
        }

        var edges: [EdgeModel] = []
        if let edgesArray = dict["edges"] as? [[String: Any]] {
            for edgeData in edgesArray {
                let source = edgeData["source_id"] as? String ?? edgeData["source"] as? String ?? ""
                let target = edgeData["target_id"] as? String ?? edgeData["target"] as? String ?? ""
                let condition = edgeData["label"] as? String ?? edgeData["condition"] as? String
                edges.append(EdgeModel(
                    id: edgeData["id"] as? String ?? UUID().uuidString,
                    source: source,
                    target: target,
                    condition: condition
                ))
            }
        }

        let createdAt: String
        if let ts = dict["created_at"] as? Double {
            let date = Date(timeIntervalSince1970: ts)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            createdAt = formatter.string(from: date)
        } else if let ts = dict["created_at"] as? String {
            createdAt = ts
        } else {
            createdAt = ""
        }

        return AgentGraphModel(
            id: uuid,
            name: name,
            nodes: nodes,
            edges: edges,
            created_at: createdAt
        )
    }

    private static func parseEventModel(from dict: [String: Any]) -> AgentEventModel? {
        guard let type = dict["type"] as? String else { return nil }
        var data: [String: JSONValue]?
        if let d = dict["data"] as? [String: Any] {
            data = [:]
            for (k, v) in d {
                if let jv = anyToJSONValue(v) {
                    data?[k] = jv
                }
            }
        }
        return AgentEventModel(
            type: type,
            node_id: dict["node_id"] as? String,
            data: data,
            timestamp: dict["timestamp"] as? String
        )
    }

    private static func anyToJSONValue(_ value: Any) -> JSONValue? {
        switch value {
        case let s as String: return .string(s)
        case let d as Double: return .double(d)
        case let i as Int: return .double(Double(i))
        case let b as Bool: return .bool(b)
        case let dict as [String: Any]:
            var result: [String: JSONValue] = [:]
            for (k, v) in dict {
                if let jv = anyToJSONValue(v) {
                    result[k] = jv
                }
            }
            return .object(result)
        case let arr as [Any]:
            var result: [JSONValue] = []
            for v in arr {
                if let jv = anyToJSONValue(v) {
                    result.append(jv)
                }
            }
            return .array(result)
        default: return nil
        }
    }

    private static func jsonValueToAny(_ value: JSONValue) -> Any {
        switch value {
        case .string(let s): return s
        case .double(let d): return d
        case .bool(let b): return b
        case .object(let dict): return dict.mapValues { jsonValueToAny($0) }
        case .array(let arr): return arr.map { jsonValueToAny($0) }
        }
    }

    private static func parsePlanModel(from dict: [String: Any]) -> PlanModel? {
        guard let planId = dict["plan_id"] as? String ?? dict["id"] as? String,
              let task = dict["task"] as? String else {
            return nil
        }
        var steps: [PlanStepModel] = []
        if let stepsData = dict["steps"] as? [[String: Any]] {
            for s in stepsData {
                steps.append(PlanStepModel(
                    id: s["step_id"] as? String ?? s["id"] as? String ?? UUID().uuidString,
                    description: s["description"] as? String ?? "",
                    status: s["status"] as? String ?? "pending",
                    result: s["result"] as? String
                ))
            }
        }
        return PlanModel(
            id: planId,
            task: task,
            status: dict["status"] as? String ?? "draft",
            steps: steps,
            context: dict["context"] as? String ?? "",
            created_at: dict["created_at"] as? String ?? ""
        )
    }

    private static func parseMemoryEntry(from dict: [String: Any]) -> MemoryEntryModel? {
        guard let entryId = dict["entry_id"] as? String ?? dict["id"] as? String,
              let content = dict["content"] as? String else {
            return nil
        }
        return MemoryEntryModel(
            id: entryId,
            content: content,
            scope: dict["scope"] as? String ?? "default",
            tags: dict["tags"] as? String ?? "",
            importance: dict["importance"] as? Int ?? 5,
            timestamp: dict["timestamp"] as? String ?? "",
            tier: dict["tier"] as? String ?? "short_term"
        )
    }

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
            has_soul: dict["has_soul"] as? Bool ?? false
        )
    }

    private static func parseMarketplaceEntry(from dict: [String: Any]) -> MarketplaceEntryModel? {
        guard let entryId = dict["entry_id"] as? String ?? dict["id"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }
        return MarketplaceEntryModel(
            id: entryId,
            name: name,
            author: dict["author"] as? String ?? "",
            description: dict["description"] as? String ?? "",
            category: dict["category"] as? String ?? "",
            tags: dict["tags"] as? [String] ?? [],
            version: dict["version"] as? String ?? "1.0.0",
            rating: dict["rating"] as? Double ?? 0.0,
            downloads: dict["downloads"] as? Int ?? 0,
            created_at: dict["created_at"] as? String ?? "",
            updated_at: dict["updated_at"] as? String ?? ""
        )
    }
}
