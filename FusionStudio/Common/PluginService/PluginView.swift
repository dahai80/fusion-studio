import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin View (Tab Container)

struct PluginView: View {
    @StateObject private var pluginManager = PluginManager.shared
    @Environment(\.studioTheme) private var theme
    @State private var selectedTab: PluginTab = .installed
    @State private var showFilePicker = false
    @State private var showCreateTemplate = false
    @State private var templateName = ""
    @State private var templateAuthor = ""

    enum PluginTab: String, CaseIterable {
        case installed
        case market
        case config
        case status
        case tokens
        case vram
        case logs
        case mcp
        case develop

        var localizedName: String {
            switch self {
            case .installed: return I18nManager.shared.t(.psvc_tab_installed)
            case .market:    return I18nManager.shared.t(.psvc_tab_market)
            case .config:    return I18nManager.shared.t(.psvc_tab_config)
            case .status:    return I18nManager.shared.t(.psvc_tab_status)
            case .tokens:    return I18nManager.shared.t(.psvc_tab_tokens)
            case .vram:      return I18nManager.shared.t(.psvc_tab_vram)
            case .logs:      return I18nManager.shared.t(.psvc_tab_logs)
            case .mcp:       return I18nManager.shared.t(.psvc_tab_mcp)
            case .develop:   return I18nManager.shared.t(.psvc_tab_develop)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(PluginTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            switch selectedTab {
            case .installed:
                InstalledPluginsView()
            case .market:
                PluginMarketView()
            case .config:
                PluginConfigView()
            case .status:
                PluginStatusView()
            case .tokens:
                PluginTokenDashboard()
            case .vram:
                PluginVramView()
            case .logs:
                PluginLogViewer()
            case .mcp:
                PluginMcpView()
            case .develop:
                PluginDeveloperView()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { showFilePicker = true }) {
                    Label(I18nManager.shared.t(.psvc_tb_install), systemImage: "plus")
                }
                Button(action: { pluginManager.scanInstalledPlugins() }) {
                    Label(I18nManager.shared.t(.psvc_tb_refresh), systemImage: "arrow.clockwise")
                }
                Button(action: { pluginManager.openPluginFolder() }) {
                    Label(I18nManager.shared.t(.psvc_tb_folder), systemImage: "folder")
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder, .zip],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                _ = pluginManager.installPlugin(at: url)
            }
        }
        .sheet(isPresented: $showCreateTemplate) {
            createTemplateSheet
        }
    }

    private var createTemplateSheet: some View {
        VStack(spacing: 16) {
            Text(I18nManager.shared.t(.psvc_tmpl_title))
                .font(.title2)
                .bold()

            TextField(I18nManager.shared.t(.psvc_tmpl_name_ph), text: $templateName)
                .textFieldStyle(.roundedBorder)

            TextField(I18nManager.shared.t(.psvc_tmpl_author_ph), text: $templateAuthor)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button(I18nManager.shared.t(.psvc_tmpl_cancel)) { showCreateTemplate = false }
                    .buttonStyle(.bordered)
                Button(I18nManager.shared.t(.psvc_tmpl_create)) {
                    if let url = pluginManager.createPluginTemplate(name: templateName, author: templateAuthor) {
                        NSWorkspace.shared.open(url)
                    }
                    templateName = ""
                    templateAuthor = ""
                    showCreateTemplate = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(templateName.isEmpty || templateAuthor.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func tabIcon(_ tab: PluginTab) -> String {
        switch tab {
        case .installed: return "square.grid.3x2"
        case .market:    return "bag"
        case .config:    return "gearshape"
        case .status:    return "heartbeat"
        case .tokens:    return "chart.bar.xaxis"
        case .vram:      return "memorychip"
        case .logs:      return "text.justify.leading"
        case .mcp:       return "network"
        case .develop:   return "hammer"
        }
    }
}
