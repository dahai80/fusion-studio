// Callers: UnifiedChatView, AgentStudioView — chat session state management
// Affected API: ChatSessionStore @MainActor ObservableObject (CRUD + send via IPC)
// Data schemas: ChatMessageData (id/role/content/parentId/childrenIds/toolCalls), ChatSessionData (id/title/mode/messages/activeBranch)

import Combine
import Foundation
import os.log

private let chatStoreLog = Logger(subsystem: "com.fusion.studio", category: "ChatSessionStore")

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

    init(
        id: String = UUID().uuidString,
        role: String,
        content: String,
        mode: String = "",
        parentId: String = "",
        childrenIds: [String] = [],
        toolCalls: [[String: Any]] = [],
        metadata: [String: Any] = [:],
        createdAt: Double = Date().timeIntervalSince1970
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
    var createdAt: Double
    var updatedAt: Double

    init(
        id: String = UUID().uuidString,
        title: String = "",
        mode: String = "simple",
        messages: [ChatMessageData] = [],
        activeBranch: String = "",
        graphId: String = "",
        createdAt: Double = Date().timeIntervalSince1970,
        updatedAt: Double = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.title = title
        self.mode = mode
        self.messages = messages
        self.activeBranch = activeBranch
        self.graphId = graphId
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

    var label: String {
        switch self {
        case .simple: return "Chat"
        case .agent: return "Agent"
        case .code: return "Code"
        case .design: return "Design"
        case .rag: return "RAG"
        }
    }

    var icon: String {
        switch self {
        case .simple: return "bubble.left.and.bubble.right"
        case .agent: return "brain"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .design: return "paintbrush"
        case .rag: return "doc.text.magnifyingglass"
        }
    }
}

@MainActor
class ChatSessionStore: ObservableObject {
    @Published var sessions: [ChatSessionData] = []
    @Published var activeSession: ChatSessionData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var ipc: IPCClient?
    private let storeDir = NSHomeDirectory() + "/.fusion-studio/chats"

    init() {}

    func setIPCClient(_ client: IPCClient) {
        self.ipc = client
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
            "created_at": s.createdAt,
            "updated_at": s.updatedAt,
            "messages": s.messages.map { msg in
                var m: [String: Any] = [
                    "id": msg.id, "role": msg.role, "content": msg.content,
                    "mode": msg.mode, "parent_id": msg.parentId,
                    "created_at": msg.createdAt,
                ]
                if !msg.childrenIds.isEmpty { m["children_ids"] = msg.childrenIds }
                return m
            },
        ]
    }

    // MARK: - CRUD

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

    func sendMessage(_ text: String, mode: String = "") async {
        guard let session = activeSession else { return }
        let userMsg = ChatMessageData(role: "user", content: text)
        var updated = session
        updated.messages.append(userMsg)
        activeSession = updated
        saveSessionLocal(updated)

        do {
            guard let ipc = ipc else {
                chatStoreLog.warning("No IPC, message saved locally only")
                return
            }
            var params: [String: Any] = [
                "session_id": session.id,
                "message": text,
            ]
            if !mode.isEmpty { params["mode"] = mode }
            let result = try await ipc.call(method: "chat.send", params: params)

            if let events = result["events"] as? [[String: Any]] {
                var content = ""
                var toolCalls: [[String: Any]] = []
                for ev in events {
                    if ev["type"] as? String == "token", let c = ev["content"] as? String {
                        content += c
                    }
                    if ev["type"] as? String == "tool_call" {
                        toolCalls.append(ev["args"] as? [String: Any] ?? [:])
                    }
                }
                let assistantMsg = ChatMessageData(
                    role: "assistant",
                    content: content,
                    mode: mode,
                    parentId: userMsg.id,
                    toolCalls: toolCalls
                )
                var updatedSession = activeSession ?? session
                updatedSession.messages.append(assistantMsg)
                if let newTitle = result["content"] as? String, updatedSession.title.isEmpty, !newTitle.isEmpty {
                    updatedSession.title = String(newTitle.prefix(60))
                }
                activeSession = updatedSession
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[idx] = updatedSession
                }
                saveSessionLocal(updatedSession)
            }
        } catch {
            chatStoreLog.error("chat.send failed: \(error.localizedDescription)")
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
        do {
            let result = try await ipc!.call(method: "chat.edit", params: [
                "session_id": session.id,
                "message_id": messageId,
                "content": newContent,
            ])
            let editedDict = result
            if let editedId = editedDict["id"] as? String {
                let editedMsg = ChatMessageData(
                    id: editedId,
                    role: "user",
                    content: newContent,
                    parentId: session.messages.first(where: { $0.id == messageId })?.parentId ?? ""
                )
                var updated = session
                updated.messages.append(editedMsg)
                updated.activeBranch = editedId
                activeSession = updated
                if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                    sessions[idx] = updated
                }
            }
        } catch {
            errorMessage = error.localizedDescription
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
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func parseMessageData(_ dict: [String: Any]) -> ChatMessageData? {
        guard let id = dict["id"] as? String,
              let role = dict["role"] as? String else { return nil }
        return ChatMessageData(
            id: id,
            role: role,
            content: dict["content"] as? String ?? "",
            mode: dict["mode"] as? String ?? "",
            parentId: dict["parent_id"] as? String ?? "",
            childrenIds: dict["children_ids"] as? [String] ?? [],
            toolCalls: dict["tool_calls"] as? [[String: Any]] ?? [],
            metadata: dict["metadata"] as? [String: Any] ?? [:],
            createdAt: dict["created_at"] as? Double ?? 0
        )
    }
}
