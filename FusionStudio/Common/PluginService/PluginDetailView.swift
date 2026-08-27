import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin Detail View

struct PluginDetailView: View {
    let plugin: Plugin
    @StateObject private var pluginManager = PluginManager.shared
    @Environment(\.studioTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: plugin.manifest.displayIcon)
                        .font(.title)
                        .foregroundColor(.accentColor)
                    Text(plugin.manifest.name)
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    PluginStateBadge(state: plugin.state)
                }
                .padding(.horizontal)

                Divider()

                GroupBox(I18nManager.shared.t(.psvc_detail_basic)) {
                    VStack(alignment: .leading, spacing: 6) {
                        PluginDetailRow(I18nManager.shared.t(.psvc_detail_id), plugin.manifest.id)
                        PluginDetailRow(I18nManager.shared.t(.psvc_detail_version), plugin.manifest.version)
                        PluginDetailRow(I18nManager.shared.t(.psvc_detail_category), plugin.manifest.category.label)
                        PluginDetailRow(I18nManager.shared.t(.psvc_detail_desc), plugin.manifest.description)
                        if let author = plugin.manifest.author {
                            PluginDetailRow(I18nManager.shared.t(.psvc_detail_author), author)
                        }
                        if let minVer = plugin.manifest.minAppVersion {
                            PluginDetailRow(I18nManager.shared.t(.psvc_detail_minver), "Fusion Studio \(minVer)")
                        }
                        PluginDetailRow(I18nManager.shared.t(.psvc_detail_entry), plugin.manifest.entryPoint ?? "-")
                        PluginDetailRow(I18nManager.shared.t(.psvc_detail_path), plugin.installPath)
                        if plugin.installPath != "builtin" {
                            PluginDetailRow(I18nManager.shared.t(.psvc_detail_instime), plugin.installDate.formatted(date: .numeric, time: .shortened))
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                GroupBox(I18nManager.shared.t(.psvc_detail_caps)) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(plugin.manifest.capabilities, id: \.rawValue) { cap in
                            HStack {
                                Image(systemName: cap.icon)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 16)
                                Text(cap.label)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        if plugin.manifest.capabilities.isEmpty {
                            Text(I18nManager.shared.t(.psvc_detail_caps_empty))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                if !plugin.manifest.params.isEmpty {
                    GroupBox(I18nManager.shared.t(.psvc_detail_params)) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(plugin.manifest.params) { param in
                                HStack(alignment: .top) {
                                    Text(param.name)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(width: 100, alignment: .leading)
                                    Text(param.type)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 50, alignment: .leading)
                                    if param.required {
                                        Text(I18nManager.shared.t(.psvc_param_required))
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.red.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                    Text(param.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .padding(.horizontal)
                }

                GroupBox(I18nManager.shared.t(.psvc_detail_runtime)) {
                    VStack(alignment: .leading, spacing: 6) {
                        PluginDetailRow(I18nManager.shared.t(.psvc_detail_sandbox), plugin.manifest.sandboxMode.label)
                        PluginDetailRow(I18nManager.shared.t(.psvc_detail_vram), plugin.manifest.vramMb > 0 ? "\(plugin.manifest.vramMb) MB" : I18nManager.shared.t(.psvc_detail_vram_none))
                        PluginDetailRow(I18nManager.shared.t(.psvc_detail_mounted), plugin.manifest.defaultMounted ? I18nManager.shared.t(.psvc_yes) : I18nManager.shared.t(.psvc_no))
                        if let timeout = plugin.manifest.timeoutSeconds {
                            PluginDetailRow(I18nManager.shared.t(.psvc_detail_timeout), "\(timeout) s")
                        }
                        if !plugin.manifest.dependsOn.isEmpty {
                            PluginDetailRow(I18nManager.shared.t(.psvc_detail_deps), plugin.manifest.dependsOn.joined(separator: ", "))
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                Spacer()

                HStack {
                    Spacer()
                    if plugin.installPath != "builtin" {
                        if plugin.state == .enabled {
                            Button(I18nManager.shared.t(.psvc_btn_disable)) { pluginManager.disablePlugin(plugin.id) }
                                .buttonStyle(.bordered)
                        } else {
                            Button(I18nManager.shared.t(.psvc_btn_enable)) { pluginManager.enablePlugin(plugin.id) }
                                .buttonStyle(.borderedProminent)
                        }
                        Button(I18nManager.shared.t(.psvc_btn_uninstall), role: .destructive) { pluginManager.uninstallPlugin(plugin.id) }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                }
                .padding()
            }
            .padding(.vertical)
        }
    }
}

struct PluginStateBadge: View {
    let state: PluginState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.icon)
                .font(.caption2)
            Text(state.label)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(state.color.opacity(0.1))
        .foregroundStyle(state.color)
        .cornerRadius(6)
    }
}

struct PluginDetailRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}
