import SwiftUI
import os.log

private let appStateLog = Logger(subsystem: "com.fusion.studio", category: "AppState")

class AppState: ObservableObject {
    @Published var selectedModule: Module = .chat
    @Published var selectedSheet: ProductSheet = .chat
    @Published var activeSection: SidebarSection = .chats
    @Published var showAboutPanel = false
    @Published var showHelp = false
    @Published var showWelcome = false
    @Published var showSettings = false
    @Published var showEnvironmentHealth = false
    @Published var isHealthCheckPassed = false
    @Published var isMLXRunning = false
    @Published var healthStatus: HealthStatus = .checking
    @Published var isInspectorVisible: Bool = false
    @Published var inspectorContext: InspectorContext = .none
    // Callers: IconRailView (+ sets false, Chats sets true), SectionContentView (switches layout).
    // Affected API: showChatsSidebar — controls whether chats section shows sidebar history list.
    // Data schemas: Bool flag. User instruction: "点击+号打开主对话框，Chats按钮右侧显示历史+对话两列"
    @Published var isSidebarCollapsed: Bool = true
    @Published var sidebarWidth: CGFloat = 260
    @Published var showChatsSidebar: Bool = false
    @Published var isDarkMode: Bool = UserDefaults.standard.object(forKey: "fusionStudio.isDarkMode") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "fusionStudio.isDarkMode") }
    }

    enum HealthStatus {
        case checking
        case healthy
        case issuesFound
        case repairing
    }
}

enum InspectorContext: Equatable {
    case none
    case agent(id: String)
    case dagNode(id: String)
    case task(id: String)
    case node(id: String)
    case clusterTask(id: String)
    case settings
    case custom(title: String)
}

enum ProductSheet: String, CaseIterable, Identifiable {
    case mlx = "Fusion-MLX"
    case code = "Fusion-Code"
    case agentStudio = "Agent Studio"
    case multiNode = "Multi-Node"
    case chat = "Chat"
    case fusionProjectsSheet = "Fusion Projects"
    case coworkSheet = "CoWork"
    case artifactsSheet = "Artifacts"
    case fsbSheet = "FSB"
    case aiAgentSheet = "AI Agent"
    case ragSheet = "Fusion RAG"
    case scienceSheet = "Science"
    case financeSheet = "Finance"
    case healthSheet = "Health"
    case pluginEcosystemSheet = "Plugin Ecosystem"
    case cliServiceSheet = "CLI Service"
    case docSheet = "Fusion Doc"
    // Callers: IconRailView/FusionSidebarView/ModuleDetailView/SectionContentView routing.
    // Affected API: ProductSheet.simulationSheet case + SidebarSection.simulation section.
    // Data schemas: enum case. User instruction: "在左侧菜单增加 fusion simulation"
    case simulationSheet = "Fusion Simulation"
    case douyinOperationSheet = "Douyin Operation"
    case trainerSheet = "Fusion Trainer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .mlx: "chip"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .agentStudio: "person.2.fill"
        case .multiNode: "network"
        case .chat: "bubble.left.and.bubble.right"
        case .fusionProjectsSheet: "folder.badge.gearshape"
        case .coworkSheet: "person.2.square.stack"
        case .artifactsSheet: "cube.box"
        case .fsbSheet:       "storefront"
        case .aiAgentSheet:   "brain"
        case .ragSheet:       "books.vertical"
        case .scienceSheet:   "flask"
        case .financeSheet:   "chart.line.uptrend.xyaxis"
        case .healthSheet:    "heart.text.square"
        case .pluginEcosystemSheet: "puzzlepiece.extension"
        case .cliServiceSheet: "terminal"
        case .docSheet:       "doc.text"
        case .simulationSheet: "cube.transparent"
        case .douyinOperationSheet: "play.rectangle.fill"
        case .trainerSheet: "graduationcap.fill"
        }
    }

    var modules: [Module] {
        switch self {
        case .mlx:
            return [.dashboard, .modelHub, .training, .tuning, .bench]
        case .code:
            return [.code, .design, .doc, .docgen, .cli, .deploy]
        case .agentStudio:
            return [.agent, .plugin, .security, .dataTools, .rag, .memory, .planner]
        case .multiNode:
            return [.clusterOverview, .clusterTopology, .clusterSync, .taskMonitor, .alertCenter, .nodeActions, .submitTask, .taskProgress, .routingStrategy, .kvCache, .serviceWeb, .multimodal, .analytics, .collab, .external, .operations]
        case .chat:
            return [.chat]
        case .fusionProjectsSheet:
            return [.fusionProjects]
        case .coworkSheet:
            return [.cowork]
        case .artifactsSheet:
            return [.artifactsRepo]
        case .fsbSheet:
            return [.fsb]
        case .aiAgentSheet:
            return [.aiAgentDashboard, .aiAgentList, .aiAgentChat, .aiAgentObserver, .aiAgentKnowledgeBase]
        case .ragSheet:
            return [.rag]
        case .scienceSheet:
            return [.science]
        case .financeSheet:
            return [.finance]
        case .healthSheet:
            return [.health]
        case .pluginEcosystemSheet:
            return [.pluginConfig, .pluginStatus, .pluginToken, .pluginVram, .pluginLog, .pluginMcp]
        case .cliServiceSheet:
            return [.cli]
        case .docSheet:
            return [.doc]
        case .simulationSheet:
            return [.simulation]
        case .douyinOperationSheet:
            return []
        case .trainerSheet:
            return [.trainer]
        }
    }
}

enum Module: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case design    = "Design"
    case code      = "Code"
    case simulation = "Simulation"  // L5 domain — deprecated, remove when upstream service lands
    case modelHub  = "Model Hub"
    case multimodal = "Multimodal"
    case training  = "Training"  // L5 domain — deprecated, remove when upstream service lands
    case cli       = "CLI"
    case doc       = "Doc"
    case bench     = "Bench"
    case desk      = "Desk"
    case dataTools = "Data Tools"
    case agent     = "Agent"
    case plugin    = "Plugin"
    case security  = "Security"
    case analytics = "Analytics"
    case collab    = "Collab"
    case tuning    = "Tuning"
    case external  = "External"
    case docgen    = "Doc Generator"
    case clusterOverview = "Cluster Overview"
    case clusterTopology = "Cluster Topology"
    case clusterSync = "Cluster Sync"
    case taskMonitor = "Task Monitor"
    case alertCenter = "Alert Center"
    case nodeActions = "Node Actions"
    case submitTask = "Submit Task"
    case taskProgress = "Task Progress"
    case routingStrategy = "Routing Strategy"
    case kvCache = "KV Cache"
    case serviceWeb = "Service Web"
    case rag        = "RAG"
    case memory     = "Memory"
    case planner    = "Planner"
    case deploy     = "Deploy"
    // Callers: ModuleDetailView, sidebar. Affected API: verify.verify, budget.set/status. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
    case operations = "Operations"
    case eduK12 = "Edu K12"  // L5 domain — deprecated, remove when upstream service lands
    case verification = "Verification"
    case tokenBudget = "Token Budget"
    case safety = "Safety"
    case tools = "Tools"
    case agentDashboard = "Agent Dashboard"
    case teamCollab = "Team Collab"
    case chat = "Chat"
    case fusionProjects = "Fusion Projects"
    case cowork = "CoWork"
    case artifactsRepo = "Artifacts Repo"
    case fsb = "FSB"
    // Callers: ModuleDetailView, FusionSidebarView. Affected API: AgentBridge.agents, ipc.agent*.
    // Data schemas: AgentModel. User instruction: "按照GUI草图实现fusion-ai-agent"
    case aiAgentDashboard = "AI Agent Dashboard"
    case aiAgentList = "AI Agent List"
    case aiAgentChat = "AI Agent Chat"
    case aiAgentObserver = "AI Agent Observer"
    case aiAgentKnowledgeBase = "AI Agent Knowledge Base"
    case science = "Science"
    case finance = "Finance"
    case health = "Health"
    case pluginConfig = "Plugin Config"
    case pluginStatus = "Plugin Status"
    case pluginToken = "Token"
    case pluginVram = "VRAM"
    case pluginLog = "Plugin Log"
    case pluginMcp = "MCP"
    // Callers: ModuleDetailView, FusionSidebarView. Affected API: trainer.* IPC via TrainerBridge.
    // Data schemas: TrainerRun/TrainerPreset/TrainerAdapter. User instruction: "continue Task" — fusion-trainer RunManager GUI panel (#175)
    case trainer = "Trainer"

    var id: String { rawValue }

    var localizedName: String {
        let key: I18nKey
        switch self {
        case .dashboard:            key = .mod_dashboard
        case .design:               key = .mod_design
        case .code:                 key = .mod_code
        case .simulation:           key = .mod_simulation
        case .modelHub:             key = .mod_modelHub
        case .multimodal:           key = .mod_multimodal
        case .training:             key = .mod_training
        case .cli:                  key = .mod_cli
        case .doc:                  key = .mod_doc
        case .bench:                key = .mod_bench
        case .desk:                 key = .mod_desk
        case .dataTools:            key = .mod_dataTools
        case .agent:                key = .mod_agent
        case .plugin:               key = .mod_plugin
        case .security:             key = .mod_security
        case .analytics:            key = .mod_analytics
        case .collab:               key = .mod_collab
        case .tuning:               key = .mod_tuning
        case .external:             key = .mod_external
        case .docgen:               key = .mod_docgen
        case .clusterOverview:      key = .mod_clusterOverview
        case .clusterTopology:      key = .mod_clusterTopology
        case .clusterSync:          key = .mod_clusterSync
        case .taskMonitor:          key = .mod_taskMonitor
        case .alertCenter:          key = .mod_alertCenter
        case .nodeActions:          key = .mod_nodeActions
        case .submitTask:           key = .mod_submitTask
        case .taskProgress:         key = .mod_taskProgress
        case .routingStrategy:      key = .mod_routingStrategy
        case .kvCache:              key = .mod_kvCache
        case .serviceWeb:           key = .mod_serviceWeb
        case .rag:                  key = .mod_rag
        case .memory:               key = .mod_memory
        case .planner:              key = .mod_planner
        case .deploy:               key = .mod_deploy
        case .operations:           key = .mod_operations
        case .eduK12:               key = .mod_eduK12
        case .verification:         key = .mod_verification
        case .tokenBudget:          key = .mod_tokenBudget
        case .safety:               key = .mod_safety
        case .tools:                key = .mod_tools
        case .agentDashboard:       key = .mod_agentDashboard
        case .teamCollab:           key = .mod_teamCollab
        case .chat:                 key = .mod_chat
        case .fusionProjects:       key = .mod_fusionProjects
        case .cowork:               key = .mod_cowork
        case .artifactsRepo:        key = .mod_artifactsRepo
        case .fsb:                  key = .mod_fsb
        case .aiAgentDashboard:     key = .mod_aiAgentDashboard
        case .aiAgentList:          key = .mod_aiAgentList
        case .aiAgentChat:          key = .mod_aiAgentChat
        case .aiAgentObserver:      key = .mod_aiAgentObserver
        case .aiAgentKnowledgeBase: key = .mod_aiAgentKnowledgeBase
        case .science:              key = .mod_science
        case .finance:              key = .mod_finance
        case .health:               key = .mod_health
        case .pluginConfig:         key = .mod_pluginConfig
        case .pluginStatus:         key = .mod_pluginStatus
        case .pluginToken:          key = .mod_pluginToken
        case .pluginVram:           key = .mod_pluginVram
        case .pluginLog:            key = .mod_pluginLog
        case .pluginMcp:            key = .mod_pluginMcp
        case .trainer:              key = .mod_trainer
        }
        return I18nManager.shared.t(key)
    }

    var icon: String {
        switch self {
        case .dashboard:  return "square.grid.2x2"
        case .design:     return "pencil.and.outline"
        case .code:       return "chevron.left.forwardslash.chevron.right"
        case .simulation: return "gearshape.2"
        case .modelHub:   return "cpu"
        case .multimodal: return "photo.on.rectangle"
        case .training:   return "brain"
        case .cli:        return "terminal"
        case .doc:        return "doc.text"
        case .bench:      return "chart.bar"
        case .desk:       return "desktopcomputer"
        case .dataTools:  return "tablecells"
        case .agent:      return "person.2.fill"
        case .plugin:     return "puzzlepiece.extension"
        case .security:   return "shield.checkered"
        case .analytics:  return "chart.bar.xaxis"
        case .collab:     return "person.2"
        case .tuning:     return "wand.and.rays"
        case .external:   return "link.circle"
        case .docgen:     return "doc.badge.gearshape"
        case .clusterOverview: return "square.grid.2x2"
        case .clusterTopology: return "point.3.connected.trianglepath.dotted"
        case .clusterSync: return "arrow.triangle.2.circlepath"
        case .taskMonitor: return "list.bullet.clipboard"
        case .alertCenter: return "exclamationmark.triangle"
        case .nodeActions: return "slider.horizontal.3"
        case .submitTask: return "paperplane"
        case .taskProgress: return "chart.bar.doc.horizontal"
        case .routingStrategy: return "arrow.triangle.branch"
        case .kvCache: return "internaldrive"
        case .serviceWeb: return "globe"
        case .rag:       return "magnifyingglass"
        case .memory:    return "brain.head.profile"
        case .planner:   return "list.bullet.rectangle"
        case .deploy:    return "arrow.up.doc"
        case .operations: return "gauge"
        case .eduK12:     return "graduationcap"
        case .verification: return "checkmark.shield"
        case .tokenBudget:  return "coins"
        case .safety:       return "shield.lefthalf.filled"
        case .tools:        return "wrench.and.screwdriver"
        case .agentDashboard: return "chart.bar.doc.horizontal"
        case .teamCollab:   return "person.3.fill"
        case .chat:         return "bubble.left.and.bubble.right"
        case .fusionProjects: return "folder.badge.gearshape"
        case .cowork:       return "person.2.square.stack"
        case .artifactsRepo: return "cube.box"
        case .fsb:          return "storefront"
        case .aiAgentDashboard: return "chart.bar.doc.horizontal"
        case .aiAgentList:     return "list.bullet"
        case .aiAgentChat:     return "bubble.left.and.bubble.right.fill"
        case .aiAgentObserver: return "eye"
        case .aiAgentKnowledgeBase: return "books.vertical"
        case .science: return "flask"
        case .finance: return "chart.line.uptrend.xyaxis"
        case .health: return "heart.text.square"
        case .pluginConfig: return "gearshape"
        case .pluginStatus: return "checkmark.circle"
        case .pluginToken: return "coins"
        case .pluginVram: return "memorychip"
        case .pluginLog: return "list.bullet.rectangle"
        case .pluginMcp: return "link"
        case .trainer:   return "graduationcap.fill"
        }
    }

    var sheet: ProductSheet {
        switch self {
        case .dashboard, .modelHub, .training, .tuning, .bench:
            return .mlx
        case .chat:
            return .chat
        case .design, .code, .docgen, .cli:
            return .code
        case .doc:
            return .docSheet
        case .agent, .plugin, .security, .dataTools:
            return .agentStudio
        case .multimodal, .analytics, .collab, .external, .desk,
             .clusterOverview, .clusterTopology, .clusterSync, .taskMonitor, .alertCenter, .nodeActions,
             .submitTask, .taskProgress, .routingStrategy, .kvCache, .serviceWeb,
             .operations:
            return .multiNode
        case .rag:
            return .ragSheet
        case .memory, .planner, .verification, .tokenBudget, .safety, .tools, .agentDashboard, .teamCollab:
            return .agentStudio
        case .deploy:
            return .code
        case .eduK12:
            return .mlx
        case .fusionProjects:
            return .fusionProjectsSheet
        case .cowork:
            return .coworkSheet
        case .artifactsRepo:
            return .artifactsSheet
        case .fsb:
            return .fsbSheet
        case .aiAgentDashboard, .aiAgentList, .aiAgentChat, .aiAgentObserver, .aiAgentKnowledgeBase:
            return .aiAgentSheet
        case .science:
            return .scienceSheet
        case .finance:
            return .financeSheet
        case .health:
            return .healthSheet
        case .simulation:
            return .simulationSheet
        case .pluginConfig, .pluginStatus, .pluginToken, .pluginVram, .pluginLog, .pluginMcp:
            return .agentStudio
        case .trainer:
            return .trainerSheet
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    // 第一部分：核心创作工具
    case chats = "Chats"
    case agent = "Agent Workbench"
    case projects = "Projects"
    case artifacts = "Artifacts"
    case code = "Code"
    case design = "Design"
    case doc = "Fusion Doc"
    case rag = "RAG"
    // 第二部分：AI 协作
    case aiAgent = "AI Console"
    case cowork = "CoWork"
    case fsb = "FSB"
    // 第三部分：平台与领域
    case mlx = "Fusion-MLX"
    case science = "Science"
    case finance = "Finance"
    case health = "Health"
    case cliService = "CLI Service"
    case simulation = "Fusion Simulation"
    case douyinOperation = "Douyin Operation"
    // 第四部分：平台扩展
    case modelHub = "Model Hub"
    case multiNode = "Multi-Node"
    case pluginEcosystem = "Plugin Ecosystem"
    case trainer = "Fusion Trainer"

    var id: String { rawValue }

    var localizedName: String {
        let key: I18nKey
        switch self {
        case .chats:           key = .secChats
        case .agent:           key = .secAgent
        case .projects:        key = .secProjects
        case .artifacts:       key = .secArtifacts
        case .code:            key = .secCode
        case .design:          key = .secDesign
        case .doc:             key = .secDoc
        case .rag:             key = .secRag
        case .aiAgent:         key = .secAIAgent
        case .cowork:          key = .secCowork
        case .fsb:             key = .secFsb
        case .mlx:             key = .secMlx
        case .science:         key = .secScience
        case .finance:         key = .secFinance
        case .health:          key = .secHealth
        case .cliService:      key = .secCliService
        case .simulation:      key = .secSimulation
        case .douyinOperation: key = .secDouyin
        case .modelHub:        key = .secModelHub
        case .multiNode:       key = .secMultiNode
        case .pluginEcosystem: key = .secPlugin
        case .trainer:         key = .secTrainer
        }
        return I18nManager.shared.t(key)
    }

    var icon: String {
        switch self {
        case .chats:     return "message"
        case .projects:  return "folder.badge.gearshape"
        case .artifacts: return "cube.box"
        case .code:      return "chevron.left.forwardslash.chevron.right"
        case .design:    return "pencil.and.outline"
        case .rag:       return "books.vertical"
        case .agent:     return "person.2.fill"
        case .aiAgent:   return "brain"
        case .cowork:    return "person.2.square.stack"
        case .mlx:       return "chip"
        case .modelHub:  return "square.stack.3d.up.fill"
        case .multiNode: return "network"
        case .fsb:       return "storefront"
        case .science:   return "flask"
        case .finance:   return "chart.line.uptrend.xyaxis"
        case .health:    return "heart.text.square"
        case .pluginEcosystem: return "puzzlepiece.extension"
        case .cliService: return "terminal"
        case .doc:       return "doc.text"
        case .simulation: return "cube.transparent"
        case .douyinOperation: return "play.rectangle.fill"
        case .trainer: return "graduationcap.fill"
        }
    }

    var modules: [Module] {
        switch self {
        case .chats:     return [.chat, .code]
        case .projects:  return [.fusionProjects]
        case .artifacts: return [.artifactsRepo]
        case .code:      return [.code, .design, .docgen, .cli]
        case .doc:       return [.doc]
        case .simulation: return [.simulation]
        case .design:    return [.design]
        case .rag:       return [.rag]
        case .agent:     return [.agent, .agentDashboard, .teamCollab, .tools, .safety, .memory, .planner, .verification, .tokenBudget, .security, .dataTools, .plugin, .desk]
        case .aiAgent:   return [.aiAgentDashboard, .aiAgentList, .aiAgentChat, .aiAgentObserver, .aiAgentKnowledgeBase]
        case .cowork:    return [.cowork]
        case .mlx:       return [.dashboard, .modelHub, .tuning, .bench]
        case .modelHub:  return [.modelHub]
        case .multiNode: return [.clusterOverview, .clusterTopology, .clusterSync, .taskMonitor, .alertCenter, .nodeActions, .submitTask, .taskProgress, .routingStrategy, .kvCache, .serviceWeb, .multimodal, .analytics, .collab, .external, .operations, .deploy]
        case .fsb:       return [.fsb]
        case .science:   return [.science]
        case .finance:   return [.finance]
        case .health:    return [.health]
        case .pluginEcosystem: return [.pluginConfig, .pluginStatus, .pluginToken, .pluginVram, .pluginLog, .pluginMcp]
        case .cliService: return [.cli]
        case .douyinOperation: return []
        case .trainer: return [.trainer]
        }
    }
}

struct SidebarItem: Identifiable {
    let id: String
    let section: SidebarSection
    let icon: String
    let title: String
    let module: Module?
    let badge: String?

    init(section: SidebarSection, icon: String, title: String, module: Module? = nil, badge: String? = nil) {
        self.id = module?.rawValue ?? "\(section.rawValue)-\(title)"
        self.section = section
        self.icon = icon
        self.title = title
        self.module = module
        self.badge = badge
    }
}
