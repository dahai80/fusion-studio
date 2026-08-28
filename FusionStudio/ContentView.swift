// Callers: FusionStudioApp body, preview.
// Affected API: ContentView .chats case — shows ChatsPanel (sidebar+detail) or UnifiedChatView (full-screen).
// Data schemas: AppState.showChatsSidebar controls chats layout mode.
// User instruction: "点击+号打开主对话框，Chats按钮右侧显示历史+对话两列"

import SwiftUI
import AppKit
import os.log

private let contentViewLog = Logger(subsystem: "com.fusion.studio", category: "ContentView")

struct ContentView: View {
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var uiPanelState: UIPanelState
    @EnvironmentObject var ipcClient: IPCClient
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var guardBridge: GuardBridge

    var body: some View {
        let theme = themeState.isDarkMode ? StudioTheme.dark : StudioTheme.light

        HStack(spacing: 0) {
            IconRailView()

            Rectangle()
                .fill(theme.separator)
                .frame(width: 1)

            if !uiPanelState.isSidebarCollapsed {
                FusionSidebarView()

                Rectangle()
                    .fill(theme.separator)
                    .frame(width: 1)
            }

            WorkspaceArea(theme: theme)

            if uiPanelState.isInspectorVisible {
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
        .preferredColorScheme(themeState.isDarkMode ? .dark : .light)
        .sheet(isPresented: $uiPanelState.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $uiPanelState.showAboutPanel) {
            AboutView()
        }
        .sheet(isPresented: $uiPanelState.showEnvironmentHealth) {
            EnvironmentHealthSheet()
        }
        // #346: fusion-event 事件感知面板 (EventStreamView, status + events + rule CRUD)。
        .sheet(isPresented: $uiPanelState.showEventStream) {
            EventStreamView()
        }
        // #344: guard L3 人机确认弹窗 (pendingChallenge 驱动, .sheet(item:))
        .sheet(item: $guardBridge.pendingChallenge) { ch in
            GuardChallengeModal(guardBridge: guardBridge, challenge: ch)
        }
        .onAppear {
            applyNativeAppearance(themeState.isDarkMode)
            contentViewLog.info("ContentView appeared - 3-column layout, darkMode=\(themeState.isDarkMode)")
        }
        .onChange(of: themeState.isDarkMode) { _, newValue in
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
    @EnvironmentObject var navState: NavigationState
    @EnvironmentObject var uiPanelState: UIPanelState
    @EnvironmentObject var themeState: ThemeState
    @EnvironmentObject var healthState: HealthState
    @StateObject private var i18n = I18nManager.shared

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
            Text(navState.activeSection.rawValue)
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if navState.activeSection != .code && navState.activeSection != .design {
                Text(navState.selectedSheet.rawValue)
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
                    themeState.isDarkMode.toggle()
                }
            }) {
                Image(systemName: themeState.isDarkMode ? "sun.max" : "moon")
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help(themeState.isDarkMode ? i18n.t(.toggleLightMode) : i18n.t(.toggleDarkMode))

            Button(action: {
                withAnimation(theme.springSnappy) {
                    uiPanelState.isInspectorVisible.toggle()
                }
            }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(uiPanelState.isInspectorVisible ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help(i18n.t(.toggleInspector))

// Replacing MLX bolt button with OfflineModeIndicator for #52
// Affected API: OfflineModeIndicator (wraps offline check + MLX status)
            HealthStatusBadge(status: healthState.healthStatus)

            OfflineModeIndicator()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(.ultraThinMaterial)
    }
}

struct SectionContentView: View {
    @EnvironmentObject var navState: NavigationState
    @EnvironmentObject var uiPanelState: UIPanelState

    var body: some View {
        Group {
            switch navState.activeSection {
            case .chats:
                if uiPanelState.showChatsSidebar {
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
            case .health:
                HealthWorkbenchView()
            case .pluginEcosystem:
                PluginEcosystemView()
                    .environmentObject(PluginBridge.shared)
            case .cliService:
                CliServiceView()
            case .doc:
                DocView()
            // Callers: SectionContentView switch on navState.activeSection.
            // Affected API: renders SimulationWorkbenchView for .simulation section.
            // Data schemas: SidebarSection.simulation. User instruction: "在左侧菜单增加 fusion simulation"
            case .simulation:
                SimulationWorkbenchView()
            // Callers: SectionContentView switch on navState.activeSection.
            // Affected API: renders DouyinOperationView for .douyinOperation section (Phase 4 GUI)。
            // Data schemas: SidebarSection.douyinOperation. User instruction: ~/operation/reconstruct-operation.md Phase 4。
            case .douyinOperation:
                DouyinOperationView()
            // Callers: ContentView switch on navState.activeSection.
            // Affected API: renders TrainerView for .trainer section (RunManager GUI via trainer.* IPC).
            // Data schemas: SidebarSection.trainer → Module.trainer. User instruction: "continue Task" — Task #5 (#175)
            case .trainer:
                TrainerView()
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
        .environmentObject(DouyinOperationBridge())
}
