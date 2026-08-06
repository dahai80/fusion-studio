import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

enum ArtifactKind: String, CaseIterable, Hashable {
    case app
    case code
    case document
    case game
    case tool
    case template

    var label: String {
        switch self {
        case .app: return "App"
        case .code: return "Code"
        case .document: return "Document"
        case .game: return "Game"
        case .tool: return "Tool"
        case .template: return "Template"
        }
    }

    var icon: String {
        switch self {
        case .app: return "app.badge"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .document: return "doc.text"
        case .game: return "gamecontroller"
        case .tool: return "wrench.and.screwdriver"
        case .template: return "square.grid.2x2"
        }
    }

    var color: Color {
        switch self {
        case .app: return .blue
        case .code: return .purple
        case .document: return .indigo
        case .game: return .green
        case .tool: return .orange
        case .template: return .teal
        }
    }
}

struct ArtifactModel: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let kind: ArtifactKind
    let currentVersion: Int
    let tokenCount: Int
    let summary: String?
    let updatedAt: Date
}

struct ArtifactVersionModel: Identifiable, Hashable {
    let id: Int
    let versionNum: Int
    let tokenCount: Int
    let changeLog: String?
    let createdAt: Date
}

struct ArtifactChatMessage: Identifiable {
    let id: String
    let role: String
    var content: String

    init(id: String = UUID().uuidString, role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

// MARK: - ArtifactsPanel

struct ArtifactsPanel: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var artifacts: [ArtifactModel] = []
    @State private var selectedArtifact: ArtifactModel?
    @State private var selectedContent: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var engineOnline = false
    @State private var sessionId = "default"
    @State private var showTemplatePicker = false
    @State private var showCreateSheet = false
    @State private var selectedTemplate: ArtifactTemplate?
    @State private var showEditSheet = false
    @State private var showVersionSheet = false
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var showInjectSheet = false
    @State private var showSessionPicker = false
    @EnvironmentObject var agentBridge: AgentBridge
    @State private var chatMessages: [ArtifactChatMessage] = []
    @State private var chatInput = ""
    @State private var chatGenerating = false
    @State private var chatError: String?
    @State private var selectedModel: String = ""
    @StateObject private var voiceInput = VoiceInputManager()
    @State private var liveContent = ""
    @State private var liveType = "html"
    @State private var liveKind: ArtifactKind = .app
    @State private var liveName = ""
    @State private var showLibrary = false
    @State private var hoveredTemplateId: String?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            conversationView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkEngineAndLoad()
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet { template in
                selectedTemplate = template
                liveKind = template.kind
                liveType = template.type
                liveName = template.name
                showTemplatePicker = false
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            if let template = selectedTemplate {
                ArtifactCreateChatSheet(sessionId: sessionId, template: template) { _ in loadArtifacts() }
            } else {
                CreateArtifactSheet(sessionId: sessionId) { _ in loadArtifacts() }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            if let art = selectedArtifact {
                EditContentSheet(artifact: art) { _ in
                    loadContent(for: art)
                    loadArtifacts()
                }
            }
        }
        .sheet(isPresented: $showVersionSheet) {
            if let art = selectedArtifact {
                VersionHistorySheet(artifact: art)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let art = selectedArtifact {
                ExportArtifactSheet(artifact: art)
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportArtifactSheet { _ in loadArtifacts() }
        }
        .sheet(isPresented: $showInjectSheet) {
            InjectPreviewSheet()
        }
        .popover(isPresented: $showSessionPicker) {
            SessionPickerView(currentSession: $sessionId)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Text("Artifacts")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if engineOnline {
                Circle().fill(Color.green).frame(width: 8, height: 8)
            } else {
                Circle().fill(Color.red).frame(width: 8, height: 8)
            }

            Text(sessionId)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(theme.accent.opacity(0.15))
                )
                .onTapGesture { showSessionPicker = true }

            Spacer()

            if isSearching {
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.footnoteSize))
                    .frame(width: 140)
                    .onSubmit { isSearching = false }
            } else {
                Button(action: { isSearching = true }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Search Artifacts")
            }

            Button(action: { showInjectSheet = true }) {
                Image(systemName: "text.append")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Inject / Safety Preview")

            Button(action: { showImportSheet = true }) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Import Artifact")

            Button(action: { startNewArtifact() }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS, weight: .semibold))
                    Text("New Artifacts")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.accent)
                )
            }
            .buttonStyle(.plain)
            .help("Start a new artifact")

            Button(action: { loadArtifacts() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    // MARK: - Conversation (chat-first)

    private var conversationView: some View {
        HSplitView {
            if showLibrary {
                librarySidebar
                    .frame(minWidth: 200, idealWidth: 240, maxWidth: 320)
            }

            chatColumn
                .frame(minWidth: 320)

            if !liveContent.isEmpty {
                livePreviewPane
                    .frame(minWidth: 560, idealWidth: 880)
            }
        }
    }

    private var librarySidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Text("Library")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingXS)
            Rectangle().fill(theme.separator).frame(height: 1)

            List(filteredArtifacts, selection: $selectedArtifact) { artifact in
                artifactRow(artifact).tag(artifact)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: selectedArtifact) { sel in
                guard let sel = sel else { return }
                liveType = sel.type
                liveKind = sel.kind
                liveName = sel.name
                loadContent(for: sel)
            }
            .onChange(of: selectedContent) { c in
                if let c = c { liveContent = c }
            }
        }
    }

    private var chatColumn: some View {
        VStack(spacing: 0) {
            chatCategoryBar
            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: theme.spacingS) {
                        if chatMessages.isEmpty {
                            emptyConversationState
                        }
                        ForEach(chatMessages) { msg in
                            chatBubble(msg).id(msg.id)
                        }
                        if chatGenerating {
                            HStack {
                                Text("Generating…")
                                    .font(.system(size: theme.footnoteSize))
                                    .foregroundStyle(theme.textTertiary)
                                Spacer()
                            }
                            .padding(.horizontal, theme.spacingL)
                        }
                    }
                    .padding(theme.spacingL)
                }
                .onChange(of: chatMessages.count) { _ in
                    if let last = chatMessages.last {
                        withAnimation(.easeOut(duration: theme.animationFast)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Rectangle().fill(theme.separator).frame(height: 1)
            chatInputBar
            Spacer()
        }
    }

    private var chatCategoryBar: some View {
        HStack(spacing: theme.spacingS) {
            Menu {
                ForEach(ArtifactKind.allCases, id: \.self) { kind in
                    Button(action: {
                        liveKind = kind
                        liveType = defaultType(for: kind)
                    }) {
                        Label(kind.label, systemImage: kind.icon)
                    }
                }
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: liveKind.icon)
                        .foregroundStyle(liveKind.color)
                    Text(liveKind.label)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.horizontal, theme.spacingS)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.groupBg)
                )
            }
            .menuStyle(.borderlessButton)

            Spacer()

            if !liveContent.isEmpty {
                Button(action: { saveLiveArtifact() }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(theme.accent)
                        )
                }
                .buttonStyle(.plain)
                .help("Save to library")
            }

            Button(action: { showLibrary.toggle() }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(showLibrary ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Toggle library")
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    private var emptyConversationState: some View {
        VStack(spacing: theme.spacingL) {
            VStack(spacing: theme.spacingS) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.textTertiary)
                Text("What will you build?")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text("Pick a template to start, then describe what you want through conversation.")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacingM), count: 3),
                spacing: theme.spacingM
            ) {
                ForEach(artifactTemplates) { template in
                    emptyTemplateTile(template)
                }
            }
            .padding(.horizontal, theme.spacingL)
        }
        .padding(.vertical, theme.spacingL)
        .frame(maxWidth: .infinity)
    }

    private func emptyTemplateTile(_ template: ArtifactTemplate) -> some View {
        let isHovered = hoveredTemplateId == template.id
        let color = template.kind.color
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            Image(systemName: template.icon)
                .font(.system(size: theme.iconL))
                .foregroundStyle(color)
            Text(template.name)
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
            Text(template.description)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.spacingM)
        .frame(minHeight: 96)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(isHovered ? theme.surfaceElevated : theme.groupBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(isHovered ? color.opacity(0.5) : theme.groupBorder, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredTemplateId = hovering ? template.id : nil
        }
        .onTapGesture {
            selectTemplate(template)
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }

    private func selectTemplate(_ template: ArtifactTemplate) {
        selectedTemplate = template
        liveKind = template.kind
        liveType = template.type
        liveName = template.name
        liveContent = ""
        chatInput = ""
        chatError = nil
        if !template.defaultContent.isEmpty {
            liveContent = template.defaultContent
        }
        var sysMsg = "You're building a \(template.kind.label) artifact (\(template.name)). Describe what you want and I'll generate it through conversation."
        chatMessages = [ArtifactChatMessage(role: "system", content: sysMsg)]
        artifactsLog.info("Template selected: \(template.id), engineOnline=\(engineOnline)")
    }

    private func startNewArtifact() {
        chatMessages = []
        liveContent = ""
        chatInput = ""
        selectedTemplate = nil
        chatError = nil
        hoveredTemplateId = nil
        artifactsLog.info("New artifact session started")
    }

    private var chatInputBar: some View {
        VStack(spacing: theme.spacingS) {
            if let err = chatError {
                Text(err)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(.red)
                    .padding(.horizontal, theme.spacingL)
            }
            HStack(alignment: .bottom, spacing: theme.spacingS) {
                TextField("Describe the artifact you want to build…", text: $chatInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.textSize))
                    .lineLimit(1...5)
                    .onSubmit { sendChat() }

                FusionModelPicker(scene: .artifacts, selection: $selectedModel, models: agentBridge.models, onChange: { id in
                    artifactsLog.info("Artifacts model selected: \(id)")
                })

                VoiceInputButton(voice: voiceInput, text: $chatInput, onSend: sendChat)

                Button(action: { sendChat() }) {
                    Image(systemName: chatGenerating ? "stop.fill" : "arrow.up.circle.fill")
                        .font(.system(size: theme.iconL))
                        .foregroundStyle(chatGenerating ? theme.textTertiary : theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(chatInput.trimmingCharacters(in: .whitespaces).isEmpty && !chatGenerating)
                .help(chatGenerating ? "Stop" : "Send")
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
            .background(theme.groupBg)
        }
    }

    private func chatBubble(_ msg: ArtifactChatMessage) -> some View {
        let isUser = msg.role == "user"
        let isSystem = msg.role == "system"
        return HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: theme.spacingXS) {
                Text(isUser ? "You" : (isSystem ? "System" : "Assistant"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                Text(msg.content)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .padding(theme.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(isUser ? theme.accent.opacity(0.15) : (isSystem ? theme.accent.opacity(0.08) : theme.groupBg))
                    )
            }
            if !isUser && !isSystem { Spacer(minLength: 40) }
        }
    }

    private var livePreviewPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if !liveName.isEmpty {
                    Text(liveName)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingXS)
            Rectangle().fill(theme.separator).frame(height: 1)

            if liveType == "html" {
                HTMLPreviewView(htmlContent: liveContent)
            } else {
                ScrollView {
                    Text(liveContent)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .textSelection(.enabled)
                        .padding(theme.spacingM)
                }
            }
        }
    }

    private func defaultType(for kind: ArtifactKind) -> String {
        switch kind {
        case .document: return "markdown"
        case .code: return "code"
        default: return "html"
        }
    }

    private func chatSystemPrompt() -> String {
        return """
        You are an artifact creator. When the user describes what they want, generate the complete artifact. \
        Output format: \(liveType). \
        Output ONLY the artifact content (a complete \(liveType) document), no explanations, no markdown fences.
        """
    }

    private func extractArtifactContent(from response: String) -> String {
        var content = response
        if content.hasPrefix("```") {
            if let firstNewline = content.firstIndex(of: "\n") {
                content = String(content[firstNewline...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if content.hasSuffix("```") {
                content = String(content.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return content
    }

    private func sendChat() {
        if voiceInput.isRecording {
            let transcript = voiceInput.stopRecording()
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                chatInput += (chatInput.isEmpty ? "" : " ") + trimmed
            }
        }
        let prompt = chatInput.trimmingCharacters(in: .whitespaces)
        guard !prompt.isEmpty else { return }
        chatInput = ""
        chatMessages.append(ArtifactChatMessage(role: "user", content: prompt))
        chatGenerating = true
        chatError = nil

        // Pre-check MLX availability before streaming
        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        if baseURL.isEmpty {
            chatError = "MLX not configured. Please set up MLX in Settings first."
            chatGenerating = false
            artifactsLog.error("sendChat: MLX baseURL empty")
            return
        }

        // Callers: ArtifactsPanel.sendChat → agentBridge.inferStream. Affected API: inferStream [[String:Any]]. Data: chatMessages.
        var messages: [[String: Any]] = [["role": "system", "content": chatSystemPrompt()]]
        for msg in chatMessages where msg.role != "system" {
            messages.append(["role": msg.role, "content": msg.content])
        }

        let assistantId = UUID().uuidString
        chatMessages.append(ArtifactChatMessage(id: assistantId, role: "assistant", content: ""))

        Task {
            do {
                let artifactsModel = selectedModel.isEmpty ? FusionConfig.shared.defaultModel(for: .artifacts) : selectedModel
                artifactsLog.info("Artifacts stream model: \(artifactsModel.isEmpty ? "(mlx default)" : artifactsModel)")
                let fullResp = try await agentBridge.inferStream(
                    messages: messages,
                    model: artifactsModel,
                    temperature: 0.7,
                    maxTokens: 4096,
                    onToken: { token in
                        if let idx = self.chatMessages.firstIndex(where: { $0.id == assistantId }) {
                            self.chatMessages[idx].content += token
                        }
                    }
                )
                let content = extractArtifactContent(from: fullResp)
                if !content.isEmpty { liveContent = content }
                artifactsLog.info("Artifacts stream done: \(content.count) chars")
            } catch {
                chatError = "Generation failed: \(error.localizedDescription)"
                artifactsLog.error("sendChat stream: \(error)")
            }
            chatGenerating = false
        }
    }

    private func saveLiveArtifact() {
        guard !liveContent.isEmpty else { return }
        Task {
            do {
                _ = try await ipcClient.artifactCreate(
                    sessionId: sessionId,
                    name: liveName.isEmpty ? "Artifact" : liveName,
                    type: liveType,
                    kind: liveKind.rawValue,
                    content: liveContent,
                    projectId: FusionProjectManager.shared.activeProject?.id
                )
                artifactsLog.info("Saved live artifact: \(self.liveName)")
                loadArtifacts()
                chatMessages.append(ArtifactChatMessage(role: "system", content: "Artifact saved to library."))
            } catch {
                chatError = "Save failed: \(error.localizedDescription)"
                artifactsLog.error("saveLiveArtifact: \(error)")
            }
        }
    }

    // MARK: - Artifact List

    private var filteredArtifacts: [ArtifactModel] {
        if searchText.isEmpty { return artifacts }
        return artifacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.type.localizedCaseInsensitiveContains(searchText) ||
            $0.kind.label.localizedCaseInsensitiveContains(searchText) ||
            ($0.summary?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var artifactList: some View {
        HSplitView {
            List(filteredArtifacts, selection: $selectedArtifact) { artifact in
                artifactRow(artifact)
                    .tag(artifact)
            }
            .frame(minWidth: 240)

            if let selected = selectedArtifact {
                artifactDetail(selected)
            } else {
                VStack {
                    Spacer()
                    Text("Select an artifact")
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .frame(minWidth: 300)
            }
        }
    }

    private func artifactRow(_ artifact: ArtifactModel) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: artifact.kind.icon)
                .font(.system(size: theme.iconS))
                .foregroundStyle(artifact.kind.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.name)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)

                HStack(spacing: theme.spacingXS) {
                    Text(artifact.kind.label.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(artifact.kind.color.opacity(0.15))
                        )

                    Text("v\(artifact.currentVersion)")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)

                    Text("\(artifact.tokenCount) tok")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail

    private func artifactDetail(_ artifact: ArtifactModel) -> some View {
        VStack(spacing: 0) {
            detailHeader(artifact)
            Rectangle().fill(theme.separator).frame(height: 1)

            if let content = selectedContent {
                contentPreview(content, type: artifact.type)
            } else {
                Spacer()
                ProgressView("Loading content...")
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
        }
        .frame(minWidth: 300)
        .onAppear { loadContent(for: artifact) }
        .onChange(of: artifact.id) { _ in loadContent(for: artifact) }
    }

    @ViewBuilder
    private func contentPreview(_ content: String, type: String) -> some View {
        switch type.lowercased() {
        case "html", "react":
            HTMLPreviewView(htmlContent: content)
        default:
            ScrollView {
                Text(content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .padding(theme.spacingL)
            }
        }
    }

    private func detailHeader(_ artifact: ArtifactModel) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: artifact.kind.icon)
                .foregroundStyle(artifact.kind.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.name)
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                if let summary = artifact.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("v\(artifact.currentVersion)")
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Button(action: { showExportSheet = true }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Export")

            Button(action: { showEditSheet = true }) {
                Image(systemName: "pencil")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Edit Content")

            Button(action: { showVersionSheet = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Version History")

            Button(action: { deleteArtifact(artifact) }) {
                Image(systemName: "trash")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    // MARK: - Empty / Error

    private var emptyState: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()

            Image(systemName: "cube.box")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)

            Text("What will you build with artifacts?")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Text("If you can dream it, you can build it. Take apps, games, templates, and tools from thought to reality.")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if !engineOnline {
                Text("Artifacts engine offline — start with: fusion-artifacts-engine start")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(.orange)
            }

            HStack(spacing: theme.spacingM) {
                Button(action: { showTemplatePicker = true }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "plus")
                            .font(.system(size: theme.iconS))
                        Text("Create")
                            .font(.system(size: theme.textSize, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                }
                .buttonStyle(.plain)

                Button(action: { showImportSheet = true }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: theme.iconS))
                        Text("Import")
                            .font(.system(size: theme.textSize, weight: .medium))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .stroke(theme.accent, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text(msg)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Button("Retry") { loadArtifacts() }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
        }
    }

    // MARK: - Data Loading

    private func checkEngineAndLoad() {
        Task {
            do {
                engineOnline = try await ipcClient.artifactPing()
                artifactsLog.info("Artifacts engine online: \(self.engineOnline)")
                if engineOnline { loadArtifacts() }
            } catch {
                engineOnline = false
                artifactsLog.error("Artifacts engine ping failed: \(error)")
            }
        }
    }

    private func loadArtifacts() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let projectId = FusionProjectManager.shared.activeProject?.id
                let result = try await ipcClient.artifactList(sessionId: sessionId, projectId: projectId)
                let items = result["artifacts"] as? [[String: Any]] ?? []
                var parsed: [ArtifactModel] = []
                for item in items {
                    if let model = parseArtifactModel(from: item) {
                        parsed.append(model)
                    }
                }
                artifacts = parsed
                artifactsLog.info("Loaded \(parsed.count) artifacts")
            } catch {
                errorMessage = "Failed to load artifacts: \(error.localizedDescription)"
                artifactsLog.error("loadArtifacts: \(error)")
            }
            isLoading = false
        }
    }

    private func loadContent(for artifact: ArtifactModel) {
        selectedContent = nil
        Task {
            do {
                let result = try await ipcClient.artifactGetContent(artifactId: artifact.id)
                if let content = result["content"] as? String {
                    selectedContent = content
                }
            } catch {
                selectedContent = "Error loading content: \(error.localizedDescription)"
                artifactsLog.error("loadContent: \(error)")
            }
        }
    }

    private func deleteArtifact(_ artifact: ArtifactModel) {
        Task {
            do {
                _ = try await ipcClient.artifactDelete(artifactId: artifact.id)
                artifacts.removeAll { $0.id == artifact.id }
                if selectedArtifact?.id == artifact.id {
                    selectedArtifact = nil
                    selectedContent = nil
                }
                artifactsLog.info("Deleted artifact \(artifact.id)")
            } catch {
                errorMessage = "Failed to delete: \(error.localizedDescription)"
                artifactsLog.error("deleteArtifact: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func parseArtifactModel(from dict: [String: Any]) -> ArtifactModel? {
        guard let id = dict["id"] as? String,
              let name = dict["name"] as? String,
              let type = dict["type"] as? String else { return nil }
        let kindRaw = dict["kind"] as? String ?? kindFallback(for: type)
        let kind = ArtifactKind(rawValue: kindRaw) ?? kindFallbackEnum(for: type)
        let version = dict["current_version"] as? Int ?? 1
        let tokens = dict["token_count"] as? Int ?? 0
        let summary = dict["summary"] as? String
        let updatedAt: Date
        if let ts = dict["updated_at"] as? Double {
            updatedAt = Date(timeIntervalSince1970: ts)
        } else {
            updatedAt = Date()
        }
        return ArtifactModel(id: id, name: name, type: type, kind: kind, currentVersion: version,
                             tokenCount: tokens, summary: summary, updatedAt: updatedAt)
    }

    private func kindFallback(for type: String) -> String {
        switch type.lowercased() {
        case "html", "react": return "app"
        case "markdown": return "document"
        case "code": return "code"
        case "data": return "tool"
        default: return "code"
        }
    }

    private func kindFallbackEnum(for type: String) -> ArtifactKind {
        ArtifactKind(rawValue: kindFallback(for: type)) ?? .code
    }

}

// MARK: - HTMLPreviewView

struct HTMLPreviewView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - ArtifactTemplate

struct ArtifactTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let type: String
    let kind: ArtifactKind
    let defaultContent: String
}

private let artifactTemplates: [ArtifactTemplate] = [
    ArtifactTemplate(
        id: "apps-and-websites",
        name: "Apps and websites",
        icon: "globe",
        description: "A new interactive artifact for a website, app surface, or product workflow.",
        type: "html",
        kind: .app,
        defaultContent: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n  <title>My App</title>\n  <style>\n    body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; }\n  </style>\n</head>\n<body>\n  <h1>Hello World</h1>\n  <p>Start building your app here.</p>\n</body>\n</html>"
    ),
    ArtifactTemplate(
        id: "documents-and-templates",
        name: "Documents and templates",
        icon: "doc.text",
        description: "A structured artifact for a document, repeatable template, or formatted brief.",
        type: "markdown",
        kind: .document,
        defaultContent: "# Document Title\n\n## Overview\n\nStart writing your document here.\n\n## Details\n\n- Point 1\n- Point 2\n- Point 3\n\n## Summary\n\nTBD"
    ),
    ArtifactTemplate(
        id: "games",
        name: "Games",
        icon: "gamecontroller",
        description: "A playable artifact for a game, simulation, or interactive challenge.",
        type: "html",
        kind: .game,
        defaultContent: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>My Game</title>\n  <style>\n    canvas { border: 1px solid #333; display: block; margin: 20px auto; }\n  </style>\n</head>\n<body>\n  <h1 style=\"text-align:center\">Game</h1>\n  <canvas id=\"canvas\" width=\"480\" height=\"320\"></canvas>\n  <script>\n    const canvas = document.getElementById('canvas');\n    const ctx = canvas.getContext('2d');\n    ctx.fillStyle = '#007AFF';\n    ctx.fillRect(10, 10, 50, 50);\n  </script>\n</body>\n</html>"
    ),
    ArtifactTemplate(
        id: "productivity-tools",
        name: "Productivity tools",
        icon: "chart.bar",
        description: "A utility artifact for planning, tracking, calculating, or repeatable work.",
        type: "html",
        kind: .tool,
        defaultContent: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>Productivity Tool</title>\n  <style>\n    body { font-family: -apple-system, sans-serif; padding: 20px; }\n    input, button { padding: 8px 12px; margin: 4px; }\n  </style>\n</head>\n<body>\n  <h1>Tool</h1>\n  <input type=\"text\" placeholder=\"Enter value...\">\n  <button onclick=\"alert('Done')\">Process</button>\n</body>\n</html>"
    ),
    ArtifactTemplate(
        id: "creative-projects",
        name: "Creative projects",
        icon: "paintbrush",
        description: "A visual or expressive artifact for creative exploration and presentation.",
        type: "html",
        kind: .template,
        defaultContent: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>Creative Project</title>\n  <style>\n    body { margin: 0; overflow: hidden; background: #1a1a2e; }\n    canvas { display: block; }\n  </style>\n</head>\n<body>\n  <canvas id=\"canvas\"></canvas>\n  <script>\n    const c = document.getElementById('canvas');\n    const ctx = c.getContext('2d');\n    c.width = window.innerWidth;\n    c.height = window.innerHeight;\n    ctx.fillStyle = '#e94560';\n    ctx.beginPath();\n    ctx.arc(c.width/2, c.height/2, 80, 0, Math.PI*2);\n    ctx.fill();\n  </script>\n</body>\n</html>"
    ),
    ArtifactTemplate(
        id: "quiz-or-survey",
        name: "Quiz or survey",
        icon: "questionmark.circle",
        description: "A question-led artifact for collecting answers, testing knowledge, or guiding choices.",
        type: "html",
        kind: .template,
        defaultContent: "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n  <meta charset=\"UTF-8\">\n  <title>Quiz</title>\n  <style>\n    body { font-family: -apple-system, sans-serif; padding: 20px; max-width: 600px; margin: auto; }\n    .question { margin: 16px 0; padding: 12px; border: 1px solid #ddd; border-radius: 8px; }\n    label { display: block; padding: 4px 0; }\n  </style>\n</head>\n<body>\n  <h1>Quiz</h1>\n  <div class=\"question\">\n    <p>Question 1?</p>\n    <label><input type=\"radio\" name=\"q1\"> Option A</label>\n    <label><input type=\"radio\" name=\"q1\"> Option B</label>\n    <label><input type=\"radio\" name=\"q1\"> Option C</label>\n  </div>\n  <button onclick=\"alert('Submitted!')\">Submit</button>\n</body>\n</html>"
    ),
    ArtifactTemplate(
        id: "start-from-scratch",
        name: "Start from scratch",
        icon: "pencil.and.outline",
        description: "A blank artifact canvas ready for a custom idea.",
        type: "code",
        kind: .app,
        defaultContent: ""
    )
]

// MARK: - TemplatePickerSheet

struct TemplatePickerSheet: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let onSelect: (ArtifactTemplate) -> Void

    @State private var hoveredTemplate: String?
    @State private var selectedId: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose a Template")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingXL)
            .padding(.top, theme.spacingL)
            .padding(.bottom, theme.spacingS)

            Text("Let's get cooking! Pick an artifact category or start building your idea from scratch.")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingXL)
                .padding(.bottom, theme.spacingL)

            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacingM), count: 4),
                    spacing: theme.spacingM
                ) {
                    ForEach(artifactTemplates) { template in
                        templateCard(template)
                    }
                }
                .padding(theme.spacingXL)
            }

            if let selId = selectedId, let sel = artifactTemplates.first(where: { $0.id == selId }) {
                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textSecondary)
                    Button(action: {
                        artifactsLog.info("Template confirmed: \(sel.id)")
                        onSelect(sel)
                    }) {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: theme.iconS))
                            Text("Continue")
                                .font(.system(size: theme.textSize, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                .fill(theme.accent)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, theme.spacingXL)
                .padding(.vertical, theme.spacingM)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 640, height: 480)
        .background(theme.contentBg)
        .animation(.easeInOut(duration: theme.animationFast), value: selectedId)
    }

    private func templateCard(_ template: ArtifactTemplate) -> some View {
        let isHovered = hoveredTemplate == template.id
        let isSelected = selectedId == template.id
        let isOtherSelected = selectedId != nil && !isSelected
        let color = template.kind.color

        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: template.icon)
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(isHovered ? 2 : 0))
                    .scaleEffect(isHovered ? 1.05 : 1.0)

                Spacer()
            }

            Text(template.name)
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)

            Text(template.description)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.spacingM)
        .frame(minHeight: 112)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(isSelected ? color.opacity(0.08) : (isHovered ? theme.surfaceElevated : theme.groupBg))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(isSelected ? color : (isHovered ? color.opacity(0.4) : theme.groupBorder),
                        lineWidth: isSelected ? 2 : 1)
        )
        .opacity(isOtherSelected ? 0.5 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredTemplate = hovering ? template.id : nil
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: theme.animationFast)) {
                selectedId = isSelected ? nil : template.id
            }
            artifactsLog.info("Template \(isSelected ? "deselected" : "selected"): \(template.id)")
        }
        .animation(.easeInOut(duration: 0.3), value: isHovered)
    }
}

// MARK: - ArtifactCreateChatSheet

struct ArtifactCreateChatSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @EnvironmentObject var agentBridge: AgentBridge
    @Environment(\.dismiss) private var dismiss

    let sessionId: String
    let template: ArtifactTemplate
    let onComplete: (ArtifactModel?) -> Void

    @State private var userPrompt = ""
    @State private var chatMessages: [ChatMessage] = []
    @State private var generatedContent = ""
    @State private var artifactName = ""
    @State private var isGenerating = false
    @State private var showPreview = false
    @State private var showManualEdit = false
    @State private var errorMessage: String?

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: String
        let content: String
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)

            if showPreview {
                previewArea
            } else {
                chatArea
            }

            Rectangle().fill(theme.separator).frame(height: 1)
            inputBar
        }
        .frame(width: 680, height: 540)
        .background(theme.contentBg)
        .onAppear {
            artifactName = template.name
            chatMessages.append(ChatMessage(
                role: "system",
                content: "You are creating a \(template.kind.label) artifact. Describe what you want to build and I'll generate it for you."
            ))
        }
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: template.kind.icon)
                .foregroundStyle(template.kind.color)
            Text(template.name)
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Spacer()

            if !generatedContent.isEmpty {
                Button(action: { showPreview.toggle() }) {
                    Image(systemName: showPreview ? "bubble.left.and.bubble.right" : "eye")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(showPreview ? "Show Chat" : "Preview")
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacingS) {
                    ForEach(chatMessages) { msg in
                        chatBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(theme.spacingL)
            }
            .onChange(of: chatMessages.count) { _ in
                if let last = chatMessages.last {
                    withAnimation(.easeOut(duration: theme.animationFast)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func chatBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == "user"
        return HStack {
            if isUser { Spacer() }
            VStack(alignment: isUser ? .trailing : .leading, spacing: theme.spacingXS) {
                Text(isUser ? "You" : "Assistant")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                Text(msg.content)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .padding(theme.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(isUser ? theme.accent.opacity(0.15) : theme.groupBg)
                    )
            }
            if !isUser { Spacer() }
        }
    }

    private var previewArea: some View {
        HSplitView {
            ScrollView {
                LazyVStack(spacing: theme.spacingS) {
                    ForEach(chatMessages) { msg in
                        chatBubble(msg)
                    }
                }
                .padding(theme.spacingL)
            }
            .frame(minWidth: 240)

            VStack(spacing: 0) {
                HStack {
                    Text("Preview")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)

                if template.type == "html" {
                    HTMLPreviewView(htmlContent: generatedContent)
                } else {
                    ScrollView {
                        Text(generatedContent)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                            .padding(theme.spacingM)
                    }
                }
            }
            .frame(minWidth: 280)
        }
    }

    private var inputBar: some View {
        VStack(spacing: theme.spacingS) {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(.red)
                    .padding(.horizontal, theme.spacingL)
            }

            HStack(spacing: theme.spacingS) {
                TextField("Describe what you want to build...", text: $userPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.textSize))
                    .onSubmit { generateArtifact() }

                if !generatedContent.isEmpty {
                    Button(action: { showManualEdit = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit Manually")
                    .popover(isPresented: $showManualEdit) {
                        ManualEditPopover(
                            name: $artifactName,
                            content: $generatedContent,
                            template: template
                        )
                    }
                }

                Button(action: { generateArtifact() }) {
                    Image(systemName: isGenerating ? "stop" : "arrow.up.circle.fill")
                        .font(.system(size: theme.iconL))
                        .foregroundStyle(isGenerating ? theme.textTertiary : theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(userPrompt.isEmpty && generatedContent.isEmpty)
                .help(isGenerating ? "Stop" : "Generate")

                if !generatedContent.isEmpty {
                    Button(action: { saveArtifact() }) {
                        Text("Create")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, theme.spacingXS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(theme.accent)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Save Artifact")
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingM)
        }
    }

    private func generateArtifact() {
        guard !userPrompt.isEmpty else { return }
        let prompt = userPrompt
        userPrompt = ""

        chatMessages.append(ChatMessage(role: "user", content: prompt))
        isGenerating = true
        errorMessage = nil

        let systemPrompt = buildSystemPrompt()
        // Callers: ArtifactsPanel.generateArtifact → agentBridge.infer. Affected API: infer [[String:Any]].
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        for msg in chatMessages where msg.role != "system" {
            messages.append(["role": msg.role, "content": msg.content])
        }

        Task {
            do {
                let artifactsModel = FusionConfig.shared.defaultModel(for: .artifacts)
                artifactsLog.info("Generate artifact model: \(artifactsModel.isEmpty ? "(mlx default)" : artifactsModel)")
                let response = try await agentBridge.infer(
                    messages: messages,
                    model: artifactsModel,
                    temperature: 0.7,
                    maxTokens: 4096
                )
                generatedContent = extractContent(from: response)
                chatMessages.append(ChatMessage(role: "assistant", content: response))
                artifactsLog.info("Generated artifact content: \(generatedContent.count) chars")
            } catch {
                let msg = (error as? BridgeError)?.userMessage ?? error.localizedDescription
                errorMessage = "Generation failed: \(msg)"
                artifactsLog.error("generateArtifact: \(error)")
            }
            isGenerating = false
        }
    }

    private func buildSystemPrompt() -> String {
        return """
        You are an artifact creator for a \(template.kind.label) category. \
        When the user describes what they want, generate the complete artifact content. \
        Output format: \(template.type). \
        Rules: Output ONLY the artifact content, no explanations or markdown fences. \
        For HTML artifacts, output a complete HTML document. \
        For markdown artifacts, output markdown. \
        For code artifacts, output the code.
        """
    }

    private func extractContent(from response: String) -> String {
        var content = response
        if content.hasPrefix("```") {
            if let firstNewline = content.firstIndex(of: "\n") {
                content = String(content[firstNewline...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if content.hasSuffix("```") {
                content = String(content.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return content
    }

    private func saveArtifact() {
        Task {
            do {
                _ = try await ipcClient.artifactCreate(
                    sessionId: sessionId,
                    name: artifactName.isEmpty ? template.name : artifactName,
                    type: template.type,
                    kind: template.kind.rawValue,
                    content: generatedContent,
                    projectId: FusionProjectManager.shared.activeProject?.id
                )
                artifactsLog.info("Created artifact from chat: \(self.artifactName)")
                onComplete(nil)
                dismiss()
            } catch {
                errorMessage = "Save failed: \(error.localizedDescription)"
                artifactsLog.error("saveArtifact: \(error)")
            }
        }
    }
}

// MARK: - ManualEditPopover

struct ManualEditPopover: View {
    @Environment(\.studioTheme) private var theme
    @Binding var name: String
    @Binding var content: String
    let template: ArtifactTemplate

    var body: some View {
        VStack(spacing: theme.spacingM) {
            TextField("Artifact name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $content)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 200)
        }
        .padding(theme.spacingM)
        .frame(width: 400, height: 300)
    }
}

// MARK: - CreateArtifactSheet (manual fallback)

struct CreateArtifactSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let sessionId: String
    let onComplete: (ArtifactModel?) -> Void

    @State private var name = ""
    @State private var type = "code"
    @State private var kind: ArtifactKind = .code
    @State private var content = ""
    @State private var summary = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let types = ["code", "markdown", "html", "react", "data"]

    init(sessionId: String, onComplete: @escaping (ArtifactModel?) -> Void) {
        self.sessionId = sessionId
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Create Artifact")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(types, id: \.self) { Text($0.capitalized) }
                }
                TextField("Summary (optional)", text: $summary)
                TextEditor(text: $content)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 200)
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Create") { createArtifact() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(name.isEmpty || (content.isEmpty && type != "code") || isCreating)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 480)
    }

    private func createArtifact() {
        isCreating = true
        errorMessage = nil
        Task {
            do {
                _ = try await ipcClient.artifactCreate(
                    sessionId: sessionId, name: name, type: type,
                    kind: kind.rawValue,
                    content: content, summary: summary.isEmpty ? nil : summary,
                    projectId: FusionProjectManager.shared.activeProject?.id
                )
                artifactsLog.info("Created artifact: \(self.name)")
                onComplete(nil)
                dismiss()
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
                artifactsLog.error("createArtifact: \(error)")
            }
            isCreating = false
        }
    }
}

// MARK: - EditContentSheet

struct EditContentSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let artifact: ArtifactModel
    let onComplete: (Bool) -> Void

    @State private var content = ""
    @State private var changeLog = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Edit: \(artifact.name)")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Form {
                TextEditor(text: $content)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 250)
                TextField("Change log (optional)", text: $changeLog)
            }
            .formStyle(.grouped)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Save New Version") { saveVersion() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(content.isEmpty || isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 440)
        .onAppear { loadCurrentContent() }
    }

    private func loadCurrentContent() {
        Task {
            do {
                let result = try await ipcClient.artifactGetContent(artifactId: artifact.id)
                if let c = result["content"] as? String { content = c }
            } catch {
                artifactsLog.error("loadCurrentContent: \(error)")
            }
        }
    }

    private func saveVersion() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                _ = try await ipcClient.artifactUpdate(
                    artifactId: artifact.id, content: content,
                    changeLog: changeLog.isEmpty ? nil : changeLog,
                    projectId: FusionProjectManager.shared.activeProject?.id
                )
                artifactsLog.info("Updated artifact \(self.artifact.id)")
                onComplete(true)
                dismiss()
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
                artifactsLog.error("saveVersion: \(error)")
            }
            isSaving = false
        }
    }
}

// MARK: - VersionHistorySheet

struct VersionHistorySheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let artifact: ArtifactModel

    @State private var versions: [ArtifactVersionModel] = []
    @State private var isLoading = true
    @State private var isRollingBack = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Version History: \(artifact.name)")
                    .font(.system(size: theme.titleSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
            }
            .padding(theme.spacingL)

            Rectangle().fill(theme.separator).frame(height: 1)

            if isLoading {
                Spacer()
                ProgressView("Loading versions...")
                Spacer()
            } else if versions.isEmpty {
                Spacer()
                Text("No versions found")
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                List(versions) { version in
                    versionRow(version)
                }
                .listStyle(.sidebar)
            }

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
                    .padding(theme.spacingS)
            }
        }
        .frame(width: 450, height: 400)
        .onAppear { loadVersions() }
    }

    private func versionRow(_ version: ArtifactVersionModel) -> some View {
        HStack(spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Text("v\(version.versionNum)")
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Text("\(version.tokenCount) tok")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    if version.versionNum == artifact.currentVersion {
                        Text("CURRENT")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 2).fill(theme.accent))
                    }
                }
                if let log = version.changeLog, !log.isEmpty {
                    Text(log)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                Text(version.createdAt, style: .date)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            if version.versionNum != artifact.currentVersion {
                Button("Rollback") { rollback(to: version.versionNum) }
                    .buttonStyle(.plain)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.accent)
                    .disabled(isRollingBack)
            }
        }
        .padding(.vertical, 2)
    }

    private func loadVersions() {
        isLoading = true
        Task {
            do {
                let result = try await ipcClient.artifactVersionList(artifactId: artifact.id)
                let items = result["versions"] as? [[String: Any]] ?? []
                var parsed: [ArtifactVersionModel] = []
                for v in items {
                    guard let verNum = v["version_num"] as? Int else { continue }
                    let id = v["id"] as? Int ?? verNum
                    let tokens = v["token_count"] as? Int ?? 0
                    let changeLog = v["change_log"] as? String
                    let createdAt: Date
                    if let ts = v["created_at"] as? Double {
                        createdAt = Date(timeIntervalSince1970: ts)
                    } else {
                        createdAt = Date()
                    }
                    parsed.append(ArtifactVersionModel(id: id, versionNum: verNum,
                                                       tokenCount: tokens, changeLog: changeLog, createdAt: createdAt))
                }
                versions = parsed
            } catch {
                errorMessage = "Failed to load versions: \(error.localizedDescription)"
                artifactsLog.error("loadVersions: \(error)")
            }
            isLoading = false
        }
    }

    private func rollback(to versionNum: Int) {
        isRollingBack = true
        Task {
            do {
                _ = try await ipcClient.artifactVersionRollback(
                    artifactId: artifact.id, targetVersion: versionNum
                )
                artifactsLog.info("Rolled back \(self.artifact.id) to v\(versionNum)")
                dismiss()
            } catch {
                errorMessage = "Rollback failed: \(error.localizedDescription)"
                artifactsLog.error("rollback: \(error)")
            }
            isRollingBack = false
        }
    }
}

// MARK: - ExportArtifactSheet

struct ExportArtifactSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let artifact: ArtifactModel

    @State private var exportedData: String?
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Export: \(artifact.name)")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if let data = exportedData {
                ScrollView {
                    Text(data)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .textSelection(.enabled)
                        .padding(theme.spacingM)
                }
                .frame(maxHeight: 300)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if exportedData != nil {
                    Button("Copy to Clipboard") {
                        if let data = exportedData {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(data, forType: .string)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                }
                Button("Export") { doExport() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(isExporting)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: exportedData != nil ? 480 : 200)
    }

    private func doExport() {
        isExporting = true
        errorMessage = nil
        Task {
            do {
                let result = try await ipcClient.artifactExport(artifactId: artifact.id)
                if let data = result["data"] as? [String: Any] {
                    exportedData = String(
                        data: try JSONSerialization.data(withJSONObject: data,
                                                          options: [.prettyPrinted, .sortedKeys]),
                        encoding: .utf8
                    )
                }
            } catch {
                errorMessage = "Export failed: \(error.localizedDescription)"
                artifactsLog.error("doExport: \(error)")
            }
            isExporting = false
        }
    }
}

// MARK: - ImportArtifactSheet

struct ImportArtifactSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    let onComplete: (Bool) -> Void

    @State private var importText = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Import Artifact")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Text("Paste exported artifact JSON below:")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)

            TextEditor(text: $importText)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 200)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Import") { doImport() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(theme.accent)
                    )
                    .disabled(importText.isEmpty || isImporting)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 380)
    }

    private func doImport() {
        isImporting = true
        errorMessage = nil
        guard let jsonData = importText.data(using: .utf8),
              let dataDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            errorMessage = "Invalid JSON"
            isImporting = false
            return
        }
        Task {
            do {
                _ = try await ipcClient.artifactImport(data: dataDict)
                artifactsLog.info("Imported artifact successfully")
                onComplete(true)
                dismiss()
            } catch {
                errorMessage = "Import failed: \(error.localizedDescription)"
                artifactsLog.error("doImport: \(error)")
            }
            isImporting = false
        }
    }
}

// MARK: - InjectPreviewSheet

struct InjectPreviewSheet: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient
    @Environment(\.dismiss) private var dismiss

    @State private var messagesText = ""
    @State private var injectedMessages: [[String: Any]]?
    @State private var totalTokens: Int?
    @State private var isSafe: Bool?
    @State private var currentTokens: Int?
    @State private var remainingTokens: Int?
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var mode = 0

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Inject / Safety Preview")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Picker("Mode", selection: $mode) {
                Text("Inject").tag(0)
                Text("Safety Check").tag(1)
            }
            .pickerStyle(.segmented)

            TextEditor(text: $messagesText)
                .font(.system(size: 11, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(
                    Group {
                        if messagesText.isEmpty {
                            Text("Paste messages JSON array here...")
                                .foregroundStyle(theme.textTertiary)
                                .padding(.top, 8).padding(.leading, 4)
                        }
                    }, alignment: .topLeading
                )

            Button(mode == 0 ? "Run Inject" : "Check Safety") { runCheck() }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .fill(theme.accent)
                )
                .disabled(messagesText.isEmpty || isRunning)

            if let error = errorMessage {
                Text(error).foregroundStyle(.red).font(.system(size: theme.footnoteSize))
            }

            if let safe = isSafe, mode == 1 {
                HStack(spacing: theme.spacingM) {
                    Label(safe ? "Safe" : "Unsafe",
                          systemImage: safe ? "checkmark.circle" : "exclamationmark.triangle")
                        .foregroundStyle(safe ? .green : .red)
                    if let current = currentTokens, let remaining = remainingTokens {
                        Text("Current: \(current) tok | Remaining: \(remaining) tok")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            if let total = totalTokens, mode == 0 {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    Text("Total tokens: \(total) | Safe: \(isSafe ?? false ? "Yes" : "No")")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    if let msgs = injectedMessages {
                        Text("Injected \(msgs.count) messages")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 460)
    }

    private func runCheck() {
        isRunning = true
        errorMessage = nil
        guard let data = messagesText.data(using: .utf8),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            errorMessage = "Invalid messages JSON"
            isRunning = false
            return
        }
        Task {
            do {
                if mode == 0 {
                    let result = try await ipcClient.artifactInject(messages: messages)
                    injectedMessages = result["messages"] as? [[String: Any]]
                    totalTokens = result["total_tokens"] as? Int
                    isSafe = result["safe"] as? Bool
                } else {
                    let result = try await ipcClient.artifactCheckSafety(messages: messages)
                    isSafe = result["safe"] as? Bool
                    currentTokens = result["current_tokens"] as? Int
                    remainingTokens = result["remaining_tokens"] as? Int
                }
            } catch {
                errorMessage = "Failed: \(error.localizedDescription)"
                artifactsLog.error("runCheck: \(error)")
            }
            isRunning = false
        }
    }
}

// MARK: - SessionPickerView

struct SessionPickerView: View {
    @Environment(\.studioTheme) private var theme
    @Binding var currentSession: String
    @State private var newSession = ""

    private let presetSessions = ["default", "workspace", "sandbox"]

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Text("Switch Session")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            ForEach(presetSessions, id: \.self) { session in
                HStack {
                    Text(session)
                        .foregroundStyle(theme.text)
                    Spacer()
                    if session == currentSession {
                        Image(systemName: "checkmark")
                            .foregroundStyle(theme.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { currentSession = session }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
            }

            Divider()

            HStack {
                TextField("Custom session", text: $newSession)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !newSession.isEmpty {
                            currentSession = newSession
                            newSession = ""
                        }
                    }
                Button("Go") {
                    if !newSession.isEmpty {
                        currentSession = newSession
                        newSession = ""
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, theme.spacingM)
        }
        .padding(theme.spacingM)
        .frame(width: 220)
    }
}
