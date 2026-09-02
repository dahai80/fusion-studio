import SwiftUI

// Callers: App entry point. API: adds ScreenContextManager StateObject. Schemas: none.
// Note: SandboxManager removed (dead code, 0 spawn 门控调用; 假沙箱开关已删, FATAL-3).

import SwiftUI
import os.log

private let appLog = Logger(subsystem: "com.fusion.studio", category: "FusionStudioApp")

@main
struct FusionStudioApp: App {
    @Environment(\.scenePhase) private var scenePhase
    // F-A5: AppState 拆 4 域子对象, 各独立 @StateObject + .environmentObject 注入。
    // AppState 持同一子对象实例保单例一致 (init 传入), 消费方按需 @EnvironmentObject 取子对象。
    @StateObject private var navState = NavigationState()
    @StateObject private var uiPanelState = UIPanelState()
    @StateObject private var healthState = HealthState()
    @StateObject private var themeState = ThemeState()
    @StateObject private var appState: AppState
    @StateObject private var ipcClient = IPCClient()
    @StateObject private var agentBridge = AgentBridge()
    @StateObject private var taskManager = TaskManager()
    @StateObject private var screenContext = ScreenContextManager()
    @StateObject private var multiNodeEngine = MultiNodeEngine()
    @StateObject private var designBridge = DesignBridge()
    @StateObject private var streamingBridge = StreamingBridge()
    @StateObject private var chatStore = ChatSessionStore()
    // Callers: FusionStudioApp body; Affected API: deskBridge injected via .environmentObject, used by DeskView 8-tab IPC architecture; Data schemas: DeskBridge models; User instruction: "对功能和api进行全量分析检测，看是否都在fusion-studio都有对应的GUI，如果没有需要立即补充GUI"
    @StateObject private var deskBridge = DeskBridge()
    // Callers: FusionStudioApp.onAppear (ensureCriticalRunning on launch), UpstreamServiceStatusView (@EnvironmentObject).
    // Affected API: upstreamManager injected via .environmentObject; ensureCriticalRunning() called in onAppear.
    // Data schemas: UpstreamServiceManager (ObservableObject) -> [UpstreamService].
    // User instruction: "在所有依赖的上游模块根目录创建start.sh，在fusion-studio启动时需要检测上游服务是否启动，如果没有启动，尝试调用start.sh启动上游服务，如果启动不成功，fusion-studio要展示服务不存在，或者服务启动失败等等"
    @StateObject private var upstreamManager = UpstreamServiceManager()
    // Callers: WelcomeView (@EnvironmentObject); Affected API: MlxHTTPClient HTTP admin client for fusion-mlx /admin/api/*; Data schemas: MlxModelDTO; User instruction: "你首先把这部分复用过来"
    @StateObject private var mlxHTTP = MlxHTTPClient(config: FusionConfig.shared)
    @StateObject private var scienceBridge = ScienceBridge()
    @StateObject private var scienceSSE = ScienceSSEClient()
    @StateObject private var financeBridge = FinanceBridge()
    // Callers: FusionStudioApp body; SimulationWorkbenchView (@EnvironmentObject).
    // Affected API: simulationBridge injected via .environmentObject; HTTP to fusion-sim :11455 /api/*.
    // Data schemas: SimulationBridge (ObservableObject) -> SimStatusDTO et al. User instruction: "和~/fusion/fuison-simulation项目集成起来"
    @StateObject private var simulationBridge = SimulationBridge()
    @StateObject private var healthBridge = HealthBridge()
    // Callers: FusionStudioApp body; DouyinOperationView (@EnvironmentObject).
    // Affected API: douyinOperationBridge injected via .environmentObject; reads fusion-operation out/ops + IPC graph.execute。
    // Data schemas: DouyinOperationBridge (ObservableObject) -> DouyinQueueCounts/WinningPatterns/StatsSnapshot. Phase 4 GUI。
    @StateObject private var douyinOperationBridge = DouyinOperationBridge()

    // Callers: FusionStudioApp body, TrainerView (@EnvironmentObject).
    // Affected API: trainerBridge injected via .environmentObject; trainer.* IPC via IPCClient → fusion-agent-studio TrainerDispatcher → fusion-trainer RunManager.
    // Data schemas: TrainerRun/TrainerPreset/TrainerDataset/TrainerAdapter/TrainerProgressEvent. User instruction: "continue Task" — Task #5 (#175)
    @StateObject private var trainerBridge = TrainerBridge()
    // Callers: FusionStudioApp body, SpeechView (@EnvironmentObject).
    // Affected API: speechBridge injected via .environmentObject; speech.* UDS JSON-RPC via IPCClient.udsCall → fusion-speech daemon (~/.fusion-speech/run/fusion-speech.sock)。
    // Data schemas: SpeechStatus/SpeechTranscribeResult/SpeechSynthesizeResult/SpeechModelsResult。#337。
    // 守护缺席 = isDaemonReady=false 优雅降级 (非崩溃), 麦克风权限独立请求。
    @StateObject private var speechBridge = SpeechBridge()
    // #344: fusion-guard 零信任动作鉴权守护 (UDS /tmp/fusion-guard.sock)。
    // 守护缺席 = isDaemonReady=false 优雅降级 (fail-open 普通工作流非全瘫), 已装 fail-closed 高危拦截。
    // L3 走 GuardChallengeModal 人机确认, L4 直接 guardBlocked 无弹窗。TCC 审计上报 fire-and-forget。
    @StateObject private var guardBridge = GuardBridge()
    // #346: fusion-event 感知层守护 (UDS /tmp/fusion-event.sock, NDJSON 长连接)。
    // 守护缺席 = isDaemonReady=false 优雅降级 (fail-open), FileWatcher 兜底 live-reload。
    // event.notification push → SystemEvent, event.heartbeat → event.pong, 断线 5s 重连。
    @StateObject private var eventBridge = EventBridge()

    init() {
        // F-A5: AppState 持 4 域子对象同一实例 (init 传入), 保单例一致。
        let nav = NavigationState()
        let ui = UIPanelState()
        let health = HealthState()
        let theme = ThemeState()
        _navState = StateObject(wrappedValue: nav)
        _uiPanelState = StateObject(wrappedValue: ui)
        _healthState = StateObject(wrappedValue: health)
        _themeState = StateObject(wrappedValue: theme)
        _appState = StateObject(wrappedValue: AppState(navState: nav, uiPanelState: ui, healthState: health, themeState: theme))
        // Dock 图标延后到 onAppear 中设置，init 阶段 NSApp 尚未就绪
    }

    private func setupDockIcon() {
        if let appIconPath = Bundle.main.path(forResource: "AppIconLight", ofType: "png"),
           let appIcon = NSImage(contentsOfFile: appIconPath) {
            appIcon.size = NSSize(width: 128, height: 128)
            NSApp.applicationIconImage = appIcon
        }
    }

    var body: some Scene {
        WindowGroup("Fusion Studio") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(navState)
                .environmentObject(uiPanelState)
                .environmentObject(healthState)
                .environmentObject(themeState)
                .environmentObject(ipcClient)
                .environmentObject(agentBridge)
                .environmentObject(taskManager)
                .environmentObject(screenContext)
                .environmentObject(multiNodeEngine)
                .environmentObject(designBridge)
                .environmentObject(streamingBridge)
                .environmentObject(chatStore)
                .environmentObject(deskBridge)
                .environmentObject(upstreamManager)
                .environmentObject(mlxHTTP)
                .environmentObject(scienceBridge)
                .environmentObject(scienceSSE)
                .environmentObject(financeBridge)
                .environmentObject(simulationBridge)
                .environmentObject(healthBridge)
                .environmentObject(douyinOperationBridge)
                .environmentObject(trainerBridge)
                .environmentObject(speechBridge)
                .environmentObject(guardBridge)
                .environmentObject(eventBridge)
                .studioThemed()
                .onAppear {
                    // 启动时检测并按需自动启动上游关键服务（mlx -> agent-studio -> artifacts-engine）。
                    // 非阻塞：IPCClient 会每 3s 自动重连，agent-studio 拉起 socket 后即可连上。
                    Task { await upstreamManager.ensureCriticalRunning() }
                    // 首次启动三档模型未配置时弹出引导（复用自 fusion-mac onboarding）
                    if FusionConfig.shared.mlxModelSmall.isEmpty {
                        uiPanelState.showWelcome = true
                    }
                    agentBridge.setIPCClient(ipcClient)
                    // Callers: FusionStudioApp.onAppear; Affected API: designBridge.ingestDesignTokens (RAG);
                    // Data schemas: design token doc string → knowledge.ingest scope=design:tokens
                    // User instruction: "continue" — Task #35 design RAG
                    designBridge.setIPCClient(ipcClient)
                    Task { await designBridge.ingestDesignTokens() }
                    ContextAssembler.shared.setIPCClient(ipcClient)
                    FusionProjectManager.shared.setIPCClient(ipcClient)
                    ipcClient.connect()
                    streamingBridge.connect()
                    // Callers: FusionStudioApp.init → wires FusionCodeAPIClient into ChatSessionStore. Affected API: chatStore.setFusionCodeClient. Data: FusionCodeAPIClient(baseURL: fusionCodeURL).
                    chatStore.setIPCClient(ipcClient)
                    chatStore.setAgentBridge(agentBridge)
                    chatStore.setFusionCodeBridge(FusionCodeBridge.shared)
                    deskBridge.setIPCClient(ipcClient)
                    trainerBridge.setIPCClient(ipcClient)
                    // #337: 注入 IPCClient + 启动时探 fusion-speech 守护状态 (缺席=优雅降级非崩溃)。
                    speechBridge.setIPCClient(ipcClient)
                    Task { await speechBridge.checkDaemonStatus() }
                    // #344: 注入 IPCClient + 探 fusion-guard 守护状态 + 注入 AgentBridge/SpeechBridge/GuardBridge.shared。
                    // 守护缺席 = isDaemonReady=false (fail-open), 已装 fail-closed 高危拦截。TCC 上报走 shared 单例便捷路径。
                    guardBridge.setIPCClient(ipcClient)
                    Task { await guardBridge.checkDaemonStatus() }
                    agentBridge.setGuardBridge(guardBridge)
                    GuardBridge.shared = guardBridge
                    // #373: 规则 CRUD 委托 guard UDS (SecurityView 走 SecurityBridge.shared 单例)。
                    SecurityBridge.shared.guardBridge = guardBridge
                    // #346: 注入 IPCClient + 探 fusion-event 守护状态 + 启动长连接流 + EventBridge.shared。
                    // 守护缺席 = isDaemonReady=false (fail-open), FileWatcher 兜底。规则管理走 udsCall 短连接。
                    eventBridge.setIPCClient(ipcClient)
                    Task {
                        await eventBridge.checkDaemonStatus()
                        await eventBridge.listRules()
                        eventBridge.startStream()
                    }
                    EventBridge.shared = eventBridge
                    ArtifactSidebarCache.shared.configure(ipcClient: ipcClient)
                    Task {
                        await performStartupHealthCheck()
                    }
                    // F-ops-4: 启动按需检查更新, 受 allowUpdateCheck 开关控制 (Settings 默认 ON)。
                    // 非强制: 复用 AutoUpdateManager 内置 1h 节流, 避免每次唤起都打 GitHub API。
                    if FusionConfig.shared.allowUpdateCheck {
                        AutoUpdateManager.shared.checkForUpdates()
                    }
                    // F-R13: 启动进程内 RSS 监控, 软阈值告警 + 日志, 防 @Published/长会话 OOM 静默。
                    // critical 阈值 (>3GB) 触发注册的 eviction 回调清无界 @Published 数组 LRU。
                    StudioMemoryMonitor.shared.start()
                    // F-I6: 启动清理统一临时目录 ~/.fusion-studio/tmp/ 陈旧 (>3d) + LRU 总大小超限 (>200MB)。
                    // 防崩溃残留 (defer 跑不到) 累积占盘 + 文件名含项目路径泄露。
                    FusionTempDir.shared.cleanupStale()
                    StudioMemoryMonitor.shared.registerEviction(name: "streamEvents") { [weak streamingBridge] in
                        let before = streamingBridge?.streamEvents.count ?? 0
                        if before > 100 {
                            streamingBridge?.streamEvents = Array((streamingBridge?.streamEvents ?? []).suffix(100))
                            return before - 100
                        }
                        return 0
                    }
                    StudioMemoryMonitor.shared.registerEviction(name: "events") { [weak agentBridge] in
                        let before = agentBridge?.runtimeState.events.count ?? 0
                        if before > 200 {
                            agentBridge?.runtimeState.events = Array((agentBridge?.runtimeState.events ?? []).suffix(200))
                            return before - 200
                        }
                        return 0
                    }
                    // 审计0827 §2.7 (P1): AgentBridge 7 域 30+ 无界 @Published 数组 + ChatSessionStore/Health/Science
                    // 高频 append 已逐点 cap (capAgents/tasks/ragResults/chatMessages/capSessions/capMessages),
                    // 但 cap 是 append 时软限; RSS critical 硬压需额外 eviction 兜底 (留 1/2 保留近期, 丢最早)。
                    StudioMemoryMonitor.shared.registerEviction(name: "agents") { [weak agentBridge] in
                        let before = agentBridge?.agentState.agents.count ?? 0
                        if before > 100 {
                            agentBridge?.agentState.agents = Array((agentBridge?.agentState.agents ?? []).suffix(100))
                            return before - 100
                        }
                        return 0
                    }
                    StudioMemoryMonitor.shared.registerEviction(name: "tasks") { [weak agentBridge] in
                        let before = agentBridge?.taskState.tasks.count ?? 0
                        if before > 200 {
                            agentBridge?.taskState.tasks = Array((agentBridge?.taskState.tasks ?? []).suffix(200))
                            return before - 200
                        }
                        return 0
                    }
                    StudioMemoryMonitor.shared.registerEviction(name: "chatMessages") { [weak agentBridge] in
                        let before = agentBridge?.projectChatState.chatMessages.count ?? 0
                        if before > 200 {
                            agentBridge?.projectChatState.chatMessages = Array((agentBridge?.projectChatState.chatMessages ?? []).suffix(200))
                            return before - 200
                        }
                        return 0
                    }
                    StudioMemoryMonitor.shared.registerEviction(name: "chatSessions") { [weak chatStore] in
                        let before = chatStore?.sessions.count ?? 0
                        if before > 100 {
                            chatStore?.sessions = Array((chatStore?.sessions ?? []).suffix(100))
                            return before - 100
                        }
                        return 0
                    }
                    StudioMemoryMonitor.shared.registerEviction(name: "healthChat") { [weak healthBridge] in
                        let before = healthBridge?.chatMessages.count ?? 0
                        if before > 200 {
                            healthBridge?.chatMessages = Array((healthBridge?.chatMessages ?? []).suffix(200))
                            return before - 200
                        }
                        return 0
                    }
                    StudioMemoryMonitor.shared.registerEviction(name: "scienceChat") { [weak scienceBridge] in
                        let before = scienceBridge?.messages.count ?? 0
                        if before > 200 {
                            scienceBridge?.messages = Array((scienceBridge?.messages ?? []).suffix(200))
                            return before - 200
                        }
                        return 0
                    }
                }
                .frame(minWidth: 1100, minHeight: 700)
                .sheet(isPresented: $uiPanelState.showWelcome) {
                    WelcomeView(onFinish: { uiPanelState.showWelcome = false })
                        .environmentObject(mlxHTTP)
                        .environmentObject(agentBridge)
                        .environmentObject(upstreamManager)
                        .environmentObject(ipcClient)
                }
                .onAppear {
                    setupDockIcon()
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    // F-A9: 启动即开始 MultiNode 轮询 (scenePhase onChange 不在首渲触发)。
                    multiNodeEngine.startPolling()
                    // F-A2子3: MLX 池可见性轮询, 复用 F-A9 scenePhase 模式。
                    agentBridge.startMlxStatusPolling()
                }
                // HIGH-4: app 进后台或退出时终止遗留 screencapture 进程, 防孤儿。
                // F-A9: MultiNode 轮询提升到 App 级生命周期 — active 常驻, 后台降频/停转。
                // 旧设计绑 8 叶子 View onAppear/onDisappear, 离开 MultiNode tab 即停, 其他子 View 拿死数据。
                .onChange(of: scenePhase) { phase in
                    if phase == .background || phase == .inactive {
                        ScreenCapture.shared.cleanup()
                        multiNodeEngine.stopPolling()
                        agentBridge.stopMlxStatusPolling()
                        // 审计0827 P0-3: 后台停长连接流, 释放 fd + 取消 readLoop Task,
                        // 防 fd/Task 泄漏 (旧: 后台不断, 退出亦无调用 stopStream)。
                        eventBridge.stopStream()
                        // 审计0830 P1-资源-5: ScreenContext 2s Accessibility 轮询未绑 scenePhase,
                        //   app 后台仍轮询 → 耗电 + 后台读 Accessibility 隐私风险。后台停, 唤醒恢复。
                        screenContext.stopMonitoring()
                    } else if phase == .active {
                        multiNodeEngine.startPolling()
                        agentBridge.startMlxStatusPolling()
                        // 审计0830 P1-资源-5: 唤醒恢复 ScreenContext 监控 (后台已停)。
                        screenContext.startMonitoring()
                        // #346: 感知层长连接在唤醒后恢复 (后台/休眠可能断 UDS), 守护缺席 fail-open 不锁死。
                        eventBridge.startStream()
                        Task { await eventBridge.checkDaemonStatus() }
                        // #372 OPS-13: 进入前台触发 WASM 日志 dump (5min 节流), 持久化上次前台段环形缓冲。
                        if FdHostWebLogCapture.shared.triggerForegroundDump() {
                            designBridge.dumpWasmLog(clear: false)
                        }
                    }
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Fusion Studio") {
                    uiPanelState.showAboutPanel = true
                }
            }
            CommandGroup(replacing: .help) {
                Button("Fusion Studio Help") {
                    uiPanelState.showHelp = true
                }
            }
            CommandGroup(after: .toolbar) {
                Button("Health Check") {
                    Task { await performStartupHealthCheck() }
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                Button("Toggle Sidebar") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        uiPanelState.isSidebarCollapsed.toggle()
                    }
                }
                .keyboardShortcut("\\", modifiers: [.command])

                Button("Toggle Inspector") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        uiPanelState.isInspectorVisible.toggle()
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Next Sheet") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        let sheets = ProductSheet.allCases
                        if let idx = sheets.firstIndex(of: navState.selectedSheet),
                           idx + 1 < sheets.count {
                            navState.selectedSheet = sheets[idx + 1]
                        } else {
                            navState.selectedSheet = sheets[0]
                        }
                    }
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .control])

                Button("Previous Sheet") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        let sheets = ProductSheet.allCases
                        if let idx = sheets.firstIndex(of: navState.selectedSheet),
                           idx > 0 {
                            navState.selectedSheet = sheets[idx - 1]
                        } else {
                            navState.selectedSheet = sheets[sheets.count - 1]
                        }
                    }
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .control])
            }
        }
    }

    private func performStartupHealthCheck() async {
        healthState.healthStatus = .checking
        // app 复用外部 mlx(11432)：直接 HTTP 探活，无需本地 MLX 进程 IPC。
        // 重试 ~10s 覆盖启动竞态，最终必收敛到 healthy/issuesFound，不再滞留 .checking (bug3/bug8)。
        let maxAttempts = 5
        var mlxOk = false
        for attempt in 1...maxAttempts {
            mlxOk = await agentBridge.probeMLXRunningStatus()
            appLog.info("performStartupHealthCheck: attempt=\(attempt) mlxOk=\(mlxOk)")
            if mlxOk { break }
            if attempt < maxAttempts {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }

        await MainActor.run {
            healthState.isHealthCheckPassed = mlxOk
            // 审计0830 P1-架构-1: MLXState.mlxRunning 为单一真相源 (probeMLXRunningStatus 已写)。
            //   HealthState.isMLXRunning 仅作镜像保 view 观测 (view 观察 healthState 非 bridge)。
            //   双源同步防脑裂: 一条 UI 显示 running 一条 offline。
            agentBridge.mlxState.mlxRunning = mlxOk
            healthState.isMLXRunning = agentBridge.mlxState.mlxRunning
            healthState.healthStatus = mlxOk ? .healthy : .issuesFound
        }

        if !mlxOk {
            appLog.error("performStartupHealthCheck: mlx unreachable after \(maxAttempts) attempts")
            return
        }

        // MLX 可达后，若用户未配置默认对话模型，从 /api/status 取已加载模型自动填充，
        // 避免各模块发送 chat 请求时 model 字段为空被 MLX 400 拒绝（Design/Chat 提交无反应根因）。
        await autoPickDefaultModel()
    }

    // 从 MLX /api/status 读取已加载模型，填入 mlxModel 作为通用默认对话模型。
    // 优先 default_model，其次 loaded_models 第一个。
    private func autoPickDefaultModel() async {
        let cfg = FusionConfig.shared
        if !cfg.mlxModel.isEmpty {
            appLog.info("autoPickDefaultModel: mlxModel already set, skip")
            return
        }
        guard let url = URL(string: "\(cfg.mlxBaseURL)/api/status") else { return }
        do {
            var req = URLRequest(url: url)
            req.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
            req.setValue("Bearer \(cfg.mlxResolvedApiKey)", forHTTPHeaderField: "Authorization")
            req.timeoutInterval = 8
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                appLog.warning("autoPickDefaultModel: /api/status parse failed")
                return
            }
            let defaultModel = json["default_model"] as? String
            let loaded = json["loaded_models"] as? [String] ?? []
            let pick = (defaultModel?.isEmpty == false ? defaultModel : nil) ?? loaded.first
            guard let model = pick, !model.isEmpty else {
                appLog.warning("autoPickDefaultModel: no default/loaded model available")
                return
            }
            await MainActor.run {
                cfg.mlxModel = model
                appLog.info("autoPickDefaultModel: set mlxModel=\(model, privacy: .public)")
            }
        } catch {
            appLog.warning("autoPickDefaultModel: /api/status unreachable: \(error.localizedDescription)")
        }
    }
}