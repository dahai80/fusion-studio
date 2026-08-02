import SwiftUI
import Combine
import os.log

// MARK: - AgentTaskListView

struct AgentTaskListView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var showCreateTask = false
    let toastManager: FusionToastManager

    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            if orchestrator.tasks.isEmpty {
                emptyTasksPlaceholder
            } else {
                ScrollView {
                    VStack(spacing: theme.spacingS) {
                        StudioSectionHeader(title: "Active Tasks")
                        let activeTasks = orchestrator.tasks.filter { $0.status != .completed && $0.status != .failed }
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
                        let completedTasks = orchestrator.tasks.filter { $0.status == .completed || $0.status == .failed }
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
            ToolbarItem {
                FusionButton("New Task", icon: "plus", style: .primary, size: .small) {
                    showCreateTask = true
                }
            }
        }
        .sheet(isPresented: $showCreateTask) {
            CreateTaskSheet(toastManager: toastManager)
        }
    }

    private func taskCard(task: AgentTask) -> some View {
        FusionCard(style: .elevated) {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack(spacing: theme.spacingS) {
                    StatusPill(status: task.status.pillStatus, compact: true)
                    Text(task.title)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Spacer()
                    FusionTag(task.priority.rawValue, color: task.priority.tagColor)
                }

                Text(task.description)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)

                HStack(spacing: theme.spacingS) {
                    FusionTag(
                        orchestrator.agents.first(where: { $0.id == task.assignedAgent })?.name ?? "Unknown",
                        icon: "person",
                        color: .blue
                    )
                    Text(task.createdAt, style: .date)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)

                    if let result = task.result {
                        Text(result.prefix(60))
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
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
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var title = ""
    @State private var description = ""
    @State private var selectedAgent = "agent-general"
    @State private var priority: AgentTask.TaskPriority = .medium
    let toastManager: FusionToastManager

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("New Task")
                .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text)

            FusionCard(style: .bordered) {
                VStack(spacing: theme.spacingM) {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text("Title")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        TextField("Task title", text: $title)
                            .textFieldStyle(.plain)
                            .padding(theme.spacingS)
                            .background(theme.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }
                    }

                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text("Description")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        TextField("Describe the task...", text: $description)
                            .textFieldStyle(.plain)
                            .padding(theme.spacingS)
                            .background(theme.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }
                    }

                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text("Assign Agent")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Picker("Agent", selection: $selectedAgent) {
                            ForEach(orchestrator.agents) { agent in
                                Label(agent.name, systemImage: agent.type.icon).tag(agent.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text("Priority")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Picker("Priority", selection: $priority) {
                            ForEach(AgentTask.TaskPriority.allCases, id: \.self) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            HStack(spacing: theme.spacingM) {
                FusionButton("Cancel", style: .secondary, size: .regular) { dismiss() }
                FusionButton("Create", icon: "plus", style: .primary, size: .regular, isDisabled: title.isEmpty) {
                    orchestrator.createTask(title: title, description: description, assignTo: selectedAgent, priority: priority)
                    toastManager.show(style: .success, title: "Task Created", message: title)
                    dismiss()
                }
            }
        }
        .padding(theme.spacingXL)
        .frame(width: 400)
        .background(theme.windowBg)
    }
}

// MARK: - WorkflowListView

struct WorkflowListView: View {
    @EnvironmentObject private var bridge: AgentBridge
    @State private var selectedGraph: AgentGraphModel?
    @State private var showCreateWorkflow = false
    let toastManager: FusionToastManager

    @Environment(\.studioTheme) var theme

    var body: some View {
        HSplitView {
            workflowListPanel
                .frame(minWidth: 280)

            if let graph = selectedGraph {
                WorkflowDetailView(graph: graph, toastManager: toastManager)
            } else {
                emptyWorkflowPlaceholder
            }
        }
        .toolbar {
            ToolbarItem {
                FusionButton("Create Workflow", icon: "plus", style: .primary, size: .small) {
                    showCreateWorkflow = true
                }
            }
        }
        .sheet(isPresented: $showCreateWorkflow) {
            CreateWorkflowSheet { name, nodes, edges in
                createWorkflowViaBridge(name: name, nodes: nodes, edges: edges)
            }
        }
    }

    private func createWorkflowViaBridge(name: String, nodes: [NodeConfigModel], edges: [EdgeModel]) {
        Task {
            do {
                let _ = try await bridge.createGraph(name: name, nodes: nodes, edges: edges)
                try await bridge.fetchGraphs()
                toastManager.show(style: .success, title: "Workflow Created", message: "\(name) saved to backend")
            } catch {
                toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
            }
        }
    }

    private var workflowListPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                StudioSectionHeader(title: "Workflows")
                if bridge.graphs.isEmpty {
                    VStack(spacing: theme.spacingM) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.textTertiary)
                        Text("No workflows yet - create one")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(.vertical, theme.spacing2XL)
                } else {
                    ListGroup {
                        ForEach(Array(bridge.graphs.enumerated()), id: \.element.id) { index, graph in
                            StudioRow(label: graph.name, sublabel: "\(graph.nodes.count) nodes, \(graph.edges.count) edges", isLast: index == bridge.graphs.count - 1) {
                                FusionTag("graph", color: .green)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedGraph = graph
                                Task {
                                    if let fresh = try? await bridge.graphGet(graphId: graph.id.uuidString) {
                                        selectedGraph = fresh
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

    private func deleteGraph(_ graph: AgentGraphModel) {
        Task {
            do {
                try await bridge.deleteGraph(id: graph.id)
                if selectedGraph?.id == graph.id { selectedGraph = nil }
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

// MARK: - WorkflowDetailView

struct WorkflowDetailView: View {
    let graph: AgentGraphModel
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @State private var executeInput = ""
    @State private var isExecuting = false
    @State private var executionResult = ""

    @Environment(\.studioTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                HStack(spacing: theme.spacingM) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: theme.iconXL))
                        .foregroundStyle(theme.accent)
                        .frame(width: 40, height: 40)
                        .background(theme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text(graph.name)
                            .font(.system(size: theme.titleSize, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.text)
                        Text("ID: \(graph.id.uuidString.prefix(8))")
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Spacer()
                }

                FusionCard(style: .inset, header: "Nodes (\(graph.nodes.count))", headerIcon: "circle.grid.2x2") {
                    VStack(spacing: 0) {
                        ForEach(Array(graph.nodes.enumerated()), id: \.element.id) { index, node in
                            HStack(spacing: theme.spacingS) {
                                nodeTypeIcon(node.type)
                                Text(node.id)
                                    .font(.system(size: theme.smallTextSize, weight: .medium))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                FusionTag(node.type, color: nodeTypeTagColor(node.type))
                            }
                            .padding(.vertical, theme.spacingS)
                            if index < graph.nodes.count - 1 {
                                Divider().foregroundStyle(theme.rowSep)
                            }
                        }
                    }
                }

                FusionCard(style: .inset, header: "Edges (\(graph.edges.count))", headerIcon: "arrow.right") {
                    VStack(spacing: 0) {
                        ForEach(Array(graph.edges.enumerated()), id: \.element.id) { index, edge in
                            HStack(spacing: theme.spacingS) {
                                Text(edge.source)
                                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                                    .foregroundStyle(theme.text)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: theme.iconXS))
                                    .foregroundStyle(theme.textTertiary)
                                Text(edge.target)
                                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                if let cond = edge.condition, !cond.isEmpty {
                                    FusionTag(cond, color: .orange)
                                }
                            }
                            .padding(.vertical, theme.spacingS)
                            if index < graph.edges.count - 1 {
                                Divider().foregroundStyle(theme.rowSep)
                            }
                        }
                    }
                }

                FusionCard(style: .inset, header: "Execute", headerIcon: "play.fill") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        HStack(spacing: theme.spacingS) {
                            TextField("Input for workflow...", text: $executeInput)
                                .textFieldStyle(.plain)
                                .padding(theme.spacingS)
                                .background(theme.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }
                            FusionButton("Run", icon: "play.fill", style: .primary, size: .small, isDisabled: isExecuting) {
                                executeGraph()
                            }
                            if isExecuting {
                                FusionButton("Cancel", icon: "stop.fill", style: .destructive, size: .small) {
                                    bridge.cancelExecution()
                                    isExecuting = false
                                }
                            }
                        }
                        if !executionResult.isEmpty {
                            ScrollView {
                                Text(executionResult)
                                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary)
                                    .textSelection(.enabled)
                                    .padding(theme.spacingS)
                            }
                            .frame(maxHeight: 200)
                            .background(theme.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        }
                    }
                }

                Spacer(minLength: theme.spacing2XL)
            }
            .padding(.vertical, theme.spacingL)
        }
    }

    private func executeGraph() {
        isExecuting = true
        executionResult = ""
        Task {
            do {
                try await bridge.executeGraph(id: graph.id, input: executeInput)
                var output = ""
                for ev in bridge.events {
                    let nodeId = ev.node_id ?? "?"
                    output += "[\(ev.type)] \(nodeId)"
                    if let data = ev.data, !data.isEmpty {
                        output += ": \(data.map { "\($0)=\($1)" }.joined(separator: " "))"
                    }
                    output += "\n"
                }
                if output.isEmpty { output = "Workflow completed (no events)" }
                executionResult = output
                toastManager.show(style: .success, title: "Workflow Complete", message: graph.name)
            } catch {
                executionResult = "Error: \(error.localizedDescription)"
                toastManager.show(style: .error, title: "Execution Failed", message: error.localizedDescription)
            }
            isExecuting = false
        }
    }

    private func nodeTypeIcon(_ type: String) -> some View {
        let name: String = switch type {
        case "start": "play.circle"
        case "llm": "brain"
        case "tool": "wrench"
        case "condition": "diamond"
        case "loop": "arrow.triangle.2.circlepath"
        case "end": "stop.circle"
        case "error_handler": "exclamationmark.triangle"
        default: "circle"
        }
        return Image(systemName: name)
            .font(.system(size: theme.iconS))
            .foregroundStyle(nodeTypeColor(type))
    }

    private func nodeTypeTagColor(_ type: String) -> TagColor {
        switch type {
        case "start": return .green
        case "llm": return .purple
        case "tool": return .blue
        case "condition": return .orange
        case "loop": return .blue
        case "end": return .gray
        case "error_handler": return .red
        default: return .gray
        }
    }

    private func nodeTypeColor(_ type: String) -> Color {
        switch type {
        case "start": return .green
        case "llm": return .purple
        case "tool": return .blue
        case "condition": return .orange
        case "loop": return .cyan
        case "end": return .gray
        case "error_handler": return .red
        default: return .gray
        }
    }
}

// MARK: - CreateWorkflowSheet

struct CreateWorkflowSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.studioTheme) var theme
    @State private var name = ""
    @State private var nodeRows: [NodeRowData] = [NodeRowData()]
    @State private var edgeRows: [EdgeRowData] = [EdgeRowData()]
    let onCreate: (String, [NodeConfigModel], [EdgeModel]) -> Void

    private let nodeTypes = ["start", "llm", "tool", "condition", "loop", "end", "error_handler"]

    struct NodeRowData: Identifiable {
        let id = UUID()
        var nodeId: String = ""
        var type: String = "llm"
    }

    struct EdgeRowData: Identifiable {
        let id = UUID()
        var source: String = ""
        var target: String = ""
        var condition: String = ""
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                Text("Create Workflow")
                    .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)

                FusionCard(style: .bordered) {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        Text("Name *")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        TextField("Workflow name", text: $name)
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

                FusionCard(style: .bordered, header: "Nodes", headerIcon: "circle.grid.2x2") {
                    VStack(spacing: theme.spacingS) {
                        ForEach($nodeRows) { $row in
                            HStack(spacing: theme.spacingS) {
                                TextField("Node ID", text: $row.nodeId)
                                    .textFieldStyle(.plain)
                                    .padding(theme.spacingXS)
                                    .background(theme.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .stroke(theme.inputBorder, lineWidth: 1)
                                    }
                                Picker("Type", selection: $row.type) {
                                    ForEach(nodeTypes, id: \.self) { t in Text(t) }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 130)
                                Button(action: { nodeRows.removeAll { $0.id == row.id } }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button(action: { nodeRows.append(NodeRowData()) }) {
                            Label("Add Node", systemImage: "plus.circle")
                                .font(.system(size: theme.footnoteSize))
                        }
                        .buttonStyle(.plain)
                    }
                }

                FusionCard(style: .bordered, header: "Edges", headerIcon: "arrow.right") {
                    VStack(spacing: theme.spacingS) {
                        ForEach($edgeRows) { $row in
                            HStack(spacing: theme.spacingS) {
                                TextField("Source", text: $row.source)
                                    .textFieldStyle(.plain)
                                    .padding(theme.spacingXS)
                                    .background(theme.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .stroke(theme.inputBorder, lineWidth: 1)
                                    }
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(theme.textTertiary)
                                TextField("Target", text: $row.target)
                                    .textFieldStyle(.plain)
                                    .padding(theme.spacingXS)
                                    .background(theme.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .stroke(theme.inputBorder, lineWidth: 1)
                                    }
                                TextField("Condition", text: $row.condition)
                                    .textFieldStyle(.plain)
                                    .frame(width: 80)
                                    .padding(theme.spacingXS)
                                    .background(theme.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .stroke(theme.inputBorder, lineWidth: 1)
                                    }
                                Button(action: { edgeRows.removeAll { $0.id == row.id } }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button(action: { edgeRows.append(EdgeRowData()) }) {
                            Label("Add Edge", systemImage: "plus.circle")
                                .font(.system(size: theme.footnoteSize))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: theme.spacingM) {
                    FusionButton("Cancel", icon: "xmark", style: .secondary, size: .regular) {
                        dismiss()
                    }
                    FusionButton("Create", icon: "checkmark", style: .primary, size: .regular, isDisabled: name.isEmpty) {
                        let nodes = nodeRows.filter { !$0.nodeId.isEmpty }.map {
                            NodeConfigModel(id: $0.nodeId, type: $0.type, config: [:], position: nil)
                        }
                        let edges = edgeRows.filter { !$0.source.isEmpty && !$0.target.isEmpty }.map {
                            EdgeModel(id: "\($0.source)-\($0.target)", source: $0.source, target: $0.target, condition: $0.condition.isEmpty ? nil : $0.condition)
                        }
                        onCreate(name, nodes, edges)
                        dismiss()
                    }
                }
            }
            .padding(theme.spacingXL)
        }
        .frame(width: 600, height: 600)
        .background(theme.windowBg)
    }
}
