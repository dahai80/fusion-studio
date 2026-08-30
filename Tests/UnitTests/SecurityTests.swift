import XCTest
@testable import FusionStudio

// HIGH-3: 验证 validateFilePath 拒绝 symlink 穿越攻击。
// 攻击者在允许前缀目录内放指向 /etc 等敏感路径的 symlink, 旧实现仅 standardizingPath
// 不解析 symlink -> 白名单前缀匹配成功 -> 放行越权读。修正后 resolvingSymlinksInPath
// 取真实 inode 路径, 敏感目标被拒。
// 审计0830 P1-资源-1: validateFilePath 白名单已删 /tmp (世界可写共享目录, 扩大攻击面),
//   临时文件统一走 ~/.fusion-studio/tmp (F-I6)。测试根目录须落在白名单前缀内, 否则
//   合法用例被新白名单拒 -> 用 ~/.fusion-studio/tmp 下随机子目录作测试根。
final class SecurityPathTests: XCTestCase {

    private let tmpRoot = NSHomeDirectory() + "/.fusion-studio/tmp/fusion-security-test-\(UUID().uuidString)"
    private let manager = FileManager.default

    override func setUp() {
        super.setUp()
        try? manager.createDirectory(atPath: tmpRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? manager.removeItem(atPath: tmpRoot)
        super.tearDown()
    }

    // 合法路径: 在 /tmp 允许前缀内 -> true
    func testAllowedTmpPathAccepted() {
        let allowedPath = tmpRoot + "/legit.txt"
        XCTAssertTrue(SecurityManager.shared.validateFilePath(allowedPath),
                      "合法 /tmp 路径应被放行")
    }

    // symlink 穿越攻击: 在 /tmp 放指向 /etc/passwd 的 symlink -> 必须 false
    func testSymlinkToSensitivePathRejected() throws {
        let symlinkPath = tmpRoot + "/escape-to-etc"
        try? manager.removeItem(atPath: symlinkPath)
        try manager.createSymbolicLink(atPath: symlinkPath, withDestinationPath: "/etc")
        defer { try? manager.removeItem(atPath: symlinkPath) }

        XCTAssertFalse(SecurityManager.shared.validateFilePath(symlinkPath),
                       "指向 /etc 的 symlink 必须被拒绝 (HIGH-3 symlink 穿越修复)")
    }

    // symlink 指向允许目录内合法文件 -> 仍应放行 (不误伤)
    func testSymlinkWithinAllowedDirAccepted() throws {
        let realFile = tmpRoot + "/real.txt"
        manager.createFile(atPath: realFile, contents: Data("x".utf8))
        let symlinkPath = tmpRoot + "/link-to-real"
        try manager.createSymbolicLink(atPath: symlinkPath, withDestinationPath: realFile)
        defer {
            try? manager.removeItem(atPath: symlinkPath)
            try? manager.removeItem(atPath: realFile)
        }

        XCTAssertTrue(SecurityManager.shared.validateFilePath(symlinkPath),
                      "允许目录内 symlink 应被放行, 不误伤合法用例")
    }

    // 显式 .. 穿越 -> false (基础防线, 与 symlink 修正正交)
    func testDotDotTraversalRejected() {
        let escaped = tmpRoot + "/../../../../etc/passwd"
        XCTAssertFalse(SecurityManager.shared.validateFilePath(escaped),
                       "含 .. 的路径必须被拒绝")
    }
}

// HIGH-6: 验证 DesignBridge.sanitizeHtml 剥 LLM 不可信 HTML 中的 XSS 向量。
// currentArtifactCode 来自 LLM, 可被 prompt 注入 emit 含 <script> 的 HTML -> 送 CLI 解析 +
// wasm 渲染 = XSS 等价。净化层剥 script/iframe/object/embed + on* 事件 + javascript:/vbscript: URL。
final class HtmlSanitizeTests: XCTestCase {

    // <script> 块被剥 (含跨行、大小写、src 外链)
    func testScriptTagStripped() {
        let html = "<div>ok</div><script>alert('xss')</script>"
        let safe = DesignBridge.sanitizeHtml(html)
        XCTAssertFalse(safe.contains("<script"), "script 标签必须被剥")
        XCTAssertFalse(safe.contains("alert"), "script 内容必须被剥")
        XCTAssertTrue(safe.contains("<div>ok</div>"), "合法 div 必须保留")
    }

    func testScriptTagCaseInsensitiveAndMultiline() {
        let html = "<SCRIPT\nsrc='evil.js'></SCRIPT>"
        let safe = DesignBridge.sanitizeHtml(html)
        XCTAssertFalse(safe.lowercased().contains("script"), "大小写不敏感 script 必须被剥")
        XCTAssertFalse(safe.contains("evil.js"), "外链 src 必须被剥")
    }

    // on* 事件处理器属性被剥 (双引号/单引号/无引号)
    func testEventHandlerAttributesStripped() {
        let html = #"<button onclick="evil()" onmouseover='bad()'>btn</button>"#
        let safe = DesignBridge.sanitizeHtml(html)
        XCTAssertFalse(safe.contains("onclick"), "onclick 必须被剥")
        XCTAssertFalse(safe.contains("onmouseover"), "onmouseover 必须被剥")
        XCTAssertFalse(safe.contains("evil"), "handler 代码必须被剥")
        XCTAssertTrue(safe.contains("<button>btn</button>"), "button 元素本体保留")
    }

    // javascript:/vbscript: URL 被替换为 #
    func testJavaScriptUrlStripped() {
        let html = #"<a href="javascript:evil()">link</a><img src='javascript:bad()'>"#
        let safe = DesignBridge.sanitizeHtml(html)
        XCTAssertFalse(safe.contains("javascript:"), "javascript: URL 必须被剥")
        XCTAssertFalse(safe.contains("evil"), "URL 内代码必须被剥")
        XCTAssertTrue(safe.contains("<a"), "a 元素本体保留")
        XCTAssertTrue(safe.contains("link</a>"), "链接文本保留")
    }

    // iframe/object/embed 被剥
    func testIframeObjectEmbedStripped() {
        let html = "<iframe src='evil'></iframe><object data='x'></object><embed src='y'>"
        let safe = DesignBridge.sanitizeHtml(html)
        XCTAssertFalse(safe.lowercased().contains("iframe"), "iframe 必须被剥")
        XCTAssertFalse(safe.lowercased().contains("object"), "object 必须被剥")
        XCTAssertFalse(safe.lowercased().contains("embed"), "embed 必须被剥")
    }

    // 合法 design HTML (style/div/svg) 不被误伤
    func testLegitimateDesignHtmlPreserved() {
        let html = "<div style=\"color:red\"><svg><circle/></svg><p>text</p></div>"
        let safe = DesignBridge.sanitizeHtml(html)
        XCTAssertTrue(safe.contains("style=\"color:red\""), "合法 style 属性必须保留")
        XCTAssertTrue(safe.contains("<svg><circle/></svg>"), "svg 必须保留")
        XCTAssertTrue(safe.contains("<p>text</p>"), "p 元素必须保留")
    }
}

// BUG-13: 验证 DesignBridge.sanitizeErrorBody 剥错误响应体中的密钥子串。
// 服务端错误体可回显请求头 (Authorization/Bearer/api_key), 原样插 UI 泄密钥。
final class ErrorBodySanitizeTests: XCTestCase {

    // Bearer <token> 整段被剥
    func testBearerTokenStripped() {
        let body = #"{"error":"Unauthorized","header":"Bearer sk-ant-abc123xyz"}"#
        let safe = DesignBridge.sanitizeErrorBody(body)
        XCTAssertFalse(safe.contains("sk-ant-abc123xyz"), "Bearer token 值必须被剥")
        XCTAssertTrue(safe.contains("Bearer ***"), "Bearer 段保留占位")
    }

    // Authorization: <scheme> <token> 整段被剥
    func testAuthorizationHeaderStripped() {
        let body = "Authorization: Bearer fg-admin-key, Content-Type: application/json"
        let safe = DesignBridge.sanitizeErrorBody(body)
        XCTAssertFalse(safe.contains("fg-admin-key"), "Authorization 内 token 必须被剥")
        XCTAssertTrue(safe.contains("Authorization: ***"), "Authorization 段保留占位")
    }

    // api_key/api-key/apikey 字段值被剥 (JSON 与 form 均覆盖)
    func testApiKeyFieldStripped() {
        let body = #"{"api_key":"sk-live-12345","model":"qwen"}"#
        let safe = DesignBridge.sanitizeErrorBody(body)
        XCTAssertFalse(safe.contains("sk-live-12345"), "api_key 字段值必须被剥")
    }

    // 非敏感错误信息保留 (不误伤)
    func testLegitimateErrorPreserved() {
        let body = #"{"error":"model not found","status":404}"#
        let safe = DesignBridge.sanitizeErrorBody(body)
        XCTAssertTrue(safe.contains("model not found"), "非敏感错误信息必须保留")
        XCTAssertTrue(safe.contains("404"), "状态码必须保留")
    }
}
