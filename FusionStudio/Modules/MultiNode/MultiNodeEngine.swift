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

    // ARCH-1 PR-C1 Phase 1: stored-prop shims → 域 state。方法体暂留 engine (Phase 2-5 迁入 service
    //   extension), 经这些 shim 访问已迁入域的 stored props。Phase 6 删 shim (方法体迁走后无引用)。
    private var splitBrainConfirmCount: Int {
        get { splitBrainState.splitBrainConfirmCount } set { splitBrainState.splitBrainConfirmCount = newValue }
    }
    private var splitBrainResolvedConfirmCount: Int {
        get { splitBrainState.splitBrainResolvedConfirmCount } set { splitBrainState.splitBrainResolvedConfirmCount = newValue }
    }
    private var splitBrainConfirmThreshold: Int { splitBrainState.splitBrainConfirmThreshold }
    private var knownLeaderEpoch: Int {
        get { splitBrainState.knownLeaderEpoch } set { splitBrainState.knownLeaderEpoch = newValue }
    }
    private var knownLeaderId: String? {
        get { splitBrainState.knownLeaderId } set { splitBrainState.knownLeaderId = newValue }
    }
    private var knownLeaderToken: String? {
        get { splitBrainState.knownLeaderToken } set { splitBrainState.knownLeaderToken = newValue }
    }
    private var consecutiveFailuresByContext: [String: Int] {
        get { pollingState.consecutiveFailuresByContext } set { pollingState.consecutiveFailuresByContext = newValue }
    }
    private var worstConsecutiveFailures: Int { pollingState.worstConsecutiveFailures }
    private var maxConsecutiveFailures: Int { pollingState.maxConsecutiveFailures }
    private var inflightFetches: Set<String> {
        get { pollingState.inflightFetches } set { pollingState.inflightFetches = newValue }
    }
    private var inflightLock: NSLock { pollingState.inflightLock }
    private var pollTimers: [Timer] {
        get { pollingState.pollTimers } set { pollingState.pollTimers = newValue }
    }
    private var nodeOfflineStreak: [String: Int] {
        get { nodeState.nodeOfflineStreak } set { nodeState.nodeOfflineStreak = newValue }
    }
    private var offlineConfirmThreshold: Int { nodeState.offlineConfirmThreshold }
    private var nodeLoadSampleCap: Int { nodeState.nodeLoadSampleCap }
    private var failoverProbeInflight: Bool {
        get { clusterHealthState.failoverProbeInflight } set { clusterHealthState.failoverProbeInflight = newValue }
    }
    private func confirmedOffline(nodeId: String) -> Bool { nodeState.confirmedOffline(nodeId: nodeId) }
    private func releaseInflight(_ key: String) { pollingState.releaseInflight(key) }

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
        if let token = knownLeaderToken, !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "X-Leader-Token")
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

    func registerKVCache(cacheId: String, modelName: String, nodeId: String, sizeMb: Double, ttlSeconds: Int = 3600) async throws {
        // 审计v0.1.58 P0-multinode-1: KV register 是写操作, 必经 canMutate+split-brain 门.
        guard canMutate else {
            ClusterAuditor.shared.record(action: "registerKV", targetNode: nodeId, targetTask: nil,
                                         result: "blocked", idempotencyKey: nil, masterHost: activeMasterHost)
            throw EngineError.writeDisabled
        }
        try assertNoSplitBrain()
        let body: [String: Any] = [
            "cache_id": cacheId,
            "model_name": modelName,
            "node_id": nodeId,
            "size_mb": sizeMb,
            "ttl_seconds": ttlSeconds,
        ]
        do {
            _ = try await post("/api/kv/register", body: body)
            ClusterAuditor.shared.record(action: "registerKV", targetNode: nodeId, targetTask: nil,
                                         result: "ok", idempotencyKey: nil, masterHost: activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "registerKV", targetNode: nodeId, targetTask: nil,
                                         result: "failed", idempotencyKey: nil, masterHost: activeMasterHost)
            throw error
        }
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

    func setRoutingStrategy(_ strategy: String) async throws {
        guard canMutate else {
            ClusterAuditor.shared.record(action: "setRouting", targetNode: nil, targetTask: nil,
                                         result: "blocked", idempotencyKey: nil, masterHost: activeMasterHost)
            throw EngineError.writeDisabled
        }
        do {
            _ = try await post("/api/routing/strategy", body: ["strategy": strategy])
            ClusterAuditor.shared.record(action: "setRouting", targetNode: nil, targetTask: nil,
                                         result: "ok", idempotencyKey: nil, masterHost: activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "setRouting", targetNode: nil, targetTask: nil,
                                         result: "failed", idempotencyKey: nil, masterHost: activeMasterHost)
            throw error
        }
    }

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

    // releaseInflight 已迁 pollingState (Phase 1 shim 转发)。旧 body 删。

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
            let prev = self.consecutiveFailuresByContext[context, default: 0]
            self.consecutiveFailuresByContext[context] = prev + 1
            if (prev + 1) >= self.maxConsecutiveFailures {
                self.isConnected = false
                engineLog.warning("MultiNode disconnected: context=\(context) failures=\(prev + 1)")
                // Track B: 降级时刷新 activeMasterHost, 并 failover 到 pool 下一 master + 健康探测。
                // 单飞保护: 多路 handleError 并发触发只探一次, 避免请求风暴。保留原有 backoff 逻辑不动。
                self.recomputeCanMutate()
                if !self.failoverProbeInflight {
                    self.failoverProbeInflight = true
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
