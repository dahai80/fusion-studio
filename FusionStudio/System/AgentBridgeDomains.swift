import SwiftUI
import os.log

// F-A1/F-I1: AgentBridge 48 @Published 拆 7 独立 ObservableObject 域类型 (审计 0825 验收 P0,
//   复用 F-A5 PR#315 AppState 拆 4 域已验证模式)。AgentBridge 持 let 域引用, facade 仍是
//   extension AgentBridge 经 self.<state>.X reach-through。SwiftUI 经 body 内 bridge.<state>.X
//   自动追踪域 (let 稳定身份), 每域独立重绘粒度 = 审计根治。0 跨域写确认 → 干净可分阶段。
// 域: RuntimeState / MLXState / AgentState / ModuleState / TaskState / ConfigState / ProjectChatState。

// MARK: - Runtime State (连接 / 执行 / 事件)

@MainActor
final class RuntimeState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isExecuting: Bool = false
    @Published var events: [AgentEventModel] = []
    // ARCH-1 PR2 (#359 facade-delegate): Runtime 行为从 AgentBridge 迁入域。
    //   IPCClient ref 由 AgentBridge.setIPCClient 注入 (健康检查 RPC 方法读 self.ipcClient)。
    //   ipcClient 为 internal (非 private): AgentRuntimeService extension 跨文件访问, Swift private=文件作用域。
    var ipcClient: IPCClient?
    init() {}
}

// MARK: - MLX State (模型列表 / 池可见性)

@MainActor
final class MLXState: ObservableObject {
    @Published var models: [MLXModelInfo] = []
    // F-A2子3: MLX 池可见性。周期轮询 mlx.status, 暴露 running + 已加载模型列表 + port。
    @Published var mlxRunning: Bool = false
    @Published var mlxLoadedModels: [String] = []
    @Published var mlxPort: Int = 0
    // ARCH-1 PR1 (#359 facade-delegate): MLX 行为从 AgentBridge 迁入域。
    //   IPCClient ref 由 AgentBridge.setIPCClient 注入 (MLX RPC 方法读 self.ipcClient)。
    //   timer/TTL 原主类 actor-local, 现域自持 (extension 可写真实类存储属性)。
    //   timer/TTL 为 internal (非 private): AgentMlxService extension 跨文件访问, Swift private=文件作用域。
    var ipcClient: IPCClient?
    var mlxStatusTimer: Timer?
    var mlxStatusFetchedAt: Date?
    init() {}
}

// MARK: - Agent State (Agent 生命周期 + Marketplace + 流式 + Graphs + Dashboard, 最大域)

@MainActor
final class AgentState: ObservableObject {
    @Published var agents: [AgentModel] = []
    @Published var currentAgent: AgentModel? = nil
    @Published var agentSkills: [String] = []
    @Published var agentSoul: String = ""
    @Published var marketplaceEntries: [MarketplaceEntryModel] = []
    @Published var marketplaceCategories: [String] = []
    @Published var agentVersionHistory: [String: [[String: Any]]] = [:]
    @Published var auditTrail: [[String: Any]] = []
    @Published var sessionLogs: [[String: Any]] = []
    @Published var activeSessionId: String = ""
    @Published var streamingContent: String = ""
    @Published var isAgentStreaming: Bool = false
    @Published var lastToolCalls: [[String: Any]] = []
    @Published var graphs: [AgentGraphModel] = []
    @Published var dashboardData: [String: Any] = [:]
    // ARCH-1 PR5 (#359 facade-delegate): Agent 行为从 AgentBridge 迁入域。
    //   IPCClient ref 由 AgentBridge.setIPCClient 注入 (agent/graph/marketplace RPC 方法读 self.ipcClient)。
    //   Agent 无 fetch TTL (fetchAgents 已有 F-R4 in-flight dedup 静态守卫, 其余 fetch 即时读/写)。
    //   ipcClient 为 internal (非 private): AgentOps/Graph/MarketplaceService extension 跨文件访问, Swift private=文件作用域。
    var ipcClient: IPCClient?
    init() {}
}

// MARK: - Module State (Planner + RAG + Memory + Safety + Template + Deploy + tools)

@MainActor
final class ModuleState: ObservableObject {
    @Published var plans: [PlanModel] = []
    @Published var currentPlan: PlanModel?
    @Published var ragResults: [RAGResultModel] = []
    @Published var memoryEntries: [MemoryEntryModel] = []
    @Published var memoryCount: Int = 0
    @Published var safetyCheckResult: SafetyCheckModel?
    @Published var safetyPendingActions: [SafetyActionModel] = []
    @Published var templates: [TemplateModel] = []
    @Published var deployFormats: [DeployFormatModel] = []
    @Published var tools: [[String: Any]] = []
    @Published var ragSources: [String] = []
    @Published var lastSkillResult: String = ""
    @Published var lastResearchResult: String = ""
    // ARCH-1 PR4 (#359 facade-delegate): Module 行为从 AgentBridge 迁入域。
    //   IPCClient ref 由 AgentBridge.setIPCClient 注入 (module RPC 方法读 self.ipcClient)。
    //   Module 无 fetch TTL (全即时读/写, 无 onAppear 风暴守卫)。
    //   ipcClient 为 internal (非 private): AgentModule*Service extension 跨文件访问, Swift private=文件作用域。
    var ipcClient: IPCClient?
    init() {}
}

// MARK: - Task State (任务 / 项目)

@MainActor
final class TaskState: ObservableObject {
    @Published var tasks: [TaskModel] = []
    @Published var projects: [ProjectBucket] = []
    // ARCH-1 PR6 (#359 facade-delegate): Task fetch 行为从 AgentBridge 迁入域。
    //   IPCClient ref 由 AgentBridge.setIPCClient 注入 (fetchTasks/fetchProjects RPC 读 self.ipcClient)。
    //   2 个 fetch TTL (tasks/projects 30s) 迁本域: fetch 叶 silo 自管防 onAppear 风暴。
    //   ipcClient/TTL 为 internal (非 private): AgentTaskService extension 跨文件访问, Swift private=文件作用域。
    //   执行集群 (taskExecuteImmediate/taskSubmit/taskDelete/taskCancel/taskRerun/taskScheduleCron/
    //     taskScheduleRunAt + taskRunHandles/backendCircuit/lockedTaskHandle/retryBackoffSeconds/taskIndex/
    //     updateTask/reportTaskStatus/encodeCronInput/summarizeEvents) 留 AgentBridge — 跨域协调器
    //     (依赖 executeGraph/parseEventModel/cronRegister + 共享 taskRunHandles/backendCircuit)。
    var ipcClient: IPCClient?
    var tasksFetchedAt: Date?
    var projectsFetchedAt: Date?
    init() {}
}

// MARK: - Config State (Connector + APIKey + Style + Hooks + Analytics + Team + Cron)

@MainActor
final class ConfigState: ObservableObject {
    @Published var connectors: [[String: Any]] = []
    @Published var apikeys: [[String: Any]] = []
    @Published var styles: [[String: Any]] = []
    @Published var analyticsData: [String: Any] = [:]
    @Published var alerts: [[String: Any]] = []
    @Published var swarmAgents: [[String: Any]] = []
    @Published var plazaChannels: [[String: Any]] = []
    @Published var cronJobs: [[String: Any]] = []
    @Published var hooks: [[String: Any]] = []
    // ARCH-1 PR3 (#359 facade-delegate): Config 行为从 AgentBridge 迁入域。
    //   IPCClient ref 由 AgentBridge.setIPCClient 注入 (config RPC 方法读 self.ipcClient)。
    //   6 fetch TTL 时间戳原主类 (apikeys/cronJobs/styles/hooks/connectors/alerts), 现域自持。
    //   ipcClient/TTL 为 internal (非 private): AgentConfig*Service extension 跨文件访问, Swift private=文件作用域。
    var ipcClient: IPCClient?
    var apikeysFetchedAt: Date?
    var cronJobsFetchedAt: Date?
    var stylesFetchedAt: Date?
    var hooksFetchedAt: Date?
    var connectorsFetchedAt: Date?
    var alertsFetchedAt: Date?
    init() {}

    // 审计0830 P0-10: ConfigState 8 @Published 数组无界。后端无限返回 + 反复 fetch →
    //   数组无上限膨胀 → 内存涨 + SwiftUI diff 全量重算卡顿 → 长会话 OOM/卡死。
    //   统一 LRU cap 200 (复用 capChatMessages 范式), 每个 fetch 后调用。超限裁尾保最新。
    private static let configArrayCap = 200
    @MainActor
    static func capConfigArray(_ array: [[String: Any]]) -> [[String: Any]] {
        guard array.count > configArrayCap else { return array }
        return Array(array.suffix(configArrayCap))
    }
}

// MARK: - Project Chat State (会话消息 / 推理中)

// ARCH-1 PR7 (#359 facade-delegate): Project Chat 行为从 AgentBridge 迁入域。
//   6 方法 (clearChat/infer/inferStream + 3 private helper) 全纯 HTTP (URLSession + FusionConfig),
//   0 IPC, 0 跨域读 → 无 ipcClient ref, 无 fetch TTL (同 PR1-PR6 坑: Swift private=文件作用域,
//   本域 internal 成员跨文件 extension 可达, 但本域无 ipcClient/TTL 需暴露)。
//   sendProjectChat 留 AgentBridge (跨域读 mlxState.models = 跨域协调器, 同 executeGraph)。
@MainActor
final class ProjectChatState: ObservableObject {
    @Published var chatMessages: [ChatMessageRecord] = []
    @Published var isInferring: Bool = false
    init() {}
}
