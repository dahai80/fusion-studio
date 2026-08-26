import SwiftUI
import os.log

// F-A1/F-I1: AgentBridge 48 @Published 拆 7 独立 ObservableObject 域类型 (审计 0825 验收 P0,
//   复用 F-A5 PR#315 AppState 拆 4 域已验证模式)。AgentBridge 持 let 域引用, facade 仍是
//   extension AgentBridge 经 self.<state>.X reach-through。SwiftUI 经 body 内 bridge.<state>.X
//   自动追踪域 (let 稳定身份), 每域独立重绘粒度 = 审计根治。0 跨域写确认 → 干净可分阶段。
// 域: RuntimeState / MLXState / AgentState / ModuleState / TaskState / ConfigState / ProjectChatState。

// MARK: - Runtime State (连接 / 执行 / 事件)

final class RuntimeState: ObservableObject {
    init() {}
}

// MARK: - MLX State (模型列表 / 池可见性)

final class MLXState: ObservableObject {
    @Published var models: [MLXModelInfo] = []
    // F-A2子3: MLX 池可见性。周期轮询 mlx.status, 暴露 running + 已加载模型列表 + port。
    @Published var mlxRunning: Bool = false
    @Published var mlxLoadedModels: [String] = []
    @Published var mlxPort: Int = 0
    init() {}
}

// MARK: - Agent State (Agent 生命周期 + Marketplace + 流式 + Graphs + Dashboard, 最大域)

final class AgentState: ObservableObject {
    init() {}
}

// MARK: - Module State (Planner + RAG + Memory + Safety + Template + Deploy + tools)

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
    init() {}
}

// MARK: - Task State (任务 / 项目)

final class TaskState: ObservableObject {
    @Published var tasks: [TaskModel] = []
    @Published var projects: [ProjectBucket] = []
    init() {}
}

// MARK: - Config State (Connector + APIKey + Style + Hooks + Analytics + Team + Cron)

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
    init() {}
}

// MARK: - Project Chat State (会话消息 / 推理中)

final class ProjectChatState: ObservableObject {
    @Published var chatMessages: [ChatMessageRecord] = []
    @Published var isInferring: Bool = false
    init() {}
}
