// Callers: DocView, DocSidebar, DocEditorArea, DocAICopilotView, DocGraphView, DocVersionView, DocOfficeView, DocWorkflowView, DocTemplateView, DocSearchView, DocCommentsView, DocFavoritesView, DocFilesPanel, DocRAGPanel, DocActivityView.
// Affected API: REST localhost:11449 (fusion-doc server — 102 routes across auth/workspace/users/page/book/chapter/tag/graph/workflow/template/office/copilot/rag/search/comment/favorite/activity/file/branding/theme/vocabulary/webhook/metadata/system/export/notification/ai controllers).
// Data schemas: DocPage/DocBook/DocChapter/DocTag/DocGraphNode/DocGraphEdge/DocWorkflow/DocTemplate/DocVersion/DocDiffLine/DocOfficeStatus/DocSearchResult/DocComment/DocFavorite/DocActivity/DocFileUpload/DocWorkflowState/DocAuthResponse/DocWorkspace/DocUser/DocBranding/DocTheme/DocVocabulary/DocWebhook/DocMetadataEntry/DocSystemInfo/DocSystemConfig/DocExportJob/DocNotification aligned with fusion-doc controller responses.
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import Foundation
import Combine
import os.log

private let docBridgeLog = Logger(subsystem: "com.fusion.studio", category: "DocBridge")
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
    @Published var comments: [DocComment] = []
    @Published var favorites: [DocFavorite] = []
    @Published var activities: [DocActivity] = []
    @Published var files: [DocFileUpload] = []
    @Published var chunks: [DocRAGChunk] = []
    @Published var workspaces: [DocWorkspace] = []
    @Published var currentWorkspace: DocWorkspace?
    @Published var users: [DocUser] = []
    @Published var branding: DocBranding?
    @Published var themes: [DocTheme] = []
    @Published var vocabulary: [DocVocabulary] = []
    @Published var webhooks: [DocWebhook] = []
    @Published var systemInfo: DocSystemInfo?
    @Published var systemConfig: [DocSystemConfig] = []
    @Published var exportJobs: [DocExportJob] = []
    @Published var notifications: [DocNotification] = []
    @Published var isAuthenticated: Bool = false
    @Published var authError: String?

    // HIGH-2 / 审计0902 R6 (P0): bearer token 存 macOS Keychain, 不再明文落 UserDefaults plist。
    // 旧版本曾存 UserDefaults "fusion_doc_auth_token", 首次读时迁移到 Keychain 并清旧明文条目。
    private static let authTokenKeychainAccount = "fusion_doc_auth_token"
    private static let authTokenLegacyKey = "fusion_doc_auth_token"
    private var authToken: String? {
        get {
            if let token = KeychainStore.get(Self.authTokenKeychainAccount), !token.isEmpty {
                return token
            }
            // 迁移: 旧明文 UserDefaults 值一次性搬入 Keychain, 然后清旧条目。
            if let legacy = UserDefaults.standard.string(forKey: Self.authTokenLegacyKey), !legacy.isEmpty {
                docBridgeLog.info("authToken: migrating legacy UserDefaults token to Keychain (len \(legacy.count))")
                _ = KeychainStore.set(Self.authTokenKeychainAccount, legacy)
                UserDefaults.standard.removeObject(forKey: Self.authTokenLegacyKey)
                return legacy
            }
            return nil
        }
        set {
            if let token = newValue, !token.isEmpty {
                _ = KeychainStore.set(Self.authTokenKeychainAccount, token)
                docBridgeLog.info("authToken: persisted to Keychain (len \(token.count))")
            } else {
                _ = KeychainStore.delete(Self.authTokenKeychainAccount)
                // 兜底清可能残留的旧明文条目。
                UserDefaults.standard.removeObject(forKey: Self.authTokenLegacyKey)
                docBridgeLog.info("authToken: cleared from Keychain (and legacy UserDefaults if present)")
            }
        }
    }

    // F-A2: DocBridge 流式 @Published 数组无界 append (create/clone/install 回调内),
    // 连续操作不 fetch 时内存单调增长。统一 LRU cap 入口, 保留最近 cap 条, 超额丢弃最旧。
    // PERF-3 ragResults 范式。各调用方在 append 后调 capXxx 限流。
    private static func cap<T>(_ arr: inout [T], _ cap: Int) {
        if arr.count > cap {
            arr.removeFirst(arr.count - cap)
        }
    }

    private let baseURL: String
    private let session: URLSession

    // 审计0902 R5 (P2): 无重连定时器 (仅 checkHealth 翻状态, 无自动重试), fusion-doc 宕 = 永久
    //   isConnected=false 无自愈。对齐 IPCClient/SimulationBridge 退避: base 2s × 2^min(attempt,5)
    //   封顶 60s + jitter, 成功复位 attempt=0。
    private var reconnectTimer: Timer?
    private var reconnectAttempt: Int = 0

    init(baseURL: String = "http://127.0.0.1:11449") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    deinit {
        reconnectTimer?.invalidate()
    }

    // MARK: - Generic HTTP

    // 审计0902 A4 (P1): 旧实现 dataTask completion 仅查 error, 无视 HTTP statusCode, 直接把响应体喂
    // JSONDecoder -> 401/403/500 body 触发 decodeError, UI 报"解码错误"而非真实鉴权/服务端故障。
    // 此守卫在解码前校验 statusCode, 4xx/5xx 抛语义化错误 (脱敏, 不回显响应体可能含的密钥/内部路径)。
    // 审计0902 #234 test hook: private→internal (status 校验纯函数, 单测覆盖 4xx/5xx 语义错误)。
    static func httpStatusError(_ response: URLResponse?, _ data: Data?) -> Error? {
        guard let http = response as? HTTPURLResponse else { return nil }
        let code = http.statusCode
        guard !(200...299).contains(code) else { return nil }
        let desc: String
        switch code {
        case 401: desc = "Unauthorized (401): 鉴权失败, 检查 fusion-doc 工作区令牌"
        case 403: desc = "Forbidden (403): 无权限访问该资源"
        case 404: desc = "Not Found (404): 端点或资源不存在"
        case 500...599: desc = "Server error (\(code)): fusion-doc 服务端故障"
        default: desc = "HTTP \(code)"
        }
        docBridgeLog.error("DocBridge HTTP \(code) (不解码响应体, 避免掩盖真实故障)")
        return NSError(domain: "DocBridge", code: code, userInfo: [NSLocalizedDescriptionKey: desc])
    }

    private func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            if let statusErr = Self.httpStatusError(response, data) { completion(.failure(statusErr)); return }
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
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            if let statusErr = Self.httpStatusError(response, data) { completion(.failure(statusErr)); return }
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
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            if let statusErr = Self.httpStatusError(response, data) { completion(.failure(statusErr)); return }
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
        session.dataTask(with: request) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            if let statusErr = Self.httpStatusError(response, data) { completion(.failure(statusErr)); return }
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
            // 审计0827 §3.9.4 (P2): lastError 旧裸 "\(context): \(error.localizedDescription)" 暴露底层错
            // (URL/路径/端口) 到 UI。context 是固定标签 (health/books 等) 非用户数据可留; error 经
            // BridgeError.sanitize 脱敏取 i18n 用户消息。日志保留 raw 供定位 (本地 os_log)。
            self.lastError = "\(context): \(BridgeError.sanitize(error))"
            // 审计0902 R5 (P2): health 失败触发退避重连, 非"翻一次状态即永久 false"。
            if context == "health" {
                self.isConnected = false
                self.scheduleReconnect()
            }
        }
    }

    // 审计0902 R5 (P2): 指数退避 + jitter。base 2s × 2^min(attempt,5) 封顶 60s, jitter (attempt×137)%1000ms;
    //   单次 fire (非 repeats) 每次重算 interval, 成功复位 attempt=0。
    private func scheduleReconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reconnectTimer?.invalidate()
            let attempt = self.reconnectAttempt
            let base = 2.0 * pow(2.0, Double(min(attempt, 5)))
            let interval = min(base, 60.0) + Double((attempt * 137) % 1000) / 1000.0
            self.reconnectAttempt += 1
            docBridgeLog.warning("DocBridge reconnect backoff: attempt=\(attempt) interval=\(String(format: "%.2f", interval))s")
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.checkHealth()
            }
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
                    self?.reconnectTimer?.invalidate()
                    self?.reconnectTimer = nil
                    self?.reconnectAttempt = 0
                }
            case .failure(let error):
                self?.handleError(error, context: "health")
            }
        }
    }

    // MARK: - Books

    func fetchBooks() {
        get("/api/books") { [weak self] (result: Result<[DocBook], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.books = Array(list.suffix(200)) }
            case .failure(let error):
                self?.handleError(error, context: "books")
            }
        }
    }

    func createBook(title: String, description: String? = nil, workspaceId: String? = nil) {
        var body: [String: Any] = ["title": title]
        if let desc = description { body["description"] = desc }
        if let wsId = workspaceId { body["workspace_id"] = wsId }
        post("/api/books", body: body) { [weak self] (result: Result<DocBook, Error>) in
            switch result {
            case .success(let book):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.books.append(book)
                    Self.cap(&self.books, 200)
                }
            case .failure(let error):
                self?.handleError(error, context: "createBook")
            }
        }
    }

    // MARK: - Chapters

    func fetchChapters(bookId: String) {
        get("/api/chapters?bookId=\(bookId)") { [weak self] (result: Result<[DocChapter], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.chapters = Array(list.suffix(200)) }
            case .failure(let error):
                self?.handleError(error, context: "chapters")
            }
        }
    }

    func createChapter(bookId: String, title: String) {
        post("/api/chapters", body: ["book_id": bookId, "title": title]) { [weak self] (result: Result<DocChapter, Error>) in
            switch result {
            case .success(let ch):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.chapters.append(ch)
                    Self.cap(&self.chapters, 500)
                }
            case .failure(let error):
                self?.handleError(error, context: "createChapter")
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
                DispatchQueue.main.async { self?.pages = Array(list.suffix(200)) }
            case .failure(let error):
                self?.handleError(error, context: "pages")
            }
        }
    }

    func fetchPage(id: String) {
        get("/api/pages/\(id)") { [weak self] (result: Result<DocPage, Error>) in
            switch result {
            case .success(let page):
                DispatchQueue.main.async { self?.currentPage = page }
            case .failure(let error):
                self?.handleError(error, context: "page")
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
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.pages.append(page)
                    Self.cap(&self.pages, 1000)
                }
            case .failure(let error):
                self?.handleError(error, context: "createPage")
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
            case .failure(let error):
                self?.handleError(error, context: "updatePage")
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
            case .failure(let error):
                self?.handleError(error, context: "deletePage")
            }
        }
    }

    // MARK: - Tags

    func fetchTags() {
        get("/api/tags") { [weak self] (result: Result<[DocTag], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.tags = Array(list.suffix(200)) }
            case .failure(let error):
                self?.handleError(error, context: "tags")
            }
        }
    }

    // MARK: - Graph

    func fetchGraph() {
        get("/api/graph") { [weak self] (result: Result<DocGraph, Error>) in
            switch result {
            case .success(let g):
                DispatchQueue.main.async { self?.graph = g }
            case .failure(let error):
                self?.handleError(error, context: "graph")
            }
        }
    }

    // MARK: - Versions

    func fetchVersions(pageId: String) {
        get("/api/pages/\(pageId)/versions") { [weak self] (result: Result<[DocVersion], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.versions = Array(list.suffix(200)) }
            case .failure(let error):
                self?.handleError(error, context: "versions")
            }
        }
    }

    func createVersion(pageId: String, title: String, content: String) {
        post("/api/pages/\(pageId)/versions", body: ["title": title, "content": content]) { [weak self] (result: Result<DocVersion, Error>) in
            switch result {
            case .success(let v):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.versions.append(v)
                    Self.cap(&self.versions, 200)
                }
            case .failure(let error):
                self?.handleError(error, context: "createVersion")
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
            case .failure(let error):
                self?.handleError(error, context: "restoreVersion")
            }
        }
    }

    // MARK: - Workflows

    func fetchWorkflows() {
        get("/api/workflows") { [weak self] (result: Result<[DocWorkflow], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.workflows = Array(list.suffix(200)) }
            case .failure(let error):
                self?.handleError(error, context: "workflows")
            }
        }
    }

    func runWorkflow(id: String, input: [String: Any]? = nil) {
        post("/api/workflows/\(id)/run", body: input) { [weak self] (result: Result<DocWorkflowRun, Error>) in
            switch result {
            case .success:
                docBridgeLog.info("Workflow \(id) started")
            case .failure(let error):
                self?.handleError(error, context: "runWorkflow")
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
                DispatchQueue.main.async { self?.templates = Array(list.suffix(200)) }
            case .failure(let error):
                self?.handleError(error, context: "templates")
            }
        }
    }

    func instantiateTemplate(id: String, variables: [String: Any]) {
        post("/api/templates/\(id)/instantiate", body: ["variables": variables]) { [weak self] (result: Result<DocPage, Error>) in
            switch result {
            case .success(let page):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.pages.append(page)
                    Self.cap(&self.pages, 1000)
                }
            case .failure(let error):
                self?.handleError(error, context: "instantiateTemplate")
            }
        }
    }

    // MARK: - Office

    func checkOfficeStatus() {
        get("/api/office/status") { [weak self] (result: Result<DocOfficeStatus, Error>) in
            switch result {
            case .success(let status):
                DispatchQueue.main.async { self?.officeStatus = status }
            case .failure(let error):
                self?.handleError(error, context: "officeStatus")
            }
        }
    }

    func createOfficeDocument(format: String, name: String) {
        struct OfficeCreateResp: Decodable { var id: String?; var path: String? }
        post("/api/office/create", body: ["format": format, "name": name]) { [weak self] (result: Result<OfficeCreateResp, Error>) in
            switch result {
            case .success:
                docBridgeLog.info("Office doc created: \(name).\(format)")
            case .failure(let error):
                self?.handleError(error, context: "createOffice")
            }
        }
    }

    func importOfficeDocument(filePath: String, bookId: String? = nil) {
        var body: [String: Any] = ["file_path": filePath]
        if let bid = bookId { body["book_id"] = bid }
        post("/api/office/import", body: body) { [weak self] (result: Result<DocPage, Error>) in
            switch result {
            case .success(let page):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.pages.append(page)
                    Self.cap(&self.pages, 1000)
                }
            case .failure(let error):
                self?.handleError(error, context: "importOffice")
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
            case .failure(let error):
                self?.handleError(error, context: "reindex")
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
            case .failure(let error):
                self?.handleError(error, context: "addLink")
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
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.templates.append(tmpl)
                    Self.cap(&self.templates, 200)
                }
                completion(.success(tmpl))
            case .failure(let error):
                self?.handleError(error, context: "createTemplate")
                completion(.failure(error))
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
            case .failure(let error):
                self?.handleError(error, context: "deleteTemplate")
                completion(.failure(error))
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
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.workflows.append(wf)
                    Self.cap(&self.workflows, 200)
                }
                completion(.success(wf))
            case .failure(let error):
                self?.handleError(error, context: "createWorkflow")
                completion(.failure(error))
            }
        }
    }

    func deleteWorkflow(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        delete("/api/workflows/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.workflows.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let error):
                self?.handleError(error, context: "deleteWorkflow")
                completion(.failure(error))
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
                DispatchQueue.main.async { self?.workflows = Array(list.suffix(200)) }
                completion(.success(list))
            case .failure(let error):
                self?.handleError(error, context: "seedWorkflows")
                completion(.failure(error))
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
                DispatchQueue.main.async { self?.files = Array(list.suffix(200)) }
                completion(.success(list))
            case .failure(let error):
                self?.handleError(error, context: "fetchFiles")
                completion(.failure(error))
            }
        }
    }

    func uploadFile(pageId: String, name: String, mime: String, content: String, completion: @escaping (Result<DocFileUpload, Error>) -> Void) {
        post("/api/pages/\(pageId)/files", body: ["name": name, "mime": mime, "content": content]) { [weak self] (result: Result<DocFileUpload, Error>) in
            switch result {
            case .success(let file):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.files.append(file)
                    Self.cap(&self.files, 500)
                }
                completion(.success(file))
            case .failure(let error):
                self?.handleError(error, context: "uploadFile")
                completion(.failure(error))
            }
        }
    }

    func deleteFile(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        delete("/api/files/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.files.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let error):
                self?.handleError(error, context: "deleteFile")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Comments

    func fetchComments(pageId: String, completion: @escaping (Result<[DocComment], Error>) -> Void) {
        get("/api/pages/\(pageId)/comments") { [weak self] (result: Result<[DocComment], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.comments = Array(list.suffix(200)) }
                completion(.success(list))
            case .failure(let error):
                self?.handleError(error, context: "fetchComments")
                completion(.failure(error))
            }
        }
    }

    func createComment(pageId: String, content: String, parentId: String? = nil, completion: @escaping (Result<DocComment, Error>) -> Void) {
        var body: [String: Any] = ["content": content]
        if let pid = parentId { body["parent_id"] = pid }
        post("/api/pages/\(pageId)/comments", body: body) { [weak self] (result: Result<DocComment, Error>) in
            switch result {
            case .success(let comment):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.comments.append(comment)
                    Self.cap(&self.comments, 500)
                }
                completion(.success(comment))
            case .failure(let error):
                self?.handleError(error, context: "createComment")
                completion(.failure(error))
            }
        }
    }

    func deleteComment(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        delete("/api/comments/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.comments.removeAll { $0.id == id } }
                completion(.success(["deleted": true]))
            case .failure(let error):
                self?.handleError(error, context: "deleteComment")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Favorites

    func fetchFavorites(completion: @escaping (Result<[DocFavorite], Error>) -> Void) {
        get("/api/favorites") { [weak self] (result: Result<[DocFavorite], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.favorites = Array(list.suffix(200)) }
                completion(.success(list))
            case .failure(let error):
                self?.handleError(error, context: "fetchFavorites")
                completion(.failure(error))
            }
        }
    }

    func addFavorite(pageId: String, completion: @escaping (Result<DocFavorite, Error>) -> Void) {
        post("/api/favorites", body: ["page_id": pageId]) { [weak self] (result: Result<DocFavorite, Error>) in
            switch result {
            case .success(let fav):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.favorites.append(fav)
                    Self.cap(&self.favorites, 200)
                }
                completion(.success(fav))
            case .failure(let error):
                self?.handleError(error, context: "addFavorite")
                completion(.failure(error))
            }
        }
    }

    func removeFavorite(pageId: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        delete("/api/favorites/\(pageId)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.favorites.removeAll { $0.page_id == pageId } }
                completion(.success(["deleted": true]))
            case .failure(let error):
                self?.handleError(error, context: "removeFavorite")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Activity

    func fetchActivity(limit: Int = 50, completion: @escaping (Result<[DocActivity], Error>) -> Void) {
        get("/api/activity?limit=\(limit)") { [weak self] (result: Result<[DocActivity], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.activities = Array(list.suffix(500)) }
                completion(.success(list))
            case .failure(let error):
                self?.handleError(error, context: "fetchActivity")
                completion(.failure(error))
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
                DispatchQueue.main.async { self?.chunks = Array(list.suffix(500)) }
                completion(.success(list))
            case .failure(let error):
                self?.handleError(error, context: "fetchChunks")
                completion(.failure(error))
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
        post("/api/auth/setup", body: ["email": username, "password": password]) { [weak self] (result: Result<DocAuthResponse, Error>) in
            switch result {
            case .success(let resp):
                if let token = resp.token {
                    self?.authToken = token
                    DispatchQueue.main.async { self?.isAuthenticated = true; self?.authError = nil }
                    docBridgeLog.info("authSetup success, token saved")
                }
                completion(.success(resp))
            case .failure(let error):
                DispatchQueue.main.async { self?.authError = BridgeError.sanitize(error) }
                docBridgeLog.error("authSetup failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    func authLogin(username: String, password: String, completion: @escaping (Result<DocAuthResponse, Error>) -> Void) {
        docBridgeLog.info("authLogin: username=\(username)")
        post("/api/auth/login", body: ["email": username, "password": password]) { [weak self] (result: Result<DocAuthResponse, Error>) in
            switch result {
            case .success(let resp):
                if let token = resp.token {
                    self?.authToken = token
                    DispatchQueue.main.async { self?.isAuthenticated = true; self?.authError = nil }
                    docBridgeLog.info("authLogin success, token saved")
                }
                completion(.success(resp))
            case .failure(let error):
                DispatchQueue.main.async { self?.authError = BridgeError.sanitize(error) }
                docBridgeLog.error("authLogin failed: \(error.localizedDescription)")
                completion(.failure(error))
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
            case .failure(let error):
                docBridgeLog.error("authRefresh failed: \(error.localizedDescription)")
                completion(.failure(error))
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
            docBridgeLog.info("restoreAuth: token found, verifying via /api/auth/me")
            verifyAndAutoLogin()
        } else {
            docBridgeLog.info("restoreAuth: no token, auto-login with default account")
            autoLogin()
        }
    }

    private func verifyAndAutoLogin() {
        get("/api/workspaces") { [weak self] (result: Result<[DocWorkspace], Error>) in
            switch result {
            case .success:
                docBridgeLog.info("restoreAuth: token still valid")
                DispatchQueue.main.async { self?.isAuthenticated = true; self?.authError = nil }
            case .failure(let error):
                docBridgeLog.warning("restoreAuth: token invalid (\(error.localizedDescription)), re-login")
                self?.autoLogin()
            }
        }
    }

    private func autoLogin() {
        docBridgeLog.info("autoLogin: default account admin@fusion.local")
        authLogin(username: "admin@fusion.local", password: "admin123") { [weak self] result in
            switch result {
            case .success:
                docBridgeLog.info("autoLogin success")
            case .failure(let error):
                docBridgeLog.error("autoLogin failed: \(error.localizedDescription) — 用户需手动登录")
                DispatchQueue.main.async { self?.authError = "自动登录失败，请手动登录" }
            }
        }
    }

    // MARK: - Workspace CRUD

    func fetchWorkspaces(completion: @escaping (Result<[DocWorkspace], Error>) -> Void) {
        docBridgeLog.info("fetchWorkspaces")
        get("/api/workspaces") { [weak self] (result: Result<[DocWorkspace], Error>) in
            switch result {
            case .success(let list):
                DispatchQueue.main.async { self?.workspaces = Array(list.suffix(200)) }
                completion(.success(list))
            case .failure(let error):
                self?.handleError(error, context: "fetchWorkspaces")
                completion(.failure(error))
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
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.workspaces.append(ws)
                    Self.cap(&self.workspaces, 50)
                    self.currentWorkspace = ws
                }
                docBridgeLog.info("createWorkspace success: \(ws.id)")
                completion(.success(ws))
            case .failure(let error):
                self?.handleError(error, context: "createWorkspace")
                completion(.failure(error))
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
            case .failure(let error):
                self?.handleError(error, context: "updateWorkspace")
                completion(.failure(error))
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
            case .failure(let error):
                self?.handleError(error, context: "deleteWorkspace")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Users

    func fetchUsers(completion: @escaping (Result<[DocUser], Error>) -> Void) {
        docBridgeLog.info("fetchUsers")
        get("/api/users") { [weak self] (result: Result<[DocUser], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.users = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.handleError(error, context: "fetchUsers"); completion(.failure(error))
            }
        }
    }

    func updateUser(id: String, username: String? = nil, email: String? = nil, role: String? = nil, completion: @escaping (Result<DocUser, Error>) -> Void) {
        docBridgeLog.info("updateUser: id=\(id)")
        var body: [String: Any] = [:]
        if let u = username { body["username"] = u }
        if let e = email { body["email"] = e }
        if let r = role { body["role"] = r }
        put("/api/users/\(id)", body: body) { [weak self] (result: Result<DocUser, Error>) in
            switch result {
            case .success(let user):
                DispatchQueue.main.async { self?.users = self?.users.map { $0.id == user.id ? user : $0 } ?? [] }
                completion(.success(user))
            case .failure(let error): self?.handleError(error, context: "updateUser"); completion(.failure(error))
            }
        }
    }

    func deleteUser(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("deleteUser: id=\(id)")
        delete("/api/users/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.users = self?.users.filter { $0.id != id } ?? [] }
                completion(.success(resp))
            case .failure(let error): self?.handleError(error, context: "deleteUser"); completion(.failure(error))
            }
        }
    }

    // MARK: - AI Raw

    func aiChat(messages: [[String: String]], completion: @escaping (Result<[String: String], Error>) -> Void) {
        docBridgeLog.info("aiChat")
        post("/api/ai/chat", body: ["messages": messages], completion: completion)
    }

    func aiCompletions(prompt: String, completion: @escaping (Result<[String: String], Error>) -> Void) {
        docBridgeLog.info("aiCompletions: prompt=\(prompt.prefix(50))")
        post("/api/ai/completions", body: ["prompt": prompt], completion: completion)
    }

    // MARK: - Branding

    func fetchBranding(completion: @escaping (Result<DocBranding, Error>) -> Void) {
        docBridgeLog.info("fetchBranding")
        get("/api/branding") { [weak self] (result: Result<DocBranding, Error>) in
            switch result {
            case .success(let b): DispatchQueue.main.async { self?.branding = b }; completion(.success(b))
            case .failure(let error): self?.handleError(error, context: "fetchBranding"); completion(.failure(error))
            }
        }
    }

    func updateBranding(branding: DocBranding, completion: @escaping (Result<DocBranding, Error>) -> Void) {
        docBridgeLog.info("updateBranding")
        let body: [String: Any?] = [
            "logo_url": branding.logo_url,
            "primary_color": branding.primary_color,
            "secondary_color": branding.secondary_color,
            "font": branding.font,
            "custom_css": branding.custom_css,
        ]
        put("/api/branding", body: body.compactMapValues { $0 }) { [weak self] (result: Result<DocBranding, Error>) in
            switch result {
            case .success(let b): DispatchQueue.main.async { self?.branding = b }; completion(.success(b))
            case .failure(let error): self?.handleError(error, context: "updateBranding"); completion(.failure(error))
            }
        }
    }

    // MARK: - Theme CRUD

    func fetchThemes(completion: @escaping (Result<[DocTheme], Error>) -> Void) {
        docBridgeLog.info("fetchThemes")
        get("/api/themes") { [weak self] (result: Result<[DocTheme], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.themes = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.handleError(error, context: "fetchThemes"); completion(.failure(error))
            }
        }
    }

    func createTheme(name: String, css: String? = nil, isDark: Bool? = nil, completion: @escaping (Result<DocTheme, Error>) -> Void) {
        docBridgeLog.info("createTheme: name=\(name)")
        var body: [String: Any] = ["name": name]
        if let c = css { body["css"] = c }
        if let d = isDark { body["is_dark"] = d }
        post("/api/themes", body: body) { [weak self] (result: Result<DocTheme, Error>) in
            switch result {
            case .success(let t): DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.themes.append(t)
                Self.cap(&self.themes, 100)
            }; completion(.success(t))
            case .failure(let error): self?.handleError(error, context: "createTheme"); completion(.failure(error))
            }
        }
    }

    func deleteTheme(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("deleteTheme: id=\(id)")
        delete("/api/themes/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.themes = self?.themes.filter { $0.id != id } ?? [] }
                completion(.success(resp))
            case .failure(let error): self?.handleError(error, context: "deleteTheme"); completion(.failure(error))
            }
        }
    }

    // MARK: - Vocabulary CRUD

    func fetchVocabulary(completion: @escaping (Result<[DocVocabulary], Error>) -> Void) {
        docBridgeLog.info("fetchVocabulary")
        get("/api/vocabulary") { [weak self] (result: Result<[DocVocabulary], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.vocabulary = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.handleError(error, context: "fetchVocabulary"); completion(.failure(error))
            }
        }
    }

    func createVocabulary(term: String, definition: String? = nil, category: String? = nil, completion: @escaping (Result<DocVocabulary, Error>) -> Void) {
        docBridgeLog.info("createVocabulary: term=\(term)")
        var body: [String: Any] = ["term": term]
        if let d = definition { body["definition"] = d }
        if let c = category { body["category"] = c }
        post("/api/vocabulary", body: body) { [weak self] (result: Result<DocVocabulary, Error>) in
            switch result {
            case .success(let v): DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.vocabulary.append(v)
                Self.cap(&self.vocabulary, 500)
            }; completion(.success(v))
            case .failure(let error): self?.handleError(error, context: "createVocabulary"); completion(.failure(error))
            }
        }
    }

    func deleteVocabulary(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("deleteVocabulary: id=\(id)")
        delete("/api/vocabulary/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.vocabulary = self?.vocabulary.filter { $0.id != id } ?? [] }
                completion(.success(resp))
            case .failure(let error): self?.handleError(error, context: "deleteVocabulary"); completion(.failure(error))
            }
        }
    }

    // MARK: - Webhooks CRUD

    func fetchWebhooks(completion: @escaping (Result<[DocWebhook], Error>) -> Void) {
        docBridgeLog.info("fetchWebhooks")
        get("/api/webhooks") { [weak self] (result: Result<[DocWebhook], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.webhooks = Array(list.suffix(200)) }; completion(.success(list))
            case .failure(let error): self?.handleError(error, context: "fetchWebhooks"); completion(.failure(error))
            }
        }
    }

    func createWebhook(url: String, events: [String]? = nil, secret: String? = nil, completion: @escaping (Result<DocWebhook, Error>) -> Void) {
        docBridgeLog.info("createWebhook: url=\(url)")
        var body: [String: Any] = ["url": url]
        if let e = events { body["events"] = e }
        if let s = secret { body["secret"] = s }
        post("/api/webhooks", body: body) { [weak self] (result: Result<DocWebhook, Error>) in
            switch result {
            case .success(let w): DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.webhooks.append(w)
                Self.cap(&self.webhooks, 100)
            }; completion(.success(w))
            case .failure(let error): self?.handleError(error, context: "createWebhook"); completion(.failure(error))
            }
        }
    }

    func deleteWebhook(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("deleteWebhook: id=\(id)")
        delete("/api/webhooks/\(id)") { [weak self] (result: Result<[String: Bool], Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.webhooks = self?.webhooks.filter { $0.id != id } ?? [] }
                completion(.success(resp))
            case .failure(let error): self?.handleError(error, context: "deleteWebhook"); completion(.failure(error))
            }
        }
    }

    func testWebhook(id: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("testWebhook: id=\(id)")
        post("/api/webhooks/\(id)/test", body: nil, completion: completion)
    }

    // MARK: - Metadata

    func fetchMetadata(entity: String, entityId: String, completion: @escaping (Result<[DocMetadataEntry], Error>) -> Void) {
        docBridgeLog.info("fetchMetadata: \(entity)/\(entityId)")
        get("/api/\(entity)/\(entityId)/metadata", completion: completion)
    }

    func setMetadata(entity: String, entityId: String, key: String, value: String, completion: @escaping (Result<DocMetadataEntry, Error>) -> Void) {
        docBridgeLog.info("setMetadata: \(entity)/\(entityId) key=\(key)")
        put("/api/\(entity)/\(entityId)/metadata", body: ["key": key, "value": value], completion: completion)
    }

    func deleteMetadata(entity: String, entityId: String, key: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("deleteMetadata: \(entity)/\(entityId) key=\(key)")
        delete("/api/\(entity)/\(entityId)/metadata/\(key)", completion: completion)
    }

    // MARK: - System

    func fetchSystemInfo(completion: @escaping (Result<DocSystemInfo, Error>) -> Void) {
        docBridgeLog.info("fetchSystemInfo")
        get("/api/system/info") { [weak self] (result: Result<DocSystemInfo, Error>) in
            switch result {
            case .success(let info): DispatchQueue.main.async { self?.systemInfo = info }; completion(.success(info))
            case .failure(let error): self?.handleError(error, context: "fetchSystemInfo"); completion(.failure(error))
            }
        }
    }

    func fetchSystemConfig(completion: @escaping (Result<[DocSystemConfig], Error>) -> Void) {
        docBridgeLog.info("fetchSystemConfig")
        get("/api/system/config") { [weak self] (result: Result<[DocSystemConfig], Error>) in
            switch result {
            case .success(let cfg):
                // F-perf-3: systemConfig LRU cap 200 (配置项不应无界增长)。
                let capped = Array(cfg.prefix(200))
                DispatchQueue.main.async { self?.systemConfig = capped }; completion(.success(capped))
            case .failure(let error): self?.handleError(error, context: "fetchSystemConfig"); completion(.failure(error))
            }
        }
    }

    func updateSystemConfig(key: String, value: String, completion: @escaping (Result<DocSystemConfig, Error>) -> Void) {
        docBridgeLog.info("updateSystemConfig: key=\(key)")
        put("/api/system/config", body: ["key": key, "value": value], completion: completion)
    }

    // MARK: - File Upload

    func uploadFile(fileData: Data, fileName: String, mimeType: String, completion: @escaping (Result<DocFileUpload, Error>) -> Void) {
        docBridgeLog.info("uploadFile: name=\(fileName)")
        guard let url = URL(string: "\(baseURL)/api/files/upload") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        session.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "DocBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(DocFileUpload.self, from: data)
                completion(.success(decoded))
            } catch { completion(.failure(error)) }
        }.resume()
    }

    // MARK: - Export

    func exportBook(bookId: String, format: String, completion: @escaping (Result<DocExportJob, Error>) -> Void) {
        docBridgeLog.info("exportBook: bookId=\(bookId) format=\(format)")
        post("/api/export/\(format)", body: ["book_id": bookId]) { [weak self] (result: Result<DocExportJob, Error>) in
            switch result {
            case .success(let job): DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.exportJobs.append(job)
                Self.cap(&self.exportJobs, 100)
            }; completion(.success(job))
            case .failure(let error): self?.handleError(error, context: "exportBook"); completion(.failure(error))
            }
        }
    }

    func fetchExportStatus(jobId: String, completion: @escaping (Result<DocExportJob, Error>) -> Void) {
        docBridgeLog.info("fetchExportStatus: jobId=\(jobId)")
        get("/api/export/\(jobId)/status", completion: completion)
    }

    // MARK: - RAG Basic

    func buildRAGIndex(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("buildRAGIndex")
        post("/api/rag/index", body: nil, completion: completion)
    }

    func fetchRAGStatus(completion: @escaping (Result<[String: String], Error>) -> Void) {
        docBridgeLog.info("fetchRAGStatus")
        get("/api/rag/status", completion: completion)
    }

    func clearRAGIndex(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("clearRAGIndex")
        delete("/api/rag/index", completion: completion)
    }

    func embedRAGContent(content: String, completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("embedRAGContent")
        post("/api/rag/embed", body: ["content": content], completion: completion)
    }

    // MARK: - Graph Search

    func graphSemanticSearch(query: String, completion: @escaping (Result<DocGraph, Error>) -> Void) {
        docBridgeLog.info("graphSemanticSearch: query=\(query.prefix(50))")
        post("/api/graph/search", body: ["query": query], completion: completion)
    }

    func graphTraverse(startId: String, direction: String = "both", maxDepth: Int = 3, completion: @escaping (Result<DocGraph, Error>) -> Void) {
        docBridgeLog.info("graphTraverse: start=\(startId) depth=\(maxDepth)")
        post("/api/graph/traverse", body: ["start_id": startId, "direction": direction, "max_depth": maxDepth], completion: completion)
    }

    func graphCluster(algorithm: String = "louvain", completion: @escaping (Result<[String: [[String]]], Error>) -> Void) {
        docBridgeLog.info("graphCluster: algorithm=\(algorithm)")
        post("/api/graph/cluster", body: ["algorithm": algorithm], completion: completion)
    }

    // MARK: - Notifications

    func fetchNotifications(completion: @escaping (Result<[DocNotification], Error>) -> Void) {
        docBridgeLog.info("fetchNotifications")
        get("/api/notifications") { [weak self] (result: Result<[DocNotification], Error>) in
            switch result {
            case .success(let list): DispatchQueue.main.async { self?.notifications = Array(list.suffix(500)) }; completion(.success(list))
            case .failure(let error): self?.handleError(error, context: "fetchNotifications"); completion(.failure(error))
            }
        }
    }

    func markNotificationRead(id: String, completion: @escaping (Result<DocNotification, Error>) -> Void) {
        docBridgeLog.info("markNotificationRead: id=\(id)")
        put("/api/notifications/\(id)/read", body: [:], completion: completion)
    }

    func markAllNotificationsRead(completion: @escaping (Result<[String: Bool], Error>) -> Void) {
        docBridgeLog.info("markAllNotificationsRead")
        put("/api/notifications/read-all", body: [:], completion: completion)
    }

    // MARK: - Collaboration (WebSocket — pending upstream #22)

    @Published var collabConnected: Bool = false
    @Published var collabUsers: [String] = []
    private var collabTask: URLSessionWebSocketTask?

    func connectCollab(pageId: String) {
        docBridgeLog.info("connectCollab: pageId=\(pageId)")
        guard let url = URL(string: baseURL.replacingOccurrences(of: "http", with: "ws") + "/collaboration?page=\(pageId)") else {
            docBridgeLog.error("connectCollab: invalid WS URL")
            return
        }
        var request = URLRequest(url: url)
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        collabTask = session.webSocketTask(with: request)
        collabTask?.resume()
        DispatchQueue.main.async { self.collabConnected = true }
        docBridgeLog.info("connectCollab: WS task started")
        receiveCollabMessage()
    }

    func disconnectCollab() {
        docBridgeLog.info("disconnectCollab")
        collabTask?.cancel(with: .goingAway, reason: nil)
        collabTask = nil
        DispatchQueue.main.async { self.collabConnected = false; self.collabUsers = [] }
    }

    func sendCollabUpdate(data: Data) {
        guard let task = collabTask else {
            docBridgeLog.warning("sendCollabUpdate: no active WS task")
            return
        }
        task.send(.data(data)) { error in
            if let error = error {
                docBridgeLog.error("sendCollabUpdate failed: \(error.localizedDescription)")
            }
        }
    }

    private func receiveCollabMessage() {
        collabTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    docBridgeLog.info("collab message: \(text.prefix(100))")
                case .data(let data):
                    docBridgeLog.info("collab binary: \(data.count) bytes")
                @unknown default:
                    break
                }
                self?.receiveCollabMessage()
            case .failure(let error):
                docBridgeLog.error("collab receive error: \(error.localizedDescription)")
                DispatchQueue.main.async { self?.collabConnected = false }
            }
        }
    }
}
