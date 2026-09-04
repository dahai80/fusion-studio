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

// 审计0902 R1 (P1): executeGraph 并发串行锁。limit=1 = mutex, 串行化所有 executeGraph 调用
//   (UI 手动 + 任务调度底层), 防共享 runtimeState.events/isExecuting 并发互覆。
nonisolated private let graphInflightLock = AsyncTaskSemaphore(limit: 1)

// 审计0830 P0-4: 异步并发信号量。限制 taskExecuteImmediate 并发上限, 防后端 (单机 MLX) 过载 +
//   重试风暴雪崩。actor 保证 acquire/release 原子, async wait 不阻塞线程。
//   单机 MLX 串行推理, 并发 graph.execute 只会挤占健康轮询连接 (P0-2) + OOM, cap 4 合理。
actor AsyncTaskSemaphore {
    private var available: Int
    private let limit: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(limit: Int) {
        self.limit = limit
        self.available = limit
    }
    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }
    func release() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else if available < limit {
            available += 1
        }
    }
}

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

// F-I4: 动态字符串键, 支持 dual-key (agent_id/id, graph_id/id, plan_id/id, step_id/id) 双读。
// 顶层声明 (非嵌 AgentBridge), 各 model struct 的 init(from:) 同文件可达。
struct FAnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = String(intValue) }
    static func key(_ s: String) -> FAnyKey { return FAnyKey(stringValue: s)! }
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

    // F-I4: graph_id/id dual-key + nodes dict-vs-array + created_at Double-or-String + node_count/edge_count fallback。
    // memberwise init 仅 parseGraphModel 内用, 抑制安全。nodes/edges catch-all config 不经 NodeConfigModel 合成 Codable
    // (wire 无 config 键, config 是除 id/type/label 外全部字段的 catch-all) → 解 raw [String:JSONValue] 手建 memberwise。
    enum GraphKeys: String, CodingKey {
        case id, name, nodes, edges, created_at, node_count, edge_count, graph_id
    }
    init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: GraphKeys.self)
        let c = try decoder.container(keyedBy: FAnyKey.self)
        if let v = try? c.decodeIfPresent(String.self, forKey: .key("graph_id")) { id = v }
        else if let v = try? top.decodeIfPresent(String.self, forKey: .id) { id = v }
        else { id = "" }
        name = (try? top.decodeIfPresent(String.self, forKey: .name)) ?? ""
        nodes = try Self.decodeNodes(from: top)
        edges = try Self.decodeEdges(from: top)
        created_at = try Self.decodeCreatedAt(from: top)
        nodeCount = (try? top.decodeIfPresent(Int.self, forKey: .node_count)) ?? nodes.count
        edgeCount = (try? top.decodeIfPresent(Int.self, forKey: .edge_count)) ?? edges.count
    }
    // nodes dict 形态 {nodeId: {type:.., <rest>}} — id 是 dict key, 其余全进 config。
    // nodes array 形态 [{id:.., type:.., label:.., <rest>}] — 除 id/type/label 外全进 config。
    private static func decodeNodes(from top: KeyedDecodingContainer<GraphKeys>) throws -> [NodeConfigModel] {
        var out: [NodeConfigModel] = []
        if let dict = try? top.decode([String: [String: JSONValue]].self, forKey: .nodes) {
            for (nodeId, fields) in dict {
                let type = strVal(fields["type"]) ?? "llm"
                var config: [String: JSONValue] = [:]
                for (k, v) in fields where k != "type" {
                    config[k] = v
                }
                out.append(NodeConfigModel(id: nodeId, type: type, config: config, position: nil))
            }
        } else if let arr = try? top.decode([[String: JSONValue]].self, forKey: .nodes) {
            for fields in arr {
                let nodeId = strVal(fields["id"]) ?? UUID().uuidString
                let type = strVal(fields["type"]) ?? "llm"
                var config: [String: JSONValue] = [:]
                for (k, v) in fields where k != "id" && k != "type" && k != "label" {
                    config[k] = v
                }
                out.append(NodeConfigModel(id: nodeId, type: type, config: config, position: nil))
            }
        }
        return out
    }
    // edges array — source_id/source, target_id/target, label/condition dual-key。
    private static func decodeEdges(from top: KeyedDecodingContainer<GraphKeys>) throws -> [EdgeModel] {
        var out: [EdgeModel] = []
        guard let arr = try? top.decode([[String: JSONValue]].self, forKey: .edges) else { return out }
        for e in arr {
            let source = strVal(e["source_id"]) ?? strVal(e["source"]) ?? ""
            let target = strVal(e["target_id"]) ?? strVal(e["target"]) ?? ""
            let condition = strVal(e["label"]) ?? strVal(e["condition"])
            let id = strVal(e["id"]) ?? UUID().uuidString
            out.append(EdgeModel(id: id, source: source, target: target, condition: condition))
        }
        return out
    }
    // created_at Double(timestamp)→格式化字符串, 或 String 直取。
    private static func decodeCreatedAt(from top: KeyedDecodingContainer<GraphKeys>) throws -> String {
        if let ts = try? top.decodeIfPresent(Double.self, forKey: .created_at) {
            let date = Date(timeIntervalSince1970: ts)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return formatter.string(from: date)
        }
        return (try? top.decodeIfPresent(String.self, forKey: .created_at)) ?? ""
    }
    private static func strVal(_ v: JSONValue?) -> String? {
        if case .string(let s) = v { return s }
        return nil
    }
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

    // F-I4: MLX /v1/models 响应 → JSONDecoder。derived name=id (匹配旧 parser), object/owned_by optional 宽容。
    enum CodingKeys: String, CodingKey { case id, name, object, owned_by }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? ""
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? id
        object = try? c.decodeIfPresent(String.self, forKey: .object)
        owned_by = try? c.decodeIfPresent(String.self, forKey: .owned_by)
    }
    // memberwise init: AgentMlxService fetchModels 构造 (derived name=id)。
    init(id: String, name: String, object: String? = nil, owned_by: String? = nil) {
        self.id = id
        self.name = name
        self.object = object
        self.owned_by = owned_by
    }

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
    // 审计0827 #4: IPCError (Hub*View 经 IPCClient.call 抛) 也经此脱敏 — 映射 BridgeError.rpcError 取按 code 的 i18n 用户消息, 不裸泄 message。
    static func sanitize(_ error: Error) -> String {
        // 审计0830 P0-9: 旧逻辑仅对非 BridgeError 记日志, rpcError/ipcError 的诊断 message 被丢弃 →
        //   生产故障无任何诊断, 运维盲调。修复: 统一在脱敏前记录完整诊断 detail (本地 os_log, 不暴露用户面),
        //   用户面仍返 i18n 脱敏消息。日志面/用户面分离。
        if let bridgeErr = error as? BridgeError {
            agentBridgeStaticLog.error("F-I10 sanitize BridgeError (log detail): \(bridgeErr.detail, privacy: .public)")
            return bridgeErr.userMessage
        }
        if let ipcErr = error as? IPCError {
            agentBridgeStaticLog.error("F-I10 sanitize IPCError (log detail): \(ipcErr.localizedDescription, privacy: .public)")
            // 审计0830 P2-错误-1~10: 旧实现传空 message 给 ipcError/rpcError → userMessage 的 msg.contains 语义分类全部恒失败,
            //   10 处映射 (connection refused / timed out / HTTP 4xx5xx / 401/403/404) 全失效, 统一走 ab_err_unavailable 兜底。
            //   修复: 传 IPCError 真实诊断串 (localizedDescription 含 "connection refused"/"timed out" 等), 让 userMessage 按语义分类。
            //   用户面仍 i18n (userMessage 不裸泄 msg, 只 contains 匹配), 不违脱敏原则。
            if case .rpcError(let code, _) = ipcErr {
                return BridgeError.rpcError(code: code, message: ipcErr.localizedDescription).userMessage
            }
            return BridgeError.ipcError(ipcErr.localizedDescription).userMessage
        }
        agentBridgeStaticLog.error("F-I10 sanitize non-bridge error (log detail): \(String(describing: error), privacy: .public)")
        return I18nManager.shared.t(.ab_err_generic)
    }

    case notConnected
    case ipcError(String)
    case decodeError(String)
    case rpcError(code: Int, message: String)
    case timeout
    case serviceUnavailable(String)
    case authFailed(String)
    case guardBlocked(String)
    // 审计product-0905 FUNC-2/3/4/9: 上游后端未实现 RPC (-32601) → 友好降级, 不裸泄 "Method not found"。
    case featureUnavailable(String)

    var detail: String {
        switch self {
        case .notConnected: return "notConnected — IPC socket not connected"
        case .ipcError(let msg): return "ipcError — \(msg)"
        case .decodeError(let msg): return "decodeError — \(msg)"
        case .rpcError(let code, let msg): return "rpcError(\(code)) — \(msg)"
        case .timeout: return "timeout"
        case .serviceUnavailable(let msg): return "serviceUnavailable — \(msg)"
        case .authFailed(let msg): return "authFailed — \(msg)"
        case .guardBlocked(let msg): return "guardBlocked — \(msg)"
        case .featureUnavailable(let method): return "featureUnavailable — \(method)"
        }
    }

    var userMessage: String {
        let i18n = I18nManager.shared
        switch self {
        case .notConnected:
            return i18n.t(.ab_err_not_connected)
        case .serviceUnavailable:
            return i18n.t(.ab_err_service_down)
        case .featureUnavailable:
            return i18n.t(.ab_err_feature_unavailable)
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
        case .guardBlocked(let msg):
            return i18n.tf(.ab_err_guard_blocked_fmt, msg)
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

    // F-I4: step_id/id dual-key。memberwise 仅 parsePlanModel 内用, 抑制安全。
    enum StepKeys: String, CodingKey { case id, description, status, result, step_id }
    init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: StepKeys.self)
        let c = try decoder.container(keyedBy: FAnyKey.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .key("step_id"))) ?? (try? top.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        description = (try? top.decodeIfPresent(String.self, forKey: .description)) ?? ""
        status = (try? top.decodeIfPresent(String.self, forKey: .status)) ?? "pending"
        result = try? top.decodeIfPresent(String.self, forKey: .result)
    }
}

struct PlanModel: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var task: String
    var status: String
    var steps: [PlanStepModel]
    var context: String
    var created_at: String

    // F-I4: plan_id/id dual-key。memberwise 仅 parsePlanModel 内用, 抑制安全。
    enum PlanKeys: String, CodingKey { case id, task, status, steps, context, created_at, plan_id }
    init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: PlanKeys.self)
        let c = try decoder.container(keyedBy: FAnyKey.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .key("plan_id"))) ?? (try? top.decodeIfPresent(String.self, forKey: .id)) ?? ""
        task = (try? top.decodeIfPresent(String.self, forKey: .task)) ?? ""
        status = (try? top.decodeIfPresent(String.self, forKey: .status)) ?? "draft"
        steps = (try? top.decodeIfPresent([PlanStepModel].self, forKey: .steps)) ?? []
        context = (try? top.decodeIfPresent(String.self, forKey: .context)) ?? ""
        created_at = (try? top.decodeIfPresent(String.self, forKey: .created_at)) ?? ""
    }
}

struct RAGResultModel: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var answer: String
    var sources: [String]
    var query: String

    // F-I4: IPC rag.query 响应 → JSONDecoder。query 调用方注入 (RagTabView/ragQuery), 缺键 ?? placeholder ""。
    enum CodingKeys: String, CodingKey { case id, answer, sources, query }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        answer = (try? c.decodeIfPresent(String.self, forKey: .answer)) ?? ""
        sources = (try? c.decodeIfPresent([String].self, forKey: .sources)) ?? []
        query = (try? c.decodeIfPresent(String.self, forKey: .query)) ?? ""
    }
    // memberwise init: ragQuery 调用方注 query, IntegrationTests 构造。保 id/sources default。
    init(id: String = UUID().uuidString, answer: String, sources: [String] = [], query: String = "") {
        self.id = id
        self.answer = answer
        self.sources = sources
        self.query = query
    }
}

struct MemoryEntryModel: Codable, Equatable, Identifiable {
    var id: String
    var content: String
    var scope: String
    var tags: String
    var importance: Int
    var timestamp: String
    var tier: String

    // F-I4: IPC memory.* 响应 → JSONDecoder。entry_id/id dual-key。守卫: id/content 缺一 → throw (匹配旧 guard nil)。
    enum CodingKeys: String, CodingKey { case id, content, scope, tags, importance, timestamp, tier, entry_id }
    init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: CodingKeys.self)
        let c = try decoder.container(keyedBy: FAnyKey.self)
        let resolvedId = (try? c.decodeIfPresent(String.self, forKey: .key("entry_id"))) ?? (try? top.decodeIfPresent(String.self, forKey: .id))
        let resolvedContent = try? top.decodeIfPresent(String.self, forKey: .content)
        guard let entryId = resolvedId, let contentVal = resolvedContent else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "memory entry missing entry_id/id or content"))
        }
        id = entryId
        content = contentVal
        scope = (try? top.decodeIfPresent(String.self, forKey: .scope)) ?? "default"
        tags = (try? top.decodeIfPresent(String.self, forKey: .tags)) ?? ""
        importance = (try? top.decodeIfPresent(Int.self, forKey: .importance)) ?? 5
        timestamp = (try? top.decodeIfPresent(String.self, forKey: .timestamp)) ?? ""
        tier = (try? top.decodeIfPresent(String.self, forKey: .tier)) ?? "short_term"
    }
    // memberwise init: AgentMemoryService parseMemoryEntry 构造 (将被 decodeCodable 替代, 保留兼容)。
    init(id: String, content: String, scope: String = "default", tags: String = "", importance: Int = 5, timestamp: String = "", tier: String = "short_term") {
        self.id = id
        self.content = content
        self.scope = scope
        self.tags = tags
        self.importance = importance
        self.timestamp = timestamp
        self.tier = tier
    }
    // F-I4: 显式 encode(to:) — CodingKeys 含 dual-key 备用 case (entry_id) 无对应存储属性, 合成 Encodable 失败, 故显式编码存储属性。
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(content, forKey: .content)
        try c.encode(scope, forKey: .scope)
        try c.encode(tags, forKey: .tags)
        try c.encode(importance, forKey: .importance)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(tier, forKey: .tier)
    }
}

struct SafetyCheckModel: Codable, Equatable {
    var level: String
    var violations: [String]
    var approved: Bool

    // F-I4: IPC safety.check 响应 → JSONDecoder 强类型解码。宽容: 缺键 ?? default (匹配旧 fromDict)。
    enum CodingKeys: String, CodingKey { case level, violations, approved }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = (try? c.decodeIfPresent(String.self, forKey: .level)) ?? ""
        violations = (try? c.decodeIfPresent([String].self, forKey: .violations)) ?? []
        approved = (try? c.decodeIfPresent(Bool.self, forKey: .approved)) ?? false
    }
    // memberwise init: safetyCheck 构造 (将被 decodeCodable 替代, 保留兼容)。
    init(level: String = "", violations: [String] = [], approved: Bool = false) {
        self.level = level
        self.violations = violations
        self.approved = approved
    }
}

struct SafetyActionModel: Codable, Equatable, Identifiable {
    var id: String
    var category: String
    var status: String
    var content: String
    var reason: String = ""

    // F-I4: IPC safety.get_pending_actions 响应 → JSONDecoder。action_id/id dual-key, ?? default 宽容。
    enum CodingKeys: String, CodingKey { case id, category, status, content, reason, action_id }
    init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: CodingKeys.self)
        let c = try decoder.container(keyedBy: FAnyKey.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .key("action_id"))) ?? (try? top.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        category = (try? top.decodeIfPresent(String.self, forKey: .category)) ?? ""
        status = (try? top.decodeIfPresent(String.self, forKey: .status)) ?? "pending"
        content = (try? top.decodeIfPresent(String.self, forKey: .content)) ?? ""
        reason = (try? top.decodeIfPresent(String.self, forKey: .reason)) ?? ""
    }
    // memberwise init: safetyEvaluateAction (site A) 从方法参数注 category/content (非 IPC dict), 不能走 decode。
    init(id: String = UUID().uuidString, category: String, status: String = "pending", content: String, reason: String = "") {
        self.id = id
        self.category = category
        self.status = status
        self.content = content
        self.reason = reason
    }
    // F-I4: 显式 encode(to:) — CodingKeys 含 dual-key 备用 case (action_id) 无对应存储属性, 合成 Encodable 失败, 故显式编码存储属性。
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(category, forKey: .category)
        try c.encode(status, forKey: .status)
        try c.encode(content, forKey: .content)
        try c.encode(reason, forKey: .reason)
    }
}

struct TemplateModel: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var category: String
    var description: String
    var variables: [String]

    // F-I4: IPC template.list/get 响应 → JSONDecoder。template_id/id dual-key, ?? default 宽容。
    enum CodingKeys: String, CodingKey { case id, name, category, description, variables, template_id }
    init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: CodingKeys.self)
        let c = try decoder.container(keyedBy: FAnyKey.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .key("template_id"))) ?? (try? top.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? top.decodeIfPresent(String.self, forKey: .name)) ?? ""
        category = (try? top.decodeIfPresent(String.self, forKey: .category)) ?? ""
        description = (try? top.decodeIfPresent(String.self, forKey: .description)) ?? ""
        variables = (try? top.decodeIfPresent([String].self, forKey: .variables)) ?? []
    }
    // memberwise init: fetchTemplates/templateGet 构造, templateGet 兜底 templateId param。
    init(id: String = UUID().uuidString, name: String = "", category: String = "", description: String = "", variables: [String] = []) {
        self.id = id
        self.name = name
        self.category = category
        self.description = description
        self.variables = variables
    }
    // F-I4: 显式 encode(to:) — CodingKeys 含 dual-key 备用 case (template_id) 无对应存储属性, 合成 Encodable 失败, 故显式编码存储属性。
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(category, forKey: .category)
        try c.encode(description, forKey: .description)
        try c.encode(variables, forKey: .variables)
    }
}

struct DeployFormatModel: Codable, Equatable, Identifiable {
    var id: String
    var format: String
    var description: String

    // F-I4: IPC deploy.list_formats 响应 → JSONDecoder。derived id=format (匹配旧 fromDict), ?? default 宽容。
    enum CodingKeys: String, CodingKey { case id, format, description }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = (try? c.decodeIfPresent(String.self, forKey: .format)) ?? ""
        description = (try? c.decodeIfPresent(String.self, forKey: .description)) ?? ""
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? format
    }
    init(id: String = UUID().uuidString, format: String, description: String = "") {
        self.id = id
        self.format = format
        self.description = description
    }
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

    // F-I4: custom init(from:) 保已知 API 变体宽容 (agent_id/id dual-key, manifest-nested fallback,
    // ?? 空 default), 走 JSONDecoder 类型化路径。类型不符 throw 可捕获 (非 ?? 静默)。
    // memberwise init 仅 parseAgentModel 内用, 抑制安全 (grep 0 外部 memberwise caller)。
    enum AgentModelKeys: String, CodingKey {
        case id, name, model, system_prompt, temperature, max_tokens, tools, capabilities
        case safety_level, tags, author, description, version, created_at, skills, has_soul
        case status, version_int, published_at, knowledge_base_ids, visibility, rag_strategy
        case web_search_enabled, deep_research_enabled, connector_ids, style, top_p
        case context_window, rate_limit_qps, manifest, agent_id
    }
    // F-I4: manifest??top??default 三级兜底。用 helper 拆表达式防 type-check timeout (单行 nested ?? + try? 撞类型推导上限)。
    // SE-0230: try? + optional-chaining 已 flatten, 单 if let 得 unwrapped 值。
    private static func mstr(_ manifest: KeyedDecodingContainer<AgentModelKeys>?, _ top: KeyedDecodingContainer<AgentModelKeys>, _ k: AgentModelKeys, _ dflt: String) -> String {
        if let v = try? manifest?.decodeIfPresent(String.self, forKey: k) { return v }
        if let v = try? top.decodeIfPresent(String.self, forKey: k) { return v }
        return dflt
    }
    private static func mdbl(_ manifest: KeyedDecodingContainer<AgentModelKeys>?, _ top: KeyedDecodingContainer<AgentModelKeys>, _ k: AgentModelKeys, _ dflt: Double) -> Double {
        if let v = try? manifest?.decodeIfPresent(Double.self, forKey: k) { return v }
        if let v = try? top.decodeIfPresent(Double.self, forKey: k) { return v }
        return dflt
    }
    private static func mint(_ manifest: KeyedDecodingContainer<AgentModelKeys>?, _ top: KeyedDecodingContainer<AgentModelKeys>, _ k: AgentModelKeys, _ dflt: Int) -> Int {
        if let v = try? manifest?.decodeIfPresent(Int.self, forKey: k) { return v }
        if let v = try? top.decodeIfPresent(Int.self, forKey: k) { return v }
        return dflt
    }
    private static func marr<T: Decodable>(_ manifest: KeyedDecodingContainer<AgentModelKeys>?, _ top: KeyedDecodingContainer<AgentModelKeys>, _ k: AgentModelKeys, _ dflt: [T]) -> [T] {
        if let v = try? manifest?.decodeIfPresent([T].self, forKey: k) { return v }
        if let v = try? top.decodeIfPresent([T].self, forKey: k) { return v }
        return dflt
    }
    private static func dualKey(_ c: KeyedDecodingContainer<FAnyKey>, _ top: KeyedDecodingContainer<AgentModelKeys>, _ alt: String, _ k: AgentModelKeys) -> String {
        if let v = try? c.decodeIfPresent(String.self, forKey: .key(alt)) { return v }
        if let v = try? top.decodeIfPresent(String.self, forKey: k) { return v }
        return ""
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: FAnyKey.self)
        let top = try decoder.container(keyedBy: AgentModelKeys.self)
        let manifest = try? top.nestedContainer(keyedBy: AgentModelKeys.self, forKey: .manifest)
        id = Self.dualKey(c, top, "agent_id", .id)
        name = Self.mstr(manifest, top, .name, "")
        model = Self.mstr(manifest, top, .model, "")
        system_prompt = Self.mstr(manifest, top, .system_prompt, "")
        temperature = Self.mdbl(manifest, top, .temperature, 0.7)
        max_tokens = Self.mint(manifest, top, .max_tokens, 4096)
        tools = Self.marr(manifest, top, .tools, [])
        capabilities = Self.marr(manifest, top, .capabilities, [])
        safety_level = Self.mstr(manifest, top, .safety_level, "L1")
        tags = Self.marr(manifest, top, .tags, [])
        author = Self.mstr(manifest, top, .author, "")
        description = Self.mstr(manifest, top, .description, "")
        version = Self.mstr(manifest, top, .version, "1.0.0")
        created_at = Self.mstr(manifest, top, .created_at, "")
        skills = (try? top.decodeIfPresent([String].self, forKey: .skills)) ?? []
        has_soul = (try? top.decodeIfPresent(Bool.self, forKey: .has_soul)) ?? false
        status = try? top.decodeIfPresent(String.self, forKey: .status)
        version_int = try? top.decodeIfPresent(Int.self, forKey: .version_int)
        published_at = try? top.decodeIfPresent(String.self, forKey: .published_at)
        knowledge_base_ids = try? top.decodeIfPresent([String].self, forKey: .knowledge_base_ids)
        visibility = try? top.decodeIfPresent(String.self, forKey: .visibility)
        rag_strategy = try? top.decodeIfPresent(String.self, forKey: .rag_strategy)
        web_search_enabled = try? top.decodeIfPresent(Bool.self, forKey: .web_search_enabled)
        deep_research_enabled = try? top.decodeIfPresent(Bool.self, forKey: .deep_research_enabled)
        connector_ids = try? top.decodeIfPresent([String].self, forKey: .connector_ids)
        style = try? top.decodeIfPresent(String.self, forKey: .style)
        top_p = try? top.decodeIfPresent(Double.self, forKey: .top_p)
        context_window = try? top.decodeIfPresent(Int.self, forKey: .context_window)
        rate_limit_qps = try? top.decodeIfPresent(Int.self, forKey: .rate_limit_qps)
    }

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

    // F-I4: IPC marketplace.* 响应 → JSONDecoder。entry_id/id dual-key。守卫: id/name 缺一 → throw (匹配旧 guard nil)。
    enum CodingKeys: String, CodingKey {
        case id, name, author, description, category, tags, version, rating, downloads, created_at, updated_at, entry_id
    }
    init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: CodingKeys.self)
        let c = try decoder.container(keyedBy: FAnyKey.self)
        let resolvedId = (try? c.decodeIfPresent(String.self, forKey: .key("entry_id"))) ?? (try? top.decodeIfPresent(String.self, forKey: .id))
        let resolvedName = try? top.decodeIfPresent(String.self, forKey: .name)
        guard let entryId = resolvedId, let nameVal = resolvedName else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "marketplace entry missing entry_id/id or name"))
        }
        id = entryId
        name = nameVal
        author = (try? top.decodeIfPresent(String.self, forKey: .author)) ?? ""
        description = (try? top.decodeIfPresent(String.self, forKey: .description)) ?? ""
        category = (try? top.decodeIfPresent(String.self, forKey: .category)) ?? ""
        tags = (try? top.decodeIfPresent([String].self, forKey: .tags)) ?? []
        version = (try? top.decodeIfPresent(String.self, forKey: .version)) ?? "1.0.0"
        rating = (try? top.decodeIfPresent(Double.self, forKey: .rating)) ?? 0.0
        downloads = (try? top.decodeIfPresent(Int.self, forKey: .downloads)) ?? 0
        created_at = (try? top.decodeIfPresent(String.self, forKey: .created_at)) ?? ""
        updated_at = (try? top.decodeIfPresent(String.self, forKey: .updated_at)) ?? ""
    }
    // memberwise init: AgentMarketplaceService parseMarketplaceEntry 构造 (将被 decodeCodable 替代, 保留兼容)。
    init(id: String, name: String, author: String = "", description: String = "", category: String = "", tags: [String] = [], version: String = "1.0.0", rating: Double = 0.0, downloads: Int = 0, created_at: String = "", updated_at: String = "") {
        self.id = id
        self.name = name
        self.author = author
        self.description = description
        self.category = category
        self.tags = tags
        self.version = version
        self.rating = rating
        self.downloads = downloads
        self.created_at = created_at
        self.updated_at = updated_at
    }
    // F-I4: 显式 encode(to:) — CodingKeys 含 dual-key 备用 case (entry_id) 无对应存储属性, 合成 Encodable 失败, 故显式编码存储属性。
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(author, forKey: .author)
        try c.encode(description, forKey: .description)
        try c.encode(category, forKey: .category)
        try c.encode(tags, forKey: .tags)
        try c.encode(version, forKey: .version)
        try c.encode(rating, forKey: .rating)
        try c.encode(downloads, forKey: .downloads)
        try c.encode(created_at, forKey: .created_at)
        try c.encode(updated_at, forKey: .updated_at)
    }
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

    // F-A1 Phase 7: isConnected/isExecuting/events 已迁 RuntimeState 域 (主类 checkHealth/executeGraph/
    //   cancelExecution/taskExecuteImmediate 写 self.runtimeState.X; setIPCClient sink 重定向 $runtimeState.isConnected)。
    //   AgentBridge 主类 @Published 块已全空 (48 全迁 7 域)。
    // F-A1 Phase 4: chatMessages/isInferring 已迁 ProjectChatState 域 (AgentProjectChatService facade 写, 0 SwiftUI 读 write-only)。
    // F-A1 Phase 6: self.agentState.dashboardData 已迁 AgentState 域 (AgentOpsService:235 跨域写, 迁入同域消除跨域写)。
    // F-A1 Phase 1: models/mlxRunning/mlxLoadedModels/mlxPort 已迁 MLXState 域 (AgentBridgeDomains.swift)。
    // ARCH-1 PR1 (#359): mlxStatusTimer/mlxStatusFetchedAt 已迁 MLXState 域 (AgentMlxService facade-delegate)。
    // F-A2子2: 30s TTL 客户端缓存, 防 onAppear fetch 风暴。写操作置 nil 强制下次重拉。
    // ARCH-1 PR3 (#359): configState 6 个 TTL (apikeys/cronJobs/styles/hooks/connectors/alerts) 已迁 ConfigState 域。
    // ARCH-1 PR6 (#359): tasks/projectsFetchedAt 已迁 TaskState 域 (AgentTaskService facade-delegate)。

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
    // 退避: 指数 1s→2s→4s 封顶 + ±12.5% jitter, 避免瞬时重打恢复中的引擎。
    // 审计0830 P1-错误-1: 旧实现开路后无 half-open → 永久开路需 app 重启复位 (与 IPCClient.swift:242 half-open 不一致)。
    //   加 half-open: 开路后冷却 window 到期转 half-open, 放一个探针请求, 成功才关路, 失败重新开路+续冷却。
    // 审计0830 P1-错误-2: 旧实现任一成功即复位 → 单次成功掩盖持续故障 → 抖动 (开→关→开)。
    //   复位需连续 N 次成功 (successThreshold), 中途任一失败归零。
    private let backendFailureThreshold = 5
    private let backendSuccessThreshold = 3
    private let backendCircuitCooldownSec = 30.0
    private var backendConsecutiveFailures: Int = 0
    private var backendConsecutiveSuccesses: Int = 0
    private var backendCircuitOpen: Bool = false
    private var backendCircuitHalfOpen: Bool = false
    private var backendCircuitOpenedAt: Date? = nil
    // 审计0902 R2 (P1): half-open 单探针 gate。旧实现在每个失败任务 catch 内独立判冷却→转 half-open,
    //   N 个并发失败任务 = N 个探针同时放出, 探针风暴击穿熔断意义。本标志保证同一 half-open 窗口只放 1 探针,
    //   其余 fast-fail。探针成功/失败复位时清。
    private var backendProbeInFlight: Bool = false

    // 审计0830 P0-4: 任务执行并发上限。无上限时 N 个任务同时 graph.execute → 单机 MLX 串行推理排队 →
    //   连接占满阻塞健康轮询 (P0-2) + 内存涨 + 重试雪崩。cap 4 限制并发执行体。
    nonisolated private let taskExecSemaphore = AsyncTaskSemaphore(limit: 4)

    // 指数退避 (s): 1 → 2 → 4 封顶, 按 retryCount 取, 加 ±12.5% jitter。
    private func retryBackoffSeconds(retryCount: Int) -> Double {
        let base = min(Double(1 << min(retryCount, 2)), 4.0)
        let jitter = Double.random(in: 0.875...1.125)
        return base * jitter
    }

    // MARK: - Module Published Properties

    // F-A1 Phase 5: plans/currentPlan/ragResults/memoryEntries/memoryCount/safetyCheckResult/
    //   safetyPendingActions/templates/deployFormats/tools/ragSources/lastSkillResult/
    //   lastResearchResult 13 @Published 已迁 ModuleState 域。

    // MARK: - Agent & Marketplace Published Properties

    // F-A1 Phase 6: self.agentState.agents/self.agentState.currentAgent/self.agentState.agentSkills/self.agentState.agentSoul/self.agentState.marketplaceEntries/
    //   self.agentState.marketplaceCategories/self.agentState.agentVersionHistory/self.agentState.auditTrail/self.agentState.sessionLogs/self.agentState.activeSessionId/
    //   self.agentState.streamingContent/self.agentState.isAgentStreaming/self.agentState.lastToolCalls 13 @Published + self.agentState.graphs + self.agentState.dashboardData
    //   (共 15) 已迁 AgentState 域 (最大域)。3 facade (Ops/Graph/Marketplace) 写 self.agentState.X,
    //   0 跨域写 (self.agentState.dashboardData 原跨域写迁入同域消除)。

    // Callers: TokenBudgetView, VectorSearchView, MemoryRelevantView, ToolBrowserView, SafetyView. Affected API: all new IPC bridge methods. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
    private let logger = Logger(subsystem: "com.fusion.studio", category: "AgentBridge")
    // F-A1 Phase 7: setIPCClient sink 订阅持有 (原 .assign(to:) 不需显式持, 改 .sink 需 store)。
    private var cancellables = Set<AnyCancellable>()
    // 审计0902 E3 (P2): setIPCClient 重连去重 — connectionSink 单 cancellable 取代旧 cancellables 无界追加;
    //   initialFetchTask 存逃逸 fetch Task, 重连前 cancel 旧 task 避孤儿累积, deinit 一并 cancel。
    private var connectionSink: AnyCancellable?
    private var initialFetchTask: Task<Void, Never>?

    // 审计0830 P0-1: SwiftUI 不自动追踪嵌套 ObservableObject。视图经 @EnvironmentObject bridge
    //   仅订阅 AgentBridge.objectWillChange, 域 @Published 变更触发域自身 objectWillChange 但无订阅者 →
    //   UI 静默失活。显式转发 7 域 objectWillChange → self.objectWillChange 修复观测断裂。
    init() {
        runtimeState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        mlxState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        agentState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        moduleState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        taskState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        configState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        projectChatState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        logger.info("AgentBridge init: 7 域 objectWillChange 转发已接线 (P0-1)")
    }

    var ipcClient: IPCClient?
    // #344: GuardBridge 延迟注入 (mirror setIPCClient), executeGraph 下发前调 guard.evaluate。
    private var guardBridge: GuardBridge?

    func setGuardBridge(_ g: GuardBridge) {
        self.guardBridge = g
        logger.info("AgentBridge GuardBridge wired")
    }

    func setIPCClient(_ client: IPCClient) {
        self.ipcClient = client
        // ARCH-1 PR1 (#359): MLX 域 facade-delegate — MLXState 持自己的 ipcClient ref (MLX RPC 方法读 self.ipcClient)。
        self.mlxState.ipcClient = client
        // ARCH-1 PR2 (#359): Runtime 域 facade-delegate — RuntimeState 持自己的 ipcClient ref (健康检查 RPC 读 self.ipcClient)。
        self.runtimeState.ipcClient = client
        // ARCH-1 PR3 (#359): Config 域 facade-delegate — ConfigState 持自己的 ipcClient ref (apikeys/cron/styles/hooks/connectors/analytics RPC 读 self.ipcClient)。
        self.configState.ipcClient = client
        // ARCH-1 PR4 (#359): Module 域 facade-delegate — ModuleState 持自己的 ipcClient ref (tools/skill/research/planner/rag/memory/safety/deploy/template RPC 读 self.ipcClient)。
        self.moduleState.ipcClient = client
        // ARCH-1 PR5 (#359): Agent 域 facade-delegate — AgentState 持自己的 ipcClient ref (agent/graph/marketplace lifecycle + skills/soul/chat/dashboard/audit RPC 读 self.ipcClient)。
        self.agentState.ipcClient = client
        // ARCH-1 PR6 (#359): Task 域 facade-delegate — TaskState 持自己的 ipcClient ref (fetchTasks/fetchProjects RPC 读 self.ipcClient)。
        self.taskState.ipcClient = client
        // F-A1 Phase 7: runtimeState 是 let 子对象, $runtimeState.isConnected 非法 ($投影仅限直接 @Published 属性)。
        // 改 .sink 手动写 runtimeState.isConnected, cancellable 持久化防订阅立即释放。
        // 审计0902 E3 (P2): setIPCClient 每次重连调用, 旧实现每次追加 1 sink 无去重 → N 重连 = N stale sink 无界追加。
        //   修复: 先取消并清空旧 connectionSink, 再存新 sink (去重, 常驻仅 1)。
        connectionSink?.cancel()
        connectionSink = client.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.runtimeState.setConnected(connected)
            }
        logger.info("AgentBridge connected to IPCClient")
        // 审计0830 P1-调度-1: cronJobId 仅内存态, app 崩溃后启动若不主动拉取 → 已注册 cron 任务在 UI 打开前丢失可见性
        //   (用户不知任务停跑/还在跑)。后端持久化 cron job, 启动即 reconcile: fetchTasks 恢复 scheduled 任务 + cronJobId。
        //   不依赖用户手动进 Task 模块触发 onAppear fetch。延迟 0.5s 等 daemon 路由就绪 (setIPCClient 早于 daemon 完全 ready)。
        // 审计0902 E3 (P2): 旧实现起逃逸 Task 未存 → N 重连 = N fetch Task 竞争 TTL guard + deinit 不取消。
        //   修复: 存入 initialFetchTask, 重连前取消旧 task 避孤儿累积。
        initialFetchTask?.cancel()
        initialFetchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            await self?.fetchTasks()
        }
    }

    // MARK: - Health Check
    // ARCH-1 PR2 (#359): checkHealth/fullHealthCheck 已迁 RuntimeState 域 (AgentRuntimeService facade-delegate)。
    //   留 1 行 stub 委托 runtimeState.X(); 健康检查 RPC 读 runtimeState.ipcClient (setIPCClient 注入)。

    // 复核 MLX 是否可达：直接走 HTTP /v1/models（app 复用外部 mlx gateway :11432）。
    // 用于启动竞态后重试 / Design 等模块进入时复核，避免 isMLXRunning 滞留 false (bug3/bug7/bug8)。
    func probeMLXRunningStatus() async -> Bool {
        let config = FusionConfig.shared
        DesignPreviewTrace.log("probeMLXRunningStatus: baseURL=\(config.mlxBaseURL) apiKeyLen=\(config.mlxResolvedApiKey.count) route=studio")
        do {
            _ = try await fetchModels()
            logger.info("probeMLXRunningStatus: mlx reachable (HTTP /v1/models)")
            DesignPreviewTrace.log("probeMLXRunningStatus: OK reachable")
            self.mlxState.setMlxRunning(true)
            return true
        } catch BridgeError.authFailed {
            // 401/403：当前解析的 api key 无效。常见根因：~/.zshrc 注入了错误的
            // FUSION_MLX_API_KEY（gateway 残留 key），env 优先级高于 settings.json。
            // 自愈：用 settings.json 的 auth.api_key 重试，成功则持久化到 user-settings，
            // 抬高其优先级覆盖错误 env，避免每次启动都 401。
            logger.warning("probeMLXRunningStatus: auth failed, attempting settings.json key self-heal")
            let healed = await selfHealApiKeyFromSettings()
            self.mlxState.setMlxRunning(healed)
            return healed
        } catch {
            logger.error("probeMLXRunningStatus: mlx unreachable: \(error)")
            DesignPreviewTrace.log("probeMLXRunningStatus: FAIL \(error)")
            self.mlxState.setMlxRunning(false)
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
    // ARCH-1 PR5 (#359 facade-delegate): fetchGraphs/createGraph/graphGet/updateGraph/deleteGraph/templateInstantiate/deployImport
    //   + parseGraphModel 抽至 AgentGraphService.swift (extension AgentState 真实体 + extension AgentBridge stub), 已迁域。
    // executeGraph 留此: 依赖 Self.parseEventModel (Event 域 private static 跨文件不可访问) + guard 鉴权 +
    //   写共享 runtimeState.events/isExecuting (跨域协调器)。cancelExecution 已迁 RuntimeState 域 (PR2)。

    // 审计0830 P0-11: 旧返回 Void, 调用方读共享 runtimeState.events → 并发任务串号 (任务 A 读任务 B 事件)。
    //   改返回 parsed events; taskExecuteImmediate 用返回值而非共享态 (并发安全), UI 手动执行仍写共享态供展示。
    func executeGraph(id: String, input: String, taskId: String = "") async throws -> [AgentEventModel] {
        guard let client = ipcClient else {
            throw BridgeError.notConnected
        }
        logger.info("executeGraph: id=\(id) task=\(taskId.isEmpty ? "-" : taskId)")

        // 审计0902 R1 (P1): 并发 guard。UI 手动执行 (taskId 空) 写共享 runtimeState.events/isExecuting,
        //   两路并发互覆 (A 清空 B 的事件)。taskExecuteImmediate 路用返回值不踩共享态 (P0-11 已修),
        //   但其底层仍走本方法, 故以 graphInflightLock 串行化所有 executeGraph, 同一时刻只允许一个在跑。
        //   不拒绝 (任务调度路径合法并发), 而是按到达顺序串行 → 后者等前者完成再执行, 共享态不被互覆。
        await graphInflightLock.acquire()
        // 审计0902 R1: release 非 defer (actor-isolated 需 await), 沿既有 taskExecSemaphore 模式
        //   在每个出口显式 await release。
        // #344: 高危动作运行时鉴权 — guard.evaluate before dispatch (PRD §17 Phase 6)。
        // 已装 guard (isDaemonReady=true): 严格 fail-closed, BLOCK/L4 不下发, L3 走人机确认弹窗。
        // 未装 guard (isDaemonReady=false): 可选上游, fail-open 普通工作流不锁死未装用户。
        if let guardBridge = guardBridge, guardBridge.isDaemonReady {
            do {
                let verdict = try await guardBridge.evaluate(
                    action: "graph.execute(\(id))",
                    content: input,
                    contentType: "text",
                    categoryHint: "agent_graph"
                )
                if verdict.isBlock {
                    logger.error("executeGraph BLOCKED by guard: \(verdict.reason, privacy: .public) risk=\(verdict.riskLevel, privacy: .public)")
                    await graphInflightLock.release()
                    throw BridgeError.guardBlocked(verdict.reason)
                }
                if verdict.needsApproval {
                    let approved = try await guardBridge.requestApproval(
                        actionId: verdict.actionId,
                        action: "graph.execute(\(id))",
                        content: input,
                        reason: verdict.reason,
                        riskLevel: verdict.riskLevel,
                        category: verdict.inferredCategory
                    )
                    if !approved {
                        logger.warning("executeGraph L3 approval denied by user")
                        await graphInflightLock.release()
                        throw BridgeError.guardBlocked("用户拒绝确认")
                    }
                }
                logger.info("executeGraph guard verdict: \(verdict.action, privacy: .public) risk=\(verdict.riskLevel, privacy: .public)")
            } catch let ge as GuardError {
                // fail-closed: guard confirm/超时不可达 = block (R2), 不绕过
                logger.error("executeGraph guard approval failed (fail-closed): \(ge.localizedDescription, privacy: .public)")
                await graphInflightLock.release()
                throw BridgeError.guardBlocked(ge.localizedDescription)
            }
        } else if guardBridge != nil {
            logger.warning("executeGraph guard daemon not ready — skip guard (optional upstream, fail-open for未装用户)")
        }

        self.runtimeState.setExecuting(true)
        self.runtimeState.setEvents([])

        do {
            var params: [String: Any] = [
                "graph_id": id,
                "input": input,
            ]
            if !taskId.isEmpty {
                params["task_id"] = taskId
            }
            // 审计0830 P1-调度-6: 单节点 hang (后端无节点级超时) → graphExecute RPC 永阻塞 →
            //   isExecuting 恒 true, UI 永久 "执行中", 后续手动执行被 isExecuting 守卫拒。
            //   客户端侧 300s 超时兜底 (合法长 workflow 留足余量, 真正 hang 在此截断): 到点 cancel, 复位 isExecuting。
            let result: [String: Any]
            do {
                // 审计0830 P1-调度-6: params 为 var, group.addTask 闭包 @Sendable 捕获 var →
                //   Swift 5.10 (CI) "reference to captured var in concurrently-executing code" 编译错。
                //   params 在此已构建完成 (下方 group 内不再写), 复制为 let 值再捕获即合法。
                let callParams = params
                result = try await withThrowingTaskGroup(of: [String: Any].self) { group in
                    group.addTask {
                        try await client.call(method: RPCMethod.graphExecute, params: callParams)
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 300_000_000_000)
                        throw BridgeError.timeout
                    }
                    guard let value = try await group.next() else {
                        throw BridgeError.timeout
                    }
                    group.cancelAll()
                    return value
                }
            } catch BridgeError.timeout {
                logger.error("executeGraph: timeout after 300s (graph_id=\(id, privacy: .public) — node hang suspected)")
                throw BridgeError.timeout
            }

            let eventsData = result["events"] as? [[String: Any]] ?? []
            var parsed: [AgentEventModel] = []
            for ev in eventsData {
                if let model = Self.parseEventModel(from: ev) {
                    parsed.append(model)
                }
            }
            self.runtimeState.setEvents(parsed)
            self.runtimeState.setExecuting(false)
            logger.info("executeGraph: received \(parsed.count) events")
            await graphInflightLock.release()
            return parsed
        } catch let error as IPCError {
            self.runtimeState.setExecuting(false)
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            logger.error("executeGraph: \(error)")
            await graphInflightLock.release()
            throw bridgeErr
        } catch {
            self.runtimeState.setExecuting(false)
            let bridgeErr = BridgeError.decodeError(error.localizedDescription)

            logger.error("executeGraph decode: \(error)")
            await graphInflightLock.release()
            throw bridgeErr
        }
    }

    // ARCH-1 PR2 (#359): cancelExecution 已迁 RuntimeState 域 (AgentRuntimeService facade-delegate), 留 1 行 stub。
    // ARCH-1 PR4 (#359): fetchTools/toolDynamicRegister/toolDynamicUnregister/getTool 已迁 ModuleState 域 (AgentModuleService facade-delegate), 留 1 行 stub。

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

    // 自愈候选 key 序列：gateway config.yaml > settings.json
    // ARCH-2 (审计product-0905 P1): 删除 fg-admin-key 硬编码兜底。无真实 key = 不自愈 (报错), 绝不用 baked-in secret。
    // 硬编码 secret 随 DMG 发布, MITM/反编译可提取, 且掩盖配置缺失。PERF-4: nonisolated async 文件读跑 cooperative 池。
    nonisolated static func mlxSelfHealKeyCandidates(currentResolved: String) async -> [String] {
        var cands: [String] = []
        if let g = await gatewayConfigApiKey(), !g.isEmpty, g != currentResolved { cands.append(g) }
        if let s = await mlxSettingsJsonApiKey(), !s.isEmpty, s != currentResolved { cands.append(s) }
        if cands.isEmpty {
            agentBridgeStaticLog.error("mlxSelfHealKeyCandidates: no real API key resolved (gateway/settings.json), refusing to fall back to hardcoded key")
        }
        return cands
    }

    // ARCH-1: RAG Operations (ragQuery/ragRetrieve/ragVectorSearch) 抽至 AgentRAGService.swift facade extension。
    // @Published ragResults/ragSources + ipcClient 留本类 (extension 不可声明存储), 0 行为零变。
    // ARCH-1 PR4 (#359): skillExecute/researchAdaptive 已迁 ModuleState 域 (AgentModuleService facade-delegate), 留 1 行 stub。

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

    // MARK: - API Key Operations
    // ARCH-1 PR3 (#359): apikeys fetch/create/revoke/rotate 已迁 ConfigState 域 (AgentConfigService facade-delegate), 留 1 行 stub。

    // MARK: - Style Operations
    // ARCH-1 PR3 (#359): fetchStyles/styleCreate/styleDelete 已迁 ConfigState 域 (AgentStyleService facade-delegate), 留 1 行 stub。

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
    // ARCH-1 PR6 (#359): fetchTasks/fetchProjects 已迁 TaskState 域 (AgentTaskService facade-delegate), 留 1 行 stub。
    //   执行集群留本主类 (跨域协调器): taskExecuteImmediate/taskSubmit/taskDelete/taskCancel/taskRerun/
    //   taskScheduleCron/taskScheduleRunAt + taskRunHandles/backendCircuit/lockedTaskHandle/retryBackoffSeconds/
    //   taskIndex/updateTask/reportTaskStatus/encodeCronInput/summarizeEvents。依赖 executeGraph/parseEventModel/cronRegister。

    func agentName(for id: String) -> String {
        self.agentState.agents.first(where: { $0.id == id })?.name ?? id.prefix(8).description
    }

    func graphName(for id: String) -> String {
        self.agentState.graphs.first(where: { $0.id == id })?.name ?? ""
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
            // 审计0830 P0-4: 并发信号量 acquire, 限制同时执行的任务数 (cap 4), 防单机 MLX 过载雪崩。
            //   各终端分支 (成功/取消/失败) 必须 release, 否则信号量永久占用锁死后续任务。
            await self.taskExecSemaphore.acquire()
            logger.info("taskExecuteImmediate acquired slot: id=\(taskId)")
            do {
                var eventsParsed: [AgentEventModel] = []
                var sessionId = ""
                if !graphId.isEmpty {
                    // 审计0830 P0-11: 用 executeGraph 返回值而非共享 runtimeState.events,
                    //   防并发任务串号 (任务 A 读任务 B 事件)。共享态仅 UI 手动执行展示用。
                    eventsParsed = try await executeGraph(id: graphId, input: inputText, taskId: taskId)
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
                _ = self.lockedTaskHandle { self.taskRunHandles.removeValue(forKey: taskId) }
                logger.info("taskExecuteImmediate done: id=\(taskId) events=\(eventsParsed.count)")
                // F-R12 / 审计0830 P1-错误-1/2: 成功处理熔断器复位。
                //   half-open 探针成功 → 关路复位 (连续成功归零, 无需攒 N)。
                //   open 态成功 (冷却已到半开, 探针通过) → 同上关路。
                //   否则 (closed 但仍有残余 failures) → 连续成功 +1, 达 successThreshold 才清零 failures (P1-错误-2 防 1 次成功掩盖持续故障)。
                if self.backendCircuitHalfOpen || self.backendCircuitOpen {
                    logger.info("F-R12 circuit probe succeeded, closing circuit halfOpen=\(self.backendCircuitHalfOpen)")
                    self.backendCircuitOpen = false
                    self.backendCircuitHalfOpen = false
                    self.backendConsecutiveFailures = 0
                    self.backendConsecutiveSuccesses = 0
                    self.backendCircuitOpenedAt = nil
                    // 审计0902 R2: 探针成功关路, 释放探针占位。
                    self.backendProbeInFlight = false
                } else if self.backendConsecutiveFailures > 0 {
                    self.backendConsecutiveSuccesses += 1
                    if self.backendConsecutiveSuccesses >= self.backendSuccessThreshold {
                        logger.info("F-R12 backend recovered after \(self.backendConsecutiveSuccesses) consecutive successes, clearing failures=\(self.backendConsecutiveFailures)")
                        self.backendConsecutiveFailures = 0
                        self.backendConsecutiveSuccesses = 0
                    }
                }
                self.reportTaskStatus(taskId, status: "completed", lastResult: ["summary": summary, "events": eventsParsed.count])
                await self.taskExecSemaphore.release()
            } catch is CancellationError {
                self.updateTask(taskId) { t in
                    if t.status != .completed { t.status = .cancelled }
                }
                // 审计0830 P0-5: cancelled 分支旧实现不 removeValue → 句柄钉在 taskRunHandles,
                //   Task 闭包持有 runtimeState/events 等大对象 → 高频取消下 dict 单调增长 → 内存泄漏。
                //   成功 (L1372)/失败 (L1427) 均清, 取消遗漏。补齐对齐。
                _ = self.lockedTaskHandle { self.taskRunHandles.removeValue(forKey: taskId) }
                logger.info("taskExecuteImmediate cancelled: id=\(taskId) handle released (P0-5)")
                // 审计0902 R2: 探针任务若被取消, 释放探针占位 + 回退到 open 续冷却, 防标志泄漏锁死后续探针。
                if self.backendProbeInFlight && self.backendCircuitHalfOpen {
                    self.backendCircuitHalfOpen = false
                    self.backendCircuitOpen = true
                    self.backendCircuitOpenedAt = Date()
                    self.backendProbeInFlight = false
                    logger.warning("F-R12 backend circuit probe CANCELLED -> re-OPEN, probe released (R2)")
                }
                await self.taskExecSemaphore.release()
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
                    await self.taskExecSemaphore.release()
                    return
                }
                let cur = self.taskState.tasks[idx]
                // 审计0830 P1-错误-2: 成功复位需连续 N 次, 任一失败归零连续成功计数。
                self.backendConsecutiveSuccesses = 0
                // F-R12: 计入后端连续失败, 达阈值开路熔断。
                self.backendConsecutiveFailures += 1
                if self.backendConsecutiveFailures >= self.backendFailureThreshold && !self.backendCircuitOpen {
                    self.backendCircuitOpen = true
                    self.backendCircuitHalfOpen = false
                    self.backendCircuitOpenedAt = Date()
                    logger.error("F-R12 backend circuit OPEN failures=\(self.backendConsecutiveFailures) cooldown=\(self.backendCircuitCooldownSec)s — fast-fail until half-open probe")
                }
                // 审计0830 P1-错误-1 / 0902 R2: 开路后冷却到期转 half-open 放单探针; 探针失败重新开路续冷却。
                //   R2 修正: 旧实现在每个失败 catch 内独立转 half-open, N 并发失败 = N 探针击穿熔断。
                //   仅当无探针在途 (backendProbeInFlight=false) 时首个任务转 half-open 并占探针; 其余 fast-fail。
                if self.backendCircuitOpen, let opened = self.backendCircuitOpenedAt,
                   Date().timeIntervalSince(opened) >= self.backendCircuitCooldownSec {
                    if !self.backendProbeInFlight {
                        self.backendCircuitOpen = false
                        self.backendCircuitHalfOpen = true
                        self.backendProbeInFlight = true
                        logger.info("F-R12 backend circuit -> HALF-OPEN (cooldown elapsed), releasing single probe (R2 gate acquired)")
                    } else {
                        // 探针已被并发首个任务占, 本任务 fast-fail 不放第二探针。
                        logger.warning("F-R12 backend circuit cooldown elapsed but probe in-flight, fast-fail id=\(taskId) (R2)")
                    }
                } else if self.backendCircuitHalfOpen {
                    // half-open 探针失败 → 重新开路, 重置冷却窗口, 释放探针占位。
                    self.backendCircuitHalfOpen = false
                    self.backendCircuitOpen = true
                    self.backendCircuitOpenedAt = Date()
                    self.backendProbeInFlight = false
                    logger.error("F-R12 backend circuit probe FAILED -> re-OPEN, cooldown restarted, probe released")
                }
                // ARCH-2: retry 上限收紧 + 退避, 防 maxRetries 过大时高频重试风暴。
                // retryCount 已 +1, 仅当未超 maxRetries 才重排。
                // F-R12: 熔断开路时跳过重试 fast-fail, 避免雪崩放大; half-open 放行探针; 退避改指数 + jitter。
                let shouldRetry = cur.retryCount <= cur.maxRetries && !self.backendCircuitOpen
                if shouldRetry {
                    let backoffNs = UInt64(retryBackoffSeconds(retryCount: cur.retryCount) * 1_000_000_000)
                    self.updateTask(taskId) { t in t.status = .queued }
                    logger.warning("taskExecuteImmediate retry: id=\(taskId) retryCount=\(cur.retryCount)/\(cur.maxRetries) backoffMs=\(backoffNs / 1_000_000) circuit=\(self.backendCircuitOpen ? "open" : (self.backendCircuitHalfOpen ? "half-open" : "closed"))")
                    // 审计0830 P0-4: retry 释放当前槽位, sleep 期间不占并发名额; 重排的 taskExecuteImmediate 会重新 acquire。
                    await self.taskExecSemaphore.release()
                    // 审计0902 R3 (P2): retry-reschedule 逃逸 Task 存入 taskRunHandles, 否则 taskDelete/
                    //   taskCancel/deinit 只取消父 handle 不取消此 sleep Task → 删/取消在退避期间孤儿 sleep 后续仍触发。
                    //   存入后 taskDelete/taskCancel 的 cancel 即覆盖退避 sleep; 重排的 taskExecuteImmediate 会重新 acquire + 覆盖此 handle。
                    let retryTask = Task {
                        try? await Task.sleep(nanoseconds: backoffNs)
                        if Task.isCancelled {
                            logger.info("taskExecuteImmediate retry cancelled: id=\(taskId)")
                            return
                        }
                        self.taskExecuteImmediate(taskId)
                    }
                    _ = self.lockedTaskHandle { self.taskRunHandles[taskId] = retryTask }
                } else {
                    let reason = (self.backendCircuitOpen || self.backendCircuitHalfOpen) ? "circuit-open" : "retries-exhausted"
                    self.updateTask(taskId) { t in t.status = .failed }
                    // F-R9: 持锁删, 防并发崩溃。
                    _ = self.lockedTaskHandle { self.taskRunHandles.removeValue(forKey: taskId) }
                    logger.error("taskExecuteImmediate failed: id=\(taskId) reason=\(reason) retryCount=\(cur.retryCount) error=\(error.localizedDescription)")
                    await self.taskExecSemaphore.release()
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
                // 审计0902 R3 (P2): taskDelete RPC 失败 → 本地 handle 已取消, 任务未从本地列表移除 (保可见性),
                //   但后端 cron 可能孤儿执行。标记 lastError 让用户知情 (非静默失败)。
                logger.error("taskDelete RPC failed: id=\(taskId) backend may retain orphan cron, error=\(error.localizedDescription)")
                self.updateTask(taskId) { t in
                    t.lastError = "后端删除失败, 可能残留定时执行: \(error.localizedDescription)"
                }
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
            logger.error("taskAddArtifacts failed: id=\(taskId) error=\(error.localizedDescription)")
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
            // 审计0902 R3 (P2): taskCancel RPC 失败 → 本地 handle 已取消 (前端停写状态), 但后端仍跑。
            //   无法回滚已 cancel 的本地 handle; 标记 lastError 让用户知情后端未真正取消 (非静默成功)。
            logger.error("taskCancel RPC failed: id=\(taskId) local handle cancelled but backend may still run, error=\(error.localizedDescription)")
            self.updateTask(taskId) { t in
                if t.status != .completed { t.status = .cancelled }
                t.lastError = "后端取消失败, 可能仍在执行: \(error.localizedDescription)"
            }
        }
    }

    func taskRerun(_ taskId: String) async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.taskRerun(taskId: taskId)
            if let d = result["task"] as? [String: Any], let updated = TaskModel(backendDict: d) {
                // 审计0827 §3.1 (P1): rerun 不重置 retryCount/lastError -> 已耗尽预算的任务 rerun
                // 进 taskExecuteImmediate catch -> retryCount 超 maxRetries -> 立即放弃无提示。
                // rerun 语义 = 全新执行, 须 reset retryCount=0 + lastError="" 再触发。
                var fresh = updated
                fresh.retryCount = 0
                fresh.lastError = ""
                if let idx = self.taskIndex(taskId) {
                    self.taskState.tasks[idx] = fresh
                }
                logger.info("taskRerun: id=\(taskId) retryCount reset to 0")
                // rerun 重置为 pending, 前端立即执行 immediate 触发.
                taskExecuteImmediate(taskId)
            }
        } catch {
            logger.error("taskRerun failed: id=\(taskId) error=\(error.localizedDescription)")
        }
    }

    // 报告状态到后端 task.status (前端执行的结果回写).
    private func reportTaskStatus(_ taskId: String, status: String, lastResult: [String: Any]? = nil, lastError: String = "") {
        guard let client = ipcClient else { return }
        Task {
            do {
                _ = try await client.taskStatus(taskId: taskId, status: status, lastResult: lastResult, lastError: lastError)
            } catch {
                logger.warning("reportTaskStatus failed: id=\(taskId) status=\(status) error=\(error.localizedDescription)")
            }
        }
    }

    func taskScheduleCron(_ taskId: String, expression: String, input: String) {
        guard let idx = taskIndex(taskId) else { return }
        let agentId = self.taskState.tasks[idx].agentId
        let graphId = self.taskState.tasks[idx].graphId
        let name = self.taskState.tasks[idx].title
        // 审计0830 P3-资源-1: encodeCronInput 失败返 nil → 不注册 cron, 标 failed, 避免空 input 静默定时执行。
        guard let inputData = encodeCronInput(taskId: taskId, agentId: agentId, input: input) else {
            updateTask(taskId) { t in
                t.status = .failed
                t.lastError = I18nManager.shared.t(.ab_err_generic)
            }
            logger.error("taskScheduleCron: encodeCronInput failed, abort registration id=\(taskId)")
            return
        }
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
                logger.error("taskScheduleCron failed: id=\(taskId) error=\(error.localizedDescription)")
            }
        }
    }

    func taskScheduleRunAt(_ taskId: String, runAt: Date, input: String) {
        guard let idx = taskIndex(taskId) else { return }
        let agentId = self.taskState.tasks[idx].agentId
        let graphId = self.taskState.tasks[idx].graphId
        let name = self.taskState.tasks[idx].title
        // 审计0830 P1-调度-2: Calendar.current = 本地 TZ, 后端按 UTC 解释 cron → 跨时区偏移。
        //   显式 UTC: runAt 视作绝对时刻, 按其 UTC 分量组 cron 表达式, 后端 UTC 解释即对齐。
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        let comp = utcCal.dateComponents([.minute, .hour, .day, .month], from: runAt)
        let expr = "\(comp.minute ?? 0) \(comp.hour ?? 0) \(comp.day ?? 1) \(comp.month ?? 1) *"
        // 审计0830 P3-资源-1: encodeCronInput 失败返 nil → 不注册 cron, 标 failed, 避免空 input 静默定时执行。
        guard let inputData = encodeCronInput(taskId: taskId, agentId: agentId, input: input) else {
            updateTask(taskId) { t in
                t.status = .failed
                t.lastError = I18nManager.shared.t(.ab_err_generic)
            }
            logger.error("taskScheduleRunAt: encodeCronInput failed, abort registration id=\(taskId)")
            return
        }
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
                logger.error("taskScheduleRunAt failed: id=\(taskId) error=\(error.localizedDescription)")
            }
        }
    }

    private func encodeCronInput(taskId: String, agentId: String, input: String) -> String? {
        let payload: [String: Any] = [
            "task_id": taskId,
            "agent_id": agentId,
            "input": input,
        ]
        // BUG-7: 旧 fallback 字符串插值在 input 含 "/\/换行时产出非法 JSON
        // (双引号未转义破坏结构, 送给 cron 解析端 JSONSerialization 必崩)。
        // 正常路径用 JSONSerialization (已转义); 失败说明 payload 不可序列化, 直接抛错不静默产出坏 JSON。
        // 审计0830 P3-资源-1: 旧实现序列化失败返 "{}" 静默 → cron 注册空 input 任务, 定时执行时无输入, 静默错误行为。
        //   改返 nil 让调用方判失败, 标 task failed + 不注册 cron, 不产 silent wrong run。
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else {
            logger.error("encodeCronInput: JSON 序列化失败 taskId=\(taskId) inputLen=\(input.count) — 不注册 cron (避免空 input 静默执行)")
            return nil
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
    // ARCH-1 PR3 (#359): cronJobs fetch/register/unregister 已迁 ConfigState 域 (AgentConfigService facade-delegate), 留 1 行 stub。
    //   @Published cronJobs 在 ConfigState 域 (外部读 TaskQueueView cron 区), 经 bridge.configState.cronJobs 不变。

    // MARK: - Hooks Operations
    // ARCH-1: fetchHooks/hooksRegister/hooksTest 抽至 AgentHooksService.swift facade extension。
    // 本域最薄叶 silo: 0 private 静态依赖, 0 持久状态, 0 跨域调用。@Published hooks 已迁 ConfigState 域 (有外部读)。

    // MARK: - Context Operations
    // ARCH-1: contextCompact/contextUsage 抽至 AgentContextService.swift facade extension。本域最简单: 2 薄透传, 0 @Published, 0 private 静态依赖。

    // MARK: - Parsing Helpers
    // ARCH-1: parseGraphModel 抽至 AgentGraphService.swift (private = 文件作用域, 与 6 调用方同文件)。

    // F-I4: [String:Any] (IPCClient 返值) → Data → JSONDecoder 强类型解码。
    // 保留 parseXModel(from:) signature, call site 零改。失败返 nil + log 报错 (审计: decode 报错可捕获, 不静默 nil)。
    // 跨文件调用方: AgentOpsService/AgentGraphService/AgentPlannerService/ArtifactsPanel 经 Self./AgentBridge. 访问。
    nonisolated static func decodeCodable<T: Decodable>(_ type: T.Type, from dict: [String: Any], context: String) -> T? {
        do {
            guard JSONSerialization.isValidJSONObject(dict) else {
                agentBridgeStaticLog.error("F-I4 decode \(context): invalid JSON object, keys=\(dict.keys.sorted())")
                return nil
            }
            let data = try JSONSerialization.data(withJSONObject: dict)
            let decoded = try JSONDecoder().decode(type, from: data)
            return decoded
        } catch {
            agentBridgeStaticLog.error("F-I4 decode \(context) failed: \(error.localizedDescription, privacy: .public) — schema drift or type mismatch, keys=\(dict.keys.sorted())")
            return nil
        }
    }

    // F-I4: 合成 Codable 足够 (type 必需, node_id/data/timestamp optional)。data:[String:JSONValue] 经 JSONValue custom Codable 解。
    // 解析路径从手动 dict["x"] as? Type 切到 JSONDecoder 强类型, 缺 type 解码抛错可捕获 (非 ?? 静默)。
    private static func parseEventModel(from dict: [String: Any]) -> AgentEventModel? {
        return decodeCodable(AgentEventModel.self, from: dict, context: "event")
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
        // 审计0902 E3 (P2): deinit 取消逃逸 initialFetchTask + connectionSink, 防释放后后台 Task/sink 持 self。
        initialFetchTask?.cancel()
        connectionSink?.cancel()
    }
}
