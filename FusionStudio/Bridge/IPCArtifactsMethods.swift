import Foundation
import os.log

extension IPCClient {
    // MARK: - Artifacts Engine (HTTP JSON-RPC, config from FusionConfig)

    private var artifactsEngineURL: String {
        FusionConfig.shared.artifactsEngineURL
    }

    func artifactsCall(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        var request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int(Date().timeIntervalSince1970 * 1000),
            "method": method,
        ]
        if !params.isEmpty {
            request["params"] = params
        }
        guard let requestData = try? JSONSerialization.data(withJSONObject: request) else {
            throw IPCError.invalidRequest
        }
        guard let url = URL(string: artifactsEngineURL) else {
            throw IPCError.invalidRequest
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = ProcessInfo.processInfo.environment["FUSION_ARTIFACTS_API_KEY"], !key.isEmpty {
            urlRequest.setValue(key, forHTTPHeaderField: "X-API-Key")
        }
        urlRequest.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IPCError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw IPCError.rpcError(code: httpResponse.statusCode, message: "HTTP \(httpResponse.statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IPCError.invalidResponse
        }
        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let msg = error["message"] as? String ?? "Unknown error"
            throw IPCError.rpcError(code: code, message: msg)
        }
        return json["result"] as? [String: Any] ?? [:]
    }

    func artifactCreate(sessionId: String, name: String, type: String, kind: String? = nil, content: String, summary: String? = nil, projectId: String? = nil, metadata: [String: Any]? = nil) async throws -> [String: Any] {
        var params: [String: Any] = [
            "session_id": sessionId,
            "name": name,
            "type": type,
            "content": content,
        ]
        if let k = kind { params["kind"] = k }
        if let s = summary { params["summary"] = s }
        if let p = projectId { params["project_id"] = p }
        if let m = metadata { params["metadata"] = m }
        return try await artifactsCall(method: "artifact.create", params: params)
    }

    func artifactGet(artifactId: String) async throws -> [String: Any] {
        let r = try await artifactsCall(method: "artifact.get", params: ["artifact_id": artifactId])
        if let art = r["artifact"] as? [String: Any] {
            var flat = art
            if flat["starred"] == nil { flat["starred"] = flat["is_starred"] }
            if flat["pinned"] == nil { flat["pinned"] = flat["is_pinned"] }
            return flat
        }
        return r
    }

    func artifactGetContent(artifactId: String, version: Int? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["artifact_id": artifactId]
        if let v = version { params["version"] = v }
        return try await artifactsCall(method: "artifact.get_content", params: params)
    }

    func artifactList(sessionId: String, includeDeleted: Bool = false, projectId: String? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["session_id": sessionId]
        if includeDeleted { params["include_deleted"] = true }
        if let p = projectId { params["project_id"] = p }
        return try await artifactsCall(method: "artifact.list", params: params)
    }

    func artifactDelete(artifactId: String, hard: Bool = false) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.delete", params: ["artifact_id": artifactId, "hard": hard])
    }

    func artifactUpdate(artifactId: String, content: String, changeLog: String? = nil, projectId: String? = nil, metadata: [String: Any]? = nil, expectedContentHash: String? = nil) async throws -> [String: Any] {
        var params: [String: Any] = ["artifact_id": artifactId, "content": content]
        if let cl = changeLog { params["change_log"] = cl }
        if let p = projectId { params["project_id"] = p }
        if let m = metadata { params["metadata"] = m }
        if let h = expectedContentHash { params["expected_content_hash"] = h }
        return try await artifactsCall(method: "artifact.update", params: params)
    }

    func artifactVersionList(artifactId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.version_list", params: ["artifact_id": artifactId])
    }

    func artifactVersionRollback(artifactId: String, targetVersion: Int) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.version_rollback", params: ["artifact_id": artifactId, "target_version": targetVersion])
    }

    func artifactInject(messages: [[String: Any]], outputBudget: Int = 8192) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.inject", params: ["messages": messages, "output_budget": outputBudget])
    }

    func artifactCheckSafety(messages: [[String: Any]], outputBudget: Int = 8192) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.check_safety", params: ["messages": messages, "output_budget": outputBudget])
    }

    func artifactExport(artifactId: String, format: String = "json") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.export", params: ["artifact_id": artifactId, "format": format])
    }

    func artifactExportSession(sessionId: String, format: String = "json") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.export_session", params: ["session_id": sessionId, "format": format])
    }

    func artifactImport(data: [String: Any]) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.import", params: ["data": data])
    }

    func artifactPing() async throws -> Bool {
        let result = try await artifactsCall(method: "ping", params: [:])
        return result["pong"] as? Bool ?? false
    }

    func artifactSync(artifactId: String, filePath: String, direction: String = "bidirectional") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.sync", params: [
            "artifact_id": artifactId,
            "file_path": filePath,
            "direction": direction
        ])
    }

    func artifactWatch(artifactId: String, action: String = "register") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.watch", params: [
            "artifact_id": artifactId,
            "action": action
        ])
    }

    func artifactExportCode(artifactId: String, language: String = "swift") async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.export_code", params: [
            "artifact_id": artifactId,
            "language": language
        ])
    }

    func artifactImportCode(code: String, language: String, name: String, sessionId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.import_code", params: [
            "code": code,
            "language": language,
            "name": name,
            "session_id": sessionId
        ])
    }

    // MARK: - Artifacts Engine (REST endpoints)

    func artifactTokenCount(text: String, model: String? = nil) async throws -> [String: Any] {
        let baseURL = artifactsEngineURL
        guard let url = URL(string: "\(baseURL)/api/token-count") else {
            throw IPCError.invalidRequest
        }
        var body: [String: Any] = ["text": text]
        if let m = model { body["model"] = m }
        guard let requestData = try? JSONSerialization.data(withJSONObject: body) else {
            throw IPCError.invalidRequest
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = requestData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IPCError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw IPCError.rpcError(code: httpResponse.statusCode, message: "artifactTokenCount HTTP \(httpResponse.statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw IPCError.invalidResponse
        }
        return json
    }

    func artifactRender(content: String, sessionId: String, langHint: String = "", projectId: String? = nil) async throws -> [String: Any] {
        var params: [String: Any] = [
            "content": content,
            "session_id": sessionId,
            "lang_hint": langHint,
        ]
        if let pid = projectId { params["project_id"] = pid }
        return try await artifactsCall(method: "artifact.render", params: params)
    }

    // MARK: - Artifacts Engine 扩展方法 (Issue #26: rename/star/pin/duplicate/snapshot/share/recycle/folder/tag/interact)

    // Callers: ArtifactsPanel / ArtifactCanvasView / 版本历史面板 / 分享弹窗. Affected API: 新增 artifact.* 方法, 复用 artifactsCall (HTTP).
    @discardableResult
    func artifactCall(method: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        return try await artifactsCall(method: method, params: params)
    }

    func artifactRename(artifactId: String, newName: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.rename", params: ["artifact_id": artifactId, "new_name": newName])
    }

    func artifactStar(artifactId: String, starred: Bool = true) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.star", params: ["artifact_id": artifactId, "starred": starred])
    }

    func artifactPin(artifactId: String, chatId: String? = nil, pinned: Bool = true) async throws -> [String: Any] {
        var p: [String: Any] = ["artifact_id": artifactId, "pinned": pinned]
        if let c = chatId { p["chat_id"] = c }
        return try await artifactsCall(method: "artifact.pin", params: p)
    }

    func artifactDuplicate(artifactId: String, newName: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["artifact_id": artifactId]
        if let n = newName { p["new_name"] = n }
        return try await artifactsCall(method: "artifact.duplicate", params: p)
    }

    func artifactListAll(filters: [String: Any]? = nil, sort: String = "updated_at", page: Int = 1, pageSize: Int = 20) async throws -> [String: Any] {
        var p: [String: Any] = ["sort": sort, "page": page, "page_size": pageSize]
        if let f = filters { p["filters"] = f }
        return try await artifactsCall(method: "artifact.list_all", params: p)
    }

    func artifactListRecycle(page: Int = 1, pageSize: Int = 20) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.list_recycle", params: ["page": page, "page_size": pageSize])
    }

    func artifactRestore(artifactId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.restore", params: ["artifact_id": artifactId])
    }

    func artifactPurgeExpired() async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.purge_expired", params: [:])
    }

    func artifactCreateSnapshot(artifactId: String, label: String? = nil, author: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["artifact_id": artifactId]
        if let l = label { p["label"] = l }
        if let a = author { p["author"] = a }
        return try await artifactsCall(method: "artifact.create_snapshot", params: p)
    }

    func artifactListSnapshots(artifactId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.list_snapshots", params: ["artifact_id": artifactId])
    }

    func artifactCreateShare(artifactId: String, createdBy: String? = nil, expiresAt: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["artifact_id": artifactId]
        if let c = createdBy { p["created_by"] = c }
        if let e = expiresAt { p["expires_at"] = e }
        return try await artifactsCall(method: "artifact.create_share", params: p)
    }

    func artifactGetShared(shareId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.get_shared", params: ["share_id": shareId])
    }

    func artifactRevokeShare(shareId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.revoke_share", params: ["share_id": shareId])
    }

    func artifactMoveToProjectKb(artifactId: String, projectId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.move_to_project_kb", params: ["artifact_id": artifactId, "project_id": projectId])
    }

    // Callers: ArtifactsPanel event timeline. Affected API: artifact.list_events (new).
    func artifactListEvents(artifactId: String, limit: Int = 50, offset: Int = 0) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.list_events", params: ["artifact_id": artifactId, "limit": limit, "offset": offset])
    }

    func artifactInteract(artifactId: String, action: String = "state_change", payload: [String: Any] = [:], sessionId: String = "") async throws -> [String: Any] {
        var p: [String: Any] = ["artifact_id": artifactId, "action": action, "payload": payload]
        if !sessionId.isEmpty { p["session_id"] = sessionId }
        return try await artifactsCall(method: "artifact.interact", params: p)
    }

    func artifactCreateFolder(name: String, parentId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = ["name": name]
        if let pid = parentId { p["parent_id"] = pid }
        return try await artifactsCall(method: "artifact.create_folder", params: p)
    }

    func artifactListFolders(parentId: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = [:]
        if let pid = parentId { p["parent_id"] = pid }
        return try await artifactsCall(method: "artifact.list_folders", params: p)
    }

    func artifactRenameFolder(folderId: String, newName: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.rename_folder", params: ["folder_id": folderId, "new_name": newName])
    }

    func artifactDeleteFolder(folderId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.delete_folder", params: ["folder_id": folderId])
    }

    func artifactMoveToFolder(artifactId: String, folderId: String?) async throws -> [String: Any] {
        var p: [String: Any] = ["artifact_id": artifactId]
        if let f = folderId { p["folder_id"] = f }
        return try await artifactsCall(method: "artifact.move_to_folder", params: p)
    }

    func artifactAddTag(artifactId: String, tag: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.add_tag", params: ["artifact_id": artifactId, "tag": tag])
    }

    func artifactRemoveTag(artifactId: String, tag: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.remove_tag", params: ["artifact_id": artifactId, "tag": tag])
    }

    func artifactListTags(artifactId: String) async throws -> [String: Any] {
        return try await artifactsCall(method: "artifact.list_tags", params: ["artifact_id": artifactId])
    }

    // MARK: - REST /api/v1 (Issue #26-B: public share direct access)

    // Callers: ArtifactShareDialog / share link resolver. Affected API: GET /api/v1/share/{share_id}.
    // No auth required; returns read-only artifact render data.
    // Fallback: REST 端点上游未实现（fusion-artifacts-engine #38）→ 退回 RPC artifact.get_shared。
    func shareGet(shareId: String) async throws -> [String: Any] {
        let baseURL = artifactsEngineURL
        guard let url = URL(string: "\(baseURL)/api/v1/share/\(shareId)") else {
            throw IPCError.invalidRequest
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw IPCError.invalidResponse
        }
        if httpResponse.statusCode == 200 {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw IPCError.invalidResponse
            }
            ipcLog.info("shareGet REST: share_id=\(shareId, privacy: .public) ok")
            return json
        }
        ipcLog.warning("shareGet REST \(httpResponse.statusCode) share_id=\(shareId, privacy: .public), fallback to RPC artifact.get_shared")
        return try await artifactsCall(method: "artifact.get_shared", params: ["share_id": shareId])
    }

    // MARK: - SSE Subscriptions (Issue #26-C: artifact + session event streams)

    // SSE event delivered via AsyncStream. Each element is [String: Any] parsed from data: line.
    // Reconnect uses Last-Event-ID header.

    func artifactEventStream(artifactId: String, lastEventId: String? = nil) -> AsyncStream<[String: Any]> {
        let baseURL = artifactsEngineURL
        return sseStream(urlString: "\(baseURL)/api/v1/artifacts/\(artifactId)/events", lastEventId: lastEventId)
    }

    func sessionEventStream(sessionId: String, lastEventId: String? = nil) -> AsyncStream<[String: Any]> {
        let baseURL = artifactsEngineURL
        return sseStream(urlString: "\(baseURL)/api/v1/sessions/\(sessionId)/events", lastEventId: lastEventId)
    }

    private func sseStream(urlString: String, lastEventId: String? = nil) -> AsyncStream<[String: Any]> {
        AsyncStream { continuation in
            guard let url = URL(string: urlString) else {
                continuation.finish()
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            if let eid = lastEventId {
                request.setValue(eid, forHTTPHeaderField: "Last-Event-ID")
            }
            request.timeoutInterval = 300

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    ipcLog.warning("SSE stream error: \(error.localizedDescription, privacy: .public)")
                    continuation.finish()
                    return
                }
                guard let data = data else {
                    continuation.finish()
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                    ipcLog.warning("SSE HTTP \(code) url=\(urlString, privacy: .public)")
                    continuation.finish()
                    return
                }
                let text = String(data: data, encoding: .utf8) ?? ""
                var currentEventId: String?
                for line in text.components(separatedBy: "\n") {
                    if line.hasPrefix("id:") {
                        currentEventId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        let jsonStr = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if let jsonData = jsonStr.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            if let eid = currentEventId {
                                var mutated = json
                                mutated["_sse_event_id"] = eid
                                continuation.yield(mutated)
                            } else {
                                continuation.yield(json)
                            }
                        }
                    }
                }
                continuation.finish()
            }
            task.resume()
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Issue #90 additions (artifact.patch / artifact.load / context.budget)

    func artifactPatch(artifactId: String, operation: String, anchor: String? = nil, content: String? = nil, expectedVersion: Int? = nil) async throws -> [String: Any] {
        var p: [String: Any] = [
            "artifact_id": artifactId,
            "operation": operation,
        ]
        if let a = anchor { p["anchor"] = a }
        if let c = content { p["content"] = c }
        if let v = expectedVersion { p["expected_version"] = v }
        ipcLog.info("artifactPatch: id=\(artifactId, privacy: .public) op=\(operation, privacy: .public) anchor=\(anchor ?? "nil", privacy: .public)")
        return try await artifactsCall(method: "artifact.patch", params: p)
    }

    func artifactLoad(artifactId: String, previewOnly: Bool = false, section: String? = nil) async throws -> [String: Any] {
        var p: [String: Any] = [
            "artifact_id": artifactId,
            "preview_only": previewOnly,
        ]
        if let s = section { p["section"] = s }
        ipcLog.info("artifactLoad: id=\(artifactId, privacy: .public) preview=\(previewOnly) section=\(section ?? "nil", privacy: .public)")
        return try await artifactsCall(method: "artifact.load", params: p)
    }

    func contextBudget(contextWindow: Int? = nil) async throws -> [String: Any] {
        var p: [String: Any] = [:]
        if let cw = contextWindow { p["context_window"] = cw }
        ipcLog.info("contextBudget: window=\(contextWindow?.description ?? "nil")")
        return try await artifactsCall(method: "context.budget", params: p)
    }

}
