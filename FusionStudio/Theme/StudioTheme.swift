// Callers: ContentView, SidebarView, AgentStudioView, all Module views via @Environment(\.studioTheme).
// Affected API: StudioTheme struct (adding ~20 new token properties, ShadowConfig struct, animation/spring helpers).
// Data schemas: ShadowConfig(color/radius/x/y), new Color/CGFloat tokens — additive only, no breaking changes.
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import SwiftUI

// MARK: - Apple HIG Design Tokens

struct StudioTheme: Sendable {
    let isDark: Bool

    // Surfaces — Apple HIG hierarchy: window < sidebar < content < elevated < overlay
    let windowBg: Color
    let sidebarBg: Color
    let sidebarBorder: Color
    let contentBg: Color
    let toolbarBg: Color
    let toolbarBorder: Color
    let groupBg: Color
    let groupBorder: Color
    let rowSep: Color
    let separator: Color
    let surfacePrimary: Color
    let surfaceSecondary: Color
    let surfaceElevated: Color
    let surfaceOverlay: Color

    // Text — Apple HIG: primary, secondary, tertiary, quaternary
    let text: Color
    let textSecondary: Color
    let textTertiary: Color
    let textQuaternary: Color

    // Accent + selection — Apple HIG: system tint, vibrancy
    let accent: Color
    let accentSoft: Color
    let accentText: Color
    let accentSecondary: Color
    let accentDestructive: Color
    let auxiliary: Color
    let auxiliarySoft: Color
    let selBg: Color
    let hoverBg: Color

    // Controls — Apple HIG: filled, tinted, gray, bordered
    let controlBg: Color
    let controlBgHover: Color
    let controlTinted: Color
    let inputBg: Color
    let inputBorder: Color
    let inputBorderFocus: Color

    // Status — Apple HIG semantic colors
    let greenDot: Color
    let amberDot: Color
    let redDot: Color
    let blueDot: Color
    let successBg: Color
    let successText: Color
    let warningBg: Color
    let warningText: Color
    let errorBg: Color
    let errorText: Color
    let infoBg: Color
    let infoText: Color

    // Code + monospace
    let codeBg: Color
    let codeText: Color

    // MARK: - Spacing Tokens (8px grid rhythm, 4px half-step - Apple HIG 4pt grid)
    // Primary spine: 8/16/24/32; 4 = half-step; 12 = legacy 4pt sub-step (292 consumers, retained).
    let spacingXS: CGFloat = 4
    let spacingS: CGFloat = 8
    let spacingM: CGFloat = 12
    let spacingL: CGFloat = 16
    let spacingXL: CGFloat = 24
    let spacing2XL: CGFloat = 32

    // MARK: - Radius Tokens
    let cornerRadius: CGFloat = 12
    let cornerRadiusSmall: CGFloat = 8
    let cornerRadiusLarge: CGFloat = 16
    let rowRadius: CGFloat = 8

    // MARK: - Font Size Tokens (Apple HIG type scale)
    let captionSize: CGFloat = 12
    let footnoteSize: CGFloat = 13
    let smallTextSize: CGFloat = 14
    let textSize: CGFloat = 15
    let bodySize: CGFloat = 16
    let titleSize: CGFloat = 19
    let headlineSize: CGFloat = 22
    let largeTitleSize: CGFloat = 30

    // MARK: - Animation Tokens
    let animationFast: Double = 0.15
    let animationNormal: Double = 0.25
    let animationSlow: Double = 0.35

    // MARK: - Shadow Tokens
    let shadowSmall: ShadowConfig
    let shadowMedium: ShadowConfig
    let shadowLarge: ShadowConfig

    // MARK: - Icon Size Tokens
    let iconXS: CGFloat = 12
    let iconS: CGFloat = 14
    let iconM: CGFloat = 16
    let iconL: CGFloat = 20
    let iconXL: CGFloat = 24
}

// MARK: - Shadow Config

struct ShadowConfig: Sendable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Theme Environment

struct StudioThemeKey: EnvironmentKey {
    static let defaultValue: StudioTheme = .light
}

extension EnvironmentValues {
    var studioTheme: StudioTheme {
        get { self[StudioThemeKey.self] }
        set { self[StudioThemeKey.self] = newValue }
    }
}

// MARK: - Theme Values

extension StudioTheme {
    static let light = StudioTheme(
        isDark: false,
        windowBg: Color(nsColor: .windowBackgroundColor),
        sidebarBg: Color(nsColor: .windowBackgroundColor),
        sidebarBorder: Color(nsColor: .separatorColor).opacity(0.5),
        contentBg: Color(nsColor: .controlBackgroundColor),
        toolbarBg: Color(nsColor: .windowBackgroundColor),
        toolbarBorder: Color(nsColor: .separatorColor).opacity(0.5),
        groupBg: Color(nsColor: .controlBackgroundColor).opacity(0.8),
        groupBorder: Color(nsColor: .separatorColor).opacity(0.3),
        rowSep: Color(nsColor: .separatorColor).opacity(0.3),
        separator: Color(nsColor: .separatorColor),
        surfacePrimary: Color(nsColor: .windowBackgroundColor),
        surfaceSecondary: Color(nsColor: .controlBackgroundColor),
        surfaceElevated: .white,
        surfaceOverlay: .white.opacity(0.85),
        text: Color(nsColor: .labelColor),
        textSecondary: Color(nsColor: .secondaryLabelColor),
        textTertiary: Color(nsColor: .tertiaryLabelColor),
        textQuaternary: Color(nsColor: .quaternaryLabelColor),
        accent: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0),
        accentSoft: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0).opacity(0.10),
        accentText: .white,
        accentSecondary: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0).opacity(0.6),
        accentDestructive: Color(red: 0.91, green: 0.30, blue: 0.24),
        auxiliary: Color(red: 31.0/255.0, green: 41.0/255.0, blue: 55.0/255.0),
        auxiliarySoft: Color(red: 31.0/255.0, green: 41.0/255.0, blue: 55.0/255.0).opacity(0.12),
        selBg: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0).opacity(0.10),
        hoverBg: Color(nsColor: .controlColor).opacity(0.06),
        controlBg: Color(nsColor: .controlBackgroundColor),
        controlBgHover: Color(nsColor: .controlBackgroundColor).opacity(0.92),
        controlTinted: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0).opacity(0.08),
        inputBg: Color(nsColor: .textBackgroundColor),
        inputBorder: Color(nsColor: .separatorColor).opacity(0.5),
        inputBorderFocus: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0),
        greenDot: Color(red: 0.20, green: 0.78, blue: 0.35),
        amberDot: Color(red: 1.0, green: 0.76, blue: 0.03),
        redDot: Color(red: 0.91, green: 0.30, blue: 0.24),
        blueDot: Color(red: 0.24, green: 0.55, blue: 0.96),
        successBg: Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.10),
        successText: Color(red: 0.16, green: 0.60, blue: 0.24),
        warningBg: Color(red: 1.0, green: 0.76, blue: 0.03).opacity(0.10),
        warningText: Color(red: 0.80, green: 0.55, blue: 0.0),
        errorBg: Color(red: 0.91, green: 0.30, blue: 0.24).opacity(0.10),
        errorText: Color(red: 0.85, green: 0.20, blue: 0.15),
        infoBg: Color(red: 0.24, green: 0.55, blue: 0.96).opacity(0.10),
        infoText: Color(red: 0.20, green: 0.45, blue: 0.85),
        codeBg: Color.black.opacity(0.04),
        codeText: Color(nsColor: .labelColor),
        shadowSmall: ShadowConfig(color: .black.opacity(0.04), radius: 2, x: 0, y: 1),
        shadowMedium: ShadowConfig(color: .black.opacity(0.08), radius: 8, x: 0, y: 2),
        shadowLarge: ShadowConfig(color: .black.opacity(0.12), radius: 16, x: 0, y: 4)
    )

    static let dark = StudioTheme(
        isDark: true,
        windowBg: Color(red: 0.118, green: 0.118, blue: 0.125),
        sidebarBg: Color(red: 31.0/255.0, green: 41.0/255.0, blue: 55.0/255.0),
        sidebarBorder: Color(white: 1.0).opacity(0.08),
        contentBg: Color(red: 0.110, green: 0.110, blue: 0.118),
        toolbarBg: Color(red: 0.118, green: 0.118, blue: 0.125),
        toolbarBorder: Color(white: 1.0).opacity(0.08),
        groupBg: Color(red: 0.173, green: 0.173, blue: 0.180).opacity(0.8),
        groupBorder: Color(white: 1.0).opacity(0.06),
        rowSep: Color(white: 1.0).opacity(0.06),
        separator: Color(white: 1.0).opacity(0.10),
        surfacePrimary: Color(red: 0.118, green: 0.118, blue: 0.125),
        surfaceSecondary: Color(red: 0.173, green: 0.173, blue: 0.180),
        surfaceElevated: Color(red: 0.220, green: 0.220, blue: 0.227),
        surfaceOverlay: Color(red: 0.100, green: 0.100, blue: 0.110).opacity(0.90),
        text: Color(white: 0.98),
        textSecondary: Color(white: 0.82),
        textTertiary: Color(white: 0.65),
        textQuaternary: Color(white: 0.45),
        accent: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0),
        accentSoft: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0).opacity(0.15),
        accentText: .white,
        accentSecondary: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0).opacity(0.6),
        accentDestructive: Color(red: 1.0, green: 0.42, blue: 0.42),
        auxiliary: Color(red: 31.0/255.0, green: 41.0/255.0, blue: 55.0/255.0),
        auxiliarySoft: Color(red: 31.0/255.0, green: 41.0/255.0, blue: 55.0/255.0).opacity(0.16),
        selBg: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0).opacity(0.20),
        hoverBg: Color(white: 1.0).opacity(0.06),
        controlBg: Color(red: 0.173, green: 0.173, blue: 0.180),
        controlBgHover: Color(red: 0.200, green: 0.200, blue: 0.210),
        controlTinted: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0).opacity(0.12),
        inputBg: Color(red: 0.140, green: 0.140, blue: 0.150),
        inputBorder: Color(white: 1.0).opacity(0.08),
        inputBorderFocus: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0),
        greenDot: Color(red: 0.30, green: 0.85, blue: 0.45),
        amberDot: Color(red: 1.0, green: 0.80, blue: 0.20),
        redDot: Color(red: 1.0, green: 0.42, blue: 0.42),
        blueDot: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0),
        successBg: Color(red: 0.30, green: 0.85, blue: 0.45).opacity(0.12),
        successText: Color(red: 0.40, green: 0.90, blue: 0.55),
        warningBg: Color(red: 1.0, green: 0.80, blue: 0.20).opacity(0.12),
        warningText: Color(red: 1.0, green: 0.85, blue: 0.40),
        errorBg: Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.12),
        errorText: Color(red: 1.0, green: 0.55, blue: 0.55),
        infoBg: Color(red: 0.0, green: 122.0 / 255.0, blue: 1.0).opacity(0.12),
        infoText: Color(red: 0.35, green: 0.72, blue: 1.0),
        codeBg: Color.white.opacity(0.06),
        codeText: Color(white: 0.92),
        shadowSmall: ShadowConfig(color: .black.opacity(0.25), radius: 2, x: 0, y: 1),
        shadowMedium: ShadowConfig(color: .black.opacity(0.35), radius: 8, x: 0, y: 2),
        shadowLarge: ShadowConfig(color: .black.opacity(0.45), radius: 16, x: 0, y: 4)
    )
}

// MARK: - View shadow helpers

extension View {
    func studioShadow(_ config: ShadowConfig) -> some View {
        shadow(color: config.color, radius: config.radius, x: config.x, y: config.y)
    }
}

// MARK: - Animation helpers

extension StudioTheme {
    var springDefault: Animation {
        .spring(response: 0.35, dampingFraction: 0.85)
    }

    var springBouncy: Animation {
        .spring(response: 0.4, dampingFraction: 0.65)
    }

    var springSnappy: Animation {
        .spring(response: 0.25, dampingFraction: 0.9)
    }

    var transitionSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    var transitionFade: AnyTransition { .opacity }

    var transitionScale: AnyTransition {
        .scale(scale: 0.96).combined(with: .opacity)
    }
}

// MARK: - Theme Modifier

struct StudioThemeModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content.environment(\.studioTheme, colorScheme == .dark ? .dark : .light)
    }
}

extension View {
    func studioThemed() -> some View {
        modifier(StudioThemeModifier())
    }
}

// MARK: - Reusable Components (Apple HIG refined)

struct ListGroup<Content: View>: View {
    let content: () -> Content
    @Environment(\.studioTheme) var theme

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) { content() }
            .background(theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .studioShadow(theme.shadowSmall)
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingXS)
    }
}

struct StudioRow<Trailing: View>: View {
    let label: String?
    let sublabel: String?
    let isLast: Bool
    let trailing: Trailing
    @Environment(\.studioTheme) var theme

    init(label: String? = nil, sublabel: String? = nil, isLast: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.label = label; self.sublabel = sublabel; self.isLast = isLast; self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: theme.spacingM) {
            if let label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: theme.textSize, weight: .medium)).foregroundStyle(theme.text)
                    if let sublabel, !sublabel.isEmpty {
                        Text(sublabel).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary).lineLimit(2)
                    }
                }
                Spacer(minLength: theme.spacingM)
            }
            trailing
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS + 2)
        .frame(maxWidth: .infinity, alignment: label == nil ? .leading : .center)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(theme.rowSep).frame(height: 0.5).padding(.horizontal, theme.spacingL)
            }
        }
    }
}

struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(eyebrow)
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(0.8)
            Text(title)
                .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text)
            Text(subtitle)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.top, theme.spacingXL)
        .padding(.bottom, theme.spacingS)
    }
}

struct StatusPill: View {
    enum Status: Equatable {
        case running, stopped, error, starting, custom(color: Color, label: String)
    }
    let status: Status
    var compact: Bool = false
    @Environment(\.studioTheme) var theme

    var body: some View {
        let cfg = config
        HStack(spacing: 5) {
            Circle()
                .fill(cfg.dot)
                .frame(width: 6, height: 6)
                .overlay {
                    if case .running = status {
                        Circle()
                            .fill(cfg.dot.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
            if !compact {
                Text(cfg.label)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(cfg.text)
            }
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(cfg.bg))
    }

    private var config: (dot: Color, text: Color, bg: Color, label: String) {
        switch status {
        case .running:  return (theme.greenDot, theme.successText, theme.successBg, "Running")
        case .starting: return (theme.blueDot, theme.infoText, theme.infoBg, "Starting")
        case .stopped:  return (theme.textTertiary, theme.textSecondary, theme.controlBg, "Stopped")
        case .error:    return (theme.redDot, theme.errorText, theme.errorBg, "Error")
        case .custom(let color, let label): return (color, color, color.opacity(0.15), label)
        }
    }
}

struct StudioSectionHeader: View {
    let title: String
    @Environment(\.studioTheme) var theme
    var body: some View {
        Text(title)
            .font(.system(size: theme.footnoteSize, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(0.8)
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingL)
            .padding(.bottom, theme.spacingXS)
    }
}
