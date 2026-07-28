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

    init() {}

    func setIPCClient(_ client: IPCClient) {
        self.ipc = client
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await ipc!.call(method: "chat.list")
            if let list = result["sessions"] as? [[String: Any]] {
                sessions = list.compactMap { parseSessionData($0) }
                chatStoreLog.info("Loaded \(self.sessions.count) chat sessions")
            }
        } catch {
            errorMessage = error.localizedDescription
            chatStoreLog.error("chat.list failed: \(error.localizedDescription)")
        }
    }

    func createSession(mode: String = "simple", title: String = "", graphId: String = "") async {
        do {
            var params: [String: Any] = ["mode": mode]
            if !title.isEmpty { params["title"] = title }
            if !graphId.isEmpty { params["graph_id"] = graphId }
            let result = try await ipc!.call(method: "chat.create", params: params)
            if let session = parseSessionData(result) {
                sessions.insert(session, at: 0)
                activeSession = session
                chatStoreLog.info("Created chat session: \(session.id)")
            }
        } catch {
            errorMessage = error.localizedDescription
            chatStoreLog.error("chat.create failed: \(error.localizedDescription)")
        }
    }

    func selectSession(_ session: ChatSessionData) {
        activeSession = session
    }

    func deleteSession(_ sessionId: String) async {
        do {
            _ = try await ipc!.call(method: "chat.delete", params: ["session_id": sessionId])
            sessions.removeAll { $0.id == sessionId }
            if activeSession?.id == sessionId {
                activeSession = sessions.first
            }
            chatStoreLog.info("Deleted chat session: \(sessionId)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendMessage(_ text: String, mode: String = "") async {
        guard let session = activeSession else { return }
        let userMsg = ChatMessageData(role: "user", content: text)
        var updated = session
        updated.messages.append(userMsg)
        activeSession = updated

        do {
            var params: [String: Any] = [
                "session_id": session.id,
                "message": text,
            ]
            if !mode.isEmpty { params["mode"] = mode }
            let result = try await ipc!.call(method: "chat.send", params: params)

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
            }
        } catch {
            errorMessage = error.localizedDescription
            chatStoreLog.error("chat.send failed: \(error.localizedDescription)")
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
