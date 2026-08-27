import SwiftUI

// MARK: - Artifact Preview View

struct ArtifactPreviewView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let artifact: SpaceArtifact
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: kindIcon(artifact.kind))
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(artifact.name)
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(kindLabel(artifact.kind))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)

            Divider()

            if artifact.content.isEmpty && artifact.filePath.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 30))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_preview_empty))
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if artifact.kind == "code" || artifact.kind == "visualization" {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MarkdownContentView(content: "```\(languageTag)\n\(artifact.content)\n```")
                    }
                    .padding(theme.spacingM)
                }
            } else {
                ScrollView {
                    MarkdownContentView(content: artifact.content)
                        .padding(theme.spacingM)
                }
            }

            if !artifact.filePath.isEmpty {
                Divider()
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    Text(artifact.filePath)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(artifact.filePath, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.surfaceSecondary.opacity(0.3))
            }
        }
        .frame(minWidth: 280, maxWidth: 400)
        .background(theme.surfacePrimary)
    }

    private var languageTag: String {
        switch artifact.kind {
        case "code": return ""
        default: return ""
        }
    }

    private func kindIcon(_ kind: String) -> String {
        switch kind {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "doc": return "doc.text"
        case "visualization": return "chart.bar"
        case "data": return "tablecells"
        default: return "shippingbox"
        }
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "code": return i18n.t(.cw_art_kindCode)
        case "doc": return i18n.t(.cw_art_kindDoc)
        case "visualization": return i18n.t(.cw_art_kindViz)
        case "data": return i18n.t(.cw_art_kindData)
        default: return kind
        }
    }
}

