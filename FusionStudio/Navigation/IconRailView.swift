// Callers: ContentView (left icon rail column).
// Affected API: IconRailView (+ → .chats showChatsSidebar=false; Chats icon → showChatsSidebar=true).
// Data schemas: SidebarSection enum, AppState.activeSection, AppState.showChatsSidebar.
// User instruction: "点击+号打开主对话框，Chats按钮右侧显示历史+对话两列"

import SwiftUI
import AppKit
import os.log

private let railLog = Logger(subsystem: "com.fusion.studio", category: "IconRail")

struct IconRailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            openSidebarButton

            Rectangle().fill(theme.separator).frame(height: 1)

            newChatButton

            ForEach(SidebarSection.allCases) { section in
                sectionIcon(section)
            }

            Spacer()

            Rectangle().fill(theme.separator).frame(height: 1)

            getAppsButton
            settingsButton
            userAvatar
        }
        .frame(width: 52)
        .background(.ultraThinMaterial)
    }

    private var openSidebarButton: some View {
        Button(action: {
            withAnimation(theme.springSnappy) {
                appState.isSidebarCollapsed.toggle()
            }
            railLog.info("Sidebar toggled: collapsed=\(appState.isSidebarCollapsed)")
        }) {
            Image(systemName: appState.isSidebarCollapsed ? "sidebar.left" : "sidebar.left.fill")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 52, height: 48)
        }
        .buttonStyle(.plain)
        .help("Toggle Sidebar (⌘\\)")
    }

    private var newChatButton: some View {
        Button(action: {
            appState.activeSection = .chats
            appState.showChatsSidebar = false
            appState.selectedSheet = .chat
            railLog.info("New chat started — full-screen chat view")
        }) {
            Image(systemName: "plus.circle")
                .font(.system(size: theme.iconM, weight: .medium))
                .foregroundStyle(theme.accent)
                .frame(width: 52, height: 40)
        }
        .buttonStyle(.plain)
        .help("New Chat")
    }

    private func sectionIcon(_ section: SidebarSection) -> some View {
        let isActive = appState.activeSection == section
        return Button(action: {
            withAnimation(theme.springSnappy) {
                appState.activeSection = section
                switch section {
                case .chats:
                    appState.selectedModule = .chat
                    appState.selectedSheet = .chat
                    appState.showChatsSidebar = true
                case .projects:
                    appState.selectedModule = .fusionProjects
                    appState.selectedSheet = .fusionProjectsSheet
                case .artifacts:
                    appState.selectedModule = .artifactsRepo
                    appState.selectedSheet = .artifactsSheet
                case .code:
                    appState.selectedModule = .code
                    appState.selectedSheet = .code
                case .design:
                    appState.selectedModule = .design
                    appState.selectedSheet = .code
                    appState.isInspectorVisible = false
                case .rag:
                    appState.selectedModule = .kb
                    appState.selectedSheet = .ragSheet
                case .agent:
                    appState.selectedModule = .agent
                    appState.selectedSheet = .agentStudio
                case .aiAgent:
                    appState.selectedModule = .aiAgentDashboard
                    appState.selectedSheet = .aiAgentSheet
                case .cowork:
                    appState.selectedModule = .cowork
                    appState.selectedSheet = .coworkSheet
                case .mlx:
                    appState.selectedModule = .dashboard
                    appState.selectedSheet = .mlx
                case .multiNode:
                    appState.selectedModule = .clusterOverview
                    appState.selectedSheet = .multiNode
                case .fsb:
                    appState.selectedModule = .fsb
                    appState.selectedSheet = .fsbSheet
                case .science:
                    appState.selectedModule = .science
                    appState.selectedSheet = .scienceSheet
                case .finance:
                    appState.selectedModule = .finance
                    appState.selectedSheet = .financeSheet
                case .pluginEcosystem:
                    appState.selectedModule = .pluginConfig
                    appState.selectedSheet = .pluginEcosystemSheet
                case .cliService:
                    appState.selectedModule = .cli
                    appState.selectedSheet = .cliServiceSheet
                case .doc:
                    appState.selectedModule = .doc
                    appState.selectedSheet = .docSheet
                // Callers: IconRailView rail button tap.
                // Affected API: appState.selectedModule/.selectedSheet routing for simulation section.
                // Data schemas: SidebarSection.simulation -> Module.simulation -> ProductSheet.simulationSheet.
                // User instruction: "在左侧菜单增加 fusion simulation"
                case .simulation:
                    appState.selectedModule = .simulation
                    appState.selectedSheet = .simulationSheet
                }
            }
            railLog.info("Section selected: \(section.rawValue)")
        }) {
            ZStack(alignment: .leading) {
                if isActive {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(theme.accent)
                        .frame(width: 3, height: 20)
                }

                Image(systemName: section.icon)
                    .font(.system(size: theme.iconM, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
                    .frame(width: 52, height: 40)
            }
        }
        .buttonStyle(.plain)
        .help(section.rawValue)
    }

    private var getAppsButton: some View {
        Button(action: {
            if let url = URL(string: "https://github.com/fusion-ml") {
                NSWorkspace.shared.open(url)
            }
        }) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 52, height: 36)
        }
        .buttonStyle(.plain)
        .help("Get App & Extensions")
    }

    private var settingsButton: some View {
        Button(action: { showSettingsMenu() }) {
            Image(systemName: "gearshape")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 52, height: 36)
        }
        .buttonStyle(.plain)
        .help("Settings")
    }

    private var userAvatar: some View {
        Circle()
            .fill(theme.accent.opacity(0.2))
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
            }
            .padding(.bottom, theme.spacingM)
            .padding(.top, theme.spacingXS)
    }

    private func showSettingsMenu() {
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings", action: Selector(("showSettingsWindow:")), keyEquivalent: ",")
        menu.addItem(settingsItem)
        menu.addItem(withTitle: "Language", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Get Help", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Upgrade Plan", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Get Apps & Extensions", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Learn More", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Logout", action: nil, keyEquivalent: "")

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
}
