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
        ("Tab", "移动到下一个元素", "导航"),
        ("Shift+Tab", "移动到上一个元素", "导航"),
        ("Enter/Space", "激活当前元素", "交互"),
        ("Esc", "取消/关闭", "交互"),
        ("↑↓←→", "在元素间移动", "导航"),
        ("Cmd+1-9", "切换模块", "模块"),
        ("Cmd+,", "打开设置", "设置"),
        ("Cmd+F", "搜索", "搜索"),
        ("Cmd+R", "运行", "操作"),
        ("Cmd+Shift+H", "显示帮助", "帮助"),
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
        announce("焦点已移至: \(element)")
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
        case general  = "通用"
        case keyboard = "键盘"
        case display  = "显示"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(A11yTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
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
            Section("VoiceOver") {
                Toggle("启用 VoiceOver 支持", isOn: $a11y.config.enableVoiceOver)
                Toggle("播报界面变化", isOn: $a11y.config.announceChanges)
                if a11y.config.announceChanges {
                    Button("测试播报") {
                        a11y.announce("这是一条测试播报消息")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("焦点管理") {
                Toggle("显示焦点环", isOn: $a11y.config.focusRingVisible)
                Toggle("启用键盘导航", isOn: $a11y.config.enableKeyboardNavigation)
            }

            Section("当前状态") {
                if let focus = a11y.focusedElement {
                    HStack { Text("当前焦点"); Spacer(); Text(focus).font(.system(.body, design: .monospaced)) }
                }
                if let announce = a11y.lastAnnouncement {
                    HStack { Text("最后播报"); Spacer(); Text(announce).font(.caption).foregroundColor(.secondary) }
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
            Section("快捷键修饰键") {
                Picker("修饰键", selection: $a11y.config.keyboardShortcutModifier) {
                    ForEach(AccessibilityConfig.KeyModifier.allCases, id: \.self) { mod in
                        Text(mod.rawValue).tag(mod)
                    }
                }
            }

            Section("键盘快捷键") {
                ForEach(a11y.keyboardShortcuts, id: \.keys) { shortcut in
                    HStack {
                        Text(shortcut.action)
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
            Section("显示适配") {
                Toggle("减少动态效果", isOn: $a11y.config.enableReducedMotion)
                Toggle("增强对比度", isOn: $a11y.config.enableHighContrast)
                Toggle("大文本", isOn: $a11y.config.enableLargeText)
            }

            Section("预览") {
                VStack(spacing: 12) {
                    Text("示例文本")
                        .font(.system(size: a11y.scaledFontSize(14)))
                    Text("缩放后: \(a11y.scaledFontSize(14), specifier: "%.0f")pt (基础 14pt)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if a11y.config.enableHighContrast {
                        HStack {
                            Rectangle().fill(Color.primary).frame(width: 20, height: 20)
                            Rectangle().fill(Color.secondary).frame(width: 20, height: 20)
                            Rectangle().fill(Color.accentColor).frame(width: 20, height: 20)
                        }
                        Text("高对比度模式已启用")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            Section("系统设置") {
                Text("macOS 系统辅助功能设置可在「系统设置 → 辅助功能」中调整")
                    .font(.caption).foregroundColor(.secondary)
                Button("打开辅助功能设置") {
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
        .a11y(label: "\(title), 快捷键: \(shortcut)")
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
        .help("VoiceOver: \(a11y.config.enableVoiceOver ? "已启用" : "已禁用")\n键盘导航: \(a11y.config.enableKeyboardNavigation ? "已启用" : "已禁用")")
    }
}