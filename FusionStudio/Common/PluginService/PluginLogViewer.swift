import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin Log Viewer (#83)

struct PluginLogViewer: View {
    @StateObject private var pm = PluginManager.shared
    @Environment(\.studioTheme) private var theme
    @State private var selectedPlugin: String = "all"
    @State private var levelFilter: String = "all"
    @State private var searchQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            logToolbar
            Divider()
            logList
        }
        .background(theme.surfacePrimary)
        .onAppear { Task { await pm.fetchLogs() } }
    }

    private var logToolbar: some View {
        HStack {
            Text(I18nManager.shared.t(.psvc_log_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 4) {
                logFilterChip(I18nManager.shared.t(.psvc_filter_all), value: "all")
                logFilterChip("INFO", value: "INFO")
                logFilterChip("WARN", value: "WARNING")
                logFilterChip("ERROR", value: "ERROR")
            }
            TextField(I18nManager.shared.t(.psvc_log_search_ph), text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .font(.caption)
            Button(action: { Task { await pm.fetchLogs() } }) {
                Image(systemName: "arrow.clockwise")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private func logFilterChip(_ label: String, value: String) -> some View {
        Button(action: { levelFilter = value }) {
            Text(label)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(levelFilter == value ? theme.accentSoft : theme.surfacePrimary)
                .foregroundColor(levelFilter == value ? theme.accent : theme.textSecondary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var logList: some View {
        let filtered = pm.logEntries.filter { entry in
            if levelFilter != "all" && entry.level != levelFilter { return false }
            if !searchQuery.isEmpty && !entry.message.localizedCaseInsensitiveContains(searchQuery) { return false }
            return true
        }

        return List {
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.justify.leading")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(I18nManager.shared.t(.psvc_log_empty))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(filtered) { entry in
                    HStack(alignment: .top, spacing: 6) {
                        Text(entry.timestamp)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)
                        Text(entry.level)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(levelColor(entry.level))
                            .frame(width: 40, alignment: .leading)
                        Text(entry.pluginId)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(theme.accent)
                            .frame(width: 80, alignment: .leading)
                        Text(entry.message)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .listStyle(.plain)
    }

    private func levelColor(_ level: String) -> Color {
        switch level {
        case "ERROR": return .red
        case "WARNING": return .orange
        case "INFO": return .green
        default: return .secondary
        }
    }
}
