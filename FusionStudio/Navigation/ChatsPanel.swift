// Callers: SectionContentView (case .chats).
// Affected API: ChatsPanel (real chat session list + conversation detail via ChatSessionStore + UnifiedChatView).
// Data schemas: ChatSessionData (id/title/mode/messages/updatedAt) from ChatSessionStore; ChatSessionStore.loadSessions/createSession/selectSession/deleteSession.
// User instruction: "点击最左侧菜单Chats，右侧显示的对话记录不是最新的全部数据，前面对话，建项目的部分没展示" + "点击最左侧菜单Chats，右侧右上角的New Chat点击没有任何反应"

import SwiftUI
import os.log

private let chatsLog = Logger(subsystem: "com.fusion.studio", category: "ChatsPanel")

struct ChatsPanel: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var chatStore: ChatSessionStore
    @State private var searchText = ""

    private var filteredSessions: [ChatSessionData] {
        let sessions = chatStore.sessions
        guard !searchText.isEmpty else { return sessions }
        return sessions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.messages.last?.content ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sessionListColumn
                .frame(width: 300)
            Rectangle().fill(theme.separator).frame(width: 1)
            detailColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await chatStore.loadSessions()
        }
    }

    private var sessionListColumn: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            searchBar
            Rectangle().fill(theme.separator).frame(height: 1)

            if chatStore.isLoading && chatStore.sessions.isEmpty {
                loadingState
            } else if filteredSessions.isEmpty {
                emptyListState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredSessions, id: \.id) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
        }
        .background(theme.surfacePrimary)
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Text("Chats")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: { Task { await startNewChat() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconXS))
                    Text("New Chat")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                }
                .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .help("Start a new chat")
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    private var searchBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
            TextField("Search chats", text: $searchText)
                .font(.system(size: theme.footnoteSize))
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    private func sessionRow(_ session: ChatSessionData) -> some View {
        let isActive = chatStore.activeSession?.id == session.id
        let preview = session.messages.last?.content ?? "No messages yet"
        return Button(action: {
            chatStore.selectSession(session)
            chatsLog.info("Selected chat session: \(session.id)")
        }) {
            HStack(spacing: theme.spacingM) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title.isEmpty ? "New Chat" : session.title)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(preview)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(Date(timeIntervalSince1970: session.updatedAt), style: .time)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.10) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await chatStore.deleteSession(session.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var detailColumn: some View {
        Group {
            if chatStore.activeSession != nil {
                UnifiedChatView()
            } else {
                emptyDetailState
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: theme.spacingS) {
            ProgressView()
            Text("Loading chats...")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyListState: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundStyle(theme.textQuaternary)
            Text(searchText.isEmpty ? "No chats yet" : "No matching chats")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyDetailState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "bubble.left")
                .font(.system(size: 40))
                .foregroundStyle(theme.textQuaternary)
            Text("Select a chat or start a new one")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startNewChat() async {
        await chatStore.createSession(mode: "simple")
        chatsLog.info("New chat created from ChatsPanel")
    }
}
