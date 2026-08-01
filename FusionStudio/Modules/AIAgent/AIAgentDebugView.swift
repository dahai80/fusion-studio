import SwiftUI
import os.log

// Callers: AIAgentListView debug action navigates to AIAgentDebugView(agentId:).
// Affected API: ipc.agentExecute/agentListSkills; AgentBridge.agents for agent lookup.
// Data schemas: AgentModel (id,name); DebugMessage (role,content,timestamp); ExecutionLog (step,detail,duration).
// User instruction: "按照GUI草图实现fusion-ai-agent... 一定要做的比claude ai agent更有竞争力"

private let debugLog = Logger(subsystem: "com.fusion.studio", category: "AIAgent.Debug")

struct AIAgentDebugView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme

    let agentId: String
    @State private var agent: AgentModel?
    @State private var chatInput = ""
    @State private var messages: [DebugMessage] = []
    @State private var executionLogs: [ExecutionLog] = []
    @State private var isExecuting = false
    @State private var activeTab: DebugTab = .chat
    @State private var skillList: [[String: Any]] = []

    enum DebugTab: String, CaseIterable {
        case chat = "对话测试"
        case logs = "执行日志"
        var icon: String {
            switch self {
            case .chat: return "bubble.left.and.bubble.right"
            case .logs: return "list.bullet.rectangle"
            }
        }
    }

    struct DebugMessage: Identifiable {
        let id = UUID()
        let role: String
        let content: String
        let timestamp: Date
    }

    struct ExecutionLog: Identifiable {
        let id = UUID()
        let step: String
        let detail: String
        let duration: String
        let timestamp: Date
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            debugTabBar
            Rectangle().fill(theme.separator).frame(height: 1)
            if activeTab == .chat {
                chatPanel
            } else {
                logsPanel
            }
        }
        .background(theme.surfaceElevated)
        .onAppear { loadAgent() }
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                Text("调试面板")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text(agent?.name ?? "Agent \(agentId.prefix(8))")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            HStack(spacing: theme.spacingXS) {
                Circle()
                    .fill(isExecuting ? theme.auxiliary : theme.accentSoft)
                    .frame(width: 8, height: 8)
                Text(isExecuting ? "执行中" : "就绪")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private var debugTabBar: some View {
        HStack(spacing: 0) {
            ForEach(DebugTab.allCases, id: \.self) { tab in
                Button(action: { activeTab = tab }) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: tab.icon)
                            .font(.system(size: theme.iconS))
                        Text(tab.rawValue)
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                    }
                    .foregroundStyle(activeTab == tab ? theme.accentText : theme.textSecondary)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(activeTab == tab ? theme.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: { clearSession() }) {
                Image(systemName: "trash")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingXS)
    }

    // MARK: - Chat Panel

    private var chatPanel: some View {
        VStack(spacing: 0) {
            messageList
            Rectangle().fill(theme.separator).frame(height: 1)
            inputBar
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacingS) {
                    if messages.isEmpty {
                        emptyChatPlaceholder
                    } else {
                        ForEach(messages) { msg in
                            messageBubble(msg)
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

    private var emptyChatPlaceholder: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("发送消息测试 Agent 响应")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Text("调试模式下可实时查看执行步骤和工具调用")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing2XL)
    }

    private func messageBubble(_ msg: DebugMessage) -> some View {
        HStack {
            if msg.role == "user" { Spacer(minLength: 80) }
            VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(msg.content)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(msg.role == "user" ? theme.accentText : theme.text)
                    .padding(theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(msg.role == "user" ? theme.accent : theme.surfaceElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(msg.role == "user" ? Color.clear : theme.separator, lineWidth: 1)
                    )
                Text(msg.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
            if msg.role == "assistant" { Spacer(minLength: 80) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: theme.spacingS) {
            TextField("输入测试消息...", text: $chatInput, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: theme.textSize))
                .lineLimit(1...4)
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
                    .font(.system(size: theme.iconXL))
                    .foregroundStyle(chatInput.trimmingCharacters(in: .whitespaces).isEmpty || isExecuting ? theme.textTertiary : theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(chatInput.trimmingCharacters(in: .whitespaces).isEmpty || isExecuting)
        }
        .padding(theme.spacingM)
    }

    // MARK: - Logs Panel

    private var logsPanel: some View {
        VStack(spacing: 0) {
            if executionLogs.isEmpty {
                emptyLogsPlaceholder
            } else {
                logList
            }
        }
    }

    private var emptyLogsPlaceholder: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("执行日志为空")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Text("发送测试消息后，执行步骤将出现在这里")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingXS) {
                ForEach(executionLogs) { log in
                    logRow(log)
                }
            }
            .padding(theme.spacingL)
        }
    }

    private func logRow(_ log: ExecutionLog) -> some View {
        HStack(spacing: theme.spacingS) {
            Text(log.timestamp, style: .time)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 60, alignment: .leading)

            Text(log.step)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.auxiliary)
                .frame(width: 100, alignment: .leading)

            Text(log.detail)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.text)
                .lineLimit(2)

            Spacer()

            Text(log.duration)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    // MARK: - Actions

    private func loadAgent() {
        agent = bridge.agents.first { $0.id == agentId }
        Task {
            do {
                let result = try await ipc.agentListSkills(agentId: agentId)
                let skills = result["skills"] as? [[String: Any]] ?? (result["data"] as? [[String: Any]] ?? [])
                await MainActor.run { skillList = skills }
            } catch {
                debugLog.error("List skills failed: \(error.localizedDescription)")
            }
        }
    }

    private func sendMessage() {
        let text = chatInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let userMsg = DebugMessage(role: "user", content: text, timestamp: Date())
        messages.append(userMsg)
        chatInput = ""
        isExecuting = true

        let startTime = Date()
        addLog(step: "receive", detail: "收到用户消息：\(text.prefix(50))", duration: "0ms")

        Task {
            do {
                let result = try await ipc.agentExecute(
                    agentId: agentId,
                    input: text
                )

                let elapsed = String(format: "%.0fms", Date().timeIntervalSince(startTime) * 1000)
                addLog(step: "execute", detail: "Agent 执行完成", duration: elapsed)

                let responseContent = result["response"] as? String
                    ?? result["output"] as? String
                    ?? result["content"] as? String
                    ?? "（无响应内容）"

                let assistantMsg = DebugMessage(role: "assistant", content: responseContent, timestamp: Date())
                await MainActor.run {
                    messages.append(assistantMsg)
                    isExecuting = false
                }

                if let toolCalls = result["tool_calls"] as? [[String: Any]] {
                    for call in toolCalls {
                        let name = call["name"] as? String ?? "unknown"
                        addLog(step: "tool_call", detail: "调用工具：\(name)", duration: "-")
                    }
                }
            } catch {
                debugLog.error("Execute failed: \(error.localizedDescription)")
                let elapsed = String(format: "%.0fms", Date().timeIntervalSince(startTime) * 1000)
                addLog(step: "error", detail: "执行失败：\(error.localizedDescription)", duration: elapsed)

                let errorMsg = DebugMessage(role: "assistant", content: "执行失败：\(error.localizedDescription)", timestamp: Date())
                await MainActor.run {
                    messages.append(errorMsg)
                    isExecuting = false
                }
            }
        }
    }

    private func addLog(step: String, detail: String, duration: String) {
        let log = ExecutionLog(step: step, detail: detail, duration: duration, timestamp: Date())
        executionLogs.append(log)
        debugLog.info("[\(step)] \(detail) (\(duration))")
    }

    private func clearSession() {
        messages.removeAll()
        executionLogs.removeAll()
        debugLog.info("Debug session cleared for agent: \(agentId)")
    }
}
