import SwiftUI
import os.log

private let codeLog = Logger(subsystem: "com.fusion.studio", category: "ScienceCodePreview")

struct ScienceCodePreview: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var scienceBridge: ScienceBridge

    var body: some View {
        ScrollView {
            let codeArtifacts = scienceBridge.messages.compactMap { msg -> [ScienceArtifact] in
                msg.artifacts?.filter { $0.isCode } ?? []
            }.flatMap { $0 }

            if codeArtifacts.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: theme.spacingS) {
                    ForEach(codeArtifacts) { artifact in
                        codeBlock(artifact)
                    }
                }
                .padding(theme.spacingM)
            }
        }
        .background(theme.surfaceElevated)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingS) {
            Spacer(minLength: 0)
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 32))
                .foregroundStyle(theme.textQuaternary)
            Text("No code generated")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Text("Use Analyze to generate code")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textQuaternary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func codeBlock(_ artifact: ScienceArtifact) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text(artifact.title)
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button {
                    copyToClipboard(artifact.content)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(artifact.content)
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.codeText)
                    .textSelection(.enabled)
            }
        }
        .padding(theme.spacingS)
        .background(theme.codeBg)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        codeLog.info("Code copied to clipboard")
    }
}
