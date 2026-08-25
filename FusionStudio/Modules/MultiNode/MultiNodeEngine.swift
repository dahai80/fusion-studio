import Foundation
import Combine
import os.log

private let engineLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeEngine")

class MultiNodeEngine: ObservableObject {
    @Published var clusterStats: ClusterStats = .empty
    @Published var nodes: [ClusterNode] = []
    @Published var tasks: [ClusterTask] = []
    @Published var alerts: [AlertItem] = []
    @Published var suggestions: [OptimizationSuggestion] = []
    @Published var autoscalerConfig: AutoscalerConfig = .default
    @Published var nodeMetrics: [String: LoadMetrics] = [:]
    @Published var nodeMetricsRaw: [String: NodeMetricsResponse] = [:]
    @Published var clusterSyncStatus: ClusterSyncStatus?
    @Published var nodeLoads: [String: NodeLoadReport] = [:]
    @Published var modelManifests: [String: ModelManifest] = [:]
    @Published var pendingNodes: [PendingNode] = []
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    // F-R6: 数据可能过期标志。fetch 失败时置 true (保留旧 nodes 不清空), 成功时清 false。
    // UI 据 stale 显示"数据可能过期"而非惊吓性"集群全没了"。连续失败达阈值才降级 isConnected。
    @Published var nodesStale: Bool = false

    // F-A11: 脑裂检测。>1 master = 网络分区两区各选 master, 客户端不应静默并排展示,
    // 须 critical alert + 阻断写操作 (remove/approve/migrate) 直到 quorum 恢复。
    var splitBrainDetected: Bool { nodes.filter { $0.isMaster }.count > 1 }

    // F-R6/F-R10: 连续失败计数 + 降级阈值。单次网络抖动不计 disconnected, 连续 N 轮失败才置离线。
    private var consecutiveFailures: Int = 0
    private let maxConsecutiveFailures: Int = 3
    // F-R10: 单飞保护。慢响应时 Timer 下一 tick 重复 fire 同一 fetch 致请求风暴, in-flight 跳过。
    private var inflightFetches: Set<String> = []
    private let inflightLock = NSLock()

    private let baseURL: String
    private let agentBaseURL: String
    private let authToken: String
    private let session: URLSession
    private var pollTimers: [Timer] = []

    init(baseURL: String? = nil, agentBaseURL: String? = nil, authToken: String? = nil) {
        let cfg = FusionConfig.shared
        self.baseURL = baseURL ?? cfg.multiNodeBaseURL
        self.agentBaseURL = agentBaseURL ?? cfg.multiNodeAgentBaseURL
        self.authToken = authToken ?? cfg.multiNodeResolvedToken
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        self.session = URLSession(configuration: config)
    }

    /// 给 URLRequest 附加 Bearer token（cluster 鉴权，参照 ModelHubAPIClient 模式）。
    private func authHeaders(_ request: inout URLRequest) {
        if !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
    }

    // MARK: - Polling

    func startPolling() {
        engineLog.info("MultiNode polling started")
        schedulePoll(interval: 2.0, label: "stats_nodes") { [weak self] in
            self?.fetchClusterStats()
            self?.fetchNodes()
        }
        schedulePoll(interval: 3.0, label: "tasks_sync") { [weak self] in
            self?.fetchTasks()
            self?.fetchClusterSyncStatus()
            self?.fetchPendingNodes()
        }
        schedulePoll(interval: 5.0, label: "node_loads") { [weak self] in
            self?.fetchAllNodeLoads()
        }
        schedulePoll(interval: 10.0, label: "suggestions_alerts") { [weak self] in
            self?.fetchSuggestions()
            self?.fetchAlerts()
        }
        fetchAutoscalerConfig()
    }

    func stopPolling() {
        pollTimers.forEach { $0.invalidate() }
        pollTimers.removeAll()
        engineLog.info("MultiNode polling stopped")
    }

    private func schedulePoll(interval: TimeInterval, label: String, action: @escaping () -> Void) {
        action()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // F-R10: 单飞保护。慢响应 (>interval) 时上一轮 action 未返回, 下一 tick 重复 fire 同 fetch,
            // 叠加致请求风暴 + 续体堆积。label 作 in-flight key, 在途则跳过本轮。
            guard let self = self else { return }
            self.inflightLock.lock()
            let already = self.inflightFetches.contains(label)
            if !already { self.inflightFetches.insert(label) }
            self.inflightLock.unlock()
            guard !already else {
                engineLog.debug("Poll skip (in-flight): \(label)")
                return
            }
            action()
            self.inflightLock.lock()
            self.inflightFetches.remove(label)
            self.inflightLock.unlock()
        }
        pollTimers.append(timer)
    }

    // MARK: - GET endpoints

    // F-R6: 成功路径重置失败状态。任一 fetch 成功即清 stale + 连续失败计数, 恢复 online。
    private func resetFailureState() {
        nodesStale = false
        consecutiveFailures = 0
        isConnected = true
    }

    func fetchClusterStats() {
        get("/api/v1/cluster/stats") { [weak self] (result: Result<V1ClusterStatsResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.clusterStats = ClusterStats.from(resp)
                    self?.resetFailureState()
                    self?.lastError = nil
                }
            case .failure(let err):
                self?.handleError(err, context: "cluster_stats")
            }
        }
    }

    func fetchNodes() {
        get("/api/nodes") { [weak self] (result: Result<NodeListResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.nodes = resp.nodes
                    self?.resetFailureState()
                    // F-A11: 检测多 master 脑裂, 日志告警 (UI 侧 ClusterTopologyView 展示 banner)。
                    let masterCount = resp.nodes.filter { $0.isMaster }.count
                    if masterCount > 1 {
                        engineLog.error("F-A11 split-brain detected: \(masterCount) masters present — quorum broken, writes should be blocked")
                    }
                }
            case .failure(let err):
                self?.handleError(err, context: "nodes")
            }
        }
    }

    func fetchPendingNodes() {
        get("/api/nodes/pending") { [weak self] (result: Result<PendingNodeListResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.pendingNodes = resp.pending }
            case .failure:
                engineLog.debug("Pending nodes endpoint not available")
            }
        }
    }

    func fetchTasks() {
        get("/api/tasks") { [weak self] (result: Result<TaskListResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.tasks = resp.tasks
                    self?.resetFailureState()
                }
            case .failure(let err):
                self?.handleError(err, context: "tasks")
            }
        }
    }

    func fetchNodeMetrics(nodeId: String) {
        get("/api/v1/nodes/\(nodeId)/metrics") { [weak self] (result: Result<NodeMetricsResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.nodeMetricsRaw[nodeId] = resp
                    self?.nodeMetrics[nodeId] = LoadMetrics.from(resp)
                }
            case .failure(let err):
                engineLog.error("Failed to fetch metrics for \(nodeId): \(err.localizedDescription)")
            }
        }
    }

    func fetchNodeMetrics(nodeId: String, completion: @escaping (Result<LoadMetrics, Error>) -> Void) {
        get("/api/v1/nodes/\(nodeId)/metrics") { [weak self] (result: Result<NodeMetricsResponse, Error>) in
            switch result {
            case .success(let resp):
                let metrics = LoadMetrics.from(resp)
                DispatchQueue.main.async {
                    self?.nodeMetricsRaw[nodeId] = resp
                    self?.nodeMetrics[nodeId] = metrics
                }
                completion(.success(metrics))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    func fetchTaskProgress(taskId: String, completion: @escaping (Result<TaskProgress, Error>) -> Void) {
        get("/api/v1/tasks/\(taskId)/progress") { result in completion(result) }
    }

    func fetchTaskTimeline(taskId: String, completion: @escaping (Result<TaskTimeline, Error>) -> Void) {
        get("/api/v1/tasks/\(taskId)/timeline") { result in completion(result) }
    }

    func fetchAutoscalerConfig() {
        get("/api/v1/autoscaler/config") { [weak self] (result: Result<AutoscalerConfig, Error>) in
            switch result {
            case .success(let config):
                DispatchQueue.main.async { self?.autoscalerConfig = config }
            case .failure:
                engineLog.debug("Autoscaler config not available, using default")
            }
        }
    }

    func fetchSuggestions() {
        get("/api/v1/observability/suggestions") { [weak self] (result: Result<SuggestionsResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.suggestions = resp.suggestions }
            case .failure:
                break
            }
        }
    }

    func fetchAlerts() {
        get("/api/v1/observability/alerts") { [weak self] (result: Result<AlertsResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.alerts = resp.alerts }
            case .failure:
                engineLog.debug("Alerts endpoint not available yet")
            }
        }
    }

    func checkHealth() {
        get("/api/health") { [weak self] (result: Result<HealthResponse, Error>) in
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

    // MARK: - Mutation endpoints

    // F-A11: 脑裂时阻断写操作 (remove/approve/migrate/submit), 防 removeNode 操作到另一分区 master。
    private func assertNoSplitBrain() throws {
        if splitBrainDetected {
            engineLog.error("F-A11 write blocked: split-brain active (>1 master)")
            throw EngineError.splitBrain
        }
    }

    func removeNode(nodeId: String) async throws {
        try assertNoSplitBrain()
        try await delete("/api/nodes/\(nodeId)")
        fetchNodes()
        fetchClusterStats()
    }

    func approveNode(nodeId: String, approvedBy: String = "admin") async throws {
        try assertNoSplitBrain()
        _ = try await post("/api/nodes/approve", body: ["node_id": nodeId, "approved_by": approvedBy])
        fetchPendingNodes()
        fetchNodes()
        fetchClusterStats()
    }

    func rejectNode(nodeId: String, reason: String = "") async throws {
        _ = try await post("/api/nodes/reject", body: ["node_id": nodeId, "reason": reason])
        fetchPendingNodes()
    }

    func cancelTask(taskId: String) async throws {
        _ = try await post("/api/tasks/\(taskId)/cancel", body: ["reason": "cancelled_by_user"])
        fetchTasks()
    }

    func degradeTask(taskId: String, targetModel: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let m = targetModel { body["target_model"] = m }
        _ = try await post("/api/tasks/\(taskId)/degrade", body: body)
        fetchTasks()
    }

    func migrateTask(taskId: String, targetNodeId: String) async throws {
        try assertNoSplitBrain()
        _ = try await post("/api/tasks/\(taskId)/migrate", body: ["target_node_id": targetNodeId])
        fetchTasks()
    }

    func migrateTask(taskId: String, targetNodeId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await migrateTask(taskId: taskId, targetNodeId: targetNodeId)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func submitTask(name: String, mode: String, modelName: String, priority: Int = 5, requiredCapability: String? = nil) async throws -> [String: Any] {
        try assertNoSplitBrain()
        var body: [String: Any] = ["name": name, "mode": mode, "model_name": modelName, "priority": priority]
        if let cap = requiredCapability { body["required_capability"] = cap }
        let result = try await post("/api/tasks/submit", body: body)
        fetchTasks()
        fetchClusterStats()
        return result
    }

    func updateAutoscalerConfig(_ config: AutoscalerConfig) async throws {
        let body: [String: Any] = [
            "min_nodes": config.minNodes,
            "max_nodes": config.maxNodes,
            "scale_up_threshold": config.scaleUpThreshold,
            "scale_down_threshold": config.scaleDownThreshold,
            "cooldown_seconds": config.cooldownSeconds,
        ]
        _ = try await put("/api/v1/autoscaler/config", body: body)
        fetchAutoscalerConfig()
    }

    func registerKVCache(cacheId: String, modelName: String, nodeId: String, sizeMb: Double, ttlSeconds: Int = 3600) async throws {
        let body: [String: Any] = [
            "cache_id": cacheId,
            "model_name": modelName,
            "node_id": nodeId,
            "size_mb": sizeMb,
            "ttl_seconds": ttlSeconds,
        ]
        _ = try await post("/api/kv/register", body: body)
    }

    func exportLogs() async throws -> Data {
        let url = URL(string: "\(baseURL)/api/v1/observability/logs/export")!
        var request = URLRequest(url: url)
        authHeaders(&request)
        let (data, _) = try await session.data(for: request)
        return data
    }

    func setRoutingStrategy(_ strategy: String) async throws {
        _ = try await post("/api/routing/strategy", body: ["strategy": strategy])
    }

    func joinNode(ipAddress: String, port: Int, token: String? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["ip_address": ipAddress, "port": port]
        if let t = token { body["token"] = t }
        return try await post("/api/join", body: body)
    }

    // MARK: - Cluster Sync (#74)

    func fetchClusterSyncStatus() {
        get("/api/cluster/status") { [weak self] (result: Result<ClusterSyncStatus, Error>) in
            switch result {
            case .success(let status):
                DispatchQueue.main.async { self?.clusterSyncStatus = status }
            case .failure:
                engineLog.debug("Cluster sync status not available")
            }
        }
    }

    func fetchModelManifest(modelName: String, completion: @escaping (Result<ModelManifest, Error>) -> Void) {
        get("/api/models/\(modelName)/manifest") { [weak self] (result: Result<ModelManifest, Error>) in
            switch result {
            case .success(let manifest):
                DispatchQueue.main.async { self?.modelManifests[modelName] = manifest }
                completion(.success(manifest))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    func triggerIncrementalSync(modelName: String, sourceHost: String, sourcePort: Int? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/sync/incremental") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(&request)
        let body: [String: Any] = [
            "model_name": modelName,
            "source_host": sourceHost,
            "source_port": sourcePort ?? FusionConfig.shared.multiNodePort,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: request) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                engineLog.info("Incremental sync triggered for \(modelName)")
                completion(.success(json))
            } else {
                completion(.failure(EngineError.noData))
            }
        }.resume()
    }

    func fetchNodeLoad(nodeId: String, completion: @escaping (Result<NodeLoadReport, Error>) -> Void) {
        get("/api/nodes/\(nodeId)/load") { [weak self] (result: Result<NodeLoadReport, Error>) in
            switch result {
            case .success(let report):
                DispatchQueue.main.async { self?.nodeLoads[nodeId] = report }
                completion(.success(report))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    func fetchAllNodeLoads() {
        for node in nodes where node.effectiveStatus == .online || node.effectiveStatus == .busy {
            fetchNodeLoad(nodeId: node.id) { _ in }
        }
    }

    // MARK: - Routing

    func fetchRoutingSummary(completion: @escaping (Result<RoutingSummary, Error>) -> Void) {
        get("/api/routing/summary") { result in completion(result) }
    }

    // MARK: - KV Cache (Master)

    func findKVCache(modelName: String, completion: @escaping (Result<KVCacheEntry, Error>) -> Void) {
        get("/api/kv/find/\(modelName)") { result in completion(result) }
    }

    // MARK: - Agent Server (port = cfg.multiNodeAgentPort, 默认 11445)

    func fetchAgentKVStats(completion: @escaping (Result<KVStatsResponse, Error>) -> Void) {
        guard let url = URL(string: "\(agentBaseURL)/api/kv/stats") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        authHeaders(&req)
        session.dataTask(with: req) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            do {
                let decoded = try JSONDecoder().decode(KVStatsResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchAgentHardware(completion: @escaping (Result<AgentHardwareInfo, Error>) -> Void) {
        guard let url = URL(string: "\(agentBaseURL)/api/hardware") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        authHeaders(&req)
        session.dataTask(with: req) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            do {
                let decoded = try JSONDecoder().decode(AgentHardwareInfo.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func checkAgentHealth(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(agentBaseURL)/api/health") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        authHeaders(&req)
        session.dataTask(with: req) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["status"] as? String == "ok" {
                    completion(.success(true))
                } else {
                    completion(.success(false))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func agentKVLookup(modelName: String, promptHash: String, completion: @escaping (Result<KVCacheEntry, Error>) -> Void) {
        guard let url = URL(string: "\(agentBaseURL)/api/kv/lookup") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(&req)
        let body = ["model_name": modelName, "prompt_hash": promptHash]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: req) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            do {
                let decoded = try JSONDecoder().decode(KVCacheEntry.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func agentKVTransfer(cacheId: String, targetNode: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(agentBaseURL)/api/kv/transfer") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(&req)
        let body = ["cache_id": cacheId, "target_node": targetNode]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: req) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["status"] as? String == "ok" {
                completion(.success(true))
            } else {
                completion(.success(false))
            }
        }.resume()
    }

    func agentKVWarm(modelName: String, prompts: [String], completion: @escaping (Result<Int, Error>) -> Void) {
        guard let url = URL(string: "\(agentBaseURL)/api/kv/warm") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(&req)
        let body: [String: Any] = ["model_name": modelName, "prompts": prompts]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        session.dataTask(with: req) { data, _, error in
            if let err = error { completion(.failure(err)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let warmed = json["warmed"] as? Int ?? 0
                    completion(.success(warmed))
                } else {
                    completion(.success(0))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Generic HTTP helpers

    private func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        authHeaders(&request)
        session.dataTask(with: request) { data, response, error in
            if let err = error {
                completion(.failure(err)); return
            }
            guard let data = data else {
                completion(.failure(EngineError.noData)); return
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                completion(.success(decoded))
            } catch {
                engineLog.error("Decode failed for \(path): \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    private func post(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw EngineError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func put(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw EngineError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func delete(_ path: String) async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw EngineError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        authHeaders(&request)
        _ = try await session.data(for: request)
    }

    private func handleError(_ error: Error, context: String) {
        let msg = error.localizedDescription
        engineLog.error("MultiNode error [\(context)]: \(msg)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lastError = "\(context): \(msg)"
            // F-R6: 失败不清空 nodes (保留旧数据), 仅置 stale 标志。UI 据 stale 显示"数据可能过期"。
            self.nodesStale = true
            // F-R6/F-R10: 连续失败计数。单次抖动不计 disconnected, 连续 N 轮失败才降级 isConnected。
            self.consecutiveFailures += 1
            if self.consecutiveFailures >= self.maxConsecutiveFailures {
                self.isConnected = false
                engineLog.warning("MultiNode disconnected after \(self.consecutiveFailures) consecutive failures")
            }
        }
    }

    deinit {
        stopPolling()
    }
}

struct HealthResponse: Codable {
    let status: String
    let role: String?
}

struct AlertsResponse: Codable {
    let alerts: [AlertItem]
}

enum EngineError: Error, LocalizedError {
    case invalidURL
    case noData
    case splitBrain

    var errorDescription: String? {
        switch self {
        case .invalidURL: return I18nManager.shared.t(.mn_err_invalidURL)
        case .noData: return I18nManager.shared.t(.mn_err_noData)
        case .splitBrain: return I18nManager.shared.t(.mn_err_splitBrain)
        }
    }
}
