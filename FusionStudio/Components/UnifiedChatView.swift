// Callers: SectionContentView (case .chats), ChatsPanel detailColumn.
// Affected API: UnifiedChatView — chat UI with centered input box (model picker + effort + mic inside input), welcome cards below.
// Data schemas: ChatSessionData, ChatMessageData from ChatSessionStore, StreamChatEvent from StreamingBridge.

import SwiftUI
import os.log

private let chatViewLog = Logger(subsystem: "com.fusion.studio", category: "UnifiedChatView")

struct UnifiedChatView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var chatStore: ChatSessionStore
    @EnvironmentObject var streamingBridge: StreamingBridge
    @EnvironmentObject var bridge: AgentBridge

    @State private var inputText: String = ""
    @State private var selectedMode: ChatMode = .simple
    @State private var selectedEffort: String = "Medium"
    @State private var thinkingEnabled: Bool = false
    @State private var showSessionList: Bool = false
    @State private var editingMessageId: String?
    @State private var editContent: String = ""
    @State private var autoScroll: Bool = true
    @State private var branchPickerMsgId: String?
    @State private var branchSiblings: [ChatMessageData] = []
    @State private var isWebSearchEnabled: Bool = false
    @State private var showMicSettings: Bool = false
    @State private var micVolume: Double = 0.8
    @State private var holdToRecord: Bool = false
    @State private var isVoiceMode: Bool = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    private var hasMessages: Bool {
        guard let session = chatStore.activeSession else { return false }
        return !session.linearBranch.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            chatToolbar
            Rectangle().fill(theme.separator).frame(height: 1)

            // Single layout: content area (welcome or messages) + input always at bottom
            messageArea
            Rectangle().fill(theme.separator).frame(height: 1)
            chatInputBox
        }
        .frame(minWidth: 320, idealWidth: 400, maxWidth: .infinity)
        .task {
            await chatStore.loadSessions()
            initDefaultModel()
        }
    }

    // MARK: - Top Toolbar

    private var chatToolbar: some View {
        HStack(spacing: theme.spacingS) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSessionList.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                Task { await newChat() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.contentBg)
    }

    // MARK: - Message Area (welcome or messages, always present)

    private var messageArea: some View {
        Group {
            if hasMessages || chatStore.isGenerating {
                messageList
            } else {
                welcomeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomeContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text("\(greeting), \(NSUserName())")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.text)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inputToolbar: some View {
        HStack(spacing: theme.spacingS) {
            // + button
            Menu {
                Toggle(isOn: $isWebSearchEnabled) {
                    Label("Web search", systemImage: "globe")
                }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

            // Model picker
            modelPickerButton

            // Effort menu
            effortMenu

            Spacer()

            // Mic button
            Button {
                showMicSettings.toggle()
            } label: {
                Image(systemName: "mic")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showMicSettings, arrowEdge: .top) {
                VStack(spacing: theme.spacingM) {
                    Text("Microphone")
                        .font(.system(size: theme.captionSize, weight: .semibold))
                    HStack(spacing: theme.spacingS) {
                        Text("Volume")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 48, alignment: .leading)
                        Slider(value: $micVolume, in: 0...1)
                            .frame(width: 120)
                    }
                    HStack(spacing: theme.spacingS) {
                        Text("Hold to Record")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                        Toggle("", isOn: $holdToRecord)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .frame(width: 188)
                }
                .padding(theme.spacingM)
            }

            // Voice mode toggle
            Button {
                isVoiceMode.toggle()
                chatViewLog.info("Voice mode: \(isVoiceMode)")
            } label: {
                Image(systemName: isVoiceMode ? "waveform" : "waveform.badge.mic")
                    .font(.system(size: 16))
                    .foregroundStyle(isVoiceMode ? theme.accent : theme.textSecondary)
            }
            .buttonStyle(.plain)

            // Send button
            Button(action: sendCurrentMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.textQuaternary : theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var modelPickerButton: some View {
        FusionModelPicker(scene: .chat, selection: $chatStore.selectedModel, models: bridge.models, onChange: { id in
            chatViewLog.info("Chat model selected: \(id)")
        })
    }

    private var effortMenu: some View {
        Menu {
            ForEach(["Low", "Medium", "High", "Extra", "Max"], id: \.self) { level in
                Button { selectedEffort = level; chatViewLog.info("Effort set to: \(level)") } label: {
                    if selectedEffort == level { Label(level, systemImage: "checkmark") } else { Text(level) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("Effort").font(.system(size: theme.captionSize, weight: .medium))
                Text(selectedEffort).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                Image(systemName: "chevron.down").font(.system(size: 8))
            }
            .foregroundStyle(theme.textSecondary).padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.separator.opacity(0.5)))
        }
        .menuStyle(.borderlessButton)
    }

    private func quickCard(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accent)
                Text(title)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .stroke(theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat Input Box (always at bottom)

    private var chatInputBox: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                SendableTextEditor(
                    text: $inputText,
                    placeholder: hasMessages ? "Ask anything — chat, explain, brainstorm..." : "How can I help you today?",
                    font: .systemFont(ofSize: CGFloat(theme.textSize)),
                    textColor: NSColor(theme.text),
                    placeholderColor: NSColor(theme.textTertiary),
                    maxHeight: 88,
                    onSend: sendCurrentMessage
                )
                .frame(minHeight: 36, idealHeight: 44, maxHeight: 88)
                .padding(.horizontal, theme.spacingL)
                .padding(.top, theme.spacingM)

                Rectangle().fill(theme.separator.opacity(0.5)).frame(height: 1)

                inputToolbar
            }
            .frame(maxWidth: 680)
            .background(theme.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(theme.inputBorder, lineWidth: 1)
            )

            // Quick action cards — visible only in empty state, below input box
            if !hasMessages && !chatStore.isGenerating {
                HStack(spacing: theme.spacingS) {
                    quickCard(icon: "pencil", title: "Write") { inputText = "Help me write something" }
                    quickCard(icon: "book", title: "Learn") { inputText = "Explain a concept to me" }
                    quickCard(icon: "chevron.left.forwardslash.chevron.right", title: "Code") { inputText = "Help me write code" }
                    quickCard(icon: "heart", title: "Life") { inputText = "Give me life advice" }
                    quickCard(icon: "hand.tap", title: "Choice") { inputText = "Help me decide between options" }
                }
                .padding(.top, theme.spacingS)
                .frame(maxWidth: 680)
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
        .background(theme.contentBg)
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

                        if chatStore.isGenerating {
                            streamingIndicator
                                .id("streaming-indicator")
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
            .onReceive(chatStore.$streamingContent) { _ in
                if autoScroll && chatStore.isGenerating {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("streaming-indicator", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var streamingIndicator: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            if chatStore.isGenerating && !chatStore.streamingContent.isEmpty {
                HStack(spacing: theme.spacingS) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating...")
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.text)
                }
                Text(chatStore.streamingContent)
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
            } else {
                HStack(spacing: theme.spacingS) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Thinking...")
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.text)
                }
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingL) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(theme.textQuaternary)
            Text("Start a conversation")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    private func messageBubble(_ msg: ChatMessageData, proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            if msg.isUser { Spacer(minLength: 60) }

            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
                if editingMessageId == msg.id {
                    editField(msg)
                } else {
                    Text(msg.content)
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.text)
                        .textSelection(.enabled)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                .fill(msg.isUser ? theme.accent.opacity(0.12) : theme.surfaceSecondary)
                        )
                }

                Text(Date(timeIntervalSince1970: msg.createdAt), style: .time)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textQuaternary)

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

            if msg.isAssistant { Spacer(minLength: 60) }
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

    // MARK: - Actions

    private func sendCurrentMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        print("[ChatView] sendCurrentMessage: '\(text.prefix(50))'")

        // Synchronously ensure session exists so SwiftUI sees the state change immediately
        chatStore.ensureActiveSession(mode: selectedMode.rawValue)
        inputText = ""

        Task {
            print("[ChatView] sendMessage Task starting, activeSession=\(chatStore.activeSession?.id ?? "nil")")
            await chatStore.sendMessage(text, mode: selectedMode.rawValue)
            print("[ChatView] sendMessage Task done, msgs=\(chatStore.activeSession?.messages.count ?? -1)")
        }
    }

    private func newChat() async {
        await chatStore.createSession(mode: selectedMode.rawValue)
    }

    private func initDefaultModel() {
        if chatStore.selectedModel.isEmpty {
            let cfg = FusionConfig.shared
            let model = cfg.defaultModel(for: .chat)
            if !model.isEmpty {
                chatStore.selectedModel = model
            } else if let first = bridge.models.first?.id {
                chatStore.selectedModel = first
            }
            chatViewLog.info("Chat default model: \(chatStore.selectedModel)")
        }
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
