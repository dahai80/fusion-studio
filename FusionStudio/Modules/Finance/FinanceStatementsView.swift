import SwiftUI

struct FinanceStatementsView: View {
    @EnvironmentObject var financeBridge: FinanceBridge
    @State private var metricsResult: [String: Any]?
    @State private var screenerResult: [String: Any]?
    @State private var selectedPreset: String = "quality"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("财务指标计算")
                    .font(.title2.bold())

                Button("示例指标计算") { calcMetrics() }
                    .buttonStyle(.bordered)

                if let r = metricsResult {
                    resultSection("指标结果", dict: r)
                }

                Divider()

                Text("选股筛选")
                    .font(.title2.bold())

                Picker("策略", selection: $selectedPreset) {
                    Text("价值").tag("value")
                    Text("成长").tag("growth")
                    Text("红利").tag("dividend")
                    Text("质量").tag("quality")
                }
                .pickerStyle(.segmented)

                Button("筛选") { screenStocks() }
                    .buttonStyle(.bordered)

                if let r = screenerResult {
                    resultSection("筛选结果", dict: r)
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
