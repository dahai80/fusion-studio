// Callers: ModuleDetailView routing.
// Affected API: AccessibilityService (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import AppKit

// MARK: - 无障碍配置

struct AccessibilityConfig {
    var enableVoiceOver: Bool = true
    var enableKeyboardNavigation: Bool = true
    var enableReducedMotion: Bool = false
    var enableHighContrast: Bool = false
    var enableLargeText: Bool = false
    var focusRingVisible: Bool = true
    var announceChanges: Bool = true
    var keyboardShortcutModifier: KeyModifier = .command

    enum KeyModifier: String, CaseIterable {
        case command = "⌘ Command"
        case option  = "⌥ Option"
        case control = "⌃ Control"
        case shift   = "⇧ Shift"
    }
}

// MARK: - 无障碍管理器

class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()

    @Published var config = AccessibilityConfig()
    @Published var focusedElement: String?
    @Published var lastAnnouncement: String?

    private let notificationCenter = NSWorkspace.shared.notificationCenter

    // MARK: - 键盘导航

    let keyboardShortcuts: [(keys: String, action: String, category: String)] = [
        ("Tab", "a11yc_sk_act_next", "a11yc_sk_cat_nav"),
        ("Shift+Tab", "a11yc_sk_act_prev", "a11yc_sk_cat_nav"),
        ("Enter/Space", "a11yc_sk_act_activate", "a11yc_sk_cat_interact"),
        ("Esc", "a11yc_sk_act_cancel", "a11yc_sk_cat_interact"),
        ("↑↓←→", "a11yc_sk_act_move", "a11yc_sk_cat_nav"),
        ("Cmd+1-9", "a11yc_sk_act_switch_module", "a11yc_sk_cat_module"),
        ("Cmd+,", "a11yc_sk_act_open_settings", "a11yc_sk_cat_settings"),
        ("Cmd+F", "a11yc_sk_act_search", "a11yc_sk_cat_search"),
        ("Cmd+R", "a11yc_sk_act_run", "a11yc_sk_cat_operation"),
        ("Cmd+Shift+H", "a11yc_sk_act_help", "a11yc_sk_cat_help"),
    ]

    // MARK: - VoiceOver 支持

    func announce(_ message: String) {
        guard config.announceChanges else { return }
        lastAnnouncement = message
        // macOS VoiceOver 播报 — 使用 NSAccessibilityElement
        #if DEBUG
        print("[VoiceOver] \(message)")
        #endif
    }

    func focusChanged(to element: String) {
        focusedElement = element
        announce(I18nManager.shared.tf(.a11yc_focus_moved_fmt, element))
    }

    // MARK: - 减少动态效果

    func shouldReduceMotion() -> Bool {
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion || config.enableReducedMotion
    }

    func shouldIncreaseContrast() -> Bool {
        return NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast || config.enableHighContrast
    }

    // MARK: - 字体大小

    func scaledFontSize(_ baseSize: CGFloat) -> CGFloat {
        guard config.enableLargeText else { return baseSize }
        let scaleFactor: CGFloat = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 1.25 : 1.15
        return baseSize * scaleFactor
    }
}

// MARK: - 无障碍修饰符

struct AccessibilityViewModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits?

    init(label: String, hint: String? = nil, traits: AccessibilityTraits? = nil) {
        self.label = label
        self.hint = hint
        self.traits = traits
    }

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

extension View {
    func a11y(label: String, hint: String? = nil, traits: AccessibilityTraits? = nil) -> some View {
        modifier(AccessibilityViewModifier(label: label, hint: hint, traits: traits))
    }
}

// MARK: - 焦点环

struct FocusRingModifier: ViewModifier {
    @State private var isFocused = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                    .padding(2)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { isFocused = hovering }
            }
    }
}

extension View {
    func focusRing() -> some View {
        modifier(FocusRingModifier())
    }
}

// MARK: - 无障碍设置面板

struct AccessibilitySettingsView: View {
    @StateObject private var a11y = AccessibilityManager.shared
    @State private var selectedTab: A11yTab = .general

    enum A11yTab: String, CaseIterable {
        case general
        case keyboard
        case display

        var localizedName: String {
            switch self {
            case .general:  return I18nManager.shared.t(.a11yc_tab_general)
            case .keyboard: return I18nManager.shared.t(.a11yc_tab_keyboard)
            case .display:  return I18nManager.shared.t(.a11yc_tab_display)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(A11yTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            switch selectedTab {
            case .general:  GeneralA11yView()
            case .keyboard: KeyboardA11yView()
            case .display:  DisplayA11yView()
            }
        }
    }

    private func tabIcon(_ tab: A11yTab) -> String {
        switch tab { case .general: return "person.crop.circle"; case .keyboard: return "keyboard"; case .display: return "eye" }
    }
}

struct GeneralA11yView: View {
    @StateObject private var a11y = AccessibilityManager.shared

    var body: some View {
        Form {
            Section(I18nManager.shared.t(.a11yc_sec_voiceover)) {
                Toggle(I18nManager.shared.t(.a11yc_enable_voiceover), isOn: $a11y.config.enableVoiceOver)
                Toggle(I18nManager.shared.t(.a11yc_announce_changes), isOn: $a11y.config.announceChanges)
                if a11y.config.announceChanges {
                    Button(I18nManager.shared.t(.a11yc_test_announce)) {
                        a11y.announce(I18nManager.shared.t(.a11yc_test_announce_msg))
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section(I18nManager.shared.t(.a11yc_sec_focus)) {
                Toggle(I18nManager.shared.t(.a11yc_show_focus_ring), isOn: $a11y.config.focusRingVisible)
                Toggle(I18nManager.shared.t(.a11yc_enable_kb_nav), isOn: $a11y.config.enableKeyboardNavigation)
            }

            Section(I18nManager.shared.t(.a11yc_sec_status)) {
                if let focus = a11y.focusedElement {
                    HStack { Text(I18nManager.shared.t(.a11yc_current_focus)); Spacer(); Text(focus).font(.system(.body, design: .monospaced)) }
                }
                if let announce = a11y.lastAnnouncement {
                    HStack { Text(I18nManager.shared.t(.a11yc_last_announce)); Spacer(); Text(announce).font(.caption).foregroundColor(.secondary) }
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

struct KeyboardA11yView: View {
    @StateObject private var a11y = AccessibilityManager.shared

    var body: some View {
        Form {
            Section(I18nManager.shared.t(.a11yc_sec_mod_key)) {
                Picker(I18nManager.shared.t(.a11yc_mod_key), selection: $a11y.config.keyboardShortcutModifier) {
                    ForEach(AccessibilityConfig.KeyModifier.allCases, id: \.self) { mod in
                        Text(mod.rawValue).tag(mod)
                    }
                }
            }

            Section(I18nManager.shared.t(.a11yc_sec_shortcuts)) {
                ForEach(a11y.keyboardShortcuts, id: \.keys) { shortcut in
                    HStack {
                        Text(I18nManager.shared.t(shortcut.action))
                            .font(.subheadline)
                        Spacer()
                        Text(shortcut.keys)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

struct DisplayA11yView: View {
    @StateObject private var a11y = AccessibilityManager.shared

    var body: some View {
        Form {
            Section(I18nManager.shared.t(.a11yc_sec_display)) {
                Toggle(I18nManager.shared.t(.a11yc_reduce_motion), isOn: $a11y.config.enableReducedMotion)
                Toggle(I18nManager.shared.t(.a11yc_high_contrast), isOn: $a11y.config.enableHighContrast)
                Toggle(I18nManager.shared.t(.a11yc_large_text), isOn: $a11y.config.enableLargeText)
            }

            Section(I18nManager.shared.t(.a11yc_sec_preview)) {
                VStack(spacing: 12) {
                    Text(I18nManager.shared.t(.a11yc_sample_text))
                        .font(.system(size: a11y.scaledFontSize(14)))
                    Text(I18nManager.shared.tf(.a11yc_scaled_fmt, String(format: "%.0f", a11y.scaledFontSize(14))))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if a11y.config.enableHighContrast {
                        HStack {
                            Rectangle().fill(Color.primary).frame(width: 20, height: 20)
                            Rectangle().fill(Color.secondary).frame(width: 20, height: 20)
                            Rectangle().fill(Color.accentColor).frame(width: 20, height: 20)
                        }
                        Text(I18nManager.shared.t(.a11yc_high_contrast_on))
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            Section(I18nManager.shared.t(.a11yc_sec_system)) {
                Text(I18nManager.shared.t(.a11yc_system_hint))
                    .font(.caption).foregroundColor(.secondary)
                Button(I18nManager.shared.t(.a11yc_open_settings)) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess")!)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - 无障碍标签视图

struct A11yLabel: View {
    let label: String
    let value: String
    let hint: String?

    init(_ label: String, value: String, hint: String? = nil) {
        self.label = label
        self.value = value
        self.hint = hint
    }

    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(.body, design: .monospaced))
        }
        .a11y(label: "\(label): \(value)", hint: hint)
    }
}

// MARK: - 键盘导航视图

struct KeyboardNavigableView: View {
    @Environment(\.studioTheme) private var theme
    let title: String
    let content: String
    let shortcut: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(content).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(shortcut)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(8)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
        .focusRing()
        .a11y(label: I18nManager.shared.tf(.a11yc_nav_label_fmt, title, shortcut))
    }
}

// MARK: - 无障碍状态指示器

struct A11yStatusIndicator: View {
    @StateObject private var a11y = AccessibilityManager.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: a11y.config.enableVoiceOver ? "voiceover" : "voiceover.slash")
                .foregroundColor(a11y.config.enableVoiceOver ? .green : .gray)
                .font(.caption)
            if a11y.config.enableKeyboardNavigation {
                Image(systemName: "keyboard")
                    .foregroundColor(.blue)
                    .font(.caption)
            }
        }
        .help(I18nManager.shared.tf(.a11yc_status_help_fmt,
             I18nManager.shared.tf(.a11yc_voiceover_state_fmt, a11y.config.enableVoiceOver ? I18nManager.shared.t(.a11yc_on) : I18nManager.shared.t(.a11yc_off)),
             I18nManager.shared.tf(.a11yc_kbnav_state_fmt, a11y.config.enableKeyboardNavigation ? I18nManager.shared.t(.a11yc_on) : I18nManager.shared.t(.a11yc_off))))
    }
}