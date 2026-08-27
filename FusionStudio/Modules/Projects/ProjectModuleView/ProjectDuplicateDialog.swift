import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ProjectDuplicateDialog: View {
    let project: FusionProject
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ipc: IPCClient

    @State private var newName: String
    @State private var includeSessions = false
    @State private var isDuplicating = false

    init(project: FusionProject) {
        self.project = project
        _newName = State(initialValue: project.name + I18nManager.shared.t(.proj_dupCopySuffix))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(i18n.t(.proj_dupTitle))
                .font(.system(size: theme.headlineSize, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_dupNameLabel))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.proj_namePh), text: $newName)
                    .textFieldStyle(.roundedBorder)
            }

            Text(i18n.t(.proj_dupScope))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Picker("", selection: $includeSessions) {
                Text(i18n.t(.proj_dupScopeInstructionsOnly)).tag(false)
                Text(i18n.t(.proj_dupScopeWithSnapshots)).tag(true)
            }
            .pickerStyle(.radioGroup)
            .font(.system(size: theme.captionSize))

            Spacer(minLength: 0)

            HStack {
                Button(i18n.t(.cancel)) { dismiss() }
                Spacer()
                Button(i18n.t(.proj_dupBtn)) { duplicateProject() }
                    .disabled(newName.isEmpty || isDuplicating)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 280)
    }

    private func duplicateProject() {
        isDuplicating = true
        Task {
            do {
                _ = try await ipc.projectDuplicate(projectId: project.id, name: newName)
                projLog.info("Project duplicated: \(newName)")
                await MainActor.run { dismiss() }
            } catch {
                projLog.error("duplicateProject failed: \(error.localizedDescription)")
                await MainActor.run { isDuplicating = false }
            }
        }
    }
}

// MARK: - GUI-4: Project Detail View (Core Page)

