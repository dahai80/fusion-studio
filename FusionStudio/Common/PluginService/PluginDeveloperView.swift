import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin Developer

struct PluginDeveloperView: View {
    @StateObject private var pluginManager = PluginManager.shared
    @Environment(\.studioTheme) private var theme
    @State private var templateName = ""
    @State private var templateAuthor = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox(I18nManager.shared.t(.psvc_dev_quick)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(I18nManager.shared.t(.psvc_dev_guide_title))
                            .font(.headline)
                        Text(I18nManager.shared.t(.psvc_dev_guide_desc))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(pluginManager.pluginDir.path)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.accentColor)
                            Button(I18nManager.shared.t(.psvc_dev_open)) { pluginManager.openPluginFolder() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                GroupBox(I18nManager.shared.t(.psvc_dev_tmpl_gen)) {
                    VStack(spacing: 12) {
                        Text(I18nManager.shared.t(.psvc_dev_tmpl_desc))
                            .font(.subheadline)
                        HStack {
                            TextField(I18nManager.shared.t(.psvc_tmpl_name_ph), text: $templateName)
                                .textFieldStyle(.roundedBorder)
                            TextField(I18nManager.shared.t(.psvc_tmpl_author_ph), text: $templateAuthor)
                                .textFieldStyle(.roundedBorder)
                            Button(I18nManager.shared.t(.psvc_dev_gen)) {
                                if let url = pluginManager.createPluginTemplate(name: templateName, author: templateAuthor) {
                                    NSWorkspace.shared.open(url)
                                }
                                templateName = ""
                                templateAuthor = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(templateName.isEmpty || templateAuthor.isEmpty)
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                GroupBox(I18nManager.shared.t(.psvc_dev_structure)) {
                    VStack(alignment: .leading, spacing: 4) {
                        CodeLine("my-plugin.plugin/")
                        CodeLine("\u{251c}\u{2500}\u{2500} manifest.json    \(I18nManager.shared.t(.psvc_dev_tree_manifest))")
                        CodeLine("\u{251c}\u{2500}\u{2500} main.py          \(I18nManager.shared.t(.psvc_dev_tree_entry))")
                        CodeLine("\u{251c}\u{2500}\u{2500} assets/          \(I18nManager.shared.t(.psvc_dev_tree_assets))")
                        CodeLine("\u{2514}\u{2500}\u{2500} README.md        \(I18nManager.shared.t(.psvc_dev_tree_readme))")
                    }
                    .padding(8)
                    .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal)

                GroupBox(I18nManager.shared.t(.psvc_dev_sample_title)) {
                    Text("""
                    {
                      "id": "my-plugin",
                      "name": "\(I18nManager.shared.t(.psvc_dev_sample_name))",
                      "version": "0.1.0",
                      "category": "custom",
                      "description": "\(I18nManager.shared.t(.psvc_dev_sample_desc))",
                      "capabilities": ["mcp_tool"],
                      "params": [],
                      "entry_point": "main.py",
                      "default_mounted": false,
                      "vram_mb": 0,
                      "depends_on": [],
                      "sandbox_mode": "inline"
                    }
                    """)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct CodeLine: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
    }
}
