// Callers: DocView, DocSidebar, DocEditorArea, DocAICopilotView, DocGraphView, DocVersionView, DocOfficeView, DocWorkflowView, DocTemplateView, DocSearchView, DocCommentsView, DocFavoritesView, DocFilesPanel, DocRAGPanel, DocActivityView.
// Affected API: REST localhost:11449 (fusion-doc server — 102 routes across auth/workspace/users/page/book/chapter/tag/graph/workflow/template/office/copilot/rag/search/comment/favorite/activity/file/branding/theme/vocabulary/webhook/metadata/system/export/notification/ai controllers).
// Data schemas: DocPage/DocBook/DocChapter/DocTag/DocGraphNode/DocGraphEdge/DocWorkflow/DocTemplate/DocVersion/DocDiffLine/DocOfficeStatus/DocSearchResult/DocComment/DocFavorite/DocActivity/DocFileUpload/DocWorkflowState/DocAuthResponse/DocWorkspace/DocUser/DocBranding/DocTheme/DocVocabulary/DocWebhook/DocMetadataEntry/DocSystemInfo/DocSystemConfig/DocExportJob/DocNotification aligned with fusion-doc controller responses.
// User instruction: "在左侧菜单增加 fusion doc,fusion-studio负责GUI，和~/fusion/fusion-doc项目集成起来，包括GUI和workflow，usercase，全面集成"

import Foundation
import Combine
import os.log

private let docBridgeLog = Logger(subsystem: "com.fusion.studio", category: "DocBridge")
// MARK: - DocBridge

// ARCH-1 facade-delegate split (audit-product-0907 P2-2). 32 @Published 拆 13 域 ObservableObject。
//   let 域引用 = 稳定身份, init() objectWillChange.sink 转发每域 (SwiftUI 不自动追踪嵌套
//   ObservableObject, P0-1 修)。32 属性经下方计算属性 get/set 转发, 0 view 改动。
//   行为按域 Phase 2-5 迁入 13 个 Doc<Domain>Service.swift extension (DocBridge 留 1 行 stub);
//   HTTP 基元 (get/post/put/delete + handleError + authToken + session/baseURL) 留 DocBridge 作
//   infra, 域经 bridge?.get 越界。协调器 (scheduleReconnect/restoreVersion/instantiateTemplate/
//   importOfficeDocument/restoreAuth/verifyToken) 留 DocBridge (跨域); 无状态 util (copilot URL/
//   searchPages/searchAdvanced/aiChat/aiCompletions) 留 DocBridge (无 @Published 不值得建域)。
//   DispatchQueue.main.async hops 留: 逃逸 completion handler (URLSession 后台队列回调) 非 @MainActor
//   隔离, hop 是正确性必需非冗余。Phase 6 收尾: 1657→641 行, infra+协调器+util only, 0 重复方法体。
@MainActor
class DocBridge: ObservableObject {
    let libraryState = DocLibraryState()
    let healthState = DocHealthState()
    let authState = DocAuthState()
    let workspaceState = DocWorkspaceState()
    let versionState = DocVersionState()
    let workflowState = DocWorkflowDomainState()
    let templateState = DocTemplateState()
    let officeState = DocOfficeState()
    let graphState = DocGraphState()
    let ragState = DocRAGState()
    let collabState = DocCollabState()
    let adminState = DocAdminState()
    let socialState = DocSocialState()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed forwards (zero view churn — 32 @Published → domain-owned)
    var books: [DocBook] { get { libraryState.books } set { libraryState.books = newValue } }
    var chapters: [DocChapter] { get { libraryState.chapters } set { libraryState.chapters = newValue } }
    var pages: [DocPage] { get { libraryState.pages } set { libraryState.pages = newValue } }
    var currentPage: DocPage? { get { libraryState.currentPage } set { libraryState.currentPage = newValue } }
    var tags: [DocTag] { get { libraryState.tags } set { libraryState.tags = newValue } }
    var isConnected: Bool { get { healthState.isConnected } set { healthState.isConnected = newValue } }
    var lastError: String? { get { healthState.lastError } set { healthState.lastError = newValue } }
    var isAuthenticated: Bool { get { authState.isAuthenticated } set { authState.isAuthenticated = newValue } }
    var authError: String? { get { authState.authError } set { authState.authError = newValue } }
    var workspaces: [DocWorkspace] { get { workspaceState.workspaces } set { workspaceState.workspaces = newValue } }
    var currentWorkspace: DocWorkspace? { get { workspaceState.currentWorkspace } set { workspaceState.currentWorkspace = newValue } }
    var versions: [DocVersion] { get { versionState.versions } set { versionState.versions = newValue } }
    var workflows: [DocWorkflow] { get { workflowState.workflows } set { workflowState.workflows = newValue } }
    var templates: [DocTemplate] { get { templateState.templates } set { templateState.templates = newValue } }
    var officeStatus: DocOfficeStatus? { get { officeState.officeStatus } set { officeState.officeStatus = newValue } }
    var graph: DocGraph? { get { graphState.graph } set { graphState.graph = newValue } }
    var chunks: [DocRAGChunk] { get { ragState.chunks } set { ragState.chunks = newValue } }
    var collabConnected: Bool { get { collabState.collabConnected } set { collabState.collabConnected = newValue } }
    var collabUsers: [String] { get { collabState.collabUsers } set { collabState.collabUsers = newValue } }
    var users: [DocUser] { get { adminState.users } set { adminState.users = newValue } }
    var branding: DocBranding? { get { adminState.branding } set { adminState.branding = newValue } }
    var themes: [DocTheme] { get { adminState.themes } set { adminState.themes = newValue } }
    var vocabulary: [DocVocabulary] { get { adminState.vocabulary } set { adminState.vocabulary = newValue } }
    var webhooks: [DocWebhook] { get { adminState.webhooks } set { adminState.webhooks = newValue } }
    var systemInfo: DocSystemInfo? { get { adminState.systemInfo } set { adminState.systemInfo = newValue } }
    var systemConfig: [DocSystemConfig] { get { adminState.systemConfig } set { adminState.systemConfig = newValue } }
    var exportJobs: [DocExportJob] { get { adminState.exportJobs } set { adminState.exportJobs = newValue } }
    var notifications: [DocNotification] { get { adminState.notifications } set { adminState.notifications = newValue } }
    var activities: [DocActivity] { get { socialState.activities } set { socialState.activities = newValue } }
    var files: [DocFileUpload] { get { socialState.files } set { socialState.files = newValue } }
    var comments: [DocComment] { get { socialState.comments } set { socialState.comments = newValue } }
    var favorites: [DocFavorite] { get { socialState.favorites } set { socialState.favorites = newValue } }

    // HIGH-2 / 审计0902 R6 (P0): bearer token 存 macOS Keychain, 不再明文落 UserDefaults plist。
    // 旧版本曾存 UserDefaults "fusion_doc_auth_token", 首次读时迁移到 Keychain 并清旧明文条目。
    private static let authTokenKeychainAccount = "fusion_doc_auth_token"
    private static let authTokenLegacyKey = "fusion_doc_auth_token"
    // ARCH-1 Phase 2: private→internal — DocAuthService 经 bridge?.authToken reach-through Keychain infra。
    var authToken: String? {
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
    // ARCH-1 Phase 2 (audit-product-0907 P2-2): private→internal — 域服务扩展跨文件 reach-through
    //   bridge?.cap(...) / DocBridge.cap(...)。纯函数 (inout 数组裁剪), 单测覆盖。
    static func cap<T>(_ arr: inout [T], _ cap: Int) {
        if arr.count > cap {
            arr.removeFirst(arr.count - cap)
        }
    }

    // ARCH-1 Phase 4 (audit-product-0907 P2-2): baseURL/session private→internal — DocCollabService
    //   reach-through (connectCollab builds WS URL from baseURL, session.webSocketTask)。
    let baseURL: String
    let session: URLSession

    init(baseURL: String = "http://127.0.0.1:11449") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        // ARCH-1: back-wire weak bridge ref + objectWillChange.sink 转发每域 (P0-1 修)。
        libraryState.bridge = self
        healthState.bridge = self
        authState.bridge = self
        workspaceState.bridge = self
        versionState.bridge = self
        workflowState.bridge = self
        templateState.bridge = self
        officeState.bridge = self
        graphState.bridge = self
        ragState.bridge = self
        collabState.bridge = self
        adminState.bridge = self
        socialState.bridge = self
        libraryState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        healthState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        authState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        workspaceState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        versionState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        workflowState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        templateState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        officeState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        graphState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        ragState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        collabState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        adminState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        socialState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        docBridgeLog.info("DocBridge init: 13 域 objectWillChange 转发已接线 (ARCH-1)")
    }

    deinit {
        // ARCH-1: 域持有 timer/WS task (nonisolated(unsafe)), deinit(nonisolated) 经 cleanup() 清理。
        healthState.cleanup()
        collabState.cleanup()
    }

    // ARCH-1 Phase 1: 旧方法体仍引用 self.reconnectTimer / self.reconnectAttempt / self.collabTask
    //   (现属 healthState/collabState)。私有转发桥使 Phase 1 不搬行为即编译通过; Phase 6 清理时随行为迁出。
    private var reconnectTimer: Timer? {
        get { healthState.reconnectTimer } set { healthState.reconnectTimer = newValue }
    }
    private var reconnectAttempt: Int {
        get { healthState.reconnectAttempt } set { healthState.reconnectAttempt = newValue }
    }
    private var collabTask: URLSessionWebSocketTask? {
        get { collabState.collabTask } set { collabState.collabTask = newValue }
    }

    // MARK: - Generic HTTP

    // 审计0902 A4 (P1): 旧实现 dataTask completion 仅查 error, 无视 HTTP statusCode, 直接把响应体喂
    // JSONDecoder -> 401/403/500 body 触发 decodeError, UI 报"解码错误"而非真实鉴权/服务端故障。
    // 此守卫在解码前校验 statusCode, 4xx/5xx 抛语义化错误 (脱敏, 不回显响应体可能含的密钥/内部路径)。
    // 审计0902 #234 test hook: private→internal (status 校验纯函数, 单测覆盖 4xx/5xx 语义错误)。
    nonisolated static func httpStatusError(_ response: URLResponse?, _ data: Data?) -> Error? {
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

    // ARCH-1 Phase 2: private→internal — 域服务扩展经 bridge?.get(...) reach-through HTTP infra。
    func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        IdentityService.applyIdentityHeaders(to: &request)
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

    // ARCH-1 Phase 2: private→internal — 域服务扩展经 bridge?.post(...) reach-through HTTP infra。
    func post<T: Decodable>(_ path: String, body: [String: Any]? = nil, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        IdentityService.applyIdentityHeaders(to: &request)
        if let body = body {
            // ERR-8 (审计product-0906 P3): 旧 try? 静默 nil body → 空 body 发出, 服务端 400 难定位。
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                docBridgeLog.error("request \(path, privacy: .public) body serialize failed: \(error.localizedDescription, privacy: .public)")
                completion(.failure(error))
                return
            }
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

    // ARCH-1 Phase 2: private→internal — 域服务扩展经 bridge?.put(...) reach-through HTTP infra。
    func put<T: Decodable>(_ path: String, body: [String: Any], completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        IdentityService.applyIdentityHeaders(to: &request)
        // ERR-8 (审计product-0906 P3): 旧 try? 静默 nil body。改 do/catch 显式失败。
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            docBridgeLog.error("PUT \(path, privacy: .public) body serialize failed: \(error.localizedDescription, privacy: .public)")
            completion(.failure(error))
            return
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

    // ARCH-1 Phase 2: private→internal — 域服务扩展经 bridge?.delete(...) reach-through HTTP infra。
    func delete<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(NSError(domain: "DocBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = authToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        IdentityService.applyIdentityHeaders(to: &request)
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

    // ARCH-1 Phase 2: private→internal — 域服务扩展经 bridge?.handleError(...) 汇入中央错漏斗 (协调器留此)。
    func handleError(_ error: Error, context: String) {
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

    // ARCH-1 Phase 2: checkHealth 行为已迁 DocHealthService.swift (extension DocHealthState +
    //   extension DocBridge stub)。scheduleReconnect 留此 (handleError 协调器调)。

    // ARCH-1 Phase 2: Library 行为已迁 DocLibraryService.swift (extension DocLibraryState +
    //   extension DocBridge stub)。旧 Books/Chapters/Pages/Tags 方法体已删, call site 经 stub 零改。

    // MARK: - Graph
    // ARCH-1 Phase 4 (audit-product-0907 P2-2): fetchGraph 迁入 DocGraphService.swift (DocBridge 留 1 行 stub)。

    // MARK: - Versions
    // ARCH-1 Phase 3 (audit-product-0907 P2-2): fetchVersions/createVersion/fetchDiff 迁入
    // DocVersionService.swift (DocBridge 留 1 行 stub)。restoreVersion 留此 (协调器: 成功后回填页面)。

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
    // ARCH-1 Phase 3 (audit-product-0907 P2-2): fetchWorkflows/runWorkflow/fetchWorkflowRuns + Workflow CRUD
    // (createWorkflow/deleteWorkflow/fetchWorkflowDetail/seedWorkflows/fetchPageWorkflowStatus/
    // fetchPageTransitions/executeTransition) 迁入 DocWorkflowService.swift (DocBridge 留 1 行 stub)。

    // MARK: - Templates
    // ARCH-1 Phase 3 (audit-product-0907 P2-2): fetchTemplates 迁入 DocTemplateService.swift (DocBridge
    //   留 1 行 stub)。instantiateTemplate 留此 (协调器: 成功后写 libraryState.pages, 跨域)。

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
    // ARCH-1 Phase 3 (audit-product-0907 P2-2): checkOfficeStatus/createOfficeDocument 迁入
    //   DocOfficeService.swift (DocBridge 留 1 行 stub)。importOfficeDocument 留此 (协调器: 成功后写
    //   libraryState.pages, 跨域)。

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
        IdentityService.applyIdentityHeaders(to: &request)
        // ERR-8 (审计product-0906 P3): 旧 try? 静默 nil body → 空 body POST, 服务端 400 难定位。
        // 此处返回 URLRequest 无 completion 回调, 序列化失败仅日志告警 + 留空 body (调用方经 HTTP 错误发现)。
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            docBridgeLog.error("buildCopilotRequest body serialize failed: \(error.localizedDescription, privacy: .public)")
        }
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
    // ARCH-1 Phase 4 (audit-product-0907 P2-2): ragEnhancedQuery/reindexPage 迁入 DocRAGService.swift;
    //   addPageLink 迁入 DocGraphService.swift (页面链接 = 图边)。DocBridge 留 1 行 stub。RAGResponse
    //   struct 留此 (类型非状态, DocRAGService 引用 DocBridge.RAGResponse)。

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
    // ARCH-1 Phase 3 (audit-product-0907 P2-2): exportOffice/previewOffice/mergeOffice/importOfficeDir/
    //   executeOfficeCommand 迁入 DocOfficeService.swift (DocBridge 留 1 行 stub)。

    // MARK: - Template CRUD
    // ARCH-1 Phase 3 (audit-product-0907 P2-2): createTemplate/updateTemplate/deleteTemplate/
    //   fetchTemplateVariables 迁入 DocTemplateService.swift (DocBridge 留 1 行 stub)。

    // MARK: - Workflow CRUD
    // ARCH-1 Phase 3 (audit-product-0907 P2-2): Workflow CRUD (createWorkflow/deleteWorkflow/
    //   fetchWorkflowDetail/seedWorkflows/fetchPageWorkflowStatus/fetchPageTransitions/executeTransition)
    //   迁入 DocWorkflowService.swift (DocBridge 留 1 行 stub)。

    // MARK: - Files
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchFiles/uploadFile(pageId)/deleteFile 迁入
    //   DocSocialService.swift (DocBridge 留 1 行 stub)。@Published files 现属 DocSocialState。

    // MARK: - Comments
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchComments/createComment/deleteComment 迁入
    //   DocSocialService.swift (DocBridge 留 1 行 stub)。@Published comments 现属 DocSocialState。

    // MARK: - Favorites
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchFavorites/addFavorite/removeFavorite 迁入
    //   DocSocialService.swift (DocBridge 留 1 行 stub)。@Published favorites 现属 DocSocialState。

    // MARK: - Activity
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchActivity/recordActivity 迁入 DocSocialService.swift
    //   (DocBridge 留 1 行 stub)。@Published activities 现属 DocSocialState。

    // MARK: - RAG Extended
    // ARCH-1 Phase 4 (audit-product-0907 P2-2): reindexAll/fetchChunks/graphSearch 迁入 DocRAGService.swift;
    //   fetchGraphNode 迁入 DocGraphService.swift。DocBridge 留 1 行 stub。

    // MARK: - Auth

    // ARCH-1 Phase 2: authSetup/authLogin/authRefresh/authLogout 已迁 DocAuthService.swift (extension
    //   DocAuthState + extension DocBridge stub)。restoreAuth/verifyToken 留此 (协调器, 编排 + 跨 /api/workspaces)。

    func restoreAuth() {
        if authToken != nil {
            docBridgeLog.info("restoreAuth: token found, verifying via /api/auth/me")
            verifyToken()
        } else {
            // SEC-3/OPS-8 (审计product-0906 P1): 不再用硬编码默认账号 admin@fusion.local/admin123
            // 静默自动登录 (供应链默认凭证风险 + 上游 issue 待修)。改为提示用户手动登录。
            docBridgeLog.warning("restoreAuth: no token, require manual login (no hardcoded default creds)")
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.authError = "请登录 Fusion Doc 账号"
            }
        }
    }

    private func verifyToken() {
        get("/api/workspaces") { [weak self] (result: Result<[DocWorkspace], Error>) in
            switch result {
            case .success:
                docBridgeLog.info("restoreAuth: token still valid")
                DispatchQueue.main.async { self?.isAuthenticated = true; self?.authError = nil }
            case .failure(let error):
                // SEC-3: token 失效不再自动用默认账号重登, 提示手动登录。
                docBridgeLog.warning("restoreAuth: token invalid (\(error.localizedDescription)), require manual login")
                DispatchQueue.main.async {
                    self?.isAuthenticated = false
                    self?.authError = "登录已失效，请重新登录"
                }
            }
        }
    }

    // MARK: - Workspace CRUD

    // ARCH-1 Phase 2: fetchWorkspaces/createWorkspace/updateWorkspace/deleteWorkspace 已迁
    //   DocWorkspaceService.swift (extension DocWorkspaceState + extension DocBridge stub)。

    // MARK: - Users
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchUsers/updateUser/deleteUser 迁入 DocAdminService.swift
    //   (DocBridge 留 1 行 stub)。@Published users 现属 DocAdminState。

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
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchBranding/updateBranding 迁入 DocAdminService.swift
    //   (DocBridge 留 1 行 stub)。@Published branding 现属 DocAdminState。

    // MARK: - Theme CRUD
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchThemes/createTheme/deleteTheme 迁入 DocAdminService.swift
    //   (DocBridge 留 1 行 stub)。@Published themes 现属 DocAdminState。

    // MARK: - Vocabulary CRUD
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchVocabulary/createVocabulary/deleteVocabulary 迁入
    //   DocAdminService.swift (DocBridge 留 1 行 stub)。@Published vocabulary 现属 DocAdminState。

    // MARK: - Webhooks CRUD
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchWebhooks/createWebhook/deleteWebhook/testWebhook 迁入
    //   DocAdminService.swift (DocBridge 留 1 行 stub)。@Published webhooks 现属 DocAdminState。

    // MARK: - Metadata
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchMetadata/setMetadata/deleteMetadata 迁入
    //   DocAdminService.swift (DocBridge 留 1 行 stub)。无 @Published (metadata 临时态, stateless)。

    // MARK: - System
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchSystemInfo/fetchSystemConfig/updateSystemConfig 迁入
    //   DocAdminService.swift (DocBridge 留 1 行 stub)。@Published systemInfo/systemConfig 现属 DocAdminState。

    // MARK: - File Upload
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): uploadFile(fileData multipart) 迁入 DocSocialService.swift
    //   (DocBridge 留 1 行 stub)。无 @Published 写 (仅返 DocFileUpload)。reach-through: baseURL/session/
    //   authToken + IdentityService + httpStatusError。ERR-2 语义化错误保留。

    // MARK: - Export
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): exportBook/fetchExportStatus 迁入 DocAdminService.swift
    //   (DocBridge 留 1 行 stub)。@Published exportJobs 现属 DocAdminState。

    // MARK: - RAG Basic
    // ARCH-1 Phase 4 (audit-product-0907 P2-2): buildRAGIndex/fetchRAGStatus/clearRAGIndex/embedRAGContent
    //   迁入 DocRAGService.swift; graphSemanticSearch/graphTraverse/graphCluster 迁入 DocGraphService.swift。
    //   DocBridge 留 1 行 stub。

    // MARK: - Notifications
    // ARCH-1 Phase 5 (audit-product-0907 P2-2): fetchNotifications/markNotificationRead/markAllNotificationsRead
    //   迁入 DocAdminService.swift (DocBridge 留 1 行 stub)。@Published notifications 现属 DocAdminState。

    // MARK: - Collaboration (WebSocket — pending upstream #22)
    // ARCH-1 Phase 4 (audit-product-0907 P2-2): connectCollab/disconnectCollab/sendCollabUpdate 迁入
    //   DocCollabService.swift (DocBridge 留 1 行 stub)。collabConnected/collabUsers/collabTask 已迁
    //   DocCollabState。WS 基础设施 reach-through: bridge?.baseURL/session/authToken。
}
