// Callers: RAGPipelineView (chat tab). API: RAGAPIClient.ask(). schema: KBAskResult. user instruction: "完成所有待办任务"

import SwiftUI
import os

struct KBChatView: View {
    @StateObject private var client = RAGAPIClient.shared
    @State private var selectedKBId: String = ""
    @State private var question = ""
    @State private var isAsking = false
    @State private var chatHistory: [ChatMessage] = []
    @State private var rewriteMode: String? = nil

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
                Text("知识库:").font(.caption)
                Picker("选择知识库", selection: $selectedKBId) {
                    Text("未选择").tag("")
                    ForEach(client.knowledgeBases) { kb in
                        Text(kb.name).tag(kb.id)
                    }
                }
                .frame(maxWidth: 200)
                Spacer()
                Picker("查询重写", selection: $rewriteMode) {
                    Text("关闭").tag(String?.none)
                    Text("HyDE").tag(String?.some("hyde"))
                    Text("扩展").tag(String?.some("expand"))
                    Text("精简").tag(String?.some("condense"))
                }
                .frame(maxWidth: 120)
            }
            .padding(8)
            Divider()

            if chatHistory.isEmpty {
                CenteredChatInput(
                    text: $question,
                    placeholder: "输入问题...",
                    isCentered: true,
                    onSend: submitQuestion
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
                    placeholder: "输入问题...",
                    isCentered: false,
                    onSend: submitQuestion
                )
            }
        }
        .task {
            await client.listBases()
        }
    }

    private func submitQuestion() {
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
                chatHistory.append(ChatMessage(role: "assistant", content: "请求失败，请检查知识库服务是否运行", sources: []))
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
                DisclosureGroup("引用来源 (\(message.sources.count))") {
                    ForEach(Array(message.sources.enumerated()), id: \.offset) { idx, src in
                        HStack {
                            Image(systemName: "doc.text").foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(src.docName).font(.caption).fontWeight(.medium)
                                Text(String(src.snippet.prefix(80)) + (src.snippet.count > 80 ? "..." : ""))
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text("相关度: \(String(format: "%.2f", src.score))")
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
