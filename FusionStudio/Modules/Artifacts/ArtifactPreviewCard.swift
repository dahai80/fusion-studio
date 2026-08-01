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
    var summary: String = ""
    var starred: Bool = false
    var pinned: Bool = false
    var folderName: String?
    var tags: [String] = []

    @State private var content: String?
    @State private var isStarred: Bool = false
    @State private var isPinned: Bool = false
    @State private var showCanvas = false
    @State private var showVersionHistory = false
    @State private var showShare = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
                .padding(.horizontal, theme.spacingM)
                .padding(.top, theme.spacingM)
                .padding(.bottom, theme.spacingS)

            previewArea
                .padding(.horizontal, theme.spacingM)
                .padding(.bottom, theme.spacingS)

            if !tags.isEmpty || folderName != nil {
                tagLine
                    .padding(.horizontal, theme.spacingM)
                    .padding(.bottom, theme.spacingXS)
            }

            actionBar
                .padding(.horizontal, theme.spacingM)
                .padding(.bottom, theme.spacingM)
        }
        .background(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(theme.surfaceSecondary))
        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).stroke(theme.separator, lineWidth: 1))
        .onAppear {
            isStarred = starred
            isPinned = pinned
            loadContent()
        }
        .onTapGesture { showCanvas = true }
        .sheet(isPresented: $showCanvas) {
            ArtifactCanvasView(artifactId: artifactId)
                .frame(minWidth: 800, minHeight: 600)
        }
        .sheet(isPresented: $showVersionHistory) {
            ArtifactVersionHistoryPanel(artifactId: artifactId)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showShare) {
            ArtifactShareDialog(artifactId: artifactId, artifactName: name)
                .frame(minWidth: 400, minHeight: 350)
        }
    }

    private var cardHeader: some View {
        HStack(spacing: theme.spacingS) {
            renderTypeIcon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Text(name)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.accent)
                    }
                }
                HStack(spacing: theme.spacingXS) {
                    Text(typeLabel)
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(renderColor)
                    Text("·")
                        .foregroundStyle(theme.textTertiary)
                    if version > 0 {
                        Text("v\(version)")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                    if !summary.isEmpty {
                        Text("·")
                            .foregroundStyle(theme.textTertiary)
                        Text(summary)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Button(action: { toggleStar() }) {
                Image(systemName: isStarred ? "star.fill" : "star")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(isStarred ? .yellow : theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    private var renderTypeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(renderColor.opacity(0.12))
                .frame(width: 32, height: 32)
            Image(systemName: iconForType(type))
                .font(.system(size: theme.iconM, weight: .medium))
                .foregroundStyle(renderColor)
        }
    }

    private var typeLabel: String {
        switch type.lowercased() {
        case "html", "react": return type.uppercased()
        default: return type.capitalized
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        let renderType = detectRenderType()
        switch renderType {
        case .html:
            miniSandboxPreview
        case .svg:
            miniSvgPreview
        case .mermaid, .markdown:
            miniTextPreview
        default:
            miniTextPreview
        }
    }

    private enum RenderKind {
        case html, svg, mermaid, markdown, code, unknown
    }

    private func detectRenderType() -> RenderKind {
        let t = type.lowercased()
        if t == "html" || t == "react" || t == "app" { return .html }
        if t == "svg" { return .svg }
        if t == "mermaid" { return .mermaid }
        if t == "markdown" || t == "doc" { return .markdown }
        if t == "code" { return .code }
        return .unknown
    }

    private var miniSandboxPreview: some View {
        Group {
            if let c = content {
                ArtifactSandboxView(htmlContent: c)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
            } else {
                loadingPlaceholder
            }
        }
    }

    private var miniSvgPreview: some View {
        Group {
            if let c = content {
                ArtifactSandboxView(htmlContent: svgWrapper(c))
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
            } else {
                loadingPlaceholder
            }
        }
    }

    private var miniTextPreview: some View {
        Group {
            if let c = content {
                Text(String(c.prefix(300)))
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.inputBg))
            } else {
                loadingPlaceholder
            }
        }
    }

    private var tagLine: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingXS) {
                if let fn = folderName {
                    HStack(spacing: 2) {
                        Image(systemName: "folder")
                            .font(.system(size: 8))
                        Text(fn)
                            .font(.system(size: theme.captionSize))
                    }
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingXS)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(theme.surfaceElevated))
                }
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.accentSecondary)
                        .padding(.horizontal, theme.spacingXS)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(theme.accentSoft.opacity(0.15)))
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: theme.spacingS) {
            Button(action: { showCanvas = true }) {
                Label("打开", systemImage: "arrow.up.right.and.arrow.down")
            }
            Button(action: { copyContent() }) {
                Label("复制", systemImage: "doc.on.doc")
            }
            Spacer()
            Button(action: { showVersionHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("版本历史")

            Button(action: { showShare = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("分享")

            Menu {
                Button(isPinned ? "取消置顶" : "置顶") { togglePin() }
                Button("复制为副本") { duplicateArtifact() }
                Divider()
                Button("移至项目KB") { moveToProjectKb() }
                Divider()
                Button("删除", role: .destructive) { deleteArtifact() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
        }
        .font(.system(size: theme.captionSize))
    }

    private var loadingPlaceholder: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
            .fill(theme.inputBg)
            .frame(height: 60)
            .overlay(ProgressView())
    }

    private var renderColor: Color {
        switch type.lowercased() {
        case "code": return .purple
        case "doc", "document", "markdown": return .indigo
        case "visualization", "chart": return .green
        case "data": return .orange
        case "html", "react", "app": return .blue
        case "svg": return .pink
        default: return theme.accent
        }
    }

    private func iconForType(_ t: String) -> String {
        switch t.lowercased() {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "doc", "document", "markdown": return "doc.text"
        case "visualization", "chart": return "chart.bar"
        case "data": return "tablecells"
        case "html", "react", "app": return "globe"
        case "svg": return "paintbrush"
        case "mermaid": return "flowchart"
        default: return "cube.box"
        }
    }

    private func svgWrapper(_ svg: String) -> String {
        "<!DOCTYPE html><html><head><style>body{margin:0;display:flex;align-items:center;justify-content:center;min-height:100vh;background:transparent}</style></head><body>\(svg)</body></html>"
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
                _ = try await ipc.artifactStar(artifactId: artifactId, starred: !isStarred)
                await MainActor.run { isStarred.toggle() }
            } catch {
                artCardLog.error("star failed: \(error.localizedDescription)")
            }
        }
    }

    private func togglePin() {
        Task {
            do {
                _ = try await ipc.artifactPin(artifactId: artifactId)
                await MainActor.run { isPinned.toggle() }
                artCardLog.info("pin toggled: \(artifactId)")
            } catch {
                artCardLog.error("pin failed: \(error.localizedDescription)")
            }
        }
    }

    private func copyContent() {
        if let c = content {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(c, forType: .string)
        }
    }

    private func duplicateArtifact() {
        Task {
            do {
                _ = try await ipc.artifactDuplicate(artifactId: artifactId, newName: name + " (副本)")
                artCardLog.info("duplicated: \(artifactId)")
            } catch {
                artCardLog.error("duplicate failed: \(error.localizedDescription)")
            }
        }
    }

    private func moveToProjectKb() {
        guard let projectId = FusionProjectManager.shared.activeProject?.id else {
            artCardLog.warning("no active project for move_to_project_kb")
            return
        }
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.move_to_project_kb", params: [
                    "artifact_id": artifactId,
                    "project_id": projectId
                ])
                artCardLog.info("moved to project kb: \(artifactId)")
            } catch {
                artCardLog.error("move_to_project_kb failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteArtifact() {
        Task {
            do {
                _ = try await ipc.artifactDelete(artifactId: artifactId)
                artCardLog.info("deleted: \(artifactId)")
            } catch {
                artCardLog.error("delete failed: \(error.localizedDescription)")
            }
        }
    }
}
