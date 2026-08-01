import SwiftUI
import os.log

// Callers: AIAgentDashboardView quick-start; SectionContentView routes .aiAgentChat to this view.
// Affected API: ipc.agentExecuteStream/agentExecute/agentList; AgentBridge.agents for agent picker.
// Data schemas: AgentModel; ChatMessage (role,content,timestamp,isStreaming,attachments).
// User instruction: "按照GUI草图实现fusion-ai-agent... 一定要做的比claude ai agent更有竞争力"

private let chatLog = Logger(subsystem: "com.fusion.studio", category: "AIAgent.Chat")

struct AIAgentChatView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme

    @State private var selectedAgentId: String = ""
    @State private var chatInput = ""
    @State private var messages: [ChatMessage] = []
    @State private var isStreaming = false
    @State private var showAgentPicker = false
    @State private var showToolbox = false
    @State private var showQuickActions = false
    @State private var webSearchEnabled = false
    @State private var deepResearchEnabled = false
    @State private var codeExecutionEnabled = false
    @State private var knowledgeQueryEnabled = false
    @State private var showRuntimeConfig = false
    @State private var rtTemperature: Double = 0.7
    @State private var rtMaxTokens: Int = 4096

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: String
        var content: String
        let timestamp: Date
        var isStreaming = false
        var attachments: [String] = []
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Rectangle().fill(theme.separator).frame(height: 1)
            messageList
            Rectangle().fill(theme.separator).frame(height: 1)
            quickActionButtons
            Rectangle().fill(theme.separator).frame(height: 1)
            chatInputBar
        }
        .background(theme.surfaceElevated)
        .onAppear { loadDefaultAgent() }
        .sheet(isPresented: $showAgentPicker) {
            agentPickerSheet
        }
    }

    private var chatHeader: some View {
        HStack(spacing: theme.spacingM) {
            Button(action: { showAgentPicker = true }) {
                HStack(spacing: theme.spacingS) {
                    Circle()
                        .fill(theme.accentSoft)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "brain")
                                .font(.system(size: theme.iconS))
                                .foregroundStyle(theme.accent)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(currentAgentName)
                            .font(.system(size: theme.footnoteSize, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Text(currentAgentModel)
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(theme.separator, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: theme.spacingS) {
                Button(action: { showToolbox.toggle() }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showToolbox) {
                    toolboxMenu
                }

                Button(action: { clearChat() }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)

                Button(action: { showRuntimeConfig.toggle() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showRuntimeConfig) { runtimeConfigPopover }
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacingM) {
                    if messages.isEmpty {
                        chatWelcome
                    } else {
                        ForEach(messages) { msg in
                            chatBubble(msg)
                                .id(msg.id)
                        }
                    }
                }
                .padding(theme.spacingL)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var chatWelcome: some View {
        VStack(spacing: theme.spacingL) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.accentSoft)
            VStack(spacing: theme.spacingXS) {
                Text("开始与 Agent 对话")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text("选择一个 Agent，输入消息即可开始")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
            }

            if bridge.agents.isEmpty {
                Text("暂无可用 Agent，请先创建")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacingS) {
                        ForEach(bridge.agents.prefix(5)) { agent in
                            Button(action: {
                                selectedAgentId = agent.id
                                showAgentPicker = false
                            }) {
                                HStack(spacing: theme.spacingXS) {
                                    Image(systemName: "brain")
                                        .font(.system(size: theme.iconS))
                                    Text(agent.name)
                                        .font(.system(size: theme.captionSize, weight: .medium))
                                }
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, theme.spacingM)
                                .padding(.vertical, theme.spacingS)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .fill(theme.accent.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing2XL)
    }

    private func chatBubble(_ msg: ChatMessage) -> some View {
        HStack(alignment: .top) {
            if msg.role == "user" { Spacer(minLength: 60) }

            if msg.role != "user" {
                Circle()
                    .fill(theme.accentSoft)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "brain")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.accent)
                    )
                    .padding(.top, 2)
            }

            VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 4) {
                if !msg.attachments.isEmpty {
                    attachmentChips(msg.attachments)
                }

                Text(msg.content)
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(msg.role == "user" ? theme.accentText : theme.text)
                    .padding(theme.spacingM)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .fill(msg.role == "user" ? theme.accent : theme.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                            .strokeBorder(msg.role == "user" ? Color.clear : theme.separator, lineWidth: 1)
                    )

                HStack(spacing: theme.spacingXS) {
                    Text(msg.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                    if msg.isStreaming {
                        Text("生成中...")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.auxiliary)
                    }
                }
            }

            if msg.role == "user" {
                Circle()
                    .fill(theme.accentDestructive.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.accentDestructive)
                    )
                    .padding(.top, 2)
            }

            if msg.role != "user" { Spacer(minLength: 60) }
        }
    }

    private func attachmentChips(_ attachments: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingXS) {
                ForEach(attachments, id: \.self) { att in
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 10))
                        Text(att)
                            .font(.system(size: theme.captionSize))
                    }
                    .foregroundStyle(theme.auxiliary)
                    .padding(.horizontal, theme.spacingS)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.auxiliarySoft)
                    )
                }
            }
        }
    }

    private var quickActionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingS) {
                quickAction("总结文档", icon: "doc.text")
                quickAction("代码生成", icon: "chevron.left.forwardslash.chevron.right")
                quickAction("数据分析", icon: "chart.bar")
                quickAction("翻译", icon: "globe")
                quickAction("创意写作", icon: "pencil.and.outline")
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
        }
    }

    private func quickAction(_ label: String, icon: String) -> some View {
        Button(action: {
            chatInput = label + "："
        }) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconS))
                Text(label)
                    .font(.system(size: theme.captionSize, weight: .medium))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var chatInputBar: some View {
        HStack(alignment: .bottom, spacing: theme.spacingS) {
            Button(action: { showToolbox = true }) {
                ZStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: theme.iconL))
                        .foregroundStyle(theme.accent)
                    if webSearchEnabled || deepResearchEnabled || codeExecutionEnabled || knowledgeQueryEnabled {
                        Circle()
                            .fill(theme.accentDestructive)
                            .frame(width: 8, height: 8)
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(.plain)

            TextField("输入消息...", text: $chatInput, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: theme.textSize))
                .lineLimit(1...6)
                .padding(theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(theme.separator, lineWidth: 1)
                )
                .onSubmit { sendMessage() }

            Button(action: { sendMessage() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(canSend ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(theme.spacingM)
    }

    private var canSend: Bool {
        !chatInput.trimmingCharacters(in: .whitespaces).isEmpty && !isStreaming && !selectedAgentId.isEmpty
    }

    private var toolboxMenu: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("工具箱")
                .font(.system(size: theme.footnoteSize, weight: .bold))
                .foregroundStyle(theme.text)
                .padding(.bottom, theme.spacingXS)

            toolboxToggle("网页搜索", icon: "globe", isOn: $webSearchEnabled)
            toolboxToggle("深度调研", icon: "magnifyingglass", isOn: $deepResearchEnabled)
            toolboxToggle("代码执行", icon: "terminal", isOn: $codeExecutionEnabled)
            toolboxToggle("知识库查询", icon: "books.vertical", isOn: $knowledgeQueryEnabled)
        }
        .padding(theme.spacingM)
        .frame(width: 200)
    }

    private func toolboxToggle(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button(action: { isOn.wrappedValue.toggle() }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(isOn.wrappedValue ? theme.accent : theme.auxiliary)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
                Spacer()
                if isOn.wrappedValue {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.vertical, theme.spacingXS)
        }
        .buttonStyle(.plain)
    }

    private var agentPickerSheet: some View {
        VStack(spacing: 0) {
            Text("选择 Agent")
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)
                .padding(theme.spacingL)

            if bridge.agents.isEmpty {
                Text("暂无可用 Agent")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(theme.spacing2XL)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingS) {
                        ForEach(bridge.agents) { agent in
                            Button(action: {
                                selectedAgentId = agent.id
                                showAgentPicker = false
                            }) {
                                HStack(spacing: theme.spacingM) {
                                    Circle()
                                        .fill(selectedAgentId == agent.id ? theme.accent : theme.accentSoft)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "brain")
                                                .font(.system(size: theme.iconS))
                                                .foregroundStyle(selectedAgentId == agent.id ? theme.accentText : theme.accent)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(agent.name)
                                            .font(.system(size: theme.footnoteSize, weight: .medium))
                                            .foregroundStyle(theme.text)
                                        Text(agent.model)
                                            .font(.system(size: theme.captionSize))
                                            .foregroundStyle(theme.textTertiary)
                                    }

                                    Spacer()

                                    if selectedAgentId == agent.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(theme.accent)
                                    }
                                }
                                .padding(theme.spacingM)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .fill(selectedAgentId == agent.id ? theme.accent.opacity(0.1) : theme.surfaceElevated)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(theme.spacingL)
                }
            }
        }
        .frame(width: 400, height: 480)
        .background(theme.surfaceElevated)
    }

    private var currentAgentName: String {
        bridge.agents.first { $0.id == selectedAgentId }?.name ?? "选择 Agent"
    }

    private var currentAgentModel: String {
        bridge.agents.first { $0.id == selectedAgentId }?.model ?? ""
    }

    private func loadDefaultAgent() {
        if selectedAgentId.isEmpty, let first = bridge.agents.first {
            selectedAgentId = first.id
        }
    }

    private func sendMessage() {
        let text = chatInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !selectedAgentId.isEmpty else { return }

        var finalInput = text
        if webSearchEnabled { finalInput = "[网页搜索] " + finalInput }
        if deepResearchEnabled { finalInput = "[深度调研] " + finalInput }
        if codeExecutionEnabled { finalInput = "[代码执行] " + finalInput }
        if knowledgeQueryEnabled { finalInput = "[知识库查询] " + finalInput }

        let userMsg = ChatMessage(role: "user", content: text, timestamp: Date())
        messages.append(userMsg)
        chatInput = ""
        isStreaming = true

        var assistantMsg = ChatMessage(role: "assistant", content: "", timestamp: Date(), isStreaming: true)
        messages.append(assistantMsg)
        let assistantIdx = messages.count - 1

        chatLog.info("Send message to agent: \(selectedAgentId), input: \(text.prefix(50))")

        Task {
            do {
                let result = try await ipc.agentExecuteStream(
                    agentId: selectedAgentId,
                    input: finalInput
                )

                let fullContent = result["response"] as? String
                    ?? result["output"] as? String
                    ?? result["content"] as? String
                    ?? "（无响应）"

                await MainActor.run {
                    messages[assistantIdx].content = fullContent
                    messages[assistantIdx].isStreaming = false
                    isStreaming = false
                }
                chatLog.info("Stream response received, length: \(fullContent.count)")
            } catch {
                chatLog.error("Stream failed, falling back to sync: \(error.localizedDescription)")
                do {
                    let fallback = try await ipc.agentExecute(
                        agentId: selectedAgentId,
                        input: finalInput
                    )
                    let content = fallback["response"] as? String
                        ?? fallback["output"] as? String
                        ?? fallback["content"] as? String
                        ?? "（无响应）"

                    await MainActor.run {
                        messages[assistantIdx].content = content
                        messages[assistantIdx].isStreaming = false
                        isStreaming = false
                    }
                } catch {
                    chatLog.error("Sync execute also failed: \(error.localizedDescription)")
                    await MainActor.run {
                        messages[assistantIdx].content = "请求失败：\(error.localizedDescription)"
                        messages[assistantIdx].isStreaming = false
                        isStreaming = false
                    }
                }
            }
        }
    }

    private func clearChat() {
        messages.removeAll()
        chatLog.info("Chat cleared")
    }

    private var runtimeConfigPopover: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("运行时配置")
                .font(.system(size: theme.footnoteSize, weight: .bold))
                .foregroundStyle(theme.text)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                HStack {
                    Text("Temperature")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(String(format: "%.2f", rtTemperature))
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.text)
                }
                Slider(value: $rtTemperature, in: 0...2, step: 0.05)
            }

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text("最大 Token")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                TextField("4096", value: $rtMaxTokens, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .frame(width: 80)
                    .padding(theme.spacingXS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceElevated))
                    .overlay(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).strokeBorder(theme.separator, lineWidth: 1))
            }

            Button("应用到当前会话") { applyRuntimeConfig() }
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.accent)
                .buttonStyle(.plain)
        }
        .padding(theme.spacingM)
        .frame(width: 240)
    }

    private func applyRuntimeConfig() {
        guard !selectedAgentId.isEmpty else { return }
        Task {
            do {
                let _ = try await ipc.agentConfigure(agentId: selectedAgentId, config: [
                    "temperature": rtTemperature,
                    "max_tokens": rtMaxTokens,
                ])
                chatLog.info("Runtime config applied: temp=\(rtTemperature), maxTokens=\(rtMaxTokens)")
            } catch {
                chatLog.error("Apply runtime config failed: \(error.localizedDescription)")
            }
        }
    }
}
