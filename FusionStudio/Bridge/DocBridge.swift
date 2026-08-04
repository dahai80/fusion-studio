// Callers: DocView, DocSidebar, DocEditorArea, DocAICopilotView, DocGraphView, DocVersionView, DocOfficeView, DocWorkflowView, DocTemplateView, DocSearchView, DocCommentsView, DocFavoritesView, DocFilesPanel, DocRAGPanel, DocActivityView.
// Affected API: REST localhost:11449 (fusion-doc server — 82 routes across page/book/chapter/tag/graph/workflow/template/office/copilot/rag/search/comment/favorite/activity/file controllers).
// Data schemas: DocPage/DocBook/DocChapter/DocTag/DocGraphNode/DocGraphEdge/DocWorkflow/DocTemplate/DocVersion/DocDiffLine/DocOfficeStatus/DocSearchResult/DocComment/DocFavorite/DocActivity/DocFileUpload/DocWorkflowState aligned with fusion-doc controller responses.
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

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

struct DocSearchResult: Codable, Identifiable {
    let id: String
    var title: String?
    var content: String?
    var score: Double?
    var type: String?
    var book_id: String?
    var tags: [DocTag]?
}

struct DocComment: Codable, Identifiable, Hashable {
    let id: String
    var page_id: String?
    var content: String?
    var parent_id: String?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocComment, rhs: DocComment) -> Bool { lhs.id == rhs.id }
}

struct DocFavorite: Codable, Identifiable, Hashable {
    let id: String
    var page_id: String?
    var title: String?
    var created_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocFavorite, rhs: DocFavorite) -> Bool { lhs.id == rhs.id }
}

struct DocActivity: Codable, Identifiable {
    let id: String
    var event: String?
    var data: String?
    var created_at: String?
}

struct DocFileUpload: Codable, Identifiable {
    let id: String
    var name: String?
    var mime: String?
    var size: Int?
    var created_at: String?
}

struct DocWorkflowState: Codable {
    var page_id: String?
    var workflow_id: String?
    var current_state: String?
    var transitions: [DocWorkflowTransition]?
}

struct DocWorkflowTransition: Codable {
    var name: String?
    var target_state: String?
}

struct DocAuthSetup: Codable {
    var username: String
    var password: String
}

struct DocAuthLogin: Codable {
    var username: String
    var password: String
}

struct DocAuthResponse: Codable {
    var token: String?
    var expiresIn: Int?
    var message: String?
}

struct DocWorkspace: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var created_at: String?
    var updated_at: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DocWorkspace, rhs: DocWorkspace) -> Bool { lhs.id == rhs.id }
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
    @Published var searchResults: [DocSearchResult] = []
    @Published var comments: [DocComment] = []
    @Published var favorites: [DocFavorite] = []
    @Published var activities: [DocActivity] = []
    @Published var files: [DocFileUpload] = []
    @Published var chunks: [DocRAGChunk] = []
    @Published var workspaces: [DocWorkspace] = []
    @Published var currentWorkspace: DocWorkspace?
    @Published var isAuthenticated: Bool = false
    @Published var authError: String?

    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "fusion_doc_auth_token") }
        set {
            if let token = newValue {
                UserDefaults.standard.set(token, forKey: "fusion_doc_auth_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "fusion_doc_auth_token")
            }
        }
    }

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
        var request = URLRequest(url: url)
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
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

    private func post<T: Decodable>(_ path: String, body: [String: Any]? = nil, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
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
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
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
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
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

    // MARK: - Search

    func searchPages(query: String, completion: @escaping (Result<[DocSearchResult], Error>) -> Void) {
        get("/api/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)") { result in
            completion(result)
        }
    }

    func searchAdvanced(query: String, tag: String? = nil, type: String? = nil, sort: String? = nil, order: String? = nil, completion: @escaping (Result<[DocSearchResult], Error>) -> Void) {
        var params: [String] = ["q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"]
        if let tag = tag { params.append("tag=\(tag)") }
        if let type = type { params.append("type=\(type)") }
        if let sort = sort { params.append("sort=\(sort)") }
        if let order = order { params.append("order=\(order)") }
        get("/api/search/advanced?\(params.joined(separator: "&"))") { result in
            completion(result)
        }
    }

    // MARK: - Copilot Actions (non-streaming)

    func copilotRewrite(text: String, instruction: String? = nil, completion: @escaping (Result<[String: String], Error>) -> Void) {
        var body: [String: Any] = ["text": text]
        if let inst = instruction { body["instruction"] = inst }
        post("/api/copilot/rewrite", body: body, completion: completion)
    }

    func copilotTranslate(text: String, targetLang: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        post("/api/copilot/translate", body: ["text": text, "target_lang": targetLang], completion: completion)
    }

    func copilotSummarize(text: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        post("/api/copilot/summarize", body: ["text": text], completion: completion)
    }

    func copilotExpand(text: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        post("/api/copilot/expand", body: ["text": text], completion: completion)
    }

    func fetchCopilotContext(pageId: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        get("/api/copilot/context/\(pageId)", completion: completion)
    }

    // MARK: - Office Extended

    func exportOffice(pageId: String, format: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        post("/api/office/export", body: ["page_id": pageId, "format": format], completion: completion)
    }

    func previewOffice(id: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        get("/api/office/preview/\(id)", completion: completion)
    }

    func mergeOffice(template: String, data: [String: Any], completion: @escaping (Result<[String: String], Error>) -> Void) {
        var body = data
        body["template"] = template
        post("/api/office/merge", body: body, completion: completion)
    }

    func importOfficeDir(dirPath: String, bookId: String? = nil, completion: @escaping (Result<[DocPage], Error>) -> Void) {
        var body: [String: Any] = ["dir_path": dirPath]
        if let bid = bookId { body["book_id"] = bid }
        post("/api/office/import-dir", body: body, completion: completion)
    }

    func executeOfficeCommand(file: String, command: String, args: [String: Any]? = nil, completion: @escaping (Result<[String: String], Error>) -> Void) {
        var body: [String: Any] = ["file": file, "command": command]
        if let args = args { body["args"] = args }
        post("/api/office/command", body: body, completion: completion)
    }

    // MARK: - Template CRUD

    func createTemplate(name: String, type: String? = nil, content: String? = nil, category: String? = nil, completion: @escaping (Result<DocTemplate, Error>) -> Void) {
        var body: [String: Any] = ["name": name]
        if let t = type { body["type"] = t }
        if let c = content { body["content"] = c }
        if let cat = category { body["category"] = cat }
        post("/api/templates", body: body) { [weak self] (result: Result<DocTemplate, Error>) in
            switch result {
            case .success(let tmpl):
                DispatchQueue.main.async { self?.templates.append(tmpl) }
                completion(.success(tmpl))
            case .failure(let err):
                self?.handleError(err, context: "createTemplate")
                completion(.failure(err))
            }
        }
    }

    func updateTemplate(id: String, name: String? = nil, content: String? = nil, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        var body: [String: Any] = [:]
        if let n = name { body["name"] = n }
        if let c = content { body["content"] = c }
        put("/api/templates/\(id)", body: body, completion: completion)
    }

    func deleteTemplate(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        delete("/api/templates/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.templates.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let err):
                self?.handleError(err, context: "deleteTemplate")
                completion(.failure(err))
            }
        }
    }

    func fetchTemplateVariables(id: String, completion: @escaping (Result<[String: [String]], Error>) -> Void) {
        get("/api/templates/\(id)/variables", completion: completion)
    }

    // MARK: - Workflow CRUD

    func createWorkflow(name: String, description: String? = nil, yamlDef: String? = nil, completion: @escaping (Result<DocWorkflow, Error>) -> Void) {
        var body: [String: Any] = ["name": name]
        if let d = description { body["description"] = d }
        if let y = yamlDef { body["yaml_def"] = y }
        post("/api/workflows", body: body) { [weak self] (result: Result<DocWorkflow, Error>) in
            switch result {
            case .success(let wf):
                DispatchQueue.main.async { self?.workflows.append(wf) }
                completion(.success(wf))
            case .failure(let err):
                self?.handleError(err, context: "createWorkflow")
                completion(.failure(err))
            }
        }
    }

    func deleteWorkflow(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        delete("/api/workflows/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.workflows.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let err):
                self?.handleError(err, context: "deleteWorkflow")
                completion(.failure(err))
            }
        }
    }

    func fetchWorkflowDetail(id: String, completion: @escaping (Result<DocWorkflow, Error>) -> Void) {
        get("/api/workflows/\(id)", completion: completion)
    }

    func seedWorkflows(completion: @escaping (Result<[DocWorkflow], Error>) -> Void) {
        post("/api/workflows/seed", body: nil) { [weak self] (result: Result<[DocWorkflow], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.workflows = list }
                completion(.success(list))
            case .failure(let err):
                self?.handleError(err, context: "seedWorkflows")
                completion(.failure(err))
            }
        }
    }

    func fetchPageWorkflowStatus(pageId: String, completion: @escaping (Result<DocWorkflowState, Error>) -> Void) {
        get("/api/pages/\(pageId)/workflow-status", completion: completion)
    }

    func fetchPageTransitions(pageId: String, completion: @escaping (Result<[DocWorkflowTransition], Error>) -> Void) {
        get("/api/pages/\(pageId)/transitions", completion: completion)
    }

    func executeTransition(pageId: String, transition: String, completion: @escaping (Result<DocWorkflowState, Error>) -> Void) {
        post("/api/pages/\(pageId)/transitions", body: ["transition": transition], completion: completion)
    }

    // MARK: - Files

    func fetchFiles(pageId: String, completion: @escaping (Result<[DocFileUpload], Error>) -> Void) {
        get("/api/pages/\(pageId)/files") { [weak self] (result: Result<[DocFileUpload], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.files = list }
                completion(.success(list))
            case .failure(let err):
                self?.handleError(err, context: "fetchFiles")
                completion(.failure(err))
            }
        }
    }

    func uploadFile(pageId: String, name: String, mime: String, content: String, completion: @escaping (Result<DocFileUpload, Error>) -> Void) {
        post("/api/pages/\(pageId)/files", body: ["name": name, "mime": mime, "content": content]) { [weak self] (result: Result<DocFileUpload, Error>) in
            switch result {
            case .success(let file):
                DispatchQueue.main.async { self?.files.append(file) }
                completion(.success(file))
            case .failure(let err):
                self?.handleError(err, context: "uploadFile")
                completion(.failure(err))
            }
        }
    }

    func deleteFile(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        delete("/api/files/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.files.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let err):
                self?.handleError(err, context: "deleteFile")
                completion(.failure(err))
            }
        }
    }

    // MARK: - Comments

    func fetchComments(pageId: String, completion: @escaping (Result<[DocComment], Error>) -> Void) {
        get("/api/pages/\(pageId)/comments") { [weak self] (result: Result<[DocComment], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.comments = list }
                completion(.success(list))
            case .failure(let err):
                self?.handleError(err, context: "fetchComments")
                completion(.failure(err))
            }
        }
    }

    func createComment(pageId: String, content: String, parentId: String? = nil, completion: @escaping (Result<DocComment, Error>) -> Void) {
        var body: [String: Any] = ["content": content]
        if let pid = parentId { body["parent_id"] = pid }
        post("/api/pages/\(pageId)/comments", body: body) { [weak self] (result: Result<DocComment, Error>) in
            switch result {
            case .success(let comment):
                DispatchQueue.main.async { self?.comments.append(comment) }
                completion(.success(comment))
            case .failure(let err):
                self?.handleError(err, context: "createComment")
                completion(.failure(err))
            }
        }
    }

    func deleteComment(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        delete("/api/comments/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.comments.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let err):
                self?.handleError(err, context: "deleteComment")
                completion(.failure(err))
            }
        }
    }

    // MARK: - Favorites

    func fetchFavorites(completion: @escaping (Result<[DocFavorite], Error>) -> Void) {
        get("/api/favorites") { [weak self] (result: Result<[DocFavorite], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.favorites = list }
                completion(.success(list))
            case .failure(let err):
                self?.handleError(err, context: "fetchFavorites")
                completion(.failure(err))
            }
        }
    }

    func addFavorite(pageId: String, completion: @escaping (Result<DocFavorite, Error>) -> Void) {
        post("/api/favorites", body: ["page_id": pageId]) { [weak self] (result: Result<DocFavorite, Error>) in
            switch result {
            case .success(let fav):
                DispatchQueue.main.async { self?.favorites.append(fav) }
                completion(.success(fav))
            case .failure(let err):
                self?.handleError(err, context: "addFavorite")
                completion(.failure(err))
            }
        }
    }

    func removeFavorite(pageId: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        delete("/api/favorites/\(pageId)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.favorites.removeAll { $0.page_id == pageId } }
                completion(.success(["deleted": true]))
            case .failure(let err):
                self?.handleError(err, context: "removeFavorite")
                completion(.failure(err))
            }
        }
    }

    // MARK: - Activity

    func fetchActivity(limit: Int = 50, completion: @escaping (Result<[DocActivity], Error>) -> Void) {
        get("/api/activity?limit=\(limit)") { [weak self] (result: Result<[DocActivity], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.activities = list }
                completion(.success(list))
            case .failure(let err):
                self?.handleError(err, context: "fetchActivity")
                completion(.failure(err))
            }
        }
    }

    func recordActivity(event: String, data: [String: Any]? = nil, completion: @escaping (Result<DocActivity, Error>) -> Void) {
        var body: [String: Any] = ["event": event]
        if let d = data { body["data"] = d }
        post("/api/activity", body: body, completion: completion)
    }

    // MARK: - RAG Extended

    func reindexAll(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        post("/api/rag/reindex-all", body: nil, completion: completion)
    }

    func fetchChunks(pageId: String, completion: @escaping (Result<[DocRAGChunk], Error>) -> Void) {
        get("/api/rag/chunks/\(pageId)") { [weak self] (result: Result<[DocRAGChunk], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.chunks = list }
                completion(.success(list))
            case .failure(let err):
                self?.handleError(err, context: "fetchChunks")
                completion(.failure(err))
            }
        }
    }

    func graphSearch(query: String, completion: @escaping (Result<DocGraph, Error>) -> Void) {
        post("/api/rag/graph/search", body: ["query": query], completion: completion)
    }

    func fetchGraphNode(id: String, completion: @escaping (Result<DocGraphNode, Error>) -> Void) {
        get("/api/graph/\(id)", completion: completion)
    }

    // MARK: - Auth

    func authSetup(username: String, password: String, completion: @escaping (Result<DocAuthResponse, Error>) -> Void) {
        docBridgeLog.info("authSetup: username=\(username)")
        post("/api/auth/setup", body: ["username": username, "password": password]) { [weak self] (result: Result<DocAuthResponse, Error>) in
            switch result {
            case .success(let resp):
                if let token = resp.token {
                    self?.authToken = token
                    DispatchQueue.main.async { self?.isAuthenticated = true; self?.authError = nil }
                    docBridgeLog.info("authSetup success, token saved")
                }
                completion(.success(resp))
            case .failure(let err):
                DispatchQueue.main.async { self?.authError = err.localizedDescription }
                docBridgeLog.error("authSetup failed: \(err.localizedDescription)")
                completion(.failure(err))
            }
        }
    }

    func authLogin(username: String, password: String, completion: @escaping (Result<DocAuthResponse, Error>) -> Void) {
        docBridgeLog.info("authLogin: username=\(username)")
        post("/api/auth/login", body: ["username": username, "password": password]) { [weak self] (result: Result<DocAuthResponse, Error>) in
            switch result {
            case .success(let resp):
                if let token = resp.token {
                    self?.authToken = token
                    DispatchQueue.main.async { self?.isAuthenticated = true; self?.authError = nil }
                    docBridgeLog.info("authLogin success, token saved")
                }
                completion(.success(resp))
            case .failure(let err):
                DispatchQueue.main.async { self?.authError = err.localizedDescription }
                docBridgeLog.error("authLogin failed: \(err.localizedDescription)")
                completion(.failure(err))
            }
        }
    }

    func authRefresh(completion: @escaping (Result<DocAuthResponse, Error>) -> Void) {
        docBridgeLog.info("authRefresh")
        post("/api/auth/refresh", body: nil) { [weak self] (result: Result<DocAuthResponse, Error>) in
            switch result {
            case .success(let resp):
                if let token = resp.token {
                    self?.authToken = token
                    DispatchQueue.main.async { self?.isAuthenticated = true }
                    docBridgeLog.info("authRefresh success")
                }
                completion(.success(resp))
            case .failure(let err):
                docBridgeLog.error("authRefresh failed: \(err.localizedDescription)")
                completion(.failure(err))
            }
        }
    }

    func authLogout() {
        docBridgeLog.info("authLogout")
        authToken = nil
        DispatchQueue.main.async { self.isAuthenticated = false }
    }

    func restoreAuth() {
        if authToken != nil {
            docBridgeLog.info("restoreAuth: token found, marking authenticated")
            isAuthenticated = true
        }
    }

    // MARK: - Workspace CRUD

    func fetchWorkspaces(completion: @escaping (Result<[DocWorkspace], Error>) -> Void) {
        docBridgeLog.info("fetchWorkspaces")
        get("/api/workspaces") { [weak self] (result: Result<[DocWorkspace], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.workspaces = list }
                completion(.success(list))
            case .failure(let err):
                self?.handleError(err, context: "fetchWorkspaces")
                completion(.failure(err))
            }
        }
    }

    func createWorkspace(name: String, description: String? = nil, completion: @escaping (Result<DocWorkspace, Error>) -> Void) {
        docBridgeLog.info("createWorkspace: name=\(name)")
        var body: [String: Any] = ["name": name]
        if let desc = description { body["description"] = desc }
        post("/api/workspaces", body: body) { [weak self] (result: Result<DocWorkspace, Error>) in
            switch result {
            case .success(let ws):
                DispatchQueue.main.async { self?.workspaces.append(ws); self?.currentWorkspace = ws }
                docBridgeLog.info("createWorkspace success: \(ws.id)")
                completion(.success(ws))
            case .failure(let err):
                self?.handleError(err, context: "createWorkspace")
                completion(.failure(err))
            }
        }
    }

    func updateWorkspace(id: String, name: String? = nil, description: String? = nil, completion: @escaping (Result<DocWorkspace, Error>) -> Void) {
        docBridgeLog.info("updateWorkspace: id=\(id)")
        var body: [String: Any] = [:]
        if let n = name { body["name"] = n }
        if let d = description { body["description"] = d }
        put("/api/workspaces/\(id)", body: body) { [weak self] (result: Result<DocWorkspace, Error>) in
            switch result {
            case .success(let ws):
                DispatchQueue.main.async {
                    self?.workspaces = self?.workspaces.map { $0.id == ws.id ? ws : $0 } ?? []
                    if self?.currentWorkspace?.id == ws.id { self?.currentWorkspace = ws }
                }
                completion(.success(ws))
            case .failure(let err):
                self?.handleError(err, context: "updateWorkspace")
                completion(.failure(err))
            }
        }
    }

    func deleteWorkspace(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("deleteWorkspace: id=\(id)")
        delete("/api/workspaces/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.workspaces = self?.workspaces.filter { $0.id != id } ?? []
                    if self?.currentWorkspace?.id == id { self?.currentWorkspace = nil }
                }
                completion(.success(resp))
            case .failure(let err):
                self?.handleError(err, context: "deleteWorkspace")
                completion(.failure(err))
            }
        }
    }
}
