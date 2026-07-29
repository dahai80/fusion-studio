// Callers: AgentStudioView, ContentView — unified chat interface replacing fragmented chat panels
// Affected API: UnifiedChatView streamingIndicator (enhanced with phase-aware progress + token preview)
// Data schemas: ChatSessionData, ChatMessageData from ChatSessionStore, StreamChatEvent from StreamingBridge
// User instruction: "按照P1~P6顺序实施所有未完成的任务" — Task #36 P6-2 AI 推理异步+进度提示

import SwiftUI
import os.log

private let chatViewLog = Logger(subsystem: "com.fusion.studio", category: "UnifiedChatView")

struct UnifiedChatView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var chatStore: ChatSessionStore
    @EnvironmentObject var streamingBridge: StreamingBridge

    @State private var inputText: String = ""
    @State private var selectedMode: ChatMode = .simple
    @State private var showSessionList: Bool = false
    // Callers: AgentStudioView, ContentView. Affected API: chat.switch_branch/branches. Data schemas: ChatMessageData siblings from chat.branches. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
    @State private var editingMessageId: String?
    @State private var editContent: String = ""
    @State private var autoScroll: Bool = true
    @State private var branchPickerMsgId: String?
    @State private var branchSiblings: [ChatMessageData] = []

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Rectangle().fill(theme.separator).frame(height: 1)

            if showSessionList {
                sessionListView
                Rectangle().fill(theme.separator).frame(height: 1)
            }

            messageList
            Rectangle().fill(theme.separator).frame(height: 1)
            inputArea
        }
        .frame(minWidth: 320, idealWidth: 400, maxWidth: .infinity)
        .task {
            await chatStore.loadSessions()
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: theme.spacingM) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSessionList.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(chatStore.activeSession?.title ?? "New Chat")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                if let session = chatStore.activeSession {
                    Text(modeLabel(session.mode))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            modePicker

            Button {
                Task { await newChat() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.toolbarBg)
    }

    private var modePicker: some View {
        Menu {
            ForEach(ChatMode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Label(mode.label, systemImage: mode.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedMode.icon)
                    .font(.system(size: 12))
                Text(selectedMode.label)
                    .font(.system(size: theme.captionSize, weight: .medium))
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Session List

    private var sessionListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(chatStore.sessions) { session in
                    sessionRow(session)
                }
            }
        }
        .frame(maxHeight: 200)
        .background(theme.sidebarBg)
    }

    private func sessionRow(_ session: ChatSessionData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title.isEmpty ? "Untitled" : session.title)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(modeLabel(session.mode) + " · " + relativeDate(session.updatedAt))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if session.id == chatStore.activeSession?.id {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .contentShape(Rectangle())
        .onTapGesture {
            chatStore.selectSession(session)
            withAnimation { showSessionList = false }
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                Task { await chatStore.deleteSession(session.id) }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacingM) {
                    if let session = chatStore.activeSession {
                        ForEach(session.linearBranch) { msg in
                            messageBubble(msg, proxy: proxy)
                                .id(msg.id)
                        }

                        if streamingBridge.isStreaming {
                            streamingIndicator
                        }
                    } else {
                        emptyState
                    }
                }
                .padding(theme.spacingL)
            }
            .background(theme.contentBg)
            .onChange(of: chatStore.activeSession?.messages.count) {
                if autoScroll, let lastMsg = chatStore.activeSession?.linearBranch.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMsg.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var streamingIndicator: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingS) {
                streamingPhaseIcon
                Text(streamingPhaseLabel)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.text)
                if !streamingBridge.streamEvents.filter({ $0.isToken }).isEmpty {
                    let tokenCount = streamingBridge.streamEvents.filter({ $0.isToken }).count
                    Text("\(tokenCount) tokens")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            let tokenEvents = streamingBridge.streamEvents.filter { $0.isToken }
            if !tokenEvents.isEmpty {
                let recentTokens = tokenEvents.suffix(20).map { $0.content }.joined()
                Text(recentTokens)
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    private var streamingPhaseLabel: String {
        let events = streamingBridge.streamEvents
        if events.contains(where: { $0.isThinking }) { return "Thinking..." }
        if events.contains(where: { $0.isToolCall }) { return "Using tools..." }
        if events.contains(where: { $0.isToken }) { return "Generating..." }
        return "Thinking..."
    }

    private var streamingPhaseIcon: some View {
        let events = streamingBridge.streamEvents
        if events.contains(where: { $0.isThinking }) {
            return AnyView(
                Image(systemName: "brain")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.accent)
                    .symbolEffect(.pulse, options: .repeating)
            )
        }
        if events.contains(where: { $0.isToolCall }) {
            return AnyView(
                Image(systemName: "wrench")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.accent)
            )
        }
        if events.contains(where: { $0.isToken }) {
            return AnyView(
                Image(systemName: "text.cursor")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.accent)
                    .symbolEffect(.pulse, options: .repeating)
            )
        }
        return AnyView(
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 12, height: 12)
        )
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingL) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(theme.textQuaternary)
            Text("Start a conversation")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textTertiary)
            Text("Choose a mode and type your message below")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textQuaternary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    private func messageBubble(_ msg: ChatMessageData, proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            if msg.isAssistant { Spacer(minLength: 40) }

            VStack(alignment: msg.isUser ? .leading : .trailing, spacing: 4) {
                if editingMessageId == msg.id {
                    editField(msg)
                } else {
                    Text(msg.content)
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(msg.isUser ? theme.text : theme.text)
                        .textSelection(.enabled)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, theme.spacingS)
                        .background(msg.isUser ? theme.accentSoft : theme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }

                if !msg.toolCalls.isEmpty {
                    toolCallIndicators(msg.toolCalls)
                }

                if msg.isUser {
                    HStack(spacing: 8) {
                        Button {
                            editingMessageId = msg.id
                            editContent = msg.content
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)

                        if msg.childrenIds.count > 1 {
                            Menu {
                                ForEach(msg.childrenIds, id: \.self) { childId in
                                    let isActive = chatStore.activeSession?.activeBranch == childId
                                    Button {
                                        Task { await chatStore.switchBranch(to: childId) }
                                    } label: {
                                        HStack {
                                            Text(childId.prefix(8))
                                            if isActive { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.branch")
                                    Text("\(msg.childrenIds.count)")
                                }
                                .font(.system(size: 10))
                                .foregroundStyle(theme.accent)
                            }
                            .menuStyle(.borderlessButton)
                        }

                        Button {
                            Task { await chatStore.branch(at: msg.id) }
                        } label: {
                            Image(systemName: "arrow.branch")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if msg.isUser { Spacer(minLength: 40) }
        }
    }

    private func editField(_ msg: ChatMessageData) -> some View {
        VStack(spacing: theme.spacingS) {
            TextEditor(text: $editContent)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .padding(theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                        .stroke(theme.accent, lineWidth: 1)
                )
                .frame(minHeight: 40)

            HStack {
                Button("Cancel") {
                    editingMessageId = nil
                    editContent = ""
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textTertiary)

                Spacer()

                Button("Save & Resend") {
                    Task {
                        await chatStore.editMessage(msg.id, newContent: editContent)
                        editingMessageId = nil
                        editContent = ""
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
            .font(.system(size: theme.captionSize))
        }
        .padding(theme.spacingS)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    private func toolCallIndicators(_ calls: [[String: Any]]) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            ForEach(Array(calls.enumerated()), id: \.offset) { _, call in
                HStack(spacing: 4) {
                    Image(systemName: "wrench")
                        .font(.system(size: 10))
                    Text(call["name"] as? String ?? "tool")
                        .font(.system(size: theme.captionSize, weight: .medium))
                }
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: theme.spacingS) {
            TextField("Message...", text: $inputText, axis: .vertical)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .lineLimit(1...5)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                        .stroke(theme.inputBorder, lineWidth: 1)
                )
                .onSubmit {
                    sendCurrentMessage()
                }

            Button {
                sendCurrentMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.textQuaternary : theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
        .background(theme.toolbarBg)
    }

    // MARK: - Actions

    private func sendCurrentMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if chatStore.activeSession == nil {
            Task {
                await chatStore.createSession(mode: selectedMode.rawValue)
                await chatStore.sendMessage(text, mode: selectedMode.rawValue)
            }
        } else {
            Task {
                await chatStore.sendMessage(text, mode: selectedMode.rawValue)
            }
        }
        inputText = ""
    }

    private func newChat() async {
        await chatStore.createSession(mode: selectedMode.rawValue)
    }

    // MARK: - Helpers

    private func modeLabel(_ mode: String) -> String {
        ChatMode(rawValue: mode)?.label ?? mode.capitalized
    }

    private func relativeDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
