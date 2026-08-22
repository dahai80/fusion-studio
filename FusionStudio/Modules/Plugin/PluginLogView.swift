import SwiftUI
import os.log

private let log = Logger(subsystem: "com.fusion.studio", category: "PluginLogView")

struct PluginLogView: View {
    @EnvironmentObject var bridge: PluginBridge
    @Environment(\.studioTheme) private var theme
    @State private var levelFilter: String = "all"
    @State private var pluginFilter: String = ""
    private let levels = ["all", "debug", "info", "warn", "error"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker(I18nManager.shared.t(.plugin_log_filter_level), selection: $levelFilter) { ForEach(levels, id: \.self) { Text($0) } }.frame(width: 100)
                TextField(I18nManager.shared.t(.plugin_log_ph_plugin_id), text: $pluginFilter).textFieldStyle(.plain).padding(6).background(theme.inputBg).cornerRadius(6).frame(width: 120)
                Spacer()
                Button(I18nManager.shared.t(.plugin_log_btn_refresh)) { bridge.fetchLogs(pluginId: pluginFilter.isEmpty ? nil : pluginFilter, level: levelFilter == "all" ? nil : levelFilter) }.font(.system(size: 11)).foregroundStyle(theme.accent).buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.vertical, 8).background(theme.surfaceSecondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredEntries) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(entry.level.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(levelColor(entry.level)).frame(width: 36, alignment: .leading)
                            Text(entry.pluginId).font(.system(size: 10)).foregroundStyle(theme.textTertiary).frame(width: 60, alignment: .leading)
                            Text(entry.message).font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.text).lineLimit(3)
                            Spacer()
                            Text(entry.timestamp).font(.system(size: 9)).foregroundStyle(theme.textTertiary)
                        }.padding(.vertical, 2).padding(.horizontal, 6)
                    }
                    if filteredEntries.isEmpty { Text(I18nManager.shared.t(.plugin_log_msg_empty)).foregroundStyle(theme.textTertiary).frame(maxWidth: .infinity, alignment: .center).padding(.top, 40) }
                }.padding(16)
            }
        }.onAppear { bridge.fetchLogs(); log.info("PluginLogView appeared") }
    }

    private var filteredEntries: [PluginLogEntry] {
        bridge.logEntries.filter { e in
            (levelFilter == "all" || e.level == levelFilter) && (pluginFilter.isEmpty || e.pluginId.contains(pluginFilter))
        }
    }

    private func levelColor(_ level: String) -> Color {
        switch level { case "error": theme.accentDestructive; case "warn": .yellow; case "debug": .gray; default: theme.accent }
    }
}
