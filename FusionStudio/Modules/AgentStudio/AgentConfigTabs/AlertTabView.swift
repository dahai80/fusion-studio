import SwiftUI
import Combine
import os.log

// MARK: - AlertTabView

struct AlertTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Alerts")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Refresh", icon: "arrow.clockwise") {
                    Task { await bridge.fetchAlerts() }
                }
            }
            .padding(theme.spacingM)

            if bridge.configState.alerts.isEmpty {
                Spacer()
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.successText)
                    Text("No active alerts")
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.alerts.enumerated()), id: \.offset) { idx, alert in
                        let level = alert["level"] as? String ?? "info"
                        let message = alert["message"] as? String ?? "No message"
                        let source = alert["source"] as? String ?? ""
                        let aid = alert["alert_id"] as? String ?? alert["id"] as? String ?? ""
                        let acknowledged = alert["acknowledged"] as? Bool ?? false
                        StudioRow(label: message, sublabel: source, isLast: idx == bridge.configState.alerts.count - 1) {
                            FusionTag(level, color: alertColor(for: level))
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            if !acknowledged {
                                Button {
                                    Task { await ackAlert(aid) }
                                } label: {
                                    Label("Acknowledge", systemImage: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchAlerts() } }
    }

    private func alertColor(for level: String) -> TagColor {
        switch level {
        case "critical", "error": return .red
        case "warning", "warn": return .orange
        case "info": return .blue
        default: return .gray
        }
    }

    private func ackAlert(_ id: String) async {
        do {
            _ = try await bridge.alertAcknowledge(alertId: id)
            toastManager.show(style: .success, title: "Acknowledged", message: "Alert dismissed")
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}
