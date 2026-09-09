import XCTest
@testable import FusionStudio

// M2-2/M2-7: TeamWorkspace contract tests. deriveColumn() mirrors daemon
// task_board.py:derive_column exactly — single rule, two implementations.
// These tests prove equivalence: same inputs → same column on both sides.
// Python source: agent_runtime/task_board.py:derive_column (M1-1, PR #307).
@MainActor
final class TeamWorkspaceTests: XCTestCase {

    // MARK: - deriveColumn contract (mirrors task_board.py:derive_column)

    func test_deriveColumn_canceled_archived() {
        let task = makeTask(status: "canceled", reviewState: "none", owner: "agent-A")
        XCTAssertEqual(task.deriveColumn(), .archived, "canceled → archived regardless of owner/review")
    }

    func test_deriveColumn_canceled_archived_evenIfApproved() {
        let task = makeTask(status: "canceled", reviewState: "approved", owner: "agent-A")
        XCTAssertEqual(task.deriveColumn(), .archived, "canceled → archived even if approved")
    }

    func test_deriveColumn_pending_noOwner_todo() {
        let task = makeTask(status: "pending", reviewState: "none", owner: "")
        XCTAssertEqual(task.deriveColumn(), .todo, "pending + no owner → todo")
    }

    func test_deriveColumn_pending_withOwner_todo() {
        // pending + has owner = already claimed but not started → fallback todo
        let task = makeTask(status: "pending", reviewState: "none", owner: "agent-A")
        XCTAssertEqual(task.deriveColumn(), .todo, "pending + owner → todo (fallback)")
    }

    func test_deriveColumn_running_inProgress() {
        let task = makeTask(status: "running", reviewState: "none", owner: "agent-A")
        XCTAssertEqual(task.deriveColumn(), .inProgress, "running → in_progress")
    }

    func test_deriveColumn_completed_review_review() {
        let task = makeTask(status: "completed", reviewState: "review", owner: "agent-A")
        XCTAssertEqual(task.deriveColumn(), .review, "completed + review → review")
    }

    func test_deriveColumn_completed_needsFix_review() {
        let task = makeTask(status: "completed", reviewState: "needs_fix", owner: "agent-A")
        XCTAssertEqual(task.deriveColumn(), .review, "completed + needs_fix → review")
    }

    func test_deriveColumn_completed_approved_approved() {
        let task = makeTask(status: "completed", reviewState: "approved", owner: "agent-A")
        XCTAssertEqual(task.deriveColumn(), .approved, "completed + approved → approved")
    }

    func test_deriveColumn_completed_none_fallbackTodo() {
        let task = makeTask(status: "completed", reviewState: "none", owner: "agent-A")
        XCTAssertEqual(task.deriveColumn(), .todo, "completed + none → todo (fallback)")
    }

    func test_deriveColumn_failed_fallbackTodo() {
        let task = makeTask(status: "failed", reviewState: "none", owner: "agent-A")
        XCTAssertEqual(task.deriveColumn(), .todo, "failed → todo (fallback — no failed column)")
    }

    func test_deriveColumn_emptyStatus_fallbackTodo() {
        let task = makeTask(status: "", reviewState: "none", owner: "")
        XCTAssertEqual(task.deriveColumn(), .todo, "empty status → todo (fallback)")
    }

    // MARK: - TeamTask dict mapping

    func test_teamTask_dictMapping_fullFields() {
        let dict: [String: Any] = [
            "task_id": "task-001",
            "title": "Build feature",
            "status": "running",
            "review_state": "none",
            "owner_agent": "agent-A",
            "priority": 7,
            "team": "ops",
            "graph_id": "g-1",
            "evidence_ref": "/out/ops/evidence/executions/task-001_ev.jsonl",
            "resource_lease_id": "lease-9",
            "created_at": 1700000000.0,
            "updated_at": 1700000100.0,
        ]
        guard let task = TeamTask(dict: dict) else {
            XCTFail("TeamTask init from dict failed"); return
        }
        XCTAssertEqual(task.id, "task-001")
        XCTAssertEqual(task.title, "Build feature")
        XCTAssertEqual(task.status, "running")
        XCTAssertEqual(task.ownerAgent, "agent-A")
        XCTAssertEqual(task.priority, 7)
        XCTAssertEqual(task.team, "ops")
        XCTAssertTrue(task.hasEvidence)
        XCTAssertTrue(task.hasLease)
    }

    func test_teamTask_dictMapping_minimalFields() {
        let dict: [String: Any] = ["task_id": "task-002"]
        guard let task = TeamTask(dict: dict) else {
            XCTFail("TeamTask init from minimal dict failed"); return
        }
        XCTAssertEqual(task.id, "task-002")
        XCTAssertEqual(task.status, "pending")
        XCTAssertEqual(task.reviewState, "none")
        XCTAssertEqual(task.ownerAgent, "")
        XCTAssertEqual(task.priority, 1)
        XCTAssertEqual(task.team, "default")
        XCTAssertFalse(task.hasEvidence)
    }

    func test_teamTask_dictMapping_missingIdReturnsNil() {
        let dict: [String: Any] = ["title": "no id"]
        XCTAssertNil(TeamTask(dict: dict), "dict without task_id/id → nil")
    }

    // MARK: - TeamEvent Codable

    func test_teamEvent_decode_taskCreated() throws {
        let json = """
        {"event_id": 42, "type": "task.created", "ts": 1700000000.5, "team": "ops", "task_id": "task-001"}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(TeamEvent.self, from: json)
        XCTAssertEqual(event.id, 42)
        XCTAssertEqual(event.type, TeamEvent.taskCreated)
        XCTAssertEqual(event.team, "ops")
        XCTAssertEqual(event.taskId, "task-001")
        XCTAssertTrue(event.triggersTaskRefresh)
    }

    func test_teamEvent_decode_executionCompleted() throws {
        let json = """
        {"event_id": 43, "type": "execution.completed", "ts": 1700000001.0, "team": "ops", "execution_id": "exec-1", "events_count": 5}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(TeamEvent.self, from: json)
        XCTAssertEqual(event.id, 43)
        XCTAssertEqual(event.type, TeamEvent.executionCompleted)
        XCTAssertEqual(event.executionId, "exec-1")
        XCTAssertEqual(event.eventsCount, 5)
        XCTAssertTrue(event.triggersTaskRefresh)
    }

    func test_teamEvent_decode_executionProgress_noRefresh() throws {
        let json = """
        {"event_id": 44, "type": "execution.progress", "ts": 1700000002.0, "team": "ops"}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(TeamEvent.self, from: json)
        XCTAssertEqual(event.type, TeamEvent.executionProgress)
        XCTAssertFalse(event.triggersTaskRefresh, "progress events do not trigger full task refresh")
    }

    // subscribed ack ({"type":"subscribed",...}) is a control frame, NOT a TeamEvent —
    // TeamEventStream.handleMessage handles it before Codable decode (no event_id field).
    // Verified at integration level, not via Codable.

    func test_teamEvent_decode_unknownFieldsIgnored() throws {
        let json = """
        {"event_id": 50, "type": "task.created", "ts": 1.0, "team": "x", "unknown_field": "ignored", "extra": 999}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(TeamEvent.self, from: json)
        XCTAssertEqual(event.id, 50)
    }

    // MARK: - KanbanColumn

    func test_kanbanColumn_allCasesCount() {
        XCTAssertEqual(KanbanColumn.allCases.count, 5, "todo/in_progress/review/approved/archived")
    }

    func test_kanbanColumn_rawValues() {
        XCTAssertEqual(KanbanColumn.todo.rawValue, "todo")
        XCTAssertEqual(KanbanColumn.inProgress.rawValue, "in_progress")
        XCTAssertEqual(KanbanColumn.review.rawValue, "review")
        XCTAssertEqual(KanbanColumn.approved.rawValue, "approved")
        XCTAssertEqual(KanbanColumn.archived.rawValue, "archived")
    }

    // MARK: - Helpers

    private func makeTask(status: String, reviewState: String, owner: String) -> TeamTask {
        TeamTask(
            id: "test-task",
            title: "test",
            status: status,
            reviewState: reviewState,
            ownerAgent: owner,
            priority: 1,
            team: "ops",
            graphId: "g-test",
            evidenceRef: "",
            resourceLeaseId: "",
            createdAt: 0,
            updatedAt: 0
        )
    }
}
