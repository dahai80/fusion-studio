import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Installed Plugins

struct InstalledPluginsView: View {
    @StateObject private var pluginManager = PluginManager.shared
    @Environment(\.studioTheme) private var theme
    @State private var selectedPlugin: Plugin?
    @State private var showUninstallAlert = false
    @State private var selectedCategory: PluginCategory?

    private var filteredPlugins: [Plugin] {
        if let cat = selectedCategory {
            return pluginManager.plugins.filter { $0.manifest.category == cat }
        }
        return pluginManager.plugins
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                categoryFilter
                List(selection: $selectedPlugin) {
                    Section(I18nManager.shared.t(.psvc_sec_builtin)) {
                        ForEach(filteredPlugins.filter { $0.installPath == "builtin" }) { plugin in
                            PluginRow(plugin: plugin)
                                .tag(plugin)
                        }
                    }
                    Section(I18nManager.shared.t(.psvc_sec_user)) {
                        let userPlugins = filteredPlugins.filter { $0.installPath != "builtin" }
                        if userPlugins.isEmpty {
                            Text(I18nManager.shared.t(.psvc_user_empty))
                                .foregroundColor(.secondary)
                        }
                        ForEach(userPlugins) { plugin in
                            PluginRow(plugin: plugin)
                                .tag(plugin)
                                .contextMenu {
                                    Button(plugin.state == .enabled ? I18nManager.shared.t(.psvc_btn_disable) : I18nManager.shared.t(.psvc_btn_enable)) {
                                        if plugin.state == .enabled {
                                            pluginManager.disablePlugin(plugin.id)
                                        } else {
                                            pluginManager.enablePlugin(plugin.id)
                                        }
                                    }
                                    Button(I18nManager.shared.t(.psvc_btn_uninstall), role: .destructive) {
                                        selectedPlugin = plugin
                                        showUninstallAlert = true
                                    }
                                }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 300)

            if let plugin = selectedPlugin {
                PluginDetailView(plugin: plugin)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(I18nManager.shared.t(.psvc_installed_empty))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .alert(I18nManager.shared.t(.psvc_uninstall_title), isPresented: $showUninstallAlert) {
            Button(I18nManager.shared.t(.psvc_tmpl_cancel), role: .cancel) {}
            Button(I18nManager.shared.t(.psvc_btn_uninstall), role: .destructive) {
                if let plugin = selectedPlugin {
                    pluginManager.uninstallPlugin(plugin.id)
                }
            }
        } message: {
            Text(I18nManager.shared.t(.psvc_uninstall_msg))
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button(I18nManager.shared.t(.psvc_filter_all)) { selectedCategory = nil }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(selectedCategory == nil ? Color.accentColor : nil)
                ForEach(PluginCategory.allCases, id: \.self) { cat in
                    Button(cat.label) { selectedCategory = cat }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(selectedCategory == cat ? Color.accentColor : nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct PluginRow: View {
    let plugin: Plugin
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: plugin.state.icon)
                .foregroundColor(plugin.state.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(plugin.manifest.name)
                        .font(.headline)
                    Spacer()
                    HubTagBadge(text: plugin.manifest.category.label, color: .accentColor)
                }
                Text(plugin.manifest.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("v\(plugin.manifest.version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if plugin.manifest.vramMb > 0 {
                        Label("\(plugin.manifest.vramMb) MB", systemImage: "memorychip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if plugin.installPath != "builtin" {
                        Text(plugin.installDate, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
