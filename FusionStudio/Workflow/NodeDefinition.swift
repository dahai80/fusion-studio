import Foundation
import os.log

// #422 P1-2: 统一节点定义协议 + 注册表 (plan §6.3)。一个分类法取代三个旧系统各自的节点集。
//   Phase-1 core 8 型: start/end/llm/tool/condition/loop/knowledge_retrieval/code。
//   run() 语义: 纯逻辑型 (start/end/condition) 本地真执行; 后端型 (llm/tool/...) 由 WorkflowExecutor
//   驱动 graph.execute — run() 抛 backendRequired, 不是假执行 (fail visibly, Rule 12)。

enum NodeCategory: String, Codable, CaseIterable, Sendable {
    case flow, model, action, control, data, logic, io
}

// config 表单字段类型 (#425 InspectorPanel 渲染依据)
enum ConfigFieldType: String, Codable, Sendable {
    case string, int, bool, dropdown, secret, multiline, modelHandle
}

struct ConfigField: Codable, Equatable, Identifiable, Sendable {
    var key: String
    var label: String
    var type: ConfigFieldType
    var defaultValue: JSONValue?
    var options: [String]?
    var required: Bool
    var advanced: Bool
    // 动态字段: showIfKey 字段值等于 showIfValue 时才显示 (plan §7.2)
    var showIfKey: String?
    var showIfValue: String?

    var id: String { key }

    init(key: String, label: String, type: ConfigFieldType, defaultValue: JSONValue? = nil,
         options: [String]? = nil, required: Bool = false, advanced: Bool = false,
         showIfKey: String? = nil, showIfValue: String? = nil) {
        self.key = key
        self.label = label
        self.type = type
        self.defaultValue = defaultValue
        self.options = options
        self.required = required
        self.advanced = advanced
        self.showIfKey = showIfKey
        self.showIfValue = showIfValue
    }
}

// 节点执行上下文: 输入端口值 + 共享 FlowState + 进程依赖注入
struct NodeContext: Sendable {
    var nodeId: UUID
    var config: [String: JSONValue]
    var inputs: [String: JSONValue]
    var flowState: FlowState
}

// §6.5: FlowState — start 节点声明 schema, executor 逐节点穿线 (Flowise $flow.state 对应物)
final class FlowState: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: JSONValue]

    init(initial: [String: JSONValue] = [:]) {
        self.values = initial
    }

    func value(for key: String) -> JSONValue? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }

    func write(_ value: JSONValue, for key: String) {
        lock.lock(); defer { lock.unlock() }
        values[key] = value
    }

    var snapshot: [String: JSONValue] {
        lock.lock(); defer { lock.unlock() }
        return values
    }
}

struct NodeResult: Sendable {
    var output: JSONValue?
    var stateWrites: [String: JSONValue]

    init(output: JSONValue? = nil, stateWrites: [String: JSONValue] = [:]) {
        self.output = output
        self.stateWrites = stateWrites
    }
}

// MARK: - NodeDefinition protocol (§6.3)

protocol NodeDefinition: Sendable {
    static var key: NodeTypeKey { get }
    static var displayName: String { get }
    static var icon: String { get }
    static var category: NodeCategory { get }
    static var inputs: [Port] { get }
    static var outputs: [Port] { get }
    static var configSchema: [ConfigField] { get }
    static func run(_ ctx: NodeContext) async throws -> NodeResult
}

extension NodeDefinition {
    static func run(_ ctx: NodeContext) async throws -> NodeResult {
        throw WorkflowError.nodeNotSupported(key.rawValue, "local")
    }
}

// MARK: - NodeRegistry

final class NodeRegistry: @unchecked Sendable {
    static let shared = NodeRegistry()

    private let lock = NSLock()
    // 存 metatype (definitions 为 caseless-enum 静态命名空间, 无实例)
    private var definitions: [NodeTypeKey: any NodeDefinition.Type] = [:]

    func register<D: NodeDefinition>(_ def: D.Type) {
        lock.lock(); defer { lock.unlock() }
        definitions[def.key] = def
    }

    func definition(for key: NodeTypeKey) -> (any NodeDefinition.Type)? {
        lock.lock(); defer { lock.unlock() }
        return definitions[key]
    }

    var registeredKeys: [NodeTypeKey] {
        lock.lock(); defer { lock.unlock() }
        return definitions.keys.sorted { $0.rawValue < $1.rawValue }
    }

    // palette 按 category 分组 (#423 PaletteSidebar / #427 全量分组)
    func categories() -> [NodeCategory: [NodeTypeKey]] {
        lock.lock(); defer { lock.unlock() }
        var grouped: [NodeCategory: [NodeTypeKey]] = [:]
        for (key, def) in definitions {
            grouped[def.category, default: []].append(key)
        }
        for (cat, keys) in grouped {
            grouped[cat] = keys.sorted { $0.rawValue < $1.rawValue }
        }
        return grouped
    }

    // 注册表初始化: Phase-1 core 8 型 (#422)。P2 #427 的 9 型在扩展点追加。
    func bootstrapCoreSet() {
        register(StartNodeDefinition.self)
        register(EndNodeDefinition.self)
        register(LLMNodeDefinition.self)
        register(ToolNodeDefinition.self)
        register(ConditionNodeDefinition.self)
        register(LoopNodeDefinition.self)
        register(KnowledgeRetrievalNodeDefinition.self)
        register(CodeNodeDefinition.self)
    }
}

// MARK: - Phase-1 core node set

struct StartNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.start
    static let displayName = "Start"
    static let icon = "play.circle.fill"
    static let category = NodeCategory.flow
    static let inputs: [Port] = []
    static let outputs = [Port(key: "out", label: "Flow", dataType: .message, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "state_keys", label: "Flow state keys (comma separated)", type: .multiline)
    ]

    static func run(_ ctx: NodeContext) async throws -> NodeResult {
        // start 节点初始化 FlowState: config state_keys 中已存在的键回显输出
        let keys = (ctx.config["state_keys"]?.stringValue ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var out: [String: JSONValue] = [:]
        for k in keys where ctx.flowState.value(for: k) != nil {
            out[k] = ctx.flowState.value(for: k)
        }
        return NodeResult(output: .object(out))
    }
}

struct EndNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.end
    static let displayName = "End"
    static let icon = "stop.circle.fill"
    static let category = NodeCategory.flow
    static let inputs = [Port(key: "in", label: "Result", dataType: .message, direction: .input)]
    static let outputs: [Port] = []
    static let configSchema: [ConfigField] = [
        ConfigField(key: "output_key", label: "Flow state key to expose", type: .string)
    ]

    static func run(_ ctx: NodeContext) async throws -> NodeResult {
        let key = ctx.config["output_key"]?.stringValue
        let output = key.flatMap { ctx.flowState.value(for: $0) } ?? ctx.inputs["in"]
        return NodeResult(output: output)
    }
}

struct LLMNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.llm
    static let displayName = "LLM"
    static let icon = "brain"
    static let category = NodeCategory.model
    static let inputs = [Port(key: "in", label: "Prompt", dataType: .message, direction: .input)]
    static let outputs = [Port(key: "out", label: "Completion", dataType: .message, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "model", label: "Model handle", type: .modelHandle, required: true),
        ConfigField(key: "system_prompt", label: "System prompt", type: .multiline),
        ConfigField(key: "temperature", label: "Temperature", type: .string, defaultValue: .string("0.7"), advanced: true),
        ConfigField(key: "max_tokens", label: "Max tokens", type: .int, defaultValue: .double(4096), advanced: true),
    ]
    // 执行走 agent-studio graph.execute (#424) — 本地无推理职责
}

struct ToolNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.tool
    static let displayName = "Tool"
    static let icon = "wrench.and.screwdriver"
    static let category = NodeCategory.action
    static let inputs = [Port(key: "in", label: "Input", dataType: .any, direction: .input)]
    static let outputs = [Port(key: "out", label: "Output", dataType: .any, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "tool_name", label: "Tool", type: .dropdown, options: ["web_search", "code_interpreter", "shell", "file_read", "file_write"], required: true),
        ConfigField(key: "params", label: "Params (JSON)", type: .multiline),
    ]
}

struct ConditionNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.condition
    static let displayName = "Condition"
    static let icon = "arrow.triangle.branch"
    static let category = NodeCategory.control
    static let inputs = [Port(key: "in", label: "Value", dataType: .data, direction: .input)]
    static let outputs = [
        Port(key: "true", label: "True", dataType: .data, direction: .output, allowsLoop: false),
        Port(key: "false", label: "False", dataType: .data, direction: .output, allowsLoop: false),
    ]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "expression", label: "Expression (jsonpath op value)", type: .string, required: true)
    ]

    // 纯逻辑本地执行: state_key exists / equals / not_equals / contains
    static func run(_ ctx: NodeContext) async throws -> NodeResult {
        let expr = ctx.config["expression"]?.stringValue ?? ""
        let parts = expr.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else {
            throw WorkflowError.incompatiblePorts("condition expression format: '<key> <op> [value]'")
        }
        let (keyPath, op) = (parts[0], parts[1])
        let expected = parts.count > 2 ? parts[2] : ""
        let actual: String
        if let v = ctx.inputs["in"] {
            switch v {
            case .string(let s): actual = s
            case .double(let d): actual = String(d)
            case .bool(let b): actual = String(b)
            default: actual = ""
            }
        } else if let v = ctx.flowState.value(for: keyPath) {
            switch v {
            case .string(let s): actual = s
            case .double(let d): actual = String(d)
            case .bool(let b): actual = String(b)
            default: actual = ""
            }
        } else {
            actual = ""
        }
        let branch: String
        switch op {
        case "exists": branch = actual.isEmpty ? "false" : "true"
        case "equals": branch = actual == expected ? "true" : "false"
        case "not_equals": branch = actual != expected ? "true" : "false"
        case "contains": branch = actual.contains(expected) ? "true" : "false"
        default:
            throw WorkflowError.incompatiblePorts("unknown condition op: \(op) (supports exists/equals/not_equals/contains)")
        }
        return NodeResult(output: .string(branch))
    }
}

struct LoopNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.loop
    static let displayName = "Loop"
    static let icon = "arrow.clockwise"
    static let category = NodeCategory.control
    static let inputs = [
        Port(key: "in", label: "Body", dataType: .data, direction: .input, allowsLoop: true)
    ]
    static let outputs = [
        Port(key: "item", label: "Item", dataType: .data, direction: .output, allowsLoop: true),
        Port(key: "done", label: "Done", dataType: .data, direction: .output),
    ]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "max_iterations", label: "Max iterations", type: .int, defaultValue: .double(100), required: true),
        ConfigField(key: "state_key", label: "Loop counter state key", type: .string, defaultValue: .string("loop_i")),
    ]
}

struct KnowledgeRetrievalNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.knowledgeRetrieval
    static let displayName = "Knowledge Retrieval"
    static let icon = "magnifyingglass"
    static let category = NodeCategory.data
    static let inputs = [Port(key: "query", label: "Query", dataType: .message, direction: .input)]
    static let outputs = [Port(key: "docs", label: "Documents", dataType: .data, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "kb_endpoint", label: "fusion-rag endpoint", type: .string, defaultValue: .string("http://127.0.0.1:11436")),
        ConfigField(key: "top_k", label: "Top K", type: .int, defaultValue: .double(5)),
    ]
}

struct CodeNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.code
    static let displayName = "Code"
    static let icon = "chevron.left.forwardslash.chevron.right"
    static let category = NodeCategory.logic
    static let inputs = [Port(key: "in", label: "Input", dataType: .any, direction: .input)]
    static let outputs = [Port(key: "out", label: "Output", dataType: .any, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "language", label: "Language", type: .dropdown, options: ["python", "javascript", "shell"], required: true),
        ConfigField(key: "source", label: "Source", type: .multiline, required: true),
    ]
}

// MARK: - 旧分类法映射表 (#422 验收: FSB 7 型 → 统一集 config preset, 不删类型)

enum LegacyTaxonomyMapping {
    // FSB uppercase types (plan §6.3: SKILL_NODE→tool, CONDITION_NODE→condition, APPROVAL_GATE_NODE→human_input 等)
    static let fsbToUnified: [String: NodeTypeKey] = [
        "START_NODE": .start,
        "END_NODE": .end,
        "SKILL_NODE": .tool,
        "CONDITION_NODE": .condition,
        "APPROVAL_GATE_NODE": .humanInput,
        "KNOWLEDGE_NODE": .knowledgeRetrieval,
        "LLM_NODE": .llm,
    ]

    // AgentStudio form-only types
    static let agentStudioToUnified: [String: NodeTypeKey] = [
        "start": .start,
        "llm": .llm,
        "tool": .tool,
        "condition": .condition,
        "loop": .loop,
        "end": .end,
        "error_handler": .condition,
        "retriever": .knowledgeRetrieval,
        "router": .condition,
        "memory": .tool,
        "human_in_loop": .humanInput,
    ]

    static func unifiedKey(for legacy: String, taxonomy: String) -> NodeTypeKey? {
        switch taxonomy {
        case "fsb": return fsbToUnified[legacy]
        case "agent-studio": return agentStudioToUnified[legacy]
        default: return nil
        }
    }
}
