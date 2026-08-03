import SwiftUI

struct FinanceDashboardView: View {
    @EnvironmentObject var financeBridge: FinanceBridge
    @State private var company: String = ""
    @State private var revenue: String = "100,120,140"
    @State private var wacc: String = "0.10"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                connectionStatus

                Text("公司全景")
                    .font(.title2.bold())

                HStack(spacing: 12) {
                    TextField("公司名称", text: $company)
                        .textFieldStyle(.roundedBorder)
                    TextField("营收(逗号分隔)", text: $revenue)
                        .textFieldStyle(.roundedBorder)
                    TextField("WACC", text: $wacc)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Button("查询") { fetchDashboard() }
                        .buttonStyle(.borderedProminent)
                }

                if let result = financeBridge.dashboardResult {
                    dashboardContent(result)
                }

                Divider()

                Text("市场概览")
                    .font(.title2.bold())

                HStack(spacing: 12) {
                    Button("价值股") { fetchMarket(preset: "value") }
                    Button("成长股") { fetchMarket(preset: "growth") }
                    Button("红利股") { fetchMarket(preset: "dividend") }
                    Button("质量股") { fetchMarket(preset: "quality") }
                }
                .buttonStyle(.bordered)

                if let market = financeBridge.marketResult {
                    marketContent(market)
                }
            }
            .padding(20)
        }
    }

    private var connectionStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(financeBridge.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(financeBridge.isConnected ? "已连接" : "未连接")
                .font(.caption)
            if let status = financeBridge.serviceStatus {
                Text("v\(status.version) · MLX: \(status.mlx.status)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func dashboardContent(_ result: FinanceDashboardResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.company).font(.headline)
            if let dcf = result.dcf {
                HStack(spacing: 16) {
                    metricCard("企业价值", value: dcf.enterpriseValue.map { String(format: "%.1f", $0) } ?? "—")
                    metricCard("股权价值", value: dcf.equityValue.map { String(format: "%.1f", $0) } ?? "—")
                }
            }
            if let metrics = result.keyMetrics {
                HStack(spacing: 16) {
                    metricCard("毛利率", value: metrics.grossMargin.map { String(format: "%.1f%%", $0 * 100) } ?? "—")
                    metricCard("EBIT利润率", value: metrics.ebitMargin.map { String(format: "%.1f%%", $0 * 100) } ?? "—")
                }
            }
        }
    }

    private func marketContent(_ market: FinanceMarketResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let screener = market.screener {
                Text("通过筛选: \(screener.passedFilter ?? 0) 只")
                    .font(.subheadline)
                if let items = screener.results {
                    ForEach(items.prefix(10)) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text(item.score.map { String(format: "%.2f", $0) } ?? "—")
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    private func metricCard(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title3.bold())
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }

    private func fetchDashboard() {
        let rev = revenue.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        financeBridge.fetchDashboard(company: company.isEmpty ? "Demo" : company, revenue: rev, ebitMargin: [], wacc: Double(wacc) ?? 0.10)
    }

    private func fetchMarket(preset: String) {
        financeBridge.fetchMarketDashboard(preset: preset, limit: 5)
    }
}
