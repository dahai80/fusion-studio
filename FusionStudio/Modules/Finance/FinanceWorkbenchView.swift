import SwiftUI
import os.log

private let viewLog = Logger(subsystem: "com.fusion.studio", category: "FinanceWorkbenchView")

struct FinanceWorkbenchView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var financeBridge: FinanceBridge
    @State private var selectedTab: FinanceModuleTab = .dashboard

    var body: some View {
        HSplitView {
            FinanceNavigationView(selectedTab: $selectedTab)
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 240)

            FinanceContentView(selectedTab: selectedTab)
                .frame(minWidth: 400, idealWidth: 600)

            FinanceCopilotPanel()
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 380)
        }
        .background(theme.contentBg)
        .onAppear {
            financeBridge.checkHealth()
            financeBridge.fetchServiceStatus()
            viewLog.info("FinanceWorkbenchView appeared")
        }
    }
}

struct FinanceNavigationView: View {
    @Environment(\.studioTheme) private var theme
    @Binding var selectedTab: FinanceModuleTab

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(I18nManager.shared.t(.fin_title))
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(FinanceModuleTab.allCases) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .frame(width: 20)
                        Text(tab.localizedName)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedTab == tab ? theme.accent.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .background(theme.sidebarBg)
    }
}

struct FinanceContentView: View {
    let selectedTab: FinanceModuleTab

    var body: some View {
        switch selectedTab {
        case .dashboard:
            FinanceDashboardView()
        case .modeling:
            FinanceModelingView()
        case .statements:
            FinanceStatementsView()
        case .risk:
            FinanceRiskView()
        case .report:
            FinanceReportView()
        }
    }
}
