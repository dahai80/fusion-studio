import XCTest
@testable import FusionStudio

// #427-#430 P2 wave 单测: 全量节点库 / FSB graph 适配 / 本地解释器
//   (condition 分支, loop 帽, iteration, template, aggregator, sub_flow,
//    checkpoint 落盘恢复) / 变量快照。

final class NodeLibraryP2Tests: XCTestCase {
    func testFullSetSeventeenTypes() {
        NodeRegistry.shared.bootstrapFullSet()
        XCTAssertEqual(NodeRegistry.shared.registeredKeys.count, NodeTypeKey.allCases.count)
        for key in NodeTypeKey.allCases {
            XCTAssertNotNil(NodeRegistry.shared.definition(for: key), "type \(key.rawValue) missing definition")
        }
    }

    func testVariableAggregatorFirstNonEmptyWins() async throws {
        let def = try XCTUnwrap(NodeRegistry.shared.definition(for: .variableAggregator))
        let state = FlowState()
        state.write(.string(""), for: "a")
        state.write(.string("winner"), for: "b")
        let ctx = NodeContext(
            nodeId: UUID(),
            config: ["state_keys": .string("a, b"), "output_key": .string("agg")],
            inputs: [:],
            flowState: state
        )
        let result = try await def.run(ctx)
        XCTAssertEqual(result.output?.stringValue, "winner")
        XCTAssertEqual(result.stateWrites["agg"]?.stringValue, "winner")
    }

    func testTemplateRendersStatePlaceholders() async throws {
        let def = try XCTUnwrap(NodeRegistry.shared.definition(for: .template))
        let state = FlowState()
        state.write(.string("World"), for: "name")
        let ctx = NodeContext(
            nodeId: UUID(),
            config: ["template": .string("Hello {{ name }}!"), "output_key": .string("greeting")],
            inputs: [:],
            flowState: state
        )
        let result = try await def.run(ctx)
        XCTAssertEqual(result.output?.stringValue, "Hello World!")
        XCTAssertEqual(result.stateWrites["greeting"]?.stringValue, "Hello World!")
    }

    func testHumanInputSchema() throws {
        XCTAssertEqual(HumanInputNodeDefinition.configSchema.count, 3)
        XCTAssertEqual(SubFlowNodeDefinition.configSchema.first?.key, "flow_name")
    }
}

final class FSBGraphAdapterTests: XCTestCase {
    func testTypeMappingBidirectional() {
        XCTAssertEqual(FSBGraphAdapter.fsbType(for: .start), "START_NODE")
        XCTAssertEqual(FSBGraphAdapter.fsbType(for: .tool), "SKILL_NODE")
        XCTAssertNil(FSBGraphAdapter.fsbType(for: .note))
        // LegacyTaxonomyMapping 正向 + FSBGraphAdapter 逆向互为反函数
        XCTAssertEqual(LegacyTaxonomyMapping.fsbToUnified["START_NODE"], .start)
    }

    func testGraphDefinitionShape() throws {
        var g = WorkflowGraph(name: "fsb-flow")
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let llm = WorkflowNode(type: .llm, position: GraphPoint(x: 100, y: 0), config: ["model": .string("qwen")])
        let note = WorkflowNode(type: .note, position: GraphPoint(x: 200, y: 0))
        g.nodes = [start, llm, note]
        g.edges = [
            WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: llm.id, targetPort: "in"),
            WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: note.id, targetPort: "in"),
        ]
        let def = FSBGraphAdapter.graphDefinition(g)
        let nodes = try XCTUnwrap(def["nodes"] as? [[String: Any]])
        XCTAssertEqual(nodes.count, 2, "note (无 FSB 映射) 不应进入 graphDefinition")
        let types = nodes.compactMap { $0["type"] as? String }
        XCTAssertEqual(types.sorted(), ["LLM_NODE", "START_NODE"])
        let edges = try XCTUnwrap(def["edges"] as? [[String: Any]])
        XCTAssertEqual(edges.count, 1, "指向 note 的边应被过滤")
        XCTAssertTrue(edges.allSatisfy { $0["source"] != nil && $0["target"] != nil })
    }

    func testNodeEventsParsingTolerantShapes() {
        let exec: [String: Any] = [
            "steps": [
                ["node_id": "n1", "status": "completed", "output": "ok"],
                ["nodeId": "n2", "status": "FAILED", "result": "boom"],
            ]
        ]
        let events = FSBGraphAdapter.nodeEvents(execution: exec)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].status, "completed")
        XCTAssertEqual(events[1].nodeId, "n2")
        XCTAssertEqual(events[1].output, "boom")
    }
}

// @Sendable yield 闭包捕获收集器 (Xcode 15: var 捕获拒绝; 锁保护盒)
private final class EventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [StepEvent] = []
    func append(_ e: StepEvent) {
        lock.lock(); defer { lock.unlock() }
        items.append(e)
    }
    var all: [StepEvent] {
        lock.lock(); defer { lock.unlock() }
        return items
    }
}

@MainActor
final class LocalGraphInterpreterTests: XCTestCase {
    private var tmp: URL!
    private var store: WorkflowFlowStore!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("interp-test-\(UUID().uuidString)", isDirectory: true)
        store = WorkflowFlowStore(root: tmp)
        NodeRegistry.shared.bootstrapFullSet()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private var events: [(id: String, kind: String)] = []

    func testStartToConditionToEndTrueBranch() async throws {
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let cond = WorkflowNode(type: .condition, position: GraphPoint(x: 100, y: 0),
                                config: ["expression": .string("flag equals yes")])
        let endT = WorkflowNode(type: .end, position: GraphPoint(x: 200, y: -50))
        let endF = WorkflowNode(type: .end, position: GraphPoint(x: 200, y: 50))
        var g = WorkflowGraph(name: "cond")
        g.nodes = [start, cond, endT, endF]
        g.edges = [
            WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: cond.id, targetPort: "in"),
            WorkflowEdge(sourceNode: cond.id, sourcePort: "true", targetNode: endT.id, targetPort: "in"),
            WorkflowEdge(sourceNode: cond.id, sourcePort: "false", targetNode: endF.id, targetPort: "in"),
        ]
        let interp = LocalGraphInterpreter()
        let seen = EventCollector()
        let (outcome, _) = try await interp.execute(
            g, inputs: ["flag": .string("yes")],
            yield: { seen.append($0) }
        )
        guard case .finished(let summary) = outcome else { return XCTFail("expected finished") }
        XCTAssertEqual(summary, "true", "end 节点 echo condition 分支输出")
        XCTAssertTrue(seen.all.contains { if case .stepStarted(let n) = $0 { return n == endT.id.uuidString } else { return false } })
        XCTAssertFalse(seen.all.contains { if case .stepStarted(let n) = $0 { return n == endF.id.uuidString } else { return false } })
    }

    func testLoopCapThrows() async throws {
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let loop = WorkflowNode(type: .loop, position: GraphPoint(x: 100, y: 0),
                                config: ["max_iterations": .string("3"), "state_key": .string("loop_i")])
        var g = WorkflowGraph(name: "loop")
        g.nodes = [start, loop]
        g.edges = [WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: loop.id, targetPort: "in", isLoop: true)]
        let interp = LocalGraphInterpreter()
        do {
            // loop_i 缺省 → 0 轮 (false), 不抛; 先给真值 + 数值步进验证帽
            _ = try await interp.execute(g, inputs: ["loop_i": .double(0)], yield: { _ in })
        } catch {
            XCTFail("false 条件不应触发 loop: \(error)")
        }
        var g2 = g
        g2.nodes[1].config["max_iterations"] = .string("3")
        do {
            _ = try await interp.execute(g2, inputs: ["loop_i": .double(1)], yield: { _ in })
            // loop_i=1 数值真值 → 自增 2,3,... 超帽抛错
            XCTFail("expected maxIterationsExceeded")
        } catch let e as WorkflowError {
            guard case .maxIterationsExceeded = e else { return XCTFail("wrong error \(e)") }
        }
    }

    func testIterationOverArrayWritesCollected() async throws {
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let iter = WorkflowNode(type: .iteration, position: GraphPoint(x: 100, y: 0),
                                config: ["item_key": .string("item"), "max_iterations": .string("10")])
        let agg = WorkflowNode(type: .variableAggregator, position: GraphPoint(x: 200, y: 0),
                               config: ["state_keys": .string("collected")])
        let end = WorkflowNode(type: .end, position: GraphPoint(x: 300, y: 0))
        var g = WorkflowGraph(name: "iter")
        g.nodes = [start, iter, agg, end]
        g.edges = [
            WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: iter.id, targetPort: "in"),
            WorkflowEdge(sourceNode: iter.id, sourcePort: "out", targetNode: agg.id, targetPort: "in"),
            WorkflowEdge(sourceNode: agg.id, sourcePort: "out", targetNode: end.id, targetPort: "in"),
        ]
        let interp = LocalGraphInterpreter()
        let (outcome, finalState) = try await interp.execute(
            g, inputs: ["items": .array([.string("a"), .string("b")])],
            yield: { _ in }
        )
        guard case .finished = outcome else { return XCTFail("expected finished") }
        guard case .array(let collected)? = finalState["collected"] else {
            return XCTFail("expected collected array, got \(finalState["collected"] ?? .string("-"))")
        }
        XCTAssertEqual(collected.count, 2)
    }

    func testTemplateInFlow() async throws {
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let tpl = WorkflowNode(type: .template, position: GraphPoint(x: 100, y: 0),
                               config: ["template": .string("Hi {{user}}"), "output_key": .string("msg")])
        let end = WorkflowNode(type: .end, position: GraphPoint(x: 200, y: 0))
        var g = WorkflowGraph(name: "tpl")
        g.nodes = [start, tpl, end]
        g.edges = [
            WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: tpl.id, targetPort: "in"),
            WorkflowEdge(sourceNode: tpl.id, sourcePort: "out", targetNode: end.id, targetPort: "in"),
        ]
        let interp = LocalGraphInterpreter()
        let (outcome, finalState) = try await interp.execute(
            g, inputs: ["user": .string("Ahai")], yield: { _ in }
        )
        guard case .finished = outcome else { return XCTFail("expected finished") }
        XCTAssertEqual(finalState["msg"]?.stringValue, "Hi Ahai")
    }

    func testCheckpointPersistedAndResumable() async throws {
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let human = WorkflowNode(type: .humanInput, position: GraphPoint(x: 100, y: 0),
                                 config: ["question": .string("Approve?"), "answer_key": .string("approval")])
        let end = WorkflowNode(type: .end, position: GraphPoint(x: 200, y: 0))
        var g = WorkflowGraph(name: "hitl")
        g.nodes = [start, human, end]
        g.edges = [
            WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: human.id, targetPort: "in"),
            WorkflowEdge(sourceNode: human.id, sourcePort: "out", targetNode: end.id, targetPort: "in"),
        ]

        // 1) run 到 checkpoint, 落盘
        let executor = LocalExecutor(flowStore: store)
        for try await _ in executor.run(g, inputs: [:]) {}
        var persisted = try store.load(g.id)
        let cp = try XCTUnwrap(persisted.pendingCheckpoint, "checkpoint 应落盘")
        XCTAssertEqual(cp.question, "Approve?")
        XCTAssertEqual(cp.answerKey, "approval")

        // 2) 模拟重启: store 重新 load → resume 续跑
        persisted = try store.load(g.id)
        let executor2 = LocalExecutor(flowStore: store)
        for try await _ in executor2.resume(persisted, answer: "approved") {}
        let final = try store.load(g.id)
        XCTAssertNil(final.pendingCheckpoint, "resume 后 checkpoint 应清除")
        XCTAssertEqual(final.nodes.count, 3, "图结构保持")
    }

    func testSubFlowInlineExecution() async throws {
        // 子流: start → end (echo input)
        var sub = WorkflowGraph(name: "double-helper")
        let subStart = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let subEnd = WorkflowNode(type: .end, position: GraphPoint(x: 100, y: 0))
        sub.nodes = [subStart, subEnd]
        sub.edges = [WorkflowEdge(sourceNode: subStart.id, sourcePort: "out", targetNode: subEnd.id, targetPort: "in")]
        try store.save(sub)

        // 主流: start → sub_flow → end
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let subNode = WorkflowNode(type: .subFlow, position: GraphPoint(x: 100, y: 0),
                                   config: ["flow_name": .string("double-helper")])
        let end = WorkflowNode(type: .end, position: GraphPoint(x: 200, y: 0))
        var main = WorkflowGraph(name: "main")
        main.nodes = [start, subNode, end]
        main.edges = [
            WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: subNode.id, targetPort: "in"),
            WorkflowEdge(sourceNode: subNode.id, sourcePort: "out", targetNode: end.id, targetPort: "in"),
        ]

        let executor = LocalExecutor(flowStore: store)
        var sawSubStream = false
        for try await ev in executor.run(main, inputs: [:]) {
            if case .tokenStream(let n, let chunk) = ev, chunk.contains("double-helper") {
                sawSubStream = n == subNode.id.uuidString
            }
        }
        XCTAssertTrue(sawSubStream, "sub_flow 内联执行应产生 tokenStream 标记")
    }

    func testUnsupportedTypeErrorVisible() async throws {
        let llm = WorkflowNode(type: .llm, position: GraphPoint(x: 0, y: 0))
        var g = WorkflowGraph(name: "bad")
        g.nodes = [llm]
        let interp = LocalGraphInterpreter()
        do {
            _ = try await interp.execute(g, inputs: [:], yield: { _ in })
            XCTFail("llm 非 local 可执行 — 应显式报错")
        } catch let e as WorkflowError {
            guard case .nodeNotSupported = e else { return XCTFail("wrong error \(e)") }
        }
    }

    func testLocalExecutorVariablesSnapshot() async throws {
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))
        let end = WorkflowNode(type: .end, position: GraphPoint(x: 100, y: 0))
        var g = WorkflowGraph(name: "vars")
        g.nodes = [start, end]
        g.edges = [WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: end.id, targetPort: "in")]
        let executor = LocalExecutor(flowStore: store)
        for try await _ in executor.run(g, inputs: ["k": .string("v")]) {}
        XCTAssertEqual(executor.lastStateSnapshot["k"]?.stringValue, "v", "#429 变量检查器数据源")
    }
}
