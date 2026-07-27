import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

struct ArtifactModel: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let currentVersion: Int
    let tokenCount: Int
    let summary: String?
    let updatedAt: Date
}

struct ArtifactVersionModel: Identifiable, Hashable {
    let id: Int
    let versionNum: Int
    let tokenCount: Int
    let changeLog: String?
    let createdAt: Date
}

// MARK: - ArtifactsPanel

struct ArtifactsPanel: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var artifacts: [ArtifactModel] = []
    @State private var selectedArtifact: ArtifactModel?
    @State private var selectedContent: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var engineOnline = false
    @State private var sessionId = "default"
    @State private var showCreateSheet = false
    @State private var showEditSheet = false
    @State private var showVersionSheet = false
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var showInjectSheet = false
    @State private var showSessionPicker = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)

            if isLoading {
                Spacer()
                ProgressView("Loading artifacts...")
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                errorView(error)
                Spacer()
            } else if artifacts.isEmpty {
                emptyState
            } else {
                artifactList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkEngineAndLoad()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateArtifactSheet(sessionId: sessionId) { _ in loadArtifacts() }
        }
        .sheet(isPresented: $showEditSheet) {
            if let art = selectedArtifact {
                EditContentSheet(artifact: art) { _ in
                    loadContent(for: art)
                    loadArtifacts()
                }
            }
        }
        .sheet(isPresented: $showVersionSheet) {
            if let art = selectedArtifact {
                VersionHistorySheet(artifact: art)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let art = selectedArtifact {
                ExportArtifactSheet(artifact: art)
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportArtifactSheet { _ in loadArtifacts() }
        }
        .sheet(isPresented: $showInjectSheet) {
            InjectPreviewSheet()
        }
        .popover(isPresented: $showSessionPicker) {
            SessionPickerView(currentSession: $sessionId)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Text("Artifacts")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if engineOnline {
                Circle().fill(Color.green).frame(width: 8, height: 8)
            } else {
                Circle().fill(Color.red).frame(width: 8, height: 8)
            }

            Text(sessionId)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(theme.accent.opacity(0.15))
                )
                .onTapGesture { showSessionPicker = true }

            Spacer()

            if isSearching {
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.footnoteSize))
                    .frame(width: 140)
                    .onSubmit { isSearching = false }
            } else {
                Button(action: { isSearching = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Search Artifacts")
            }

            Button(action: { showInjectSheet = true }) {
                Image(systemName: "text.append")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Inject / Safety Preview")

            Button(action: { showImportSheet = true }) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Import Artifact")

            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Create Artifact")

            Button(action: { loadArtifacts() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    // MARK: - Artifact List

    private var filteredArtifacts: [ArtifactModel] {
        if searchText.isEmpty { return artifacts }
        return artifacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.type.localizedCaseInsensitiveContains(searchText) ||
            ($0.summary?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var artifactList: some View {
        HSplitView {
            List(filteredArtifacts, selection: $selectedArtifact) { artifact in
                artifactRow(artifact)
                    .tag(artifact)
            }
            .frame(minWidth: 240)

            if let selected = selectedArtifact {
                artifactDetail(selected)
            } else {
                VStack {
                    Spacer()
                    Text("Select an artifact")
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .frame(minWidth: 300)
            }
        }
    }

    private func artifactRow(_ artifact: ArtifactModel) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: iconForType(artifact.type))
                .font(.system(size: theme.iconS))
                .foregroundStyle(colorForType(artifact.type))

            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.name)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)

                HStack(spacing: theme.spacingXS) {
                    Text(artifact.type.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(colorForType(artifact.type).opacity(0.15))
                        )

                    Text("v\(artifact.currentVersion)")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)

                    Text("\(artifact.tokenCount) tok")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail

    private func artifactDetail(_ artifact: ArtifactModel) -> some View {
        VStack(spacing: 0) {
            detailHeader(artifact)
            Rectangle().fill(theme.separator).frame(height: 1)

            if let content = selectedContent {
                contentPreview(content, type: artifact.type)
            } else {
                Spacer()
                ProgressView("Loading content...")
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
        }
        .frame(minWidth: 300)
        .onAppear { loadContent(for: artifact) }
        .onChange(of: artifact.id) { _ in loadContent(for: artifact) }
    }

    @ViewBuilder
    private func contentPreview(_ content: String, type: String) -> some View {
        switch type.lowercased() {
        case "html", "react":
            HTMLPreviewView(htmlContent: content)
        default:
            ScrollView {
                Text(content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .padding(theme.spacingL)
            }
        }
    }

    private func detailHeader(_ artifact: ArtifactModel) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: iconForType(artifact.type))
                .foregroundStyle(colorForType(artifact.type))

            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.name)
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                if let summary = artifact.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("v\(artifact.currentVersion)")
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Button(action: { showExportSheet = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Export")

            Button(action: { showEditSheet = true }) {
                Image(systemName: "pencil")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Edit Content")

            Button(action: { showVersionSheet = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Version History")

            Button(action: { deleteArtifact(artifact) }) {
                Image(systemName: "trash")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    // MARK: - Empty / Error

    private var emptyState: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()

            Image(systemName: "cube.box")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)

            Text("What will you build with artifacts?")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Text("If you can dream it, you can build it. Take apps, games, templates, and tools from thought to reality.")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if !engineOnline {
                Text("Artifacts engine offline — start with: fusion-artifacts-engine start")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: theme.spacingM) {
                Button(action: { showCreateSheet = true }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "plus")
                            .font(.system(size: theme.iconS))
                        Text("Create")
                            .font(.system(size: theme.textSize, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                }
                .buttonStyle(.plain)

                Button(action: { showImportSheet = true }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: theme.iconS))
                        Text("Import")
                            .font(.system(size: theme.textSize, weight: .medium))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .stroke(theme.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(msg)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Button("Retry") { loadArtifacts() }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
        }
    }

    // MARK: - Data Loading

    private func checkEngineAndLoad() {
        Task {
            do {
                engineOnline = try await ipcClient.artifactPing()
                artifactsLog.info("Artifacts engine online: \(self.engineOnline)")
                if engineOnline { loadArtifacts() }
            } catch {
                engineOnline = false
                artifactsLog.error("Artifacts engine ping failed: \(error)")
            }
        }
    }

    private func loadArtifacts() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await ipcClient.artifactList(sessionId: sessionId)
                let items = result["artifacts"] as? [[String: Any]] ?? []
                var parsed: [ArtifactModel] = []
                for item in items {
                    if let model = parseArtifactModel(from: item) {
                        parsed.append(model)
                    }
                }
                artifacts = parsed
                artifactsLog.info("Loaded \(parsed.count) artifacts")
            } catch {
                errorMessage = "Failed to load artifacts: \(error.localizedDescription)"
                artifactsLog.error("loadArtifacts: \(error)")
            }
            isLoading = false
        }
    }

    private func loadContent(for artifact: ArtifactModel) {
        selectedContent = nil
        Task {
            do {
                let result = try await ipcClient.artifactGetContent(artifactId: artifact.id)
                if let content = result["content"] as? String {
                    selectedContent = content
                }
            } catch {
                selectedContent = "Error loading content: \(error.localizedDescription)"
                artifactsLog.error("loadContent: \(error)")
            }
        }
    }

    private func deleteArtifact(_ artifact: ArtifactModel) {
        Task {
            do {
                _ = try await ipcClient.artifactDelete(artifactId: artifact.id)
                artifacts.removeAll { $0.id == artifact.id }
                if selectedArtifact?.id == artifact.id {
                    selectedArtifact = nil
                    selectedContent = nil
                }
                artifactsLog.info("Deleted artifact \(artifact.id)")
            } catch {
                errorMessage = "Failed to delete: \(error.localizedDescription)"
                artifactsLog.error("deleteArtifact: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func parseArtifactModel(from dict: [String: Any]) -> ArtifactModel? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let type = dict["type"] as? String else { return nil }
        let version = dict["current_version"] as? Int ?? 1
        let tokens = dict["token_count"] as? Int ?? 0
        let summary = dict["summary"] as? String
        let updatedAt: Date
        if let ts = dict["updated_at"] as? Double {
            updatedAt = Date(timeIntervalSince1970: ts)
        } else {
            updatedAt = Date()
        }
        return ArtifactModel(id: id, name: name, type: type, currentVersion: version,
                             tokenCount: tokens, summary: summary, updatedAt: updatedAt)
    }

    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "markdown": return "doc.text"
        case "html": return "globe"
        case "react": return "atom"
        case "data": return "tablecells"
        default: return "doc"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type.lowercased() {
        case "code": return .blue
        case "markdown": return .purple
        case "html": return .orange
        case "react": return .cyan
        case "data": return .green
        default: return .gray
        }
    }
}

// MARK: - HTMLPreviewView

struct HTMLPreviewView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
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
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - CreateArtifactSheet

struct CreateArtifactSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let sessionId: String
    let onComplete: (ArtifactModel?) -> Void

    @State private var name = ""
    @State private var type = "code"
    @State private var content = ""
    @State private var summary = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let types = ["code", "markdown", "html", "react", "data"]

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Create Artifact")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(types, id: \.self) { Text($0.capitalized) }
                }
                TextField("Summary (optional)", text: $summary)
                TextEditor(text: $content)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 200)
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Create") { createArtifact() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(name.isEmpty || content.isEmpty || isCreating)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 480)
    }

    private func createArtifact() {
        isCreating = true
        errorMessage = nil
        Task {
            do {
                _ = try await ipcClient.artifactCreate(
                    sessionId: sessionId, name: name, type: type,
                    content: content, summary: summary.isEmpty ? nil : summary
                )
                artifactsLog.info("Created artifact: \(self.name)")
                onComplete(nil)
                dismiss()
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
                artifactsLog.error("createArtifact: \(error)")
            }
            isCreating = false
        }
    }
}

// MARK: - EditContentSheet

struct EditContentSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let artifact: ArtifactModel
    let onComplete: (Bool) -> Void

    @State private var content = ""
    @State private var changeLog = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Edit: \(artifact.name)")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Form {
                TextEditor(text: $content)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 250)
                TextField("Change log (optional)", text: $changeLog)
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Save New Version") { saveVersion() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(content.isEmpty || isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 440)
        .onAppear { loadCurrentContent() }
    }

    private func loadCurrentContent() {
        Task {
            do {
                let result = try await ipcClient.artifactGetContent(artifactId: artifact.id)
                if let c = result["content"] as? String { content = c }
            } catch {
                artifactsLog.error("loadCurrentContent: \(error)")
            }
        }
    }

    private func saveVersion() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                _ = try await ipcClient.artifactUpdate(
                    artifactId: artifact.id, content: content,
                    changeLog: changeLog.isEmpty ? nil : changeLog
                )
                artifactsLog.info("Updated artifact \(self.artifact.id)")
                onComplete(true)
                dismiss()
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
                artifactsLog.error("saveVersion: \(error)")
            }
            isSaving = false
        }
    }
}

// MARK: - VersionHistorySheet

struct VersionHistorySheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let artifact: ArtifactModel

    @State private var versions: [ArtifactVersionModel] = []
    @State private var isLoading = true
    @State private var isRollingBack = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Version History: \(artifact.name)")
                    .font(.system(size: theme.titleSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
            }
            .padding(theme.spacingL)

            Rectangle().fill(theme.separator).frame(height: 1)

            if isLoading {
                Spacer()
                ProgressView("Loading versions...")
                Spacer()
            } else if versions.isEmpty {
                Spacer()
                Text("No versions found")
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                List(versions) { version in
                    versionRow(version)
                }
                .listStyle(.sidebar)
            }

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
                    .padding(theme.spacingS)
            }
        }
        .frame(width: 450, height: 400)
        .onAppear { loadVersions() }
    }

    private func versionRow(_ version: ArtifactVersionModel) -> some View {
        HStack(spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Text("v\(version.versionNum)")
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Text("\(version.tokenCount) tok")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    if version.versionNum == artifact.currentVersion {
                        Text("CURRENT")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 2).fill(theme.accent))
                    }
                }
                if let log = version.changeLog, !log.isEmpty {
                    Text(log)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                Text(version.createdAt, style: .date)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            if version.versionNum != artifact.currentVersion {
                Button("Rollback") { rollback(to: version.versionNum) }
                    .buttonStyle(.plain)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.accent)
                    .disabled(isRollingBack)
            }
        }
        .padding(.vertical, 2)
    }

    private func loadVersions() {
        isLoading = true
        Task {
            do {
                let result = try await ipcClient.artifactVersionList(artifactId: artifact.id)
                let items = result["versions"] as? [[String: Any]] ?? []
                var parsed: [ArtifactVersionModel] = []
                for v in items {
                    guard let verNum = v["version_num"] as? Int else { continue }
                    let id = v["id"] as? Int ?? verNum
                    let tokens = v["token_count"] as? Int ?? 0
                    let changeLog = v["change_log"] as? String
                    let createdAt: Date
                    if let ts = v["created_at"] as? Double {
                        createdAt = Date(timeIntervalSince1970: ts)
                    } else {
                        createdAt = Date()
                    }
                    parsed.append(ArtifactVersionModel(id: id, versionNum: verNum,
                                                       tokenCount: tokens, changeLog: changeLog, createdAt: createdAt))
                }
                versions = parsed
            } catch {
                errorMessage = "Failed to load versions: \(error.localizedDescription)"
                artifactsLog.error("loadVersions: \(error)")
            }
            isLoading = false
        }
    }

    private func rollback(to versionNum: Int) {
        isRollingBack = true
        Task {
            do {
                _ = try await ipcClient.artifactVersionRollback(
                    artifactId: artifact.id, targetVersion: versionNum
                )
                artifactsLog.info("Rolled back \(self.artifact.id) to v\(versionNum)")
                dismiss()
            } catch {
                errorMessage = "Rollback failed: \(error.localizedDescription)"
                artifactsLog.error("rollback: \(error)")
            }
            isRollingBack = false
        }
    }
}

// MARK: - ExportArtifactSheet

struct ExportArtifactSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let artifact: ArtifactModel

    @State private var exportedData: String?
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Export: \(artifact.name)")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if let data = exportedData {
                ScrollView {
                    Text(data)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .textSelection(.enabled)
                        .padding(theme.spacingM)
                }
                .frame(maxHeight: 300)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if exportedData != nil {
                    Button("Copy to Clipboard") {
                        if let data = exportedData {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(data, forType: .string)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                }
                Button("Export") { doExport() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(isExporting)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: exportedData != nil ? 480 : 200)
    }

    private func doExport() {
        isExporting = true
        errorMessage = nil
        Task {
            do {
                let result = try await ipcClient.artifactExport(artifactId: artifact.id)
                if let data = result["data"] as? [String: Any] {
                    exportedData = String(
                        data: try JSONSerialization.data(withJSONObject: data,
                                                          options: [.prettyPrinted, .sortedKeys]),
                        encoding: .utf8
                    )
                }
            } catch {
                errorMessage = "Export failed: \(error.localizedDescription)"
                artifactsLog.error("doExport: \(error)")
            }
            isExporting = false
        }
    }
}

// MARK: - ImportArtifactSheet

struct ImportArtifactSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let onComplete: (Bool) -> Void

    @State private var importText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Import Artifact")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Text("Paste exported artifact JSON below:")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)

            TextEditor(text: $importText)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 200)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Import") { doImport() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(importText.isEmpty || isImporting)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 380)
    }

    private func doImport() {
        isImporting = true
        errorMessage = nil
        guard let jsonData = importText.data(using: .utf8),
              let dataDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            errorMessage = "Invalid JSON"
            isImporting = false
            return
        }
        Task {
            do {
                _ = try await ipcClient.artifactImport(data: dataDict)
                artifactsLog.info("Imported artifact successfully")
                onComplete(true)
                dismiss()
            } catch {
                errorMessage = "Import failed: \(error.localizedDescription)"
                artifactsLog.error("doImport: \(error)")
            }
            isImporting = false
        }
    }
}

// MARK: - InjectPreviewSheet

struct InjectPreviewSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    @State private var messagesText = ""
    @State private var injectedMessages: [[String: Any]]?
    @State private var totalTokens: Int?
    @State private var isSafe: Bool?
    @State private var currentTokens: Int?
    @State private var remainingTokens: Int?
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var mode = 0

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Inject / Safety Preview")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Picker("Mode", selection: $mode) {
                Text("Inject").tag(0)
                Text("Safety Check").tag(1)
            }
            .pickerStyle(.segmented)

            TextEditor(text: $messagesText)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(
                    Group {
                        if messagesText.isEmpty {
                            Text("Paste messages JSON array here...")
                                .foregroundStyle(theme.textTertiary)
                                .padding(.top, 8).padding(.leading, 4)
                        }
                    }, alignment: .topLeading
                )

            Button(mode == 0 ? "Run Inject" : "Check Safety") { runCheck() }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .fill(theme.accent)
                )
                .disabled(messagesText.isEmpty || isRunning)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            if let safe = isSafe, mode == 1 {
                HStack(spacing: theme.spacingM) {
                    Label(safe ? "Safe" : "Unsafe",
                          systemImage: safe ? "checkmark.circle" : "exclamationmark.triangle")
                        .foregroundStyle(safe ? .green : .red)
                    if let current = currentTokens, let remaining = remainingTokens {
                        Text("Current: \(current) tok | Remaining: \(remaining) tok")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            if let total = totalTokens, mode == 0 {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    Text("Total tokens: \(total) | Safe: \(isSafe ?? false ? "Yes" : "No")")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    if let msgs = injectedMessages {
                        Text("Injected \(msgs.count) messages")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 460)
    }

    private func runCheck() {
        isRunning = true
        errorMessage = nil
        guard let data = messagesText.data(using: .utf8),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            errorMessage = "Invalid messages JSON"
            isRunning = false
            return
        }
        Task {
            do {
                if mode == 0 {
                    let result = try await ipcClient.artifactInject(messages: messages)
                    injectedMessages = result["messages"] as? [[String: Any]]
                    totalTokens = result["total_tokens"] as? Int
                    isSafe = result["safe"] as? Bool
                } else {
                    let result = try await ipcClient.artifactCheckSafety(messages: messages)
                    isSafe = result["safe"] as? Bool
                    currentTokens = result["current_tokens"] as? Int
                    remainingTokens = result["remaining_tokens"] as? Int
                }
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
                artifactsLog.error("runCheck: \(error)")
            }
            isRunning = false
        }
    }
}

// MARK: - SessionPickerView

struct SessionPickerView: View {
    @Environment(\.studioTheme) private var theme
    @Binding var currentSession: String
    @State private var newSession = ""

    private let presetSessions = ["default", "workspace", "sandbox"]

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Text("Switch Session")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            ForEach(presetSessions, id: \.self) { session in
                HStack {
                    Text(session)
                        .foregroundStyle(theme.text)
                    Spacer()
                    if session == currentSession {
                        Image(systemName: "checkmark")
                            .foregroundStyle(theme.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { currentSession = session }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
            }

            Divider()

            HStack {
                TextField("Custom session", text: $newSession)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !newSession.isEmpty {
                            currentSession = newSession
                            newSession = ""
                        }
                    }
                Button("Go") {
                    if !newSession.isEmpty {
                        currentSession = newSession
                        newSession = ""
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, theme.spacingM)
        }
        .padding(theme.spacingM)
        .frame(width: 220)
    }
}
