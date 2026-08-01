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

struct SpaceAgent: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var systemPrompt: String
    var model: String
    var permission: String
    var source: String
    var capabilities: [String]
    var createdAt: Date

    init(id: String = UUID().uuidString,
         name: String = "",
         systemPrompt: String = "",
         model: String = "",
         permission: String = "all_member",
         source: String = "local",
         capabilities: [String] = []) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.model = model
        self.permission = permission
        self.source = source
        self.capabilities = capabilities
        self.createdAt = Date()
    }

    static func fromDict(_ d: [String: Any]) -> SpaceAgent {
        let dateFormatter = ISO8601DateFormatter()
        let id = d["agent_id"] as? String ?? d["id"] as? String ?? UUID().uuidString
        var agent = SpaceAgent(
            id: id,
            name: d["agent_name"] as? String ?? d["name"] as? String ?? "",
            systemPrompt: d["system_prompt"] as? String ?? "",
            model: d["model"] as? String ?? "",
            permission: d["permission"] as? String ?? "all_member",
            source: d["source"] as? String ?? "local",
            capabilities: d["capabilities"] as? [String] ?? []
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
    var createdAt: Date

    init(id: String = UUID().uuidString,
         name: String = "",
         kind: String = "code",
         description: String = "",
         fileSize: Int64 = 0,
         content: String = "",
         filePath: String = "") {
        self.id = id
        self.name = name
        self.kind = kind
        self.description = description
        self.fileSize = fileSize
        self.content = content
        self.filePath = filePath
        self.createdAt = Date()
    }

    static func fromDict(_ d: [String: Any]) -> SpaceArtifact {
        let dateFormatter = ISO8601DateFormatter()
        let id = d["artifact_id"] as? String ?? d["id"] as? String ?? UUID().uuidString
        var art = SpaceArtifact(
            id: id,
            name: d["name"] as? String ?? "",
            kind: d["kind"] as? String ?? d["type"] as? String ?? "code",
            description: d["description"] as? String ?? "",
            fileSize: d["file_size"] as? Int64 ?? 0,
            content: d["content"] as? String ?? "",
            filePath: d["file_path"] as? String ?? ""
        )
        art.createdAt = dateFormatter.date(from: d["created_at"] as? String ?? "") ?? Date()
        return art
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
    @Published var isLoading: Bool = false

    private(set) var ipcClient: IPCClient?

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
            coworkLog.info("Loaded \(loaded.count) spaces")
        } catch {
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
        } catch {
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
        } catch {
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
        } catch {
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
        } catch {
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
        } catch {
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
        } catch {
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
        } catch {
            coworkLog.error("loadSnapshots failed: \(error.localizedDescription)")
        }
    }
}
