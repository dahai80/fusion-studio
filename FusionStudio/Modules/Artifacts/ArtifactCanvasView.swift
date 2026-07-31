import SwiftUI
import os.log

private let canvasLog = Logger(subsystem: "com.fusion.studio", category: "Artifacts.Canvas")

enum ArtifactCanvasTab: Int, CaseIterable {
    case preview = 0
    case code = 1

    var item: FusionTabItem {
        switch self {
        case .preview: return FusionTabItem(title: "Preview", icon: "safari")
        case .code:    return FusionTabItem(title: "Code", icon: "chevron.left.forwardslash.chevron.right")
        }
    }
}

struct ArtifactCanvasView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let artifactId: String
    @State private var artifact: [String: Any]?
    @State private var content: String = ""
    @State private var codeContent: String = ""
    @State private var isLoading = false
    @State private var activeTab: ArtifactCanvasTab = .preview
    @State private var starred = false
    @State private var pinned = false
    @State private var versions: [[String: Any]] = []
    @State private var showVersionHistory = false
    @State private var showShareDialog = false
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Rectangle().fill(theme.separator).frame(height: 1)
            FusionTabBar(
                selected: Binding(
                    get: { activeTab.rawValue },
                    set: { if let t = ArtifactCanvasTab(rawValue: $0) { activeTab = t } }
                ),
                tabs: ArtifactCanvasTab.allCases.map { $0.item }
            )
            .padding(.horizontal, theme.spacingM)
            switch activeTab {
            case .preview:
                previewPanel
            case .code:
                codePanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadArtifact() }
    }

    private var toolbar: some View {
        HStack(spacing: theme.spacingS) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)

            if let a = artifact {
                Text(a["name"] as? String ?? "Untitled")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
            }

            Spacer()

            Button(action: { toggleStar() }) {
                Image(systemName: starred ? "star.fill" : "star")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(starred ? .yellow : theme.textTertiary)
            }
            .buttonStyle(.plain)

            Button(action: { togglePin() }) {
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(pinned ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)

            Button(action: { showShareDialog = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)

            Button(action: { showVersionHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceElevated)
    }

    private var previewPanel: some View {
        Group {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if content.isEmpty {
                Text("无预览内容")
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(content)
                            .font(.system(size: theme.textSize, design: .monospaced))
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                            .padding(theme.spacingL)
                    }
                }
            }
        }
    }

    private var codePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                TextEditor(text: $codeContent)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .scrollDisabled(true)
                    .padding(theme.spacingM)
            }
            HStack {
                Spacer()
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                Button("保存") { saveContent() }
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .disabled(isSaving || codeContent.isEmpty)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
            .background(theme.surfaceElevated)
        }
    }

    private func loadArtifact() {
        isLoading = true
        Task {
            do {
                let a = try await ipc.artifactGet(artifactId: artifactId)
                let c = try await ipc.artifactGetContent(artifactId: artifactId)
                let v = try await ipc.artifactVersionList(artifactId: artifactId)
                await MainActor.run {
                    artifact = a
                    content = c["content"] as? String ?? ""
                    codeContent = content
                    starred = a["starred"] as? Bool ?? false
                    pinned = a["pinned"] as? Bool ?? false
                    versions = v["versions"] as? [[String: Any]] ?? []
                    isLoading = false
                }
            } catch {
                canvasLog.error("load artifact failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func saveContent() {
        isSaving = true
        Task {
            do {
                _ = try await ipc.artifactUpdate(artifactId: artifactId, content: codeContent)
                canvasLog.info("artifact saved: \(artifactId)")
                await MainActor.run {
                    content = codeContent
                    isSaving = false
                }
            } catch {
                canvasLog.error("save failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func toggleStar() {
        Task {
            _ = try await ipc.artifactStar(artifactId: artifactId, starred: !starred)
            await MainActor.run { starred.toggle() }
        }
    }

    private func togglePin() {
        Task {
            _ = try await ipc.artifactPin(artifactId: artifactId, pinned: !pinned)
            await MainActor.run { pinned.toggle() }
        }
    }
}
