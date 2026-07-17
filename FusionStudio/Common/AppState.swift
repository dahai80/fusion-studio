import SwiftUI

/// 全局应用状态
class AppState: ObservableObject {
    @Published var selectedModule: Module = .dashboard
    @Published var showAboutPanel = false
    @Published var showHelp = false
    @Published var showSettings = false
    @Published var isHealthCheckPassed = false
    @Published var isMLXRunning = false
    @Published var healthStatus: HealthStatus = .checking

    enum HealthStatus {
        case checking
        case healthy
        case issuesFound
        case repairing
    }
}

/// 模块枚举（对应九大产品 + 扩展模块）
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
        }
    }
}