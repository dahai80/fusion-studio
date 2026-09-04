import SwiftUI
import AppKit
import os.log

private let fcLog = Logger(subsystem: "com.fusion.studio", category: "FusionCodeView")

// MARK: - Main View

// F-R2: 流式 token throttle 聚合缓冲 (文件级, onToken 跑在 URLSession 后台线程, 跨 View 实例共享)。
nonisolated(unsafe) private var fcStreamBuffer: String = ""
nonisolated(unsafe) private var fcLastStreamFlush: DispatchTime = .now()

struct FusionCodeView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: AgentBridge
    @StateObject private var fcBridge = FusionCodeBridge.shared
    @StateObject private var workspace = ProjectWorkspace.shared
    @StateObject private var voiceInput = VoiceInputManager()
    @StateObject private var i18n = I18nManager.shared

    @State private var inputText = ""
    @State private var messages: [FCChatMessage] = []
    @State private var lastProcessedEventIdx = 0
    @State private var executionMode: FCExecutionMode = .askPermissions
    @State private var selectedModel = ""
    @State private var showFileTree = true
    @State private var showRightPanel = true
    @State private var rightPaneTab: FCRightPane = .editor
    @State private var editorContent = ""
    @State private var editorLanguage = "plaintext"
    @State private var diffOriginal = ""
    @State private var diffModified = ""
    @State private var diffLanguage = "plaintext"
    @State private var showSlashMenu = false
    @State private var slashFilter = ""
    @State private var showOpenProject = false
    @State private var pendingPermissions: [FCPermissionRequest] = []
    @State private var currentSessionId: String?
    @State private var kbStatusText = ""
    @State private var isWebSearchEnabled = false
    @State private var detectedGitURL: String?
    @State private var showSessionPicker = false
    @State private var showContextPanel = false
    @State private var showTemplatePicker = false
    @State private var showMemoryPanel = false
    @State private var refocusTrigger = 0
    @State private var isMLXFallback = false
    @State private var layoutMode: FCLayoutMode = .fourColumn
    @State private var showSessionSidebar = true
    @State private var previewHtmlContent = ""

    enum FCRightPane: String, CaseIterable {
        case editor = "Editor"
        case diff = "Diff"
        case preview = "Preview"
        case terminal = "Terminal"
        case snapshot = "Snapshot"
        case workflow = "Workflow"
        case sandbox = "Sandbox"

        var localLabel: String {
            switch self {
            case .editor: return I18nManager.shared.t(.fc_pane_editor)
            case .diff: return I18nManager.shared.t(.fc_pane_diff)
            case .preview: return I18nManager.shared.t(.fc_pane_preview)
            case .terminal: return I18nManager.shared.t(.fc_pane_terminal)
            case .snapshot: return I18nManager.shared.t(.fc_pane_snapshot)
            case .workflow: return I18nManager.shared.t(.fc_pane_workflow)
            case .sandbox: return I18nManager.shared.t(.fc_pane_sandbox)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if showSessionSidebar && layoutMode == .fourColumn {
                    FCSessionSidebar(
                        bridge: fcBridge,
                        selectedSessionId: $currentSessionId,
                        layoutMode: $layoutMode
                    )
                    Divider()
                }

                if showFileTree && layoutMode != .chatOnly {
                    fcFileTreePanel
                        .frame(width: 240)
                        .background(theme.sidebarBg)
                    Divider()
                }

                // 右侧两列（chat + 右侧面板）组合，输入框贯穿其底部
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        fcChatPanel
                            .frame(maxWidth: .infinity)

                        if showRightPanel && layoutMode != .chatOnly && layoutMode != .twoColumn {
                            Divider()
                            fcRightPanel
                                .frame(width: 480)
                                .background(theme.contentBg)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // 对话输入框贯穿右侧两列底部
                    if layoutMode != .chatOnly {
                        Divider()
                        fcInputBar
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showOpenProject) {
            OpenProjectSheet(workspace: workspace)
        }
        .onAppear {
            loadInitialState()
        }
        .onChange(of: fcBridge.chatEvents.count) { _, _ in
            processIncomingEvents()
        }
        .onChange(of: fcBridge.isStreaming) { _, streaming in
            if !streaming, let lastIdx = messages.indices.last {
                messages[lastIdx].isStreaming = false
            }
        }
        .onChange(of: workspace.selectedFile) { _, newFile in
            if let f = newFile {
                editorContent = f.content
                editorLanguage = f.language
            }
        }
    }

    private func loadInitialState() {
        if selectedModel.isEmpty {
            let cfg = FusionConfig.shared.defaultModel(for: .code)
            if !cfg.isEmpty {
                selectedModel = cfg
            }
        }
        fcBridge.checkConnection()
        fcBridge.refreshModels()
        if workspace.hasProject {
            fcBridge.refreshSessions()
            loadKBStatus()
        }
        fcLog.info("FusionCodeView initialized, connected=\(fcBridge.isConnected)")
    }

    private func loadKBStatus() {
        Task {
            guard let cwd = workspace.projectRoot?.path else { return }
            do {
                let status = try await fcBridge.kbStatus(cwd: cwd)
                let built = status["built"] as? Bool ?? false
                let chunks = status["total_chunks"] as? Int ?? 0
                await MainActor.run {
                    kbStatusText = built ? "KB: \(chunks) chunks" : "KB: not built"
                }
            } catch {
                await MainActor.run { kbStatusText = "KB: unavailable" }
            }
        }
    }

    // MARK: - File Tree Panel

    private var fcFileTreePanel: some View {
        VStack(spacing: 0) {
            fcFileTreeHeader
            Divider()

            HStack(spacing: 0) {
                Button(action: { withAnimation { showFileTree = false } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, theme.spacingS)

                Spacer()

                if workspace.hasProject {
                    Button(action: { showContextPanel = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showContextPanel, arrowEdge: .trailing) {
                        fcContextPanel
                    }
                }

                Button(action: { workspace.openLocalFolder() }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, theme.spacingS)
            }
            .padding(.vertical, theme.spacingXS)
            .background(theme.toolbarBg)
            Divider()

            if workspace.hasProject {
                FileTreeView()
            } else {
                noProjectView
            }

            Divider()

            fcFileTreeFooter
        }
    }

    private var fcFileTreeHeader: some View {
        HStack(spacing: theme.spacingS) {
            if workspace.hasProject {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workspace.projectName)
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    if !workspace.gitBranch.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9))
                            Text(workspace.gitBranch)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(theme.textTertiary)
                    }
                }
            } else {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.accent)
                Text("Fusion Code")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.toolbarBg)
    }

    private var fcFileTreeFooter: some View {
        HStack(spacing: theme.spacingS) {
            if !kbStatusText.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(kbStatusText.contains("not") ? theme.amberDot : theme.greenDot)
                        .frame(width: 6, height: 6)
                    Text(kbStatusText)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            if workspace.hasProject {
                Button(action: { buildKB() }) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                Button(action: { showMemoryPanel = true }) {
                    Image(systemName: "brain")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showMemoryPanel, arrowEdge: .top) {
                    FCMemoryPanel()
                }
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.toolbarBg)
    }

    private var noProjectView: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.fc_no_project_title))
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Button(i18n.t(.fc_open_folder)) {
                workspace.openLocalFolder()
            }
            .buttonStyle(.plain)
            .font(.system(size: theme.footnoteSize, weight: .medium))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingXS + 2)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.accent.opacity(0.1))
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chat Panel

    private var fcChatPanel: some View {
        VStack(spacing: 0) {
            fcChatToolbar
            Divider()

            if !fcBridge.isConnected {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.amberDot)
                    Text(i18n.t(.fc_offline_mlx))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.accent.opacity(0.05))
            }

            if messages.isEmpty {
                fcWelcomeView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: theme.spacingM) {
                            ForEach(messages) { msg in
                                FCMessageBubble(message: msg, onApplyCode: applyCodeFromMessage, onApprove: approvePermission, onDeny: denyPermission)
                                    .id(msg.id)
                            }
                            if fcBridge.isStreaming {
                                HStack(spacing: theme.spacingS) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(i18n.t(.fc_thinking))
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.textTertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, theme.spacing2XL)
                            }
                        }
                        .padding(.horizontal, theme.spacing2XL)
                        .padding(.vertical, theme.spacingL)
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation(theme.springDefault) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }

    private var fcChatToolbar: some View {
        HStack(spacing: theme.spacingS) {
            if !showSessionSidebar {
                Button(action: { withAnimation { showSessionSidebar = true } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if !showFileTree {
                Button(action: { withAnimation { showFileTree = true } }) {
                    Image(systemName: "folder.sidebar")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if let sid = currentSessionId {
                Button(action: { showSessionPicker = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .font(.system(size: 10))
                        Text(sid.prefix(8))
                            .font(.system(size: 10, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.separator.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSessionPicker, arrowEdge: .bottom) {
                    fcSessionPicker
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(fcBridge.isConnected ? theme.greenDot : theme.redDot)
                    .frame(width: 6, height: 6)
                Text(fcBridge.isConnected ? i18n.t(.fc_connected) : i18n.t(.fc_offline))
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }

            FusionModelPicker(scene: .code, selection: $selectedModel, models: bridge.mlxState.models, onChange: { id in
                fcLog.info("Model switched: \(id)")
            })

            if workspace.hasProject {
                Button(action: { inputText = "/kb " }) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: { withAnimation { showRightPanel.toggle() } }) {
                Image(systemName: showRightPanel ? "rectangle.split.1x2" : "rectangle.split.2x1")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(FCLayoutMode.allCases, id: \.self) { mode in
                    Button(action: { withAnimation { layoutMode = mode } }) {
                        Label(mode.localLabel, systemImage: mode.icon)
                    }
                }
                Divider()
                Button(action: { withAnimation { showSessionSidebar.toggle() } }) {
                    Label(showSessionSidebar ? i18n.t(.fc_hide_session_bar) : i18n.t(.fc_show_session_bar), systemImage: "sidebar.left")
                }
            } label: {
                Image(systemName: layoutMode.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.toolbarBg)
    }

    private var fcWelcomeView: some View {
        VStack(spacing: theme.spacingL) {
            Spacer(minLength: 0)

            Text(greeting)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.text)

            Text(i18n.t(.fc_welcome_subtitle))
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: theme.spacingS) {
                FCWelcomeCard(icon: "folder.badge.plus", title: i18n.t(.fc_card_open_title), subtitle: i18n.t(.fc_card_open_sub)) {
                    showOpenProject = true
                }
                FCWelcomeCard(icon: "chevron.left.forwardslash.chevron.right", title: i18n.t(.fc_card_code_title), subtitle: i18n.t(.fc_card_code_sub)) {
                    inputText = i18n.t(.fc_prompt_write)
                }
                FCWelcomeCard(icon: "ladybug", title: i18n.t(.fc_card_debug_title), subtitle: i18n.t(.fc_card_debug_sub)) {
                    inputText = i18n.t(.fc_prompt_debug)
                }
                FCWelcomeCard(icon: "books.vertical", title: i18n.t(.fc_card_kb_title), subtitle: i18n.t(.fc_card_kb_sub)) {
                    inputText = "/kb "
                }
            }

            HStack(spacing: theme.spacingS) {
                FCWelcomeCard(icon: "brain", title: i18n.t(.fc_card_memory_title), subtitle: i18n.t(.fc_card_memory_sub)) {
                    inputText = "/memory"
                }
                FCWelcomeCard(icon: "square.grid.3x3", title: i18n.t(.fc_card_template_title), subtitle: i18n.t(.fc_card_template_sub)) {
                    inputText = "/template"
                }
                FCWelcomeCard(icon: "magnifyingglass", title: i18n.t(.fc_card_review_title), subtitle: i18n.t(.fc_card_review_sub)) {
                    inputText = "/review"
                }
                FCWelcomeCard(icon: "checkmark.shield", title: i18n.t(.fc_card_test_title), subtitle: i18n.t(.fc_card_test_sub)) {
                    inputText = "/test"
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.spacing2XL)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return i18n.t(.fc_greeting_morning)
        case 12..<17: return i18n.t(.fc_greeting_afternoon)
        case 17..<21: return i18n.t(.fc_greeting_evening)
        default: return i18n.t(.fc_greeting_night)
        }
    }

    // MARK: - Input Bar

    private var fcInputBar: some View {
        VStack(spacing: 0) {
            if let gitURL = detectedGitURL {
                GitURLDetectionBar(url: gitURL) {
                    detectedGitURL = nil
                } onSendAsText: {
                    inputText = detectedGitURL ?? ""
                    detectedGitURL = nil
                }
            }

            HStack(alignment: .bottom, spacing: theme.spacingS) {
                Menu {
                    ForEach(FCExecutionMode.allCases, id: \.self) { mode in
                        Button {
                            executionMode = mode
                            fcLog.info("Mode switched: \(mode.rawValue)")
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                Text(mode.localLabel)
                                Spacer()
                                if executionMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: executionMode.icon)
                            .font(.system(size: 11))
                        Text(executionMode.localLabel)
                            .font(.system(size: theme.captionSize, weight: .medium))
                    }
                    .foregroundStyle(modeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(modeBg))
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Button(action: { workspace.openLocalFolder() }) {
                        Label(i18n.t(.fc_add_folder), systemImage: "folder.badge.plus")
                    }
                    Button(action: { workspace.openSingleFile() }) {
                        Label(i18n.t(.fc_add_file), systemImage: "doc.text")
                    }
                    Divider()
                    Button(action: { inputText = "/kb " }) {
                        Label(i18n.t(.fc_query_kb), systemImage: "books.vertical")
                    }
                    Button(action: { showTemplatePicker = true }) {
                        Label(i18n.t(.fc_templates), systemImage: "square.grid.3x3")
                    }
                    Divider()
                    Toggle(isOn: $isWebSearchEnabled) {
                        Label(i18n.t(.fc_web_search), systemImage: "globe")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(theme.textTertiary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .popover(isPresented: $showTemplatePicker, arrowEdge: .top) {
                    fcTemplatePicker
                }

                ZStack(alignment: .topLeading) {
                    SendableTextEditor(
                        text: $inputText,
                        placeholder: i18n.t(.fc_input_placeholder),
                        font: .systemFont(ofSize: 14),
                        textColor: NSColor.labelColor,
                        placeholderColor: NSColor.tertiaryLabelColor,
                        maxHeight: 88,
                        onSend: sendMessage,
                        refocusTrigger: $refocusTrigger
                    )
                    .frame(minHeight: 28, maxHeight: 88)
                    .popover(isPresented: $showSlashMenu, arrowEdge: .top) {
                        FCSlashCommandMenu(filter: slashFilter, onSelect: { cmd in
                            inputText = "/\(cmd.name) "
                            showSlashMenu = false
                        })
                    }
                }
                .onChange(of: inputText) { _, newValue in
                    detectSlashCommand(newValue)
                    detectGitURL(newValue)
                }

                VoiceInputButton(voice: voiceInput, text: $inputText, onSend: sendMessage)

                if fcBridge.isStreaming {
                    Button(action: { fcBridge.chatCancel() }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(theme.accentDestructive)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(inputText.isEmpty ? theme.textTertiary : theme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty)
                }
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .background(theme.toolbarBg)
        }
        .overlay(alignment: .topTrailing) {
            if !pendingPermissions.isEmpty {
                FCPermissionDetailPanel(
                    request: pendingPermissions[0],
                    onApprove: { approvePermission(pendingPermissions[0].id) },
                    onDeny: { denyPermission(pendingPermissions[0].id) }
                )
                .padding(theme.spacingM)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private var modeColor: Color {
        switch executionMode {
        case .askPermissions: return theme.accent
        case .autoAccept: return theme.greenDot
        case .planOnly: return theme.auxiliary
        }
    }

    private var modeBg: Color {
        switch executionMode {
        case .askPermissions: return theme.accent.opacity(0.1)
        case .autoAccept: return theme.successBg
        case .planOnly: return theme.auxiliarySoft
        }
    }

    // MARK: - Right Panel

    private var fcRightPanel: some View {
        VStack(spacing: 0) {
            fcRightPanelTabBar
            Divider()

            switch rightPaneTab {
            case .editor:
                if workspace.selectedFile != nil {
                    MonacoEditorView(
                        content: $editorContent,
                        language: $editorLanguage,
                        onContentChange: { newContent in
                            handleEditorContentChange(newContent)
                        }
                    )
                } else {
                    VStack(spacing: theme.spacingM) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.textQuaternary)
                        Text(i18n.t(.fc_select_file_edit))
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            case .diff:
                FCDiffReviewView(
                    original: diffOriginal,
                    modified: diffModified,
                    language: diffLanguage,
                    fileName: workspace.selectedFile?.relativePath ?? "untitled"
                )

            case .preview:
                FCWebPreviewPanel(htmlContent: $previewHtmlContent)

            case .terminal:
                PTYTerminalView(workingDirectory: Binding(
                    get: { workspace.projectRoot?.path },
                    set: { _ in }
                ))

            case .snapshot:
                if let sid = currentSessionId {
                    FCSnapshotPanel(sessionId: sid)
                } else {
                    VStack(spacing: theme.spacingM) {
                        Image(systemName: "camera")
                            .font(.system(size: 24))
                            .foregroundStyle(theme.textTertiary)
                        Text(i18n.t(.fc_select_session_snapshot))
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            case .workflow:
                FCWorkflowPanel()

            case .sandbox:
                FCSandboxPanel()
            }

            if workspace.selectedFile != nil && rightPaneTab == .editor {
                fcEditorStatusBar
            }
        }
    }

    private var fcRightPanelTabBar: some View {
        HStack(spacing: 0) {
            ForEach(FCRightPane.allCases, id: \.self) { pane in
                Button(action: { rightPaneTab = pane }) {
                    HStack(spacing: 4) {
                        Image(systemName: rightPaneIcon(pane))
                            .font(.system(size: 11))
                        Text(pane.localLabel)
                            .font(.system(size: theme.captionSize))
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS + 2)
                    .background(rightPaneTab == pane ? theme.accent.opacity(0.1) : Color.clear)
                    .foregroundStyle(rightPaneTab == pane ? theme.accent : theme.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()

            if workspace.selectedFile != nil {
                Text(workspace.selectedFile?.relativePath ?? "")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textQuaternary)
                    .lineLimit(1)
                    .padding(.trailing, theme.spacingM)
            }
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, theme.spacingXS)
        .background(theme.toolbarBg)
    }

    private func rightPaneIcon(_ pane: FCRightPane) -> String {
        switch pane {
        case .editor:   return "chevron.left.forwardslash.chevron.right"
        case .diff:     return "arrow.triangle.swap"
        case .preview:  return "safari"
        case .terminal: return "terminal"
        case .snapshot: return "camera"
        case .workflow: return "flowchart"
        case .sandbox:  return "lock.shield"
        }
    }

    private var fcEditorStatusBar: some View {
        HStack(spacing: theme.spacingM) {
            if let file = workspace.selectedFile {
                Text(file.language)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                Text("UTF-8")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if let file = workspace.selectedFile, workspace.hasCheckpoint(file) {
                Button(i18n.t(.fc_undo)) {
                    if workspace.undoLastWrite(file) {
                        editorContent = workspace.selectedFile?.content ?? file.content
                        fcLog.info("Undo checkpoint restored")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(theme.accent)
            }
            Button(i18n.t(.fc_save)) {
                if let file = workspace.selectedFile {
                    Task {
                        let ok = await workspace.write(file: file, content: editorContent)
                        if ok { fcLog.info("File saved: \(file.name)") }
                    }
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.toolbarBg)
    }

    // MARK: - Context Panel

    private var fcContextPanel: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(i18n.t(.fc_project_context))
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if workspace.hasProject {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    contextRow(i18n.t(.fc_ctx_project), value: workspace.projectName)
                    if !workspace.gitBranch.isEmpty {
                        contextRow(i18n.t(.fc_ctx_branch), value: workspace.gitBranch)
                    }
                    contextRow(i18n.t(.fc_ctx_files), value: "\(workspace.files.count)")
                    contextRow(i18n.t(.fc_ctx_model), value: selectedModel.isEmpty ? i18n.t(.fc_not_selected) : selectedModel)
                    contextRow(i18n.t(.fc_ctx_mode), value: executionMode.localLabel)
                    contextRow(i18n.t(.fc_ctx_kb), value: kbStatusText)
                }
            } else {
                Text(i18n.t(.fc_no_project_open))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingM)
        .frame(width: 240)
    }

    private func contextRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.text)
                .lineLimit(1)
        }
    }

    // MARK: - Memory Panel

    private var fcMemoryPanel: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(i18n.t(.fc_project_memory))
                .font(.system(size: theme.footnoteSize, weight: .semibold))

            Button(i18n.t(.fc_load_memory)) {
                loadMemoryFiles()
            }
            .buttonStyle(.plain)
            .font(.system(size: theme.captionSize, weight: .medium))
            .foregroundStyle(theme.accent)

            Button(i18n.t(.fc_write_memory)) {
                inputText = "/memory "
                showMemoryPanel = false
            }
            .buttonStyle(.plain)
            .font(.system(size: theme.captionSize))
            .foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingM)
        .frame(width: 220)
    }

    // MARK: - Session Picker

    private var fcSessionPicker: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.fc_sessions))
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if fcBridge.sessions.isEmpty {
                Text(i18n.t(.fc_no_sessions))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacingXS) {
                        ForEach(fcBridge.sessions) { session in
                            Button {
                                currentSessionId = session.id
                                showSessionPicker = false
                                fcLog.info("Session selected: \(session.id)")
                            } label: {
                                HStack(spacing: theme.spacingS) {
                                    Image(systemName: session.state.icon)
                                        .font(.system(size: 10))
                                        .foregroundColor(colorForSessionState(session.state))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.displayTitle)
                                            .font(.system(size: theme.captionSize))
                                            .foregroundStyle(theme.text)
                                            .lineLimit(1)
                                        Text(String(format: i18n.t(.fc_messages_count), session.messageCount))
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.textTertiary)
                                    }
                                    Spacer()
                                    if session.id == currentSessionId {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.accent)
                                    }
                                }
                                .padding(.horizontal, theme.spacingS)
                                .padding(.vertical, theme.spacingXS)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(theme.spacingM)
        .frame(width: 260)
    }

    private func colorForSessionState(_ state: FCSessionState) -> Color {
        switch state {
        case .running, .clusterRunning: return .green
        case .waitingApproval: return .yellow
        case .paused: return .orange
        case .completed: return .blue
        case .failed: return .red
        default: return .gray
        }
    }

    // MARK: - Template Picker

    private var fcTemplatePicker: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(i18n.t(.fc_workflow_templates))
                .font(.system(size: theme.footnoteSize, weight: .semibold))

            let builtinTemplates: [(String, String, String)] = [
                (i18n.t(.fc_tpl_review), "magnifyingglass", "/review"),
                (i18n.t(.fc_tpl_test), "checkmark.shield", "/test"),
                (i18n.t(.fc_tpl_debug), "ladybug", "/debug"),
                (i18n.t(.fc_tpl_refactor), "hammer", "/refactor"),
                (i18n.t(.fc_tpl_explain), "text.bubble", "/explain"),
                (i18n.t(.fc_tpl_deploy), "cloud.upload", "/deploy"),
            ]

            ForEach(builtinTemplates, id: \.0) { tpl in
                Button {
                    inputText = tpl.2 + " "
                    showTemplatePicker = false
                } label: {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: tpl.1)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.accent)
                            .frame(width: 20)
                        Text(tpl.0)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.text)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(.vertical, theme.spacingXS)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.spacingM)
        .frame(width: 260)
    }

    // MARK: - Actions

    private func sendMessage() {
        if voiceInput.isRecording {
            let transcript = voiceInput.stopRecording()
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                inputText += (inputText.isEmpty ? "" : " ") + trimmed
            }
        }
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        if text.hasPrefix("/") {
            handleSlashCommand(text)
            inputText = ""
            refocusTrigger += 1
            return
        }

        let userMsg = FCChatMessage(role: "user", content: text, toolCalls: [], timestamp: Date())
        messages.append(userMsg)

        let assistantMsg = FCChatMessage(role: "assistant", content: "", toolCalls: [], timestamp: Date(), isStreaming: true)
        messages.append(assistantMsg)

        if fcBridge.isConnected {
            isMLXFallback = false
            fcBridge.chatStream(
                sessionId: currentSessionId,
                message: text,
                cwd: workspace.projectRoot?.path,
                model: selectedModel.isEmpty ? nil : selectedModel,
                executionMode: executionMode.rawValue,
                webSearch: isWebSearchEnabled
            )
        } else {
            isMLXFallback = true
            sendViaMLXFallback(text: text)
        }

        inputText = ""
        detectedGitURL = nil
        refocusTrigger += 1
        fcLog.info("Message sent: \(text.prefix(50)) mode=\(executionMode.rawValue) mlx=\(isMLXFallback)")
    }

    private func sendViaMLXFallback(text: String) {
        var mlxMessages: [[String: Any]] = [
            ["role": "system", "content": "You are an expert coding assistant. Help the user with their coding questions concisely and accurately."]
        ]
        for msg in messages where msg.role != "system" && !msg.content.isEmpty && !msg.isStreaming {
            mlxMessages.append(["role": msg.role, "content": msg.content])
        }
        let assistantId = messages.last?.id ?? UUID()
        Task {
            do {
                let model = selectedModel.isEmpty ? FusionConfig.shared.defaultModel(for: .code) : selectedModel
                let fullResp = try await bridge.inferStream(
                    messages: mlxMessages,
                    model: model,
                    temperature: 0.7,
                    maxTokens: 4096,
                    // F-R2: throttle 聚合 token, 距上次刷新 >50ms 才 hop MainActor 写 @Published,
                    // 防每 token 直接跨线程写 @Published (竞态) + 千次 MainActor hop 风暴。
                    onToken: { token in
                        fcStreamBuffer.append(token)
                        let now = DispatchTime.now()
                        if now.uptimeNanoseconds - fcLastStreamFlush.uptimeNanoseconds >= 50_000_000 {
                            fcLastStreamFlush = now
                            let snapshot = fcStreamBuffer
                            fcStreamBuffer = ""
                            Task { @MainActor in
                                if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                                    self.messages[idx].content += snapshot
                                }
                            }
                        }
                    }
                )
                fcLog.info("MLX fallback done: \(fullResp.count) chars")
            } catch {
                if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                    self.messages[idx].content = "Error: \(error.localizedDescription)"
                    self.messages[idx].isStreaming = false
                }
                fcLog.error("MLX fallback failed: \(error.localizedDescription)")
            }
            if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                self.messages[idx].isStreaming = false
            }
        }
    }

    private func processIncomingEvents() {
        let allEvents = fcBridge.chatEvents
        guard lastProcessedEventIdx < allEvents.count, !messages.isEmpty else { return }

        let lastIdx = messages.indices.last!
        guard messages[lastIdx].role == "assistant" else { return }

        let newEvents = Array(allEvents.dropFirst(lastProcessedEventIdx))
        var toolCalls = messages[lastIdx].toolCalls

        for event in newEvents {
            switch event.type {
            case "tool_use", "tool_call":
                let tier = permissionTier(for: event.toolName)
                let tc = FCToolCall(
                    name: event.toolName,
                    args: event.toolArgs,
                    status: tier == .tier1 || executionMode == .autoAccept ? .approved : .pending,
                    output: nil
                )
                toolCalls.append(tc)
                if tc.status == .pending {
                    let req = FCPermissionRequest(
                        tool: event.toolName,
                        args: event.toolArgs,
                        tier: tier,
                        description: describeToolCall(event.toolName, args: event.toolArgs)
                    )
                    pendingPermissions.append(req)
                }
            case "tool_result", "tool_output":
                if let pendingIdx = toolCalls.lastIndex(where: { $0.status == .approved || $0.status == .running }) {
                    toolCalls[pendingIdx] = FCToolCall(
                        id: toolCalls[pendingIdx].id,
                        name: toolCalls[pendingIdx].name,
                        args: toolCalls[pendingIdx].args,
                        status: .completed,
                        output: event.content
                    )
                }
            default:
                break
            }
        }

        lastProcessedEventIdx = allEvents.count

        messages[lastIdx] = FCChatMessage(
            id: messages[lastIdx].id,
            role: "assistant",
            content: fcBridge.currentStreamContent,
            toolCalls: toolCalls,
            timestamp: messages[lastIdx].timestamp,
            isStreaming: fcBridge.isStreaming
        )
    }

    private func permissionTier(for tool: String) -> FCPermissionTier {
        let tier1Tools = ["Read", "Glob", "Grep", "Ls", "WebFetch", "GitRead", "git_read", "read", "glob", "grep", "ls", "web_fetch"]
        return tier1Tools.contains(tool) ? .tier1 : .tier2
    }

    private func describeToolCall(_ tool: String, args: [String: Any]) -> String {
        switch tool {
        case "Edit", "edit":
            let path = args["file_path"] as? String ?? args["path"] as? String ?? "unknown"
            return String(format: I18nManager.shared.t(.fc_tool_edit), path)
        case "Write", "write":
            let path = args["file_path"] as? String ?? args["path"] as? String ?? "unknown"
            return String(format: I18nManager.shared.t(.fc_tool_write), path)
        case "Bash", "bash":
            let cmd = args["command"] as? String ?? "unknown"
            return String(format: I18nManager.shared.t(.fc_tool_run), String(cmd.prefix(60)))
        case "MultiEdit", "multi_edit":
            return I18nManager.shared.t(.fc_tool_multi_edit)
        default:
            return "\(tool): \(args.values.first.map { "\($0)" } ?? "")"
        }
    }

    private func handleSlashCommand(_ text: String) {
        let parts = text.split(separator: " ", maxSplits: 1)
        let cmd = String(parts[0]).lowercased()
        let arg = parts.count > 1 ? String(parts[1]) : ""

        switch cmd {
        case "/clear":
            messages.removeAll()
            fcBridge.chatEvents.removeAll()
            fcBridge.currentStreamContent = ""
            fcLog.info("Conversation cleared")
        case "/help":
            let helpText = FC_SLASH_COMMANDS.map { "\($0.shortcut) — \($0.description)" }.joined(separator: "\n")
            messages.append(FCChatMessage(role: "assistant", content: helpText, toolCalls: [], timestamp: Date()))
        case "/kb":
            handleKBQuery(arg)
        case "/memory":
            handleMemoryCommand(arg)
        case "/template":
            showTemplatePicker = true
        case "/model":
            if !arg.isEmpty {
                selectedModel = arg
                messages.append(FCChatMessage(role: "assistant", content: String(format: I18nManager.shared.t(.fc_msg_model_switched), arg), toolCalls: [], timestamp: Date()))
            } else {
                messages.append(FCChatMessage(role: "assistant", content: String(format: I18nManager.shared.t(.fc_msg_current_model), selectedModel.isEmpty ? "none" : selectedModel), toolCalls: [], timestamp: Date()))
            }
        case "/compact":
            fcBridge.compactSession(sessionId: currentSessionId)
            messages.append(FCChatMessage(role: "system", content: I18nManager.shared.t(.fc_msg_context_compacted), toolCalls: [], timestamp: Date()))
            fcLog.info("compact sent for session \(currentSessionId ?? "none")")
        case "/review", "/test", "/debug", "/refactor", "/explain", "/deploy", "/init":
            let userMsg = FCChatMessage(role: "user", content: text, toolCalls: [], timestamp: Date())
            messages.append(userMsg)
            let assistantMsg = FCChatMessage(role: "assistant", content: "", toolCalls: [], timestamp: Date(), isStreaming: true)
            messages.append(assistantMsg)
            fcBridge.chatStream(sessionId: currentSessionId, message: text, cwd: workspace.projectRoot?.path, model: selectedModel.isEmpty ? nil : selectedModel, executionMode: executionMode.rawValue, webSearch: isWebSearchEnabled, commandMode: true)
        default:
            messages.append(FCChatMessage(role: "assistant", content: String(format: I18nManager.shared.t(.fc_msg_unknown_cmd), cmd), toolCalls: [], timestamp: Date()))
        }
    }

    private func handleKBQuery(_ query: String) {
        guard !query.isEmpty else {
            messages.append(FCChatMessage(role: "assistant", content: I18nManager.shared.t(.fc_msg_kb_usage), toolCalls: [], timestamp: Date()))
            return
        }
        guard let cwd = workspace.projectRoot?.path else {
            messages.append(FCChatMessage(role: "assistant", content: I18nManager.shared.t(.fc_msg_no_project_open), toolCalls: [], timestamp: Date()))
            return
        }
        Task {
            do {
                let result = try await fcBridge.queryKB(cwd: cwd, query: query)
                let results = result["results"] as? [[String: Any]] ?? []
                if results.isEmpty {
                    await MainActor.run {
                        messages.append(FCChatMessage(role: "assistant", content: String(format: I18nManager.shared.t(.fc_msg_kb_no_results), query), toolCalls: [], timestamp: Date()))
                    }
                } else {
                    let formatted = results.enumerated().map { (i, r) in
                        let content = r["content"] as? String ?? ""
                        let source = r["source"] as? String ?? "unknown"
                        return "[\(i + 1)] \(source)\n\(content.prefix(200))..."
                    }.joined(separator: "\n\n")
                    await MainActor.run {
                        messages.append(FCChatMessage(role: "assistant", content: String(format: I18nManager.shared.t(.fc_msg_kb_results), formatted), toolCalls: [], timestamp: Date()))
                    }
                }
            } catch {
                await MainActor.run {
                    messages.append(FCChatMessage(role: "assistant", content: String(format: I18nManager.shared.t(.fc_msg_kb_failed), error.localizedDescription), toolCalls: [], timestamp: Date()))
                }
            }
        }
    }

    private func handleMemoryCommand(_ arg: String) {
        guard let cwd = workspace.projectRoot?.path else {
            messages.append(FCChatMessage(role: "assistant", content: I18nManager.shared.t(.fc_msg_no_project), toolCalls: [], timestamp: Date()))
            return
        }
        Task {
            do {
                let result = try await fcBridge.getMemory(cwd: cwd)
                let files = result["files"] as? [[String: Any]] ?? []
                if files.isEmpty {
                    await MainActor.run {
                        messages.append(FCChatMessage(role: "assistant", content: I18nManager.shared.t(.fc_msg_no_memory), toolCalls: [], timestamp: Date()))
                    }
                } else {
                    let list = files.map { f in
                        let name = f["filename"] as? String ?? "unknown"
                        let size = f["size"] as? Int ?? 0
                        return "- \(name) (\(size) bytes)"
                    }.joined(separator: "\n")
                    await MainActor.run {
                        messages.append(FCChatMessage(role: "assistant", content: String(format: I18nManager.shared.t(.fc_msg_memory_files), list), toolCalls: [], timestamp: Date()))
                    }
                }
            } catch {
                await MainActor.run {
                    messages.append(FCChatMessage(role: "assistant", content: String(format: I18nManager.shared.t(.fc_msg_memory_failed), error.localizedDescription), toolCalls: [], timestamp: Date()))
                }
            }
        }
    }

    private func buildKB() {
        guard let cwd = workspace.projectRoot?.path else { return }
        Task {
            await MainActor.run { kbStatusText = I18nManager.shared.t(.fc_kb_building) }
            do {
                _ = try await fcBridge.buildKB(cwd: cwd)
                loadKBStatus()
                fcLog.info("KB build triggered")
            } catch {
                await MainActor.run { kbStatusText = I18nManager.shared.t(.fc_kb_build_failed) }
                fcLog.error("KB build failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadMemoryFiles() {
        showMemoryPanel = false
        inputText = "/memory"
        sendMessage()
    }

    private func detectSlashCommand(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        showSlashMenu = trimmed.hasPrefix("/") && trimmed.count <= 30 && !trimmed.contains(" ")
        if showSlashMenu {
            slashFilter = String(trimmed.dropFirst())
        }
    }

    private func detectGitURL(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("https://github.com/") || trimmed.hasPrefix("https://gitlab.com/") || trimmed.hasPrefix("https://bitbucket.org/") {
            if trimmed.hasSuffix(".git") || trimmed.split(separator: "/").count >= 5 {
                detectedGitURL = trimmed
            }
        } else {
            detectedGitURL = nil
        }
    }

    private func applyCodeFromMessage(_ code: String, language: String) {
        if let file = workspace.selectedFile {
            diffOriginal = file.content
            diffModified = code
            diffLanguage = language
            rightPaneTab = .diff
            showRightPanel = true
            fcLog.info("Apply code: showing diff for \(file.name)")
        } else {
            editorContent = code
            editorLanguage = language
            rightPaneTab = .editor
            showRightPanel = true
            fcLog.info("Apply code: opened in new editor")
        }
    }

    private func handleEditorContentChange(_ newContent: String) {
        if let file = workspace.selectedFile, newContent != file.content {
            workspace.selectedFile?.content = newContent
            workspace.selectedFile?.isModified = true
        }
    }

    private func approvePermission(_ id: UUID) {
        if let req = pendingPermissions.first(where: { $0.id == id }) {
            fcBridge.sendPermissionResponse(toolCallId: req.id.uuidString, approved: true)
        }
        pendingPermissions.removeAll { $0.id == id }
        if let lastIdx = messages.indices.last {
            let msg = messages[lastIdx]
            var updatedCalls = msg.toolCalls
            if let tcIdx = updatedCalls.firstIndex(where: { $0.status == .pending }) {
                updatedCalls[tcIdx] = FCToolCall(id: updatedCalls[tcIdx].id, name: updatedCalls[tcIdx].name, args: updatedCalls[tcIdx].args, status: .approved, output: nil)
            }
            messages[lastIdx] = FCChatMessage(id: msg.id, role: msg.role, content: msg.content, toolCalls: updatedCalls, timestamp: msg.timestamp, isStreaming: msg.isStreaming)
        }
        fcLog.info("Permission approved")
    }

    private func denyPermission(_ id: UUID) {
        if let req = pendingPermissions.first(where: { $0.id == id }) {
            fcBridge.sendPermissionResponse(toolCallId: req.id.uuidString, approved: false)
        }
        pendingPermissions.removeAll { $0.id == id }
        if let lastIdx = messages.indices.last {
            let msg = messages[lastIdx]
            var updatedCalls = msg.toolCalls
            if let tcIdx = updatedCalls.firstIndex(where: { $0.status == .pending }) {
                updatedCalls[tcIdx] = FCToolCall(id: updatedCalls[tcIdx].id, name: updatedCalls[tcIdx].name, args: updatedCalls[tcIdx].args, status: .denied, output: I18nManager.shared.t(.fc_denied_by_user))
            }
            messages[lastIdx] = FCChatMessage(id: msg.id, role: msg.role, content: msg.content, toolCalls: updatedCalls, timestamp: msg.timestamp, isStreaming: msg.isStreaming)
        }
        fcLog.info("Permission denied")
    }
}
