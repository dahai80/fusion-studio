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
    // 审计0830 P1-调度-4: 旧版单次 master 快照判定脑裂, 瞬态抖动 (一次 fetch 拿到 stale 双 master) 误报。
    //   改连续 N 轮确认才置位, 恢复 (≤1 master) 立即清零复位。stored @Published 替纯计算属性 (需跨轮状态)。
    @Published var splitBrainDetected: Bool = false
    private var splitBrainConfirmCount: Int = 0
    private let splitBrainConfirmThreshold: Int = 2

    // F-A13: 重复执行检测 (客户端可做项)。同一 task assignedNodes>=2 且 running 且 mode!=data_parallel
    // → 疑似网络抖动致 submit 重复提交, 两节点跑同一份未分片输入。data_parallel 多节点 = 合法分片不告警。
    // 真因缺 idempotency key + pending 队列需后端 (#23/#31 已提), 客户端此告警仅 UI 可见性止血。
    @Published var duplicateExecutionTaskIds: [String] = []
    var duplicateExecutionDetected: Bool { !duplicateExecutionTaskIds.isEmpty }

    // F-R6/F-R10: 连续失败计数 + 降级阈值。单次网络抖动不计 disconnected, 连续 N 轮失败才置离线。
    // 审计0827 §3.5 (P2): 4 路 poll 共享单一 consecutiveFailures, 交叉复位致降级失真
    // (node_loads 偶发成功复位 → 其余 3 路持续失败被掩盖, 计数永不达 3)。
    // 改 per-context 计数, 任一路达阈值即降级; backoff 取最差路值避免一路快一路慢。
    private var consecutiveFailuresByContext: [String: Int] = [:]
    private let maxConsecutiveFailures: Int = 3
    private var worstConsecutiveFailures: Int {
        consecutiveFailuresByContext.values.max() ?? 0
    }
    // F-R10: 单飞保护。慢响应时 Timer 下一 tick 重复 fire 同一 fetch 致请求风暴, in-flight 跳过。
    private var inflightFetches: Set<String> = []
    private let inflightLock = NSLock()

    // 审计0830 P1-调度-5: effectiveStatus 无滞后, 节点心跳抖动 → 状态频繁切换 (online↔offline)。
    //   engine 维护 per-node 连续 offline 计数, 达阈值 K 才确认 offline (决策点用 confirmedOffline)。
    //   model 的 effectiveStatus 仍即时 (UI 即时反馈), engine 决策 (retry/eligibility) 用滞后值防抖。
    private var nodeOfflineStreak: [String: Int] = [:]
    private let offlineConfirmThreshold: Int = 2

    // 审计0830 P1-调度-5: 决策点 (retry/eligibility) 用滞后确认, 非 model 即时 effectiveStatus。
    //   未知节点 (streak 无记录, 0) 默认即时状态: 避免新加入节点首轮 fetch 未到被误判健康。
    private func confirmedOffline(nodeId: String) -> Bool {
        let streak = nodeOfflineStreak[nodeId] ?? 0
        if streak >= offlineConfirmThreshold { return true }
        guard let n = nodes.first(where: { $0.id == nodeId }) else { return true }
        return n.effectiveStatus == .offline
    }

    // F-A7: init 阶段 let 快照 baseURL/agentBaseURL/authToken → 改计算属性实时读 FusionConfig.shared。
    // FusionConfig host/port/token 全 @AppStorage 可运行时改, 但旧 let 快照让 engine 永远拿旧值,
    // 设置面板/WelcomeView/env 改后 engine 仍连旧地址旧 token, 与 IPCMultiNodeMethods 实时读口径打架。
    // 保留 init 显式 override (测试/注入), 仅 override 存 stored, 默认 path 走计算属性实时读。
    private let overrideBaseURL: String?
    private let overrideAgentBaseURL: String?
    private let overrideAuthToken: String?
    private let session: URLSession
    private var pollTimers: [Timer] = []

    private var baseURL: String { overrideBaseURL ?? FusionConfig.shared.multiNodeBaseURL }
    private var agentBaseURL: String { overrideAgentBaseURL ?? FusionConfig.shared.multiNodeAgentBaseURL }
    private var authToken: String { overrideAuthToken ?? FusionConfig.shared.multiNodeResolvedToken }

    init(baseURL: String? = nil, agentBaseURL: String? = nil, authToken: String? = nil) {
        self.overrideBaseURL = baseURL
        self.overrideAgentBaseURL = agentBaseURL
        self.overrideAuthToken = authToken
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
        // F-A9: App 级生命周期调用 (scenePhase active), 多叶子 View onAppear 不再各自调。
        // 幂等: 已有 timer 在跑则跳过, 防重复 schedule 致请求风暴。
        if !pollTimers.isEmpty {
            engineLog.info("MultiNode polling already running, skip")
            return
        }
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
        // F-R10: 指数退避轮询。失败时 interval × 2^min(consecutiveFailures,5), 封顶 60s; 成功复位 base。
        // 单发递归 Timer 每轮重算 delay (固定 repeats Timer 无法动态调 interval)。单飞保护防慢响应风暴。
        var runOnce: (() -> Void)?
        runOnce = { [weak self] in
            guard let self = self else { return }
            self.inflightLock.lock()
            let already = self.inflightFetches.contains(label)
            if !already { self.inflightFetches.insert(label) }
            self.inflightLock.unlock()
            guard !already else {
                engineLog.debug("Poll skip (in-flight): \(label)")
                self.reschedulePoll(interval: interval, label: label, action: action, runOnce: runOnce!)
                return
            }
            action()
            self.inflightLock.lock()
            self.inflightFetches.remove(label)
            self.inflightLock.unlock()
            self.reschedulePoll(interval: interval, label: label, action: action, runOnce: runOnce!)
        }
        action()
        reschedulePoll(interval: interval, label: label, action: action, runOnce: runOnce!)
    }

    private func reschedulePoll(interval: TimeInterval, label: String, action: @escaping () -> Void, runOnce: @escaping () -> Void) {
        // F-R10: delay = base × 2^min(consecutiveFailures,5), 封顶 60s。consecutiveFailures=0 复位 base。
        // 审计0827 §3.5: 取 worstConsecutiveFailures (4 路最差值) 避免单路复位让全局 backoff 立归 base。
        let backoff = TimeInterval(min(worstConsecutiveFailures, 5))
        let delay = min(interval * pow(2.0, backoff), 60.0)
        if delay > interval {
            engineLog.info("Poll backoff \(label): \(interval)s -> \(Int(delay))s (failures=\(self.worstConsecutiveFailures))")
        }
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            runOnce()
        }
        // 审计0827 §2.3 (P1): pollTimers 单发 timer 已 fire (isValid=false) 仍留数组,
        // 每轮 +1 无 prune, 长跑累积 (4 pollers × N cycles)。append 前剔失效项保数组紧致。
        pollTimers = pollTimers.filter { $0.isValid }
        pollTimers.append(timer)
    }

    // MARK: - GET endpoints

    // F-R6: 成功路径重置失败状态。fetch 成功即清该路 stale + 该路连续失败计数, 恢复 online。
    // 审计0827 §3.5: 按 context 复位, 非全局清零 — 避免交叉复位掩盖其余持续失败路径。
    private func resetFailureState(context: String) {
        nodesStale = false
        consecutiveFailuresByContext[context] = 0
        // 任一路成功即认为集群可达; 离线态由 handleError 按各路独立判定。
        if !isConnected { isConnected = true }
    }

    func fetchClusterStats() {
        get("/api/v1/cluster/stats") { [weak self] (result: Result<V1ClusterStatsResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.clusterStats = ClusterStats.from(resp)
                    self?.resetFailureState(context: "cluster_stats")
                    self?.lastError = nil
                }
            case .failure(let error):
                self?.handleError(error, context: "cluster_stats")
            }
        }
    }

    func fetchNodes() {
        get("/api/nodes") { [weak self] (result: Result<NodeListResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async {
                    self?.nodes = resp.nodes
                    self?.resetFailureState(context: "nodes")
                    // F-A11: 检测多 master 脑裂, 日志告警 (UI 侧 ClusterTopologyView 展示 banner)。
                    // 审计0830 P1-调度-4: 连续 N 轮 >1 master 才确认脑裂, 瞬态抖动不误报; ≤1 立即复位。
                    let masterCount = resp.nodes.filter { $0.isMaster }.count
                    if masterCount > 1 {
                        self?.splitBrainConfirmCount += 1
                        if self?.splitBrainDetected == false && (self?.splitBrainConfirmCount ?? 0) >= (self?.splitBrainConfirmThreshold ?? 2) {
                            self?.splitBrainDetected = true
                            engineLog.error("F-A11 split-brain confirmed: \(masterCount) masters across \(self?.splitBrainConfirmCount ?? 0) rounds — writes blocked")
                        }
                    } else {
                        if self?.splitBrainDetected == true {
                            engineLog.info("F-A11 split-brain resolved (≤1 master), unblocking writes")
                        }
                        self?.splitBrainConfirmCount = 0
                        self?.splitBrainDetected = false
                    }
                    // 审计0830 P1-调度-5: per-node offline 连续计数, 供 confirmedOffline 滞后决策。
                    if let self = self {
                        for n in resp.nodes {
                            if n.effectiveStatus == .offline {
                                self.nodeOfflineStreak[n.id, default: 0] += 1
                            } else {
                                self.nodeOfflineStreak[n.id] = 0
                            }
                        }
                    }
                }
            case .failure(let error):
                self?.handleError(error, context: "nodes")
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
                    // 审计0902 A5 (P2): tasks 全量替换无 cap, 后端返 >500 则绕过 taskSubmit LRU cap 500。
                    //   cap 500 与单机 task 列表一致, 超限只保前 500 (按后端返回序, 通常近时间序)。
                    var fetched = resp.tasks
                    if fetched.count > 500 {
                        fetched = Array(fetched.prefix(500))
                    }
                    self?.tasks = fetched
                    self?.resetFailureState(context: "tasks")
                    self?.detectDuplicateExecution()
                }
            case .failure(let error):
                self?.handleError(error, context: "tasks")
            }
        }
    }

    // F-A13: 扫 tasks 找疑似重复执行 (assignedNodes>=2 && running && mode!=data_parallel)。
    // data_parallel 多节点 = 合法分片; pipeline/inference 单节点意图, 多节点 = 疑似 submit 重复。
    private func detectDuplicateExecution() {
        let dups = tasks.filter { task in
            task.assignedNodes.count >= 2 &&
            task.status == .running &&
            task.mode != "data_parallel"
        }.map { $0.id }
        if dups != duplicateExecutionTaskIds {
            duplicateExecutionTaskIds = dups
            if !dups.isEmpty {
                engineLog.error("F-A13 suspected duplicate execution: tasks=\(dups) (>=2 running nodes, mode!=data_parallel)")
            } else {
                engineLog.info("F-A13 duplicate execution cleared")
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
            case .failure(let error):
                engineLog.error("Failed to fetch metrics for \(nodeId): \(error.localizedDescription)")
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
            case .failure(let error):
                completion(.failure(error))
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
                    // 审计0827 §3.5: health 路 success 复位其 context 失败计数。
                    self?.consecutiveFailuresByContext["health"] = 0
                }
            case .failure(let error):
                self?.handleError(error, context: "health")
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

    func submitTask(name: String, mode: String, modelName: String, priority: Int = 5, requiredCapability: String? = nil, excludeNodes: [String]? = nil) async throws -> [String: Any] {
        try assertNoSplitBrain()
        var body: [String: Any] = ["name": name, "mode": mode, "model_name": modelName, "priority": priority]
        if let cap = requiredCapability { body["required_capability"] = cap }
        // 审计0830 P1-调度-3: retryTask 透传 exclude_nodes 含原失败节点, 后端排除则不重命中同一故障节点。
        //   后端 submit 端点当前可能忽略此字段 (上游缺口), 客户端传递为前置; 后端支持后即生效, 无害。
        if let ex = excludeNodes, !ex.isEmpty { body["exclude_nodes"] = ex }
        let result = try await post("/api/tasks/submit", body: body)
        fetchTasks()
        fetchClusterStats()
        return result
    }

    // F-A12: 失败 task 重试需带原 task 的 assignedNodes 黑名单 + 原 requiredCapability/priority。
    // 后端 submit 端点无 exclude_nodes 字段 (fusion-multi-nodes 上游缺口) → 客户端止血:
    // 保留原参数 + assignedNodes 全 offline 则阻断重试 (防 "无限重试同一个坑"), 健康则重新 submit。
    func retryTask(_ task: ClusterTask) async throws -> [String: Any] {
        try assertNoSplitBrain()
        let assigned = task.assignedNodes
        // 审计0830 P1-调度-5: 用 confirmedOffline 滞后确认, 瞬态抖动不误判全 offline 阻断重试。
        let offlineAssigned = assigned.filter { confirmedOffline(nodeId: $0) }
        if !assigned.isEmpty && offlineAssigned.count == assigned.count {
            engineLog.error("F-A12 retry blocked: all assigned nodes offline. task=\(task.id) assigned=\(assigned)")
            throw EngineError.retryNoHealthyNode
        }
        let origPriority = task.priority ?? 5
        let origCap = task.requiredCapability
        engineLog.info("F-A12 retry: task=\(task.id) assigned=\(assigned) offline=\(offlineAssigned) priority=\(origPriority) cap=\(origCap ?? "nil")")
        // 审计0830 P1-调度-3: 透传 offlineAssigned 作 exclude_nodes, 后端排除则重试不命中同一故障节点。
        return try await submitTask(
            name: task.name, mode: task.mode, modelName: task.modelName,
            priority: origPriority, requiredCapability: origCap,
            excludeNodes: offlineAssigned
        )
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
            case .failure(let error):
                completion(.failure(error))
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
            if let error = error { completion(.failure(error)); return }
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
            case .failure(let error):
                completion(.failure(error))
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

    // MARK: - Agent Server (port = cfg.multiNodeAgentPort, 默认 11458, 原 11445 迁出)

    func fetchAgentKVStats(completion: @escaping (Result<KVStatsResponse, Error>) -> Void) {
        guard let url = URL(string: "\(agentBaseURL)/api/kv/stats") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        authHeaders(&req)
        session.dataTask(with: req) { data, _, error in
            if let error = error { completion(.failure(error)); return }
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
            if let error = error { completion(.failure(error)); return }
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
            if let error = error { completion(.failure(error)); return }
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
            if let error = error { completion(.failure(error)); return }
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
            if let error = error { completion(.failure(error)); return }
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
        // 审计0827 §3.6 (P2): 无 (model) 去重, 并发 warm (多 agent / 重复点按钮) → 重复 POST
        // → MLX 后端同模型重复分配 KV cache 显存翻倍, 8-16 节点触发 GPU OOM。
        // 按 model 名单飞: in-flight 期间同 model 跳过, 回调完成才释放。
        // 审计0830 P1-调度-7: 旧 [weak self] 回调若 self 已 nil → releaseInflight no-op → key 永留 inflightFetches,
        //   后续同 model warm 恒被 skip = 永久 hang。改强引用 self 至回调结束 (engine 随 app 生命周期, 无提早释放风险),
        //   且全路径 (URL 构造失败 / 网络错误 / 解码失败) 经统一 release 闭包释放, 无遗漏路径。
        let inflightKey = "kv_warm:\(modelName)"
        inflightLock.lock()
        if inflightFetches.contains(inflightKey) {
            inflightLock.unlock()
            engineLog.warning("agentKVWarm skip (in-flight): \(modelName)")
            completion(.failure(EngineError.duplicateRequest))
            return
        }
        inflightFetches.insert(inflightKey)
        inflightLock.unlock()
        // 统一释放闭包: 任意出口 (含 early-return) 都经此, 保证 lock 不泄漏。
        // 强引用 self: 回调持有 self 至网络完成才释放, 避免 weak-nil 跳过 releaseInflight 致 key 永留。
        let release = { self.releaseInflight(inflightKey) }
        guard let url = URL(string: "\(agentBaseURL)/api/kv/warm") else {
            release()
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(&req)
        let body: [String: Any] = ["model_name": modelName, "prompts": prompts]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        // 强引用 self: 回调持有 self 至网络完成才释放, 避免 weak-nil 路径跳过 releaseInflight。
        session.dataTask(with: req) { data, _, error in
            release()
            if let error = error { completion(.failure(error)); return }
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

    private func releaseInflight(_ key: String) {
        inflightLock.lock()
        inflightFetches.remove(key)
        inflightLock.unlock()
    }

    // MARK: - Generic HTTP helpers

    private func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var request = URLRequest(url: url)
        authHeaders(&request)
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error)); return
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
            // 审计0827 §3.5: 按 context 独立计数, 单路失败达阈值即降级 (非全局累计),
            // 避免交叉复位让持续失败路径永不到阈值。
            let prev = self.consecutiveFailuresByContext[context, default: 0]
            self.consecutiveFailuresByContext[context] = prev + 1
            if (prev + 1) >= self.maxConsecutiveFailures {
                self.isConnected = false
                engineLog.warning("MultiNode disconnected: context=\(context) failures=\(prev + 1)")
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
    case retryNoHealthyNode
    case duplicateRequest

    var errorDescription: String? {
        switch self {
        case .invalidURL: return I18nManager.shared.t(.mn_err_invalidURL)
        case .noData: return I18nManager.shared.t(.mn_err_noData)
        case .splitBrain: return I18nManager.shared.t(.mn_err_splitBrain)
        case .retryNoHealthyNode: return I18nManager.shared.t(.mn_err_retryNoHealthyNode)
        case .duplicateRequest: return I18nManager.shared.t(.mn_err_duplicateRequest)
        }
    }
}
