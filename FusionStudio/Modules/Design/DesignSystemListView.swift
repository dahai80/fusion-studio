// Callers: ModuleDetailView.designInfoPanel (designSystems tab).
// Affected API: activateSystem (refactored to use DesignBridge.runFusionDesign), refreshSystems (refactored), findFusionDesignCLI removed.
// Data schemas: DesignSystemInfo unchanged.
// User instruction: Phase 4 — refactor raw Process() to unified CLI bridge

import SwiftUI
import os.log

private let dsListLog = Logger(subsystem: "com.fusion.studio", category: "DesignSystemListView")

struct DesignSystemInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let cliId: String
    let tokenCount: Int

    var localName: String {
        switch id {
        case "apple-hig": return I18nManager.shared.t(.design_ds_name_appleHIG)
        case "minimal-dashboard": return I18nManager.shared.t(.design_ds_name_adminMinimal)
        case "robot-sim": return I18nManager.shared.t(.design_ds_name_robotSim)
        default: return name
        }
    }

    var localDescription: String {
        switch id {
        case "apple-hig": return I18nManager.shared.t(.design_ds_desc_appleHIG)
        case "minimal-dashboard": return I18nManager.shared.t(.design_ds_desc_adminMinimal)
        case "robot-sim": return I18nManager.shared.t(.design_ds_desc_robotSim)
        default: return I18nManager.shared.t(.design_ds_customDesc)
        }
    }

    static let builtIn: [DesignSystemInfo] = [
        DesignSystemInfo(id: "apple-hig", name: "Apple HIG", description: "Apple Human Interface Guidelines", icon: "apple.logo", cliId: "apple-hig", tokenCount: 28),
        DesignSystemInfo(id: "minimal-dashboard", name: "极简后台", description: "极简风格后台管理", icon: "rectangle.split.3x1", cliId: "minimal-dashboard", tokenCount: 22),
        DesignSystemInfo(id: "robot-sim", name: "机器人仿真", description: "工业仿真控制面板", icon: "gearshape.2", cliId: "robot-sim", tokenCount: 24)
    ]
}

struct DesignSystemListView: View {
    @Environment(\.studioTheme) var theme
    @EnvironmentObject var designBridge: DesignBridge
    @StateObject private var i18n = I18nManager.shared

    @State private var activeSystemId: String = "apple-hig"
    @State private var availableSystems: [DesignSystemInfo] = DesignSystemInfo.builtIn
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(theme.separator).frame(height: 1)
            systemList
            Rectangle().fill(theme.separator).frame(height: 1)
            activeSystemFooter
        }
    }

    private var header: some View {
        HStack {
            Text(i18n.t(.design_ds_title))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .textCase(.uppercase)
            Spacer()
            Button(action: refreshSystems) {
                HStack(spacing: 3) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 10, height: 10)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                    }
                    Text(i18n.t(.design_ds_refresh))
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var systemList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.spacingXS) {
                if let error = errorMessage {
                    errorRow(error)
                }
                ForEach(availableSystems) { sys in
                    systemRow(sys)
                }
            }
            .padding(theme.spacingS)
        }
    }

    private func systemRow(_ sys: DesignSystemInfo) -> some View {
        let isActive = sys.cliId == activeSystemId

        return Button(action: { activateSystem(sys) }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: sys.icon)
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(isActive ? theme.accentText : theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(isActive ? theme.accent : theme.groupBg)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(sys.localName)
                        .font(.system(size: theme.footnoteSize, weight: isActive ? .semibold : .medium))
                        .foregroundStyle(theme.text)
                    Text(sys.localDescription)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.greenDot)
                } else {
                    Text("\(sys.tokenCount) tokens")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.08) : theme.groupBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .stroke(isActive ? theme.accent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isActive)
    }

    private func errorRow(_ msg: String) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.amberDot)
            Text(msg)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
            Spacer()
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingS)
        .background(theme.warningBg)
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private var activeSystemFooter: some View {
        HStack(spacing: theme.spacingXS) {
            Circle().fill(theme.greenDot).frame(width: 6, height: 6)
            Text(String(format: i18n.t(.design_ds_activeFmt), activeSystemName))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Button(action: applyActiveSystem) {
                HStack(spacing: 3) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 9))
                    Text(i18n.t(.design_ds_applyToCanvas))
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var activeSystemName: String {
        availableSystems.first(where: { $0.cliId == activeSystemId })?.localName ?? activeSystemId
    }

    private func activateSystem(_ sys: DesignSystemInfo) {
        let result = designBridge.runFusionDesign(["activate", sys.cliId])
        if result.exitCode == 0 {
            activeSystemId = sys.cliId
            dsListLog.info("Activated design system: \(sys.cliId)")
        } else {
            errorMessage = String(format: i18n.t(.design_ds_activateFailFmt), String(result.error.prefix(200)))
            dsListLog.error("Activate failed: \(result.error)")
        }
    }

    private func refreshSystems() {
        isRefreshing = true
        errorMessage = nil

        let result = designBridge.runFusionDesign(["list-design-systems"])
        if result.exitCode == 0 {
            let ids = result.output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            var systems = [DesignSystemInfo]()
            for id in ids {
                if let builtin = DesignSystemInfo.builtIn.first(where: { $0.cliId == id }) {
                    systems.append(builtin)
                } else {
                    systems.append(DesignSystemInfo(id: id, name: id, description: "自定义设计系统", icon: "paintpalette", cliId: id, tokenCount: 0))
                }
            }
            availableSystems = systems
            dsListLog.info("Refreshed design systems: \(ids)")
        } else {
            errorMessage = String(format: i18n.t(.design_ds_listFailFmt), String(result.error.prefix(200)))
        }
        isRefreshing = false
    }

    private func applyActiveSystem() {
        designBridge.applyDesignTokensToCanvas(systemId: activeSystemId)
    }
}
