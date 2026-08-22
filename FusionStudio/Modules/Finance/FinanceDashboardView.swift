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

                Text(I18nManager.shared.t(.fin_company_panorama))
                    .font(.title2.bold())

                HStack(spacing: 12) {
                    TextField(I18nManager.shared.t(.fin_ph_company), text: $company)
                        .textFieldStyle(.roundedBorder)
                    TextField(I18nManager.shared.t(.fin_ph_revenue), text: $revenue)
                        .textFieldStyle(.roundedBorder)
                    TextField("WACC", text: $wacc)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Button(I18nManager.shared.t(.fin_btn_query)) { fetchDashboard() }
                        .buttonStyle(.borderedProminent)
                }

                if let result = financeBridge.dashboardResult {
                    dashboardContent(result)
                }

                Divider()

                Text(I18nManager.shared.t(.fin_market_overview))
                    .font(.title2.bold())

                HStack(spacing: 12) {
                    Button(I18nManager.shared.t(.fin_stock_value)) { fetchMarket(preset: "value") }
                    Button(I18nManager.shared.t(.fin_stock_growth)) { fetchMarket(preset: "growth") }
                    Button(I18nManager.shared.t(.fin_stock_dividend)) { fetchMarket(preset: "dividend") }
                    Button(I18nManager.shared.t(.fin_stock_quality)) { fetchMarket(preset: "quality") }
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
            Text(financeBridge.isConnected ? I18nManager.shared.t(.fin_connected) : I18nManager.shared.t(.fin_disconnected))
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
                    metricCard(I18nManager.shared.t(.fin_metric_enterprise), value: dcf.enterpriseValue.map { String(format: "%.1f", $0) } ?? "—")
                    metricCard(I18nManager.shared.t(.fin_metric_equity), value: dcf.equityValue.map { String(format: "%.1f", $0) } ?? "—")
                }
            }
            if let metrics = result.keyMetrics {
                HStack(spacing: 16) {
                    metricCard(I18nManager.shared.t(.fin_metric_gross_margin), value: metrics.grossMargin.map { String(format: "%.1f%%", $0 * 100) } ?? "—")
                    metricCard(I18nManager.shared.t(.fin_metric_ebit_margin), value: metrics.ebitMargin.map { String(format: "%.1f%%", $0 * 100) } ?? "—")
                }
            }
        }
    }

    private func marketContent(_ market: FinanceMarketResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let screener = market.screener {
                Text(String(format: I18nManager.shared.t(.fin_passed_filter), screener.passedFilter ?? 0))
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
