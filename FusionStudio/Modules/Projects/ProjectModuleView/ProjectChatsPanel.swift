import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ProjectChatsPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var agentBridge: AgentBridge
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let projectId: String
    @State private var chats: [ProjectChat] = []
    @State private var activeChatId: String?
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var refocusTrigger = 0
    @State private var selectedModel: String = ""
    @StateObject private var voiceInput = VoiceInputManager()
    @State private var ragMode: RAGMode = .AUTO
    @State private var showRAGScopeSelector = false
    @State private var showSnapshots = false
    @State private var tokenUsed: Int = 0
    @State private var tokenBudget: Int = 128000
    @State private var showAgentConfig = false
    @State private var showRAGConfig = false
    @State private var snapshots: [ChatSnapshot] = []
    @State private var selectedChatForMenu: ProjectChat?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: Chat list
            VStack(alignment: .leading, spacing: 0) {
                // Chat list header
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundStyle(theme.accent)
                    Text(i18n.t(.proj_chatsTitle))
                        .font(.system(size: theme.textSize, weight: .semibold))
                    Text("\(chats.count)")
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    Button(action: { createNewChat() }) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(chats) { chat in
                            chatRow(chat)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }

                // Snapshots section
                if !snapshots.isEmpty {
                    Divider()
                    HStack {
                        Image(systemName: "camera")
                            .font(.system(size: theme.iconXS))
                        Text(i18n.t(.proj_chatsSnapshots))
                            .font(.system(size: theme.captionSize, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.top, theme.spacingXS)

                    ForEach(snapshots) { snap in
                        HStack {
                            Image(systemName: "photo")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textTertiary)
                            Text(snap.label)
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text(String(format: i18n.t(.proj_chatsSnapMsgCountFmt), snap.messageCount))
                                .font(.system(size: 8))
                                .foregroundStyle(theme.textQuaternary)
                        }
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, 3)
                    }
                }
            }
            .frame(width: 200)

            Rectangle().fill(theme.separator).frame(width: 1)

            // Right: Chat canvas
            VStack(spacing: 0) {
                if let chatId = activeChatId {
                    chatCanvas(chatId: chatId)
                } else {
                    Spacer()
                    VStack(spacing: theme.spacingS) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.textQuaternary)
                        Text(i18n.t(.proj_chatsEmpty))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            loadChats()
            loadSnapshots()
            refreshBudget()
        }
        .alert(i18n.t(.proj_chatsHint), isPresented: $showError, presenting: errorMessage) { _ in
            Button(i18n.t(.ok), role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    private func chatRow(_ chat: ProjectChat) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: chat.isStarred ? "star.fill" : "bubble.left.fill")
                .font(.system(size: 9))
                .foregroundStyle(chat.isStarred ? .yellow : theme.textTertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text(chat.title)
                    .font(.system(size: theme.footnoteSize, weight: activeChatId == chat.id ? .semibold : .regular))
                    .foregroundStyle(activeChatId == chat.id ? theme.accent : theme.text)
                    .lineLimit(1)
                Text("\(chat.messageCount) msgs · \(chat.tokenUsage) tokens")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(theme.textQuaternary)
            }

            Spacer()

            // GUI-7: Chat three-dot menu
            ChatContextMenu(chat: chat, projectId: projectId)
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(activeChatId == chat.id ? theme.accent.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            activeChatId = chat.id
            loadMessages(chatId: chat.id)
        }
    }

    // MARK: GUI-4: Chat Canvas

    private func chatCanvas(chatId: String) -> some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacingS) {
                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                    }
                    .padding(theme.spacingM)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // GUI-4: Bottom input bar — Agent / RAG / Attachments / Send
            chatInputBar(chatId: chatId)
        }
    }

    // GUI-22: RAG source annotation in messages
    private func messageBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == "user"
        return HStack(alignment: .top, spacing: theme.spacingS) {
            if isUser { Spacer(minLength: 40) }

            Image(systemName: isUser ? "person.fill" : "robot")
                .font(.system(size: theme.iconS))
                .foregroundStyle(isUser ? theme.textSecondary : theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(msg.content)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)

                // GUI-22: RAG sources
                if let sources = msg.ragSources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 8))
                            Text(i18n.t(.proj_ragSources))
                        }
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)

                        ForEach(sources, id: \.self) { source in
                            Text("📄 \(source)")
                                .font(.system(size: 8))
                                .foregroundStyle(theme.textTertiary)
                        }

                        HStack(spacing: 4) {
                            Text(String(format: i18n.t(.proj_ragModeLabelFmt), ragMode.rawValue))
                            if ragMode == .MANUAL {
                                Button(i18n.t(.proj_ragSwitchAuto)) { ragMode = .AUTO }
                                    .font(.system(size: 8))
                            } else if ragMode == .AUTO {
                                Button(i18n.t(.proj_ragSwitchManual)) { ragMode = .MANUAL }
                                    .font(.system(size: 8))
                            }
                        }
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textQuaternary)
                    }
                    .padding(theme.spacingXS)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(theme.accent.opacity(0.06)))
                }
            }
            .padding(theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isUser ? theme.accent.opacity(0.12) : theme.textTertiary.opacity(0.04))
            )

            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, theme.spacingM)
    }

    // GUI-4 + GUI-12: Bottom bar with Agent / RAG / Budget / Send
    private func chatInputBar(chatId: String) -> some View {
        VStack(spacing: 0) {
            // GUI-12: Context budget bar
            contextBudgetBar

            Divider()
            HStack(spacing: theme.spacingS) {
                // Agent selector (GUI-10) + config button
                Menu {
                    Button(i18n.t(.proj_inputUseDefaultAgent)) { }
                    Button(i18n.t(.proj_inputGenericChat)) { }
                    Divider()
                    Button(i18n.t(.proj_inputPreviewAgent)) { }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "robot")
                            .font(.system(size: theme.iconXS))
                        Text("Agent")
                            .font(.system(size: theme.captionSize))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                    }
                    .foregroundStyle(theme.accent)
                }
                .menuStyle(.borderlessButton)

                // FS-2: Agent config button
                Button(action: { showAgentConfig = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)

                // RAG mode (GUI-17)
                Menu {
                    Button(i18n.t(.proj_inputRagAuto)) { ragMode = .AUTO }
                    Button(i18n.t(.proj_inputRagManual)) { ragMode = .MANUAL; showRAGScopeSelector = true }
                    Button(i18n.t(.proj_inputRagOff)) { ragMode = .OFF }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: theme.iconXS))
                        Text(String(format: i18n.t(.proj_inputRagLabelFmt), ragMode.rawValue))
                            .font(.system(size: theme.captionSize))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                    }
                    .foregroundStyle(ragMode == .OFF ? theme.textTertiary : theme.accent)
                }
                .menuStyle(.borderlessButton)

                // FS-3: RAG config button
                Button(action: { showRAGConfig = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)

                // Attachments dropdown
                Menu {
                    Button(i18n.t(.proj_inputAttachTemp)) { }
                    Button(i18n.t(.proj_inputAttachScreenshot)) { }
                    Button(i18n.t(.proj_inputAttachWebSearch)) { }
                    Button(i18n.t(.proj_inputAttachSkill)) { }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .menuStyle(.borderlessButton)

                // Input field — 多行输入框，占两行高度
                SendableTextEditor(
                    text: $inputText,
                    placeholder: i18n.t(.proj_inputPlaceholder),
                    font: .systemFont(ofSize: theme.footnoteSize),
                    textColor: NSColor.labelColor,
                    placeholderColor: NSColor.tertiaryLabelColor,
                    maxHeight: 60,
                    onSend: { sendMessage(chatId: chatId) },
                    refocusTrigger: $refocusTrigger
                )
                .frame(minHeight: 36, maxHeight: 60)

                FusionModelPicker(scene: .agent, selection: $selectedModel, models: agentBridge.mlxState.models, onChange: { id in
                    projLog.info("Project chat model selected: \(id)")
                })

                VoiceInputButton(voice: voiceInput, text: $inputText, onSend: { sendMessage(chatId: chatId) })

                // Send
                Button(action: { sendMessage(chatId: chatId) }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(inputText.isEmpty ? theme.textTertiary : theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
        }
        .sheet(isPresented: $showRAGScopeSelector) {
            RAGScopeSelector(projectId: projectId, ragMode: $ragMode)
        }
        .sheet(isPresented: $showAgentConfig) {
            AgentConfigSheet(projectId: projectId)
        }
        .sheet(isPresented: $showRAGConfig) {
            RAGConfigSheet(projectId: projectId, ragMode: $ragMode)
        }
    }

    // GUI-12: Context budget bar
    private var contextBudgetBar: some View {
        let ratio = tokenBudget > 0 ? Double(tokenUsed) / Double(tokenBudget) : 0
        return HStack(spacing: 8) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 9))
                .foregroundStyle(ratio > 0.9 ? theme.accentDestructive : theme.textTertiary)
            Text(formatTokenCount(tokenUsed))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.text)
            Text("/")
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
            Text(formatTokenCount(tokenBudget))
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
            ProgressView(value: ratio)
                .progressViewStyle(.linear)
                .tint(ratio > 0.9 ? theme.accentDestructive : ratio > 0.7 ? .yellow : theme.accent)
                .frame(maxWidth: 120)
            Text(String(format: "%.0f%%", ratio * 100))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(ratio > 0.9 ? theme.accentDestructive : theme.textTertiary)
            if ratio > 0.9 {
                Text(i18n.t(.proj_budgetLow))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.accentDestructive)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, 3)
        .background(theme.surfaceSecondary)
    }

    private func formatTokenCount(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000.0) }
        return "\(n)"
    }

    private func refreshBudget() {
        Task {
            do {
                let r = try await ipc.contextBudget()
                let used = r["used"] as? Int ?? r["token_used"] as? Int ?? 0
                let budget = r["budget"] as? Int ?? r["total_budget"] as? Int ?? 128000
                await MainActor.run { tokenUsed = used; tokenBudget = budget }
            } catch {
                projLog.error("refreshBudget failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Actions

    private func loadChats() {
        Task {
            do {
                let result = try await ipc.projectChatList(projectId: projectId)
                if let items = result["items"] as? [[String: Any]] ?? result["chats"] as? [[String: Any]] {
                    await MainActor.run {
                        self.chats = items.compactMap { ProjectChat.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadChats failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadSnapshots() {
        Task {
            do {
                let result = try await ipc.projectChatSnapshotList(chatId: activeChatId ?? "")
                if let items = result["items"] as? [[String: Any]] ?? result["snapshots"] as? [[String: Any]] {
                    await MainActor.run {
                        self.snapshots = items.compactMap { d in
                            ChatSnapshot(
                                id: d["id"] as? String ?? "",
                                chatId: d["chat_id"] as? String ?? "",
                                label: d["label"] as? String ?? "Snapshot",
                                messageCount: d["message_count"] as? Int ?? 0,
                                createdAt: ISO8601DateFormatter().date(from: d["created_at"] as? String ?? "") ?? Date()
                            )
                        }
                    }
                }
            } catch {
                projLog.error("loadSnapshots failed: \(error.localizedDescription)")
            }
        }
    }

    private func createNewChat() {
        Task {
            do {
                let result = try await ipc.projectChatCreate(projectId: projectId, title: "New Chat")
                let chat = ProjectChat.fromDict(result)
                await MainActor.run {
                    self.chats.insert(chat, at: 0)
                    self.activeChatId = chat.id
                }
                projLog.info("Chat created in project \(projectId)")
            } catch {
                projLog.error("createNewChat failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = String(format: i18n.t(.proj_chatsCreateFailFmt), error.localizedDescription)
                    self.showError = true
                }
            }
        }
    }

    private func loadMessages(chatId: String) {
        Task {
            do {
                let result = try await ipc.projectMessageList(chatId: chatId)
                if let items = result["items"] as? [[String: Any]] ?? result["messages"] as? [[String: Any]] {
                    await MainActor.run {
                        self.messages = items.compactMap { ChatMessage.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadMessages failed: \(error.localizedDescription)")
            }
        }
    }

    private func sendMessage(chatId: String) {
        if voiceInput.isRecording {
            let transcript = voiceInput.stopRecording()
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                inputText += (inputText.isEmpty ? "" : " ") + trimmed
            }
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task {
            do {
                let result = try await ipc.projectMessageAdd(
                    chatId: chatId, content: text,
                    ragMode: ragMode == .OFF ? nil : ragMode.rawValue
                )
                let userMsg = ChatMessage.fromDict(result)
                await MainActor.run { self.messages.append(userMsg) }
                await generateReply(chatId: chatId)
            } catch {
                projLog.error("sendMessage failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = String(format: i18n.t(.proj_chatsSendFailFmt), error.localizedDescription)
                    self.showError = true
                }
            }
        }
    }

    // 生成 AI 回复：用当前会话历史调 MLX /v1/chat/completions，回填到 messages。
    // 上游 project.chat.message.add 暂不接 role 字段（强制 user），assistant 回复先本地展示，
    // 待上游 PR 支持后落库。
    private func generateReply(chatId: String) async {
        let cfg = FusionConfig.shared
        let model = selectedModel.isEmpty ? cfg.defaultModel(for: .agent) : selectedModel
        if model.isEmpty {
            projLog.error("generateReply: no model selected, cannot infer")
            await MainActor.run {
                self.errorMessage = i18n.t(.proj_chatsNoModel)
                self.showError = true
            }
            return
        }
        var hist: [[String: Any]] = []
        for m in messages {
            hist.append(["role": m.role, "content": m.content])
        }
        do {
            let reply = try await agentBridge.infer(messages: hist, model: model)
            let assistantMsg = ChatMessage(id: UUID().uuidString, role: "assistant", content: reply)
            await MainActor.run { self.messages.append(assistantMsg) }
            projLog.info("generateReply: reply \(reply.count) chars for chat \(chatId)")
        } catch {
            projLog.error("generateReply infer failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = String(format: i18n.t(.proj_chatsReplyFailFmt), error.localizedDescription)
                self.showError = true
            }
        }
    }
}

// MARK: - GUI-7: Chat Context Menu

