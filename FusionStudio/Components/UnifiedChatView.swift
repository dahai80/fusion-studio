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
    @StateObject private var voiceInput = VoiceInputManager()
    @State private var isVoiceMode: Bool = false
    @State private var showVolumeSlider: Bool = false
    @State private var refocusTrigger: Int = 0
    @State private var showClearConfirm: Bool = false
    @State private var hoveredSessionId: String?
    @State private var renamingSessionId: String?
    @State private var renameText: String = ""
    @State private var pendingAttachments: [AttachmentData] = []
    @State private var isDragTarget: Bool = false
    @State private var contextInfoText: String = ""
    @State private var showContextInfo: Bool = false

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

    private var activePreset: ChatPreset? {
        guard let raw = chatStore.activeSession?.preset else { return nil }
        return ChatPreset(rawValue: raw)
    }

    private var currentPlaceholder: String {
        if let preset = activePreset {
            return preset.placeholder
        }
        return hasMessages ? "Ask anything — chat, explain, brainstorm..." : "How can I help you today?"
    }

    private var activeOutputStyle: OutputStyle? {
        guard let raw = chatStore.activeSession?.outputStyle else { return nil }
        return OutputStyle(rawValue: raw)
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
        .onChange(of: chatStore.isGenerating) { oldValue, newValue in
            if oldValue && !newValue {
                refocusTrigger += 1
            }
        }
        .onChange(of: chatStore.activeSession?.id) { _, _ in
            refocusTrigger += 1
        }
        .alert("Context", isPresented: $showContextInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contextInfoText)
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

            if !chatStore.sessions.isEmpty {
                Button {
                    showClearConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .alert("Clear All Chats", isPresented: $showClearConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear All", role: .destructive) {
                        Task { await chatStore.clearAllSessions() }
                    }
                } message: {
                    Text("Delete all \(chatStore.sessions.count) chat sessions? This cannot be undone.")
                }

                if chatStore.activeSession != nil {
                    Menu {
                        Button {
                            Task { await compactContext() }
                        } label: {
                            Label("Compact Context", systemImage: "rectangle.compress.vertical")
                        }
                        Button {
                            Task { await showContextUsage() }
                        } label: {
                            Label("Context Usage", systemImage: "gauge.with.dots.needle.bottom.50percent")
                        }
                    } label: {
                        Image(systemName: "rectangle.compress.vertical")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

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
                Button {
                    pickFiles()
                } label: {
                    Label("Add files or photos", systemImage: "paperclip")
                }
                .keyboardShortcut("u", modifiers: .command)
                Button {
                    takeScreenshot()
                } label: {
                    Label("Take a screenshot", systemImage: "camera")
                }
                Divider()
                Toggle(isOn: $chatStore.isWebSearchEnabled) {
                    Label("Web search", systemImage: "globe")
                }
                Divider()
                // Research toggle
                Toggle(isOn: Binding(
                    get: { chatStore.activeSession?.mode == ChatMode.research.rawValue },
                    set: { on in
                        if on {
                            chatStore.activeSession?.mode = ChatMode.research.rawValue
                        } else {
                            chatStore.activeSession?.mode = ChatMode.simple.rawValue
                        }
                    }
                )) {
                    Label("Research", systemImage: "magnifyingglass")
                }
                // Use style — output style picker
                Menu {
                    ForEach(OutputStyle.allCases, id: \.rawValue) { style in
                        Button {
                            chatStore.activeSession?.outputStyle = style.rawValue
                        } label: {
                            Label(style.label, systemImage: style.icon)
                        }
                    }
                    if chatStore.activeSession?.outputStyle != nil {
                        Divider()
                        Button("清除风格") {
                            chatStore.activeSession?.outputStyle = nil
                        }
                    }
                } label: {
                    Label("Use style", systemImage: "text.badge.star")
                }
                // Skills submenu
                Menu {
                    ForEach(FusionSkillManager.shared.skills) { skill in
                        Button {
                            chatStore.activeSession?.activeSkill = skill.id.uuidString
                            chatViewLog.info("Skill activated: \(skill.name)")
                        } label: {
                            Label(skill.name, systemImage: skill.icon)
                        }
                    }
                    if chatStore.activeSession?.activeSkill != nil {
                        Divider()
                        Button("清除技能") {
                            chatStore.activeSession?.activeSkill = nil
                        }
                    }
                } label: {
                    Label("Skills", systemImage: "wand.and.stars")
                }
                Divider()
                // Project picker — link session to a project
                Menu {
                    Button("无关联") {
                        chatStore.activeSession?.projectId = nil
                    }
                    Divider()
                    ForEach(FusionProjectManager.shared.projects, id: \.id) { project in
                        Button(project.name) {
                            chatStore.activeSession?.projectId = project.id.uuidString
                        }
                    }
                } label: {
                    Label("Project", systemImage: "folder")
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

            // Preset indicator — shows active ChatPreset with output style
            if let preset = activePreset {
                HStack(spacing: 4) {
                    Image(systemName: preset.icon)
                        .font(.system(size: 11))
                    Text(preset.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(theme.accent.opacity(0.12))
                .clipShape(Capsule())
                .onTapGesture {
                    chatStore.activeSession?.preset = nil
                    chatStore.activeSession?.outputStyle = nil
                }
                .help("当前模式：\(preset.label)，点击清除")

                // Output style indicator (tap to clear)
                if activeOutputStyle != nil {
                    Image(systemName: activeOutputStyle?.icon ?? "text.badge.star")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accent)
                        .onTapGesture {
                            chatStore.activeSession?.outputStyle = nil
                        }
                        .help("当前风格：\(activeOutputStyle?.label ?? "")，点击清除")
                }
            }

            // Project indicator
            if let projectId = chatStore.activeSession?.projectId,
               let project = FusionProjectManager.shared.projects.first(where: { $0.id.uuidString == projectId }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                    Text(project.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
                .onTapGesture {
                    chatStore.activeSession?.projectId = nil
                }
                .help("关联项目：\(project.name)，点击解除")
            }

            Spacer()

            // Mic button — click to toggle recording
            Button {
                toggleRecording()
                showVolumeSlider = true
                chatViewLog.info("Mic button: showVolumeSlider=true, isRecording=\(voiceInput.isRecording)")
            } label: {
                Image(systemName: voiceInput.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 16))
                    .foregroundStyle(voiceInput.isRecording ? theme.accent : theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(voiceInput.isRecording ? "Stop recording" : "Start voice input")

            // Volume slider - shown on mouseup, decoupled from recording state
            if showVolumeSlider {
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.1")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Slider(value: Binding(
                        get: { voiceInput.inputVolume },
                        set: { voiceInput.setInputVolume($0) }
                    ), in: 0...2)
                    .frame(width: 80)
                    .tint(theme.accent)
                    Image(systemName: "speaker.wave.3")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Button {
                        showVolumeSlider = false
                        chatViewLog.info("Volume slider closed")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }

            // Audio level indicator
            if voiceInput.isRecording {
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.accent)
                    .frame(width: max(2, CGFloat(voiceInput.audioLevel) * 16), height: 4)
                    .animation(.easeInOut(duration: 0.1), value: voiceInput.audioLevel)
            }

            // Live transcript indicator
            if voiceInput.isRecording && !voiceInput.liveTranscript.isEmpty {
                Text(voiceInput.liveTranscript)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)
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
                    .foregroundStyle(voiceInput.isRecording || !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.accent : theme.textQuaternary)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !voiceInput.isRecording)
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
            // Attachment bar — shows pending attachments above input
            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacingS) {
                        ForEach(pendingAttachments) { att in
                            HStack(spacing: 4) {
                                Image(systemName: att.isImage ? "photo" : "doc")
                                    .font(.system(size: 11))
                                Text(att.name)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                Button {
                                    pendingAttachments.removeAll { $0.id == att.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                            }
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.surfaceSecondary)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.top, theme.spacingS)
                }
            }
            VStack(spacing: 0) {
                SendableTextEditor(
                    text: $inputText,
                    placeholder: currentPlaceholder,
                    font: .systemFont(ofSize: CGFloat(theme.textSize)),
                    textColor: NSColor(theme.text),
                    placeholderColor: NSColor(theme.textTertiary),
                    maxHeight: 88,
                    onSend: sendCurrentMessage,
                    refocusTrigger: $refocusTrigger
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

            // Quick action cards — visible only in empty state, driven by ChatPreset
            if !hasMessages && !chatStore.isGenerating {
                HStack(spacing: theme.spacingS) {
                    ForEach(ChatPreset.allCases, id: \.rawValue) { preset in
                        quickCard(icon: preset.icon, title: preset.label) {
                            if chatStore.activeSession != nil {
                                chatStore.activeSession?.preset = preset.rawValue
                                inputText = preset.placeholder
                            }
                        }
                    }
                }
                .padding(.top, theme.spacingS)
                .frame(maxWidth: 680)
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
        .background(theme.contentBg)
        .onDrop(of: [.fileURL], isTargeted: $isDragTarget) { providers in
            handleDrop(providers: providers)
        }
        .overlay(
            Group {
                if isDragTarget {
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .stroke(theme.accent, lineWidth: 2)
                        .background(theme.accent.opacity(0.08))
                        .overlay(
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                Text("释放以添加附件")
                                    .font(.system(size: theme.captionSize, weight: .medium))
                            }
                            .foregroundStyle(theme.accent)
                        )
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingM)
                        .allowsHitTesting(false)
                }
            }
        )
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
        let isActive = session.id == chatStore.activeSession?.id
        let isHovered = hoveredSessionId == session.id
        let isRenaming = renamingSessionId == session.id
        return HStack {
            if session.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
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
                    Text(session.title.isEmpty ? "Untitled" : session.title)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                }
                Text(modeLabel(session.mode) + " · " + relativeDate(session.updatedAt))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
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
                        renameText = session.title.isEmpty ? "Untitled" : session.title
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
            } else if isActive && !isRenaming {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(isActive ? theme.accent.opacity(0.10) : (isHovered ? theme.separator.opacity(0.3) : .clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isRenaming { return }
            chatStore.selectSession(session)
            withAnimation { showSessionList = false }
        }
        .onHover { hovering in
            hoveredSessionId = hovering ? session.id : nil
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
                // Attachment thumbnails
                if !msg.attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: theme.spacingS) {
                            ForEach(msg.attachments) { att in
                                AttachmentThumbnail(attachment: att)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: msg.isUser ? .trailing : .leading)
                    }
                }
                if editingMessageId == msg.id {
                    editField(msg)
                } else {
                    if msg.isUser {
                        Text(msg.content)
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, theme.spacingS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                    .fill(theme.accent.opacity(0.12))
                            )
                    } else {
                        Text(try! AttributedString(markdown: msg.content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                            .tint(theme.accent)
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, theme.spacingS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                    .fill(theme.surfaceSecondary)
                            )
                    }
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(Date(timeIntervalSince1970: msg.createdAt), style: .time)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textQuaternary)
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
        if voiceInput.isRecording {
            let transcript = voiceInput.stopRecording()
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                inputText += (inputText.isEmpty ? "" : " ") + trimmed
            }
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }
        chatViewLog.info("sendCurrentMessage: text='\(text.prefix(50))', attachments=\(pendingAttachments.count)")

        chatStore.ensureActiveSession(mode: selectedMode.rawValue)
        inputText = ""

        let attachments = pendingAttachments
        pendingAttachments = []

        Task {
            await chatStore.sendMessage(text, mode: selectedMode.rawValue, attachments: attachments)
        }
    }

    private func takeScreenshot() {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"]
            task.launch()
            task.waitUntilExit()
            chatViewLog.info("Screenshot process exited with code \(task.terminationStatus)")
            guard task.terminationStatus == 0 else {
                chatViewLog.warning("Screenshot cancelled or failed")
                return
            }
            DispatchQueue.main.async {
                let pb = NSPasteboard.general
                let imgData = pb.data(forType: .tiff)
                    ?? pb.data(forType: .png)
                    ?? pb.data(forType: .fileURL).flatMap { data -> Data? in
                        guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters),
                              let url = URL(string: path) else { return nil }
                        let cleanPath = url.path.isEmpty ? path : url.path
                        return try? Data(contentsOf: URL(fileURLWithPath: cleanPath))
                    }
                if let imgData = imgData {
                    let b64 = imgData.base64EncodedString()
                    let att = AttachmentData(name: "screenshot.png", type: "image", mimeType: "image/png", dataBase64: b64)
                    pendingAttachments.append(att)
                    chatViewLog.info("Screenshot attached, size=\(b64.count) chars base64")
                } else {
                    if let img = NSImage(pasteboard: pb) {
                        guard let tiffData = img.tiffRepresentation else {
                            chatViewLog.warning("Screenshot: cannot get tiffRepresentation")
                            return
                        }
                        let bitmap = NSBitmapImageRep(data: tiffData)
                        let pngData = bitmap?.representation(using: .png, properties: [:])
                        if let pngData = pngData {
                            let b64 = pngData.base64EncodedString()
                            let att = AttachmentData(name: "screenshot.png", type: "image", mimeType: "image/png", dataBase64: b64)
                            pendingAttachments.append(att)
                            chatViewLog.info("Screenshot attached via NSImage, size=\(b64.count) chars base64")
                        }
                    } else {
                        let count = pb.types?.count ?? 0
                        chatViewLog.warning("Screenshot: no image on pasteboard, \(count) types found")
                    }
                }
            }
        }
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                guard let data = try? Data(contentsOf: url) else {
                    chatViewLog.warning("Cannot read file: \(url.path)")
                    continue
                }
                let ext = url.pathExtension.lowercased()
                let mime: String
                let type: String
                switch ext {
                case "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff":
                    type = "image"
                    mime = "image/\(ext == "jpg" ? "jpeg" : ext)"
                default:
                    type = "file"
                    mime = "application/octet-stream"
                }
                let b64 = data.base64EncodedString()
                let att = AttachmentData(name: url.lastPathComponent, type: type, mimeType: mime, dataBase64: b64)
                pendingAttachments.append(att)
                chatViewLog.info("File attached: \(url.lastPathComponent), type=\(type), size=\(b64.count) chars base64")
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier("public.file-url") else { continue }
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    chatViewLog.warning("Drop: cannot resolve file URL")
                    return
                }
                DispatchQueue.main.async {
                    guard let fileData = try? Data(contentsOf: url) else {
                        chatViewLog.warning("Drop: cannot read file: \(url.path)")
                        return
                    }
                    let ext = url.pathExtension.lowercased()
                    let mime: String
                    let type: String
                    switch ext {
                    case "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff":
                        type = "image"
                        mime = "image/\(ext == "jpg" ? "jpeg" : ext)"
                    default:
                        type = "file"
                        mime = "application/octet-stream"
                    }
                    let b64 = fileData.base64EncodedString()
                    let att = AttachmentData(name: url.lastPathComponent, type: type, mimeType: mime, dataBase64: b64)
                    self.pendingAttachments.append(att)
                    chatViewLog.info("Drop: attached \(url.lastPathComponent), type=\(type), size=\(b64.count) chars base64")
                }
            }
            handled = true
        }
        return handled
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
            } else if let pref = MLXModelInfo.preferredDefault(in: bridge.models) {
                chatStore.selectedModel = pref.id
            }
            chatViewLog.info("Chat default model: \(chatStore.selectedModel)")
        }
    }

    private func compactContext() async {
        guard let sessionId = chatStore.activeSession?.id else { return }
        do {
            let result = try await bridge.contextCompact(sessionId: sessionId)
            let tokens = result["tokens_saved"] as? Int ?? result["compacted"] as? Int
            chatViewLog.info("Context compacted: session=\(sessionId) result=\(result)")
            contextInfoText = tokens != nil
                ? "Context compacted. \(tokens!) tokens saved."
                : "Context compacted successfully."
            showContextInfo = true
        } catch {
            chatViewLog.warning("Context compact failed: \(error)")
            contextInfoText = "Compact failed: \(error.localizedDescription)"
            showContextInfo = true
        }
    }

    private func showContextUsage() async {
        guard let sessionId = chatStore.activeSession?.id else { return }
        do {
            let result = try await bridge.contextUsage(sessionId: sessionId)
            chatViewLog.info("Context usage: session=\(sessionId) result=\(result)")
            let used = result["tokens_used"] as? Int ?? result["used"] as? Int ?? 0
            let limit = result["token_limit"] as? Int ?? result["limit"] as? Int ?? 0
            let pct = result["percent"] as? Double ?? (limit > 0 ? Double(used) / Double(limit) * 100 : 0)
            let percent = result["percent"] as? Int
            contextInfoText = percent != nil
                ? "Context usage: \(percent!)% (\(used) / \(limit) tokens)"
                : String(format: "Context usage: %.0f%% (%d / %d tokens)", pct, used, limit)
            showContextInfo = true
        } catch {
            chatViewLog.warning("Context usage failed: \(error)")
            contextInfoText = "Usage query failed: \(error.localizedDescription)"
            showContextInfo = true
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

    private func toggleRecording() {
        if voiceInput.isRecording {
            let transcript = voiceInput.stopRecording()
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if isVoiceMode {
                inputText = trimmed
                sendCurrentMessage()
            } else {
                inputText += (inputText.isEmpty ? "" : " ") + trimmed
            }
        } else {
            voiceInput.startRecording()
        }
    }
}

private struct AttachmentThumbnail: View {
    let attachment: AttachmentData
    @Environment(\.studioTheme) private var theme
    @State private var nsImage: NSImage?

    var body: some View {
        Group {
            if let nsImage = nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius * 0.5, style: .continuous))
            } else if attachment.isImage {
                RoundedRectangle(cornerRadius: theme.cornerRadius * 0.5, style: .continuous)
                    .fill(theme.surfaceSecondary)
                    .frame(width: 120, height: 80)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundStyle(theme.textTertiary)
                    )
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.system(size: 11))
                    Text(attachment.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.surfaceSecondary)
                .clipShape(Capsule())
            }
        }
        .task(id: attachment.id) {
            guard nsImage == nil, attachment.isImage else { return }
            let b64 = attachment.dataBase64
            let name = attachment.name
            let decoded = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                guard let data = Data(base64Encoded: b64) else { return nil }
                return NSImage(data: data)
            }.value
            if let decoded = decoded {
                chatViewLog.info("AttachmentThumbnail: decoded '\(name)', size=\(decoded.size.width)x\(decoded.size.height)")
                nsImage = decoded
            } else {
                chatViewLog.warning("AttachmentThumbnail: decode failed for '\(name)'")
            }
        }
    }
}
