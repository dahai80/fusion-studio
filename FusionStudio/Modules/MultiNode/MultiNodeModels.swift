import Foundation
import os.log

private let modelsLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeModels")

// MARK: - /api/v1/cluster/stats 响应（嵌套结构）

struct V1ClusterStatsResponse: Codable {
    let cluster: V1ClusterInfo
    let tasks: V1TaskInfo
    let loadSummary: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case cluster, tasks
        case loadSummary = "load_summary"
    }
}

struct V1ClusterInfo: Codable {
    let onlineNodes: Int
    let totalNodes: Int
    let activeTasks: Int
    let totalMemoryGB: Double
    let availableMemoryGB: Double
    let utilization: Double

    enum CodingKeys: String, CodingKey {
        case onlineNodes = "online_nodes"
        case totalNodes = "total_nodes"
        case activeTasks = "active_tasks"
        case totalMemoryGB = "total_memory_gb"
        case availableMemoryGB = "available_memory_gb"
        case utilization
    }
}

struct V1TaskInfo: Codable {
    let total: Int
    let completed: Int
    let failed: Int
}

// 供 View 使用的扁平化集群统计

struct ClusterStats: Identifiable {
    var id: String { "cluster_stats" }
    let totalNodes: Int
    let onlineNodes: Int
    let activeTasks: Int
    let totalMemoryGB: Double
    let availableMemoryGB: Double
    let utilization: Double
    let totalTasks: Int
    let completedTasks: Int
    let failedTasks: Int

    static let empty = ClusterStats(
        totalNodes: 0, onlineNodes: 0, activeTasks: 0,
        totalMemoryGB: 0, availableMemoryGB: 0, utilization: 0,
        totalTasks: 0, completedTasks: 0, failedTasks: 0
    )

    static func from(_ resp: V1ClusterStatsResponse) -> ClusterStats {
        ClusterStats(
            totalNodes: resp.cluster.totalNodes,
            onlineNodes: resp.cluster.onlineNodes,
            activeTasks: resp.cluster.activeTasks,
            totalMemoryGB: resp.cluster.totalMemoryGB,
            availableMemoryGB: resp.cluster.availableMemoryGB,
            utilization: resp.cluster.utilization,
            totalTasks: resp.tasks.total,
            completedTasks: resp.tasks.completed,
            failedTasks: resp.tasks.failed
        )
    }
}

// MARK: - /api/nodes 响应（包装结构）

struct NodeListResponse: Codable {
    let total: Int
    let online: Int
    let nodes: [ClusterNode]
}

// MARK: - /api/tasks 响应（包装结构）

struct TaskListResponse: Codable {
    let total: Int
    let tasks: [ClusterTask]
}

// MARK: - NodeStatus

enum NodeStatus: String, Codable, CaseIterable {
    case online
    case busy
    case offline
    case fault
}

// MARK: - ClusterNode（匹配 _node_to_resp）

struct ClusterNode: Codable, Identifiable, Hashable {
    let id: String
    let hostname: String
    let ipAddress: String
    let port: Int
    let status: NodeStatus
    let totalMemoryGB: Double
    let availableMemoryGB: Double
    let cpuCores: Int
    let gpuCores: Int
    let deviceModel: String
    let umaSizeGB: Double?
    let activeTasks: Int
    let maxTasks: Int
    let score: Double
    let lastHeartbeat: Double?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case id = "node_id"
        case hostname
        case ipAddress = "ip_address"
        case port
        case status
        case totalMemoryGB = "total_memory_gb"
        case availableMemoryGB = "available_memory_gb"
        case cpuCores = "cpu_cores"
        case gpuCores = "gpu_cores"
        case deviceModel = "device_model"
        case umaSizeGB = "uma_size_gb"
        case activeTasks = "active_tasks"
        case maxTasks = "max_tasks"
        case score
        case lastHeartbeat = "last_heartbeat"
        case role
    }

    var isMaster: Bool { role == "master" }

    // F-A10: 客户端本地心跳陈旧度判定。lastHeartbeat 服务器时间戳 (epoch s),
    // 超过 30s 视为陈旧 — 服务端可能心跳漏判或返回脏 status, 客户端不无条件信任,
    // 本地降级为 offline 防 migrate 任务到死节点挂死。
    static let heartbeatStaleSeconds: Double = 30

    var heartbeatAge: Double? {
        guard let hb = lastHeartbeat, hb > 0 else { return nil }
        return Date().timeIntervalSince1970 - hb
    }

    var heartbeatStale: Bool {
        guard let age = heartbeatAge else { return false }
        return age > Self.heartbeatStaleSeconds
    }

    // 客户端最终判定的状态: 服务端 status 被 stale 心跳覆盖为 offline。
    var effectiveStatus: NodeStatus {
        heartbeatStale ? .offline : status
    }

    var memoryUsageRatio: Double {
        guard totalMemoryGB > 0 else { return 0 }
        return 1.0 - (availableMemoryGB / totalMemoryGB)
    }

    var taskLoadRatio: Double {
        guard maxTasks > 0 else { return 0 }
        return Double(activeTasks) / Double(maxTasks)
    }

    static let placeholder = ClusterNode(
        id: "placeholder", hostname: "-", ipAddress: "-",
        port: 0, status: .offline, totalMemoryGB: 0,
        availableMemoryGB: 0, cpuCores: 0, gpuCores: 0,
        deviceModel: "-", umaSizeGB: nil, activeTasks: 0,
        maxTasks: 0, score: 0, lastHeartbeat: nil, role: nil
    )
}

// MARK: - /api/nodes/pending 响应（待审批节点）

struct PendingNodeListResponse: Codable {
    let pending: [PendingNode]
}

struct PendingNode: Codable, Identifiable, Hashable {
    let id: String
    let hostname: String
    let ipAddress: String
    let port: Int
    let requestedAt: Double

    enum CodingKeys: String, CodingKey {
        case id = "node_id"
        case hostname
        case ipAddress = "ip_address"
        case port
        case requestedAt = "requested_at"
    }
}

// MARK: - /api/v1/nodes/{id}/metrics 响应

struct NodeMetricsResponse: Codable, Identifiable {
    var id: String { nodeId }
    let nodeId: String
    let status: String
    let role: String?
    let score: Double
    let availableMemoryGB: Double
    let totalMemoryGB: Double
    let activeTasks: Int
    let maxTasks: Int
    let networkRttMs: Double?
    let loadMetrics: LoadMetricsDetail?

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case status, role, score
        case availableMemoryGB = "available_memory_gb"
        case totalMemoryGB = "total_memory_gb"
        case activeTasks = "active_tasks"
        case maxTasks = "max_tasks"
        case networkRttMs = "network_rtt_ms"
        case loadMetrics = "load_metrics"
    }
}

struct LoadMetricsDetail: Codable {
    let umaUsedRatio: Double
    let cpuPercent: Double
    let metalUtil: Double
    let taskQueueLen: Int
    let netRttMs: Double

    enum CodingKeys: String, CodingKey {
        case umaUsedRatio = "uma_used_ratio"
        case cpuPercent = "cpu_percent"
        case metalUtil = "metal_util"
        case taskQueueLen = "task_queue_len"
        case netRttMs = "net_rtt_ms"
    }
}

// 兼容旧代码的 LoadMetrics（从 NodeMetricsResponse 转换）

struct LoadMetrics: Identifiable {
    var id: String { nodeId }
    let nodeId: String
    let cpuPercent: Double
    let memoryPercent: Double
    let gpuPercent: Double
    let queueLength: Int

    static func from(_ resp: NodeMetricsResponse) -> LoadMetrics {
        let load = resp.loadMetrics
        return LoadMetrics(
            nodeId: resp.nodeId,
            cpuPercent: load?.cpuPercent ?? 0,
            memoryPercent: load?.umaUsedRatio ?? 0,
            gpuPercent: load?.metalUtil ?? 0,
            queueLength: load?.taskQueueLen ?? 0
        )
    }

    static let empty = LoadMetrics(nodeId: "", cpuPercent: 0, memoryPercent: 0, gpuPercent: 0, queueLength: 0)
}

// MARK: - ClusterTaskStatus

enum ClusterTaskStatus: String, Codable, CaseIterable {
    case pending
    case running
    case completed
    case failed
    case cancelled
    case degraded
}

// MARK: - ClusterTask（匹配 _task_to_resp）

struct ClusterTask: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let mode: String
    let modelName: String
    let status: ClusterTaskStatus
    let assignedNodes: [String]
    let createdAt: Double?
    let startedAt: Double?
    let completedAt: Double?
    let error: String?
    let requiredCapability: String?
    let priority: Int?
    let degradedFromModel: String?
    let degradationCount: Int?
    let cancelReason: String?
    let subTasks: [SubTask]?

    enum CodingKeys: String, CodingKey {
        case id = "task_id"
        case name
        case mode
        case modelName = "model_name"
        case status
        case assignedNodes = "assigned_nodes"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case error
        case requiredCapability = "required_capability"
        case priority
        case degradedFromModel = "degraded_from_model"
        case degradationCount = "degradation_count"
        case cancelReason = "cancel_reason"
        case subTasks = "sub_tasks"
    }
}

struct SubTask: Codable, Hashable {
    let subTaskId: String
    let nodeId: String
    let status: String
    let progress: Double?

    enum CodingKeys: String, CodingKey {
        case subTaskId = "sub_task_id"
        case nodeId = "node_id"
        case status
        case progress
    }
}

// MARK: - /api/v1/tasks/{id}/progress 响应

struct TaskProgress: Codable, Identifiable {
    var id: String { taskId }
    let taskId: String
    let name: String?
    let status: String?
    let progress: Double
    let totalShards: Int
    let completedShards: Int
    let assignedNodes: [String]?
    let elapsedSeconds: Double?
    let remainingSeconds: Double?
    let modelName: String?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case name, status, progress
        case totalShards = "total_shards"
        case completedShards = "completed_shards"
        case assignedNodes = "assigned_nodes"
        case elapsedSeconds = "elapsed_seconds"
        case remainingSeconds = "remaining_seconds"
        case modelName = "model_name"
    }
}

// MARK: - /api/v1/tasks/{id}/timeline 响应

struct TaskTimeline: Codable {
    let taskId: String
    let name: String?
    let status: String?
    let events: [TimelineEvent]

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case name, status, events
    }
}

struct TimelineEvent: Codable, Identifiable {
    var id: String { "\(timestamp)-\(event)" }
    let timestamp: String
    let event: String
    let detail: String?
}

// MARK: - /api/v1/autoscaler/config 响应

struct AutoscalerConfig: Codable, Identifiable {
    var id: String { "autoscaler" }
    let enabled: Bool
    let minNodes: Int
    let maxNodes: Int
    let scaleUpThreshold: Double
    let scaleDownThreshold: Double
    let cooldownSeconds: Int
    let idleTimeoutSeconds: Int?
    let policy: String
    let checkInterval: Int?
    let rebalanceThreshold: Double?

    enum CodingKeys: String, CodingKey {
        case enabled
        case minNodes = "min_nodes"
        case maxNodes = "max_nodes"
        case scaleUpThreshold = "scale_up_threshold"
        case scaleDownThreshold = "scale_down_threshold"
        case cooldownSeconds = "cooldown_seconds"
        case idleTimeoutSeconds = "idle_timeout_seconds"
        case policy
        case checkInterval = "check_interval"
        case rebalanceThreshold = "rebalance_threshold"
    }

    static let `default` = AutoscalerConfig(
        enabled: false, minNodes: 2, maxNodes: 8,
        scaleUpThreshold: 0.8, scaleDownThreshold: 0.3,
        cooldownSeconds: 60, idleTimeoutSeconds: 300,
        policy: "threshold", checkInterval: 30, rebalanceThreshold: 0.2
    )
}

// MARK: - /api/v1/observability/suggestions 响应（包装结构）

struct SuggestionsResponse: Codable {
    let suggestions: [OptimizationSuggestion]
    let error: String?
}

// 匹配后端返回字段: priority, category, title, suggestion, related_alert

struct OptimizationSuggestion: Codable, Identifiable {
    var id: String { title }
    let priority: String
    let category: String
    let title: String
    let suggestion: String
    let relatedAlert: String?

    enum CodingKeys: String, CodingKey {
        case priority, category, title, suggestion
        case relatedAlert = "related_alert"
    }
}

// MARK: - Alert（匹配后端 Alert dataclass）
// 后端 Alert: alert_id, severity, title, message, node_id, created_at, resolved, resolved_at

struct AlertItem: Codable, Identifiable {
    let id: String
    let severity: String
    let title: String?
    let message: String
    let nodeId: String?
    let createdAt: Double?
    let resolved: Bool?

    enum CodingKeys: String, CodingKey {
        case id = "alert_id"
        case severity, title, message
        case nodeId = "node_id"
        case createdAt = "created_at"
        case resolved
    }

    var isCritical: Bool { severity == "critical" }
    var isWarning: Bool { severity == "warning" }
}

// MARK: - AnyCodable（用于 load_summary 等动态结构）

struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) { value = intVal }
        else if let doubleVal = try? container.decode(Double.self) { value = doubleVal }
        else if let boolVal = try? container.decode(Bool.self) { value = boolVal }
        else if let strVal = try? container.decode(String.self) { value = strVal }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int { try container.encode(intVal) }
        else if let doubleVal = value as? Double { try container.encode(doubleVal) }
        else if let boolVal = value as? Bool { try container.encode(boolVal) }
        else if let strVal = value as? String { try container.encode(strVal) }
        else { try container.encodeNil() }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
}

// MARK: - /api/routing/summary 响应

struct RoutingSummary: Codable {
    let strategy: String
    let nodes: [RoutingNodeInfo]?
    let totalLoad: Double?
    let avgLoad: Double?

    enum CodingKeys: String, CodingKey {
        case strategy, nodes
        case totalLoad = "total_load"
        case avgLoad = "avg_load"
    }
}

struct RoutingNodeInfo: Codable, Identifiable {
    var id: String { nodeId }
    let nodeId: String
    let load: Double
    let activeTasks: Int
    let maxTasks: Int

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case load
        case activeTasks = "active_tasks"
        case maxTasks = "max_tasks"
    }
}

// MARK: - /api/kv/find/{model_name} 响应

struct KVCacheEntry: Codable, Identifiable {
    var id: String { cacheId }
    let cacheId: String
    let modelName: String
    let nodeId: String
    let sizeMb: Double
    let accessCount: Int

    enum CodingKeys: String, CodingKey {
        case cacheId = "cache_id"
        case modelName = "model_name"
        case nodeId = "node_id"
        case sizeMb = "size_mb"
        case accessCount = "access_count"
    }
}

// MARK: - Agent Server /api/kv/stats 响应

struct KVStatsResponse: Codable {
    let totalEntries: Int
    let totalSizeMb: Double
    let byModel: [String: ModelKVInfo]?
    let hitRate: Double?

    enum CodingKeys: String, CodingKey {
        case totalEntries = "total_entries"
        case totalSizeMb = "total_size_mb"
        case byModel = "by_model"
        case hitRate = "hit_rate"
    }
}

struct ModelKVInfo: Codable {
    let count: Int
    let sizeMb: Double
    let avgAccessCount: Double?

    enum CodingKeys: String, CodingKey {
        case count
        case sizeMb = "size_mb"
        case avgAccessCount = "avg_access_count"
    }
}

// MARK: - Agent Server /api/hardware 响应

struct AgentHardwareInfo: Codable {
    let nodeId: String?
    let cpuCores: Int?
    let memoryGB: Double?
    let gpuCores: Int?
    let deviceModel: String?

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case cpuCores = "cpu_cores"
        case memoryGB = "memory_gb"
        case gpuCores = "gpu_cores"
        case deviceModel = "device_model"
    }
}

// MARK: - /api/cluster/status 响应 (集群同步状态)

struct ClusterSyncStatus: Codable {
    let partition: PartitionInfo?
    let syncAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case partition
        case syncAvailable = "sync_available"
    }

    var isDegraded: Bool { partition?.isDegraded ?? false }
    var partitionState: String { partition?.partitionState ?? "connected" }
}

struct PartitionInfo: Codable {
    let nodeId: String?
    let partitionState: String
    let isDegraded: Bool
    let nodes: [String: PartitionNodeStatus]?

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case partitionState = "partition_state"
        case isDegraded = "is_degraded"
        case nodes
    }
}

struct PartitionNodeStatus: Codable {
    let lastHeartbeatAgo: Double?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case lastHeartbeatAgo = "last_heartbeat_ago"
        case status
    }
}

// MARK: - /api/models/{model_name}/manifest 响应

struct ModelManifest: Codable, Identifiable {
    var id: String { modelName }
    let modelName: String
    let modelId: String?
    let totalSize: Int64?
    let createdAt: String?
    let files: [FileEntry]?

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case modelId = "model_id"
        case totalSize = "total_size"
        case createdAt = "created_at"
        case files
    }
}

struct FileEntry: Codable, Identifiable, Hashable {
    var id: String { path }
    let path: String
    let size: Int64?
    let sha256: String?
    let modifiedAt: String?

    enum CodingKeys: String, CodingKey {
        case path, size, sha256
        case modifiedAt = "modified_at"
    }
}

// MARK: - /api/nodes/{node_id}/load 响应

struct NodeLoadReport: Codable, Identifiable {
    var id: String { nodeId }
    let nodeId: String
    let gpuMemoryUsedGb: Double
    let gpuMemoryTotalGb: Double
    let ramUsedGb: Double
    let ramTotalGb: Double
    let diskUsedGb: Double
    let diskTotalGb: Double
    let cpuPercent: Double
    let activeTasks: Int
    let maxTasks: Int
    let reportedAt: String?

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case gpuMemoryUsedGb = "gpu_memory_used_gb"
        case gpuMemoryTotalGb = "gpu_memory_total_gb"
        case ramUsedGb = "ram_used_gb"
        case ramTotalGb = "ram_total_gb"
        case diskUsedGb = "disk_used_gb"
        case diskTotalGb = "disk_total_gb"
        case cpuPercent = "cpu_percent"
        case activeTasks = "active_tasks"
        case maxTasks = "max_tasks"
        case reportedAt = "reported_at"
    }

    var gpuUsageRatio: Double {
        guard gpuMemoryTotalGb > 0 else { return 0 }
        return gpuMemoryUsedGb / gpuMemoryTotalGb
    }

    var ramUsageRatio: Double {
        guard ramTotalGb > 0 else { return 0 }
        return ramUsedGb / ramTotalGb
    }

    static let empty = NodeLoadReport(
        nodeId: "", gpuMemoryUsedGb: 0, gpuMemoryTotalGb: 0,
        ramUsedGb: 0, ramTotalGb: 0, diskUsedGb: 0, diskTotalGb: 0,
        cpuPercent: 0, activeTasks: 0, maxTasks: 0, reportedAt: nil
    )
}
