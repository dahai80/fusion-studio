import Foundation
import os.log

private let coworkLog = Logger(subsystem: "com.fusion.studio", category: "CoworkSpace")

enum SpaceStatus: String, Codable, CaseIterable {
    case active
    case archived
    case deleted
}

enum CollabMode: String, Codable, CaseIterable {
    case local
    case p2p
    case gateway
}

enum SpaceRole: String, Codable, CaseIterable {
    case owner
    case admin
    case member
    case viewer
}

enum SpacePermission: String, Codable {
    case manage_members
    case manage_agents
    case upload_files
    case send_messages
    case create_snapshot
    case control_desktop
    case manage_workflows
    case manage_artifacts
    case run_deep_research
}

struct SpaceConfig: Codable, Equatable {
    var enableWebSearch: Bool
    var enableDeepResearch: Bool
    var enableComputerUse: Bool
    var allowMemberUpload: Bool
    var allowMemberAgent: Bool
    var allowMemberWorkflow: Bool
    var maxMembers: Int
    var autoArchiveDays: Int
    var streamResponse: Bool
    var defaultModel: String

    init(enableWebSearch: Bool = true,
         enableDeepResearch: Bool = false,
         enableComputerUse: Bool = false,
         allowMemberUpload: Bool = true,
         allowMemberAgent: Bool = false,
         allowMemberWorkflow: Bool = false,
         maxMembers: Int = 10,
         autoArchiveDays: Int = 0,
         streamResponse: Bool = true,
         defaultModel: String = "") {
        self.enableWebSearch = enableWebSearch
        self.enableDeepResearch = enableDeepResearch
        self.enableComputerUse = enableComputerUse
        self.allowMemberUpload = allowMemberUpload
        self.allowMemberAgent = allowMemberAgent
        self.allowMemberWorkflow = allowMemberWorkflow
        self.maxMembers = maxMembers
        self.autoArchiveDays = autoArchiveDays
        self.streamResponse = streamResponse
        self.defaultModel = defaultModel
    }

    static func fromDict(_ d: [String: Any]) -> SpaceConfig {
        SpaceConfig(
            enableWebSearch: d["enable_web_search"] as? Bool ?? true,
            enableDeepResearch: d["enable_deep_research"] as? Bool ?? false,
            enableComputerUse: d["enable_computer_use"] as? Bool ?? false,
            allowMemberUpload: d["allow_member_upload"] as? Bool ?? true,
            allowMemberAgent: d["allow_member_agent"] as? Bool ?? false,
            allowMemberWorkflow: d["allow_member_workflow"] as? Bool ?? false,
            maxMembers: d["max_members"] as? Int ?? 10,
            autoArchiveDays: d["auto_archive_days"] as? Int ?? 0,
            streamResponse: d["stream_response"] as? Bool ?? true,
            defaultModel: d["default_model"] as? String ?? ""
        )
    }

    func toDict() -> [String: Any] {
        [
            "enable_web_search": enableWebSearch,
            "enable_deep_research": enableDeepResearch,
            "enable_computer_use": enableComputerUse,
            "allow_member_upload": allowMemberUpload,
            "allow_member_agent": allowMemberAgent,
            "allow_member_workflow": allowMemberWorkflow,
            "max_members": maxMembers,
            "auto_archive_days": autoArchiveDays,
            "stream_response": streamResponse,
            "default_model": defaultModel,
        ]
    }
}

struct CoworkSpace: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var ownerId: String
    var description: String
    var collabMode: CollabMode
    var status: SpaceStatus
    var config: SpaceConfig
    var memberCount: Int
    var agentCount: Int
    var artifactCount: Int
    var messageCount: Int
    var kbPath: String?
    var createdAt: Date
    var updatedAt: Date
    var lastActivityAt: Date?

    init(id: String = UUID().uuidString,
         name: String,
         ownerId: String = "local_user",
         description: String = "",
         collabMode: CollabMode = .local,
         status: SpaceStatus = .active,
         config: SpaceConfig = SpaceConfig(),
         memberCount: Int = 1,
         agentCount: Int = 0,
         artifactCount: Int = 0,
         messageCount: Int = 0,
         kbPath: String? = nil) {
        self.id = id
        self.name = name
        self.ownerId = ownerId
        self.description = description
        self.collabMode = collabMode
        self.status = status
        self.config = config
        self.memberCount = memberCount
        self.agentCount = agentCount
        self.artifactCount = artifactCount
        self.messageCount = messageCount
        self.kbPath = kbPath
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastActivityAt = nil
    }

    var isActive: Bool { status == .active }
    var isArchived: Bool { status == .archived }
    var isOwner: Bool { ownerId == "local_user" }

    static func fromDict(_ d: [String: Any]) -> CoworkSpace {
        let id = d["space_id"] as? String ?? d["id"] as? String ?? UUID().uuidString
        let name = d["name"] as? String ?? "Untitled Space"
        let ownerId = d["owner_id"] as? String ?? "local_user"
        let desc = d["description"] as? String ?? ""
        let modeStr = d["collab_mode"] as? String ?? "local"
        let mode = CollabMode(rawValue: modeStr) ?? .local
        let statusStr = d["status"] as? String ?? "active"
        let status = SpaceStatus(rawValue: statusStr) ?? .active
        let config: SpaceConfig
        if let cfg = d["config"] as? [String: Any] {
            config = SpaceConfig.fromDict(cfg)
        } else {
            config = SpaceConfig()
        }
        let memberCount = d["member_count"] as? Int ?? 1
        let agentCount = d["agent_count"] as? Int ?? 0
        let artifactCount = d["artifact_count"] as? Int ?? 0
        let messageCount = d["message_count"] as? Int ?? 0
        let kbPath = d["kb_path"] as? String
        let dateFormatter = ISO8601DateFormatter()
        let createdAt = dateFormatter.date(from: d["created_at"] as? String ?? "") ?? Date()
        let updatedAt = dateFormatter.date(from: d["updated_at"] as? String ?? "") ?? Date()
        let lastActivityAt = dateFormatter.date(from: d["last_activity_at"] as? String ?? "")

        var space = CoworkSpace(
            id: id, name: name, ownerId: ownerId, description: desc,
            collabMode: mode, status: status, config: config,
            memberCount: memberCount, agentCount: agentCount,
            artifactCount: artifactCount, messageCount: messageCount,
            kbPath: kbPath
        )
        space.createdAt = createdAt
        space.updatedAt = updatedAt
        space.lastActivityAt = lastActivityAt
        return space
    }
}

struct SpaceMember: Identifiable, Codable, Equatable {
    let id: String
    var userId: String
    var displayName: String
    var role: SpaceRole
    var isOnline: Bool
    var joinedAt: Date
    var avatarUrl: String?

    init(id: String = UUID().uuidString,
         userId: String,
         displayName: String = "",
         role: SpaceRole = .member,
         isOnline: Bool = false,
         avatarUrl: String? = nil) {
        self.id = id
        self.userId = userId
        self.displayName = displayName
        self.role = role
        self.isOnline = isOnline
        self.joinedAt = Date()
        self.avatarUrl = avatarUrl
    }

    var displayLabel: String {
        displayName.isEmpty ? userId : displayName
    }

    static func fromDict(_ d: [String: Any]) -> SpaceMember {
        let dateFormatter = ISO8601DateFormatter()
        let roleStr = d["role"] as? String ?? "member"
        let role = SpaceRole(rawValue: roleStr) ?? .member
        var member = SpaceMember(
            id: d["id"] as? String ?? UUID().uuidString,
            userId: d["user_id"] as? String ?? "",
            displayName: d["display_name"] as? String ?? "",
            role: role,
            isOnline: d["is_online"] as? Bool ?? false,
            avatarUrl: d["avatar_url"] as? String
        )
        member.joinedAt = dateFormatter.date(from: d["joined_at"] as? String ?? "") ?? Date()
        return member
    }
}

struct SpaceMessage: Identifiable, Codable, Equatable {
    let id: String
    var spaceId: String
    var senderId: String
    var senderName: String
    var senderType: String
    var content: String
    var attachments: [SpaceAttachment]
    var commentCount: Int
    var mentionedAgents: [String]
    var createdAt: Date

    init(id: String = UUID().uuidString,
         spaceId: String = "",
         senderId: String = "",
         senderName: String = "",
         senderType: String = "user",
         content: String = "",
         attachments: [SpaceAttachment] = [],
         commentCount: Int = 0,
         mentionedAgents: [String] = []) {
        self.id = id
        self.spaceId = spaceId
        self.senderId = senderId
        self.senderName = senderName
        self.senderType = senderType
        self.content = content
        self.attachments = attachments
        self.commentCount = commentCount
        self.mentionedAgents = mentionedAgents
        self.createdAt = Date()
    }

    var isFromAgent: Bool { senderType == "agent" }
    var hasAttachments: Bool { !attachments.isEmpty }

    static func fromDict(_ d: [String: Any]) -> SpaceMessage {
        let dateFormatter = ISO8601DateFormatter()
        let attachRaw = d["attachments"] as? [[String: Any]] ?? []
        let attachments = attachRaw.map { SpaceAttachment.fromDict($0) }
        var msg = SpaceMessage(
            id: d["id"] as? String ?? UUID().uuidString,
            spaceId: d["space_id"] as? String ?? "",
            senderId: d["sender_id"] as? String ?? "",
            senderName: d["sender_name"] as? String ?? "",
            senderType: d["sender_type"] as? String ?? "user",
            content: d["content"] as? String ?? "",
            attachments: attachments,
            commentCount: d["comment_count"] as? Int ?? 0,
            mentionedAgents: d["mentioned_agents"] as? [String] ?? []
        )
        msg.createdAt = dateFormatter.date(from: d["created_at"] as? String ?? "") ?? Date()
        return msg
    }
}

struct SpaceAttachment: Identifiable, Codable, Equatable {
    let id: String
    var fileName: String
    var fileType: String
    var fileUrl: String
    var fileSize: Int64

    init(id: String = UUID().uuidString,
         fileName: String = "",
         fileType: String = "file",
         fileUrl: String = "",
         fileSize: Int64 = 0) {
        self.id = id
        self.fileName = fileName
        self.fileType = fileType
        self.fileUrl = fileUrl
        self.fileSize = fileSize
    }

    static func fromDict(_ d: [String: Any]) -> SpaceAttachment {
        SpaceAttachment(
            id: d["id"] as? String ?? UUID().uuidString,
            fileName: d["file_name"] as? String ?? "",
            fileType: d["file_type"] as? String ?? "file",
            fileUrl: d["file_url"] as? String ?? "",
            fileSize: d["file_size"] as? Int64 ?? 0
        )
    }
}

struct SpaceComment: Identifiable, Codable, Equatable {
    let id: String
    var messageId: String
    var authorId: String
    var authorName: String
    var content: String
    var createdAt: Date

    init(id: String = UUID().uuidString,
         messageId: String = "",
         authorId: String = "",
         authorName: String = "",
         content: String = "") {
        self.id = id
        self.messageId = messageId
        self.authorId = authorId
        self.authorName = authorName
        self.content = content
        self.createdAt = Date()
    }

    static func fromDict(_ d: [String: Any]) -> SpaceComment {
        let dateFormatter = ISO8601DateFormatter()
        var comment = SpaceComment(
            id: d["id"] as? String ?? UUID().uuidString,
            messageId: d["message_id"] as? String ?? "",
            authorId: d["author_id"] as? String ?? "",
            authorName: d["author_name"] as? String ?? "",
            content: d["content"] as? String ?? ""
        )
        comment.createdAt = dateFormatter.date(from: d["created_at"] as? String ?? "") ?? Date()
        return comment
    }
}

struct SpaceSnapshot: Identifiable, Codable, Equatable {
    let id: String
    var spaceId: String
    var name: String
    var messageCount: Int
    var agentCount: Int
    var workflowCount: Int
    var artifactCount: Int
    var memberCount: Int
    var createdAt: Date

    init(id: String = UUID().uuidString,
         spaceId: String = "",
         name: String = "",
         messageCount: Int = 0,
         agentCount: Int = 0,
         workflowCount: Int = 0,
         artifactCount: Int = 0,
         memberCount: Int = 0) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.messageCount = messageCount
        self.agentCount = agentCount
        self.workflowCount = workflowCount
        self.artifactCount = artifactCount
        self.memberCount = memberCount
        self.createdAt = Date()
    }

    static func fromDict(_ d: [String: Any]) -> SpaceSnapshot {
        let dateFormatter = ISO8601DateFormatter()
        let id = d["snapshot_id"] as? String ?? d["id"] as? String ?? UUID().uuidString
        var snap = SpaceSnapshot(
            id: id,
            spaceId: d["space_id"] as? String ?? "",
            name: d["name"] as? String ?? "",
            messageCount: d["message_count"] as? Int ?? 0,
            agentCount: d["agent_count"] as? Int ?? 0,
            workflowCount: d["workflow_count"] as? Int ?? 0,
            artifactCount: d["artifact_count"] as? Int ?? 0,
            memberCount: d["member_count"] as? Int ?? 0
        )
        snap.createdAt = dateFormatter.date(from: d["created_at"] as? String ?? "") ?? Date()
        return snap
    }
}

enum SpaceAgentType: String, Codable, CaseIterable {
    case chat
    case code
    case research
    case workflow
    case custom
}

struct SpaceAgent: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var systemPrompt: String
    var model: String
    var permission: String
    var source: String
    var capabilities: [String]
    var agentType: SpaceAgentType
    var enableRag: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString,
         name: String = "",
         systemPrompt: String = "",
         model: String = "",
         permission: String = "all_member",
         source: String = "local",
         capabilities: [String] = [],
         agentType: SpaceAgentType = .chat,
         enableRag: Bool = false) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.model = model
        self.permission = permission
        self.source = source
        self.capabilities = capabilities
        self.agentType = agentType
        self.enableRag = enableRag
        self.createdAt = Date()
    }

    var typeIcon: String {
        switch agentType {
        case .chat: return "bubble.left.and.bubble.right"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .research: return "magnifyingglass"
        case .workflow: return "arrow.triangle.branch"
        case .custom: return "star"
        }
    }

    static func fromDict(_ d: [String: Any]) -> SpaceAgent {
        let dateFormatter = ISO8601DateFormatter()
        let id = d["agent_id"] as? String ?? d["id"] as? String ?? UUID().uuidString
        let typeStr = d["agent_type"] as? String ?? d["type"] as? String ?? "chat"
        var agent = SpaceAgent(
            id: id,
            name: d["agent_name"] as? String ?? d["name"] as? String ?? "",
            systemPrompt: d["system_prompt"] as? String ?? "",
            model: d["model"] as? String ?? "",
            permission: d["permission"] as? String ?? "all_member",
            source: d["source"] as? String ?? "local",
            capabilities: d["capabilities"] as? [String] ?? [],
            agentType: SpaceAgentType(rawValue: typeStr) ?? .chat,
            enableRag: d["enable_rag"] as? Bool ?? false
        )
        agent.createdAt = dateFormatter.date(from: d["created_at"] as? String ?? "") ?? Date()
        return agent
    }
}

struct SpaceInviteLink: Identifiable, Codable, Equatable {
    let id: String
    var inviteCode: String
    var role: SpaceRole
    var maxUses: Int
    var usedCount: Int
    var expiresAt: Date?
    var createdAt: Date

    init(id: String = UUID().uuidString,
         inviteCode: String = "",
         role: SpaceRole = .member,
         maxUses: Int = 0,
         usedCount: Int = 0,
         expiresAt: Date? = nil) {
        self.id = id
        self.inviteCode = inviteCode
        self.role = role
        self.maxUses = maxUses
        self.usedCount = usedCount
        self.expiresAt = expiresAt
        self.createdAt = Date()
    }

    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return exp < Date()
    }

    var isExhausted: Bool {
        maxUses > 0 && usedCount >= maxUses
    }

    static func fromDict(_ d: [String: Any]) -> SpaceInviteLink {
        let dateFormatter = ISO8601DateFormatter()
        let roleStr = d["role"] as? String ?? "member"
        let role = SpaceRole(rawValue: roleStr) ?? .member
        var link = SpaceInviteLink(
            id: d["id"] as? String ?? UUID().uuidString,
            inviteCode: d["invite_code"] as? String ?? "",
            role: role,
            maxUses: d["max_uses"] as? Int ?? 0,
            usedCount: d["used_count"] as? Int ?? 0,
            expiresAt: dateFormatter.date(from: d["expires_at"] as? String ?? "")
        )
        link.createdAt = dateFormatter.date(from: d["created_at"] as? String ?? "") ?? Date()
        return link
    }
}

struct SpaceWorkflow: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var status: String
    var nodeCount: Int
    var lastRunAt: Date?
    var createdAt: Date

    init(id: String = UUID().uuidString,
         name: String = "",
         status: String = "idle",
         nodeCount: Int = 0,
         lastRunAt: Date? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.nodeCount = nodeCount
        self.lastRunAt = lastRunAt
        self.createdAt = Date()
    }

    static func fromDict(_ d: [String: Any]) -> SpaceWorkflow {
        let dateFormatter = ISO8601DateFormatter()
        let id = d["workflow_id"] as? String ?? d["id"] as? String ?? UUID().uuidString
        var wf = SpaceWorkflow(
            id: id,
            name: d["name"] as? String ?? "",
            status: d["status"] as? String ?? "idle",
            nodeCount: d["node_count"] as? Int ?? 0,
            lastRunAt: dateFormatter.date(from: d["last_run_at"] as? String ?? "")
        )
        wf.createdAt = dateFormatter.date(from: d["created_at"] as? String ?? "") ?? Date()
        return wf
    }
}

struct SpaceArtifact: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var kind: String
    var description: String
    var fileSize: Int64
    var content: String
    var filePath: String
    var ownerId: String
    var version: Int
    var shareCode: String?
    var metadata: [String: String]
    var createdAt: Date
    var updatedAt: Date?

    init(id: String = UUID().uuidString,
         name: String = "",
         kind: String = "code",
         description: String = "",
         fileSize: Int64 = 0,
         content: String = "",
         filePath: String = "",
         ownerId: String = "local_user",
         version: Int = 1,
         shareCode: String? = nil,
         metadata: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.kind = kind
        self.description = description
        self.fileSize = fileSize
        self.content = content
        self.filePath = filePath
        self.ownerId = ownerId
        self.version = version
        self.shareCode = shareCode
        self.metadata = metadata
        self.createdAt = Date()
    }

    var isShared: Bool { shareCode != nil }

    var kindIcon: String {
        switch kind {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "document": return "doc.text"
        case "image": return "photo"
        case "chart": return "chart.bar"
        case "html": return "globe"
        case "svg": return "square.on.circle"
        default: return "doc"
        }
    }

    static func fromDict(_ d: [String: Any]) -> SpaceArtifact {
        let dateFormatter = ISO8601DateFormatter()
        let id = d["artifact_id"] as? String ?? d["id"] as? String ?? UUID().uuidString
        let metaRaw = d["metadata"] as? [String: Any] ?? [:]
        let metadata = metaRaw.mapValues { String(describing: $0) }
        var art = SpaceArtifact(
            id: id,
            name: d["name"] as? String ?? "",
            kind: d["kind"] as? String ?? d["type"] as? String ?? "code",
            description: d["description"] as? String ?? "",
            fileSize: d["file_size"] as? Int64 ?? 0,
            content: d["content"] as? String ?? "",
            filePath: d["file_path"] as? String ?? "",
            ownerId: d["owner_id"] as? String ?? "local_user",
            version: d["version"] as? Int ?? 1,
            shareCode: d["share_code"] as? String,
            metadata: metadata
        )
        art.createdAt = dateFormatter.date(from: d["created_at"] as? String ?? "") ?? Date()
        art.updatedAt = dateFormatter.date(from: d["updated_at"] as? String ?? "")
        return art
    }
}

struct SpaceKnowledgeStatus: Identifiable, Codable, Equatable {
    let id: String
    var spaceId: String
    var kbId: String?
    var kbName: String?
    var documentCount: Int
    var chunkCount: Int
    var isBound: Bool
    var lastIndexedAt: Date?

    init(id: String = UUID().uuidString,
         spaceId: String = "",
         kbId: String? = nil,
         kbName: String? = nil,
         documentCount: Int = 0,
         chunkCount: Int = 0,
         isBound: Bool = false,
         lastIndexedAt: Date? = nil) {
        self.id = id
        self.spaceId = spaceId
        self.kbId = kbId
        self.kbName = kbName
        self.documentCount = documentCount
        self.chunkCount = chunkCount
        self.isBound = isBound
        self.lastIndexedAt = lastIndexedAt
    }

    var statusText: String {
        isBound ? "\(documentCount) docs, \(chunkCount) chunks" : "Not bound"
    }

    static func fromDict(_ d: [String: Any]) -> SpaceKnowledgeStatus {
        let dateFormatter = ISO8601DateFormatter()
        return SpaceKnowledgeStatus(
            id: d["id"] as? String ?? UUID().uuidString,
            spaceId: d["space_id"] as? String ?? "",
            kbId: d["kb_id"] as? String,
            kbName: d["kb_name"] as? String,
            documentCount: d["document_count"] as? Int ?? 0,
            chunkCount: d["chunk_count"] as? Int ?? 0,
            isBound: d["is_bound"] as? Bool ?? (d["kb_id"] as? String != nil),
            lastIndexedAt: dateFormatter.date(from: d["last_indexed_at"] as? String ?? "")
        )
    }
}

struct SpaceNotification: Identifiable, Codable, Equatable {
    let id: String
    var userId: String
    var spaceId: String
    var title: String
    var type: String
    var content: String
    var isRead: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString,
         userId: String = "",
         spaceId: String = "",
         title: String = "",
         type: String = "info",
         content: String = "",
         isRead: Bool = false) {
        self.id = id
        self.userId = userId
        self.spaceId = spaceId
        self.title = title
        self.type = type
        self.content = content
        self.isRead = isRead
        self.createdAt = Date()
    }

    var typeIcon: String {
        switch type {
        case "info": return "info.circle"
        case "success": return "checkmark.circle"
        case "warning": return "exclamationmark.triangle"
        case "error": return "xmark.circle"
        case "mention": return "at"
        case "agent": return "cpu"
        default: return "bell"
        }
    }

    var typeColor: String {
        switch type {
        case "info": return "blue"
        case "success": return "green"
        case "warning": return "orange"
        case "error": return "red"
        case "mention": return "purple"
        case "agent": return "cyan"
        default: return "gray"
        }
    }

    static func fromDict(_ d: [String: Any]) -> SpaceNotification {
        let dateFormatter = ISO8601DateFormatter()
        var notif = SpaceNotification(
            id: d["id"] as? String ?? d["notification_id"] as? String ?? UUID().uuidString,
            userId: d["user_id"] as? String ?? "",
            spaceId: d["space_id"] as? String ?? "",
            title: d["title"] as? String ?? "",
            type: d["type"] as? String ?? "info",
            content: d["content"] as? String ?? "",
            isRead: d["is_read"] as? Bool ?? false
        )
        notif.createdAt = dateFormatter.date(from: d["created_at"] as? String ?? "") ?? Date()
        return notif
    }
}

struct SpaceDiscoveryPeer: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var host: String
    var port: Int
    var spaceCount: Int
    var memberCount: Int

    init(id: String = UUID().uuidString,
         name: String = "",
         host: String = "",
         port: Int = 0,
         spaceCount: Int = 0,
         memberCount: Int = 0) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.spaceCount = spaceCount
        self.memberCount = memberCount
    }

    static func fromDict(_ d: [String: Any]) -> SpaceDiscoveryPeer {
        SpaceDiscoveryPeer(
            id: d["id"] as? String ?? UUID().uuidString,
            name: d["name"] as? String ?? "",
            host: d["host"] as? String ?? "",
            port: d["port"] as? Int ?? 0,
            spaceCount: d["space_count"] as? Int ?? 0,
            memberCount: d["member_count"] as? Int ?? 0
        )
    }
}

class CoworkSpaceManager: ObservableObject {
    static let shared = CoworkSpaceManager()

    @Published var spaces: [CoworkSpace] = []
    @Published var activeSpace: CoworkSpace?
    @Published var activeMembers: [SpaceMember] = []
    @Published var activeMessages: [SpaceMessage] = []
    @Published var activeAgents: [SpaceAgent] = []
    @Published var activeArtifacts: [SpaceArtifact] = []
    @Published var activeWorkflows: [SpaceWorkflow] = []
    @Published var activeSnapshots: [SpaceSnapshot] = []
    @Published var activeKnowledge: SpaceKnowledgeStatus?
    @Published var activeNotifications: [SpaceNotification] = []
    @Published var isLoading: Bool = false
    @Published var unavailableMethods: Set<String> = []

    private(set) var ipcClient: IPCClient?
    private let rpcAvail = RPCMethodAvailability.shared

    func isMethodAvailable(_ method: String) -> Bool {
        rpcAvail.isMethodAvailable(method)
    }

    func setIPCClient(_ client: IPCClient) {
        ipcClient = client
    }

    func loadSpaces(status: String? = nil) async {
        guard let ipc = ipcClient else { return }
        isLoading = true
        do {
            let result = try await ipc.spaceList(status: status)
            let items = result["items"] as? [[String: Any]] ?? result["spaces"] as? [[String: Any]] ?? []
            let loaded = items.map { CoworkSpace.fromDict($0) }
            await MainActor.run {
                self.spaces = loaded
                self.isLoading = false
            }
            rpcAvail.markAvailable("desk.space.list")
            coworkLog.info("Loaded \(loaded.count) spaces")
        } catch {
            if rpcAvail.handleRPCError(error, method: "desk.space.list") {
                await MainActor.run { self.unavailableMethods = rpcAvail.unavailableMethods }
            }
            coworkLog.error("loadSpaces failed: \(error.localizedDescription)")
            await MainActor.run { self.isLoading = false }
        }
    }

    func loadSpace(spaceId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.spaceGet(spaceId: spaceId)
            let space = CoworkSpace.fromDict(result)
            await MainActor.run { self.activeSpace = space }
            rpcAvail.markAvailable("desk.space.get")
        } catch {
            if rpcAvail.handleRPCError(error, method: "desk.space.get") {
                await MainActor.run { self.unavailableMethods = rpcAvail.unavailableMethods }
            }
            coworkLog.error("loadSpace failed: \(error.localizedDescription)")
        }
    }

    func createSpace(name: String, description: String = "", collabMode: CollabMode = .local,
                      config: SpaceConfig = SpaceConfig()) async throws -> CoworkSpace {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceCreate(name: name, ownerId: "local_user",
                                                 description: description, collabMode: collabMode.rawValue)
        let space = CoworkSpace.fromDict(result)
        await MainActor.run { self.spaces.insert(space, at: 0) }
        coworkLog.info("Space created: \(name)")
        return space
    }

    func loadMembers(spaceId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.spaceMemberList(spaceId: spaceId)
            let items = result["members"] as? [[String: Any]] ?? []
            let members = items.map { SpaceMember.fromDict($0) }
            await MainActor.run { self.activeMembers = members }
            rpcAvail.markAvailable("desk.space.member.list")
        } catch {
            if rpcAvail.handleRPCError(error, method: "desk.space.member.list") {
                await MainActor.run { self.unavailableMethods = rpcAvail.unavailableMethods }
            }
            coworkLog.error("loadMembers failed: \(error.localizedDescription)")
        }
    }

    func loadMessages(spaceId: String, limit: Int = 50) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.spaceChatHistory(spaceId: spaceId, limit: limit)
            let items = result["messages"] as? [[String: Any]] ?? []
            let messages = items.map { SpaceMessage.fromDict($0) }
            await MainActor.run { self.activeMessages = messages }
            rpcAvail.markAvailable("desk.space.chat.history")
        } catch {
            if rpcAvail.handleRPCError(error, method: "desk.space.chat.history") {
                await MainActor.run { self.unavailableMethods = rpcAvail.unavailableMethods }
            }
            coworkLog.error("loadMessages failed: \(error.localizedDescription)")
        }
    }

    func sendMessage(spaceId: String, content: String, senderId: String = "local_user",
                      senderName: String = "", mentionedAgents: [String] = []) async throws -> SpaceMessage {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceChatSend(spaceId: spaceId, content: content,
                                                    senderId: senderId, senderName: senderName,
                                                    mentionedAgents: mentionedAgents)
        let msg = SpaceMessage.fromDict(result)
        await MainActor.run { self.activeMessages.append(msg) }
        return msg
    }

    func loadAgents(spaceId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.spaceAgentList(spaceId: spaceId)
            let items = result["agents"] as? [[String: Any]] ?? []
            let agents = items.map { SpaceAgent.fromDict($0) }
            await MainActor.run { self.activeAgents = agents }
            rpcAvail.markAvailable("desk.space.agent.list")
        } catch {
            if rpcAvail.handleRPCError(error, method: "desk.space.agent.list") {
                await MainActor.run { self.unavailableMethods = rpcAvail.unavailableMethods }
            }
            coworkLog.error("loadAgents failed: \(error.localizedDescription)")
        }
    }

    func loadArtifacts(spaceId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.spaceArtifactList(spaceId: spaceId)
            let items = result["artifacts"] as? [[String: Any]] ?? []
            let artifacts = items.map { SpaceArtifact.fromDict($0) }
            await MainActor.run { self.activeArtifacts = artifacts }
            rpcAvail.markAvailable("desk.space.artifact.list")
        } catch {
            if rpcAvail.handleRPCError(error, method: "desk.space.artifact.list") {
                await MainActor.run { self.unavailableMethods = rpcAvail.unavailableMethods }
            }
            coworkLog.error("loadArtifacts failed: \(error.localizedDescription)")
        }
    }

    func loadWorkflows(spaceId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.spaceWorkflowList(spaceId: spaceId)
            let items = result["workflows"] as? [[String: Any]] ?? []
            let workflows = items.map { SpaceWorkflow.fromDict($0) }
            await MainActor.run { self.activeWorkflows = workflows }
            rpcAvail.markAvailable("desk.space.workflow.list")
        } catch {
            if rpcAvail.handleRPCError(error, method: "desk.space.workflow.list") {
                await MainActor.run { self.unavailableMethods = rpcAvail.unavailableMethods }
            }
            coworkLog.error("loadWorkflows failed: \(error.localizedDescription)")
        }
    }

    func loadSnapshots(spaceId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.spaceSnapshotList(spaceId: spaceId)
            let items = result["snapshots"] as? [[String: Any]] ?? []
            let snapshots = items.map { SpaceSnapshot.fromDict($0) }
            await MainActor.run { self.activeSnapshots = snapshots }
            rpcAvail.markAvailable("desk.space.snapshot.list")
        } catch {
            if rpcAvail.handleRPCError(error, method: "desk.space.snapshot.list") {
                await MainActor.run { self.unavailableMethods = rpcAvail.unavailableMethods }
            }
            coworkLog.error("loadSnapshots failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Knowledge (D4)

    func loadKnowledgeStatus(spaceId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.spaceKnowledgeStatus(spaceId: spaceId)
            let status = SpaceKnowledgeStatus.fromDict(result)
            await MainActor.run { self.activeKnowledge = status }
            rpcAvail.markAvailable("desk.space.knowledge.status")
            coworkLog.info("Knowledge status loaded for space \(spaceId)")
        } catch {
            if rpcAvail.handleRPCError(error, method: "desk.space.knowledge.status") {
                await MainActor.run { self.unavailableMethods = rpcAvail.unavailableMethods }
            }
            coworkLog.error("loadKnowledgeStatus failed: \(error.localizedDescription)")
        }
    }

    func bindKnowledge(spaceId: String, kbId: String? = nil) async {
        guard let ipc = ipcClient else { return }
        do {
            let _ = try await ipc.spaceKnowledgeBind(spaceId: spaceId, kbId: kbId)
            await loadKnowledgeStatus(spaceId: spaceId)
            coworkLog.info("Knowledge bound for space \(spaceId)")
        } catch {
            coworkLog.error("bindKnowledge failed: \(error.localizedDescription)")
        }
    }

    func unbindKnowledge(spaceId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let _ = try await ipc.spaceKnowledgeUnbind(spaceId: spaceId)
            await MainActor.run { self.activeKnowledge = nil }
            coworkLog.info("Knowledge unbound for space \(spaceId)")
        } catch {
            coworkLog.error("unbindKnowledge failed: \(error.localizedDescription)")
        }
    }

    func searchKnowledge(spaceId: String, query: String, topK: Int = 5) async throws -> [[String: Any]] {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceKnowledgeSearch(spaceId: spaceId, query: query, topK: topK)
        coworkLog.info("Knowledge search '\(query)' in space \(spaceId)")
        return result["results"] as? [[String: Any]] ?? []
    }

    func queryKnowledge(spaceId: String, question: String, topK: Int = 5) async throws -> [String: Any] {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceKnowledgeQuery(spaceId: spaceId, question: question, topK: topK)
        coworkLog.info("Knowledge query '\(question)' in space \(spaceId)")
        return result
    }

    func uploadKnowledge(spaceId: String, filePath: String) async throws -> [String: Any] {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceKnowledgeUpload(spaceId: spaceId, filePath: filePath)
        await loadKnowledgeStatus(spaceId: spaceId)
        coworkLog.info("Knowledge uploaded \(filePath) to space \(spaceId)")
        return result
    }

    // MARK: - Notifications

    func loadNotifications(userId: String = "local_user", unreadOnly: Bool = false) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.spaceNotificationList(userId: userId, unreadOnly: unreadOnly)
            let items = result["notifications"] as? [[String: Any]] ?? []
            let notifs = items.map { SpaceNotification.fromDict($0) }
            await MainActor.run { self.activeNotifications = notifs }
            rpcAvail.markAvailable("desk.notification.list")
        } catch {
            if rpcAvail.handleRPCError(error, method: "desk.notification.list") {
                await MainActor.run { self.unavailableMethods = rpcAvail.unavailableMethods }
            }
            coworkLog.error("loadNotifications failed: \(error.localizedDescription)")
        }
    }

    func markNotificationRead(notificationId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let _ = try await ipc.spaceNotificationMarkRead(notificationId: notificationId)
            await MainActor.run {
                self.activeNotifications = self.activeNotifications.map { n in
                    var m = n; if n.id == notificationId { m.isRead = true }; return m
                }
            }
        } catch {
            coworkLog.error("markNotificationRead failed: \(error.localizedDescription)")
        }
    }

    func unreadNotificationCount() -> Int {
        activeNotifications.filter { !$0.isRead }.count
    }

    // MARK: - Agent V2

    func updateAgent(spaceId: String, agentId: String, agentName: String? = nil,
                     systemPrompt: String? = nil, permission: String? = nil,
                     model: String? = nil) async throws -> SpaceAgent {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceAgentUpdate(spaceId: spaceId, agentId: agentId,
                                                      agentName: agentName, systemPrompt: systemPrompt,
                                                      permission: permission, model: model)
        let agent = SpaceAgent.fromDict(result)
        await loadAgents(spaceId: spaceId)
        coworkLog.info("Agent updated: \(agentId)")
        return agent
    }

    func callAgent(spaceId: String, agentId: String, message: String,
                   model: String? = nil) async throws -> [String: Any] {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceAgentCall(spaceId: spaceId, agentId: agentId,
                                                    message: message, model: model)
        coworkLog.info("Agent called: \(agentId)")
        return result
    }

    func relayAgents(spaceId: String, agentIds: [String], message: String,
                     model: String? = nil) async throws -> [String: Any] {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceAgentRelay(spaceId: spaceId, agentIds: agentIds,
                                                     message: message, model: model)
        coworkLog.info("Agent relay: \(agentIds.count) agents")
        return result
    }

    // MARK: - Artifact V2

    func getArtifact(spaceId: String, artifactId: String) async throws -> SpaceArtifact {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceArtifactGet(spaceId: spaceId, artifactId: artifactId)
        return SpaceArtifact.fromDict(result)
    }

    func deleteArtifact(spaceId: String, artifactId: String) async throws {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let _ = try await ipc.spaceArtifactDelete(spaceId: spaceId, artifactId: artifactId)
        await loadArtifacts(spaceId: spaceId)
        coworkLog.info("Artifact deleted: \(artifactId)")
    }

    func updateArtifact(spaceId: String, artifactId: String, name: String? = nil,
                        content: String? = nil, metadata: [String: Any]? = nil) async throws -> SpaceArtifact {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceArtifactUpdate(spaceId: spaceId, artifactId: artifactId,
                                                         name: name, content: content, metadata: metadata)
        let art = SpaceArtifact.fromDict(result)
        await loadArtifacts(spaceId: spaceId)
        coworkLog.info("Artifact updated: \(artifactId)")
        return art
    }

    func shareArtifact(spaceId: String, artifactId: String) async throws -> String {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceArtifactShare(spaceId: spaceId, artifactId: artifactId)
        await loadArtifacts(spaceId: spaceId)
        coworkLog.info("Artifact shared: \(artifactId)")
        return result["share_code"] as? String ?? ""
    }

    // MARK: - Desktop V2

    func shareDesktop(spaceId: String, action: String) async throws -> [String: Any] {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceDesktopShare(spaceId: spaceId, action: action)
        coworkLog.info("Desktop share: \(action)")
        return result
    }

    func controlDesktop(spaceId: String, action: String) async throws -> [String: Any] {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceDesktopControl(spaceId: spaceId, action: action)
        coworkLog.info("Desktop control: \(action)")
        return result
    }

    // MARK: - Snapshot V2

    func restoreSnapshot(spaceId: String, snapshotId: String) async throws -> [String: Any] {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.spaceSnapshotRestore(spaceId: spaceId, snapshotId: snapshotId)
        await loadSpace(spaceId: spaceId)
        coworkLog.info("Snapshot restored: \(snapshotId)")
        return result
    }

    func deleteSnapshot(spaceId: String, snapshotId: String) async throws {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let _ = try await ipc.spaceSnapshotDelete(spaceId: spaceId, snapshotId: snapshotId)
        await loadSnapshots(spaceId: spaceId)
        coworkLog.info("Snapshot deleted: \(snapshotId)")
    }

    // MARK: - Chat Context

    func loadChatContext(spaceId: String, limit: Int? = nil) async throws -> [String: Any] {
        guard let ipc = ipcClient else {
            throw NSError(domain: "CoworkSpace", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        return try await ipc.spaceChatContext(spaceId: spaceId, limit: limit)
    }
}
