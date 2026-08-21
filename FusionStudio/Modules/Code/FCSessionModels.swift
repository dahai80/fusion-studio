import Foundation
import os.log

let fcSessionLog = Logger(subsystem: "com.fusion.studio", category: "FCSession")

enum FCSessionState: String, CaseIterable, Codable {
    case idle = "idle"
    case running = "running"
    case waitingApproval = "waiting_approval"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case clusterRunning = "cluster_running"

    var icon: String {
        switch self {
        case .idle: return "circle"
        case .running: return "circle.fill"
        case .waitingApproval: return "circle.lefthalf.filled"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .clusterRunning: return "network"
        }
    }

    var color: String {
        switch self {
        case .idle: return "gray"
        case .running: return "green"
        case .waitingApproval: return "yellow"
        case .paused: return "orange"
        case .completed: return "blue"
        case .failed: return "red"
        case .clusterRunning: return "purple"
        }
    }

    var label: String {
        switch self {
        case .idle: return I18nManager.shared.t(.fc_state_idle)
        case .running: return I18nManager.shared.t(.fc_state_running)
        case .waitingApproval: return I18nManager.shared.t(.fc_state_waiting)
        case .paused: return I18nManager.shared.t(.fc_state_paused)
        case .completed: return I18nManager.shared.t(.fc_state_completed)
        case .failed: return I18nManager.shared.t(.fc_state_failed)
        case .clusterRunning: return I18nManager.shared.t(.fc_state_cluster)
        }
    }
}

struct FCSessionConfig: Codable, Identifiable {
    var id: String { sessionId }
    let sessionId: String
    var name: String
    var workingDir: String
    var model: String
    var temperature: Double
    var maxTokens: Int
    var securityMode: String
    var allowedDirs: [String]

    init(
        sessionId: String = "",
        name: String = "",
        workingDir: String = "",
        model: String = "qwen3.5-9b",
        temperature: Double = 0.1,
        maxTokens: Int = 4096,
        securityMode: String = "manual",
        allowedDirs: [String] = []
    ) {
        self.sessionId = sessionId
        self.name = name
        self.workingDir = workingDir
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.securityMode = securityMode
        self.allowedDirs = allowedDirs
    }
}

struct FCSessionDetail: Identifiable, Codable {
    let id: String
    var name: String
    var state: FCSessionState
    var config: FCSessionConfig
    var messageCount: Int
    var createdAt: Double
    var updatedAt: Double
    var error: String
    var clusterNode: String

    init(
        id: String = UUID().uuidString.prefix(12).lowercased(),
        name: String = "",
        state: FCSessionState = .idle,
        config: FCSessionConfig = FCSessionConfig(),
        messageCount: Int = 0,
        createdAt: Double = Date().timeIntervalSince1970,
        updatedAt: Double = Date().timeIntervalSince1970,
        error: String = "",
        clusterNode: String = ""
    ) {
        self.id = id
        self.name = name
        self.state = state
        self.config = config
        self.messageCount = messageCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.error = error
        self.clusterNode = clusterNode
    }

    var isRunning: Bool {
        state == .running || state == .clusterRunning
    }

    var canPause: Bool {
        state == .running
    }

    var canResume: Bool {
        state == .paused
    }

    var displayTitle: String {
        name.isEmpty ? "Session \(id.prefix(6))" : name
    }
}

struct FCSnapshotInfo: Identifiable, Codable {
    let id: String
    var label: String
    var createdAt: Double
    var deltaCount: Int

    var displayLabel: String {
        label.isEmpty ? "Snapshot \(id.suffix(6))" : label
    }

    var formattedDate: String {
        let date = Date(timeIntervalSince1970: createdAt)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

enum FCSidebarGroupMode: String, CaseIterable {
    case byProject = "按项目"
    case byState = "按状态"
    case flat = "平铺"

    var localLabel: String {
        switch self {
        case .byProject: return I18nManager.shared.t(.fc_gm_by_project)
        case .byState: return I18nManager.shared.t(.fc_gm_by_state)
        case .flat: return I18nManager.shared.t(.fc_gm_flat)
        }
    }
}

enum FCLayoutMode: String, CaseIterable {
    case fourColumn = "四栏"
    case threeColumn = "三栏"
    case twoColumn = "双栏"
    case chatOnly = "纯对话"

    var icon: String {
        switch self {
        case .fourColumn: return "sidebar.left"
        case .threeColumn: return "menubar.rectangle"
        case .twoColumn: return "rectangle.split.2x1"
        case .chatOnly: return "message"
        }
    }

    var localLabel: String {
        switch self {
        case .fourColumn: return I18nManager.shared.t(.fc_layout_four_column)
        case .threeColumn: return I18nManager.shared.t(.fc_layout_three_column)
        case .twoColumn: return I18nManager.shared.t(.fc_layout_two_column)
        case .chatOnly: return I18nManager.shared.t(.fc_layout_chat_only)
        }
    }
}
