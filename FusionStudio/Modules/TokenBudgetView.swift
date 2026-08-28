// Callers: ModuleDetailView routing. Affected API: budget.set/status. Data schemas: budget.set(total_budget=Int, warn_percent=Int, hard_limit=Bool), budget.status() returns {total, used, remaining, percent, is_exceeded}. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"

import SwiftUI
import os.log

struct TokenBudgetView: View {
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var totalBudget: Int = 100000
    @State private var warnPercent: Int = 80
    @State private var hardLimit: Bool = true
    @State private var status: [String: Any]?
    @State private var isSetting: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var errorMsg: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "TokenBudget")

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Text("Token Budget")
                .font(.system(size: theme.titleSize, weight: .bold))
                .foregroundStyle(theme.text)

            GroupBox("Current Status") {
                if let st = status {
                    VStack(spacing: theme.spacingS) {
                        budgetBar(st)
                        HStack(spacing: theme.spacingL) {
                            statLabel("Total", value: fmt(st["total"]))
                            statLabel("Used", value: fmt(st["used"]))
                            statLabel("Remaining", value: fmt(st["remaining"]))
                        }
                        if let exceeded = st["is_exceeded"] as? Bool, exceeded {
                            Text("Budget Exceeded!").foregroundStyle(.red).font(.caption)
                        }
                    }
                } else {
                    Text("No budget set").foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.horizontal, theme.spacingM)

            Button("Refresh Status") { refreshStatus() }
                .disabled(isRefreshing)

            Divider()

            GroupBox("Configure Budget") {
                VStack(spacing: theme.spacingS) {
                    HStack {
                        Text("Total Tokens")
                        Spacer()
                        TextField("", value: $totalBudget, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                    HStack {
                        Text("Warn %")
                        Spacer()
                        Slider(value: Binding(
                            get: { Double(warnPercent) },
                            set: { warnPercent = Int($0) }
                        ), in: 50...100, step: 5) {
                            Text("\(warnPercent)%")
                        }
                        .frame(width: 150)
                    }
                    Toggle("Hard Limit", isOn: $hardLimit)
                    Button("Set Budget") { setBudget() }
                        .disabled(isSetting)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, theme.spacingM)

            if let err = errorMsg {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            Spacer()
        }
        .navigationTitle("Token Budget")
        .onAppear { refreshStatus() }
    }

    private func budgetBar(_ st: [String: Any]) -> some View {
        let pct = st["percent"] as? Double ?? 0
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.surfaceSecondary)
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(pct > Double(warnPercent) ? .orange : theme.accent)
                        .frame(width: geo.size.width * min(pct / 100, 1.0), height: 12)
                }
            }
            .frame(height: 12)
            Text(String(format: "%.1f%% used", pct))
                .font(.caption).foregroundStyle(theme.textTertiary)
        }
    }

    private func statLabel(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(theme.textTertiary)
            Text(value).font(.system(size: theme.smallTextSize, weight: .medium))
        }
    }

    private func fmt(_ val: Any?) -> String {
        guard let n = val as? Int else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func refreshStatus() {
        isRefreshing = true
        Task {
            do {
                status = try await bridge.ipcClient!.budgetStatus()
            } catch {
                errorMsg = BridgeError.sanitize(error)
                logger.error("budgetStatus failed: \(error.localizedDescription)")
            }
            isRefreshing = false
        }
    }

    private func setBudget() {
        isSetting = true
        Task {
            do {
                _ = try await bridge.ipcClient!.budgetSet(
                    totalBudget: totalBudget, warnPercent: warnPercent, hardLimit: hardLimit
                )
                logger.info("Budget set: \(totalBudget) tokens")
                refreshStatus()
            } catch {
                errorMsg = BridgeError.sanitize(error)
                logger.error("budgetSet failed: \(error.localizedDescription)")
            }
            isSetting = false
        }
    }
}
