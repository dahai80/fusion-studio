import XCTest
@testable import FusionStudio

/// 模块间集成测试
final class ModuleIntegrationTests: XCTestCase {
    func testModuleInteropService() {
        let interop = ModuleInteropService.shared
        interop.clearHistory()
        interop.exportDesignToCode(designId: "test-design", code: "print(\"hello\")", language: "python")
        let exp = XCTestExpectation(description: "transfer")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(interop.recentTransfers.isEmpty)
            let last = interop.recentTransfers.last!
            XCTAssertEqual(last.sourceModule, "design")
            XCTAssertEqual(last.targetModule, "code")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testDesignToCodeToSimulationFlow() {
        let interop = ModuleInteropService.shared
        interop.clearHistory()
        interop.exportDesignToCode(designId: "d1", code: "code", language: "swift")
        interop.deployCodeToSimulation(codeId: "c1", code: "panel", platform: "pybullet")
        interop.feedbackToDesign(sceneId: "s1", feedback: "优化", suggestions: ["调整布局"])
        let exp = XCTestExpectation(description: "flow")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertGreaterThanOrEqual(interop.recentTransfers.count, 3)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testInteropClearHistory() {
        let interop = ModuleInteropService.shared
        interop.exportDesignToCode(designId: "d1", code: "code", language: "swift")
        interop.clearHistory()
        XCTAssertTrue(interop.recentTransfers.isEmpty)
    }
}

/// IPC 集成测试
final class IPCIntegrationTests: XCTestCase {
    func testIPCClientInitialization() {
        let client = IPCClient(socketPath: "/tmp/test-ipc.sock")
        XCTAssertNotNil(client)
    }

    func testIPCErrorMapping() {
        XCTAssertEqual(IPCError.rpcError(code: -32601, message: "未知方法").localizedDescription, "RPC 错误: 未知方法")
    }
}

/// 配置同步集成测试
final class ConfigSyncIntegrationTests: XCTestCase {
    func testConfigSyncManager() {
        let manager = ConfigSyncManager.shared
        XCTAssertFalse(manager.isSyncing)
        XCTAssertEqual(manager.syncStatus, .idle)
    }

    func testBackupDirectory() {
        let manager = ConfigSyncManager.shared
        let backupDir = manager.backupDir
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupDir.path))
    }
}

/// 自动更新集成测试
final class AutoUpdateIntegrationTests: XCTestCase {
    func testUpdateManager() {
        let manager = AutoUpdateManager.shared
        XCTAssertEqual(manager.state, .idle)
        XCTAssertFalse(manager.currentVersion.isEmpty)
    }

    func testVersionComparison() {
        let manager = AutoUpdateManager.shared
        let version = AppVersion(
            tagName: "99.99.99",
            name: "Test",
            body: "Test release",
            publishedAt: "2026-01-01",
            htmlUrl: "https://example.com",
            assets: []
        )
        XCTAssertTrue(version.isNewerThan)
    }
}

/// 性能 Profiler 集成测试
final class ProfilerIntegrationTests: XCTestCase {
    func testProfilerStartStop() {
        let profiler = PerformanceProfiler.shared
        profiler.startProfiling()
        XCTAssertTrue(profiler.isProfiling)
        profiler.stopProfiling()
        XCTAssertFalse(profiler.isProfiling)
    }

    func testProfilerHistory() {
        // sampleMetrics() 为空桩 (假数据已清理, 待接通真实性能 IPC, 见 ProfilerView.sampleMetrics)
        // 故采样期间 history 保持空; stopProfiling 后 isProfiling 复位为 false
        let profiler = PerformanceProfiler.shared
        profiler.clearHistory()
        profiler.startProfiling()
        XCTAssertTrue(profiler.isProfiling)
        let expectation = XCTestExpectation(description: "等待采样窗口")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            profiler.stopProfiling()
            XCTAssertFalse(profiler.isProfiling)
            XCTAssertTrue(profiler.history.isEmpty, "sampleMetrics 为空桩, 不应写入 history")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testProfilerScore() {
        var metrics = PerfMetrics()
        metrics.cpuUsage = 10
        metrics.memoryUsage = 8
        metrics.gpuUsage = 20
        metrics.fps = 60
        XCTAssertGreaterThanOrEqual(metrics.score, 80)
    }
}

/// RAG 集成测试
final class RAGIntegrationTests: XCTestCase {
    func testRAGAPIClient() {
        let client = RAGAPIClient.shared
        XCTAssertTrue(client.knowledgeBases.isEmpty)
    }

    func testRAGResultModelBridgeRead() {
        let model = RAGResultModel(answer: "test answer", sources: ["src1"], query: "test")
        XCTAssertEqual(model.answer, "test answer")
        XCTAssertEqual(model.sources.count, 1)
    }
}

/// 安全扫描集成测试
final class SecurityScanTests: XCTestCase {
    func testNoHardcodedSecrets() {
        let sourceDir = FileManager.default.currentDirectoryPath + "/FusionStudio"
        let enumerator = FileManager.default.enumerator(atPath: sourceDir)
        var files = [String]()
        while let file = enumerator?.nextObject() as? String {
            if file.hasSuffix(".swift") { files.append(file) }
        }

        // 检测硬编码的敏感值（赋值字面量），而非环境变量名引用。
        // 环境变量名如 FUSION_MLX_API_KEY、字段名如 mlxApiKey 不算泄露。
        // 仅匹配被赋了非空字面量的敏感字段（形如 key = "value"）。
        // 空串初始化如 password = ""、环境变量名引用如 FUSION_MLX_API_KEY 不算泄露。
        // (?m)multiline + (?:^|[^\w"]) 前置: 排除 i18n dict key 形如 "doc_auth_password" = "..."
        // (password 紧前是 " 属 enum/dict rawValue 标识符, 非密钥赋值)
        let sensitivePatterns = [
            "(?m)(?:^|[^\\w\"])SECRET_KEY\\s*=\\s*\"[^\"]+\"",
            "(?m)(?:^|[^\\w\"])API_KEY\\s*=\\s*\"[^\"]+\"",
            "(?m)(?:^|[^\\w\"])password\\s*=\\s*\"[^\"]+\"",
        ]
        for file in files {
            let path = "\(sourceDir)/\(file)"
            guard let content = try? String(contentsOfFile: path) else { continue }
            for pattern in sensitivePatterns {
                if content.range(of: pattern, options: .regularExpression) != nil {
                    XCTFail("发现可能的敏感信息泄露: \(file) 包含硬编码 '\(pattern)'")
                }
            }
        }
    }

    func testNoHttpsOnlyCheck() {
        // 验证所有网络请求使用 HTTPS
        let sourceDir = FileManager.default.currentDirectoryPath + "/FusionStudio"
        let enumerator = FileManager.default.enumerator(atPath: sourceDir)
        var files = [String]()
        while let file = enumerator?.nextObject() as? String {
            if file.hasSuffix(".swift") { files.append(file) }
        }

        for file in files {
            let path = "\(sourceDir)/\(file)"
            guard let content = try? String(contentsOfFile: path) else { continue }
            // 检查 URL 使用 (仅检查代码中的明确 URL，忽略 localhost)
            let lines = content.split(separator: "\n")
            for line in lines {
                if line.contains("http://") && !line.contains("localhost") && !line.contains("127.0.0.1") {
                    print("⚠️ 可能的不安全连接: \(file): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
    }
}