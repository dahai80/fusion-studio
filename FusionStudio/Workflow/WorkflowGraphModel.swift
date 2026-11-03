import Foundation
import os.log

// #421 P1-1: 统一工作流图模型 (plan fusion-studio-workflow-enhance-0903 §6.2)。
//   取代三个互不统一的子系统数据形状 (AgentGraphModel 无类型端口 / FSB [String:Any] config / 已删 DAGCanvas)。
//   全部 Codable 本地落盘 (#426) + GraphCodec seam 映射后端契约 (AgentGraphModel)。

private let workflowModelLog = Logger(subsystem: "com.fusion.studio", category: "WorkflowModel")

// MARK: - Port

enum PortDataType: String, Codable, CaseIterable, Sendable {
    case message, data, tool, json, array, any
}

enum PortDirection: String, Codable, CaseIterable, Sendable {
    case input, output
}

// §6.2: typed port handle (langflow sourceHandle/targetHandle 对应物)。
struct Port: Codable, Equatable, Identifiable, Sendable {
    var key: String
    var label: String
    var dataType: PortDataType
    var direction: PortDirection
    var allowsLoop: Bool

    var id: String { "\(direction.rawValue):\(key)" }

    init(key: String, label: String, dataType: PortDataType, direction: PortDirection, allowsLoop: Bool = false) {
        self.key = key
        self.label = label
        self.dataType = dataType
        self.direction = direction
        self.allowsLoop = allowsLoop
    }
}

// MARK: - Port compatibility (§6.2 typed-port validation, langflow types_compatible 对应物)

enum PortCompatibility {
    enum Verdict: Equatable, Sendable {
        case ok
        // .any 是逃生舱, 允许但带警告 (plan §6.2 "escape hatch but discouraged")
        case okWithWarning(String)
        case rejected(String)
    }

    // 迁移表: 旧数据形状端口类型映射 (.data→.json 等, plan §6.2)
    private static let migrations: [PortDataType: Set<PortDataType>] = [
        .data: [.json],
        .message: [.json],
        .tool: [.any],
    ]

    static func check(output: PortDataType, input: PortDataType) -> Verdict {
        if output == input { return .ok }
        if output == .any || input == .any {
            return .okWithWarning("untyped .any port connection (discouraged)")
        }
        if migrations[output]?.contains(input) == true {
            return .okWithWarning("migration mapping \(output.rawValue)->\(input.rawValue) applied")
        }
        return .rejected("incompatible port types: \(output.rawValue) -> \(input.rawValue)")
    }

    static func validateEdge(source: Port, target: Port) -> Verdict {
        guard source.direction == .output else {
            return .rejected("source port is not an output (\(source.key))")
        }
        guard target.direction == .input else {
            return .rejected("target port is not an input (\(target.key))")
        }
        return check(output: source.dataType, input: target.dataType)
    }
}

// MARK: - Graph model

// §6.2: 视口状态随图落盘 (pan/zoom 恢复)
struct GraphViewport: Codable, Equatable, Sendable {
    var offsetX: Double
    var offsetY: Double
    var scale: Double

    init(offsetX: Double = 0, offsetY: Double = 0, scale: Double = 1.0) {
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
    }
}

// CGPoint 非 Codable — 自持 x/y 包装 (plan §6.2 WorkflowNode.position/size)
struct GraphPoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ p: CGPoint) {
        self.x = Double(p.x)
        self.y = Double(p.y)
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

// 统一节点类型 key (§6.3 表, 17 型全量枚举; P1 core 8 型注册, P2 #427 补齐余下)
enum NodeTypeKey: String, Codable, CaseIterable, Sendable {
    case start, end, llm, tool, condition, loop, knowledgeRetrieval = "knowledge_retrieval", code
    case agent, mcpTool = "mcp_tool", questionClassifier = "question_classifier", iteration
    case variableAggregator = "variable_aggregator", template, httpRequest = "http_request"
    case humanInput = "human_input", subFlow = "sub_flow"
    case note
}

struct WorkflowNode: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var type: NodeTypeKey
    var position: GraphPoint
    var size: GraphPoint
    var config: [String: JSONValue]
    var parentNodeId: UUID?
    var frozen: Bool

    init(id: UUID = UUID(), type: NodeTypeKey, position: GraphPoint, size: GraphPoint = GraphPoint(x: 200, y: 72),
         config: [String: JSONValue] = [:], parentNodeId: UUID? = nil, frozen: Bool = false) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.config = config
        self.parentNodeId = parentNodeId
        self.frozen = frozen
    }
}

struct WorkflowEdge: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var sourceNode: UUID
    var sourcePort: String
    var targetNode: UUID
    var targetPort: String
    var condition: String?
    var isLoop: Bool

    init(id: UUID = UUID(), sourceNode: UUID, sourcePort: String, targetNode: UUID, targetPort: String,
         condition: String? = nil, isLoop: Bool = false) {
        self.id = id
        self.sourceNode = sourceNode
        self.sourcePort = sourcePort
        self.targetNode = targetNode
        self.targetPort = targetPort
        self.condition = condition
        self.isLoop = isLoop
    }
}

struct WorkflowGraph: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var nodes: [WorkflowNode]
    var edges: [WorkflowEdge]
    var viewport: GraphViewport
    var flowStateSchema: [String]
    // metadata: backend_id 等非图结构键 (落盘保留; codec 读写)
    var metadata: [String: JSONValue]

    init(id: UUID = UUID(), name: String, nodes: [WorkflowNode] = [], edges: [WorkflowEdge] = [],
         viewport: GraphViewport = GraphViewport(), flowStateSchema: [String] = [],
         metadata: [String: JSONValue] = [:]) {
        self.id = id
        self.name = name
        self.nodes = nodes
        self.edges = edges
        self.viewport = viewport
        self.flowStateSchema = flowStateSchema
        self.metadata = metadata
    }
}

// MARK: - GraphCodec seam (§6.2 backend mapping)

protocol GraphCodec {
    var backendKind: String { get }
    func toBackend(_ graph: WorkflowGraph) throws -> AgentGraphModel
    func fromBackend(_ model: AgentGraphModel) -> WorkflowGraph
}

// AgentStudio 后端映射: node type 走统一 key 的 rawValue, config 透传;
//   后端契约无类型端口 (audit §2.1) → 边只用节点 id, port key 落 config 不丢失 (round-trip 保真)。
struct AgentStudioCodec: GraphCodec {
    let backendKind = "agent-studio"

    func toBackend(_ graph: WorkflowGraph) throws -> AgentGraphModel {
        guard !graph.name.isEmpty else {
            throw WorkflowError.emptyName
        }
        let nodes = graph.nodes.map { n in
            var cfg = n.config
            cfg["label"] = .string(nodeLabel(n))
            if let src = graph.edges.first(where: { $0.sourceNode == n.id }) {
                cfg["source_port"] = .string(src.sourcePort)
            }
            return NodeConfigModel(
                id: n.id.uuidString,
                type: n.type.rawValue,
                config: cfg,
                position: PositionModel(x: n.position.x, y: n.position.y)
            )
        }
        let edges = graph.edges.map { e in
            EdgeModel(
                id: e.id.uuidString,
                source: e.sourceNode.uuidString,
                target: e.targetNode.uuidString,
                condition: e.condition
            )
        }
        return AgentGraphModel(
            id: graph.backendId ?? "",
            name: graph.name,
            nodes: nodes,
            edges: edges,
            created_at: "",
            nodeCount: nodes.count,
            edgeCount: edges.count
        )
    }

    func fromBackend(_ model: AgentGraphModel) -> WorkflowGraph {
        let nodes: [WorkflowNode] = model.nodes.map { n in
            let key = NodeTypeKey(rawValue: n.type) ?? .tool
            var cfg = n.config
            cfg.removeValue(forKey: "label")
            return WorkflowNode(
                type: key,
                position: GraphPoint(x: n.position?.x ?? 0, y: n.position?.y ?? 0),
                config: cfg
            )
        }
        // 后端契约边无 port (audit §2.1) → 统一默认端口 in/out
        let edges = model.edges.map { e in
            WorkflowEdge(
                sourceNode: UUID(uuidString: e.source) ?? UUID(),
                sourcePort: "out",
                targetNode: UUID(uuidString: e.target) ?? UUID(),
                targetPort: "in",
                condition: e.condition
            )
        }
        return WorkflowGraph(id: UUID(), name: model.name, nodes: nodes, edges: edges)
    }
}

extension WorkflowGraph {
    // 后端 graph id (create/update 后写回 metadata), 随图落盘
    var backendId: String? {
        get { metadata["backend_id"]?.stringValue }
        set { metadata["backend_id"] = newValue.map { .string($0) } }
    }
}

func nodeLabel(_ n: WorkflowNode) -> String {
    if let l = n.config["label"]?.stringValue { return l }
    if let def = NodeRegistry.shared.definition(for: n.type) { return def.displayName }
    return n.type.rawValue
}

// JSONValue → [String: Any] (FSB/cowork 后端 dict 契约用)
extension JSONValue {
    static func toAny(_ v: JSONValue) -> Any {
        switch v {
        case .string(let s): return s
        case .double(let d): return d
        case .bool(let b): return b
        case .object(let o): return o.mapValues { toAny($0) }
        case .array(let a): return a.map { toAny($0) }
        }
    }
}

// MARK: - Errors

enum WorkflowError: LocalizedError {
    case emptyName
    case incompatiblePorts(String)
    case nodeNotSupported(String, String)
    case corruptFlowFile(String)
    case maxIterationsExceeded(Int)

    var errorDescription: String? {
        switch self {
        case .emptyName: return "flow name is empty"
        case .incompatiblePorts(let why): return why
        case .nodeNotSupported(let type, let backend): return "node type '\(type)' not supported by backend '\(backend)'"
        case .corruptFlowFile(let path): return "flow file corrupted: \(path)"
        case .maxIterationsExceeded(let cap): return "loop max_iterations=\(cap) exceeded"
        }
    }
}
