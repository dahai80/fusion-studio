import SwiftUI
import os.log

private let snapLog = Logger(subsystem: "com.fusion.studio", category: "SessionSnapshot")

struct SessionSnapshotView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let spaceId: String
    let sessionId: String

    @State private var snapshots: [[String: Any]] = []
    @State private var isLoading = false
    @State private var showCreateDialog = false
    @State private var newSnapLabel = ""
    @State private var showForkConfirm = false
    @State private var forkSnapId = ""

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text("会话快照")
                    .font(.system(size: theme.textSize, weight: .semibold))
                Spacer()
                Button(action: { showCreateDialog = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("创建快照")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if snapshots.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "camera")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.textTertiary)
                    Text("暂无快照")
                        .foregroundStyle(theme.textSecondary)
                    Text("创建快照以保存当前会话状态，可随时回溯或 Fork")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(snapshots.indices, id: \.self) { idx in
                        snapshotRow(snapshots[idx])
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .padding(theme.spacingM)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { loadSnapshots() }
        .alert("创建快照", isPresented: $showCreateDialog) {
            TextField("标签（可选）", text: $newSnapLabel)
            Button("创建") { createSnapshot() }
            Button("取消", role: .cancel) { newSnapLabel = "" }
        }
        .alert("Fork 此快照为新会话？", isPresented: $showForkConfirm) {
            Button("Fork") { forkSnapshot(forkSnapId) }
            Button("取消", role: .cancel) { forkSnapId = "" }
        }
    }

    @ViewBuilder
    private func snapshotRow(_ snap: [String: Any]) -> some View {
        let snapId = snap["id"] as? String ?? ""
        let label = snap["label"] as? String ?? "auto"
        let ts = snap["created_at"] as? String ?? ""
        let msgCount = snap["message_count"] as? Int ?? 0

        HStack(spacing: theme.spacingS) {
            Image(systemName: label == "auto" ? "clock" : "bookmark")
                .foregroundStyle(theme.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: theme.textSize, weight: .medium))
                HStack(spacing: theme.spacingS) {
                    Text(ts)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                    Text("\(msgCount) 条消息")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            HStack(spacing: theme.spacingXS) {
                Button(action: { restoreSnapshot(snapId) }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("恢复到此快照")

                Button(action: { forkSnapId = snapId; showForkConfirm = true }) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Fork 为新会话")

                Button(action: { deleteSnapshot(snapId) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("删除快照")
            }
        }
        .padding(.vertical, theme.spacingXS)
    }

    private func loadSnapshots() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceCall(method: "desk.session.snapshot_list", params: [
                    "space_id": spaceId,
                    "session_id": sessionId,
                ])
                if let items = result["snapshots"] as? [[String: Any]] {
                    await MainActor.run { snapshots = items }
                }
            } catch {
                snapLog.error("snapshot_list failed: \(error.localizedDescription)")
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func createSnapshot() {
        Task {
            do {
                var params: [String: Any] = [
                    "space_id": spaceId,
                    "session_id": sessionId,
                ]
                if !newSnapLabel.isEmpty {
                    params["label"] = newSnapLabel
                }
                _ = try await ipc.spaceCall(method: "desk.session.snapshot_create", params: params)
                await MainActor.run { newSnapLabel = "" }
                snapLog.info("snapshot created for session \(sessionId)")
                loadSnapshots()
            } catch {
                snapLog.error("snapshot_create failed: \(error.localizedDescription)")
            }
        }
    }

    private func restoreSnapshot(_ snapId: String) {
        Task {
            do {
                _ = try await ipc.spaceCall(method: "desk.session.snapshot_restore", params: [
                    "space_id": spaceId,
                    "session_id": sessionId,
                    "snapshot_id": snapId,
                ])
                snapLog.info("snapshot \(snapId) restored for session \(sessionId)")
            } catch {
                snapLog.error("snapshot_restore failed: \(error.localizedDescription)")
            }
        }
    }

    private func forkSnapshot(_ snapId: String) {
        Task {
            do {
                let result = try await ipc.spaceCall(method: "desk.session.snapshot_fork", params: [
                    "space_id": spaceId,
                    "session_id": sessionId,
                    "snapshot_id": snapId,
                ])
                let newSessionId = result["session_id"] as? String ?? ""
                snapLog.info("forked snapshot \(snapId) → new session \(newSessionId)")
                forkSnapId = ""
            } catch {
                snapLog.error("snapshot_fork failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteSnapshot(_ snapId: String) {
        Task {
            do {
                _ = try await ipc.spaceCall(method: "desk.session.snapshot_delete", params: [
                    "space_id": spaceId,
                    "session_id": sessionId,
                    "snapshot_id": snapId,
                ])
                snapLog.info("snapshot \(snapId) deleted")
                loadSnapshots()
            } catch {
                snapLog.error("snapshot_delete failed: \(error.localizedDescription)")
            }
        }
    }
}
