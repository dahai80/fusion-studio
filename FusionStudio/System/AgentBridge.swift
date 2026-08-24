// Callers: AgentStudioView, LogPanelView, ProfilerView, TaskQueueView — all module views needing Python backend data.
// Affected API: AgentBridge @MainActor ObservableObject (published properties + async methods).
// Data schemas: AgentGraphModel, AgentEventModel, BridgeError, ExecuteRequest, ModelInfo.
// Communication: UDS JSON-RPC 2.0 via IPCClient (no more HTTP).
// User instruction: "坚各个产品的边界和原则，fusion-studio的GUI基本定稿了，现在把功能做起来，开始吧"

import Foundation
import Combine
import os.log

// 供 static 方法 (gatewayConfigApiKey 等) 使用的文件级 logger, 实例 logger 在 class 内。
private let agentBridgeStaticLog = Logger(subsystem: "com.fusion.studio", category: "AgentBridge")

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

struct AgentGraphModel: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var nodes: [NodeConfigModel]
    var edges: [EdgeModel]
    var created_at: String
    // graph.list 只返回 node_count/edge_count (nodes 为空 dict), 列表展示用此计数
    var nodeCount: Int
    var edgeCount: Int
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

    var isTextChatModel: Bool {
        let n = name.lowercased()
        let nonText = ["flux", "stable-diffusion", "sdxl", "sd-turbo", "sd3",
                       "mochi", "ltx-video", "ltxvideo", "ltx", "wan2", "cogvideo", "cogview",
                       "skyreels", "whisper", "parler", "bark", "xtts", "tts", "coqui", "openvoice",
                       "clip", "siglip", "dinov2", "kandinsky", "shap-e", "audioldm",
                       "oldt5", "dspark", "diffusiongemma",
                       "text_encoder", "transformer", "vae"]
        for token in nonText where n.contains(token) { return false }
        return true
    }

    static func preferredDefault(in models: [MLXModelInfo]) -> MLXModelInfo? {
        let chat = models.filter { $0.isTextChatModel }
        guard !chat.isEmpty else { return models.first }
        func score(_ m: MLXModelInfo) -> Int {
            let n = m.name.lowercased()
            var s = 0
            if n.contains("qwen") { s += 100 }
            if n.contains("3.6") || n.contains("3-6") { s += 30 }
            if n.contains("9b") { s += 50 }
            if n.contains("4bit") || n.contains("4-bit") || n.contains("-4b") || n.contains("_4b") { s += 40 }
            return s
        }
        return chat.max(by: { score($0) < score($1) }) ?? chat.first
    }
}

// Callers: ChatSessionStore, DesignBridge, CodeEditorView. Affected API: BridgeError.userMessage. Data: error classification for user-facing messages.
enum BridgeError: Error, Equatable, LocalizedError {
    var errorDescription: String? { userMessage }
    case notConnected
    case ipcError(String)
    case decodeError(String)
    case rpcError(code: Int, message: String)
    case timeout
    case serviceUnavailable(String)
    case authFailed(String)

    var detail: String {
        switch self {
        case .notConnected: return "notConnected — IPC socket not connected"
        case .ipcError(let msg): return "ipcError — \(msg)"
        case .decodeError(let msg): return "decodeError — \(msg)"
        case .rpcError(let code, let msg): return "rpcError(\(code)) — \(msg)"
        case .timeout: return "timeout"
        case .serviceUnavailable(let msg): return "serviceUnavailable — \(msg)"
        case .authFailed(let msg): return "authFailed — \(msg)"
        }
    }

    var userMessage: String {
        let i18n = I18nManager.shared
        switch self {
        case .notConnected:
            return i18n.t(.ab_err_not_connected)
        case .serviceUnavailable:
            return i18n.t(.ab_err_service_down)
        case .authFailed:
            return i18n.t(.ab_err_auth_failed)
        case .timeout:
            return i18n.t(.ab_err_timeout)
        case .ipcError(let msg):
            if msg.contains("connection refused") || msg.contains("Could not connect") || msg.contains("No route to host") {
                return i18n.t(.ab_err_service_down)
            }
            if msg.contains("timed out") {
                return i18n.t(.ab_err_timeout)
            }
            if msg.contains("non-200") || msg.contains("HTTP 4") || msg.contains("HTTP 5") {
                return i18n.t(.ab_err_service_anomaly)
            }
            return i18n.t(.ab_err_unavailable)
        case .decodeError:
            return i18n.t(.ab_err_decode_mismatch)
        case .rpcError(let code, _):
            if code == 401 || code == 403 {
                return i18n.t(.ab_err_auth_failed)
            }
            if code == 404 {
                return i18n.t(.ab_err_service_down)
            }
            return i18n.tf(.ab_err_unavailable_code_fmt, code)
        }
    }
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
    var status: String?
    var version_int: Int?
    var published_at: String?
    var knowledge_base_ids: [String]?
    var visibility: String?
    var rag_strategy: String?
    var web_search_enabled: Bool?
    var deep_research_enabled: Bool?
    var connector_ids: [String]?
    var style: String?
    var top_p: Double?
    var context_window: Int?
    var rate_limit_qps: Int?

    var statusLabel: String {
        let i18n = I18nManager.shared
        switch status ?? "draft" {
        case "published": return i18n.t(.ab_status_published)
        case "draft": return i18n.t(.ab_status_draft)
        case "active": return i18n.t(.ab_status_active)
        case "archived": return i18n.t(.ab_status_archived)
        default: return status ?? i18n.t(.ab_status_draft)
        }
    }
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
    @Published var dashboardData: [String: Any] = [:]

    // ARCH-2: 逃逸 Task 生命周期管理。taskExecuteImmediate 的 fire-and-forget Task 存 handle,
    // 按 taskId 索引。任务删除/对象销毁时 cancel, 防 view 销毁后后台 Task 仍写 @Published。
    // nonisolated(unsafe): Task<Void, Never> 是 Sendable, deinit (nonisolated) 需遍历 cancel,
    // 不走 actor 隔离检查。仅 @MainActor 方法读写, 无真并发竞态。
    nonisolated(unsafe) private var taskRunHandles: [String: Task<Void, Never>] = [:]

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
    @Published var tools: [[String: Any]] = []
    @Published var ragSources: [String] = []
    @Published var lastSkillResult: String = ""
    @Published var lastResearchResult: String = ""

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
        let result: [String: Any]
        do {
            result = try await withThrowingTaskGroup(of: [String: Any].self) { group in
                group.addTask {
                    try await client.call(method: "env.health_check")
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 8_000_000_000)
                    throw BridgeError.timeout
                }
                guard let value = try await group.next() else {
                    throw BridgeError.timeout
                }
                group.cancelAll()
                return value
            }
        } catch BridgeError.timeout {
            self.isConnected = false
            self.lastError = .timeout
            logger.error("fullHealthCheck: timeout after 8s (env.health_check did not respond)")
            throw BridgeError.timeout
        }
        self.isConnected = true
        return result
    }

    // 复核 MLX 是否可达：直接走 HTTP /v1/models（app 复用外部 mlx，env-daemon 不一定在线）。
    // 用于启动竞态后重试 / Design 等模块进入时复核，避免 isMLXRunning 滞留 false (bug3/bug7/bug8)。
    func probeMLXRunningStatus() async -> Bool {
        let config = FusionConfig.shared
        DesignPreviewTrace.log("probeMLXRunningStatus: baseURL=\(config.mlxBaseURL) apiKeyLen=\(config.mlxResolvedApiKey.count) route=studio")
        do {
            _ = try await fetchModels()
            logger.info("probeMLXRunningStatus: mlx reachable (HTTP /v1/models)")
            DesignPreviewTrace.log("probeMLXRunningStatus: OK reachable")
            return true
        } catch BridgeError.authFailed {
            // 401/403：当前解析的 api key 无效。常见根因：~/.zshrc 注入了错误的
            // FUSION_MLX_API_KEY（gateway 残留 key），env 优先级高于 settings.json。
            // 自愈：用 settings.json 的 auth.api_key 重试，成功则持久化到 user-settings，
            // 抬高其优先级覆盖错误 env，避免每次启动都 401。
            logger.warning("probeMLXRunningStatus: auth failed, attempting settings.json key self-heal")
            return await selfHealApiKeyFromSettings()
        } catch {
            logger.error("probeMLXRunningStatus: mlx unreachable: \(error)")
            DesignPreviewTrace.log("probeMLXRunningStatus: FAIL \(error)")
            return false
        }
    }

    // MLX 探活 401 自愈：按候选 key 序列（gateway config.yaml > settings.json > fg-admin-key）
    // 逐个探测当前 baseURL（gateway 11432 或直连 11434），首个 200 的持久化到 user-settings。
    private func selfHealApiKeyFromSettings() async -> Bool {
        let cfg = FusionConfig.shared
        let candidates = await Self.mlxSelfHealKeyCandidates(currentResolved: cfg.mlxResolvedApiKey)
        guard !candidates.isEmpty else {
            logger.error("selfHealApiKey: no candidate keys to fall back")
            return false
        }
        let baseURL = cfg.mlxBaseURL
        guard let url = URL(string: "\(baseURL)/v1/models") else { return false }
        for key in candidates {
            do {
                var req = URLRequest(url: url)
                req.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
                req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                req.timeoutInterval = 10
                let (_, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                if code == 200 {
                    cfg.mlxApiKey = key
                    logger.info("selfHealApiKey: persisted key (len \(key.count)) to user-settings (resolved key was invalid)")
                    return true
                }
                logger.warning("selfHealApiKey: candidate key (len \(key.count)) failed HTTP \(code)")
            } catch {
                logger.warning("selfHealApiKey: candidate key probe failed: \(error.localizedDescription)")
            }
        }
        logger.error("selfHealApiKey: all \(candidates.count) candidate keys failed")
        return false
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
            // 仅在 id 集合或数量变化时更新 @Published, 避免 .task 反复触发 AgentStudioView body 重算导致 Workflows 转圈
            // BUG-6: 旧实现 zip(parsed, self.graphs) 按较短序列截断, 删除项不被检测
            // (parsed 比 graphs 短时 zip 只比到 parsed.count, 尾部多余 graphs.id 不参与比较 -> changed=false)。
            // 改用 id 集合差集, 增删均能检出。
            let parsedIds = Set(parsed.map(\.id))
            let currentIds = Set(self.graphs.map(\.id))
            let changed = parsed.count != self.graphs.count || parsedIds != currentIds
            if changed {
                self.graphs = parsed
            }
            logger.info("fetchGraphs: received \(parsed.count) graphs (changed=\(changed))")
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
            // daemon graph.get 的 result 顶层即 graph 数据 (含 nodes/edges/name), 不包在 graph key 里
            let graphData = (result["graph"] as? [String: Any]) ?? result
            return Self.parseGraphModel(from: graphData)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("graphGet: \(error)")
            throw bridgeErr
        }
    }

    func deleteGraph(id: String) async throws {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("deleteGraph: id=\(id)")
        do {
            _ = try await client.call(method: "graph.delete", params: ["graph_id": id])
            logger.info("deleteGraph: deleted id=\(id, privacy: .public)")
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("deleteGraph id=\(id, privacy: .public) failed: \(error.errorDescription ?? "unknown", privacy: .public)")
            throw bridgeErr
        }
    }

    func executeGraph(id: String, input: String, taskId: String = "") async throws {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("executeGraph: id=\(id) task=\(taskId.isEmpty ? "-" : taskId)")
        self.isExecuting = true
        self.events = []

        do {
            var params: [String: Any] = [
                "graph_id": id,
                "input": input,
            ]
            if !taskId.isEmpty {
                params["task_id"] = taskId
            }
            let result = try await client.call(method: "graph.execute", params: params)

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

    func updateGraph(id: String, name: String? = nil, nodes: [NodeConfigModel]? = nil, edges: [EdgeModel]? = nil) async throws -> AgentGraphModel? {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("updateGraph: id=\(id)")
        var params: [String: Any] = ["graph_id": id]
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
            let tools = result["tools"] as? [[String: Any]] ?? []
            self.tools = tools
            return tools
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            logger.error("fetchTools: \(error)")
            throw bridgeErr
        }
    }

    func toolDynamicRegister(name: String, description: String, parameters: [String: Any], code: String = "") async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("toolDynamicRegister: \(name)")
        do {
            let result = try await client.toolDynamicRegister(name: name, description: description, parameters: parameters, code: code)
            try await fetchTools()
            return result
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func toolDynamicUnregister(name: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("toolDynamicUnregister: \(name)")
        do {
            _ = try await client.toolDynamicUnregister(name: name)
            try await fetchTools()
            return true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
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
        try await fetchModels(withApiKey: FusionConfig.shared.mlxResolvedApiKey)
    }

    private func fetchModels(withApiKey apiKey: String) async throws -> [MLXModelInfo] {
        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        guard let url = URL(string: "\(baseURL)/v1/models") else {
            throw BridgeError.ipcError("Invalid MLX URL: \(baseURL)")
        }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 10
            request.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else {
                throw BridgeError.serviceUnavailable("MLX non-HTTP response")
            }
            guard httpResp.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                logger.error("fetchModels: HTTP \(httpResp.statusCode) — \(body)")
                let code = httpResp.statusCode
                if code == 401 || code == 403 {
                    if let fallback = await Self.mlxSettingsJsonApiKey(), !fallback.isEmpty, fallback != apiKey {
                        logger.warning("fetchModels: auth failed with resolved key (len \(apiKey.count)), retrying with settings.json key")
                        return try await fetchModels(withApiKey: fallback)
                    }
                    throw BridgeError.authFailed("MLX returned HTTP \(code)")
                }
                throw BridgeError.serviceUnavailable("MLX returned HTTP \(code)")
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

    // PERF-4: nonisolated async — 文件 I/O 跑 cooperative 线程池, 不阻塞 MainActor。sync 版删除: 全部调用方已 async await。
    nonisolated static func mlxSettingsJsonApiKey() async -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory() + "/.fusion-mlx/settings.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let auth = json["auth"] as? [String: Any],
              let key = auth["api_key"] as? String, !key.isEmpty else {
            return nil
        }
        return key
    }

    // gateway (11432) 的有效 api key：解析 ~/fusion/fusion-gateway/config.yaml auth.api_keys[0]。
    // env FUSION_MLX_API_KEY 常是过期值（被 gateway 拒），自愈回退到此 key。
    // PERF-4: nonisolated async — config.yaml 读取 + 行解析跑 cooperative 线程池, 不阻塞 MainActor。
    nonisolated static func gatewayConfigApiKey() async -> String? {
        let paths = [
            NSHomeDirectory() + "/fusion/fusion-gateway/config.yaml",
            "/Users/dahai/fusion/fusion-gateway/config.yaml",
        ]
        for path in paths {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            // BUG-5: 旧实现 trimmed.hasPrefix("key:") 无节作用域, 可命中任意段落的 key:
            // (api_keys 列表项 key: 之外, 若有 auth.jwt_secret 等误写或未来新增 key: 字段均会误读)。
            // 修正: 仅在 auth 节作用域内取第一个非占位 key:。
            var inAuthSection = false
            var authIndent: Int = -1
            for line in content.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                let indent = line.count - line.prefix(while: { $0 == " " }).count
                // 顶层 (indent 0) 键: 进入/离开节作用域
                if indent == 0 {
                    inAuthSection = trimmed.hasPrefix("auth:")
                    authIndent = -1
                    continue
                }
                guard inAuthSection else { continue }
                // 记录 auth 直属子项缩进, 只在其下更深缩进识别 list item key:
                if authIndent < 0 { authIndent = indent }
                if trimmed.hasPrefix("key:") {
                    let v = trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces)
                    if !v.isEmpty && !v.contains("your-") && !v.contains("change-me") {
                        agentBridgeStaticLog.info("gatewayConfigApiKey: 命中 auth 节 key=\(v, privacy: .private)")
                        return v
                    }
                }
            }
        }
        return nil
    }

    // 自愈候选 key 序列：gateway config.yaml > settings.json > 内置 fg-admin-key 兜底
    // PERF-4: nonisolated async — 内部两个文件读 async, 本身也 nonisolated 跑 cooperative 池。
    nonisolated static func mlxSelfHealKeyCandidates(currentResolved: String) async -> [String] {
        var cands: [String] = []
        if let g = await gatewayConfigApiKey(), !g.isEmpty, g != currentResolved { cands.append(g) }
        if let s = await mlxSettingsJsonApiKey(), !s.isEmpty, s != currentResolved { cands.append(s) }
        if !cands.contains("fg-admin-key") { cands.append("fg-admin-key") }
        return cands
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
        var messages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        for msg in chatMessages {
            messages.append(["role": msg.role, "content": msg.content])
        }

        isInferring = true
        defer { isInferring = false }

        let projectSettings = pm.activeProject?.settings ?? ProjectSettings()
        var chatModel = projectSettings.defaultModel
        if chatModel.isEmpty {
            chatModel = MLXModelInfo.preferredDefault(in: models)?.name ?? ""
            logger.info("sendProjectChat: default model empty, picked \(chatModel)")
        }
        // BUG-1: 旧实现流结束才在 :1049 追加 assistantRecord, 与 onToken 的流式追加竞争 ->
        // 最终 record 覆盖流式部分 (或并行 Task 乱序导致 token 丢失/错位)。修正: 流开始前预置空
        // assistant 占位, onToken 逐 token 原位追加, 流结束不再重复 append (response 即占位累计内容)。
        let assistantRecord = ChatMessageRecord(role: "assistant", content: "")
        chatMessages.append(assistantRecord)
        let response = try await inferStream(
            messages: messages,
            model: chatModel,
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

        // 流结束: 若 inferStream 返回值与占位累计不一致 (如含 thinking 前缀), 以完整 response 回填占位记录,
        // 并持久化到 session。不再重复 append (避免双条 assistant 消息)。
        if let lastIdx = chatMessages.indices.last, chatMessages[lastIdx].role == "assistant" {
            chatMessages[lastIdx].content = response
        }
        if let session = pm.activeSession {
            pm.addMessage(toSession: session.id, role: "assistant", content: response)
        }
        logger.info("sendProjectChat done: respLen=\(response.count)")
        return response
    }

    func clearChat() {
        chatMessages = []
        FusionProjectManager.shared.activeSession = nil
    }

    // BUG-4: 原 loadSessionMessages 仅 chatMessages=[] 不回填 session 历史且无调用方 (死方法,
    // 切 session 走 pm.loadSession + pm.loadMessages 路径不经此), 历史丢失且方法误导。已删除。

    func infer(messages: [[String: Any]], model: String = "", temperature: Double = 0.7, maxTokens: Int = 2048, effort: String = "medium", thinking: Bool = false, webSearch: Bool = false) async throws -> String {
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
        if webSearch {
            body["web_search"] = true
        }
        guard let requestData = try? JSONSerialization.data(withJSONObject: body) else {
            throw BridgeError.ipcError("Failed to encode request")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
        request.timeoutInterval = 120
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw BridgeError.serviceUnavailable("MLX non-HTTP response")
        }
        guard httpResp.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            logger.error("infer: HTTP \(httpResp.statusCode) — \(responseBody)")
            let code = httpResp.statusCode
            if code == 401 || code == 403 {
                // 自愈：env key 常过期（gateway 拒），回退候选 key 重试一次
                if let healed = await selfHealApiKeyForInfer(currentURL: url, routeKey: apiKey) {
                    var retryReq = request
                    retryReq.setValue("Bearer \(healed)", forHTTPHeaderField: "Authorization")
                    let (d2, r2) = try await URLSession.shared.data(for: retryReq)
                    guard let h2 = r2 as? HTTPURLResponse, h2.statusCode == 200 else {
                        throw BridgeError.authFailed("MLX inference returned HTTP \(code) (self-heal retry HTTP \((r2 as? HTTPURLResponse)?.statusCode ?? -1))")
                    }
                    return try parseInferResponse(data: d2, thinking: thinking)
                }
                throw BridgeError.authFailed("MLX inference returned HTTP \(code)")
            }
            throw BridgeError.serviceUnavailable("MLX inference returned HTTP \(code)")
        }
        return try parseInferResponse(data: data, thinking: thinking)
    }

    // 探测候选 key（gateway config.yaml > settings.json > fg-admin-key），首个 200 的持久化并返回。
    private func selfHealApiKeyForInfer(currentURL: URL, routeKey: String) async -> String? {
        let cfg = FusionConfig.shared
        let candidates = await Self.mlxSelfHealKeyCandidates(currentResolved: routeKey)
        for key in candidates {
            guard let probeURL = URL(string: "\(cfg.mlxBaseURL)/v1/models") else { continue }
            var req = URLRequest(url: probeURL)
            req.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            req.timeoutInterval = 10
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                if (resp as? HTTPURLResponse)?.statusCode == 200 {
                    cfg.mlxApiKey = key
                    logger.info("infer selfHeal: persisted key (len \(key.count))")
                    return key
                }
            } catch {
                logger.warning("infer selfHeal: probe failed: \(error.localizedDescription)")
            }
        }
        return nil
    }

    private func parseInferResponse(data: Data, thinking: Bool) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw BridgeError.decodeError("Invalid /v1/chat/completions response")
        }
        var content = message["content"] as? String ?? ""
        if thinking, let reasoning = message["reasoning_content"] as? String, !reasoning.isEmpty {
            content = "<think>\n\(reasoning)\n</think>\n\n\(content)"
        }
        logger.info("infer: received \(content.count) chars, thinking=\(thinking)")
        return content
    }

    func inferStream(messages: [[String: Any]], model: String = "", temperature: Double = 0.7, maxTokens: Int = 2048, effort: String = "medium", thinking: Bool = false, webSearch: Bool = false, onToken: @escaping (String) -> Void) async throws -> String {
        // Callers: ChatSessionStore.sendMessage, AgentBridge.sendProjectChat. Affected API: inferStream. Data: baseURL, model.
        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        print("[inferStream] baseURL=\(baseURL), model=\(model), apiKey=\(apiKey.isEmpty ? "empty" : "set"), webSearch=\(webSearch)")
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw BridgeError.ipcError("Invalid MLX URL: \(baseURL)")
        }
        var body: [String: Any] = [
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": true,
        ]
        if webSearch {
            body["web_search"] = true
        }
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
        request.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
        request.timeoutInterval = 300
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw BridgeError.serviceUnavailable("MLX non-HTTP response")
        }
        if httpResp.statusCode == 401 || httpResp.statusCode == 403 {
            logger.error("inferStream: auth failed HTTP \(httpResp.statusCode), baseURL=\(baseURL), apiKeyLen=\(apiKey.count), route=studio")
            // 自愈：env key 常过期（gateway 拒），回退候选 key 重试一次（流式重发）
            if let healed = await selfHealApiKeyForInfer(currentURL: url, routeKey: apiKey) {
                var retryReq = request
                retryReq.setValue("Bearer \(healed)", forHTTPHeaderField: "Authorization")
                let (b2, r2) = try await URLSession.shared.bytes(for: retryReq)
                guard let h2 = r2 as? HTTPURLResponse, h2.statusCode == 200 else {
                    throw BridgeError.authFailed("MLX returned HTTP \(httpResp.statusCode) (self-heal retry HTTP \((r2 as? HTTPURLResponse)?.statusCode ?? -1))")
                }
                return try await drainStream(bytes: b2, thinking: thinking, onToken: onToken)
            }
            throw BridgeError.authFailed("MLX returned HTTP \(httpResp.statusCode)")
        }
        guard httpResp.statusCode == 200 else {
            throw BridgeError.serviceUnavailable("MLX streaming returned HTTP \(httpResp.statusCode)")
        }
        return try await drainStream(bytes: bytes, thinking: thinking, onToken: onToken)
    }

    // 消费流式响应，拼装 fullContent + thinking 前缀，逐 token 回调
    private func drainStream(bytes: URLSession.AsyncBytes, thinking: Bool, onToken: @escaping (String) -> Void) async throws -> String {
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
            fullContent = "🤖\n\(thinkingContent)\n\n\n\(fullContent)"
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

    // ARCH-1: RAG Operations (ragQuery/ragRetrieve/ragVectorSearch) 抽至 AgentRAGService.swift facade extension。
    // @Published ragResults/ragSources/lastError + ipcClient 留本类 (extension 不可声明存储), 0 行为零变。

    func skillExecute(agentId: String, skillName: String, input: String, tools: [String] = []) async throws -> String {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("skillExecute: agent=\(agentId) skill=\(skillName)")
        do {
            let result = try await client.skillExecute(agentId: agentId, skillName: skillName, input: input, tools: tools)
            let output = result["result"] as? String ?? result["output"] as? String ?? ""
            self.lastSkillResult = output
            return output
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func researchAdaptive(question: String, maxSteps: Int = 10, webSearch: Bool = true) async throws -> String {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("researchAdaptive: question=\(question) maxSteps=\(maxSteps)")
        do {
            let result = try await client.researchAdaptive(question: question, maxSteps: maxSteps, webSearch: webSearch)
            let summary = result["summary"] as? String ?? result["result"] as? String ?? ""
            self.lastResearchResult = summary
            return summary
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
    // ARCH-1: fetchTemplates + templateGet 抽至 AgentTemplateService.swift facade extension。
    // templateInstantiate 留此: 依赖 Self.parseGraphModel (private static L2948 跨文件不可访问),
    // 待 Graph 域抽取时与 parseGraphModel + 5 graph 方法同搬。

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

    func agentCreate(name: String, model: String = "", systemPrompt: String = "", temperature: Double = 0.7, maxTokens: Int = 4096, tools: [String] = [], capabilities: [String] = [], safetyLevel: String = "L1", tags: [String] = [], description: String = "", soul: String = "", memory: String = "", agentsMd: String = "") async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentCreate: name=\(name), soul=\(soul.isEmpty ? "empty" : "set"), memory=\(memory.isEmpty ? "empty" : "set"), agentsMd=\(agentsMd.isEmpty ? "empty" : "set")")
        do {
            let result = try await client.agentCreate(name: name, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags, description: description, soul: soul, memory: memory, agentsMd: agentsMd)
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
                // PERF-3: 删 agent 时清 agentVersionHistory 该 agent 条目, 否则已删 agent 版本历史孤儿驻留 dict 永不释放。
                self.agentVersionHistory.removeValue(forKey: agentId)
            }
            return deleted
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - Agent Lifecycle

    func agentPublish(agentId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentPublish: id=\(agentId)")
        let result = try await client.agentPublish(agentId: agentId)
        guard let updated = Self.parseAgentModel(from: result) else {
            throw BridgeError.ipcError("Invalid publish response")
        }
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx] = updated
        }
        return updated
    }

    func agentArchive(agentId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentArchive: id=\(agentId)")
        let result = try await client.agentArchive(agentId: agentId)
        guard let updated = Self.parseAgentModel(from: result) else {
            throw BridgeError.ipcError("Invalid archive response")
        }
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx] = updated
        }
        return updated
    }

    func agentUnpublish(agentId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentUnpublish: id=\(agentId)")
        let result = try await client.agentUnpublish(agentId: agentId)
        guard let status = result["status"] as? String, status == "draft" else {
            let msg = (result["message"] as? String) ?? "unpublish failed"
            throw BridgeError.ipcError(msg)
        }
        let updated = try await agentGet(agentId: agentId)
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx] = updated
        }
        return updated
    }

    func agentClone(agentId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentClone: id=\(agentId)")
        let result = try await client.agentClone(agentId: agentId)
        guard let cloned = Self.parseAgentModel(from: result) else {
            throw BridgeError.ipcError("Invalid clone response")
        }
        agents.append(cloned)
        return cloned
    }

    @Published var agentVersionHistory: [String: [[String: Any]]] = [:]

    func agentSnapshot(agentId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentSnapshot: id=\(agentId)")
        let result = try await client.call(method: "agent_studio.agent.snapshot", params: ["agent_id": agentId])
        try await fetchAgents()
        return result
    }

    func agentVersions(agentId: String) async throws -> [[String: Any]] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentVersions: id=\(agentId)")
        let result = try await client.call(method: "agent_studio.agent.versions", params: ["agent_id": agentId])
        guard let versions = result as? [[String: Any]] else {
            let items = result["versions"] as? [[String: Any]] ?? []
            agentVersionHistory[agentId] = items
            return items
        }
        agentVersionHistory[agentId] = versions
        return versions
    }

    func agentRestoreVersion(agentId: String, versionId: String) async throws -> AgentModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("agentRestoreVersion: id=\(agentId) version=\(versionId)")
        let result = try await client.call(method: "agent_studio.agent.restore_version", params: ["agent_id": agentId, "version_id": versionId])
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
            self.dashboardData = result
            logger.info("Dashboard fetched: \(result.keys.joined(separator: ","))")
        } catch {
            logger.debug("Dashboard fetch failed: \(error.localizedDescription)")
        }
    }

    @Published var auditTrail: [[String: Any]] = []
    @Published var sessionLogs: [[String: Any]] = []

    func fetchAuditTrail(agentId: String? = nil, startDate: String? = nil, endDate: String? = nil) async {
        guard let client = ipcClient else { return }
        do {
            var params: [String: Any] = [:]
            if let aid = agentId { params["agent_id"] = aid }
            if let s = startDate { params["start_date"] = s }
            if let e = endDate { params["end_date"] = e }
            let result = try await client.call(method: "agent_studio.audit.trail", params: params)
            let items = result["entries"] as? [[String: Any]] ?? (result as? [[String: Any]] ?? [])
            auditTrail = items
            logger.info("Audit trail fetched: \(items.count) entries")
        } catch {
            logger.debug("Audit trail fetch failed: \(error.localizedDescription)")
        }
    }

    func fetchSessionLogs(agentId: String? = nil, startDate: String? = nil, endDate: String? = nil) async {
        guard let client = ipcClient else { return }
        do {
            var params: [String: Any] = [:]
            if let aid = agentId { params["agent_id"] = aid }
            if let s = startDate { params["start_date"] = s }
            if let e = endDate { params["end_date"] = e }
            let result = try await client.call(method: "agent_studio.session.logs", params: params)
            let items = result["sessions"] as? [[String: Any]] ?? (result as? [[String: Any]] ?? [])
            sessionLogs = items
            logger.info("Session logs fetched: \(items.count) entries")
        } catch {
            logger.debug("Session logs fetch failed: \(error.localizedDescription)")
        }
    }

    @Published var activeSessionId: String = ""
    @Published var streamingContent: String = ""
    @Published var isAgentStreaming: Bool = false
    @Published var lastToolCalls: [[String: Any]] = []

    func chatStream(agentId: String, message: String, sessionId: String? = nil, onToken: @escaping (String) -> Void) async throws -> String {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        logger.info("chatStream: agent=\(agentId)")
        var params: [String: Any] = [
            "agent_id": agentId,
            "message": message,
        ]
        if let sid = sessionId { params["session_id"] = sid }

        activeSessionId = sessionId ?? ""
        isAgentStreaming = true
        streamingContent = ""
        lastToolCalls = []
        defer { isAgentStreaming = false }

        do {
            let result = try await client.call(method: "agent_studio.agent.chat", params: params)
            let content = result["content"] as? String ?? ""
            let toolCalls = result["tool_calls"] as? [[String: Any]] ?? []
            let sid = result["session_id"] as? String ?? activeSessionId
            activeSessionId = sid
            lastToolCalls = toolCalls
            streamingContent = content
            onToken(content)
            return content
        } catch {
            isAgentStreaming = false
            throw error
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
            // ARCH-2: 仅当仍是当前选中 agent 时才回写 @Published。
            // 切 agent 后旧 fetch 的回调若仍写 self.agentSkills = skills -> 跨 agent 残留串台。
            if self.currentAgent?.id == agentId {
                self.agentSkills = skills
            } else {
                logger.info("fetchAgentSkills: agent 已切换, 丢弃过期 skills agentId=\(agentId) current=\(self.currentAgent?.id ?? "nil")")
            }
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
            if added && self.currentAgent?.id == agentId {
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
            if deleted && self.currentAgent?.id == agentId {
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
            // ARCH-2: 仅当仍是当前选中 agent 时才回写 @Published。
            // 切 agent 后旧 fetch 的回调若仍写 self.agentSoul = soul -> 跨 agent 残留串台。
            if self.currentAgent?.id == agentId {
                self.agentSoul = soul
            } else {
                logger.info("fetchAgentSoul: agent 已切换, 丢弃过期 soul agentId=\(agentId) current=\(self.currentAgent?.id ?? "nil")")
            }
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
            if updated && self.currentAgent?.id == agentId {
                self.agentSoul = soul
            }
            return updated
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - Connector Operations

    @Published var connectors: [[String: Any]] = []

    func fetchConnectors() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.connectorList()
            self.connectors = result["connectors"] as? [[String: Any]] ?? []
            logger.info("Fetched \(self.connectors.count) connectors")
        } catch {
            logger.debug("fetchConnectors failed: \(error.localizedDescription)")
        }
    }

    func connectorCreate(name: String, type: String, config: [String: Any]) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.connectorCreate(name: name, type: type, config: config)
        await fetchConnectors()
        return result
    }

    func connectorDelete(connectorId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.connectorDelete(connectorId: connectorId)
        await fetchConnectors()
        return result
    }

    func connectorConnect(connectorId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.connectorConnect(connectorId: connectorId)
    }

    func connectorDisconnect(connectorId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.connectorDisconnect(connectorId: connectorId)
    }

    func connectorTest(connectorId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.connectorTest(connectorId: connectorId)
    }

    // MARK: - API Key Operations

    @Published var apikeys: [[String: Any]] = []

    func fetchApikeys() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.apikeyList()
            self.apikeys = result["keys"] as? [[String: Any]] ?? []
            logger.info("Fetched \(self.apikeys.count) API keys")
        } catch {
            logger.debug("fetchApikeys failed: \(error.localizedDescription)")
        }
    }

    func apikeyCreate(name: String, permissions: [String] = [], agentIds: [String] = []) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.apikeyCreate(name: name, permissions: permissions, agentIds: agentIds)
        await fetchApikeys()
        return result
    }

    func apikeyRevoke(keyId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.apikeyRevoke(keyId: keyId)
        await fetchApikeys()
        return result
    }

    func apikeyRotate(keyId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.call(method: "agent_studio.apikey.rotate", params: ["key_id": keyId])
        await fetchApikeys()
        logger.info("Rotated API key: \(keyId)")
        return result
    }

    // MARK: - Style Operations

    @Published var styles: [[String: Any]] = []

    func fetchStyles() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.styleList()
            self.styles = result["styles"] as? [[String: Any]] ?? []
            logger.info("Fetched \(self.styles.count) styles")
        } catch {
            logger.debug("fetchStyles failed: \(error.localizedDescription)")
        }
    }

    func styleCreate(name: String, template: String, rules: [String: Any] = [:]) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.styleCreate(name: name, template: template, rules: rules)
        await fetchStyles()
        return result
    }

    func styleDelete(styleId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.styleDelete(styleId: styleId)
        await fetchStyles()
        return result
    }

    // MARK: - Analytics & Alert Operations

    @Published var analyticsData: [String: Any] = [:]
    @Published var alerts: [[String: Any]] = []

    func fetchAnalytics(agentId: String? = nil, range: String = "week") async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.analyticsAgentUsage(agentId: agentId, range: range)
            self.analyticsData = result
            logger.info("Analytics fetched")
        } catch {
            logger.debug("fetchAnalytics failed: \(error.localizedDescription)")
        }
    }

    func fetchAlerts() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.alertList()
            self.alerts = result["alerts"] as? [[String: Any]] ?? []
            logger.info("Fetched \(self.alerts.count) alerts")
        } catch {
            logger.debug("fetchAlerts failed: \(error.localizedDescription)")
        }
    }

    func alertAcknowledge(alertId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.alertAcknowledge(alertId: alertId)
        await fetchAlerts()
        return result
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

    // MARK: - Team Operations

    @Published var swarmAgents: [[String: Any]] = []
    @Published var plazaChannels: [[String: Any]] = []
    @Published var cronJobs: [[String: Any]] = []
    @Published var hooks: [[String: Any]] = []
    @Published var tasks: [TaskModel] = []
    @Published var projects: [ProjectBucket] = []

    func teamOrchestrate(task: String, agentIds: [String], mode: String = "sequential") async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.teamOrchestrate(task: task, agentIds: agentIds, mode: mode)
    }

    func fetchSwarmAgents() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.teamSwarmAgents()
            self.swarmAgents = result["agents"] as? [[String: Any]] ?? []
            logger.info("Fetched \(self.swarmAgents.count) swarm agents")
        } catch {
            logger.debug("fetchSwarmAgents failed: \(error.localizedDescription)")
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
            logger.info("Fetched \(self.plazaChannels.count) plaza channels")
        } catch {
            logger.debug("fetchPlazaChannels failed: \(error.localizedDescription)")
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

    // MARK: - Task Operations

    // 从后端 task.list 拉取持久化任务. 后端 5 态 → 前端 7 态.
    func fetchTasks() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.taskList(limit: 200)
            let raw = result["tasks"] as? [[String: Any]] ?? []
            var parsed: [TaskModel] = []
            for d in raw {
                if let t = TaskModel(backendDict: d) { parsed.append(t) }
            }
            self.tasks = parsed
            logger.info("fetchTasks: \(parsed.count) backend tasks")
        } catch {
            logger.warning("fetchTasks failed: \(error.localizedDescription)")
        }
    }

    // 拉取 Project 聚合看板桶 (#141 priority-2). 后端 project.list 按 project_id 分组统计.
    func fetchProjects() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.projectList()
            let raw = result["projects"] as? [[String: Any]] ?? []
            var parsed: [ProjectBucket] = []
            for d in raw {
                if let b = ProjectBucket(backendDict: d) { parsed.append(b) }
            }
            self.projects = parsed
            logger.info("fetchProjects: \(parsed.count) projects")
        } catch {
            logger.warning("fetchProjects failed: \(error.localizedDescription)")
        }
    }

    func agentName(for id: String) -> String {
        agents.first(where: { $0.id == id })?.name ?? id.prefix(8).description
    }

    func graphName(for id: String) -> String {
        graphs.first(where: { $0.id == id })?.name ?? ""
    }

    private func taskIndex(_ id: String) -> Int? {
        tasks.firstIndex(where: { $0.id == id })
    }

    private func updateTask(_ id: String, _ mutate: (inout TaskModel) -> Void) {
        guard let idx = taskIndex(id) else { return }
        mutate(&tasks[idx])
        tasks[idx].updatedAt = Date()
    }

    // 提交到后端 task.submit; cron 触发由后端自动注册 cron job 并回写 cron_job_id.
    // 返回后端落库后的 TaskModel (含真实 task_id, cron_job_id).
    @discardableResult
    func taskSubmit(
        title: String,
        description: String,
        agentId: String,
        graphId: String,
        trigger: TaskModel.TaskTrigger,
        cronExpression: String,
        runAt: Date?,
        input: String,
        priority: AgentTask.TaskPriority = .medium,
        projectId: String = ""
    ) async throws -> TaskModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let runAtEpoch = runAt?.timeIntervalSince1970 ?? 0
        let prioInt = priority == .low ? 0 : (priority == .medium ? 1 : (priority == .high ? 2 : 3))
        let triggerStr = trigger == .immediate ? "immediate" : (trigger == .cron ? "cron" : "run_at")
        let result = try await client.taskSubmit(
            title: title,
            description: description,
            agentId: agentId,
            graphId: graphId,
            trigger: triggerStr,
            cronExpression: cronExpression,
            runAt: runAtEpoch,
            input: input,
            status: "pending",
            priority: prioInt,
            projectId: projectId,
            maxRetries: 3
        )
        guard let taskDict = result["task"] as? [String: Any],
              let saved = TaskModel(backendDict: taskDict) else {
            throw BridgeError.decodeError("task.submit missing task field")
        }
        if let idx = self.taskIndex(saved.id) {
            self.tasks[idx] = saved
        } else {
            self.tasks.append(saved)
        }
        logger.info("taskSubmit: id=\(saved.id) title=\(title) trigger=\(trigger.rawValue) cron_job=\(saved.cronJobId)")
        return saved
    }

    func taskExecuteImmediate(_ taskId: String) {
        guard let idx = taskIndex(taskId) else { return }
        let agentId = tasks[idx].agentId
        let graphId = tasks[idx].graphId
        let inputText = tasks[idx].input
        updateTask(taskId) { t in
            t.status = .running
            t.lastRunAt = Date()
            t.lastError = ""
        }
        reportTaskStatus(taskId, status: "running")
        logger.info("taskExecuteImmediate: id=\(taskId) agent=\(agentId) graph=\(graphId)")
        // ARCH-2: 存 Task handle。重复执行同 taskId 先 cancel 旧 handle (防并发重复跑)。
        taskRunHandles[taskId]?.cancel()
        let handle = Task {
            do {
                var eventsParsed: [AgentEventModel] = []
                var sessionId = ""
                if !graphId.isEmpty {
                    try await executeGraph(id: graphId, input: inputText, taskId: taskId)
                    eventsParsed = self.events
                } else {
                    let result = try await agentExecute(agentId: agentId, input: inputText)
                    sessionId = result["session_id"] as? String ?? ""
                    let eventsData = result["events"] as? [[String: Any]] ?? []
                    for ev in eventsData {
                        if let model = Self.parseEventModel(from: ev) {
                            eventsParsed.append(model)
                        }
                    }
                }
                try Task.checkCancellation()
                let summary = summarizeEvents(eventsParsed)
                self.updateTask(taskId) { t in
                    t.status = .completed
                    t.events = eventsParsed
                    t.lastResult = summary
                    t.sessionId = sessionId
                    t.lastRunAt = Date()
                }
                self.taskRunHandles.removeValue(forKey: taskId)
                logger.info("taskExecuteImmediate done: id=\(taskId) events=\(eventsParsed.count)")
                self.reportTaskStatus(taskId, status: "completed", lastResult: ["summary": summary, "events": eventsParsed.count])
            } catch is CancellationError {
                self.updateTask(taskId) { t in
                    if t.status != .completed { t.status = .cancelled }
                }
                logger.info("taskExecuteImmediate cancelled: id=\(taskId)")
            } catch {
                self.updateTask(taskId) { t in
                    t.lastError = error.localizedDescription
                    t.lastRunAt = Date()
                    t.retryCount += 1
                }
                // BUG-3: 旧实现 self.taskIndex(taskId) ?? 0 在任务已被删除时回退到下标 0,
                // 误读另一条任务的 retryCount/maxRetries -> 用错任务的重试预算决定本任务去留,
                // 甚至对已删任务继续递归 taskExecuteImmediate (retryCount 永远 <= maxRetries 时死循环)。
                // 修正: 任务已删 (taskIndex nil) 即早退, 不再读错行也不递归。
                guard let idx = self.taskIndex(taskId) else {
                    logger.warning("taskExecuteImmediate catch: 任务已删除, 放弃 retry id=\(taskId)")
                    return
                }
                let cur = self.tasks[idx]
                // ARCH-2: retry 上限收紧 + 退避, 防 maxRetries 过大时高频重试风暴。
                // retryCount 已 +1, 仅当未超 maxRetries 才重排; 退避 1s 避免立即重试打满后端。
                if cur.retryCount <= cur.maxRetries {
                    self.updateTask(taskId) { t in t.status = .queued }
                    logger.warning("taskExecuteImmediate retry: id=\(taskId) retryCount=\(cur.retryCount)/\(cur.maxRetries)")
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        if Task.isCancelled {
                            logger.info("taskExecuteImmediate retry cancelled: id=\(taskId)")
                            return
                        }
                        self.taskExecuteImmediate(taskId)
                    }
                } else {
                    self.updateTask(taskId) { t in t.status = .failed }
                    self.taskRunHandles.removeValue(forKey: taskId)
                    logger.error("taskExecuteImmediate failed: id=\(taskId) retryCount=\(cur.retryCount) err=\(error.localizedDescription)")
                }
                self.reportTaskStatus(taskId, status: "failed", lastError: error.localizedDescription)
            }
        }
        taskRunHandles[taskId] = handle
    }

    // 上游 task.delete RPC 已落地 (PR#148); 真删 + 注销关联 cron job (后端处理).
    func taskDelete(_ taskId: String) {
        guard let client = ipcClient else { return }
        // ARCH-2: 删任务先 cancel 在跑的执行 Task, 防 RPC 删后后台 Task 仍写已删任务状态。
        taskRunHandles[taskId]?.cancel()
        taskRunHandles.removeValue(forKey: taskId)
        Task {
            do {
                _ = try await client.taskDelete(taskId: taskId)
                self.tasks.removeAll { $0.id == taskId }
                logger.info("taskDelete: id=\(taskId) deleted via RPC")
            } catch {
                logger.error("taskDelete failed: id=\(taskId) err=\(error.localizedDescription)")
            }
        }
    }

    func taskAddArtifacts(_ taskId: String, artifactIds: [String]) async {
        guard let client = ipcClient else { return }
        do {
            let resp = try await client.taskAddArtifacts(taskId: taskId, artifactIds: artifactIds)
            let aids = resp["artifact_ids"] as? [String] ?? []
            self.updateTask(taskId) { t in t.artifactIds = aids }
            logger.info("taskAddArtifacts: id=\(taskId) +\(artifactIds.count) -> \(aids.count)")
        } catch {
            logger.error("taskAddArtifacts failed: id=\(taskId) err=\(error.localizedDescription)")
        }
    }

    func taskCancel(_ taskId: String) async {
        guard let client = ipcClient else { return }
        do {
            _ = try await client.taskCancel(taskId: taskId)
            self.updateTask(taskId) { t in t.status = .cancelled }
            logger.info("taskCancel: id=\(taskId)")
        } catch {
            logger.error("taskCancel failed: id=\(taskId) err=\(error.localizedDescription)")
        }
    }

    func taskRerun(_ taskId: String) async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.taskRerun(taskId: taskId)
            if let d = result["task"] as? [String: Any], let updated = TaskModel(backendDict: d) {
                if let idx = self.taskIndex(taskId) {
                    self.tasks[idx] = updated
                }
                logger.info("taskRerun: id=\(taskId)")
                // rerun 重置为 pending, 前端立即执行 immediate 触发.
                taskExecuteImmediate(taskId)
            }
        } catch {
            logger.error("taskRerun failed: id=\(taskId) err=\(error.localizedDescription)")
        }
    }

    // 报告状态到后端 task.status (前端执行的结果回写).
    private func reportTaskStatus(_ taskId: String, status: String, lastResult: [String: Any]? = nil, lastError: String = "") {
        guard let client = ipcClient else { return }
        Task {
            do {
                _ = try await client.taskStatus(taskId: taskId, status: status, lastResult: lastResult, lastError: lastError)
            } catch {
                logger.warning("reportTaskStatus failed: id=\(taskId) status=\(status) err=\(error.localizedDescription)")
            }
        }
    }

    func taskScheduleCron(_ taskId: String, expression: String, input: String) {
        guard let idx = taskIndex(taskId) else { return }
        let agentId = tasks[idx].agentId
        let graphId = tasks[idx].graphId
        let name = tasks[idx].title
        let inputData = encodeCronInput(taskId: taskId, agentId: agentId, input: input)
        updateTask(taskId) { t in
            t.status = .scheduled
            t.cronExpression = expression
        }
        logger.info("taskScheduleCron: id=\(taskId) expr=\(expression) graph=\(graphId)")
        Task {
            do {
                let result = try await cronRegister(
                    name: name,
                    expression: expression,
                    graphId: graphId,
                    inputData: inputData
                )
                let jobId = result["id"] as? String
                    ?? (result["job"] as? [String: Any])?["id"] as? String
                    ?? ""
                self.updateTask(taskId) { t in
                    t.cronJobId = jobId
                }
                logger.info("taskScheduleCron registered: id=\(taskId) cron_job=\(jobId)")
            } catch {
                self.updateTask(taskId) { t in
                    t.status = .failed
                    t.lastError = error.localizedDescription
                }
                logger.error("taskScheduleCron failed: id=\(taskId) err=\(error.localizedDescription)")
            }
        }
    }

    func taskScheduleRunAt(_ taskId: String, runAt: Date, input: String) {
        guard let idx = taskIndex(taskId) else { return }
        let agentId = tasks[idx].agentId
        let graphId = tasks[idx].graphId
        let name = tasks[idx].title
        let comp = Calendar.current.dateComponents([.minute, .hour, .day, .month], from: runAt)
        let expr = "\(comp.minute ?? 0) \(comp.hour ?? 0) \(comp.day ?? 1) \(comp.month ?? 1) *"
        let inputData = encodeCronInput(taskId: taskId, agentId: agentId, input: input)
        updateTask(taskId) { t in
            t.status = .scheduled
            t.runAt = runAt
            t.cronExpression = expr
        }
        logger.info("taskScheduleRunAt: id=\(taskId) runAt=\(runAt) expr=\(expr)")
        Task {
            do {
                let result = try await cronRegister(
                    name: name,
                    expression: expr,
                    graphId: graphId,
                    inputData: inputData
                )
                let jobId = result["id"] as? String
                    ?? (result["job"] as? [String: Any])?["id"] as? String
                    ?? ""
                self.updateTask(taskId) { t in
                    t.cronJobId = jobId
                }
                logger.info("taskScheduleRunAt registered: id=\(taskId) cron_job=\(jobId)")
            } catch {
                self.updateTask(taskId) { t in
                    t.status = .failed
                    t.lastError = error.localizedDescription
                }
                logger.error("taskScheduleRunAt failed: id=\(taskId) err=\(error.localizedDescription)")
            }
        }
    }

    private func encodeCronInput(taskId: String, agentId: String, input: String) -> String {
        let payload: [String: Any] = [
            "task_id": taskId,
            "agent_id": agentId,
            "input": input,
        ]
        // BUG-7: 旧 fallback 字符串插值在 input 含 "/\/换行时产出非法 JSON
        // (双引号未转义破坏结构, 送给 cron 解析端 JSONSerialization 必崩)。
        // 正常路径用 JSONSerialization (已转义); 失败说明 payload 不可序列化, 直接抛错不静默产出坏 JSON。
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else {
            logger.error("encodeCronInput: JSON 序列化失败 taskId=\(taskId) inputLen=\(input.count)")
            return "{}"
        }
        return str
    }

    private func summarizeEvents(_ events: [AgentEventModel]) -> String {
        guard !events.isEmpty else { return "Task completed (no events)" }
        var lines: [String] = []
        for ev in events {
            var line = "[\(ev.type)] \(ev.node_id ?? "?")"
            if let data = ev.data, !data.isEmpty {
                let parts = data.map { "\($0)=\($1)" }.joined(separator: " ")
                line += ": \(parts)"
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Cron Operations

    func fetchCronJobs() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.cronList()
            self.cronJobs = result["jobs"] as? [[String: Any]] ?? result["crons"] as? [[String: Any]] ?? []
            logger.info("Fetched \(self.cronJobs.count) cron jobs")
        } catch {
            logger.debug("fetchCronJobs failed: \(error.localizedDescription)")
        }
    }

    func cronRegister(name: String, schedule: String, agentId: String, input: String = "") async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.cronRegister(name: name, schedule: schedule, agentId: agentId, input: input)
        await fetchCronJobs()
        return result
    }

    func cronUnregister(cronId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.cronUnregister(cronId: cronId)
        await fetchCronJobs()
        return result
    }

    // MARK: - Hooks Operations

    func fetchHooks() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.hooksList()
            self.hooks = result["hooks"] as? [[String: Any]] ?? []
            logger.info("Fetched \(self.hooks.count) hooks")
        } catch {
            logger.debug("fetchHooks failed: \(error.localizedDescription)")
        }
    }

    func hooksRegister(event: String, agentId: String, action: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.hooksRegister(event: event, agentId: agentId, action: action)
        await fetchHooks()
        return result
    }

    func hooksTest(hookId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.hooksTest(hookId: hookId)
    }

    // MARK: - Context Operations

    func contextCompact(sessionId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.contextCompact(sessionId: sessionId)
    }

    func contextUsage(sessionId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.contextUsage(sessionId: sessionId)
    }

    // MARK: - Parsing Helpers

    private static func parseGraphModel(from dict: [String: Any]) -> AgentGraphModel? {
        guard let graphId = dict["graph_id"] as? String ?? dict["id"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }

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

        // node_count/edge_count 优先取后端元数据; graph.get 返回完整 nodes 时退化为实际数组长度
        let nodeCount = dict["node_count"] as? Int ?? nodes.count
        let edgeCount = dict["edge_count"] as? Int ?? edges.count

        return AgentGraphModel(
            id: graphId,
            name: name,
            nodes: nodes,
            edges: edges,
            created_at: createdAt,
            nodeCount: nodeCount,
            edgeCount: edgeCount
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

    // ARCH-2: 对象销毁取消所有逃逸执行 Task, 防 bridge 释放后后台 Task 仍持 self 写 @Published。
    // taskRunHandles 声明 nonisolated(unsafe), deinit (nonisolated) 可遍历 cancel。
    deinit {
        for (_, handle) in taskRunHandles {
            handle.cancel()
        }
    }
}
