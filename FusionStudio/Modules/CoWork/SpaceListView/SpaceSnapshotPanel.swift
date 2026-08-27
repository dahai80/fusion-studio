import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")


struct SpaceSnapshotPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var snapshots: [SpaceSnapshot] = []
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var snapName = ""
    @State private var showForkDialog = false
    @State private var forkSnapId = ""
    @State private var forkName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_snap2_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showCreate = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                Button(action: { loadSnapshots() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if isLoading {
                ProgressView().padding()
            } else if snapshots.isEmpty {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_snap2_empty))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacingL)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(snapshots) { snap in
                            snapRow(snap)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }
        }
        .onAppear { loadSnapshots() }
        .alert(i18n.t(.cw_snap2_createTitle), isPresented: $showCreate) {
            TextField(i18n.t(.cw_snap2_namePh), text: $snapName)
            Button(i18n.t(.cw_snap2_createTitle)) { createSnapshot() }
            Button(i18n.t(.cancel), role: .cancel) { }
        }
        .alert(i18n.t(.cw_snap2_forkTitle), isPresented: $showForkDialog) {
            TextField(i18n.t(.cw_snap2_forkSpacePh), text: $forkName)
            Button(i18n.t(.cw_snap2_forkTitle)) { forkSnapshot() }
            Button(i18n.t(.cancel), role: .cancel) { }
        }
    }

    private func snapRow(_ snap: SpaceSnapshot) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "camera")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(snap.name)
                    .font(.system(size: theme.captionSize, weight: .medium))
                HStack(spacing: theme.spacingXS) {
                    Label("\(snap.messageCount)", systemImage: "bubble.left")
                    Label("\(snap.agentCount)", systemImage: "brain.head.profile")
                    Label("\(snap.artifactCount)", systemImage: "shippingbox")
                }
                .font(.system(size: 8))
                .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Menu {
                Button(i18n.t(.cw_snap2_restore)) { restoreSnapshot(snap.id) }
                Button(i18n.t(.cw_snap2_forkNew)) {
                    forkSnapId = snap.id
                    forkName = snap.name + " (Fork)"
                    showForkDialog = true
                }
                Divider()
                Button(i18n.t(.delete), role: .destructive) { deleteSnapshot(snap.id) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 4)
    }

    private func createSnapshot() {
        Task {
            do {
                _ = try await ipc.spaceSnapshotCreate(spaceId: spaceId, name: snapName.isEmpty ? "snapshot" : snapName)
                snapName = ""
                loadSnapshots()
            } catch {
                spaceLog.error("snapshot.create failed: \(error.localizedDescription)")
            }
        }
    }

    private func restoreSnapshot(_ snapId: String) {
        Task {
            do {
                _ = try await ipc.spaceCall(method: "desk.space.snapshot.restore", params: [
                    "space_id": spaceId, "snapshot_id": snapId,
                ])
                spaceLog.info("Snapshot restored: \(snapId)")
                loadSnapshots()
            } catch {
                spaceLog.error("snapshot.restore failed: \(error.localizedDescription)")
            }
        }
    }

    private func forkSnapshot() {
        Task {
            do {
                _ = try await ipc.spaceSnapshotClone(spaceId: spaceId, snapshotId: forkSnapId, newName: forkName)
                spaceLog.info("Snapshot forked: \(forkSnapId)")
                forkName = ""
                loadSnapshots()
            } catch {
                spaceLog.error("snapshot.fork failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteSnapshot(_ snapId: String) {
        Task {
            do {
                _ = try await ipc.spaceCall(method: "desk.space.snapshot.delete", params: [
                    "space_id": spaceId, "snapshot_id": snapId,
                ])
                loadSnapshots()
            } catch {
                spaceLog.error("snapshot.delete failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadSnapshots() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceSnapshotList(spaceId: spaceId)
                let items = result["snapshots"] as? [[String: Any]] ?? []
                await MainActor.run { snapshots = items.map { SpaceSnapshot.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("snapshot.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

