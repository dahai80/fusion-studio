// Callers: KBListView, KBChatView, SearchDebugView, KBSettingsView
// API: fusion-rag HTTP REST at /kb/* endpoints
// schema: JSON request/response matching routes.py endpoints
// user instruction: "完成所有待办任务"

import Foundation
import Combine
import os

// MARK: - Data Models

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
}

// MARK: - RAG API Client

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

    // MARK: - Generic HTTP

    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> [String: Any] {
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
            // might be single object wrapping array
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

    func createBase(name: String, description: String = "", chunkStrategy: String = "semantic", embeddingModel: String = "BGE-M3") async -> KBInfo? {
        do {
            let result = try await request("/kb/bases", method: "POST", body: [
                "name": name,
                "description": description,
                "chunk_strategy": chunkStrategy,
                "embedding_model": embeddingModel,
            ])
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
                vectors: result["vectors"] as? Int ?? 0
            )
        } catch {
            logger.error("getStats failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Documents

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

    // MARK: - Search

    func search(kbId: String, query: String, topK: Int = 5, threshold: Double = 0.3, rewriteMode: String? = nil) async -> [KBSearchResult] {
        do {
            var body: [String: Any] = [
                "query": query,
                "top_k": topK,
                "threshold": threshold,
            ]
            if let mode = rewriteMode {
                body["rewrite_mode"] = mode
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

    func ask(kbId: String, question: String, topK: Int = 5, rewriteMode: String? = nil, history: [[String: String]]? = nil) async -> KBAskResult? {
        do {
            var body: [String: Any] = [
                "question": question,
                "top_k": topK,
            ]
            if let mode = rewriteMode {
                body["rewrite_mode"] = mode
            }
            if let hist = history {
                body["history"] = hist
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
}

// MARK: - Errors

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
