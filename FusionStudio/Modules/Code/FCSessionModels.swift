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

    // F-I4: IPC session.* 响应 → JSONDecoder 强类型解码。config 字段在 top-level 扁平 (非 nested "config" 键),
    // 与 FCSessionConfig.memberwise 字段 camelCase 不同, 故读 flat snake_case 后构造 config。宽容: 缺键 ?? default。
    // working_dir/cwd dual-key (后端两套键)。守卫: id 缺 → throw (匹配旧 guard nil)。
    enum CodingKeys: String, CodingKey {
        case id, name, state
        case message_count, created_at, updated_at, error, cluster_node
        case working_dir, cwd, model, temperature, max_tokens, security_mode, allowed_dirs
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let idVal = try? c.decodeIfPresent(String.self, forKey: .id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "session missing id"))
        }
        id = idVal
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        let stateStr = (try? c.decodeIfPresent(String.self, forKey: .state)) ?? "idle"
        state = FCSessionState(rawValue: stateStr) ?? .idle
        messageCount = (try? c.decodeIfPresent(Int.self, forKey: .message_count)) ?? 0
        createdAt = (try? c.decodeIfPresent(Double.self, forKey: .created_at)) ?? Date().timeIntervalSince1970
        updatedAt = (try? c.decodeIfPresent(Double.self, forKey: .updated_at)) ?? Date().timeIntervalSince1970
        error = (try? c.decodeIfPresent(String.self, forKey: .error)) ?? ""
        clusterNode = (try? c.decodeIfPresent(String.self, forKey: .cluster_node)) ?? ""
        config = FCSessionConfig(
            sessionId: id,
            name: name,
            workingDir: (try? c.decodeIfPresent(String.self, forKey: .working_dir)) ?? (try? c.decodeIfPresent(String.self, forKey: .cwd)) ?? "",
            model: (try? c.decodeIfPresent(String.self, forKey: .model)) ?? "",
            temperature: (try? c.decodeIfPresent(Double.self, forKey: .temperature)) ?? 0.1,
            maxTokens: (try? c.decodeIfPresent(Int.self, forKey: .max_tokens)) ?? 4096,
            securityMode: (try? c.decodeIfPresent(String.self, forKey: .security_mode)) ?? "manual",
            allowedDirs: (try? c.decodeIfPresent([String].self, forKey: .allowed_dirs)) ?? []
        )
    }

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

    // F-I4: 显式 encode(to:) — CodingKeys 含 dual-key 备用 case (cwd) 无对应存储属性, 合成 Encodable 失败, 故显式编码。
    // FCSessionDetail 无磁盘编码路径 (sessions 内存态), Encodable 仅为 Codable 一致性, 扁平写 config 字段。
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(state, forKey: .state)
        try c.encode(messageCount, forKey: .message_count)
        try c.encode(createdAt, forKey: .created_at)
        try c.encode(updatedAt, forKey: .updated_at)
        try c.encode(error, forKey: .error)
        try c.encode(clusterNode, forKey: .cluster_node)
        try c.encode(config.workingDir, forKey: .working_dir)
        try c.encode(config.model, forKey: .model)
        try c.encode(config.temperature, forKey: .temperature)
        try c.encode(config.maxTokens, forKey: .max_tokens)
        try c.encode(config.securityMode, forKey: .security_mode)
        try c.encode(config.allowedDirs, forKey: .allowed_dirs)
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
