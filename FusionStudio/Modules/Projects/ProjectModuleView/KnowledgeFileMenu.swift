import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct KnowledgeFileMenu: View {
    let file: KnowledgeFile
    let projectId: String
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        Menu {
            Button(action: { previewFile() }) {
                Label(i18n.t(.proj_kbMenuPreview), systemImage: "eye")
            }
            Button(action: {}) {
                Label(i18n.t(.proj_kbMenuRename), systemImage: "pencil")
            }
            Button(action: {}) {
                Label(i18n.t(.proj_kbMenuReplace), systemImage: "arrow.2.circlepath")
            }
            Button(action: {}) {
                Label(i18n.t(.proj_kbMenuMove), systemImage: "folder")
            }
            Divider()
            Button(role: .destructive, action: { removeFile() }) {
                Label(i18n.t(.proj_kbMenuRemove), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
        }
        .menuStyle(.borderlessButton)
    }

    private func previewFile() {
        projLog.info("Preview file: \(file.fileName)")
    }

    private func removeFile() {
        Task {
            do {
                try await ipc.projectKnowledgeFileDelete(fileId: file.id)
            } catch {
                projLog.error("removeFile failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GUI-4 + GUI-7: Chats Panel

