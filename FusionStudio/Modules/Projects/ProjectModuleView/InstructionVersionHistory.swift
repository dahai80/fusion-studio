import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct InstructionVersionHistory: View {
    let projectId: String
    let snapshots: [InstructionSnapshot]
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ipc: IPCClient

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.proj_instHistoryTitle))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            if snapshots.isEmpty {
                Text(i18n.t(.proj_instHistoryEmpty))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingS) {
                        ForEach(Array(snapshots.enumerated()), id: \.element.id) { idx, snap in
                            HStack(alignment: .top, spacing: theme.spacingS) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(idx == 0 ? "●" : "○")
                                            .foregroundStyle(idx == 0 ? theme.accent : theme.textTertiary)
                                        Text(String(format: i18n.t(.proj_instHistoryCurrentFmt), snapshots.count - idx))
                                            .font(.system(size: theme.footnoteSize, weight: .medium))
                                        Text("— \(relativeTime(snap.createdAt))")
                                            .font(.system(size: theme.captionSize))
                                            .foregroundStyle(theme.textTertiary)
                                        if idx == 0 {
                                            Text(i18n.t(.proj_instHistoryCurrentTag))
                                                .font(.system(size: 9))
                                                .foregroundStyle(theme.accent)
                                        }
                                    }
                                    Text(String(snap.content.prefix(80)))
                                        .font(.system(size: theme.captionSize, design: .monospaced))
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if idx != 0 {
                                    Button(i18n.t(.proj_instHistoryRestore)) {
                                        restoreSnapshot(snap)
                                    }
                                    .font(.system(size: theme.captionSize))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(theme.accent)
                                }
                                if snapshots.count > 1 {
                                    Button(role: .destructive) {
                                        deleteSnapshot(snap)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: theme.captionSize))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(theme.spacingS)
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(theme.textTertiary.opacity(0.04)))
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button(i18n.t(.close)) { dismiss() }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 400)
    }

    private func restoreSnapshot(_ snap: InstructionSnapshot) {
        Task {
            do {
                _ = try await ipc.projectInstructionSnapshotRestore(snapshotId: snap.id)
                projLog.info("Instruction restored to snapshot \(snap.id)")
                dismiss()
            } catch {
                projLog.error("restoreSnapshot failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteSnapshot(_ snap: InstructionSnapshot) {
        Task {
            do {
                _ = try await ipc.projectInstructionSnapshotDelete(snapshotId: snap.id)
                projLog.info("Instruction snapshot deleted \(snap.id)")
            } catch {
                projLog.error("deleteSnapshot failed: \(error.localizedDescription)")
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return String(format: i18n.t(.proj_minAgoFmt), Int(interval / 60)) }
        if interval < 86400 { return String(format: i18n.t(.proj_hourAgoFmt), Int(interval / 3600)) }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - GUI-4 + GUI-18: Knowledge Base Tree View

