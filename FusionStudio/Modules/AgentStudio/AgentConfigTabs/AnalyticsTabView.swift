import SwiftUI
import Combine
import os.log

// MARK: - AnalyticsTabView

struct AnalyticsTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var selectedRange = "week"

    private let ranges = ["day", "week", "month"]

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                HStack {
                    Text("Analytics")
                        .font(.system(size: theme.titleSize, weight: .bold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Picker("Range", selection: $selectedRange) {
                        ForEach(ranges, id: \.self) { r in
                            Text(r.capitalized).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: selectedRange) { _, newRange in
                        Task { await bridge.fetchAnalytics(range: newRange) }
                    }
                }
                .padding(theme.spacingM)

                analyticsCards
                agentUsageList
                Spacer()
            }
        }
        .onAppear { Task { await bridge.fetchAnalytics(range: selectedRange) } }
    }

    private var analyticsCards: some View {
        let d = bridge.configState.analyticsData
        let totalRequests = d["total_requests"] as? Int ?? 0
        let totalTokens = d["total_tokens"] as? Int ?? 0
        let avgLatency = d["avg_latency_ms"] as? Double ?? 0
        let errorRate = d["error_rate"] as? Double ?? 0
        let cards: [(String, String, String, TagColor)] = [
            ("Total Requests", "\(totalRequests)", "text.bubble", .blue),
            ("Total Tokens", "\(totalTokens)", "number", .blue),
            ("Avg Latency", String(format: "%.0fms", avgLatency), "clock", .purple),
            ("Error Rate", String(format: "%.1f%%", errorRate), "exclamationmark.triangle", errorRate > 5 ? .red : .green),
        ]
        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
        ], spacing: theme.spacingM) {
            ForEach(cards, id: \.0) { card in
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Image(systemName: card.2)
                            .foregroundStyle(theme.accent)
                        Spacer()
                        Text(card.0)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Text(card.1)
                        .font(.system(size: theme.titleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text)
                }
                .padding(theme.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .fill(theme.surfaceSecondary)
                )
            }
        }
        .padding(.horizontal, theme.spacingM)
    }

    private var agentUsageList: some View {
        let perAgent = bridge.configState.analyticsData["per_agent"] as? [[String: Any]] ?? []
        return VStack(alignment: .leading, spacing: 0) {
            if perAgent.isEmpty {
                Text("No per-agent analytics data")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(theme.spacingL)
            } else {
                ForEach(Array(perAgent.enumerated()), id: \.offset) { idx, entry in
                    let name = entry["name"] as? String ?? entry["agent_id"] as? String ?? "Unknown"
                    let reqs = entry["requests"] as? Int ?? 0
                    let tokens = entry["tokens"] as? Int ?? 0
                    HStack {
                        Text(name)
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.text)
                        Spacer()
                        Text("\(reqs) reqs")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                        Text("\(tokens) tok")
                            .font(.system(size: theme.captionSize, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.text)
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(idx % 2 == 0 ? theme.surfaceSecondary : theme.surfacePrimary)
                }
            }
        }
        .padding(.horizontal, theme.spacingM)
    }
}
