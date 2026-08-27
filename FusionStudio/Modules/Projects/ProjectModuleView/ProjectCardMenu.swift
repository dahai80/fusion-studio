import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ProjectCardMenu: View {
    let project: FusionProject
    let onAction: (ProjectCardAction, FusionProject) -> Void

    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var showDeleteConfirm = false
    @State private var showDuplicateDialog = false
    @State private var showRenameDialog = false
    @State private var renameText = ""

    var body: some View {
        Menu {
            Button(action: { onAction(.star, project) }) {
                Label(project.isStarred ? i18n.t(.proj_menuUnstar) : i18n.t(.proj_menuStar),
                      systemImage: project.isStarred ? "star.slash" : "star")
            }
            Button(action: { renameText = project.name; showRenameDialog = true }) {
                Label(i18n.t(.proj_menuRename), systemImage: "pencil")
            }
            Button(action: { showDuplicateDialog = true }) {
                Label(i18n.t(.proj_menuDuplicate), systemImage: "doc.on.doc")
            }
            Button(action: { onAction(.export, project) }) {
                Label(i18n.t(.proj_menuExport), systemImage: "square.and.arrow.up")
            }
            Divider()
            if project.isArchived {
                Button(action: { onAction(.unarchive, project) }) {
                    Label(i18n.t(.proj_unarchiveBtn), systemImage: "archivebox")
                }
            } else {
                Button(action: { onAction(.archive, project) }) {
                    Label(i18n.t(.proj_menuArchive), systemImage: "archivebox")
                }
            }
            Button(role: .destructive, action: { showDeleteConfirm = true }) {
                Label(i18n.t(.proj_menuDelete), systemImage: "trash")
            }
            Divider()
            Button(action: { onAction(.settings, project) }) {
                Label(i18n.t(.proj_menuSettings), systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: theme.iconXS, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .alert(i18n.t(.proj_deleteAlertTitle), isPresented: $showDeleteConfirm) {
            Button(i18n.t(.cancel), role: .cancel) {}
            Button(i18n.t(.proj_deleteConfirm), role: .destructive) {
                onAction(.delete, project)
            }
        } message: {
            Text(String(format: i18n.t(.proj_deleteAlertMsgFmt), project.name))
        }
        .sheet(isPresented: $showDuplicateDialog) {
            // GUI-6: Duplicate Dialog
            ProjectDuplicateDialog(project: project)
        }
        .sheet(isPresented: $showRenameDialog) {
            VStack(spacing: theme.spacingM) {
                Text(i18n.t(.proj_renameTitle))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                TextField(i18n.t(.proj_namePh), text: $renameText)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(i18n.t(.cancel)) { showRenameDialog = false }
                    Spacer()
                    Button(i18n.t(.save)) {
                        Task { await renameProject() }
                        showRenameDialog = false
                    }
                    .disabled(renameText.isEmpty)
                }
            }
            .padding(theme.spacingL)
            .frame(width: 360)
        }
    }

    private func renameProject() async {
        do {
            _ = try await ipc.projectUpdate(projectId: project.id, fields: ["name": renameText])
            projLog.info("Project renamed: \(renameText)")
        } catch {
            projLog.error("renameProject failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - GUI-3: Create Project Dialog

