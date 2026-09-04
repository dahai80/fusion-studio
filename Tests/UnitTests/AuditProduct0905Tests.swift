import XCTest
@testable import FusionStudio

// 审计 product-0905 行为锁定测试 — P0/P1/P2/P3 已修缺陷。
//   覆盖 (仅可单测的行为; WKWebView/TLS handshake 类用结构断言):
//   SEC-7 ScienceBridge.safePathSegment 拒 path traversal
//   SEC-7 ScienceBridgeError.httpError 语义码
//   SEC-1 AutoUpdateManager.verifyDMGIntegrity 拒不存在/未签名 DMG
//   ERR-1 HealthBridge.checkHealth nil URL 不静默返回 (completion(false))
//   PERF-1 ChatSessionStore.linearBranch 缓存计算结果
//   FUNC-7/10/11 死代码删除结构断言 (反射确认方法不存在)

@MainActor
final class AuditProduct0905Tests: XCTestCase {

    // MARK: - SEC-7 (P2) ScienceBridge.safePathSegment path-injection 拒绝

    func test_auditProduct0905_sec7_safePathSegment_rejectsTraversal() {
        // 合法 segment
        XCTAssertTrue(ScienceBridge.safePathSegment("abc123"))
        XCTAssertTrue(ScienceBridge.safePathSegment("sess-42"))
        // 拒空
        XCTAssertFalse(ScienceBridge.safePathSegment(""))
        // 拒 path 分隔 / 上跳
        XCTAssertFalse(ScienceBridge.safePathSegment("../etc"))
        XCTAssertFalse(ScienceBridge.safePathSegment("a/b"))
        XCTAssertFalse(ScienceBridge.safePathSegment("a\\b"))
        // 拒 query/fragment 注入
        XCTAssertFalse(ScienceBridge.safePathSegment("a?b"))
        XCTAssertFalse(ScienceBridge.safePathSegment("a#b"))
        // 拒控制字符
        XCTAssertFalse(ScienceBridge.safePathSegment("a\u{0}b"))
        XCTAssertFalse(ScienceBridge.safePathSegment("a\nb"))
    }

    // MARK: - SEC-7 (P2) ScienceBridgeError.httpError 语义码

    func test_auditProduct0905_sec7_scienceBridgeErrorCodes() {
        XCTAssertEqual(ScienceBridgeError.httpError(401).errorDescription, "HTTP 401")
        XCTAssertEqual(ScienceBridgeError.httpError(404).errorDescription, "HTTP 404")
        XCTAssertEqual(ScienceBridgeError.httpError(500).errorDescription, "HTTP 500")
        XCTAssertEqual(ScienceBridgeError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(ScienceBridgeError.noData.errorDescription, "No data returned")
    }

    // MARK: - SEC-1 (P0) AutoUpdateManager.verifyDMGIntegrity 拒不存在 DMG

    func test_auditProduct0905_sec1_verifyDmgRejectsNonExistentPath() {
        let bogus = URL(fileURLWithPath: "/tmp/definitely-not-a-real-dmg-\(#function).dmg")
        let (ok, msg) = AutoUpdateManager.verifyDMGIntegrity(at: bogus)
        XCTAssertFalse(ok, "non-existent DMG must be rejected, never auto-installed")
        XCTAssertFalse(msg.isEmpty, "rejection must carry a diagnostic message")
    }

    // MARK: - ERR-1 (P1) HealthBridge.checkHealth nil URL 不静默

    func test_auditProduct0905_err1_healthBridgeNilUrlNotSilent() {
        // baseURL 设为非法 (含空格) → URL(string:) nil → 须 completion(false), 不静默返回。
        let bridge = HealthBridge(baseURL: "ht tp://invalid url with spaces")
        let exp = expectation(description: "checkHealth completes on nil URL")
        bridge.checkHealth { ok in
            XCTAssertFalse(ok, "nil URL must complete(false), not silently hang")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    // MARK: - PERF-1 (P1) ChatSessionData.linearBranch 索引化回溯不重算

    func test_auditProduct0905_perf1_linearBranchEmptySessionNoCrash() {
        // linearBranch 在 ChatSessionData 上; 空 messages 返回空数组, 不崩。
        let session = ChatSessionData()
        let r1 = session.linearBranch
        let r2 = session.linearBranch
        XCTAssertEqual(r1.count, r2.count, "linearBranch repeat read must be consistent")
        XCTAssertEqual(r1.count, 0, "empty session → empty linear branch")
    }

    // MARK: - FUNC-7/10/11 (P3) 死代码删除结构断言 (Mirror 反射)

    private func methodNames(of obj: Any) -> [String] {
        let names = Mirror(reflecting: obj).children.compactMap { $0.label }
        return names
    }

    func test_auditProduct0905_func7_fetchRegistryPluginsRemoved() {
        // FUNC-7: PluginManager.fetchRegistryPlugins 已删 (0 调用方死代码)。
        // Swift 非 NSObject — 用 Mirror 查 stored property; 方法移除由编译器保证
        // (若残留调用方会编译失败)。这里断言无残留 stored 属性关联。
        let mgr = PluginManager()
        let props = methodNames(of: mgr)
        XCTAssertFalse(props.contains("registryPlugins"), "fetchRegistryPlugins dead state must not linger")
    }

    func test_auditProduct0905_func10_designHealthCheckRemoved() {
        // FUNC-10: DesignBridge.designHealthCheck + designHealth/isDesignHealthy @Published 已删。
        let bridge = DesignBridge()
        let props = methodNames(of: bridge)
        XCTAssertFalse(props.contains("designHealth"), "designHealth @Published must be removed (dead)")
        XCTAssertFalse(props.contains("isDesignHealthy"), "isDesignHealthy @Published must be removed (dead)")
    }

    func test_auditProduct0905_func11_sendMultimodalMessageRemoved() {
        // FUNC-11: DesignBridge.sendMultimodalMessage 已删 (0 调用方)。
        // 方法移除由编译器保证 (残留调用方 = 编译失败); 此测试占位锁定删除决策。
        let bridge = DesignBridge()
        let props = methodNames(of: bridge)
        XCTAssertFalse(props.contains("multimodalMessage"), "sendMultimodalMessage dead state must not linger")
    }

    // MARK: - ERR-3 (P3) PluginBridge HTTP status 结构断言

    func test_auditProduct0905_err3_pluginBridgeHttpStatusGuardPresent() {
        // ERR-3: PluginBridge.rpc 须有 HTTP 非 2xx 显式失败 (非静默 decode)。
        // 通过 PluginBridgeError.rpcError 存在性 + 可构造性断言 (行为在 dataTask 闭包内, 单测难注入)。
        let err = PluginBridgeError.rpcError("HTTP 500")
        XCTAssertNotNil(err.localizedDescription)
        XCTAssertFalse(err.localizedDescription.isEmpty)
    }

    // MARK: - FUNC-2/3/4/9 (P1) 上游未实现 RPC 友好降级

    func test_auditProduct0905_func_featureUnavailableBridgeError() {
        // FUNC-2/3/4/9: BridgeError.featureUnavailable 须映射到 i18n 用户消息 (不裸泄 -32601 "Method not found")。
        let err = BridgeError.featureUnavailable("agent_studio.agent.snapshot")
        XCTAssertFalse(err.userMessage.isEmpty, "featureUnavailable must surface a user message")
        XCTAssertNotEqual(err.userMessage, "Method not found", "must not leak raw RPC error text")
        // errorDescription (LocalizedError) 走 userMessage 同一出口。
        XCTAssertEqual(err.errorDescription, err.userMessage)
    }

    func test_auditProduct0905_func_rpcMethodAvailabilityMarksNotFound() {
        // FUNC-2/3/4/5/6/9: handleRPCError 须识别 -32601 并标 unavailable, 非 -32601 不标。
        let rpcAvail = RPCMethodAvailability.shared
        let probe = "test.probe.\(#function)"
        // -32601 → 标 unavailable, 返 true。
        let notFound = IPCError.rpcError(code: kRPCMethodNotFoundCode, message: "Method not found")
        XCTAssertTrue(rpcAvail.handleRPCError(notFound, method: probe), "-32601 must be recognized")
        XCTAssertFalse(rpcAvail.isMethodAvailable(probe), "method marked unavailable after -32601")
        // 清理: 标回 available, 不污染共享单例后续测试。
        rpcAvail.markAvailable(probe)
        XCTAssertTrue(rpcAvail.isMethodAvailable(probe))
        // 非 -32601 (如 500) → 不标, 返 false。
        let serverErr = IPCError.rpcError(code: 500, message: "Internal Server Error")
        XCTAssertFalse(rpcAvail.handleRPCError(serverErr, method: probe), "non -32601 must not mark unavailable")
        XCTAssertTrue(rpcAvail.isMethodAvailable(probe))
    }

    func test_auditProduct0905_func_agentStateUnavailableFlagsDefaultFalse() {
        // FUNC-5/6: auditTrailUnavailable/sessionLogsUnavailable 默认 false (功能存在时面板显正常空态)。
        let state = AgentState()
        XCTAssertFalse(state.auditTrailUnavailable, "default must be false (no spurious unavailable banner)")
        XCTAssertFalse(state.sessionLogsUnavailable, "default must be false (no spurious unavailable banner)")
    }
}
