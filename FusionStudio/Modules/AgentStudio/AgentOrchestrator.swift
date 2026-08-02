import SwiftUI
import Combine
import os.log

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
