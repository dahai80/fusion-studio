import Foundation
import os.log

// #433 P3-3: 图编辑 seam + NL planner (plan §6.5 NL build)。
//   GraphEditor protocol: 画布/外部调用者共用的最小编辑原语;
//   WorkflowGraphEditor: 值语义实现 (mutating);
//   NLGraphPlanner: bridge.infer 出严格 JSON plan (节点类型白名单校验, 非法型丢弃不中断)。

private let editorLog = Logger(subsystem: "com.fusion.studio", category: "GraphEditor")

// MARK: - Plan 模型 (LLM 输出契约)

struct GraphPlanNode: Codable, Equatable {
    var type: String
    var config: [String: JSONValue]?

    init(type: String, config: [String: JSONValue]? = nil) {
        self.type = type
        self.config = config
    }
}

struct GraphPlanEdge: Codable, Equatable, Hashable {
    var from: Int
    var to: Int

    init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}

struct GraphPlan: Codable, Equatable {
    var name: String
    var nodes: [GraphPlanNode]
    var edges: [GraphPlanEdge]?

    init(name: String, nodes: [GraphPlanNode], edges: [GraphPlanEdge]? = nil) {
        self.name = name
        self.nodes = nodes
        self.edges = edges
    }

    func encode() throws -> Data { try JSONEncoder().encode(self) }

    static func decode(_ data: Data) throws -> GraphPlan {
        try JSONDecoder().decode(GraphPlan.self, from: data)
    }
}

// MARK: - GraphEditor seam

protocol GraphEditor {
    @discardableResult mutating func addNode(type: NodeTypeKey, at position: GraphPoint, config: [String: JSONValue]) -> UUID
    mutating func connect(from: UUID, to: UUID, sourcePort: String?, targetPort: String?)
    mutating func setConfig(nodeId: UUID, key: String, value: JSONValue)
    mutating func removeNode(nodeId: UUID)
    // 应用 plan: 非法节点类型跳过 (日志可见), 返回实际加节点数
    @discardableResult mutating func applyPlan(_ plan: GraphPlan) -> Int
}

struct WorkflowGraphEditor: GraphEditor {
    private(set) var graph: WorkflowGraph

    init(graph: WorkflowGraph) {
        self.graph = graph
    }

    mutating func addNode(type: NodeTypeKey, at position: GraphPoint, config: [String: JSONValue] = [:]) -> UUID {
        let node = WorkflowNode(type: type, position: position, config: config)
        graph.nodes.append(node)
        editorLog.info("editor addNode \(type.rawValue, privacy: .public)")
        return node.id
    }

    mutating func connect(from: UUID, to: UUID, sourcePort: String? = nil, targetPort: String? = nil) {
        let srcPort = sourcePort ?? nodeType(from).flatMap { NodeRegistry.shared.definition(for: $0)?.outputs.first?.key } ?? "out"
        let dstPort = targetPort ?? "in"
        guard from != to else {
            editorLog.warning("editor connect rejected: self-loop \(from.uuidString.prefix(8))")
            return
        }
        guard !graph.edges.contains(where: { $0.sourceNode == from && $0.targetNode == to }) else {
            editorLog.warning("editor connect dedup: \(from.uuidString.prefix(8))->\(to.uuidString.prefix(8))")
            return
        }
        graph.edges.append(WorkflowEdge(sourceNode: from, sourcePort: srcPort, targetNode: to, targetPort: dstPort))
    }

    mutating func setConfig(nodeId: UUID, key: String, value: JSONValue) {
        guard let idx = graph.nodes.firstIndex(where: { $0.id == nodeId }) else {
            editorLog.warning("editor setConfig: node missing \(nodeId.uuidString.prefix(8))")
            return
        }
        graph.nodes[idx].config[key] = value
    }

    mutating func removeNode(nodeId: UUID) {
        graph.nodes.removeAll { $0.id == nodeId }
        graph.edges.removeAll { $0.sourceNode == nodeId || $0.targetNode == nodeId }
    }

    mutating func applyPlan(_ plan: GraphPlan) -> Int {
        if !plan.name.isEmpty {
            graph.name = plan.name
        }
        var idByIndex: [Int: UUID] = [:]
        var added = 0
        for (idx, pn) in plan.nodes.enumerated() {
            guard let type = NodeTypeKey(rawValue: pn.type) else {
                editorLog.warning("plan node[\(idx)] unknown type '\(pn.type, privacy: .public)' — skipped")
                continue
            }
            let node = WorkflowNode(
                type: type,
                position: GraphPoint(x: 80 + Double(added) * 240, y: 160 + Double(added % 2) * 40),
                config: pn.config ?? [:]
            )
            graph.nodes.append(node)
            idByIndex[idx] = node.id
            added += 1
        }
        for edge in plan.edges ?? [] {
            guard let from = idByIndex[edge.from], let to = idByIndex[edge.to] else {
                editorLog.warning("plan edge \(edge.from)->\(edge.to) references skipped node — dropped")
                continue
            }
            connect(from: from, to: to)
        }
        editorLog.info("plan applied nodes=\(added)/\(plan.nodes.count) edges=\(plan.edges?.count ?? 0)")
        return added
    }

    private func nodeType(_ id: UUID) -> NodeTypeKey? {
        graph.nodes.first { $0.id == id }?.type
    }
}

// MARK: - NL planner (bridge.infer 路径, 直连 MLX)

struct NLGraphPlanner {
    // 注入 seam: 测试走 mock, 生产走 bridge.infer
    typealias InferFn = ([[String: Any]]) async throws -> String
    let infer: InferFn

    static let planSchemaPrompt = """
    You are a workflow graph planner. Output ONLY one JSON object, no markdown, no explanation.
    Schema:
    {"name": string, "nodes": [{"type": one of [start,end,llm,tool,condition,loop,knowledge_retrieval,code,agent,mcp_tool,question_classifier,iteration,variable_aggregator,template,http_request,human_input,sub_flow,note], "config": object}], "edges": [{"from": node_index, "to": node_index}]}
    Nodes must form a runnable chain starting with "start" and ending with "end". Config values are strings or numbers.
    """

    func plan(prompt: String) async throws -> GraphPlan {
        let messages: [[String: Any]] = [
            ["role": "system", "content": Self.planSchemaPrompt],
            ["role": "user", "content": prompt],
        ]
        let raw = try await infer(messages)
        let text = try Self.extractPlanJSON(raw)
        do {
            return try GraphPlan.decode(text)
        } catch {
            editorLog.error("plan decode failed: \(error.localizedDescription, privacy: .public) raw=\(String(raw.prefix(200)), privacy: .public)")
            throw WorkflowError.corruptFlowFile("planner returned invalid plan JSON")
        }
    }

    // 提取首个 { 到最后一个 } (LLM 常见 ```json 包裹 / 前后闲话)
    static func extractPlanJSON(_ raw: String) throws -> Data {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}"), start < end else {
            throw WorkflowError.corruptFlowFile("planner output has no JSON object")
        }
        return Data(String(raw[start...end]).utf8)
    }
}
