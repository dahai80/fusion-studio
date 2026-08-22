import SwiftUI
import os.log

private let log = Logger(subsystem: "com.fusion.studio", category: "PluginCatalogView")

struct PluginCatalogView: View {
    @EnvironmentObject var bridge: PluginBridge
    @Environment(\.studioTheme) private var theme
    @State private var filterCategory: String = "all"
    @State private var searchText: String = ""

    private let categories = ["all", "codingPlan", "contextCompress", "mlxInference", "terminalProxy", "fileIndex", "quantization", "visualBackend", "custom"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    TextField(I18nManager.shared.t(.plugin_ph_search), text: $searchText)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(theme.inputBg)
                        .cornerRadius(6)
                    Picker(I18nManager.shared.t(.plugin_filter_category), selection: $filterCategory) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    .frame(width: 140)
                }

                ForEach(filteredPlugins) { plugin in
                    pluginRow(plugin)
                }

                if filteredPlugins.isEmpty {
                    Text(I18nManager.shared.t(.plugin_msg_empty))
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding(16)
        }
        .onAppear {
            bridge.listPlugins()
            log.info("PluginCatalogView appeared")
        }
    }

    private var filteredPlugins: [PluginListItem] {
        bridge.plugins.filter { p in
            (filterCategory == "all" || p.category == filterCategory) &&
            (searchText.isEmpty || p.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    private func pluginRow(_ plugin: PluginListItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 16))
                .foregroundStyle(theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(plugin.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.text)
                    Text(plugin.version)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
                Text(plugin.description)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if plugin.installed {
                Button(action: {
                    bridge.uninstallPlugin(pluginId: plugin.id) { _ in bridge.listPlugins() }
                }) {
                    Text(I18nManager.shared.t(.plugin_btn_uninstall))
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accentDestructive)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    bridge.installPlugin(pluginId: plugin.id) { _ in bridge.listPlugins() }
                }) {
                    Text(I18nManager.shared.t(.plugin_btn_install))
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(theme.surfaceSecondary)
        .cornerRadius(8)
    }
}
