import SwiftUI
import os.log

private let chatLog = Logger(subsystem: "com.fusion.studio", category: "ScienceChatView")

struct ScienceChatView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var scienceBridge: ScienceBridge
    @EnvironmentObject var scienceSSE: ScienceSSEClient
    @EnvironmentObject var agentBridge: AgentBridge
    @Binding var inputText: String
    @Binding var selectedPipeline: SciencePipelineTemplate?
    @State private var autoScroll: Bool = true
    @State private var selectedModel: String = ""
    @StateObject private var voiceInput = VoiceInputManager()

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Rectangle().fill(theme.separator).frame(height: 1)
            messageArea
            Rectangle().fill(theme.separator).frame(height: 1)
            chatInputBox
        }
        .background(theme.contentBg)
    }

    private var chatHeader: some View {
        HStack(spacing: theme.spacingS) {
            if let session = scienceBridge.currentSession {
                Text(session.title)
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
            } else {
                Text("Science Workbench")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
            }
            Spacer()

            if let session = scienceBridge.currentSession {
                actionButton(icon: "magnifyingglass", label: "Search") {
                    scienceBridge.searchPapers(sessionId: session.id, query: inputText) { _ in }
                }
                actionButton(icon: "chart.bar.xaxis", label: "Analyze") {
                    scienceBridge.analyzeData(sessionId: session.id, query: inputText) { _ in }
                }
                actionButton(icon: "chart.pie", label: "Visualize") {
                    scienceBridge.visualize(sessionId: session.id, query: inputText) { _ in }
                }
                actionButton(icon: "doc.text.magnifyingglass", label: "Review") {
                    scienceBridge.review(sessionId: session.id, query: inputText) { _ in }
                }
            }

            if scienceBridge.isConnected {
                StatusPill(status: .running, compact: true)
            } else {
                StatusPill(status: .stopped, compact: true)
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: theme.captionSize, weight: .medium))
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(theme.accent.opacity(0.10))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var messageArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacingM) {
                    if scienceBridge.messages.isEmpty && !scienceSSE.isStreaming {
                        welcomeContent
                    } else {
                        ForEach(scienceBridge.messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                        if scienceSSE.isStreaming {
                            streamingBubble
                                .id("streaming")
                        }
                    }
                }
                .padding(theme.spacingL)
            }
            .background(theme.contentBg)
            .onChange(of: scienceBridge.messages.count) {
                if autoScroll, let last = scienceBridge.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onReceive(scienceSSE.$streamingContent) { _ in
                if autoScroll && scienceSSE.isStreaming {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("streaming", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: theme.spacingL) {
            Spacer(minLength: 0)
            Image(systemName: "flask")
                .font(.system(size: 48))
                .foregroundStyle(theme.accent.opacity(0.3))
            Text("Science Workbench")
                .font(.system(size: theme.titleSize, weight: .bold))
                .foregroundStyle(theme.text)
            Text("Search papers, analyze data, generate visualizations,\nand write literature reviews with AI assistance.")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: theme.spacingS) {
                ForEach(sciencePipelineTemplates) { pipeline in
                    Button {
                        selectedPipeline = pipeline
                        inputText = pipeline.steps.joined(separator: " -> ")
                    } label: {
                        VStack(spacing: theme.spacingXS) {
                            Image(systemName: pipeline.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(theme.accent)
                            Text(pipeline.name)
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                        }
                        .padding(theme.spacingM)
                        .background(theme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                .stroke(theme.separator, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func messageBubble(_ msg: ScienceMessage) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            if msg.isUser { Spacer(minLength: 60) }
            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
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

                if let artifacts = msg.artifacts, !artifacts.isEmpty {
                    artifactsView(artifacts)
                }

                Text(Date(timeIntervalSince1970: msg.createdAt), style: .time)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textQuaternary)
            }
            if msg.isAssistant { Spacer(minLength: 60) }
        }
    }

    private func artifactsView(_ artifacts: [ScienceArtifact]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingS) {
                ForEach(artifacts) { artifact in
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: artifactIcon(artifact.type))
                            .font(.system(size: 11))
                            .foregroundStyle(theme.accent)
                        Text(artifact.title)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, theme.spacingS)
                    .padding(.vertical, theme.spacingXS)
                    .background(theme.accent.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func artifactIcon(_ type: String) -> String {
        switch type {
        case "figure": return "chart.bar"
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "paper": return "doc.text"
        default: return "square.dashed"
        }
    }

    private var streamingBubble: some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: theme.spacingS) {
                    ProgressView().controlSize(.small)
                    Text("Generating...")
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.text)
                }
                if !scienceSSE.streamingContent.isEmpty {
                    Text(scienceSSE.streamingContent)
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.text)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .fill(theme.surfaceSecondary)
            )
            Spacer(minLength: 60)
        }
    }

    private var chatInputBox: some View {
        VStack(spacing: 0) {
            SendableTextEditor(
                text: $inputText,
                placeholder: "Ask a research question...",
                font: .systemFont(ofSize: CGFloat(theme.textSize)),
                textColor: NSColor(theme.text),
                placeholderColor: NSColor(theme.textTertiary),
                maxHeight: 88,
                onSend: sendMessage,
                refocusTrigger: .constant(0)
            )
            .frame(minHeight: 36, idealHeight: 44, maxHeight: 88)
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingM)

            HStack(spacing: theme.spacingS) {
                if let pipeline = selectedPipeline {
                    HStack(spacing: 4) {
                        Image(systemName: pipeline.icon)
                            .font(.system(size: 10))
                        Text(pipeline.name)
                            .font(.system(size: theme.captionSize, weight: .medium))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.accent.opacity(0.12))
                    .clipShape(Capsule())
                    .onTapGesture { selectedPipeline = nil }
                }
                Spacer()
                FusionModelPicker(scene: .chat, selection: $selectedModel, models: agentBridge.models, onChange: { id in
                    chatLog.info("Science model selected: \(id)")
                })
                VoiceInputButton(voice: voiceInput, text: $inputText, onSend: sendMessage)
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.accent : theme.textQuaternary)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
        }
        .background(theme.inputBg)
    }

    private func sendMessage() {
        if voiceInput.isRecording {
            let transcript = voiceInput.stopRecording()
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                inputText += (inputText.isEmpty ? "" : " ") + trimmed
            }
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        guard let session = scienceBridge.currentSession else {
            scienceBridge.createSession(title: String(text.prefix(50))) { result in
                switch result {
                case .success(let session):
                    sendToSession(session.id, text: text)
                case .failure(let err):
                    chatLog.error("Auto-create session failed: \(err.localizedDescription)")
                }
            }
            return
        }
        sendToSession(session.id, text: text)
    }

    private func sendToSession(_ sessionId: String, text: String) {
        inputText = ""
        let userMsg = ScienceMessage(
            id: UUID().uuidString,
            sessionId: sessionId,
            role: "user",
            content: text,
            createdAt: Date().timeIntervalSince1970,
            artifacts: nil
        )
        scienceBridge.messages.append(userMsg)
        scienceBridge.fetchAudit(sessionId: sessionId)
        scienceSSE.streamChat(sessionId: sessionId, message: text)
        scienceBridge.sendChat(sessionId: sessionId, message: text) { _ in }
    }
}
