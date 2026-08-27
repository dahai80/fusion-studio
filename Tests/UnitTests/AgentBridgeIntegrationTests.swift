import XCTest
@testable import FusionStudio

// F-I5: AgentBridge 核心路径集成测试 (batch 17b)。
// mock IPCClient (MockIPCClient) + setIPCClient 注入, 验证 call 方法名/参数 + 响应解析 + @Published 状态。
// 回归守卫: F-I4 刚改的 parseAgentModel/parseGraphModel/parsePlanModel 路径 + 4 修复的响应 key (agents/graphs/tasks/projects)。
// 非严格 schema 校验 — 验证已知 API 变体宽容 (dual-key/manifest-nested/dict-array/??default) 仍工作 (用户 Conservative 决策)。
@MainActor
final class AgentBridgeIntegrationTests: XCTestCase {

    private var mock: MockIPCClient!
    private var bridge: AgentBridge!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockIPCClient()
        bridge = AgentBridge()
        bridge.setIPCClient(mock)
    }

    override func tearDown() async throws {
        mock = nil
        bridge = nil
        try await super.tearDown()
    }

    // MARK: - Group 1 — Agent lifecycle (AgentOpsService, parseAgentModel via F-I4)

    // fetchAgents: dual-key agent_id/id, recordedCalls.method, @Published agents 更新。
    // 回归守卫: 修复的 result["agents"] key (F-A1 regression 6e02e36 把它改成 "self.agentState.agents" 致列表恒空)。
    func testFetchAgentsParsesListAndDualKey() async throws {
        mock.responsesByMethod[RPCMethod.agentList] = [
            "agents": [
                ["agent_id": "a1", "name": "One", "model": "q"],
                ["id": "a2", "name": "Two"],
            ],
        ]
        let parsed = try await bridge.fetchAgents()
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].id, "a1")
        XCTAssertEqual(parsed[1].id, "a2")
        XCTAssertEqual(mock.recordedCalls.first?.method, RPCMethod.agentList)
        XCTAssertEqual(bridge.agentState.agents.count, 2)
        XCTAssertEqual(bridge.agentState.agents.first?.id, "a1")
    }

    // manifest-nested 三级兜底: 顶层无 model/temperature, manifest 嵌套有 → 取 manifest 值。
    func testFetchAgentsManifestNested() async throws {
        mock.responsesByMethod[RPCMethod.agentList] = [
            "agents": [
                ["id": "m1", "name": "M", "manifest": ["model": "qwen2", "temperature": 0.5]],
            ],
        ]
        let parsed = try await bridge.fetchAgents()
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].model, "qwen2")
        XCTAssertEqual(parsed[0].temperature, 0.5)
    }

    // agentCreate: call method + params 含 name, 返 AgentModel.id 非空, currentAgent 设上。
    func testAgentCreateParsesAndAppends() async throws {
        mock.responsesByMethod[RPCMethod.agentCreate] = [
            "agent_id": "c1", "name": "Created", "model": "q",
        ]
        let agent = try await bridge.agentCreate(name: "Created", model: "q")
        XCTAssertEqual(agent.id, "c1")
        XCTAssertEqual(mock.lastCall(method: RPCMethod.agentCreate)?.params["name"] as? String, "Created")
        XCTAssertEqual(bridge.agentState.currentAgent?.id, "c1")
        XCTAssertTrue(bridge.agentState.agents.contains { $0.id == "c1" })
    }

    // agentGet: dual-key agent_id。
    func testAgentGetParsesDualKey() async throws {
        mock.responsesByMethod[RPCMethod.agentGet] = [
            "agent_id": "g1", "name": "G",
        ]
        let agent = try await bridge.agentGet(agentId: "g1")
        XCTAssertEqual(agent.id, "g1")
    }

    // F-I4 宽容: 无 id → parseAgentModel 返 nil (id 空 guard) → fetchAgents compactMap 丢弃 → 返 [ok], 不 throw。
    func testFetchAgentsMalformedEntryDropped() async throws {
        mock.responsesByMethod[RPCMethod.agentList] = [
            "agents": [
                ["name": "no id"],
                ["id": "ok", "name": "OK"],
            ],
        ]
        let parsed = try await bridge.fetchAgents()
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].id, "ok")
    }

    // MARK: - Group 2 — Graph (AgentGraphService, parseGraphModel via F-I4)

    // fetchGraphs: array 形态 nodes + 修复的 result["graphs"] key (F-A1 regression)。
    func testFetchGraphsParsesArrayForm() async throws {
        mock.responsesByMethod[RPCMethod.graphList] = [
            "graphs": [
                ["id": "g1", "name": "G1", "nodes": [["id": "n1", "type": "llm", "label": "N1"]], "edges": []],
            ],
        ]
        let parsed = try await bridge.fetchGraphs()
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].id, "g1")
        XCTAssertEqual(parsed[0].nodes.count, 1)
        XCTAssertEqual(parsed[0].nodes[0].id, "n1")
        XCTAssertEqual(parsed[0].nodeCount, 1)
        XCTAssertEqual(bridge.agentState.graphs.count, 1)
    }

    // fetchGraphs: nodes dict 形态 {nodeId: {type:..}} — id 是 dict key, 其余进 config。
    func testFetchGraphsParsesDictFormNodes() async throws {
        mock.responsesByMethod[RPCMethod.graphList] = [
            "graphs": [
                ["id": "g2", "name": "G2", "nodes": ["n1": ["type": "llm"]], "edges": []],
            ],
        ]
        let parsed = try await bridge.fetchGraphs()
        XCTAssertEqual(parsed[0].nodes.count, 1)
        XCTAssertEqual(parsed[0].nodes[0].id, "n1")
        XCTAssertEqual(parsed[0].nodes[0].type, "llm")
    }

    // fetchGraphs: dual-key graph_id。
    func testFetchGraphsDualKeyId() async throws {
        mock.responsesByMethod[RPCMethod.graphList] = [
            "graphs": [
                ["graph_id": "g3", "name": "G3"],
            ],
        ]
        let parsed = try await bridge.fetchGraphs()
        XCTAssertEqual(parsed[0].id, "g3")
    }

    // createGraph: call method + params 含 name/nodes/edges, 返 AgentGraphModel。
    func testCreateGraphSendsParamsAndParses() async throws {
        mock.responsesByMethod[RPCMethod.graphCreate] = [
            "id": "cg1", "name": "Created", "nodes": [], "edges": [],
        ]
        let graph = try await bridge.createGraph(name: "Created", nodes: [], edges: [])
        XCTAssertEqual(graph.id, "cg1")
        let call = mock.lastCall(method: RPCMethod.graphCreate)
        XCTAssertEqual(call?.params["name"] as? String, "Created")
        XCTAssertNotNil(call?.params["nodes"])
        XCTAssertNotNil(call?.params["edges"])
    }

    // graphGet: daemon 顶层即 graph 数据, graphGet 已做 (result["graph"] ?? result) 兜底。
    func testGraphGetUnwrapsGraphKey() async throws {
        mock.responsesByMethod[RPCMethod.graphGet] = [
            "graph": ["id": "gg1", "name": "G"],
        ]
        let graph = try await bridge.graphGet(graphId: "gg1")
        XCTAssertNotNil(graph)
        XCTAssertEqual(graph?.id, "gg1")
    }

    // MARK: - Group 3 — Planner (AgentPlannerService, parsePlanModel/PlanStepModel via F-I4)

    // plannerCreatePlan: dual-key plan_id, .task, recordedCalls.method。
    func testPlannerCreatePlanParsesDualKey() async throws {
        mock.responsesByMethod[RPCMethod.plannerCreatePlan] = [
            "plan_id": "p1", "task": "do X", "status": "draft", "steps": [],
        ]
        let plan = try await bridge.plannerCreatePlan(task: "do X")
        XCTAssertEqual(plan.id, "p1")
        XCTAssertEqual(plan.task, "do X")
        XCTAssertEqual(mock.lastCall(method: RPCMethod.plannerCreatePlan)?.params["task"] as? String, "do X")
        XCTAssertEqual(bridge.moduleState.currentPlan?.id, "p1")
    }

    // PlanStepModel: dual-key step_id/id within steps。
    func testParsePlanStepDualKey() async throws {
        mock.responsesByMethod[RPCMethod.plannerCreatePlan] = [
            "id": "p2", "task": "t", "steps": [
                ["step_id": "s1", "description": "step", "status": "pending"],
                ["id": "s2", "description": "two"],
            ],
        ]
        let plan = try await bridge.plannerCreatePlan(task: "t")
        XCTAssertEqual(plan.steps.count, 2)
        XCTAssertEqual(plan.steps[0].id, "s1")
        XCTAssertEqual(plan.steps[1].id, "s2")
    }

    // fetchPlans: list 解析 + @Published plans 更新 (修复的 result["plans"] 未泄漏, 但同范式验)。
    func testFetchPlansParsesList() async throws {
        mock.responsesByMethod[RPCMethod.plannerListPlans] = [
            "plans": [
                ["id": "p1", "task": "a"],
                ["plan_id": "p2", "task": "b"],
            ],
        ]
        let parsed = try await bridge.fetchPlans()
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].id, "p1")
        XCTAssertEqual(parsed[1].id, "p2")
        XCTAssertEqual(bridge.moduleState.plans.count, 2)
    }

    // MARK: - Group 4 — Task (AgentBridge.taskSubmit)

    // taskSubmit: call method + params 含 title/agent_id/graph_id/trigger/priority, 返 TaskModel.id 非空。
    func testTaskSubmitSendsParamsAndParses() async throws {
        mock.responsesByMethod[RPCMethod.taskSubmit] = [
            "task": [
                "task_id": "t1", "title": "T", "status": "pending",
                "trigger": "immediate", "priority": 1,
            ],
        ]
        let task = try await bridge.taskSubmit(
            title: "T", description: "d", agentId: "a1", graphId: "g1",
            trigger: .immediate, cronExpression: "", runAt: nil, input: "in"
        )
        XCTAssertEqual(task.id, "t1")
        let call = mock.lastCall(method: RPCMethod.taskSubmit)
        XCTAssertEqual(call?.params["title"] as? String, "T")
        XCTAssertEqual(call?.params["agent_id"] as? String, "a1")
        XCTAssertEqual(call?.params["graph_id"] as? String, "g1")
        XCTAssertEqual(call?.params["trigger"] as? String, "immediate")
        XCTAssertEqual(call?.params["priority"] as? Int, 1)
    }

    // taskSubmit priority mapping: low=0/medium=1/high=2/critical=3。
    func testTaskSubmitPriorityMapping() async throws {
        mock.responsesByMethod[RPCMethod.taskSubmit] = [
            "task": ["task_id": "t2", "title": "T", "trigger": "immediate"],
        ]
        _ = try await bridge.taskSubmit(
            title: "T", description: "", agentId: "a", graphId: "g",
            trigger: .immediate, cronExpression: "", runAt: nil, input: "", priority: .high
        )
        let call = mock.lastCall(method: RPCMethod.taskSubmit)
        XCTAssertEqual(call?.params["priority"] as? Int, 2)
    }

    // MARK: - Group 5 — Error paths

    // 无 ipcClient → BridgeError.notConnected。setIPCClient 非 optional, 用本地 fresh bridge 不注入。
    func testNoIPCClientThrowsNotConnected() async throws {
        let bare = AgentBridge()
        do {
            _ = try await bare.fetchAgents()
            XCTFail("expected BridgeError.notConnected")
        } catch let err as BridgeError {
            XCTAssertEqual(err, .notConnected)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // IPCError.rpcError 传播: fetchAgents catch IPCError → BridgeError.ipcError。
    func testRPCErrorPropagates() async throws {
        mock.errorsByMethod[RPCMethod.agentList] = IPCError.rpcError(code: -1, message: "boom")
        do {
            _ = try await bridge.fetchAgents()
            XCTFail("expected BridgeError.ipcError")
        } catch let err as BridgeError {
            if case .ipcError = err {
            } else {
                XCTFail("expected .ipcError, got \(err)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // agentGet 单路径: 响应缺 id → parseAgentModel 返 nil → throw BridgeError.decodeError。
    // (list 路径 compactMap 丢弃不 throw; 单路径 guard nil throw。)
    func testMalformedResponseDecodeError() async throws {
        mock.responsesByMethod[RPCMethod.agentGet] = [
            "name": "no id here",
        ]
        do {
            _ = try await bridge.agentGet(agentId: "x")
            XCTFail("expected BridgeError.decodeError")
        } catch let err as BridgeError {
            if case .decodeError = err {
            } else {
                XCTFail("expected .decodeError, got \(err)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Group 6 — F-I4 parser edge (直调 decodeCodable, 锁宽容行为)

    // decodeCodable internal static → @testable 可直调, 验 F-I4 custom init(from:) 宽容行为本身 (不经 IPC)。

    // dual-key agent_id/id 两种形态均解出正确 .id。
    func testDecodeAgentDualKeyBothForms() {
        let d1: [String: Any] = ["agent_id": "x1", "name": "A"]
        let d2: [String: Any] = ["id": "x2", "name": "B"]
        let a1 = AgentBridge.decodeCodable(AgentModel.self, from: d1, context: "agent")
        let a2 = AgentBridge.decodeCodable(AgentModel.self, from: d2, context: "agent")
        XCTAssertEqual(a1?.id, "x1")
        XCTAssertEqual(a2?.id, "x2")
    }

    // graph created_at Double(timestamp) → AgentGraphModel custom init 处理, 解成功。
    func testDecodeGraphCreatedAtDouble() {
        let d: [String: Any] = ["id": "g", "name": "G", "created_at": 1700000000.0]
        let g = AgentBridge.decodeCodable(AgentGraphModel.self, from: d, context: "graph")
        XCTAssertNotNil(g)
        XCTAssertFalse(g?.created_at.isEmpty ?? true)
    }

    // 最小 event {type:"node_start"} → 解成功, node_id/data/timestamp 为 nil (optional 宽容)。
    func testDecodeEventMinimal() {
        let d: [String: Any] = ["type": "node_start"]
        let ev = AgentBridge.decodeCodable(AgentEventModel.self, from: d, context: "event")
        XCTAssertEqual(ev?.type, "node_start")
        XCTAssertNil(ev?.node_id)
        XCTAssertNil(ev?.data)
        XCTAssertNil(ev?.timestamp)
    }

    // PlanStepModel 无 id → custom init 兜底 UUID().uuidString, .id 非空。
    func testDecodePlanStepMissingIdGetsUUID() {
        let d: [String: Any] = ["description": "x", "status": "pending"]
        let step = AgentBridge.decodeCodable(PlanStepModel.self, from: d, context: "planstep")
        XCTAssertNotNil(step)
        XCTAssertFalse(step?.id.isEmpty ?? true)
        XCTAssertEqual(step?.description, "x")
        XCTAssertEqual(step?.status, "pending")
    }
}
