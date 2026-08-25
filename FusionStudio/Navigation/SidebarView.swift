// Callers: Legacy sidebar — enums moved to AppState.swift, SidebarView replaced by IconRailView + FusionSidebarView.
// Affected API: SheetHeader, SidebarRow, HealthStatusBadge (kept as reusable components).
// Data schemas: ProductSheet/Module now in AppState.swift.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

struct SheetHeader: View {
    let sheet: ProductSheet
    let isCollapsed: Bool
    let toggleCollapse: () -> Void
    @Environment(\.studioTheme) private var theme

    var body: some View {
        Button(action: toggleCollapse) {
            HStack(spacing: 6) {
                Image(systemName: sheet.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(sheet.rawValue)
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .textCase(.uppercase)
                    .kerning(0.6)
                Spacer()
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.textQuaternary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SidebarRow: View {
    let module: Module
    @Environment(\.studioTheme) private var theme

    var body: some View {
        Label(module.localizedName, systemImage: module.icon)
            .font(.system(size: theme.textSize))
            .foregroundStyle(theme.text)
            .padding(.vertical, 3)
    }
}

struct HealthStatusBadge: View {
    let status: AppState.HealthStatus
    @EnvironmentObject private var uiPanelState: UIPanelState
    @Environment(\.studioTheme) private var theme

    var body: some View {
        Button(action: { uiPanelState.showEnvironmentHealth = true }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(text)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help("点击查看所有子系统健康状态")
    }

    private var color: Color {
        switch status {
        case .checking:    return theme.textTertiary
        case .healthy:     return theme.greenDot
        case .issuesFound: return theme.redDot
        case .repairing:   return theme.amberDot
        }
    }

    private var text: String {
        switch status {
        case .checking:    return "检测中..."
        case .healthy:     return "环境正常"
        case .issuesFound: return "环境异常"
        case .repairing:   return "修复中..."
        }
    }
}
