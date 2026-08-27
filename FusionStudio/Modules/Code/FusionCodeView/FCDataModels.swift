import SwiftUI
import AppKit
import os.log

private let fcLog = Logger(subsystem: "com.fusion.studio", category: "FusionCodeView")

// MARK: - Execution Modes

enum FCExecutionMode: String, CaseIterable {
    case askPermissions = "Ask"
    case autoAccept = "Auto"
    case planOnly = "Plan"

    var icon: String {
        switch self {
        case .askPermissions: return "lock.shield"
        case .autoAccept: return "bolt.fill"
        case .planOnly: return "eye"
        }
    }

    var description: String {
        switch self {
        case .askPermissions: return "Approve edits & commands"
        case .autoAccept: return "Auto-approve file edits"
        case .planOnly: return "Read-only analysis"
        }
    }

    var localLabel: String {
        switch self {
        case .askPermissions: return I18nManager.shared.t(.fc_mode_ask)
        case .autoAccept: return I18nManager.shared.t(.fc_mode_auto)
        case .planOnly: return I18nManager.shared.t(.fc_mode_plan)
        }
    }
}

// MARK: - Chat Message Model

struct FCChatMessage: Identifiable {
    let id: UUID
    let role: String
    var content: String
    let toolCalls: [FCToolCall]
    let timestamp: Date
    var isStreaming = false

    init(id: UUID = UUID(), role: String, content: String, toolCalls: [FCToolCall] = [], timestamp: Date = Date(), isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}

struct FCToolCall: Identifiable {
    let id: UUID
    let name: String
    let args: [String: Any]
    let status: FCToolStatus
    let output: String?

    init(id: UUID = UUID(), name: String, args: [String: Any] = [:], status: FCToolStatus, output: String? = nil) {
        self.id = id
        self.name = name
        self.args = args
        self.status = status
        self.output = output
    }
}

enum FCToolStatus {
    case pending
    case running
    case approved
    case denied
    case completed
    case failed
}

// MARK: - Permission Tier

enum FCPermissionTier {
    case tier1
    case tier2
}

struct FCPermissionRequest: Identifiable {
    let id = UUID()
    let tool: String
    let args: [String: Any]
    let tier: FCPermissionTier
    let description: String
}

// MARK: - Slash Commands

struct FCSlashCommand: Identifiable {
    let id = UUID()
    let name: String
    let shortcut: String
    let description: String
    let icon: String
}

let FC_SLASH_COMMANDS: [FCSlashCommand] = [
    FCSlashCommand(name: "help", shortcut: "/help", description: "Show available commands", icon: "questionmark.circle"),
    FCSlashCommand(name: "clear", shortcut: "/clear", description: "Clear conversation", icon: "trash"),
    FCSlashCommand(name: "compact", shortcut: "/compact", description: "Compact conversation context", icon: "compress"),
    FCSlashCommand(name: "model", shortcut: "/model", description: "Switch model", icon: "cpu"),
    FCSlashCommand(name: "kb", shortcut: "/kb", description: "Query knowledge base", icon: "books.vertical"),
    FCSlashCommand(name: "memory", shortcut: "/memory", description: "Manage project memory", icon: "brain"),
    FCSlashCommand(name: "template", shortcut: "/template", description: "Apply workflow template", icon: "square.grid.3x3"),
    FCSlashCommand(name: "init", shortcut: "/init", description: "Initialize project context", icon: "arrow.triangle.2.circlepath"),
    FCSlashCommand(name: "review", shortcut: "/review", description: "Code review current changes", icon: "magnifyingglass"),
    FCSlashCommand(name: "test", shortcut: "/test", description: "Generate and run tests", icon: "checkmark.shield"),
    FCSlashCommand(name: "deploy", shortcut: "/deploy", description: "Deploy project", icon: "cloud.upload"),
    FCSlashCommand(name: "explain", shortcut: "/explain", description: "Explain code", icon: "text.bubble"),
    FCSlashCommand(name: "refactor", shortcut: "/refactor", description: "Refactor code", icon: "hammer"),
    FCSlashCommand(name: "debug", shortcut: "/debug", description: "Debug issue", icon: "ladybug"),
]
