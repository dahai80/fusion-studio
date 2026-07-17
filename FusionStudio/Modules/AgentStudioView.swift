import SwiftUI
import Combine

// MARK: - 智能体类型

enum AgentType: String, CaseIterable, Identifiable {
    case code      = "代码智能体"
    case research  = "研究智能体"
    case design    = "设计智能体"
    case analysis  = "分析智能体"
    case general   = "通用智能体"
    case custom    = "自定义智能体"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .research: return "book"
        case .design:   return "pencil.and.outline"
        case .analysis: return "chart.bar"
        case .general:  return "brain"
        case .custom:   return "person.fill.badge.plus"
        }
    }
    var color: Color {
        switch self {
        case .code:     return .blue
        case .research: return .green
        case .design:   return .orange
        case .analysis: return .purple
        case .general:  return .pink
        case .custom:   return .gray
        }
    }
    var defaultModel: String {
        switch self {
        case .code:     return "deepseek-coder-6.7b-4bit"
        case .research: return "qwen3.5-9b-4bit"
        case .design:   return "qwen2-vl-7b-4bit"
        case .analysis: return "qwen3.5-9b-4bit"
        case .general:  return "llama3-8b-4bit"
        case .custom:   return "qwen3.5-9b-4bit"
        }
    }
}

// MARK: - 智能体

struct Agent: Identifiable, Hashable {
    let id: String
    var name: String
    var type: AgentType
    var model: String
    var systemPrompt: String
    var status: AgentStatus
    var createdAt: Date
    var taskCount: Int
    var isBuiltin: Bool

    enum AgentStatus: String, Codable {
        case idle     = "空闲"
        case thinking = "思考中"
        case working  = "执行中"
        case error    = "错误"

        var color: Color {
            switch self {
            case .idle:     return .gray
            case .thinking: return .blue
            case .working:  return .green
            case .error:    return .red
            }
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Agent, rhs: Agent) -> Bool { lhs.id == rhs.id }
}

// MARK: - 智能体任务

struct AgentTask: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var assignedAgent: String
    var status: AgentTaskStatus
    var createdAt: Date
    var completedAt: Date?
    var result: String?
    var subtasks: [String]

    enum AgentTaskStatus: String, Codable {
        case pending    = "待分配"
        case assigned   = "已分配"
        case inProgress = "进行中"
        case completed  = "已完成"
        case failed     = "失败"

        var color: Color {
            switch self {
            case .pending:    return .gray
            case .assigned:   return .blue
            case .inProgress: return .orange
            case .completed:  return .green
            case .failed:     return .red
            }
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AgentTask, rhs: AgentTask) -> Bool { lhs.id == rhs.id }
}

// MARK: - 工作流

struct AgentWorkflow: Identifiable, Hashable {
    let id: String
    var name: String
    var description: String
    var steps: [WorkflowStep]
    var createdAt: Date
    var isActive: Bool

    struct WorkflowStep: Identifiable, Hashable {
        let id: String
        var agentId: String
        var instruction: String
        var dependsOn: [String]
        var order: Int

        func hash(into hasher: inout Hasher) { hasher.combine(id) }
        static func == (lhs: WorkflowStep, rhs: WorkflowStep) -> Bool { lhs.id == rhs.id }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AgentWorkflow, rhs: AgentWorkflow) -> Bool { lhs.id == rhs.id }
}

// MARK: - 智能体编排器

class AgentOrchestrator: ObservableObject {
    static let shared = AgentOrchestrator()

    @Published var agents: [Agent] = []
    @Published var tasks: [AgentTask] = []
    @Published var workflows: [AgentWorkflow] = []
    @Published var activeWorkflow: AgentWorkflow?
    @Published var conversationLog: [AgentMessage] = []

    struct AgentMessage: Identifiable {
        let id = UUID()
        let fromAgent: String
        let toAgent: String
        let content: String
        let timestamp: Date
    }

    init() {
        loadBuiltinAgents()
    }

    private func loadBuiltinAgents() {
        agents = [
            Agent(id: "agent-code", name: "CodeWizard", type: .code, model: "deepseek-coder-6.7b-4bit",
                  systemPrompt: "你是一个专业的代码生成和审查智能体。擅长编写、调试和优化代码。", status: .idle, createdAt: Date(), taskCount: 42, isBuiltin: true),
            Agent(id: "agent-research", name: "ResearchBot", type: .research, model: "qwen3.5-9b-4bit",
                  systemPrompt: "你是一个研究助手，擅长信息检索、分析和总结。", status: .idle, createdAt: Date(), taskCount: 28, isBuiltin: true),
            Agent(id: "agent-design", name: "DesignAI", type: .design, model: "qwen2-vl-7b-4bit",
                  systemPrompt: "你是一个 AI 设计助手，擅长 UI 设计、配色和布局建议。", status: .idle, createdAt: Date(), taskCount: 15, isBuiltin: true),
            Agent(id: "agent-analysis", name: "DataViz", type: .analysis, model: "qwen3.5-9b-4bit",
                  systemPrompt: "你是一个数据分析师，擅长数据处理、统计分析和可视化。", status: .idle, createdAt: Date(), taskCount: 33, isBuiltin: true),
            Agent(id: "agent-general", name: "FusionBot", type: .general, model: "llama3-8b-4bit",
                  systemPrompt: "你是一个通用助手，可以回答各种问题并协助多智能体协作。", status: .idle, createdAt: Date(), taskCount: 56, isBuiltin: true),
        ]
        loadSampleWorkflows()
    }

    private func loadSampleWorkflows() {
        workflows = [
            AgentWorkflow(id: "wf-1", name: "代码审查流水线", description: "自动审查代码质量、安全性和性能", steps: [
                .init(id: "ws-1", agentId: "agent-code", instruction: "审查代码质量和风格", dependsOn: [], order: 1),
                .init(id: "ws-2", agentId: "agent-analysis", instruction: "分析代码性能瓶颈", dependsOn: ["ws-1"], order: 2),
                .init(id: "ws-3", agentId: "agent-research", instruction: "查找最佳实践建议", dependsOn: ["ws-1"], order: 2),
            ], createdAt: Date(), isActive: false),
            AgentWorkflow(id: "wf-2", name: "设计到代码", description: "从设计稿自动生成前端代码", steps: [
                .init(id: "ws-4", agentId: "agent-design", instruction: "分析设计稿并提取组件", dependsOn: [], order: 1),
                .init(id: "ws-5", agentId: "agent-code", instruction: "生成 SwiftUI 代码", dependsOn: ["ws-4"], order: 2),
                .init(id: "ws-6", agentId: "agent-analysis", instruction: "验证代码正确性", dependsOn: ["ws-5"], order: 3),
            ], createdAt: Date(), isActive: false),
        ]
    }

    // MARK: - 智能体操作

    func createAgent(name: String, type: AgentType, model: String) {
        let agent = Agent(
            id: "agent-\(UUID().uuidString.prefix(6))",
            name: name,
            type: type,
            model: model.isEmpty ? type.defaultModel : model,
            systemPrompt: "你是一个\(type.rawValue)。",
            status: .idle,
            createdAt: Date(),
            taskCount: 0,
            isBuiltin: false
        )
        agents.append(agent)
        objectWillChange.send()
    }

    func deleteAgent(_ id: String) {
        agents.removeAll { $0.id == id && !$0.isBuiltin }
        objectWillChange.send()
    }

    // MARK: - 任务操作

    func createTask(title: String, description: String, assignTo agentId: String) {
        let task = AgentTask(
            id: "task-\(UUID().uuidString.prefix(6))",
            title: title,
            description: description,
            assignedAgent: agentId,
            status: .assigned,
            createdAt: Date(),
            subtasks: []
        )
        tasks.append(task)
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx].status = .working
            agents[idx].taskCount += 1
        }
        objectWillChange.send()
    }

    func completeTask(_ id: String, result: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].status = .completed
        tasks[idx].completedAt = Date()
        tasks[idx].result = result
        let agentId = tasks[idx].assignedAgent
        if let aIdx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[aIdx].status = .idle
        }
        objectWillChange.send()
    }

    // MARK: - 工作流操作

    func runWorkflow(_ workflow: AgentWorkflow) {
        activeWorkflow = workflow
        for step in workflow.steps.sorted(by: { $0.order < $1.order }) {
            let agentName = agents.first(where: { $0.id == step.agentId })?.name ?? "unknown"
            let msg = AgentMessage(
                fromAgent: "system",
                toAgent: agentName,
                content: "执行步骤 \(step.order): \(step.instruction)",
                timestamp: Date()
            )
            conversationLog.append(msg)
            if let idx = agents.firstIndex(where: { $0.id == step.agentId }) {
                agents[idx].status = .working
            }
        }
        objectWillChange.send()
    }

    func stopWorkflow() {
        activeWorkflow = nil
        for idx in agents.indices { agents[idx].status = .idle }
        objectWillChange.send()
    }

    // MARK: - 智能体间通信

    func sendMessage(from: String, to: String, content: String) {
        let msg = AgentMessage(fromAgent: from, toAgent: to, content: content, timestamp: Date())
        conversationLog.append(msg)
        if conversationLog.count > 100 { conversationLog.removeFirst(conversationLog.count - 100) }
        objectWillChange.send()
    }

    func clearConversation() {
        conversationLog.removeAll()
        objectWillChange.send()
    }
}

// MARK: - 智能体编排面板

struct AgentStudioView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var selectedTab: AgentTab = .agents
    @State private var showCreateAgent = false

    enum AgentTab: String, CaseIterable {
        case agents      = "智能体"
        case tasks       = "任务"
        case workflows   = "工作流"
        case conversation = "对话"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(AgentTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            switch selectedTab {
            case .agents:    AgentListView()
            case .tasks:     AgentTaskListView()
            case .workflows: WorkflowListView()
            case .conversation: ConversationView()
            }
        }
        .sheet(isPresented: $showCreateAgent) {
            CreateAgentSheet { name, type, model in
                orchestrator.createAgent(name: name, type: type, model: model)
            }
        }
    }

    private func tabIcon(_ tab: AgentTab) -> String {
        switch tab {
        case .agents:      return "person.2"
        case .tasks:       return "checklist"
        case .workflows:   return "arrow.triangle.branch"
        case .conversation: return "bubble.left.and.bubble.right"
        }
    }
}

// MARK: - 智能体列表

struct AgentListView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var selectedAgent: Agent?
    @State private var showCreateAgent = false

    var body: some View {
        HSplitView {
            List(selection: $selectedAgent) {
                Section("内置智能体") {
                    ForEach(orchestrator.agents.filter { $0.isBuiltin }) { agent in
                        AgentRow(agent: agent)
                            .tag(agent)
                    }
                }
                Section("自定义智能体") {
                    let custom = orchestrator.agents.filter { !$0.isBuiltin }
                    if custom.isEmpty {
                        Text("暂无自定义智能体")
                            .foregroundColor(.secondary)
                    }
                    ForEach(custom) { agent in
                        AgentRow(agent: agent)
                            .tag(agent)
                            .contextMenu { Button("删除", role: .destructive) { orchestrator.deleteAgent(agent.id) } }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 280)

            if let agent = selectedAgent {
                AgentDetailView(agent: agent)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "brain")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("选择一个智能体查看详情")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar {
            ToolbarItem { Button(action: { showCreateAgent = true }) {
                Label("创建智能体", systemImage: "plus")
            }}
        }
        .sheet(isPresented: $showCreateAgent) {
            CreateAgentSheet { name, type, model in
                orchestrator.createAgent(name: name, type: type, model: model)
            }
        }
    }
}

struct AgentRow: View {
    let agent: Agent

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(agent.status.color)
                .frame(width: 8, height: 8)
            Image(systemName: agent.type.icon)
                .foregroundColor(agent.type.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.headline)
                Text(agent.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Text(agent.status.rawValue)
                        .font(.caption2)
                        .foregroundColor(agent.status.color)
                    Text("· \(agent.taskCount) 任务")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AgentDetailView: View {
    let agent: Agent
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var taskInput = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: agent.type.icon)
                        .font(.title)
                        .foregroundColor(agent.type.color)
                    Text(agent.name)
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    AgentStatusBadge(status: agent.status)
                }
                .padding(.horizontal)

                Divider()

                GroupBox("基本信息") {
                    VStack(alignment: .leading, spacing: 6) {
                        AgentDetailRow("类型", agent.type.rawValue)
                        AgentDetailRow("模型", agent.model)
                        AgentDetailRow("状态", agent.status.rawValue)
                        AgentDetailRow("任务数", "\(agent.taskCount)")
                        AgentDetailRow("内置", agent.isBuiltin ? "是" : "否")
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                GroupBox("系统提示词") {
                    Text(agent.systemPrompt)
                        .font(.body)
                        .padding(8)
                }
                .padding(.horizontal)

                GroupBox("分配任务") {
                    HStack {
                        TextField("输入任务描述...", text: $taskInput)
                            .textFieldStyle(.roundedBorder)
                        Button("分配") {
                            orchestrator.createTask(title: taskInput, description: taskInput, assignTo: agent.id)
                            taskInput = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(taskInput.isEmpty)
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
    }
}

struct AgentStatusBadge: View {
    let status: Agent.AgentStatus
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(status.color).frame(width: 8, height: 8)
            Text(status.rawValue).font(.caption)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(status.color.opacity(0.1)).cornerRadius(6)
    }
}

struct AgentDetailRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary).frame(width: 60, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}

// MARK: - 创建智能体

struct CreateAgentSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var type: AgentType = .custom
    @State private var model = ""
    let onCreate: (String, AgentType, String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("创建智能体").font(.title2).bold()
            TextField("名称", text: $name).textFieldStyle(.roundedBorder)
            Picker("类型", selection: $type) {
                ForEach(AgentType.allCases) { t in
                    Label(t.rawValue, systemImage: t.icon).tag(t)
                }
            }
            TextField("模型（留空使用默认）", text: $model).textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("创建") {
                    onCreate(name, type, model)
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(name.isEmpty)
            }
        }
        .padding().frame(width: 320)
    }
}

// MARK: - 任务列表

struct AgentTaskListView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var showCreateTask = false

    var body: some View {
        VStack {
            if orchestrator.tasks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checklist").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("暂无任务").foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(orchestrator.tasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Circle().fill(task.status.color).frame(width: 8, height: 8)
                                Text(task.title).font(.headline)
                                Spacer()
                                Text(task.status.rawValue).font(.caption).foregroundColor(task.status.color)
                            }
                            Text(task.description).font(.caption).foregroundColor(.secondary)
                            HStack {
                                Text(orchestrator.agents.first(where: { $0.id == task.assignedAgent })?.name ?? "未知")
                                    .font(.caption2).padding(.horizontal, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                                Text(task.createdAt, style: .date).font(.caption2).foregroundColor(.secondary)
                                if let result = task.result {
                                    Text("· \(result.prefix(40))...").font(.caption2).foregroundColor(.green)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem { Button(action: { showCreateTask = true }) {
                Label("新建任务", systemImage: "plus")
            }}
        }
        .sheet(isPresented: $showCreateTask) {
            CreateTaskSheet()
        }
    }
}

struct CreateTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var title = ""
    @State private var description = ""
    @State private var selectedAgent = "agent-general"

    var body: some View {
        VStack(spacing: 16) {
            Text("新建任务").font(.title2).bold()
            TextField("标题", text: $title).textFieldStyle(.roundedBorder)
            TextField("描述", text: $description).textFieldStyle(.roundedBorder)
            Picker("分配智能体", selection: $selectedAgent) {
                ForEach(orchestrator.agents) { agent in
                    Label(agent.name, systemImage: agent.type.icon).tag(agent.id)
                }
            }
            HStack {
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("创建") {
                    orchestrator.createTask(title: title, description: description, assignTo: selectedAgent)
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(title.isEmpty)
            }
        }
        .padding().frame(width: 320)
    }
}

// MARK: - 工作流列表

struct WorkflowListView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                ForEach(orchestrator.workflows) { workflow in
                    WorkflowCard(workflow: workflow)
                }
            }
            .padding()
        }
    }
}

struct WorkflowCard: View {
    let workflow: AgentWorkflow
    @StateObject private var orchestrator = AgentOrchestrator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workflow.name).font(.headline)
            Text(workflow.description).font(.caption).foregroundColor(.secondary)
            Divider()
            ForEach(workflow.steps.sorted(by: { $0.order < $1.order })) { step in
                HStack(spacing: 6) {
                    Text("\(step.order)").font(.caption2).foregroundColor(.secondary).frame(width: 16)
                    Circle().fill(orchestrator.agents.first(where: { $0.id == step.agentId })?.type.color ?? .gray).frame(width: 6, height: 6)
                    Text(orchestrator.agents.first(where: { $0.id == step.agentId })?.name ?? "未知").font(.caption)
                    Text(step.instruction).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Divider()
            HStack {
                Spacer()
                Button(orchestrator.activeWorkflow?.id == workflow.id ? "运行中..." : "运行") {
                    orchestrator.runWorkflow(workflow)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(orchestrator.activeWorkflow != nil)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - 对话日志

struct ConversationView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared

    var body: some View {
        VStack {
            if orchestrator.conversationLog.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("暂无对话记录").foregroundColor(.secondary)
                    Text("运行工作流后，智能体间的通信将显示在这里").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(orchestrator.conversationLog) { msg in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(msg.fromAgent).font(.caption).fontWeight(.bold)
                                        Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                                        Text(msg.toAgent).font(.caption).fontWeight(.bold)
                                        Spacer()
                                        Text(msg.timestamp, style: .time).font(.caption2).foregroundColor(.secondary)
                                    }
                                    Text(msg.content).font(.system(.body, design: .monospaced)).foregroundColor(.primary)
                                }
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                                .id(msg.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: orchestrator.conversationLog.count) { _, _ in
                        withAnimation { proxy.scrollTo(orchestrator.conversationLog.last?.id, anchor: .bottom) }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem { Button("清空") { orchestrator.clearConversation() }.buttonStyle(.bordered).controlSize(.small) }
        }
    }
}