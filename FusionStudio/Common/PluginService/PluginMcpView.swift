import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin MCP View (#84)

struct PluginMcpView: View {
    @StateObject private var pm = PluginManager.shared
    @Environment(\.studioTheme) private var theme
    @State private var selectedSession: [String: Any]?

    var body: some View {
        VStack(spacing: 0) {
            mcpToolbar
            Divider()
            if pm.mcpSessions.isEmpty {
                emptyMcp
            } else {
                mcpContent
            }
        }
        .background(theme.surfacePrimary)
        .onAppear { Task { await pm.fetchMcpSessions() } }
    }

    private var mcpToolbar: some View {
        HStack {
            Text(I18nManager.shared.t(.psvc_mcp_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Text(I18nManager.shared.tf(.psvc_mcp_session_fmt, pm.mcpSessions.count))
                .font(.caption)
                .foregroundColor(.secondary)
            Button(action: { Task { await pm.fetchMcpSessions() } }) {
                Image(systemName: "arrow.clockwise")
            }
            Button(action: { Task { await pm.pruneMcpSessions() } }) {
                Image(systemName: "trash")
            }
            .help(I18nManager.shared.t(.psvc_mcp_prune))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var emptyMcp: some View {
        VStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(I18nManager.shared.t(.psvc_mcp_empty))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mcpContent: some View {
        List {
            ForEach(Array(pm.mcpSessions.enumerated()), id: \.offset) { _, session in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(session["session_id"] as? String ?? "")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(session["transport"] as? String ?? "stdio")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(theme.accentSoft)
                            .cornerRadius(3)
                    }
                    if let calls = session["call_count"] as? Int {
                        Text(I18nManager.shared.tf(.psvc_mcp_calls_fmt, calls))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if let rateLimit = session["rate_limit_remaining"] as? Int {
                        HStack(spacing: 4) {
                            Text(I18nManager.shared.t(.psvc_mcp_ratelimit))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(I18nManager.shared.tf(.psvc_mcp_remaining_fmt, rateLimit))
                                .font(.caption2)
                                .foregroundColor(rateLimit < 10 ? .red : .green)
                        }
                    }
                }
                .padding(8)
                .background(theme.surfaceSecondary)
                .cornerRadius(6)
            }
        }
        .listStyle(.plain)
    }
}
