import SwiftUI

struct FinanceStatementsView: View {
    @EnvironmentObject var financeBridge: FinanceBridge
    @State private var metricsResult: [String: Any]?
    @State private var screenerResult: [String: Any]?
    @State private var selectedPreset: String = "quality"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(I18nManager.shared.t(.fin_metrics_calc))
                    .font(.title2.bold())

                Button(I18nManager.shared.t(.fin_btn_sample_metrics)) { calcMetrics() }
                    .buttonStyle(.bordered)

                if let r = metricsResult {
                    resultSection(I18nManager.shared.t(.fin_metrics_result), dict: r)
                }

                Divider()

                Text(I18nManager.shared.t(.fin_stock_screener))
                    .font(.title2.bold())

                Picker(I18nManager.shared.t(.fin_strategy), selection: $selectedPreset) {
                    Text(I18nManager.shared.t(.fin_strategy_value)).tag("value")
                    Text(I18nManager.shared.t(.fin_strategy_growth)).tag("growth")
                    Text(I18nManager.shared.t(.fin_strategy_dividend)).tag("dividend")
                    Text(I18nManager.shared.t(.fin_strategy_quality)).tag("quality")
                }
                .pickerStyle(.segmented)

                Button(I18nManager.shared.t(.fin_btn_screen)) { screenStocks() }
                    .buttonStyle(.bordered)

                if let r = screenerResult {
                    resultSection(I18nManager.shared.t(.fin_screen_result), dict: r)
                }
            }
            .padding(20)
        }
    }

    private func resultSection(_ title: String, dict: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key).foregroundColor(.secondary)
                    Spacer()
                    Text(formatVal(dict[key]))
                }
                .font(.subheadline)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }

    private func formatVal(_ val: Any) -> String {
        if let d = val as? Double { return String(format: "%.2f", d) }
        if let i = val as? Int { return "\(i)" }
        if let s = val as? String { return s }
        if let arr = val as? [Any] { return "[\(arr.count)]" }
        if let d = val as? [String: Any] { return "{\(d.count)}" }
        return "—"
    }

    private func calcMetrics() {
        financeBridge.fetchMetrics(
            incomeStatement: ["revenue": 1000, "cogs": 600, "operating_expenses": 200, "interest_expense": 50, "tax_rate": 0.25],
            balanceSheet: ["total_assets": 5000, "total_liabilities": 2000, "cash": 500, "current_assets": 1500, "current_liabilities": 800, "inventory": 300],
            cashFlow: ["operating_cf": 300, "capex": 100]
        ) { result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self.metricsResult = r }
            }
        }
    }

    private func screenStocks() {
        financeBridge.screenStocks(filters: ["preset": selectedPreset], limit: 5) { result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self.screenerResult = r }
            }
        }
    }
}
