import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.fusion.studio", category: "ThemeSwitcher")

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"
    case custom = "自定义"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        case .custom: return "paintbrush"
        }
    }
}

class ThemeSwitcherState: ObservableObject {
    static let shared = ThemeSwitcherState()

    @Published var mode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "app_theme_mode")
            applyTheme()
            logger.info("Theme mode changed to \(self.mode.rawValue)")
        }
    }
    @Published var customAccentHex: String {
        didSet {
            UserDefaults.standard.set(customAccentHex, forKey: "custom_accent_hex")
            if mode == .custom { applyTheme() }
        }
    }

    init() {
        let savedMode = UserDefaults.standard.string(forKey: "app_theme_mode") ?? "跟随系统"
        self.mode = AppThemeMode(rawValue: savedMode) ?? .system
        self.customAccentHex = UserDefaults.standard.string(forKey: "custom_accent_hex") ?? "#007AFF"
    }

    func applyTheme() {
        switch mode {
        case .system:
            NotificationCenter.default.post(name: .themeDidChange, object: nil, userInfo: ["theme": "system"])
        case .light:
            NotificationCenter.default.post(name: .themeDidChange, object: nil, userInfo: ["theme": "light"])
        case .dark:
            NotificationCenter.default.post(name: .themeDidChange, object: nil, userInfo: ["theme": "dark"])
        case .custom:
            NotificationCenter.default.post(name: .themeDidChange, object: nil, userInfo: ["theme": "custom", "accent": customAccentHex])
        }
    }

    func resetToDefault() {
        mode = .system
        customAccentHex = "#007AFF"
    }
}

extension Notification.Name {
    static let themeDidChange = Notification.Name("theme.didChange")
}

struct ThemeSwitcherView: View {
    @StateObject private var state = ThemeSwitcherState.shared
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingM) {
                    modePicker
                    if state.mode == .custom {
                        customAccentSection
                    }
                    previewSection
                    resetSection
                }
                .padding(theme.spacingM)
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "circle.lefthalf.filled")
                .foregroundColor(theme.accent)
            Text("主题切换")
                .font(.system(size: theme.bodySize, weight: .semibold))
                .foregroundColor(theme.text)
            Spacer()
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("外观模式")
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundColor(theme.textSecondary)

            HStack(spacing: theme.spacingS) {
                ForEach(AppThemeMode.allCases) { m in
                    Button(action: { state.mode = m }) {
                        VStack(spacing: theme.spacingXS) {
                            ZStack {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                                    .fill(state.mode == m ? theme.accentSoft : theme.groupBg)
                                    .frame(width: 56, height: 40)
                                Image(systemName: m.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(state.mode == m ? theme.accent : theme.textSecondary)
                            }
                            Text(m.rawValue)
                                .font(.system(size: 10))
                                .foregroundColor(state.mode == m ? theme.accentText : theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                            .stroke(state.mode == m ? theme.accent : Color.clear, lineWidth: 2)
                            .frame(width: 56, height: 40)
                    )
                }
            }
        }
    }

    private var customAccentSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("自定义强调色")
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundColor(theme.textSecondary)

            HStack(spacing: theme.spacingS) {
                TextField("#007AFF", text: $state.customAccentHex)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundColor(theme.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.inputBg)
                    .cornerRadius(theme.cornerRadiusSmall)
                    .frame(width: 100)

                HStack(spacing: theme.spacingXS) {
                    accentSwatch("#007AFF", label: "蓝")
                    accentSwatch("#FF3B30", label: "红")
                    accentSwatch("#34C759", label: "绿")
                    accentSwatch("#FF9500", label: "橙")
                    accentSwatch("#AF52DE", label: "紫")
                    accentSwatch("#FF2D55", label: "粉")
                }
            }
        }
    }

    private func accentSwatch(_ hex: String, label: String) -> some View {
        Button(action: { state.customAccentHex = hex }) {
            VStack(spacing: 2) {
                Circle()
                    .fill(Color(hex: hex) ?? theme.accent)
                    .frame(width: 20, height: 20)
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("预览")
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundColor(theme.textSecondary)

            HStack(spacing: theme.spacingS) {
                previewCard("浅色", isLight: true)
                previewCard("深色", isLight: false)
            }
        }
    }

    private func previewCard(_ title: String, isLight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            HStack(spacing: 6) {
                Circle().fill(isLight ? Color.black.opacity(0.1) : Color.white.opacity(0.2)).frame(width: 12, height: 12)
                Circle().fill(isLight ? Color.black.opacity(0.05) : Color.white.opacity(0.1)).frame(width: 12, height: 12)
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(isLight ? Color(red: 0, green: 122/255, blue: 1) : Color(red: 0, green: 122/255, blue: 1))
                .frame(height: 20)
                .overlay(Text("Button").font(.system(size: 9)).foregroundColor(.white))
        }
        .padding(12)
        .background(isLight ? Color(white: 0.97) : Color(white: 0.12))
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
    }

    private var resetSection: some View {
        Button(action: { state.resetToDefault() }) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                Text("重置为默认")
                    .font(.system(size: theme.captionSize))
            }
            .foregroundColor(theme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
