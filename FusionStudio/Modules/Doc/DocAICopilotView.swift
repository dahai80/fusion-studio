// Callers: DocView (HSplitView right pane).
// Affected API: DocBridge copilotCompleteURL/copilotRewriteURL/copilotCommandURL/buildCopilotRequest/ragEnhancedQuery/copilotRewrite/copilotTranslate/copilotSummarize/copilotExpand/fetchCopilotContext — SSE + REST /api/copilot/* + /api/rag/* endpoints.
// Data schemas: CopilotMessage (local), DocPage context from DocBridge, CopilotMode 7 modes.
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let copilotLog = Logger(subsystem: "com.fusion.studio", category: "DocAICopilot")

struct DocAICopilotView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
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

        var localLabel: String {
            switch self {
            case .chat:      return I18nManager.shared.t(.doc_cp_modeChat)
            case .command:   return I18nManager.shared.t(.doc_cp_modeCommand)
            case .rag:       return I18nManager.shared.t(.doc_cp_modeRag)
            case .rewrite:   return I18nManager.shared.t(.doc_cp_modeRewrite)
            case .translate: return I18nManager.shared.t(.doc_cp_modeTranslate)
            case .summarize: return I18nManager.shared.t(.doc_cp_modeSummarize)
            case .expand:    return I18nManager.shared.t(.doc_cp_modeExpand)
            }
        }
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
                    Text(mode.localLabel)
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
                Picker(i18n.t(.doc_cp_targetLang), selection: $targetLang) {
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
            .help(i18n.t(.doc_cp_clearChat))
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
                            Text(i18n.t(.doc_cp_thinking))
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
                copilotMode == .chat ? i18n.t(.doc_cp_phChat) :
                copilotMode == .command ? i18n.t(.doc_cp_phCommand) :
                copilotMode == .rewrite ? i18n.t(.doc_cp_phRewrite) :
                copilotMode == .translate ? String(format: i18n.t(.doc_cp_phTranslateFmt), targetLang) :
                copilotMode == .summarize ? i18n.t(.doc_cp_phSummarize) :
                copilotMode == .expand ? i18n.t(.doc_cp_phExpand) :
                i18n.t(.doc_cp_phRag),
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
            appendError(i18n.t(.doc_cp_errCopilotURL))
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
            appendError(i18n.t(.doc_cp_errCommandURL))
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
                        var content = self.i18n.t(.doc_cp_ragChunksPrefix) + "\n\n"
                        for (i, chunk) in chunks.enumerated() {
                            if let txt = chunk.chunk_text {
                                content += "\(i + 1). \(String(txt.prefix(200)))\n\n"
                            }
                        }
                        self.chatMessages.append(CopilotMessage(role: "assistant", content: content))
                    } else {
                        self.chatMessages.append(CopilotMessage(role: "assistant", content: self.i18n.t(.doc_cp_ragNoResult)))
                    }
                case .failure(let error):
                    self.appendError(error.localizedDescription)
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
                    self.appendError(self.i18n.t(.doc_cp_errNoData))
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
                    accumulated = String(data: data, encoding: .utf8) ?? self.i18n.t(.doc_cp_emptyResp)
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
                    let content = resp["result"] ?? resp["text"] ?? self.i18n.t(.doc_cp_noResult)
                    self.chatMessages.append(CopilotMessage(role: "assistant", content: self.i18n.t(.doc_cp_rewriteResultPrefix) + "\n\(content)"))
                case .failure(let error):
                    self.appendError(error.localizedDescription)
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
                    let content = resp["result"] ?? resp["translation"] ?? self.i18n.t(.doc_cp_noResult)
                    self.chatMessages.append(CopilotMessage(role: "assistant", content: String(format: self.i18n.t(.doc_cp_translateResultFmt), self.targetLang) + "\n\(content)"))
                case .failure(let error):
                    self.appendError(error.localizedDescription)
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
                    let content = resp["result"] ?? resp["summary"] ?? self.i18n.t(.doc_cp_noResult)
                    self.chatMessages.append(CopilotMessage(role: "assistant", content: self.i18n.t(.doc_cp_summarizePrefix) + "\n\(content)"))
                case .failure(let error):
                    self.appendError(error.localizedDescription)
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
                    let content = resp["result"] ?? resp["expanded"] ?? self.i18n.t(.doc_cp_noResult)
                    self.chatMessages.append(CopilotMessage(role: "assistant", content: self.i18n.t(.doc_cp_expandPrefix) + "\n\(content)"))
                case .failure(let error):
                    self.appendError(error.localizedDescription)
                }
            }
        }
    }

    private func appendError(_ message: String) {
        isStreaming = false
        chatMessages.append(CopilotMessage(role: "assistant", content: i18n.t(.doc_cp_errPrefix) + message))
        copilotLog.error("Copilot error: \(message)")
    }
}
