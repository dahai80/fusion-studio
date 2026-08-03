import SwiftUI

// Callers: App entry point. API: adds SandboxManager + ScreenContextManager StateObjects. Schemas: none.
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import SwiftUI
import os.log

private let appLog = Logger(subsystem: "com.fusion.studio", category: "FusionStudioApp")

@main
struct FusionStudioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var ipcClient = IPCClient()
    @StateObject private var agentBridge = AgentBridge()
    @StateObject private var taskManager = TaskManager()
    @StateObject private var sandboxManager = SandboxManager()
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

    init() {
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
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(ipcClient)
                .environmentObject(agentBridge)
                .environmentObject(taskManager)
                .environmentObject(sandboxManager)
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
                .studioThemed()
                .onAppear {
                    // 启动时检测并按需自动启动上游关键服务（mlx -> agent-studio -> artifacts-engine）。
                    // 非阻塞：IPCClient 会每 3s 自动重连，agent-studio 拉起 socket 后即可连上。
                    Task { await upstreamManager.ensureCriticalRunning() }
                    // 首次启动三档模型未配置时弹出引导（复用自 fusion-mac onboarding）
                    if FusionConfig.shared.mlxModelSmall.isEmpty {
                        appState.showWelcome = true
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
                    ArtifactSidebarCache.shared.configure(ipcClient: ipcClient)
                    Task {
                        await performStartupHealthCheck()
                    }
                }
                .frame(minWidth: 1100, minHeight: 700)
                .sheet(isPresented: $appState.showWelcome) {
                    WelcomeView(onFinish: { appState.showWelcome = false })
                        .environmentObject(mlxHTTP)
                        .environmentObject(agentBridge)
                        .environmentObject(upstreamManager)
                        .environmentObject(ipcClient)
                }
                .onAppear {
                    setupDockIcon()
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Fusion Studio") {
                    appState.showAboutPanel = true
                }
            }
            CommandGroup(replacing: .help) {
                Button("Fusion Studio Help") {
                    appState.showHelp = true
                }
            }
            CommandGroup(after: .toolbar) {
                Button("Health Check") {
                    Task { await performStartupHealthCheck() }
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                Button("Toggle Sidebar") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        appState.isSidebarCollapsed.toggle()
                    }
                }
                .keyboardShortcut("\\", modifiers: [.command])

                Button("Toggle Inspector") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        appState.isInspectorVisible.toggle()
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Next Sheet") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        let sheets = ProductSheet.allCases
                        if let idx = sheets.firstIndex(of: appState.selectedSheet),
                           idx + 1 < sheets.count {
                            appState.selectedSheet = sheets[idx + 1]
                        } else {
                            appState.selectedSheet = sheets[0]
                        }
                    }
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .control])

                Button("Previous Sheet") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        let sheets = ProductSheet.allCases
                        if let idx = sheets.firstIndex(of: appState.selectedSheet),
                           idx > 0 {
                            appState.selectedSheet = sheets[idx - 1]
                        } else {
                            appState.selectedSheet = sheets[sheets.count - 1]
                        }
                    }
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .control])
            }
        }
    }

    private func performStartupHealthCheck() async {
        appState.healthStatus = .checking
        // app 复用外部 mlx(11434)：直接 HTTP 探活，不依赖 env-daemon IPC。
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
            appState.isHealthCheckPassed = mlxOk
            appState.isMLXRunning = mlxOk
            appState.healthStatus = mlxOk ? .healthy : .issuesFound
        }

        if !mlxOk {
            appLog.error("performStartupHealthCheck: mlx unreachable after \(maxAttempts) attempts")
        }
    }
}