import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin Status View (#80)

struct PluginStatusView: View {
    @StateObject private var pm = PluginManager.shared
    @Environment(\.studioTheme) private var theme
    @State private var filterState: String = "all"

    var body: some View {
        VStack(spacing: 0) {
            statusToolbar
            Divider()
            if pm.pluginStates.isEmpty {
                emptyStatus
            } else {
                statusList
            }
        }
        .background(theme.surfacePrimary)
        .onAppear { Task { await pm.fetchPluginStates() } }
    }

    private var statusToolbar: some View {
        HStack {
            Text(I18nManager.shared.t(.psvc_status_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 4) {
                statusFilterChip(I18nManager.shared.t(.psvc_filter_all), value: "all")
                statusFilterChip(I18nManager.shared.t(.psvc_status_filter_run), value: "enabled")
                statusFilterChip(I18nManager.shared.t(.psvc_status_filter_crash), value: "crashed")
                statusFilterChip(I18nManager.shared.t(.psvc_status_filter_timeout), value: "timeout")
            }
            Button(action: { Task { await pm.fetchPluginStates() } }) {
                Image(systemName: "arrow.clockwise")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private func statusFilterChip(_ label: String, value: String) -> some View {
        Button(action: { filterState = value }) {
            Text(label)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(filterState == value ? theme.accentSoft : theme.surfacePrimary)
                .foregroundColor(filterState == value ? theme.accent : theme.textSecondary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var emptyStatus: some View {
        VStack(spacing: 8) {
            Image(systemName: "heartbeat")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(I18nManager.shared.t(.psvc_status_empty))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusList: some View {
        List {
            let filtered = filterState == "all" ? pm.pluginStates :
                pm.pluginStates.filter { $0["state"] as? String == filterState }
            ForEach(Array(filtered.enumerated()), id: \.offset) { _, item in
                HStack {
                    let state = item["state"] as? String ?? "unknown"
                    Circle()
                        .fill(stateColor(state))
                        .frame(width: 8, height: 8)
                    Text(item["plugin_id"] as? String ?? "")
                        .font(.subheadline)
                    Spacer()
                    Text(state)
                        .font(.caption)
                        .foregroundColor(stateColor(state))
                    if let count = item["restart_count"] as? Int, count > 0 {
                        Text(I18nManager.shared.tf(.psvc_status_restart_fmt, count))
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "enabled", "loaded": return .green
        case "crashed": return .red
        case "timeout": return .orange
        case "disabled": return .gray
        default: return .secondary
        }
    }
}
