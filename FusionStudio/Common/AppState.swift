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

/// 模块枚举（对应九大产品）
enum Module: String, CaseIterable, Identifiable {
    case dashboard = "控制台"
    case design    = "设计"
    case code      = "编码"
    case simulation = "仿真"
    case modelHub  = "模型"
    case cli       = "命令行"
    case doc       = "文档"
    case kb        = "知识库"
    case bench     = "测评"
    case desk      = "自动化"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:  return "square.grid.2x2"
        case .design:     return "pencil.and.outline"
        case .code:       return "chevron.left.forwardslash.chevron.right"
        case .simulation: return "gearshape.2"
        case .modelHub:   return "cpu"
        case .cli:        return "terminal"
        case .doc:        return "doc.text"
        case .kb:         return "books.vertical"
        case .bench:      return "chart.bar"
        case .desk:       return "desktopcomputer"
        }
    }
}