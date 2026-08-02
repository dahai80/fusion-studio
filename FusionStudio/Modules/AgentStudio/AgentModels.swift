import SwiftUI
import Combine
import os.log

let agentStudioLog = Logger(subsystem: "com.fusion.studio", category: "AgentStudioView")

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
