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
        // 审计0827 #8: plugins 无界 append (builtin 路), cap 200 复用 PERF-3 ragResults 范式。
        if plugins.count > 200 { plugins.removeFirst(plugins.count - 200) }
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
        // 审计0827 #8: plugins 无界 append (installed 路), cap 200 复用 PERF-3 ragResults 范式。
        if plugins.count > 200 { plugins.removeFirst(plugins.count - 200) }

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
            let response = try await client.call(method: RPCMethod.pluginList, params: [:])
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
            // 审计0827 #8: plugins 无界 append (registry 路), cap 200 复用 PERF-3 ragResults 范式。
            if plugins.count > 200 { plugins.removeFirst(plugins.count - 200) }
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
        DispatchQueue.main.async { self.pluginStates = Array(result.suffix(200)) }
    }

    func fetchTokenRecords(pluginId: String? = nil) async {
        var params: [String: Any] = [:]
        if let pid = pluginId { params["plugin_id"] = pid }
        let result = await ipcCallArray("plugins/token.records", params: params)
        DispatchQueue.main.async { self.tokenRecords = Array(result.suffix(200)) }
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
            // 审计0830 P1: logEntries 日志流无界, 后端无限返回则内存单调增长。LRU cap 200 保最新。
            let mapped = result.map { item in
                PluginLogEntry(
                    pluginId: item["plugin_id"] as? String ?? "",
                    level: item["level"] as? String ?? "INFO",
                    message: item["message"] as? String ?? "",
                    timestamp: item["timestamp"] as? String ?? ""
                )
            }
            self.logEntries = Array(mapped.suffix(200))
        }
    }

    func fetchMcpSessions() async {
        let result = await ipcCallArray("plugins/mcp.sessions")
        DispatchQueue.main.async { self.mcpSessions = Array(result.suffix(200)) }
    }

    func pruneMcpSessions(maxAge: Int = 3600) async {
        _ = await ipcCall("plugins/mcp.sessions.prune", params: ["max_age_seconds": maxAge])
        await fetchMcpSessions()
    }
}
