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
    @State private var hoveredSessionId: String?
    @State private var renamingSessionId: String?
    @State private var renameText: String = ""
    @State private var selectedProjectFilter: String? = nil
    @State private var availableProjects: [(id: String, name: String)] = []

    private var filteredSessions: [ChatSessionData] {
        var sessions = chatStore.sessions
        if let pid = selectedProjectFilter {
            sessions = sessions.filter { $0.projectId == pid }
        }
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
            loadAvailableProjects()
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
        VStack(spacing: 0) {
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

            if !availableProjects.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacingXS) {
                        filterChip(label: "All", isSelected: selectedProjectFilter == nil) {
                            selectedProjectFilter = nil
                        }
                        filterChip(label: "未关联", isSelected: selectedProjectFilter == "") {
                            selectedProjectFilter = ""
                        }
                        ForEach(availableProjects, id: \.id) { proj in
                            filterChip(label: proj.name, isSelected: selectedProjectFilter == proj.id) {
                                selectedProjectFilter = proj.id
                            }
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                }
                .padding(.vertical, theme.spacingXS)
            }
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: theme.captionSize, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? theme.accent.opacity(0.15) : theme.surfaceSecondary)
                )
        }
        .buttonStyle(.plain)
    }

    private func sessionRow(_ session: ChatSessionData) -> some View {
        let isActive = chatStore.activeSession?.id == session.id
        let isHovered = hoveredSessionId == session.id
        let isRenaming = renamingSessionId == session.id
        let preview = session.messages.last?.content ?? "No messages yet"
        return HStack(spacing: theme.spacingM) {
            if session.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                if isRenaming {
                    TextField(session.title, text: $renameText, onCommit: {
                        chatStore.renameSession(session.id, newTitle: renameText)
                        renamingSessionId = nil
                    })
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .textFieldStyle(.plain)
                    .onExitCommand { renamingSessionId = nil }
                } else {
                    Text(session.title.isEmpty ? "New Chat" : session.title)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                }
                Text(preview)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered && !isRenaming {
                Menu {
                    Button {
                        chatStore.pinSession(session.id)
                    } label: {
                        Label(session.isPinned ? "Unpin" : "Pin to Top", systemImage: session.isPinned ? "pin.slash" : "pin")
                    }
                    Button {
                        chatStore.shareSession(session.id)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        renameText = session.title.isEmpty ? "New Chat" : session.title
                        renamingSessionId = session.id
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        Task { await chatStore.deleteSession(session.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .transition(.opacity)
            } else if !isRenaming {
                Text(Date(timeIntervalSince1970: session.updatedAt), style: .time)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(isActive ? theme.accent.opacity(0.10) : (isHovered ? theme.separator.opacity(0.3) : .clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isRenaming { return }
            chatStore.selectSession(session)
            chatsLog.info("Selected chat session: \(session.id)")
        }
        .onHover { hovering in
            hoveredSessionId = hovering ? session.id : nil
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

    private func loadAvailableProjects() {
        let projects = FusionProjectManager.shared.projects
        var seen = Set<String>()
        var result: [(id: String, name: String)] = []
        for proj in projects {
            let idStr = proj.id.uuidString
            if !seen.contains(idStr) {
                seen.insert(idStr)
                result.append((id: idStr, name: proj.name))
            }
        }
        for session in chatStore.sessions {
            if let pid = session.projectId, !pid.isEmpty, !seen.contains(pid) {
                seen.insert(pid)
                result.append((id: pid, name: pid.prefix(8) + "…"))
            }
        }
        availableProjects = result
        chatsLog.info("Loaded \(result.count) projects for filter")
    }
}
