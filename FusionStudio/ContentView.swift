// Callers: FusionStudioApp body, preview.
// Affected API: ContentView (IconRail + collapsible sidebar + workspace + inspector).
// Data schemas: AppState.isSidebarCollapsed controls sidebar visibility.
// User instruction: "最左侧菜单恢复到上次的形式，窄窄的icon rail，点击图标直接切换主页面，不展开侧边栏"

import SwiftUI
import os.log

private let contentViewLog = Logger(subsystem: "com.fusion.studio", category: "ContentView")

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var ipcClient: IPCClient
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = colorScheme == .dark ? StudioTheme.dark : StudioTheme.light

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
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $appState.showAboutPanel) {
            AboutView()
        }
        .onAppear {
            contentViewLog.info("ContentView appeared — IconRail + sidebar layout active")
        }
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

            if appState.activeSection != .code && appState.activeSection != .customize && appState.activeSection != .design {
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
                    appState.isInspectorVisible.toggle()
                }
            }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(appState.isInspectorVisible ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Toggle Inspector")

            HealthStatusBadge(status: appState.healthStatus)

            Button(action: {}) {
                Image(systemName: appState.isMLXRunning ? "bolt.fill" : "bolt.slash")
                    .foregroundStyle(appState.isMLXRunning ? theme.greenDot : theme.redDot)
                    .font(.system(size: theme.iconS))
            }
            .buttonStyle(.plain)
            .help(appState.isMLXRunning ? "MLX Running" : "MLX Offline")
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
                ChatsPanel()
            case .projects:
                ProjectsPanel()
            case .artifacts:
                ArtifactsPanel()
            case .code:
                FusionCodeView()
            case .customize:
                CustomizePanel()
            case .design:
                DesignView()
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
