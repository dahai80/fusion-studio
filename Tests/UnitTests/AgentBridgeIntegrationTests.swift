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

    // MARK: - Group 6b — F-I4 batch 迁移模型宽容 (decodeCodable 直调, 锁 custom init(from:) leniency)

    // SafetyCheckModel: 缺键全 ?? default, approved 缺 → false (旧 fromDict true, 新 init 一致性 false — 测记录新行为)。
    func testDecodeSafetyCheckMissingKeysDefaults() {
        let d: [String: Any] = ["level": "L2"]
        let check = AgentBridge.decodeCodable(SafetyCheckModel.self, from: d, context: "safetyCheck")
        XCTAssertEqual(check?.level, "L2")
        XCTAssertEqual(check?.violations, [])
        XCTAssertEqual(check?.approved, false)
    }

    // SafetyActionModel dual-key action_id/id, 缺 → UUID 兜底。
    func testDecodeSafetyActionDualKey() {
        let d1: [String: Any] = ["action_id": "ac1", "status": "approved"]
        let d2: [String: Any] = ["id": "ac2", "category": "fs_write"]
        let a1 = AgentBridge.decodeCodable(SafetyActionModel.self, from: d1, context: "safetyAction")
        let a2 = AgentBridge.decodeCodable(SafetyActionModel.self, from: d2, context: "safetyAction")
        XCTAssertEqual(a1?.id, "ac1")
        XCTAssertEqual(a1?.status, "approved")
        XCTAssertEqual(a2?.id, "ac2")
        XCTAssertEqual(a2?.category, "fs_write")
    }

    // DeployFormatModel 派生 id=format (无显式 id 键)。
    func testDecodeDeployFormatDerivedId() {
        let d: [String: Any] = ["format": "json", "description": "JSON export"]
        let f = AgentBridge.decodeCodable(DeployFormatModel.self, from: d, context: "deployFormat")
        XCTAssertEqual(f?.format, "json")
        XCTAssertEqual(f?.id, "json")
        XCTAssertEqual(f?.description, "JSON export")
    }

    // RAGResultModel: answer/sources 解码, query 解码后调用方覆盖 (本测试验解码默认)。
    func testDecodeRAGResultAnswerSources() {
        let d: [String: Any] = ["answer": "A", "sources": ["s1", "s2"]]
        let r = AgentBridge.decodeCodable(RAGResultModel.self, from: d, context: "ragQuery")
        XCTAssertEqual(r?.answer, "A")
        XCTAssertEqual(r?.sources, ["s1", "s2"])
        XCTAssertEqual(r?.query, "")
        XCTAssertFalse(r?.id.isEmpty ?? true)
    }

    // TemplateModel dual-key template_id/id。
    func testDecodeTemplateDualKey() {
        let d1: [String: Any] = ["template_id": "t1", "name": "T1", "variables": ["a", "b"]]
        let d2: [String: Any] = ["id": "t2", "name": "T2"]
        let t1 = AgentBridge.decodeCodable(TemplateModel.self, from: d1, context: "template")
        let t2 = AgentBridge.decodeCodable(TemplateModel.self, from: d2, context: "template")
        XCTAssertEqual(t1?.id, "t1")
        XCTAssertEqual(t1?.variables, ["a", "b"])
        XCTAssertEqual(t2?.id, "t2")
        XCTAssertEqual(t2?.variables, [])
    }

    // MLXModelInfo 派生 name=id (无显式 name 键)。
    func testDecodeMLXModelInfoDerivedName() {
        let d: [String: Any] = ["id": "qwen3.5-9b", "object": "model", "owned_by": "local"]
        let m = AgentBridge.decodeCodable(MLXModelInfo.self, from: d, context: "mlxModel")
        XCTAssertEqual(m?.id, "qwen3.5-9b")
        XCTAssertEqual(m?.name, "qwen3.5-9b")
        XCTAssertEqual(m?.object, "model")
        XCTAssertEqual(m?.owned_by, "local")
    }

    // MarketplaceEntryModel dual-key entry_id/id + guard id/name 缺一 → nil (匹配旧 guard)。
    func testDecodeMarketplaceEntryDualKeyAndGuard() {
        let d1: [String: Any] = ["entry_id": "e1", "name": "Entry", "version": "2.0.0", "rating": 4.5, "downloads": 100]
        let d2: [String: Any] = ["id": "e2", "name": "Two"]
        let d3: [String: Any] = ["entry_id": "e3"]
        let e1 = AgentBridge.decodeCodable(MarketplaceEntryModel.self, from: d1, context: "marketplace")
        let e2 = AgentBridge.decodeCodable(MarketplaceEntryModel.self, from: d2, context: "marketplace")
        let e3 = AgentBridge.decodeCodable(MarketplaceEntryModel.self, from: d3, context: "marketplace")
        XCTAssertEqual(e1?.id, "e1")
        XCTAssertEqual(e1?.version, "2.0.0")
        XCTAssertEqual(e1?.rating, 4.5)
        XCTAssertEqual(e1?.downloads, 100)
        XCTAssertEqual(e2?.id, "e2")
        XCTAssertNil(e3)
    }

    // MemoryEntryModel dual-key entry_id/id + guard id/content 缺一 → nil。
    func testDecodeMemoryEntryDualKeyAndGuard() {
        let d1: [String: Any] = ["entry_id": "m1", "content": "hello", "scope": "work", "importance": 8, "tier": "long_term"]
        let d2: [String: Any] = ["id": "m2", "content": "world"]
        let d3: [String: Any] = ["entry_id": "m3", "scope": "x"]
        let e1 = AgentBridge.decodeCodable(MemoryEntryModel.self, from: d1, context: "memory")
        let e2 = AgentBridge.decodeCodable(MemoryEntryModel.self, from: d2, context: "memory")
        let e3 = AgentBridge.decodeCodable(MemoryEntryModel.self, from: d3, context: "memory")
        XCTAssertEqual(e1?.id, "m1")
        XCTAssertEqual(e1?.content, "hello")
        XCTAssertEqual(e1?.importance, 8)
        XCTAssertEqual(e1?.tier, "long_term")
        XCTAssertEqual(e2?.id, "m2")
        XCTAssertNil(e3)
    }

    // FCSessionDetail: flat top-level config 字段 + working_dir/cwd dual-key + state 枚举兜底 + 缺 Date → now(非零)。
    func testDecodeFCSessionDetailFlatConfigDualKeyAndEnum() {
        let d: [String: Any] = [
            "id": "sess1", "name": "My", "state": "running",
            "working_dir": "/tmp/proj", "model": "qwen3", "temperature": 0.3,
            "max_tokens": 8192, "security_mode": "auto", "allowed_dirs": ["/a", "/b"],
            "message_count": 42, "cluster_node": "node1"
        ]
        let s = AgentBridge.decodeCodable(FCSessionDetail.self, from: d, context: "fcSessionDetail")
        XCTAssertEqual(s?.id, "sess1")
        XCTAssertEqual(s?.name, "My")
        XCTAssertEqual(s?.state, .running)
        XCTAssertEqual(s?.config.workingDir, "/tmp/proj")
        XCTAssertEqual(s?.config.model, "qwen3")
        XCTAssertEqual(s?.config.temperature, 0.3)
        XCTAssertEqual(s?.config.maxTokens, 8192)
        XCTAssertEqual(s?.config.allowedDirs, ["/a", "/b"])
        XCTAssertEqual(s?.messageCount, 42)
        XCTAssertEqual(s?.clusterNode, "node1")
    }

    // FCSessionDetail cwd 替代 working_dir + 未知 state → .idle 兜底 + id 缺 → nil。
    func testDecodeFCSessionDetailCwdFallbackAndUnknownState() {
        let d1: [String: Any] = ["id": "s2", "cwd": "/home", "state": "weird_state"]
        let d2: [String: Any] = ["name": "noId"]
        let s1 = AgentBridge.decodeCodable(FCSessionDetail.self, from: d1, context: "fcSessionDetail")
        let s2 = AgentBridge.decodeCodable(FCSessionDetail.self, from: d2, context: "fcSessionDetail")
        XCTAssertEqual(s1?.config.workingDir, "/home")
        XCTAssertEqual(s1?.state, .idle)
        XCTAssertNil(s2)
    }
}
