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
