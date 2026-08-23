import SwiftUI
import os.log

private let onbLog = Logger(subsystem: "com.fusion.studio", category: "onboarding")

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
        case .welcome:    return I18nManager.shared.t(.onb_title_welcome)
        case .dashboard:  return I18nManager.shared.t(.onb_title_dashboard)
        case .modules:    return I18nManager.shared.t(.onb_title_modules)
        case .design:     return I18nManager.shared.t(.onb_title_design)
        case .code:       return I18nManager.shared.t(.onb_title_code)
        case .simulation: return I18nManager.shared.t(.onb_title_simulation)
        case .settings:   return I18nManager.shared.t(.onb_title_settings)
        case .complete:   return I18nManager.shared.t(.onb_title_complete)
        }
    }

    var description: String {
        switch self {
        case .welcome:    return I18nManager.shared.t(.onb_desc_welcome)
        case .dashboard:  return I18nManager.shared.t(.onb_desc_dashboard)
        case .modules:    return I18nManager.shared.t(.onb_desc_modules)
        case .design:     return I18nManager.shared.t(.onb_desc_design)
        case .code:       return I18nManager.shared.t(.onb_desc_code)
        case .simulation: return I18nManager.shared.t(.onb_desc_simulation)
        case .settings:   return I18nManager.shared.t(.onb_desc_settings)
        case .complete:   return I18nManager.shared.t(.onb_desc_complete)
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
        onbLog.info("onboarding completed")
    }

    func reset() {
        hasCompletedOnboarding = false
        currentStep = .welcome
        showOnboarding = true
        onbLog.info("onboarding reset")
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
                                Label(I18nManager.shared.t(.onb_btn_prev), systemImage: "arrow.left")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }

                        if onboarding.isLastStep {
                            Button(action: onboarding.complete) {
                                Label(I18nManager.shared.t(.onb_btn_start), systemImage: "hand.wave")
                                    .frame(width: 160)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.green)
                        } else {
                            Button(action: onboarding.next) {
                                Label(I18nManager.shared.t(.onb_btn_next), systemImage: "arrow.right")
                                    .frame(width: 120)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }

                    Button(I18nManager.shared.t(.onb_btn_skip), action: onboarding.skip)
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
    ContextualTip(title: I18nManager.shared.t(.onb_tip_env_title), message: I18nManager.shared.t(.onb_tip_env_msg), icon: "stethoscope", targetModule: "dashboard", priority: 1),
    ContextualTip(title: I18nManager.shared.t(.onb_tip_mlx_title), message: I18nManager.shared.t(.onb_tip_mlx_msg), icon: "bolt", targetModule: "settings", priority: 2),
    ContextualTip(title: I18nManager.shared.t(.onb_tip_link_title), message: I18nManager.shared.t(.onb_tip_link_msg), icon: "arrow.triangle.branch", targetModule: nil, priority: 3),
    ContextualTip(title: I18nManager.shared.t(.onb_tip_key_title), message: I18nManager.shared.t(.onb_tip_key_msg), icon: "keyboard", targetModule: nil, priority: 4),
    ContextualTip(title: I18nManager.shared.t(.onb_tip_offline_title), message: I18nManager.shared.t(.onb_tip_offline_msg), icon: "lock.shield", targetModule: "settings", priority: 5),
]

// MARK: - 帮助面板

struct HelpPanelView: View {
    @State private var selectedTab: HelpTab = .tips
    @State private var searchText = ""

    enum HelpTab: String, CaseIterable {
        case tips
        case faq
        case shortcuts
        case about

        var localizedName: String {
            switch self {
            case .tips:      return I18nManager.shared.t(.onb_tab_tips)
            case .faq:       return I18nManager.shared.t(.onb_tab_faq)
            case .shortcuts: return I18nManager.shared.t(.onb_tab_shortcuts)
            case .about:     return I18nManager.shared.t(.onb_tab_about)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(HelpTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
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
        .searchable(text: $searchText, prompt: I18nManager.shared.t(.onb_search_hint))
    }
}

struct FAQView: View {
    @State private var selectedItem: String?

    var faqs: [(question: String, answer: String)] {
        [
            (I18nManager.shared.t(.onb_faq_free_q), I18nManager.shared.t(.onb_faq_free_a)),
            (I18nManager.shared.t(.onb_faq_intel_q), I18nManager.shared.t(.onb_faq_intel_a)),
            (I18nManager.shared.t(.onb_faq_install_q), I18nManager.shared.t(.onb_faq_install_a)),
            (I18nManager.shared.t(.onb_faq_cloud_q), I18nManager.shared.t(.onb_faq_cloud_a)),
            (I18nManager.shared.t(.onb_faq_update_q), I18nManager.shared.t(.onb_faq_update_a)),
            (I18nManager.shared.t(.onb_faq_lang_q), I18nManager.shared.t(.onb_faq_lang_a)),
            (I18nManager.shared.t(.onb_faq_plugin_q), I18nManager.shared.t(.onb_faq_plugin_a)),
            (I18nManager.shared.t(.onb_faq_lan_q), I18nManager.shared.t(.onb_faq_lan_a)),
        ]
    }

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
    var shortcuts: [(keys: String, action: String)] {
        [
            ("Cmd + 1-9", I18nManager.shared.t(.onb_sc_mod)),
            ("Cmd + ,", I18nManager.shared.t(.onb_sc_settings)),
            ("Cmd + R", I18nManager.shared.t(.onb_sc_run)),
            ("Cmd + B", I18nManager.shared.t(.onb_sc_build)),
            ("Cmd + Shift + F", I18nManager.shared.t(.onb_sc_search)),
            ("Cmd + Shift + H", I18nManager.shared.t(.onb_sc_help)),
            ("Cmd + Shift + N", I18nManager.shared.t(.onb_sc_new)),
            ("Cmd + Shift + E", I18nManager.shared.t(.onb_sc_export)),
            ("Space", I18nManager.shared.t(.onb_sc_preview)),
            ("Esc", I18nManager.shared.t(.onb_sc_cancel)),
        ]
    }

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

            Text(I18nManager.shared.tf(.onb_about_version, updateManager.currentVersion, updateManager.currentBuild))
                .font(.title3)
                .foregroundColor(.secondary)

            Text(I18nManager.shared.t(.onb_about_tagline))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            VStack(alignment: .leading, spacing: 8) {
                Label(I18nManager.shared.t(.onb_about_macos), systemImage: "cpu")
                Label(I18nManager.shared.t(.onb_about_offline), systemImage: "lock.shield")
                Label(I18nManager.shared.t(.onb_about_modules), systemImage: "square.grid.3x3")
                Label(I18nManager.shared.t(.onb_about_license), systemImage: "doc.text")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Button(action: { updateManager.checkForUpdates(force: true) }) {
                Label(I18nManager.shared.t(.onb_about_check_update), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .padding(.top)

            Spacer()

            Text(I18nManager.shared.t(.onb_about_copyright))
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
            Label(I18nManager.shared.t(.onb_btn_reset), systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
