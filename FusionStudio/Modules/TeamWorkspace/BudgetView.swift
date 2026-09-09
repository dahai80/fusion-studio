import SwiftUI
import os.log

private let budgetViewLog = Logger(subsystem: "com.fusion.studio", category: "BudgetView")

// M2-6: BudgetView + team health. Uses budget.status (global, existing RPC)
// + team.health (per-team, upstream #318 merged 625b66e).
struct BudgetView: View {
    @EnvironmentObject var teamBridge: TeamBridge

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                budgetCard
                healthCard
            }
            .padding(12)
        }
        .onAppear {
            Task {
                await teamBridge.refreshBudget()
                await teamBridge.refreshTeamHealth()
            }
            budgetViewLog.info("BudgetView appeared team=\(teamBridge.selectedTeam, privacy: .public)")
        }
    }

    // MARK: - Budget card

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("Budget", icon: "creditcard.fill")
            if let budget = teamBridge.budget {
                budgetContent(budget)
            } else {
                Text("No budget data")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func budgetContent(_ budget: TeamBudget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statBlock(label: "Max", value: "\(budget.maxTokens)", color: .secondary)
                statBlock(label: "Spent", value: "\(budget.spentTokens)", color: .orange)
                statBlock(label: "Remaining", value: "\(budget.remaining)", color: budget.exceeded ? .red : .green)
            }
            progressBar(budget)
            if budget.exceeded {
                overBudgetWarning
            }
            if budget.estimatedCost > 0 {
                HStack {
                    Text("Est. Cost")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "$%.4f", budget.estimatedCost))
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
    }

    private func progressBar(_ budget: TeamBudget) -> some View {
        let pct = budget.maxTokens > 0
            ? min(Double(budget.spentTokens) / Double(budget.maxTokens), 1.0)
            : 0
        return VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(budget.exceeded ? Color.red : Color.accentColor)
                        .frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)
            Text("\(Int(pct * 100))% used")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    private var overBudgetWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.system(size: 11))
            Text("Budget exceeded — token spending capped")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Health card

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader("Team Health", icon: "heart.text.square.fill")
            if let health = teamBridge.teamHealth {
                healthContent(health)
            } else {
                Text("No health data")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func healthContent(_ health: TeamHealth) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statBlock(label: "Pending", value: "\(health.pendingTasks)", color: .orange)
                statBlock(label: "Running", value: "\(health.runningTasks)", color: .accentColor)
                statBlock(label: "Total", value: "\(health.totalTasks)", color: .secondary)
            }
            HStack {
                statBlock(label: "Max Concurrency", value: "\(health.maxConcurrency)", color: .secondary)
                Spacer()
            }
            Text("Per-team health (team=\(teamBridge.selectedTeam))")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func cardHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
    }

    private func statBlock(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
