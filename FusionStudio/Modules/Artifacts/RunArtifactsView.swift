import SwiftUI
import os.log

// N9 (#348) GUI parity: versioned run artifacts (graph + environment + conversation).
private let runArtifactLog = Logger(subsystem: "com.fusion.studio", category: "RunArtifacts")

struct RunArtifactsView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    @State private var artifacts: [[String: Any]] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedArtifactId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar
            Rectangle().fill(theme.separator).frame(height: 1)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await load() }
        .sheet(isPresented: Binding(
            get: { selectedArtifactId != nil },
            set: { if !$0 { selectedArtifactId = nil } }
        )) {
            if let id = selectedArtifactId {
                RunArtifactDetailView(artifactId: id)
                    .frame(minWidth: 720, minHeight: 560)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: theme.spacingM) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                TextField("Search run artifacts", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await load() } }
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.inputBg))
            .overlay(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).stroke(theme.inputBorder, lineWidth: 1))

            if isLoading {
                ProgressView().controlSize(.small)
            }
            Spacer()
            Button {
                Task { await load() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    @ViewBuilder
    private var content: some View {
        if artifacts.isEmpty && !isLoading {
            VStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.textTertiary)
                Text(errorMessage ?? "No run artifacts yet")
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(Array(artifacts.enumerated()), id: \.offset) { _, item in
                let artifactId = item["artifact_id"] as? String ?? ""
                Button {
                    selectedArtifactId = artifactId
                } label: {
                    RunArtifactRow(item: item)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            artifacts = try await ipc.runArtifactList(limit: 100, name: searchText.trimmingCharacters(in: .whitespaces))
            runArtifactLog.info("loaded \(self.artifacts.count) run artifacts")
        } catch {
            errorMessage = error.localizedDescription
            runArtifactLog.error("load failed: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}

struct RunArtifactRow: View {
    @Environment(\.studioTheme) private var theme
    let item: [String: Any]

    var body: some View {
        HStack(spacing: theme.spacingM) {
            Image(systemName: "shippingbox")
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item["name"] as? String ?? "run")
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text("v\(item["version"] as? Int ?? 0)")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(theme.accent.opacity(0.15)))
                        .foregroundStyle(theme.accent)
                }
                Text(item["run_id"] as? String ?? "")
                    .font(.caption2)
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            metric("bubble.left", item["message_count"] as? Int ?? 0)
            metric("circle.grid.3x3", item["graph_nodes"] as? Int ?? 0)
            metric("arrow.triangle.branch", item["graph_edges"] as? Int ?? 0)
            Text(formatDate(item["created_at"] as? Double ?? 0))
                .font(.caption2)
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func metric(_ systemImage: String, _ value: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage).font(.caption2)
            Text("\(value)").font(.caption2)
        }
        .foregroundStyle(theme.textSecondary)
    }

    private func formatDate(_ value: Double) -> String {
        guard value > 0 else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: value))
    }
}

struct RunArtifactDetailView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let artifactId: String

    @State private var record: [String: Any] = [:]
    @State private var versions: [[String: Any]] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(record["name"] as? String ?? "Run Artifact")
                    .font(.headline)
                Text("v\(record["version"] as? Int ?? 0)")
                    .font(.caption)
                    .padding(.horizontal, 5)
                    .background(Capsule().fill(theme.accent.opacity(0.15)))
                Spacer()
                if isLoading { ProgressView().controlSize(.small) }
            }
            .padding(theme.spacingL)
            Rectangle().fill(theme.separator).frame(height: 1)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingL) {
                        overviewSection
                        if !versions.isEmpty { versionsSection }
                        if let conversation = record["conversation"] as? [String: Any] {
                            conversationSection(conversation)
                        }
                        jsonSection("Graph", value: record["graph"])
                        jsonSection("Environment", value: record["environment"])
                        jsonSection("Metadata", value: record["metadata"])
                    }
                    .padding(theme.spacingL)
                }
            }
        }
        .task { await load() }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Overview")
            infoRow("Artifact ID", artifactId)
            infoRow("Run ID", record["run_id"] as? String ?? "")
            infoRow("Schema", record["schema"] as? String ?? "")
            infoRow("Created", formatDate(record["created_at"] as? Double ?? 0))
            if let conversation = record["conversation"] as? [String: Any] {
                infoRow("Messages", "\(conversation["count"] as? Int ?? 0)")
            }
        }
    }

    private var versionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Versions")
            ForEach(Array(versions.enumerated()), id: \.offset) { _, version in
                HStack(spacing: theme.spacingS) {
                    Text("v\(version["version"] as? Int ?? 0)")
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .background(Capsule().fill(theme.surfaceSecondary))
                    Text(version["artifact_id"] as? String ?? "")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(formatDate(version["created_at"] as? Double ?? 0))
                        .font(.caption2)
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    private func conversationSection(_ conversation: [String: Any]) -> some View {
        let messages = conversation["messages"] as? [[String: Any]] ?? []
        return VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Conversation (\(messages.count))")
            ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                VStack(alignment: .leading, spacing: 2) {
                    Text(message["role"] as? String ?? "")
                        .font(.caption2)
                        .foregroundStyle(theme.accent)
                    Text(message["content"] as? String ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 5).fill(theme.surfaceSecondary))
            }
        }
    }

    @ViewBuilder
    private func jsonSection(_ title: String, value: Any?) -> some View {
        if let value, let text = prettyJSON(value) {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle(title)
                ScrollView(.horizontal) {
                    Text(text)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 220)
                .background(RoundedRectangle(cornerRadius: 6).fill(theme.surfaceSecondary))
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.footnoteSize, weight: .semibold))
            .foregroundStyle(theme.textSecondary)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(theme.text)
                .textSelection(.enabled)
        }
    }

    private func prettyJSON(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }

    private func formatDate(_ value: Double) -> String {
        guard value > 0 else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: Date(timeIntervalSince1970: value))
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            record = try await ipc.runArtifactGet(artifactId: artifactId)
            let name = record["name"] as? String ?? ""
            if !name.isEmpty {
                versions = try await ipc.runArtifactVersions(name: name)
            }
            runArtifactLog.info("loaded run artifact \(artifactId, privacy: .public)")
        } catch {
            errorMessage = error.localizedDescription
            runArtifactLog.error("load detail failed: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }
}
