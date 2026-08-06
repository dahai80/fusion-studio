// Callers: FusionStudioApp body, preview.
// Affected API: ContentView .chats case — shows ChatsPanel (sidebar+detail) or UnifiedChatView (full-screen).
// Data schemas: AppState.showChatsSidebar controls chats layout mode.
// User instruction: "点击+号打开主对话框，Chats按钮右侧显示历史+对话两列"

import SwiftUI
import AppKit
import os.log

private let contentViewLog = Logger(subsystem: "com.fusion.studio", category: "ContentView")

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var ipcClient: IPCClient
    @EnvironmentObject var taskManager: TaskManager

    var body: some View {
        let theme = appState.isDarkMode ? StudioTheme.dark : StudioTheme.light

        HStack(spacing: 0) {
            IconRailView()

            Rectangle()
                .fill(theme.separator)
                .frame(width: 1)

            if !appState.isSidebarCollapsed {
                FusionSidebarView()

                Rectangle()
                    .fill(theme.separator)
                    .frame(width: 1)
            }

            WorkspaceArea(theme: theme)

            if appState.isInspectorVisible {
                Rectangle()
                    .fill(theme.separator)
                    .frame(width: 1)

                InspectorPanel()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(minWidth: 1100, minHeight: 700)
        .background(theme.windowBg)
        .environment(\.studioTheme, theme)
        .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $appState.showAboutPanel) {
            AboutView()
        }
        .onAppear {
            applyNativeAppearance(appState.isDarkMode)
            contentViewLog.info("ContentView appeared - 3-column layout, darkMode=\(appState.isDarkMode)")
        }
        .onChange(of: appState.isDarkMode) { _, newValue in
            applyNativeAppearance(newValue)
        }
    }

    private func applyNativeAppearance(_ dark: Bool) {
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        contentViewLog.info("Native appearance applied: dark=\(dark)")
    }
}

struct WorkspaceArea: View {
    let theme: StudioTheme
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            workspaceToolbar

            SectionContentView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.contentBg)
    }

    private var workspaceToolbar: some View {
        HStack(spacing: theme.spacingM) {
            Text(appState.activeSection.rawValue)
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if appState.activeSection != .code && appState.activeSection != .design {
                Text(appState.selectedSheet.rawValue)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingXS)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(theme.accent.opacity(0.12))
                    )
            }

            Spacer()

            Button(action: {
                withAnimation(theme.springSnappy) {
                    appState.isDarkMode.toggle()
                }
            }) {
                Image(systemName: appState.isDarkMode ? "sun.max" : "moon")
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help(appState.isDarkMode ? "切换到亮色模式" : "切换到暗色模式")

            Button(action: {
                withAnimation(theme.springSnappy) {
                    appState.isInspectorVisible.toggle()
                }
            }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(appState.isInspectorVisible ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Toggle Inspector")

// Replacing MLX bolt button with OfflineModeIndicator for #52
// Affected API: OfflineModeIndicator (wraps offline check + MLX status)
            HealthStatusBadge(status: appState.healthStatus)

            OfflineModeIndicator()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(.ultraThinMaterial)
    }
}

struct SectionContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.activeSection {
            case .chats:
                if appState.showChatsSidebar {
                    ChatsPanel()
                } else {
                    UnifiedChatView()
                }
            case .projects:
                ProjectModuleView()
            case .artifacts:
                ArtifactsPanel()
            case .code:
                FusionCodeView()
            case .design:
                DesignView()
            case .rag:
                RAGMainView()
            case .agent:
                ModuleDetailView()
            case .aiAgent:
                ModuleDetailView()
            case .cowork:
                SpaceListView()
            case .mlx:
                ModuleDetailView()
            case .modelHub:
                ModuleDetailView()
            case .multiNode:
                ModuleDetailView()
            case .fsb:
                FSBWorkspaceView()
            case .science:
                ScienceWorkbenchView()
                    .environmentObject(ScienceBridge())
                    .environmentObject(ScienceSSEClient())
            case .finance:
                FinanceWorkbenchView()
            case .pluginEcosystem:
                PluginEcosystemView()
                    .environmentObject(PluginBridge.shared)
            case .cliService:
                CliServiceView()
            case .doc:
                DocView()
            // Callers: SectionContentView switch on appState.activeSection.
            // Affected API: renders SimulationWorkbenchView for .simulation section.
            // Data schemas: SidebarSection.simulation. User instruction: "在左侧菜单增加 fusion simulation"
            case .simulation:
                SimulationWorkbenchView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(IPCClient())
        .environmentObject(TaskManager())
}
