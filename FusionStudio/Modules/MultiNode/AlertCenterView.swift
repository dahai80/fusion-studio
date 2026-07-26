import SwiftUI
import os.log

private let alertLog = Logger(subsystem: "com.fusion.studio", category: "AlertCenter")

struct AlertCenterView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme

    @State private var selectedTab: AlertTab = .active
    @State private var acknowledgedAlerts: Set<String> = []

    enum AlertTab: String, CaseIterable {
        case active = "活跃告警"
        case suggestions = "智能建议"
        case history = "告警历史"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: "告警中心", subtitle: "集群异常检测与智能建议")

                tabBar

                switch selectedTab {
                case .active:
                    activeAlertsSection
                case .suggestions:
                    suggestionsSection
                case .history:
                    historySection
                }
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
        .onAppear { engine.startPolling() }
        .onDisappear { engine.stopPolling() }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AlertTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(theme.springDefault) { selectedTab = tab }
                } label: {
                    HStack(spacing: theme.spacingXS) {
                        Text(tab.rawValue)
                            .font(.system(size: theme.smallTextSize, weight: tab == selectedTab ? .semibold : .regular))
                        if tab == .active {
                            let count = engine.alerts.filter { !($0.acknowledged ?? false) }.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: theme.captionSize, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(theme.redDot))
                            }
                        }
                    }
                    .foregroundStyle(tab == selectedTab ? theme.accent : theme.textSecondary)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        tab == selectedTab ? theme.accentSoft : Color.clear,
                        in: RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingM)
    }

    private var activeAlerts: [AlertItem] {
        engine.alerts.filter { !($0.acknowledged ?? false) && !acknowledgedAlerts.contains($0.id) }
    }

    private var activeAlertsSection: some View {
        ListGroup {
            StudioSectionHeader(title: "活跃告警 (\(activeAlerts.count))")

            if activeAlerts.isEmpty {
                emptyState(icon: "checkmark.shield", text: "无活跃告警，集群运行正常")
            }

            ForEach(activeAlerts) { alert in
                alertRow(alert)
            }
        }
    }

    private var suggestionsSection: some View {
        ListGroup {
            StudioSectionHeader(title: "智能建议 (\(engine.suggestions.count))")

            if engine.suggestions.isEmpty {
                emptyState(icon: "lightbulb", text: "暂无优化建议")
            }

            ForEach(engine.suggestions) { suggestion in
                suggestionRow(suggestion)
            }
        }
    }

    private var historySection: some View {
        ListGroup {
            StudioSectionHeader(title: "告警历史")

            if engine.alerts.isEmpty {
                emptyState(icon: "clock", text: "暂无告警历史")
            }

            ForEach(engine.alerts) { alert in
                alertRow(alert, showAck: true)
            }
        }
    }

    @ViewBuilder
    private func alertRow(_ alert: AlertItem, showAck: Bool = false) -> some View {
        HStack(spacing: theme.spacingM) {
            Image(systemName: alert.isCritical ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: theme.bodySize))
                .foregroundStyle(alert.isCritical ? theme.redDot : theme.amberDot)

            VStack(alignment: .leading, spacing: 2) {
                if let title = alert.title {
                    Text(title)
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                }
                Text(alert.message)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                HStack(spacing: theme.spacingS) {
                    if let ts = alert.createdAt {
                        Text(formatTimestamp(ts))
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    if let nodeId = alert.nodeId {
                        Text("Node: \(nodeId)")
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }

            Spacer()

            if !showAck {
                FusionButton("确认", style: .ghost, size: .small) {
                    withAnimation(theme.springSnappy) {
                        _ = acknowledgedAlerts.insert(alert.id)
                    }
                }
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    @ViewBuilder
    private func suggestionRow(_ suggestion: OptimizationSuggestion) -> some View {
        HStack(spacing: theme.spacingM) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: theme.bodySize))
                .foregroundStyle(theme.amberDot)

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                Text(suggestion.suggestion)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(3)
                HStack(spacing: theme.spacingS) {
                    Text(suggestion.category)
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.accent)
                    Text(suggestion.priority)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    @ViewBuilder
    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text(text)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing2XL)
    }

    private func formatTimestamp(_ ts: Double) -> String {
        let date = Date(timeIntervalSince1970: ts)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
