// Callers: SectionContentView (case .artifacts).
// Affected API: ArtifactsPanel (artifact gallery with search, list, detail view).
// Data schemas: ArtifactModel (id, name, type, version, tokenCount, summary, updatedAt).
// Communication: IPCClient.artifact* methods (HTTP JSON-RPC to artifacts-engine on port 8892).
// User instruction: "马上给上游提交issue和pr"

import SwiftUI
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

struct ArtifactsPanel: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @State private var searchText = ""
    @State private var artifacts: [ArtifactModel] = []
    @State private var selectedArtifact: ArtifactModel?
    @State private var selectedContent: String?
    @State private var versions: [ArtifactVersionModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var engineOnline = false

    private let sessionId = "default"

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
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Text("Artifacts")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if engineOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }

            Spacer()

            Button(action: { loadArtifacts() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button(action: { }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Search Artifacts")
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    private var filteredArtifacts: [ArtifactModel] {
        if searchText.isEmpty { return artifacts }
        return artifacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.type.localizedCaseInsensitiveContains(searchText)
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

    private func artifactDetail(_ artifact: ArtifactModel) -> some View {
        VStack(spacing: 0) {
            detailHeader(artifact)
            Rectangle().fill(theme.separator).frame(height: 1)

            if let content = selectedContent {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        Text(content)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                            .padding(theme.spacingL)
                    }
                }
            } else {
                Spacer()
                ProgressView("Loading content...")
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
        }
        .frame(minWidth: 300)
        .onAppear {
            loadContent(for: artifact)
        }
        .onChange(of: artifact.id) { _ in
            loadContent(for: artifact)
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
                if let summary = artifact.summary {
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

            Button(action: { loadVersions(for: artifact) }) {
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

            Button(action: {
                loadArtifacts()
            }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                    Text("Refresh")
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
                if engineOnline {
                    loadArtifacts()
                }
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

    private func loadVersions(for artifact: ArtifactModel) {
        Task {
            do {
                let result = try await ipcClient.artifactVersionList(artifactId: artifact.id)
                let versionItems = result["versions"] as? [[String: Any]] ?? []
                for v in versionItems {
                    artifactsLog.info("Version \(v["version_num"] ?? "?"): \(v["token_count"] ?? 0) tokens")
                }
            } catch {
                artifactsLog.error("loadVersions: \(error)")
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
              let type = dict["type"] as? String else {
            return nil
        }
        let version = dict["current_version"] as? Int ?? 1
        let tokens = dict["token_count"] as? Int ?? 0
        let summary = dict["summary"] as? String
        let updatedAt: Date
        if let ts = dict["updated_at"] as? Double {
            updatedAt = Date(timeIntervalSince1970: ts)
        } else {
            updatedAt = Date()
        }
        return ArtifactModel(
            id: id,
            name: name,
            type: type,
            currentVersion: version,
            tokenCount: tokens,
            summary: summary,
            updatedAt: updatedAt
        )
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
