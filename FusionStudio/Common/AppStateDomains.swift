import SwiftUI
import os.log

// F-A5: AppState 原 God-state 把导航 + UI面板开关 + 健康 + 主题 4 类无关职责混装一个
//   ObservableObject。任一 @Published 变化触发 AppState.objectWillChange, 全 app @EnvironmentObject
//   视图重算 body (审计 0825 F-A5)。拆 4 独立 ObservableObject, 各域独立观察, 互不牵连重绘:
//   - NavigationState: 模块路由 (selectedModule/selectedSheet/activeSection)
//   - UIPanelState: UI 面板开关 (about/help/welcome/settings/envHealth/inspector/sidebar/chatsSidebar)
//   - HealthState: 健康状态 (isHealthCheckPassed/isMLXRunning/healthStatus) — 后台健康检查更新只重绘读健康域视图
//   - ThemeState: 主题 (isDarkMode 带 UserDefaults 持久化)
// 各子对象在 FusionStudioApp 注入为独立 .environmentObject, 消费方按需 @EnvironmentObject 取用。

private let appStateDomainsLog = Logger(subsystem: "com.fusion.studio", category: "AppStateDomains")

// MARK: - Navigation State

final class NavigationState: ObservableObject {
    @Published var selectedModule: Module = .chat
    @Published var selectedSheet: ProductSheet = .chat
    @Published var activeSection: SidebarSection = .chats

    init() {}
}

// MARK: - UI Panel State

final class UIPanelState: ObservableObject {
    @Published var showAboutPanel = false
    @Published var showHelp = false
    @Published var showWelcome = false
    @Published var showSettings = false
    @Published var showEnvironmentHealth = false
    // #346: fusion-event 事件感知面板 (EventStreamView sheet)。
    @Published var showEventStream = false
    @Published var isInspectorVisible: Bool = false
    @Published var inspectorContext: InspectorContext = .none
    @Published var isSidebarCollapsed: Bool = true
    @Published var sidebarWidth: CGFloat = 260
    @Published var showChatsSidebar: Bool = false

    init() {}
}

// MARK: - Health State

final class HealthState: ObservableObject {
    @Published var isHealthCheckPassed = false
    @Published var isMLXRunning = false
    @Published var healthStatus: AppState.HealthStatus = .checking

    init() {}
}

// MARK: - Theme State

final class ThemeState: ObservableObject {
    @Published var isDarkMode: Bool = UserDefaults.standard.object(forKey: "fusionStudio.isDarkMode") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "fusionStudio.isDarkMode")
            appStateDomainsLog.info("ThemeState: isDarkMode -> \(self.isDarkMode)")
        }
    }

    init() {}
}
