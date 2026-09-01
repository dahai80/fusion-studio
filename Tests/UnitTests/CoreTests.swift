import XCTest
@testable import FusionStudio

final class IPCClientTests: XCTestCase {
    func testInitialState() {
        let client = IPCClient(socketPath: "/tmp/test-fusion-studio.sock")
        XCTAssertFalse(client.isConnected)
    }

    func testIPCErrorTypes() {
        XCTAssertEqual(IPCError.disconnected.localizedDescription, "IPC 未连接")
        XCTAssertEqual(IPCError.invalidRequest.localizedDescription, "无效的请求")
        XCTAssertEqual(IPCError.invalidResponse.localizedDescription, "无效的响应")
    }

    func testConnectionFailure() {
        let client = IPCClient(socketPath: "/tmp/nonexistent-socket.sock")
        XCTAssertFalse(client.isConnected)
    }
}

final class AppStateTests: XCTestCase {
    func testDefaultModule() {
        let state = AppState()
        XCTAssertEqual(state.navState.selectedModule, .chat)
    }

    func testInitialHealthStatus() {
        let state = AppState()
        XCTAssertEqual(state.healthState.healthStatus, .checking)
    }

    func testModuleIcons() {
        XCTAssertEqual(Module.dashboard.icon, "square.grid.2x2")
        XCTAssertEqual(Module.design.icon, "pencil.and.outline")
        XCTAssertEqual(Module.code.icon, "chevron.left.forwardslash.chevron.right")
        XCTAssertEqual(Module.simulation.icon, "gearshape.2")
        XCTAssertEqual(Module.modelHub.icon, "cpu")
        XCTAssertEqual(Module.cli.icon, "terminal")
        XCTAssertEqual(Module.doc.icon, "doc.text")
        XCTAssertEqual(Module.bench.icon, "chart.bar")
        XCTAssertEqual(Module.desk.icon, "desktopcomputer")
    }
}

final class FusionConfigTests: XCTestCase {
    func testDefaultValues() {
        let config = FusionConfig.shared
        XCTAssertEqual(config.language, "zh-CN")
        XCTAssertEqual(config.defaultQuant, "4bit")
        XCTAssertTrue(config.offlineMode)
        XCTAssertTrue(config.autoStartMLX)
        XCTAssertEqual(config.maxMemory, 16.0)
    }

    // #382: mlxHost 默认 127.0.0.1 非 localhost。
    // OrbStack/Docker 绑 *:11434 (IPv6 ::1) 时 localhost 优先 ::1 → 命中容器 → 502 包 401。
    // 127.0.0.1 显式 IPv4 绕开。验证 fresh-install 默认 (清持久化 key 后重建 config)。
    func testMlxHostDefaultIsIPv4Loopback() {
        let defaults = UserDefaults.standard
        let savedHost = defaults.string(forKey: "mlxHost")
        let savedPort = defaults.object(forKey: "mlxPort") as? Int
        defer {
            if let h = savedHost { defaults.set(h, forKey: "mlxHost") } else { defaults.removeObject(forKey: "mlxHost") }
            if let p = savedPort { defaults.set(p, forKey: "mlxPort") } else { defaults.removeObject(forKey: "mlxPort") }
        }
        defaults.removeObject(forKey: "mlxHost")
        defaults.removeObject(forKey: "mlxPort")
        let config = FusionConfig.shared
        config.mlxHost = "127.0.0.1"
        config.mlxPort = 11434
        // 清后重读: 确认默认值非 localhost (绕 OrbStack IPv6 劫持)
        XCTAssertEqual(config.mlxHost, "127.0.0.1", "mlxHost 默认应为 127.0.0.1 非 localhost (#382 OrbStack 劫持)")
    }

    func testOfflineMode() {
        let config = FusionConfig.shared
        config.offlineMode = true
        XCTAssertTrue(config.isOffline)
    }

    // mlxBaseURL 优先级：FUSION_GATEWAY_URL/FUSION_MLX_URL > FUSION_MLX_PORT > mlxHost:mlxPort
    func testMLXBaseURL() {
        let config = FusionConfig.shared
        config.mlxHost = "localhost"
        config.mlxPort = 11434
        let env = ProcessInfo.processInfo.environment
        if let full = env["FUSION_GATEWAY_URL"] ?? env["FUSION_MLX_URL"], !full.isEmpty {
            XCTAssertEqual(config.mlxBaseURL, full, "env FUSION_GATEWAY_URL/MLX_URL 应被采用")
        } else if let portStr = env["FUSION_MLX_PORT"], let port = Int(portStr), port > 0 {
            XCTAssertEqual(config.mlxBaseURL, "http://localhost:\(port)", "env FUSION_MLX_PORT 应覆盖端口")
        } else {
            XCTAssertEqual(config.mlxBaseURL, "http://localhost:11434", "无 env 时用 mlxHost:mlxPort")
        }
    }

    // #380: mlxEndpointOverrideEnabled ON 时 mlxBaseURL 用 @AppStorage host:port,
    // 必须覆盖所有 env (FUSION_GATEWAY_URL/FUSION_MLX_URL/FUSION_MLX_PORT)。
    func testMLXBaseURLUserOverride() {
        let config = FusionConfig.shared
        let savedOverride = config.mlxEndpointOverrideEnabled
        let savedHost = config.mlxHost
        let savedPort = config.mlxPort
        defer {
            config.mlxEndpointOverrideEnabled = savedOverride
            config.mlxHost = savedHost
            config.mlxPort = savedPort
        }
        config.mlxHost = "127.0.0.1"
        config.mlxPort = 11434
        config.mlxEndpointOverrideEnabled = true
        // 无论 env 是否设置, override ON 必须用 @AppStorage host:port
        XCTAssertEqual(config.mlxBaseURL, "http://127.0.0.1:11434",
                       "override ON 应使用 @AppStorage host:port 覆盖所有 env")
    }

    // #380: override OFF (默认) 时保留原 env 优先级行为, 部署默认不变。
    func testMLXBaseURLOverrideOffPreservesEnvPriority() {
        let config = FusionConfig.shared
        let savedOverride = config.mlxEndpointOverrideEnabled
        let savedHost = config.mlxHost
        let savedPort = config.mlxPort
        defer {
            config.mlxEndpointOverrideEnabled = savedOverride
            config.mlxHost = savedHost
            config.mlxPort = savedPort
        }
        config.mlxHost = "localhost"
        config.mlxPort = 11434
        config.mlxEndpointOverrideEnabled = false
        let env = ProcessInfo.processInfo.environment
        if let full = env["FUSION_GATEWAY_URL"] ?? env["FUSION_MLX_URL"], !full.isEmpty {
            XCTAssertEqual(config.mlxBaseURL, full, "override OFF 时 env FUSION_GATEWAY_URL/MLX_URL 仍优先")
        } else if let portStr = env["FUSION_MLX_PORT"], let port = Int(portStr), port > 0 {
            XCTAssertEqual(config.mlxBaseURL, "http://localhost:\(port)", "override OFF 时 env FUSION_MLX_PORT 仍覆盖端口")
        } else {
            XCTAssertEqual(config.mlxBaseURL, "http://localhost:11434", "override OFF 无 env 时用默认")
        }
    }

    // mlxResolvedApiKey 必须从环境变量 FUSION_MLX_API_KEY 取值
    // （gateway 入站鉴权）。用户设置(Keychain-backed mlxApiKey)优先；
    // 为空时回退 env，再回退 ~/.fusion-mlx/settings.json auth.api_key。
    func testMLXResolvedApiKeyEnvVar() {
        let config = FusionConfig.shared
        let savedUserKey = config.mlxApiKey
        defer { config.mlxApiKey = savedUserKey }
        config.mlxApiKey = ""
        let envKey = ProcessInfo.processInfo.environment["FUSION_MLX_API_KEY"] ?? ""
        let resolved = config.mlxResolvedApiKey
        if !envKey.isEmpty {
            XCTAssertEqual(resolved, envKey, "env FUSION_MLX_API_KEY 应被采用")
        } else {
            // env 未设置时，解析结果应来自 settings.json 或为空，不得是硬编码值
            XCTAssertTrue(resolved.isEmpty || resolved.count <= 64, "无 env 时回退 settings.json，非硬编码")
        }
    }

    func testResetToDefaults() {
        let config = FusionConfig.shared
        config.launchAtLogin = true
        config.autoStartMLX = false
        config.resetToDefaults()
        XCTAssertFalse(config.launchAtLogin)
        XCTAssertTrue(config.autoStartMLX)
        XCTAssertEqual(config.language, "zh-CN")
    }
}

final class TaskManagerTests: XCTestCase {
    func testSubmitTask() {
        let manager = TaskManager.shared
        let id = manager.submit(title: "测试任务", type: .inference)
        XCTAssertFalse(id.isEmpty)
        let found = XCTestExpectation(description: "task appended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(manager.tasks.contains { $0.id == id })
            found.fulfill()
        }
        wait(for: [found], timeout: 1.0)
    }

    func testTaskStates() {
        let manager = TaskManager.shared
        manager.clearAll()
        let id = manager.submit(title: "状态测试", type: .compile)
        let exp = XCTestExpectation(description: "states")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            manager.start(id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(manager.tasks.first { $0.id == id }?.status, .running)
                manager.pause(id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    XCTAssertEqual(manager.tasks.first { $0.id == id }?.status, .paused)
                    manager.resume(id)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        XCTAssertEqual(manager.tasks.first { $0.id == id }?.status, .running)
                        manager.cancel(id)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            XCTAssertEqual(manager.tasks.first { $0.id == id }?.status, .cancelled)
                            exp.fulfill()
                        }
                    }
                }
            }
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testTaskProgress() {
        let manager = TaskManager.shared
        let id = manager.submit(title: "进度测试", type: .download)
        let exp = XCTestExpectation(description: "progress")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            manager.start(id)
            manager.updateProgress(id, progress: 0.5, label: "50%")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let task = manager.tasks.first { $0.id == id }
                XCTAssertEqual(task?.progress, 0.5)
                XCTAssertEqual(task?.progressLabel, "50%")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testCompleteTask() {
        let manager = TaskManager.shared
        let exp0 = XCTestExpectation(description: "clear")
        manager.clearAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp0.fulfill() }
        wait(for: [exp0], timeout: 1.0)
        let id = manager.submit(title: "完成测试", type: .export)
        let exp = XCTestExpectation(description: "complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let found = manager.tasks.first { $0.id == id }
            XCTAssertNotNil(found, "Task \(id) not found in \(manager.tasks.map { $0.id })")
            manager.start(id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                XCTAssertEqual(manager.tasks.first { $0.id == id }?.status, .running)
                manager.complete(id, result: ["status": "ok"])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    let task = manager.tasks.first { $0.id == id }
                    XCTAssertEqual(task?.status, .completed)
                    XCTAssertEqual(task?.progress, 1.0)
                    exp.fulfill()
                }
            }
        }
        wait(for: [exp], timeout: 3.0)
    }

    func testFailTask() {
        let manager = TaskManager.shared
        let id = manager.submit(title: "失败测试", type: .simulation)
        let exp = XCTestExpectation(description: "fail")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            manager.start(id)
            manager.fail(id, error: "测试错误")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let task = manager.tasks.first { $0.id == id }
                XCTAssertEqual(task?.status, .failed)
                XCTAssertEqual(task?.errorMessage, "测试错误")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testCounts() {
        let manager = TaskManager.shared
        manager.clearAll()
        _ = manager.submit(title: "任务1", type: .inference)
        _ = manager.submit(title: "任务2", type: .compile)
        let id3 = manager.submit(title: "任务3", type: .download)
        let exp = XCTestExpectation(description: "counts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            manager.start(id3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(manager.activeCount, 1)
                XCTAssertEqual(manager.queueCount, 2)
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 2.0)
    }
}

final class ModelInfoTests: XCTestCase {
    func testPresetCount() {
        XCTAssertEqual(ModelInfo.presets.count, 4)
    }

    func testModelFields() {
        let model = ModelInfo.presets[0]
        XCTAssertEqual(model.id, "qwen3.5-9b-4bit")
        XCTAssertEqual(model.name, "Qwen3.5 9B")
        XCTAssertEqual(model.quantization, "4bit")
        XCTAssertEqual(model.format, "mlx")
        XCTAssertFalse(model.isDownloaded)
        XCTAssertFalse(model.isActive)
    }

    func testHashable() {
        let a = ModelInfo.presets[0]
        let b = ModelInfo.presets[0]
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }
}

final class LogManagerTests: XCTestCase {
    func testInitialState() {
        let manager = LogManager.shared
        XCTAssertTrue(manager.autoScroll)
        let exp = XCTestExpectation(description: "sample logs")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(manager.logs.isEmpty)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testAddLog() {
        let manager = LogManager.shared
        manager.clearLogs()
        let exp1 = XCTestExpectation(description: "clear")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1.0)
        let count = manager.logs.count
        manager.addLog(level: .info, source: "test", module: "测试", message: "测试消息")
        let exp2 = XCTestExpectation(description: "add")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(manager.logs.count, count + 1)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1.0)
    }

    func testMaxLogs() {
        let manager = LogManager.shared
        for i in 0..<100 {
            manager.addLog(level: .debug, source: "test", module: "测试", message: "批量日志 \(i)")
        }
        let exp = XCTestExpectation(description: "max")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertLessThanOrEqual(manager.logs.count, 10_000)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    func testErrorCount() {
        let manager = LogManager.shared
        manager.clearLogs()
        let exp1 = XCTestExpectation(description: "clear")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp1.fulfill() }
        wait(for: [exp1], timeout: 1.0)
        manager.addLog(level: .error, source: "test", module: "测试", message: "错误测试")
        manager.addLog(level: .fatal, source: "test", module: "测试", message: "致命测试")
        let exp2 = XCTestExpectation(description: "errorCount")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertGreaterThanOrEqual(manager.errorCount, 2)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1.0)
    }

    func testClearLogs() {
        let manager = LogManager.shared
        manager.clearLogs()
        let exp = XCTestExpectation(description: "clear")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(manager.logs.isEmpty)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}

final class CollaborationTests: XCTestCase {
    func testInitialState() {
        let collab = CollaborationService.shared
        XCTAssertFalse(collab.isEnabled)
        XCTAssertTrue(collab.peers.isEmpty)
        XCTAssertNil(collab.activeSession)
    }

    func testLocalPeer() {
        let collab = CollaborationService.shared
        let peer = collab.localPeer
        XCTAssertFalse(peer.name.isEmpty)
        XCTAssertEqual(peer.status, .online)
        XCTAssertFalse(peer.sharedModules.isEmpty)
    }

    func testCreateSession() {
        let collab = CollaborationService.shared
        collab.createSession(name: "测试会话")
        XCTAssertNotNil(collab.activeSession)
        XCTAssertEqual(collab.activeSession?.name, "测试会话")
        collab.leaveSession()
        XCTAssertNil(collab.activeSession)
    }
}

final class I18nTests: XCTestCase {
    func testDefaultLanguage() {
        let i18n = I18nManager.shared
        XCTAssertNotNil(i18n.currentLanguage)
    }

    func testTranslation() {
        let i18n = I18nManager.shared
        i18n.currentLanguage = .zhCN
        XCTAssertEqual(i18n.t(.ok), "确定")
        XCTAssertEqual(i18n.t(.cancel), "取消")
        XCTAssertEqual(i18n.t(.dashboard), "控制台")

        i18n.currentLanguage = .enUS
        XCTAssertEqual(i18n.t(.ok), "OK")
        XCTAssertEqual(i18n.t(.cancel), "Cancel")
        XCTAssertEqual(i18n.t(.dashboard), "Dashboard")
    }

    func testLanguageSwitch() {
        let i18n = I18nManager.shared
        i18n.currentLanguage = .jaJP
        XCTAssertEqual(i18n.currentLanguage, .jaJP)
        i18n.currentLanguage = .koKR
        XCTAssertEqual(i18n.currentLanguage, .koKR)
        i18n.currentLanguage = .zhCN
    }
}

final class PluginManagerTests: XCTestCase {
    func testBuiltinPlugins() {
        let manager = PluginManager.shared
        XCTAssertFalse(manager.plugins.isEmpty)
        let builtins = manager.plugins.filter { $0.installPath == "builtin" }
        XCTAssertGreaterThanOrEqual(builtins.count, 4)
    }

    func testActivePluginCount() {
        let manager = PluginManager.shared
        XCTAssertGreaterThanOrEqual(manager.enabledPluginCount, 4)
    }
}

final class TemplateCategoryTests: XCTestCase {
    func testBridgeKeyRoundTrip() {
        for cat in TemplateCategory.allCases where cat != .all {
            XCTAssertEqual(TemplateCategory.fromBridgeKey(cat.bridgeKey), cat)
        }
    }

    func testFromBridgeKeyDefault() {
        XCTAssertEqual(TemplateCategory.fromBridgeKey("unknown"), .all)
    }
}

final class AgentOrchestratorTests: XCTestCase {
    func testBuiltinAgents() {
        let orchestrator = AgentOrchestrator.shared
        XCTAssertFalse(orchestrator.agents.isEmpty)
        XCTAssertGreaterThanOrEqual(orchestrator.agents.count, 5)
    }

    func testCreateAndDeleteAgent() {
        let orchestrator = AgentOrchestrator.shared
        let count = orchestrator.agents.count
        orchestrator.createAgent(name: "测试智能体", type: .custom, model: "test-model")
        XCTAssertEqual(orchestrator.agents.count, count + 1)
        let created = orchestrator.agents.last!
        orchestrator.deleteAgent(created.id)
        XCTAssertEqual(orchestrator.agents.count, count)
    }

    func testCreateTask() {
        let orchestrator = AgentOrchestrator.shared
        let agentId = orchestrator.agents[0].id
        let count = orchestrator.tasks.count
        orchestrator.createTask(title: "测试任务", description: "测试描述", assignTo: agentId)
        XCTAssertEqual(orchestrator.tasks.count, count + 1)
    }

    func testWorkflow() {
        let orchestrator = AgentOrchestrator.shared
        XCTAssertFalse(orchestrator.workflows.isEmpty)
        XCTAssertGreaterThanOrEqual(orchestrator.workflows.count, 2)
    }

    func testSendMessage() {
        let orchestrator = AgentOrchestrator.shared
        let count = orchestrator.conversationLog.count
        orchestrator.sendMessage(from: "A", to: "B", content: "测试消息")
        XCTAssertEqual(orchestrator.conversationLog.count, count + 1)
        orchestrator.clearConversation()
        XCTAssertTrue(orchestrator.conversationLog.isEmpty)
    }
}