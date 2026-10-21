import XCTest
@testable import FusionStudio

// #417/#418: thinking channel SSE frames, permission cards, mobile overview.

final class AgentStreamFrameParsingTests: XCTestCase {

    func testAnswerTokenFrame() {
        let event = AgentSSEClient.parse(["type": "token", "content": "hello"])
        XCTAssertEqual(event.kind, .token)
        XCTAssertEqual(event.content, "hello")
        XCTAssertTrue(event.isAnswerToken)
    }

    func testThinkingTokenFrameStaysSeparate() {
        let event = AgentSSEClient.parse(["type": "thinking_token", "content": "reason"])
        XCTAssertEqual(event.kind, .thinkingToken)
        XCTAssertEqual(event.content, "reason")
        XCTAssertTrue(event.isThinkingToken)
        XCTAssertFalse(event.isAnswerToken)
    }

    func testDeltaAndReasoningMetadataFallback() {
        let delta = AgentSSEClient.parse(["type": "result", "delta": "answer"])
        XCTAssertEqual(delta.content, "answer")
        let metadata = AgentSSEClient.parse([
            "type": "thinking_token",
            "metadata": ["reasoning_content": "chain"],
        ])
        XCTAssertEqual(metadata.content, "chain")
    }

    func testRunArtifactIdFromTopLevelAndMetadata() {
        let top = AgentSSEClient.parse(["type": "result", "run_artifact_id": "art_1"])
        XCTAssertEqual(top.runArtifactId, "art_1")
        let nested = AgentSSEClient.parse([
            "type": "done",
            "metadata": ["run_artifact_id": "art_2"],
        ])
        XCTAssertEqual(nested.runArtifactId, "art_2")
    }

    func testErrorFrameUsesMessageKey() {
        let event = AgentSSEClient.parse(["type": "error", "message": "boom"])
        XCTAssertEqual(event.kind, .error)
        XCTAssertEqual(event.content, "boom")
    }

    func testUnknownFrameFallsBackToOther() {
        let event = AgentSSEClient.parse(["type": "mystery"])
        XCTAssertEqual(event.kind, .other)
        XCTAssertEqual(event.content, "")
    }
}

final class SafetyCardDecodingTests: XCTestCase {

    func testNestedCardDecodes() throws {
        let json = """
        {
            "action_id": "perm_1",
            "category": "file_write",
            "status": "pending",
            "content": "write file",
            "card": {
                "card_type": "folder",
                "level": "high",
                "requires_diff": true,
                "diff": "@@ -1 +1 @@",
                "original": "a",
                "proposed": "b"
            }
        }
        """
        let action = try JSONDecoder().decode(SafetyActionModel.self, from: Data(json.utf8))
        XCTAssertEqual(action.id, "perm_1")
        XCTAssertEqual(action.cardType, "folder")
        XCTAssertEqual(action.level, "high")
        XCTAssertTrue(action.requiresDiff)
        XCTAssertEqual(action.diff, "@@ -1 +1 @@")
    }

    func testFlatFieldsFallback() throws {
        let json = """
        {
            "id": "perm_2",
            "category": "network_access",
            "status": "pending",
            "content": "fetch url",
            "level": "medium",
            "diff": "@@ -2 +2 @@"
        }
        """
        let action = try JSONDecoder().decode(SafetyActionModel.self, from: Data(json.utf8))
        XCTAssertEqual(action.id, "perm_2")
        XCTAssertEqual(action.cardType, "network")
        XCTAssertEqual(action.level, "medium")
        XCTAssertFalse(action.requiresDiff)
        XCTAssertEqual(action.diff, "@@ -2 +2 @@")
    }

    func testDeriveCardType() {
        XCTAssertEqual(SafetyCardModel.deriveCardType(category: "file_read"), "folder")
        XCTAssertEqual(SafetyCardModel.deriveCardType(category: "network_access"), "network")
        XCTAssertEqual(SafetyCardModel.deriveCardType(category: "tool_call"), "remote")
        XCTAssertEqual(SafetyCardModel.deriveCardType(category: "shell_exec"), "code")
    }
}

final class CoworkMobileOverviewTests: XCTestCase {

    func testOverviewDecodesRunsAndApprovals() {
        let object: [String: Any] = [
            "runs": [
                ["run_id": "r1", "workflow_name": "wf", "status": "running"],
            ],
            "pending_approvals": [
                ["action_id": "a1", "tool_name": "shell", "source": "local"],
            ],
            "generated_at": 123.0,
        ]
        let overview = CoworkMobileOverview.from(object)
        XCTAssertEqual(overview.runs.count, 1)
        XCTAssertEqual(overview.runs.first?["run_id"] as? String, "r1")
        XCTAssertEqual(overview.pendingApprovals.count, 1)
        XCTAssertEqual(overview.pendingApprovals.first?["action_id"] as? String, "a1")
        XCTAssertEqual(overview.generatedAt, 123.0)
    }

    func testOverviewToleratesMissingFields() {
        let overview = CoworkMobileOverview.from([:])
        XCTAssertTrue(overview.runs.isEmpty)
        XCTAssertTrue(overview.pendingApprovals.isEmpty)
        XCTAssertEqual(overview.generatedAt, 0)
    }
}
