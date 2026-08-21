import SwiftUI
import Foundation
import os.log

private let snapshotLog = Logger(subsystem: "com.fusion.studio", category: "FCSnapshot")

class FCSnapshotManager: ObservableObject {
    static let shared = FCSnapshotManager()

    @Published var snapshots: [FCSnapshotInfo] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let fileManager = FileManager.default

    var snapshotDir: String {
        let projectRoot = ProjectWorkspace.shared.projectRoot?.path ?? NSHomeDirectory()
        return "\(projectRoot)/.fusion/snapshots"
    }

    func loadSnapshots(sessionId: String? = nil) {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let dir = sessionId.map { "\(self.snapshotDir)/\($0)" } ?? self.snapshotDir
            var results: [FCSnapshotInfo] = []

            guard let enumerator = self.fileManager.enumerator(atPath: dir) else {
                DispatchQueue.main.async {
                    self.snapshots = []
                    self.isLoading = false
                }
                return
            }

            for case let path as String in enumerator {
                if path.hasSuffix(".json"), path.contains("snapshot") {
                    let full = "\(dir)/\(path)"
                    if let data = self.fileManager.contents(atPath: full),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let id = json["id"] as? String ?? path
                        let label = json["label"] as? String ?? ""
                        let createdAt = json["created_at"] as? Double ?? 0
                        let deltas = json["deltas"] as? [[String: Any]] ?? []
                        let info = FCSnapshotInfo(
                            id: id,
                            label: label,
                            createdAt: createdAt > 0 ? createdAt : Date().timeIntervalSince1970,
                            deltaCount: deltas.count
                        )
                        results.append(info)
                    }
                }
            }

            results.sort { $0.createdAt > $1.createdAt }
            DispatchQueue.main.async {
                self.snapshots = results
                self.isLoading = false
                snapshotLog.info("loaded \(results.count) snapshots")
            }
        }
    }

    func createSnapshot(sessionId: String, label: String = "") {
        let id = UUID().uuidString.prefix(12).lowercased()
        let dir = "\(snapshotDir)/\(sessionId)"
        try? fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let snapshot: [String: Any] = [
            "id": String(id),
            "label": label,
            "created_at": Date().timeIntervalSince1970,
            "deltas": []
        ]

        let path = "\(dir)/snapshot_\(id).json"
        if let data = try? JSONSerialization.data(withJSONObject: snapshot, options: .prettyPrinted) {
            fileManager.createFile(atPath: path, contents: data)
            snapshotLog.info("snapshot created: \(id) for session \(sessionId)")
        }

        loadSnapshots(sessionId: sessionId)
    }

    func restoreSnapshot(sessionId: String, snapshotId: String) {
        snapshotLog.info("restore snapshot \(snapshotId) for session \(sessionId)")
        let path = "\(snapshotDir)/\(sessionId)/snapshot_\(snapshotId).json"
        guard let data = fileManager.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            lastError = String(format: I18nManager.shared.t(.fc_snap_not_found), snapshotId)
            return
        }
        let deltaCount = (json["deltas"] as? [[String: Any]])?.count ?? 0
        snapshotLog.info("snapshot restored: \(snapshotId), deltas=\(deltaCount)")
    }

    func deleteSnapshot(sessionId: String, snapshotId: String) {
        let path = "\(snapshotDir)/\(sessionId)/snapshot_\(snapshotId).json"
        try? fileManager.removeItem(atPath: path)
        snapshotLog.info("snapshot deleted: \(snapshotId)")
        loadSnapshots(sessionId: sessionId)
    }

    func rewind(sessionId: String, steps: Int = 1) {
        let targetIdx = max(0, snapshots.count - steps - 1)
        guard targetIdx < snapshots.count else { return }
        let target = snapshots[targetIdx]
        restoreSnapshot(sessionId: sessionId, snapshotId: target.id)
        snapshotLog.info("rewound \(steps) steps to snapshot \(target.id)")
    }
}

struct FCSnapshotPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var manager = FCSnapshotManager.shared
    let sessionId: String
    @State private var newLabel = ""
    @State private var showCreateSheet = false
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(spacing: theme.spacingS) {
            HStack {
                Text(i18n.t(.fc_snapshots))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                Button(action: { manager.loadSnapshots(sessionId: sessionId) }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if manager.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            } else if manager.snapshots.isEmpty {
                Text(i18n.t(.fc_no_snapshots))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(manager.snapshots) { snap in
                            snapshotRow(snap)
                        }
                    }
                }
            }
        }
        .padding(theme.spacingM)
        .frame(maxHeight: 300)
        .onAppear { manager.loadSnapshots(sessionId: sessionId) }
        .sheet(isPresented: $showCreateSheet) {
            VStack(spacing: 12) {
                Text(i18n.t(.fc_create_snapshot))
                    .font(.system(size: 13, weight: .semibold))
                TextField(i18n.t(.fc_label_optional), text: $newLabel)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(i18n.t(.fc_cancel)) { showCreateSheet = false }
                    Button(i18n.t(.fc_create)) {
                        manager.createSnapshot(sessionId: sessionId, label: newLabel)
                        newLabel = ""
                        showCreateSheet = false
                    }
                }
            }
            .padding(16)
            .frame(width: 260)
        }
    }

    private func snapshotRow(_ snap: FCSnapshotInfo) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "camera")
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(snap.displayLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(String(format: i18n.t(.fc_snap_deltas_fmt), snap.deltaCount, snap.formattedDate))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 4).fill(theme.groupBg))
        .contextMenu {
            Button(i18n.t(.fc_restore)) { manager.restoreSnapshot(sessionId: sessionId, snapshotId: snap.id) }
            Button(i18n.t(.fc_rewind_here)) { manager.rewind(sessionId: sessionId, steps: manager.snapshots.firstIndex(where: { $0.id == snap.id }) ?? 0) }
            Divider()
            Button(i18n.t(.fc_delete), role: .destructive) { manager.deleteSnapshot(sessionId: sessionId, snapshotId: snap.id) }
        }
    }
}
