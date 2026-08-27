import Foundation
import os.log

private let projectLog = Logger(subsystem: "com.fusion.studio", category: "FusionProject")

enum KnowledgeScope: String, Codable, CaseIterable {
    case project
    case session
    case global
}

enum RAGMode: String, Codable, CaseIterable {
    case AUTO
    case MANUAL
    case OFF
}

enum PromptMergeMode: String, Codable, CaseIterable {
    case AGENT_FIRST
    case PROJECT_ONLY
}

struct KnowledgeFile: Identifiable, Codable, Equatable {
    let id: String
    var fileName: String
    var filePath: String
    var fileSize: Int64
    var tokenCount: Int
    var addedAt: Date
    var scope: KnowledgeScope
    var folderId: String?
    var indexStatus: String
    var mimeType: String?

    init(id: String = UUID().uuidString, fileName: String, filePath: String,
         fileSize: Int64 = 0, tokenCount: Int = 0, scope: KnowledgeScope = .project,
         folderId: String? = nil, indexStatus: String = "pending", mimeType: String? = nil) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.fileSize = fileSize
        self.tokenCount = tokenCount
        self.addedAt = Date()
        self.scope = scope
        self.folderId = folderId
        self.indexStatus = indexStatus
        self.mimeType = mimeType
    }
}

struct KnowledgeFolder: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var parentId: String?
    var createdAt: Date
    var fileCount: Int

    init(id: String = UUID().uuidString, name: String, parentId: String? = nil, fileCount: Int = 0) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.createdAt = Date()
        self.fileCount = fileCount
    }
}

struct ProjectChat: Identifiable, Codable, Equatable {
    let id: String
    var projectId: String
    var title: String
    var model: String
    var agentId: String?
    var isStarred: Bool
    var messageCount: Int
    var tokenUsage: Int
    var forkedFrom: String?
    var forkLabel: String?
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, projectId: String, title: String = "New Chat",
         model: String = "", agentId: String? = nil, isStarred: Bool = false,
         messageCount: Int = 0, tokenUsage: Int = 0,
         forkedFrom: String? = nil, forkLabel: String? = nil) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.model = model
        self.agentId = agentId
        self.isStarred = isStarred
        self.messageCount = messageCount
        self.tokenUsage = tokenUsage
        self.forkedFrom = forkedFrom
        self.forkLabel = forkLabel
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    var role: String
    var content: String
    var timestamp: Date
    var ragSources: [String]?
    var tempAttachmentIds: [String]?

    init(id: String = UUID().uuidString, role: String, content: String,
         ragSources: [String]? = nil, tempAttachmentIds: [String]? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.ragSources = ragSources
        self.tempAttachmentIds = tempAttachmentIds
    }
}

struct ChatSnapshot: Identifiable, Codable, Equatable {
    let id: String
    var chatId: String
    var label: String
    var messageCount: Int
    var createdAt: Date
}

struct InstructionSnapshot: Identifiable, Codable, Equatable {
    let id: String
    var label: String
    var content: String
    var createdAt: Date
}

struct AgentBinding: Codable, Equatable {
    var agentId: String?
    var agentName: String?
    var mergeMode: PromptMergeMode
    var agentPrompt: String?
}

struct AgentMeta: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var description: String?
    var icon: String?
    var capabilities: [String]?
}

struct ProjectSettings: Codable, Equatable {
    var defaultModel: String
    var temperature: Double
    var maxTokens: Int
    var autoLoadClaudeMd: Bool
    var autoScanKnowledge: Bool

    init(defaultModel: String = "", temperature: Double = 0.7, maxTokens: Int = 4096,
         autoLoadClaudeMd: Bool = true, autoScanKnowledge: Bool = true) {
        self.defaultModel = defaultModel
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.autoLoadClaudeMd = autoLoadClaudeMd
        self.autoScanKnowledge = autoScanKnowledge
    }
}

struct FusionProject: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var description: String
    var rootPath: String
    var customInstructions: String
    var knowledgeFiles: [KnowledgeFile]
    var knowledgeFolders: [KnowledgeFolder]
    var chats: [ProjectChat]
    var createdAt: Date
    var updatedAt: Date
    var settings: ProjectSettings
    var isStarred: Bool
    var isArchived: Bool
    var ragMode: RAGMode
    var ragTopK: Int
    var ragThreshold: Double
    var defaultAgentId: String?
    var promptMergeMode: PromptMergeMode
    var agentBinding: AgentBinding?

    init(name: String, rootPath: String = "", description: String = "",
         customInstructions: String = "", ragMode: RAGMode = .AUTO,
         promptMergeMode: PromptMergeMode = .AGENT_FIRST) {
        self.id = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        self.name = name
        self.rootPath = rootPath
        self.description = description
        self.customInstructions = customInstructions
        self.knowledgeFiles = []
        self.knowledgeFolders = []
        self.chats = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.settings = ProjectSettings()
        self.isStarred = false
        self.isArchived = false
        self.ragMode = ragMode
        self.ragTopK = 5
        self.ragThreshold = 0.5
        self.defaultAgentId = nil
        self.promptMergeMode = promptMergeMode
        self.agentBinding = nil
    }

    var totalKnowledgeTokens: Int {
        knowledgeFiles.reduce(0) { $0 + $1.tokenCount }
    }

    var hasKnowledge: Bool { !knowledgeFiles.isEmpty }
    var hasInstructions: Bool { !customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var lastOpened: Date { chats.last?.updatedAt ?? updatedAt }
    var fileCount: Int { knowledgeFiles.count }
    var chatCount: Int { chats.count }
    var agentName: String? { agentBinding?.agentName }

    static func fromDict(_ d: [String: Any]) -> FusionProject {
        let id = d["id"] as? String ?? UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        let name = d["name"] as? String ?? "Untitled"
        let desc = d["description"] as? String ?? ""
        let root = d["root_path"] as? String ?? ""
        let instructions = d["custom_instructions"] as? String ?? ""
        let isStarred = d["is_starred"] as? Bool ?? false
        let isArchived = d["is_archived"] as? Bool ?? false
        let ragModeStr = d["rag_mode"] as? String ?? "AUTO"
        let ragMode = RAGMode(rawValue: ragModeStr) ?? .AUTO
        let ragTopK = d["rag_top_k"] as? Int ?? 5
        let ragThreshold = d["rag_threshold"] as? Double ?? 0.5
        let mergeModeStr = d["prompt_merge_mode"] as? String ?? "AGENT_FIRST"
        let mergeMode = PromptMergeMode(rawValue: mergeModeStr) ?? .AGENT_FIRST
        let defaultAgent = d["default_agent_id"] as? String

        var project = FusionProject(name: name, rootPath: root, description: desc,
                                    customInstructions: instructions, ragMode: ragMode,
                                    promptMergeMode: mergeMode)
        project.id = id
        project.isStarred = isStarred
        project.isArchived = isArchived
        project.ragTopK = ragTopK
        project.ragThreshold = ragThreshold
        project.defaultAgentId = defaultAgent
        return project
    }

    private static func _rebuildWithId(_ p: FusionProject, newId: String) -> FusionProject {
        var result = p
        result.id = newId
        return result
    }

    static func from(recent: RecentProject) -> FusionProject {
        FusionProject(name: recent.name, rootPath: recent.path)
    }
}

// Legacy aliases for backward compat with ProjectsPanel
typealias ProjectSession = ProjectChat
typealias ChatMessageRecord = ChatMessage

class FusionProjectManager: ObservableObject {
    static let shared = FusionProjectManager()

    @Published var projects: [FusionProject] = []
    @Published var activeProject: FusionProject?
    @Published var activeChat: ProjectChat?
    @Published var activeChatMessages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var upstreamDegraded: Bool = false

    // Legacy alias
    var activeSession: ProjectChat? {
        get { activeChat }
        set { activeChat = newValue }
    }

    private let baseDir: URL
    private let indexURL: URL
    private(set) var ipcClient: IPCClient?
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let fm = FileManager.default
        baseDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".fusion-studio/projects", isDirectory: true)
        indexURL = baseDir.appendingPathComponent("index.json")
        try? fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        loadProjects()
    }

    func setIPCClient(_ client: IPCClient) {
        ipcClient = client
        // IPC 注入后立刻从后端拉取真实项目，覆盖本地遗留 UUID 项目
        // 否则 ProjectsPanel 侧边栏只会显示 ~/.fusion-studio/projects 本地占位，
        // 点会话时传本地 UUID 给后端 -> "project not found"
        Task { await loadProjectsFromBackend() }
    }

    // MARK: - Backend-Synced Operations

    func loadProjectsFromBackend() async {
        guard let ipc = ipcClient else { return }
        isLoading = true
        do {
            let result = try await ipc.projectList(includeArchived: true)
            if let items = result["items"] as? [[String: Any]] {
                let loaded = items.map { FusionProject.fromDict($0) }
                let backendIds = Set(loaded.map { $0.id })
                await MainActor.run {
                    self.projects = loaded
                    self.isLoading = false
                }
                purgeStaleLocalProjects(keeping: backendIds)
                projectLog.info("Loaded \(items.count) projects from backend")
            } else {
                await MainActor.run { self.isLoading = false }
            }
        } catch {
            projectLog.error("projectList from backend failed: \(error.localizedDescription)")
            await MainActor.run { self.isLoading = false }
        }
    }

    func createProjectBackend(name: String, description: String = "", ragMode: RAGMode = .AUTO,
                               promptMergeMode: PromptMergeMode = .AGENT_FIRST,
                               defaultAgentId: String? = nil) async throws -> FusionProject {
        guard let ipc = ipcClient else {
            throw NSError(domain: "FusionProject", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.projectCreate(name: name, description: description,
                                                   defaultAgentId: defaultAgentId,
                                                   ragMode: ragMode.rawValue,
                                                   promptMergeMode: promptMergeMode.rawValue)
        let project = FusionProject.fromDict(result)
        await MainActor.run {
            self.projects.insert(project, at: 0)
        }
        projectLog.info("Project created via backend: \(name)")
        return project
    }

    func deleteProjectBackend(_ projectId: String) async throws {
        guard let ipc = ipcClient else { return }
        try await ipc.projectDelete(projectId: projectId)
        await MainActor.run {
            self.projects.removeAll { $0.id == projectId }
            if self.activeProject?.id == projectId {
                self.activeProject = nil
                self.activeChat = nil
                self.activeChatMessages = []
            }
        }
        projectLog.info("Project deleted via backend: \(projectId)")
    }

    func archiveProjectBackend(_ projectId: String) async throws {
        guard let ipc = ipcClient else { return }
        let result = try await ipc.projectArchive(projectId: projectId)
        let updated = FusionProject.fromDict(result)
        await MainActor.run {
            if let idx = self.projects.firstIndex(where: { $0.id == projectId }) {
                self.projects[idx] = updated
            }
            if self.activeProject?.id == projectId {
                self.activeProject = updated
            }
        }
    }

    func starProjectBackend(_ projectId: String, starred: Bool) async throws {
        guard let ipc = ipcClient else { return }
        let result = try await ipc.projectStar(projectId: projectId, starred: starred)
        let updated = FusionProject.fromDict(result)
        await MainActor.run {
            if let idx = self.projects.firstIndex(where: { $0.id == projectId }) {
                self.projects[idx] = updated
            }
            if self.activeProject?.id == projectId {
                self.activeProject = updated
            }
        }
    }

    func duplicateProjectBackend(_ projectId: String, name: String? = nil) async throws -> FusionProject {
        guard let ipc = ipcClient else {
            throw NSError(domain: "FusionProject", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.projectDuplicate(projectId: projectId, name: name)
        let newProject = FusionProject.fromDict(result)
        await MainActor.run {
            self.projects.insert(newProject, at: 0)
        }
        return newProject
    }

    // MARK: - Chat Backend Operations

    func loadChatsForProject(_ projectId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.projectChatList(projectId: projectId)
            if let items = result as? [[String: Any]] {
                let chats = items.compactMap { ProjectChat.fromDict($0) }
                await MainActor.run {
                    if let idx = self.projects.firstIndex(where: { $0.id == projectId }) {
                        self.projects[idx].chats = chats
                        if self.activeProject?.id == projectId {
                            self.activeProject?.chats = chats
                        }
                    }
                }
            }
        } catch {
            projectLog.error("loadChats failed: \(error.localizedDescription)")
        }
    }

    func createChat(projectId: String, title: String = "New Chat", model: String? = nil,
                     agentId: String? = nil) async throws -> ProjectChat {
        guard let ipc = ipcClient else {
            throw NSError(domain: "FusionProject", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.projectChatCreate(projectId: projectId, title: title,
                                                       model: model, agentId: agentId)
        let chat = ProjectChat.fromDict(result)
        await MainActor.run {
            if let idx = self.projects.firstIndex(where: { $0.id == projectId }) {
                self.projects[idx].chats.insert(chat, at: 0)
                if self.activeProject?.id == projectId {
                    self.activeProject?.chats.insert(chat, at: 0)
                }
            }
            self.activeChat = chat
        }
        projectLog.info("Chat created: \(chat.title)")
        return chat
    }

    func deleteChat(_ chatId: String, projectId: String) async throws {
        guard let ipc = ipcClient else { return }
        try await ipc.projectChatDelete(chatId: chatId)
        await MainActor.run {
            if let idx = self.projects.firstIndex(where: { $0.id == projectId }) {
                self.projects[idx].chats.removeAll { $0.id == chatId }
                if self.activeProject?.id == projectId {
                    self.activeProject?.chats.removeAll { $0.id == chatId }
                }
            }
            if self.activeChat?.id == chatId {
                self.activeChat = nil
                self.activeChatMessages = []
            }
        }
    }

    func forkChat(_ chatId: String, label: String? = nil) async throws -> ProjectChat {
        guard let ipc = ipcClient else {
            throw NSError(domain: "FusionProject", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.projectChatFork(chatId: chatId, label: label)
        let forked = ProjectChat.fromDict(result)
        return forked
    }

    func loadMessages(chatId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.projectMessageList(chatId: chatId)
            if let items = result as? [[String: Any]] {
                let msgs = items.compactMap { ChatMessage.fromDict($0) }
                await MainActor.run { self.activeChatMessages = msgs }
            }
        } catch {
            projectLog.error("loadMessages failed: \(error.localizedDescription)")
        }
    }

    func sendMessage(chatId: String, content: String, ragMode: String? = nil,
                      ragScope: [String]? = nil) async throws -> ChatMessage {
        guard let ipc = ipcClient else {
            throw NSError(domain: "FusionProject", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "IPCClient not set"])
        }
        let result = try await ipc.projectMessageAdd(chatId: chatId, content: content,
                                                        ragMode: ragMode, ragScope: ragScope)
        let msg = ChatMessage.fromDict(result)
        await MainActor.run {
            self.activeChatMessages.append(msg)
            // 审计0827 #7: activeChatMessages 无界 append, 长会话单调增长, cap 200 复用 PERF-3 ragResults 范式。
            if self.activeChatMessages.count > 200 {
                self.activeChatMessages.removeFirst(self.activeChatMessages.count - 200)
            }
        }
        return msg
    }

    // MARK: - Knowledge Backend Operations

    func loadKnowledgeFiles(projectId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.projectKnowledgeFileList(projectId: projectId)
            if let items = result as? [[String: Any]] {
                let files = items.compactMap { KnowledgeFile.fromDict($0) }
                await MainActor.run {
                    if let idx = self.projects.firstIndex(where: { $0.id == projectId }) {
                        self.projects[idx].knowledgeFiles = files
                        if self.activeProject?.id == projectId {
                            self.activeProject?.knowledgeFiles = files
                        }
                    }
                }
            }
        } catch {
            projectLog.error("loadKnowledgeFiles failed: \(error.localizedDescription)")
        }
    }

    func loadKnowledgeFolders(projectId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.projectFolderList(projectId: projectId)
            if let items = result as? [[String: Any]] {
                let folders = items.compactMap { KnowledgeFolder.fromDict($0) }
                await MainActor.run {
                    if let idx = self.projects.firstIndex(where: { $0.id == projectId }) {
                        self.projects[idx].knowledgeFolders = folders
                        if self.activeProject?.id == projectId {
                            self.activeProject?.knowledgeFolders = folders
                        }
                    }
                }
            }
        } catch {
            projectLog.error("loadKnowledgeFolders failed: \(error.localizedDescription)")
        }
    }

    func uploadKnowledgeFile(projectId: String, sourcePath: String, originalName: String,
                              folderId: String? = nil) async throws {
        guard let ipc = ipcClient else { return }
        _ = try await ipc.projectKnowledgeFileUpload(projectId: projectId, sourcePath: sourcePath,
                                                       originalName: originalName, folderId: folderId)
        await loadKnowledgeFiles(projectId: projectId)
        projectLog.info("Knowledge file uploaded: \(originalName)")
    }

    func deleteKnowledgeFile(projectId: String, fileId: String) async throws {
        guard let ipc = ipcClient else { return }
        try await ipc.projectKnowledgeFileDelete(fileId: fileId)
        await loadKnowledgeFiles(projectId: projectId)
    }

    // MARK: - Agent Backend Operations

    func loadAgentBinding(projectId: String) async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.projectAgentGet(projectId: projectId)
            let binding = AgentBinding.fromDict(result)
            await MainActor.run {
                if let idx = self.projects.firstIndex(where: { $0.id == projectId }) {
                    self.projects[idx].agentBinding = binding
                    if self.activeProject?.id == projectId {
                        self.activeProject?.agentBinding = binding
                    }
                }
            }
        } catch {
            projectLog.error("loadAgentBinding failed: \(error.localizedDescription)")
        }
    }

    func setAgentBinding(projectId: String, agentId: String?,
                          mergeMode: PromptMergeMode?) async throws {
        guard let ipc = ipcClient else { return }
        let result = try await ipc.projectAgentSet(projectId: projectId, agentId: agentId,
                                                     mergeMode: mergeMode?.rawValue)
        let binding = AgentBinding.fromDict(result)
        await MainActor.run {
            if let idx = self.projects.firstIndex(where: { $0.id == projectId }) {
                self.projects[idx].agentBinding = binding
                if self.activeProject?.id == projectId {
                    self.activeProject?.agentBinding = binding
                }
            }
        }
    }

    func listAvailableAgents() async -> [AgentMeta] {
        guard let ipc = ipcClient else { return [] }
        do {
            let result = try await ipc.projectAgentList()
            if let items = result as? [[String: Any]] {
                return items.compactMap { AgentMeta.fromDict($0) }
            }
        } catch {
            projectLog.error("listAvailableAgents failed: \(error.localizedDescription)")
        }
        return []
    }

    // MARK: - Upstream Health

    func checkUpstreamHealth() async {
        guard let ipc = ipcClient else { return }
        do {
            let result = try await ipc.projectUpstreamHealth()
            let degraded = (result["rag"] as? String == "down") || (result["mlx"] as? String == "down")
            await MainActor.run { self.upstreamDegraded = degraded }
        } catch {
            await MainActor.run { self.upstreamDegraded = true }
        }
    }

    // MARK: - Local Operations (fallback)

    func createProject(name: String, rootPath: String, description: String = "",
                        customInstructions: String = "") -> FusionProject {
        var project = FusionProject(name: name, rootPath: rootPath,
                                    description: description, customInstructions: customInstructions)
        saveProjectToDisk(&project)
        projects.insert(project, at: 0)
        saveIndex()
        projectLog.info("Project created locally: \(name) at \(rootPath)")
        return project
    }

    func updateProject(_ project: FusionProject) {
        var mutated = project
        mutated.updatedAt = Date()
        saveProjectToDisk(&mutated)
        if let idx = projects.firstIndex(where: { $0.id == mutated.id }) {
            projects[idx] = mutated
        }
        if activeProject?.id == mutated.id {
            activeProject = mutated
        }
        saveIndex()
        projectLog.info("Project updated: \(mutated.name)")
    }

    func deleteProject(_ project: FusionProject) {
        let dir = projectDir(project.id)
        try? FileManager.default.removeItem(at: dir)
        projects.removeAll { $0.id == project.id }
        if activeProject?.id == project.id {
            activeProject = nil
            activeChat = nil
            activeChatMessages = []
        }
        saveIndex()
        projectLog.info("Project deleted: \(project.name)")
    }

    func openProject(_ project: FusionProject) {
        var p = project
        p.updatedAt = Date()
        activeProject = p
        activeChat = nil
        activeChatMessages = []
        if let existing = projects.firstIndex(where: { $0.id == project.id }) {
            projects[existing] = p
        }
        saveIndex()
        projectLog.info("Project opened: \(project.name)")
    }

    func closeProject() {
        if var p = activeProject {
            p.updatedAt = Date()
            saveProjectToDisk(&p)
        }
        activeProject = nil
        activeChat = nil
        activeChatMessages = []
        projectLog.info("Project closed")
    }

    // Legacy session methods — map to chat operations
    func createSession(projectId: String, title: String = "New Chat", model: String = "") -> ProjectChat {
        var chat = ProjectChat(projectId: projectId, title: title, model: model)
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return chat }
        var p = projects[idx]
        p.chats.insert(chat, at: 0)
        p.updatedAt = Date()
        activeChat = chat
        saveProjectToDisk(&p)
        projects[idx] = p
        if activeProject?.id == projectId {
            activeProject = p
        }
        saveIndex()
        projectLog.info("Session created: \(title) in project \(p.name)")
        return chat
    }

    func addMessage(toSession sessionId: String, role: String, content: String) {
        guard var project = activeProject,
              let sIdx = project.chats.firstIndex(where: { $0.id == sessionId }) else { return }
        let record = ChatMessage(role: role, content: content)
        project.chats[sIdx].messageCount += 1
        project.chats[sIdx].updatedAt = Date()
        project.chats[sIdx].tokenUsage += estimateTokenCount(content)
        activeChat = project.chats[sIdx]
        activeChatMessages.append(record)
        // 审计0827 #7: activeChatMessages 无界 append, 长会话单调增长, cap 200 复用 PERF-3 ragResults 范式。
        if activeChatMessages.count > 200 {
            activeChatMessages.removeFirst(activeChatMessages.count - 200)
        }
        updateProject(project)
    }

    func loadSession(_ session: ProjectChat) {
        activeChat = session
        projectLog.info("Session loaded: \(session.title)")
    }

    func deleteSession(_ session: ProjectChat, projectId: String) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        var p = projects[idx]
        p.chats.removeAll { $0.id == session.id }
        if activeChat?.id == session.id {
            activeChat = p.chats.first
        }
        saveProjectToDisk(&p)
        projects[idx] = p
        if activeProject?.id == projectId {
            activeProject = p
        }
        saveIndex()
        projectLog.info("Session deleted: \(session.title)")
    }

    func addKnowledgeFile(_ file: KnowledgeFile, projectId: String) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        var p = projects[idx]
        p.knowledgeFiles.append(file)
        p.updatedAt = Date()
        saveProjectToDisk(&p)
        projects[idx] = p
        if activeProject?.id == projectId {
            activeProject = p
        }
        saveIndex()
        projectLog.info("Knowledge file added: \(file.fileName) to project \(p.name)")
    }

    func removeKnowledgeFile(id: String, projectId: String) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        var p = projects[idx]
        p.knowledgeFiles.removeAll { $0.id == id }
        p.updatedAt = Date()
        saveProjectToDisk(&p)
        projects[idx] = p
        if activeProject?.id == projectId {
            activeProject = p
        }
        saveIndex()
    }

    func scanKnowledgeFiles(projectId: String) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        var p = projects[idx]
        let root = URL(fileURLWithPath: p.rootPath)
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                              options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) else { return }

        var existing = Set(p.knowledgeFiles.map(\.filePath))
        var added = 0

        for case let itemURL as URL in enumerator {
            let ext = itemURL.pathExtension.lowercased()
            guard knowledgeExtensions.contains(ext) else { continue }
            guard !existing.contains(itemURL.path) else { continue }

            let attrs = try? fm.attributesOfItem(atPath: itemURL.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            if size > 500_000 { continue }

            let kf = KnowledgeFile(
                fileName: itemURL.lastPathComponent,
                filePath: itemURL.path,
                fileSize: size,
                tokenCount: estimateTokenCountFromFile(at: itemURL.path),
                scope: .project
            )
            p.knowledgeFiles.append(kf)
            existing.insert(itemURL.path)
            added += 1
        }

        if added > 0 {
            p.updatedAt = Date()
            saveProjectToDisk(&p)
            projects[idx] = p
            if activeProject?.id == projectId {
                activeProject = p
            }
            saveIndex()
            projectLog.info("Scanned and added \(added) knowledge files to project \(p.name)")
        }
    }

    func importFromRecentProjects(_ recents: [RecentProject]) {
        for recent in recents {
            if projects.contains(where: { $0.rootPath == recent.path }) { continue }
            let project = FusionProject.from(recent: recent)
            var mutable = project
            saveProjectToDisk(&mutable)
            projects.append(mutable)
        }
        saveIndex()
        projectLog.info("Imported \(recents.count) recent projects")
    }

    func ingestKnowledgeToRAG(projectId: String) async {
        guard let client = ipcClient else {
            projectLog.warning("IPCClient not set, skipping knowledge ingestion")
            return
        }
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        let project = projects[idx]
        let scope = "project:\(project.id)"

        for file in project.knowledgeFiles {
            // 审计0827 #2: knowledgeFiles 路径可能来自导入项目 (非本机用户面板选择), 防 symlink/.. 越界读, validateFilePath 拒则跳过。
            guard SecurityManager.shared.validateFilePath(file.filePath) else { continue }
            guard let content = try? String(contentsOfFile: file.filePath, encoding: .utf8) else { continue }
            let metadata: [String: Any] = [
                "file_name": file.fileName,
                "file_path": file.filePath,
                "project_id": project.id
            ]
            do {
                _ = try await client.knowledgeIngest(content: content, scope: scope, metadata: metadata)
            } catch {
                projectLog.warning("Failed to ingest \(file.fileName): \(error.localizedDescription)")
            }
        }
        projectLog.info("Ingested \(project.knowledgeFiles.count) files to RAG for project \(project.name)")
    }

    // MARK: - Persistence

    private func projectDir(_ id: String) -> URL {
        baseDir.appendingPathComponent(id, isDirectory: true)
    }

    private func saveProjectToDisk(_ project: inout FusionProject) {
        let dir = projectDir(project.id)
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let metaURL = dir.appendingPathComponent("project.json")
        if let data = try? encoder.encode(project) {
            try? data.write(to: metaURL, options: .atomic)
        }

        if !project.customInstructions.isEmpty {
            let instURL = dir.appendingPathComponent("instructions.md")
            try? project.customInstructions.write(to: instURL, atomically: true, encoding: .utf8)
        }

        if let settingsData = try? encoder.encode(project.settings) {
            let settingsURL = dir.appendingPathComponent("settings.json")
            try? settingsData.write(to: settingsURL, options: .atomic)
        }
    }

    private func saveIndex() {
        let index = projects.map {
            ProjectIndex(id: $0.id, name: $0.name, rootPath: $0.rootPath, updatedAt: $0.updatedAt)
        }
        if let data = try? encoder.encode(index) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    private func loadProjects() {
        isLoading = true

        if let data = try? Data(contentsOf: indexURL),
           let index = try? decoder.decode([ProjectIndex].self, from: data) {
            for entry in index {
                let metaURL = projectDir(entry.id).appendingPathComponent("project.json")
                if let data = try? Data(contentsOf: metaURL),
                   let project = try? decoder.decode(FusionProject.self, from: data) {
                    projects.append(project)
                }
            }
        }

        isLoading = false
        projectLog.info("Loaded \(self.projects.count) projects")
    }

    // 后端项目加载成功后，清理本地遗留的 fallback 项目目录（大写 UUID 等），
    // 防止下次 init 再加载进列表 → 点会话传本地 id 给后端 → "project not found"。
    private func purgeStaleLocalProjects(keeping backendIds: Set<String>) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) else { return }
        var removed = 0
        for dir in entries where dir.hasDirectoryPath {
            let pid = dir.lastPathComponent
            if !backendIds.contains(pid) {
                try? fm.removeItem(at: dir)
                removed += 1
            }
        }
        if removed > 0 {
            let kept = entries.filter { backendIds.contains($0.lastPathComponent) }
            let newIndex = kept.map { ProjectIndex(id: $0.lastPathComponent, name: "", rootPath: "", updatedAt: Date()) }
            if let data = try? encoder.encode(newIndex) {
                try? data.write(to: indexURL, options: .atomic)
            }
            projectLog.info("Purged \(removed) stale local project dirs not in backend")
        }
    }

    private let knowledgeExtensions: Set<String> = [
        "md", "txt", "swift", "py", "js", "ts", "tsx", "jsx", "json",
        "yaml", "yml", "toml", "rs", "go", "java", "c", "h", "cpp", "hpp"
    ]

    private func estimateTokenCount(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    private func estimateTokenCountFromFile(at path: String) -> Int {
        // 审计0827 #2: path 来自 knowledgeFiles (可能导入项目), validateFilePath 拒则返 0 token。
        guard SecurityManager.shared.validateFilePath(path) else { return 0 }
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return 0 }
        return estimateTokenCount(content)
    }

    private struct ProjectIndex: Codable {
        let id: String
        let name: String
        let rootPath: String
        let updatedAt: Date
    }
}

// MARK: - Dict Parsing Extensions

extension ProjectChat {
    static func fromDict(_ d: [String: Any]) -> ProjectChat {
        var chat = ProjectChat(
            id: d["id"] as? String ?? UUID().uuidString,
            projectId: d["project_id"] as? String ?? "",
            title: d["title"] as? String ?? "New Chat",
            model: d["model"] as? String ?? "",
            agentId: d["agent_id"] as? String,
            isStarred: d["is_starred"] as? Bool ?? false,
            messageCount: d["message_count"] as? Int ?? 0,
            tokenUsage: d["token_usage"] as? Int ?? 0,
            forkedFrom: d["forked_from"] as? String,
            forkLabel: d["fork_label"] as? String
        )
        chat.createdAt = ISO8601DateFormatter().date(from: d["created_at"] as? String ?? "") ?? Date()
        chat.updatedAt = ISO8601DateFormatter().date(from: d["updated_at"] as? String ?? "") ?? Date()
        return chat
    }
}

extension ChatMessage {
    static func fromDict(_ d: [String: Any]) -> ChatMessage {
        var msg = ChatMessage(
            id: d["id"] as? String ?? UUID().uuidString,
            role: d["role"] as? String ?? "user",
            content: d["content"] as? String ?? "",
            ragSources: d["rag_sources"] as? [String],
            tempAttachmentIds: d["temp_attachment_ids"] as? [String]
        )
        msg.timestamp = ISO8601DateFormatter().date(from: d["timestamp"] as? String ?? "") ?? Date()
        return msg
    }
}

extension KnowledgeFile {
    static func fromDict(_ d: [String: Any]) -> KnowledgeFile {
        KnowledgeFile(
            id: d["id"] as? String ?? UUID().uuidString,
            fileName: d["file_name"] as? String ?? d["original_name"] as? String ?? "unknown",
            filePath: d["file_path"] as? String ?? d["source_path"] as? String ?? "",
            fileSize: d["file_size"] as? Int64 ?? 0,
            tokenCount: d["token_count"] as? Int ?? 0,
            scope: .project,
            folderId: d["folder_id"] as? String,
            indexStatus: d["index_status"] as? String ?? "pending",
            mimeType: d["mime_type"] as? String
        )
    }
}

extension KnowledgeFolder {
    static func fromDict(_ d: [String: Any]) -> KnowledgeFolder {
        KnowledgeFolder(
            id: d["id"] as? String ?? UUID().uuidString,
            name: d["name"] as? String ?? "Unnamed",
            parentId: d["parent_id"] as? String,
            fileCount: d["file_count"] as? Int ?? 0
        )
    }
}

extension AgentBinding {
    static func fromDict(_ d: [String: Any]) -> AgentBinding {
        let mergeStr = d["merge_mode"] as? String ?? "AGENT_FIRST"
        return AgentBinding(
            agentId: d["agent_id"] as? String,
            agentName: d["agent_name"] as? String,
            mergeMode: PromptMergeMode(rawValue: mergeStr) ?? .AGENT_FIRST,
            agentPrompt: d["agent_prompt"] as? String
        )
    }
}

extension AgentMeta {
    static func fromDict(_ d: [String: Any]) -> AgentMeta {
        AgentMeta(
            id: d["id"] as? String ?? UUID().uuidString,
            name: d["name"] as? String ?? "Unknown Agent",
            description: d["description"] as? String,
            icon: d["icon"] as? String,
            capabilities: d["capabilities"] as? [String]
        )
    }
}
