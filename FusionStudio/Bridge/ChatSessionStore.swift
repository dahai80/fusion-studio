// Callers: UnifiedChatView, AgentStudioView — chat session state management
// Affected API: ChatSessionStore @MainActor ObservableObject (CRUD + send via IPC)
// Data schemas: ChatMessageData (id/role/content/parentId/childrenIds/toolCalls), ChatSessionData (id/title/mode/messages/activeBranch)

import AppKit
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

    private var ipc: IPCClient?
    weak var agentBridge: AgentBridge?
    private let storeDir = NSHomeDirectory() + "/.fusion-studio/chats"
    private var fusionCodeClient: FusionCodeAPIClient?

    init() {}

    func setIPCClient(_ client: IPCClient) {
        self.ipc = client
    }

    func setAgentBridge(_ bridge: AgentBridge) {
        self.agentBridge = bridge
    }

    func setFusionCodeClient(_ client: FusionCodeAPIClient) {
        self.fusionCodeClient = client
        chatStoreLog.info("FusionCodeAPIClient set on ChatSessionStore")
    }

    func fetchProjects() async -> [FusionCodeProject] {
        guard let client = fusionCodeClient else {
            chatStoreLog.warning("fetchProjects: no FusionCodeAPIClient, returning empty")
            return []
        }
        do {
            return try await client.fetchProjects()
        } catch {
            chatStoreLog.error("fetchProjects failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Local persistence

    private func ensureStoreDir() {
        try? FileManager.default.createDirectory(atPath: storeDir, withIntermediateDirectories: true)
    }

    private func sessionPath(_ id: String) -> String {
        return storeDir + "/" + id + ".json"
    }

    private func saveSessionLocal(_ session: ChatSessionData) {
        ensureStoreDir()
        let dict = sessionToDict(session)
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return }
        try? data.write(to: URL(fileURLWithPath: sessionPath(session.id)), options: .atomic)
    }

    private func deleteSessionLocal(_ id: String) {
        try? FileManager.default.removeItem(atPath: sessionPath(id))
    }

    private func loadSessionsLocal() -> [ChatSessionData] {
        ensureStoreDir()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: storeDir) else { return [] }
        return files.filter { $0.hasSuffix(".json") }.compactMap { file -> ChatSessionData? in
            let path = storeDir + "/" + file
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
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
        activeSession = session
        saveSessionLocal(session)
        chatStoreLog.info("ensureActiveSession: created \(session.id)")
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let ipc = ipc else {
                sessions = loadSessionsLocal()
                chatStoreLog.info("No IPC, loaded \(self.sessions.count) local sessions")
                return
            }
            let result = try await ipc.call(method: "chat.list")
            if let list = result["sessions"] as? [[String: Any]] {
                sessions = list.compactMap { parseSessionData($0) }
                chatStoreLog.info("Loaded \(self.sessions.count) chat sessions via IPC")
            }
        } catch {
            chatStoreLog.warning("chat.list IPC failed (\(error.localizedDescription)), falling back to local")
            sessions = loadSessionsLocal()
        }
    }

    func createSession(mode: String = "simple", title: String = "", graphId: String = "") async {
        let session = ChatSessionData(title: title.isEmpty ? "New Chat" : title, mode: mode, graphId: graphId)
        sessions.insert(session, at: 0)
        activeSession = session
        saveSessionLocal(session)
        chatStoreLog.info("Created chat session: \(session.id)")

        if let ipc = ipc {
            do {
                var params: [String: Any] = ["mode": mode]
                if !title.isEmpty { params["title"] = title }
                if !graphId.isEmpty { params["graph_id"] = graphId }
                let result = try await ipc.call(method: "chat.create", params: params)
                if let remote = parseSessionData(result) {
                    deleteSessionLocal(session.id)
                    sessions.remove(at: 0)
                    sessions.insert(remote, at: 0)
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
        }
        chatStoreLog.info("Deleted chat session: \(sessionId)")
        if let ipc = ipc {
            do {
                _ = try await ipc.call(method: "chat.delete", params: ["session_id": sessionId])
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
                    _ = try await ipc.call(method: "chat.delete", params: ["session_id": id])
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
            let defaultModel = MLXModelInfo.preferredDefault(in: bridge.models)?.id ?? fallbackModel
            let model = !selectedModel.isEmpty ? selectedModel : defaultModel
            print("[ChatStore] sendMessage: resolved model='\(model)', selectedModel='\(selectedModel)', bridgeModels=\(bridge.models.map { $0.id }), configSmall='\(FusionConfig.shared.mlxModelSmall)'")
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
               let uuid = UUID(uuidString: pid),
               let project = FusionProjectManager.shared.projects.first(where: { $0.id == uuid }) {
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
                let response = try await runResearch(messages: messages, model: model)
                let assistantMsg = ChatMessageData(role: "assistant", content: response, mode: mode, parentId: userMsg.id)
                var updatedSession = activeSession ?? session
                updatedSession.messages.append(assistantMsg)
                updatedSession.activeBranch = assistantMsg.id
                if updatedSession.title.isEmpty { updatedSession.title = String(text.prefix(60)) }
                updatedSession.updatedAt = Date().timeIntervalSince1970
                activeSession = updatedSession
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) { sessions[idx] = updatedSession }
                saveSessionLocal(updatedSession)
                return
            }

            let response = try await bridge.inferStream(
                messages: messages,
                model: model,
                temperature: 0.7,
                maxTokens: 2048,
                webSearch: self.isWebSearchEnabled,
                onToken: { [weak self] token in
                    Task { @MainActor in
                        self?.streamingContent += token
                    }
                }
            )
            print("[ChatStore] sendMessage: inferStream returned successfully")
            let assistantMsg = ChatMessageData(
                role: "assistant",
                content: response,
                mode: mode,
                parentId: userMsg.id
            )
            var updatedSession = activeSession ?? session
            updatedSession.messages.append(assistantMsg)
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
            print("[ChatStore] sendMessage: inferStream OK, \(response.count) chars")
        } catch {
            print("[ChatStore] sendMessage: inferStream FAILED: \(error), type=\(type(of: error))")
            let errorDetail = (error as? BridgeError)?.detail ?? "\(type(of: error)): \(error.localizedDescription)"
            let friendlyMsg = (error as? BridgeError)?.userMessage ?? "AI 服务暂时不可用，请稍后重试。"
            print("[ChatStore] errorDetail: \(errorDetail)")
            let errMsg = ChatMessageData(
                role: "assistant",
                content: "⚠️ \(friendlyMsg)",
                mode: mode,
                parentId: userMsg.id
            )
            var updatedSession = activeSession ?? session
            updatedSession.messages.append(errMsg)
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
        activeSession = updated

        do {
            var params: [String: Any] = [
                "session_id": session.id,
                "message": "[multimodal]",
                "content": content,
            ]
            if !mode.isEmpty { params["mode"] = mode }
            let result = try await ipc.call(method: "chat.send", params: params)

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
                activeSession = updatedSession
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[idx] = updatedSession
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            chatStoreLog.error("chat.send multimodal failed: \(error.localizedDescription)")
        }
    }

    func branch(at messageId: String) async {
        guard let session = activeSession else { return }
        do {
            let result = try await ipc!.call(method: "chat.branch", params: [
                "session_id": session.id,
                "message_id": messageId,
            ])
            if let branched = parseSessionData(result) {
                sessions.insert(branched, at: 0)
                activeSession = branched
                chatStoreLog.info("Branched chat at \(messageId) -> \(branched.id)")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Callers: UnifiedChatView branch picker. Affected API: chat.switch_branch/branches/message_tree. Data schemas: branchId=String, returns ChatSessionData or [ChatMessageData]. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
    func switchBranch(to branchId: String) async {
        guard let session = activeSession else { return }
        do {
            let result = try await ipc!.chatSwitchBranch(sessionId: session.id, branchId: branchId)
            if let updated = parseSessionData(result) {
                activeSession = updated
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[idx] = updated
                }
                chatStoreLog.info("Switched branch to \(branchId)")
            }
        } catch {
            errorMessage = error.localizedDescription
            chatStoreLog.error("chat.switch_branch failed: \(error.localizedDescription)")
        }
    }

    func listBranches(at messageId: String) async -> [ChatMessageData] {
        guard let session = activeSession else { return [] }
        do {
            let result = try await ipc!.chatBranches(sessionId: session.id, messageId: messageId)
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
        do {
            return try await ipc!.chatMessageTree(sessionId: session.id)
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
                let result = try await ipcClient.call(method: "chat.edit", params: [
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
        let researchSteps = [
            "Break down the user's question into 2-3 key sub-questions that need independent research. List them concisely.",
            "For each sub-question, provide your best answer using web search results. Cite sources where possible.",
            "Synthesize all findings into a comprehensive, well-structured response with citations and cross-references."
        ]
        var researchMessages = messages
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
            let result = try await agentBridge!.inferStream(
                messages: stepMessages,
                model: model,
                temperature: 0.3,
                maxTokens: 4096,
                webSearch: true,
                onToken: { [weak self] token in
                    Task { @MainActor in
                        self?.streamingContent += token
                    }
                }
            )
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
        let defaultModel = MLXModelInfo.preferredDefault(in: bridge.models)?.id ?? fallbackModel
        let model = !selectedModel.isEmpty ? selectedModel : defaultModel

        let editedMsgIdx = session.messages.firstIndex(where: { $0.id == editedMsgId })
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
           let uuid = UUID(uuidString: pid),
           let project = FusionProjectManager.shared.projects.first(where: { $0.id == uuid }) {
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
            let response = try await bridge.inferStream(
                messages: finalMessages,
                model: model,
                temperature: 0.7,
                maxTokens: 2048,
                onToken: { [weak self] token in
                    Task { @MainActor in
                        self?.streamingContent += token
                    }
                }
            )
            let assistantMsg = ChatMessageData(
                role: "assistant",
                content: response,
                parentId: editedMsgId
            )
            var updatedSession = activeSession ?? session
            updatedSession.messages.append(assistantMsg)
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
            updatedSession.activeBranch = errMsg.id
            activeSession = updatedSession
            if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[idx] = updatedSession
            }
            saveSessionLocal(updatedSession)
            chatStoreLog.error("resendAfterEdit: infer failed: \(error.localizedDescription)")
        }

    }

    private func parseSessionData(_ dict: [String: Any]) -> ChatSessionData? {
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

    private func parseMessageData(_ dict: [String: Any]) -> ChatMessageData? {
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
}
