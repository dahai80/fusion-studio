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
    @EnvironmentObject var ipc: IPCClient
    @StateObject private var i18n = I18nManager.shared

    @State private var inputText: String = ""
    @State private var selectedMode: ChatMode = .simple
    @State private var sessionTemplates: [[String: Any]] = []
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
    @State private var selectedArtifactRefId: String? = nil
    @State private var showArtifactCanvas: Bool = false
    // #217: 首页 Chat↔Cowork 模式切换 + 授权文件夹 + 工作流实时进度.
    @State private var homeMode: CoworkHomeMode = .chat
    @StateObject private var coworkHome = CoworkHomeBridge(ipc: IPCClient())

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
            loadSessionTemplates()
            // #217: 注入真实 ipc (StateObject init 用空桩), 回填授权文件夹.
            coworkHome.ipc = ipc
            await coworkHome.loadScopedFolder()
        }
        .onChange(of: chatStore.isGenerating) { oldValue, newValue in
            if oldValue && !newValue {
                refocusTrigger += 1
            }
        }
        .onChange(of: chatStore.activeSession?.id) { _, _ in
            refocusTrigger += 1
        }
        // #217: 切到 Cowork 模式 — 确保授权文件夹 (空则弹 NSOpenPanel).
        .onChange(of: homeMode) { _, newMode in
            guard newMode == .cowork else { return }
            Task {
                let ready = await coworkHome.ensureScopedFolder()
                if ready { chatStore.ensureActiveSession(mode: "cowork") }
                chatViewLog.info("cowork mode: scopedReady=\(ready)")
            }
        }
        // #217: desk.events.* 事件 -> 对话气泡 (注入当前 cowork 会话).
        .onChange(of: coworkHome.lastEvent) { _, ev in
            guard let ev = ev else { return }
            appendCoworkBubble(ev)
        }
        // #217: 离开视图停止事件轮询.
        .onDisappear { coworkHome.stopPolling() }
        .alert("Context", isPresented: $showContextInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contextInfoText)
        }
        .environment(\.openURL, OpenURLAction { url in
            openArtifactRef(url)
            return .handled
        })
        .sheet(isPresented: $showArtifactCanvas) {
            if let aid = selectedArtifactRefId {
                ArtifactCanvasView(artifactId: aid)
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
    }

    // MARK: - Top Toolbar

    private var chatToolbar: some View {
        HStack(spacing: theme.spacingS) {
            // #217: 首页 Chat ↔ Cowork 模式切换.
            coworkModePicker
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

// #50 Adding session template dropdown to new chat button
// Affected API: IPCClient.templateList(), ChatSessionStore.createSession
// Data schemas: GET /api/templates {templates: [{id, name, description, category}]}
// User instruction: #50 新建会话模板选择下拉框
            Menu {
                Button("空白会话") {
                    Task { await newChat() }
                }
                Divider()
                ForEach(Array(sessionTemplates.enumerated()), id: \.offset) { idx, tpl in
                    let name = tpl["name"] as? String ?? "Template"
                    Button(name) {
                        Task { await newChatFromTemplate(tpl) }
                    }
                }
                if sessionTemplates.isEmpty {
                    Text(i18n.t(.loadingTemplates)).font(.caption)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.accent)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.contentBg)
    }

    // #217: Chat ↔ Cowork 首页模式切换器 (segmented).
    private var coworkModePicker: some View {
        HStack(spacing: 2) {
            ForEach(CoworkHomeMode.allCases, id: \.self) { mode in
                let active = homeMode == mode
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        homeMode = mode
                    }
                } label: {
                    Text(mode == .chat ? i18n.t(.cw_home_mode_chat) : i18n.t(.cw_home_mode_cowork))
                        .font(.system(size: theme.footnoteSize, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? theme.accent : theme.textSecondary)
                        .padding(.horizontal, theme.spacingS)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(active ? theme.accent.opacity(0.15) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .help(i18n.t(.cw_home_mode_cowork))
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
                            chatStore.activeSession?.projectId = project.id
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
                .help(String(format: i18n.t(.currentModeClear), preset.label))

                // Output style indicator (tap to clear)
                if activeOutputStyle != nil {
                    Image(systemName: activeOutputStyle?.icon ?? "text.badge.star")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accent)
                        .onTapGesture {
                            chatStore.activeSession?.outputStyle = nil
                        }
                        .help(String(format: i18n.t(.currentStyleClear), activeOutputStyle?.label ?? ""))
                }
            }

            // Project indicator
            if let projectId = chatStore.activeSession?.projectId,
               let project = FusionProjectManager.shared.projects.first(where: { $0.id == projectId }) {
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
                .help(String(format: i18n.t(.linkedProjectClear), project.name))
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
        FusionModelPicker(scene: .chat, selection: $chatStore.selectedModel, models: bridge.mlxState.models, onChange: { id in
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
                                Text(i18n.t(.releaseToAddAttachment))
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
                        Text(try! AttributedString(markdown: renderArtifactRefs(msg.content), options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
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

        // #217: Cowork 模式走工作流提交 (desk.workflow.create/run + desk.events 进度气泡);
        // 否则走原有聊天流.
        if homeMode == .cowork {
            chatStore.ensureActiveSession(mode: "cowork")
            Task {
                let ok = await coworkHome.submitWorkflow(prompt: text)
                if ok {
                    // 成功: 用户消息即时显示, desk.events 轮询驱动 assistant 进度气泡.
                    chatStore.appendMessage(ChatMessageData(role: "user", content: text))
                } else {
                    // 工作流服务不可用 (如本地单机 fusion-cowork 路由 gateway 11432 失败).
                    // 回退直连推理 (经 #380 override → mlx 127.0.0.1:11434), 让 cowork tab 仍能对话.
                    let failReason = coworkHome.lastError ?? i18n.t(.cw_home_submit_fail)
                    chatViewLog.warning("cowork submitWorkflow failed (\(failReason, privacy: .public)), fallback to direct inferStream")
                    await chatStore.sendMessage(text, mode: "cowork", attachments: attachments)
                }
            }
            return
        }

        Task {
            await chatStore.sendMessage(text, mode: selectedMode.rawValue, attachments: attachments)
        }
    }

    // #217: desk.events.* 事件映射为 assistant 对话气泡 (内联进当前 cowork 会话).
    private func appendCoworkBubble(_ ev: CoworkHomeEvent) {
        chatStore.appendMessage(ChatMessageData(role: "assistant", content: ev.text, mode: "cowork"))
        chatViewLog.info("cowork bubble: kind=\(ev.kind.rawValue) text='\(ev.text.prefix(40))'")
    }

    // HIGH-4: 旧实现 DispatchQueue.global(.userInitiated) + waitUntilExit 阻塞协作线程池,
    // 重复调用可耗尽; Process 出作用域被 ARC 回回收 -> 交互截图变孤儿。
    // 改用 ScreenCapture 单例 (保活 + try run + terminationHandler) async 不阻塞协作线程池。
    private func takeScreenshot() {
        Task {
            let code = await ScreenCapture.shared.captureInteractive()
            chatViewLog.info("Screenshot process exited with code \(code)")
            guard code == 0 else {
                chatViewLog.warning("Screenshot cancelled or failed code=\(code)")
                return
            }
            await MainActor.run {
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

    private func newChatFromTemplate(_ tpl: [String: Any]) async {
        let tplId = tpl["id"] as? String ?? ""
        await chatStore.createSession(mode: selectedMode.rawValue)
        chatViewLog.info("Created session from template: \(tplId)")
    }

    private func initDefaultModel() {
        if chatStore.selectedModel.isEmpty {
            let cfg = FusionConfig.shared
            let model = cfg.defaultModel(for: .chat)
            if !model.isEmpty {
                chatStore.selectedModel = model
            } else if let pref = MLXModelInfo.preferredDefault(in: bridge.mlxState.models) {
                chatStore.selectedModel = pref.id
            }
            chatViewLog.info("Chat default model: \(chatStore.selectedModel)")
        }
    }

    private func loadSessionTemplates() {
        Task {
            do {
                let result = try await ipc.templateList(category: "session")
                await MainActor.run {
                    sessionTemplates = result["templates"] as? [[String: Any]] ?? []
                    chatViewLog.info("Session templates loaded: \(self.sessionTemplates.count)")
                }
            } catch {
                chatViewLog.error("Template load failed: \(error.localizedDescription)")
            }
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

    // MARK: - Artifact-Ref Rendering (Issue #88)

    private static let artifactRefPattern = try! NSRegularExpression(
        pattern: #"\[Artifact:\s*([^|]+?)\s*\|\s*ID:\s*(art_\w+)\s*\|\s*Type:\s*(\w+)(?:\s*\|.*)?\]"#,
        options: []
    )

    private func renderArtifactRefs(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let matches = Self.artifactRefPattern.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else { return text }
        var result = text
        for match in matches.reversed() {
            guard match.numberOfRanges >= 4,
                  let nameRange = Range(match.range(at: 1), in: text),
                  let idRange = Range(match.range(at: 2), in: text),
                  let typeRange = Range(match.range(at: 3), in: text) else { continue }
            let name = String(text[nameRange]).trimmingCharacters(in: .whitespaces)
            let id = String(text[idRange])
            let type = String(text[typeRange])
            guard let fullRange = Range(match.range, in: text) else { continue }
            let icon = iconForArtifactType(type)
            let replacement = "[\(icon) \(name)](fusion://artifact/\(id))"
            result.replaceSubrange(fullRange, with: replacement)
        }
        return result
    }

    private func iconForArtifactType(_ type: String) -> String {
        switch type.lowercased() {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "doc", "document", "markdown": return "doc.text"
        case "html", "react", "app": return "globe"
        case "svg": return "paintbrush"
        case "visualization", "chart": return "chart.bar"
        case "data": return "tablecells"
        case "mermaid": return "flowchart"
        default: return "cube.box"
        }
    }

    private func openArtifactRef(_ url: URL) {
        guard url.scheme == "fusion",
              url.host == "artifact",
              let id = url.pathComponents.last, id.hasPrefix("art_") else { return }
        chatViewLog.info("Artifact-ref tapped: \(id)")
        selectedArtifactRefId = id
        showArtifactCanvas = true
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
