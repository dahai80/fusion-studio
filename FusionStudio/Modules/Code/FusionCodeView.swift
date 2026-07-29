import SwiftUI
import AppKit
import os.log

private let fusionCodeLog = Logger(subsystem: "com.fusion.studio", category: "FusionCodeView")

enum CodeRightPane: String, CaseIterable {
    case editor = "Editor"
    case diff = "Diff"
    case terminal = "Terminal"
}

struct FusionCodeView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var bridge: AgentBridge
    @StateObject private var agent = CodeAgent.shared
    @StateObject private var workspace = ProjectWorkspace.shared

    @State private var inputText = ""
    @State private var selectedModel = ""
    @State private var showModelPicker = false
    @State private var selectedEffort: String = "Medium"
    @State private var thinkingEnabled = false
    @State private var modelPickerPage: ModelPickerPage = .main
    @State private var sidebarTab: CodeSidebarTab = .files
    @State private var rightPane: CodeRightPane = .editor
    @State private var showSidebar = true
    @State private var showRightPanel = false
    @State private var editorContent = ""
    @State private var editorLanguage = "plaintext"
    @State private var diffOriginal = ""
    @State private var diffModified = ""
    @State private var diffLanguage = "plaintext"
    @State private var showOpenProject = false
    @State private var detectedGitURL: String?
    @State private var isWebSearchEnabled = false

    enum CodeSidebarTab: String, CaseIterable {
        case files = "Files"
        case chat = "Chat"
        case git = "Git"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                sidebarPanel
                    .frame(width: 240)
                    .background(theme.surfaceSecondary)
            }

            chatPanel
                .frame(maxWidth: .infinity)

            if showRightPanel {
                rightPanel
                    .frame(width: 480)
                    .background(theme.contentBg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showOpenProject) {
            OpenProjectSheet(workspace: workspace)
        }
        .onAppear {
            agent.agentBridge = bridge
            if selectedModel.isEmpty && !bridge.models.isEmpty {
                selectedModel = bridge.models.first?.name ?? ""
                agent.selectedModel = selectedModel
            }
            Task {
                _ = try? await bridge.fetchModels()
                if selectedModel.isEmpty, let first = bridge.models.first?.name {
                    selectedModel = first
                    agent.selectedModel = first
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarPanel: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()

            HStack(spacing: 0) {
                ForEach(CodeSidebarTab.allCases, id: \.self) { tab in
                    Button(action: { sidebarTab = tab }) {
                        VStack(spacing: 2) {
                            Image(systemName: sidebarTabIcon(tab))
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(size: 9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(sidebarTab == tab ? theme.accent.opacity(0.15) : Color.clear)
                        .foregroundStyle(sidebarTab == tab ? theme.accent : theme.textSecondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(theme.surfaceSecondary)
            Divider()

            switch sidebarTab {
            case .files: FileTreeView()
            case .chat:  ChatHistoryView()
            case .git:   FusionGitPanel()
            }
        }
    }

    private var sidebarHeader: some View {
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
                Text("Fusion Code")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
            }
            Spacer()
            Button(action: { showOpenProject = true }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private func sidebarTabIcon(_ tab: CodeSidebarTab) -> String {
        switch tab {
        case .files: return workspace.hasProject ? "folder.fill" : "folder"
        case .chat:  return "message"
        case .git:   return "arrow.triangle.branch"
        }
    }

    // MARK: - Chat Panel

    private var chatPanel: some View {
        VStack(spacing: 0) {
            chatToolbar
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: theme.spacingM) {
                        if agent.conversation.isEmpty && !workspace.hasProject {
                            welcomeSection
                        }
                        ForEach(agent.conversation) { msg in
                            CodeMessageBubble(message: msg, onApplyCode: applyCodeFromMessage)
                                .id(msg.id)
                        }
                        if agent.isThinking {
                            HStack(spacing: theme.spacingS) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking...")
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
                .onChange(of: agent.conversation.count) {
                    if let last = agent.conversation.last {
                        withAnimation(theme.springDefault) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: agent.scrollToMessageId) { _, id in
                    guard let id else { return }
                    withAnimation(theme.springDefault) { proxy.scrollTo(id, anchor: .center) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { agent.scrollToMessageId = nil }
                }
            }

            Divider()
            chatInputBar
        }
    }

    private var chatToolbar: some View {
        HStack(spacing: theme.spacingS) {
            Button(action: { withAnimation { showSidebar.toggle() } }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            if workspace.hasProject {
                Button(action: { withAnimation { showRightPanel.toggle() } }) {
                    Image(systemName: showRightPanel ? "rectangle.split.1x2" : "rectangle.split.2x1")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: { showModelPicker.toggle() }) {
                HStack(spacing: 4) {
                    Text(selectedModel.isEmpty ? "Model" : selectedModel)
                        .font(.system(size: theme.captionSize, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.separator.opacity(0.5))
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showModelPicker, arrowEdge: .bottom) {
                ModelPickerPopover(
                    bridge: bridge,
                    selectedModel: $selectedModel,
                    selectedEffort: $selectedEffort,
                    thinkingEnabled: $thinkingEnabled,
                    modelPickerPage: $modelPickerPage,
                    onSelect: { model in
                        selectedModel = model
                        agent.selectedModel = model
                        Task { try? await bridge.mlxSetModel(model: model) }
                        fusionCodeLog.info("Model selected: \(model)")
                        showModelPicker = false
                    }
                )
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.contentBg)
    }

    private var welcomeSection: some View {
        VStack(spacing: theme.spacingL) {
            Spacer(minLength: 0)

            Text("\(greeting), \(NSUserName())")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.text)

            HStack(spacing: theme.spacingS) {
                WelcomeCardView(icon: "folder.badge.plus", title: "Open Project", subtitle: "Start with a local folder") {
                    showOpenProject = true
                }
                WelcomeCardView(icon: "doc.text", title: "Explain", subtitle: "Understand code patterns") {
                    inputText = "Explain this code"
                }
                WelcomeCardView(icon: "ladybug", title: "Debug", subtitle: "Find and fix issues") {
                    inputText = "Help me debug this"
                }
                WelcomeCardView(icon: "hammer", title: "Refactor", subtitle: "Improve code quality") {
                    inputText = "Refactor this code"
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var chatInputBar: some View {
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
                    Button(action: { workspace.openLocalFolder() }) {
                        Label("Add files", systemImage: "doc.badge.plus")
                    }
                    Button(action: { workspace.openSingleFile() }) {
                        Label("Add file", systemImage: "doc.text")
                    }
                    Button(action: {
                        isWebSearchEnabled.toggle()
                        fusionCodeLog.info("Web search: \(isWebSearchEnabled)")
                    }) {
                        Label("Web search", systemImage: "globe")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(theme.textTertiary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                TextField("Ask anything — code, explain, debug, refactor...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.textSize))
                    .lineLimit(1...6)
                    .onSubmit { sendMessage() }
                    .onChange(of: inputText) { _, newValue in
                        detectGitURL(newValue)
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(inputText.isEmpty ? theme.textTertiary : theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || agent.isThinking)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .background(theme.surfaceSecondary)
        }
    }

    // MARK: - Right Panel (Editor/Diff/Terminal)

    private var rightPanel: some View {
        VStack(spacing: 0) {
            rightPanelTabBar
            Divider()

            switch rightPane {
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
                        Text("Select a file to edit")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            case .diff:
                MonacoDiffView(
                    originalContent: diffOriginal,
                    modifiedContent: diffModified,
                    language: diffLanguage
                )

            case .terminal:
                PTYTerminalView(workingDirectory: Binding(
                    get: { workspace.projectRoot?.path },
                    set: { _ in }
                ))
            }

            if workspace.selectedFile != nil && rightPane == .editor {
                editorStatusBar
            }
        }
    }

    private var rightPanelTabBar: some View {
        HStack(spacing: 0) {
            ForEach(CodeRightPane.allCases, id: \.self) { pane in
                Button(action: { rightPane = pane }) {
                    HStack(spacing: 4) {
                        Image(systemName: rightPaneIcon(pane))
                            .font(.system(size: 11))
                        Text(pane.rawValue)
                            .font(.system(size: theme.captionSize))
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS + 2)
                    .background(
                        rightPane == pane ? theme.accent.opacity(0.1) : Color.clear
                    )
                    .foregroundStyle(rightPane == pane ? theme.accent : theme.textSecondary)
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
        .background(theme.surfaceSecondary)
    }

    private func rightPaneIcon(_ pane: CodeRightPane) -> String {
        switch pane {
        case .editor:   return "chevron.left.forwardslash.chevron.right"
        case .diff:     return "arrow.triangle.swap"
        case .terminal: return "terminal"
        }
    }

    private var editorStatusBar: some View {
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
                Button("Undo") {
                    if workspace.undoLastWrite(file) {
                        editorContent = file.content
                        fusionCodeLog.info("Undo checkpoint restored")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(theme.accent)
            }

            Button("Save") {
                if let file = workspace.selectedFile {
                    workspace.write(file: file, content: editorContent)
                    fusionCodeLog.info("File saved: \(file.name)")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.surfaceSecondary)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let effort = selectedEffort.lowercased()
        let context = agent.buildContextString()
        agent.askAI(prompt: text, context: context, effort: effort, thinking: thinkingEnabled)
        inputText = ""
        detectedGitURL = nil
        fusionCodeLog.info("Message sent: \(text.prefix(50)) effort=\(effort)")
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
            rightPane = .diff
            showRightPanel = true
            fusionCodeLog.info("Apply code: showing diff for \(file.name)")
        } else {
            editorContent = code
            editorLanguage = language
            rightPane = .editor
            showRightPanel = true
            fusionCodeLog.info("Apply code: opened in new editor")
        }
    }

    private func handleEditorContentChange(_ newContent: String) {
        if let file = workspace.selectedFile, newContent != file.content {
            workspace.selectedFile?.content = newContent
            workspace.selectedFile?.isModified = true
        }
    }
}

// MARK: - Model Picker Popover

struct ModelPickerPopover: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: AgentBridge
    @Binding var selectedModel: String
    @Binding var selectedEffort: String
    @Binding var thinkingEnabled: Bool
    @Binding var modelPickerPage: ModelPickerPage
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                if bridge.models.isEmpty {
                    Text("No models available")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.vertical, 4)
                } else {
                    let displayModels = Array(bridge.models.prefix(4))
                    ForEach(displayModels) { model in
                        Button(action: { onSelect(model.name) }) {
                            HStack {
                                Text(model.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.text)
                                    .lineLimit(1)
                                Spacer()
                                if selectedModel == model.name {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(selectedModel == model.name ? theme.accent.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider().padding(.vertical, 2)

                    HStack {
                        Text("Effort")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.text)
                        Spacer()
                        Text(selectedEffort)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(modelPickerPage == .effort ? theme.accent.opacity(0.08) : Color.clear)
                    )
                    .onHover { hovering in
                        if hovering { modelPickerPage = .effort }
                    }

                    if bridge.models.count > 4 {
                        Divider().padding(.vertical, 2)
                        HStack {
                            Text("More Models")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(modelPickerPage == .moreModels ? theme.accent.opacity(0.08) : Color.clear)
                        )
                        .onHover { hovering in
                            if hovering { modelPickerPage = .moreModels }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(width: 200)

            if modelPickerPage != .main {
                Divider().padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 2) {
                    switch modelPickerPage {
                    case .effort:
                        ForEach(["Low", "Medium", "High", "Extra", "Max"], id: \.self) { level in
                            Button(action: {
                                selectedEffort = level
                                modelPickerPage = .main
                            }) {
                                HStack {
                                    Text(level)
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.text)
                                    Spacer()
                                    if selectedEffort == level {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(selectedEffort == level ? theme.accent.opacity(0.1) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().padding(.vertical, 2)

                        HStack {
                            Text("Thinking")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.text)
                            Spacer()
                            Toggle("", isOn: $thinkingEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)

                    case .moreModels:
                        let moreModels = Array(bridge.models.dropFirst(4))
                        ForEach(moreModels) { model in
                            Button(action: { onSelect(model.name) }) {
                                HStack {
                                    Text(model.name)
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.text)
                                        .lineLimit(1)
                                    Spacer()
                                    if selectedModel == model.name {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(selectedModel == model.name ? theme.accent.opacity(0.1) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                    default:
                        EmptyView()
                    }
                }
                .padding(.vertical, 6)
                .frame(width: 180)
            }
        }
    }
}

// MARK: - Code Message Bubble with Apply

struct CodeMessageBubble: View {
    let message: CodeAgent.CodeMessage
    let onApplyCode: (String, String) -> Void
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            if message.role == "user" {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(message.role == "user" ? theme.accent.opacity(0.12) : theme.surfaceSecondary)
                    )

                if message.role == "assistant" && !message.codeBlocks.isEmpty {
                    codeApplyButtons
                }

                Text(message.timestamp, style: .time)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textQuaternary)
            }

            if message.role == "assistant" {
                Spacer(minLength: 60)
            }
        }
    }

    private var codeApplyButtons: some View {
        HStack(spacing: theme.spacingS) {
            ForEach(Array(message.codeBlocks.enumerated()), id: \.offset) { index, block in
                Button(action: {
                    let lang = detectLanguageFromCode(block)
                    onApplyCode(block, lang)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 10))
                        Text("Apply Code \(message.codeBlocks.count > 1 ? "#\(index + 1)" : "")")
                            .font(.system(size: theme.captionSize, weight: .medium))
                        let stats = computeDiffStats(block)
                        if stats.added > 0 || stats.removed > 0 {
                            diffIndicatorBadge(added: stats.added, removed: stats.removed)
                        }
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS + 2)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.accent.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func diffIndicatorBadge(added: Int, removed: Int) -> some View {
        HStack(spacing: 2) {
            if added > 0 {
                Text("+\(added)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
            }
            if removed > 0 {
                Text("-\(removed)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
    }

    private func computeDiffStats(_ code: String) -> (added: Int, removed: Int) {
        var added = 0
        var removed = 0
        let lines = code.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("+") && !trimmed.hasPrefix("++") {
                added += 1
            } else if trimmed.hasPrefix("-") && !trimmed.hasPrefix("--") {
                removed += 1
            }
        }
        if added == 0 && removed == 0 {
            added = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        }
        return (added, removed)
    }

    private func detectLanguageFromCode(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<html") { return "html" }
        if trimmed.hasPrefix("<?xml") { return "xml" }
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") { return "json" }
        if trimmed.hasPrefix("#!") {
            if trimmed.contains("python") { return "python" }
            if trimmed.contains("bash") || trimmed.contains("zsh") { return "shell" }
        }
        if trimmed.hasPrefix("import ") {
            if trimmed.contains("from tkinter") || trimmed.contains("import os") { return "python" }
            if trimmed.contains("SwiftUI") { return "swift" }
            if trimmed.contains("react") { return "javascript" }
        }
        if trimmed.hasPrefix("func ") || trimmed.hasPrefix("class ") || trimmed.hasPrefix("struct ") { return "swift" }
        if trimmed.hasPrefix("fn ") || trimmed.hasPrefix("impl ") { return "rust" }
        if trimmed.hasPrefix("def ") || trimmed.hasPrefix("class ") && trimmed.contains(":") { return "python" }
        return "plaintext"
    }
}

// MARK: - Welcome Card View

struct WelcomeCardView: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @Environment(\.studioTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(theme.accent)

                Text(title)
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            .padding(theme.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .fill(isHovered ? theme.surfaceElevated : theme.groupBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(isHovered ? theme.accent.opacity(0.3) : theme.groupBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - Git Panel

struct FusionGitPanel: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var git = GitManager.shared
    @StateObject private var workspace = ProjectWorkspace.shared
    @State private var commitMessage = ""
    @State private var newBranchName = ""
    @State private var showNewBranch = false
    @State private var selectedDiffFile: String?
    @State private var diffContent: String?

    var body: some View {
        VStack(spacing: 0) {
            branchHeader
            if showNewBranch {
                newBranchForm
            }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingM) {
                    changesSection
                    if !git.stashList.isEmpty {
                        stashSection
                    }
                    logSection
                }
                .padding(theme.spacingM)
            }
        }
        .background(theme.surfaceSecondary)
        .onAppear {
            git.setProjectRoot(workspace.projectRoot)
        }
        .onChange(of: workspace.projectRoot) { _, _ in
            git.setProjectRoot(workspace.projectRoot)
        }
    }

    private var branchHeader: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 11))
                .foregroundStyle(theme.accent)
            Text(git.branch.isEmpty ? "No branch" : git.branch)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.text)

            Spacer()

            Button { git.pull() } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Button { git.push() } label: {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Button { showNewBranch = true } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Button { git.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfacePrimary)
    }

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("Changes")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            if git.changes.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("No changes")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
            } else {
                ForEach(git.changes) { change in
                    HStack(spacing: theme.spacingS) {
                        Text(change.status)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(colorForGitStatus(change.statusColor))
                            .frame(width: 16)

                        Text(change.file)
                            .font(.system(size: 10))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button {
                            diffContent = git.diff(file: change.file)
                            selectedDiffFile = change.file
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)

                        Button {
                            _ = git.discardChanges(file: change.file)
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.mini)
                    }
                    .padding(.vertical, 2)
                }

                commitSection
            }
        }
    }

    private var commitSection: some View {
        VStack(spacing: theme.spacingS) {
            TextField("Commit message...", text: $commitMessage)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.surfacePrimary)
                )

            HStack(spacing: theme.spacingS) {
                Button {
                    if git.commit(message: commitMessage) {
                        commitMessage = ""
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                        Text("Commit All")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS + 2)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.accent)
                    )
                }
                .buttonStyle(.plain)
                .disabled(commitMessage.isEmpty)

                Button {
                    _ = git.stash()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 10))
                        Text("Stash")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }

    private var stashSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("Stash")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            ForEach(git.stashList.indices, id: \.self) { index in
                Text(git.stashList[index])
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            Button {
                _ = git.stashPop()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 10))
                    Text("Pop Stash")
                        .font(.system(size: 10))
                }
                .foregroundStyle(theme.accent)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("Recent Commits")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            ForEach(git.log) { entry in
                HStack(spacing: theme.spacingS) {
                    Text(entry.hash)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.accent)
                    Text(entry.message)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                }
            }

            if !git.branches.isEmpty && git.branches.count > 1 {
                branchSwitcher
            }
        }
    }

    private var newBranchForm: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 11))
                .foregroundStyle(theme.accent)
            TextField("Branch name...", text: $newBranchName)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .onSubmit {
                    if git.createBranch(name: newBranchName) {
                        newBranchName = ""
                        showNewBranch = false
                    }
                }
            Button {
                if git.createBranch(name: newBranchName) {
                    newBranchName = ""
                    showNewBranch = false
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            Button {
                showNewBranch = false
                newBranchName = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfacePrimary)
    }

    private var branchSwitcher: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("Branches")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            ForEach(git.branches, id: \.self) { name in
                Button {
                    git.checkout(branch: name)
                } label: {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: name == git.branch ? "smallcircle.filled.circle" : "circle")
                            .font(.system(size: 9))
                            .foregroundStyle(name == git.branch ? theme.accent : theme.textTertiary)
                        Text(name)
                            .font(.system(size: 10))
                            .foregroundStyle(name == git.branch ? theme.text : theme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func colorForGitStatus(_ name: String) -> Color {
        switch name {
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "blue": return .blue
        case "purple": return .purple
        default: return .gray
        }
    }
}
