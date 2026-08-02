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
    case ragSheet = "RAG"
    case scienceSheet = "Science"

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
        }
    }

    var modules: [Module] {
        switch self {
        case .mlx:
            return [.dashboard, .modelHub, .training, .tuning, .bench]
        case .code:
            return [.code, .design, .doc, .docgen, .cli, .deploy]
        case .agentStudio:
            return [.agent, .plugin, .security, .kb, .dataTools, .rag, .memory, .planner]
        case .multiNode:
            return [.clusterOverview, .clusterTopology, .clusterSync, .taskMonitor, .alertCenter, .nodeActions, .submitTask, .taskProgress, .routingStrategy, .kvCache, .serviceWeb, .multimodal, .simulation, .analytics, .collab, .external, .operations]
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
            return [.kb, .rag]
        case .scienceSheet:
            return [.science]
        }
    }
}

enum Module: String, CaseIterable, Identifiable {
    case dashboard = "控制台"
    case design    = "设计"
    case code      = "编码"
    case simulation = "仿真"  // L5 domain — deprecated, remove when upstream service lands
    case modelHub  = "模型"
    case multimodal = "多模态"
    case training  = "训练"  // L5 domain — deprecated, remove when upstream service lands
    case cli       = "命令行"
    case doc       = "文档"
    case kb        = "知识库"
    case bench     = "测评"
    case desk      = "自动化"
    case dataTools = "数据工具"
    case agent     = "智能体"
    case plugin    = "插件"
    case security  = "安全"
    case analytics = "分析"
    case collab    = "协作"
    case tuning    = "调优"
    case external  = "外部集成"
    case docgen    = "文档生成"
    case clusterOverview = "集群总览"
    case clusterTopology = "拓扑图"
    case clusterSync = "集群同步"
    case taskMonitor = "任务监控"
    case alertCenter = "告警中心"
    case nodeActions = "节点管理"
    case submitTask = "提交任务"
    case taskProgress = "任务详情"
    case routingStrategy = "路由策略"
    case kvCache = "KV缓存"
    case serviceWeb = "服务面板"
    case rag        = "RAG"
    case memory     = "记忆"
    case planner    = "规划"
    case deploy     = "部署"
    // Callers: ModuleDetailView, sidebar. Affected API: verify.verify, budget.set/status. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
    case operations = "运维"
    case eduK12 = "教育"  // L5 domain — deprecated, remove when upstream service lands
    case verification = "验证"
    case tokenBudget = "预算"
    case safety = "安全审批"
    case tools = "工具"
    case agentDashboard = "Agent监控"
    case teamCollab = "团队协作"
    case chat = "对话"
    case fusionProjects = "项目管理"
    case cowork = "协作空间"
    case artifactsRepo = "Artifacts仓库"
    case fsb = "FSB"
    // Callers: ModuleDetailView, FusionSidebarView. Affected API: AgentBridge.agents, ipc.agent*.
    // Data schemas: AgentModel. User instruction: "按照GUI草图实现fusion-ai-agent"
    case aiAgentDashboard = "AI总览"
    case aiAgentList = "Agent列表"
    case aiAgentChat = "AI对话"
    case aiAgentObserver = "AI监控"
    case aiAgentKnowledgeBase = "AI知识库"
    case science = "科研"

    var id: String { rawValue }

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
        case .kb:         return "books.vertical"
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
        }
    }

    var sheet: ProductSheet {
        switch self {
        case .dashboard, .modelHub, .training, .tuning, .bench:
            return .mlx
        case .chat:
            return .chat
        case .design, .code, .doc, .docgen, .cli:
            return .code
        case .agent, .plugin, .security, .dataTools:
            return .agentStudio
        case .multimodal, .simulation, .analytics, .collab, .external, .desk,
             .clusterOverview, .clusterTopology, .clusterSync, .taskMonitor, .alertCenter, .nodeActions,
             .submitTask, .taskProgress, .routingStrategy, .kvCache, .serviceWeb,
             .operations:
            return .multiNode
        case .kb, .rag:
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
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case chats = "Chats"
    case projects = "Projects"
    case artifacts = "Artifacts"
    case code = "Code"
    case design = "Design"
    case rag = "RAG"
    case agent = "Agent"
    case aiAgent = "AI Agent"
    case cowork = "CoWork"
    case fsb = "FSB"
    case mlx = "Fusion-MLX"
    case multiNode = "Multi-Node"
    case science = "Science"

    var id: String { rawValue }

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
        case .multiNode: return "network"
        case .fsb:       return "storefront"
        case .science:   return "flask"
        }
    }

    var modules: [Module] {
        switch self {
        case .chats:     return [.chat, .code]
        case .projects:  return [.fusionProjects]
        case .artifacts: return [.artifactsRepo]
        case .code:      return [.code, .design, .doc, .docgen, .cli]
        case .design:    return [.design]
        case .rag:       return [.kb, .rag]
        case .agent:     return [.agent, .agentDashboard, .teamCollab, .tools, .safety, .memory, .planner, .verification, .tokenBudget, .security, .dataTools, .plugin, .desk]
        case .aiAgent:   return [.aiAgentDashboard, .aiAgentList, .aiAgentChat, .aiAgentObserver, .aiAgentKnowledgeBase]
        case .cowork:    return [.cowork]
        case .mlx:       return [.dashboard, .modelHub, .tuning, .bench]
        case .multiNode: return [.clusterOverview, .clusterTopology, .clusterSync, .taskMonitor, .alertCenter, .nodeActions, .submitTask, .taskProgress, .routingStrategy, .kvCache, .serviceWeb, .multimodal, .analytics, .collab, .external, .operations, .deploy]
        case .fsb:       return [.fsb]
        case .science:   return [.science]
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
