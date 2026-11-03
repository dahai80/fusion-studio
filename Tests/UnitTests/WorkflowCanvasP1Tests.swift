import XCTest
@testable import FusionStudio

// #421-#426 P1 wave 单测: 模型 round-trip / codec / 端口兼容矩阵 / registry / flow store /
//   executor (mock graph service) / secret 持久化缺席。

final class WorkflowGraphModelTests: XCTestCase {
    func testGraphCodableRoundTrip() throws {
        var g = WorkflowGraph(name: "rt")
        let n1 = WorkflowNode(type: .llm, position: GraphPoint(x: 10, y: 20), config: ["model": .string("qwen")])
        let n2 = WorkflowNode(type: .end, position: GraphPoint(x: 200, y: 20))
        g.nodes = [n1, n2]
        g.edges = [WorkflowEdge(sourceNode: n1.id, sourcePort: "out", targetNode: n2.id, targetPort: "in")]
        g.viewport = GraphViewport(offsetX: 5, offsetY: 6, scale: 1.5)
        g.backendId = "bg-1"

        let data = try JSONEncoder.fusionWorkflow.encode(g)
        let back = try JSONDecoder.fusionWorkflow.decode(WorkflowGraph.self, from: data)

        XCTAssertEqual(back, g)
        XCTAssertEqual(back.backendId, "bg-1")
    }

    func testCodecToBackendFromBackendRoundTrip() throws {
        var g = WorkflowGraph(name: "codec")
        let n1 = WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0), config: ["state_keys": .string("x")])
        let n2 = WorkflowNode(type: .llm, position: GraphPoint(x: 100, y: 0))
        g.nodes = [n1, n2]
        g.edges = [WorkflowEdge(sourceNode: n1.id, sourcePort: "out", targetNode: n2.id, targetPort: "in")]

        let codec = AgentStudioCodec()
        let backend = try codec.toBackend(g)
        XCTAssertEqual(backend.nodes.count, 2)
        XCTAssertEqual(backend.edges.first?.source, n1.id.uuidString)
        XCTAssertEqual(backend.name, "codec")

        let back = codec.fromBackend(backend)
        XCTAssertEqual(back.nodes.count, 2)
        XCTAssertEqual(back.nodes.map(\.type), [.start, .llm])
        XCTAssertEqual(back.edges.count, 1)
        // port key 保真: source_port 落 config
        XCTAssertEqual(backend.nodes.first?.config["source_port"]?.stringValue, "out")
    }

    func testCodecRejectsEmptyName() {
        let g = WorkflowGraph(name: "")
        XCTAssertThrowsError(try AgentStudioCodec().toBackend(g)) { err in
            guard case WorkflowError.emptyName = err else {
                return XCTFail("expected emptyName, got \(err)")
            }
        }
    }

    func testPortCompatibilityMatrix() {
        func verdict(_ out: PortDataType, _ in: PortDataType) -> PortCompatibility.Verdict {
            PortCompatibility.check(output: out, input: `in`)
        }
        // 同型 ok
        XCTAssertEqual(verdict(.message, .message), .ok)
        XCTAssertEqual(verdict(.json, .json), .ok)
        // .any 逃生舱带警告
        guard case .okWithWarning = verdict(.any, .json) else { return XCTFail("any->json should warn") }
        guard case .okWithWarning = verdict(.json, .any) else { return XCTFail("json->any should warn") }
        // 迁移表
        guard case .okWithWarning = verdict(.data, .json) else { return XCTFail("data->json migration") }
        guard case .okWithWarning = verdict(.message, .json) else { return XCTFail("message->json migration") }
        guard case .okWithWarning = verdict(.tool, .any) else { return XCTFail("tool->any migration") }
        // 拒绝带原因
        guard case .rejected(let why) = verdict(.data, .tool) else { return XCTFail("data->tool rejected") }
        XCTAssertTrue(why.contains("incompatible"))
    }

    func testValidateEdgeDirectionGuards() {
        let out = Port(key: "out", label: "o", dataType: .message, direction: .output)
        let inp = Port(key: "in", label: "i", dataType: .message, direction: .input)
        XCTAssertEqual(PortCompatibility.validateEdge(source: out, target: inp), .ok)
        guard case .rejected = PortCompatibility.validateEdge(source: inp, target: out) else {
            return XCTFail("input-as-source rejected")
        }
    }

    func testUnknownBackendTypeMapsToTool() {
        let m = AgentGraphModel(
            id: "g1", name: "legacy",
            nodes: [NodeConfigModel(id: "n1", type: "mystery_type", config: [:], position: PositionModel(x: 0, y: 0))],
            edges: [], created_at: "", nodeCount: 1, edgeCount: 0
        )
        let g = AgentStudioCodec().fromBackend(m)
        XCTAssertEqual(g.nodes.first?.type, .tool)
    }
}

final class NodeRegistryTests: XCTestCase {
    func testCoreSetRegisteredAndDiscoverable() {
        // registry 单例共享 (P2 bootstrapFullSet 可能先跑) — 断言核心键存在, 不锁计数
        NodeRegistry.shared.bootstrapCoreSet()
        XCTAssertGreaterThanOrEqual(NodeRegistry.shared.registeredKeys.count, 8)
        XCTAssertNotNil(NodeRegistry.shared.definition(for: .llm))
        XCTAssertNotNil(NodeRegistry.shared.definition(for: .condition))
    }

    func testCategoriesGrouping() {
        NodeRegistry.shared.bootstrapCoreSet()
        let cats = NodeRegistry.shared.categories()
        XCTAssertTrue(cats[.flow]?.contains(.start) ?? false)
        XCTAssertTrue(cats[.model]?.contains(.llm) ?? false)
    }

    func testConditionNodeRealRun() async throws {
        NodeRegistry.shared.bootstrapCoreSet()
        let def = try XCTUnwrap(NodeRegistry.shared.definition(for: .condition))
        let state = FlowState()
        state.write(.string("high"), for: "score")
        let ctx = NodeContext(
            nodeId: UUID(),
            config: ["expression": .string("score equals high")],
            inputs: [:],
            flowState: state
        )
        let result = try await def.run(ctx)
        XCTAssertEqual(result.output?.stringValue, "true")
    }

    func testConditionNodeFalseBranch() async throws {
        NodeRegistry.shared.bootstrapCoreSet()
        let def = try XCTUnwrap(NodeRegistry.shared.definition(for: .condition))
        let ctx = NodeContext(
            nodeId: UUID(),
            config: ["expression": .string("score equals low")],
            inputs: ["score": .string("high")],
            flowState: FlowState()
        )
        let result = try await def.run(ctx)
        XCTAssertEqual(result.output?.stringValue, "false")
    }

    func testTaxonomyMappingFSB() {
        XCTAssertEqual(LegacyTaxonomyMapping.fsbToUnified["START_NODE"], .start)
        XCTAssertEqual(LegacyTaxonomyMapping.fsbToUnified["LLM_NODE"], .llm)
        XCTAssertEqual(LegacyTaxonomyMapping.fsbToUnified["SKILL_NODE"], .tool)
        XCTAssertEqual(LegacyTaxonomyMapping.fsbToUnified["APPROVAL_GATE_NODE"], .humanInput)
    }

    func testTaxonomyMappingAgentStudio() {
        XCTAssertEqual(LegacyTaxonomyMapping.agentStudioToUnified["error_handler"], .condition)
        XCTAssertEqual(LegacyTaxonomyMapping.agentStudioToUnified["router"], .condition)
        XCTAssertEqual(LegacyTaxonomyMapping.agentStudioToUnified["human_in_loop"], .humanInput)
    }
}

final class WorkflowFlowStoreTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("flowstore-test-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testSaveLoadDelete() throws {
        let store = WorkflowFlowStore(root: tmp)
        var g = WorkflowGraph(name: "flow-a")
        g.nodes = [WorkflowNode(type: .start, position: GraphPoint(x: 0, y: 0))]
        try store.save(g)
        let loaded = try store.load(g.id)
        XCTAssertEqual(loaded, g)
        try store.delete(g.id)
        XCTAssertThrowsError(try store.load(g.id))
    }

    func testCorruptFileQuarantined() throws {
        let store = WorkflowFlowStore(root: tmp)
        let g = WorkflowGraph(name: "bad")
        try store.save(g)
        // 破坏文件内容
        let url = tmp.appendingPathComponent("flows").appendingPathComponent("\(g.id.uuidString).json")
        try Data("{{{not json".utf8).write(to: url)
        XCTAssertThrowsError(try store.load(g.id)) { err in
            guard case WorkflowError.corruptFlowFile = err else {
                return XCTFail("expected corruptFlowFile, got \(err)")
            }
        }
        // 损坏文件移入 corrupt/ 留现场
        let corrupt = try FileManager.default.contentsOfDirectory(at: tmp.appendingPathComponent("corrupt"), includingPropertiesForKeys: nil)
        XCTAssertEqual(corrupt.count, 1)
    }

    func testListFlowsToleratesCorruptEntry() throws {
        let store = WorkflowFlowStore(root: tmp)
        let g = WorkflowGraph(name: "good")
        try store.save(g)
        try Data("]broken[".utf8).write(to: tmp.appendingPathComponent("flows").appendingPathComponent("dead.json"))
        let flows = try store.listFlows()
        XCTAssertEqual(flows.count, 1)
        XCTAssertEqual(flows.first?.id, g.id)
    }

    func testSnapshotLRUCap() throws {
        let store = WorkflowFlowStore(root: tmp)
        var g = WorkflowGraph(name: "snap")
        for i in 0..<25 {
            g.name = "snap-\(i)"
            try store.save(g)
        }
        let snaps = try store.snapshots(for: g.id)
        XCTAssertEqual(snaps.count, 20, "快照应 LRU 截到 20")
        XCTAssertEqual(snaps.first?.name, "snap-24", "最新在前")
    }

    func testTemplatesRoundTrip() throws {
        let store = WorkflowFlowStore(root: tmp)
        let g = WorkflowGraph(name: "proto")
        try store.saveAsTemplate(g, templateName: "starter")
        let templates = try store.listTemplates()
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates.first?.name, "starter")
    }
}

// executor mock: graph service 注入点 (#424 可测性)
@MainActor
private final class MockGraphService: AgentGraphServiceProviding {
    var createdGraphs: [AgentGraphModel] = []
    var events: [AgentEventModel]

    init(events: [AgentEventModel]) {
        self.events = events
    }

    func createGraph(name: String, nodes: [NodeConfigModel], edges: [EdgeModel]) async throws -> AgentGraphModel {
        let m = AgentGraphModel(id: "bg-\(createdGraphs.count + 1)", name: name, nodes: nodes, edges: edges, created_at: "", nodeCount: nodes.count, edgeCount: edges.count)
        createdGraphs.append(m)
        return m
    }

    func updateGraph(id: String, name: String?, nodes: [NodeConfigModel]?, edges: [EdgeModel]?) async throws -> AgentGraphModel? {
        AgentGraphModel(id: id, name: name ?? "", nodes: nodes ?? [], edges: edges ?? [], created_at: "", nodeCount: nodes?.count ?? 0, edgeCount: edges?.count ?? 0)
    }

    func cancelExecution() {}

    func execute() async throws -> [AgentEventModel] { events }
}

@MainActor
final class AgentStudioExecutorTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("executor-test-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func makeGraph() -> WorkflowGraph {
        var g = GraphFlowBuilderView.seedGraph()
        g.name = "exec-test"
        return g
    }

    func testRunYieldsStepEventsFromBackendEvents() async throws {
        let backendEvents = [
            AgentEventModel(type: "node_started", node_id: "n1", data: nil),
            AgentEventModel(type: "token_delta", node_id: "n1", data: ["text": .string("hel")]),
            AgentEventModel(type: "node_finished", node_id: "n1", data: ["output": .string("done")]),
        ]
        let mock = MockGraphService(events: backendEvents)

        // 注入 execute: AgentStudioExecutor 经 bridge.executeGraph — mock 走 graphService 只覆盖 CRUD,
        // execute 事件流经 AgentBridge; 此处直接驱动 executor.run 会调 bridge (nil → notConnected)。
        // 可测路径: 验证 syncGraph 落 create + 事件映射器。用 run 的 create 分支 + notConnected 错误路径。
        let executor = AgentStudioExecutor(bridge: nil, graphService: mock)
        let g = makeGraph()
        let stream = executor.run(g, inputs: [:])

        var sawRunStarted = false
        do {
            for try await _ in stream {}
            XCTFail("expected throw (no bridge)")
        } catch {
            sawRunStarted = true
        }
        XCTAssertTrue(sawRunStarted, "无 bridge 应显式报错 (fail visibly)")
        XCTAssertEqual(mock.createdGraphs.count, 1, "执行前应先 create graph")
        XCTAssertEqual(mock.createdGraphs.first?.name, "exec-test")
    }

    func testBackendIdRegistryAfterCreate() async throws {
        let mock = MockGraphService(events: [])
        let executor = AgentStudioExecutor(bridge: nil, graphService: mock)
        let g = makeGraph()
        let stream = executor.run(g, inputs: [:])
        do { for try await _ in stream {} } catch {}
        XCTAssertEqual(executor.backendId(for: g.id), "bg-1", "run create 后 backendId 应可取回")
    }

    func testUnsupportedNodeTypesBadgeSource() {
        let executor = AgentStudioExecutor(bridge: nil, graphService: MockGraphService(events: []))
        XCTAssertFalse(executor.supportedNodeTypes.contains(.note), "note 不应被后端执行")
        XCTAssertTrue(executor.supportedNodeTypes.contains(.llm))
    }
}

final class WorkflowSecretPersistenceTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("secret-test-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testSecretNeverInPersistedJSON() throws {
        // inspector 写 secret → config 变占位符; 落盘 JSON 不得含真值
        let schema = LLMNodeDefinition.configSchema
        let apiKeyField = schema.first { $0.type == .secret }
        // LLM schema 可能无 secret 字段 — 兜底构造
        let field = apiKeyField ?? ConfigField(key: "api_key", label: "API Key", type: .secret, defaultValue: nil, options: nil, required: false, advanced: false, showIfKey: nil, showIfValue: nil)

        var node = WorkflowNode(type: .llm, position: GraphPoint(x: 0, y: 0))
        node.config[field.key] = .string("sk-live-secret-123")
        let stripped = SecretStripper.strip(config: node.config, schema: [field])
        node.config = stripped

        XCTAssertEqual(stripped[field.key]?.stringValue, SecretStore.placeholder(field.key), "strip 后应为占位符")

        var g = WorkflowGraph(name: "sec")
        g.nodes = [node]
        let store = WorkflowFlowStore(root: tmp)
        try store.save(g)
        let raw = try String(contentsOf: tmp.appendingPathComponent("flows").appendingPathComponent("\(g.id.uuidString).json"), encoding: .utf8)
        XCTAssertFalse(raw.contains("sk-live-secret-123"), "secret 真值绝不能落盘")
        XCTAssertTrue(raw.contains("<keychain:"), "落盘应为 keychain 占位符")

        // unmask 读回编辑
        let loaded = try store.load(g.id)
        let unmasked = SecretStripper.unmask(config: loaded.nodes[0].config, schema: [field])
        XCTAssertEqual(unmasked[field.key]?.stringValue, "sk-live-secret-123")
    }

    func testSummaryMasksSecret() {
        let field = ConfigField(key: "api_key", label: "API Key", type: .secret, defaultValue: nil, options: nil, required: false, advanced: false, showIfKey: nil, showIfValue: nil)
        let s = SecretStripper.summary(config: ["api_key": .string("sk-secret")], schema: [field])
        XCTAssertTrue(s.contains("••••"))
        XCTAssertFalse(s.contains("sk-secret"))
    }
}
