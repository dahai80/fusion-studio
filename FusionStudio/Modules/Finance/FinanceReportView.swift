import SwiftUI

struct FinanceReportView: View {
    @EnvironmentObject var financeBridge: FinanceBridge
    @State private var company: String = "TestCorp"
    @State private var reportResult: [String: Any]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(I18nManager.shared.t(.fin_valuation_report))
                    .font(.title2.bold())

                HStack(spacing: 12) {
                    TextField(I18nManager.shared.t(.fin_ph_company), text: $company)
                        .textFieldStyle(.roundedBorder)
                    Button(I18nManager.shared.t(.fin_btn_gen_report)) { genReport() }
                        .buttonStyle(.borderedProminent)
                }

                if let r = reportResult {
                    resultSection(I18nManager.shared.t(.fin_report_content), dict: r)
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
        if let s = val as? String { return String(s.prefix(80)) }
        if let arr = val as? [Any] { return "[\(arr.count)]" }
        if let d = val as? [String: Any] { return "{\(d.count)}" }
        return "—"
    }

    private func genReport() {
        financeBridge.generateValuationReport(company: company) { result in
            DispatchQueue.main.async {
                if case .success(let r) = result { self.reportResult = r }
            }
        }
    }
}
