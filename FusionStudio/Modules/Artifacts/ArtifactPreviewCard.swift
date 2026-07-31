import SwiftUI
import os.log

private let artCardLog = Logger(subsystem: "com.fusion.studio", category: "Artifacts.PreviewCard")

struct ArtifactPreviewCard: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let artifactId: String
    let name: String
    let type: String
    let version: Int

    @State private var content: String?
    @State private var starred = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            cardHeader
            if let c = content {
                contentPreview(c)
            } else {
                loadingPlaceholder
            }
            actionBar
        }
        .padding(theme.spacingM)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(theme.surfaceSecondary))
        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).stroke(theme.separator, lineWidth: 1))
        .onAppear { loadContent() }
    }

    private var cardHeader: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: iconForType(type))
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                HStack(spacing: theme.spacingXS) {
                    Text(type.uppercased())
                    Text("·")
                    Text("v\(version)")
                }
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button(action: { toggleStar() }) {
                Image(systemName: starred ? "star.fill" : "star")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(starred ? .yellow : theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private func contentPreview(_ c: String) -> some View {
        Text(String(c.prefix(200)))
            .font(.system(size: theme.footnoteSize, design: .monospaced))
            .foregroundStyle(theme.textSecondary)
            .lineLimit(5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacingS)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.inputBg))
    }

    private var loadingPlaceholder: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
            .fill(theme.inputBg)
            .frame(height: 60)
            .overlay(ProgressView())
    }

    private var actionBar: some View {
        HStack(spacing: theme.spacingS) {
            Button("打开") { openArtifact() }
            Button("复制") { copyContent() }
            Button("下载") { downloadArtifact() }
            Spacer()
            Menu {
                Button("星标") { toggleStar() }
                Button("置顶") { pinArtifact() }
                Divider()
                Button("版本历史") { }
                Button("分享") { }
                Divider()
                Button("删除", role: .destructive) { deleteArtifact() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: theme.iconS))
            }
            .menuStyle(.borderlessButton)
        }
        .font(.system(size: theme.captionSize))
    }

    private func iconForType(_ t: String) -> String {
        switch t {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "doc": return "doc.text"
        case "visualization": return "chart.bar"
        case "data": return "tablecells"
        default: return "cube.box"
        }
    }

    private func loadContent() {
        Task {
            do {
                let r = try await ipc.artifactGetContent(artifactId: artifactId)
                let c = r["content"] as? String
                await MainActor.run { content = c }
            } catch {
                artCardLog.error("preview load failed: \(error.localizedDescription)")
            }
        }
    }

    private func toggleStar() {
        Task {
            do {
                _ = try await ipc.artifactStar(artifactId: artifactId, starred: !starred)
                await MainActor.run { starred.toggle() }
            } catch {
                artCardLog.error("star failed: \(error.localizedDescription)")
            }
        }
    }

    private func openArtifact() { }
    private func pinArtifact() {
        Task { _ = try await ipc.artifactPin(artifactId: artifactId) }
    }
    private func copyContent() {
        if let c = content {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(c, forType: .string)
        }
    }
    private func downloadArtifact() {
        Task { _ = try await ipc.artifactExport(artifactId: artifactId) }
    }
    private func deleteArtifact() {
        Task { _ = try await ipc.artifactDelete(artifactId: artifactId) }
    }
}
