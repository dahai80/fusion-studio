import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ProjectAgentPreview: View {
    let project: FusionProject
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Image(systemName: "robot")
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(theme.accent)
                Text(project.agentName ?? i18n.t(.proj_previewUnbound))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            if let binding = project.agentBinding {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    if let prompt = binding.agentPrompt {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(i18n.t(.proj_previewRole))
                                .font(.system(size: theme.captionSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            Text(String(prompt.prefix(200)))
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.text)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.proj_previewActiveConfig))
                            .font(.system(size: theme.captionSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Text(String(format: i18n.t(.proj_previewPromptStrategyFmt), binding.mergeMode == .AGENT_FIRST ? i18n.t(.proj_previewPromptAgentFirst) : i18n.t(.proj_previewPromptProjectOnly)))
                        Text(String(format: i18n.t(.proj_previewRagModeFmt), project.ragMode.rawValue, project.ragTopK, String(project.ragThreshold)))
                        Text(i18n.t(.proj_previewAccessKb))
                    }
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                }
            } else {
                Text(i18n.t(.proj_previewUnboundHint))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 0)

            HStack {
                Button(i18n.t(.proj_previewGotoAgentStudio)) { }
                    .font(.system(size: theme.footnoteSize))
                Spacer()
                Button(i18n.t(.close)) { dismiss() }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400, height: 320)
    }
}

// MARK: - GUI-13: CoWork Import Dialog

