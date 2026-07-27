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
        XCTAssertNotNil(client.lastError)
    }
}

final class AppStateTests: XCTestCase {
    func testDefaultModule() {
        let state = AppState()
        XCTAssertEqual(state.selectedModule, .dashboard)
    }

    func testInitialHealthStatus() {
        let state = AppState()
        XCTAssertEqual(state.healthStatus, .checking)
    }

    func testModuleIcons() {
        XCTAssertEqual(Module.dashboard.icon, "square.grid.2x2")
        XCTAssertEqual(Module.design.icon, "pencil.and.outline")
        XCTAssertEqual(Module.code.icon, "chevron.left.forwardslash.chevron.right")
        XCTAssertEqual(Module.simulation.icon, "gearshape.2")
        XCTAssertEqual(Module.modelHub.icon, "cpu")
        XCTAssertEqual(Module.cli.icon, "terminal")
        XCTAssertEqual(Module.doc.icon, "doc.text")
        XCTAssertEqual(Module.kb.icon, "books.vertical")
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

    func testOfflineMode() {
        let config = FusionConfig.shared
        config.offlineMode = true
        XCTAssertTrue(config.isOffline)
    }

    func testMLXBaseURL() {
        let config = FusionConfig.shared
        config.mlxHost = "localhost"
        config.mlxPort = 8000
        XCTAssertEqual(config.mlxBaseURL, "http://localhost:8000")
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
        XCTAssertTrue(manager.tasks.contains { $0.id == id })
    }

    func testTaskStates() {
        let manager = TaskManager.shared
        let id = manager.submit(title: "状态测试", type: .compile)
        manager.start(id)
        XCTAssertEqual(manager.tasks.first { $0.id == id }?.status, .running)
        manager.pause(id)
        XCTAssertEqual(manager.tasks.first { $0.id == id }?.status, .paused)
        manager.resume(id)
        XCTAssertEqual(manager.tasks.first { $0.id == id }?.status, .running)
        manager.cancel(id)
        XCTAssertEqual(manager.tasks.first { $0.id == id }?.status, .cancelled)
    }

    func testTaskProgress() {
        let manager = TaskManager.shared
        let id = manager.submit(title: "进度测试", type: .download)
        manager.start(id)
        manager.updateProgress(id, progress: 0.5, label: "50%")
        let task = manager.tasks.first { $0.id == id }
        XCTAssertEqual(task?.progress, 0.5)
        XCTAssertEqual(task?.progressLabel, "50%")
    }

    func testCompleteTask() {
        let manager = TaskManager.shared
        let id = manager.submit(title: "完成测试", type: .export)
        manager.start(id)
        manager.complete(id, result: ["status": "ok"])
        let task = manager.tasks.first { $0.id == id }
        XCTAssertEqual(task?.status, .completed)
        XCTAssertEqual(task?.progress, 1.0)
    }

    func testFailTask() {
        let manager = TaskManager.shared
        let id = manager.submit(title: "失败测试", type: .simulation)
        manager.start(id)
        manager.fail(id, error: "测试错误")
        let task = manager.tasks.first { $0.id == id }
        XCTAssertEqual(task?.status, .failed)
        XCTAssertEqual(task?.errorMessage, "测试错误")
    }

    func testCounts() {
        let manager = TaskManager.shared
        manager.clearAll()
        _ = manager.submit(title: "任务1", type: .inference)
        _ = manager.submit(title: "任务2", type: .compile)
        let id3 = manager.submit(title: "任务3", type: .download)
        manager.start(id3)
        XCTAssertEqual(manager.activeCount, 1)
        XCTAssertEqual(manager.queueCount, 2)
    }
}

final class ModelInfoTests: XCTestCase {
    func testPresetCount() {
        XCTAssertEqual(ModelInfo.presets.count, 5)
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
        XCTAssertFalse(manager.logs.isEmpty)
        XCTAssertTrue(manager.autoScroll)
    }

    func testAddLog() {
        let manager = LogManager.shared
        let count = manager.logs.count
        manager.addLog(level: .info, source: "test", module: "测试", message: "测试消息")
        XCTAssertEqual(manager.logs.count, count + 1)
    }

    func testMaxLogs() {
        let manager = LogManager.shared
        // Max is 10_000, should not exceed
        for i in 0..<100 {
            manager.addLog(level: .debug, source: "test", module: "测试", message: "批量日志 \(i)")
        }
        XCTAssertLessThanOrEqual(manager.logs.count, 10_000)
    }

    func testErrorCount() {
        let manager = LogManager.shared
        manager.addLog(level: .error, source: "test", module: "测试", message: "错误测试")
        manager.addLog(level: .fatal, source: "test", module: "测试", message: "致命测试")
        XCTAssertGreaterThanOrEqual(manager.errorCount, 2)
    }

    func testClearLogs() {
        let manager = LogManager.shared
        manager.clearLogs()
        XCTAssertTrue(manager.logs.isEmpty)
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
        XCTAssertEqual(i18n.currentLanguage, .zhCN)
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
        i18n.currentLanguage = .zhCN // reset
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
        XCTAssertGreaterThanOrEqual(manager.activePluginCount, 4)
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