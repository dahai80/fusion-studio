import SwiftUI
import Foundation
import os.log

private let fcBridgeLog = Logger(subsystem: "com.fusion.studio", category: "FusionCodeBridge")

struct FCChatEvent {
    let type: String
    let content: String
    let toolName: String
    let toolArgs: [String: Any]
    let timestamp: Date
}

struct FCSession: Identifiable {
    let id: String
    let title: String
    let createdAt: String
    let cwd: String
    let messageCount: Int
}

struct FCModelStatus {
    let connected: Bool
    let models: [[String: Any]]
    let loaded: [String]
    let error: String?
}

class FusionCodeBridge: ObservableObject {
    static let shared = FusionCodeBridge()

    @Published var isConnected = false
    @Published var lastError: String?
    @Published var chatEvents: [FCChatEvent] = []
    @Published var isStreaming = false
    @Published var currentStreamContent = ""
    @Published var sessions: [FCSessionDetail] = []
    @Published var availableModels: [String] = []

    let serverURL = "http://127.0.0.1:\(FusionConfig.shared.fusionCodePort)"
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession = URLSession(configuration: .default)

    init() {
        checkConnection()
    }

    // MARK: - Connection

    func checkConnection() {
        Task {
            do {
                var req = URLRequest(url: URL(string: "\(serverURL)/api/model/status")!)
                req.setValue("Bearer \(FusionConfig.shared.fusionCodeApiKey)", forHTTPHeaderField: "Authorization")
                let (_, response) = try await urlSession.data(for: req)
                await MainActor.run {
                    self.isConnected = (response as? HTTPURLResponse)?.statusCode == 200
                    if self.isConnected {
                        self.lastError = nil
                        fcBridgeLog.info("fusion-code server connected")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isConnected = false
                    self.lastError = "fusion-code server not running on \(serverURL)"
                }
                fcBridgeLog.warning("fusion-code server unreachable: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - HTTP Helpers

    private func httpGet(_ path: String, query: [String: String] = [:]) async throws -> [String: Any] {
        var comps = URLComponents(string: "\(serverURL)\(path)")!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(FusionConfig.shared.fusionCodeApiKey)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await urlSession.data(for: request)
        guard let http = resp as? HTTPURLResponse else {
            throw NSError(domain: "FusionCodeBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        guard http.statusCode == 200 else {
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let msg = body?["error"] as? String ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "FusionCodeBridge", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw NSError(domain: "FusionCodeBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }
        return json
    }

    private func httpPost(_ path: String, body: [String: Any]? = nil, query: [String: String] = [:]) async throws -> [String: Any] {
        var comps = URLComponents(string: "\(serverURL)\(path)")!
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(FusionConfig.shared.fusionCodeApiKey)", forHTTPHeaderField: "Authorization")
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await urlSession.data(for: request)
        guard let http = resp as? HTTPURLResponse else {
            throw NSError(domain: "FusionCodeBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        guard http.statusCode == 200 else {
            let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let msg = body?["error"] as? String ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "FusionCodeBridge", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw NSError(domain: "FusionCodeBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }
        return json
    }

    // MARK: - Project

    func projectContext(cwd: String) async throws -> [String: Any] {
        try await httpGet("/api/project/context", query: ["cwd": cwd])
    }

    func listProjects() async throws -> [[String: Any]] {
        let result = try await httpGet("/api/projects")
        return (result["projects"] as? [[String: Any]]) ?? []
    }

    func projectContext(id: String) async throws -> [String: Any] {
        try await httpGet("/api/projects/\(id)/context")
    }

    // MARK: - Sessions

    func listSessions(cwd: String? = nil, projectId: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> [FCSession] {
        var query: [String: String] = ["limit": "\(limit)", "offset": "\(offset)"]
        if let cwd = cwd { query["cwd"] = cwd }
        if let pid = projectId { query["project_id"] = pid }
        let result = try await httpGet("/api/sessions", query: query)
        let raw = (result["sessions"] as? [[String: Any]]) ?? []
        return raw.compactMap { s in
            guard let id = s["id"] as? String else { return nil }
            return FCSession(
                id: id,
                title: (s["title"] as? String) ?? (s["name"] as? String) ?? "Untitled",
                createdAt: (s["created_at"] as? String) ?? (s["createdAt"] as? String) ?? "",
                cwd: (s["cwd"] as? String) ?? (s["workDir"] as? String) ?? "",
                messageCount: (s["message_count"] as? Int) ?? (s["messageCount"] as? Int) ?? 0
            )
        }
    }

    func getSession(id: String) async throws -> [String: Any] {
        try await httpGet("/api/sessions/\(id)")
    }

    // MARK: - Session Management

    @discardableResult
    func createSession(config: FCSessionConfig) -> String {
        let newId = config.sessionId.isEmpty ? UUID().uuidString.prefix(12).lowercased() : config.sessionId
        let cfg = config
        let detail = FCSessionDetail(
            id: String(newId),
            name: cfg.name,
            state: .idle,
            config: cfg,
            messageCount: 0
        )
        sessions.insert(detail, at: 0)
        fcBridgeLog.info("session created: \(newId)")
        return detail.id
    }

    func pauseSession(id: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        if sessions[idx].canPause {
            sessions[idx].state = .paused
            fcBridgeLog.info("session paused: \(id)")
        }
    }

    func resumeSession(id: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        if sessions[idx].canResume {
            sessions[idx].state = .running
            fcBridgeLog.info("session resumed: \(id)")
        }
    }

    func deleteSession(id: String) {
        sessions.removeAll { $0.id == id }
        fcBridgeLog.info("session deleted: \(id)")
    }

    func cloneSession(id: String) {
        guard let original = sessions.first(where: { $0.id == id }) else { return }
        let cloned = FCSessionDetail(
            id: UUID().uuidString.prefix(12).lowercased(),
            name: "\(original.name) (副本)",
            state: .idle,
            config: original.config,
            messageCount: 0
        )
        sessions.insert(cloned, at: 0)
        fcBridgeLog.info("session cloned from \(id) -> \(cloned.id)")
    }

    func renameSession(id: String, name: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[idx].name = name
        fcBridgeLog.info("session renamed: \(id) -> \(name)")
    }

    func refreshSessions() {
        Task {
            do {
                let result = try await httpGet("/api/sessions", query: ["limit": "100"])
                let raw = (result["sessions"] as? [[String: Any]]) ?? []
                await MainActor.run {
                    self.sessions = raw.compactMap { parseSessionDetail($0) }
                    fcBridgeLog.info("refreshed \(self.sessions.count) sessions from server")
                }
            } catch {
                fcBridgeLog.info("session refresh fallback to local: \(error.localizedDescription)")
            }
        }
    }

    func refreshModels() {
        Task {
            do {
                let status = try await modelStatus()
                await MainActor.run {
                    self.availableModels = status.loaded
                    if self.availableModels.isEmpty {
                        self.availableModels = []
                        fcBridgeLog.warning("no models loaded from fusion-code, falling back to MLX")
                    }
                    fcBridgeLog.info("available models: \(self.availableModels)")
                }
                if self.availableModels.isEmpty {
                    let mlxModels = await fetchMLXModels()
                    await MainActor.run {
                        if !mlxModels.isEmpty { self.availableModels = mlxModels }
                    }
                }
            } catch {
                fcBridgeLog.error("refreshModels failed: \(error.localizedDescription)")
                let mlxModels = await fetchMLXModels()
                await MainActor.run {
                    self.availableModels = mlxModels
                }
            }
        }
    }

    private func fetchMLXModels() async -> [String] {
        guard let url = URL(string: FusionConfig.shared.mlxBaseURL + "/v1/models") else { return [] }
        do {
            var request = URLRequest(url: url)
            let key = FusionConfig.shared.mlxResolvedApiKey
            if !key.isEmpty {
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            }
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["data"] as? [[String: Any]] else { return [] }
            return models.compactMap { $0["id"] as? String }
        } catch {
            fcBridgeLog.warning("MLX /v1/models unavailable: \(error.localizedDescription)")
            return []
        }
    }

    func compactSession(sessionId: String? = nil) {
        var dict: [String: Any] = ["action": "chat.compact"]
        if let sid = sessionId { dict["session_id"] = sid }
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { error in
                if let error = error {
                    fcBridgeLog.error("WS compact send error: \(error.localizedDescription)")
                } else {
                    fcBridgeLog.info("WS compact sent for session \(sessionId ?? "current")")
                }
            }
        }
    }

    private func parseSessionDetail(_ s: [String: Any]) -> FCSessionDetail? {
        guard let id = s["id"] as? String else { return nil }
        let stateStr = s["state"] as? String ?? "idle"
        let state = FCSessionState(rawValue: stateStr) ?? .idle
        let config = FCSessionConfig(
            sessionId: id,
            name: (s["name"] as? String) ?? "",
            workingDir: (s["working_dir"] as? String) ?? (s["cwd"] as? String) ?? "",
            model: (s["model"] as? String) ?? "",
            temperature: (s["temperature"] as? Double) ?? 0.1,
            maxTokens: (s["max_tokens"] as? Int) ?? 4096,
            securityMode: (s["security_mode"] as? String) ?? "manual",
            allowedDirs: (s["allowed_dirs"] as? [String]) ?? []
        )
        return FCSessionDetail(
            id: id,
            name: (s["name"] as? String) ?? "",
            state: state,
            config: config,
            messageCount: (s["message_count"] as? Int) ?? 0,
            createdAt: (s["created_at"] as? Double) ?? Date().timeIntervalSince1970,
            updatedAt: (s["updated_at"] as? Double) ?? Date().timeIntervalSince1970,
            error: s["error"] as? String ?? "",
            clusterNode: s["cluster_node"] as? String ?? ""
        )
    }

    // MARK: - Code Generation

    func generateCode(prompt: String, language: String, context: String? = nil, maxTokens: Int? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["prompt": prompt, "language": language]
        if let ctx = context { body["context"] = ctx }
        if let mt = maxTokens { body["max_tokens"] = mt }
        return try await httpPost("/api/code/generate", body: body)
    }

    // MARK: - LSP

    func lspOperation(_ operation: String, filePath: String, line: Int? = nil, character: Int? = nil, query: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["operation": operation, "file_path": filePath]
        if let l = line { body["line"] = l }
        if let c = character { body["character"] = c }
        if let q = query { body["query"] = q }
        return try await httpPost("/api/lsp/operation", body: body)
    }

    // MARK: - Memory

    func getMemory(cwd: String) async throws -> [String: Any] {
        try await httpGet("/api/memory", query: ["cwd": cwd])
    }

    func writeMemory(cwd: String, filename: String, content: String, type: String = "project") async throws -> [String: Any] {
        try await httpPost("/api/memory", body: ["filename": filename, "content": content, "type": type], query: ["cwd": cwd])
    }

    // MARK: - Model Status

    func modelStatus() async throws -> FCModelStatus {
        let result = try await httpGet("/api/model/status")
        return FCModelStatus(
            connected: (result["connected"] as? Bool) ?? false,
            models: (result["models"] as? [[String: Any]]) ?? [],
            loaded: (result["loaded"] as? [String]) ?? [],
            error: result["error"] as? String
        )
    }

    // MARK: - Knowledge Base

    func buildKB(cwd: String) async throws -> [String: Any] {
        try await httpPost("/api/kb/build", body: [:], query: ["cwd": cwd])
    }

    func queryKB(cwd: String, query: String, topK: Int = 5) async throws -> [String: Any] {
        try await httpPost("/api/kb/query", body: ["query": query, "topK": topK], query: ["cwd": cwd])
    }

    func kbStatus(cwd: String) async throws -> [String: Any] {
        try await httpGet("/api/kb/status", query: ["cwd": cwd])
    }

    // MARK: - Templates

    func listTemplates(cwd: String) async throws -> [String: Any] {
        try await httpGet("/api/templates", query: ["cwd": cwd])
    }

    // MARK: - WebSocket Chat Streaming

    func chatStream(sessionId: String? = nil, message: String, cwd: String? = nil, model: String? = nil, executionMode: String? = nil, webSearch: Bool = false, commandMode: Bool = false) {
        guard !isStreaming else { return }

        var wsURLStr = serverURL.replacingOccurrences(of: "http", with: "ws") + "/ws/chat"
        let token = FusionConfig.shared.fusionCodeApiKey
        if !token.isEmpty {
            let encoded = token.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? token
            wsURLStr += "?token=\(encoded)"
        }
        let wsURL = URL(string: wsURLStr)!
        webSocketTask = urlSession.webSocketTask(with: wsURL)
        webSocketTask?.resume()

        isStreaming = true
        currentStreamContent = ""
        fcBridgeLog.info("WS chat connecting to \(wsURL.absoluteString)")

        var sendDict: [String: Any] = ["action": "chat.stream", "message": message]
        if let sid = sessionId { sendDict["session_id"] = sid }
        if let c = cwd { sendDict["cwd"] = c }
        if let m = model { sendDict["model"] = m }
        if let mode = executionMode { sendDict["execution_mode"] = mode }
        if webSearch { sendDict["web_search"] = true }
        if commandMode { sendDict["command_mode"] = true }

        if let sendData = try? JSONSerialization.data(withJSONObject: sendDict),
           let sendStr = String(data: sendData, encoding: .utf8) {
            webSocketTask?.send(.string(sendStr)) { error in
                if let error = error {
                    fcBridgeLog.error("WS send error: \(error.localizedDescription)")
                }
            }
        }

        receiveWebSocketMessages()
    }

    func chatCancel() {
        let cancelDict: [String: Any] = ["action": "chat.cancel"]
        if let data = try? JSONSerialization.data(withJSONObject: cancelDict),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { _ in }
        }
        stopStreaming()
    }

    func sendPermissionResponse(toolCallId: String, approved: Bool) {
        let action = approved ? "tool.approve" : "tool.deny"
        let dict: [String: Any] = ["action": action, "tool_call_id": toolCallId]
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let str = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(str)) { error in
                if let error = error {
                    fcBridgeLog.error("WS permission send error: \(error.localizedDescription)")
                }
            }
            fcBridgeLog.info("WS permission \(action) for \(toolCallId)")
        }
    }

    private func receiveWebSocketMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleWSMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleWSMessage(text)
                    }
                @unknown default:
                    break
                }
                if self.isStreaming {
                    self.receiveWebSocketMessages()
                }
            case .failure(let error):
                fcBridgeLog.error("WS receive error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.stopStreaming()
                }
            }
        }
    }

    private func handleWSMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }

        let type = json["type"] as? String ?? ""

        switch type {
        case "chat_event":
            let event = json["event"] as? [String: Any] ?? [:]
            let eventType = event["type"] as? String ?? ""
            let content = event["content"] as? String ?? ""
            let toolName = event["name"] as? String ?? ""
            let toolArgs = event["args"] as? [String: Any] ?? [:]

            let fcEvent = FCChatEvent(
                type: eventType,
                content: content,
                toolName: toolName,
                toolArgs: toolArgs,
                timestamp: Date()
            )

            DispatchQueue.main.async {
                self.chatEvents.append(fcEvent)
                if !content.isEmpty {
                    self.currentStreamContent += content
                }
                self.objectWillChange.send()
            }

        case "chat_done":
            DispatchQueue.main.async {
                self.stopStreaming()
            }

        case "error":
            let msg = json["message"] as? String ?? "Unknown error"
            DispatchQueue.main.async {
                self.lastError = msg
                self.stopStreaming()
            }

        default:
            break
        }
    }

    private func stopStreaming() {
        isStreaming = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        fcBridgeLog.info("WS chat stream ended")
    }
}
