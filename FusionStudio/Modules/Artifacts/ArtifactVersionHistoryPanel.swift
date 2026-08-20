import SwiftUI
import os.log

private let verLog = Logger(subsystem: "com.fusion.studio", category: "Artifacts.VersionHistory")

struct ArtifactVersionHistoryPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let artifactId: String
    @State private var versions: [[String: Any]] = []
    @State private var isLoading = false
    @State private var showRollbackConfirm = false
    @State private var rollbackTarget: Int?
    @State private var showCreateSnapshot = false
    @State private var snapshotLabel = ""
    @State private var showDiff = false
    @State private var diffBaseVersion: Int?
    @State private var diffTargetVersion: Int?
    @State private var diffContent: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar

            Rectangle().fill(theme.separator).frame(height: 1)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if versions.isEmpty {
                emptyState
            } else {
                versionList
            }

            if showDiff, diffContent != nil {
                diffPanel
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear { loadVersions() }
        .alert(i18n.t(.art_vh_rollbackConfirm), isPresented: $showRollbackConfirm) {
            Button(i18n.t(.art_vh_rollback)) { performRollback() }
            Button(i18n.t(.art_vh_cancel), role: .cancel) { }
        } message: {
            if let v = rollbackTarget {
                Text(String(format: i18n.t(.art_vh_rollbackMsg), v))
            }
        }
        .alert(i18n.t(.art_vh_createSnapshot), isPresented: $showCreateSnapshot) {
            TextField(i18n.t(.art_vh_snapshotName), text: $snapshotLabel)
            Button(i18n.t(.art_vh_create)) { createSnapshot() }
            Button(i18n.t(.art_vh_cancel), role: .cancel) { }
        }
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingM) {
            Text(i18n.t(.art_vh_title))
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Spacer()

            Button(action: { showCreateSnapshot = true }) {
                Label(i18n.t(.art_vh_createSnapshot), systemImage: "bookmark")
            }
            .font(.system(size: theme.footnoteSize))
            .buttonStyle(.plain)
            .foregroundStyle(theme.accent)

            Button(action: { loadVersions() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "clock")
                .font(.system(size: 30))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.art_vh_empty))
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var versionList: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingXS) {
                ForEach(versions.indices, id: \.self) { idx in
                    versionRow(versions[idx], index: idx)
                }
            }
            .padding(theme.spacingM)
        }
    }

    private func versionRow(_ v: [String: Any], index: Int) -> some View {
        let ver = v["version"] as? Int ?? 0
        let label = v["label"] as? String ?? "auto"
        let ts = v["created_at"] as? String ?? ""
        let isNamed = v["is_named"] as? Bool ?? false
        let isCurrent = index == 0
        let charCount = v["char_count"] as? Int ?? 0

        return HStack(spacing: theme.spacingS) {
            ZStack {
                Circle()
                    .fill(isCurrent ? theme.accent.opacity(0.15) : theme.surfaceElevated)
                    .frame(width: 28, height: 28)
                Image(systemName: isNamed ? "bookmark.fill" : (isCurrent ? "circle.fill" : "circle"))
                    .font(.system(size: isCurrent ? 8 : theme.iconS))
                    .foregroundStyle(isNamed ? theme.accent : (isCurrent ? theme.accent : theme.textTertiary))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Text("v\(ver)")
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    if isNamed {
                        Text(label)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.accent)
                    }
                    if isCurrent {
                        Text(i18n.t(.art_vh_current))
                            .font(.system(size: theme.captionSize, weight: .medium))
                            .foregroundStyle(theme.accentText)
                            .padding(.horizontal, theme.spacingXS)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 4).fill(theme.accent))
                    }
                }
                HStack(spacing: theme.spacingXS) {
                    Text(formatTimestamp(ts))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                    if charCount > 0 {
                        Text("·")
                            .foregroundStyle(theme.textTertiary)
                        Text(String(format: i18n.t(.art_vh_chars), charCount))
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }

            Spacer()

            if !isCurrent {
                Button(action: { showDiffFor(ver) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(i18n.t(.art_vh_diffCurrent))

                Button(i18n.t(.art_vh_rollback)) {
                    rollbackTarget = ver
                    showRollbackConfirm = true
                }
                .font(.system(size: theme.captionSize))
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(isCurrent ? theme.accent.opacity(0.04) : theme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(isCurrent ? theme.accent.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }

    private var diffPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(theme.separator).frame(height: 1)

            HStack {
                Text(i18n.t(.art_vh_incremental))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                if let base = diffBaseVersion, let target = diffTargetVersion {
                    Text("v\(target) → v\(base)")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Button(action: { showDiff = false; diffContent = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)

            if let diff = diffContent {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(diff.split(separator: "\n").indices, id: \.self) { idx in
                            let line = diff.split(separator: "\n")[idx]
                            patchLineView(String(line))
                        }
                    }
                    .padding(theme.spacingM)
                }
                .frame(maxHeight: 250)
            }
        }
    }

    @ViewBuilder
    private func patchLineView(_ line: String) -> some View {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            Text(line)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 1)
                .padding(.horizontal, 4)
                .background(Color.green.opacity(0.08))
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            Text(line)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 1)
                .padding(.horizontal, 4)
                .background(Color.red.opacity(0.08))
        } else if line.hasPrefix("@@") {
            Text(line)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 1)
                .padding(.horizontal, 4)
        } else {
            Text(line)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 1)
                .padding(.horizontal, 4)
        }
    }

    private func formatTimestamp(_ ts: String) -> String {
        guard !ts.isEmpty else { return "" }
        if ts.count > 19 {
            return String(ts.prefix(19)).replacingOccurrences(of: "T", with: " ")
        }
        return ts
    }

    private func loadVersions() {
        isLoading = true
        Task {
            do {
                let r = try await ipc.artifactVersionList(artifactId: artifactId)
                let items = r["versions"] as? [[String: Any]] ?? []
                await MainActor.run { versions = items; isLoading = false }
                verLog.info("versions loaded: \(items.count)")
            } catch {
                verLog.error("version list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func createSnapshot() {
        guard !snapshotLabel.isEmpty else { return }
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.create_snapshot", params: [
                    "artifact_id": artifactId,
                    "label": snapshotLabel
                ])
                verLog.info("snapshot created: \(self.snapshotLabel)")
                await MainActor.run { snapshotLabel = "" }
                loadVersions()
            } catch {
                verLog.error("create snapshot failed: \(error.localizedDescription)")
            }
        }
    }

    private func showDiffFor(_ targetVer: Int) {
        guard let currentVer = versions.first?["version"] as? Int else { return }
        diffBaseVersion = currentVer
        diffTargetVersion = targetVer
        Task {
            do {
                let r = try await ipc.artifactCall(method: "artifact.version_diff", params: [
                    "artifact_id": artifactId,
                    "from_version": targetVer,
                    "to_version": currentVer
                ])
                let diff = r["diff"] as? String ?? r["unified_diff"] as? String ?? I18nManager.shared.t(.art_vh_noDiff)
                await MainActor.run {
                    diffContent = diff
                    showDiff = true
                }
            } catch {
                verLog.error("version diff failed: \(error.localizedDescription)")
                await MainActor.run {
                    diffContent = String(format: I18nManager.shared.t(.art_vh_diffFail), error.localizedDescription)
                    showDiff = true
                }
            }
        }
    }

    private func performRollback() {
        guard let target = rollbackTarget else { return }
        Task {
            do {
                _ = try await ipc.artifactVersionRollback(artifactId: artifactId, targetVersion: target)
                verLog.info("rolled back to v\(target)")
                loadVersions()
            } catch {
                verLog.error("rollback failed: \(error.localizedDescription)")
            }
        }
    }
}
