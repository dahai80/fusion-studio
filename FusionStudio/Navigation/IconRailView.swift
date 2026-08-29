// Callers: ContentView (left icon rail column).
// Affected API: IconRailView (+ → .chats showChatsSidebar=false; Chats icon → showChatsSidebar=true).
// Data schemas: SidebarSection enum, AppState.activeSection, AppState.showChatsSidebar.
// User instruction: "点击+号打开主对话框，Chats按钮右侧显示历史+对话两列"

import SwiftUI
import AppKit
import os.log

private let railLog = Logger(subsystem: "com.fusion.studio", category: "IconRail")

struct IconRailView: View {
    @EnvironmentObject var navState: NavigationState
    @EnvironmentObject var uiPanelState: UIPanelState
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(spacing: 0) {
            openSidebarButton

            Rectangle().fill(theme.separator).frame(height: 1)

            newChatButton

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id("railScrollTop")
                        ForEach(SidebarSection.allCases) { section in
                            sectionIcon(section)
                        }
                        Color.clear.frame(height: 0).id("railScrollBottom")
                    }
                }

                VStack(spacing: 4) {
                    Button(action: { withAnimation { proxy.scrollTo("railScrollTop", anchor: .top) } }) {
                        Image(systemName: "chevron.up.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help(i18n.t(.scrollUp))

                    Button(action: { withAnimation { proxy.scrollTo("railScrollBottom", anchor: .bottom) } }) {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help(i18n.t(.scrollDown))
                }
                .padding(.vertical, 4)
            }

            Spacer()

            Rectangle().fill(theme.separator).frame(height: 1)

            getAppsButton
            settingsButton
            userAvatar
        }
        .frame(width: 52)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("IconRail")
    }

    private var openSidebarButton: some View {
        Button(action: {
            withAnimation(theme.springSnappy) {
                uiPanelState.isSidebarCollapsed.toggle()
            }
            railLog.info("Sidebar toggled: collapsed=\(uiPanelState.isSidebarCollapsed)")
        }) {
            Image(systemName: uiPanelState.isSidebarCollapsed ? "sidebar.left" : "sidebar.left.fill")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 52, height: 48)
        }
        .buttonStyle(.plain)
        .help(i18n.t(.toggleSidebar))
        .accessibilityIdentifier("sidebar.toggle")
    }

    private var newChatButton: some View {
        Button(action: {
            navState.activeSection = .chats
            uiPanelState.showChatsSidebar = false
            navState.selectedSheet = .chat
            railLog.info("New chat started — full-screen chat view")
        }) {
            Image(systemName: "plus.circle")
                .font(.system(size: theme.iconM, weight: .medium))
                .foregroundStyle(theme.accent)
                .frame(width: 52, height: 40)
        }
        .buttonStyle(.plain)
        .help(i18n.t(.newChat))
        .accessibilityIdentifier("chat.new")
    }

    private func sectionIcon(_ section: SidebarSection) -> some View {
        let isActive = navState.activeSection == section
        return Button(action: {
            withAnimation(theme.springSnappy) {
                navState.activeSection = section
                switch section {
                case .chats:
                    navState.selectedSheet = .chat
                    uiPanelState.showChatsSidebar = true
                case .projects:
                    navState.selectedSheet = .fusionProjectsSheet
                case .artifacts:
                    navState.selectedSheet = .artifactsSheet
                case .code:
                    navState.selectedSheet = .code
                case .design:
                    navState.selectedSheet = .code
                    uiPanelState.isInspectorVisible = false
                case .rag:
                    navState.selectedSheet = .ragSheet
                case .agent:
                    navState.selectedSheet = .agentStudio
                case .aiAgent:
                    navState.selectedSheet = .aiAgentSheet
                case .cowork:
                    navState.selectedSheet = .coworkSheet
                case .mlx:
                    navState.selectedSheet = .mlx
                // Model Hub 作为图标栏顶层独立入口，直接进 ModelHubMainView
                case .modelHub:
                    navState.selectedSheet = .mlx
                case .multiNode:
                    navState.selectedSheet = .multiNode
                case .fsb:
                    navState.selectedSheet = .fsbSheet
                case .science:
                    navState.selectedSheet = .scienceSheet
                case .finance:
                    navState.selectedSheet = .financeSheet
                case .health:
                    navState.selectedSheet = .healthSheet
                case .pluginEcosystem:
                    navState.selectedSheet = .pluginEcosystemSheet
                case .cliService:
                    navState.selectedSheet = .cliServiceSheet
                case .doc:
                    navState.selectedSheet = .docSheet
                // Callers: IconRailView rail button tap.
                // Affected API: navState.selectedModule/.selectedSheet routing for simulation section.
                // Data schemas: SidebarSection.simulation -> Module.simulation -> ProductSheet.simulationSheet.
                // User instruction: "在左侧菜单增加 fusion simulation"
                case .simulation:
                    navState.selectedSheet = .simulationSheet
                // Callers: IconRailView rail button tap. Affected API: selectedSheet routing for douyin section. Phase 4 GUI。
                case .douyinOperation:
                    navState.selectedSheet = .douyinOperationSheet
                // Callers: IconRailView rail button tap. Affected API: selectedModule/.selectedSheet routing for trainer section.
                // Data schemas: SidebarSection.trainer → Module.trainer → ProductSheet.trainerSheet. User instruction: "continue Task" — Task #5 (#175)
                case .trainer:
                    navState.selectedSheet = .trainerSheet
                }
                // #358: selectedModule is single-sourced from SidebarSection.modules.first
                // (no duplicated literals — every section's first module is authoritative).
                // selectedSheet above is intentionally hand-maintained per section: the
                // "section landing sheet" can differ from modules.first.sheet (e.g.
                // pluginEcosystem→.pluginEcosystemSheet vs .pluginConfig.sheet=.agentStudio;
                // cliService→.cliServiceSheet vs .cli.sheet=.code). Both switches are
                // exhaustive (no default) so a new SidebarSection case forces compiler errors
                // at every dependent site. ?? .chat is dead-but-safe defense for empty modules.
                navState.selectedModule = section.modules.first ?? .chat
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
        .help(section.localizedName)
        .accessibilityIdentifier("nav.\(section.rawValue)")
    }

    private var getAppsButton: some View {
        Button(action: {
            if let url = URL(string: "https://github.com/dahai80/fusion-studio") {
                NSWorkspace.shared.open(url)
            }
        }) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 52, height: 36)
        }
        .buttonStyle(.plain)
        .help(i18n.t(.getApps))
        .accessibilityIdentifier("apps.get")
    }

    private var settingsButton: some View {
        Button(action: { showSettingsMenu() }) {
            Image(systemName: "gearshape")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 52, height: 36)
        }
        .buttonStyle(.plain)
        .help(i18n.t(.settings))
        .accessibilityIdentifier("settings.open")
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
        let target = MenuActionTarget()

        let settingsItem = NSMenuItem(title: i18n.t(.settings), action: #selector(MenuActionTarget.runClosure), keyEquivalent: ",")
        settingsItem.target = target
        settingsItem.representedObject = { [self] in
            uiPanelState.showSettings = true
            railLog.info("settings menu: open SettingsView")
        }
        menu.addItem(settingsItem)

        // #346: 事件感知面板 (EventStreamView, fusion-event 感知层消费)。
        let eventItem = NSMenuItem(title: i18n.t(.event_title), action: #selector(MenuActionTarget.runClosure), keyEquivalent: "")
        eventItem.target = target
        eventItem.representedObject = { [self] in
            uiPanelState.showEventStream = true
            railLog.info("settings menu: open EventStreamView")
        }
        menu.addItem(eventItem)

        // Language 子菜单：切换 I18nManager.shared.currentLanguage，当前语言打勾
        let langMenu = NSMenu()
        let currentLang = I18nManager.shared.currentLanguage
        for lang in AppLanguage.allCases {
            let item = NSMenuItem(title: "\(lang.flag) \(lang.displayName)", action: #selector(MenuActionTarget.runClosure), keyEquivalent: "")
            item.target = target
            item.representedObject = {
                I18nManager.shared.currentLanguage = lang
                railLog.info("settings menu: language -> \(lang.rawValue)")
            }
            item.state = (lang == currentLang) ? .on : .off
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: i18n.t(.language), action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(NSMenuItem.separator())

        let helpItem = NSMenuItem(title: i18n.t(.getHelp), action: #selector(MenuActionTarget.runClosure), keyEquivalent: "")
        helpItem.target = target
        helpItem.representedObject = {
            if let url = URL(string: "https://github.com/dahai80/fusion-studio/issues") {
                NSWorkspace.shared.open(url)
            }
        }
        menu.addItem(helpItem)

        let upgradeItem = NSMenuItem(title: i18n.t(.upgradePlan), action: #selector(MenuActionTarget.runClosure), keyEquivalent: "")
        upgradeItem.target = target
        upgradeItem.representedObject = {
            if let url = URL(string: "https://github.com/dahai80/fusion-studio/releases") {
                NSWorkspace.shared.open(url)
            }
        }
        menu.addItem(upgradeItem)

        let appsItem = NSMenuItem(title: i18n.t(.getApps), action: #selector(MenuActionTarget.runClosure), keyEquivalent: "")
        appsItem.target = target
        appsItem.representedObject = {
            if let url = URL(string: "https://github.com/dahai80/fusion-studio") {
                NSWorkspace.shared.open(url)
            }
        }
        menu.addItem(appsItem)

        let learnItem = NSMenuItem(title: i18n.t(.learnMore), action: #selector(MenuActionTarget.runClosure), keyEquivalent: "")
        learnItem.target = target
        learnItem.representedObject = {
            if let url = URL(string: "https://github.com/dahai80/fusion-studio") {
                NSWorkspace.shared.open(url)
            }
        }
        menu.addItem(learnItem)

        menu.addItem(NSMenuItem.separator())

        // Logout：本地优先架构无账号登录，置灰
        let logoutItem = NSMenuItem(title: i18n.t(.logout), action: nil, keyEquivalent: "")
        logoutItem.isEnabled = false
        menu.addItem(logoutItem)

        // 持有 target 防止菜单生命周期内被释放
        objc_setAssociatedObject(menu, "menuActionTarget", target, .OBJC_ASSOCIATION_RETAIN)

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
}

// NSMenuItem target/action 闭包中介。菜单项 representedObject 存闭包，
// runClosure 回调时取出执行。
private final class MenuActionTarget: NSObject {
    @objc func runClosure(_ sender: NSMenuItem) {
        if let action = sender.representedObject as? () -> Void {
            action()
        }
    }
}
