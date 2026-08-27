import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct CoWorkImportDialog: View {
    let project: FusionProject
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ipc: IPCClient

    @State private var selectedSpaceId: String?
    @State private var includeKnowledge = true
    @State private var includeSnapshots = false
    @State private var isImporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.proj_coworkTitle))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_coworkTarget))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                Text(i18n.t(.proj_coworkTargetPlaceholder))
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
            }

            Text(i18n.t(.proj_coworkSyncContent))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Toggle(i18n.t(.proj_coworkSyncKnowledge), isOn: $includeKnowledge)
            Toggle(i18n.t(.proj_coworkSyncSnapshots), isOn: $includeSnapshots)

            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(i18n.t(.proj_coworkWarning))
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                Button(i18n.t(.proj_coworkConfirm)) { importToCoWork() }
                    .disabled(isImporting)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 340)
    }

    private func importToCoWork() {
        isImporting = true
        Task {
            do {
                _ = try await ipc.projectCoworkTrigger(
                    projectId: project.id,
                    action: "import",
                    payload: [
                        "include_knowledge": includeKnowledge,
                        "include_snapshots": includeSnapshots
                    ]
                )
                projLog.info("Imported to CoWork from project \(project.id)")
                await MainActor.run { dismiss() }
            } catch {
                projLog.error("importToCoWork failed: \(error.localizedDescription)")
                await MainActor.run { isImporting = false }
            }
        }
    }
}

// MARK: - GUI-17: RAG Scope Selector (MANUAL mode)

