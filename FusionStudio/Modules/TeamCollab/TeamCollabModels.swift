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
        case .online: return "在线"
        case .busy: return "繁忙"
        case .tripped: return "熔断"
        case .offline: return "离线"
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
        case .pending: return "待执行"
        case .running: return "执行中"
        case .done: return "已完成"
        case .failed: return "失败"
        case .escalated: return "已升级"
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
        case .sequential: return "顺序执行"
        case .parallel: return "并行执行"
        case .masterWorker: return "主从分解"
        case .handoff: return "链式交接"
        case .broadcast: return "广播汇聚"
        case .supervisor: return "监督路由"
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
        case .sequential: return "按顺序依次执行,前一步输出作为后一步输入"
        case .parallel: return "所有 Agent 并行执行,结果合并"
        case .masterWorker: return "Master 分解任务 -> Workers 并行 -> 汇总"
        case .handoff: return "Agent 链式传递,携带累积上下文"
        case .broadcast: return "全员并行处理,合并策略(concat/best/json)"
        case .supervisor: return "Supervisor 逐轮路由,JSON 决策 done/__end__"
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
        case .swarm: return "蜂群委派"
        case .plaza: return "广场协商"
        case .fmp: return "FM 协议"
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
        case .swarm: return "按能力/handoff_targets 委派,跳数受控 (team.swarm_*)"
        case .plaza: return "频道广播 + @mention 路由 + 熔断 (team.plaza_*)"
        case .fmp: return "FMProtocol send/receive/route/mention/circuit breaker (team.fmp_*)"
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
            SwarmAgent(id: "p1a2b3c4", name: "Planner", role: "规划", model: "qwen2.5-7b",
                       identityColor: .blue, capabilities: ["plan", "decompose", "route"],
                       handoffTargets: ["c0d3a1b2", "r5e6f7a8"], maxHops: 3, status: .online,
                       tasksDone: 42, tasksActive: 2,
                       circuit: CircuitBreakerState(threshold: 3, failures: 0, isOpen: false, resetInSeconds: 30)),
            SwarmAgent(id: "c0d3a1b2", name: "Coder", role: "编码", model: "qwen2.5-7b",
                       identityColor: .orange, capabilities: ["code", "debug", "test"],
                       handoffTargets: ["r5e6f7a8", "e3f4a5b6"], maxHops: 3, status: .tripped,
                       tasksDone: 118, tasksActive: 0, circuit: cb),
            SwarmAgent(id: "r5e6f7a8", name: "Reviewer", role: "评审", model: "qwen2.5-7b",
                       identityColor: .green, capabilities: ["review", "lint", "approve"],
                       handoffTargets: ["w9b0c1d2", "c0d3a1b2"], maxHops: 3, status: .busy,
                       tasksDone: 87, tasksActive: 1,
                       circuit: CircuitBreakerState(threshold: 3, failures: 1, isOpen: false, resetInSeconds: 30)),
            SwarmAgent(id: "w9b0c1d2", name: "Writer", role: "文档", model: "qwen2.5-7b",
                       identityColor: .purple, capabilities: ["write", "summarize", "translate"],
                       handoffTargets: ["e3f4a5b6"], maxHops: 3, status: .online,
                       tasksDone: 65, tasksActive: 0,
                       circuit: CircuitBreakerState(threshold: 3, failures: 0, isOpen: false, resetInSeconds: 30)),
            SwarmAgent(id: "e3f4a5b6", name: "Executor", role: "执行", model: "qwen2.5-7b",
                       identityColor: .teal, capabilities: ["execute", "deploy", "verify"],
                       handoffTargets: ["p1a2b3c4"], maxHops: 3, status: .online,
                       tasksDone: 203, tasksActive: 3,
                       circuit: CircuitBreakerState(threshold: 3, failures: 0, isOpen: false, resetInSeconds: 30)),
            SwarmAgent(id: "s7c8d9e0", name: "Researcher", role: "调研", model: "qwen2.5-7b",
                       identityColor: .pink, capabilities: ["search", "fetch", "analyze"],
                       handoffTargets: ["p1a2b3c4", "w9b0c1d2"], maxHops: 3, status: .offline,
                       tasksDone: 34, tasksActive: 0,
                       circuit: CircuitBreakerState(threshold: 3, failures: 0, isOpen: false, resetInSeconds: 30))
        ]

        self.delegations = [
            TaskDelegation(id: "d-001", task: "拆解需求 PRD-77", delegator: "Planner", delegatee: "Coder",
                           triggerCondition: "capability=code", deliverable: "实现 diff", status: .done,
                           hopCount: 1, createdAt: "09:12", result: "+412 / -58"),
            TaskDelegation(id: "d-002", task: "评审 auth 模块", delegator: "Coder", delegatee: "Reviewer",
                           triggerCondition: "handoff_target", deliverable: "评审意见", status: .running,
                           hopCount: 2, createdAt: "09:24", result: ""),
            TaskDelegation(id: "d-003", task: "部署到 staging", delegator: "Reviewer", delegatee: "Coder",
                           triggerCondition: "capability=deploy", deliverable: "部署日志", status: .escalated,
                           hopCount: 3, createdAt: "09:31", result: "熔断,已升级至 Planner"),
            TaskDelegation(id: "d-004", task: "生成 API 文档", delegator: "Planner", delegatee: "Writer",
                           triggerCondition: "capability=write", deliverable: "markdown", status: .pending,
                           hopCount: 1, createdAt: "09:40", result: "")
        ]

        self.handoffs = [
            HandoffRecord(id: "h-1", fromAgent: "Planner", toAgent: "Coder", taskId: "d-001",
                          hopCount: 1, summary: "PRD-77 已拆解为 3 子任务", timestamp: "09:12"),
            HandoffRecord(id: "h-2", fromAgent: "Coder", toAgent: "Reviewer", taskId: "d-002",
                          hopCount: 2, summary: "auth 模块实现完成,含测试", timestamp: "09:24"),
            HandoffRecord(id: "h-3", fromAgent: "Reviewer", toAgent: "Coder", taskId: "d-003",
                          hopCount: 3, summary: "评审通过,触发部署", timestamp: "09:31")
        ]

        let msgs: [PlazaMessage] = [
            PlazaMessage(id: "m-1", sender: "Planner", content: "@Coder 开始 PRD-77 编码", mentions: ["Coder"], round: 1, timestamp: "09:11"),
            PlazaMessage(id: "m-2", sender: "Coder", content: "已完成,提交 @Reviewer 评审", mentions: ["Reviewer"], round: 1, timestamp: "09:22"),
            PlazaMessage(id: "m-3", sender: "Reviewer", content: "评审通过,建议部署 @Executor", mentions: ["Executor"], round: 2, timestamp: "09:30"),
            PlazaMessage(id: "m-4", sender: "human", content: "Coder 熔断,暂停该 agent", mentions: [], round: 2, timestamp: "09:32")
        ]
        self.channels = [
            PlazaChannel(id: "ch-prd77", name: "PRD-77 协作", participants: ["Planner", "Coder", "Reviewer", "Writer", "Executor"],
                         isSuspended: false, currentRound: 2, maxRounds: 3, messages: msgs),
            PlazaChannel(id: "ch-research", name: "技术调研", participants: ["Researcher", "Planner", "Writer"],
                         isSuspended: true, currentRound: 3, maxRounds: 3, messages: [
                            PlazaMessage(id: "rm-1", sender: "Researcher", content: "检索到 12 篇相关论文", mentions: ["Planner"], round: 3, timestamp: "08:50")
                         ])
        ]

        self.fmStats = FMStats(sent: 184, received: 167, droppedDedup: 9, circuitBlocked: 5, routed: 153, maxRounds: 3)

        self.subGraphs = [
            SubGraphInfo(id: "sg-code-review", name: "代码评审流", nodeCount: 5, edgeCount: 6, entryNode: "start", status: "active", lastRun: "09:31"),
            SubGraphInfo(id: "sg-doc-pipeline", name: "文档生成流", nodeCount: 4, edgeCount: 3, entryNode: "start", status: "idle", lastRun: "昨日 18:02"),
            SubGraphInfo(id: "sg-deploy", name: "部署流水线", nodeCount: 6, edgeCount: 8, entryNode: "build", status: "draft", lastRun: "-")
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
