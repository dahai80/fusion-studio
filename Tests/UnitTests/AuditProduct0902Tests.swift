import XCTest
import CryptoKit
@testable import FusionStudio

// 审计 product-0902 #247 test hook — P0/P1 已修缺陷的行为锁定测试 (product 报告 1P0/9P1)。
//   覆盖:
//   T0-1 F-ops-1 healthPort 11456→11469 stale-port migration (P0)
//   T1-1 F-ft-1/F-ft-6 FinanceBridgeError.httpError 语义码 (P1)
//   T1-2 F-ft-2 ChatSessionStore nil-ipc graceful no-crash (P1)
//   T1-3 F-ft-3 UnifiedChatView.parseMarkdownSafely no fatalError (P1)
//   T1-4 F-sec-1 multiNodeBaseURL 远程强制 https:// (P1)
//   T1-9 F-func-1/F-ops-5 criticalBackendMissing flag (P1)

@MainActor
final class AuditProduct0902Tests: XCTestCase {

    // MARK: - T0-1 (P0) healthPort stale 11456 → 11469 migration

    func test_auditProduct0902_T0_healthPortMigratesStale11456() {
        let key = "healthPort"
        let gateKey = "fusionConfig.stalePortMigratedV1"
        let origPort = UserDefaults.standard.integer(forKey: key)
        let origGate = UserDefaults.standard.bool(forKey: gateKey)
        defer {
            UserDefaults.standard.set(origPort, forKey: key)
            UserDefaults.standard.set(origGate, forKey: gateKey)
        }
        // 重置 migration gate + 设 stale 11456
        UserDefaults.standard.set(false, forKey: gateKey)
        UserDefaults.standard.set(11456, forKey: key)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: key), 11456, "fixture: stale 11456 set")

        // 触发 migrateStalePorts (init 内调用, 但 gate 已置位 — 直接调 func 重跑)
        let cfg = FusionConfig()
        cfg.migrateStalePorts()
        XCTAssertEqual(cfg.healthPort, 11469, "stale 11456 must migrate to 11469 (fusion-health probe)")
        XCTAssertEqual(UserDefaults.standard.integer(forKey: key), 11469, "migration must persist to UserDefaults")
    }

    func test_auditProduct0902_T0_healthPortFreshDefaultIs11469() {
        let key = "healthPort"
        let original = UserDefaults.standard.object(forKey: key)
        defer {
            if let original = original {
                UserDefaults.standard.set(original, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.removeObject(forKey: key)

        let cfg = FusionConfig()
        XCTAssertEqual(cfg.healthPort, 11469, "fresh install default must be 11469 (not dead 11456)")
    }

    // MARK: - T1-1 (P1) FinanceBridgeError.httpError semantic codes

    func test_auditProduct0902_T1_financeBridgeHttpStatusError() {
        // F-ft-1: 非 2xx 不再静默成功, 抛 FinanceBridgeError.httpError(code)。
        XCTAssertEqual(FinanceBridgeError.httpError(401).errorDescription, "HTTP error 401")
        XCTAssertEqual(FinanceBridgeError.httpError(403).errorDescription, "HTTP error 403")
        XCTAssertEqual(FinanceBridgeError.httpError(404).errorDescription, "HTTP error 404")
        XCTAssertEqual(FinanceBridgeError.httpError(500).errorDescription, "HTTP error 500")
        XCTAssertEqual(FinanceBridgeError.httpError(599).errorDescription, "HTTP error 599")
        // F-ft-6: 无数据不再 ?? [:] 静默, 走 noData
        XCTAssertEqual(FinanceBridgeError.noData.errorDescription, "No data returned")
        XCTAssertEqual(FinanceBridgeError.invalidURL.errorDescription, "Invalid URL")
    }

    // MARK: - T1-2 (P1) ChatSessionStore force-unwrap eradicated (structural lock)

    func test_auditProduct0902_T1_chatStoreNoForceUnwrap() {
        // F-ft-2: 原 5 处 ipc!/agentBridge! (L966/985/1002/1015/1097) 改 guard let ipc/agentBridge else { return }。
        // 方法签名带 async + 必需参数, 无法在单测中直接调 (需真实 IPC/Mock)。锁结构: 源码无残留 force-unwrap。
        let srcPath = (#file as NSString).deletingLastPathComponent
            + "/../../FusionStudio/Bridge/ChatSessionStore.swift"
        guard let src = try? String(contentsOfFile: srcPath, encoding: .utf8) else {
            XCTFail("cannot read ChatSessionStore source"); return
        }
        // 原 force-unwrap 点 (ipc!, agentBridge!) 应已全部消除
        XCTAssertFalse(src.contains("ipc!"), "no ipc! force-unwrap remaining in ChatSessionStore")
        XCTAssertFalse(src.contains("agentBridge!"), "no agentBridge! force-unwrap remaining")
        // guard let 替换存在
        XCTAssertTrue(src.contains("guard let ipc = ipc"), "guard let ipc pattern present (graceful nil path)")
        XCTAssertTrue(src.contains("guard let agentBridge = agentBridge"), "guard let agentBridge pattern present")
    }

    // MARK: - T1-3 (P1) parseMarkdownSafely no fatalError on malformed input

    func test_auditProduct0902_T1_markdownNoFatalError() {
        // F-ft-3: 原 try! AttributedString(markdown:) 遇畸形输入 fatalError。
        // 现 parseMarkdownSafely: try? 失败回退明文, 不崩。
        let malformed = "\"):(\""
        let result = UnifiedChatView.parseMarkdownSafely(malformed)
        XCTAssertFalse(result.characters.isEmpty, "malformed markdown must fall back to plain non-empty AttributedString")

        let normal = "**bold** and `code`"
        let normalResult = UnifiedChatView.parseMarkdownSafely(normal)
        XCTAssertFalse(normalResult.characters.isEmpty, "valid markdown must parse to non-empty AttributedString")

        let empty = ""
        let emptyResult = UnifiedChatView.parseMarkdownSafely(empty)
        XCTAssertTrue(emptyResult.characters.isEmpty, "empty input → empty AttributedString (no crash)")
    }

    // MARK: - T1-4 (P1) multiNodeBaseURL remote → https://, local → http://

    func test_auditProduct0902_T1_multiNodeTlsSchemeRemoteVsLocal() {
        // F-sec-1: 远程主机强制 https:// (Bearer token 明文保护); 本地回环 http://。
        let cfg = FusionConfig()
        let originalHost = cfg.modelHubHost
        let originalPort = cfg.multiNodePort
        defer {
            cfg.modelHubHost = originalHost
            cfg.multiNodePort = originalPort
        }

        // 远程
        cfg.modelHubHost = "10.0.0.5"
        XCTAssertTrue(cfg.multiNodeBaseURL.hasPrefix("https://"), "remote host must force https:// scheme")
        XCTAssertTrue(cfg.multiNodeBaseURL.contains("10.0.0.5"), "host preserved")
        XCTAssertTrue(cfg.multiNodeAgentBaseURL.hasPrefix("https://"), "agent base URL remote must force https://")

        // 本地回环
        cfg.modelHubHost = "127.0.0.1"
        XCTAssertTrue(cfg.multiNodeBaseURL.hasPrefix("http://"), "localhost must stay http://")
        XCTAssertTrue(cfg.multiNodeAgentBaseURL.hasPrefix("http://"), "localhost agent URL must stay http://")

        cfg.modelHubHost = "localhost"
        XCTAssertTrue(cfg.multiNodeBaseURL.hasPrefix("http://"), "localhost hostname must stay http://")
    }

    // MARK: - T1-9 (P1) criticalBackendMissing flag

    func test_auditProduct0902_T1_criticalBackendMissingFlag() {
        // F-func-1/F-ops-5: 后端未安装不再静默 IPC 失败, 置 criticalBackendMissing=true + hint。
        let mgr = UpstreamServiceManager()
        // 默认 false (后端存在或未探测)
        XCTAssertFalse(mgr.criticalBackendMissing, "flag default false before notInstalled path hit")
        // 直接验证 flag 可写 (实际触发靠 runStartSh notInstalled, 此处锁 API 契约)
        mgr.criticalBackendMissing = true
        XCTAssertTrue(mgr.criticalBackendMissing, "flag settable to true")
        // hint 字段存在且可读 (即使空也是合法初值)
        _ = mgr.criticalBackendMissingHint
    }

    // MARK: - 审计v0.1.58 residual — bundle manifest 完整性 opt-in 强制

    func test_residual_manifestNoManifest_returnsTrue() {
        // 无 MANIFEST.txt (dev / 未打包) → 跳过, 返回 true
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("fs-manifest-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let cfg = FusionConfig()
        XCTAssertTrue(cfg.verifyBundleManifest(svcDir: tmp), "no MANIFEST.txt → true (dev, skip)")
    }

    func test_residual_manifestMatch_returnsTrue() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("fs-manifest-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let fileName = "start.sh"
        let content = "#!/bin/bash\necho hi\n"
        let fileURL = tmp.appendingPathComponent(fileName)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        let sha = sha256Hex(content.data(using: .utf8)!)

        let manifest = "--- file-integrity ---\n\(fileName) \(sha)\n"
        try? manifest.write(to: tmp.appendingPathComponent("MANIFEST.txt"), atomically: true, encoding: .utf8)

        let cfg = FusionConfig()
        XCTAssertTrue(cfg.verifyBundleManifest(svcDir: tmp), "matching sha256 → true")
    }

    func test_residual_manifestMismatch_returnsFalse() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("fs-manifest-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let fileName = "start.sh"
        try? "#!/bin/bash\necho real\n".write(
            to: tmp.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        let manifest = "--- file-integrity ---\n\(fileName) deadbeef\n"
        try? manifest.write(to: tmp.appendingPathComponent("MANIFEST.txt"), atomically: true, encoding: .utf8)

        let cfg = FusionConfig()
        XCTAssertFalse(cfg.verifyBundleManifest(svcDir: tmp), "sha256 mismatch → false (tampered)")
    }

    func test_residual_manifestMissingFile_returnsFalse() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("fs-manifest-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let manifest = "--- file-integrity ---\nstart.sh deadbeef\n"
        try? manifest.write(to: tmp.appendingPathComponent("MANIFEST.txt"), atomically: true, encoding: .utf8)

        let cfg = FusionConfig()
        XCTAssertFalse(cfg.verifyBundleManifest(svcDir: tmp), "file missing from disk → false")
    }

    func test_residual_enforceBundleIntegrityDefaultOff() {
        let cfg = FusionConfig()
        XCTAssertFalse(cfg.enforceBundleIntegrity, "default off (warn-only, avoid MANIFEST deadlock)")
    }

    func test_residual_resolveBackendStartShRespectsEnforceFlag() {
        // 结构锁: resolveBackendStartSh bundle 分支读 enforceBundleIntegrity 决定拒/纳 bundle。
        let srcPath = (#file as NSString).deletingLastPathComponent
            + "/../../FusionStudio/Common/FusionConfig.swift"
        guard let src = try? String(contentsOfFile: srcPath, encoding: .utf8) else {
            XCTFail("cannot read FusionConfig source"); return
        }
        XCTAssertTrue(src.contains("enforceBundleIntegrity"), "opt-in flag property present")
        XCTAssertTrue(src.contains("verifyBundleManifest(svcDir:"), "manifest verify call present")
        XCTAssertTrue(src.contains("!manifestOk && FusionConfig.shared.enforceBundleIntegrity"),
            "bundle branch: reject bundle only when manifest mismatch AND enforce on")
    }

    private func sha256Hex(_ data: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
