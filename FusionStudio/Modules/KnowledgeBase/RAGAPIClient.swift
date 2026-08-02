import Foundation
import Combine
import os

struct KBInfo: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let chunkStrategy: String?
    let embeddingModel: String?
    let fileCount: Int?
    let chunkCount: Int?
    let createdAt: Double?
}

struct KBSearchResult: Identifiable {
    let id: String
    let score: Double
    let text: String
    let docName: String
    let docPath: String
    let docType: String?
    let chunkIndex: Int?
    let metadata: [String: Any]?
    let context: String?
}

struct KBAskResult {
    let answer: String
    let sources: [KBSource]
}

struct KBSource {
    let docName: String
    let docPath: String
    let score: Double
    let snippet: String
}

struct KBStats: Codable {
    let id: String
    let name: String
    let documents: Int
    let chunks: Int
    let vectors: Int
    let fileCount: Int?
    let chunkCount: Int?
}

struct KBDocument: Identifiable {
    let id: String
    let filePath: String
    let fileName: String
    let docType: String
    let size: Int
    let chunkCount: Int
    let chars: Int
    let createdAt: Double?
}

struct KBWatchInfo: Identifiable {
    let id: String
    let fileCount: Int
    let pollInterval: Int
    let changesDetected: Int
    let lastReindex: String?
}

struct KBAPIKeyInfo: Identifiable {
    let id: String
    let name: String
    let createdAt: Double
}

class RAGAPIClient: ObservableObject {
    static let shared = RAGAPIClient()

    @Published var knowledgeBases: [KBInfo] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "RAGAPIClient")

    private var baseURL: String {
        FusionConfig.shared.fusionRagURL
    }

    private var apiKey: String {
        FusionConfig.shared.fusionRagApiKey
    }

    func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw RAGAPIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        request.timeoutInterval = 60
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw RAGAPIClientError.invalidResponse
        }
        guard httpResp.statusCode >= 200 && httpResp.statusCode < 300 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            logger.error("RAG API error: \(httpResp.statusCode) \(bodyStr)")
            throw RAGAPIClientError.httpError(status: httpResp.statusCode, message: bodyStr)
        }
        if data.isEmpty { return [:] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RAGAPIClientError.invalidResponse
        }
        return json
    }

    private func requestArray(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> [[String: Any]] {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw RAGAPIClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        request.timeoutInterval = 60
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse else {
            throw RAGAPIClientError.invalidResponse
        }
        guard httpResp.statusCode >= 200 && httpResp.statusCode < 300 else {
            throw RAGAPIClientError.httpError(status: httpResp.statusCode, message: "")
        }
        if data.isEmpty { return [] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return [obj]
            }
            return []
        }
        return json
    }

    // MARK: - Health

    func healthCheck() async -> Bool {
        do {
            let result = try await request("/health")
            return result["status"] as? String == "ok"
        } catch {
            logger.warning("RAG health check failed: \(error.localizedDescription)")
            return false
        }
    }

    func serviceStatus() async -> [String: Any]? {
        do {
            return try await request("/kb/status")
        } catch {
            logger.error("serviceStatus failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - KB CRUD

    func listBases() async -> [KBInfo] {
        isLoading = true
        defer { isLoading = false }
        do {
            let items = try await requestArray("/kb/bases")
            let bases = items.compactMap { item -> KBInfo? in
                guard let id = item["id"] as? String else { return nil }
                return KBInfo(
                    id: id,
                    name: item["name"] as? String ?? "",
                    description: item["description"] as? String ?? "",
                    chunkStrategy: item["chunk_strategy"] as? String,
                    embeddingModel: item["embedding_model"] as? String,
                    fileCount: item["file_count"] as? Int,
                    chunkCount: item["chunk_count"] as? Int,
                    createdAt: item["created_at"] as? Double
                )
            }
            await MainActor.run { self.knowledgeBases = bases }
            return bases
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            logger.error("listBases failed: \(error.localizedDescription)")
            return []
        }
    }

    func createBase(name: String, description: String = "", chunkStrategy: String = "semantic", embeddingModel: String = "BGE-M3", kbId: String? = nil) async -> KBInfo? {
        do {
            var body: [String: Any] = [
                "name": name,
                "description": description,
                "chunk_strategy": chunkStrategy,
                "embedding_model": embeddingModel,
            ]
            if let kbId = kbId {
                body["kb_id"] = kbId
            }
            let result = try await request("/kb/bases", method: "POST", body: body)
            guard let id = result["id"] as? String else { return nil }
            return KBInfo(id: id, name: name, description: description, chunkStrategy: chunkStrategy, embeddingModel: embeddingModel, fileCount: 0, chunkCount: 0, createdAt: Date().timeIntervalSince1970)
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            logger.error("createBase failed: \(error.localizedDescription)")
            return nil
        }
    }

    func deleteBase(kbId: String) async -> Bool {
        do {
            let _ = try await request("/kb/bases/\(kbId)", method: "DELETE")
            return true
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            logger.error("deleteBase failed: \(error.localizedDescription)")
            return false
        }
    }

    func getBase(kbId: String) async -> KBInfo? {
        do {
            let result = try await request("/kb/bases/\(kbId)")
            guard let id = result["id"] as? String else { return nil }
            return KBInfo(
                id: id,
                name: result["name"] as? String ?? (result["config"] as? [String: Any])?["name"] as? String ?? "",
                description: result["description"] as? String ?? "",
                chunkStrategy: (result["config"] as? [String: Any])?["chunk_strategy"] as? String,
                embeddingModel: (result["config"] as? [String: Any])?["embedding_model"] as? String,
                fileCount: result["file_count"] as? Int,
                chunkCount: result["chunk_count"] as? Int,
                createdAt: result["created_at"] as? Double
            )
        } catch {
            logger.error("getBase failed: \(error.localizedDescription)")
            return nil
        }
    }

    func getStats(kbId: String) async -> KBStats? {
        do {
            let result = try await request("/kb/bases/\(kbId)/stats")
            return KBStats(
                id: result["id"] as? String ?? "",
                name: result["name"] as? String ?? "",
                documents: result["documents"] as? Int ?? 0,
                chunks: result["chunks"] as? Int ?? 0,
                vectors: result["vectors"] as? Int ?? 0,
                fileCount: result["file_count"] as? Int,
                chunkCount: result["chunk_count"] as? Int
            )
        } catch {
            logger.error("getStats failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Documents

    func listDocuments(kbId: String) async -> [KBDocument] {
        do {
            let items = try await requestArray("/kb/bases/\(kbId)/documents")
            return items.compactMap { item -> KBDocument? in
                guard let id = item["doc_id"] as? String ?? item["id"] as? String else { return nil }
                return KBDocument(
                    id: id,
                    filePath: item["file_path"] as? String ?? "",
                    fileName: item["file_name"] as? String ?? "",
                    docType: item["doc_type"] as? String ?? "",
                    size: item["size"] as? Int ?? 0,
                    chunkCount: item["chunk_count"] as? Int ?? 0,
                    chars: item["chars"] as? Int ?? 0,
                    createdAt: item["created_at"] as? Double
                )
            }
        } catch {
            logger.error("listDocuments failed: \(error.localizedDescription)")
            return []
        }
    }

    func uploadDocument(kbId: String, filePath: String, contextualize: Bool = true) async -> [String: Any]? {
        do {
            return try await request("/kb/bases/\(kbId)/documents", method: "POST", body: [
                "file_path": filePath,
                "contextualize": contextualize,
            ])
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            logger.error("uploadDocument failed: \(error.localizedDescription)")
            return nil
        }
    }

    func batchUpload(kbId: String, filePaths: [String], contextualize: Bool = true) async -> [String: Any]? {
        do {
            return try await request("/kb/bases/\(kbId)/documents/batch", method: "POST", body: [
                "file_paths": filePaths,
                "contextualize": contextualize,
            ])
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            logger.error("batchUpload failed: \(error.localizedDescription)")
            return nil
        }
    }

    func ingestContent(kbId: String, content: String, contentType: String = "text", docName: String? = nil, metadata: [String: Any]? = nil) async -> [String: Any]? {
        do {
            var body: [String: Any] = [
                "content": content,
                "content_type": contentType,
            ]
            if let docName = docName {
                body["doc_name"] = docName
            }
            if let metadata = metadata {
                body["metadata"] = metadata
            }
            return try await request("/kb/bases/\(kbId)/documents/ingest", method: "POST", body: body)
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            logger.error("ingestContent failed: \(error.localizedDescription)")
            return nil
        }
    }

    func deleteDocument(kbId: String, docId: String) async -> Bool {
        do {
            let _ = try await request("/kb/bases/\(kbId)/documents/\(docId)", method: "DELETE")
            return true
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            logger.error("deleteDocument failed: \(error.localizedDescription)")
            return false
        }
    }

    func replaceDocument(kbId: String, docId: String, filePath: String, contextualize: Bool = true) async -> [String: Any]? {
        do {
            return try await request("/kb/bases/\(kbId)/documents/\(docId)", method: "PUT", body: [
                "file_path": filePath,
                "contextualize": contextualize,
            ])
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            logger.error("replaceDocument failed: \(error.localizedDescription)")
            return nil
        }
    }

    func documentStatus(kbId: String, docId: String) async -> [String: Any]? {
        do {
            return try await request("/kb/bases/\(kbId)/documents/\(docId)/status")
        } catch {
            logger.error("documentStatus failed: \(error.localizedDescription)")
            return nil
        }
    }

    func scanDirectory(kbId: String, dirPath: String, contextualize: Bool = true) async -> [String: Any]? {
        do {
            return try await request("/kb/bases/\(kbId)/scan", method: "POST", body: [
                "dir_path": dirPath,
                "contextualize": contextualize,
            ])
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            logger.error("scanDirectory failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - File Watch

    func watchFiles(kbId: String, filePaths: [String], pollInterval: Int = 30) async -> KBWatchInfo? {
        do {
            let result = try await request("/kb/bases/\(kbId)/watch", method: "POST", body: [
                "file_paths": filePaths,
                "poll_interval": pollInterval,
            ])
            guard let watchId = result["watch_id"] as? String else { return nil }
            return KBWatchInfo(
                id: watchId,
                fileCount: result["file_count"] as? Int ?? 0,
                pollInterval: result["poll_interval"] as? Int ?? pollInterval,
                changesDetected: 0,
                lastReindex: nil
            )
        } catch {
            logger.error("watchFiles failed: \(error.localizedDescription)")
            return nil
        }
    }

    func unwatchFiles(kbId: String, watchId: String) async -> Bool {
        do {
            let _ = try await request("/kb/bases/\(kbId)/unwatch", method: "POST", body: [
                "watch_id": watchId,
            ])
            return true
        } catch {
            logger.error("unwatchFiles failed: \(error.localizedDescription)")
            return false
        }
    }

    func watchStatus(kbId: String) async -> [KBWatchInfo] {
        do {
            let result = try await request("/kb/bases/\(kbId)/watch/status")
            let watches = result["watches"] as? [[String: Any]] ?? []
            return watches.compactMap { w -> KBWatchInfo? in
                guard let watchId = w["watch_id"] as? String else { return nil }
                return KBWatchInfo(
                    id: watchId,
                    fileCount: w["file_count"] as? Int ?? 0,
                    pollInterval: 0,
                    changesDetected: w["changes_detected"] as? Int ?? 0,
                    lastReindex: w["last_reindex"] as? String
                )
            }
        } catch {
            logger.error("watchStatus failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Search

    func search(kbId: String, query: String, topK: Int = 5, threshold: Double = 0.3,
                rewriteMode: String? = nil, hybrid: Bool = false, rerank: Bool = false,
                hybridAlpha: Double = 0.7, folderPrefix: String? = nil) async -> [KBSearchResult] {
        do {
            var body: [String: Any] = [
                "query": query,
                "top_k": topK,
                "threshold": threshold,
                "hybrid": hybrid,
                "rerank": rerank,
                "hybrid_alpha": hybridAlpha,
            ]
            if let mode = rewriteMode {
                body["rewrite_mode"] = mode
            }
            if let prefix = folderPrefix {
                body["folder_prefix"] = prefix
            }
            let items = try await requestArray("/kb/bases/\(kbId)/search", method: "POST", body: body)
            return items.compactMap { item -> KBSearchResult? in
                guard let id = item["id"] as? String else { return nil }
                return KBSearchResult(
                    id: id,
                    score: item["score"] as? Double ?? 0,
                    text: item["text"] as? String ?? "",
                    docName: item["doc_name"] as? String ?? "",
                    docPath: item["doc_path"] as? String ?? "",
                    docType: item["doc_type"] as? String,
                    chunkIndex: item["chunk_index"] as? Int,
                    metadata: item["metadata"] as? [String: Any],
                    context: item["context"] as? String
                )
            }
        } catch {
            logger.error("search failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Ask (RAG)

    func ask(kbId: String, question: String, topK: Int = 5, rewriteMode: String? = nil,
             history: [[String: String]]? = nil, hybrid: Bool = false, rerank: Bool = false,
             model: String? = nil, maxTokens: Int? = nil, temperature: Double? = nil,
             folderPrefix: String? = nil) async -> KBAskResult? {
        do {
            var body: [String: Any] = [
                "question": question,
                "top_k": topK,
                "hybrid": hybrid,
                "rerank": rerank,
            ]
            if let mode = rewriteMode {
                body["rewrite_mode"] = mode
            }
            if let hist = history {
                body["history"] = hist
            }
            if let model = model {
                body["model"] = model
            }
            if let maxTokens = maxTokens {
                body["max_tokens"] = maxTokens
            }
            if let temperature = temperature {
                body["temperature"] = temperature
            }
            if let prefix = folderPrefix {
                body["folder_prefix"] = prefix
            }
            let result = try await request("/kb/bases/\(kbId)/ask", method: "POST", body: body)
            let sources = (result["sources"] as? [[String: Any]] ?? []).compactMap { s -> KBSource? in
                KBSource(
                    docName: s["doc_name"] as? String ?? "",
                    docPath: s["doc_path"] as? String ?? "",
                    score: s["score"] as? Double ?? 0,
                    snippet: s["snippet"] as? String ?? ""
                )
            }
            return KBAskResult(
                answer: result["answer"] as? String ?? "No answer",
                sources: sources
            )
        } catch {
            logger.error("ask failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Project-KB Mapping

    func mapProjectKB(projectId: String, kbId: String? = nil, name: String? = nil) async -> [String: Any]? {
        do {
            var body: [String: Any] = [:]
            if let kbId = kbId {
                body["kb_id"] = kbId
            }
            if let name = name {
                body["name"] = name
            }
            return try await request("/kb/projects/\(projectId)/kb", method: "POST", body: body)
        } catch {
            logger.error("mapProjectKB failed: \(error.localizedDescription)")
            return nil
        }
    }

    func getProjectKB(projectId: String) async -> String? {
        do {
            let result = try await request("/kb/projects/\(projectId)/kb")
            return result["kb_id"] as? String
        } catch {
            logger.error("getProjectKB failed: \(error.localizedDescription)")
            return nil
        }
    }

    func unmapProjectKB(projectId: String) async -> Bool {
        do {
            let _ = try await request("/kb/projects/\(projectId)/kb", method: "DELETE")
            return true
        } catch {
            logger.error("unmapProjectKB failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - API Key Management

    func listApiKeys() async -> [KBAPIKeyInfo] {
        do {
            let result = try await request("/kb/auth/keys")
            let items = result["keys"] as? [[String: Any]] ?? []
            return items.compactMap { k -> KBAPIKeyInfo? in
                guard let hash = k["key_hash"] as? String else { return nil }
                return KBAPIKeyInfo(
                    id: hash,
                    name: k["name"] as? String ?? "",
                    createdAt: k["created_at"] as? Double ?? 0
                )
            }
        } catch {
            logger.error("listApiKeys failed: \(error.localizedDescription)")
            return []
        }
    }

    func createApiKey(name: String = "default") async -> String? {
        do {
            let result = try await request("/kb/auth/keys", method: "POST", body: [
                "name": name,
            ])
            if let returned = result["key"] as? String {
                return returned
            }
            return result["api_key"] as? String
        } catch {
            logger.error("createApiKey failed: \(error.localizedDescription)")
            return nil
        }
    }

    func deleteApiKey(keyHash: String) async -> Bool {
        do {
            let _ = try await request("/kb/auth/keys/\(keyHash)", method: "DELETE")
            return true
        } catch {
            logger.error("deleteApiKey failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Version Snapshots

    func createSnapshot(kbId: String, description: String = "") async -> [String: Any]? {
        do {
            return try await request("/kb/bases/\(kbId)/versions", method: "POST", body: [
                "description": description,
            ])
        } catch {
            logger.error("createSnapshot failed: \(error.localizedDescription)")
            return nil
        }
    }

    func listSnapshots(kbId: String) async -> [[String: Any]] {
        do {
            return try await requestArray("/kb/bases/\(kbId)/versions")
        } catch {
            logger.error("listSnapshots failed: \(error.localizedDescription)")
            return []
        }
    }

    func rollbackSnapshot(kbId: String, versionId: String) async -> Bool {
        do {
            let _ = try await request("/kb/bases/\(kbId)/versions/\(versionId)/rollback", method: "POST", body: [:])
            return true
        } catch {
            logger.error("rollbackSnapshot failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Search Templates

    func listTemplates(kbId: String) async -> [[String: Any]] {
        do {
            return try await requestArray("/kb/bases/\(kbId)/templates")
        } catch {
            logger.error("listTemplates failed: \(error.localizedDescription)")
            return []
        }
    }

    func createTemplate(kbId: String, name: String, description: String = "",
                        alpha: Double = 0.7, rerank: Bool = false,
                        topK: Int = 10, threshold: Double = 0.5,
                        rewriteMode: String = "") async -> [String: Any]? {
        do {
            return try await request("/kb/bases/\(kbId)/templates", method: "POST", body: [
                "name": name,
                "description": description,
                "alpha": alpha,
                "rerank": rerank,
                "top_k": topK,
                "threshold": threshold,
                "rewrite_mode": rewriteMode,
            ])
        } catch {
            logger.error("createTemplate failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Permissions

    func listPermissions(kbId: String) async -> [[String: Any]] {
        do {
            return try await requestArray("/kb/bases/\(kbId)/permissions")
        } catch {
            logger.error("listPermissions failed: \(error.localizedDescription)")
            return []
        }
    }

    func addPermission(kbId: String, subject: String, resourceType: String = "kb",
                       resourcePath: String = "/", actions: [String] = ["read"]) async -> [String: Any]? {
        do {
            return try await request("/kb/bases/\(kbId)/permissions", method: "POST", body: [
                "subject": subject,
                "resource_type": resourceType,
                "resource_path": resourcePath,
                "actions": actions,
            ])
        } catch {
            logger.error("addPermission failed: \(error.localizedDescription)")
            return nil
        }
    }

    func checkPermission(kbId: String, subject: String, action: String = "read",
                         resourcePath: String = "/") async -> Bool {
        do {
            let result = try await request("/kb/bases/\(kbId)/permissions/check", method: "POST", body: [
                "subject": subject,
                "action": action,
                "resource_path": resourcePath,
            ])
            return result["allowed"] as? Bool ?? false
        } catch {
            logger.error("checkPermission failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Audit Logs

    func listAuditLogs(kbId: String, limit: Int = 50, offset: Int = 0) async -> [[String: Any]] {
        do {
            return try await requestArray("/kb/bases/\(kbId)/audit?limit=\(limit)&offset=\(offset)")
        } catch {
            logger.error("listAuditLogs failed: \(error.localizedDescription)")
            return []
        }
    }

    func exportAuditLogs(kbId: String, format: String = "json") async -> String? {
        do {
            let result = try await request("/kb/bases/\(kbId)/audit/export?format=\(format)")
            return result["data"] as? String ?? (result.description)
        } catch {
            logger.error("exportAuditLogs failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Benchmark

    func runBench(kbId: String, queries: [[String: Any]]) async -> [String: Any]? {
        do {
            return try await request("/kb/bases/\(kbId)/bench", method: "POST", body: [
                "queries": queries,
            ])
        } catch {
            logger.error("runBench failed: \(error.localizedDescription)")
            return nil
        }
    }

    func listBenchResults(kbId: String, testName: String? = nil) async -> [[String: Any]] {
        do {
            var path = "/kb/bases/\(kbId)/bench/results"
            if let name = testName {
                path += "?test_name=\(name)"
            }
            return try await requestArray(path)
        } catch {
            logger.error("listBenchResults failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Incremental Sync

    func incrementalSync(kbId: String, directory: String, patterns: [String]? = nil) async -> [String: Any]? {
        do {
            var body: [String: Any] = ["directory": directory]
            if let patterns = patterns {
                body["patterns"] = patterns
            }
            return try await request("/kb/bases/\(kbId)/sync", method: "POST", body: body)
        } catch {
            logger.error("incrementalSync failed: \(error.localizedDescription)")
            return nil
        }
    }
}

enum RAGAPIClientError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .invalidResponse: return "无效的响应"
        case .httpError(let s, let m): return "HTTP \(s): \(m)"
        }
    }
}
