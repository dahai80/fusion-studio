// Callers: ModuleDetailView.designInfoPanel (embedded as tab)
// Affected API: DesignTokenPanel (new view), DesignTokenCategory (new enum)
// Data schemas: StudioTheme token properties (read-only display)
// User instruction: Task #33 — Fusion Design Token 系统 + 组件库面板

import SwiftUI

enum DesignTokenCategory: String, CaseIterable {
    case colors = "颜色"
    case spacing = "间距"
    case typography = "排版"
    case radius = "圆角"
    case shadows = "阴影"
    case animation = "动画"

    var icon: String {
        switch self {
        case .colors: return "paintpalette"
        case .spacing: return "arrow.left.and.right"
        case .typography: return "textformat"
        case .radius: return "square.dashed"
        case .shadows: return "shadow"
        case .animation: return "waveform.path"
        }
    }
}

struct DesignTokenPanel: View {
    @Environment(\.studioTheme) var theme
    @State private var selectedCategory: DesignTokenCategory = .colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            categoryTabs
            Rectangle().fill(theme.separator).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingM) {
                    tokenContent
                }
                .padding(theme.spacingM)
            }
        }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingXS) {
                ForEach(DesignTokenCategory.allCases, id: \.self) { cat in
                    Button(action: { selectedCategory = cat }) {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 10))
                            Text(cat.rawValue)
                                .font(.system(size: theme.captionSize, weight: .medium))
                        }
                        .foregroundStyle(selectedCategory == cat ? theme.accentText : theme.textSecondary)
                        .padding(.horizontal, theme.spacingS)
                        .padding(.vertical, theme.spacingXS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(selectedCategory == cat ? theme.accent : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(theme.spacingS)
        }
    }

    @ViewBuilder
    private var tokenContent: some View {
        switch selectedCategory {
        case .colors: colorTokens
        case .spacing: spacingTokens
        case .typography: typographyTokens
        case .radius: radiusTokens
        case .shadows: shadowTokens
        case .animation: animationTokens
        }
    }

    private var colorTokens: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            tokenSectionHeader("Surface")
            colorGrid([
                ("windowBg", theme.windowBg), ("sidebarBg", theme.sidebarBg),
                ("contentBg", theme.contentBg), ("toolbarBg", theme.toolbarBg),
                ("surfacePrimary", theme.surfacePrimary), ("surfaceSecondary", theme.surfaceSecondary),
                ("surfaceElevated", theme.surfaceElevated), ("surfaceOverlay", theme.surfaceOverlay),
                ("groupBg", theme.groupBg)
            ])

            tokenSectionHeader("Text")
            colorGrid([
                ("text", theme.text), ("textSecondary", theme.textSecondary),
                ("textTertiary", theme.textTertiary), ("textQuaternary", theme.textQuaternary)
            ])

            tokenSectionHeader("Accent")
            colorGrid([
                ("accent", theme.accent), ("accentSoft", theme.accentSoft),
                ("accentText", theme.accentText), ("accentSecondary", theme.accentSecondary),
                ("accentDestructive", theme.accentDestructive)
            ])

            tokenSectionHeader("Status")
            colorGrid([
                ("greenDot", theme.greenDot), ("amberDot", theme.amberDot),
                ("redDot", theme.redDot), ("blueDot", theme.blueDot),
                ("successBg", theme.successBg), ("warningBg", theme.warningBg),
                ("errorBg", theme.errorBg), ("infoBg", theme.infoBg)
            ])

            tokenSectionHeader("Controls")
            colorGrid([
                ("controlBg", theme.controlBg), ("controlTinted", theme.controlTinted),
                ("inputBg", theme.inputBg), ("inputBorder", theme.inputBorder),
                ("selBg", theme.selBg), ("hoverBg", theme.hoverBg)
            ])
        }
    }

    private func colorGrid(_ tokens: [(String, Color)]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: theme.spacingXS),
            GridItem(.flexible(), spacing: theme.spacingXS)
        ], spacing: theme.spacingXS) {
            ForEach(tokens, id: \.0) { name, color in
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color)
                        .frame(height: 32)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(theme.groupBorder, lineWidth: 0.5)
                        )
                    Text(name)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var spacingTokens: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            tokenSectionHeader("Spacing Scale (4pt grid)")
            ForEach([
                ("spacingXS", theme.spacingXS),
                ("spacingS", theme.spacingS),
                ("spacingM", theme.spacingM),
                ("spacingL", theme.spacingL),
                ("spacingXL", theme.spacingXL),
                ("spacing2XL", theme.spacing2XL)
            ], id: \.0) { name, value in
                HStack(spacing: theme.spacingS) {
                    Text(name)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 90, alignment: .leading)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(theme.accent.opacity(0.6))
                        .frame(width: value, height: 12)
                    Spacer()
                    Text("\(Int(value))pt")
                        .font(.system(size: theme.captionSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    private var typographyTokens: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            tokenSectionHeader("Type Scale")
            ForEach([
                ("captionSize", theme.captionSize),
                ("footnoteSize", theme.footnoteSize),
                ("smallTextSize", theme.smallTextSize),
                ("textSize", theme.textSize),
                ("bodySize", theme.bodySize),
                ("titleSize", theme.titleSize),
                ("headlineSize", theme.headlineSize),
                ("largeTitleSize", theme.largeTitleSize)
            ], id: \.0) { name, size in
                HStack(spacing: theme.spacingS) {
                    Text(name)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 110, alignment: .leading)
                    Text("Aa")
                        .font(.system(size: size, weight: .medium))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Text("\(Int(size))pt")
                        .font(.system(size: theme.captionSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.vertical, 2)
            }

            tokenSectionHeader("Icon Sizes")
            ForEach([
                ("iconXS", theme.iconXS),
                ("iconS", theme.iconS),
                ("iconM", theme.iconM),
                ("iconL", theme.iconL),
                ("iconXL", theme.iconXL)
            ], id: \.0) { name, size in
                HStack(spacing: theme.spacingS) {
                    Text(name)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 70, alignment: .leading)
                    Image(systemName: "star.fill")
                        .font(.system(size: size))
                        .foregroundStyle(theme.accent)
                    Spacer()
                    Text("\(Int(size))pt")
                        .font(.system(size: theme.captionSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    private var radiusTokens: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            tokenSectionHeader("Corner Radius")
            ForEach([
                ("cornerRadiusSmall", theme.cornerRadiusSmall),
                ("cornerRadius", theme.cornerRadius),
                ("cornerRadiusLarge", theme.cornerRadiusLarge),
                ("rowRadius", theme.rowRadius)
            ], id: \.0) { name, value in
                HStack(spacing: theme.spacingM) {
                    Text(name)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 130, alignment: .leading)
                    RoundedRectangle(cornerRadius: value, style: .continuous)
                        .stroke(theme.accent, lineWidth: 1.5)
                        .fill(theme.accent.opacity(0.08))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text("\(Int(value))")
                                .font(.system(size: theme.captionSize, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.accent)
                        )
                    Spacer()
                }
            }
        }
    }

    private var shadowTokens: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            tokenSectionHeader("Shadow Scale")
            ForEach([
                ("shadowSmall", theme.shadowSmall),
                ("shadowMedium", theme.shadowMedium),
                ("shadowLarge", theme.shadowLarge)
            ], id: \.0) { name, shadow in
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(name)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                    HStack(spacing: theme.spacingL) {
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.surfaceElevated)
                            .frame(width: 64, height: 48)
                            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("radius: \(Int(shadow.radius))")
                            Text("offset: (\(Int(shadow.x)), \(Int(shadow.y)))")
                        }
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    }
                }
                .padding(theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.groupBg)
                )
            }
        }
    }

    private var animationTokens: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            tokenSectionHeader("Duration")
            ForEach([
                ("animationFast", theme.animationFast),
                ("animationNormal", theme.animationNormal),
                ("animationSlow", theme.animationSlow)
            ], id: \.0) { name, duration in
                HStack(spacing: theme.spacingS) {
                    Text(name)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 120, alignment: .leading)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(theme.accent.opacity(0.5))
                        .frame(width: CGFloat(duration) * 200, height: 10)
                    Spacer()
                    Text(String(format: "%.2fs", duration))
                        .font(.system(size: theme.captionSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            tokenSectionHeader("Spring Presets")
            ForEach([
                ("springDefault", "response: 0.35, damping: 0.85"),
                ("springBouncy", "response: 0.40, damping: 0.65"),
                ("springSnappy", "response: 0.25, damping: 0.90")
            ], id: \.0) { name, params in
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: theme.footnoteSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                    Text(params)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingXS)
            }
        }
    }

    private func tokenSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: theme.captionSize, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.top, theme.spacingXS)
    }
}
