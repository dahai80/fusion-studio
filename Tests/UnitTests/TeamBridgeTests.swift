import XCTest
@testable import FusionStudio

// M2-7: TeamBridge snapshot→model mapping + write RPC contract tests.
// Uses MockIPCClient (F-I5) to verify TeamBridge calls correct RPC methods
// with correct params + maps response dicts to domain models correctly.
@MainActor
final class TeamBridgeTests: XCTestCase {

    private var mock: MockIPCClient!
    private var bridge: TeamBridge!

    override func setUp() {
        super.setUp()
        mock = MockIPCClient()
        bridge = TeamBridge()
        // setIPCClient triggers refreshAll + connectStream — stub daemon.status to avoid error
        mock.responsesByMethod[RPCMethod.daemonStatus] = [
            "ws_port": 0,
            "ws_enabled": false,
            "ws_token": "",
        ]
        // stub snapshot RPCs with empty results so refreshAll doesn't error
        mock.responsesByMethod[RPCMethod.taskList] = ["tasks": []]
        mock.responsesByMethod[RPCMethod.teamSwarmAgents] = ["agents": []]
        mock.responsesByMethod[RPCMethod.budgetStatus] = [:]
        mock.responsesByMethod[RPCMethod.teamHealth] = [:]
    }

    override func tearDown() {
        bridge.stop()
        mock = nil
        bridge = nil
        super.tearDown()
    }

    // MARK: - refreshTasks mapping (#314 server-side team filter)

    func test_refreshTasks_callsTaskListWithTeamParam() async {
        let taskDict: [String: Any] = [
            "task_id": "t-1", "title": "Do thing", "status": "running",
            "review_state": "none", "owner_agent": "agent-A", "priority": 5,
            "team": "ops", "graph_id": "g-1",
        ]
        mock.responsesByMethod[RPCMethod.taskList] = ["tasks": [taskDict]]
        bridge.selectedTeam = "ops"
        bridge.setIPCClient(mock)
        // setIPCClient already calls refreshAll; give it a tick
        try? await Task.sleep(nanoseconds: 100_000_000)
        await bridge.refreshTasks()

        let call = mock.lastCall(method: RPCMethod.taskList)
        XCTAssertNotNil(call, "task.list called")
        XCTAssertEqual(call?.params["team"] as? String, "ops", "team param passed to server-side filter")
        XCTAssertEqual(bridge.tasks.count, 1)
        XCTAssertEqual(bridge.tasks.first?.id, "t-1")
        XCTAssertEqual(bridge.tasks.first?.status, "running")
    }

    func test_refreshTasks_mapsMultipleTasks() async {
        mock.responsesByMethod[RPCMethod.taskList] = [
            "tasks": [
                ["task_id": "t-1", "status": "pending", "team": "ops"],
                ["task_id": "t-2", "status": "running", "team": "ops"],
                ["task_id": "t-3", "status": "completed", "review_state": "approved", "team": "ops"],
            ],
        ]
        bridge.setIPCClient(mock)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await bridge.refreshTasks()
        XCTAssertEqual(bridge.tasks.count, 3)
        XCTAssertEqual(bridge.tasks[0].id, "t-1")
        XCTAssertEqual(bridge.tasks[2].reviewState, "approved")
    }

    // MARK: - refreshMembers mapping

    func test_refreshMembers_mapsAgents() async {
        mock.responsesByMethod[RPCMethod.teamSwarmAgents] = [
            "agents": [
                ["agent_id": "a-1", "name": "Coder", "capabilities": ["code", "review"]],
                ["agent_id": "a-2", "name": "Tester", "skills": ["test"]],
            ],
        ]
        bridge.setIPCClient(mock)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await bridge.refreshMembers()
        XCTAssertEqual(bridge.members.count, 2)
        XCTAssertEqual(bridge.members[0].name, "Coder")
        XCTAssertEqual(bridge.members[0].capabilities, ["code", "review"])
        XCTAssertEqual(bridge.members[1].capabilities, ["test"], "skills key fallback")
    }

    // MARK: - setReviewState write RPC (#317)

    func test_setReviewState_callsCorrectRPC() async throws {
        mock.responsesByMethod[RPCMethod.taskSetReviewState] = [
            "task_id": "t-1", "review_state": "approved", "updated_at": 1700000000.0,
        ]
        mock.responsesByMethod[RPCMethod.taskList] = ["tasks": []]
        bridge.setIPCClient(mock)
        try? await Task.sleep(nanoseconds: 100_000_000)

        let ok = try await bridge.setReviewState(taskId: "t-1", reviewState: "approved")
        XCTAssertTrue(ok, "setReviewState returns true on success")

        let call = mock.lastCall(method: RPCMethod.taskSetReviewState)
        XCTAssertEqual(call?.params["task_id"] as? String, "t-1")
        XCTAssertEqual(call?.params["review_state"] as? String, "approved")
    }

    func test_setReviewState_errorReturnsFalse() async throws {
        mock.responsesByMethod[RPCMethod.taskSetReviewState] = [
            "status": "error", "message": "Task not found",
        ]
        mock.responsesByMethod[RPCMethod.taskList] = ["tasks": []]
        bridge.setIPCClient(mock)
        try? await Task.sleep(nanoseconds: 100_000_000)

        let ok = try await bridge.setReviewState(taskId: "ghost", reviewState: "approved")
        XCTAssertFalse(ok, "error status → false")
    }

    // MARK: - evidence RPCs (#316)

    func test_refreshEvidence_callsEvidenceList() async {
        mock.responsesByMethod[RPCMethod.evidenceList] = [
            "evidence": [
                ["task_id": "t-1", "team": "ops", "evidence_ref": "/out/ops/ev.jsonl",
                 "status": "completed", "execution_id": "exec-1", "events_count": 10],
            ],
        ]
        bridge.selectedTeam = "ops"
        bridge.setIPCClient(mock)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await bridge.refreshEvidence()

        let call = mock.lastCall(method: RPCMethod.evidenceList)
        XCTAssertEqual(call?.params["team"] as? String, "ops")
        XCTAssertEqual(bridge.evidence.count, 1)
        XCTAssertEqual(bridge.evidence.first?.evidenceRef, "/out/ops/ev.jsonl")
    }

    func test_refreshFailedEvidence_callsEvidenceFailure() async {
        mock.responsesByMethod[RPCMethod.evidenceFailure] = [
            "evidence": [
                ["task_id": "t-2", "status": "failed", "evidence_ref": "/out/ops/ev2.jsonl"],
            ],
        ]
        bridge.setIPCClient(mock)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await bridge.refreshFailedEvidence()

        let call = mock.lastCall(method: RPCMethod.evidenceFailure)
        XCTAssertNotNil(call, "evidence.failure RPC called")
        XCTAssertEqual(bridge.evidence.count, 1)
        XCTAssertTrue(bridge.evidence.first?.isFailed ?? false)
    }

    // MARK: - team.health per-team (#318)

    func test_refreshTeamHealth_callsTeamHealthWithTeam() async {
        mock.responsesByMethod[RPCMethod.teamHealth] = [
            "team": "ops", "pending": 3, "running": 2, "total": 10, "max_concurrency": 4,
        ]
        bridge.selectedTeam = "ops"
        bridge.setIPCClient(mock)
        try? await Task.sleep(nanoseconds: 100_000_000)
        await bridge.refreshTeamHealth()

        let call = mock.lastCall(method: RPCMethod.teamHealth)
        XCTAssertEqual(call?.params["team"] as? String, "ops", "team param passed")
        XCTAssertEqual(bridge.teamHealth?.pendingTasks, 3)
        XCTAssertEqual(bridge.teamHealth?.runningTasks, 2)
        XCTAssertEqual(bridge.teamHealth?.totalTasks, 10)
    }

    // MARK: - connectStream WS discovery (#315)

    func test_connectStream_readsWsEnabledFromDaemonStatus() async {
        // ws_port=0 avoids creating real URLSessionWebSocketTask in CI (SIGSEGV on URLSession cleanup).
        // wsEnabled flag is still set from ws_enabled field — this test verifies parsing, not WS connection.
        mock.responsesByMethod[RPCMethod.daemonStatus] = [
            "ws_port": 0,
            "ws_enabled": true,
            "ws_token": "test-token-abc",
        ]
        bridge.setIPCClient(mock)
        try? await Task.sleep(nanoseconds: 200_000_000)
        await bridge.connectStream()
        XCTAssertTrue(bridge.wsEnabled, "ws_enabled=true from daemon.status")
    }

    func test_connectStream_wsDisabledStartsPolling() async {
        mock.responsesByMethod[RPCMethod.daemonStatus] = [
            "ws_port": 0,
            "ws_enabled": false,
            "ws_token": "",
        ]
        bridge.setIPCClient(mock)
        try? await Task.sleep(nanoseconds: 200_000_000)
        await bridge.connectStream()
        XCTAssertFalse(bridge.wsEnabled, "ws_enabled=false")
    }

    // MARK: - break_in (#317 existing)

    func test_sendBreakIn_callsCorrectRPC() async throws {
        mock.responsesByMethod[RPCMethod.teamPlazaBreakIn] = ["status": "sent"]
        bridge.selectedTeam = "ops"
        bridge.setIPCClient(mock)
        try? await Task.sleep(nanoseconds: 100_000_000)

        let res = try await bridge.sendBreakIn(message: "stop now")
        let call = mock.lastCall(method: RPCMethod.teamPlazaBreakIn)
        XCTAssertEqual(call?.params["team"] as? String, "ops")
        XCTAssertEqual(call?.params["message"] as? String, "stop now")
        XCTAssertEqual(res["status"] as? String, "sent")
    }
}
