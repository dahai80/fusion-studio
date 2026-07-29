// Callers: ModuleDetailView routing (.desk → DeskView).
// Affected API: DeskView 8-tab IPC architecture + 9 new bridge method GUI interactions.
// Data schemas: DeskBridge @EnvironmentObject, DeskNodeDetail, DeskTemplateDetail, DeskWorkflowExecStatus, DeskMLXModel, event subscribe/poll.
// User instruction: "补充9个方法的桥接和对应的GUI交互"

import SwiftUI

enum DeskTab: String, CaseIterable, Identifiable {
    case templates  = "模板"
    case workflows  = "工作流"
    case agents     = "智能体"
    case sessions   = "会话"
    case permissions = "权限"
    case mlx        = "MLX"
    case system     = "系统"
    case events     = "事件"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .templates:   return "square.stack"
        case .workflows:   return "arrow.triangle.branch"
        case .agents:      return "person.2.fill"
        case .sessions:    return "clock.arrow.circlepath"
        case .permissions: return "lock.shield"
        case .mlx:         return "cpu"
        case .system:      return "desktopcomputer"
        case .events:      return "bell.badge"
        }
    }
}

// MARK: - Main DeskView

struct DeskView: View {
    @EnvironmentObject var bridge: DeskBridge
    @Environment(\.studioTheme) private var theme
    @State private var selectedTab: DeskTab = .templates

    var body: some View {
        VStack(spacing: 0) {
            deskTabBar
            Divider()
            if !bridge.isConnected {
                disconnectedView
            } else {
                tabContent
            }
        }
        .task {
            await bridge.loadAll()
        }
    }

    private var deskTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(DeskTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? theme.accentText : theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedTab == tab ? theme.accent : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(theme.toolbarBg)
    }

    private var disconnectedView: some View {
        VStack(spacing: 0) {
            UpstreamServiceStatusBanner(serviceId: "fusion-desk")
            Divider()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text("Fusion-Desk 服务未连接")
                    .font(.title3)
                    .foregroundColor(theme.text)
                Text("请启动 fusion-desk 服务后重试（需在 fusion-desk 根目录创建 start.sh）")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("重新连接") {
                    Task { await bridge.loadAll() }
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .templates:   DeskTemplateTab()
        case .workflows:   DeskWorkflowTab()
        case .agents:      DeskAgentTab()
        case .sessions:    DeskSessionTab()
        case .permissions: DeskPermissionTab()
        case .mlx:         DeskMLXTab()
        case .system:      DeskSystemTab()
        case .events:      DeskEventsTab()
        }
    }
}

// MARK: - Template Tab (uses getTemplate for detail popup)

struct DeskTemplateTab: View {
    @EnvironmentObject var bridge: DeskBridge
    @Environment(\.studioTheme) private var theme
    @State private var searchText = ""
    @State private var runningTemplateId: String?
    @State private var runResult: String?
    @State private var showDetail = false

    var filteredTemplates: [DeskTemplateInfo] {
        if searchText.isEmpty { return bridge.templates }
        return bridge.templates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.textTertiary)
                TextField("搜索模板...", text: $searchText)
                    .textFieldStyle(.plain)
                Spacer()
                Text("\(bridge.templates.count) 个模板")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
                Button(action: { Task { await bridge.loadTemplates() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.surfaceSecondary)

            Divider()

            if bridge.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTemplates.isEmpty {
                deskEmptyState(icon: "square.stack", text: "暂无模板")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredTemplates) { tpl in
                            HStack(spacing: 12) {
                                Image(systemName: "square.stack")
                                    .foregroundColor(theme.accent)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tpl.name)
                                        .font(.headline)
                                        .foregroundColor(theme.text)
                                    Text(tpl.description)
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if !tpl.category.isEmpty {
                                    Text(tpl.category)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(theme.accentSoft)
                                        .cornerRadius(4)
                                }

                                Button(action: { showTemplateDetail(tpl.id) }) {
                                    Image(systemName: "info.circle")
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)

                                Button(action: { runTemplate(tpl) }) {
                                    Image(systemName: "play.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(runningTemplateId != nil)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.surfaceSecondary)
                            .cornerRadius(8)
                        }
                    }
                    .padding(12)
                }
            }

            if let result = runResult {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(result)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Button("关闭") { runResult = nil }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.surfaceElevated)
            }
        }
        .sheet(isPresented: $showDetail) {
            templateDetailSheet
        }
    }

    private var templateDetailSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("模板详情")
                    .font(.title3)
                    .foregroundColor(theme.text)
                Spacer()
                Button("关闭") { showDetail = false }
                    .buttonStyle(.borderless)
            }

            if let detail = bridge.selectedTemplateDetail {
                Group {
                    LabeledContent("名称", value: detail.name)
                    LabeledContent("分类", value: detail.category)
                    LabeledContent("描述", value: detail.description)
                }
                .font(.subheadline)

                if !detail.steps.isEmpty {
                    Divider()
                    Text("步骤")
                        .font(.headline)
                        .foregroundColor(theme.text)
                    ForEach(detail.steps.indices, id: \.self) { i in
                        let step = detail.steps[i]
                        HStack(spacing: 8) {
                            Text("\(i + 1)")
                                .font(.caption)
                                .foregroundColor(theme.accent)
                                .frame(width: 20)
                            Text(step["name"] ?? "Step \(i + 1)")
                                .foregroundColor(theme.text)
                            Spacer()
                            if let node = step["node"] {
                                Text(node)
                                    .font(.caption)
                                    .foregroundColor(theme.textTertiary)
                            }
                        }
                        .font(.subheadline)
                    }
                }
            } else {
                ProgressView("加载中...")
            }
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 300)
        .background(theme.contentBg)
    }

    private func showTemplateDetail(_ id: String) {
        Task {
            await bridge.getTemplate(templateId: id)
            showDetail = true
        }
    }

    private func runTemplate(_ tpl: DeskTemplateInfo) {
        runningTemplateId = tpl.id
        Task {
            let result = await bridge.runTemplate(templateId: tpl.id)
            runningTemplateId = nil
            if let r = result {
                let status = r["status"] as? String ?? "unknown"
                runResult = "模板 \(tpl.name): \(status)"
            } else {
                runResult = "模板 \(tpl.name): 执行失败"
            }
        }
    }
}

// MARK: - Workflow Tab (uses getWorkflowStatus for execution tracking)

struct DeskWorkflowTab: View {
    @EnvironmentObject var bridge: DeskBridge
    @Environment(\.studioTheme) private var theme
    @State private var promptText = ""
    @State private var showExecStatus = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("输入自然语言创建工作流...", text: $promptText)
                    .textFieldStyle(.plain)
                    .onSubmit { createWorkflow() }

                Button(action: createWorkflow) {
                    Label("创建", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(promptText.isEmpty)

                Spacer()

                Text("\(bridge.workflows.count) 个工作流")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)

                Button("执行状态") {
                    Task {
                        await bridge.getWorkflowStatus()
                        showExecStatus = true
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { Task { await bridge.loadWorkflows() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.surfaceSecondary)

            Divider()

            if bridge.isLoading {
                ProgressView("加载中...").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bridge.workflows.isEmpty {
                deskEmptyState(icon: "arrow.triangle.branch", text: "暂无工作流，输入提示语创建")
            } else {
                List(bridge.workflows) { wf in
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(theme.accent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(wf.name)
                                .font(.headline)
                                .foregroundColor(theme.text)
                            Text(wf.summary)
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        Text(wf.status)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.accentSoft)
                            .cornerRadius(4)

                        Button(action: { cancelWorkflow(wf.id) }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(theme.accentDestructive)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(isPresented: $showExecStatus) {
            workflowExecStatusSheet
        }
    }

    private var workflowExecStatusSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("工作流执行状态")
                    .font(.title3)
                    .foregroundColor(theme.text)
                Spacer()
                Button("刷新") {
                    Task { await bridge.getWorkflowStatus() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("关闭") { showExecStatus = false }
                    .buttonStyle(.borderless)
            }

            if bridge.workflowExecStatuses.isEmpty {
                Text("当前无执行中的工作流")
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(Array(bridge.workflowExecStatuses.values), id: \.executionId) { ex in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(ex.executionId)
                                .font(.headline)
                                .foregroundColor(theme.text)
                            Spacer()
                            Text(ex.status)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ex.status == "completed" ? Color.green.opacity(0.15) : theme.accentSoft)
                                .foregroundColor(ex.status == "completed" ? .green : theme.accent)
                                .cornerRadius(4)
                        }
                        if !ex.currentNode.isEmpty {
                            Text("当前节点: \(ex.currentNode)")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }
                        if ex.progress > 0 {
                            ProgressView(value: ex.progress)
                                .progressViewStyle(.linear)
                        }
                        if !ex.result.isEmpty {
                            Text(ex.result)
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 300)
        .background(theme.contentBg)
    }

    private func createWorkflow() {
        guard !promptText.isEmpty else { return }
        let prompt = promptText
        promptText = ""
        Task {
            let result = await bridge.createWorkflow(prompt: prompt)
            if let _ = result {
                await bridge.loadWorkflows()
            }
        }
    }

    private func cancelWorkflow(_ executionId: String) {
        Task {
            await bridge.cancelWorkflow(executionId: executionId)
            await bridge.getWorkflowStatus()
        }
    }
}

// MARK: - Agent Tab (uses getNodeInfo for node detail in system tab, kept here unchanged)

struct DeskAgentTab: View {
    @EnvironmentObject var bridge: DeskBridge
    @Environment(\.studioTheme) private var theme
    @State private var taskInput = ""
    @State private var submittedTaskId: String?
    @State private var agentStatusDetail: [String: Any]?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("提交任务给智能体...", text: $taskInput)
                    .textFieldStyle(.plain)
                    .onSubmit { submitTask() }

                Button(action: submitTask) {
                    Label("提交", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(taskInput.isEmpty)

                Spacer()

                Text("\(bridge.agents.count) 个智能体")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)

                Button(action: { Task { await bridge.loadAgents() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.surfaceSecondary)

            Divider()

            if bridge.agents.isEmpty {
                deskEmptyState(icon: "person.2.fill", text: "暂无智能体")
            } else {
                List(bridge.agents) { agent in
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundColor(theme.accent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(agent.name)
                                .font(.headline)
                                .foregroundColor(theme.text)
                            Text("ID: \(agent.id)")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }

                        Spacer()

                        Text(agent.status)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.accentSoft)
                            .cornerRadius(4)

                        Button(action: { checkAgentStatus(agent.id) }) {
                            Image(systemName: "eye")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)

                        Button(action: { cancelTask(agent.id) }) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(theme.accentDestructive)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let tid = submittedTaskId {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("任务 \(tid) 已提交")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Button("查看状态") {
                        Task { checkAgentStatus(tid) }
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    Button("关闭") { submittedTaskId = nil }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.surfaceElevated)
            }

            if let status = agentStatusDetail {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("状态: \(status["status"] as? String ?? "unknown")")
                            .font(.caption)
                            .foregroundColor(theme.text)
                        if let progress = status["progress"] as? Double {
                            Text("进度: \(String(format: "%.0f%%", progress * 100))")
                                .font(.caption2)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    Spacer()
                    Button("关闭") { agentStatusDetail = nil }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.surfaceElevated)
            }
        }
    }

    private func submitTask() {
        guard !taskInput.isEmpty else { return }
        let task = taskInput
        taskInput = ""
        Task {
            let tid = await bridge.submitAgentTask(task: task)
            if let tid = tid {
                submittedTaskId = tid
                await bridge.loadAgents()
            }
        }
    }

    private func checkAgentStatus(_ taskId: String) {
        Task {
            if let result = await bridge.getAgentStatus(taskId: taskId) {
                agentStatusDetail = result
            }
        }
    }

    private func cancelTask(_ taskId: String) {
        Task {
            await bridge.cancelAgentTask(taskId: taskId)
            await bridge.loadAgents()
        }
    }
}

// MARK: - Session Tab (uses getSession, updateSession)

struct DeskSessionTab: View {
    @EnvironmentObject var bridge: DeskBridge
    @Environment(\.studioTheme) private var theme
    @State private var newSessionName = ""
    @State private var showCreateSession = false
    @State private var showEditSession = false
    @State private var editingSessionId: String?
    @State private var editSessionName = ""
    @State private var editSessionDesc = ""
    @State private var sessionDetail: DeskSession?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer()
                Button(action: { showCreateSession = true }) {
                    Label("新建会话", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Text("\(bridge.sessions.count) 个会话")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)

                Button(action: { Task { await bridge.loadSessions() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.surfaceSecondary)

            Divider()

            if bridge.sessions.isEmpty {
                deskEmptyState(icon: "clock.arrow.circlepath", text: "暂无会话")
            } else {
                List(bridge.sessions) { session in
                    HStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(theme.accent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.name)
                                .font(.headline)
                                .foregroundColor(theme.text)
                            HStack(spacing: 8) {
                                Text("步骤: \(session.steps)")
                                    .font(.caption)
                                    .foregroundColor(theme.textTertiary)
                                if let updated = session.updatedAt {
                                    Text(updated)
                                        .font(.caption2)
                                        .foregroundColor(theme.textQuaternary)
                                }
                            }
                        }

                        Spacer()

                        Text(session.status)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.accentSoft)
                            .cornerRadius(4)

                        Button(action: { loadSessionDetail(session.id) }) {
                            Image(systemName: "eye")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)

                        Menu {
                            Button("编辑") {
                                editingSessionId = session.id
                                editSessionName = session.name
                                editSessionDesc = ""
                                showEditSession = true
                            }
                            Button("分叉") {
                                Task { await bridge.forkSession(sessionId: session.id) }
                            }
                            Button("删除", role: .destructive) {
                                Task { await bridge.deleteSession(sessionId: session.id) }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .alert("新建会话", isPresented: $showCreateSession) {
            TextField("会话名称", text: $newSessionName)
            Button("取消", role: .cancel) { newSessionName = "" }
            Button("创建") {
                guard !newSessionName.isEmpty else { return }
                let name = newSessionName
                newSessionName = ""
                Task { await bridge.createSession(name: name) }
            }
        }
        .alert("编辑会话", isPresented: $showEditSession) {
            TextField("名称", text: $editSessionName)
            TextField("描述", text: $editSessionDesc)
            Button("取消", role: .cancel) {}
            Button("保存") {
                guard let sid = editingSessionId, !editSessionName.isEmpty else { return }
                var updates: [String: Any] = ["name": editSessionName]
                if !editSessionDesc.isEmpty {
                    updates["description"] = editSessionDesc
                }
                Task { await bridge.updateSession(sessionId: sid, updates: updates) }
            }
        }
        .sheet(isPresented: .init(
            get: { sessionDetail != nil },
            set: { if !$0 { sessionDetail = nil } }
        )) {
            sessionDetailSheet
        }
    }

    private var sessionDetailSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("会话详情")
                    .font(.title3)
                    .foregroundColor(theme.text)
                Spacer()
                Button("关闭") { sessionDetail = nil }
                    .buttonStyle(.borderless)
            }

            if let s = sessionDetail {
                Group {
                    LabeledContent("ID", value: s.id)
                    LabeledContent("名称", value: s.name)
                    LabeledContent("状态", value: s.status)
                    LabeledContent("步骤数", value: "\(s.steps)")
                }
                .font(.subheadline)
            }
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 350, minHeight: 250)
        .background(theme.contentBg)
    }

    private func loadSessionDetail(_ sessionId: String) {
        Task {
            sessionDetail = await bridge.getSession(sessionId: sessionId)
        }
    }
}

// MARK: - Permission Tab (uses checkPermission)

struct DeskPermissionTab: View {
    @EnvironmentObject var bridge: DeskBridge
    @Environment(\.studioTheme) private var theme
    @State private var checkToolName = ""
    @State private var showCheckResult = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("权限规则")
                    .font(.headline)
                    .foregroundColor(theme.text)

                Spacer()

                HStack(spacing: 4) {
                    TextField("检查工具", text: $checkToolName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .controlSize(.small)
                    Button("检查") {
                        guard !checkToolName.isEmpty else { return }
                        Task {
                            await bridge.checkPermission(toolName: checkToolName)
                            showCheckResult = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button("重置全部") {
                    Task { await bridge.resetPermissions() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(theme.accentDestructive)

                Button(action: { Task { await bridge.loadPermissions() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.surfaceSecondary)

            Divider()

            if showCheckResult, let result = bridge.permissionCheckResult {
                HStack(spacing: 8) {
                    let allowed = result["allowed"] as? Bool ?? false
                    Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(allowed ? .green : .red)
                    Text("工具 \(checkToolName): \(allowed ? "允许" : "拒绝")")
                        .font(.caption)
                        .foregroundColor(theme.text)
                    Spacer()
                    Button("关闭") { showCheckResult = false }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.surfaceElevated)
            }

            if bridge.permissions.isEmpty {
                deskEmptyState(icon: "lock.shield", text: "暂无权限规则")
            } else {
                List(bridge.permissions) { rule in
                    HStack(spacing: 12) {
                        Image(systemName: rule.allowed ? "checkmark.shield.fill" : "xmark.shield.fill")
                            .foregroundColor(rule.allowed ? .green : .red)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.toolName)
                                .font(.headline)
                                .foregroundColor(theme.text)
                            Text("范围: \(rule.scope)")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }

                        Spacer()

                        Text(rule.allowed ? "允许" : "拒绝")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rule.allowed ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                            .foregroundColor(rule.allowed ? .green : .red)
                            .cornerRadius(4)

                        Button("切换") {
                            Task {
                                if rule.allowed {
                                    await bridge.denyPermission(toolName: rule.toolName, scope: rule.scope)
                                } else {
                                    await bridge.approvePermission(toolName: rule.toolName, scope: rule.scope)
                                }
                            }
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - MLX Tab (uses loadMLXModels for dropdown)

struct DeskMLXTab: View {
    @EnvironmentObject var bridge: DeskBridge
    @Environment(\.studioTheme) private var theme
    @State private var startModel = ""
    @State private var showModelPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fusion-MLX 状态")
                        .font(.headline)
                        .foregroundColor(theme.text)
                    if let status = bridge.mlxStatus {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(status.status == "running" ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(status.status == "running" ? "运行中" : "已停止")
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Menu {
                        ForEach(bridge.mlxModels) { model in
                            Button(action: { startModel = model.name }) {
                                HStack {
                                    Text(model.name)
                                    if !model.size.isEmpty {
                                        Text("(\(model.size))")
                                            .foregroundColor(theme.textTertiary)
                                    }
                                }
                            }
                        }
                        if bridge.mlxModels.isEmpty {
                            Text("无可用模型")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                            Text(bridge.mlxModels.isEmpty ? "模型列表" : "\(bridge.mlxModels.count) 个模型")
                        }
                        .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .controlSize(.small)

                    TextField("模型名称", text: $startModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .controlSize(.small)

                    Button("启动") {
                        Task { await bridge.startMLX(model: startModel) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("停止") {
                        Task { await bridge.stopMLX() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(theme.accentDestructive)

                    Button(action: {
                        Task {
                            await bridge.loadMLXStatus()
                            await bridge.loadMLXModels()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(12)
            .background(theme.surfaceSecondary)

            Divider()

            Spacer()

            if let status = bridge.mlxStatus, status.status == "running" {
                VStack(spacing: 16) {
                    Image(systemName: "cpu")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Fusion-MLX 运行中")
                        .font(.title3)
                        .foregroundColor(theme.text)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 48))
                        .foregroundColor(theme.textTertiary)
                    Text("Fusion-MLX 未启动")
                        .font(.title3)
                        .foregroundColor(theme.textSecondary)
                    Text("从模型列表选择或输入名称，点击「启动」")
                        .font(.subheadline)
                        .foregroundColor(theme.textTertiary)
                }
            }

            Spacer()
        }
    }
}

// MARK: - System Tab (uses getNodeInfo for node detail popup)

struct DeskSystemTab: View {
    @EnvironmentObject var bridge: DeskBridge
    @Environment(\.studioTheme) private var theme
    @State private var showNodeDetail = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("系统信息")
                    .font(.headline)
                    .foregroundColor(theme.text)
                Spacer()
                Button(action: {
                    Task {
                        await bridge.loadSystemInfo()
                        await bridge.loadNodeCategories()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.surfaceSecondary)

            Divider()

            if let info = bridge.systemInfo {
                ScrollView {
                    VStack(spacing: 12) {
                        infoRow(icon: "desktopcomputer", label: "平台", value: info.platform)
                        infoRow(icon: "chevron.left.forwardslash.chevron.right", label: "Python", value: info.python)
                        infoRow(icon: "cpu", label: "CPU 核心数", value: "\(info.cpuCount)")
                        infoRow(icon: "memorychip", label: "内存总量", value: "\(String(format: "%.1f", info.memoryTotalGB)) GB")
                        infoRow(icon: "gauge", label: "内存使用", value: "\(String(format: "%.1f", info.memoryUsedPct))%")
                        infoRow(icon: "internaldrive", label: "磁盘剩余", value: "\(String(format: "%.1f", info.diskFreeGB)) GB")

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("节点分类")
                                .font(.headline)
                                .foregroundColor(theme.text)
                            ForEach(bridge.nodeCategories.sorted(by: { $0.key < $1.key }), id: \.key) { cat, count in
                                HStack {
                                    Text(cat)
                                        .foregroundColor(theme.textSecondary)
                                    Spacer()
                                    Text("\(count)")
                                        .foregroundColor(theme.accent)
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(12)
                        .background(theme.surfaceSecondary)
                        .cornerRadius(8)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("节点列表")
                                .font(.headline)
                                .foregroundColor(theme.text)
                            ForEach(bridge.nodes) { node in
                                HStack(spacing: 8) {
                                    Image(systemName: "cube")
                                        .foregroundColor(theme.accent)
                                        .frame(width: 20)
                                    Text(node.name)
                                        .foregroundColor(theme.text)
                                    Spacer()
                                    Text(node.category)
                                        .font(.caption)
                                        .foregroundColor(theme.textTertiary)
                                    Button(action: { loadNodeDetail(node.name) }) {
                                        Image(systemName: "info.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .controlSize(.small)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(12)
                        .background(theme.surfaceSecondary)
                        .cornerRadius(8)
                    }
                    .padding(12)
                }
            } else {
                deskEmptyState(icon: "desktopcomputer", text: "系统信息加载中...")
            }
        }
        .sheet(isPresented: $showNodeDetail) {
            nodeDetailSheet
        }
    }

    private var nodeDetailSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("节点详情")
                    .font(.title3)
                    .foregroundColor(theme.text)
                Spacer()
                Button("关闭") { showNodeDetail = false }
                    .buttonStyle(.borderless)
            }

            if let detail = bridge.selectedNodeDetail {
                Group {
                    LabeledContent("名称", value: detail.name)
                    LabeledContent("分类", value: detail.category)
                    LabeledContent("描述", value: detail.description)
                }
                .font(.subheadline)

                if !detail.inputs.isEmpty {
                    Divider()
                    Text("输入参数")
                        .font(.headline)
                        .foregroundColor(theme.text)
                    ForEach(Array(detail.inputs.sorted(by: { $0.key < $1.key })), id: \.key) { key, val in
                        HStack {
                            Text(key)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            Text(val)
                                .foregroundColor(theme.accent)
                        }
                        .font(.caption)
                    }
                }

                if !detail.outputs.isEmpty {
                    Divider()
                    Text("输出")
                        .font(.headline)
                        .foregroundColor(theme.text)
                    ForEach(Array(detail.outputs.sorted(by: { $0.key < $1.key })), id: \.key) { key, val in
                        HStack {
                            Text(key)
                                .foregroundColor(theme.textSecondary)
                            Spacer()
                            Text(val)
                                .foregroundColor(theme.accent)
                        }
                        .font(.caption)
                    }
                }
            } else {
                ProgressView("加载中...")
            }
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 300)
        .background(theme.contentBg)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(theme.accent)
                .frame(width: 28)
            Text(label)
                .foregroundColor(theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(theme.text)
                .fontWeight(.medium)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
        .cornerRadius(8)
    }

    private func loadNodeDetail(_ name: String) {
        Task {
            await bridge.getNodeInfo(name: name)
            showNodeDetail = true
        }
    }
}

// MARK: - Events Tab (uses subscribeEvents + pollEvents)

struct DeskEventsTab: View {
    @EnvironmentObject var bridge: DeskBridge
    @Environment(\.studioTheme) private var theme
    @State private var isPolling = false
    @State private var pollTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("事件流")
                    .font(.headline)
                    .foregroundColor(theme.text)

                Spacer()

                if bridge.eventSubscriptionId != nil {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isPolling ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(isPolling ? "轮询中" : "已订阅")
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                }

                Text("\(bridge.recentEvents.count) 个事件")
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)

                Button(isPolling ? "停止轮询" : "开始轮询") {
                    togglePolling()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { Task { await bridge.loadRecentEvents() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.surfaceSecondary)

            Divider()

            if bridge.recentEvents.isEmpty {
                deskEmptyState(icon: "bell.badge", text: "暂无事件")
            } else {
                List(bridge.recentEvents) { evt in
                    HStack(spacing: 12) {
                        Image(systemName: eventTypeIcon(evt.type))
                            .foregroundColor(theme.accent)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(evt.type)
                                .font(.headline)
                                .foregroundColor(theme.text)
                            Text("来源: \(evt.source)")
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }

                        Spacer()

                        Text(formatTimestamp(evt.timestamp))
                            .font(.caption2)
                            .foregroundColor(theme.textQuaternary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onDisappear {
            stopPolling()
        }
    }

    private func togglePolling() {
        if isPolling {
            stopPolling()
        } else {
            startPolling()
        }
    }

    private func startPolling() {
        isPolling = true
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                await bridge.pollEvents()
            }
        }
    }

    private func stopPolling() {
        isPolling = false
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func eventTypeIcon(_ type: String) -> String {
        switch type.lowercased() {
        case let t where t.contains("error"): return "exclamationmark.triangle.fill"
        case let t where t.contains("start"): return "play.fill"
        case let t where t.contains("stop"):  return "stop.fill"
        case let t where t.contains("complete"): return "checkmark.circle.fill"
        default: return "bell.fill"
        }
    }

    private func formatTimestamp(_ ts: Double) -> String {
        let date = Date(timeIntervalSince1970: ts)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Shared Empty State

private func deskEmptyState(icon: String, text: String) -> some View {
    VStack(spacing: 12) {
        Spacer()
        Image(systemName: icon)
            .font(.system(size: 36))
            .foregroundColor(.secondary)
        Text(text)
            .foregroundColor(.secondary)
        Spacer()
    }
}
