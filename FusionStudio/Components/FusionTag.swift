// Callers: AgentStudioView, ProfilerView, LogPanelView
// Affected API: FusionTag view, TagColor enum
// Data schemas: TagColor enum (blue/green/orange/red/purple/gray)
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import SwiftUI
import os.log

private let fusionTagLog = os.Logger(subsystem: "com.fusion.studio", category: "FusionTag")

enum TagColor {
    case blue, green, orange, red, purple, gray
}

struct FusionTag: View {
    let title: String
    let icon: String?
    let color: TagColor
    let isRemovable: Bool
    let onRemove: (() -> Void)?

    @Environment(\.studioTheme) var theme

    init(_ title: String, icon: String? = nil, color: TagColor = .blue, isRemovable: Bool = false, onRemove: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isRemovable = isRemovable
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(colorConfig.text)
            }
            Text(title)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(colorConfig.text)
                .lineLimit(1)
            if isRemovable {
                Button {
                    fusionTagLog.info("FusionTag remove tapped: \(self.title, privacy: .public)")
                    onRemove?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: theme.captionSize - 1, weight: .bold))
                        .foregroundStyle(colorConfig.text.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(colorConfig.bg))
        .clipShape(Capsule())
    }

    private var colorConfig: (bg: Color, text: Color) {
        switch color {
        case .blue:   return (theme.infoBg, theme.infoText)
        case .green:  return (theme.successBg, theme.successText)
        case .orange: return (theme.warningBg, theme.warningText)
        case .red:    return (theme.errorBg, theme.errorText)
        case .purple: return (theme.accentSoft, theme.accent)
        case .gray:   return (theme.controlBg, theme.textSecondary)
        }
    }
}
