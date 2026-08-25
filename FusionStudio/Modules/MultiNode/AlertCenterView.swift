import SwiftUI
import os.log

private let alertLog = Logger(subsystem: "com.fusion.studio", category: "AlertCenter")

struct AlertCenterView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var selectedTab: AlertTab = .active
    @State private var acknowledgedAlerts: Set<String> = []
    @State private var isExporting = false

    enum AlertTab: String, CaseIterable {
        case active
        case suggestions
        case history
        var localLabel: String {
            switch self {
            case .active: return I18nManager.shared.t(.mn_alert_tab_active)
            case .suggestions: return I18nManager.shared.t(.mn_alert_tab_suggestions)
            case .history: return I18nManager.shared.t(.mn_alert_tab_history)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: i18n.t(.mn_alert_title), subtitle: i18n.t(.mn_alert_subtitle))

                HStack {
                    Spacer()
                    FusionButton(i18n.t(.mn_alert_exportBtn), icon: "arrow.down.doc", style: .secondary, size: .small,
                        isLoading: isExporting) {
                        exportAlertLog()
                    }
                }
                .padding(.horizontal, theme.spacingL)

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
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AlertTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(theme.springDefault) { selectedTab = tab }
                } label: {
                    HStack(spacing: theme.spacingXS) {
                        Text(tab.localLabel)
                            .font(.system(size: theme.smallTextSize, weight: tab == selectedTab ? .semibold : .regular))
                        if tab == .active {
                            let count = engine.alerts.filter { !($0.resolved ?? false) }.count
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
        engine.alerts.filter { !($0.resolved ?? false) && !acknowledgedAlerts.contains($0.id) }
    }

    private var activeAlertsSection: some View {
        ListGroup {
            StudioSectionHeader(title: String(format: i18n.t(.mn_alert_activeTitleFmt), activeAlerts.count))

            if activeAlerts.isEmpty {
                emptyState(icon: "checkmark.shield", text: i18n.t(.mn_alert_activeEmpty))
            }

            ForEach(activeAlerts) { alert in
                alertRow(alert)
            }
        }
    }

    private var suggestionsSection: some View {
        ListGroup {
            StudioSectionHeader(title: String(format: i18n.t(.mn_alert_suggestTitleFmt), engine.suggestions.count))

            if engine.suggestions.isEmpty {
                emptyState(icon: "lightbulb", text: i18n.t(.mn_alert_suggestEmpty))
            }

            ForEach(engine.suggestions) { suggestion in
                suggestionRow(suggestion)
            }
        }
    }

    private var historySection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_alert_historyTitle))

            if engine.alerts.isEmpty {
                emptyState(icon: "clock", text: i18n.t(.mn_alert_historyEmpty))
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
                FusionButton(i18n.t(.mn_alert_ackBtn), style: .ghost, size: .small) {
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

    private func exportAlertLog() {
        isExporting = true
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "fusion-alerts-\(Int(Date().timeIntervalSince1970)).log"
        panel.begin { response in
            isExporting = false
            guard response == .OK, let url = panel.url else { return }
            let lines = engine.alerts.map { alert in
                let ts = alert.createdAt.map { String($0) } ?? "N/A"
                let level = alert.isCritical ? "CRITICAL" : "WARNING"
                let node = alert.nodeId ?? "N/A"
                return "[\(ts)] [\(level)] node=\(node) title=\(alert.title ?? "-") msg=\(alert.message)"
            }
            let content = lines.joined(separator: "\n")
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                alertLog.info("Alert log exported to \(url.path)")
            } catch {
                alertLog.error("Export failed: \(error.localizedDescription)")
            }
        }
    }
}
