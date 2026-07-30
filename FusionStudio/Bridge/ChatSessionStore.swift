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
    @Published var streamingContent: String = ""
    @Published var isGenerating: Bool = false
    @Published var selectedModel: String = ""

    private var ipc: IPCClient?
    weak var agentBridge: AgentBridge?
    private let storeDir = NSHomeDirectory() + "/.fusion-studio/chats"

    init() {}

    func setIPCClient(_ client: IPCClient) {
        self.ipc = client
    }

    func setAgentBridge(_ bridge: AgentBridge) {
        self.agentBridge = bridge
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
        guard let session = activeSession else {
            chatStoreLog.error("sendMessage: no active session, abort")
            return
        }
        chatStoreLog.info("sendMessage: text='\(text.prefix(50))', session=\(session.id), msgs=\(session.messages.count)")
        let userMsg = ChatMessageData(role: "user", content: text)
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
                isGenerating = false
                streamingContent = ""
                return
            }
            let fallbackModel = FusionConfig.shared.mlxModelSmall.isEmpty ? "Qwen3.5-9B-4bit" : FusionConfig.shared.mlxModelSmall
            let model = !selectedModel.isEmpty ? selectedModel : (bridge.models.first?.id ?? fallbackModel)
            print("[ChatStore] sendMessage: resolved model='\(model)', selectedModel='\(selectedModel)', bridgeModels=\(bridge.models.map { $0.id }), configSmall='\(FusionConfig.shared.mlxModelSmall)'")
            let messages: [[String: String]] = updated.messages.map { msg in
                ["role": msg.role, "content": msg.content]
            }
            chatStoreLog.info("sendMessage: starting stream infer, model=\(model)")
            print("[ChatStore] sendMessage: inferStream start, model=\(model), msgs=\(messages.count), selectedModel=\(selectedModel), bridgeModels=\(bridge.models.map { $0.id })")
            print("[ChatStore] sendMessage: calling bridge.inferStream now...")
            let response = try await bridge.inferStream(
                messages: messages,
                model: model,
                temperature: 0.7,
                maxTokens: 2048,
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
            print("[ChatStore] errorDetail: \(errorDetail)")
            let errMsg = ChatMessageData(
                role: "assistant",
                content: "⚠️ AI inference failed: \(errorDetail)",
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

        isGenerating = false
        streamingContent = ""
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
        let model = !selectedModel.isEmpty ? selectedModel : (bridge.models.first?.id ?? fallbackModel)

        let editedMsgIdx = session.messages.firstIndex(where: { $0.id == editedMsgId })
        let messagesToResend: [[String: String]]
        if let idx = editedMsgIdx {
            messagesToResend = session.messages[0...idx].map { msg in
                ["role": msg.role, "content": msg.content]
            }
        } else {
            messagesToResend = session.messages.map { msg in
                ["role": msg.role, "content": msg.content]
            }
        }

        chatStoreLog.info("resendAfterEdit: starting stream infer, model=\(model), msgs=\(messagesToResend.count)")
        isGenerating = true
        streamingContent = ""

        do {
            let response = try await bridge.inferStream(
                messages: messagesToResend,
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
                content: "⚠️ AI inference failed: \((error as? BridgeError)?.detail ?? error.localizedDescription)",
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

        isGenerating = false
        streamingContent = ""
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
