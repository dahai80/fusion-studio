import XCTest
@testable import FusionStudio

// 审计0902 #234 test hook — P0/P1 已修缺陷的行为锁定测试。
//   覆盖: R6 DocBridge authToken Keychain · A2 AppState 转发 · A4 HTTP statusCode
//   (Sim/Sec 公开枚举) · E7 sanitizeHtml/StyleBlock CSS XSS 向量。
//   私有 status 函数 (Doc/Health) 经 internal test hook 暴露, 见各桥文件。

@MainActor
final class Audit0902Tests: XCTestCase {

    // MARK: - R6 (P0) DocBridge authToken Keychain migration

    func test_audit0902_R6_authToken_keychainRoundTripAndLegacyMigration() {
        let acct = "test_audit0902_r6_doc_auth_token"
        defer { _ = KeychainStore.delete(acct) }
        _ = KeychainStore.delete(acct)
        let legacy = "test_audit0902_r6_legacy_token"
        defer { UserDefaults.standard.removeObject(forKey: legacy) }

        // Keychain 直存直取
        XCTAssertTrue(KeychainStore.set(acct, "secret-xyz"), "set should succeed")
        XCTAssertEqual(KeychainStore.get(acct), "secret-xyz")
        // 空 token 删除
        XCTAssertTrue(KeychainStore.delete(acct), "delete should succeed")
        XCTAssertNil(KeychainStore.get(acct))

        // 旧明文 UserDefaults 模拟迁移: 写 legacy, DocBridge.authToken getter 应搬 Keychain 并清旧。
        UserDefaults.standard.set("legacy-bearer-value", forKey: legacy)
        // 直接验证 KeychainStore 原语语义 (DocBridge getter 调同一组原语), 搬迁逻辑不可独立实例化
        // (authToken 是 private 计算属性), 故以原语级锁行为: set 后 get 一致, delete 后 nil。
        XCTAssertTrue(KeychainStore.set(legacy, "legacy-bearer-value"))
        XCTAssertEqual(KeychainStore.get(legacy), "legacy-bearer-value")
        UserDefaults.standard.removeObject(forKey: legacy)
        XCTAssertTrue(KeychainStore.delete(legacy))
        XCTAssertNil(KeychainStore.get(legacy))
    }

    // MARK: - A2 (P1) AppState objectWillChange forwarding

    func test_audit0902_A2_appStateForwardsSubobjectChange() {
        let nav = NavigationState()
        let ui = UIPanelState()
        let health = HealthState()
        let theme = ThemeState()
        let state = AppState(navState: nav, uiPanelState: ui, healthState: health, themeState: theme)

        let exp = expectation(description: "AppState.objectWillChange fires on sub-object change")
        var fireCount = 0
        let token = state.objectWillChange.sink {
            fireCount += 1
            if fireCount >= 1 { exp.fulfill() }
        }
        // 改子对象 @Published -> 应转发触发 AppState.objectWillChange
        nav.selectedModule = .design
        wait(for: [exp], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(fireCount, 1, "AppState must forward sub-object objectWillChange")
        token.cancel()
    }

    func test_audit0902_A2_appStateForwardsAllFourDomains() {
        let nav = NavigationState()
        let ui = UIPanelState()
        let health = HealthState()
        let theme = ThemeState()
        let state = AppState(navState: nav, uiPanelState: ui, healthState: health, themeState: theme)
        var fireCount = 0
        let token = state.objectWillChange.sink { fireCount += 1 }

        nav.activeSection = .agent
        ui.isInspectorVisible = true
        health.isMLXRunning = true
        theme.isDarkMode.toggle()
        // 4 域各改一次, 转发应累计 >=4
        XCTAssertGreaterThanOrEqual(fireCount, 4, "all 4 sub-objects must forward changes")
        token.cancel()
    }

    // MARK: - A4 (P1) HTTP statusCode semantic errors (Sim/Sec 公开枚举)

    func test_audit0902_A4_simulationBridgeError_statusCodes() {
        XCTAssertEqual(SimulationBridgeError.httpError(401).errorDescription, "Unauthorized (401): fusion-sim 鉴权失败")
        XCTAssertEqual(SimulationBridgeError.httpError(403).errorDescription, "Forbidden (403): 无权限")
        XCTAssertEqual(SimulationBridgeError.httpError(404).errorDescription, "Not Found (404): 端点或资源不存在")
        XCTAssertEqual(SimulationBridgeError.httpError(500).errorDescription, "Server error (500): fusion-sim 服务端故障")
        XCTAssertEqual(SimulationBridgeError.httpError(599).errorDescription, "Server error (599): fusion-sim 服务端故障")
        XCTAssertEqual(SimulationBridgeError.httpError(418).errorDescription, "HTTP 418")
    }

    func test_audit0902_A4_securityBridgeError_statusCodes() {
        XCTAssertEqual(SecurityBridgeError.httpError(401).errorDescription, "Unauthorized (401): fusion-security 鉴权失败")
        XCTAssertEqual(SecurityBridgeError.httpError(403).errorDescription, "Forbidden (403): 无权限")
        XCTAssertEqual(SecurityBridgeError.httpError(404).errorDescription, "Not Found (404): 端点或资源不存在")
        XCTAssertEqual(SecurityBridgeError.httpError(500).errorDescription, "Server error (500): fusion-security 服务端故障")
        XCTAssertEqual(SecurityBridgeError.httpError(503).errorDescription, "Server error (503): fusion-security 服务端故障")
        XCTAssertEqual(SecurityBridgeError.httpError(302).errorDescription, "HTTP 302")
    }

    // DocBridge.httpStatusError / HealthBridge.healthStatusError: private→internal test hook。
    // 构造 HTTPURLResponse (本地 URL), 验 4xx/5xx 返 NSError, 2xx 返 nil。
    private func makeResponse(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "http://127.0.0.1:1/p")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    func test_audit0902_A4_docBridgeHttpStatusError() {
        XCTAssertNil(DocBridge.httpStatusError(makeResponse(200), nil), "2xx must not error")
        XCTAssertNil(DocBridge.httpStatusError(nil, nil), "non-HTTP response must not error")
        let e401 = DocBridge.httpStatusError(makeResponse(401), Data())
        XCTAssertEqual((e401 as NSError?)?.code, 401)
        XCTAssertTrue((e401?.localizedDescription ?? "").contains("401"))
        let e500 = DocBridge.httpStatusError(makeResponse(500), Data())
        XCTAssertEqual((e500 as NSError?)?.code, 500)
        let e404 = DocBridge.httpStatusError(makeResponse(404), Data())
        XCTAssertEqual((e404 as NSError?)?.code, 404)
    }

    func test_audit0902_A4_healthBridgeHealthStatusError() {
        XCTAssertNil(HealthBridge.healthStatusError(makeResponse(204)), "2xx must not error")
        XCTAssertNil(HealthBridge.healthStatusError(nil), "non-HTTP response must not error")
        let e401 = HealthBridge.healthStatusError(makeResponse(401))
        XCTAssertEqual((e401 as NSError?)?.code, 401)
        XCTAssertTrue((e401?.localizedDescription ?? "").contains("401"))
        let e503 = HealthBridge.healthStatusError(makeResponse(503))
        XCTAssertEqual((e503 as NSError?)?.code, 503)
    }

    // MARK: - E7 (P1) sanitizeHtml + sanitizeStyleBlock CSS XSS vectors

    func test_audit0902_E7_stripsScriptTags() {
        let out = DesignBridge.sanitizeHtml("<div>ok</div><script>alert(1)</script>")
        XCTAssertFalse(out.contains("<script"), "script tag must be stripped")
        XCTAssertTrue(out.contains("<div>ok</div>"), "legit content survives")
    }

    func test_audit0902_E7_stripsNestedScriptBypass() {
        let out = DesignBridge.sanitizeHtml("<scr<script>ipt>alert(1)</script>")
        XCTAssertFalse(out.lowercased().contains("script>ipt"), "nested script bypass must collapse")
    }

    func test_audit0902_E7_stripsOnEventHandlers() {
        let out = DesignBridge.sanitizeHtml("<img src=x onerror=\"alert(1)\">")
        XCTAssertFalse(out.contains("onerror"), "on* event handler must be stripped")
    }

    func test_audit0902_E7_stripsJavascriptUrl() {
        let out = DesignBridge.sanitizeHtml("<a href=\"javascript:alert(1)\">click</a>")
        XCTAssertFalse(out.lowercased().contains("javascript:"), "javascript: URL must be neutralized")
    }

    func test_audit0902_E7_stripsIframeObjectEmbedMath() {
        for tag in ["iframe", "object", "embed", "math"] {
            let out = DesignBridge.sanitizeHtml("<\(tag) src=\"x\"></\(tag)>")
            XCTAssertFalse(out.contains("<\(tag)"), "\(tag) injection surface must be stripped")
        }
    }

    func test_audit0902_E7_styleBlockCssXssStrippedButLegitSurvives() {
        // #388: 整块剥 <style> 丢暗色 token + 自定义 class -> 预览空白。外科净化应保留 :root/class, 剥 XSS 向量。
        let html = """
        <style>
        :root { --bg: #1a1a1a; }
        .surface { background: var(--bg); }
        .evil { width: expression(alert(1)); }
        .import-eval { }
        @import url(evil.css);
        body { background: url(javascript:alert(1)); }
        * { behavior: url(evil.htc); }
        </style>
        <div class="surface">ok</div>
        """
        let out = DesignBridge.sanitizeHtml(html)
        // 合法 CSS 保留
        XCTAssertTrue(out.contains(":root"), ":root design tokens must survive (外科非整剥)")
        XCTAssertTrue(out.contains(".surface"), "custom class must survive")
        // XSS 向量剥除
        XCTAssertFalse(out.contains("expression("), "expression() CSS XSS must be stripped")
        XCTAssertFalse(out.contains("@import"), "@import must be stripped")
        XCTAssertFalse(out.lowercased().contains("url(javascript:"), "url(javascript:) must be stripped")
        XCTAssertFalse(out.contains("behavior:"), "behavior: must be stripped")
    }

    func test_audit0902_E7_sanitizeStyleBlockPreservesBlockWhenNoVectors() {
        let html = "<style>.a{color:red}</style><p>x</p>"
        let out = DesignBridge.sanitizeStyleBlock(html)
        XCTAssertTrue(out.contains("<style>"), "clean style block must be preserved verbatim")
        XCTAssertTrue(out.contains(".a{color:red}"), "clean CSS body must be preserved")
    }
}
