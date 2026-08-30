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

struct ArtifactModel: Identifiable, Hashable, Decodable {
    let id: String
    let name: String
    let type: String
    let kind: ArtifactKind
    let currentVersion: Int
    let tokenCount: Int
    let summary: String?
    let updatedAt: Date

    // F-I4: custom init(from:) 保 kindFallback 宽容 (缺 kind 按 type 推断)。memberwise init 被 parseArtifactModel
    // + ArtifactSidebarCache 改调 decodeCodable 后无 caller, 抑制安全。updated_at Double(timestamp)→Date。
    enum ArtKeys: String, CodingKey {
        case id, name, type, kind, current_version, token_count, summary, updated_at
    }
    init(from decoder: Decoder) throws {
        let top = try decoder.container(keyedBy: ArtKeys.self)
        id = try top.decode(String.self, forKey: .id)
        name = try top.decode(String.self, forKey: .name)
        type = try top.decode(String.self, forKey: .type)
        let kindRaw = (try? top.decodeIfPresent(String.self, forKey: .kind)) ?? Self.kindFallback(for: type)
        kind = ArtifactKind(rawValue: kindRaw) ?? Self.kindFallbackEnum(for: type)
        currentVersion = (try? top.decodeIfPresent(Int.self, forKey: .current_version)) ?? 1
        tokenCount = (try? top.decodeIfPresent(Int.self, forKey: .token_count)) ?? 0
        summary = try? top.decodeIfPresent(String.self, forKey: .summary)
        if let ts = try? top.decodeIfPresent(Double.self, forKey: .updated_at) {
            updatedAt = Date(timeIntervalSince1970: ts)
        } else {
            updatedAt = Date()
        }
    }
    // F-I4: kindFallback 提升 static (parseArtifactModel + ArtifactSidebarCache 共用, 去重)。
    static func kindFallback(for type: String) -> String {
        switch type.lowercased() {
        case "html", "react": return "app"
        case "markdown": return "document"
        case "code": return "code"
        case "data": return "tool"
        default: return "code"
        }
    }
    static func kindFallbackEnum(for type: String) -> ArtifactKind {
        ArtifactKind(rawValue: kindFallback(for: type)) ?? .code
    }
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
            if let error = chatError {
                Text(error)
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

                FusionModelPicker(scene: .artifacts, selection: $selectedModel, models: agentBridge.mlxState.models, onChange: { id in
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
        // F-I4: Codable 强类型解码 (ArtifactModel.init(from:) 保 kindFallback + updated_at Double)。
        // 保留原 guard 语义: id/name/type 缺失 → 返 nil (caller continue)。
        return AgentBridge.decodeCodable(ArtifactModel.self, from: dict, context: "artifact")
    }

}

