import SwiftUI
import Combine
import os.log

private let workflowLog = Logger(subsystem: "com.fusion.studio", category: "WorkflowListView")

// MARK: - AgentTaskListView

struct AgentTaskListView: View {
    @EnvironmentObject private var bridge: AgentBridge
    @State private var showCreateTask = false
    @State private var selectedTask: TaskModel?
    @State private var viewMode: TaskViewMode = .list
    let toastManager: FusionToastManager

    @Environment(\.studioTheme) var theme

    enum TaskViewMode { case list, board }

    private var activeTasks: [TaskModel] {
        bridge.taskState.tasks.filter { !$0.status.isTerminal }
    }

    private var completedTasks: [TaskModel] {
        bridge.taskState.tasks.filter { $0.status.isTerminal }
    }

    var body: some View {
        VStack(spacing: 0) {
            if bridge.taskState.tasks.isEmpty {
                emptyTasksPlaceholder
            } else if viewMode == .board {
                TaskBoardView(toastManager: toastManager)
            } else {
                ScrollView {
                    VStack(spacing: theme.spacingS) {
                        StudioSectionHeader(title: "Active Tasks")
                        if activeTasks.isEmpty {
                            Text("No active tasks")
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.textTertiary)
                                .padding(.horizontal, theme.spacingL)
                        } else {
                            ForEach(activeTasks) { task in
                                taskCard(task: task)
                            }
                        }

                        StudioSectionHeader(title: "Completed")
                        if completedTasks.isEmpty {
                            Text("No completed tasks")
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.textTertiary)
                                .padding(.horizontal, theme.spacingL)
                        } else {
                            ForEach(completedTasks) { task in
                                taskCard(task: task)
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Picker("View", selection: $viewMode) {
                    Label("List", systemImage: "list.bullet").tag(AgentTaskListView.TaskViewMode.list)
                    Label("Board", systemImage: "square.grid.2x2").tag(AgentTaskListView.TaskViewMode.board)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            ToolbarItem {
                FusionButton("New Task", icon: "plus", style: .primary, size: .small) {
                    showCreateTask = true
                }
            }
            ToolbarItem {
                Button {
                    Task {
                        await bridge.fetchTasks()
                        await bridge.fetchProjects()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showCreateTask) {
            CreateTaskSheet(toastManager: toastManager)
        }
        .sheet(item: $selectedTask) { task in
            AgentTaskDetailView(taskId: task.id, toastManager: toastManager)
        }
        .onAppear {
            Task {
                await bridge.fetchTasks()
                await bridge.fetchProjects()
            }
        }
    }

    private func taskCard(task: TaskModel) -> some View {
        FusionCard(style: .elevated) {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack(spacing: theme.spacingS) {
                    StatusPill(status: task.status.pillStatus, compact: true)
                    Text(task.title)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Spacer()
                    FusionTag(task.trigger.rawValue, icon: task.trigger.icon, color: triggerColor(task.trigger))
                }

                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: theme.spacingS) {
                    FusionTag(
                        bridge.agentName(for: task.agentId),
                        icon: "person",
                        color: .blue
                    )
                    if !task.graphId.isEmpty {
                        let gname = bridge.graphName(for: task.graphId)
                        FusionTag(
                            gname.isEmpty ? "workflow" : gname,
                            icon: "arrow.triangle.branch",
                            color: .purple
                        )
                    }
                    if !task.projectId.isEmpty {
                        FusionTag(task.projectId, icon: "folder", color: .green)
                    }
                    if task.trigger == .cron {
                        Text(nextRunText(task))
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Spacer()
                    Text(task.createdAt, style: .relative)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }

                if !task.lastResult.isEmpty {
                    Text(task.lastResult.prefix(80))
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                if !task.lastError.isEmpty {
                    Text(task.lastError.prefix(80))
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.errorText)
                        .lineLimit(1)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTask = task
        }
        .contextMenu {
            if !task.status.isTerminal {
                Button("Cancel", role: .destructive) {
                    Task { await bridge.taskCancel(task.id) }
                    toastManager.show(style: .info, title: "Task Cancelled", message: task.title)
                }
            }
            Button("Rerun") {
                Task { await bridge.taskRerun(task.id) }
                toastManager.show(style: .success, title: "Task Rerun", message: task.title)
            }
            Button("Delete", role: .destructive) {
                bridge.taskDelete(task.id)
            }
        }
    }

    private func triggerColor(_ t: TaskModel.TaskTrigger) -> TagColor {
        switch t {
        case .immediate: return .green
        case .cron:      return .orange
        case .runAt:     return .blue
        }
    }

    private func nextRunText(_ task: TaskModel) -> String {
        if let runAt = task.runAt {
            let fmt = DateFormatter()
            fmt.dateFormat = "MM-dd HH:mm"
            return "at \(fmt.string(from: runAt))"
        }
        if !task.cronExpression.isEmpty {
            return "cron \(task.cronExpression)"
        }
        return ""
    }

    private var emptyTasksPlaceholder: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("No tasks yet")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Text("Create a task to assign work to agents")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
    }
}

// MARK: - CreateTaskSheet

struct CreateTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.studioTheme) var theme
    @EnvironmentObject private var bridge: AgentBridge
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var title = ""
    @State private var description = ""
    @State private var selectedAgent = ""
    @State private var selectedGraph = ""
    @State private var selectedProject = ""
    @State private var newProjectName = ""
    @State private var trigger: TaskModel.TaskTrigger = .immediate
    @State private var cronExpression = "0 * * * *"
    @State private var runAtDate = Date().addingTimeInterval(3600)
    @State private var input = ""
    @State private var priority: AgentTask.TaskPriority = .medium
    let toastManager: FusionToastManager

    private let cronPresets: [(String, String)] = [
        ("Every hour", "0 * * * *"),
        ("Every 30 min", "*/30 * * * *"),
        ("Daily 9am", "0 9 * * *"),
    ]

    private var canCreate: Bool {
        guard !title.isEmpty, !selectedAgent.isEmpty else { return false }
        if trigger == .cron && cronExpression.isEmpty { return false }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                Text("New Task")
                    .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)

                FusionCard(style: .bordered) {
                    VStack(spacing: theme.spacingM) {
                        labeledField("Title") {
                            textEditor($title, placeholder: "Task title")
                        }

                        labeledField("Description") {
                            textEditor($description, placeholder: "Describe the task...")
                        }

                        labeledField("Assign Agent") {
                            Picker("Agent", selection: $selectedAgent) {
                                if bridge.agentState.agents.isEmpty && orchestrator.agents.isEmpty {
                                    Text("No agents available").tag("")
                                }
                                if !bridge.agentState.agents.isEmpty {
                                    Section("Backend Agents") {
                                        ForEach(bridge.agentState.agents) { agent in
                                            Label(agent.name, systemImage: "brain.head.profile").tag(agent.id)
                                        }
                                    }
                                }
                                if !orchestrator.agents.isEmpty {
                                    Section("Built-in Agents") {
                                        ForEach(orchestrator.agents) { agent in
                                            Label(agent.name, systemImage: agent.type.icon).tag(agent.id)
                                        }
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        labeledField("Workflow (optional)") {
                            Picker("Workflow", selection: $selectedGraph) {
                                Text("None (single agent step)").tag("")
                                ForEach(bridge.agentState.graphs) { g in
                                    Text(g.name).tag(g.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        labeledField("Project (optional)") {
                            VStack(spacing: theme.spacingXS) {
                                Picker("Project", selection: $selectedProject) {
                                    Text("No project").tag("")
                                    ForEach(bridge.taskState.projects) { p in
                                        Text("\(p.id) (\(p.total))").tag(p.id)
                                    }
                                    Text("New project…").tag("__new__")
                                }
                                .pickerStyle(.menu)
                                if selectedProject == "__new__" {
                                    textEditor($newProjectName, placeholder: "New project id (e.g. release-v1)")
                                        .font(.system(size: theme.footnoteSize))
                                }
                            }
                        }

                        labeledField("Trigger") {
                            Picker("Trigger", selection: $trigger) {
                                ForEach(TaskModel.TaskTrigger.allCases) { t in
                                    Label(t.rawValue, systemImage: t.icon).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if trigger == .cron {
                            labeledField("Cron Expression") {
                                VStack(spacing: theme.spacingXS) {
                                    textEditor($cronExpression, placeholder: "*/5 * * * *")
                                        .font(.system(.body, design: .monospaced))
                                    HStack(spacing: theme.spacingS) {
                                        ForEach(cronPresets, id: \.1) { label, expr in
                                            FusionButton(label, style: .tinted, size: .small) {
                                                cronExpression = expr
                                            }
                                        }
                                    }
                                    Text("Format: minute hour day month weekday")
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.textTertiary)
                                }
                            }
                        } else if trigger == .runAt {
                            labeledField("Run Once At") {
                                DatePicker("When", selection: $runAtDate, in: Date()...)
                                    .labelsHidden()
                            }
                        }

                        labeledField("Priority") {
                            Picker("Priority", selection: $priority) {
                                ForEach(AgentTask.TaskPriority.allCases, id: \.self) { p in
                                    Text(p.rawValue).tag(p)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        labeledField("Input") {
                            VStack(spacing: theme.spacingXS) {
                                TextEditor(text: $input)
                                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                                    .frame(minHeight: 60)
                                    .padding(theme.spacingS)
                                    .background(theme.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .stroke(theme.inputBorder, lineWidth: 1)
                                    }
                                Text("Execution input sent to agent / workflow")
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                    }
                }

                HStack(spacing: theme.spacingM) {
                    FusionButton("Cancel", style: .secondary, size: .regular) { dismiss() }
                    FusionButton("Create", icon: "plus", style: .primary, size: .regular, isDisabled: !canCreate) {
                        createTask()
                    }
                }
            }
            .padding(theme.spacingXL)
            .frame(width: 460)
            .background(theme.windowBg)
        }
        .frame(width: 480, height: 640)
        .onAppear { Task { await bridge.fetchProjects() } }
    }

    private func createTask() {
        // __new__ 占位 → 取 newProjectName 为 project_id; 空则不入 project.
        let effectiveProject = selectedProject == "__new__"
            ? newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
            : selectedProject
        Task {
            do {
                let task = try await bridge.taskSubmit(
                    title: title,
                    description: description,
                    agentId: selectedAgent,
                    graphId: selectedGraph,
                    trigger: trigger,
                    cronExpression: trigger == .cron ? cronExpression : "",
                    runAt: trigger == .runAt ? runAtDate : nil,
                    input: input,
                    priority: priority,
                    projectId: effectiveProject
                )
                switch trigger {
                case .immediate:
                    await MainActor.run { bridge.taskExecuteImmediate(task.id) }
                case .cron:
                    // 后端 task.submit 已自动注册 cron job (需 graph_id); 无 graph_id 时前端补注册.
                    if selectedGraph.isEmpty {
                        bridge.taskScheduleCron(task.id, expression: cronExpression, input: input)
                    }
                case .runAt:
                    bridge.taskScheduleRunAt(task.id, runAt: runAtDate, input: input)
                }
                await MainActor.run {
                    toastManager.show(style: .success, title: "Task Created", message: title)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(label)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func textEditor(_ text: Binding<String>, placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .padding(theme.spacingS)
            .background(theme.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .stroke(theme.inputBorder, lineWidth: 1)
            }
    }
}

// MARK: - TaskDetailView

struct AgentTaskDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.studioTheme) var theme
    @EnvironmentObject private var bridge: AgentBridge
    let taskId: String
    let toastManager: FusionToastManager
    @State private var executions: [CronExecutionModel] = []
    @State private var isLoadingExec = false

    private var task: TaskModel? {
        bridge.taskState.tasks.first(where: { $0.id == taskId })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                if let task {
                    HStack(spacing: theme.spacingM) {
                        Image(systemName: task.trigger.icon)
                            .font(.system(size: theme.iconXL))
                            .foregroundStyle(theme.accent)
                            .frame(width: 40, height: 40)
                            .background(theme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text(task.title)
                                .font(.system(size: theme.titleSize, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.text)
                            HStack(spacing: theme.spacingS) {
                                StatusPill(status: task.status.pillStatus, compact: true)
                                Text(task.id)
                                    .font(.system(size: theme.captionSize, design: .monospaced))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                        Spacer()
                        FusionButton("Close", icon: "xmark", style: .secondary, size: .small) { dismiss() }
                    }

                    FusionCard(style: .inset, header: "Details", headerIcon: "info.circle") {
                        VStack(spacing: theme.spacingS) {
                            detailRow("Agent", bridge.agentName(for: task.agentId))
                            if !task.graphId.isEmpty {
                                let gname = bridge.graphName(for: task.graphId)
                                detailRow("Workflow", gname.isEmpty ? task.graphId : gname)
                            }
                            if !task.projectId.isEmpty {
                                detailRow("Project", task.projectId)
                            }
                            detailRow("Trigger", task.trigger.rawValue)
                            if !task.cronExpression.isEmpty {
                                detailRow("Cron", task.cronExpression)
                            }
                            if let runAt = task.runAt {
                                detailRow("Run At", runAtText(runAt))
                            }
                            if !task.sessionId.isEmpty {
                                detailRow("Session", task.sessionId)
                            }
                            if !task.cronJobId.isEmpty {
                                detailRow("Cron Job", task.cronJobId)
                            }
                        }
                    }

                    if !task.input.isEmpty {
                        FusionCard(style: .inset, header: "Input", headerIcon: "text.alignleft") {
                            Text(task.input)
                                .font(.system(size: theme.footnoteSize, design: .monospaced))
                                .foregroundStyle(theme.textSecondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !task.lastError.isEmpty {
                        FusionCard(style: .inset, header: "Error", headerIcon: "exclamationmark.triangle") {
                            Text(task.lastError)
                                .font(.system(size: theme.footnoteSize, design: .monospaced))
                                .foregroundStyle(theme.errorText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !task.lastResult.isEmpty {
                        FusionCard(style: .inset, header: "Result", headerIcon: "checkmark.circle") {
                            ScrollView {
                                Text(task.lastResult)
                                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 240)
                        }
                    }

                    if (task.trigger == .cron || task.trigger == .runAt) && !task.cronJobId.isEmpty {
                        FusionCard(style: .inset, header: "Execution History", headerIcon: "clock.arrow.2.circlepath") {
                            if isLoadingExec {
                                ProgressView().padding()
                            } else if executions.isEmpty {
                                Text("No executions recorded")
                                    .font(.system(size: theme.footnoteSize))
                                    .foregroundStyle(theme.textTertiary)
                                    .padding(.vertical, theme.spacingS)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(executions.enumerated()), id: \.element.id) { idx, exe in
                                        HStack(spacing: theme.spacingS) {
                                            Circle().fill(exe.statusColor).frame(width: 8, height: 8)
                                            Text(exe.startedAtText).font(.system(size: theme.captionSize, design: .monospaced))
                                            Text(exe.durationText).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                                            Spacer()
                                            Text(exe.status).font(.system(size: theme.captionSize)).foregroundStyle(exe.statusColor)
                                        }
                                        .padding(.vertical, theme.spacingS)
                                        if idx < executions.count - 1 {
                                            Divider().foregroundStyle(theme.rowSep)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: theme.spacingM) {
                        if !task.status.isTerminal {
                            FusionButton("Cancel", icon: "stop.fill", style: .destructive, size: .small) {
                                Task { await bridge.taskCancel(task.id) }
                                toastManager.show(style: .info, title: "Cancelled", message: task.title)
                            }
                        }
                        FusionButton("Rerun", icon: "arrow.clockwise", style: .secondary, size: .small) {
                            Task { await bridge.taskRerun(task.id) }
                            toastManager.show(style: .success, title: "Rerun Started", message: task.title)
                            loadExecutions(cronJobId: task.cronJobId)
                        }
                    }
                } else {
                    Text("Task not found")
                        .foregroundStyle(theme.textTertiary)
                        .padding()
                }
            }
            .padding(theme.spacingL)
        }
        .frame(width: 560, height: 600)
        .background(theme.windowBg)
        .onAppear {
            if let task, (task.trigger == .cron || task.trigger == .runAt) && !task.cronJobId.isEmpty {
                loadExecutions(cronJobId: task.cronJobId)
            }
        }
    }

    private func runAtText(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: date)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            Text(label)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func loadExecutions(cronJobId: String) {
        isLoadingExec = true
        Task {
            do {
                let result = try await bridge.cronListExecutions(jobId: cronJobId)
                await MainActor.run {
                    self.executions = result.map { CronExecutionModel(from: $0) }
                    self.isLoadingExec = false
                }
            } catch {
                await MainActor.run { self.isLoadingExec = false }
            }
        }
    }
}

// MARK: - TaskBoardView

struct TaskBoardView: View {
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var selectedTask: TaskModel?
    let toastManager: FusionToastManager

    private var columns: [(TaskModel.TaskStatus, [TaskModel])] {
        let order: [TaskModel.TaskStatus] = [.pending, .queued, .scheduled, .running, .failed, .completed, .cancelled]
        return order.map { status in
            (status, bridge.taskState.tasks.filter { $0.status == status })
        }.filter { !$0.1.isEmpty || $0.0 == .pending || $0.0 == .running }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: theme.spacingM) {
                ForEach(columns, id: \.0) { status, tasks in
                    boardColumn(status: status, tasks: tasks)
                }
            }
            .padding(theme.spacingM)
        }
        .sheet(item: $selectedTask) { task in
            AgentTaskDetailView(taskId: task.id, toastManager: toastManager)
        }
    }

    private func boardColumn(status: TaskModel.TaskStatus, tasks: [TaskModel]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingS) {
                Circle()
                    .fill(status.pillStatus == .error ? theme.errorText : theme.accent)
                    .frame(width: 8, height: 8)
                Text(status.rawValue)
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Text("\(tasks.count)")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, theme.spacingS)

            VStack(spacing: theme.spacingS) {
                ForEach(tasks) { task in
                    boardCard(task: task)
                }
                if tasks.isEmpty {
                    Text("—")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacingS)
                }
            }
        }
        .frame(width: 260, alignment: .leading)
        .padding(theme.spacingS)
        .background(theme.groupBg)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.rowSep, lineWidth: 1)
        }
    }

    private func boardCard(task: TaskModel) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(task.title)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.text)
                .lineLimit(2)

            if !task.description.isEmpty {
                Text(task.description)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }

            HStack(spacing: theme.spacingXS) {
                FusionTag(bridge.agentName(for: task.agentId), icon: "person", color: .blue)
                if !task.graphId.isEmpty {
                    FusionTag("workflow", icon: "arrow.triangle.branch", color: .purple)
                }
                if !task.projectId.isEmpty {
                    FusionTag(task.projectId, icon: "folder", color: .green)
                }
                Spacer()
                FusionTag(task.trigger.rawValue, icon: task.trigger.icon, color: .gray)
            }
        }
        .padding(theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.inputBg)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { selectedTask = task }
        .contextMenu {
            if !task.status.isTerminal {
                Button("Cancel", role: .destructive) {
                    Task { await bridge.taskCancel(task.id) }
                }
            }
            Button("Rerun") { Task { await bridge.taskRerun(task.id) } }
            Button("Delete", role: .destructive) { bridge.taskDelete(task.id) }
        }
    }
}

// MARK: - WorkflowListView

struct WorkflowListView: View {
    @EnvironmentObject private var bridge: AgentBridge
    @State private var detailMode: DetailMode = .empty
    @State private var searchText = ""
    @State private var isLoading = false
    let toastManager: FusionToastManager

    @Environment(\.studioTheme) var theme

    private enum DetailMode {
        case empty
        case creating
        case editing(AgentGraphModel)
    }

    private var filteredGraphs: [AgentGraphModel] {
        guard !searchText.isEmpty else { return bridge.agentState.graphs }
        return bridge.agentState.graphs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            workflowListPanel
                .frame(minWidth: 240, idealWidth: 320, maxWidth: 420)

            detailView
                .frame(minWidth: 900)
        }
        .toolbar {
            ToolbarItem {
                FusionButton("Refresh", icon: "arrow.clockwise", style: .secondary, size: .small, isDisabled: isLoading) {
                    Task { await refreshGraphs() }
                }
            }
            ToolbarItem {
                FusionButton("Create Workflow", icon: "plus", style: .primary, size: .small) {
                    workflowLog.info("detailMode -> .creating")
                    detailMode = .creating
                }
            }
        }
        .task {
            // 已有数据不重拉, 避免每次切 tab 都 fetch 触发 body 重算导致转圈
            if bridge.agentState.graphs.isEmpty {
                await loadGraphs()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch detailMode {
        case .empty:
            emptyWorkflowPlaceholder
        case .creating:
            AgentWorkflowCanvasView(mode: .create, toastManager: toastManager) {
                Task { await refreshGraphs() }
            }
        case .editing(let graph):
            AgentWorkflowCanvasView(mode: .edit(graph), toastManager: toastManager) {
                Task { await refreshGraphs() }
            }
        }
    }

    private func loadGraphs() async {
        guard !isLoading else { return }
        isLoading = true
        // defer 保证 task 被取消(tab 切走)时 isLoading 也能复位, 避免卡转圈
        defer { isLoading = false }
        let t0 = Date()
        do {
            try await bridge.fetchGraphs()
            let elapsed = Int(Date().timeIntervalSince(t0) * 1000)
            workflowLog.info("WorkflowListView loaded \(bridge.agentState.graphs.count) graphs in \(elapsed)ms")
        } catch {
            let elapsed = Int(Date().timeIntervalSince(t0) * 1000)
            workflowLog.error("WorkflowListView loadGraphs failed in \(elapsed)ms: \(error)")
            toastManager.show(style: .warning, title: "Load Failed", message: "无法加载流水线: \(error.localizedDescription)")
        }
    }

    private func refreshGraphs() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await bridge.fetchGraphs()
            workflowLog.info("WorkflowListView refreshed \(bridge.agentState.graphs.count) graphs")
        } catch {
            workflowLog.error("WorkflowListView refresh failed: \(error)")
        }
    }

    private var workflowListPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                StudioSectionHeader(title: "Workflows")
                searchBox
                if isLoading && bridge.agentState.graphs.isEmpty {
                    VStack(spacing: theme.spacingS) {
                        ProgressView()
                        Text("Loading workflows...")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(.vertical, theme.spacing2XL)
                } else if filteredGraphs.isEmpty {
                    VStack(spacing: theme.spacingM) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.textTertiary)
                        Text(searchText.isEmpty ? "No workflows yet - create one" : "No matching workflows")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(.vertical, theme.spacing2XL)
                } else {
                    ListGroup {
                        ForEach(Array(filteredGraphs.enumerated()), id: \.element.id) { index, graph in
                            StudioRow(label: graph.name, sublabel: "\(graph.nodeCount) nodes, \(graph.edgeCount) edges", isLast: index == filteredGraphs.count - 1) {
                                FusionTag("graph", color: .green)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task {
                                    if let fresh = try? await bridge.graphGet(graphId: graph.id) {
                                        workflowLog.info("detailMode -> .editing(\(fresh.id, privacy: .public))")
                                        detailMode = .editing(fresh)
                                    } else {
                                        workflowLog.info("detailMode -> .editing(\(graph.id, privacy: .public)) fallback")
                                        detailMode = .editing(graph)
                                    }
                                }
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    deleteGraph(graph)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var searchBox: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
            TextField("Search workflows (e.g. douyin)", text: $searchText)
                .font(.system(size: theme.footnoteSize))
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private func deleteGraph(_ graph: AgentGraphModel) {
        Task {
            do {
                try await bridge.deleteGraph(id: graph.id)
                if case .editing(let g) = detailMode, g.id == graph.id {
                    workflowLog.info("detailMode -> .empty (deleted current)")
                    detailMode = .empty
                }
                // 删除成功立即刷新列表, 否则列表仍显示已删项, 再次删除会触发 Graph not found
                try await bridge.fetchGraphs()
                toastManager.show(style: .info, title: "Workflow Deleted", message: graph.name)
            } catch {
                toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
            }
        }
    }

    private var emptyWorkflowPlaceholder: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)
            Text("Select a workflow to view details")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
