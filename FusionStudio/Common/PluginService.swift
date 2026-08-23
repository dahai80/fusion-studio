// Callers: ModuleDetailView.swift:38 → PluginView().
// Affected API: PluginManager (IPC plugin.list), IPCClient.shared.call.
// Data schemas: PluginManifest (aligned with fusion-plugins-ecosystem registry.py PluginManifest.to_dict()),
//   PluginCategory, PluginCapability, PluginParam, PluginState (aligned with lifecycle.py), SandboxMode (schema.py).
// Issue: #77 — align PluginService.swift with fusion-plugins-ecosystem schema.

import Foundation
import SwiftUI
import Combine
import os.log

private let pluginLog = Logger(subsystem: "com.fusion.studio", category: "PluginService")

// MARK: - Plugin Category (upstream: PluginCategory)

enum PluginCategory: String, Codable, CaseIterable {
    case codingPlan       = "coding_plan"
    case contextCompress  = "context_compress"
    case mlxInference     = "mlx_inference"
    case terminalProxy    = "terminal_proxy"
    case fileIndex        = "file_index"
    case quantization     = "quantization"
    case visualBackend    = "visual_backend"
    case custom           = "custom"

    var label: String {
        switch self {
        case .codingPlan:      return I18nManager.shared.t(.psvc_cat_codingPlan)
        case .contextCompress: return I18nManager.shared.t(.psvc_cat_contextCompress)
        case .mlxInference:    return I18nManager.shared.t(.psvc_cat_mlxInference)
        case .terminalProxy:   return I18nManager.shared.t(.psvc_cat_terminalProxy)
        case .fileIndex:       return I18nManager.shared.t(.psvc_cat_fileIndex)
        case .quantization:    return I18nManager.shared.t(.psvc_cat_quantization)
        case .visualBackend:   return I18nManager.shared.t(.psvc_cat_visualBackend)
        case .custom:          return I18nManager.shared.t(.psvc_cat_custom)
        }
    }

    var icon: String {
        switch self {
        case .codingPlan:      return "chevron.left.forwardslash.chevron.right"
        case .contextCompress: return "compress"
        case .mlxInference:    return "cpu"
        case .terminalProxy:   return "terminal"
        case .fileIndex:       return "doc.text.magnifyingglass"
        case .quantization:    return "arrow.triangle.2.circlepath"
        case .visualBackend:   return "photo"
        case .custom:          return "puzzlepiece.extension"
        }
    }
}

// MARK: - Plugin Capability (upstream: PluginCapability)

enum PluginCapability: String, Codable, CaseIterable {
    case mcpTool      = "mcp_tool"
    case claudeSkill  = "claude_skill"
    case subagent     = "subagent"
    case fileAccess   = "file_access"
    case vramConsumer = "vram_consumer"
    case longTask     = "long_task"

    var label: String {
        switch self {
        case .mcpTool:      return "MCP Tool"
        case .claudeSkill:  return "Claude Skill"
        case .subagent:     return I18nManager.shared.t(.psvc_cap_subagent)
        case .fileAccess:   return I18nManager.shared.t(.psvc_cap_fileAccess)
        case .vramConsumer: return I18nManager.shared.t(.psvc_cap_vramConsumer)
        case .longTask:     return I18nManager.shared.t(.psvc_cap_longTask)
        }
    }

    var icon: String {
        switch self {
        case .mcpTool:      return "wrench.and.screwdriver"
        case .claudeSkill:  return "sparkles"
        case .subagent:     return "person.2"
        case .fileAccess:   return "folder"
        case .vramConsumer: return "memorychip"
        case .longTask:     return "clock"
        }
    }
}

// MARK: - Sandbox Mode (upstream: SandboxMode)

enum SandboxMode: String, Codable, CaseIterable {
    case inline  = "inline"
    case process = "process"

    var label: String {
        switch self {
        case .inline:  return I18nManager.shared.t(.psvc_sbox_inline)
        case .process: return I18nManager.shared.t(.psvc_sbox_process)
        }
    }
}

// MARK: - Plugin Param (upstream: PluginParam)

struct PluginParam: Codable, Identifiable {
    let name: String
    let type: String
    let description: String
    var required: Bool
    var default_value: String?
    var enum_values: [String]?

    var id: String { name }
}

// MARK: - Plugin Manifest (aligned with upstream PluginManifest.to_dict())

struct PluginManifest: Codable {
    let id: String
    let name: String
    let version: String
    let category: PluginCategory
    let description: String
    var capabilities: [PluginCapability]
    var params: [PluginParam]
    var entryPoint: String?
    var defaultMounted: Bool
    var timeoutSeconds: Int?
    var vramMb: Int
    var dependsOn: [String]
    var sandboxMode: SandboxMode

    // Legacy fields kept for local-dir scan backward compat
    var author: String?
    var minAppVersion: String?
    var icon: String?
    var homepage: String?

    var displayIcon: String { icon ?? category.icon }

    enum CodingKeys: String, CodingKey {
        case id, name, version, category, description, capabilities, params
        case entryPoint = "entry_point"
        case defaultMounted = "default_mounted"
        case timeoutSeconds = "timeout_seconds"
        case vramMb = "vram_mb"
        case dependsOn = "depends_on"
        case sandboxMode = "sandbox_mode"
        case author, minAppVersion, icon, homepage
    }
}

// MARK: - Plugin State (aligned with upstream PluginState)

enum PluginState: String, Equatable {
    case registered = "registered"
    case loaded     = "loaded"
    case enabled    = "enabled"
    case disabled   = "disabled"
    case crashed    = "crashed"
    case timeout    = "timeout"

    var label: String {
        switch self {
        case .registered: return I18nManager.shared.t(.psvc_state_registered)
        case .loaded:     return I18nManager.shared.t(.psvc_state_loaded)
        case .enabled:    return I18nManager.shared.t(.psvc_state_enabled)
        case .disabled:   return I18nManager.shared.t(.psvc_state_disabled)
        case .crashed:    return I18nManager.shared.t(.psvc_state_crashed)
        case .timeout:    return I18nManager.shared.t(.psvc_state_timeout)
        }
    }

    var color: Color {
        switch self {
        case .registered: return .gray
        case .loaded:     return .blue
        case .enabled:    return .green
        case .disabled:   return .gray
        case .crashed:    return .red
        case .timeout:    return .orange
        }
    }

    var icon: String {
        switch self {
        case .registered: return "circle"
        case .loaded:     return "arrow.down.circle"
        case .enabled:    return "checkmark.circle.fill"
        case .disabled:   return "pause.circle"
        case .crashed:    return "xmark.circle.fill"
        case .timeout:    return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Plugin Instance

struct Plugin: Identifiable, Hashable {
    let id: String
    var manifest: PluginManifest
    var state: PluginState
    var installDate: Date
    var installPath: String
    var config: [String: Any]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Plugin, rhs: Plugin) -> Bool { lhs.id == rhs.id }
}

// MARK: - Plugin Manager

class PluginManager: ObservableObject {
    static let shared = PluginManager()

    @Published var plugins: [Plugin] = []
    @Published var showSystemPlugins = false
    @Published var lastScanDate: Date?

    private let fileManager = FileManager.default

    var pluginDir: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".fusion-studio/plugins")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var enabledPluginCount: Int { plugins.filter { $0.state == .enabled }.count }
    var crashedPluginCount: Int { plugins.filter { $0.state == .crashed || $0.state == .timeout }.count }

    init() {
        loadBuiltinPlugins()
        scanInstalledPlugins()
    }

    // MARK: - Built-in Plugins

    private func loadBuiltinPlugins() {
        let builtins: [(PluginManifest, PluginState)] = [
            (PluginManifest(
                id: "builtin-terminal", name: I18nManager.shared.t(.psvc_seed_term_name), version: "1.0.0",
                category: .terminalProxy,
                description: I18nManager.shared.t(.psvc_seed_term_desc),
                capabilities: [.longTask], params: [],
                entryPoint: "terminal", defaultMounted: true,
                timeoutSeconds: nil, vramMb: 0, dependsOn: [],
                sandboxMode: .inline,
                author: "Fusion Studio", minAppVersion: "1.0.0",
                icon: "terminal", homepage: nil
            ), .enabled),
            (PluginManifest(
                id: "builtin-git", name: I18nManager.shared.t(.psvc_seed_git_name), version: "1.0.0",
                category: .codingPlan,
                description: I18nManager.shared.t(.psvc_seed_git_desc),
                capabilities: [.fileAccess], params: [],
                entryPoint: "git", defaultMounted: true,
                timeoutSeconds: nil, vramMb: 0, dependsOn: [],
                sandboxMode: .inline,
                author: "Fusion Studio", minAppVersion: "1.0.0",
                icon: "arrow.triangle.branch", homepage: nil
            ), .enabled),
            (PluginManifest(
                id: "builtin-export", name: I18nManager.shared.t(.psvc_seed_export_name), version: "1.0.0",
                category: .visualBackend,
                description: I18nManager.shared.t(.psvc_seed_export_desc),
                capabilities: [.fileAccess, .longTask], params: [],
                entryPoint: "export", defaultMounted: false,
                timeoutSeconds: 300, vramMb: 0, dependsOn: [],
                sandboxMode: .inline,
                author: "Fusion Studio", minAppVersion: "1.0.0",
                icon: "square.and.arrow.up", homepage: nil
            ), .enabled),
            (PluginManifest(
                id: "builtin-markdown", name: I18nManager.shared.t(.psvc_seed_md_name), version: "1.0.0",
                category: .custom,
                description: I18nManager.shared.t(.psvc_seed_md_desc),
                capabilities: [.mcpTool], params: [],
                entryPoint: "markdown", defaultMounted: false,
                timeoutSeconds: nil, vramMb: 0, dependsOn: [],
                sandboxMode: .inline,
                author: "Fusion Studio", minAppVersion: "1.0.0",
                icon: "doc.text.magnifyingglass", homepage: nil
            ), .enabled),
        ]

        for (manifest, state) in builtins {
            let plugin = Plugin(
                id: manifest.id,
                manifest: manifest,
                state: state,
                installDate: Date(),
                installPath: "builtin",
                config: [:]
            )
            plugins.append(plugin)
        }
        pluginLog.info("Loaded \(builtins.count) built-in plugins")
    }

    // MARK: - Scan Installed Plugins

    func scanInstalledPlugins() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: pluginDir,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let pluginDirs = contents.filter { $0.pathExtension == "plugin" || $0.lastPathComponent.hasSuffix(".fusion") }
        var newPlugins: [Plugin] = []

        for dir in pluginDirs {
            let manifestPath = dir.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestPath),
                  let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) else { continue }

            let attrs = try? fileManager.attributesOfItem(atPath: dir.path)
            let date = attrs?[.creationDate] as? Date ?? Date()

            let plugin = Plugin(
                id: manifest.id,
                manifest: manifest,
                state: .registered,
                installDate: date,
                installPath: dir.path,
                config: [:]
            )
            newPlugins.append(plugin)
        }

        for plugin in newPlugins {
            if !plugins.contains(where: { $0.id == plugin.id }) {
                plugins.append(plugin)
            }
        }

        lastScanDate = Date()
        objectWillChange.send()
        pluginLog.info("Scanned \(newPlugins.count) installed plugins")
    }

    // MARK: - IPC Registry Fetch

    func fetchRegistryPlugins() async {
        // IPCClient is injected via @EnvironmentObject at view layer;
        // fetch is triggered from InstalledPluginsView.task with explicit client.
        // This method is a fallback using a short-lived client.
        let client = IPCClient()
        guard client.isConnected else {
            pluginLog.warning("Registry fetch skipped: IPC not connected")
            return
        }
        do {
            let response = try await client.call(method: "plugin.list", params: [:])
            guard let items = response["result"] as? [[String: Any]] else { return }

            for item in items {
                guard let id = item["id"] as? String else { continue }
                if plugins.contains(where: { $0.id == id }) { continue }

                guard let data = try? JSONSerialization.data(withJSONObject: item),
                      let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) else { continue }

                let plugin = Plugin(
                    id: manifest.id,
                    manifest: manifest,
                    state: .registered,
                    installDate: Date(),
                    installPath: "registry",
                    config: [:]
                )
                plugins.append(plugin)
            }
            pluginLog.info("Fetched \(items.count) plugins from registry")
        } catch {
            pluginLog.warning("Registry fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Plugin Operations

    func installPlugin(at url: URL) -> Bool {
        let fileName = url.lastPathComponent
        let dest = pluginDir.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.copyItem(at: url, to: dest)
            scanInstalledPlugins()
            pluginLog.info("Plugin installed: \(fileName)")
            return true
        } catch {
            pluginLog.error("Install failed: \(error.localizedDescription)")
            return false
        }
    }

    func enablePlugin(_ id: String) {
        guard let idx = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[idx].state = .enabled
        objectWillChange.send()
        pluginLog.info("Enabled: \(id)")
    }

    func disablePlugin(_ id: String) {
        guard let idx = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[idx].state = .disabled
        objectWillChange.send()
        pluginLog.info("Disabled: \(id)")
    }

    func uninstallPlugin(_ id: String) {
        guard let plugin = plugins.first(where: { $0.id == id }),
              plugin.installPath != "builtin" else { return }

        try? fileManager.removeItem(atPath: plugin.installPath)
        plugins.removeAll { $0.id == id }
        objectWillChange.send()
        pluginLog.info("Uninstalled: \(id)")
    }

    func openPluginFolder() {
        NSWorkspace.shared.open(pluginDir)
    }

    func createPluginTemplate(name: String, author: String) -> URL? {
        let pluginName = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let pluginDir = pluginDir.appendingPathComponent("\(pluginName).plugin")
        try? fileManager.createDirectory(at: pluginDir, withIntermediateDirectories: true)

        let manifest = PluginManifest(
            id: "custom-\(pluginName)",
            name: name,
            version: "0.1.0",
            category: .custom,
            description: I18nManager.shared.t(.psvc_template_desc),
            capabilities: [.mcpTool],
            params: [],
            entryPoint: "main.py",
            defaultMounted: false,
            timeoutSeconds: nil,
            vramMb: 0,
            dependsOn: [],
            sandboxMode: .inline,
            author: author,
            minAppVersion: "1.0.0",
            icon: "puzzlepiece.extension",
            homepage: nil
        )

        let manifestPath = pluginDir.appendingPathComponent("manifest.json")
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestPath)
        }

        let mainCode = """
# Fusion Studio Plugin: \(name)
# \(author)

def on_load():
    pass

def on_unload():
    pass

def on_register_commands():
    return []

def on_render_panel():
    return \"\"\"<div>
        <h3>\(name)</h3>
        <p>Plugin loaded</p>
    </div>\"\"\"
"""
        let mainPath = pluginDir.appendingPathComponent("main.py")
        try? mainCode.write(to: mainPath, atomically: true, encoding: .utf8)

        scanInstalledPlugins()
        pluginLog.info("Template created: \(pluginName)")
        return pluginDir
    }

    // MARK: - IPC Methods (fusion-plugins-ecosystem)

    @Published var ecosystemConfig: [String: Any] = [:]
    @Published var pluginStates: [[String: Any]] = []
    @Published var tokenRecords: [[String: Any]] = []
    @Published var vramUsage: [String: Any] = [:]
    @Published var logEntries: [PluginLogEntry] = []
    @Published var mcpSessions: [[String: Any]] = []

    struct PluginLogEntry: Identifiable {
        let id = UUID()
        var pluginId: String
        var level: String
        var message: String
        var timestamp: String
    }

    func ipcCall(_ method: String, params: [String: Any] = [:]) async -> [String: Any]? {
        let client = IPCClient()
        guard client.isConnected else {
            pluginLog.warning("IPC not connected for \(method)")
            return nil
        }
        do {
            let resp = try await client.call(method: method, params: params)
            return resp["result"] as? [String: Any]
        } catch {
            pluginLog.error("IPC \(method) failed: \(error.localizedDescription)")
            return nil
        }
    }

    func ipcCallArray(_ method: String, params: [String: Any] = [:]) async -> [[String: Any]] {
        let client = IPCClient()
        guard client.isConnected else { return [] }
        do {
            let resp = try await client.call(method: method, params: params)
            return resp["result"] as? [[String: Any]] ?? []
        } catch {
            pluginLog.error("IPC \(method) failed: \(error.localizedDescription)")
            return []
        }
    }

    func fetchEcosystemConfig() async {
        if let result = await ipcCall("plugins/config.get") {
            DispatchQueue.main.async { self.ecosystemConfig = result }
        }
    }

    func setEcosystemConfig(_ key: String, value: Any) async {
        _ = await ipcCall("plugins/config.set", params: [key: value])
        await fetchEcosystemConfig()
    }

    func fetchPluginStates() async {
        let result = await ipcCallArray("plugins/states")
        DispatchQueue.main.async { self.pluginStates = result }
    }

    func fetchTokenRecords(pluginId: String? = nil) async {
        var params: [String: Any] = [:]
        if let pid = pluginId { params["plugin_id"] = pid }
        let result = await ipcCallArray("plugins/token.records", params: params)
        DispatchQueue.main.async { self.tokenRecords = result }
    }

    func pruneTokenRecords(maxAge: Int = 3600) async {
        _ = await ipcCall("plugins/token.prune", params: ["max_age_seconds": maxAge])
        await fetchTokenRecords()
    }

    func fetchVramUsage() async {
        if let result = await ipcCall("plugins/vram.usage") {
            DispatchQueue.main.async { self.vramUsage = result }
        }
    }

    func fetchLogs(pluginId: String? = nil, level: String? = nil) async {
        var params: [String: Any] = [:]
        if let pid = pluginId { params["plugin_id"] = pid }
        if let lvl = level { params["level"] = lvl }
        let result = await ipcCallArray("plugins/logs.stream", params: params)
        DispatchQueue.main.async {
            self.logEntries = result.map { item in
                PluginLogEntry(
                    pluginId: item["plugin_id"] as? String ?? "",
                    level: item["level"] as? String ?? "INFO",
                    message: item["message"] as? String ?? "",
                    timestamp: item["timestamp"] as? String ?? ""
                )
            }
        }
    }

    func fetchMcpSessions() async {
        let result = await ipcCallArray("plugins/mcp.sessions")
        DispatchQueue.main.async { self.mcpSessions = result }
    }

    func pruneMcpSessions(maxAge: Int = 3600) async {
        _ = await ipcCall("plugins/mcp.sessions.prune", params: ["max_age_seconds": maxAge])
        await fetchMcpSessions()
    }
}

// MARK: - Plugin Market Item

struct PluginMarketItem: Identifiable {
    let id: String
    let name: String
    let author: String
    let description: String
    let version: String
    let downloads: Int
    let rating: Double
    let iconName: String
    let isInstalled: Bool
    let hasUpdate: Bool
}

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

// MARK: - Plugin Market

struct PluginMarketView: View {
    @Environment(\.studioTheme) private var theme
    let marketItems: [PluginMarketItem] = [
        PluginMarketItem(id: "theme-dark", name: I18nManager.shared.t(.psvc_market_theme_name), author: "Fusion Labs", description: I18nManager.shared.t(.psvc_market_theme_desc), version: "1.2.0", downloads: 1280, rating: 4.5, iconName: "paintpalette", isInstalled: false, hasUpdate: false),
        PluginMarketItem(id: "code-lint", name: I18nManager.shared.t(.psvc_market_lint_name), author: "DevTools", description: I18nManager.shared.t(.psvc_market_lint_desc), version: "0.8.0", downloads: 856, rating: 4.2, iconName: "checkmark.shield", isInstalled: true, hasUpdate: true),
        PluginMarketItem(id: "sim-extra", name: I18nManager.shared.t(.psvc_market_sim_name), author: "SimLab", description: I18nManager.shared.t(.psvc_market_sim_desc), version: "1.0.0", downloads: 2340, rating: 4.8, iconName: "gearshape.2.fill", isInstalled: false, hasUpdate: false),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12) {
                ForEach(marketItems) { item in
                    MarketCard(item: item)
                }
            }
            .padding()
        }
    }
}

struct MarketCard: View {
    @Environment(\.studioTheme) private var theme
    let item: PluginMarketItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Spacer()
                if item.hasUpdate {
                    Text(I18nManager.shared.t(.psvc_market_update_badge))
                        .font(.system(size: 8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                }
            }

            Text(item.name)
                .font(.headline)

            Text(item.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Image(systemName: "person")
                    .font(.caption2)
                Text(item.author)
                    .font(.caption2)
                Spacer()
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text("\(item.rating, specifier: "%.1f")")
                    .font(.caption2)
                Text("\u{00b7} \(item.downloads)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("v\(item.version)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button(item.isInstalled ? (item.hasUpdate ? I18nManager.shared.t(.psvc_market_btn_update) : I18nManager.shared.t(.psvc_market_btn_installed)) : I18nManager.shared.t(.psvc_market_btn_install)) {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(item.isInstalled && !item.hasUpdate)
            }
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
    }
}

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

// MARK: - Plugin Config View (#79)

struct PluginConfigView: View {
    @StateObject private var pm = PluginManager.shared
    @Environment(\.studioTheme) private var theme
    @State private var editingKey: String?
    @State private var editingValue: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(I18nManager.shared.t(.psvc_cfg_title))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: { Task { await pm.fetchEcosystemConfig() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help(I18nManager.shared.t(.psvc_cfg_refresh))
                }

                if pm.ecosystemConfig.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text(I18nManager.shared.t(.psvc_cfg_empty))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ForEach(Array(pm.ecosystemConfig.keys.sorted()), id: \.self) { key in
                        configRow(key: key, value: pm.ecosystemConfig[key])
                    }
                }
            }
            .padding(16)
        }
        .background(theme.surfacePrimary)
        .onAppear { Task { await pm.fetchEcosystemConfig() } }
    }

    private func configRow(key: String, value: Any?) -> some View {
        HStack {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(theme.accent)
                .frame(width: 200, alignment: .leading)
            Spacer()
            if editingKey == key {
                TextField(I18nManager.shared.t(.psvc_cfg_value_ph), text: $editingValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 200)
                Button(I18nManager.shared.t(.psvc_cfg_save)) {
                    let val: Any = editingValue.lowercased() == "true" ? true :
                                  editingValue.lowercased() == "false" ? false :
                                  (Int(editingValue) as Any?) ?? editingValue
                    Task { await pm.setEcosystemConfig(key, value: val) }
                    editingKey = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button(I18nManager.shared.t(.psvc_tmpl_cancel)) { editingKey = nil }
                    .controlSize(.small)
            } else {
                Text(String(describing: value ?? ""))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                Button(I18nManager.shared.t(.psvc_cfg_edit)) {
                    editingKey = key
                    editingValue = String(describing: value ?? "")
                }
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
    }
}

// MARK: - Plugin Status View (#80)

struct PluginStatusView: View {
    @StateObject private var pm = PluginManager.shared
    @Environment(\.studioTheme) private var theme
    @State private var filterState: String = "all"

    var body: some View {
        VStack(spacing: 0) {
            statusToolbar
            Divider()
            if pm.pluginStates.isEmpty {
                emptyStatus
            } else {
                statusList
            }
        }
        .background(theme.surfacePrimary)
        .onAppear { Task { await pm.fetchPluginStates() } }
    }

    private var statusToolbar: some View {
        HStack {
            Text(I18nManager.shared.t(.psvc_status_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            HStack(spacing: 4) {
                statusFilterChip(I18nManager.shared.t(.psvc_filter_all), value: "all")
                statusFilterChip(I18nManager.shared.t(.psvc_status_filter_run), value: "enabled")
                statusFilterChip(I18nManager.shared.t(.psvc_status_filter_crash), value: "crashed")
                statusFilterChip(I18nManager.shared.t(.psvc_status_filter_timeout), value: "timeout")
            }
            Button(action: { Task { await pm.fetchPluginStates() } }) {
                Image(systemName: "arrow.clockwise")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.surfaceSecondary)
    }

    private func statusFilterChip(_ label: String, value: String) -> some View {
        Button(action: { filterState = value }) {
            Text(label)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(filterState == value ? theme.accentSoft : theme.surfacePrimary)
                .foregroundColor(filterState == value ? theme.accent : theme.textSecondary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var emptyStatus: some View {
        VStack(spacing: 8) {
            Image(systemName: "heartbeat")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(I18nManager.shared.t(.psvc_status_empty))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusList: some View {
        List {
            let filtered = filterState == "all" ? pm.pluginStates :
                pm.pluginStates.filter { $0["state"] as? String == filterState }
            ForEach(Array(filtered.enumerated()), id: \.offset) { _, item in
                HStack {
                    let state = item["state"] as? String ?? "unknown"
                    Circle()
                        .fill(stateColor(state))
                        .frame(width: 8, height: 8)
                    Text(item["plugin_id"] as? String ?? "")
                        .font(.subheadline)
                    Spacer()
                    Text(state)
                        .font(.caption)
                        .foregroundColor(stateColor(state))
                    if let count = item["restart_count"] as? Int, count > 0 {
                        Text(I18nManager.shared.tf(.psvc_status_restart_fmt, count))
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func stateColor(_ state: String) -> Color {
        switch state {
        case "enabled", "loaded": return .green
        case "crashed": return .red
        case "timeout": return .orange
        case "disabled": return .gray
        default: return .secondary
        }
    }
}

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
