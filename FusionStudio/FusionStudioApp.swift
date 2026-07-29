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
                .studioThemed()
                .onAppear {
                    // 启动时检测并按需自动启动上游关键服务（mlx -> agent-studio -> artifacts-engine）。
                    // 非阻塞：IPCClient 会每 3s 自动重连，agent-studio 拉起 socket 后即可连上。
                    Task { await upstreamManager.ensureCriticalRunning() }
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
                    chatStore.setIPCClient(ipcClient)
                    deskBridge.setIPCClient(ipcClient)
                    ArtifactSidebarCache.shared.configure(ipcClient: ipcClient)
                    Task {
                        await performStartupHealthCheck()
                    }
                }
                .frame(minWidth: 1100, minHeight: 700)
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
        // 启动竞态：ensureCriticalRunning 异步拉起 agent-studio 守护进程，IPCClient 首次调用
        // 可能尚未连上 socket。重试最多 ~20s，避免 isMLXRunning 滞留 false 导致 Design 误报
        // "MLX 服务未运行" (bug2)。
        let maxAttempts = 10
        var healthy = false
        var mlxOk = false
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                let result = try await agentBridge.fullHealthCheck()
                healthy = result["healthy"] as? Bool ?? false
                let checks = result["checks"] as? [String: [String: Any]] ?? [:]
                mlxOk = checks["mlx_api"]?["ok"] as? Bool ?? false
                appLog.info("performStartupHealthCheck: attempt=\(attempt) healthy=\(healthy) mlxOk=\(mlxOk)")
                lastError = nil
                break
            } catch {
                lastError = error
                appLog.warning("performStartupHealthCheck: attempt=\(attempt)/\(maxAttempts) failed: \(error)")
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }

        await MainActor.run {
            appState.isHealthCheckPassed = healthy
            appState.isMLXRunning = mlxOk
            appState.healthStatus = healthy ? .healthy : .issuesFound
        }

        if mlxOk {
            try? await agentBridge.fetchModels()
        }

        if lastError != nil && !mlxOk {
            appLog.error("performStartupHealthCheck: gave up after \(maxAttempts) attempts: \(lastError!)")
        }
    }
}