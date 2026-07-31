import SwiftUI
import os.log

private let verLog = Logger(subsystem: "com.fusion.studio", category: "Artifacts.VersionHistory")

struct ArtifactVersionHistoryPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let artifactId: String
    @State private var versions: [[String: Any]] = []
    @State private var isLoading = false
    @State private var showRollbackConfirm = false
    @State private var rollbackTarget: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("版本历史")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                Spacer()
                Button(action: { loadVersions() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingM)

            if isLoading {
                ProgressView().padding()
            } else if versions.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.textTertiary)
                    Text("暂无版本记录")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(versions.indices, id: \.self) { idx in
                            versionRow(versions[idx])
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                }
            }
        }
        .onAppear { loadVersions() }
        .alert("确认回滚？", isPresented: $showRollbackConfirm) {
            Button("回滚") { performRollback() }
            Button("取消", role: .cancel) { }
        } message: {
            if let v = rollbackTarget {
                Text("将回滚到版本 v\(v)，当前版本将保存为命名快照")
            }
        }
    }

    private func versionRow(_ v: [String: Any]) -> some View {
        let ver = v["version"] as? Int ?? 0
        let label = v["label"] as? String ?? "auto"
        let ts = v["created_at"] as? String ?? ""
        let isNamed = v["is_named"] as? Bool ?? false

        return HStack(spacing: theme.spacingS) {
            Image(systemName: isNamed ? "bookmark.fill" : "clock")
                .font(.system(size: theme.iconM))
                .foregroundStyle(isNamed ? theme.accent : theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Text("v\(ver)")
                        .font(.system(size: theme.textSize, weight: .medium))
                    if isNamed {
                        Text(label)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.accent)
                    }
                }
                Text(ts)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button("回滚") {
                rollbackTarget = ver
                showRollbackConfirm = true
            }
            .font(.system(size: theme.captionSize))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.surfaceSecondary))
    }

    private func loadVersions() {
        isLoading = true
        Task {
            do {
                let r = try await ipc.artifactVersionList(artifactId: artifactId)
                let items = r["versions"] as? [[String: Any]] ?? []
                await MainActor.run { versions = items; isLoading = false }
            } catch {
                verLog.error("version list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
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
