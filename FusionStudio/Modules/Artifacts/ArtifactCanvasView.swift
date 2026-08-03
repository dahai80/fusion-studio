import SwiftUI
import WebKit
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
    @State private var artifactType: String = "html"
    @State private var currentVersion: Int = 1
    @State private var hasUnsavedChanges = false
    @State private var showSnapshotSheet = false
    @State private var snapshotLabel = ""
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var previewKey = UUID()
    @State private var showTagFolder = false
    @State private var tokenCount: Int = 0
    @State private var contextBudget: Int = 32768
    @State private var sections: [[String: Any]] = []
    @State private var activeSection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Rectangle().fill(theme.separator).frame(height: 1)
            if hasUnsavedChanges {
                unsavedBanner
            }
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
                HStack(spacing: 0) {
                    if !sections.isEmpty { sectionSidebar }
                    previewPanel
                }
            case .code:
                codePanel
            }
            tokenBudgetBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadArtifact() }
        .sheet(isPresented: $showVersionHistory) {
            ArtifactVersionHistoryPanel(artifactId: artifactId)
                .frame(minWidth: 420, minHeight: 500)
        }
        .sheet(isPresented: $showShareDialog) {
            ArtifactShareDialog(
                artifactId: artifactId,
                artifactName: artifact?["name"] as? String ?? "Untitled"
            )
        }
        .sheet(isPresented: $showSnapshotSheet) {
            snapshotSheet
        }
        .alert("重命名", isPresented: $showRenameAlert) {
            TextField("新名称", text: $renameText)
            Button("确认") { performRename() }
            Button("取消", role: .cancel) { }
        }
        .alert("确认删除？", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) { performDelete() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("此操作将移入回收站，可恢复")
        }
    }

    private var unsavedBanner: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: theme.iconS))
                .foregroundStyle(.orange)
            Text("有未保存的更改")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Button("放弃") {
                codeContent = content
                hasUnsavedChanges = false
            }
            .font(.system(size: theme.captionSize))
            .buttonStyle(.plain)
            .foregroundStyle(theme.textTertiary)
            Button("保存") { saveContent() }
                .font(.system(size: theme.captionSize, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingXS)
        .background(theme.accentSoft.opacity(0.3))
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

            if currentVersion > 0 {
                Text("v\(currentVersion)")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, theme.spacingXS)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(theme.accent.opacity(0.15)))
            }

            Spacer()

            Button(action: { showRenameAlert = true; renameText = artifact?["name"] as? String ?? "" }) {
                Image(systemName: "pencil")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)

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

            Button(action: { showSnapshotSheet = true }) {
                Image(systemName: "bookmark")
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

            Button(action: { showTagFolder = true }) {
                Image(systemName: "tag")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showTagFolder) {
                ArtifactTagFolderPopover(artifactId: artifactId)
            }

            Button(action: { showShareDialog = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)

            Button(action: { duplicateArtifact() }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)

            Button(action: { showDeleteConfirm = true }) {
                Image(systemName: "trash")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accentDestructive)
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
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 30))
                        .foregroundStyle(theme.textTertiary)
                    Text("无预览内容")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                renderPreview
            }
        }
    }

    @ViewBuilder
    private var renderPreview: some View {
        let lowerType = artifactType.lowercased()
        switch lowerType {
        case "html", "react", "app":
            ArtifactSandboxView(htmlContent: content)
                .id(previewKey)
        case "svg":
            ArtifactSandboxView(htmlContent: svgWrapper(content))
                .id(previewKey)
        case "mermaid":
            ArtifactSandboxView(htmlContent: mermaidWrapper(content))
                .id(previewKey)
        case "markdown", "doc", "document":
            ArtifactSandboxView(htmlContent: markdownWrapper(content))
                .id(previewKey)
        default:
            ScrollView {
                Text(content)
                    .font(.system(size: theme.textSize, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .padding(theme.spacingL)
            }
        }
    }

    private var codePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Text(artifactType.uppercased())
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, theme.spacingS)
                    .padding(.vertical, theme.spacingXS)
                    .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(theme.accent.opacity(0.1)))
                Text("\(codeContent.count) 字符")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingXS)
            .background(theme.surfaceElevated)

            ScrollView {
                TextEditor(text: Binding(
                    get: { codeContent },
                    set: { newValue in
                        codeContent = newValue
                        hasUnsavedChanges = newValue != content
                    }
                ))
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .foregroundStyle(theme.text)
                .scrollDisabled(true)
                .padding(theme.spacingM)
            }

            HStack(spacing: theme.spacingM) {
                if hasUnsavedChanges {
                    Button("放弃更改") {
                        codeContent = content
                        hasUnsavedChanges = false
                    }
                    .font(.system(size: theme.footnoteSize))
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                Button("保存") { saveContent() }
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .buttonStyle(.plain)
                    .disabled(isSaving || !hasUnsavedChanges)
                    .foregroundStyle(hasUnsavedChanges ? theme.accent : theme.textTertiary)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
            .background(theme.surfaceElevated)
        }
    }

    private var snapshotSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("创建版本快照")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            TextField("快照标签（可选）", text: $snapshotLabel)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: theme.textSize))

            HStack {
                Button("取消") { showSnapshotSheet = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("创建") { createSnapshot() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.accent))
            }
        }
        .padding(theme.spacingL)
        .frame(width: 360)
    }

    private func svgWrapper(_ svg: String) -> String {
        "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><style>body{margin:0;display:flex;justify-content:center;align-items:center;min-height:100vh;background:transparent;}svg{max-width:100%;max-height:100vh;}</style></head><body>\(svg)</body></html>"
    }

    private func mermaidWrapper(_ code: String) -> String {
        let escaped = code.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`").replacingOccurrences(of: "$", with: "\\$")
        return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><script src=\"https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js\"></script><style>body{margin:20px;background:transparent;font-family:sans-serif;}.mermaid{display:flex;justify-content:center;}</style><script>mermaid.initialize({startOnLoad:true,theme:'dark'});</script></head><body><pre class=\"mermaid\">\(escaped)</pre></body></html>"
    }

    private func markdownWrapper(_ md: String) -> String {
        let escaped = md.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "`", with: "\\`").replacingOccurrences(of: "$", with: "\\$").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\"", with: "\\\"")
        return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><script src=\"https://cdn.jsdelivr.net/npm/marked/marked.min.js\"></script><style>body{margin:20px;background:transparent;color:#e0e0e0;font-family:-apple-system,sans-serif;line-height:1.6;}h1,h2,h3{color:#fff;}a{color:#007AFF;}code{background:rgba(255,255,255,0.1);padding:2px 6px;border-radius:3px;font-size:0.9em;}pre{background:rgba(255,255,255,0.05);padding:12px;border-radius:8px;overflow-x:auto;}pre code{background:transparent;padding:0;}blockquote{border-left:3px solid #007AFF;padding-left:12px;color:#aaa;}table{border-collapse:collapse;width:100%;}th,td{border:1px solid #333;padding:8px;text-align:left;}th{background:rgba(255,255,255,0.05);}</style></head><body><div id=\"content\"></div><script>document.getElementById('content').innerHTML=marked.parse(\"\(escaped)\");</script></body></html>"
    }

    private func loadArtifact() {
        isLoading = true
        Task {
            do {
                let a = try await ipc.artifactGet(artifactId: artifactId)
                let c = try await ipc.artifactGetContent(artifactId: artifactId)
                let v = try await ipc.artifactVersionList(artifactId: artifactId)
                let loaded = try await ipc.artifactLoad(artifactId: artifactId)
                let budget = try await ipc.contextBudget()
                await MainActor.run {
                    artifact = a
                    content = c["content"] as? String ?? ""
                    codeContent = content
                    starred = a["starred"] as? Bool ?? false
                    pinned = a["pinned"] as? Bool ?? false
                    artifactType = a["type"] as? String ?? "html"
                    currentVersion = a["current_version"] as? Int ?? 1
                    versions = v["versions"] as? [[String: Any]] ?? []
                    tokenCount = loaded["total_tokens"] as? Int ?? 0
                    contextBudget = budget["total_budget"] as? Int ?? 32768
                    sections = loaded["sections"] as? [[String: Any]] ?? []
                    previewKey = UUID()
                    isLoading = false
                }
                canvasLog.info("canvas loaded: \(artifactId) type=\(self.artifactType) v\(self.currentVersion) tokens=\(self.tokenCount)")
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
                    hasUnsavedChanges = false
                    previewKey = UUID()
                    currentVersion += 1
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

    private func createSnapshot() {
        Task {
            do {
                _ = try await ipc.artifactCreateSnapshot(artifactId: artifactId, label: snapshotLabel.isEmpty ? nil : snapshotLabel)
                canvasLog.info("snapshot created: \(artifactId)")
                await MainActor.run {
                    showSnapshotSheet = false
                    snapshotLabel = ""
                }
            } catch {
                canvasLog.error("snapshot failed: \(error.localizedDescription)")
            }
        }
    }

    private func duplicateArtifact() {
        Task {
            do {
                let name = artifact?["name"] as? String ?? "Untitled"
                _ = try await ipc.artifactDuplicate(artifactId: artifactId, newName: name + " (副本)")
                canvasLog.info("artifact duplicated: \(artifactId)")
            } catch {
                canvasLog.error("duplicate failed: \(error.localizedDescription)")
            }
        }
    }

    private func performRename() {
        guard !renameText.isEmpty else { return }
        Task {
            do {
                _ = try await ipc.artifactRename(artifactId: artifactId, newName: renameText)
                canvasLog.info("artifact renamed: \(artifactId)")
                await MainActor.run { artifact?["name"] = renameText }
            } catch {
                canvasLog.error("rename failed: \(error.localizedDescription)")
            }
        }
    }

    private func performDelete() {
        Task {
            do {
                _ = try await ipc.artifactDelete(artifactId: artifactId)
                canvasLog.info("artifact deleted: \(artifactId)")
                await MainActor.run { dismiss() }
            } catch {
                canvasLog.error("delete failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - ST-3: Token Budget Bar

    private var tokenBudgetBar: some View {
        HStack(spacing: 8) {
            Text("Tokens")
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
            Text("\(tokenCount)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.text)
            let ratio = contextBudget > 0 ? Double(tokenCount) / Double(contextBudget) : 0
            ProgressView(value: ratio)
                .progressViewStyle(.linear)
                .tint(ratio > 0.9 ? theme.accentDestructive : ratio > 0.7 ? .yellow : theme.accent)
                .frame(maxWidth: 200)
            Text(String(format: "%.0f%%", ratio * 100))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(ratio > 0.9 ? theme.accentDestructive : theme.textTertiary)
            Spacer()
            if !sections.isEmpty {
                Text("\(sections.count) 章节")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingXS)
        .background(theme.surfaceSecondary)
    }

    // MARK: - ST-5: Section Sidebar

    private var sectionSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("章节目录")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            Rectangle().fill(theme.separator).frame(height: 1)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections.indices, id: \.self) { idx in
                        let sec = sections[idx]
                        let title = sec["title"] as? String ?? "Section \(idx + 1)"
                        let secId = sec["id"] as? String ?? "\(idx)"
                        Button(action: { loadSection(secId) }) {
                            HStack(spacing: 6) {
                                if activeSection == secId {
                                    RoundedRectangle(cornerRadius: 1.5).fill(theme.accent).frame(width: 2, height: 14)
                                } else {
                                    Color.clear.frame(width: 2, height: 14)
                                }
                                Text(title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(activeSection == secId ? theme.accent : theme.text)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 180)
        .background(theme.surfaceSecondary)
    }

    private func loadSection(_ sectionId: String) {
        activeSection = sectionId
        Task {
            do {
                let r = try await ipc.artifactLoad(artifactId: artifactId)
                if let sectionsData = r["sections"] as? [[String: Any]] {
                    let target = sectionsData.first { ($0["id"] as? String) == sectionId }
                    if let sec = target?["content"] as? String {
                        await MainActor.run { self.content = sec }
                    }
                }
            } catch {
                canvasLog.error("loadSection failed: \(error.localizedDescription)")
            }
        }
    }
}

struct ArtifactSandboxView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController = WKUserContentController()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(true, forKey: "drawsTransparentBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                if url.scheme == "data" || url.scheme == "about" {
                    decisionHandler(.allow)
                } else {
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
