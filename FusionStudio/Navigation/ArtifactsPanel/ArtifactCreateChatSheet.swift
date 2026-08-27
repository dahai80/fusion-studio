import SwiftUI
import WebKit
import os.log

private let artifactsLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactsPanel")

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

