import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin vRAM View (#82)

struct PluginVramView: View {
    @StateObject private var pm = PluginManager.shared
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            vramToolbar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    vramOverview
                    vramBreakdown
                }
                .padding(16)
            }
        }
        .background(theme.surfacePrimary)
        .onAppear { Task { await pm.fetchVramUsage() } }
    }

    private var vramToolbar: some View {
        HStack {
            Text(I18nManager.shared.t(.psvc_vram_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: { Task { await pm.fetchVramUsage() } }) {
                Image(systemName: "arrow.clockwise")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private var vramOverview: some View {
        let total = pm.vramUsage["total_mb"] as? Double ?? 0
        let used = pm.vramUsage["used_mb"] as? Double ?? 0
        let free = total - used
        let ratio = total > 0 ? used / total : 0

        return VStack(alignment: .leading, spacing: 8) {
            Text(I18nManager.shared.t(.psvc_vram_overview))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.surfaceSecondary)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.accent)
                        .frame(width: geo.size.width * CGFloat(ratio))
                }
            }
            .frame(height: 20)
            HStack {
                Label(I18nManager.shared.tf(.psvc_vram_used_fmt, used), systemImage: "memorychip")
                    .font(.caption)
                    .foregroundColor(theme.accent)
                Spacer()
                Label(I18nManager.shared.tf(.psvc_vram_free_fmt, free), systemImage: "memorychip")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Label(I18nManager.shared.tf(.psvc_vram_total_fmt, total), systemImage: "memorychip")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(theme.surfaceSecondary)
        .cornerRadius(8)
    }

    private var vramBreakdown: some View {
        let byPlugin = pm.vramUsage["by_plugin"] as? [[String: Any]] ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text(I18nManager.shared.t(.psvc_vram_byplugin))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            if byPlugin.isEmpty {
                Text(I18nManager.shared.t(.psvc_vram_empty))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(byPlugin.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item["plugin_id"] as? String ?? "")
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.0f MB", item["vram_mb"] as? Double ?? 0))
                            .font(.caption)
                            .foregroundColor(theme.accent)
                    }
                    .padding(6)
                    .background(theme.surfaceSecondary)
                    .cornerRadius(4)
                }
            }
        }
    }
}
