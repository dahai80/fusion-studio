// Importers/callers: AgentStudioView, SidebarView, LogPanelView, ProfilerView, SettingsView, all Module detail views.
// Affected API: FusionButton view (Style: primary/secondary/tinted/destructive/ghost, Size: small/regular/large).
// Data schemas: None (pure view component). User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import SwiftUI

struct FusionButton: View {
    enum Style { case primary, secondary, tinted, destructive, ghost }
    enum Size { case small, regular, large }

    let title: String
    let icon: String?
    let style: Style
    let size: Size
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.studioTheme) var theme

    init(_ title: String, icon: String? = nil, style: Style = .primary, size: Size = .regular, isLoading: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.style = style; self.size = size
        self.isLoading = isLoading; self.isDisabled = isDisabled; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacingS) {
                if isLoading {
                    ProgressView()
                        .controlSize(size == .small ? .small : .regular)
                        .tint(fgColor)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: iconSize, weight: .medium))
                }
                Text(title).font(.system(size: fontSizer, weight: .medium))
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .frame(minWidth: minWidth)
            .background(bgColor)
            .foregroundStyle(fgColor)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
            .overlay {
                if style == .secondary || style == .ghost {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity((isDisabled || isLoading) ? 0.5 : 1.0)
        .animation(theme.springSnappy, value: isLoading)
    }

    private var fontSizer: CGFloat {
        switch size { case .small: theme.smallTextSize; case .regular: theme.textSize; case .large: theme.bodySize }
    }
    private var iconSize: CGFloat {
        switch size { case .small: theme.iconS; case .regular: theme.iconM; case .large: theme.iconL }
    }
    private var hPad: CGFloat {
        switch size { case .small: theme.spacingM; case .regular: theme.spacingL; case .large: theme.spacingXL }
    }
    private var vPad: CGFloat {
        switch size { case .small: 5; case .regular: 7; case .large: 10 }
    }
    private var minWidth: CGFloat? {
        switch size { case .small: nil; case .regular: 80; case .large: 120 }
    }
    private var bgColor: Color {
        switch style {
        case .primary: theme.accent
        case .secondary: theme.controlBg
        case .tinted: theme.accentSoft
        case .destructive: theme.accentDestructive
        case .ghost: .clear
        }
    }
    private var fgColor: Color {
        switch style {
        case .primary: theme.accentText
        case .secondary: theme.text
        case .tinted: theme.accent
        case .destructive: .white
        case .ghost: theme.textSecondary
        }
    }
    private var borderColor: Color {
        switch style {
        case .secondary: theme.inputBorder
        case .ghost: .clear
        default: .clear
        }
    }
}
