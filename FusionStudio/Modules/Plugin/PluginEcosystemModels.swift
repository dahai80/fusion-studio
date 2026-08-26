import Foundation
import os.log

private let modelsLog = Logger(subsystem: "com.fusion.studio", category: "PluginEcosystemModels")

// MARK: - PluginListItem (#78)

struct PluginListItem: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let version: String
    let description: String
    let author: String?
    let enabled: Bool
    let installed: Bool

    static func fromDict(_ d: [String: Any]) -> PluginListItem? {
        guard let id = d["id"] as? String,
              let name = d["name"] as? String else { return nil }
        return PluginListItem(
            id: id,
            name: name,
            category: d["category"] as? String ?? "custom",
            version: d["version"] as? String ?? "0.0.0",
            description: d["description"] as? String ?? "",
            author: d["author"] as? String,
            enabled: d["enabled"] as? Bool ?? false,
            installed: d["installed"] as? Bool ?? false
        )
    }
}

// MARK: - EcosystemConfig (#79)

struct EcosystemConfig: Hashable {
    let sandboxMode: String
    let autoUpdate: Bool
    let maxConcurrentPlugins: Int
    let logLevel: String
    let tokenBudget: Int
    let vramLimitMB: Int
    let mcpEnabled: Bool

    static func fromDict(_ d: [String: Any]) -> EcosystemConfig {
        return EcosystemConfig(
            sandboxMode: d["sandbox_mode"] as? String ?? "restricted",
            autoUpdate: d["auto_update"] as? Bool ?? false,
            maxConcurrentPlugins: d["max_concurrent_plugins"] as? Int ?? 4,
            logLevel: d["log_level"] as? String ?? "info",
            tokenBudget: d["token_budget"] as? Int ?? 32768,
            vramLimitMB: d["vram_limit_mb"] as? Int ?? 4096,
            mcpEnabled: d["mcp_enabled"] as? Bool ?? true
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sandboxMode)
        hasher.combine(autoUpdate)
        hasher.combine(maxConcurrentPlugins)
        hasher.combine(logLevel)
        hasher.combine(tokenBudget)
        hasher.combine(vramLimitMB)
        hasher.combine(mcpEnabled)
    }
}

// MARK: - PluginStateInfo (#80)

struct PluginStateInfo: Identifiable, Hashable {
    let id: String
    let pluginId: String
    let state: String
    let pid: Int?
    let startTime: String?
    let uptime: Int?
    let errorCount: Int
    let lastError: String?

    static func fromDict(_ d: [String: Any]) -> PluginStateInfo? {
        guard let id = d["id"] as? String ?? d["plugin_id"] as? String else { return nil }
        return PluginStateInfo(
            id: id,
            pluginId: d["plugin_id"] as? String ?? id,
            state: d["state"] as? String ?? "unknown",
            pid: d["pid"] as? Int,
            startTime: d["start_time"] as? String,
            uptime: d["uptime"] as? Int,
            errorCount: d["error_count"] as? Int ?? 0,
            lastError: d["last_error"] as? String
        )
    }
}

// MARK: - TokenRecord (#81)

struct TokenRecord: Identifiable, Hashable {
    let id: String
    let pluginId: String
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let timestamp: String
    let model: String?

    static func fromDict(_ d: [String: Any]) -> TokenRecord? {
        guard let id = d["id"] as? String ?? d["plugin_id"] as? String else { return nil }
        return TokenRecord(
            id: id,
            pluginId: d["plugin_id"] as? String ?? id,
            promptTokens: d["prompt_tokens"] as? Int ?? 0,
            completionTokens: d["completion_tokens"] as? Int ?? 0,
            totalTokens: d["total_tokens"] as? Int ?? 0,
            timestamp: d["timestamp"] as? String ?? "",
            model: d["model"] as? String
        )
    }
}

// MARK: - VRAMUsage (#82)

struct VRAMUsage: Hashable {
    let totalMB: Int
    let usedMB: Int
    let freeMB: Int
    let byPlugin: [VRAMPluginEntry]

    static func fromDict(_ d: [String: Any]) -> VRAMUsage {
        let entries = (d["by_plugin"] as? [[String: Any]] ?? []).compactMap { VRAMPluginEntry.fromDict($0) }
        return VRAMUsage(
            totalMB: d["total_mb"] as? Int ?? 0,
            usedMB: d["used_mb"] as? Int ?? 0,
            freeMB: d["free_mb"] as? Int ?? 0,
            byPlugin: entries
        )
    }
}

struct VRAMPluginEntry: Identifiable, Hashable {
    let id: String
    let pluginId: String
    let allocatedMB: Int
    let peakMB: Int

    static func fromDict(_ d: [String: Any]) -> VRAMPluginEntry? {
        guard let id = d["id"] as? String ?? d["plugin_id"] as? String else { return nil }
        return VRAMPluginEntry(
            id: id,
            pluginId: d["plugin_id"] as? String ?? id,
            allocatedMB: d["allocated_mb"] as? Int ?? 0,
            peakMB: d["peak_mb"] as? Int ?? 0
        )
    }
}

// MARK: - PluginLogEntry (#83)

struct PluginLogEntry: Identifiable, Hashable {
    let id: String
    let pluginId: String
    let level: String
    let message: String
    let timestamp: String

    static func fromDict(_ d: [String: Any]) -> PluginLogEntry? {
        guard let id = d["id"] as? String else { return nil }
        return PluginLogEntry(
            id: id,
            pluginId: d["plugin_id"] as? String ?? "",
            level: d["level"] as? String ?? "info",
            message: d["message"] as? String ?? "",
            timestamp: d["timestamp"] as? String ?? ""
        )
    }
}

// MARK: - MCPSession (#84)

struct MCPSession: Identifiable, Hashable {
    let id: String
    let pluginId: String
    let server: String
    let status: String
    let toolCount: Int
    let connectedAt: String

    static func fromDict(_ d: [String: Any]) -> MCPSession? {
        guard let id = d["id"] as? String ?? d["session_id"] as? String else { return nil }
        return MCPSession(
            id: id,
            pluginId: d["plugin_id"] as? String ?? "",
            server: d["server"] as? String ?? "",
            status: d["status"] as? String ?? "unknown",
            toolCount: d["tool_count"] as? Int ?? 0,
            connectedAt: d["connected_at"] as? String ?? ""
        )
    }
}
