import Foundation

// M2: TeamWorkspace domain models. team state lives in daemon (SQLite), GUI caches render only.
// TeamTask/TeamMember/PlazaMessage mapped manually from RPC [String:Any] dicts (not Codable —
// lastResult carries arbitrary JSON). TeamEvent is Codable (decoded from WS JSON frames).

// MARK: - KanbanColumn

enum KanbanColumn: String, CaseIterable {
    case todo
    case inProgress = "in_progress"
    case review
    case approved
    case archived

    var displayName: String {
        switch self {
        case .todo: return "Todo"
        case .inProgress: return "In Progress"
        case .review: return "Review"
        case .approved: return "Approved"
        case .archived: return "Archived"
        }
    }
}

// MARK: - TeamTask

struct TeamTask: Identifiable {
    let id: String
    let title: String
    let status: String
    let reviewState: String
    let ownerAgent: String
    let priority: Int
    let team: String
    let graphId: String
    let evidenceRef: String
    let resourceLeaseId: String
    let createdAt: Double
    let updatedAt: Double

    init(id: String, title: String, status: String, reviewState: String,
         ownerAgent: String, priority: Int, team: String, graphId: String,
         evidenceRef: String, resourceLeaseId: String,
         createdAt: Double, updatedAt: Double) {
        self.id = id
        self.title = title
        self.status = status
        self.reviewState = reviewState
        self.ownerAgent = ownerAgent
        self.priority = priority
        self.team = team
        self.graphId = graphId
        self.evidenceRef = evidenceRef
        self.resourceLeaseId = resourceLeaseId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(dict: [String: Any]) {
        guard let taskId = (dict["task_id"] as? String) ?? (dict["id"] as? String) else { return nil }
        self.id = taskId
        self.title = (dict["title"] as? String) ?? ""
        self.status = (dict["status"] as? String) ?? "pending"
        self.reviewState = (dict["review_state"] as? String) ?? "none"
        self.ownerAgent = (dict["owner_agent"] as? String) ?? ""
        self.priority = (dict["priority"] as? Int) ?? 1
        self.team = (dict["team"] as? String) ?? "default"
        self.graphId = (dict["graph_id"] as? String) ?? ""
        self.evidenceRef = (dict["evidence_ref"] as? String) ?? ""
        self.resourceLeaseId = (dict["resource_lease_id"] as? String) ?? ""
        self.createdAt = (dict["created_at"] as? Double) ?? 0
        self.updatedAt = (dict["updated_at"] as? Double) ?? 0
    }

    var hasEvidence: Bool { !evidenceRef.isEmpty }
    var hasLease: Bool { !resourceLeaseId.isEmpty }

    // Swift mirror of daemon task_board.py:derive_column. Single rule, two implementations.
    // M2-7 contract test target — feed same inputs, assert same column.
    func deriveColumn() -> KanbanColumn {
        if status == "canceled" { return .archived }
        if status == "pending" && ownerAgent.isEmpty { return .todo }
        if status == "running" { return .inProgress }
        if status == "completed" && (reviewState == "review" || reviewState == "needs_fix") { return .review }
        if status == "completed" && reviewState == "approved" { return .approved }
        return .todo
    }
}

// MARK: - TeamMember

struct TeamMember: Identifiable {
    let id: String
    let name: String
    let capabilities: [String]
    let currentTask: String?
    let leaseStatus: String?

    init(id: String, name: String, capabilities: [String],
         currentTask: String?, leaseStatus: String?) {
        self.id = id
        self.name = name
        self.capabilities = capabilities
        self.currentTask = currentTask
        self.leaseStatus = leaseStatus
    }

    init?(dict: [String: Any]) {
        guard let agentId = (dict["agent_id"] as? String) ?? (dict["id"] as? String) else { return nil }
        self.id = agentId
        self.name = (dict["name"] as? String) ?? agentId
        let caps = (dict["capabilities"] as? [String]) ?? (dict["skills"] as? [String]) ?? []
        self.capabilities = caps
        self.currentTask = (dict["current_task"] as? String) ?? (dict["current_task_id"] as? String)
        self.leaseStatus = (dict["lease_status"] as? String) ?? (dict["status"] as? String)
    }
}

// MARK: - PlazaMessage

struct PlazaMessage: Identifiable {
    let id: String
    let channel: String
    let sender: String
    let content: String
    let ts: Double

    init(id: String, channel: String, sender: String, content: String, ts: Double) {
        self.id = id
        self.channel = channel
        self.sender = sender
        self.content = content
        self.ts = ts
    }

    init?(dict: [String: Any]) {
        guard let msgId = (dict["message_id"] as? String) ?? (dict["id"] as? String) ?? (dict["hash"] as? String) else { return nil }
        self.id = msgId
        self.channel = (dict["channel"] as? String) ?? ""
        self.sender = (dict["sender"] as? String) ?? (dict["sender_id"] as? String) ?? ""
        self.content = (dict["content"] as? String) ?? (dict["message"] as? String) ?? ""
        self.ts = (dict["ts"] as? Double) ?? (dict["timestamp"] as? Double) ?? 0
    }
}

// MARK: - TeamBudget

struct TeamBudget {
    let maxTokens: Int
    let spentTokens: Int
    let remaining: Int
    let exceeded: Bool
    let estimatedCost: Double

    init(maxTokens: Int, spentTokens: Int, remaining: Int,
         exceeded: Bool, estimatedCost: Double) {
        self.maxTokens = maxTokens
        self.spentTokens = spentTokens
        self.remaining = remaining
        self.exceeded = exceeded
        self.estimatedCost = estimatedCost
    }

    init?(dict: [String: Any]) {
        let mx = (dict["max_tokens"] as? Int) ?? (dict["budget"] as? Int) ?? 0
        let spent = (dict["spent_tokens"] as? Int) ?? (dict["used"] as? Int) ?? 0
        self.maxTokens = mx
        self.spentTokens = spent
        self.remaining = mx - spent
        self.exceeded = spent >= mx
        self.estimatedCost = (dict["estimated_cost"] as? Double) ?? 0
    }
}

// MARK: - TeamHealth

struct TeamHealth {
    let pendingTasks: Int
    let runningTasks: Int
    let totalTasks: Int
    let maxConcurrency: Int

    init(pendingTasks: Int, runningTasks: Int, totalTasks: Int, maxConcurrency: Int) {
        self.pendingTasks = pendingTasks
        self.runningTasks = runningTasks
        self.totalTasks = totalTasks
        self.maxConcurrency = maxConcurrency
    }

    init?(dict: [String: Any]) {
        self.pendingTasks = (dict["pending"] as? Int) ?? (dict["pending_tasks"] as? Int) ?? 0
        self.runningTasks = (dict["running"] as? Int) ?? (dict["running_tasks"] as? Int) ?? 0
        self.totalTasks = (dict["total"] as? Int) ?? (dict["total_tasks"] as? Int) ?? 0
        self.maxConcurrency = (dict["max_concurrency"] as? Int) ?? 4
    }
}

// MARK: - TeamEvidence (M2-5, upstream #316 evidence.list/evidence.failure)

struct TeamEvidence: Identifiable {
    let id: String
    let taskId: String
    let team: String
    let evidenceRef: String
    let status: String
    let executionId: String
    let eventsCount: Int
    let createdAt: Double

    init(id: String, taskId: String, team: String, evidenceRef: String,
         status: String, executionId: String, eventsCount: Int, createdAt: Double) {
        self.id = id
        self.taskId = taskId
        self.team = team
        self.evidenceRef = evidenceRef
        self.status = status
        self.executionId = executionId
        self.eventsCount = eventsCount
        self.createdAt = createdAt
    }

    init?(dict: [String: Any]) {
        let tid = (dict["task_id"] as? String) ?? ""
        guard !tid.isEmpty else { return nil }
        self.id = tid
        self.taskId = tid
        self.team = (dict["team"] as? String) ?? "default"
        self.evidenceRef = (dict["evidence_ref"] as? String) ?? ""
        self.status = (dict["status"] as? String) ?? ""
        self.executionId = (dict["execution_id"] as? String) ?? ""
        self.eventsCount = (dict["events_count"] as? Int) ?? 0
        self.createdAt = (dict["created_at"] as? Double) ?? 0
    }

    var isFailed: Bool { status == "failed" || status == "canceled" }
}

// MARK: - TeamEvent (Codable — decoded from WS JSON frames)

struct TeamEvent: Identifiable, Codable {
    let id: Int
    let type: String
    let ts: Double
    let team: String
    let taskId: String?
    let executionId: String?
    let eventsCount: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id = "event_id"
        case type
        case ts
        case team
        case taskId = "task_id"
        case executionId = "execution_id"
        case eventsCount = "events_count"
        case error
    }

    // event types from M1-6 team.events WS channel + #319 new events
    static let taskCreated = "task.created"
    static let executionProgress = "execution.progress"
    static let executionCompleted = "execution.completed"
    static let executionCancelled = "execution.cancelled"
    static let executionFailed = "execution.failed"
    static let subscribed = "subscribed"
    // #319 merged: new event types
    static let reviewRequested = "review.requested"
    static let resourceLeaseGranted = "resource.lease_granted"
    static let resourceLeaseExpired = "resource.lease_expired"

    var triggersTaskRefresh: Bool {
        switch type {
        case TeamEvent.taskCreated, TeamEvent.executionCompleted,
             TeamEvent.executionCancelled, TeamEvent.executionFailed,
             TeamEvent.reviewRequested:
            return true
        default:
            return false
        }
    }
}
