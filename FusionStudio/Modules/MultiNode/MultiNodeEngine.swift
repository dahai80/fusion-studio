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
    @Published var isConnected: Bool = false
    @Published var lastError: String?

    private let baseURL: String
    private let session: URLSession
    private var pollTimers: [Timer] = []

    init(baseURL: String = "http://127.0.0.1:9753") {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        self.session = URLSession(configuration: config)
    }

    // MARK: - Polling

    func startPolling() {
        engineLog.info("MultiNode polling started")
        schedulePoll(interval: 2.0) { [weak self] in
            self?.fetchClusterStats()
            self?.fetchNodes()
        }
        schedulePoll(interval: 3.0) { [weak self] in
            self?.fetchTasks()
        }
        schedulePoll(interval: 10.0) { [weak self] in
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

    private func schedulePoll(interval: TimeInterval, action: @escaping () -> Void) {
        action()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in action() }
        pollTimers.append(timer)
    }

    // MARK: - GET endpoints

    func fetchClusterStats() {
        get("/api/v1/cluster/stats") { [weak self] (result: Result<V1ClusterStatsResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.clusterStats = ClusterStats.from(resp)
                    self?.isConnected = true
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
                    self?.isConnected = true
                }
            case .failure(let err):
                self?.handleError(err, context: "nodes")
            }
        }
    }

    func fetchTasks() {
        get("/api/tasks") { [weak self] (result: Result<TaskListResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.tasks = resp.tasks
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

    func removeNode(nodeId: String) async throws {
        try await delete("/api/nodes/\(nodeId)")
        fetchNodes()
        fetchClusterStats()
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
        let (data, _) = try await session.data(from: url)
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

    // MARK: - Routing

    func fetchRoutingSummary(completion: @escaping (Result<RoutingSummary, Error>) -> Void) {
        get("/api/routing/summary") { result in completion(result) }
    }

    // MARK: - KV Cache (Master)

    func findKVCache(modelName: String, completion: @escaping (Result<KVCacheEntry, Error>) -> Void) {
        get("/api/kv/find/\(modelName)") { result in completion(result) }
    }

    // MARK: - Agent Server (port 9755)

    func fetchAgentKVStats(agentURL: String = "http://127.0.0.1:9755", completion: @escaping (Result<KVStatsResponse, Error>) -> Void) {
        guard let url = URL(string: "\(agentURL)/api/kv/stats") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        session.dataTask(with: url) { data, _, error in
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

    func fetchAgentHardware(agentURL: String = "http://127.0.0.1:9755", completion: @escaping (Result<AgentHardwareInfo, Error>) -> Void) {
        guard let url = URL(string: "\(agentURL)/api/hardware") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        session.dataTask(with: url) { data, _, error in
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

    func checkAgentHealth(agentURL: String = "http://127.0.0.1:9755", completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(agentURL)/api/health") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        session.dataTask(with: url) { data, _, error in
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

    func agentKVLookup(modelName: String, promptHash: String, agentURL: String = "http://127.0.0.1:9755", completion: @escaping (Result<KVCacheEntry, Error>) -> Void) {
        guard let url = URL(string: "\(agentURL)/api/kv/lookup") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

    func agentKVTransfer(cacheId: String, targetNode: String, agentURL: String = "http://127.0.0.1:9755", completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(agentURL)/api/kv/transfer") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

    func agentKVWarm(modelName: String, prompts: [String], agentURL: String = "http://127.0.0.1:9755", completion: @escaping (Result<Int, Error>) -> Void) {
        guard let url = URL(string: "\(agentURL)/api/kv/warm") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["model_name": modelName, "prompts": prompts]
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
        session.dataTask(with: url) { data, response, error in
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
        _ = try await session.data(for: request)
    }

    private func handleError(_ error: Error, context: String) {
        let msg = error.localizedDescription
        engineLog.error("MultiNode error [\(context)]: \(msg)")
        DispatchQueue.main.async { [weak self] in
            self?.lastError = "\(context): \(msg)"
            if msg.contains("connect") || msg.contains("refused") {
                self?.isConnected = false
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

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效 URL"
        case .noData: return "无数据返回"
        }
    }
}
