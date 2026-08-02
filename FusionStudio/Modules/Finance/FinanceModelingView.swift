import SwiftUI

struct FinanceModelingView: View {
    @EnvironmentObject var financeBridge: FinanceBridge
    @State private var company: String = "TestCorp"
    @State private var revenue: String = "100,120,140"
    @State private var wacc: String = "0.10"
    @State private var terminalGrowth: String = "0.03"
    @State private var dcfResult: [String: Any]?
    @State private var sensitivityResult: [String: Any]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("DCF 估值")
                    .font(.title2.bold())

                HStack(spacing: 12) {
                    TextField("公司", text: $company)
                        .textFieldStyle(.roundedBorder)
                    TextField("营收", text: $revenue)
                        .textFieldStyle(.roundedBorder)
                    TextField("WACC", text: $wacc)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    TextField("永续增长率", text: $terminalGrowth)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Button("计算 DCF") { calcDCF() }
                        .buttonStyle(.borderedProminent)
                }

                if let r = dcfResult {
                    resultSection("DCF 结果", dict: r)
                }

                Divider()

                Text("敏感性分析")
                    .font(.title2.bold())

                Button("运行敏感性分析") { calcSensitivity() }
                    .buttonStyle(.bordered)

                if let r = sensitivityResult {
                    resultSection("敏感性矩阵", dict: r)
                }

                Divider()

                Text("投资组合优化")
                    .font(.title2.bold())

                Button("示例组合优化") { calcPortfolio() }
                    .buttonStyle(.bordered)
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
                    Text(formatValue(dict[key]))
                }
                .font(.subheadline)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }

    private func formatValue(_ val: Any) -> String {
        if let d = val as? Double { return String(format: "%.2f", d) }
        if let i = val as? Int { return "\(i)" }
        if let s = val as? String { return s }
        if let arr = val as? [Any] { return "[\(arr.count) items]" }
        if let dict = val as? [String: Any] { return "{\(dict.count) keys}" }
        return String(describing: val)
    }

    private func calcDCF() {
        let rev = revenue.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        financeBridge.calculateDCF(company: company, revenue: rev, wacc: Double(wacc) ?? 0.10, terminalGrowth: Double(terminalGrowth) ?? 0.03) { result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self.dcfResult = r }
            }
        }
    }

    private func calcSensitivity() {
        let rev = revenue.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        financeBridge.sensitivityAnalysis(company: company, revenue: rev, wacc: Double(wacc) ?? 0.10, terminalGrowth: Double(terminalGrowth) ?? 0.03, waccRange: [0.08, 0.10, 0.12], growthRange: [0.02, 0.03, 0.04]) { result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self.sensitivityResult = r }
            }
        }
    }

    private func calcPortfolio() {
        financeBridge.portfolioOptimize(assets: ["Stock A", "Stock B"], returns: [0.10, 0.08], volatilities: [0.20, 0.15], correlations: [[1.0, 0.5], [0.5, 1.0]]) { _ in }
    }
}
