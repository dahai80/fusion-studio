// Callers: ContentView via ModuleDetailView, NavigationView module routing.
// Affected API: AgentStudioView (bridge-connected — agent CRUD + config via AgentBridge backend).
// Data schemas: AgentType, Agent, AgentTask, AgentWorkflow, AgentOrchestrator (retained for builtins + local tasks).
// Communication: UDS JSON-RPC 2.0 via IPCClient → AgentBridge.
// User instruction: "继续，把所有的业务都接入完整，然后按照业务场景进行测试，另外创建agent和配置agent的能力我还没看到"

import SwiftUI
import Combine
import os.log

private let agentStudioLog = Logger(subsystem: "com.fusion.studio", category: "AgentStudioView")

// MARK: - AgentType

enum AgentType: String, CaseIterable, Identifiable {
    case code      = "Code"
    case research  = "Research"
    case design    = "Design"
    case analysis  = "Analysis"
    case general   = "General"
    case custom    = "Custom"

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
    var tagColor: TagColor {
        switch self {
        case .code:     return .blue
        case .research: return .green
        case .design:   return .orange
        case .analysis: return .purple
        case .general:  return .gray
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
    var defaultSystemPrompt: String {
        switch self {
        case .code:     return "You are a professional code generation and review agent."
        case .research: return "You are a research assistant, skilled at information retrieval and analysis."
        case .design:   return "You are an AI design assistant, skilled at UI design and layout."
        case .analysis: return "You are a data analyst, skilled at processing and visualization."
        case .general:  return "You are a general assistant for multi-agent collaboration."
        case .custom:   return "You are a custom agent."
        }
    }
}

// MARK: - Agent

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
    var temperature: Double
    var maxTokens: Int
    var tools: [String]
    var capabilities: [String]
    var safetyLevel: String
    var tags: [String]

    enum AgentStatus: String, Codable {
        case idle     = "Idle"
        case thinking = "Thinking"
        case working  = "Working"
        case error    = "Error"

        var pillStatus: StatusPill.Status {
            switch self {
            case .idle:     return .stopped
            case .thinking: return .starting
            case .working:  return .running
            case .error:    return .error
            }
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Agent, rhs: Agent) -> Bool { lhs.id == rhs.id }
}

// MARK: - AgentTask

struct AgentTask: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var assignedAgent: String
    var status: AgentTaskStatus
    var priority: TaskPriority
    var createdAt: Date
    var completedAt: Date?
    var result: String?
    var subtasks: [String]

    enum TaskPriority: String, CaseIterable, Codable {
        case low    = "Low"
        case medium = "Medium"
        case high   = "High"
        case critical = "Critical"

        var tagColor: TagColor {
            switch self {
            case .low:      return .gray
            case .medium:   return .blue
            case .high:     return .orange
            case .critical: return .red
            }
        }
    }

    enum AgentTaskStatus: String, Codable {
        case pending    = "Pending"
        case assigned   = "Assigned"
        case inProgress = "In Progress"
        case completed  = "Completed"
        case failed     = "Failed"

        var pillStatus: StatusPill.Status {
            switch self {
            case .pending:    return .stopped
            case .assigned:   return .starting
            case .inProgress: return .running
            case .completed:  return .custom(color: Color(red: 0, green: 122.0 / 255.0, blue: 1.0), label: "Done")
            case .failed:     return .error
            }
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AgentTask, rhs: AgentTask) -> Bool { lhs.id == rhs.id }
}

// MARK: - AgentWorkflow

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

// MARK: - AgentOrchestrator

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

    private let logger = Logger(subsystem: "com.fusion.studio", category: "AgentOrchestrator")

    init() {
        loadBuiltinAgents()
    }

    private func loadBuiltinAgents() {
        agents = [
            Agent(id: "agent-code", name: "CodeWizard", type: .code, model: "deepseek-coder-6.7b-4bit",
                  systemPrompt: "You are a professional code generation and review agent.",
                  status: .idle, createdAt: Date(), taskCount: 42, isBuiltin: true,
                  temperature: 0.7, maxTokens: 4096, tools: [], capabilities: [], safetyLevel: "L1", tags: ["code"]),
            Agent(id: "agent-research", name: "ResearchBot", type: .research, model: "qwen3.5-9b-4bit",
                  systemPrompt: "You are a research assistant, skilled at information retrieval and analysis.",
                  status: .idle, createdAt: Date(), taskCount: 28, isBuiltin: true,
                  temperature: 0.5, maxTokens: 4096, tools: [], capabilities: [], safetyLevel: "L1", tags: ["research"]),
            Agent(id: "agent-design", name: "DesignAI", type: .design, model: "qwen2-vl-7b-4bit",
                  systemPrompt: "You are an AI design assistant, skilled at UI design and layout.",
                  status: .idle, createdAt: Date(), taskCount: 15, isBuiltin: true,
                  temperature: 0.8, maxTokens: 4096, tools: [], capabilities: [], safetyLevel: "L1", tags: ["design"]),
            Agent(id: "agent-analysis", name: "DataViz", type: .analysis, model: "qwen3.5-9b-4bit",
                  systemPrompt: "You are a data analyst, skilled at processing and visualization.",
                  status: .idle, createdAt: Date(), taskCount: 33, isBuiltin: true,
                  temperature: 0.3, maxTokens: 4096, tools: [], capabilities: [], safetyLevel: "L1", tags: ["analysis"]),
            Agent(id: "agent-general", name: "FusionBot", type: .general, model: "llama3-8b-4bit",
                  systemPrompt: "You are a general assistant for multi-agent collaboration.",
                  status: .idle, createdAt: Date(), taskCount: 56, isBuiltin: true,
                  temperature: 0.7, maxTokens: 4096, tools: [], capabilities: [], safetyLevel: "L1", tags: ["general"]),
        ]
        loadSampleWorkflows()
    }

    private func loadSampleWorkflows() {
        workflows = [
            AgentWorkflow(id: "wf-1", name: "Code Review Pipeline", description: "Automated code quality, security, and performance review", steps: [
                .init(id: "ws-1", agentId: "agent-code", instruction: "Review code quality and style", dependsOn: [], order: 1),
                .init(id: "ws-2", agentId: "agent-analysis", instruction: "Analyze code performance bottlenecks", dependsOn: ["ws-1"], order: 2),
                .init(id: "ws-3", agentId: "agent-research", instruction: "Find best practice recommendations", dependsOn: ["ws-1"], order: 2),
            ], createdAt: Date(), isActive: false),
            AgentWorkflow(id: "wf-2", name: "Design to Code", description: "Generate frontend code from design mockups", steps: [
                .init(id: "ws-4", agentId: "agent-design", instruction: "Analyze design and extract components", dependsOn: [], order: 1),
                .init(id: "ws-5", agentId: "agent-code", instruction: "Generate SwiftUI code", dependsOn: ["ws-4"], order: 2),
                .init(id: "ws-6", agentId: "agent-analysis", instruction: "Verify code correctness", dependsOn: ["ws-5"], order: 3),
            ], createdAt: Date(), isActive: false),
        ]
    }

    func createAgent(name: String, type: AgentType, model: String, systemPrompt: String = "", temperature: Double = 0.7, maxTokens: Int = 4096, tools: [String] = [], capabilities: [String] = [], safetyLevel: String = "L1", tags: [String] = []) {
        let agent = Agent(
            id: "agent-\(UUID().uuidString.prefix(6))",
            name: name,
            type: type,
            model: model.isEmpty ? type.defaultModel : model,
            systemPrompt: systemPrompt.isEmpty ? type.defaultSystemPrompt : systemPrompt,
            status: .idle,
            createdAt: Date(),
            taskCount: 0,
            isBuiltin: false,
            temperature: temperature,
            maxTokens: maxTokens,
            tools: tools,
            capabilities: capabilities,
            safetyLevel: safetyLevel,
            tags: tags
        )
        agents.append(agent)
        logger.info("createAgent: id=\(agent.id) name=\(name) type=\(type.rawValue)")
        objectWillChange.send()
    }

    func deleteAgent(_ id: String) {
        agents.removeAll { $0.id == id && !$0.isBuiltin }
        logger.info("deleteAgent: id=\(id)")
        objectWillChange.send()
    }

    func createTask(title: String, description: String, assignTo agentId: String, priority: AgentTask.TaskPriority = .medium) {
        let task = AgentTask(
            id: "task-\(UUID().uuidString.prefix(6))",
            title: title,
            description: description,
            assignedAgent: agentId,
            status: .assigned,
            priority: priority,
            createdAt: Date(),
            subtasks: []
        )
        tasks.append(task)
        if let idx = agents.firstIndex(where: { $0.id == agentId }) {
            agents[idx].status = .working
            agents[idx].taskCount += 1
        }
        logger.info("createTask: id=\(task.id) title=\(title) agent=\(agentId)")
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
        logger.info("completeTask: id=\(id)")
        objectWillChange.send()
    }

    func runWorkflow(_ workflow: AgentWorkflow) {
        activeWorkflow = workflow
        for step in workflow.steps.sorted(by: { $0.order < $1.order }) {
            let agentName = agents.first(where: { $0.id == step.agentId })?.name ?? "unknown"
            let msg = AgentMessage(
                fromAgent: "system",
                toAgent: agentName,
                content: "Execute step \(step.order): \(step.instruction)",
                timestamp: Date()
            )
            conversationLog.append(msg)
            if let idx = agents.firstIndex(where: { $0.id == step.agentId }) {
                agents[idx].status = .working
            }
        }
        logger.info("runWorkflow: id=\(workflow.id) name=\(workflow.name)")
        objectWillChange.send()
    }

    func stopWorkflow() {
        activeWorkflow = nil
        for idx in agents.indices { agents[idx].status = .idle }
        logger.info("stopWorkflow")
        objectWillChange.send()
    }

    func sendMessage(from: String, to: String, content: String) {
        let msg = AgentMessage(fromAgent: from, toAgent: to, content: content, timestamp: Date())
        conversationLog.append(msg)
        if conversationLog.count > 100 { conversationLog.removeFirst(conversationLog.count - 100) }
        objectWillChange.send()
    }

    func clearConversation() {
        conversationLog.removeAll()
        logger.info("clearConversation")
        objectWillChange.send()
    }
}

// MARK: - AgentStudioView

struct AgentStudioView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @EnvironmentObject private var bridge: AgentBridge
    @StateObject private var screenContext = ScreenContextManager()
    @StateObject private var fileWatcher = FileWatcher()
    @StateObject private var toastManager = FusionToastManager()
    @State private var selectedTab: Int = 0
    @State private var showCreateAgent = false

    @Environment(\.studioTheme) var theme

    private var taskCount: Int {
        orchestrator.tasks.filter { $0.status != .completed }.count
    }

    private var unreadCount: Int {
        orchestrator.conversationLog.count
    }

    private var contextTitle: String {
        let ctx = screenContext.currentContext
        if ctx.activeAppName.isEmpty {
            return "Agent Studio"
        }
        return ctx.activeAppName
    }

    private var bridgeSubtitle: String {
        bridge.isConnected ? "Backend Connected" : "Backend Offline"
    }

    var body: some View {
        VStack(spacing: 0) {
            contextBar

            ScreenHeader(
                eyebrow: "Agent Studio",
                title: contextTitle,
                subtitle: bridgeSubtitle
            )

            FusionTabBar(selected: $selectedTab, tabs: [
                FusionTabItem(title: "Agents", icon: "person.2", badge: nil),
                FusionTabItem(title: "Tasks", icon: "checklist", badge: taskCount > 0 ? taskCount : nil),
                FusionTabItem(title: "Workflows", icon: "arrow.triangle.branch", badge: nil),
                FusionTabItem(title: "Chat", icon: "bubble.left.and.bubble.right", badge: unreadCount > 0 ? unreadCount : nil),
            ])

            Divider().foregroundStyle(theme.separator)

            Group {
                switch selectedTab {
                case 0: AgentListView(toastManager: toastManager)
                case 1: AgentTaskListView(toastManager: toastManager)
                case 2: WorkflowListView(toastManager: toastManager)
                case 3: ConversationView(toastManager: toastManager)
                default: AgentListView(toastManager: toastManager)
                }
            }
            .animation(theme.springDefault, value: selectedTab)
        }
        .background(theme.windowBg)
        .toast(manager: toastManager)
        .sheet(isPresented: $showCreateAgent) {
            CreateAgentSheet { name, type, model, systemPrompt, temperature, maxTokens, tools, capabilities, safetyLevel, tags in
                createAgentViaBridge(name: name, type: type, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags)
            }
        }
        .onAppear {
            screenContext.startMonitoring()
            agentStudioLog.info("AgentStudioView appeared")
            Task {
                do {
                    try await bridge.checkHealth()
                    try await bridge.fetchAgents()
                    agentStudioLog.info("Bridge health check passed, fetched \(bridge.agents.count) backend agents")
                } catch {
                    agentStudioLog.warning("Bridge connection failed on appear: \(error)")
                }
            }
        }
        .onDisappear {
            screenContext.stopMonitoring()
            fileWatcher.stopWatching()
            agentStudioLog.info("AgentStudioView disappeared")
        }
    }

    private var contextBar: some View {
        let ctx = screenContext.currentContext
        let hasContext = !ctx.activeAppName.isEmpty || !ctx.windowTitle.isEmpty
        return Group {
            if hasContext {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "contextualmenu.and.cursorarrow")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                    if !ctx.activeAppName.isEmpty {
                        Text(ctx.activeAppName)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                    if !ctx.windowTitle.isEmpty {
                        Text(ctx.windowTitle)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingXS)
                .background(theme.surfaceSecondary)
            }
        }
    }

    private func createAgentViaBridge(name: String, type: AgentType, model: String, systemPrompt: String, temperature: Double, maxTokens: Int, tools: [String], capabilities: [String], safetyLevel: String, tags: [String]) {
        orchestrator.createAgent(name: name, type: type, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags)
        toastManager.show(style: .success, title: "Agent Created", message: "\(name) is ready locally")

        Task {
            do {
                let _ = try await bridge.agentCreate(
                    name: name,
                    model: model.isEmpty ? type.defaultModel : model,
                    systemPrompt: systemPrompt.isEmpty ? type.defaultSystemPrompt : systemPrompt,
                    temperature: temperature,
                    maxTokens: maxTokens,
                    tools: tools,
                    capabilities: capabilities,
                    safetyLevel: safetyLevel,
                    tags: tags,
                    soul: ""
                )
                try await bridge.fetchAgents()
                agentStudioLog.info("Created agent via bridge: \(name)")
                toastManager.show(style: .success, title: "Backend Synced", message: "\(name) persisted to backend")
            } catch {
                agentStudioLog.error("Failed to create agent via bridge: \(error)")
                toastManager.show(style: .warning, title: "Backend Sync", message: "Agent created locally but backend sync failed")
            }
        }
    }
}

// MARK: - AgentListView

struct AgentListView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @EnvironmentObject private var bridge: AgentBridge
    @State private var selectedAgent: Agent?
    @State private var selectedBackendAgent: AgentModel?
    @State private var showCreateAgent = false
    let toastManager: FusionToastManager

    @Environment(\.studioTheme) var theme

    var body: some View {
        HSplitView {
            agentListPanel
                .frame(minWidth: 280)

            if let backendAgent = selectedBackendAgent {
                BackendAgentDetailView(agent: backendAgent, toastManager: toastManager)
            } else if let agent = selectedAgent {
                AgentDetailView(agent: agent, toastManager: toastManager)
            } else {
                emptyDetailPlaceholder
            }
        }
        .toolbar {
            ToolbarItem {
                FusionButton("Create Agent", icon: "plus", style: .primary, size: .small) {
                    showCreateAgent = true
                }
            }
        }
        .sheet(isPresented: $showCreateAgent) {
            CreateAgentSheet { name, type, model, systemPrompt, temperature, maxTokens, tools, capabilities, safetyLevel, tags in
                createAndSync(name: name, type: type, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags)
            }
        }
    }

    private func createAndSync(name: String, type: AgentType, model: String, systemPrompt: String, temperature: Double, maxTokens: Int, tools: [String], capabilities: [String], safetyLevel: String, tags: [String]) {
        orchestrator.createAgent(name: name, type: type, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags)
        toastManager.show(style: .success, title: "Agent Created", message: "\(name) is ready")
        Task {
            do {
                let _ = try await bridge.agentCreate(
                    name: name,
                    model: model.isEmpty ? type.defaultModel : model,
                    systemPrompt: systemPrompt.isEmpty ? type.defaultSystemPrompt : systemPrompt,
                    temperature: temperature,
                    maxTokens: maxTokens,
                    tools: tools,
                    capabilities: capabilities,
                    safetyLevel: safetyLevel,
                    tags: tags,
                    soul: ""
                )
                try await bridge.fetchAgents()
            } catch {
                agentStudioLog.error("Backend sync failed for agent \(name): \(error)")
            }
        }
    }

    private var agentListPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                StudioSectionHeader(title: "Backend Agents")
                if bridge.agents.isEmpty {
                    Text("No backend agents — create one")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingM)
                } else {
                    ListGroup {
                        ForEach(Array(bridge.agents.enumerated()), id: \.element.id) { index, agent in
                            StudioRow(label: agent.name, sublabel: agent.model, isLast: index == bridge.agents.count - 1) {
                                HStack(spacing: theme.spacingS) {
                                    FusionTag(agent.safety_level, color: .blue)
                                    if agent.has_soul {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: theme.iconXS))
                                            .foregroundStyle(theme.accent)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedBackendAgent = agent
                                selectedAgent = nil
                                agentStudioLog.info("Selected backend agent: \(agent.name)")
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    deleteBackendAgent(agent)
                                }
                            }
                        }
                    }
                }

                StudioSectionHeader(title: "Built-in Agents")
                ListGroup {
                    ForEach(Array(orchestrator.agents.filter { $0.isBuiltin }.enumerated()), id: \.element.id) { index, agent in
                        StudioRow(label: agent.name, sublabel: agent.model, isLast: index == orchestrator.agents.filter { $0.isBuiltin }.count - 1) {
                            agentRowTrailing(agent: agent)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAgent = agent
                            selectedBackendAgent = nil
                            agentStudioLog.info("Selected built-in agent: \(agent.name)")
                        }
                    }
                }

                StudioSectionHeader(title: "Custom Agents (local)")
                let customAgents = orchestrator.agents.filter { !$0.isBuiltin }
                if customAgents.isEmpty {
                    Text("No custom agents yet")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingM)
                } else {
                    ListGroup {
                        ForEach(Array(customAgents.enumerated()), id: \.element.id) { index, agent in
                            StudioRow(label: agent.name, sublabel: agent.model, isLast: index == customAgents.count - 1) {
                                agentRowTrailing(agent: agent)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedAgent = agent
                                selectedBackendAgent = nil
                                agentStudioLog.info("Selected custom agent: \(agent.name)")
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    orchestrator.deleteAgent(agent.id)
                                    if selectedAgent?.id == agent.id { selectedAgent = nil }
                                    toastManager.show(style: .info, title: "Agent Deleted", message: "\(agent.name) removed")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func deleteBackendAgent(_ agent: AgentModel) {
        Task {
            do {
                let deleted = try await bridge.agentDelete(agentId: agent.id)
                if deleted {
                    if selectedBackendAgent?.id == agent.id { selectedBackendAgent = nil }
                    toastManager.show(style: .info, title: "Agent Deleted", message: "\(agent.name) removed from backend")
                }
            } catch {
                toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
            }
        }
    }

    private func agentRowTrailing(agent: Agent) -> some View {
        HStack(spacing: theme.spacingS) {
            FusionTag(agent.type.rawValue, icon: agent.type.icon, color: agent.type.tagColor)
            StatusPill(status: agent.status.pillStatus, compact: true)
            Text("\(agent.taskCount)")
                .font(.system(size: theme.captionSize, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var emptyDetailPlaceholder: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)
            Text("Select an agent to view details")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - BackendAgentDetailView

struct BackendAgentDetailView: View {
    let agent: AgentModel
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @State private var taskInput = ""
    @State private var isExecuting = false
    @State private var executionResult: String = ""
    @State private var showConfigure = false
    @State private var editTemperature: Double = 0.7
    @State private var editMaxTokens: Int = 4096
    @State private var editSafetyLevel: String = "L1"
    @State private var editModel: String = ""

    @Environment(\.studioTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                headerSection

                FusionCard(style: .inset, header: "Configuration", headerIcon: "gearshape") {
                    VStack(spacing: 0) {
                        infoRow(label: "Model", value: agent.model, isLast: false)
                        infoRow(label: "Temperature", value: String(format: "%.1f", agent.temperature), isLast: false)
                        infoRow(label: "Max Tokens", value: "\(agent.max_tokens)", isLast: false)
                        infoRow(label: "Safety Level", value: agent.safety_level, isLast: false)
                        infoRow(label: "Tools", value: agent.tools.joined(separator: ", "), isLast: false)
                        infoRow(label: "Capabilities", value: agent.capabilities.joined(separator: ", "), isLast: false)
                        infoRow(label: "Tags", value: agent.tags.joined(separator: ", "), isLast: false)
                        infoRow(label: "Has Soul", value: agent.has_soul ? "Yes" : "No", isLast: false)
                        infoRow(label: "Skills", value: agent.skills.joined(separator: ", "), isLast: true)
                    }
                }

                FusionCard(style: .inset, header: "System Prompt", headerIcon: "text.bubble") {
                    Text(agent.system_prompt)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                }

                FusionCard(style: .inset, header: "Execute", headerIcon: "play.fill") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        HStack(spacing: theme.spacingS) {
                            TextField("Enter task for this agent...", text: $taskInput)
                                .textFieldStyle(.plain)
                                .padding(theme.spacingS)
                                .background(theme.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }

                            FusionButton("Run", icon: "play.fill", style: .primary, size: .small, isDisabled: taskInput.isEmpty || isExecuting) {
                                executeAgent()
                            }
                        }

                        if !executionResult.isEmpty {
                            Text(executionResult)
                                .font(.system(size: theme.footnoteSize, design: .monospaced))
                                .foregroundStyle(theme.textSecondary)
                                .padding(theme.spacingS)
                                .background(theme.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        }
                    }
                }

                HStack(spacing: theme.spacingM) {
                    FusionButton("Configure", icon: "slider.horizontal.3", style: .secondary, size: .small) {
                        editTemperature = agent.temperature
                        editMaxTokens = agent.max_tokens
                        editSafetyLevel = agent.safety_level
                        editModel = agent.model
                        showConfigure = true
                    }
                    FusionButton("Delete Agent", icon: "trash", style: .destructive, size: .small) {
                        deleteAgent()
                    }
                    Spacer()
                }
                .padding(.horizontal, theme.spacingS)

                Spacer(minLength: theme.spacing2XL)
            }
            .padding(.vertical, theme.spacingL)
        }
        .sheet(isPresented: $showConfigure) {
            ConfigureAgentSheet(
                agent: agent,
                temperature: $editTemperature,
                maxTokens: $editMaxTokens,
                safetyLevel: $editSafetyLevel,
                model: $editModel,
                onSave: { saveConfig() },
                toastManager: toastManager
            )
        }
    }

    private var headerSection: some View {
        HStack(spacing: theme.spacingM) {
            Image(systemName: "brain")
                .font(.system(size: theme.iconXL))
                .foregroundStyle(theme.accent)
                .frame(width: 40, height: 40)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(agent.name)
                    .font(.system(size: theme.titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)
                FusionTag(agent.safety_level, color: .blue)
            }
            Spacer()
            if isExecuting {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, theme.spacingL)
    }

    private func infoRow(label: String, value: String, isLast: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .foregroundStyle(theme.text)
            Spacer()
        }
        .padding(.vertical, theme.spacingXS)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(theme.rowSep)
                    .frame(height: 0.5)
            }
        }
    }

    private func executeAgent() {
        guard !taskInput.isEmpty else { return }
        isExecuting = true
        executionResult = ""
        Task {
            do {
                let result = try await bridge.agentExecute(agentId: agent.id, input: taskInput)
                isExecuting = false
                if let status = result["status"] as? String, status == "error" {
                    executionResult = "Error: \(result["message"] as? String ?? "unknown")"
                } else {
                    let output = result["output"] as? String ?? result["content"] as? String ?? "Completed"
                    executionResult = output
                }
                toastManager.show(style: .success, title: "Execution Complete", message: "Agent \(agent.name) finished")
            } catch {
                isExecuting = false
                executionResult = "Error: \(error.localizedDescription)"
                toastManager.show(style: .error, title: "Execution Failed", message: error.localizedDescription)
            }
        }
    }

    private func deleteAgent() {
        Task {
            do {
                let deleted = try await bridge.agentDelete(agentId: agent.id)
                if deleted {
                    toastManager.show(style: .info, title: "Agent Deleted", message: "\(agent.name) removed")
                }
            } catch {
                toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
            }
        }
    }

    private func saveConfig() {
        Task {
            do {
                let _ = try await bridge.agentConfigure(agentId: agent.id, config: [
                    "temperature": editTemperature,
                    "max_tokens": editMaxTokens,
                    "safety_level": editSafetyLevel,
                    "model": editModel,
                ])
                try await bridge.fetchAgents()
                showConfigure = false
                toastManager.show(style: .success, title: "Configuration Saved", message: "\(agent.name) updated")
            } catch {
                toastManager.show(style: .error, title: "Save Failed", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - ConfigureAgentSheet

struct ConfigureAgentSheet: View {
    let agent: AgentModel
    @Binding var temperature: Double
    @Binding var maxTokens: Int
    @Binding var safetyLevel: String
    @Binding var model: String
    let onSave: () -> Void
    let toastManager: FusionToastManager

    @Environment(\.dismiss) var dismiss
    @Environment(\.studioTheme) var theme

    private let safetyLevels = ["L1", "L2", "L3", "L4"]

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Configure Agent")
                .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text)

            Text(agent.name)
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            FusionCard(style: .bordered) {
                VStack(spacing: theme.spacingM) {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text("Model")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        TextField("Model name", text: $model)
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
                        Text("Temperature: \(String(format: "%.1f", temperature))")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                    }

                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text("Max Tokens")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        TextField("Max tokens", value: $maxTokens, format: .number)
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
                        Text("Safety Level")
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Picker("Safety Level", selection: $safetyLevel) {
                            ForEach(safetyLevels, id: \.self) { level in
                                Text(level).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            HStack(spacing: theme.spacingM) {
                FusionButton("Cancel", style: .secondary, size: .regular) { dismiss() }
                FusionButton("Save", icon: "checkmark", style: .primary, size: .regular) {
                    onSave()
                }
            }
        }
        .padding(theme.spacingXL)
        .frame(width: 400)
        .background(theme.windowBg)
    }
}

// MARK: - AgentDetailView

struct AgentDetailView: View {
    let agent: Agent
    let toastManager: FusionToastManager
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var taskInput = ""

    @Environment(\.studioTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                headerSection

                FusionCard(style: .inset, header: "Information", headerIcon: "info.circle") {
                    VStack(spacing: 0) {
                        infoRow(label: "Type", value: agent.type.rawValue, isLast: false)
                        infoRow(label: "Model", value: agent.model, isLast: false)
                        infoRow(label: "Status", value: agent.status.rawValue, isLast: false)
                        infoRow(label: "Tasks", value: "\(agent.taskCount)", isLast: false)
                        infoRow(label: "Built-in", value: agent.isBuiltin ? "Yes" : "No", isLast: false)
                        infoRow(label: "Temperature", value: String(format: "%.1f", agent.temperature), isLast: false)
                        infoRow(label: "Safety Level", value: agent.safetyLevel, isLast: true)
                    }
                }

                FusionCard(style: .inset, header: "System Prompt", headerIcon: "text.bubble") {
                    Text(agent.systemPrompt)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                }

                FusionCard(style: .inset, header: "Assign Task", headerIcon: "paperplane") {
                    HStack(spacing: theme.spacingS) {
                        TextField("Describe the task...", text: $taskInput)
                            .textFieldStyle(.plain)
                            .padding(theme.spacingS)
                            .background(theme.inputBg)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }

                        FusionButton("Assign", icon: "paperplane", style: .primary, size: .small, isDisabled: taskInput.isEmpty) {
                            orchestrator.createTask(title: taskInput, description: taskInput, assignTo: agent.id)
                            toastManager.show(style: .success, title: "Task Assigned", message: "Task sent to \(agent.name)")
                            taskInput = ""
                        }
                    }
                }

                HStack(spacing: theme.spacingM) {
                    if !agent.isBuiltin {
                        FusionButton("Delete Agent", icon: "trash", style: .destructive, size: .small) {
                            orchestrator.deleteAgent(agent.id)
                            toastManager.show(style: .info, title: "Agent Deleted", message: "\(agent.name) removed")
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, theme.spacingS)

                Spacer(minLength: theme.spacing2XL)
            }
            .padding(.vertical, theme.spacingL)
        }
    }

    private var headerSection: some View {
        HStack(spacing: theme.spacingM) {
            Image(systemName: agent.type.icon)
                .font(.system(size: theme.iconXL))
                .foregroundStyle(theme.accent)
                .frame(width: 40, height: 40)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(agent.name)
                    .font(.system(size: theme.titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)
                FusionTag(agent.type.rawValue, icon: agent.type.icon, color: agent.type.tagColor)
            }
            Spacer()
            StatusPill(status: agent.status.pillStatus)
        }
        .padding(.horizontal, theme.spacingL)
    }

    private func infoRow(label: String, value: String, isLast: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .foregroundStyle(theme.text)
            Spacer()
        }
        .padding(.vertical, theme.spacingXS)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(theme.rowSep)
                    .frame(height: 0.5)
            }
        }
    }
}

// MARK: - CreateAgentSheet

struct CreateAgentSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.studioTheme) var theme
    @State private var name = ""
    @State private var type: AgentType = .custom
    @State private var model = ""
    @State private var systemPrompt = ""
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 4096
    @State private var safetyLevel: String = "L1"
    @State private var toolsText: String = ""
    @State private var capabilitiesText: String = ""
    @State private var tagsText: String = ""
    let onCreate: (String, AgentType, String, String, Double, Int, [String], [String], String, [String]) -> Void

    private let safetyLevels = ["L1", "L2", "L3", "L4"]

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                Text("Create Agent")
                    .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)

                FusionCard(style: .bordered) {
                    VStack(spacing: theme.spacingM) {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Name *")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField("Agent name", text: $name)
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
                            Text("Type")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            Picker("Type", selection: $type) {
                                ForEach(AgentType.allCases) { t in
                                    Label(t.rawValue, systemImage: t.icon).tag(t)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Model (leave empty for default)")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField(type.defaultModel, text: $model)
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
                            Text("System Prompt")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField(type.defaultSystemPrompt, text: $systemPrompt, axis: .vertical)
                                .lineLimit(2...4)
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
                            Text("Temperature: \(String(format: "%.1f", temperature))")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            Slider(value: $temperature, in: 0...2, step: 0.1)
                        }

                        HStack(spacing: theme.spacingM) {
                            VStack(alignment: .leading, spacing: theme.spacingXS) {
                                Text("Max Tokens")
                                    .font(.system(size: theme.footnoteSize, weight: .medium))
                                    .foregroundStyle(theme.textSecondary)
                                TextField("4096", value: $maxTokens, format: .number)
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
                                Text("Safety Level")
                                    .font(.system(size: theme.footnoteSize, weight: .medium))
                                    .foregroundStyle(theme.textSecondary)
                                Picker("Safety", selection: $safetyLevel) {
                                    ForEach(safetyLevels, id: \.self) { level in
                                        Text(level).tag(level)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Tools (comma-separated)")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField("web_search, calculator, code_execute", text: $toolsText)
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
                            Text("Capabilities (comma-separated)")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField("code_generation, web_browsing", text: $capabilitiesText)
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
                            Text("Tags (comma-separated)")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField("code, python, review", text: $tagsText)
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
                }

                HStack(spacing: theme.spacingM) {
                    FusionButton("Cancel", style: .secondary, size: .regular) { dismiss() }
                    FusionButton("Create", icon: "plus", style: .primary, size: .regular, isDisabled: name.isEmpty) {
                        let tools = toolsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        let capabilities = capabilitiesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        onCreate(name, type, model, systemPrompt, temperature, maxTokens, tools, capabilities, safetyLevel, tags)
                        dismiss()
                    }
                }
            }
            .padding(theme.spacingXL)
            .frame(width: 440)
            .background(theme.windowBg)
        }
    }
}

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
    @StateObject private var orchestrator = AgentOrchestrator.shared
    let toastManager: FusionToastManager

    @Environment(\.studioTheme) var theme

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320))], spacing: theme.spacingM) {
                ForEach(orchestrator.workflows) { workflow in
                    WorkflowCard(workflow: workflow, toastManager: toastManager)
                }
            }
            .padding(theme.spacingL)
        }
    }
}

struct WorkflowCard: View {
    let workflow: AgentWorkflow
    let toastManager: FusionToastManager
    @StateObject private var orchestrator = AgentOrchestrator.shared

    @Environment(\.studioTheme) var theme

    private var isActive: Bool {
        orchestrator.activeWorkflow?.id == workflow.id
    }

    var body: some View {
        FusionCard(style: .elevated, header: workflow.name, headerIcon: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text(workflow.description)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)

                stepVisualization

                HStack {
                    if isActive {
                        FusionButton("Stop", icon: "stop.fill", style: .destructive, size: .small) {
                            orchestrator.stopWorkflow()
                            toastManager.show(style: .info, title: "Workflow Stopped", message: workflow.name)
                        }
                    } else {
                        FusionButton("Run", icon: "play.fill", style: .primary, size: .small, isDisabled: orchestrator.activeWorkflow != nil) {
                            orchestrator.runWorkflow(workflow)
                            toastManager.show(style: .success, title: "Workflow Running", message: workflow.name)
                        }
                    }
                    Spacer()
                    Text("\(workflow.steps.count) steps")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    private var stepVisualization: some View {
        let sortedSteps = workflow.steps.sorted(by: { $0.order < $1.order })
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sortedSteps.enumerated()), id: \.element.id) { index, step in
                HStack(spacing: theme.spacingM) {
                    ZStack {
                        Circle()
                            .fill(isActive ? theme.accentSoft : theme.controlBg)
                            .frame(width: 24, height: 24)
                        Text("\(step.order)")
                            .font(.system(size: theme.captionSize, weight: .bold, design: .rounded))
                            .foregroundStyle(isActive ? theme.accent : theme.textSecondary)
                    }

                    if index < sortedSteps.count - 1 {
                        Rectangle()
                            .fill(theme.rowSep)
                            .frame(width: 1.5)
                            .frame(height: 8)
                    } else {
                        Color.clear.frame(width: 1.5, height: 0)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(orchestrator.agents.first(where: { $0.id == step.agentId })?.name ?? "Unknown")
                            .font(.system(size: theme.smallTextSize, weight: .medium))
                            .foregroundStyle(theme.text)
                        Text(step.instruction)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    FusionTag(
                        orchestrator.agents.first(where: { $0.id == step.agentId })?.type.rawValue ?? "",
                        color: orchestrator.agents.first(where: { $0.id == step.agentId })?.type.tagColor ?? .gray
                    )
                }
                .padding(.leading, 0)
            }
        }
    }
}

// MARK: - ConversationView

struct ConversationView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var inputText = ""
    let toastManager: FusionToastManager

    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            if orchestrator.conversationLog.isEmpty {
                emptyChatPlaceholder
            } else {
                messageList
            }
            inputBar
        }
        .toolbar {
            ToolbarItem {
                FusionButton("Clear", icon: "trash", style: .ghost, size: .small) {
                    orchestrator.clearConversation()
                    toastManager.show(style: .info, title: "Chat Cleared", message: "Conversation history removed")
                }
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: theme.spacingS) {
                    ForEach(orchestrator.conversationLog) { msg in
                        messageBubble(msg: msg)
                            .id(msg.id)
                    }
                }
                .padding(theme.spacingL)
            }
            .onChange(of: orchestrator.conversationLog.count) { _, _ in
                withAnimation(theme.springSnappy) {
                    proxy.scrollTo(orchestrator.conversationLog.last?.id, anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(msg: AgentOrchestrator.AgentMessage) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                HStack(spacing: theme.spacingXS) {
                    Text(msg.fromAgent)
                        .font(.system(size: theme.smallTextSize, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Image(systemName: "arrow.right")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                    Text(msg.toAgent)
                        .font(.system(size: theme.smallTextSize, weight: .semibold))
                        .foregroundStyle(theme.accentSecondary)
                    Spacer()
                    Text(msg.timestamp, style: .time)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Text(msg.content)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
            }
        }
        .padding(theme.spacingM)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
    }

    private var inputBar: some View {
        HStack(spacing: theme.spacingS) {
            TextField("Send a message...", text: $inputText)
                .textFieldStyle(.plain)
                .padding(theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                }
                .onSubmit { sendMessage() }

            FusionButton("Send", icon: "paperplane.fill", style: .primary, size: .small, isDisabled: inputText.isEmpty) {
                sendMessage()
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.separator)
                .frame(height: 0.5)
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        orchestrator.sendMessage(from: "User", to: "All Agents", content: inputText)
        agentStudioLog.info("User sent message: \(inputText)")
        inputText = ""
    }

    private var emptyChatPlaceholder: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("No messages yet")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Text("Run a workflow or send a message to start a conversation")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
    }
}
