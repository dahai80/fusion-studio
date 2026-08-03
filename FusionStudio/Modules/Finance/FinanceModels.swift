import Foundation

struct FinanceHealthResponse: Codable {
    let status: String
    let version: String
}

struct FinanceDashboardResult: Codable {
    let company: String
    let dcf: FinanceDCFResult?
    let scenarios: FinanceScenariosResult?
    let keyMetrics: FinanceKeyMetrics?
    let riskSummary: FinanceRiskSummary?

    enum CodingKeys: String, CodingKey {
        case company, dcf, scenarios
        case keyMetrics = "key_metrics"
        case riskSummary = "risk_summary"
    }
}

struct FinanceDCFResult: Codable {
    let enterpriseValue: Double?
    let equityValue: Double?
    let fcfList: [Double]?
    let terminalValue: Double?

    enum CodingKeys: String, CodingKey {
        case enterpriseValue = "enterprise_value"
        case equityValue = "equity_value"
        case fcfList = "fcf_list"
        case terminalValue = "terminal_value"
    }
}

struct FinanceScenariosResult: Codable {
    let bear: FinanceScenarioDetail?
    let base: FinanceScenarioDetail?
    let bull: FinanceScenarioDetail?
}

struct FinanceScenarioDetail: Codable {
    let equityValue: Double?
    let adjustments: [String: Double]?

    enum CodingKeys: String, CodingKey {
        case equityValue = "equity_value"
        case adjustments
    }
}

struct FinanceKeyMetrics: Codable {
    let grossMargin: Double?
    let ebitMargin: Double?

    enum CodingKeys: String, CodingKey {
        case grossMargin = "gross_margin"
        case ebitMargin = "ebit_margin"
    }
}

struct FinanceRiskSummary: Codable {
    let status: String?
    let note: String?
}

struct FinanceMarketResult: Codable {
    let screener: FinanceScreenerResult?
    let marketStatus: String?

    enum CodingKeys: String, CodingKey {
        case screener
        case marketStatus = "market_status"
    }
}

struct FinanceScreenerResult: Codable {
    let passedFilter: Int?
    let results: [FinanceScreenerItem]?

    enum CodingKeys: String, CodingKey {
        case passedFilter = "passed_filter"
        case results
    }
}

struct FinanceScreenerItem: Codable, Identifiable {
    let name: String
    let score: Double?
    var id: String { name }
}

struct FinanceServiceStatus: Codable {
    let service: String
    let version: String
    let mlx: FinanceMLXStatus
    let modules: [String]
}

struct FinanceMLXStatus: Codable {
    let status: String
    let models: [String]
}

struct FinanceCopilotMessage: Codable, Identifiable {
    let role: String
    let content: String
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case role, content
        case sessionId = "session_id"
    }

    var id: String { "\(role)_\(content.prefix(16))_\(Int(Date().timeIntervalSince1970 * 1000))" }
}

enum FinanceModuleTab: String, CaseIterable, Identifiable {
    case dashboard = "仪表盘"
    case modeling = "建模"
    case statements = "财报"
    case risk = "风控"
    case report = "报告"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:  return "square.grid.2x2"
        case .modeling:   return "chart.bar.xaxis"
        case .statements: return "doc.text.magnifyingglass"
        case .risk:       return "shield.checkered"
        case .report:     return "doc.richtext"
        }
    }
}
