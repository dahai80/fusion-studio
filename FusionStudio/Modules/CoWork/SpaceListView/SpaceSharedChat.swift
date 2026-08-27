import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

private struct IdentifiableString: Identifiable {
    let id: String
}

struct SpaceSharedChat: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    let space: CoworkSpace

    @State private var messages: [SpaceMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var selectedAgentId: String?
    @State private var availableAgents: [SpaceAgent] = []
    @State private var showCommentMessageId: String?
    @State private var showPlusMenu = false
    @State private var showDeepResearch = false
    @State private var researchQuery = ""
    @State private var streamingContent: String = ""
    @State private var isStreaming = false
    @State private var streamingAgentName: String = ""
    @State private var hoveredMsgId: String?
    @State private var showRelayPicker = false
    @State private var relayAgentIds: [String] = []
    @State private var isRelaying = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && messages.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty && !isStreaming {
                chatEmptyState
            } else {
                messageList
            }
            chatInputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadMessages(); loadAgents() }
        .sheet(item: Binding(
            get: { showCommentMessageId.map { IdentifiableString(id: $0) } },
            set: { showCommentMessageId = $0?.id }
        )) { item in
            SpaceCommentThread(spaceId: spaceId, messageId: item.id)
        }
        .sheet(isPresented: $showDeepResearch) {
            SpaceDeepResearchView(spaceId: spaceId)
        }
    }

    private var chatEmptyState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.cw_chat_emptyTitle))
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text(i18n.t(.cw_chat_emptyHint))
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacingS) {
                    ForEach(messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                    if isStreaming {
                        streamingBubble
                            .id("streaming-bubble")
                    }
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: streamingContent) { _ in
                if isStreaming {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("streaming-bubble", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var streamingBubble: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: theme.iconXS))
                    .foregroundStyle(theme.accent)
                Text(streamingAgentName.isEmpty ? "Agent" : streamingAgentName)
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text("Agent")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(theme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Spacer()
                if streamingContent.isEmpty {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text(i18n.t(.cw_chat_thinking))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            if !streamingContent.isEmpty {
                MarkdownContentView(content: streamingContent)
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.accent.opacity(0.04))
        )
    }

    private func messageBubble(_ msg: SpaceMessage) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: msg.isFromAgent ? "brain.head.profile" : "person.circle")
                    .font(.system(size: theme.iconXS))
                    .foregroundStyle(msg.isFromAgent ? theme.accent : theme.textSecondary)
                Text(msg.senderName.isEmpty ? msg.senderId : msg.senderName)
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(msg.isFromAgent ? theme.accent : theme.text)
                if msg.isFromAgent {
                    Text("Agent")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Spacer()
                Text(msg.createdAt, style: .time)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }
            MarkdownContentView(content: msg.content)

            if !msg.mentionedAgents.isEmpty {
                HStack(spacing: theme.spacingXS) {
                    ForEach(msg.mentionedAgents, id: \.self) { aid in
                        Text("@\(aid)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.accent)
                    }
                }
            }

            if msg.hasAttachments {
                HStack(spacing: theme.spacingXS) {
                    ForEach(msg.attachments) { att in
                        HStack(spacing: 4) {
                            Image(systemName: attachmentIcon(att.fileType))
                                .font(.system(size: 9))
                            Text(att.fileName)
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, theme.spacingXS)
                        .padding(.vertical, 3)
                        .background(theme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }

            HStack(spacing: theme.spacingM) {
                Button(action: { copyMessageContent(msg) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text(i18n.t(.cw_chat_copy))
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                if msg.isFromAgent {
                    Button(action: { retryAgentMessage(msg) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9))
                            Text(i18n.t(.cw_chat_retry))
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: { showCommentMessageId = msg.id }) {
                    HStack(spacing: 3) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 9))
                        if msg.commentCount > 0 {
                            Text("\(msg.commentCount)")
                        }
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(msg.isFromAgent ? theme.accent.opacity(0.04) : theme.surfaceSecondary)
        )
        .onHover { hovering in
            hoveredMsgId = hovering ? msg.id : nil
        }
    }

    private func copyMessageContent(_ msg: SpaceMessage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(msg.content, forType: .string)
        spaceLog.info("Message content copied id=\(msg.id)")
    }

    private func retryAgentMessage(_ msg: SpaceMessage) {
        guard !isStreaming else { return }
        let prevUserMsg = messages.last(where: { !$0.isFromAgent && $0.createdAt < msg.createdAt })
        let retryContent = prevUserMsg?.content ?? msg.content
        startStreaming(content: retryContent)
    }

    private func attachmentIcon(_ type: String) -> String {
        switch type {
        case "image": return "photo"
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "file": return "doc"
        default: return "paperclip"
        }
    }

    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: theme.spacingS) {
                Menu {
                    Button(action: { }) {
                        Label(i18n.t(.cw_chat_attach), systemImage: "paperclip")
                    }
                    if space.config.enableDeepResearch {
                        Button(action: { showDeepResearch = true }) {
                            Label(i18n.t(.cw_create_deepResearch), systemImage: "telescope")
                        }
                    }
                    if space.config.enableWebSearch {
                        Button(action: { inputText += " /web " }) {
                            Label(i18n.t(.cw_create_webSearch), systemImage: "globe")
                        }
                    }
                    Button(action: { }) {
                        Label(i18n.t(.cw_chat_screenshot), systemImage: "camera")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.textTertiary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                if !availableAgents.isEmpty {
                    Menu {
                        Button(i18n.t(.cw_chat_noAgent)) { selectedAgentId = nil }
                        Divider()
                        ForEach(availableAgents) { agent in
                            Button(action: { selectedAgentId = agent.id }) {
                                HStack {
                                    Text(agent.name)
                                    if agent.id == selectedAgentId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: theme.iconXS))
                            if let aid = selectedAgentId,
                               let agent = availableAgents.first(where: { $0.id == aid }) {
                                Text(agent.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(theme.accent)
                    }
                    .menuStyle(.borderlessButton)
                }

                if availableAgents.count >= 2 {
                    Button(action: { showRelayPicker = true }) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: theme.iconXS))
                            if !relayAgentIds.isEmpty {
                                Text("\(relayAgentIds.count)")
                                    .font(.system(size: 9, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isRelaying ? theme.accentDestructive.opacity(0.15) : theme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(isRelaying ? theme.accentDestructive : theme.accent)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showRelayPicker) {
                        relayPickerView
                    }
                }

                TextField(i18n.t(.cw_chat_inputPh), text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.textSize))
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(isStreaming ? theme.accentDestructive : (inputText.trimmingCharacters(in: .whitespaces).isEmpty ? theme.textQuaternary : theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isStreaming)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
            .background(theme.toolbarBg)
        }
    }

    private func sendMessage() {
        if isStreaming || isRelaying { return }
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        if !relayAgentIds.isEmpty {
            sendRelayMessage(content: text)
            return
        }
        let userMsg = SpaceMessage(
            spaceId: spaceId, senderId: "local_user",
            senderName: "", senderType: "user", content: text
        )
        messages.append(userMsg)
        startStreaming(content: text)
    }

    private func startStreaming(content: String) {
        let mentionedAgents = extractMentionedAgents(from: content)
        streamingContent = ""
        isStreaming = true
        streamingAgentName = ""
        if let aid = selectedAgentId,
           let agent = availableAgents.first(where: { $0.id == aid }) {
            streamingAgentName = agent.name
        }
        Task {
            do {
                let stream = ipc.spaceChatStreamEvents(
                    spaceId: spaceId, content: content,
                    senderId: "local_user", mentionedAgents: mentionedAgents
                )
                for try await event in stream {
                    await MainActor.run {
                        if event.isToken {
                            streamingContent += event.content
                        } else if event.isDone {
                            finalizeStreaming()
                        } else if event.isError {
                            spaceLog.error("stream error: \(event.content)")
                            if streamingContent.isEmpty {
                                streamingContent = String(format: i18n.t(.cw_chat_streamErr), event.content)
                            }
                            finalizeStreaming()
                        } else if event.isThinking {
                            if streamingAgentName.isEmpty && !event.name.isEmpty {
                                streamingAgentName = event.name
                            }
                        }
                    }
                }
                if isStreaming {
                    await MainActor.run { finalizeStreaming() }
                }
            } catch {
                spaceLog.error("spaceChatStreamEvents failed: \(error.localizedDescription)")
                await MainActor.run {
                    streamingContent = String(format: i18n.t(.cw_chat_sendFail), error.localizedDescription)
                    finalizeStreaming()
                }
            }
        }
    }

    private func finalizeStreaming() {
        if !streamingContent.isEmpty {
            let agentMsg = SpaceMessage(
                spaceId: spaceId,
                senderId: selectedAgentId ?? "agent",
                senderName: streamingAgentName.isEmpty ? "Agent" : streamingAgentName,
                senderType: "agent",
                content: streamingContent
            )
            messages.append(agentMsg)
        }
        streamingContent = ""
        isStreaming = false
        streamingAgentName = ""
    }

    private func extractMentionedAgents(from text: String) -> [String] {
        var agents: [String] = []
        let pattern = "@(\\w+)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    agents.append(String(text[range]))
                }
            }
        }
        if let aid = selectedAgentId { agents.append(aid) }
        return agents
    }

    private func loadMessages() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceChatHistory(spaceId: spaceId)
                let items = result["messages"] as? [[String: Any]] ?? []
                let msgs = items.map { SpaceMessage.fromDict($0) }
                await MainActor.run { messages = msgs; isLoading = false }
            } catch {
                spaceLog.error("chat.history failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func loadAgents() {
        Task {
            do {
                let result = try await ipc.spaceAgentList(spaceId: spaceId)
                let items = result["agents"] as? [[String: Any]] ?? []
                await MainActor.run { availableAgents = items.map { SpaceAgent.fromDict($0) } }
            } catch {
                spaceLog.error("agent.list for chat failed: \(error.localizedDescription)")
            }
        }
    }

    private var relayPickerView: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.cw_chat_relay))
                .font(.system(size: theme.footnoteSize, weight: .semibold))
            Text(i18n.t(.cw_chat_relayHint))
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
            ForEach(availableAgents) { agent in
                Button(action: {
                    if relayAgentIds.contains(agent.id) {
                        relayAgentIds.removeAll { $0 == agent.id }
                    } else {
                        relayAgentIds.append(agent.id)
                    }
                }) {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: relayAgentIds.contains(agent.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(relayAgentIds.contains(agent.id) ? theme.accent : theme.textTertiary)
                        Image(systemName: agent.typeIcon)
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(theme.accent)
                        Text(agent.name)
                            .font(.system(size: theme.captionSize))
                        Spacer()
                        if let idx = relayAgentIds.firstIndex(of: agent.id) {
                            Text("#\(idx + 1)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            if !relayAgentIds.isEmpty {
                HStack {
                    Button(i18n.t(.cw_chat_relayClear)) { relayAgentIds = [] }
                        .buttonStyle(.plain)
                        .font(.system(size: 9))
                    Spacer()
                    Button(i18n.t(.cw_chat_relayDone)) { showRelayPicker = false }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
        .padding(theme.spacingM)
        .frame(width: 280)
    }

    private func sendRelayMessage(content: String) {
        guard !relayAgentIds.isEmpty else { return }
        isRelaying = true
        let userMsg = SpaceMessage(
            spaceId: spaceId, senderId: "local_user",
            senderName: "", senderType: "user", content: content
        )
        messages.append(userMsg)
        Task {
            do {
                let result = try await ipc.spaceAgentRelay(
                    spaceId: spaceId, agentIds: relayAgentIds,
                    message: content
                )
                let relayMessages = result["messages"] as? [[String: Any]] ?? []
                await MainActor.run {
                    for rm in relayMessages {
                        let msg = SpaceMessage.fromDict(rm)
                        messages.append(msg)
                    }
                    isRelaying = false
                }
                spaceLog.info("Agent relay completed with \(relayAgentIds.count) agents")
            } catch {
                spaceLog.error("Agent relay failed: \(error.localizedDescription)")
                await MainActor.run {
                    let errMsg = SpaceMessage(
                        spaceId: spaceId, senderId: "system",
                        senderName: i18n.t(.cw_system_name), senderType: "system",
                        content: String(format: i18n.t(.cw_chat_relayFail), error.localizedDescription)
                    )
                    messages.append(errMsg)
                    isRelaying = false
                }
            }
        }
    }
}

