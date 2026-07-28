// Callers: ProjectsPanel, FusionSidebarView, ContextAssembler, AgentBridge, FusionCodeView.
// Affected API: FusionProjectManager.shared (CRUD + persistence), replaces RecentProject usage.
// Data schemas: FusionProject, KnowledgeFile, ProjectSession, ProjectSettings, KnowledgeScope.
// User instruction: "立即落地fusion projects"

import Foundation
import os.log

private let projectLog = Logger(subsystem: "com.fusion.studio", category: "FusionProject")

enum KnowledgeScope: String, Codable, CaseIterable {
    case project
    case session
    case global
}

struct KnowledgeFile: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    var filePath: String
    var fileSize: Int64
    var tokenCount: Int
    var addedAt: Date
    var scope: KnowledgeScope

    init(fileName: String, filePath: String, fileSize: Int64 = 0, tokenCount: Int = 0, scope: KnowledgeScope = .project) {
        self.id = UUID()
        self.fileName = fileName
        self.filePath = filePath
        self.fileSize = fileSize
        self.tokenCount = tokenCount
        self.addedAt = Date()
        self.scope = scope
    }
}

struct ProjectSession: Identifiable, Codable, Equatable {
    let id: UUID
    var projectId: UUID
    var title: String
    var messages: [ChatMessageRecord]
    var createdAt: Date
    var updatedAt: Date
    var model: String
    var tokenUsage: Int

    init(projectId: UUID, title: String, model: String = "") {
        self.id = UUID()
        self.projectId = projectId
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.model = model
        self.tokenUsage = 0
    }
}

struct ChatMessageRecord: Codable, Equatable {
    var role: String
    var content: String
    var timestamp: Date

    init(role: String, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
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
    let id: UUID
    var name: String
    var description: String
    var rootPath: String
    var customInstructions: String
    var knowledgeFiles: [KnowledgeFile]
    var sessions: [ProjectSession]
    var createdAt: Date
    var updatedAt: Date
    var settings: ProjectSettings

    init(name: String, rootPath: String, description: String = "", customInstructions: String = "") {
        self.id = UUID()
        self.name = name
        self.rootPath = rootPath
        self.description = description
        self.customInstructions = customInstructions
        self.knowledgeFiles = []
        self.sessions = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.settings = ProjectSettings()
    }

    var totalKnowledgeTokens: Int {
        knowledgeFiles.reduce(0) { $0 + $1.tokenCount }
    }

    var hasKnowledge: Bool {
        !knowledgeFiles.isEmpty
    }

    var hasInstructions: Bool {
        !customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var lastOpened: Date {
        sessions.last?.updatedAt ?? updatedAt
    }

    static func from(recent: RecentProject) -> FusionProject {
        FusionProject(name: recent.name, rootPath: recent.path)
    }
}

class FusionProjectManager: ObservableObject {
    static let shared = FusionProjectManager()

    @Published var projects: [FusionProject] = []
    @Published var activeProject: FusionProject?
    @Published var activeSession: ProjectSession?
    @Published var isLoading: Bool = false

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
    }

    func createProject(name: String, rootPath: String, description: String = "", customInstructions: String = "") -> FusionProject {
        var project = FusionProject(name: name, rootPath: rootPath, description: description, customInstructions: customInstructions)
        saveProjectToDisk(&project)
        projects.insert(project, at: 0)
        saveIndex()
        projectLog.info("Project created: \(name) at \(rootPath)")
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
            activeSession = nil
        }
        saveIndex()
        projectLog.info("Project deleted: \(project.name)")
    }

    func openProject(_ project: FusionProject) {
        var p = project
        p.updatedAt = Date()
        activeProject = p
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
        activeSession = nil
        projectLog.info("Project closed")
    }

    func createSession(projectId: UUID, title: String = "New Chat", model: String = "") -> ProjectSession {
        let session = ProjectSession(projectId: projectId, title: title, model: model)
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return session }
        var p = projects[idx]
        p.sessions.insert(session, at: 0)
        p.updatedAt = Date()
        activeSession = session
        saveProjectToDisk(&p)
        projects[idx] = p
        if activeProject?.id == projectId {
            activeProject = p
        }
        saveIndex()
        projectLog.info("Session created: \(title) in project \(p.name)")
        return session
    }

    func addMessage(toSession sessionId: UUID, role: String, content: String) {
        guard var project = activeProject,
              let sIdx = project.sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        let record = ChatMessageRecord(role: role, content: content)
        project.sessions[sIdx].messages.append(record)
        project.sessions[sIdx].updatedAt = Date()
        project.sessions[sIdx].tokenUsage += estimateTokenCount(content)
        activeSession = project.sessions[sIdx]
        updateProject(project)
    }

    func loadSession(_ session: ProjectSession) {
        activeSession = session
        projectLog.info("Session loaded: \(session.title)")
    }

    func deleteSession(_ session: ProjectSession, projectId: UUID) {
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        var p = projects[idx]
        p.sessions.removeAll { $0.id == session.id }
        if activeSession?.id == session.id {
            activeSession = p.sessions.first
        }
        saveProjectToDisk(&p)
        projects[idx] = p
        if activeProject?.id == projectId {
            activeProject = p
        }
        saveIndex()
        projectLog.info("Session deleted: \(session.title)")
    }

    func addKnowledgeFile(_ file: KnowledgeFile, projectId: UUID) {
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

    func removeKnowledgeFile(id: UUID, projectId: UUID) {
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
        projectLog.info("Knowledge file removed from project \(p.name)")
    }

    func scanKnowledgeFiles(projectId: UUID) {
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

    func ingestKnowledgeToRAG(projectId: UUID) async {
        guard let client = ipcClient else {
            projectLog.warning("IPCClient not set, skipping knowledge ingestion")
            return
        }
        guard let idx = projects.firstIndex(where: { $0.id == projectId }) else { return }
        let project = projects[idx]
        let scope = "project:\(project.id.uuidString)"

        for file in project.knowledgeFiles {
            guard let content = try? String(contentsOfFile: file.filePath, encoding: .utf8) else { continue }
            let metadata: [String: Any] = [
                "file_name": file.fileName,
                "file_path": file.filePath,
                "project_id": project.id.uuidString
            ]
            do {
                _ = try await client.knowledgeIngest(content: content, scope: scope, metadata: metadata)
            } catch {
                projectLog.warning("Failed to ingest \(file.fileName): \(error.localizedDescription)")
            }
        }
        projectLog.info("Ingested \(project.knowledgeFiles.count) files to RAG for project \(project.name)")
    }

    private func projectDir(_ id: UUID) -> URL {
        baseDir.appendingPathComponent(id.uuidString, isDirectory: true)
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
        let index = projects.map { ProjectIndex(id: $0.id, name: $0.name, rootPath: $0.rootPath, updatedAt: $0.updatedAt) }
        if let data = try? encoder.encode(index) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    private func loadProjects() {
        isLoading = true

        if let data = try? Data(contentsOf: indexURL), let index = try? decoder.decode([ProjectIndex].self, from: data) {
            for entry in index {
                let metaURL = projectDir(entry.id).appendingPathComponent("project.json")
                if let data = try? Data(contentsOf: metaURL), let project = try? decoder.decode(FusionProject.self, from: data) {
                    projects.append(project)
                }
            }
        }

        isLoading = false
        projectLog.info("Loaded \(self.projects.count) projects")
    }

    private let knowledgeExtensions: Set<String> = ["md", "txt", "swift", "py", "js", "ts", "tsx", "jsx", "json", "yaml", "yml", "toml", "rs", "go", "java", "c", "h", "cpp", "hpp"]

    private func estimateTokenCount(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    private func estimateTokenCountFromFile(at path: String) -> Int {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return 0 }
        return estimateTokenCount(content)
    }

    private struct ProjectIndex: Codable {
        let id: UUID
        let name: String
        let rootPath: String
        let updatedAt: Date
    }
}
