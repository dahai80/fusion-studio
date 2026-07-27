import SwiftUI
import os.log

private let appStateLog = Logger(subsystem: "com.fusion.studio", category: "AppState")

class AppState: ObservableObject {
    @Published var selectedModule: Module = .code
    @Published var selectedSheet: ProductSheet = .code
    @Published var activeSection: SidebarSection = .code
    @Published var showAboutPanel = false
    @Published var showHelp = false
    @Published var showSettings = false
    @Published var isHealthCheckPassed = false
    @Published var isMLXRunning = false
    @Published var healthStatus: HealthStatus = .checking
    @Published var isInspectorVisible: Bool = false
    @Published var inspectorContext: InspectorContext = .none
    @Published var isSidebarCollapsed: Bool = true
    @Published var sidebarWidth: CGFloat = 260

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

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .mlx: "chip"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .agentStudio: "person.2.fill"
        case .multiNode: "network"
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
            return [.clusterOverview, .clusterTopology, .taskMonitor, .alertCenter, .nodeActions, .submitTask, .taskProgress, .routingStrategy, .kvCache, .serviceWeb, .multimodal, .simulation, .analytics, .collab, .external, .operations]
        }
    }
}

enum Module: String, CaseIterable, Identifiable {
    case dashboard = "控制台"
    case design    = "设计"
    case code      = "编码"
    case simulation = "仿真"
    case modelHub  = "模型"
    case multimodal = "多模态"
    case training  = "训练"
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
    case operations = "运维"

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
        }
    }

    var sheet: ProductSheet {
        switch self {
        case .dashboard, .modelHub, .training, .tuning, .bench:
            return .mlx
        case .design, .code, .doc, .docgen, .cli:
            return .code
        case .agent, .plugin, .security, .kb, .dataTools:
            return .agentStudio
        case .multimodal, .simulation, .analytics, .collab, .external, .desk,
             .clusterOverview, .clusterTopology, .taskMonitor, .alertCenter, .nodeActions,
             .submitTask, .taskProgress, .routingStrategy, .kvCache, .serviceWeb,
             .operations:
            return .multiNode
        case .rag, .memory, .planner:
            return .agentStudio
        case .deploy:
            return .code
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case chats = "Chats"
    case projects = "Projects"
    case artifacts = "Artifacts"
    case code = "Code"
    case customize = "Customize"
    case design = "Design"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chats:     return "message"
        case .projects:  return "folder"
        case .artifacts: return "cube.box"
        case .code:      return "chevron.left.forwardslash.chevron.right"
        case .customize: return "paintpalette"
        case .design:    return "pencil.and.outline"
        }
    }

    var modules: [Module] {
        switch self {
        case .chats:     return [.code]
        case .projects:  return []
        case .artifacts: return []
        case .code:      return [.code, .design, .doc, .docgen, .cli]
        case .customize: return []
        case .design:    return [.design]
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
