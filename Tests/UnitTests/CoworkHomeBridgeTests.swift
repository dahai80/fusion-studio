import XCTest
@testable import FusionStudio

// #217: Chat/Cowork 共用首页 — CoworkHomeBridge + 事件映射 单测.
// Callers: UnitTests target. Affected API: CoworkHomeBridge, CoworkHomeEventMapper, CoworkHomeMode.
// Data schemas: desk.system.set_scoped_folder/scoped_folder, desk.workflow.create/run, desk.events.*.

final class CoworkHomeEventMapperTests: XCTestCase {

    func testStepEventMapsToStepBubble() {
        let raw: [String: Any] = ["type": "step", "node": "codegen", "status": "running"]
        let ev = CoworkHomeEventMapper.map(raw)
        XCTAssertEqual(ev?.kind, .step)
        XCTAssertEqual(ev?.text, "▶ codegen · running")
    }

    func testNodeStartFallbackFields() {
        // node_start 无 status, name 作节点名兜底.
        let raw: [String: Any] = ["type": "node_start", "name": "planner"]
        let ev = CoworkHomeEventMapper.map(raw)
        XCTAssertEqual(ev?.kind, .step)
        XCTAssertEqual(ev?.text, "▶ planner")
    }

    func testArtifactEventMapsToArtifactBubble() {
        let raw: [String: Any] = ["type": "artifact", "name": "main.py"]
        let ev = CoworkHomeEventMapper.map(raw)
        XCTAssertEqual(ev?.kind, .artifact)
        XCTAssertEqual(ev?.text, "📦 main.py")
    }

    func testArtifactCreatedFallbackField() {
        let raw: [String: Any] = ["type": "artifact_created", "artifact": "report.md"]
        let ev = CoworkHomeEventMapper.map(raw)
        XCTAssertEqual(ev?.kind, .artifact)
        XCTAssertEqual(ev?.text, "📦 report.md")
    }

    func testDoneEventMapsToDoneBubble() {
        for t in ["done", "completed", "workflow_done"] {
            let ev = CoworkHomeEventMapper.map(["type": t])
            XCTAssertEqual(ev?.kind, .done, "type=\(t) 应映射为 done")
            XCTAssertEqual(ev?.text, "✓ done")
        }
    }

    func testErrorEventMapsToErrorBubble() {
        let raw: [String: Any] = ["type": "error", "message": "OOM"]
        let ev = CoworkHomeEventMapper.map(raw)
        XCTAssertEqual(ev?.kind, .error)
        XCTAssertEqual(ev?.text, "✗ error: OOM")
    }

    func testErrorEventFallbackField() {
        let raw: [String: Any] = ["type": "failed", "error": "timeout"]
        let ev = CoworkHomeEventMapper.map(raw)
        XCTAssertEqual(ev?.kind, .error)
        XCTAssertEqual(ev?.text, "✗ error: timeout")
    }

    func testUnknownTypeReturnsNil() {
        let ev = CoworkHomeEventMapper.map(["type": "heartbeat"])
        XCTAssertNil(ev)
    }

    func testEmptyDictReturnsNil() {
        let ev = CoworkHomeEventMapper.map([:])
        XCTAssertNil(ev)
    }

    func testStepMissingNodeUsesPlaceholder() {
        let raw: [String: Any] = ["type": "step", "status": "ok"]
        let ev = CoworkHomeEventMapper.map(raw)
        XCTAssertEqual(ev?.text, "▶ ? · ok")
    }
}

final class CoworkHomeModeTests: XCTestCase {

    func testModeEnumHasChatAndCowork() {
        let all = CoworkHomeMode.allCases
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains(.chat))
        XCTAssertTrue(all.contains(.cowork))
    }

    func testDefaultIsChat() {
        // homeMode 默认 .chat — 验证 rawValue 稳定.
        XCTAssertEqual(CoworkHomeMode.chat.rawValue, "chat")
        XCTAssertEqual(CoworkHomeMode.cowork.rawValue, "cowork")
    }
}

@MainActor
final class CoworkHomeBridgeStateTests: XCTestCase {

    func testInitialStateEmpty() {
        let bridge = CoworkHomeBridge(ipc: IPCClient(socketPath: "/tmp/test-cowork-nope.sock"))
        XCTAssertTrue(bridge.scopedFolders.isEmpty)
        XCTAssertTrue(bridge.enforce)
        XCTAssertFalse(bridge.isAuthorizing)
        XCTAssertFalse(bridge.isPolling)
        XCTAssertNil(bridge.lastError)
        XCTAssertNil(bridge.lastEvent)
    }

    func testStopPollingIsSafeWhenIdle() {
        let bridge = CoworkHomeBridge(ipc: IPCClient(socketPath: "/tmp/test-cowork-nope.sock"))
        // 未 startPolling 直接 stop — 不应崩, 状态复位.
        bridge.stopPolling()
        XCTAssertFalse(bridge.isPolling)
    }

    func testEnsureScopedFolderSkipsWhenFoldersPresent() {
        let bridge = CoworkHomeBridge(ipc: IPCClient(socketPath: "/tmp/test-cowork-nope.sock"))
        bridge.scopedFolders = ["/tmp/pre-authorized"]
        // 已注册文件夹 — ensureScopedFolder 不应弹窗, 直接返回 true.
        // (无真实 socket, 但 isEmpty 分支短路, 不会触网.)
        let exp = XCTestExpectation(description: "ensure short-circuit")
        Task {
            let ready = await bridge.ensureScopedFolder()
            XCTAssertTrue(ready)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testStartPollingNoOpWhenAlreadyPolling() {
        let bridge = CoworkHomeBridge(ipc: IPCClient(socketPath: "/tmp/test-cowork-nope.sock"))
        // 手动置 isPolling=true 模拟运行中, 再 startPolling 不应重复订阅.
        bridge.isPolling = true
        bridge.startPolling()
        // 无 subId 被设置 (因短路 return), 仍无轮询任务.
        XCTAssertNil(bridge.subId)
    }

    // 工作流服务不可用 (本地单机 fusion-cowork 路由 gateway 失败 / 服务未启动) 时,
    // submitWorkflow 必须返回 false 并置 lastError — 该信号驱动 UnifiedChatView 回退直连推理 (#380 override).
    func testSubmitWorkflowFailsSetsLastErrorWhenServiceDown() {
        let bridge = CoworkHomeBridge(ipc: IPCClient(socketPath: "/tmp/test-cowork-down.sock"))
        let exp = XCTestExpectation(description: "submitWorkflow fails")
        Task {
            let ok = await bridge.submitWorkflow(prompt: "你是谁")
            // 无真实 socket → udsCall 抛 IPCError.disconnected → catch → 返回 false + lastError.
            XCTAssertFalse(ok, "服务不可用时 submitWorkflow 应返回 false (回退直连推理信号)")
            XCTAssertNotNil(bridge.lastError, "失败应置 lastError 供日志/回退决策")
            XCTAssertFalse(bridge.isPolling, "失败不应启动事件轮询")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.0)
    }
}
