// Callers: CodeView (embedded in sidebar as .preview tab), DesignCodeLink (push updates).
// Affected API: CodeDesignPreviewPanel (new View), SidebarTab (add .preview case), Notification.Name.switchToDesignModule.
// Data schemas: reads DesignBridge.currentArtifactCode/Title, DesignCodeLink.shared.isActive/lastSyncDirection.
// User instruction: "启动 Phase 4" — Task #47 Code 模块内嵌设计预览

import SwiftUI
import os.log

private let codeDesignLog = Logger(subsystem: "com.fusion.studio", category: "CodeDesignPreviewPanel")

struct CodeDesignPreviewPanel: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var designBridge: DesignBridge
    @State private var deviceMode: PreviewDeviceMode = .mobile

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader
            Rectangle().fill(theme.separator).frame(height: 1)
            previewContent
            Rectangle().fill(theme.separator).frame(height: 1)
            syncBar
        }
        .background(theme.surfaceSecondary)
    }

    private var panelHeader: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "paintbrush")
                .font(.system(size: 11))
                .foregroundStyle(theme.accent)
            Text("Design Preview")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()

            ForEach(PreviewDeviceMode.allCases, id: \.self) { mode in
                Button(action: { deviceMode = mode }) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(deviceMode == mode ? theme.accent : theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(mode.label)
            }

            Button(action: { openInDesignModule() }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("在 Design 模块中打开")
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceElevated)
    }

    private var previewContent: some View {
        Group {
            if designBridge.currentArtifactCode.isEmpty {
                emptyState
            } else {
                DesignPreviewView(
                    htmlContent: $designBridge.currentArtifactCode,
                    deviceMode: deviceMode
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "paintbrush.pointed")
                .font(.system(size: 28))
                .foregroundStyle(theme.textTertiary)
            Text("没有设计内容")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
            Text("在 Design 模块中创建设计后\n可在此预览")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingL)
    }

    private var syncBar: some View {
        HStack(spacing: theme.spacingS) {
            Circle()
                .fill(DesignCodeLink.shared.isActive ? Color.green : Color.orange)
                .frame(width: 6, height: 6)

            if DesignCodeLink.shared.isActive {
                Text("双向同步已开启")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            } else {
                Text("同步未连接")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            if let direction = DesignCodeLink.shared.lastSyncDirection {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.right.arrow.left")
                        .font(.system(size: 8))
                    Text(direction.rawValue)
                        .font(.system(size: 9))
                }
                .foregroundStyle(theme.textTertiary)
            }

            Button(action: {
                let projectId = FusionProjectManager.shared.activeProject?.id
                DesignCodeLink.shared.pushDesignToFile(
                    designBridge: designBridge,
                    projectId: projectId
                )
                codeDesignLog.info("Manual push design→file from CodeDesignPreviewPanel")
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("导出到文件")
            .disabled(designBridge.currentArtifactCode.isEmpty)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.surfaceElevated)
    }

    private func openInDesignModule() {
        NotificationCenter.default.post(name: .switchToDesignModule, object: nil)
        codeDesignLog.info("Requested switch to Design module")
    }
}

extension Notification.Name {
    static let switchToDesignModule = Notification.Name("switchToDesignModule")
}
