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

struct TaskModel: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var agentId: String
    var graphId: String
    var trigger: TaskTrigger
    var cronExpression: String
    var runAt: Date?
    var cronJobId: String
    var input: String
    var status: TaskStatus
    var priority: AgentTask.TaskPriority
    var sessionId: String
    var artifactIds: [String]
    var lastResult: String
    var lastError: String
    var retryCount: Int
    var maxRetries: Int
    var createdAt: Date
    var updatedAt: Date
    var lastRunAt: Date?
    var events: [AgentEventModel]

    enum TaskTrigger: String, CaseIterable, Identifiable {
        case immediate = "Immediate"
        case cron = "Schedule"
        case runAt = "Once"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .immediate: return "play.fill"
            case .cron:      return "clock.arrow.2.circlepath"
            case .runAt:     return "calendar.badge.clock"
            }
        }
    }

    enum TaskStatus: String, Codable {
        case pending    = "Pending"
        case queued     = "Queued"
        case scheduled  = "Scheduled"
        case running    = "Running"
        case completed  = "Completed"
        case failed     = "Failed"
        case cancelled  = "Cancelled"

        var pillStatus: StatusPill.Status {
            switch self {
            case .pending:    return .stopped
            case .queued:     return .starting
            case .scheduled:  return .custom(color: .orange, label: "Scheduled")
            case .running:    return .running
            case .completed:  return .custom(color: Color(red: 0, green: 122.0 / 255.0, blue: 1.0), label: "Done")
            case .failed:     return .error
            case .cancelled:  return .stopped
            }
        }

        var isTerminal: Bool { self == .completed || self == .failed || self == .cancelled }

        // 后端 snake_case status → 前端. 后端 5 态: pending/running/completed/failed/canceled ( canceled 单 d ).
        static func fromBackend(_ raw: String) -> TaskStatus {
            switch raw.lowercased() {
            case "running":   return .running
            case "completed": return .completed
            case "failed":    return .failed
            case "canceled", "cancelled": return .cancelled
            case "scheduled": return .scheduled
            case "queued":    return .queued
            default:          return .pending
            }
        }
    }

    // 后端 trigger: immediate/cron/run_at → 前端 TaskTrigger
    static func triggerFromBackend(_ raw: String) -> TaskTrigger {
        switch raw.lowercased() {
        case "cron":   return .cron
        case "run_at": return .runAt
        default:       return .immediate
        }
    }

    static func priorityFromBackend(_ value: Any?) -> AgentTask.TaskPriority {
        let idx: Int = {
            if let i = value as? Int { return i }
            if let s = value as? String, let i = Int(s) { return i }
            if let d = value as? Double { return Int(d) }
            return 1
        }()
        switch idx {
        case 0:  return .low
        case 2:  return .high
        case 3:  return .critical
        default: return .medium
        }
    }

    var priorityInt: Int {
        switch priority {
        case .low:      return 0
        case .medium:   return 1
        case .high:     return 2
        case .critical: return 3
        }
    }

    var triggerBackend: String {
        switch trigger {
        case .immediate: return "immediate"
        case .cron:      return "cron"
        case .runAt:     return "run_at"
        }
    }

    // 后端 to_dict (snake_case, 时间为 epoch float, 0 = nil) → TaskModel
    init?(backendDict d: [String: Any]) {
        guard let id = d["task_id"] as? String, !id.isEmpty else { return nil }
        func date(_ key: String) -> Date? {
            let v = d[key]
            if let f = v as? Double, f > 0 { return Date(timeIntervalSince1970: f) }
            if let i = v as? Int, i > 0 { return Date(timeIntervalSince1970: TimeInterval(i)) }
            if let s = v as? String, let f = Double(s), f > 0 { return Date(timeIntervalSince1970: f) }
            return nil
        }
        self.id = id
        self.title = d["title"] as? String ?? ""
        self.description = d["description"] as? String ?? ""
        self.agentId = d["agent_id"] as? String ?? ""
        self.graphId = d["graph_id"] as? String ?? ""
        self.trigger = TaskModel.triggerFromBackend(d["trigger"] as? String ?? "immediate")
        self.cronExpression = d["cron_expression"] as? String ?? ""
        self.runAt = date("run_at")
        self.cronJobId = d["cron_job_id"] as? String ?? ""
        self.input = d["input"] as? String ?? ""
        self.status = TaskStatus.fromBackend(d["status"] as? String ?? "pending")
        self.priority = TaskModel.priorityFromBackend(d["priority"])
        self.sessionId = d["session_id"] as? String ?? ""
        if let arr = d["artifact_ids"] as? [String] {
            self.artifactIds = arr
        } else if let arr = d["artifact_ids"] as? [Any] {
            self.artifactIds = arr.compactMap { $0 as? String }
        } else {
            self.artifactIds = []
        }
        if let res = d["last_result"] as? [String: Any], !res.isEmpty {
            if let data = try? JSONSerialization.data(withJSONObject: res),
               let str = String(data: data, encoding: .utf8) {
                self.lastResult = str
            } else {
                self.lastResult = ""
            }
        } else if let s = d["last_result"] as? String {
            self.lastResult = s
        } else {
            self.lastResult = ""
        }
        self.lastError = d["last_error"] as? String ?? ""
        self.retryCount = d["retry_count"] as? Int ?? 0
        self.maxRetries = d["max_retries"] as? Int ?? 3
        self.createdAt = date("created_at") ?? Date()
        self.updatedAt = date("updated_at") ?? Date()
        self.lastRunAt = date("last_run_at")
        self.events = []
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: TaskModel, rhs: TaskModel) -> Bool { lhs.id == rhs.id }
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
