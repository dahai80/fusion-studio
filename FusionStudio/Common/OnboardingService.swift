import SwiftUI

// MARK: - 引导步骤

enum OnboardingStep: Int, CaseIterable {
    case welcome    = 0
    case dashboard  = 1
    case modules    = 2
    case design     = 3
    case code       = 4
    case simulation = 5
    case settings   = 6
    case complete   = 7

    var title: String {
        switch self {
        case .welcome:    return "欢迎使用 Fusion Studio"
        case .dashboard:  return "控制台概览"
        case .modules:    return "模块导航"
        case .design:     return "AI 设计画布"
        case .code:       return "AI 编码助手"
        case .simulation: return "机器人仿真"
        case .settings:   return "个性化设置"
        case .complete:   return "准备就绪"
        }
    }

    var description: String {
        switch self {
        case .welcome:    return "Fusion Studio 是 Fusion-MLX 生态的统一桌面客户端。它将设计、编码、仿真、模型管理等 10 个模块整合为一个 macOS 原生应用。"
        case .dashboard:  return "控制台是您的指挥中心。在这里可以查看环境健康状态、运行任务队列、监控硬件使用情况。"
        case .modules:    return "左侧边栏列出了所有可用模块。点击任意模块即可快速切换。当前已激活 10 个模块。"
        case .design:     return "使用 AI 驱动的设计画布创建 UI 界面。支持对话式生成、一键导出代码到编码模块。"
        case .code:       return "内置代码编辑器和集成终端。支持 Swift、Python、Rust 等多种语言，可直接运行和调试。"
        case .simulation: return "3D 物理仿真引擎，支持机器人运动学、动力学仿真。可与设计和编码模块联动。"
        case .settings:   return "在设置中配置硬件加速、离线模式、量化精度、工作区路径等。"
        case .complete:   return "您已掌握基本操作！如需更多帮助，请查看帮助菜单或访问在线文档。"
        }
    }

    var icon: String {
        switch self {
        case .welcome:    return "bolt.circle.fill"
        case .dashboard:  return "square.grid.2x2"
        case .modules:    return "square.grid.3x3"
        case .design:     return "pencil.and.outline"
        case .code:       return "chevron.left.forwardslash.chevron.right"
        case .simulation: return "gearshape.2"
        case .settings:   return "gearshape"
        case .complete:   return "checkmark.circle.fill"
        }
    }
}

// MARK: - 引导管理器

class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    @Published var showOnboarding = false
    @Published var currentStep: OnboardingStep = .welcome
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "onboarding_completed") }
    }

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboarding_completed")
        if !hasCompletedOnboarding { showOnboarding = true }
    }

    var isLastStep: Bool { currentStep == .complete }
    var progress: Double { Double(currentStep.rawValue + 1) / Double(OnboardingStep.allCases.count) }

    func next() {
        guard currentStep.rawValue < OnboardingStep.allCases.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .complete
        }
    }

    func previous() {
        guard currentStep.rawValue > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
        }
    }

    func skip() {
        hasCompletedOnboarding = true
        showOnboarding = false
    }

    func complete() {
        hasCompletedOnboarding = true
        showOnboarding = false
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
    }

    func reset() {
        hasCompletedOnboarding = false
        currentStep = .welcome
        showOnboarding = true
    }
}

// MARK: - 引导覆盖层

struct OnboardingOverlay: View {
    @StateObject private var onboarding = OnboardingManager.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                // 进度条
                ProgressView(value: onboarding.progress)
                    .tint(.accentColor)
                    .padding(.horizontal, 40)

                // 卡片
                VStack(spacing: 20) {
                    Image(systemName: onboarding.currentStep.icon)
                        .font(.system(size: 64))
                        .foregroundStyle(.linearGradient(
                            colors: [.purple, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text(onboarding.currentStep.title)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.primary)

                    Text(onboarding.currentStep.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .shadow(radius: 20)
                )
                .padding(.horizontal, 40)

                Spacer()

                // 底部按钮
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        if onboarding.currentStep != .welcome {
                            Button(action: onboarding.previous) {
                                Label("上一步", systemImage: "arrow.left")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }

                        if onboarding.isLastStep {
                            Button(action: onboarding.complete) {
                                Label("开始使用", systemImage: "hand.wave")
                                    .frame(width: 160)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.green)
                        } else {
                            Button(action: onboarding.next) {
                                Label("下一步", systemImage: "arrow.right")
                                    .frame(width: 120)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }

                    Button("跳过引导", action: onboarding.skip)
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.bottom, 40)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - 提示气泡

struct TipBubble: View {
    let title: String
    let message: String
    let icon: String
    var color: Color = .accentColor
    var dismissAction: (() -> Void)?

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let dismiss = dismissAction {
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: color.opacity(0.2), radius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { isVisible = true }
        }
    }
}

// MARK: - 上下文提示

struct ContextualTip: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let targetModule: String?
    let priority: Int
}

let contextualTips: [ContextualTip] = [
    ContextualTip(title: "环境健康检查", message: "首次使用请运行环境自检，确保所有依赖已安装", icon: "stethoscope", targetModule: "dashboard", priority: 1),
    ContextualTip(title: "MLX 推理服务", message: "AI 功能需要 fusion-mlx 服务运行，在设置中开启自动启动", icon: "bolt", targetModule: "settings", priority: 2),
    ContextualTip(title: "模块联动", message: "设计 → 代码 → 仿真 三联动，一键流转数据", icon: "arrow.triangle.branch", targetModule: nil, priority: 3),
    ContextualTip(title: "快捷键", message: "Cmd+1-9 快速切换模块，Cmd+, 打开设置", icon: "keyboard", targetModule: nil, priority: 4),
    ContextualTip(title: "离线模式", message: "默认开启离线模式，所有数据仅存储在本地", icon: "lock.shield", targetModule: "settings", priority: 5),
]

// MARK: - 帮助面板

struct HelpPanelView: View {
    @State private var selectedTab: HelpTab = .tips
    @State private var searchText = ""

    enum HelpTab: String, CaseIterable {
        case tips    = "使用提示"
        case faq     = "常见问题"
        case shortcuts = "快捷键"
        case about   = "关于"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(HelpTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            switch selectedTab {
            case .tips:    TipsListView()
            case .faq:     FAQView()
            case .shortcuts: ShortcutsView()
            case .about:   AboutDetailView()
            }
        }
    }

    private func tabIcon(_ tab: HelpTab) -> String {
        switch tab {
        case .tips: return "lightbulb"
        case .faq:  return "questionmark.circle"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

struct TipsListView: View {
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(contextualTips.filter {
                    searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText)
                }) { tip in
                    TipBubble(title: tip.title, message: tip.message, icon: tip.icon, color: .accentColor, dismissAction: nil)
                }
            }
            .padding()
        }
        .searchable(text: $searchText, prompt: "搜索提示...")
    }
}

struct FAQView: View {
    @State private var selectedItem: String?

    let faqs: [(question: String, answer: String)] = [
        ("Fusion Studio 是否完全免费？", "是的，Fusion Studio 是开源软件，使用 MIT 许可证，完全免费。"),
        ("是否支持 Intel Mac？", "目前仅支持 Apple Silicon (M1-M5)，因为依赖 MLX 框架的 Metal 加速。"),
        ("如何安装 fusion-mlx？", "在控制台运行环境自检，点击「修复」按钮自动安装，或手动执行 pip install fusion-mlx。"),
        ("数据会上传到云端吗？", "不会。Fusion Studio 默认开启离线模式，所有数据仅存储在本地。"),
        ("如何更新 Fusion Studio？", "在设置中点击「检查更新」，或从 GitHub Release 下载最新 DMG。"),
        ("支持哪些编程语言？", "内置支持 Swift、Python、Rust、JavaScript、TypeScript、HTML、CSS、JSON、YAML。"),
        ("如何创建自定义插件？", "在插件面板中点击「创建模板」，生成插件骨架后编辑 manifest.json 和 main.py。"),
        ("局域网协作安全吗？", "所有数据传输仅在局域网内进行，使用 Bonjour/mDNS 发现，不经过外部网络。"),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(faqs, id: \.question) { faq in
                    DisclosureGroup {
                        Text(faq.answer)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } label: {
                        Text(faq.question)
                            .font(.headline)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct ShortcutsView: View {
    let shortcuts: [(keys: String, action: String)] = [
        ("Cmd + 1-9", "切换模块"),
        ("Cmd + ,", "打开设置"),
        ("Cmd + R", "运行当前代码"),
        ("Cmd + B", "构建项目"),
        ("Cmd + Shift + F", "搜索"),
        ("Cmd + Shift + H", "显示帮助"),
        ("Cmd + Shift + N", "新建文档"),
        ("Cmd + Shift + E", "导出"),
        ("Space", "预览/播放"),
        ("Esc", "取消/关闭"),
    ]

    var body: some View {
        List {
            ForEach(shortcuts, id: \.keys) { shortcut in
                HStack {
                    Text(shortcut.action)
                        .font(.body)
                    Spacer()
                    Text(shortcut.keys)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct AboutDetailView: View {
    @StateObject private var updateManager = AutoUpdateManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Fusion Studio")
                .font(.largeTitle)
                .bold()

            Text("版本 \(updateManager.currentVersion) (Build \(updateManager.currentBuild))")
                .font(.title3)
                .foregroundColor(.secondary)

            Text("Fusion-MLX 本地 AI 生态的统一桌面客户端")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            VStack(alignment: .leading, spacing: 8) {
                Label("macOS 14+ Apple Silicon", systemImage: "cpu")
                Label("100% 本地离线", systemImage: "lock.shield")
                Label("10 个模块 · 全生态收口", systemImage: "square.grid.3x3")
                Label("MIT 开源许可证", systemImage: "doc.text")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Button(action: { updateManager.checkForUpdates(force: true) }) {
                Label("检查更新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .padding(.top)

            Spacer()

            Text("© 2026 Fusion-MLX Team")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 重新引导按钮

struct ResetOnboardingButton: View {
    @StateObject private var onboarding = OnboardingManager.shared

    var body: some View {
        Button(action: { onboarding.reset() }) {
            Label("重新显示引导", systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}