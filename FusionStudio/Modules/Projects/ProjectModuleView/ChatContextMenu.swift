import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ChatContextMenu: View {
    let chat: ProjectChat
    let projectId: String
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var showDeleteConfirm = false

    var body: some View {
        Menu {
            Button(action: { toggleStar() }) {
                Label(chat.isStarred ? i18n.t(.proj_chatMenuUnstar) : i18n.t(.proj_chatMenuStar),
                      systemImage: chat.isStarred ? "star.slash" : "star")
            }
            Button(action: {}) {
                Label(i18n.t(.proj_chatMenuRename), systemImage: "pencil")
            }
            Divider()
            // GUI-7: Fork & Snapshot (Fusion unique)
            Button(action: { forkChat() }) {
                Label(i18n.t(.proj_chatMenuFork), systemImage: "arrow.triangle.branch")
            }
            Button(action: { createSnapshot() }) {
                Label(i18n.t(.proj_chatMenuSnapshot), systemImage: "camera")
            }
            Divider()
            Button(action: {}) {
                Label(i18n.t(.proj_chatMenuMove), systemImage: "arrow.right.doc")
            }
            Button(action: {}) {
                Label(i18n.t(.proj_chatMenuRemove), systemImage: "doc.text.magnifyingglass")
            }
            Divider()
            Button(role: .destructive, action: { showDeleteConfirm = true }) {
                Label(i18n.t(.proj_chatMenuDelete), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 8))
                .foregroundStyle(theme.textTertiary)
        }
        .menuStyle(.borderlessButton)
        .alert(i18n.t(.proj_chatDeleteAlertTitle), isPresented: $showDeleteConfirm) {
            Button(i18n.t(.cancel), role: .cancel) {}
            Button(i18n.t(.delete), role: .destructive) { deleteChat() }
        }
    }

    private func toggleStar() {
        Task {
            _ = try await ipc.projectChatStar(chatId: chat.id, starred: !chat.isStarred)
        }
    }

    private func forkChat() {
        Task {
            _ = try await ipc.projectChatFork(chatId: chat.id, label: nil)
            projLog.info("Chat forked: \(chat.id)")
        }
    }

    private func createSnapshot() {
        Task {
            _ = try await ipc.projectChatSnapshotCreate(chatId: chat.id, label: nil)
            projLog.info("Snapshot created for chat: \(chat.id)")
        }
    }

    private func deleteChat() {
        Task {
            try await ipc.projectChatDelete(chatId: chat.id)
        }
    }
}

// MARK: - FS-2: Agent Config Sheet

