// Callers: UnifiedChatView, AgentStudioView — chat session state management
// Affected API: ChatSessionStore @MainActor ObservableObject (CRUD + send via IPC)
// Data schemas: ChatMessageData (id/role/content/parentId/childrenIds/toolCalls), ChatSessionData (id/title/mode/messages/activeBranch)

import AppKit
import Foundation

struct FusionCodeProject: Codable, Identifiable {
    let id: String
    let name: String
    let path: String?
    let createdAt: Double?
    let updatedAt: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, path
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
import Combine
import Foundation
import os.log

private let chatStoreLog = Logger(subsystem: "com.fusion.studio", category: "ChatSessionStore")

struct AttachmentData: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let type: String       // "image" | "file"
    let mimeType: String   // e.g. "image/png", "text/plain"
    let dataBase64: String // base64-encoded content

    init(
        id: String = UUID().uuidString,
        name: String,
        type: String,
        mimeType: String,
        dataBase64: String
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.mimeType = mimeType
        self.dataBase64 = dataBase64
    }

    var isImage: Bool { type == "image" }

    static func == (lhs: AttachmentData, rhs: AttachmentData) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChatMessageData: Identifiable, Equatable {
    let id: String
    let role: String
    let content: String
    let mode: String
    let parentId: String
    let childrenIds: [String]
    let toolCalls: [[String: Any]]
    let metadata: [String: Any]
    let createdAt: Double
    var attachments: [AttachmentData]

    init(
        id: String = UUID().uuidString,
        role: String,
        content: String,
        mode: String = "",
        parentId: String = "",
        childrenIds: [String] = [],
        toolCalls: [[String: Any]] = [],
        metadata: [String: Any] = [:],
        createdAt: Double = Date().timeIntervalSince1970,
        attachments: [AttachmentData] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.mode = mode
        self.parentId = parentId
        self.childrenIds = childrenIds
        self.toolCalls = toolCalls
        self.metadata = metadata
        self.createdAt = createdAt
        self.attachments = attachments
    }

    static func == (lhs: ChatMessageData, rhs: ChatMessageData) -> Bool {
        lhs.id == rhs.id
    }

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
}

struct ChatSessionData: Identifiable {
    let id: String
    var title: String
    var mode: String
    var messages: [ChatMessageData]
    var activeBranch: String
    var graphId: String
    var isPinned: Bool
    var preset: String?
    var outputStyle: String?
    var projectId: String?
    var activeSkill: String?
    var createdAt: Double
    var updatedAt: Double

    init(
        id: String = UUID().uuidString,
        title: String = "",
        mode: String = "simple",
        messages: [ChatMessageData] = [],
        activeBranch: String = "",
        graphId: String = "",
        isPinned: Bool = false,
        preset: String? = nil,
        outputStyle: String? = nil,
        projectId: String? = nil,
        activeSkill: String? = nil,
        createdAt: Double = Date().timeIntervalSince1970,
        updatedAt: Double = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.title = title
        self.mode = mode
        self.messages = messages
        self.activeBranch = activeBranch
        self.graphId = graphId
        self.isPinned = isPinned
        self.preset = preset
        self.outputStyle = outputStyle
        self.projectId = projectId
        self.activeSkill = activeSkill
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var linearBranch: [ChatMessageData] {
        guard !messages.isEmpty else { return [] }
        var leaf = activeBranch
        if leaf.isEmpty, let first = messages.first {
            leaf = first.id
        }
        var chain: [ChatMessageData] = []
        var current = messages.first(where: { $0.id == leaf })
        while let msg = current {
            chain.append(msg)
            if msg.parentId.isEmpty { break }
            current = messages.first(where: { $0.id == msg.parentId })
        }
        return chain.reversed()
    }
}

enum ChatMode: String, CaseIterable {
    case simple = "simple"
    case agent = "agent"
    case code = "code"
    case design = "design"
    case rag = "rag"
    case research = "research"

    var label: String {
        switch self {
        case .simple: return "Chat"
        case .agent: return "Agent"
        case .code: return "Code"
        case .design: return "Design"
        case .rag: return "RAG"
        case .research: return "Research"
        }
    }

    var icon: String {
        switch self {
        case .simple: return "bubble.left.and.bubble.right"
        case .agent: return "brain"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .design: return "paintbrush"
        case .rag: return "doc.text.magnifyingglass"
        case .research: return "magnifyingglass"
        }
    }
}

// Callers: UnifiedChatView quickCard. Affected API: ChatPreset.systemPrompt. Data: preset→system prompt injection per PRD L1.
enum ChatPreset: String, CaseIterable {
    case code = "code"
    case write = "write"
    case create = "create"
    case learn = "learn"
    case life = "life"

    var label: String {
        switch self {
        case .code: return "Code"
        case .write: return "Write"
        case .create: return "Create"
        case .learn: return "Learn"
        case .life: return "Life"
        }
    }

    var icon: String {
        switch self {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .write: return "pencil"
        case .create: return "sparkles"
        case .learn: return "book"
        case .life: return "heart"
        }
    }

    var systemPrompt: String {
        switch self {
        case .code:
            return "You are an expert coding assistant. Prioritize code blocks, diffs, step-by-step debugging, and concise technical explanations. Minimize verbose natural language."
        case .write:
            return "You are a professional writing assistant. Focus on logical structure, consistent tone, clear paragraph organization, and polished formal output. Prefer structured headings and logical argumentation."
        case .create:
            return "You are a creative brainstorming assistant. Encourage divergent thinking, provide multiple alternative proposals, and generate imaginative concepts. Embrace bold ideas."
        case .learn:
            return "You are a patient learning tutor. Explain concepts from simple to deep, use analogies and examples, actively confirm understanding of key points, and create structured study outlines."
        case .life:
            return "You are a helpful daily life assistant. Give concise, practical advice for travel planning, to-do lists, decision-making, and everyday questions. Keep responses light and actionable."
        }
    }

    var placeholder: String {
        switch self {
        case .code: return "Ask me to write, debug, or refactor code..."
        case .write: return "Ask me to help write a document, email, or report..."
        case .create: return "Ask me to brainstorm ideas, stories, or concepts..."
        case .learn: return "Ask me to explain a concept or create a study plan..."
        case .life: return "Ask me to plan a trip, make a list, or help decide..."
        }
    }
}

enum OutputStyle: String, CaseIterable {
    case formal = "formal"
    case concise = "concise"
    case technical = "technical"
    case academic = "academic"

    var label: String {
        switch self {
        case .formal: return "正式"
        case .concise: return "极简"
        case .technical: return "技术文档"
        case .academic: return "学术"
        }
    }

    var icon: String {
        switch self {
        case .formal: return "text.badge.star"
        case .concise: return "text.badge.minus"
        case .technical: return "text.badge.checkmark"
        case .academic: return "text.badge.plus"
        }
    }

    var stylePrompt: String {
        switch self {
        case .formal: return "Use a formal, professional tone with complete sentences and polished language."
        case .concise: return "Be extremely concise. Use bullet points and short phrases. Avoid filler words."
        case .technical: return "Format output as technical documentation with headers, code examples, parameter tables, and versioned sections."
        case .academic: return "Use academic style: citations, abstract, methodology, structured argumentation, and formal terminology."
        }
    }
}

@MainActor
class ChatSessionStore: ObservableObject {
    @Published var sessions: [ChatSessionData] = []
    @Published var activeSession: ChatSessionData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var streamingContent: String = ""
    @Published var isGenerating: Bool = false
    @Published var selectedModel: String = ""
    @Published var isWebSearchEnabled: Bool = false

    // F-R2: onToken 节流状态。3 处 inferStream onToken 累积 token 到 buffer,
    // 距上次刷新 >50ms 才 hop MainActor 写 streamingContent, 防千 token 千 Task 风暴。
    // 每次 inferStream 开始前 resetStreamThrottle() 重置, 流结束 streamingContent 置空兜底残量。
    private var streamTokenBuffer = ""
    private var streamLastFlush = DispatchTime.now()
    private let streamThrottleNs: UInt64 = 50_000_000

    private func resetStreamThrottle() {
        streamTokenBuffer = ""
        streamLastFlush = DispatchTime.now()
    }

    private func appendStreamToken(_ token: String) {
        streamTokenBuffer += token
        let now = DispatchTime.now()
        if now.uptimeNanoseconds - streamLastFlush.uptimeNanoseconds >= streamThrottleNs {
            streamLastFlush = now
            let snapshot = streamTokenBuffer
            streamTokenBuffer = ""
            Task { @MainActor in
                self.streamingContent += snapshot
            }
        }
    }

    private func flushStreamBuffer() {
        guard !streamTokenBuffer.isEmpty else { return }
        let snapshot = streamTokenBuffer
        streamTokenBuffer = ""
        Task { @MainActor in
            self.streamingContent += snapshot
        }
    }

    private var ipc: IPCClient?
    weak var agentBridge: AgentBridge?
    private let storeDir = NSHomeDirectory() + "/.fusion-studio/chats"
    private var fcBridge: FusionCodeBridge?
    private var activeRAGWatchId: String?
    private var activeRAGWatchKbId: String?

    // 审计0827 §2.2 (P0/P1): sessions + 每 session.messages 双重无界, 长会话 OOM 杀进程。
    // cap 复用 PERF-3 ragResults 范式: 超限 removeFirst。capSessions 限总会话数, capMessages 限单会话消息数。
    // 500 消息 ≈ 长对话上限 (超则丢最早, 保最新上下文); 200 会话 ≈ 多轮切换上限。注册 StudioMemoryMonitor 兜底。
    private static let maxSessions = 200
    private static let maxMessagesPerSession = 500

    private func capSessions() {
        if sessions.count > Self.maxSessions {
            let drop = sessions.count - Self.maxSessions
            chatStoreLog.info("capSessions: drop \(drop) oldest (count=\(self.sessions.count) > \(Self.maxSessions))")
            sessions.removeLast(drop)
        }
    }

    private func capMessages(_ session: inout ChatSessionData) {
        if session.messages.count > Self.maxMessagesPerSession {
            let drop = session.messages.count - Self.maxMessagesPerSession
            let sid = session.id
            session.messages.removeFirst(drop)
            chatStoreLog.info("capMessages: session=\(sid, privacy: .public) drop \(drop) oldest (count > \(Self.maxMessagesPerSession))")
        }
    }

    init() {}

    func setIPCClient(_ client: IPCClient) {
        self.ipc = client
    }

    func setAgentBridge(_ bridge: AgentBridge) {
        self.agentBridge = bridge
    }

    func setFusionCodeBridge(_ bridge: FusionCodeBridge) {
        self.fcBridge = bridge
        chatStoreLog.info("FusionCodeBridge set on ChatSessionStore")
    }

    func fetchProjects() async -> [FusionCodeProject] {
        guard let bridge = fcBridge else {
            chatStoreLog.warning("fetchProjects: no FusionCodeBridge, returning empty")
            return []
        }
        do {
            let rawProjects = try await bridge.listProjects()
            return rawProjects.compactMap { p in
                guard let id = p["id"] as? String, let name = p["name"] as? String else { return nil }
                return FusionCodeProject(
                    id: id,
                    name: name,
                    path: p["path"] as? String,
                    createdAt: p["created_at"] as? Double,
                    updatedAt: p["updated_at"] as? Double
                )
            }
        } catch {
            chatStoreLog.error("fetchProjects failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Local persistence

    // 审计0827 §3.2 (P1): nonisolated — storeDir 是 let, createDirectory 无状态依赖, 可后台跑。
    nonisolated private func ensureStoreDir() {
        try? FileManager.default.createDirectory(atPath: storeDir, withIntermediateDirectories: true)
    }

    private func sessionPath(_ id: String) -> String {
        return storeDir + "/" + id + ".json"
    }

    private func saveSessionLocal(_ session: ChatSessionData) {
        ensureStoreDir()
        let dict = sessionToDict(session)
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else {
            chatStoreLog.error("saveSessionLocal: JSON serialize failed id=\(session.id, privacy: .public)")
            return
        }
        // 审计0827 #22: try? 吞写盘错, 用户消息看似发送但未持久化, 崩溃后丢失。改 do/catch 记 error。
        // 审计0827 §3.2 (P1): data.write 同步 I/O 在 @MainActor 阻塞主线程, 磁盘忙时 UI 卡顿。
        // sessionToDict 已 capture 值类型 + data 是值, 后台线程写盘安全。派 cooperative queue。
        let path = sessionPath(session.id)
        let sid = session.id
        DispatchQueue.global(qos: .utility).async {
            do {
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            } catch {
                chatStoreLog.error("saveSessionLocal failed id=\(sid, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func deleteSessionLocal(_ id: String) {
        // 审计0827 #22: try? 吞删错, 改 do/catch 记 error (文件不存在等非致命也记供定位)。
        do {
            try FileManager.default.removeItem(atPath: sessionPath(id))
        } catch {
            chatStoreLog.warning("deleteSessionLocal failed id=\(id, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
    }

    // 审计0827 §3.2 (P1): 文件 I/O (contentsOfDirectory + Data(contentsOf:)) 在 @MainActor 阻塞主线程。
    // 改 nonisolated async — 跑 cooperative 线程池不阻塞 MainActor; parseSessionData/parseMessageData 亦 nonisolated。
    nonisolated private func loadSessionsLocal() async -> [ChatSessionData] {
        ensureStoreDir()
        let fm = FileManager.default
        let dir = storeDir
        // 审计0827 #22: 目录读失败记 error, 非静默返空。
        guard let files = try? fm.contentsOfDirectory(atPath: dir) else {
            chatStoreLog.error("loadSessionsLocal: contentsOfDirectory failed dir=\(dir, privacy: .public)")
            return []
        }
        return files.filter { $0.hasSuffix(".json") }.compactMap { file -> ChatSessionData? in
            let path = storeDir + "/" + file
            // 审计0827 #22: 单文件读/解析失败记 warning 跳过 (可能损坏文件), 不静默返 nil。
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                chatStoreLog.warning("loadSessionsLocal: read failed file=\(file, privacy: .public)")
                return nil
            }
            guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                chatStoreLog.warning("loadSessionsLocal: parse failed file=\(file, privacy: .public)")
                return nil
            }
            return parseSessionData(dict)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func sessionToDict(_ s: ChatSessionData) -> [String: Any] {
        return [
            "id": s.id,
            "title": s.title,
            "mode": s.mode,
            "active_branch": s.activeBranch,
            "graph_id": s.graphId,
            "is_pinned": s.isPinned,
            "preset": s.preset as Any,
            "output_style": s.outputStyle as Any,
            "project_id": s.projectId as Any,
            "active_skill": s.activeSkill as Any,
            "created_at": s.createdAt,
            "updated_at": s.updatedAt,
            "messages": s.messages.map { msg in
                var m: [String: Any] = [
                    "id": msg.id, "role": msg.role, "content": msg.content,
                    "mode": msg.mode, "parent_id": msg.parentId,
                    "created_at": msg.createdAt,
                ]
                if !msg.childrenIds.isEmpty { m["children_ids"] = msg.childrenIds }
                if !msg.attachments.isEmpty {
                    m["attachments"] = msg.attachments.map { a in
                        ["id": a.id, "name": a.name, "type": a.type, "mime_type": a.mimeType, "data_base64": a.dataBase64]
                    }
                }
                return m
            },
        ]
    }

    // MARK: - CRUD

    func ensureActiveSession(mode: String = "simple") {
        guard activeSession == nil else { return }
        let session = ChatSessionData(title: "New Chat", mode: mode)
        sessions.insert(session, at: 0)
        capSessions()
        activeSession = session
        saveSessionLocal(session)
        chatStoreLog.info("ensureActiveSession: created \(session.id)")
    }

    // #217: 外部 bridge (CoworkHomeBridge) 向当前会话追加消息 (工作流进度气泡/用户输入).
    // 复用既有 append 模式: 更新 activeSession + sessions[idx] + 持久化.
    func appendMessage(_ msg: ChatMessageData) {
        guard let session = activeSession else {
            chatStoreLog.warning("appendMessage: no active session, drop")
            return
        }
        var updated = session
        updated.messages.append(msg)
        capMessages(&updated)
        updated.activeBranch = msg.id
        updated.updatedAt = Date().timeIntervalSince1970
        activeSession = updated
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = updated
        }
        saveSessionLocal(updated)
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let ipc = ipc else {
                // 审计0827 §3.2: loadSessionsLocal nonisolated, await 后台读盘不阻塞 MainActor。
                sessions = await loadSessionsLocal()
                capSessions()
                chatStoreLog.info("No IPC, loaded \(self.sessions.count) local sessions")
                return
            }
            let result = try await ipc.call(method: RPCMethod.chatList)
            if let list = result["sessions"] as? [[String: Any]] {
                sessions = list.compactMap { parseSessionData($0) }
                capSessions()
                chatStoreLog.info("Loaded \(self.sessions.count) chat sessions via IPC")
            }
        } catch {
            chatStoreLog.warning("chat.list IPC failed (\(error.localizedDescription)), falling back to local")
            // 审计0827 §3.2: 后台读盘 fallback 不阻塞 MainActor。
            sessions = await loadSessionsLocal()
            capSessions()
        }
    }

    func createSession(mode: String = "simple", title: String = "", graphId: String = "") async {
        let session = ChatSessionData(title: title.isEmpty ? "New Chat" : title, mode: mode, graphId: graphId)
        sessions.insert(session, at: 0)
        capSessions()
        activeSession = session
        saveSessionLocal(session)
        chatStoreLog.info("Created chat session: \(session.id)")

        if let ipc = ipc {
            do {
                var params: [String: Any] = ["mode": mode]
                if !title.isEmpty { params["title"] = title }
                if !graphId.isEmpty { params["graph_id"] = graphId }
                let result = try await ipc.call(method: RPCMethod.chatCreate, params: params)
                if let remote = parseSessionData(result) {
                    deleteSessionLocal(session.id)
                    sessions.remove(at: 0)
                    sessions.insert(remote, at: 0)
                    capSessions()
                    activeSession = remote
                    saveSessionLocal(remote)
                }
            } catch {
                chatStoreLog.warning("chat.create IPC failed, using local session")
            }
        }
    }

    func selectSession(_ session: ChatSessionData) {
        activeSession = session
    }

    func pinSession(_ sessionId: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[idx].isPinned.toggle()
        let pinned = sessions[idx].isPinned
        chatStoreLog.info("Pin session \(sessionId): \(pinned)")
        if activeSession?.id == sessionId {
            activeSession = sessions[idx]
        }
        saveSessionLocal(sessions[idx])
        sortSessions()
    }

    func renameSession(_ sessionId: String, newTitle: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sessions[idx].title = trimmed
        chatStoreLog.info("Rename session \(sessionId): '\(trimmed)'")
        if activeSession?.id == sessionId {
            activeSession = sessions[idx]
        }
        saveSessionLocal(sessions[idx])
    }

    func shareSession(_ sessionId: String) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }
        let text = session.messages.map { msg in
            "[\(msg.role)] \(msg.content)"
        }.joined(separator: "\n\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        chatStoreLog.info("Share session \(sessionId): copied \(session.messages.count) messages to pasteboard")
    }

    private func sortSessions() {
        sessions.sort { a, b in
            if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }

    func deleteSession(_ sessionId: String) async {
        deleteSessionLocal(sessionId)
        sessions.removeAll { $0.id == sessionId }
        if activeSession?.id == sessionId {
            activeSession = sessions.first
            await stopRAGWatch()
        }
        chatStoreLog.info("Deleted chat session: \(sessionId)")
        if let ipc = ipc {
            do {
                _ = try await ipc.call(method: RPCMethod.chatDelete, params: ["session_id": sessionId])
            } catch {
                chatStoreLog.warning("chat.delete IPC failed, local delete done")
            }
        }
    }

    func clearAllSessions() async {
        let ids = sessions.map { $0.id }
        let count = ids.count
        for id in ids {
            deleteSessionLocal(id)
        }
        sessions.removeAll()
        activeSession = nil
        chatStoreLog.info("Cleared all \(count) chat sessions")
        if let ipc = ipc {
            for id in ids {
                do {
                    _ = try await ipc.call(method: RPCMethod.chatDelete, params: ["session_id": id])
                } catch {
                    chatStoreLog.warning("chat.delete IPC failed for \(id)")
                }
            }
        }
    }

    func sendMessage(_ text: String, mode: String = "", attachments: [AttachmentData] = []) async {
        guard let session = activeSession else {
            chatStoreLog.error("sendMessage: no active session, abort")
            return
        }
        chatStoreLog.info("sendMessage: text='\(text.prefix(50))', session=\(session.id), msgs=\(session.messages.count), attachments=\(attachments.count)")
        let userMsg = ChatMessageData(role: "user", content: text, attachments: attachments)
        var updated = session
        updated.messages.append(userMsg)
        capMessages(&updated)
        updated.activeBranch = userMsg.id
        if updated.title.isEmpty {
            updated.title = String(text.prefix(60))
        }
        updated.updatedAt = Date().timeIntervalSince1970
        activeSession = updated
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = updated
        }
        saveSessionLocal(updated)

        isGenerating = true
        streamingContent = ""
        defer {
            isGenerating = false
            streamingContent = ""
        }

        do {
            guard let bridge = agentBridge else {
                chatStoreLog.error("sendMessage: agentBridge is NIL, cannot infer")
                let errMsg = ChatMessageData(
                    role: "assistant",
                    content: "⚠️ AI service not available. Please check your configuration.",
                    mode: mode,
                    parentId: userMsg.id
                )
                var errSession = activeSession ?? updated
                errSession.messages.append(errMsg)
                capMessages(&errSession)
                errSession.activeBranch = errMsg.id
                errSession.updatedAt = Date().timeIntervalSince1970
                activeSession = errSession
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[idx] = errSession
                }
                saveSessionLocal(errSession)
                return
            }
            let fallbackModel = FusionConfig.shared.mlxModelSmall.isEmpty ? "Qwen3.5-9B-4bit" : FusionConfig.shared.mlxModelSmall
            let defaultModel = MLXModelInfo.preferredDefault(in: bridge.mlxState.models)?.id ?? fallbackModel
            let model = !selectedModel.isEmpty ? selectedModel : defaultModel
            chatStoreLog.debug("sendMessage resolved model=\(model, privacy: .public) selected=\(self.selectedModel, privacy: .public) modelCount=\(bridge.mlxState.models.count, privacy: .public) configSmall=\(FusionConfig.shared.mlxModelSmall, privacy: .public)")
            // caller: ChatSessionStore.sendMessage → builds message array with optional system prompt + multimodal
            var messages: [[String: Any]] = []
            var systemParts: [String] = []
            if let presetRaw = updated.preset, let preset = ChatPreset(rawValue: presetRaw) {
                systemParts.append(preset.systemPrompt)
            }
            if let styleRaw = updated.outputStyle, let style = OutputStyle(rawValue: styleRaw) {
                systemParts.append(style.stylePrompt)
            }
            if let skillId = updated.activeSkill,
               let uuid = UUID(uuidString: skillId),
               let skill = FusionSkillManager.shared.skills.first(where: { $0.id == uuid }) {
                systemParts.append("[Skill: \(skill.name)] \(skill.systemPrompt)")
                chatStoreLog.info("Injected skill '\(skill.name)'")
            }
            if let pid = updated.projectId,
               let project = FusionProjectManager.shared.projects.first(where: { $0.id == pid }) {
                if project.hasInstructions {
                    systemParts.append("[Project: \(project.name)] \(project.customInstructions)")
                }
                if project.hasKnowledge {
                    var knowledgeParts = ["[Project Knowledge Files for \(project.name)]"]
                    for kf in project.knowledgeFiles {
                        // 审计0827 #2: knowledgeFiles 路径可能来自导入项目, 防 symlink/.. 越界读, validateFilePath 拒则跳过。
                        guard SecurityManager.shared.validateFilePath(kf.filePath) else { continue }
                        if let content = try? String(contentsOfFile: kf.filePath, encoding: .utf8) {
                            let truncated = String(content.prefix(8000))
                            knowledgeParts.append("[\(kf.fileName)]\n\(truncated)")
                        }
                    }
                    systemParts.append(knowledgeParts.joined(separator: "\n\n"))
                }
                chatStoreLog.info("Injected project '\(project.name)': instructions=\(project.hasInstructions), knowledge=\(project.knowledgeFiles.count) files")
            }
            if !systemParts.isEmpty {
                messages.append(["role": "system", "content": systemParts.joined(separator: " ")])
            }
            for msg in updated.messages {
                if msg.attachments.isEmpty {
                    messages.append(["role": msg.role, "content": msg.content])
                } else {
                    var contentParts: [[String: Any]] = [["type": "text", "text": msg.content]]
                    var fileTextParts: [String] = []
                    for att in msg.attachments {
                        if att.isImage {
                            contentParts.append([
                                "type": "image_url",
                                "image_url": ["url": "data:\(att.mimeType);base64,\(att.dataBase64)"]
                            ])
                            // OCR: extract text from image if OCR model available
                            if let ipc = self.ipc {
                                do {
                                    let ocrModels = try await ipc.listOCRModels()
                                    if let ocrModel = ocrModels.first {
                                        let dataURI = "data:\(att.mimeType);base64,\(att.dataBase64)"
                                        let ocrText = try await ipc.ocr(image: dataURI, model: ocrModel)
                                        if !ocrText.isEmpty {
                                            let truncated = String(ocrText.prefix(8000))
                                            fileTextParts.append("[OCR: \(att.name)]\n\(truncated)")
                                            chatStoreLog.info("OCR: extracted \(ocrText.count) chars from \(att.name)")
                                        }
                                    }
                                } catch {
                                    chatStoreLog.debug("OCR skipped for \(att.name): \(error.localizedDescription)")
                                }
                            }
                        } else {
                            if let decoded = Data(base64Encoded: att.dataBase64),
                               let textContent = String(data: decoded, encoding: .utf8) {
                                let truncated = String(textContent.prefix(8000))
                                fileTextParts.append("[File: \(att.name)]\n\(truncated)")
                            } else {
                                fileTextParts.append("[File: \(att.name)] (binary, \(att.dataBase64.count) bytes base64)")
                            }
                        }
                    }
                    if !fileTextParts.isEmpty {
                        let combinedText = (msg.content.isEmpty ? "" : msg.content + "\n\n") + fileTextParts.joined(separator: "\n\n")
                        contentParts[0] = ["type": "text", "text": combinedText]
                    }
                    messages.append(["role": msg.role, "content": contentParts])
                }
            }
            chatStoreLog.info("sendMessage: starting stream infer, model=\(model), webSearch=\(self.isWebSearchEnabled), mode=\(mode)")

            if mode == ChatMode.research.rawValue {
                var response: String
                if let ipcClient = self.ipc {
                    do {
                        let result = try await ipcClient.researchAdaptive(question: text, maxSteps: 10, webSearch: isWebSearchEnabled)
                        if let answer = result["answer"] as? String, !answer.isEmpty {
                            response = answer
                            let steps = result["steps_taken"] as? Int ?? 0
                            let sufficient = result["sufficient"] as? Bool ?? true
                            chatStoreLog.info("research.adaptive: \(steps) steps, sufficient=\(sufficient)")
                        } else {
                            response = try await runResearch(messages: messages, model: model)
                        }
                    } catch {
                        chatStoreLog.warning("research.adaptive failed, falling back to local: \(error.localizedDescription)")
                        response = try await runResearch(messages: messages, model: model)
                    }
                } else {
                    response = try await runResearch(messages: messages, model: model)
                }
                let assistantMsg = ChatMessageData(role: "assistant", content: response, mode: mode, parentId: userMsg.id)
                var updatedSession = activeSession ?? session
                updatedSession.messages.append(assistantMsg)
                capMessages(&updatedSession)
                updatedSession.activeBranch = assistantMsg.id
                if updatedSession.title.isEmpty { updatedSession.title = String(text.prefix(60)) }
                updatedSession.updatedAt = Date().timeIntervalSince1970
                activeSession = updatedSession
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) { sessions[idx] = updatedSession }
                saveSessionLocal(updatedSession)
                return
            }

            resetStreamThrottle()
            let response = try await bridge.inferStream(
                messages: messages,
                model: model,
                temperature: 0.7,
                maxTokens: 2048,
                webSearch: self.isWebSearchEnabled,
                onToken: { [weak self] token in
                    self?.appendStreamToken(token)
                }
            )
            flushStreamBuffer()
            chatStoreLog.info("sendMessage inferStream returned successfully")
            let assistantMsg = ChatMessageData(
                role: "assistant",
                content: response,
                mode: mode,
                parentId: userMsg.id
            )
            var updatedSession = activeSession ?? session
            updatedSession.messages.append(assistantMsg)
            capMessages(&updatedSession)
            updatedSession.activeBranch = assistantMsg.id
            if updatedSession.title.isEmpty {
                updatedSession.title = String(text.prefix(60))
            }
            updatedSession.updatedAt = Date().timeIntervalSince1970
            activeSession = updatedSession
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = updatedSession
            }
            saveSessionLocal(updatedSession)
            chatStoreLog.info("Chat stream response received, length=\(response.count)")
            // Auto-render artifact from assistant response
            if let ipcClient = self.ipc, response.count >= 1500 {
                do {
                    let renderResult = try await ipcClient.artifactRender(
                        content: response,
                        sessionId: session.id,
                        langHint: ""
                    )
                    if let created = renderResult["created"] as? Bool, created {
                        chatStoreLog.info("Auto-rendered artifact from response")
                    }
                } catch {
                    chatStoreLog.debug("Artifact render skipped: \(error.localizedDescription)")
                }
            }
        } catch {
            chatStoreLog.error("sendMessage inferStream FAILED: \(error.localizedDescription, privacy: .public) type=\(String(describing: type(of: error)), privacy: .public)")
            // 审计0827 §3.9.3 (P2): errorDetail 旧裸 \(type(of:error)): \(error.localizedDescription) 暴露底层错 (路径/端口/堆栈) 到日志。
            // 改 BridgeError.sanitize 统一脱敏出口, 仅 i18n 用户消息 + type 供定位, 不泄 detail。
            let errorDetail = BridgeError.sanitize(error)
            let friendlyMsg = (error as? BridgeError)?.userMessage ?? "AI 服务暂时不可用，请稍后重试。"
            chatStoreLog.error("sendMessage errorDetail: \(errorDetail, privacy: .public)")
            let errMsg = ChatMessageData(
                role: "assistant",
                content: "⚠️ \(friendlyMsg)",
                mode: mode,
                parentId: userMsg.id
            )
            var updatedSession = activeSession ?? session
            updatedSession.messages.append(errMsg)
            capMessages(&updatedSession)
            updatedSession.activeBranch = errMsg.id
            updatedSession.updatedAt = Date().timeIntervalSince1970
            activeSession = updatedSession
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = updatedSession
            }
            saveSessionLocal(updatedSession)
            chatStoreLog.error("Chat infer failed: \(error.localizedDescription)")
        }
    }

    func sendMultimodal(session: ChatSessionData, content: [[String: Any]], mode: String = "") async {
        guard let ipc = ipc else { return }
        var updated = activeSession ?? session
        let userMsg = ChatMessageData(
            role: "user",
            content: "[multimodal]",
            mode: mode.isEmpty ? session.mode : mode,
            parentId: updated.messages.last?.id ?? ""
        )
        updated.messages.append(userMsg)
        capMessages(&updated)
        activeSession = updated

        do {
            var params: [String: Any] = [
                "session_id": session.id,
                "message": "[multimodal]",
                "content": content,
            ]
            if !mode.isEmpty { params["mode"] = mode }
            let result = try await ipc.call(method: RPCMethod.chatSend, params: params)

            if let errorCode = result["code"] as? Int, errorCode == 422 {
                errorMessage = result["message"] as? String ?? "Vision model required for image input"
                return
            }

            if let events = result["events"] as? [[String: Any]] {
                var textContent = ""
                var toolCalls: [[String: Any]] = []
                for ev in events {
                    if ev["type"] as? String == "token", let c = ev["content"] as? String {
                        textContent += c
                    }
                    if ev["type"] as? String == "tool_call" {
                        toolCalls.append(ev["args"] as? [String: Any] ?? [:])
                    }
                }
                let assistantMsg = ChatMessageData(
                    role: "assistant",
                    content: textContent,
                    mode: mode,
                    parentId: userMsg.id,
                    toolCalls: toolCalls
                )
                var updatedSession = activeSession ?? session
                updatedSession.messages.append(assistantMsg)
                capMessages(&updatedSession)
                activeSession = updatedSession
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[idx] = updatedSession
                }
            }
        } catch {
            errorMessage = BridgeError.sanitize(error)
            chatStoreLog.error("chat.send multimodal failed: \(error.localizedDescription)")
        }
    }

    func branch(at messageId: String) async {
        guard let session = activeSession else { return }
        guard let ipc = ipc else {
            chatStoreLog.warning("branch: no IPCClient, aborting")
            return
        }
        do {
            let result = try await ipc.call(method: RPCMethod.chatBranch, params: [
                "session_id": session.id,
                "message_id": messageId,
            ])
            if let branched = parseSessionData(result) {
                sessions.insert(branched, at: 0)
                capSessions()
                activeSession = branched
                chatStoreLog.info("Branched chat at \(messageId) -> \(branched.id)")
            }
        } catch {
            errorMessage = BridgeError.sanitize(error)
        }
    }

    // Callers: UnifiedChatView branch picker. Affected API: chat.switch_branch/branches/message_tree. Data schemas: branchId=String, returns ChatSessionData or [ChatMessageData]. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
    func switchBranch(to branchId: String) async {
        guard let session = activeSession else { return }
        guard let ipc = ipc else {
            chatStoreLog.warning("switchBranch: no IPCClient, aborting")
            return
        }
        do {
            let result = try await ipc.chatSwitchBranch(sessionId: session.id, branchId: branchId)
            if let updated = parseSessionData(result) {
                activeSession = updated
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[idx] = updated
                }
                chatStoreLog.info("Switched branch to \(branchId)")
            }
        } catch {
            errorMessage = BridgeError.sanitize(error)
            chatStoreLog.error("chat.switch_branch failed: \(error.localizedDescription)")
        }
    }

    func listBranches(at messageId: String) async -> [ChatMessageData] {
        guard let session = activeSession else { return [] }
        guard let ipc = ipc else {
            chatStoreLog.warning("listBranches: no IPCClient, returning empty")
            return []
        }
        do {
            let result = try await ipc.chatBranches(sessionId: session.id, messageId: messageId)
            if let branches = result["branches"] as? [[String: Any]] {
                return branches.compactMap { parseMessageData($0) }
            }
        } catch {
            chatStoreLog.error("chat.branches failed: \(error.localizedDescription)")
        }
        return []
    }

    func loadMessageTree() async -> [String: Any]? {
        guard let session = activeSession else { return nil }
        guard let ipc = ipc else {
            chatStoreLog.warning("loadMessageTree: no IPCClient, returning nil")
            return nil
        }
        do {
            return try await ipc.chatMessageTree(sessionId: session.id)
        } catch {
            chatStoreLog.error("chat.message_tree failed: \(error.localizedDescription)")
        }
        return nil
    }

    func editMessage(_ messageId: String, newContent: String) async {
        guard let session = activeSession else { return }
        chatStoreLog.info("editMessage: msg=\(messageId), newContent='\(newContent.prefix(50))'")

        let parentId = session.messages.first(where: { $0.id == messageId })?.parentId ?? ""
        let editedMsg = ChatMessageData(
            role: "user",
            content: newContent,
            parentId: parentId
        )

        if let ipcClient = ipc {
            do {
                let result = try await ipcClient.call(method: RPCMethod.chatEdit, params: [
                    "session_id": session.id,
                    "message_id": messageId,
                    "content": newContent,
                ])
                if let editedId = result["id"] as? String {
                    let remoteMsg = ChatMessageData(
                        id: editedId,
                        role: "user",
                        content: newContent,
                        parentId: parentId
                    )
                    var updated = session
                    updated.messages.append(remoteMsg)
                    capMessages(&updated)
                    updated.activeBranch = editedId
                    activeSession = updated
                    if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                        sessions[idx] = updated
                    }
                    saveSessionLocal(updated)
                    chatStoreLog.info("editMessage: IPC success, editedId=\(editedId)")
                    await resendAfterEdit(editedMsgId: editedId)
                    return
                }
            } catch {
                chatStoreLog.warning("editMessage: IPC failed (\(error.localizedDescription)), falling back to local")
            }
        }

        var updated = session
        updated.messages.append(editedMsg)
        capMessages(&updated)
        updated.activeBranch = editedMsg.id
        activeSession = updated
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = updated
        }
        saveSessionLocal(updated)
        chatStoreLog.info("editMessage: local edit done, editedMsgId=\(editedMsg.id)")
        await resendAfterEdit(editedMsgId: editedMsg.id)
    }

    private func runResearch(messages: [[String: Any]], model: String) async throws -> String {
        guard let agentBridge = agentBridge else {
            chatStoreLog.error("runResearch: no AgentBridge available")
            throw BridgeError.notConnected
        }
        let researchSteps = [
            "Break down the user's question into 2-3 key sub-questions that need independent research. List them concisely.",
            "For each sub-question, provide your best answer using web search results. Cite sources where possible.",
            "Synthesize all findings into a comprehensive, well-structured response with citations and cross-references."
        ]
        let researchMessages = messages
        var allFindings = ""
        for (idx, step) in researchSteps.enumerated() {
            chatStoreLog.info("Research step \(idx + 1)/\(researchSteps.count)")
            streamingContent = "🔍 Research step \(idx + 1)/\(researchSteps.count)...\n"
            var stepMessages = researchMessages
            if idx > 0 {
                stepMessages.append(["role": "assistant", "content": allFindings])
                stepMessages.append(["role": "user", "content": step])
            } else {
                stepMessages.append(["role": "user", "content": "Research mode: \(step)"])
            }
            resetStreamThrottle()
            let result = try await agentBridge.inferStream(
                messages: stepMessages,
                model: model,
                temperature: 0.3,
                maxTokens: 4096,
                webSearch: true,
                onToken: { [weak self] token in
                    self?.appendStreamToken(token)
                }
            )
            flushStreamBuffer()
            allFindings += "\n\n--- Step \(idx + 1) ---\n\(result)"
        }
        return allFindings
    }

    private func resendAfterEdit(editedMsgId: String) async {
        guard let session = activeSession else { return }
        guard let bridge = agentBridge else {
            chatStoreLog.warning("resendAfterEdit: no AgentBridge, showing error")
            let errMsg = ChatMessageData(
                role: "assistant",
                content: "⚠️ AI service not available. Please check your configuration.",
                parentId: editedMsgId
            )
            var updatedSession = session
            updatedSession.messages.append(errMsg)
            capMessages(&updatedSession)
            updatedSession.activeBranch = errMsg.id
            updatedSession.updatedAt = Date().timeIntervalSince1970
            activeSession = updatedSession
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = updatedSession
            }
            saveSessionLocal(updatedSession)
            return
        }
        let fallbackModel = FusionConfig.shared.mlxModelSmall.isEmpty ? "Qwen3.5-9B-4bit" : FusionConfig.shared.mlxModelSmall
        let defaultModel = MLXModelInfo.preferredDefault(in: bridge.mlxState.models)?.id ?? fallbackModel
        let model = !selectedModel.isEmpty ? selectedModel : defaultModel

        let editedMsgIdx = session.messages.firstIndex(where: { $0.id == editedMsgId })

        // Pre-compute OCR for image attachments (async, before synchronous map)
        var ocrCache: [String: String] = [:] // att.id -> ocr text
        if let ipc = self.ipc {
            do {
                let ocrModels = try await ipc.listOCRModels()
                if let ocrModel = ocrModels.first {
                    if let idx = editedMsgIdx {
                        for msg in session.messages[0...idx] {
                            for att in msg.attachments where att.isImage {
                                if ocrCache[att.id] == nil {
                                    do {
                                        let dataURI = "data:\(att.mimeType);base64,\(att.dataBase64)"
                                        let ocrText = try await ipc.ocr(image: dataURI, model: ocrModel)
                                        if !ocrText.isEmpty {
                                            ocrCache[att.id] = String(ocrText.prefix(8000))
                                            chatStoreLog.info("OCR: extracted \(ocrText.count) chars from \(att.name)")
                                        }
                                    } catch {
                                        chatStoreLog.debug("OCR skipped for \(att.name): \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                chatStoreLog.debug("OCR model discovery failed: \(error.localizedDescription)")
            }
        }

        let messagesToResend: [[String: Any]]
        if let idx = editedMsgIdx {
            messagesToResend = session.messages[0...idx].map { msg in
                if msg.attachments.isEmpty {
                    return ["role": msg.role, "content": msg.content]
                } else {
                    var parts: [[String: Any]] = [["type": "text", "text": msg.content]]
                    var fileTextParts: [String] = []
                    for att in msg.attachments {
                        if att.isImage {
                            parts.append(["type": "image_url", "image_url": ["url": "data:\(att.mimeType);base64,\(att.dataBase64)"]])
                            if let ocrText = ocrCache[att.id] {
                                fileTextParts.append("[OCR: \(att.name)]\n\(ocrText)")
                            }
                        } else {
                            if let decoded = Data(base64Encoded: att.dataBase64),
                               let textContent = String(data: decoded, encoding: .utf8) {
                                let truncated = String(textContent.prefix(8000))
                                fileTextParts.append("[File: \(att.name)]\n\(truncated)")
                            } else {
                                fileTextParts.append("[File: \(att.name)] (binary, \(att.dataBase64.count) bytes base64)")
                            }
                        }
                    }
                    if !fileTextParts.isEmpty {
                        let combinedText = (msg.content.isEmpty ? "" : msg.content + "\n\n") + fileTextParts.joined(separator: "\n\n")
                        parts[0] = ["type": "text", "text": combinedText]
                    }
                    return ["role": msg.role, "content": parts]
                }
            }
        } else {
            messagesToResend = session.messages.map { msg in
                if msg.attachments.isEmpty {
                    return ["role": msg.role, "content": msg.content]
                } else {
                    var parts: [[String: Any]] = [["type": "text", "text": msg.content]]
                    for att in msg.attachments where att.isImage {
                        parts.append(["type": "image_url", "image_url": ["url": "data:\(att.mimeType);base64,\(att.dataBase64)"]])
                    }
                    return ["role": msg.role, "content": parts]
                }
            }
        }

        chatStoreLog.info("resendAfterEdit: starting stream infer, model=\(model), msgs=\(messagesToResend.count)")

        var systemParts: [String] = []
        if let presetRaw = session.preset, let preset = ChatPreset(rawValue: presetRaw) {
            systemParts.append(preset.systemPrompt)
        }
        if let styleRaw = session.outputStyle, let style = OutputStyle(rawValue: styleRaw) {
            systemParts.append(style.stylePrompt)
        }
        if let skillId = session.activeSkill,
           let uuid = UUID(uuidString: skillId),
           let skill = FusionSkillManager.shared.skills.first(where: { $0.id == uuid }) {
            systemParts.append("[Skill: \(skill.name)] \(skill.systemPrompt)")
        }
        if let pid = session.projectId,
           let project = FusionProjectManager.shared.projects.first(where: { $0.id == pid }) {
            if project.hasInstructions {
                systemParts.append("[Project: \(project.name)] \(project.customInstructions)")
            }
            if project.hasKnowledge {
                var knowledgeParts = ["[Project Knowledge Files for \(project.name)]"]
                for kf in project.knowledgeFiles {
                    if let content = try? String(contentsOfFile: kf.filePath, encoding: .utf8) {
                        let truncated = String(content.prefix(8000))
                        knowledgeParts.append("[\(kf.fileName)]\n\(truncated)")
                    }
                }
                systemParts.append(knowledgeParts.joined(separator: "\n\n"))
            }
        }
        var finalMessages: [[String: Any]] = []
        if !systemParts.isEmpty {
            finalMessages.append(["role": "system", "content": systemParts.joined(separator: " ")])
        }
        finalMessages.append(contentsOf: messagesToResend)
        isGenerating = true
        streamingContent = ""
        defer {
            isGenerating = false
            streamingContent = ""
        }

        do {
            resetStreamThrottle()
            let response = try await bridge.inferStream(
                messages: finalMessages,
                model: model,
                temperature: 0.7,
                maxTokens: 2048,
                onToken: { [weak self] token in
                    self?.appendStreamToken(token)
                }
            )
            flushStreamBuffer()
            let assistantMsg = ChatMessageData(
                role: "assistant",
                content: response,
                parentId: editedMsgId
            )
            var updatedSession = activeSession ?? session
            updatedSession.messages.append(assistantMsg)
            capMessages(&updatedSession)
            updatedSession.activeBranch = assistantMsg.id
            updatedSession.updatedAt = Date().timeIntervalSince1970
            activeSession = updatedSession
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = updatedSession
            }
            saveSessionLocal(updatedSession)
            chatStoreLog.info("resendAfterEdit: response received, length=\(response.count)")
        } catch {
            let errMsg = ChatMessageData(
                role: "assistant",
                content: "⚠️ \((error as? BridgeError)?.userMessage ?? "AI 服务暂时不可用，请稍后重试。")",
                parentId: editedMsgId
            )
            var updatedSession = activeSession ?? session
            updatedSession.messages.append(errMsg)
            capMessages(&updatedSession)
            updatedSession.activeBranch = errMsg.id
            activeSession = updatedSession
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = updatedSession
            }
            saveSessionLocal(updatedSession)
            chatStoreLog.error("resendAfterEdit: infer failed: \(error.localizedDescription)")
        }

    }

    // 审计0827 §3.2 (P1): nonisolated — 纯解析无 self 状态, 供 loadSessionsLocal 后台调用。
    nonisolated private func parseSessionData(_ dict: [String: Any]) -> ChatSessionData? {
        guard let id = dict["id"] as? String else { return nil }
        let title = dict["title"] as? String ?? ""
        let mode = dict["mode"] as? String ?? "simple"
        let activeBranch = dict["active_branch"] as? String ?? ""
        let graphId = dict["graph_id"] as? String ?? ""
        let createdAt = dict["created_at"] as? Double ?? 0
        let updatedAt = dict["updated_at"] as? Double ?? 0
        let isPinned = dict["is_pinned"] as? Bool ?? false
        let preset = dict["preset"] as? String
        let outputStyle = dict["output_style"] as? String
        let projectId = dict["project_id"] as? String
        let activeSkill = dict["active_skill"] as? String

        var messages: [ChatMessageData] = []
        if let msgs = dict["messages"] as? [[String: Any]] {
            messages = msgs.compactMap { parseMessageData($0) }
        }

        return ChatSessionData(
            id: id,
            title: title,
            mode: mode,
            messages: messages,
            activeBranch: activeBranch,
            graphId: graphId,
            isPinned: isPinned,
            preset: preset,
            outputStyle: outputStyle,
            projectId: projectId,
            activeSkill: activeSkill,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // 审计0827 §3.2 (P1): nonisolated — 纯解析, 供 parseSessionData 后台调用。
    nonisolated private func parseMessageData(_ dict: [String: Any]) -> ChatMessageData? {
        guard let id = dict["id"] as? String,
              let role = dict["role"] as? String else { return nil }
        var attachments: [AttachmentData] = []
        if let attList = dict["attachments"] as? [[String: Any]] {
            attachments = attList.compactMap { a in
                guard let aid = a["id"] as? String,
                      let name = a["name"] as? String,
                      let type = a["type"] as? String,
                      let mime = a["mime_type"] as? String,
                      let b64 = a["data_base64"] as? String else { return nil }
                return AttachmentData(id: aid, name: name, type: type, mimeType: mime, dataBase64: b64)
            }
        }
        return ChatMessageData(
            id: id,
            role: role,
            content: dict["content"] as? String ?? "",
            mode: dict["mode"] as? String ?? "",
            parentId: dict["parent_id"] as? String ?? "",
            childrenIds: dict["children_ids"] as? [String] ?? [],
            toolCalls: dict["tool_calls"] as? [[String: Any]] ?? [],
            metadata: dict["metadata"] as? [String: Any] ?? [:],
            createdAt: dict["created_at"] as? Double ?? 0,
            attachments: attachments
        )
    }

    // MARK: - RAG Watch

    func startRAGWatch(kbId: String, filePaths: [String], pollInterval: Int = 30) async {
        await stopRAGWatch()
        guard let ipcClient = ipc, !filePaths.isEmpty else { return }
        do {
            let result = try await ipcClient.ragWatch(kbId: kbId, filePaths: filePaths, pollInterval: pollInterval)
            if let wid = result["watch_id"] as? String {
                activeRAGWatchId = wid
                activeRAGWatchKbId = kbId
                chatStoreLog.info("RAG watch started: kb=\(kbId) watch=\(wid) files=\(filePaths.count)")
            }
        } catch {
            chatStoreLog.debug("RAG watch start failed: \(error.localizedDescription)")
        }
    }

    func stopRAGWatch() async {
        guard let wid = activeRAGWatchId, let kbId = activeRAGWatchKbId, let ipcClient = ipc else {
            activeRAGWatchId = nil
            activeRAGWatchKbId = nil
            return
        }
        do {
            _ = try await ipcClient.ragUnwatch(kbId: kbId, watchId: wid)
            chatStoreLog.info("RAG watch stopped: kb=\(kbId) watch=\(wid)")
        } catch {
            chatStoreLog.debug("RAG watch stop failed: \(error.localizedDescription)")
        }
        activeRAGWatchId = nil
        activeRAGWatchKbId = nil
    }
}
