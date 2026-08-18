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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.studioTheme) private var theme

    let agentId: String
    @State private var agent: AgentModel?
    @State private var chatInput = ""
    @State private var messages: [DebugMessage] = []
    @State private var executionLogs: [ExecutionLog] = []
    @State private var isExecuting = false
    @State private var activeTab: DebugTab = .chat
    @State private var skillList: [[String: Any]] = []
    @State private var codeTaskInput = ""
    @State private var codeTaskLang = "python"
    @State private var codeLanguages: [(name: String, tag: String)] = [("Python", "python")]
    @State private var codeTasks: [[String: Any]] = []
    @State private var codeTaskLoading = false
    @State private var historyEntries: [HistoryEntry] = []
    @State private var historyLoading = false

    enum DebugTab: String, CaseIterable {
        case chat = "对话测试"
        case logs = "执行日志"
        case tasks = "代码任务"
        var icon: String {
            switch self {
            case .chat: return "bubble.left.and.bubble.right"
            case .logs: return "list.bullet.rectangle"
            case .tasks: return "terminal"
            }
        }
    }

    struct DebugMessage: Identifiable {
        let id = UUID()
        let role: String
        var content: String
        let timestamp: Date
        var isStreaming: Bool = false
    }

    struct ExecutionLog: Identifiable {
        let id = UUID()
        let step: String
        let detail: String
        let duration: String
        let timestamp: Date
    }

    struct HistoryEntry: Identifiable {
        let id = UUID()
        let runId: String
        let trigger: String
        let inputSummary: String
        let outputSummary: String
        let tokensUsed: Int
        let durationMs: Int
        let status: String
        let startedAt: Double
        let completedAt: Double
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            debugTabBar
            Rectangle().fill(theme.separator).frame(height: 1)
            if activeTab == .chat {
                chatPanel
            } else if activeTab == .logs {
                logsPanel
            } else {
                tasksPanel
            }
        }
        .background(theme.surfaceElevated)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 720, minHeight: 560)
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
            HStack(spacing: theme.spacingS) {
                HStack(spacing: theme.spacingXS) {
                    Circle()
                        .fill(isExecuting ? theme.auxiliary : theme.accentSoft)
                        .frame(width: 8, height: 8)
                    Text(isExecuting ? "执行中" : "就绪")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("关闭")
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
            HStack {
                Text("当前会话日志")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: loadHistory) {
                    HStack(spacing: 4) {
                        if historyLoading { ProgressView().controlSize(.small) }
                        Image(systemName: "clock.arrow.circlepath")
                        Text("加载历史")
                    }
                    .font(.system(size: theme.captionSize))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)

            if !historyEntries.isEmpty {
                Rectangle().fill(theme.separator).frame(height: 1)
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(historyEntries) { entry in
                            historyRow(entry)
                        }
                    }
                    .padding(theme.spacingM)
                }
                .frame(maxHeight: .infinity)
            } else if executionLogs.isEmpty {
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

    private func historyRow(_ entry: HistoryEntry) -> some View {
        let statusColor: Color = {
            switch entry.status {
            case "completed": return theme.accent
            case "error": return theme.accentDestructive
            case "running": return theme.auxiliary
            default: return theme.textTertiary
            }
        }()
        let startedDate = Date(timeIntervalSince1970: entry.startedAt)
        let durationStr = entry.durationMs > 0 ? "\(entry.durationMs)ms" : "-"
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text(entry.runId.prefix(8))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                Text(entry.trigger)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.auxiliary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(theme.auxiliarySoft))
                Spacer()
                Text(entry.status)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(statusColor)
                Text(durationStr)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                Text("\(entry.tokensUsed) tok")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }
            if !entry.inputSummary.isEmpty {
                Text("→ \(entry.inputSummary)")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
            }
            if !entry.outputSummary.isEmpty {
                Text("← \(entry.outputSummary)")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    private func loadHistory() {
        historyLoading = true
        Task {
            do {
                let result = try await ipc.agentHistory(agentId: agentId, limit: 20)
                let rawList = result["history"] as? [[String: Any]] ?? []
                let entries = rawList.compactMap { dict -> HistoryEntry? in
                    guard let runId = dict["run_id"] as? String, !runId.isEmpty else { return nil }
                    return HistoryEntry(
                        runId: runId,
                        trigger: dict["trigger"] as? String ?? "manual",
                        inputSummary: dict["input_summary"] as? String ?? "",
                        outputSummary: dict["output_summary"] as? String ?? "",
                        tokensUsed: dict["tokens_used"] as? Int ?? 0,
                        durationMs: dict["duration_ms"] as? Int ?? 0,
                        status: dict["status"] as? String ?? "completed",
                        startedAt: dict["started_at"] as? Double ?? 0,
                        completedAt: dict["completed_at"] as? Double ?? 0
                    )
                }
                await MainActor.run {
                    historyEntries = entries
                    historyLoading = false
                }
                debugLog.info("Loaded \(entries.count) history entries for agent \(agentId)")
            } catch {
                debugLog.error("Load history failed: \(error.localizedDescription)")
                await MainActor.run { historyLoading = false }
            }
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

    // MARK: - Code Tasks Panel

    private var tasksPanel: some View {
        VStack(spacing: 0) {
            taskSubmitBar
            Rectangle().fill(theme.separator).frame(height: 1)
            if codeTasks.isEmpty {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "terminal")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.textTertiary)
                    Text("暂无代码任务")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                    Text("提交代码让 Agent 执行并查看结果")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(Array(codeTasks.enumerated()), id: \.offset) { _, task in
                            taskRow(task)
                        }
                    }
                    .padding(theme.spacingM)
                }
            }
        }
    }

    private var taskSubmitBar: some View {
        VStack(spacing: theme.spacingS) {
            HStack(spacing: theme.spacingS) {
                Picker("语言", selection: $codeTaskLang) {
                    ForEach(codeLanguages, id: \.tag) { lang in
                        Text(lang.name).tag(lang.tag)
                    }
                }
                .frame(width: 120)
                .font(.system(size: theme.captionSize))
                Spacer()
                Button(action: submitCodeTask) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("提交")
                    }
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                .disabled(codeTaskInput.isEmpty || codeTaskLoading)
            }
            TextEditor(text: $codeTaskInput)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .frame(height: 80)
                .padding(theme.spacingXS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(theme.separator, lineWidth: 1)
                )
        }
        .padding(theme.spacingS)
    }

    private func taskRow(_ task: [String: Any]) -> some View {
        let taskId = task["task_id"] as? String ?? task["id"] as? String ?? ""
        let status = task["status"] as? String ?? "pending"
        let code = task["code"] as? String ?? ""
        let output = task["output"] as? String ?? ""
        let lang = task["language"] as? String ?? ""
        let statusColor: Color = {
            switch status {
            case "completed": return theme.accent
            case "running": return theme.auxiliary
            case "failed", "error": return theme.accentDestructive
            default: return theme.textTertiary
            }
        }()
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text(taskId.prefix(8))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                Text(lang)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.auxiliary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(theme.auxiliarySoft))
                Spacer()
                Text(status)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(statusColor)
                if status == "running" {
                    Button(action: { cancelTask(taskId: taskId) }) {
                        Image(systemName: "stop.circle")
                            .foregroundStyle(theme.accentDestructive)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(code.prefix(100))
                .font(.system(size: theme.captionSize, design: .monospaced))
                .foregroundStyle(theme.text)
                .lineLimit(2)
            if !output.isEmpty {
                Text(output.prefix(200))
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(3)
            }
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
            await loadCodeTasks()
            await loadCodeLanguages()
        }
    }

    private func loadCodeLanguages() async {
        do {
            let result = try await ipc.agentCodeLanguages()
            let raw = result["languages"] as? [[String: Any]] ?? []
            var langs: [(name: String, tag: String)] = []
            for entry in raw {
                let tag = (entry["language"] as? String) ?? "python"
                let name = tag.capitalized.replacingOccurrences(of: "Javascript", with: "JavaScript")
                langs.append((name, tag))
            }
            if langs.isEmpty { langs = [("Python", "python")] }
            await MainActor.run {
                codeLanguages = langs
                if !langs.contains(where: { $0.tag == codeTaskLang }) {
                    codeTaskLang = langs.first?.tag ?? "python"
                }
            }
        } catch {
            debugLog.error("Load code languages failed: \(error.localizedDescription)")
        }
    }

    private func loadCodeTasks() async {
        do {
            let result = try await ipc.agentTasks(agentId: agentId)
            let tasks = result["tasks"] as? [[String: Any]] ?? (result["data"] as? [[String: Any]] ?? [])
            await MainActor.run { codeTasks = tasks }
        } catch {
            debugLog.error("Load code tasks failed: \(error.localizedDescription)")
        }
    }

    private func submitCodeTask() {
        let code = codeTaskInput.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        codeTaskLoading = true
        Task {
            do {
                let result = try await ipc.agentSubmitCodeTask(agentId: agentId, code: code, language: codeTaskLang)
                debugLog.info("Code task submitted: \(result)")
                await loadCodeTasks()
                await MainActor.run {
                    codeTaskInput = ""
                    codeTaskLoading = false
                }
            } catch {
                debugLog.error("Submit code task failed: \(error.localizedDescription)")
                await MainActor.run { codeTaskLoading = false }
            }
        }
    }

    private func cancelTask(taskId: String) {
        Task {
            do {
                let _ = try await ipc.agentCancelTask(taskId: taskId)
                debugLog.info("Task \(taskId) cancelled")
                await loadCodeTasks()
            } catch {
                debugLog.error("Cancel task failed: \(error.localizedDescription)")
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

        var streamMsg = DebugMessage(role: "assistant", content: "", timestamp: Date(), isStreaming: true)
        messages.append(streamMsg)
        let streamIdx = messages.count - 1

        Task {
            do {
                let result = try await ipc.agentExecuteStream(
                    agentId: agentId,
                    input: text
                )

                let responseContent = result["response"] as? String
                    ?? result["output"] as? String
                    ?? result["content"] as? String
                    ?? "（无响应内容）"

                let elapsed = String(format: "%.0fms", Date().timeIntervalSince(startTime) * 1000)
                addLog(step: "execute", detail: "Agent 执行完成", duration: elapsed)

                await MainActor.run {
                    messages[streamIdx].content = responseContent
                    messages[streamIdx].isStreaming = false
                    isExecuting = false
                }

                if let toolCalls = result["tool_calls"] as? [[String: Any]] {
                    for call in toolCalls {
                        let name = call["name"] as? String ?? "unknown"
                        addLog(step: "tool_call", detail: "调用工具：\(name)", duration: "-")
                    }
                }
            } catch {
                debugLog.error("Stream failed, fallback to sync: \(error.localizedDescription)")
                do {
                    let fallback = try await ipc.agentExecute(
                        agentId: agentId,
                        input: text
                    )
                    let content = fallback["response"] as? String
                        ?? fallback["output"] as? String
                        ?? fallback["content"] as? String
                        ?? "（无响应内容）"

                    let elapsed = String(format: "%.0fms", Date().timeIntervalSince(startTime) * 1000)
                    addLog(step: "execute", detail: "Agent 执行完成(fallback)", duration: elapsed)

                    await MainActor.run {
                        messages[streamIdx].content = content
                        messages[streamIdx].isStreaming = false
                        isExecuting = false
                    }
                } catch {
                    let elapsed = String(format: "%.0fms", Date().timeIntervalSince(startTime) * 1000)
                    addLog(step: "error", detail: "执行失败：\(error.localizedDescription)", duration: elapsed)
                    await MainActor.run {
                        messages[streamIdx].content = "执行失败：\(error.localizedDescription)"
                        messages[streamIdx].isStreaming = false
                        isExecuting = false
                    }
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
