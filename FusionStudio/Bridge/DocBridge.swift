// Callers: DocView, DocSidebar, DocEditorView, DocAICopilotView, DocGraphView, DocVersionView, DocOfficeView, DocWorkflowView, DocTemplateView.
// Affected API: REST localhost:11449 (fusion-doc server — 82 routes across page/book/chapter/tag/graph/workflow/template/office/copilot/rag controllers).
// Data schemas: DocPage/DocBook/DocChapter/DocTag/DocGraphNode/DocGraphEdge/DocWorkflow/DocTemplate/DocVersion/DocDiffLine/DocOfficeStatus aligned with fusion-doc controller responses.
// User instruction: "按照prd文档和fusion-doc配合打造有竞争力的领先的产品"

import Foundation
import Combine
import os.log

private let docBridgeLog = Logger(subsystem: "com.fusion.studio", category: "DocBridge")

// MARK: - Data Models

struct DocPage: Codable, Identifiable, Hashable {
    let id: String
    var workspace_id: String?
    var book_id: String?
    var chapter_id: String?
    var title: String
    var slug: String?
    var content: String
    var markdown: String?
    var editor_mode: String?
    var parent_id: String?
    var sort_order: Int?
    var is_published: Int?
    var created_at: String?
    var updated_at: String?
    var tags: [DocTag]?
    var links: [DocPageRef]?
    var backlinks: [DocPageRef]?
    var files: [DocFileRef]?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocPage, rhs: DocPage) -> Bool { lhs.id == rhs.id }
}

struct DocPageRef: Codable, Hashable {
    let id: String
    let title: String
}

struct DocBook: Codable, Identifiable, Hashable {
    let id: String
    var workspace_id: String?
    var title: String
    var slug: String?
    var description: String?
    var cover: String?
    var sort_order: Int?
    var created_at: String?
    var updated_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocBook, rhs: DocBook) -> Bool { lhs.id == rhs.id }
}

struct DocChapter: Codable, Identifiable, Hashable {
    let id: String
    var book_id: String?
    var title: String
    var slug: String?
    var description: String?
    var sort_order: Int?
    var created_at: String?
    var updated_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocChapter, rhs: DocChapter) -> Bool { lhs.id == rhs.id }
}

struct DocTag: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var slug: String?
    var color: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocTag, rhs: DocTag) -> Bool { lhs.id == rhs.id }
}

struct DocFileRef: Codable, Hashable {
    let id: String
    var name: String?
    var mime: String?
    var size: Int?
    var created_at: String?
}

struct DocGraphNode: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var type: String?
    var tags: [String]?
    var linkCount: Int?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocGraphNode, rhs: DocGraphNode) -> Bool { lhs.id == rhs.id }
}

struct DocGraphEdge: Codable, Hashable {
    let source: String
    let target: String
    var link_type: String?
}

struct DocGraph: Codable {
    var nodes: [DocGraphNode]
    var edges: [DocGraphEdge]
}

struct DocVersion: Codable, Identifiable, Hashable {
    let id: String
    var page_id: String?
    var title: String?
    var content: String?
    var version: Int?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocVersion, rhs: DocVersion) -> Bool { lhs.id == rhs.id }
}

struct DocDiffLine: Codable, Hashable {
    var type: String
    var line: String
}

struct DocDiffResult: Codable {
    var page_id: String?
    var v1: Int?
    var v2: Int?
    var diff: [DocDiffLine]?
}

struct DocWorkflow: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var yaml_def: String?
    var status: String?
    var last_run: String?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocWorkflow, rhs: DocWorkflow) -> Bool { lhs.id == rhs.id }
}

struct DocWorkflowRun: Codable, Identifiable {
    let id: String
    var workflow_id: String?
    var status: String?
    var input: String?
    var output: String?
    var steps: String?
    var started_at: String?
    var completed_at: String?
}

struct DocTemplate: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var type: String?
    var content: String?
    var variables: String?
    var category: String?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocTemplate, rhs: DocTemplate) -> Bool { lhs.id == rhs.id }
}

struct DocOfficeStatus: Codable {
    var available: Bool?
    var version: String?
    var formats: [String]?
}

struct DocRAGChunk: Codable, Identifiable {
    let id: String
    var page_id: String?
    var chunk_index: Int?
    var chunk_text: String?
    var chunk_type: String?
}

// MARK: - DocBridge

class DocBridge: ObservableObject {
    @Published var books: [DocBook] = []
    @Published var chapters: [DocChapter] = []
    @Published var pages: [DocPage] = []
    @Published var currentPage: DocPage?
    @Published var tags: [DocTag] = []
    @Published var graph: DocGraph?
    @Published var versions: [DocVersion] = []
    @Published var workflows: [DocWorkflow] = []
    @Published var templates: [DocTemplate] = []
    @Published var officeStatus: DocOfficeStatus?
    @Published var isConnected: Bool = false
    @Published var lastError: String?

    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = "http://127.0.0.1:11449") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic HTTP

    private func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        session.dataTask(with: url) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "DocBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]? = nil, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "DocBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func put<T: Decodable>(_ path: String, body: [String: Any], completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "DocBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func delete<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "DocBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func handleError(_ error: Error, context: String) {
        docBridgeLog.error("[\(context)] \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.lastError = "\(context): \(error.localizedDescription)"
            if context == "health" { self.isConnected = false }
        }
    }

    // MARK: - Health

    func checkHealth() {
        struct HealthResp: Decodable { var status: String? }
        get("/api/health") { [weak self] (result: Result<HealthResp, Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.isConnected = true
                    self?.lastError = nil
                }
            case .failure(let err):
                self?.handleError(err, context: "health")
            }
        }
    }

    // MARK: - Books

    func fetchBooks() {
        get("/api/books") { [weak self] (result: Result<[DocBook], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.books = list }
            case .failure(let err):
                self?.handleError(err, context: "books")
            }
        }
    }

    func createBook(title: String, description: String? = nil) {
        var body: [String: Any] = ["title": title]
        if let desc = description { body["description"] = desc }
        post("/api/books", body: body) { [weak self] (result: Result<DocBook, Error>) in
            switch result {
            case .success(let book):
                DispatchQueue.main.async { self?.books.append(book) }
            case .failure(let err):
                self?.handleError(err, context: "createBook")
            }
        }
    }

    // MARK: - Chapters

    func fetchChapters(bookId: String) {
        get("/api/chapters?bookId=\(bookId)") { [weak self] (result: Result<[DocChapter], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.chapters = list }
            case .failure(let err):
                self?.handleError(err, context: "chapters")
            }
        }
    }

    func createChapter(bookId: String, title: String) {
        post("/api/chapters", body: ["book_id": bookId, "title": title]) { [weak self] (result: Result<DocChapter, Error>) in
            switch result {
            case .success(let ch):
                DispatchQueue.main.async { self?.chapters.append(ch) }
            case .failure(let err):
                self?.handleError(err, context: "createChapter")
            }
        }
    }

    // MARK: - Pages

    func fetchPages(bookId: String? = nil, chapterId: String? = nil) {
        var path = "/api/pages"
        var params: [String] = []
        if let bid = bookId { params.append("bookId=\(bid)") }
        if let cid = chapterId { params.append("chapterId=\(cid)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }

        get(path) { [weak self] (result: Result<[DocPage], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.pages = list }
            case .failure(let err):
                self?.handleError(err, context: "pages")
            }
        }
    }

    func fetchPage(id: String) {
        get("/api/pages/\(id)") { [weak self] (result: Result<DocPage, Error>) in
            switch result {
            case .success(let page):
                DispatchQueue.main.async { self?.currentPage = page }
            case .failure(let err):
                self?.handleError(err, context: "page")
            }
        }
    }

    func createPage(title: String, bookId: String? = nil, chapterId: String? = nil, content: String = "") {
        var body: [String: Any] = ["title": title, "content": content]
        if let bid = bookId { body["book_id"] = bid }
        if let cid = chapterId { body["chapter_id"] = cid }
        post("/api/pages", body: body) { [weak self] (result: Result<DocPage, Error>) in
            switch result {
            case .success(let page):
                DispatchQueue.main.async { self?.pages.append(page) }
            case .failure(let err):
                self?.handleError(err, context: "createPage")
            }
        }
    }

    func updatePage(id: String, title: String, content: String, markdown: String? = nil) {
        var body: [String: Any] = ["title": title, "content": content]
        if let md = markdown { body["markdown"] = md }
        put("/api/pages/\(id)", body: body) { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    if let idx = self?.pages.firstIndex(where: { $0.id == id }) {
                        self?.pages[idx].title = title
                        self?.pages[idx].content = content
                    }
                    if self?.currentPage?.id == id {
                        self?.currentPage?.title = title
                        self?.currentPage?.content = content
                    }
                }
            case .failure(let err):
                self?.handleError(err, context: "updatePage")
            }
        }
    }

    func deletePage(id: String) {
        struct DeleteResp: Decodable { var deleted: Bool? }
        delete("/api/pages/\(id)") { [weak self] (result: Result<DeleteResp, Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.pages.removeAll { $0.id == id }
                    if self?.currentPage?.id == id { self?.currentPage = nil }
                }
            case .failure(let err):
                self?.handleError(err, context: "deletePage")
            }
        }
    }

    // MARK: - Tags

    func fetchTags() {
        get("/api/tags") { [weak self] (result: Result<[DocTag], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.tags = list }
            case .failure(let err):
                self?.handleError(err, context: "tags")
            }
        }
    }

    // MARK: - Graph

    func fetchGraph() {
        get("/api/graph") { [weak self] (result: Result<DocGraph, Error>) in
            switch result {
            case .success(let g):
                DispatchQueue.main.async { self?.graph = g }
            case .failure(let err):
                self?.handleError(err, context: "graph")
            }
        }
    }

    // MARK: - Versions

    func fetchVersions(pageId: String) {
        get("/api/pages/\(pageId)/versions") { [weak self] (result: Result<[DocVersion], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.versions = list }
            case .failure(let err):
                self?.handleError(err, context: "versions")
            }
        }
    }

    func createVersion(pageId: String, title: String, content: String) {
        post("/api/pages/\(pageId)/versions", body: ["title": title, "content": content]) { [weak self] (result: Result<DocVersion, Error>) in
            switch result {
            case .success(let v):
                DispatchQueue.main.async { self?.versions.append(v) }
            case .failure(let err):
                self?.handleError(err, context: "createVersion")
            }
        }
    }

    func fetchDiff(pageId: String, v1: Int, v2: Int, completion: @escaping (Result<DocDiffResult, Error>) -> Void) {
        get("/api/pages/\(pageId)/diff?v1=\(v1)&v2=\(v2)") { result in
            completion(result)
        }
    }

    func restoreVersion(pageId: String, versionId: String) {
        struct RestoreResp: Decodable { var restored: Bool? }
        post("/api/pages/\(pageId)/versions/\(versionId)/restore") { [weak self] (result: Result<RestoreResp, Error>) in
            switch result {
            case .success:
                self?.fetchPage(id: pageId)
            case .failure(let err):
                self?.handleError(err, context: "restoreVersion")
            }
        }
    }

    // MARK: - Workflows

    func fetchWorkflows() {
        get("/api/workflows") { [weak self] (result: Result<[DocWorkflow], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.workflows = list }
            case .failure(let err):
                self?.handleError(err, context: "workflows")
            }
        }
    }

    func runWorkflow(id: String, input: [String: Any]? = nil) {
        post("/api/workflows/\(id)/run", body: input) { [weak self] (result: Result<DocWorkflowRun, Error>) in
            switch result {
            case .success:
                docBridgeLog.info("Workflow \(id) started")
            case .failure(let err):
                self?.handleError(err, context: "runWorkflow")
            }
        }
    }

    func fetchWorkflowRuns(id: String, completion: @escaping (Result<[DocWorkflowRun], Error>) -> Void) {
        get("/api/workflows/\(id)/runs") { result in
            completion(result)
        }
    }

    // MARK: - Templates

    func fetchTemplates() {
        get("/api/templates") { [weak self] (result: Result<[DocTemplate], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.templates = list }
            case .failure(let err):
                self?.handleError(err, context: "templates")
            }
        }
    }

    func instantiateTemplate(id: String, variables: [String: Any]) {
        post("/api/templates/\(id)/instantiate", body: ["variables": variables]) { [weak self] (result: Result<DocPage, Error>) in
            switch result {
            case .success(let page):
                DispatchQueue.main.async { self?.pages.append(page) }
            case .failure(let err):
                self?.handleError(err, context: "instantiateTemplate")
            }
        }
    }

    // MARK: - Office

    func checkOfficeStatus() {
        get("/api/office/status") { [weak self] (result: Result<DocOfficeStatus, Error>) in
            switch result {
            case .success(let status):
                DispatchQueue.main.async { self?.officeStatus = status }
            case .failure(let err):
                self?.handleError(err, context: "officeStatus")
            }
        }
    }

    func createOfficeDocument(format: String, name: String) {
        struct OfficeCreateResp: Decodable { var id: String?; var path: String? }
        post("/api/office/create", body: ["format": format, "name": name]) { [weak self] (result: Result<OfficeCreateResp, Error>) in
            switch result {
            case .success:
                docBridgeLog.info("Office doc created: \(name).\(format)")
            case .failure(let err):
                self?.handleError(err, context: "createOffice")
            }
        }
    }

    func importOfficeDocument(filePath: String, bookId: String? = nil) {
        var body: [String: Any] = ["file_path": filePath]
        if let bid = bookId { body["book_id"] = bid }
        post("/api/office/import", body: body) { [weak self] (result: Result<DocPage, Error>) in
            switch result {
            case .success(let page):
                DispatchQueue.main.async { self?.pages.append(page) }
            case .failure(let err):
                self?.handleError(err, context: "importOffice")
            }
        }
    }

    // MARK: - AI Copilot URLs

    func copilotCompleteURL() -> URL? { URL(string: "\(baseURL)/api/copilot/complete") }
    func copilotRewriteURL() -> URL? { URL(string: "\(baseURL)/api/copilot/rewrite") }
    func copilotTranslateURL() -> URL? { URL(string: "\(baseURL)/api/copilot/translate") }
    func copilotSummarizeURL() -> URL? { URL(string: "\(baseURL)/api/copilot/summarize") }
    func copilotExpandURL() -> URL? { URL(string: "\(baseURL)/api/copilot/expand") }
    func copilotCommandURL() -> URL? { URL(string: "\(baseURL)/api/copilot/command") }
    func copilotContextURL(pageId: String) -> URL? { URL(string: "\(baseURL)/api/copilot/context/\(pageId)") }

    func buildCopilotRequest(url: URL, body: [String: Any]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - RAG

    struct RAGResponse: Decodable {
        var answer: String?
        var chunks: [RAGChunkItem]?
        struct RAGChunkItem: Decodable {
            var chunk_text: String?
            var page_id: String?
        }
    }

    func ragEnhancedQuery(query: String, topK: Int = 5, completion: @escaping (Result<RAGResponse, Error>) -> Void) {
        post("/api/rag/enhanced-query", body: ["query": query, "top_k": topK]) { result in
            completion(result)
        }
    }

    func reindexPage(pageId: String) {
        struct ReindexResp: Decodable { var reindexed: Bool? }
        post("/api/rag/reindex/\(pageId)") { [weak self] (result: Result<ReindexResp, Error>) in
            switch result {
            case .success:
                docBridgeLog.info("Page \(pageId) reindexed")
            case .failure(let err):
                self?.handleError(err, context: "reindex")
            }
        }
    }

    // MARK: - Links

    func addPageLink(sourceId: String, targetId: String, linkType: String = "reference") {
        struct LinkResp: Decodable { var id: String? }
        post("/api/pages/\(sourceId)/links", body: ["target_page_id": targetId, "link_type": linkType]) { [weak self] (result: Result<LinkResp, Error>) in
            switch result {
            case .success:
                docBridgeLog.info("Link added: \(sourceId) -> \(targetId)")
            case .failure(let err):
                self?.handleError(err, context: "addLink")
            }
        }
    }
}
