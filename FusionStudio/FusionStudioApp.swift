import SwiftUI

// Callers: App entry point. API: adds SandboxManager + ScreenContextManager StateObjects. Schemas: none.
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import SwiftUI

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
                .studioThemed()
                .onAppear {
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
        do {
            let result = try await agentBridge.fullHealthCheck()
            let healthy = result["healthy"] as? Bool ?? false
            let checks = result["checks"] as? [String: [String: Any]] ?? [:]

            let mlxOk = checks["mlx_api"]?["ok"] as? Bool ?? false

            await MainActor.run {
                appState.isHealthCheckPassed = healthy
                appState.isMLXRunning = mlxOk
                appState.healthStatus = healthy ? .healthy : .issuesFound
            }

            if mlxOk {
                try? await agentBridge.fetchModels()
            }
        } catch {
            await MainActor.run {
                appState.isHealthCheckPassed = false
                appState.isMLXRunning = false
                appState.healthStatus = .issuesFound
            }
        }
    }
}