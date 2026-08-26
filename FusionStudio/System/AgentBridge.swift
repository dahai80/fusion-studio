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

    // F-I10: 统一脱敏出口。catch 块把任意 Error 转 i18n 用户消息, 不裸抛底层错误 (含路径/端口/堆栈)。
    // BridgeError 走 userMessage (已 i18n+按 token 脱敏); 非 BridgeError 走 generic 通用兜底, 不泄露 detail。
    static func sanitize(_ error: Error) -> String {
        if let bridgeErr = error as? BridgeError {
            return bridgeErr.userMessage
        }
        agentBridgeStaticLog.error("F-I10 sanitize non-bridge error (detail suppressed): \(String(describing: error), privacy: .public)")
        return I18nManager.shared.t(.ab_err_generic)
    }

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

    // F-A1/F-I1: 7 域子对象, 各独立 ObservableObject 持自己的 @Published (见 AgentBridgeDomains.swift)。
    // 持同一实例 (let 稳定身份), SwiftUI 经 bridge.<state>.X 自动追踪。@Published 分阶段从主类迁入域。
    let runtimeState = RuntimeState()
    let mlxState = MLXState()
    let agentState = AgentState()
    let moduleState = ModuleState()
    let taskState = TaskState()
    let configState = ConfigState()
    let projectChatState = ProjectChatState()

    @Published var isConnected: Bool = false
    @Published var graphs: [AgentGraphModel] = []
    @Published var events: [AgentEventModel] = []
    @Published var isExecuting: Bool = false
    // F-A1 Phase 4: chatMessages/isInferring 已迁 ProjectChatState 域 (AgentProjectChatService facade 写, 0 SwiftUI 读 write-only)。
    @Published var dashboardData: [String: Any] = [:]
    // F-A1 Phase 1: models/mlxRunning/mlxLoadedModels/mlxPort 已迁 MLXState 域 (AgentBridgeDomains.swift)。
    // F-A2子3: 以下 2 个 AgentMlxService facade extension 跨文件访问, 故 internal。
    var mlxStatusTimer: Timer?
    var mlxStatusFetchedAt: Date?
    // F-A2子2: 30s TTL 客户端缓存, 防 onAppear fetch 风暴。写操作置 nil 强制下次重拉。
    // extension 不可声明存储属性, 故 8 个 fetch 时间戳集中主类, facade extension 读 self.xxxFetchedAt。
    private var apikeysFetchedAt: Date?
    private var projectsFetchedAt: Date?
    private var tasksFetchedAt: Date?
    private var cronJobsFetchedAt: Date?
    // F-A2子2: 以下 4 个 facade extension 跨文件访问, 故 internal (非 private, Swift private=文件作用域)。
    var stylesFetchedAt: Date?
    var hooksFetchedAt: Date?
    var connectorsFetchedAt: Date?
    var alertsFetchedAt: Date?

    // ARCH-2: 逃逸 Task 生命周期管理。taskExecuteImmediate 的 fire-and-forget Task 存 handle,
    // 按 taskId 索引。任务删除/对象销毁时 cancel, 防 view 销毁后后台 Task 仍写 @Published。
    // F-R9: nonisolated(unsafe) 字典 + deinit(nonisolated)遍历cancel + @MainActor写 = 真竞态崩溃。
    // NSLock 保护所有读写, deinit 也持锁, 消除 Dictionary 并发修改 EXC_BAD_ACCESS。
    nonisolated private let taskHandlesLock = NSLock()
    nonisolated(unsafe) private var taskRunHandles: [String: Task<Void, Never>] = [:]

    nonisolated private func lockedTaskHandle<T>(_ body: () -> T) -> T {
        taskHandlesLock.lock()
        defer { taskHandlesLock.unlock() }
        return body()
    }

    // F-R12: 跨任务后端熔断 + 统一退避。
    // 后端 (MLX/daemon) 故障时, N 个排队任务各自重试 maxRetries 次 = 雪崩放大器。
    // 熔断: 连续 failureThreshold 次失败后开路, 新重试 fast-fail 不再打后端;
    // 任一成功复位。退避: 指数 1s→2s→4s 封顶 + ±12.5% jitter, 避免瞬时重打恢复中的引擎。
    private let backendFailureThreshold = 5
    private var backendConsecutiveFailures: Int = 0
    private var backendCircuitOpen: Bool = false

    // 指数退避 (s): 1 → 2 → 4 封顶, 按 retryCount 取, 加 ±12.5% jitter。
    private func retryBackoffSeconds(retryCount: Int) -> Double {
        let base = min(Double(1 << min(retryCount, 2)), 4.0)
        let jitter = Double.random(in: 0.875...1.125)
        return base * jitter
    }

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
    // F-A1: 以下 7 个 @Published 原散落 Agent Ops/Lifecycle MARK 中, 抽 facade 时迁此集中声明
    // (extension 不可声明存储属性)。extension 内写 self.<prop>, 观察链不变。
    @Published var agentVersionHistory: [String: [[String: Any]]] = [:]
    @Published var auditTrail: [[String: Any]] = []
    @Published var sessionLogs: [[String: Any]] = []
    @Published var activeSessionId: String = ""
    @Published var streamingContent: String = ""
    @Published var isAgentStreaming: Bool = false
    @Published var lastToolCalls: [[String: Any]] = []

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
            let result = try await client.call(method: RPCMethod.ping)
            let pong = result["pong"] as? Bool ?? false
            self.isConnected = pong
            logger.info("checkHealth: connected=\(pong)")
            return pong
        } catch let error as IPCError {
            self.isConnected = false
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

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
                    try await client.call(method: RPCMethod.envHealthCheck)
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
            logger.error("fullHealthCheck: timeout after 8s (env.health_check did not respond)")
            throw BridgeError.timeout
        }
        self.isConnected = true
        return result
    }

    // 复核 MLX 是否可达：直接走 HTTP /v1/models（app 复用外部 mlx gateway :11432）。
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
        return try await client.call(method: RPCMethod.envRepair, params: ["item_id": itemId])
    }

    func repairAll() async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        return try await client.call(method: RPCMethod.envRepairAll)
    }

    // MARK: - Graph Operations
    // ARCH-1: fetchGraphs/createGraph/graphGet/updateGraph + parseGraphModel 抽至 AgentGraphService.swift facade extension
    // (耦合同迁: parseGraphModel private static + 6 调用方 = 4 graph + templateInstantiate + deployImport, private = 文件作用域必须同文件)。
    // deleteGraph/executeGraph/cancelExecution 留此: executeGraph 依赖 Self.parseEventModel (Event 域 private) + 写共享 events/isExecuting;
    //   deleteGraph/cancelExecution 无 parseGraphModel 依赖, 留以保持 Graph Ops MARK 完整语义。

    func deleteGraph(id: String) async throws {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("deleteGraph: id=\(id)")
        do {
            _ = try await client.call(method: RPCMethod.graphDelete, params: ["graph_id": id])
            logger.info("deleteGraph: deleted id=\(id, privacy: .public)")
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

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
            let result = try await client.call(method: RPCMethod.graphExecute, params: params)

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

            logger.error("executeGraph: \(error)")
            throw bridgeErr
        } catch {
            self.isExecuting = false
            let bridgeErr = BridgeError.decodeError(error.localizedDescription)

            logger.error("executeGraph decode: \(error)")
            throw bridgeErr
        }
    }

    func cancelExecution() {
        logger.info("cancelExecution")
        self.isExecuting = false
    }

    func fetchTools() async throws -> [[String: Any]] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("fetchTools")
        do {
            let result = try await client.call(method: RPCMethod.toolList, params: [:])
            let tools = result["tools"] as? [[String: Any]] ?? []
            self.tools = tools
            return tools
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

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

            throw bridgeErr
        }
    }

    func getTool(name: String) async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("getTool: \(name)")
        do {
            return try await client.call(method: RPCMethod.toolGet, params: ["name": name])
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

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
            let result = try await client.call(method: RPCMethod.sessionList, params: [:]) as [String: Any]
            if let sessions = result["sessions"] as? [[String: Any]] {
                return sessions
            }
            return []
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

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
            return try await client.call(method: RPCMethod.cronRegister, params: params)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func cronUnregister(id: String) async throws -> [String: Any] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("cronUnregister: \(id)")
        do {
            return try await client.call(method: RPCMethod.cronUnregister, params: ["id": id])
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func cronList() async throws -> [[String: Any]] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("cronList")
        do {
            let result = try await client.call(method: RPCMethod.cronList, params: [:]) as [String: Any]
            if let jobs = result["jobs"] as? [[String: Any]] {
                return jobs
            }
            return []
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

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
            let result = try await client.call(method: RPCMethod.cronListExecutions, params: params) as [String: Any]
            if let executions = result["executions"] as? [[String: Any]] {
                return executions
            }
            return []
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

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

            logger.error("knowledgeSearch: \(error)")
            throw bridgeErr
        }
    }

    // MARK: - MLX Operations

    // ARCH-1 / F-A1: fetchModels (×2) + startMLX/stopMLX/restartMLX/mlxStatus/mlxSetModel 6 方法抽至
    // AgentMlxService.swift facade extension。@Published models/mlxRunning/mlxLoadedModels/mlxPort 已迁 MLXState 域, extension 写 self.mlxState.X。
    // 下方 3 个 nonisolated static 留主类: Project Chat selfHealApiKeyForInfer 跨域调 Self.mlxSelfHealKeyCandidates。

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

    // ARCH-1: RAG Operations (ragQuery/ragRetrieve/ragVectorSearch) 抽至 AgentRAGService.swift facade extension。
    // @Published ragResults/ragSources + ipcClient 留本类 (extension 不可声明存储), 0 行为零变。

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

            throw bridgeErr
        }
    }

    // MARK: - Memory Operations
    // ARCH-1: memoryStore/memoryRecall/fetchRecentMemories/memoryDelete/memoryDeleteScope/fetchMemoryCount
    //   + parseMemoryEntry (域内专属 parser, 4 调用方全 Memory 域) 抽至 AgentMemoryService.swift facade extension。
    //   parser 同搬范式 (同 #287 parseMarketplaceEntry): private = 文件作用域, 同文件 extension Self.parseMemoryEntry 可达。
    //   0 跨域调用, 域内 @Published memoryEntries/memoryCount。@Published 留主类 (有外部读)。
    //   MAINT: memoryGet 删 (0 前端调用方, UI 无单条详情视图)。

    // MARK: - Safety Operations
    // ARCH-1: safetyCheck/safetyEvaluateAction/safetyApproveAction/safetyRejectAction/fetchPendingSafetyActions/safetyAddPolicy
    //   抽至 AgentSafetyService.swift facade extension。叶 silo (域内 Model 构造, 无 parser, 无持久状态)。
    //   safetyEvaluateAction/fetchPendingSafetyActions 用 UUID → Foundation。@Published safetyCheckResult/safetyPendingActions 留主类 (有外部读)。

    // ARCH-1: Template Operations 全量抽完 (fetchTemplates/templateGet → AgentTemplateService #284, templateInstantiate → AgentGraphService 本批次)。
    // ARCH-1: Deploy Operations 全量抽完 (deployExport/fetchDeployFormats → AgentDeployService #285, deployImport → AgentGraphService 本批次)。
    // templateInstantiate/deployImport 随 parseGraphModel 同搬 AgentGraphService.swift (private = 文件作用域, 必须同文件)。

    // MARK: - Connector Operations
    // ARCH-1: fetchConnectors/connectorCreate/connectorDelete/connectorConnect/connectorDisconnect/connectorTest
    //   抽至 AgentConnectorService.swift facade extension。叶 silo: 0 private 静态依赖, 0 持久状态。
    //   connectorCreate/Delete 调 fetchConnectors (同域, extension 内可达)。@Published connectors 已迁 ConfigState 域。

    // MARK: - API Key Operations

    // F-A1 Phase 2: apikeys 已迁 ConfigState 域。

    func fetchApikeys() async {
        if let t = apikeysFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        apikeysFetchedAt = Date()
        guard let client = ipcClient else { return }
        do {
            let result = try await client.apikeyList()
            self.configState.apikeys = result["keys"] as? [[String: Any]] ?? []
            logger.info("Fetched \(self.configState.apikeys.count) API keys")
        } catch {
            logger.debug("fetchApikeys failed: \(error.localizedDescription)")
        }
    }

    func apikeyCreate(name: String, permissions: [String] = [], agentIds: [String] = []) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.apikeyCreate(name: name, permissions: permissions, agentIds: agentIds)
        apikeysFetchedAt = nil
        await fetchApikeys()
        return result
    }

    func apikeyRevoke(keyId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.apikeyRevoke(keyId: keyId)
        apikeysFetchedAt = nil
        await fetchApikeys()
        return result
    }

    func apikeyRotate(keyId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.call(method: RPCMethod.agentStudioApikeyRotate, params: ["key_id": keyId])
        apikeysFetchedAt = nil
        await fetchApikeys()
        logger.info("Rotated API key: \(keyId)")
        return result
    }

    // MARK: - Style Operations
    // ARCH-1: fetchStyles/styleCreate/styleDelete 抽至 AgentStyleService.swift facade extension。
    // 本域最薄叶 silo: 0 private 静态依赖, 0 持久状态。styleCreate/Delete 调 fetchStyles (同域, extension 内可达)。
    // @Published styles 已迁 ConfigState 域 (有外部读)。

    // MARK: - Analytics & Alert Operations
    // ARCH-1: fetchAnalytics/fetchAlerts/alertAcknowledge 抽至 AgentAnalyticsService.swift facade extension。
    // @Published analyticsData/alerts 已迁 ConfigState 域 (有外部 SwiftUI 读 AgentConfigTabs)。

    // MARK: - Team Operations
    // ARCH-1: teamOrchestrate/fetchSwarmAgents/fetchPlazaChannels 抽至 AgentTeamService.swift facade extension。
    //   叶 silo: 0 private static, 0 持久状态。fetchSwarmAgents/fetchPlazaChannels UI onAppear 刷新读。
    //   @Published swarmAgents/plazaChannels 已迁 ConfigState 域 (有外部读)。
    //   MAINT: teamSwarmRegister/Delegate/Stats + teamPlazaCreate/Broadcast 删 (0 前端调用方, UI 只读列表)。

    // MARK: - Task Operations
    // @Published self.taskState.tasks/self.taskState.projects 已迁 TaskState 域 (有外部 SwiftUI 读 TaskQueueView/ProjectsPanel)。

    // 从后端 task.list 拉取持久化任务. 后端 5 态 → 前端 7 态.
    func fetchTasks() async {
        if let t = tasksFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        tasksFetchedAt = Date()
        guard let client = ipcClient else { return }
        do {
            let result = try await client.taskList(limit: 200)
            let raw = result["self.taskState.tasks"] as? [[String: Any]] ?? []
            var parsed: [TaskModel] = []
            for d in raw {
                if let t = TaskModel(backendDict: d) { parsed.append(t) }
            }
            self.taskState.tasks = parsed
            logger.info("fetchTasks: \(parsed.count) backend self.taskState.tasks")
        } catch {
            logger.warning("fetchTasks failed: \(error.localizedDescription)")
        }
    }

    // 拉取 Project 聚合看板桶 (#141 priority-2). 后端 project.list 按 project_id 分组统计.
    func fetchProjects() async {
        if let t = projectsFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        projectsFetchedAt = Date()
        guard let client = ipcClient else { return }
        do {
            let result = try await client.projectList()
            let raw = result["self.taskState.projects"] as? [[String: Any]] ?? []
            var parsed: [ProjectBucket] = []
            for d in raw {
                if let b = ProjectBucket(backendDict: d) { parsed.append(b) }
            }
            self.taskState.projects = parsed
            logger.info("fetchProjects: \(parsed.count) self.taskState.projects")
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
        self.taskState.tasks.firstIndex(where: { $0.id == id })
    }

    private func updateTask(_ id: String, _ mutate: (inout TaskModel) -> Void) {
        guard let idx = taskIndex(id) else { return }
        mutate(&self.taskState.tasks[idx])
        self.taskState.tasks[idx].updatedAt = Date()
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
            self.taskState.tasks[idx] = saved
        } else {
            self.taskState.tasks.append(saved)
            // F-A2: self.taskState.tasks 无界 append, 连续提交不 fetch 时单调增长。保留最近 500 (LRU),
            // 超额丢弃最旧。PERF-3 ragResults 范式。
            if self.taskState.tasks.count > 500 {
                self.taskState.tasks.removeFirst(self.taskState.tasks.count - 500)
            }
        }
        logger.info("taskSubmit: id=\(saved.id) title=\(title) trigger=\(trigger.rawValue) cron_job=\(saved.cronJobId)")
        return saved
    }

    func taskExecuteImmediate(_ taskId: String) {
        guard let idx = taskIndex(taskId) else { return }
        let agentId = self.taskState.tasks[idx].agentId
        let graphId = self.taskState.tasks[idx].graphId
        let inputText = self.taskState.tasks[idx].input
        updateTask(taskId) { t in
            t.status = .running
            t.lastRunAt = Date()
            t.lastError = ""
        }
        reportTaskStatus(taskId, status: "running")
        logger.info("taskExecuteImmediate: id=\(taskId) agent=\(agentId) graph=\(graphId)")
        // ARCH-2: 存 Task handle。重复执行同 taskId 先 cancel 旧 handle (防并发重复跑)。
        // F-R9: 持锁读写, 防与 deinit 并发崩溃。
        lockedTaskHandle { taskRunHandles[taskId]?.cancel() }
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
                // F-R9: 持锁删, 防并发崩溃。
                self.lockedTaskHandle { self.taskRunHandles.removeValue(forKey: taskId) }
                logger.info("taskExecuteImmediate done: id=\(taskId) events=\(eventsParsed.count)")
                // F-R12: 成功复位熔断器, 允许后续任务恢复正常重试。
                if self.backendCircuitOpen || self.backendConsecutiveFailures > 0 {
                    logger.info("F-R12 backend recovered, circuit closed failures=\(self.backendConsecutiveFailures)")
                    self.backendConsecutiveFailures = 0
                    self.backendCircuitOpen = false
                }
                self.reportTaskStatus(taskId, status: "completed", lastResult: ["summary": summary, "events": eventsParsed.count])
            } catch is CancellationError {
                self.updateTask(taskId) { t in
                    if t.status != .completed { t.status = .cancelled }
                }
                logger.info("taskExecuteImmediate cancelled: id=\(taskId)")
            } catch {
                self.updateTask(taskId) { t in
                    t.lastError = BridgeError.sanitize(error)
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
                let cur = self.taskState.tasks[idx]
                // F-R12: 计入后端连续失败, 达阈值开路熔断。
                backendConsecutiveFailures += 1
                if backendConsecutiveFailures >= backendFailureThreshold && !backendCircuitOpen {
                    backendCircuitOpen = true
                    logger.error("F-R12 backend circuit OPEN failures=\(self.backendConsecutiveFailures) — fast-fail retries until a task succeeds")
                }
                // ARCH-2: retry 上限收紧 + 退避, 防 maxRetries 过大时高频重试风暴。
                // retryCount 已 +1, 仅当未超 maxRetries 才重排。
                // F-R12: 熔断开路时跳过重试 fast-fail, 避免雪崩放大; 退避改指数 + jitter。
                let shouldRetry = cur.retryCount <= cur.maxRetries && !backendCircuitOpen
                if shouldRetry {
                    let backoffNs = UInt64(retryBackoffSeconds(retryCount: cur.retryCount) * 1_000_000_000)
                    self.updateTask(taskId) { t in t.status = .queued }
                    logger.warning("taskExecuteImmediate retry: id=\(taskId) retryCount=\(cur.retryCount)/\(cur.maxRetries) backoffMs=\(backoffNs / 1_000_000) circuit=\(self.backendCircuitOpen)")
                    Task {
                        try? await Task.sleep(nanoseconds: backoffNs)
                        if Task.isCancelled {
                            logger.info("taskExecuteImmediate retry cancelled: id=\(taskId)")
                            return
                        }
                        self.taskExecuteImmediate(taskId)
                    }
                } else {
                    let reason = backendCircuitOpen ? "circuit-open" : "retries-exhausted"
                    self.updateTask(taskId) { t in t.status = .failed }
                    // F-R9: 持锁删, 防并发崩溃。
                    self.lockedTaskHandle { self.taskRunHandles.removeValue(forKey: taskId) }
                    logger.error("taskExecuteImmediate failed: id=\(taskId) reason=\(reason) retryCount=\(cur.retryCount) err=\(error.localizedDescription)")
                }
                self.reportTaskStatus(taskId, status: "failed", lastError: error.localizedDescription)
            }
        }
        // F-R9: 持锁写入, 防与 deinit/taskCancel 并发崩溃。
        lockedTaskHandle { taskRunHandles[taskId] = handle }
    }

    // 上游 task.delete RPC 已落地 (PR#148); 真删 + 注销关联 cron job (后端处理).
    func taskDelete(_ taskId: String) {
        guard let client = ipcClient else { return }
        // ARCH-2: 删任务先 cancel 在跑的执行 Task, 防 RPC 删后后台 Task 仍写已删任务状态。
        // F-R9: 持锁读写, 防并发崩溃。
        lockedTaskHandle {
            taskRunHandles[taskId]?.cancel()
            taskRunHandles.removeValue(forKey: taskId)
        }
        Task {
            do {
                _ = try await client.taskDelete(taskId: taskId)
                self.taskState.tasks.removeAll { $0.id == taskId }
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
        // F-R3: 真取消。先 cancel 本地 Task handle (停止前端轮询/写状态), 再通知后端 RPC。
        // 旧实现只 RPC + 置 .cancelled, 本地 Task 仍跑完写 .completed 覆盖。
        // F-R9: 持锁读写, 防并发崩溃。
        lockedTaskHandle { taskRunHandles[taskId]?.cancel() }
        guard let client = ipcClient else { return }
        do {
            _ = try await client.taskCancel(taskId: taskId)
            self.updateTask(taskId) { t in
                if t.status != .completed { t.status = .cancelled }
            }
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
                    self.taskState.tasks[idx] = updated
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
        let agentId = self.taskState.tasks[idx].agentId
        let graphId = self.taskState.tasks[idx].graphId
        let name = self.taskState.tasks[idx].title
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
                    t.lastError = BridgeError.sanitize(error)
                }
                logger.error("taskScheduleCron failed: id=\(taskId) err=\(error.localizedDescription)")
            }
        }
    }

    func taskScheduleRunAt(_ taskId: String, runAt: Date, input: String) {
        guard let idx = taskIndex(taskId) else { return }
        let agentId = self.taskState.tasks[idx].agentId
        let graphId = self.taskState.tasks[idx].graphId
        let name = self.taskState.tasks[idx].title
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
                    t.lastError = BridgeError.sanitize(error)
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
    // @Published cronJobs 已迁 ConfigState 域 (有外部 SwiftUI 读 TaskQueueView cron 区)。

    func fetchCronJobs() async {
        if let t = cronJobsFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        cronJobsFetchedAt = Date()
        guard let client = ipcClient else { return }
        do {
            let result = try await client.cronList()
            self.configState.cronJobs = result["jobs"] as? [[String: Any]] ?? result["crons"] as? [[String: Any]] ?? []
            logger.info("Fetched \(self.configState.cronJobs.count) cron jobs")
        } catch {
            logger.debug("fetchCronJobs failed: \(error.localizedDescription)")
        }
    }

    func cronRegister(name: String, schedule: String, agentId: String, input: String = "") async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.cronRegister(name: name, schedule: schedule, agentId: agentId, input: input)
        cronJobsFetchedAt = nil
        await fetchCronJobs()
        return result
    }

    func cronUnregister(cronId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.cronUnregister(cronId: cronId)
        cronJobsFetchedAt = nil
        await fetchCronJobs()
        return result
    }

    // MARK: - Hooks Operations
    // ARCH-1: fetchHooks/hooksRegister/hooksTest 抽至 AgentHooksService.swift facade extension。
    // 本域最薄叶 silo: 0 private 静态依赖, 0 持久状态, 0 跨域调用。@Published hooks 已迁 ConfigState 域 (有外部读)。

    // MARK: - Context Operations
    // ARCH-1: contextCompact/contextUsage 抽至 AgentContextService.swift facade extension。本域最简单: 2 薄透传, 0 @Published, 0 private 静态依赖。

    // MARK: - Parsing Helpers
    // ARCH-1: parseGraphModel 抽至 AgentGraphService.swift (private = 文件作用域, 与 6 调用方同文件)。

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

    // ARCH-1: anyToJSONValue 通用 Any→JSONValue 转换器 (非域 parser), private→internal。
    // 被 parseEventModel (留本文件, Event 域) + parseGraphModel (抽至 AgentGraphService.swift, Graph 域) 共用。
    // 仅 widen 通用 helper, 域 parser (parseEventModel/parsePlanModel 等) 仍 private, "不 widen 域 parser" 约定不变。
    static func anyToJSONValue(_ value: Any) -> JSONValue? {
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

    // ARCH-1: parseMemoryEntry (memory-specific private static, 4 调用方全 Memory 域) 抽至 AgentMemoryService.swift,
    //   与 7 Memory 方法同文件 (private = 文件作用域, 同文件 extension Self.parseMemoryEntry 可达, 同 #287 parseMarketplaceEntry 范式)。

    // ARCH-1: parseMarketplaceEntry (marketplace-specific private static) 抽至 AgentMarketplaceService.swift, 仅 3 调用方全在该 extension。

    // ARCH-2: 对象销毁取消所有逃逸执行 Task, 防 bridge 释放后后台 Task 仍持 self 写 @Published。
    // taskRunHandles 声明 nonisolated(unsafe), deinit (nonisolated) 可遍历 cancel。
    deinit {
        // F-R9: 持锁拷贝再遍历 cancel, 避免遍历中 @MainActor 写入并发修改崩溃
        let handles = lockedTaskHandle { Array(taskRunHandles.values) }
        for handle in handles {
            handle.cancel()
        }
    }
}
