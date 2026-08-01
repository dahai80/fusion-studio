import SwiftUI
import os.log

private let fsbLog = Logger(subsystem: "com.fusion.studio", category: "FSB.Workbench")

struct FSBWorkbenchView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let workspaceId: String
    let onBack: () -> Void

    @State private var workspace: [String: Any] = [:]
    @State private var connectors: [[String: Any]] = []
    @State private var skills: [[String: Any]] = []
    @State private var workflows: [[String: Any]] = []
    @State private var pendingTasks: [[String: Any]] = []
    @State private var executionHistory: [[String: Any]] = []
    @State private var variables: [[String: Any]] = []
    @State private var connectorMeta: [[String: Any]] = []
    @State private var selectedSection: WorkbenchSection = .workflows
    @State private var showWorkflowEditor = false
    @State private var editingWorkflowId: String? = nil
    @State private var showConnectorDialog = false
    @State private var showSkillDialog = false
    @State private var showScheduleDialog = false
    @State private var scheduleWfId = ""
    @State private var showApprovalDialog = false
    @State private var approvalTask: [String: Any] = [:]
    @State private var rightPanelTab: RightPanelTab = .approval

    enum WorkbenchSection: String, CaseIterable {
        case connectors = "连接器"
        case skills = "技能"
        case workflows = "工作流"
        case variables = "变量"
        case templates = "模板"
    }

    enum RightPanelTab: String, CaseIterable {
        case approval = "待审批"
        case scheduled = "定时任务"
        case history = "执行历史"
        case sandbox = "上下文沙盒"
    }

    var body: some View {
        HStack(spacing: 0) {
            customizeSidebar
            centerPanel
            rightPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadAll() }
        .sheet(isPresented: $showWorkflowEditor) {
            FSBWorkflowCanvasView(
                ipc: ipc,
                workspaceId: workspaceId,
                workflowId: editingWorkflowId,
                onSave: { loadAll() }
            )
        }
        .sheet(isPresented: $showConnectorDialog) {
            FSBConnectorDialog(ipc: ipc, workspaceId: workspaceId, connectorMeta: connectorMeta, onDone: { loadAll() })
        }
        .sheet(isPresented: $showSkillDialog) {
            FSBSkillDialog(ipc: ipc, workspaceId: workspaceId, onDone: { loadAll() })
        }
        .sheet(isPresented: $showScheduleDialog) {
            FSBScheduleDialog(ipc: ipc, workspaceId: workspaceId, wfId: scheduleWfId, onDone: { loadAll() })
        }
        .sheet(isPresented: $showApprovalDialog) {
            FSBApprovalDialog(
                ipc: ipc,
                workspaceId: workspaceId,
                task: approvalTask,
                onDone: { loadAll() }
            )
        }
    }

    private var customizeSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                Text(workspace["title"] as? String ?? "工作台")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer()
            }
            .padding(theme.spacingS)

            Divider()
            sectionTabs
            Divider()

            ScrollView {
                switch selectedSection {
                case .connectors: connectorsContent
                case .skills: skillsContent
                case .workflows: workflowsContent
                case .variables: variablesContent
                case .templates: templatesContent
                }
            }
        }
        .frame(width: 240)
        .background(theme.contentBg)
    }

    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(WorkbenchSection.allCases, id: \.self) { section in
                    Button(action: { selectedSection = section }) {
                        Text(section.rawValue)
                            .font(.system(size: theme.captionSize, weight: selectedSection == section ? .semibold : .regular))
                            .foregroundStyle(selectedSection == section ? theme.accent : theme.textSecondary)
                            .padding(.horizontal, theme.spacingS)
                            .padding(.vertical, theme.spacingXS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(selectedSection == section ? theme.accentSoft : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(theme.spacingXS)
        }
    }

    private var connectorsContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Text("已连接")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showConnectorDialog = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            if connectors.isEmpty {
                Text("暂无连接器")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingM)
            } else {
                ForEach(connectors.indices, id: \.self) { idx in
                    connectorRow(conn: connectors[idx])
                }
            }

            Divider()
            Text("可用连接器")
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            ForEach(connectorMeta.indices, id: \.self) { idx in
                connectorMetaRow(meta: connectorMeta[idx])
            }
        }
        .padding(theme.spacingS)
    }

    @ViewBuilder
    private func connectorRow(conn: [String: Any]) -> some View {
        let connId = conn["connId"] as? String ?? ""
        let key = conn["connectorKey"] as? String ?? ""
        let status = conn["authStatus"] as? String ?? "disconnected"
        let statusColor: Color = status == "connected" ? .green : (status == "expired" ? .orange : .red)

        HStack(spacing: theme.spacingS) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(key)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Menu {
                Button(action: { refreshConnector(connId) }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                Button(action: { disconnectConnector(connId) }) {
                    Label("断开", systemImage: "xmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    @ViewBuilder
    private func connectorMetaRow(meta: [String: Any]) -> some View {
        let key = meta["connectorKey"] as? String ?? ""
        let displayName = meta["displayName"] as? String ?? key
        let icon = meta["icon"] as? String ?? "plug"
        let desc = meta["description"] as? String ?? ""
        let isConnected = connectors.contains { ($0["connectorKey"] as? String ?? "") == key }

        HStack(spacing: theme.spacingS) {
            Image(systemName: icon)
                .foregroundStyle(isConnected ? theme.accent : theme.textTertiary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.text)
                if !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if !isConnected {
                Button(action: { showConnectorDialog = true }) {
                    Text("连接")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.spacingXS)
    }

    private var skillsContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Text("技能列表")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showSkillDialog = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            if skills.isEmpty {
                Text("暂无技能")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingM)
            } else {
                ForEach(skills.indices, id: \.self) { idx in
                    skillRow(skill: skills[idx])
                }
            }
        }
        .padding(theme.spacingS)
    }

    @ViewBuilder
    private func skillRow(skill: [String: Any]) -> some View {
        let skillId = skill["skillId"] as? String ?? ""
        let name = skill["displayName"] as? String ?? skill["name"] as? String ?? "未命名"
        let type = skill["type"] as? String ?? "prompt"
        let enabled = skill["enabled"] as? Bool ?? true
        let typeIcon = type == "prompt" ? "text.bubble" : (type == "function" ? "gearshape" : "network")

        HStack(spacing: theme.spacingS) {
            Image(systemName: typeIcon)
                .foregroundStyle(enabled ? theme.accent : theme.textTertiary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(enabled ? theme.text : theme.textTertiary)
                Text(type)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Button(action: { toggleSkill(skillId: skillId, enabled: !enabled) }) {
                Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(enabled ? theme.accent : theme.textTertiary)
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            Menu {
                Button(action: { testSkill(skillId: skillId) }) {
                    Label("测试", systemImage: "play")
                }
                Button(role: .destructive, action: { deleteSkill(skillId: skillId) }) {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    private var workflowsContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Text("工作流列表")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: {
                    editingWorkflowId = nil
                    showWorkflowEditor = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            if workflows.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "flowchart")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.textTertiary)
                    Text("暂无工作流")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                    Button(action: {
                        editingWorkflowId = nil
                        showWorkflowEditor = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("创建工作流")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingM)
            } else {
                ForEach(workflows.indices, id: \.self) { idx in
                    workflowRow(wf: workflows[idx])
                }
            }
        }
        .padding(theme.spacingS)
    }

    @ViewBuilder
    private func workflowRow(wf: [String: Any]) -> some View {
        let wfId = wf["wfId"] as? String ?? wf["id"] as? String ?? ""
        let name = wf["displayName"] as? String ?? wf["name"] as? String ?? "未命名"
        let enabled = wf["enabled"] as? Bool ?? true
        let slashCmd = wf["slashCommand"] as? String ?? ""
        let schedule = wf["schedule"] as? [String: Any] ?? [:]
        let scheduleType = schedule["type"] as? String ?? "manual"

        HStack(spacing: theme.spacingS) {
            Image(systemName: "flowchart")
                .foregroundStyle(enabled ? theme.accent : theme.textTertiary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(enabled ? theme.text : theme.textTertiary)
                    .lineLimit(1)
                HStack(spacing: theme.spacingXS) {
                    if !slashCmd.isEmpty {
                        Text("/\(slashCmd)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(theme.accentSecondary)
                    }
                    if scheduleType != "manual" {
                        Image(systemName: scheduleType == "cron" ? "clock" : "bolt")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
            Menu {
                Button(action: {
                    editingWorkflowId = wfId
                    showWorkflowEditor = true
                }) {
                    Label("编辑", systemImage: "pencil")
                }
                Button(action: { runWorkflow(wfId: wfId) }) {
                    Label("运行", systemImage: "play")
                }
                Button(action: {
                    scheduleWfId = wfId
                    showScheduleDialog = true
                }) {
                    Label("排期", systemImage: "clock")
                }
                Divider()
                Button(role: .destructive, action: { deleteWorkflow(wfId: wfId) }) {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    private var variablesContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Text("变量")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { addVariable() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            if variables.isEmpty {
                Text("暂无变量")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingM)
            } else {
                ForEach(variables.indices, id: \.self) { idx in
                    variableRow(idx: idx)
                }
            }
        }
        .padding(theme.spacingS)
    }

    @ViewBuilder
    private func variableRow(idx: Int) -> some View {
        let v = variables[idx]
        let key = v["key"] as? String ?? ""
        let val = v["value"] as? String ?? String(describing: v["value"] ?? "")

        HStack(spacing: theme.spacingS) {
            Text(key)
                .font(.system(size: theme.captionSize, design: .monospaced))
                .foregroundStyle(theme.accent)
            Text("=")
                .foregroundStyle(theme.textTertiary)
            Text(val)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.text)
                .lineLimit(1)
            Spacer()
            Button(action: { removeVariable(at: idx) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    private var templatesContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Text("模板")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }
            FSBTemplateGallery(onSelect: { _ in })
        }
        .padding(theme.spacingS)
    }

    // MARK: - Center Panel

    private var centerPanel: some View {
        VStack(spacing: 0) {
            centerHeader
            if workflows.isEmpty {
                centerEmpty
            } else {
                workflowGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.contentBg)
    }

    private var centerHeader: some View {
        HStack {
            Text(workspace["title"] as? String ?? "工作台")
                .font(.system(size: theme.textSize, weight: .bold))
                .foregroundStyle(theme.text)
            Spacer()
            if !pendingTasks.isEmpty {
                Button(action: { rightPanelTab = .approval }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.shield")
                        Text("\(pendingTasks.count)")
                    }
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            Button(action: {
                editingWorkflowId = nil
                showWorkflowEditor = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("新建工作流")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(theme.spacingM)
    }

    private var centerEmpty: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()
            Image(systemName: "flowchart")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)
            Text("创建你的第一个工作流")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Button(action: {
                editingWorkflowId = nil
                showWorkflowEditor = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("新建工作流")
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private var workflowGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: theme.spacingM),
                GridItem(.flexible(), spacing: theme.spacingM),
            ], spacing: theme.spacingM) {
                ForEach(workflows.indices, id: \.self) { idx in
                    workflowCard(wf: workflows[idx])
                }
            }
            .padding(theme.spacingM)
        }
    }

    @ViewBuilder
    private func workflowCard(wf: [String: Any]) -> some View {
        let wfId = wf["wfId"] as? String ?? wf["id"] as? String ?? ""
        let name = wf["displayName"] as? String ?? wf["name"] as? String ?? "未命名"
        let desc = wf["description"] as? String ?? ""
        let enabled = wf["enabled"] as? Bool ?? true
        let slashCmd = wf["slashCommand"] as? String ?? ""
        let schedule = wf["schedule"] as? [String: Any] ?? [:]
        let scheduleType = schedule["type"] as? String ?? "manual"
        let graph = wf["graphDefinition"] as? [String: Any] ?? [:]
        let nodeCount = (graph["nodes"] as? [[String: Any]])?.count ?? 0

        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: "flowchart")
                    .foregroundStyle(theme.accent)
                Text(name)
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer()
                Circle()
                    .fill(enabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            if !desc.isEmpty {
                Text(desc)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            HStack(spacing: theme.spacingM) {
                Label("\(nodeCount) 节点", systemImage: "circle.grid.3x3")
                if !slashCmd.isEmpty {
                    Text("/\(slashCmd)")
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.accentSecondary)
                }
                if scheduleType != "manual" {
                    Label(scheduleType, systemImage: scheduleType == "cron" ? "clock" : "bolt")
                        .foregroundStyle(.orange)
                }
            }
            .font(.system(size: theme.captionSize))
            .foregroundStyle(theme.textTertiary)

            HStack(spacing: theme.spacingS) {
                Button(action: { runWorkflow(wfId: wfId) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play")
                        Text("运行")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                Button(action: {
                    editingWorkflowId = wfId
                    showWorkflowEditor = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("编辑")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.separator, lineWidth: 0.5)
        )
    }

    // MARK: - Right Panel (Task Center)

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            rightPanelHeader
            rightPanelContent
        }
        .frame(width: 280)
        .background(theme.contentBg)
    }

    private var rightPanelHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text("任务中心")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
            }
            .padding(theme.spacingS)

            HStack(spacing: 0) {
                ForEach(RightPanelTab.allCases, id: \.self) { tab in
                    Button(action: { rightPanelTab = tab }) {
                        Text(tab.rawValue)
                            .font(.system(size: theme.captionSize, weight: rightPanelTab == tab ? .semibold : .regular))
                            .foregroundStyle(rightPanelTab == tab ? theme.accent : theme.textSecondary)
                            .padding(.vertical, theme.spacingXS)
                            .frame(maxWidth: .infinity)
                            .background(
                                rightPanelTab == tab ? theme.accentSoft : Color.clear
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, theme.spacingXS)

            Divider()
        }
    }

    @ViewBuilder
    private var rightPanelContent: some View {
        ScrollView {
            switch rightPanelTab {
            case .approval: approvalContent
            case .scheduled: scheduledContent
            case .history: historyContent
            case .sandbox: sandboxContent
            }
        }
    }

    private var approvalContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            if pendingTasks.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.textTertiary)
                    Text("无待审批任务")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingL)
            } else {
                ForEach(pendingTasks.indices, id: \.self) { idx in
                    approvalTaskRow(task: pendingTasks[idx])
                }
            }
        }
        .padding(theme.spacingS)
    }

    @ViewBuilder
    private func approvalTaskRow(task: [String: Any]) -> some View {
        let taskId = task["taskId"] as? String ?? ""
        let title = task["title"] as? String ?? "审批请求"
        let status = task["status"] as? String ?? "pending"

        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Image(systemName: "exclamationmark.shield")
                    .foregroundStyle(.orange)
                Text(title)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer()
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }
            HStack(spacing: theme.spacingS) {
                Button(action: { approveTask(taskId) }) {
                    Text("批准")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                Button(action: { denyTask(taskId) }) {
                    Text("拒绝")
                        .font(.system(size: 11))
                }
                .controlSize(.mini)
                Button(action: {
                    approvalTask = task
                    showApprovalDialog = true
                }) {
                    Text("编辑")
                        .font(.system(size: 11))
                }
                .controlSize(.mini)
            }
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    private var scheduledContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            let scheduled = workflows.filter { wf in
                let sched = wf["schedule"] as? [String: Any] ?? [:]
                return (sched["type"] as? String ?? "manual") != "manual"
            }
            if scheduled.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.textTertiary)
                    Text("无定时任务")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingL)
            } else {
                ForEach(scheduled.indices, id: \.self) { idx in
                    let wf = scheduled[idx]
                    let name = wf["displayName"] as? String ?? wf["name"] as? String ?? ""
                    let sched = wf["schedule"] as? [String: Any] ?? [:]
                    let cron = sched["cron"] as? String ?? ""
                    let eventType = sched["eventTrigger"] as? String ?? ""
                    let schedType = sched["type"] as? String ?? "manual"

                    HStack(spacing: theme.spacingS) {
                        Image(systemName: schedType == "cron" ? "clock" : "bolt")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.system(size: theme.captionSize, weight: .medium))
                                .foregroundStyle(theme.text)
                            if !cron.isEmpty {
                                Text("Cron: \(cron)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            if !eventType.isEmpty {
                                Text("Event: \(eventType)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                        Spacer()
                    }
                    .padding(theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.surfaceElevated)
                    )
                }
            }
        }
        .padding(theme.spacingS)
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            if executionHistory.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.textTertiary)
                    Text("暂无执行记录")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingL)
            } else {
                ForEach(executionHistory.indices, id: \.self) { idx in
                    historyRow(run: executionHistory[idx])
                }
            }
        }
        .padding(theme.spacingS)
    }

    @ViewBuilder
    private func historyRow(run: [String: Any]) -> some View {
        let runId = run["runId"] as? String ?? ""
        let status = run["status"] as? String ?? ""
        let trigger = run["triggerType"] as? String ?? ""
        let statusIcon: String = {
            switch status {
            case "COMPLETED": return "checkmark.circle.fill"
            case "RUNNING": return "arrow.trianglehead.2.clockwise"
            case "PAUSED": return "pause.circle.fill"
            case "FAILED": return "xmark.circle.fill"
            default: return "questionmark.circle"
            }
        }()
        let statusColor: Color = {
            switch status {
            case "COMPLETED": return .green
            case "RUNNING": return theme.accent
            case "PAUSED": return .orange
            case "FAILED": return .red
            default: return .gray
            }
        }()

        HStack(spacing: theme.spacingS) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(runId.prefix(12))
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.text)
                HStack(spacing: theme.spacingXS) {
                    Text(status)
                    Text("·")
                    Text(trigger)
                }
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
    }

    private var sandboxContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            let latestRun = executionHistory.first
            if let run = latestRun,
               let sandbox = run["contextSandbox"] as? [String: Any] {
                let snapshots = sandbox["snapshots"] as? [String: Any] ?? [:]
                let inputData = sandbox["inputData"] as? [String: Any] ?? [:]
                let sandboxVars = sandbox["variables"] as? [String: Any] ?? [:]

                Group {
                    if !inputData.isEmpty {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("输入数据")
                                .font(.system(size: theme.captionSize, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                            ForEach(Array(inputData.keys), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(theme.accent)
                                    Spacer()
                                    Text(String(describing: inputData[key] ?? ""))
                                        .font(.system(size: 11))
                                        .foregroundStyle(theme.text)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }

                    if !sandboxVars.isEmpty {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("沙盒变量")
                                .font(.system(size: theme.captionSize, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                            ForEach(Array(sandboxVars.keys), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(theme.accent)
                                    Spacer()
                                    Text(String(describing: sandboxVars[key] ?? ""))
                                        .font(.system(size: 11))
                                        .foregroundStyle(theme.text)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }

                    if !snapshots.isEmpty {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("快照")
                                .font(.system(size: theme.captionSize, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                            ForEach(Array(snapshots.keys), id: \.self) { key in
                                Text(key)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.textTertiary)
                    Text("上下文沙盒为空")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                    Text("运行工作流后，沙盒将记录\n执行上下文和数据快照")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(theme.spacingL)
            }
        }
        .padding(theme.spacingS)
    }

    // MARK: - Data Loading

    private func loadAll() {
        Task {
            async let wsResult = ipc.fsbGetWorkspace(wsId: workspaceId)
            async let connResult = ipc.fsbListConnectors(wsId: workspaceId)
            async let skillResult = ipc.fsbListSkills(wsId: workspaceId)
            async let wfResult = ipc.fsbListWorkflows(wsId: workspaceId)
            async let taskResult = ipc.fsbListPendingTasks(wsId: workspaceId)
            async let histResult = ipc.fsbExecutionHistory(wsId: workspaceId)
            async let varResult = ipc.fsbListVariables(wsId: workspaceId)

            do {
                let ws = try await wsResult
                let conns = try await connResult
                let sks = try await skillResult
                let wfs = try await wfResult
                let tasks = try await taskResult
                let hist = try await histResult
                let vars = try await varResult

                await MainActor.run {
                    workspace = ws
                    connectors = conns
                    skills = sks
                    workflows = wfs
                    pendingTasks = tasks
                    executionHistory = hist
                    variables = vars
                }
            } catch {
                fsbLog.error("loadAll failed: \(error.localizedDescription)")
            }

            do {
                let meta = try await ipc.fsbListConnectorMeta()
                await MainActor.run { connectorMeta = meta }
            } catch {
                fsbLog.warning("connector meta load failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Actions

    private func runWorkflow(wfId: String) {
        Task {
            do {
                _ = try await ipc.fsbRunWorkflow(wsId: workspaceId, wfId: wfId)
                fsbLog.info("workflow run started: \(wfId)")
                loadAll()
            } catch {
                fsbLog.error("workflow run failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteWorkflow(wfId: String) {
        Task {
            do {
                _ = try await ipc.fsbDeleteWorkflow(wsId: workspaceId, wfId: wfId)
                fsbLog.info("workflow deleted: \(wfId)")
                loadAll()
            } catch {
                fsbLog.error("workflow delete failed: \(error.localizedDescription)")
            }
        }
    }

    private func refreshConnector(_ connId: String) {
        Task {
            do {
                _ = try await ipc.fsbRefreshConnector(wsId: workspaceId, connId: connId)
                fsbLog.info("connector refreshed: \(connId)")
                loadAll()
            } catch {
                fsbLog.error("connector refresh failed: \(error.localizedDescription)")
            }
        }
    }

    private func disconnectConnector(_ connId: String) {
        Task {
            do {
                _ = try await ipc.fsbDisconnectConnector(wsId: workspaceId, connId: connId)
                fsbLog.info("connector disconnected: \(connId)")
                loadAll()
            } catch {
                fsbLog.error("connector disconnect failed: \(error.localizedDescription)")
            }
        }
    }

    private func toggleSkill(skillId: String, enabled: Bool) {
        Task {
            do {
                _ = try await ipc.fsbUpdateSkill(wsId: workspaceId, skillId: skillId, enabled: enabled)
                fsbLog.info("skill \(skillId) enabled=\(enabled)")
                loadAll()
            } catch {
                fsbLog.error("skill toggle failed: \(error.localizedDescription)")
            }
        }
    }

    private func testSkill(skillId: String) {
        Task {
            do {
                _ = try await ipc.fsbTestSkill(wsId: workspaceId, skillId: skillId)
                fsbLog.info("skill tested: \(skillId)")
            } catch {
                fsbLog.error("skill test failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteSkill(skillId: String) {
        Task {
            do {
                _ = try await ipc.fsbDeleteSkill(wsId: workspaceId, skillId: skillId)
                fsbLog.info("skill deleted: \(skillId)")
                loadAll()
            } catch {
                fsbLog.error("skill delete failed: \(error.localizedDescription)")
            }
        }
    }

    private func approveTask(_ taskId: String) {
        Task {
            do {
                _ = try await ipc.fsbApproveTask(wsId: workspaceId, taskId: taskId)
                fsbLog.info("task approved: \(taskId)")
                loadAll()
            } catch {
                fsbLog.error("task approve failed: \(error.localizedDescription)")
            }
        }
    }

    private func denyTask(_ taskId: String) {
        Task {
            do {
                _ = try await ipc.fsbDenyTask(wsId: workspaceId, taskId: taskId)
                fsbLog.info("task denied: \(taskId)")
                loadAll()
            } catch {
                fsbLog.error("task deny failed: \(error.localizedDescription)")
            }
        }
    }

    private func addVariable() {
        let key = "var_\(Int.random(in: 1000...9999))"
        variables.append(["key": key, "value": ""])
        saveVariables()
    }

    private func removeVariable(at idx: Int) {
        guard idx < variables.count else { return }
        variables.remove(at: idx)
        saveVariables()
    }

    private func saveVariables() {
        Task {
            do {
                _ = try await ipc.fsbUpdateVariables(wsId: workspaceId, variables: variables)
                fsbLog.info("variables saved")
            } catch {
                fsbLog.error("variables save failed: \(error.localizedDescription)")
            }
        }
    }
}
