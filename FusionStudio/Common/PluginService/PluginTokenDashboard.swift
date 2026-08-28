import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin Token Dashboard (#81)

struct PluginTokenDashboard: View {
    @StateObject private var pm = PluginManager.shared
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            tokenToolbar
            Divider()
            if pm.tokenRecords.isEmpty {
                emptyToken
            } else {
                tokenContent
            }
        }
        .background(theme.surfacePrimary)
        .onAppear { Task { await pm.fetchTokenRecords() } }
    }

    private var tokenToolbar: some View {
        HStack {
            Text(I18nManager.shared.t(.psvc_token_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: { Task { await pm.fetchTokenRecords() } }) {
                Image(systemName: "arrow.clockwise")
            }
            Button(action: { Task { await pm.pruneTokenRecords() } }) {
                Image(systemName: "trash")
            }
            .help(I18nManager.shared.t(.psvc_token_prune))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var emptyToken: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(I18nManager.shared.t(.psvc_token_empty))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tokenContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                let byPlugin = Dictionary(grouping: pm.tokenRecords) { $0["plugin_id"] as? String ?? "unknown" }
                ForEach(Array(byPlugin.keys.sorted()), id: \.self) { pluginId in
                    let records = byPlugin[pluginId] ?? []
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pluginId)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        let totalTokens = records.compactMap { $0["total_tokens"] as? Int }.reduce(0, +)
                        let wallSecs = records.compactMap { $0["wall_seconds"] as? Double }.reduce(0, +)
                        HStack(spacing: 12) {
                            Label("\(totalTokens) tokens", systemImage: "number")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                            Label(String(format: "%.1fs", wallSecs), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }

                        let byKind = Dictionary(grouping: records) { $0["kind"] as? String ?? "unknown" }
                        HStack(spacing: 4) {
                            ForEach(Array(byKind.keys.sorted()), id: \.self) { kind in
                                let count = byKind[kind]?.count ?? 0
                                Text(kind)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(kindColor(kind).opacity(0.2))
                                    .foregroundColor(kindColor(kind))
                                    .cornerRadius(3)
                                Text("\(count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(8)
                }
            }
            .padding(16)
        }
    }

    private func kindColor(_ kind: String) -> Color {
        switch kind {
        case "PLUGIN_LOCAL": return .blue
        case "PLUGIN_REMOTE": return .purple
        case "CLAUDE_LOCAL": return .green
        case "CLAUDE_REMOTE": return .orange
        default: return .gray
        }
    }
}
