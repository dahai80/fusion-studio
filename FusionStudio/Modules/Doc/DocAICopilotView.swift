// Callers: DocView (HSplitView right pane).
// Affected API: DocBridge copilotCompleteURL/copilotRewriteURL/copilotCommandURL/buildCopilotRequest/ragEnhancedQuery/copilotRewrite/copilotTranslate/copilotSummarize/copilotExpand/fetchCopilotContext — SSE + REST /api/copilot/* + /api/rag/* endpoints.
// Data schemas: CopilotMessage (local), DocPage context from DocBridge, CopilotMode 7 modes.
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let copilotLog = Logger(subsystem: "com.fusion.studio", category: "DocAICopilot")

struct DocAICopilotView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: DocBridge
    @Binding var selectedPageId: String?
    @State private var chatMessages: [CopilotMessage] = []
    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var copilotMode: CopilotMode = .chat
    @State private var targetLang = "English"

    enum CopilotMode: String, CaseIterable {
        case chat = "对话"
        case command = "指令"
        case rag = "知识"
        case rewrite = "改写"
        case translate = "翻译"
        case summarize = "摘要"
        case expand = "扩展"
    }

    struct CopilotMessage: Identifiable {
        let id = UUID()
        var role: String
        var content: String
    }

    var body: some View {
        VStack(spacing: 0) {
            modeSelector
            Divider()
            messageList
            Divider()
            inputBar
        }
        .background(theme.surfacePrimary)
    }

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(CopilotMode.allCases, id: \.self) { mode in
                Button(action: { copilotMode = mode }) {
                    Text(mode.rawValue)
                        .font(.caption)
                        .fontWeight(copilotMode == mode ? .semibold : .regular)
                        .foregroundColor(copilotMode == mode ? theme.accent : theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(copilotMode == mode ? theme.surfaceSecondary : Color.clear)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if copilotMode == .translate {
                Picker("目标语言", selection: $targetLang) {
                    ForEach(["English", "中文", "日本語", "한국어", "Français", "Deutsch", "Español"], id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                .frame(width: 100)
                .font(.caption)
            }
            Button(action: { chatMessages.removeAll() }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("清空对话")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.surfaceSecondary)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(chatMessages) { msg in
                        messageBubble(msg)
                    }
                    if isStreaming {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("思考中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .id("streaming")
                    }
                }
                .padding(10)
            }
            .onChange(of: chatMessages.count) { _ in
                if let last = chatMessages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(_ msg: CopilotMessage) -> some View {
        HStack {
            if msg.role == "user" { Spacer() }
            VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 2) {
                Text(msg.content)
                    .font(.subheadline)
                    .foregroundColor(msg.role == "user" ? .white : .primary)
                    .padding(10)
                    .background(
                        msg.role == "user"
                            ? theme.accent
                            : theme.surfaceSecondary
                    )
                    .cornerRadius(10)
            }
            if msg.role == "assistant" { Spacer() }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                copilotMode == .chat ? "输入消息..." :
                copilotMode == .command ? "/command ..." :
                copilotMode == .rewrite ? "输入改写指令..." :
                copilotMode == .translate ? "输入文本翻译为\(targetLang)..." :
                copilotMode == .summarize ? "输入文本生成摘要..." :
                copilotMode == .expand ? "输入文本扩展内容..." :
                "? 知识检索...",
                text: $inputText,
                axis: .vertical
            )
            .lineLimit(1...5)
            .textFieldStyle(.plain)
            .font(.subheadline)
            .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title3)
                    .foregroundColor(isStreaming ? .secondary : theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(isStreaming || inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(10)
        .background(theme.surfaceSecondary)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        chatMessages.append(CopilotMessage(role: "user", content: text))
        inputText = ""
        isStreaming = true

        switch copilotMode {
        case .chat:
            sendChat(text)
        case .command:
            sendCommand(text)
        case .rag:
            sendRAGQuery(text)
        case .rewrite:
            sendRewrite(text)
        case .translate:
            sendTranslate(text)
        case .summarize:
            sendSummarize(text)
        case .expand:
            sendExpand(text)
        }
    }

    private func sendChat(_ text: String) {
        guard let url = bridge.copilotCompleteURL() else {
            appendError("Copilot URL 不可用")
            return
        }

        var context = ""
        if let page = bridge.currentPage {
            context = String(page.content.prefix(2000))
        }

        let body: [String: Any] = [
            "prompt": text,
            "context": context
        ]

        streamSSE(url: url, body: body)
    }

    private func sendCommand(_ text: String) {
        guard let url = bridge.copilotCommandURL() else {
            appendError("Command URL 不可用")
            return
        }

        let body: [String: Any] = [
            "command": text,
            "page_id": selectedPageId ?? ""
        ]

        streamSSE(url: url, body: body)
    }

    private func sendRAGQuery(_ text: String) {
        bridge.ragEnhancedQuery(query: text) { result in
            DispatchQueue.main.async {
                self.isStreaming = false
                switch result {
                case .success(let data):
                    if let answer = data.answer, !answer.isEmpty {
                        self.chatMessages.append(CopilotMessage(role: "assistant", content: answer))
                    } else if let chunks = data.chunks, !chunks.isEmpty {
                        var content = "📚 相关知识片段：\n\n"
                        for (i, chunk) in chunks.enumerated() {
                            if let txt = chunk.chunk_text {
                                content += "\(i + 1). \(String(txt.prefix(200)))\n\n"
                            }
                        }
                        self.chatMessages.append(CopilotMessage(role: "assistant", content: content))
                    } else {
                        self.chatMessages.append(CopilotMessage(role: "assistant", content: "无相关结果"))
                    }
                case .failure(let err):
                    self.appendError(err.localizedDescription)
                }
            }
        }
    }

    private func streamSSE(url: URL, body: [String: Any]) {
        let request = bridge.buildCopilotRequest(url: url, body: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isStreaming = false
                if let error = error {
                    self.appendError(error.localizedDescription)
                    return
                }
                guard let data = data else {
                    self.appendError("无响应数据")
                    return
                }

                let raw = String(data: data, encoding: .utf8) ?? ""
                var accumulated = ""

                for line in raw.components(separatedBy: "\n") {
                    if line.hasPrefix("data: ") {
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        if let jsonData = payload.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let content = json["content"] as? String {
                            accumulated += content
                        }
                    } else if !line.hasPrefix("event:") && !line.isEmpty {
                        accumulated += line
                    }
                }

                if accumulated.isEmpty {
                    accumulated = String(data: data, encoding: .utf8) ?? "(空响应)"
                }

                self.chatMessages.append(CopilotMessage(role: "assistant", content: accumulated))
                copilotLog.info("Copilot response: \(accumulated.prefix(100))")
            }
        }.resume()
    }

    private func sendRewrite(_ text: String) {
        bridge.copilotRewrite(text: text) { result in
            DispatchQueue.main.async {
                self.isStreaming = false
                switch result {
                case .success(let resp):
                    let content = resp["result"] ?? resp["text"] ?? "(无结果)"
                    self.chatMessages.append(CopilotMessage(role: "assistant", content: "✏️ 改写结果：\n\(content)"))
                case .failure(let err):
                    self.appendError(err.localizedDescription)
                }
            }
        }
    }

    private func sendTranslate(_ text: String) {
        bridge.copilotTranslate(text: text, targetLang: targetLang) { result in
            DispatchQueue.main.async {
                self.isStreaming = false
                switch result {
                case .success(let resp):
                    let content = resp["result"] ?? resp["translation"] ?? "(无结果)"
                    self.chatMessages.append(CopilotMessage(role: "assistant", content: "🌐 翻译结果(\(self.targetLang))：\n\(content)"))
                case .failure(let err):
                    self.appendError(err.localizedDescription)
                }
            }
        }
    }

    private func sendSummarize(_ text: String) {
        bridge.copilotSummarize(text: text) { result in
            DispatchQueue.main.async {
                self.isStreaming = false
                switch result {
                case .success(let resp):
                    let content = resp["result"] ?? resp["summary"] ?? "(无结果)"
                    self.chatMessages.append(CopilotMessage(role: "assistant", content: "📋 摘要：\n\(content)"))
                case .failure(let err):
                    self.appendError(err.localizedDescription)
                }
            }
        }
    }

    private func sendExpand(_ text: String) {
        bridge.copilotExpand(text: text) { result in
            DispatchQueue.main.async {
                self.isStreaming = false
                switch result {
                case .success(let resp):
                    let content = resp["result"] ?? resp["expanded"] ?? "(无结果)"
                    self.chatMessages.append(CopilotMessage(role: "assistant", content: "📖 扩展内容：\n\(content)"))
                case .failure(let err):
                    self.appendError(err.localizedDescription)
                }
            }
        }
    }

    private func appendError(_ message: String) {
        isStreaming = false
        chatMessages.append(CopilotMessage(role: "assistant", content: "❌ \(message)"))
        copilotLog.error("Copilot error: \(message)")
    }
}
