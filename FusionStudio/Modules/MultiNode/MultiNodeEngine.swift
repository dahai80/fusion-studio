import Foundation
import Combine
import os.log

private let engineLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeEngine")

@MainActor
class MultiNodeEngine: ObservableObject {
    // ARCH-1 (PR-C1): 18 @Published 拆 10 域 ObservableObject。let 域引用 = 稳定身份,
    //   init() objectWillChange.sink 转发每域 (SwiftUI 不自动追踪嵌套 ObservableObject, P0-1 修)。
    //   18 属性经下方计算属性 get/set 转发, 62 view 读站点 0 改 (0 $binding, 计算属性不产 projectedValue)。
    //   行为按域 Phase 2-5 迁入 MultiNode<Domain>Service.swift extension。
    let clusterHealthState = MultiNodeClusterHealthState()
    let nodeState = MultiNodeNodeState()
    let taskState = MultiNodeTaskState()
    let splitBrainState = MultiNodeSplitBrainState()
    let autoscalerState = MultiNodeAutoscalerState()
    let syncState = MultiNodeSyncState()
    let kvCacheState = MultiNodeKVCacheState()
    let agentServerState = MultiNodeAgentServerState()
    let routingState = MultiNodeRoutingState()
    let pollingState = MultiNodePollingState()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Cluster Health State 转发
    var clusterStats: ClusterStats {
        get { clusterHealthState.clusterStats } set { clusterHealthState.clusterStats = newValue }
    }
    var isConnected: Bool {
        get { clusterHealthState.isConnected } set { clusterHealthState.isConnected = newValue }
    }
    var lastError: String? {
        get { clusterHealthState.lastError } set { clusterHealthState.lastError = newValue }
    }
    var nodesStale: Bool {
        get { clusterHealthState.nodesStale } set { clusterHealthState.nodesStale = newValue }
    }
    var activeMasterHost: String? {
        get { clusterHealthState.activeMasterHost } set { clusterHealthState.activeMasterHost = newValue }
    }

    // MARK: - Node State 转发
    var nodes: [ClusterNode] {
        get { nodeState.nodes } set { nodeState.nodes = newValue }
    }
    var pendingNodes: [PendingNode] {
        get { nodeState.pendingNodes } set { nodeState.pendingNodes = newValue }
    }
    var nodeMetrics: [String: LoadMetrics] {
        get { nodeState.nodeMetrics } set { nodeState.nodeMetrics = newValue }
    }
    var nodeMetricsRaw: [String: NodeMetricsResponse] {
        get { nodeState.nodeMetricsRaw } set { nodeState.nodeMetricsRaw = newValue }
    }
    var nodeLoads: [String: NodeLoadReport] {
        get { nodeState.nodeLoads } set { nodeState.nodeLoads = newValue }
    }
    var modelManifests: [String: ModelManifest] {
        get { nodeState.modelManifests } set { nodeState.modelManifests = newValue }
    }

    // MARK: - Task State 转发
    var tasks: [ClusterTask] {
        get { taskState.tasks } set { taskState.tasks = newValue }
    }
    var duplicateExecutionTaskIds: [String] {
        get { taskState.duplicateExecutionTaskIds } set { taskState.duplicateExecutionTaskIds = newValue }
    }
    var duplicateExecutionDetected: Bool { taskState.duplicateExecutionDetected }

    // MARK: - Split Brain State 转发
    var splitBrainDetected: Bool {
        get { splitBrainState.splitBrainDetected } set { splitBrainState.splitBrainDetected = newValue }
    }

    // MARK: - Autoscaler State 转发
    var autoscalerConfig: AutoscalerConfig {
        get { autoscalerState.autoscalerConfig } set { autoscalerState.autoscalerConfig = newValue }
    }
    var alerts: [AlertItem] {
        get { autoscalerState.alerts } set { autoscalerState.alerts = newValue }
    }
    var suggestions: [OptimizationSuggestion] {
        get { autoscalerState.suggestions } set { autoscalerState.suggestions = newValue }
    }

    // MARK: - Sync State 转发
    var clusterSyncStatus: ClusterSyncStatus? {
        get { syncState.clusterSyncStatus } set { syncState.clusterSyncStatus = newValue }
    }

    // Track B: 写操作前置门。connected 且无脑裂才允许 remove/approve/migrate/submit/retry/routing/autoscaler。
    // 计算属性 (非 @Published stored) — 永远反映 isConnected/splitBrainDetected 当前值, 无需手动刷新。
    var canMutate: Bool { isConnected && !splitBrainDetected }

    // B1: cap unbounded mirror dicts (periodic refresh, no order — evict arbitrary excess keys)。
    // ARCH-1 PR-C1: internal — 域 service extension 经 Self.capDict reach-through。
    internal static func capDict<K: Hashable, V>(_ dict: inout [K: V], _ max: Int) {
        if dict.count > max {
            let drop = dict.count - max
            for k in Array(dict.keys).prefix(drop) { dict.removeValue(forKey: k) }
        }
    }

    // F-A7: init 阶段 let 快照 baseURL/agentBaseURL/authToken → 改计算属性实时读 FusionConfig.shared。
    // FusionConfig host/port/token 全 @AppStorage 可运行时改, 但旧 let 快照让 engine 永远拿旧值,
    // 设置面板/WelcomeView/env 改后 engine 仍连旧地址旧 token, 与 IPCMultiNodeMethods 实时读口径打架。
    // 保留 init 显式 override (测试/注入), 仅 override 存 stored, 默认 path 走计算属性实时读。
    private let overrideBaseURL: String?
    private let overrideAgentBaseURL: String?
    private let overrideAuthToken: String?

    // Track B: TLS 会话由 ClusterTransport 统一提供 (含 TLS 委托 + 超时)。engine 不再自建 URLSession。
    // ARCH-1 PR-C1: internal — 域 service extension 经 bridge?.session reach-through。
    internal var session: URLSession { ClusterTransport.shared.session }

    internal var baseURL: String {
        if let override = overrideBaseURL { return override }
        // 审计v0.1.58 P2-2: pool 活跃端点用完整 URL (含 scheme), 非 urlString (无 scheme 致 URL 构造失败).
        // Track B: pool 优先, pool 空回退 FusionConfig 默认 (向后兼容单 master 部署)。
        if let ep = MasterPool.shared.active, let u = ep.url {
            return u.absoluteString
        }
        return FusionConfig.shared.multiNodeBaseURL
    }
    internal var agentBaseURL: String { overrideAgentBaseURL ?? FusionConfig.shared.multiNodeAgentBaseURL }
    // Track B: cluster token 走 Keychain (Task 6 迁移), 保留 override 供测试注入。
    internal var authToken: String { overrideAuthToken ?? KeychainStore.readClusterToken() ?? "" }

    // Track B: pool 驱动的 cluster URL, scheme 按 FusionConfig 默认 baseURL 推断 (http/https)。
    private var clusterURL: URL? {
        guard let ep = MasterPool.shared.active else { return nil }
        let scheme = FusionConfig.shared.multiNodeBaseURL.hasPrefix("https") ? "https" : "http"
        let base = ep.url ?? URL(string: "http://\(ep.host):\(ep.port)")!
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.scheme = scheme
        return comps?.url
    }

    init(baseURL: String? = nil, agentBaseURL: String? = nil, authToken: String? = nil) {
        self.overrideBaseURL = baseURL
        self.overrideAgentBaseURL = agentBaseURL
        self.overrideAuthToken = authToken
        clusterHealthState.bridge = self
        nodeState.bridge = self
        taskState.bridge = self
        splitBrainState.bridge = self
        autoscalerState.bridge = self
        syncState.bridge = self
        kvCacheState.bridge = self
        agentServerState.bridge = self
        routingState.bridge = self
        pollingState.bridge = self
        clusterHealthState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        nodeState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        taskState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        splitBrainState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        autoscalerState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        syncState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        kvCacheState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        agentServerState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        routingState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        pollingState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        engineLog.info("MultiNodeEngine init: 10 域 objectWillChange 转发已接线 (ARCH-1 PR-C1)")
    }

    /// Track C: 客户端幂等键。上游 fusion-multi-node #23/#31 暂忽略 X-Idempotency-Key header;
    /// 上游采纳后自动启用服务端去重。每次 submit/retry 生成新 UUID。
    static func generateIdempotencyKey() -> String {
        let key = UUID().uuidString
        engineLog.info("idempotency key generated: \(key)")
        return key
    }

    /// Track B: 写操作前置门 (UI 侧 ClusterWriteButton 共享)。canMutate=true 才允许写,
    /// 脑裂/离线时 UI 禁用按钮 + 审计 "blocked"。静态方法便于无 engine 引用的视图调用。
    static func shouldEnableWrite(canMutate: Bool) -> Bool {
        canMutate
    }

    /// 给 URLRequest 附加 Bearer token（cluster 鉴权，参照 ModelHubAPIClient 模式）。
    // ARCH-1 PR-C1: internal — 域 service extension 经 bridge?.authHeaders reach-through。
    internal func authHeaders(_ request: inout URLRequest) {
        if !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
    }

    // #77: 变更请求附 X-Leader-Token (per-leader token)。server enforce 开 + token 过期 → 409 LeaderChanged。
    //   缺 header server 放行 (灰度兼容), 故 token 未取到 (nil/空) 时不发 header, 行为同旧版。
    // ARCH-1 PR-C1: internal — 域 service extension 经 bridge?.leaderTokenHeader reach-through。
    internal func leaderTokenHeader(_ request: inout URLRequest) {
        if let token = splitBrainState.knownLeaderToken, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "X-Leader-Token")
        }
    }

    // MARK: - Polling

    func startPolling() {
        // F-A9: App 级生命周期调用 (scenePhase active), 多叶子 View onAppear 不再各自调。
        // 幂等: 已有 timer 在跑则跳过, 防重复 schedule 致请求风暴。
        // ARCH-1 PR-C1 Phase 5: coordinator — 调 8 域 fetch, 留 engine。schedulePoll 委派 pollingState。
        if !pollingState.pollTimers.isEmpty {
            engineLog.info("MultiNode polling already running, skip")
            return
        }
        engineLog.info("MultiNode polling started")
        pollingState.schedulePoll(interval: 2.0, label: "stats_nodes") { [weak self] in
            self?.fetchClusterStats()
            self?.fetchNodes()
        }
        pollingState.schedulePoll(interval: 3.0, label: "tasks_sync") { [weak self] in
            self?.fetchTasks()
            self?.fetchClusterSyncStatus()
            self?.fetchPendingNodes()
        }
        pollingState.schedulePoll(interval: 5.0, label: "node_loads") { [weak self] in
            self?.fetchAllNodeLoads()
        }
        pollingState.schedulePoll(interval: 10.0, label: "suggestions_alerts") { [weak self] in
            self?.fetchSuggestions()
            self?.fetchAlerts()
        }
        fetchAutoscalerConfig()
    }

    func stopPolling() {
        pollingState.pollTimers.forEach { $0.invalidate() }
        pollingState.pollTimers.removeAll()
        engineLog.info("MultiNode polling stopped")
    }

    // MARK: - GET endpoints (ClusterHealth + Node — Phase 2 stubs, bodies in Service files)

    // ARCH-1 PR-C1 Phase 2: resetFailureState/fetchClusterStats/checkHealth → MultiNodeClusterHealthService.
    //   fetchNodes/fetchPendingNodes/fetchNodeMetrics×2/fetchModelManifest/fetchNodeLoad/fetchAllNodeLoads/
    //   removeNode/approveNode/rejectNode/joinNode → MultiNodeNodeService. engine 留 1 行 stub 保外部签名。
    func resetFailureState(context: String) { clusterHealthState.resetFailureState(context: context) }
    func fetchClusterStats() { clusterHealthState.fetchClusterStats() }
    func fetchNodes() { nodeState.fetchNodes() }
    func fetchPendingNodes() { nodeState.fetchPendingNodes() }

    // ARCH-1 PR-C1 Phase 3: Task 域 stubs, bodies in MultiNodeTaskService.swift。
    func fetchTasks() { taskState.fetchTasks() }
    func detectDuplicateExecution() { taskState.detectDuplicateExecution() }
    func fetchNodeMetrics(nodeId: String) { nodeState.fetchNodeMetrics(nodeId: nodeId) }
    func fetchNodeMetrics(nodeId: String, completion: @escaping (Result<LoadMetrics, Error>) -> Void) {
        nodeState.fetchNodeMetrics(nodeId: nodeId, completion: completion)
    }
    func fetchTaskProgress(taskId: String, completion: @escaping (Result<TaskProgress, Error>) -> Void) {
        taskState.fetchTaskProgress(taskId: taskId, completion: completion)
    }
    func fetchTaskTimeline(taskId: String, completion: @escaping (Result<TaskTimeline, Error>) -> Void) {
        taskState.fetchTaskTimeline(taskId: taskId, completion: completion)
    }

    // ARCH-1 PR-C1 Phase 4: Autoscaler 域 stubs, bodies in MultiNodeAutoscalerService.swift。
    func fetchAutoscalerConfig() { autoscalerState.fetchAutoscalerConfig() }
    func fetchSuggestions() { autoscalerState.fetchSuggestions() }
    func fetchAlerts() { autoscalerState.fetchAlerts() }

    func checkHealth() { clusterHealthState.checkHealth() }

    // Track B: 刷新 activeMasterHost (pool 当前 master)。canMutate 为计算属性无需刷新, 此方法仅同步 host。
    // 在 isConnected/splitBrainDetected 赋值点 + checkHealth 成功/失败 + poll 失败 failover 后调用。
    internal func recomputeCanMutate() {
        activeMasterHost = MasterPool.shared.active?.host
    }

    // MARK: - Mutation endpoints

    // F-A11: 脑裂时阻断写操作 (remove/approve/migrate/submit), 防 removeNode 操作到另一分区 master。
    // ARCH-1 PR-C1: internal — 域 service extension 经 bridge?.assertNoSplitBrain reach-through (协调器留 engine)。
    internal func assertNoSplitBrain() throws {
        if splitBrainDetected {
            engineLog.error("F-A11 write blocked: split-brain active (>1 master)")
            throw EngineError.splitBrain
        }
    }

    func removeNode(nodeId: String) async throws { try await nodeState.removeNode(nodeId: nodeId) }
    func approveNode(nodeId: String, approvedBy: String = "admin") async throws {
        try await nodeState.approveNode(nodeId: nodeId, approvedBy: approvedBy)
    }
    func rejectNode(nodeId: String, reason: String = "") async throws {
        try await nodeState.rejectNode(nodeId: nodeId, reason: reason)
    }

    func cancelTask(taskId: String) async throws { try await taskState.cancelTask(taskId: taskId) }
    func degradeTask(taskId: String, targetModel: String? = nil) async throws {
        try await taskState.degradeTask(taskId: taskId, targetModel: targetModel)
    }
    func migrateTask(taskId: String, targetNodeId: String) async throws {
        try await taskState.migrateTask(taskId: taskId, targetNodeId: targetNodeId)
    }
    func migrateTask(taskId: String, targetNodeId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        taskState.migrateTask(taskId: taskId, targetNodeId: targetNodeId, completion: completion)
    }
    func submitTask(name: String, mode: String, modelName: String, priority: Int = 5, requiredCapability: String? = nil, excludeNodes: [String]? = nil) async throws -> [String: Any] {
        try await taskState.submitTask(name: name, mode: mode, modelName: modelName, priority: priority, requiredCapability: requiredCapability, excludeNodes: excludeNodes)
    }
    func retryTask(_ task: ClusterTask) async throws -> [String: Any] { try await taskState.retryTask(task) }

    func updateAutoscalerConfig(_ config: AutoscalerConfig) async throws {
        try await autoscalerState.updateAutoscalerConfig(config)
    }

    // ARCH-1 PR-C1 Phase 5: KVCache 域 stubs, bodies in MultiNodeKVCacheService.swift。
    func registerKVCache(cacheId: String, modelName: String, nodeId: String, sizeMb: Double, ttlSeconds: Int = 3600) async throws {
        try await kvCacheState.registerKVCache(cacheId: cacheId, modelName: modelName, nodeId: nodeId, sizeMb: sizeMb, ttlSeconds: ttlSeconds)
    }
    func findKVCache(modelName: String, completion: @escaping (Result<KVCacheEntry, Error>) -> Void) {
        kvCacheState.findKVCache(modelName: modelName, completion: completion)
    }
    func fetchAgentKVStats(completion: @escaping (Result<KVStatsResponse, Error>) -> Void) {
        kvCacheState.fetchAgentKVStats(completion: completion)
    }
    func agentKVLookup(modelName: String, promptHash: String, completion: @escaping (Result<KVCacheEntry, Error>) -> Void) {
        kvCacheState.agentKVLookup(modelName: modelName, promptHash: promptHash, completion: completion)
    }
    func agentKVTransfer(cacheId: String, targetNode: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        kvCacheState.agentKVTransfer(cacheId: cacheId, targetNode: targetNode, completion: completion)
    }
    func agentKVWarm(modelName: String, prompts: [String], completion: @escaping (Result<Int, Error>) -> Void) {
        kvCacheState.agentKVWarm(modelName: modelName, prompts: prompts, completion: completion)
    }

    func exportLogs() async throws -> Data {
        guard let url = URL(string: "\(baseURL)/api/v1/observability/logs/export") else {
            throw EngineError.invalidURL
        }
        var request = URLRequest(url: url)
        authHeaders(&request)
        let (data, _) = try await session.data(for: request)
        return data
    }

    // ARCH-1 PR-C1 Phase 5: Routing 域 stubs, bodies in MultiNodeRoutingService.swift。
    func setRoutingStrategy(_ strategy: String) async throws { try await routingState.setRoutingStrategy(strategy) }

    func joinNode(ipAddress: String, port: Int, token: String? = nil) async throws -> [String: Any] {
        try await nodeState.joinNode(ipAddress: ipAddress, port: port, token: token)
    }

    // MARK: - Cluster Sync (#74)

    // ARCH-1 PR-C1 Phase 4: Sync 域 stubs, bodies in MultiNodeSyncService.swift。
    func fetchClusterSyncStatus() { syncState.fetchClusterSyncStatus() }

    func fetchModelManifest(modelName: String, completion: @escaping (Result<ModelManifest, Error>) -> Void) {
        nodeState.fetchModelManifest(modelName: modelName, completion: completion)
    }

    func triggerIncrementalSync(modelName: String, sourceHost: String, sourcePort: Int? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        syncState.triggerIncrementalSync(modelName: modelName, sourceHost: sourceHost, sourcePort: sourcePort, completion: completion)
    }

    func fetchNodeLoad(nodeId: String, completion: @escaping (Result<NodeLoadReport, Error>) -> Void) {
        nodeState.fetchNodeLoad(nodeId: nodeId, completion: completion)
    }
    func fetchAllNodeLoads() { nodeState.fetchAllNodeLoads() }

    // MARK: - Routing

    // ARCH-1 PR-C1 Phase 5: Routing 域 stubs, bodies in MultiNodeRoutingService.swift。
    func fetchRoutingSummary(completion: @escaping (Result<RoutingSummary, Error>) -> Void) {
        routingState.fetchRoutingSummary(completion: completion)
    }

    // ARCH-1 PR-C1 Phase 5: AgentServer 域 stubs, bodies in MultiNodeAgentServerService.swift。
    func fetchAgentHardware(completion: @escaping (Result<AgentHardwareInfo, Error>) -> Void) {
        agentServerState.fetchAgentHardware(completion: completion)
    }
    func checkAgentHealth(completion: @escaping (Result<Bool, Error>) -> Void) {
        agentServerState.checkAgentHealth(completion: completion)
    }

    // MARK: - Generic HTTP helpers

    // ARCH-1 PR-C1: internal — 域 service extension 经 bridge?.get(...) reach-through。
    internal func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
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

    internal func post(_ path: String, body: [String: Any], idempotencyKey: String? = nil) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw EngineError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(&request)
        leaderTokenHeader(&request)
        if let key = idempotencyKey {
            request.setValue(key, forHTTPHeaderField: "X-Idempotency-Key")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    internal func put(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw EngineError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authHeaders(&request)
        leaderTokenHeader(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    internal func delete(_ path: String) async throws {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw EngineError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        authHeaders(&request)
        leaderTokenHeader(&request)
        _ = try await session.data(for: request)
    }

    // ARCH-1 PR-C1: internal — 域 service extension 经 bridge?.handleError reach-through (协调器留 engine)。
    internal func handleError(_ error: Error, context: String) {
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
            let prev = self.pollingState.consecutiveFailuresByContext[context, default: 0]
            self.pollingState.consecutiveFailuresByContext[context] = prev + 1
            if (prev + 1) >= self.pollingState.maxConsecutiveFailures {
                self.isConnected = false
                engineLog.warning("MultiNode disconnected: context=\(context) failures=\(prev + 1)")
                // Track B: 降级时刷新 activeMasterHost, 并 failover 到 pool 下一 master + 健康探测。
                // 单飞保护: 多路 handleError 并发触发只探一次, 避免请求风暴。保留原有 backoff 逻辑不动。
                self.recomputeCanMutate()
                if !self.clusterHealthState.failoverProbeInflight {
                    self.clusterHealthState.failoverProbeInflight = true
                    let next = MasterPool.shared.advance()
                    engineLog.info("Track B failover to \(next?.host ?? "nil", privacy: .public) after disconnect (context=\(context))")
                    self.recomputeCanMutate()
                    self.checkHealth()
                }
            }
        }
    }

    // B5: nonisolated deinit cannot call MainActor-isolated stopPolling(); inline timer
    // invalidation (Timer.invalidate is safe from any queue). pollTimers is nonisolated(unsafe) on pollingState。
    deinit {
        pollingState.cleanup()
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
    case writeDisabled

    var errorDescription: String? {
        switch self {
        case .invalidURL: return I18nManager.shared.t(.mn_err_invalidURL)
        case .noData: return I18nManager.shared.t(.mn_err_noData)
        case .splitBrain: return I18nManager.shared.t(.mn_err_splitBrain)
        case .retryNoHealthyNode: return I18nManager.shared.t(.mn_err_retryNoHealthyNode)
        case .duplicateRequest: return I18nManager.shared.t(.mn_err_duplicateRequest)
        case .writeDisabled: return "Write blocked: cluster not healthy or split-brain"
        }
    }
}
