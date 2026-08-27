import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

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

