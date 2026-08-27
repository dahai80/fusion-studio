import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ProjectGlobalMenu: View {
    let project: FusionProject
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @EnvironmentObject var ipc: IPCClient
    @State private var showDeleteConfirm = false
    @State private var showDuplicateDialog = false

    var body: some View {
        Menu {
            Button(action: { toggleStar() }) {
                Label(project.isStarred ? i18n.t(.proj_menuUnstar) : i18n.t(.proj_menuStar),
                      systemImage: project.isStarred ? "star.slash" : "star")
            }
            Button(action: { }) {
                Label(i18n.t(.proj_menuRename), systemImage: "pencil")
            }
            Button(action: { showDuplicateDialog = true }) {
                Label(i18n.t(.proj_menuDuplicate), systemImage: "doc.on.doc")
            }
            Button(action: { exportProject() }) {
                Label(i18n.t(.proj_menuExport), systemImage: "square.and.arrow.up")
            }
            if project.isArchived {
                Button(action: { unarchiveProject() }) {
                    Label(i18n.t(.proj_unarchiveBtn), systemImage: "archivebox")
                }
            } else {
                Button(action: { archiveProject() }) {
                    Label(i18n.t(.proj_menuArchive), systemImage: "archivebox")
                }
            }
            Divider()
            Button(role: .destructive, action: { showDeleteConfirm = true }) {
                Label(i18n.t(.proj_menuDelete), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
        }
        .menuStyle(.borderlessButton)
        // GUI-20: Delete confirmation
        .alert(i18n.t(.proj_deleteAlertTitle), isPresented: $showDeleteConfirm) {
            Button(i18n.t(.cancel), role: .cancel) {}
            Button(i18n.t(.proj_deleteConfirm), role: .destructive) { deleteProject() }
        } message: {
            Text(String(format: i18n.t(.proj_deleteAlertMsgFullFmt), project.name, project.fileCount, project.chatCount))
        }
        .sheet(isPresented: $showDuplicateDialog) {
            ProjectDuplicateDialog(project: project)
        }
    }

    private func toggleStar() {
        Task { _ = try await ipc.projectStar(projectId: project.id, starred: !project.isStarred) }
    }
    private func archiveProject() {
        Task { _ = try await ipc.projectArchive(projectId: project.id) }
    }
    private func unarchiveProject() {
        Task { _ = try await ipc.projectUnarchive(projectId: project.id) }
    }
    private func exportProject() {
        Task { _ = try await ipc.projectExport(projectId: project.id) }
    }
    private func deleteProject() {
        Task {
            do {
                if !project.isArchived {
                    _ = try await ipc.projectArchive(projectId: project.id)
                }
                try await ipc.projectDelete(projectId: project.id)
                await MainActor.run {
                    let pm = FusionProjectManager.shared
                    pm.projects.removeAll { $0.id == project.id }
                    if pm.activeProject?.id == project.id {
                        pm.activeProject = nil
                        pm.activeChat = nil
                        pm.activeChatMessages = []
                    }
                }
                projLog.info("deleted project \(project.id)")
            } catch {
                projLog.error("deleteProject failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GUI-4 Left Panel: Instructions (Collapsible Section)

