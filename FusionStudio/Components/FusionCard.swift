// Callers: AgentStudioView, SidebarView, all Module detail views for content grouping.
// API: FusionCard view (elevated/inset/grouped/bordered styles). No schemas.
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import SwiftUI

struct FusionCard<Content: View>: View {
    enum CardStyle { case elevated, inset, grouped, bordered }

    let style: CardStyle
    let header: String?
    let headerIcon: String?
    let content: Content

    @Environment(\.studioTheme) var theme

    init(style: CardStyle = .elevated, header: String? = nil, headerIcon: String? = nil, @ViewBuilder content: () -> Content) {
        self.style = style; self.header = header; self.headerIcon = headerIcon; self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header {
                HStack(spacing: theme.spacingS) {
                    if let headerIcon {
                        Image(systemName: headerIcon)
                            .font(.system(size: theme.iconM, weight: .medium))
                            .foregroundStyle(theme.accent)
                    }
                    Text(header)
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.top, theme.spacingM)
                .padding(.bottom, theme.spacingS)
            }
            content
                .padding(.horizontal, theme.spacingL)
                .padding(.bottom, theme.spacingM)
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .overlay {
            if style == .bordered {
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(theme.inputBorder, lineWidth: 1)
            }
        }
        .studioShadow(shadowForStyle)
        .padding(.horizontal, theme.spacingS)
    }

    private var cardBg: Color {
        switch style {
        case .elevated: theme.surfaceElevated
        case .inset: theme.surfaceSecondary
        case .grouped: theme.surfaceSecondary
        case .bordered: theme.surfacePrimary
        }
    }

    private var shadowForStyle: ShadowConfig {
        switch style {
        case .elevated: theme.shadowMedium
        case .inset: theme.shadowSmall
        case .grouped: theme.shadowSmall
        case .bordered: theme.shadowSmall
        }
    }
}
