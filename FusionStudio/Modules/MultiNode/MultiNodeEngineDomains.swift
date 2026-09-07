import Foundation
import Combine
import os.log

// ARCH-1 (PR-C1): MultiNodeEngine 18 @Published + ~59 methods 拆 10 独立 ObservableObject 域类型。
//   复用 AgentBridge #359 / DesignBridge #408 已验模式 (AgentBridgeDomains.swift / DesignBridgeDomains.swift)。
//   engine 持 let 域引用 (稳定身份), init() objectWillChange.sink 转发每域 (SwiftUI 不自动追踪嵌套
//   ObservableObject, P0-1 修)。18 属性经 engine 计算属性 get/set 转发保 62 view 读站点 0 改。
//   行为按域分阶段迁入 MultiNode<Domain>Service.swift extension。HTTP infra (get/post/put/delete,
//   authHeaders, leaderTokenHeader, session) 留 engine private, 域经 bridge?.get(...) reach-through。
//   协调器 (handleError / recomputeCanMutate / assertNoSplitBrain / startPolling / stopPolling) 留
//   engine (读 >1 域)。engine 为 @MainActor, 域亦 @MainActor (PR-B 已隔离)。
// 域: ClusterHealthState / NodeState / TaskState / SplitBrainState / AutoscalerState / SyncState /
//     KVCacheState / AgentServerState / RoutingState / PollingState。

private let mnDomainLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeEngineDomains")

// MARK: - Cluster Health State (集群统计 / 连接态 / 错误 / 过期标志 / 当前 master host)

@MainActor
final class MultiNodeClusterHealthState: ObservableObject {
    @Published var clusterStats: ClusterStats = .empty
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var nodesStale: Bool = false
    @Published var activeMasterHost: String? = nil
    // Track B: failover 健康探测单飞, 防 handleError 多路并发触发重复 checkHealth 风暴。
    var failoverProbeInflight: Bool = false
    weak var bridge: MultiNodeEngine?
    init() {}
}

// MARK: - Node State (节点列表 / 待批节点 / 指标 / 负载 / 模型清单)

@MainActor
final class MultiNodeNodeState: ObservableObject {
    @Published var nodes: [ClusterNode] = []
    @Published var pendingNodes: [PendingNode] = []
    @Published var nodeMetrics: [String: LoadMetrics] = [:]
    @Published var nodeMetricsRaw: [String: NodeMetricsResponse] = [:]
    @Published var nodeLoads: [String: NodeLoadReport] = [:]
    @Published var modelManifests: [String: ModelManifest] = [:]
    // 审计0830 P1-调度-5: per-node 连续 offline 计数, 达阈值 K 才确认 offline (决策点用 confirmedOffline)。
    var nodeOfflineStreak: [String: Int] = [:]
    let offlineConfirmThreshold: Int = 2
    // B2: node_loads poll throughput cap. >50 online nodes → sample top-N busiest by cpuPercent。
    let nodeLoadSampleCap = 50
    weak var bridge: MultiNodeEngine?
    init() {}

    func confirmedOffline(nodeId: String) -> Bool {
        let streak = nodeOfflineStreak[nodeId] ?? 0
        if streak >= offlineConfirmThreshold { return true }
        guard let n = nodes.first(where: { $0.id == nodeId }) else { return true }
        return n.effectiveStatus == .offline
    }
}

// MARK: - Task State (任务列表 / 重复执行检测)

@MainActor
final class MultiNodeTaskState: ObservableObject {
    @Published var tasks: [ClusterTask] = []
    @Published var duplicateExecutionTaskIds: [String] = []
    var duplicateExecutionDetected: Bool { !duplicateExecutionTaskIds.isEmpty }
    weak var bridge: MultiNodeEngine?
    init() {}
}

// MARK: - Split Brain State (脑裂检测 / 领导纪元 / per-leader token)

@MainActor
final class MultiNodeSplitBrainState: ObservableObject {
    @Published var splitBrainDetected: Bool = false
    var splitBrainConfirmCount: Int = 0
    // 审计v0.1.58 P1-4: 脑裂解除同样需连续 N 轮 ≤1 master 确认, 防瞬态抖动误放行写入。
    var splitBrainResolvedConfirmCount: Int = 0
    let splitBrainConfirmThreshold: Int = 2
    // #76: 已知最大领导纪元 + leader_id (HA failover 递增; 单 master/active-active 恒 0/"")。
    var knownLeaderEpoch: Int = 0
    var knownLeaderId: String? = nil
    // #77: per-leader token (从 /api/v1/cluster/stats leader_token 刷新)。
    var knownLeaderToken: String? = nil
    weak var bridge: MultiNodeEngine?
    init() {}
}

// MARK: - Autoscaler State (自动伸缩配置 / 告警 / 优化建议)

@MainActor
final class MultiNodeAutoscalerState: ObservableObject {
    @Published var autoscalerConfig: AutoscalerConfig = .default
    @Published var alerts: [AlertItem] = []
    @Published var suggestions: [OptimizationSuggestion] = []
    weak var bridge: MultiNodeEngine?
    init() {}
}

// MARK: - Sync State (集群同步状态)

@MainActor
final class MultiNodeSyncState: ObservableObject {
    @Published var clusterSyncStatus: ClusterSyncStatus?
    weak var bridge: MultiNodeEngine?
    init() {}
}

// MARK: - KV Cache State (KV 缓存写操作 — 方法域, 0 @Published)

@MainActor
final class MultiNodeKVCacheState: ObservableObject {
    weak var bridge: MultiNodeEngine?
    init() {}
}

// MARK: - Agent Server State (Agent 端口硬件/健康 — 方法域, 0 @Published)

@MainActor
final class MultiNodeAgentServerState: ObservableObject {
    weak var bridge: MultiNodeEngine?
    init() {}
}

// MARK: - Routing State (路由策略 — 方法域, 0 @Published)

@MainActor
final class MultiNodeRoutingState: ObservableObject {
    weak var bridge: MultiNodeEngine?
    init() {}
}

// MARK: - Polling State (轮询定时器 / 单飞保护 / 连续失败计数)

@MainActor
final class MultiNodePollingState: ObservableObject {
    // B5: nonisolated(unsafe) — timers only mutated on main (startPolling/stopPolling/reschedulePoll
    // are MainActor) and deinit invalidates synchronously. No cross-queue mutation.
    nonisolated(unsafe) var pollTimers: [Timer] = []
    // F-R10: 单飞保护。慢响应时 Timer 下一 tick 重复 fire 同一 fetch 致请求风暴, in-flight 跳过。
    var inflightFetches: Set<String> = []
    let inflightLock = NSLock()
    // F-R6/F-R10: per-context 连续失败计数 + 降级阈值。单次网络抖动不计 disconnected, 连续 N 轮失败才降级。
    var consecutiveFailuresByContext: [String: Int] = [:]
    let maxConsecutiveFailures: Int = 3
    var worstConsecutiveFailures: Int {
        consecutiveFailuresByContext.values.max() ?? 0
    }
    weak var bridge: MultiNodeEngine?
    init() {}

    func releaseInflight(_ key: String) {
        inflightLock.lock()
        inflightFetches.remove(key)
        inflightLock.unlock()
    }

    // B5: nonisolated deinit cleanup — Timer.invalidate 线程安全 (镜像 DesignBridge canvasState.cleanup / AgentBridge F-R9)。
    nonisolated func cleanup() {
        pollTimers.forEach { $0.invalidate() }
        pollTimers.removeAll()
    }
}
