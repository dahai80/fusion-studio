import SwiftUI

struct FinanceRiskView: View {
    @EnvironmentObject var financeBridge: FinanceBridge
    @State private var entity: String = ""
    @State private var kycResult: [String: Any]?
    @State private var varResult: [String: Any]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("KYC 尽职调查")
                    .font(.title2.bold())

                HStack(spacing: 12) {
                    TextField("实体名称", text: $entity)
                        .textFieldStyle(.roundedBorder)
                    Button("筛查") { runKYC() }
                        .buttonStyle(.borderedProminent)
                }

                if let r = kycResult {
                    resultSection("KYC 结果", dict: r)
                }

                Divider()

                Text("VaR 风险价值")
                    .font(.title2.bold())

                Button("示例 VaR 计算") { calcVar() }
                    .buttonStyle(.bordered)

                if let r = varResult {
                    resultSection("VaR 结果", dict: r)
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

    private func runKYC() {
        financeBridge.kycScreening(entity: entity.isEmpty ? "Test Corp" : entity) { result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self.kycResult = r }
            }
        }
    }

    private func calcVar() {
        financeBridge.calculateVar(returns: [0.01, -0.02, 0.03, -0.01, 0.02, 0.005, -0.015, 0.025]) { result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self.varResult = r }
            }
        }
    }
}
