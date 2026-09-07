import Foundation
import os.log

// ARCH-1 Phase 4 (audit-product-0907 P2-2): DocRAG 行为迁入。DocBridge 留 1 行 stub 转发 (保外部签名:
//   ragEnhancedQuery/reindexPage/reindexAll/fetchChunks/graphSearch/buildRAGIndex/fetchRAGStatus/
//   clearRAGIndex/embedRAGContent call site 0 改)。@Published (chunks) 现属 DocRAGState (fetchChunks
//   直写 self.chunks)。RAGResponse nested struct 留 DocBridge (类型非状态, 服务引用 DocBridge.RAGResponse)。
//   HTTP 经 bridge?.get/post/delete; 错误经 bridge?.handleError。

private let docRAGLog = Logger(subsystem: "com.fusion.studio", category: "DocRAGService")

extension DocRAGState {

    func ragEnhancedQuery(query: String, topK: Int = 5, completion: @escaping (Result<DocBridge.RAGResponse, Error>) -> Void) {
        bridge?.post("/api/rag/enhanced-query", body: ["query": query, "top_k": topK]) { result in
            completion(result)
        }
    }

    func reindexPage(pageId: String) {
        struct ReindexResp: Decodable { var reindexed: Bool? }
        bridge?.post("/api/rag/reindex/\(pageId)") { [weak self] (result: Result<ReindexResp, Error>) in
            switch result {
            case .success:
                docRAGLog.info("Page \(pageId) reindexed")
            case .failure(let error):
                self?.bridge?.handleError(error, context: "reindex")
            }
        }
    }

    func reindexAll(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        bridge?.post("/api/rag/reindex-all", body: nil, completion: completion)
    }

    func fetchChunks(pageId: String, completion: @escaping (Result<[DocRAGChunk], Error>) -> Void) {
        bridge?.get("/api/rag/chunks/\(pageId)") { [weak self] (result: Result<[DocRAGChunk], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.chunks = Array(list.suffix(500)) }
                completion(.success(list))
            case .failure(let error):
                self?.bridge?.handleError(error, context: "fetchChunks")
                completion(.failure(error))
            }
        }
    }

    func graphSearch(query: String, completion: @escaping (Result<DocGraph, Error>) -> Void) {
        bridge?.post("/api/rag/graph/search", body: ["query": query], completion: completion)
    }

    func buildRAGIndex(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docRAGLog.info("buildRAGIndex")
        bridge?.post("/api/rag/index", body: nil, completion: completion)
    }

    func fetchRAGStatus(completion: @escaping (Result<[String: String], Error>) -> Void) {
        docRAGLog.info("fetchRAGStatus")
        bridge?.get("/api/rag/status", completion: completion)
    }

    func clearRAGIndex(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docRAGLog.info("clearRAGIndex")
        bridge?.delete("/api/rag/index", completion: completion)
    }

    func embedRAGContent(content: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docRAGLog.info("embedRAGContent")
        bridge?.post("/api/rag/embed", body: ["content": content], completion: completion)
    }
}

extension DocBridge {

    func ragEnhancedQuery(query: String, topK: Int = 5, completion: @escaping (Result<RAGResponse, Error>) -> Void) {
        ragState.ragEnhancedQuery(query: query, topK: topK, completion: completion)
    }

    func reindexPage(pageId: String) { ragState.reindexPage(pageId: pageId) }

    func reindexAll(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        ragState.reindexAll(completion: completion)
    }

    func fetchChunks(pageId: String, completion: @escaping (Result<[DocRAGChunk], Error>) -> Void) {
        ragState.fetchChunks(pageId: pageId, completion: completion)
    }

    func graphSearch(query: String, completion: @escaping (Result<DocGraph, Error>) -> Void) {
        ragState.graphSearch(query: query, completion: completion)
    }

    func buildRAGIndex(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        ragState.buildRAGIndex(completion: completion)
    }

    func fetchRAGStatus(completion: @escaping (Result<[String: String], Error>) -> Void) {
        ragState.fetchRAGStatus(completion: completion)
    }

    func clearRAGIndex(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        ragState.clearRAGIndex(completion: completion)
    }

    func embedRAGContent(content: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        ragState.embedRAGContent(content: content, completion: completion)
    }
}
