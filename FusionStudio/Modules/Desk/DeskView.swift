// Callers: ModuleDetailView routing (.desk → DeskView).
// Affected API: DeskView 8-tab IPC architecture + 9 new bridge method GUI interactions.
// Data schemas: DeskBridge @EnvironmentObject, DeskNodeDetail, DeskTemplateDetail, DeskWorkflowExecStatus, DeskMLXModel, event subscribe/poll.
// User instruction: "补充9个方法的桥接和对应的GUI交互"

import SwiftUI

enum DeskTab: String, CaseIterable, Identifiable {
    case templates  = "templates"
    case workflows  = "workflows"
    case agents     = "agents"
    case sessions   = "sessions"
    case permissions = "permissions"
    case mlx        = "MLX"
    case system     = "system"
    case events     = "events"

    var id: String { rawValue }

    var labelKey: I18nKey {
        switch self {
        case .templates:   return .desk_tab_templates
        case .workflows:   return .desk_tab_workflows
        case .agents:      return .desk_tab_agents
        case .sessions:    return .desk_tab_sessions
        case .permissions: return .desk_tab_permissions
        case .mlx:         return .desk_tab_mlx
        case .system:      return .desk_tab_system
        case .events:      return .desk_tab_events
        }
    }

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
    @StateObject private var i18n = I18nManager.shared
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
                            Text(i18n.t(tab.labelKey))
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
            UpstreamServiceStatusBanner(serviceId: "cowork-desk")
            Divider()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text(i18n.t(.desk_svc_notConnected))
                    .font(.title3)
                    .foregroundColor(theme.text)
                Text(i18n.t(.desk_svc_notConnectedHint))
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button(i18n.t(.desk_reconnect)) {
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
    @StateObject private var i18n = I18nManager.shared
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
                TextField(i18n.t(.desk_searchTemplates), text: $searchText)
                    .textFieldStyle(.plain)
                Spacer()
                Text(String(format: i18n.t(.desk_tpl_count), bridge.templates.count))
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
                ProgressView(i18n.t(.desk_loading))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTemplates.isEmpty {
                deskEmptyState(icon: "square.stack", text: i18n.t(.desk_noTemplates))
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
                    Button(i18n.t(.desk_close)) { runResult = nil }
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
                Text(i18n.t(.desk_tpl_detail))
                    .font(.title3)
                    .foregroundColor(theme.text)
                Spacer()
                Button(i18n.t(.desk_close)) { showDetail = false }
                    .buttonStyle(.borderless)
            }

            if let detail = bridge.selectedTemplateDetail {
                Group {
                    LabeledContent(i18n.t(.desk_name), value: detail.name)
                    LabeledContent(i18n.t(.desk_category), value: detail.category)
                    LabeledContent(i18n.t(.desk_description), value: detail.description)
                }
                .font(.subheadline)

                if !detail.steps.isEmpty {
                    Divider()
                    Text(i18n.t(.desk_steps))
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
                ProgressView(i18n.t(.desk_loading))
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
                runResult = String(format: i18n.t(.desk_tpl_runResult), tpl.name, status)
            } else {
                runResult = String(format: i18n.t(.desk_tpl_runFail), tpl.name)
            }
        }
    }
}

// MARK: - Workflow Tab (uses getWorkflowStatus for execution tracking)

struct DeskWorkflowTab: View {
    @EnvironmentObject var bridge: DeskBridge
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var promptText = ""
    @State private var showExecStatus = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField(i18n.t(.desk_wf_promptPlaceholder), text: $promptText)
                    .textFieldStyle(.plain)
                    .onSubmit { createWorkflow() }

                Button(action: createWorkflow) {
                    Label(i18n.t(.desk_create), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(promptText.isEmpty)

                Spacer()

                Text(String(format: i18n.t(.desk_wf_count), bridge.workflows.count))
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)

                Button(i18n.t(.desk_wf_execStatus)) {
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
                ProgressView(i18n.t(.desk_loading)).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if bridge.workflows.isEmpty {
                deskEmptyState(icon: "arrow.triangle.branch", text: i18n.t(.desk_noWorkflows))
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
                Text(i18n.t(.desk_wf_execStatusTitle))
                    .font(.title3)
                    .foregroundColor(theme.text)
                Spacer()
                Button(i18n.t(.desk_refresh)) {
                    Task { await bridge.getWorkflowStatus() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button(i18n.t(.desk_close)) { showExecStatus = false }
                    .buttonStyle(.borderless)
            }

            if bridge.workflowExecStatuses.isEmpty {
                Text(i18n.t(.desk_wf_noRunning))
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
                            Text(String(format: i18n.t(.desk_wf_currentNode), ex.currentNode))
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
    @StateObject private var i18n = I18nManager.shared
    @State private var taskInput = ""
    @State private var submittedTaskId: String?
    @State private var agentStatusDetail: [String: Any]?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField(i18n.t(.desk_agent_taskPlaceholder), text: $taskInput)
                    .textFieldStyle(.plain)
                    .onSubmit { submitTask() }

                Button(action: submitTask) {
                    Label(i18n.t(.desk_submit), systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(taskInput.isEmpty)

                Spacer()

                Text(String(format: i18n.t(.desk_agent_count), bridge.agents.count))
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
                deskEmptyState(icon: "person.2.fill", text: i18n.t(.desk_noAgents))
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
                            Text(String(format: i18n.t(.desk_agent_id), agent.id))
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
                    Text(String(format: i18n.t(.desk_agent_taskSubmitted), tid))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Button(i18n.t(.desk_agent_viewStatus)) {
                        Task { checkAgentStatus(tid) }
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    Button(i18n.t(.desk_close)) { submittedTaskId = nil }
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
                        Text(String(format: i18n.t(.desk_agent_status), status["status"] as? String ?? "unknown"))
                            .font(.caption)
                            .foregroundColor(theme.text)
                        if let progress = status["progress"] as? Double {
                            Text(String(format: i18n.t(.desk_agent_progress), String(format: "%.0f%%", progress * 100)))
                                .font(.caption2)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                    Spacer()
                    Button(i18n.t(.desk_close)) { agentStatusDetail = nil }
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
    @StateObject private var i18n = I18nManager.shared
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
                    Label(i18n.t(.desk_session_new), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Text(String(format: i18n.t(.desk_session_count), bridge.sessions.count))
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
                deskEmptyState(icon: "clock.arrow.circlepath", text: i18n.t(.desk_noSessions))
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
                                Text(String(format: i18n.t(.desk_session_steps), session.steps))
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
                            Button(i18n.t(.desk_edit)) {
                                editingSessionId = session.id
                                editSessionName = session.name
                                editSessionDesc = ""
                                showEditSession = true
                            }
                            Button(i18n.t(.desk_session_fork)) {
                                Task { await bridge.forkSession(sessionId: session.id) }
                            }
                            Button(i18n.t(.desk_delete), role: .destructive) {
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
        .alert(i18n.t(.desk_session_new), isPresented: $showCreateSession) {
            TextField(i18n.t(.desk_session_namePlaceholder), text: $newSessionName)
            Button(i18n.t(.desk_cancel), role: .cancel) { newSessionName = "" }
            Button(i18n.t(.desk_create)) {
                guard !newSessionName.isEmpty else { return }
                let name = newSessionName
                newSessionName = ""
                Task { await bridge.createSession(name: name) }
            }
        }
        .alert(i18n.t(.desk_session_edit), isPresented: $showEditSession) {
            TextField(i18n.t(.desk_name), text: $editSessionName)
            TextField(i18n.t(.desk_description), text: $editSessionDesc)
            Button(i18n.t(.desk_cancel), role: .cancel) {}
            Button(i18n.t(.desk_save)) {
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
                Text(i18n.t(.desk_session_detail))
                    .font(.title3)
                    .foregroundColor(theme.text)
                Spacer()
                Button(i18n.t(.desk_close)) { sessionDetail = nil }
                    .buttonStyle(.borderless)
            }

            if let s = sessionDetail {
                Group {
                    LabeledContent("ID", value: s.id)
                    LabeledContent(i18n.t(.desk_name), value: s.name)
                    LabeledContent(i18n.t(.desk_status), value: s.status)
                    LabeledContent(i18n.t(.desk_session_stepCount), value: "\(s.steps)")
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
    @StateObject private var i18n = I18nManager.shared
    @State private var checkToolName = ""
    @State private var showCheckResult = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(i18n.t(.desk_perm_rules))
                    .font(.headline)
                    .foregroundColor(theme.text)

                Spacer()

                HStack(spacing: 4) {
                    TextField(i18n.t(.desk_perm_checkTool), text: $checkToolName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .controlSize(.small)
                    Button(i18n.t(.desk_perm_check)) {
                        guard !checkToolName.isEmpty else { return }
                        Task {
                            await bridge.checkPermission(toolName: checkToolName)
                            showCheckResult = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(i18n.t(.desk_perm_resetAll)) {
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
                    Text(String(format: i18n.t(.desk_perm_checkResult), checkToolName, allowed ? i18n.t(.desk_perm_allowed) : i18n.t(.desk_perm_denied)))
                        .font(.caption)
                        .foregroundColor(theme.text)
                    Spacer()
                    Button(i18n.t(.desk_close)) { showCheckResult = false }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.surfaceElevated)
            }

            if bridge.permissions.isEmpty {
                deskEmptyState(icon: "lock.shield", text: i18n.t(.desk_perm_noRules))
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
                            Text(String(format: i18n.t(.desk_perm_scope), rule.scope))
                                .font(.caption)
                                .foregroundColor(theme.textTertiary)
                        }

                        Spacer()

                        Text(rule.allowed ? i18n.t(.desk_perm_allowed) : i18n.t(.desk_perm_denied))
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rule.allowed ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                            .foregroundColor(rule.allowed ? .green : .red)
                            .cornerRadius(4)

                        Button(i18n.t(.desk_perm_toggle)) {
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
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.desk_mlx_status))
                        .font(.headline)
                        .foregroundColor(theme.text)
                    if let status = bridge.mlxStatus {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(status.status == "running" ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(status.status == "running" ? i18n.t(.desk_mlx_running) : i18n.t(.desk_mlx_stopped))
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Menu {
                        ForEach(bridge.mlxModels) { model in
                            HStack {
                                Text(model.name)
                                if !model.size.isEmpty {
                                    Text("(\(model.size))")
                                        .foregroundColor(theme.textTertiary)
                                }
                            }
                        }
                        if bridge.mlxModels.isEmpty {
                            Text(i18n.t(.desk_mlx_noModels))
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                            Text(bridge.mlxModels.isEmpty ? i18n.t(.desk_mlx_modelList) : String(format: i18n.t(.desk_mlx_modelCount), bridge.mlxModels.count))
                        }
                        .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .controlSize(.small)

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
                    Text(i18n.t(.desk_mlx_runningTitle))
                        .font(.title3)
                        .foregroundColor(theme.text)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 48))
                        .foregroundColor(theme.textTertiary)
                    Text(i18n.t(.desk_mlx_stoppedTitle))
                        .font(.title3)
                        .foregroundColor(theme.textSecondary)
                    Text(i18n.t(.desk_mlx_manageHint))
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
    @StateObject private var i18n = I18nManager.shared
    @State private var showNodeDetail = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(i18n.t(.desk_sys_info))
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
                        infoRow(icon: "desktopcomputer", label: i18n.t(.desk_sys_platform), value: info.platform)
                        infoRow(icon: "chevron.left.forwardslash.chevron.right", label: "Python", value: info.python)
                        infoRow(icon: "cpu", label: i18n.t(.desk_sys_cpuCores), value: "\(info.cpuCount)")
                        infoRow(icon: "memorychip", label: i18n.t(.desk_sys_memoryTotal), value: "\(String(format: "%.1f", info.memoryTotalGB)) GB")
                        infoRow(icon: "gauge", label: i18n.t(.desk_sys_memoryUsed), value: "\(String(format: "%.1f", info.memoryUsedPct))%")
                        infoRow(icon: "internaldrive", label: i18n.t(.desk_sys_diskFree), value: "\(String(format: "%.1f", info.diskFreeGB)) GB")

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(i18n.t(.desk_sys_nodeCategories))
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
                            Text(i18n.t(.desk_sys_nodeList))
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
                deskEmptyState(icon: "desktopcomputer", text: i18n.t(.desk_sys_loading))
            }
        }
        .sheet(isPresented: $showNodeDetail) {
            nodeDetailSheet
        }
    }

    private var nodeDetailSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(i18n.t(.desk_sys_nodeDetail))
                    .font(.title3)
                    .foregroundColor(theme.text)
                Spacer()
                Button(i18n.t(.desk_close)) { showNodeDetail = false }
                    .buttonStyle(.borderless)
            }

            if let detail = bridge.selectedNodeDetail {
                Group {
                    LabeledContent(i18n.t(.desk_name), value: detail.name)
                    LabeledContent(i18n.t(.desk_category), value: detail.category)
                    LabeledContent(i18n.t(.desk_description), value: detail.description)
                }
                .font(.subheadline)

                if !detail.inputs.isEmpty {
                    Divider()
                    Text(i18n.t(.desk_sys_inputs))
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
                    Text(i18n.t(.desk_sys_outputs))
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
                ProgressView(i18n.t(.desk_loading))
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
    @StateObject private var i18n = I18nManager.shared
    @State private var isPolling = false
    @State private var pollTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(i18n.t(.desk_evt_stream))
                    .font(.headline)
                    .foregroundColor(theme.text)

                Spacer()

                if bridge.eventSubscriptionId != nil {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isPolling ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(isPolling ? i18n.t(.desk_evt_polling) : i18n.t(.desk_evt_subscribed))
                            .font(.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                }

                Text(String(format: i18n.t(.desk_evt_count), bridge.recentEvents.count))
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)

                Button(isPolling ? i18n.t(.desk_evt_stopPoll) : i18n.t(.desk_evt_startPoll)) {
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
                deskEmptyState(icon: "bell.badge", text: i18n.t(.desk_noEvents))
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
                            Text(String(format: i18n.t(.desk_evt_source), evt.source))
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
