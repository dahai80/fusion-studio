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
        let cfg = FusionConfig.shared.defaultModel(for: .agent)
        if !cfg.isEmpty { return cfg }
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
                FusionTabItem(title: "Dashboard", icon: "chart.bar", badge: nil),
                FusionTabItem(title: "Team", icon: "person.3", badge: nil),
                FusionTabItem(title: "Connectors", icon: "link", badge: nil),
                FusionTabItem(title: "API Keys", icon: "key", badge: nil),
                FusionTabItem(title: "Styles", icon: "paintbrush", badge: nil),
                FusionTabItem(title: "Analytics", icon: "chart.xyaxis.line", badge: nil),
                FusionTabItem(title: "Alerts", icon: "bell", badge: nil),
                FusionTabItem(title: "Cron", icon: "clock.arrow.2.circlepath", badge: nil),
                FusionTabItem(title: "Hooks", icon: "point.3.connected.trianglepath.dotted", badge: nil),
                FusionTabItem(title: "Marketplace", icon: "bag", badge: nil),
                FusionTabItem(title: "Chat", icon: "bubble.left.and.bubble.right", badge: unreadCount > 0 ? unreadCount : nil),
            ])

            Divider().foregroundStyle(theme.separator)

            Group {
                switch selectedTab {
                case 0: AgentListView(toastManager: toastManager)
                case 1: AgentTaskListView(toastManager: toastManager)
                case 2: WorkflowListView(toastManager: toastManager)
                case 3: DashboardTabView(toastManager: toastManager)
                case 4: TeamTabView(toastManager: toastManager)
                case 5: ConnectorTabView(toastManager: toastManager)
                case 6: ApikeyTabView(toastManager: toastManager)
                case 7: StyleTabView(toastManager: toastManager)
                case 8: AnalyticsTabView(toastManager: toastManager)
                case 9: AlertTabView(toastManager: toastManager)
                case 10: CronTabView(toastManager: toastManager)
                case 11: HooksTabView(toastManager: toastManager)
                case 12: MarketplaceTabView(toastManager: toastManager)
                case 13: ConversationView(toastManager: toastManager)
                default: AgentListView(toastManager: toastManager)
                }
            }
            .animation(theme.springDefault, value: selectedTab)
        }
        .background(theme.windowBg)
        .toast(manager: toastManager)
        .sheet(isPresented: $showCreateAgent) {
            CreateAgentSheet { name, type, model, systemPrompt, temperature, maxTokens, tools, capabilities, safetyLevel, tags, soul, memory, agentsMd, graphId in
                createAgentViaBridge(name: name, type: type, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags, soul: soul, memory: memory, agentsMd: agentsMd)
            }
        }
        .onAppear {
            screenContext.startMonitoring()
            agentStudioLog.info("AgentStudioView appeared")
            Task {
                do {
                    try await bridge.checkHealth()
                    try await bridge.fetchAgents()
                    try await bridge.fetchGraphs()
                    agentStudioLog.info("Bridge health check passed, fetched \(bridge.agents.count) agents, \(bridge.graphs.count) graphs")
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

    private func createAgentViaBridge(name: String, type: AgentType, model: String, systemPrompt: String, temperature: Double, maxTokens: Int, tools: [String], capabilities: [String], safetyLevel: String, tags: [String], soul: String, memory: String, agentsMd: String) {
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
                    soul: soul,
                    memory: memory,
                    agentsMd: agentsMd
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
        GeometryReader { geo in
            HSplitView {
                agentListPanel
                    .frame(minWidth: 200, idealWidth: max(200, geo.size.width * 0.2), maxWidth: 360)

                Group {
                    if let backendAgent = selectedBackendAgent {
                        BackendAgentDetailView(agent: backendAgent, toastManager: toastManager)
                            .onAppear { bridge.currentAgent = backendAgent }
                    } else if let agent = selectedAgent {
                        AgentDetailView(agent: agent, toastManager: toastManager)
                            .onAppear { bridge.currentAgent = nil }
                    } else {
                        emptyDetailPlaceholder
                    }
                }
                .frame(minWidth: 400, idealWidth: geo.size.width * 0.8)
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
            CreateAgentSheet { name, type, model, systemPrompt, temperature, maxTokens, tools, capabilities, safetyLevel, tags, soul, memory, agentsMd, graphId in
                createAndSync(name: name, type: type, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags, soul: soul, memory: memory, agentsMd: agentsMd)
            }
        }
    }

    private func createAndSync(name: String, type: AgentType, model: String, systemPrompt: String, temperature: Double, maxTokens: Int, tools: [String], capabilities: [String], safetyLevel: String, tags: [String], soul: String, memory: String, agentsMd: String) {
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
                    soul: soul,
                    memory: memory,
                    agentsMd: agentsMd
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
                                    if let status = agent.status {
                                        FusionTag(status, color: statusColor(for: status))
                                    }
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
                                if agent.status != "published" {
                                    Button {
                                        Task { await publishBackendAgent(agent) }
                                    } label: {
                                        Label("Publish", systemImage: "arrow.up.circle")
                                    }
                                }
                                if agent.status == "published" {
                                    Button {
                                        Task { await archiveBackendAgent(agent) }
                                    } label: {
                                        Label("Archive", systemImage: "archivebox")
                                    }
                                }
                                Button {
                                    Task { await cloneBackendAgent(agent) }
                                } label: {
                                    Label("Clone", systemImage: "doc.on.doc")
                                }
                                Divider()
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

    private func publishBackendAgent(_ agent: AgentModel) async {
        do {
            let updated = try await bridge.agentPublish(agentId: agent.id)
            toastManager.show(style: .success, title: "Published", message: "\(updated.name) is now live")
        } catch {
            toastManager.show(style: .error, title: "Publish Failed", message: error.localizedDescription)
        }
    }

    private func archiveBackendAgent(_ agent: AgentModel) async {
        do {
            let updated = try await bridge.agentArchive(agentId: agent.id)
            toastManager.show(style: .info, title: "Archived", message: "\(updated.name) archived")
        } catch {
            toastManager.show(style: .error, title: "Archive Failed", message: error.localizedDescription)
        }
    }

    private func cloneBackendAgent(_ agent: AgentModel) async {
        do {
            let cloned = try await bridge.agentClone(agentId: agent.id)
            toastManager.show(style: .success, title: "Cloned", message: "\(cloned.name) created")
        } catch {
            toastManager.show(style: .error, title: "Clone Failed", message: error.localizedDescription)
        }
    }

    private func statusColor(for status: String) -> TagColor {
        switch status {
        case "draft": return .gray
        case "published": return .green
        case "archived": return .orange
        default: return .gray
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
    @State private var newSkillName = ""
    @State private var showSoulEditor = false
    @State private var editSoulContent = ""

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
                        infoRow(label: "Tags", value: agent.tags.joined(separator: ", "), isLast: true)
                    }
                }

                skillsSection

                soulSection

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
                            if isExecuting {
                                FusionButton("Cancel", icon: "stop.fill", style: .destructive, size: .small) {
                                    bridge.cancelExecution()
                                    isExecuting = false
                                }
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
        .sheet(isPresented: $showSoulEditor) {
            SoulEditorSheet(soulContent: $editSoulContent, onSave: {
                saveSoul()
            }, toastManager: toastManager)
        }
        .onAppear {
            loadSkillsAndSoul()
        }
    }

    private var skillsSection: some View {
        FusionCard(style: .inset, header: "Skills (\(bridge.agentSkills.count))", headerIcon: "sparkles") {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                if bridge.agentSkills.isEmpty {
                    Text("No skills assigned")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    FlowLayout(spacing: theme.spacingXS) {
                        ForEach(bridge.agentSkills, id: \.self) { skill in
                            HStack(spacing: theme.spacingXS) {
                                Text(skill)
                                    .font(.system(size: theme.captionSize, weight: .medium))
                                    .foregroundStyle(theme.text)
                                Button(action: { deleteSkill(skill) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(theme.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, theme.spacingS)
                            .padding(.vertical, theme.spacingXS)
                            .background(theme.accentSoft)
                            .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: theme.spacingS) {
                    TextField("New skill name", text: $newSkillName)
                        .textFieldStyle(.plain)
                        .padding(theme.spacingXS)
                        .background(theme.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(theme.inputBorder, lineWidth: 1)
                        }
                    FusionButton("Add", icon: "plus", style: .secondary, size: .small, isDisabled: newSkillName.isEmpty) {
                        addSkill()
                    }
                }
            }
        }
    }

    private var soulSection: some View {
        FusionCard(style: .inset, header: "Soul", headerIcon: "heart.fill") {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                if bridge.agentSoul.isEmpty {
                    Text("No soul defined")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                } else {
                    Text(bridge.agentSoul)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(5)
                        .textSelection(.enabled)
                }
                FusionButton("Edit Soul", icon: "pencil", style: .secondary, size: .small) {
                    editSoulContent = bridge.agentSoul
                    showSoulEditor = true
                }
            }
        }
    }

    private func loadSkillsAndSoul() {
        Task {
            do {
                _ = try await bridge.fetchAgentSkills(agentId: agent.id)
                _ = try await bridge.fetchAgentSoul(agentId: agent.id)
            } catch {
                agentStudioLog.warning("Failed to load skills/soul: \(error)")
            }
        }
    }

    private func addSkill() {
        guard !newSkillName.isEmpty else { return }
        let name = newSkillName
        newSkillName = ""
        Task {
            do {
                let ok = try await bridge.agentAddSkill(agentId: agent.id, skillName: name)
                if ok {
                    toastManager.show(style: .success, title: "Skill Added", message: name)
                }
            } catch {
                toastManager.show(style: .error, title: "Add Skill Failed", message: error.localizedDescription)
            }
        }
    }

    private func deleteSkill(_ skill: String) {
        Task {
            do {
                let ok = try await bridge.agentDeleteSkill(agentId: agent.id, skillName: skill)
                if ok {
                    toastManager.show(style: .info, title: "Skill Removed", message: skill)
                }
            } catch {
                toastManager.show(style: .error, title: "Remove Skill Failed", message: error.localizedDescription)
            }
        }
    }

    private func saveSoul() {
        Task {
            do {
                let ok = try await bridge.agentUpdateSoul(agentId: agent.id, soul: editSoulContent)
                if ok {
                    showSoulEditor = false
                    toastManager.show(style: .success, title: "Soul Updated", message: "Agent soul saved")
                }
            } catch {
                toastManager.show(style: .error, title: "Soul Update Failed", message: error.localizedDescription)
            }
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
    @EnvironmentObject var bridge: AgentBridge

    // Backend SafetyGateway defines a 3-level system (L1/L2/L3); L4 has no backend meaning.
    private let safetyLevels = ["L1", "L2", "L3"]
    private let safetyExplanations: [String: String] = [
        "L1": "Autonomous - agent acts silently, no approval needed.",
        "L2": "Preview - agent shows a diff/plan and waits for your confirm before executing.",
        "L3": "Gateway - agent must get explicit approval before every action."
    ]

    private var availableModels: [MLXModelInfo] {
        let chat = bridge.models.filter { $0.isTextChatModel }
        return chat.isEmpty ? bridge.models : chat
    }

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
                        if availableModels.isEmpty {
                            TextField(agent.model, text: $model)
                                .textFieldStyle(.plain)
                                .padding(theme.spacingS)
                                .background(theme.inputBg)
                                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }
                            Text("No models loaded from fusion-mlx. Start the MLX service or enter a model id manually.")
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                        } else {
                            FusionModelPicker(scene: .agent, selection: $model, models: bridge.models)
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
                        Text(safetyExplanations[safetyLevel] ?? "")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
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
    @EnvironmentObject var bridge: AgentBridge
    @State private var name = ""
    @State private var availableGraphs: [AgentGraphModel] = []
    @State private var selectedGraphId: UUID? = nil
    @State private var type: AgentType = .custom
    @State private var model = ""
    @State private var systemPrompt = ""
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Int = 4096
    @State private var safetyLevel: String = "L1"
    @State private var toolsText: String = ""
    @State private var capabilitiesText: String = ""
    @State private var tagsText: String = ""
    @State private var soulMd: String = ""
    @State private var memoryMd: String = ""
    @State private var agentsMd: String = ""
    let onCreate: (String, AgentType, String, String, Double, Int, [String], [String], String, [String], String, String, String, UUID?) -> Void

    // Backend SafetyGateway defines a 3-level system (L1/L2/L3); L4 has no backend meaning.
    private let safetyLevels = ["L1", "L2", "L3"]
    private let safetyExplanations: [String: String] = [
        "L1": "Autonomous — agent acts silently, no approval needed.",
        "L2": "Preview — agent shows a diff/plan and waits for your confirm before executing.",
        "L3": "Gateway — agent must get explicit approval before every action."
    ]

    private var availableModels: [MLXModelInfo] {
        let chat = bridge.models.filter { $0.isTextChatModel }
        return chat.isEmpty ? bridge.models : chat
    }

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
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Model")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            if availableModels.isEmpty {
                                TextField(type.defaultModel, text: $model)
                                    .textFieldStyle(.plain)
                                    .padding(theme.spacingS)
                                    .background(theme.inputBg)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .stroke(theme.inputBorder, lineWidth: 1)
                                    }
                                Text("No models loaded from fusion-mlx. Start the MLX service or enter a model id manually.")
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textTertiary)
                            } else {
                                FusionModelPicker(scene: .agent, selection: $model, models: bridge.models, defaultTag: "")
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
                                Text(safetyExplanations[safetyLevel] ?? "")
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
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

                        markdownField("SOUL.md (personality & instructions)",
                                      placeholder: "Define the agent's persona, tone, and core instructions...",
                                      text: $soulMd)
                        markdownField("MEMORY.md (persistent memory)",
                                      placeholder: "Facts and context the agent should remember across sessions...",
                                      text: $memoryMd)
                        markdownField("AGENTS.md (metadata & conventions)",
                                      placeholder: "Conventions, sub-agent definitions, and operational notes...",
                                      text: $agentsMd)

                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text("Workflow / Graph")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            if availableGraphs.isEmpty {
                                HStack(spacing: 4) {
                                    Text("No graphs available — create one in Workflow tab")
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.textTertiary)
                                    Button("Refresh") {
                                        Task { try? await bridge.fetchGraphs() }
                                    }
                                    .font(.system(size: theme.captionSize))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color.accentColor)
                                }
                            } else {
                                Picker("Select Graph", selection: $selectedGraphId) {
                                    Text("None").tag(UUID?.none)
                                    ForEach(availableGraphs, id: \.id) { graph in
                                        Text("\(graph.name) (\(graph.nodes.count) nodes)")
                                            .tag(UUID?.some(graph.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
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
                        onCreate(name, type, model, systemPrompt, temperature, maxTokens, tools, capabilities, safetyLevel, tags, soulMd, memoryMd, agentsMd, selectedGraphId)
                        dismiss()
                    }
                }
            }
            .padding(theme.spacingXL)
            .frame(width: 440)
            .background(theme.windowBg)
        }
        .onAppear {
            Task {
                if let graphs = try? await bridge.fetchGraphs() {
                    availableGraphs = graphs
                }
            }
        }
    }

    private func markdownField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(title)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            TextEditor(text: text)
                .font(.system(size: theme.footnoteSize))
                .scrollContentBackground(.hidden)
                .padding(theme.spacingS)
                .frame(minHeight: 80, idealHeight: 100)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textTertiary)
                            .padding(theme.spacingS)
                            .allowsHitTesting(false)
                    }
                }
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

// MARK: - TeamTabView

struct TeamTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showOrchestrateSheet = false
    @State private var orchestrateTask = ""
    @State private var selectedAgentIds: Set<String> = []
    @State private var orchestrateMode = "sequential"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Multi-Agent Team")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Orchestrate", icon: "play.circle") { showOrchestrateSheet = true }
            }
            .padding(theme.spacingM)

            StudioSectionHeader(title: "Swarm Agents")
            if bridge.swarmAgents.isEmpty {
                Text("No swarm agents registered")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingM)
            } else {
                ListGroup {
                    ForEach(Array(bridge.swarmAgents.enumerated()), id: \.offset) { idx, agent in
                        let name = agent["name"] as? String ?? agent["agent_id"] as? String ?? "Unknown"
                        let role = agent["role"] as? String ?? "worker"
                        let status = agent["status"] as? String ?? "idle"
                        StudioRow(label: name, sublabel: role, isLast: idx == bridge.swarmAgents.count - 1) {
                            FusionTag(status, color: status == "active" ? .green : .gray)
                        }
                    }
                }
            }

            StudioSectionHeader(title: "Plaza Channels")
            if bridge.plazaChannels.isEmpty {
                Text("No plaza channels")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingM)
            } else {
                ListGroup {
                    ForEach(Array(bridge.plazaChannels.enumerated()), id: \.offset) { idx, ch in
                        let name = ch["name"] as? String ?? "Unknown"
                        let desc = ch["description"] as? String ?? ""
                        StudioRow(label: name, sublabel: desc, isLast: idx == bridge.plazaChannels.count - 1) {
                            FusionTag("channel", color: .purple)
                        }
                    }
                }
            }
            Spacer()
        }
        .onAppear {
            Task {
                await bridge.fetchSwarmAgents()
                await bridge.fetchPlazaChannels()
            }
        }
        .sheet(isPresented: $showOrchestrateSheet) {
            orchestrateSheet
        }
    }

    private var orchestrateSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("Orchestrate Task")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Task description", text: $orchestrateTask, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            Picker("Mode", selection: $orchestrateMode) {
                Text("Sequential").tag("sequential")
                Text("Parallel").tag("parallel")
                Text("Swarm").tag("swarm")
            }
            .pickerStyle(.segmented)
            Text("Select agents:")
                .font(.system(size: theme.captionSize))
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(bridge.agents) { agent in
                        HStack {
                            Image(systemName: selectedAgentIds.contains(agent.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(theme.accent)
                            Text(agent.name)
                                .font(.system(size: theme.textSize))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedAgentIds.contains(agent.id) {
                                selectedAgentIds.remove(agent.id)
                            } else {
                                selectedAgentIds.insert(agent.id)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
            HStack {
                FusionButton("Cancel") { showOrchestrateSheet = false }
                Spacer()
                FusionButton("Run", icon: "play") {
                    Task { await runOrchestration() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450, height: 500)
    }

    private func runOrchestration() async {
        guard !orchestrateTask.isEmpty, !selectedAgentIds.isEmpty else { return }
        do {
            let result = try await bridge.teamOrchestrate(task: orchestrateTask, agentIds: Array(selectedAgentIds), mode: orchestrateMode)
            let status = result["status"] as? String ?? "started"
            toastManager.show(style: .success, title: "Orchestration \(status)", message: orchestrateTask)
            showOrchestrateSheet = false
            orchestrateTask = ""
            selectedAgentIds.removeAll()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - CronTabView

struct CronTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newSchedule = "0 * * * *"
    @State private var newAgentId = ""
    @State private var newInput = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Scheduled Tasks")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Add Cron", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.cronJobs.isEmpty {
                Spacer()
                Text("No scheduled tasks")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.cronJobs.enumerated()), id: \.offset) { idx, job in
                        let name = job["name"] as? String ?? "Unknown"
                        let schedule = job["schedule"] as? String ?? ""
                        let agentId = job["agent_id"] as? String ?? ""
                        let cronId = job["cron_id"] as? String ?? job["id"] as? String ?? ""
                        let enabled = job["enabled"] as? Bool ?? true
                        StudioRow(label: name, sublabel: "\(schedule) → \(agentId)", isLast: idx == bridge.cronJobs.count - 1) {
                            FusionTag(enabled ? "active" : "paused", color: enabled ? .green : .gray)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Unregister", role: .destructive) {
                                Task { await unregisterCron(cronId, name: name) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchCronJobs() } }
        .sheet(isPresented: $showCreateSheet) {
            createCronSheet
        }
    }

    private var createCronSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New Scheduled Task")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Schedule (cron)", text: $newSchedule)
                .textFieldStyle(.roundedBorder)
            Picker("Agent", selection: $newAgentId) {
                Text("Select agent").tag("")
                ForEach(bridge.agents) { a in
                    Text(a.name).tag(a.id)
                }
            }
            .pickerStyle(.menu)
            TextField("Input (optional)", text: $newInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createCron() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createCron() async {
        guard !newName.isEmpty, !newAgentId.isEmpty else { return }
        do {
            _ = try await bridge.cronRegister(name: newName, schedule: newSchedule, agentId: newAgentId, input: newInput)
            toastManager.show(style: .success, title: "Created", message: newName)
            showCreateSheet = false
            newName = ""; newInput = ""
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func unregisterCron(_ id: String, name: String) async {
        do {
            _ = try await bridge.cronUnregister(cronId: id)
            toastManager.show(style: .info, title: "Removed", message: name)
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - HooksTabView

struct HooksTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newEvent = "agent.execute"
    @State private var newAgentId = ""
    @State private var newAction = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Hooks")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Add Hook", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.hooks.isEmpty {
                Spacer()
                Text("No hooks registered")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.hooks.enumerated()), id: \.offset) { idx, hook in
                        let event = hook["event"] as? String ?? "Unknown"
                        let agentId = hook["agent_id"] as? String ?? ""
                        let action = hook["action"] as? String ?? ""
                        let hookId = hook["hook_id"] as? String ?? hook["id"] as? String ?? ""
                        StudioRow(label: event, sublabel: "\(agentId) → \(action)", isLast: idx == bridge.hooks.count - 1) {
                            FusionTag("hook", color: .blue)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                Task { await testHook(hookId) }
                            } label: {
                                Label("Test", systemImage: "bolt")
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchHooks() } }
        .sheet(isPresented: $showCreateSheet) {
            createHookSheet
        }
    }

    private var createHookSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New Hook")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Event (e.g. agent.execute)", text: $newEvent)
                .textFieldStyle(.roundedBorder)
            Picker("Agent", selection: $newAgentId) {
                Text("Select agent").tag("")
                ForEach(bridge.agents) { a in
                    Text(a.name).tag(a.id)
                }
            }
            .pickerStyle(.menu)
            TextField("Action", text: $newAction)
                .textFieldStyle(.roundedBorder)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createHook() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createHook() async {
        guard !newEvent.isEmpty, !newAgentId.isEmpty, !newAction.isEmpty else { return }
        do {
            _ = try await bridge.hooksRegister(event: newEvent, agentId: newAgentId, action: newAction)
            toastManager.show(style: .success, title: "Hook Created", message: newEvent)
            showCreateSheet = false
            newAction = ""
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func testHook(_ id: String) async {
        do {
            let result = try await bridge.hooksTest(hookId: id)
            let success = result["success"] as? Bool ?? false
            toastManager.show(style: success ? .success : .error, title: success ? "Hook OK" : "Hook Failed", message: "")
        } catch {
            toastManager.show(style: .error, title: "Test Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - AnalyticsTabView

struct AnalyticsTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var selectedRange = "week"

    private let ranges = ["day", "week", "month"]

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                HStack {
                    Text("Analytics")
                        .font(.system(size: theme.titleSize, weight: .bold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Picker("Range", selection: $selectedRange) {
                        ForEach(ranges, id: \.self) { r in
                            Text(r.capitalized).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: selectedRange) { _, newRange in
                        Task { await bridge.fetchAnalytics(range: newRange) }
                    }
                }
                .padding(theme.spacingM)

                analyticsCards
                agentUsageList
                Spacer()
            }
        }
        .onAppear { Task { await bridge.fetchAnalytics(range: selectedRange) } }
    }

    private var analyticsCards: some View {
        let d = bridge.analyticsData
        let totalRequests = d["total_requests"] as? Int ?? 0
        let totalTokens = d["total_tokens"] as? Int ?? 0
        let avgLatency = d["avg_latency_ms"] as? Double ?? 0
        let errorRate = d["error_rate"] as? Double ?? 0
        let cards: [(String, String, String, TagColor)] = [
            ("Total Requests", "\(totalRequests)", "text.bubble", .blue),
            ("Total Tokens", "\(totalTokens)", "number", .blue),
            ("Avg Latency", String(format: "%.0fms", avgLatency), "clock", .purple),
            ("Error Rate", String(format: "%.1f%%", errorRate), "exclamationmark.triangle", errorRate > 5 ? .red : .green),
        ]
        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
        ], spacing: theme.spacingM) {
            ForEach(cards, id: \.0) { card in
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Image(systemName: card.2)
                            .foregroundStyle(theme.accent)
                        Spacer()
                        Text(card.0)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Text(card.1)
                        .font(.system(size: theme.titleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text)
                }
                .padding(theme.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .fill(theme.surfaceSecondary)
                )
            }
        }
        .padding(.horizontal, theme.spacingM)
    }

    private var agentUsageList: some View {
        let perAgent = bridge.analyticsData["per_agent"] as? [[String: Any]] ?? []
        return VStack(alignment: .leading, spacing: 0) {
            if perAgent.isEmpty {
                Text("No per-agent analytics data")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(theme.spacingL)
            } else {
                ForEach(Array(perAgent.enumerated()), id: \.offset) { idx, entry in
                    let name = entry["name"] as? String ?? entry["agent_id"] as? String ?? "Unknown"
                    let reqs = entry["requests"] as? Int ?? 0
                    let tokens = entry["tokens"] as? Int ?? 0
                    HStack {
                        Text(name)
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.text)
                        Spacer()
                        Text("\(reqs) reqs")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                        Text("\(tokens) tok")
                            .font(.system(size: theme.captionSize, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.text)
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(idx % 2 == 0 ? theme.surfaceSecondary : theme.surfacePrimary)
                }
            }
        }
        .padding(.horizontal, theme.spacingM)
    }
}

// MARK: - AlertTabView

struct AlertTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Alerts")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Refresh", icon: "arrow.clockwise") {
                    Task { await bridge.fetchAlerts() }
                }
            }
            .padding(theme.spacingM)

            if bridge.alerts.isEmpty {
                Spacer()
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.successText)
                    Text("No active alerts")
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.alerts.enumerated()), id: \.offset) { idx, alert in
                        let level = alert["level"] as? String ?? "info"
                        let message = alert["message"] as? String ?? "No message"
                        let source = alert["source"] as? String ?? ""
                        let aid = alert["alert_id"] as? String ?? alert["id"] as? String ?? ""
                        let acknowledged = alert["acknowledged"] as? Bool ?? false
                        StudioRow(label: message, sublabel: source, isLast: idx == bridge.alerts.count - 1) {
                            FusionTag(level, color: alertColor(for: level))
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            if !acknowledged {
                                Button {
                                    Task { await ackAlert(aid) }
                                } label: {
                                    Label("Acknowledge", systemImage: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchAlerts() } }
    }

    private func alertColor(for level: String) -> TagColor {
        switch level {
        case "critical", "error": return .red
        case "warning", "warn": return .orange
        case "info": return .blue
        default: return .gray
        }
    }

    private func ackAlert(_ id: String) async {
        do {
            _ = try await bridge.alertAcknowledge(alertId: id)
            toastManager.show(style: .success, title: "Acknowledged", message: "Alert dismissed")
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - ConnectorTabView

struct ConnectorTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newType = "http"
    @State private var newConfig = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Connectors")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Add Connector", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.connectors.isEmpty {
                Spacer()
                Text("No connectors configured")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.connectors.enumerated()), id: \.offset) { idx, conn in
                        let name = conn["name"] as? String ?? "Unknown"
                        let type = conn["type"] as? String ?? ""
                        let status = conn["status"] as? String ?? "unknown"
                        let cid = conn["connector_id"] as? String ?? conn["id"] as? String ?? ""
                        StudioRow(label: name, sublabel: type, isLast: idx == bridge.connectors.count - 1) {
                            FusionTag(status, color: status == "connected" ? .green : status == "disconnected" ? .gray : .orange)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button { Task { await testConnector(cid, name: name) } } label: {
                                Label("Test", systemImage: "bolt")
                            }
                            if status != "connected" {
                                Button { Task { await connectConnector(cid, name: name) } } label: {
                                    Label("Connect", systemImage: "link")
                                }
                            }
                            if status == "connected" {
                                Button { Task { await disconnectConnector(cid, name: name) } } label: {
                                    Label("Disconnect", systemImage: "link.badge.plus")
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                Task { await deleteConnector(cid, name: name) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchConnectors() } }
        .sheet(isPresented: $showCreateSheet) {
            createConnectorSheet
        }
    }

    private var createConnectorSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New Connector")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Type (http, database, api...)", text: $newType)
                .textFieldStyle(.roundedBorder)
            TextField("Config (JSON)", text: $newConfig, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createConnector() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createConnector() async {
        guard !newName.isEmpty else { return }
        var config: [String: Any] = [:]
        if let data = newConfig.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            config = json
        }
        do {
            _ = try await bridge.connectorCreate(name: newName, type: newType, config: config)
            toastManager.show(style: .success, title: "Created", message: "\(newName)")
            showCreateSheet = false
            newName = ""; newConfig = ""
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func testConnector(_ id: String, name: String) async {
        do {
            let result = try await bridge.connectorTest(connectorId: id)
            let success = result["success"] as? Bool ?? false
            toastManager.show(style: success ? .success : .error, title: success ? "OK" : "Failed", message: "\(name)")
        } catch {
            toastManager.show(style: .error, title: "Test Failed", message: error.localizedDescription)
        }
    }

    private func connectConnector(_ id: String, name: String) async {
        do {
            _ = try await bridge.connectorConnect(connectorId: id)
            toastManager.show(style: .success, title: "Connected", message: name)
            await bridge.fetchConnectors()
        } catch {
            toastManager.show(style: .error, title: "Connect Failed", message: error.localizedDescription)
        }
    }

    private func disconnectConnector(_ id: String, name: String) async {
        do {
            _ = try await bridge.connectorDisconnect(connectorId: id)
            toastManager.show(style: .info, title: "Disconnected", message: name)
            await bridge.fetchConnectors()
        } catch {
            toastManager.show(style: .error, title: "Disconnect Failed", message: error.localizedDescription)
        }
    }

    private func deleteConnector(_ id: String, name: String) async {
        do {
            _ = try await bridge.connectorDelete(connectorId: id)
            toastManager.show(style: .info, title: "Deleted", message: name)
        } catch {
            toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - ApikeyTabView

struct ApikeyTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newPermissions = "read,execute"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("API Keys")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Create Key", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.apikeys.isEmpty {
                Spacer()
                Text("No API keys")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.apikeys.enumerated()), id: \.offset) { idx, key in
                        let name = key["name"] as? String ?? "Unknown"
                        let kid = key["key_id"] as? String ?? key["id"] as? String ?? ""
                        let prefix = key["key_prefix"] as? String ?? ""
                        let perms = key["permissions"] as? [String] ?? []
                        StudioRow(label: name, sublabel: prefix.isEmpty ? kid : prefix, isLast: idx == bridge.apikeys.count - 1) {
                            if perms.contains("admin") {
                                FusionTag("admin", color: .red)
                            } else if perms.contains("execute") {
                                FusionTag("execute", color: .green)
                            } else {
                                FusionTag("read", color: .blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Revoke", role: .destructive) {
                                Task { await revokeKey(kid, name: name) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchApikeys() } }
        .sheet(isPresented: $showCreateSheet) {
            createApikeySheet
        }
    }

    private var createApikeySheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New API Key")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Permissions (comma-separated)", text: $newPermissions)
                .textFieldStyle(.roundedBorder)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createKey() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createKey() async {
        guard !newName.isEmpty else { return }
        let perms = newPermissions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        do {
            let result = try await bridge.apikeyCreate(name: newName, permissions: perms)
            let keyVal = result["key"] as? String ?? ""
            toastManager.show(style: .success, title: "Key Created", message: keyVal.isEmpty ? newName : "Copy key: \(keyVal.prefix(12))...")
            showCreateSheet = false
            newName = ""; newPermissions = "read,execute"
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func revokeKey(_ id: String, name: String) async {
        do {
            _ = try await bridge.apikeyRevoke(keyId: id)
            toastManager.show(style: .info, title: "Revoked", message: name)
        } catch {
            toastManager.show(style: .error, title: "Revoke Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - StyleTabView

struct StyleTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newTemplate = "default"
    @State private var newRules = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Styles")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Add Style", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.styles.isEmpty {
                Spacer()
                Text("No custom styles")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.styles.enumerated()), id: \.offset) { idx, style in
                        let name = style["name"] as? String ?? "Unknown"
                        let template = style["template"] as? String ?? ""
                        let sid = style["style_id"] as? String ?? style["id"] as? String ?? ""
                        StudioRow(label: name, sublabel: template, isLast: idx == bridge.styles.count - 1) {
                            FusionTag("style", color: .purple)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await deleteStyle(sid, name: name) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchStyles() } }
        .sheet(isPresented: $showCreateSheet) {
            createStyleSheet
        }
    }

    private var createStyleSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New Style")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Template (default, formal, casual...)", text: $newTemplate)
                .textFieldStyle(.roundedBorder)
            TextField("Rules (JSON)", text: $newRules, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createStyle() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createStyle() async {
        guard !newName.isEmpty else { return }
        var rules: [String: Any] = [:]
        if let data = newRules.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            rules = json
        }
        do {
            _ = try await bridge.styleCreate(name: newName, template: newTemplate, rules: rules)
            toastManager.show(style: .success, title: "Created", message: newName)
            showCreateSheet = false
            newName = ""; newRules = ""
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func deleteStyle(_ id: String, name: String) async {
        do {
            _ = try await bridge.styleDelete(styleId: id)
            toastManager.show(style: .info, title: "Deleted", message: name)
        } catch {
            toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - DashboardTabView

struct DashboardTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    private let dashboardLog = Logger(subsystem: "com.fusion.studio", category: "Dashboard")

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                StudioSectionHeader(title: "Overview")
                dashboardCards
                StudioSectionHeader(title: "Agent Status Breakdown")
                agentStatusList
                Spacer()
            }
            .padding(theme.spacingL)
        }
        .onAppear {
            Task { await bridge.fetchDashboard() }
        }
    }

    private var dashboardCards: some View {
        let d = bridge.dashboardData
        let cards: [(String, String, String, Color)] = [
            ("Total Agents", "\(d["total_agents"] as? Int ?? bridge.agents.count)", "person.2", .blue),
            ("Published", "\(d["published_agents"] as? Int ?? bridge.agents.filter { $0.status == "published" }.count)", "arrow.up.circle", .green),
            ("Active", "\(d["active_agents"] as? Int ?? 0)", "bolt", .orange),
            ("Today Requests", "\(d["today_requests"] as? Int ?? 0)", "text.bubble", .purple),
            ("Total Tokens", "\(d["total_tokens"] as? Int ?? 0)", "number", .cyan),
            ("Errors", "\(d["error_count"] as? Int ?? 0)", "exclamationmark.triangle", .red),
        ]
        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
        ], spacing: theme.spacingM) {
            ForEach(cards, id: \.0) { card in
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Image(systemName: card.2)
                            .foregroundStyle(card.3)
                        Spacer()
                        Text(card.0)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Text(card.1)
                        .font(.system(size: theme.titleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text)
                }
                .padding(theme.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .fill(theme.surfaceSecondary)
                )
            }
        }
    }

    private var agentStatusList: some View {
        VStack(spacing: 0) {
            let draft = bridge.agents.filter { $0.status == "draft" || $0.status == nil }
            let published = bridge.agents.filter { $0.status == "published" }
            let archived = bridge.agents.filter { $0.status == "archived" }
            statusRow(label: "Draft", count: draft.count, color: .gray)
            statusRow(label: "Published", count: published.count, color: .green)
            statusRow(label: "Archived", count: archived.count, color: .orange)
        }
    }

    private func statusRow(label: String, count: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
            Spacer()
            Text("\(count)")
                .font(.system(size: theme.textSize, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.text)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
        .background(theme.surfaceSecondary)
    }
}

// MARK: - MarketplaceTabView

struct MarketplaceTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @State private var searchText = ""
    @State private var selectedCategory = ""
    @State private var entries: [MarketplaceEntryModel] = []
    @State private var categories: [String] = []
    @State private var showPublish = false
    @State private var publishName = ""
    @State private var publishAuthor = ""
    @State private var publishDesc = ""
    @State private var publishCategory = ""
    @State private var publishTags = ""
    @State private var publishVersion = "1.0.0"
    @State private var publishGraphId = ""

    @Environment(\.studioTheme) var theme

    var body: some View {
        GeometryReader { geo in
            HSplitView {
                marketplaceSidebar
                    .frame(minWidth: 200, idealWidth: max(200, geo.size.width * 0.2), maxWidth: 360)

                marketplaceDetail
                    .frame(minWidth: 400, idealWidth: geo.size.width * 0.8)
            }
        }
        .onAppear {
            loadMarketplace()
        }
    }

    private var marketplaceSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StudioSectionHeader(title: "Marketplace")

                HStack(spacing: theme.spacingS) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(theme.textTertiary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { searchMarketplace() }
                }
                .padding(theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.bottom, theme.spacingS)

                if !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: theme.spacingXS) {
                            FusionTag("All", color: selectedCategory.isEmpty ? .blue : .gray)
                                .onTapGesture { selectedCategory = ""; searchMarketplace() }
                            ForEach(categories, id: \.self) { cat in
                                FusionTag(cat, color: selectedCategory == cat ? .blue : .gray)
                                    .onTapGesture { selectedCategory = cat; searchMarketplace() }
                            }
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.bottom, theme.spacingS)
                }

                if entries.isEmpty {
                    VStack(spacing: theme.spacingM) {
                        Image(systemName: "bag")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.textTertiary)
                        Text("No marketplace entries")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(.vertical, theme.spacing2XL)
                } else {
                    ListGroup {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            MarketplaceEntryRow(entry: entry, isLast: index == entries.count - 1)
                        }
                    }
                }

                HStack {
                    Spacer()
                    FusionButton("Publish", icon: "arrow.up.doc", style: .primary, size: .small) {
                        showPublish = true
                    }
                }
                .padding(theme.spacingM)
            }
        }
        .sheet(isPresented: $showPublish) {
            publishSheet
        }
    }

    private var marketplaceDetail: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "bag")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)
            Text("Select an entry or publish your work")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var publishSheet: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                Text("Publish to Marketplace")
                    .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)

                formField("Name *", text: $publishName)
                formField("Author", text: $publishAuthor)
                formField("Description", text: $publishDesc)
                formField("Category", text: $publishCategory)
                formField("Tags (comma separated)", text: $publishTags)
                formField("Version", text: $publishVersion)
                formField("Graph ID", text: $publishGraphId)

                HStack(spacing: theme.spacingM) {
                    FusionButton("Cancel", icon: "xmark", style: .secondary, size: .regular) {
                        showPublish = false
                    }
                    FusionButton("Publish", icon: "arrow.up.doc", style: .primary, size: .regular, isDisabled: publishName.isEmpty) {
                        publishToMarketplace()
                    }
                }
            }
            .padding(theme.spacingXL)
        }
        .frame(width: 500, height: 500)
        .background(theme.windowBg)
    }

    private func formField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(label)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            TextField(label, text: text)
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

    private func loadMarketplace() {
        Task {
            do {
                categories = try await bridge.fetchMarketplaceCategories()
                entries = try await bridge.marketplaceSearch(query: "", category: "", tags: [])
            } catch {
                agentStudioLog.warning("Marketplace load failed: \(error)")
            }
        }
    }

    private func searchMarketplace() {
        Task {
            do {
                entries = try await bridge.marketplaceSearch(query: searchText, category: selectedCategory, tags: [])
            } catch {
                toastManager.show(style: .error, title: "Search Failed", message: error.localizedDescription)
            }
        }
    }

    private func publishToMarketplace() {
        Task {
            do {
                let graphData: [String: Any] = publishGraphId.isEmpty ? [:] : ["graph_id": publishGraphId]
                let _ = try await bridge.marketplacePublish(
                    name: publishName,
                    author: publishAuthor,
                    description: publishDesc,
                    category: publishCategory,
                    tags: publishTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                    version: publishVersion,
                    graphData: graphData
                )
                showPublish = false
                toastManager.show(style: .success, title: "Published", message: "\(publishName) is now on marketplace")
                entries = try await bridge.marketplaceSearch(query: "", category: "", tags: [])
            } catch {
                toastManager.show(style: .error, title: "Publish Failed", message: error.localizedDescription)
            }
        }
    }
}

struct MarketplaceEntryRow: View {
    let entry: MarketplaceEntryModel
    let isLast: Bool
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(entry.name)
                    .font(.system(size: theme.smallTextSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(entry.author)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if !entry.category.isEmpty {
                FusionTag(entry.category, color: .blue)
            }
            FusionButton("Install", icon: "arrow.down.circle", style: .secondary, size: .small) {
                installEntry()
            }
        }
        .padding(.vertical, theme.spacingS)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(theme.rowSep).frame(height: 0.5)
            }
        }
    }

    private func installEntry() {
        Task {
            do {
                let _ = try await bridge.marketplaceInstall(entryId: entry.id)
            } catch {
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
            Spacer()
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
            TextField("Send a message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: theme.textSize))
                .lineLimit(1...6)
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

// MARK: - SoulEditorSheet

struct SoulEditorSheet: View {
    @Binding var soulContent: String
    let onSave: () -> Void
    let toastManager: FusionToastManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Edit Soul")
                .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text)

            TextEditor(text: $soulContent)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .padding(theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                }
                .frame(minHeight: 200)

            HStack(spacing: theme.spacingM) {
                FusionButton("Cancel", icon: "xmark", style: .secondary, size: .regular) {
                    dismiss()
                }
                FusionButton("Save", icon: "checkmark", style: .primary, size: .regular) {
                    onSave()
                }
            }
        }
        .padding(theme.spacingXL)
        .frame(width: 500, height: 400)
        .background(theme.windowBg)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private struct LayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var result = LayoutResult()
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            result.positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        result.size = CGSize(width: maxWidth, height: currentY + rowHeight)
        return result
    }
}
