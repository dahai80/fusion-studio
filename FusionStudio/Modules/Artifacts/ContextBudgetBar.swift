import SwiftUI
import os.log

private let log = Logger(subsystem: "com.fusion.studio", category: "ContextBudgetBar")

struct ContextBudgetBar: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    let sessionId: String
    @State private var used: Int = 0
    @State private var total: Int = 32768
    @State private var isLoading: Bool = false

    private var ratio: Double { total > 0 ? Double(used) / Double(total) : 0 }
    private var ratioColor: Color {
        if ratio > 0.9 { return theme.danger }
        if ratio > 0.7 { return .yellow }
        return theme.accent
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Context Budget")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text("\(used)/\(total)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ratioColor)
            }
            ProgressView(value: ratio)
                .progressViewStyle(.linear)
                .tint(ratioColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.cardBackground)
        .cornerRadius(6)
        .onAppear { fetchBudget() }
    }

    private func fetchBudget() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.contextBudget(sessionId: sessionId)
                DispatchQueue.main.async {
                    self.used = result["used_tokens"] as? Int ?? 0
                    self.total = result["total_budget"] as? Int ?? 32768
                    self.isLoading = false
                }
            } catch {
                log.error("ContextBudgetBar fetch failed: \(error.localizedDescription)")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
    }
}
