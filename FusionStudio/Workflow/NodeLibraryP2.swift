import Foundation
import os.log

// #427 P2-1: 全量节点库 — 17 unified 型补齐余下 9 (plan §6.3 表)。
//   后端执行型 (agent/mcp_tool/question_classifier/http_request/human_input/sub_flow/
//   iteration) 走 schema 声明 + backend/interpreter 执行; 纯本地型 (variable_aggregator/
//   template) 自带 run。

// MARK: - Agent / Tool 类 (后端执行)

struct AgentNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.agent
    static let displayName = "Agent"
    static let icon = "cpu"
    static let category = NodeCategory.model
    static let inputs = [Port(key: "in", label: "Task", dataType: .message, direction: .input)]
    static let outputs = [Port(key: "out", label: "Result", dataType: .message, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "label", label: "Label", type: .string, required: false),
        ConfigField(key: "agent_id", label: "Agent ID", type: .string, required: true),
        ConfigField(key: "task", label: "Task prompt", type: .multiline, required: true),
        ConfigField(key: "tools", label: "Tools (comma-separated)", type: .string, required: false, advanced: true),
        ConfigField(key: "max_steps", label: "Max steps", type: .int, defaultValue: .string("10"), required: false, advanced: true),
    ]
}

struct McpToolNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.mcpTool
    static let displayName = "MCP Tool"
    static let icon = "wrench.and.screwdriver"
    static let category = NodeCategory.action
    static let inputs = [Port(key: "in", label: "Input", dataType: .json, direction: .input)]
    static let outputs = [Port(key: "out", label: "Output", dataType: .json, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "server", label: "MCP server", type: .string, required: true),
        ConfigField(key: "tool_name", label: "Tool name", type: .string, required: true),
        ConfigField(key: "arguments", label: "Arguments (JSON)", type: .multiline, required: false),
    ]
}

struct QuestionClassifierNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.questionClassifier
    static let displayName = "Question Classifier"
    static let icon = "questionmark.bubble"
    static let category = NodeCategory.logic
    static let inputs = [Port(key: "in", label: "Question", dataType: .message, direction: .input)]
    static let outputs = [
        Port(key: "class_1", label: "Class 1", dataType: .message, direction: .output),
        Port(key: "class_2", label: "Class 2", dataType: .message, direction: .output),
        Port(key: "class_3", label: "Class 3", dataType: .message, direction: .output),
    ]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "model", label: "Model", type: .modelHandle, required: true),
        ConfigField(key: "classes", label: "Classes (comma-separated)", type: .string, required: true),
        ConfigField(key: "instruction", label: "Classification instruction", type: .multiline, required: false, advanced: true),
    ]
}

struct HttpRequestNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.httpRequest
    static let displayName = "HTTP Request"
    static let icon = "network"
    static let category = NodeCategory.action
    static let inputs = [Port(key: "in", label: "Body", dataType: .json, direction: .input)]
    static let outputs = [Port(key: "out", label: "Response", dataType: .json, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "method", label: "Method", type: .dropdown, options: ["GET", "POST", "PUT", "DELETE"], required: true),
        ConfigField(key: "url", label: "URL", type: .string, required: true),
        ConfigField(key: "headers", label: "Headers (JSON)", type: .multiline, required: false, advanced: true),
        ConfigField(key: "timeout_s", label: "Timeout (s)", type: .int, defaultValue: .string("30"), required: false, advanced: true),
    ]
}

// MARK: - 控制类 (interpreter 执行)

struct IterationNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.iteration
    static let displayName = "Iteration"
    static let icon = "arrow.triangle.2.circlepath"
    static let category = NodeCategory.control
    static let inputs = [
        Port(key: "in", label: "Items", dataType: .array, direction: .input),
    ]
    static let outputs = [
        Port(key: "out", label: "Collected", dataType: .array, direction: .output, allowsLoop: true),
        Port(key: "item", label: "Item", dataType: .any, direction: .output, allowsLoop: true),
    ]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "item_key", label: "Item state key", type: .string, required: true),
        ConfigField(key: "max_iterations", label: "Max iterations", type: .int, defaultValue: .string("100"), required: false),
    ]
}

struct VariableAggregatorNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.variableAggregator
    static let displayName = "Variable Aggregator"
    static let icon = "square.stack.3d.up"
    static let category = NodeCategory.data
    static let inputs = [
        Port(key: "in", label: "Value", dataType: .any, direction: .input, allowsLoop: true),
    ]
    static let outputs = [Port(key: "out", label: "Aggregated", dataType: .any, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "state_keys", label: "State keys (comma-separated, first non-empty wins)", type: .string, required: true),
        ConfigField(key: "output_key", label: "Output state key", type: .string, required: false),
    ]

    // 纯本地: 首个非空 state 值透传 (Flowise variable-aggregator 语义)
    static func run(_ ctx: NodeContext) async throws -> NodeResult {
        let keys = (ctx.config["state_keys"]?.stringValue ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for k in keys {
            if let v = ctx.flowState.value(for: k), !isEmptyValue(v) {
                var writes: [String: JSONValue] = [:]
                if let out = ctx.config["output_key"]?.stringValue, !out.isEmpty {
                    writes[out] = v
                }
                return NodeResult(output: v, stateWrites: writes)
            }
        }
        if let input = ctx.inputs["in"], !isEmptyValue(input) {
            return NodeResult(output: input)
        }
        return NodeResult(output: .string(""))
    }

    private static func isEmptyValue(_ v: JSONValue) -> Bool {
        switch v {
        case .string(let s): return s.isEmpty
        case .object(let o): return o.isEmpty
        case .array(let a): return a.isEmpty
        case .double(let d): return d.isNaN
        case .bool: return false
        }
    }
}

struct TemplateNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.template
    static let displayName = "Template"
    static let icon = "doc.richtext"
    static let category = NodeCategory.data
    static let inputs = [Port(key: "in", label: "Values", dataType: .any, direction: .input)]
    static let outputs = [Port(key: "out", label: "Rendered", dataType: .message, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "template", label: "Template ({{key}} placeholders)", type: .multiline, required: true),
        ConfigField(key: "output_key", label: "Output state key", type: .string, required: false),
    ]

    // 纯本地: "{{key}}" 占位符以 FlowState/inputs 值替换
    static func run(_ ctx: NodeContext) async throws -> NodeResult {
        let template = ctx.config["template"]?.stringValue ?? ""
        var out = template
        let range = NSRange(out.startIndex..., in: out)
        let pattern = try? NSRegularExpression(pattern: "\\{\\{\\s*([A-Za-z0-9_.]+)\\s*\\}\\}")
        for match in (pattern?.matches(in: out, range: range) ?? []).reversed() {
            guard let r = Range(match.range(at: 1), in: out) else { continue }
            let key = String(out[r])
            var value = ""
            if let v = ctx.inputs["in"] {
                if case .object(let obj) = v, let kv = obj[key] { value = JSONValue.serializeScalar(kv) }
            }
            if value.isEmpty, let sv = ctx.flowState.value(for: key) {
                value = JSONValue.serializeScalar(sv)
            }
            if let full = Range(match.range(at: 0), in: out) {
                out.replaceSubrange(full, with: value)
            }
        }
        var writes: [String: JSONValue] = [:]
        if let outKey = ctx.config["output_key"]?.stringValue, !outKey.isEmpty {
            writes[outKey] = .string(out)
        }
        return NodeResult(output: .string(out), stateWrites: writes)
    }
}

// MARK: - IO 类 (interpreter checkpoint)

struct HumanInputNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.humanInput
    static let displayName = "Human Input"
    static let icon = "person.wave.2"
    static let category = NodeCategory.io
    static let inputs = [Port(key: "in", label: "Context", dataType: .message, direction: .input)]
    static let outputs = [Port(key: "out", label: "Answer", dataType: .message, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "question", label: "Question to human", type: .multiline, required: true),
        ConfigField(key: "answer_key", label: "Answer state key", type: .string, required: true),
        ConfigField(key: "timeout_s", label: "Timeout (s, 0 = never)", type: .int, defaultValue: .string("0"), required: false, advanced: true),
    ]
}

struct SubFlowNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.subFlow
    static let displayName = "Sub Flow"
    static let icon = "flowchart"
    static let category = NodeCategory.flow
    static let inputs = [Port(key: "in", label: "Input", dataType: .any, direction: .input)]
    static let outputs = [Port(key: "out", label: "Output", dataType: .any, direction: .output)]
    static let configSchema: [ConfigField] = [
        ConfigField(key: "flow_name", label: "Flow name (local library)", type: .string, required: true),
        ConfigField(key: "input_key", label: "Input state key", type: .string, required: false, advanced: true),
        ConfigField(key: "output_key", label: "Output state key", type: .string, required: false, advanced: true),
    ]
}

// JSONValue 标量序列化 (template/aggregator 渲染用)
extension JSONValue {
    static func serializeScalar(_ v: JSONValue) -> String {
        switch v {
        case .string(let s): return s
        case .double(let d): return d.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(d)) : String(d)
        case .bool(let b): return String(b)
        case .object(let o): return "{" + o.keys.sorted().map { "\($0)" }.joined(separator: ",") + "}"
        case .array(let a): return "[" + "\(a.count) items]"
        }
    }
}


// note: 画布注释节点 (无执行语义, 注册进 registry 供 palette/校验)
struct NoteNodeDefinition: NodeDefinition {
    static let key = NodeTypeKey.note
    static let displayName = "Note"
    static let icon = "note.text"
    static let category = NodeCategory.flow
    static let inputs: [Port] = []
    static let outputs: [Port] = []
    static let configSchema: [ConfigField] = [
        ConfigField(key: "text", label: "Note text", type: .multiline, required: false)
    ]

    static func run(_ ctx: NodeContext) async throws -> NodeResult {
        NodeResult(output: ctx.config["text"] ?? .string(""))
    }
}
