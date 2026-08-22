// Callers: TeamCollabView + area views (TeamCollabAreas.swift) read these models and TeamCollabStore.
// Affected API: OrchestrationPattern(6 cases aligned with MultiAgentOrchestrator), IndependentRouter(3 types),
//   TeamCollabStore.activePattern/activeRouter.
// Data schemas: mirrors fusion-agent-studio orchestrator.py(6 patterns), swarm_router.py, plaza.py, fmp_router.py.
// User instruction: "Issue #8 team-collab 映射修正：区分 MultiAgentOrchestrator 6 模式与 SwarmRouter/Plaza/FMProtocol 独立 router"

import SwiftUI
import os.log

private let teamLog = Logger(subsystem: "com.fusion.studio", category: "TeamCollab")

enum AgentStatus: String, CaseIterable, Identifiable {
    case online = "online"
    case busy = "busy"
    case tripped = "tripped"
    case offline = "offline"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .online: return I18nManager.shared.t(.tc_status_online)
        case .busy: return I18nManager.shared.t(.tc_status_busy)
        case .tripped: return I18nManager.shared.t(.tc_status_tripped)
        case .offline: return I18nManager.shared.t(.tc_status_offline)
        }
    }

    var dot: Color {
        switch self {
        case .online: return .green
        case .busy: return .orange
        case .tripped: return .red
        case .offline: return .gray
        }
    }
}

enum DelegationStatus: String, CaseIterable, Identifiable {
    case pending = "pending"
    case running = "running"
    case done = "done"
    case failed = "failed"
    case escalated = "escalated"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return I18nManager.shared.t(.tc_del_pending)
        case .running: return I18nManager.shared.t(.tc_del_running)
        case .done: return I18nManager.shared.t(.tc_del_done)
        case .failed: return I18nManager.shared.t(.tc_del_failed)
        case .escalated: return I18nManager.shared.t(.tc_del_escalated)
        }
    }
}

struct SwarmAgent: Identifiable, Hashable {
    let id: String
    let name: String
    let role: String
    let model: String
    let identityColor: Color
    let capabilities: [String]
    let handoffTargets: [String]
    let maxHops: Int
    var status: AgentStatus
    var tasksDone: Int
    var tasksActive: Int
    var circuit: CircuitBreakerState

    static func == (lhs: SwarmAgent, rhs: SwarmAgent) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var roleLabel: String {
        switch role {
        case "planner": return I18nManager.shared.t(.tc_role_planner)
        case "coder": return I18nManager.shared.t(.tc_role_coder)
        case "reviewer": return I18nManager.shared.t(.tc_role_reviewer)
        case "writer": return I18nManager.shared.t(.tc_role_writer)
        case "executor": return I18nManager.shared.t(.tc_role_executor)
        case "researcher": return I18nManager.shared.t(.tc_role_researcher)
        default: return role
        }
    }
}

struct CircuitBreakerState: Hashable {
    var threshold: Int
    var failures: Int
    var isOpen: Bool
    var resetInSeconds: Double

    var progress: Double {
        guard threshold > 0 else { return 0 }
        return Double(failures) / Double(threshold)
    }
}

struct TaskDelegation: Identifiable, Hashable {
    let id: String
    let task: String
    let delegator: String
    let delegatee: String
    let triggerCondition: String
    let deliverable: String
    var status: DelegationStatus
    var hopCount: Int
    let createdAt: String
    var result: String

    static func == (lhs: TaskDelegation, rhs: TaskDelegation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct HandoffRecord: Identifiable, Hashable {
    let id: String
    let fromAgent: String
    let toAgent: String
    let taskId: String
    let hopCount: Int
    let summary: String
    let timestamp: String

    static func == (lhs: HandoffRecord, rhs: HandoffRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct PlazaMessage: Identifiable, Hashable {
    let id: String
    let sender: String
    let content: String
    let mentions: [String]
    let round: Int
    let timestamp: String

    static func == (lhs: PlazaMessage, rhs: PlazaMessage) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct PlazaChannel: Identifiable, Hashable {
    let id: String
    let name: String
    let participants: [String]
    var isSuspended: Bool
    var currentRound: Int
    let maxRounds: Int
    var messages: [PlazaMessage]

    static func == (lhs: PlazaChannel, rhs: PlazaChannel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct FMStats: Hashable {
    var sent: Int
    var received: Int
    var droppedDedup: Int
    var circuitBlocked: Int
    var routed: Int
    var maxRounds: Int
}

// MARK: - OrchestrationPattern (6 cases aligned with MultiAgentOrchestrator)
// Backend: team.orchestrate(pattern=..., agents=[...])
// Issue #8: add sequential/parallel, remove swarm/plaza (they are independent routers)

enum OrchestrationPattern: String, CaseIterable, Identifiable {
    case sequential = "sequential"
    case parallel = "parallel"
    case masterWorker = "master_worker"
    case handoff = "handoff"
    case broadcast = "broadcast"
    case supervisor = "supervisor"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sequential: return I18nManager.shared.t(.tc_pat_sequential)
        case .parallel: return I18nManager.shared.t(.tc_pat_parallel)
        case .masterWorker: return I18nManager.shared.t(.tc_pat_master_worker)
        case .handoff: return I18nManager.shared.t(.tc_pat_handoff)
        case .broadcast: return I18nManager.shared.t(.tc_pat_broadcast)
        case .supervisor: return I18nManager.shared.t(.tc_pat_supervisor)
        }
    }

    var icon: String {
        switch self {
        case .sequential: return "list.number"
        case .parallel: return "square.split.2x2"
        case .masterWorker: return "rectangle.split.3x1"
        case .handoff: return "arrow.right.arrow.left"
        case .broadcast: return "antenna.radiowaves.left.and.right"
        case .supervisor: return "shield.lefthalf.filled"
        }
    }

    var desc: String {
        switch self {
        case .sequential: return I18nManager.shared.t(.tc_pat_desc_sequential)
        case .parallel: return I18nManager.shared.t(.tc_pat_desc_parallel)
        case .masterWorker: return I18nManager.shared.t(.tc_pat_desc_master_worker)
        case .handoff: return I18nManager.shared.t(.tc_pat_desc_handoff)
        case .broadcast: return I18nManager.shared.t(.tc_pat_desc_broadcast)
        case .supervisor: return I18nManager.shared.t(.tc_pat_desc_supervisor)
        }
    }
}

// MARK: - IndependentRouter (SwarmRouter / Plaza / FMProtocol)
// Issue #8: separate from OrchestrationPattern — these are independent routers with their own endpoints

enum IndependentRouter: String, CaseIterable, Identifiable {
    case swarm = "swarm"
    case plaza = "plaza"
    case fmp = "fmp"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .swarm: return I18nManager.shared.t(.tc_router_swarm)
        case .plaza: return I18nManager.shared.t(.tc_router_plaza)
        case .fmp: return I18nManager.shared.t(.tc_router_fmp)
        }
    }

    var icon: String {
        switch self {
        case .swarm: return "circle.hexagonpath"
        case .plaza: return "bubble.left.and.bubble.right"
        case .fmp: return "antenna.radiowaves.left.and.right"
        }
    }

    var desc: String {
        switch self {
        case .swarm: return I18nManager.shared.t(.tc_router_desc_swarm)
        case .plaza: return I18nManager.shared.t(.tc_router_desc_plaza)
        case .fmp: return I18nManager.shared.t(.tc_router_desc_fmp)
        }
    }
}

struct SubGraphInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let nodeCount: Int
    let edgeCount: Int
    let entryNode: String
    var status: String
    let lastRun: String

    static func == (lhs: SubGraphInfo, rhs: SubGraphInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

final class TeamCollabStore: ObservableObject {
    @Published var agents: [SwarmAgent]
    @Published var delegations: [TaskDelegation]
    @Published var handoffs: [HandoffRecord]
    @Published var channels: [PlazaChannel]
    @Published var fmStats: FMStats
    @Published var subGraphs: [SubGraphInfo]
    @Published var activePattern: OrchestrationPattern = .sequential
    @Published var activeRouter: IndependentRouter = .swarm

    init() {
        let cb = CircuitBreakerState(threshold: 3, failures: 3, isOpen: true, resetInSeconds: 30)
        self.agents = [
            SwarmAgent(id: "p1a2b3c4", name: "Planner", role: "planner", model: "qwen2.5-7b",
                       identityColor: .blue, capabilities: ["plan", "decompose", "route"],
                       handoffTargets: ["c0d3a1b2", "r5e6f7a8"], maxHops: 3, status: .online,
                       tasksDone: 42, tasksActive: 2,
                       circuit: CircuitBreakerState(threshold: 3, failures: 0, isOpen: false, resetInSeconds: 30)),
            SwarmAgent(id: "c0d3a1b2", name: "Coder", role: "coder", model: "qwen2.5-7b",
                       identityColor: .orange, capabilities: ["code", "debug", "test"],
                       handoffTargets: ["r5e6f7a8", "e3f4a5b6"], maxHops: 3, status: .tripped,
                       tasksDone: 118, tasksActive: 0, circuit: cb),
            SwarmAgent(id: "r5e6f7a8", name: "Reviewer", role: "reviewer", model: "qwen2.5-7b",
                       identityColor: .green, capabilities: ["review", "lint", "approve"],
                       handoffTargets: ["w9b0c1d2", "c0d3a1b2"], maxHops: 3, status: .busy,
                       tasksDone: 87, tasksActive: 1,
                       circuit: CircuitBreakerState(threshold: 3, failures: 1, isOpen: false, resetInSeconds: 30)),
            SwarmAgent(id: "w9b0c1d2", name: "Writer", role: "writer", model: "qwen2.5-7b",
                       identityColor: .purple, capabilities: ["write", "summarize", "translate"],
                       handoffTargets: ["e3f4a5b6"], maxHops: 3, status: .online,
                       tasksDone: 65, tasksActive: 0,
                       circuit: CircuitBreakerState(threshold: 3, failures: 0, isOpen: false, resetInSeconds: 30)),
            SwarmAgent(id: "e3f4a5b6", name: "Executor", role: "executor", model: "qwen2.5-7b",
                       identityColor: .teal, capabilities: ["execute", "deploy", "verify"],
                       handoffTargets: ["p1a2b3c4"], maxHops: 3, status: .online,
                       tasksDone: 203, tasksActive: 3,
                       circuit: CircuitBreakerState(threshold: 3, failures: 0, isOpen: false, resetInSeconds: 30)),
            SwarmAgent(id: "s7c8d9e0", name: "Researcher", role: "researcher", model: "qwen2.5-7b",
                       identityColor: .pink, capabilities: ["search", "fetch", "analyze"],
                       handoffTargets: ["p1a2b3c4", "w9b0c1d2"], maxHops: 3, status: .offline,
                       tasksDone: 34, tasksActive: 0,
                       circuit: CircuitBreakerState(threshold: 3, failures: 0, isOpen: false, resetInSeconds: 30))
        ]

        self.delegations = [
            TaskDelegation(id: "d-001", task: I18nManager.shared.t(.tc_seed_task1), delegator: "Planner", delegatee: "Coder",
                           triggerCondition: "capability=code", deliverable: I18nManager.shared.t(.tc_seed_deliverable1), status: .done,
                           hopCount: 1, createdAt: "09:12", result: "+412 / -58"),
            TaskDelegation(id: "d-002", task: I18nManager.shared.t(.tc_seed_task2), delegator: "Coder", delegatee: "Reviewer",
                           triggerCondition: "handoff_target", deliverable: I18nManager.shared.t(.tc_seed_deliverable2), status: .running,
                           hopCount: 2, createdAt: "09:24", result: ""),
            TaskDelegation(id: "d-003", task: I18nManager.shared.t(.tc_seed_task3), delegator: "Reviewer", delegatee: "Coder",
                           triggerCondition: "capability=deploy", deliverable: I18nManager.shared.t(.tc_seed_deliverable3), status: .escalated,
                           hopCount: 3, createdAt: "09:31", result: I18nManager.shared.t(.tc_seed_result1)),
            TaskDelegation(id: "d-004", task: I18nManager.shared.t(.tc_seed_task4), delegator: "Planner", delegatee: "Writer",
                           triggerCondition: "capability=write", deliverable: "markdown", status: .pending,
                           hopCount: 1, createdAt: "09:40", result: "")
        ]

        self.handoffs = [
            HandoffRecord(id: "h-1", fromAgent: "Planner", toAgent: "Coder", taskId: "d-001",
                          hopCount: 1, summary: I18nManager.shared.t(.tc_seed_handoff1), timestamp: "09:12"),
            HandoffRecord(id: "h-2", fromAgent: "Coder", toAgent: "Reviewer", taskId: "d-002",
                          hopCount: 2, summary: I18nManager.shared.t(.tc_seed_handoff2), timestamp: "09:24"),
            HandoffRecord(id: "h-3", fromAgent: "Reviewer", toAgent: "Coder", taskId: "d-003",
                          hopCount: 3, summary: I18nManager.shared.t(.tc_seed_handoff3), timestamp: "09:31")
        ]

        let msgs: [PlazaMessage] = [
            PlazaMessage(id: "m-1", sender: "Planner", content: I18nManager.shared.t(.tc_seed_msg1), mentions: ["Coder"], round: 1, timestamp: "09:11"),
            PlazaMessage(id: "m-2", sender: "Coder", content: I18nManager.shared.t(.tc_seed_msg2), mentions: ["Reviewer"], round: 1, timestamp: "09:22"),
            PlazaMessage(id: "m-3", sender: "Reviewer", content: I18nManager.shared.t(.tc_seed_msg3), mentions: ["Executor"], round: 2, timestamp: "09:30"),
            PlazaMessage(id: "m-4", sender: "human", content: I18nManager.shared.t(.tc_seed_msg4), mentions: [], round: 2, timestamp: "09:32")
        ]
        self.channels = [
            PlazaChannel(id: "ch-prd77", name: I18nManager.shared.t(.tc_seed_ch_name1), participants: ["Planner", "Coder", "Reviewer", "Writer", "Executor"],
                         isSuspended: false, currentRound: 2, maxRounds: 3, messages: msgs),
            PlazaChannel(id: "ch-research", name: I18nManager.shared.t(.tc_seed_ch_name2), participants: ["Researcher", "Planner", "Writer"],
                         isSuspended: true, currentRound: 3, maxRounds: 3, messages: [
                            PlazaMessage(id: "rm-1", sender: "Researcher", content: I18nManager.shared.t(.tc_seed_msg5), mentions: ["Planner"], round: 3, timestamp: "08:50")
                         ])
        ]

        self.fmStats = FMStats(sent: 184, received: 167, droppedDedup: 9, circuitBlocked: 5, routed: 153, maxRounds: 3)

        self.subGraphs = [
            SubGraphInfo(id: "sg-code-review", name: I18nManager.shared.t(.tc_seed_sub_name1), nodeCount: 5, edgeCount: 6, entryNode: "start", status: "active", lastRun: "09:31"),
            SubGraphInfo(id: "sg-doc-pipeline", name: I18nManager.shared.t(.tc_seed_sub_name2), nodeCount: 4, edgeCount: 3, entryNode: "start", status: "idle", lastRun: I18nManager.shared.t(.tc_seed_lastrun_yesterday)),
            SubGraphInfo(id: "sg-deploy", name: I18nManager.shared.t(.tc_seed_sub_name3), nodeCount: 6, edgeCount: 8, entryNode: "build", status: "draft", lastRun: "-")
        ]

        teamLog.info("TeamCollabStore init: agents=\(self.agents.count) delegations=\(self.delegations.count) channels=\(self.channels.count)")
    }

    func agent(byId id: String) -> SwarmAgent? {
        agents.first { $0.id == id }
    }

    func agentName(byId id: String) -> String {
        agent(byId: id)?.name ?? id
    }

    var onlineCount: Int { agents.filter { $0.status == .online }.count }
    var trippedCount: Int { agents.filter { $0.status == .tripped }.count }
    var offlineCount: Int { agents.filter { $0.status == .offline }.count }
    var runningDelegations: Int { delegations.filter { $0.status == .running }.count }
    var suspendedChannels: Int { channels.filter { $0.isSuspended }.count }
}
