// Callers: RAGPipelineView (chat tab). API: RAGAPIClient.ask(). schema: KBAskResult. user instruction: "完成所有待办任务"

import SwiftUI
import os

struct KBChatView: View {
    var initialKBId: String = ""
    @StateObject private var client = RAGAPIClient.shared
    @EnvironmentObject private var agentBridge: AgentBridge
    @State private var selectedKBId: String = ""
    @State private var question = ""
    @State private var isAsking = false
    @State private var chatHistory: [ChatMessage] = []
    @State private var rewriteMode: String? = nil
    @State private var selectedModel: String = ""
    @StateObject private var voiceInput = VoiceInputManager()

    private let logger = Logger(subsystem: "com.fusion.studio", category: "KBChatView")

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: String
        let content: String
        let sources: [KBSource]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(I18nManager.shared.t(.kbc_label_kb) + ":").font(.caption)
                Picker(I18nManager.shared.t(.kbc_ph_select_kb), selection: $selectedKBId) {
                    Text(I18nManager.shared.t(.kbc_opt_not_selected)).tag("")
                    ForEach(client.knowledgeBases) { kb in
                        Text(kb.name).tag(kb.id)
                    }
                }
                .frame(maxWidth: 200)
                Spacer()
                Picker(I18nManager.shared.t(.kbc_label_rewrite), selection: $rewriteMode) {
                    Text(I18nManager.shared.t(.kbc_rewrite_off)).tag(String?.none)
                    Text("HyDE").tag(String?.some("hyde"))
                    Text(I18nManager.shared.t(.kbc_rewrite_expand)).tag(String?.some("expand"))
                    Text(I18nManager.shared.t(.kbc_rewrite_condense)).tag(String?.some("condense"))
                }
                .frame(maxWidth: 120)
            }
            .padding(8)
            Divider()

            if chatHistory.isEmpty {
                CenteredChatInput(
                    text: $question,
                    placeholder: I18nManager.shared.t(.kbc_ph_input_question),
                    isCentered: true,
                    onSend: submitQuestion,
                    trailingContent: AnyView(inputControls)
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(chatHistory) { msg in
                                ChatBubbleView(message: msg).id(msg.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: chatHistory.count) { _ in
                        if let last = chatHistory.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()

                CenteredChatInput(
                    text: $question,
                    placeholder: I18nManager.shared.t(.kbc_ph_input_question),
                    isCentered: false,
                    onSend: submitQuestion,
                    trailingContent: AnyView(inputControls)
                )
            }
        }
        .task {
            await client.listBases()
            if selectedKBId.isEmpty && !initialKBId.isEmpty {
                selectedKBId = initialKBId
                logger.info("KBChatView preselect KB: \(initialKBId, privacy: .public)")
            }
        }
    }

    private var inputControls: some View {
        HStack(spacing: 8) {
            FusionModelPicker(scene: .chat, selection: $selectedModel, models: agentBridge.models, onChange: { id in
                logger.info("KB model selected: \(id)")
            })
            VoiceInputButton(voice: voiceInput, text: $question, onSend: submitQuestion)
        }
    }

    private func submitQuestion() {
        if voiceInput.isRecording {
            let transcript = voiceInput.stopRecording()
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                question += (question.isEmpty ? "" : " ") + trimmed
            }
        }
        guard !question.isEmpty, !selectedKBId.isEmpty else { return }
        let q = question
        question = ""
        chatHistory.append(ChatMessage(role: "user", content: q, sources: []))
        isAsking = true
        Task {
            let result = await client.ask(kbId: selectedKBId, question: q, topK: 5, rewriteMode: rewriteMode)
            isAsking = false
            if let result = result {
                chatHistory.append(ChatMessage(role: "assistant", content: result.answer, sources: result.sources))
            } else {
                chatHistory.append(ChatMessage(role: "assistant", content: I18nManager.shared.t(.kbc_msg_request_failed), sources: []))
            }
        }
    }
}

struct ChatBubbleView: View {
    let message: KBChatView.ChatMessage

    var body: some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .padding(10)
                .background(
                    message.role == "user"
                        ? Color.accentColor.opacity(0.15)
                        : Color(nsColor: .controlBackgroundColor)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if !message.sources.isEmpty {
                DisclosureGroup(String(format: I18nManager.shared.t(.kbc_label_sources), message.sources.count)) {
                    ForEach(Array(message.sources.enumerated()), id: \.offset) { idx, src in
                        HStack {
                            Image(systemName: "doc.text").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(src.docName).font(.caption).fontWeight(.medium)
                                Text(String(src.snippet.prefix(80)) + (src.snippet.count > 80 ? "..." : ""))
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(String(format: I18nManager.shared.t(.kbc_label_relevance_f), src.score))
                                    .font(.caption2).foregroundStyle(.blue)
                            }
                        }
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
    }
}
