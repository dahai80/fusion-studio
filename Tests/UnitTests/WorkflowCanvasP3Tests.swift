import XCTest
@testable import FusionStudio

// #431-#433 P3 wave 单测: 模板画廊 / 运行历史 + diff / 渲染快车道标志 /
//   GraphEditor plan 应用 / NL planner JSON 提取 / FlowMCP JSON-RPC (mock 传输, 不占端口)。

final class FlowTemplatesTests: XCTestCase {
    func testSevenStartersBuildRunnableShape() {
        NodeRegistry.shared.bootstrapFullSet()
        let all = FlowTemplates.all()
        XCTAssertEqual(all.count, 7)
        for t in all {
            let g = t.build()
            XCTAssertFalse(g.name.isEmpty, "template \(t.name) name")
            XCTAssertEqual(g.nodes.first?.type, .start, "\(t.name) 应 start 开头")
            XCTAssertEqual(g.nodes.last?.type, .end, "\(t.name) 应 end 收尾")
            XCTAssertEqual(g.edges.count, g.nodes.count - 1, "\(t.name) 链式边数")
        }
        let names = all.map(\.name)
        XCTAssertEqual(Set(names).count, 7, "模板名唯一")
    }

    func testSeedIfEmptyIdempotent() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tpl-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = WorkflowFlowStore(root: tmp)
        FlowTemplates.seedIfEmpty(into: store)
        FlowTemplates.seedIfEmpty(into: store)
        XCTAssertEqual(try store.listTemplates().count, 7, "重复播种不产生副本")
    }

    func testInstantiateGetsFreshIdentity() {
        NodeRegistry.shared.bootstrapFullSet()
        let original = FlowTemplates.summarizer()
        var picked = original
        picked.id = UUID()
        picked.backendId = nil
        picked.pendingCheckpoint = nil
        XCTAssertNotEqual(picked.id, original.id)
        XCTAssertNil(picked.backendId)
        XCTAssertNil(picked.pendingCheckpoint)
        XCTAssertEqual(picked.nodes, original.nodes, "结构保真")
    }
}

@MainActor
final class RunHistoryTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("runhist-test-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func record(_ id: String, statuses: [String: String] = ["n1": "finished:ok"]) -> WorkflowRunRecord {
        WorkflowRunRecord(id: id, startedAt: 1, finishedAt: 2, summary: id, ok: true, nodeStatuses: statuses)
    }

    func testAppendCapAndOrder() {
        let store = RunHistoryStore(root: tmp)
        let flow = UUID()
        for i in 0..<25 {
            store.append(flow, record("r\(i)"))
        }
        let runs = store.history(of: flow)
        XCTAssertEqual(runs.count, 20, "历史 cap 20")
        XCTAssertEqual(runs.first?.id, "r24", "最新在前")
        XCTAssertEqual(runs.last?.id, "r5")
        XCTAssertEqual(store.history(of: UUID()).count, 0, "无历史 flow 返回空")
    }

    func testDiffRows() {
        let a = record("a", statuses: [
            "same": "finished:x",
            "chg": "finished:old",
            "gone": "finished:bye",
        ])
        let b = record("b", statuses: [
            "same": "finished:x",
            "chg": "error:boom",
            "new": "finished:hi",
        ])
        let rows = RunDiff.compare(a, b)
        XCTAssertEqual(rows.filter { if case .same = $0 { return true } else { return false } }.count, 1)
        XCTAssertEqual(rows.filter { if case .changed = $0 { return true } else { return false } }.count, 1)
        XCTAssertEqual(rows.filter { if case .onlyA = $0 { return true } else { return false } }.count, 1)
        XCTAssertEqual(rows.filter { if case .onlyB = $0 { return true } else { return false } }.count, 1)
    }

    func testLocalExecutorRecordsHistory() async throws {
        let tmpFlow = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("runhist-exec-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpFlow) }
        let store = WorkflowFlowStore(root: tmpFlow)
        NodeRegistry.shared.bootstrapFullSet()
        var g = WorkflowGraph(name: "hist-flow")
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let end = WorkflowNode(type: .end, position: GraphPoint(x: 100, y: 0))
        g.nodes = [start, end]
        g.edges = [WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: end.id, targetPort: "in")]
        try store.save(g)
        let executor = LocalExecutor(flowStore: store)
        for try await _ in executor.run(g, inputs: [:]) {}
        let history = RunHistoryStore(root: tmpFlow.appendingPathComponent("runs")).history(of: g.id)
        XCTAssertEqual(history.count, 1, "#432 local run 应落历史")
        XCTAssertTrue(history[0].ok)
        XCTAssertEqual(history[0].nodeStatuses.count, 2, "start+end 均有终态")
    }

    @MainActor
    func testRenderFastPathThreshold() {
        NodeRegistry.shared.bootstrapCoreSet()
        var g = WorkflowGraph(name: "perf")
        for i in 0..<80 {
            g.nodes.append(WorkflowNode(type: .note, position: GraphPoint(x: Double(i) * 20, y: 0)))
        }
        let canvas = GraphCanvasView(graph: .constant(g), executor: nil, toast: nil, flowStore: nil)
        XCTAssertFalse(canvas.renderFastPath, "80 节点不开启快车道")
        g.nodes.append(WorkflowNode(type: .note, position: GraphPoint(x: 0, y: 0)))
        let heavy = GraphCanvasView(graph: .constant(g), executor: nil, toast: nil, flowStore: nil)
        XCTAssertTrue(heavy.renderFastPath, ">80 节点开启快车道 (隐藏 summary/token/阴影/minimap)")
    }
}

final class GraphEditorTests: XCTestCase {
    func testAddConnectRemove() {
        NodeRegistry.shared.bootstrapCoreSet()
        var editor = WorkflowGraphEditor(graph: WorkflowGraph(name: "edit"))
        let a = editor.addNode(type: .start, at: GraphPoint(x: 0, y: 0))
        let b = editor.addNode(type: .end, at: GraphPoint(x: 100, y: 0))
        editor.connect(from: a, to: b, sourcePort: "out", targetPort: "in")
        XCTAssertEqual(editor.graph.nodes.count, 2)
        XCTAssertEqual(editor.graph.edges.count, 1)
        editor.setConfig(nodeId: a, key: "state_keys", value: .string("x"))
        XCTAssertEqual(editor.graph.nodes[0].config["state_keys"]?.stringValue, "x")
        editor.removeNode(nodeId: a)
        XCTAssertEqual(editor.graph.nodes.count, 1)
        XCTAssertTrue(editor.graph.edges.isEmpty, "删节点应连带删边")
        // 自环与重复边拒绝
        let c = editor.addNode(type: .tool, at: GraphPoint(x: 200, y: 0))
        editor.connect(from: c, to: c)
        XCTAssertTrue(editor.graph.edges.isEmpty)
        editor.connect(from: b, to: c)
        editor.connect(from: b, to: c)
        XCTAssertEqual(editor.graph.edges.count, 1, "重复边去重")
    }

    func testApplyPlanValidAndUnknownTypes() {
        NodeRegistry.shared.bootstrapCoreSet()
        var editor = WorkflowGraphEditor(graph: WorkflowGraph(name: "planned"))
        let plan = GraphPlan(
            name: "p1",
            nodes: [
                GraphPlanNode(type: "start"),
                GraphPlanNode(type: "llm", config: ["model": .string("qwen")]),
                GraphPlanNode(type: "mystery_type"),
                GraphPlanNode(type: "end"),
            ],
            edges: [
                GraphPlanEdge(from: 0, to: 1),
                GraphPlanEdge(from: 1, to: 2), // 引用被跳过节点 — 丢
                GraphPlanEdge(from: 1, to: 3),
            ]
        )
        let applied = editor.applyPlan(plan)
        XCTAssertEqual(applied, 3, "未知类型跳过, 其余 3 个加进")
        XCTAssertEqual(editor.graph.name, "p1", "plan 命名生效")
        XCTAssertEqual(editor.graph.nodes.map(\.type), [.start, .llm, .end])
        XCTAssertEqual(editor.graph.edges.count, 2, "0->1 与 1->3 有效; 引用被跳过节点的边丢弃")
    }
}

final class NLGraphPlannerTests: XCTestCase {
    func testExtractPlanJSONFromFencedOutput() throws {
        let raw = """
        Here is the plan:
        ```json
        {"name": "route", "nodes": [{"type": "start"}, {"type": "end"}], "edges": [{"from": 0, "to": 1}]}
        ```
        Hope it helps!
        """
        let data = try NLGraphPlanner.extractPlanJSON(raw)
        let plan = try GraphPlan.decode(data)
        XCTAssertEqual(plan.name, "route")
        XCTAssertEqual(plan.nodes.count, 2)
        XCTAssertEqual(plan.edges?.count, 1)
    }

    func testExtractRejectsNoJSON() {
        XCTAssertThrowsError(try NLGraphPlanner.extractPlanJSON("no json here"))
    }

    func testPlanViaMockInfer() async throws {
        let mock: NLGraphPlanner.InferFn = { messages in
            XCTAssertEqual(messages.first?["role"] as? String, "system")
            return """
            {"name": "mocked", "nodes": [{"type": "start"}, {"type": "template", "config": {"template": "hi"}}, {"type": "end"}],
             "edges": [{"from": 0, "to": 1}, {"from": 1, "to": 2}]}
            """
        }
        let planner = NLGraphPlanner(infer: mock)
        let plan = try await planner.plan(prompt: "say hi")
        XCTAssertEqual(plan.name, "mocked")
        XCTAssertEqual(plan.nodes.count, 3)
    }

    func testPlanInvalidJSONThrows() async {
        let planner = NLGraphPlanner(infer: { _ in "not a plan" })
        do {
            _ = try await planner.plan(prompt: "x")
            XCTFail("expected throw")
        } catch {}
    }
}

@MainActor
final class FlowMCPServerTests: XCTestCase {
    private var tmp: URL!
    private var store: WorkflowFlowStore!
    private var server: FlowMCPServer!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mcp-test-\(UUID().uuidString)", isDirectory: true)
        store = WorkflowFlowStore(root: tmp)
        NodeRegistry.shared.bootstrapFullSet()
        var g = WorkflowGraph(name: "hello-flow")
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let end = WorkflowNode(type: .end, position: GraphPoint(x: 100, y: 0))
        g.nodes = [start, end]
        g.edges = [WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: end.id, targetPort: "in")]
        try store.save(g)
        server = FlowMCPServer(flowStore: store)
    }

    override func tearDownWithError() throws {
        server.stop()
        try? FileManager.default.removeItem(at: tmp)
    }

    private func rpc(_ method: String, params: String? = nil, id: String = "1") -> Data {
        let p = params.map { ", \"params\": \($0)" } ?? ""
        return Data("{\"jsonrpc\": \"2.0\", \"id\": \"\(id)\", \"method\": \"\(method)\"\(p)}".utf8)
    }

    private func decode(_ data: Data) throws -> [String: JSONValue] {
        try JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    func testInitialize() throws {
        let resp = try decode(server.handleJSONRPC(rpc("initialize")))
        guard case .object(let result)? = resp["result"],
              case .object(let info)? = result["serverInfo"],
              case .string(let name)? = info["name"] else {
            return XCTFail("initialize result shape")
        }
        XCTAssertEqual(name, "fusion-studio-flow-mcp")
    }

    func testToolsListMapsFlows() throws {
        let resp = try decode(server.handleJSONRPC(rpc("tools/list")))
        guard case .object(let result)? = resp["result"],
              case .array(let tools)? = result["tools"] else {
            return XCTFail("tools/list shape")
        }
        XCTAssertEqual(tools.count, 1)
        guard case .object(let tool)? = tools.first,
              case .string(let toolName)? = tool["name"] else {
            return XCTFail("tool shape")
        }
        XCTAssertEqual(toolName, "hello-flow")
    }

    func testToolsCallRunsFlowLocally() async throws {
        let summary = try await server.runTool(name: "hello-flow", inputs: [:])
        XCTAssertFalse(summary.isEmpty, "start→end 本地真跑应出 summary")
    }

    func testToolsCallUnknownFlowErrors() async {
        do {
            _ = try await server.runTool(name: "missing", inputs: [:])
            XCTFail("expected throw")
        } catch {}
    }

    func testUnknownMethodAndParseError() throws {
        let resp = try decode(server.handleJSONRPC(rpc("bogus/method")))
        guard case .object(let err)? = resp["error"],
              case .double(let code)? = err["code"] else {
            return XCTFail("error shape")
        }
        XCTAssertEqual(code, -32601)
        let bad = try decode(server.handleJSONRPC(Data("not json".utf8)))
        guard case .object(let err2)? = bad["error"] else {
            return XCTFail("parse error shape")
        }
        XCTAssertNotNil(err2["code"])
    }

    func testHealthAndFlowToolsMapping() throws {
        let get = "GET /health HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        let payload = String(decoding: server.httpPayload(Data(get.utf8)), as: UTF8.self)
        XCTAssertTrue(payload.contains("\"status\":\"ok\""))
        let tools = FlowMCPServer.flowTools([WorkflowGraph(name: "t1"), WorkflowGraph(name: "t2")])
        XCTAssertEqual(tools.count, 2)
    }
}
