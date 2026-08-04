// Callers: ModelHubAPIClient decodes these; all Model Hub views use them as data source.
// Affected API: Codable DTOs matching fusion-model-hub /api/v1/* JSON responses.
// Data schemas: JSON response shapes from upstream routers (models/quantize/downloads/cluster/monitor/auth/system/hardware/benchmarks).
// User instruction: issue #63 — market search, modules, benchmarks, scheduling, QPS

import Foundation

// MARK: - Common

struct HubSimpleResponse: Codable {
    let success: Bool?
    let message: String?
    let error: String?
}

// MARK: - Models

struct HubModelListResponse: Codable {
    let models: [HubModel]
    let total: Int?
}

struct HubModel: Identifiable, Codable, Hashable {
    let id: String
    var name: String?
    var displayName: String?
    var modelPath: String?
    var engineType: String?
    var format: String?
    var sizeBytes: Int?
    var quantization: String?
    var parameters: String?
    var family: String?
    var isDownloaded: Bool?
    var isActive: Bool?
    var isPinned: Bool?
    var allowedModules: [String]?
    var versions: [HubModelVersion]?
    var source: String?
    var description: String?
    var tags: [String]?
    var downloads: Int?
    var likes: Int?
    var license: String?
    var task: String?
    var createdAt: String?
    var updatedAt: String?
    var modelType: String?
    var ttlSeconds: Int?
    var ratingAvg: Double?
    var favoriteCount: Int?
    var isServing: Bool?
    var compatibleFormats: [String]?

    var displayTitle: String { displayName ?? name ?? id }
    var sizeGB: Double { Double(sizeBytes ?? 0) / 1_073_741_824.0 }
    var sizeFormatted: String { String(format: "%.1f GB", sizeGB) }

    var fusionModuleHint: String? {
        switch task {
        case "text-generation", "conversational": return "Fusion Chat"
        case "code", "text2code": return "Fusion Code"
        case "embedding", "feature-extraction": return "Fusion RAG"
        case "image-generation", "text-to-image": return "Fusion Design"
        case "visual-question-answering", "multimodal": return "Fusion Design"
        default: return nil
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: HubModel, rhs: HubModel) -> Bool { lhs.id == rhs.id }
}

struct HubModelVersion: Codable, Identifiable {
    let id: String
    let version: String?
    let createdAt: String?
    let sizeBytes: Int?
    let format: String?
    let quantization: String?
    let status: String?
    let benchmarkScore: Double?
    let accuracy: Double?

    var statusEnum: HubVersionStatus {
        HubVersionStatus(rawValue: status ?? "") ?? .draft
    }
}

enum HubVersionStatus: String, CaseIterable {
    case draft = "draft"
    case testing = "testing"
    case published = "published"
    case deprecated = "deprecated"
    case retired = "retired"

    var label: String {
        switch self {
        case .draft: return "草稿"
        case .testing: return "测试中"
        case .published: return "已发布"
        case .deprecated: return "已废弃"
        case .retired: return "已下线"
        }
    }

    var icon: String {
        switch self {
        case .draft: return "pencil"
        case .testing: return "flask"
        case .published: return "checkmark.circle.fill"
        case .deprecated: return "exclamationmark.triangle"
        case .retired: return "archivebox"
        }
    }

    var color: String {
        switch self {
        case .draft: return "gray"
        case .testing: return "orange"
        case .published: return "green"
        case .deprecated: return "yellow"
        case .retired: return "red"
        }
    }
}

struct HubMarketSearchResponse: Codable {
    let results: [HubMarketModel]
    let total: Int?
    let page: Int?
    let limit: Int?
}

struct HubMarketModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String?
    let repoId: String?
    let source: String?
    let description: String?
    let downloads: Int?
    let likes: Int?
    let tags: [String]?
    let task: String?
    let format: String?
    let quantization: String?
    let parameters: String?
    let family: String?
    let sizeBytes: Int?
    let license: String?
    let author: String?
    let updatedAt: String?

    var displayTitle: String { name ?? repoId ?? id }
    var sizeGB: Double { Double(sizeBytes ?? 0) / 1_073_741_824.0 }
    var sizeFormatted: String { sizeGB > 0 ? String(format: "%.1f GB", sizeGB) : "" }

    var sourceIcon: String {
        switch source {
        case "huggingface": return "h.square.fill"
        case "modelscope": return "m.square.fill"
        case "local": return "internaldrive"
        default: return "globe"
        }
    }

    var sourceColor: String {
        switch source {
        case "huggingface": return "yellow"
        case "modelscope": return "blue"
        case "local": return "gray"
        default: return "green"
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: HubMarketModel, rhs: HubMarketModel) -> Bool { lhs.id == rhs.id }
}

struct HubVersionListResponse: Codable {
    let versions: [HubModelVersion]
    let total: Int?
}

// MARK: - Downloads

struct HubDownloadListResponse: Codable {
    let tasks: [HubDownloadTask]
    let total: Int?
}

struct HubDownloadTaskResponse: Codable {
    let task: HubDownloadTask
}

struct HubDownloadTask: Identifiable, Codable {
    let id: String
    let repoId: String?
    let source: String?
    let targetFormat: String?
    let quantization: String?
    let status: String?
    let progress: Double?
    let speed: String?
    let eta: String?
    let error: String?
    let createdAt: String?
    let completedAt: String?

    var isComplete: Bool { status == "completed" || status == "done" }
    var isFailed: Bool { status == "failed" || status == "error" }
    var progressPct: Int { Int((progress ?? 0) * 100) }
}

// MARK: - Quantize

struct HubQuantizeTaskResponse: Codable {
    let task: HubQuantizeTask
}

struct HubQuantizeTask: Identifiable, Codable {
    let id: String
    let modelId: String?
    let targetFormat: String?
    let bits: Int?
    let preset: String?
    let status: String?
    let progress: Double?
    let outputPath: String?
    let error: String?
    let createdAt: String?
    let completedAt: String?
    let benchmarkResult: HubBenchmarkEntry?

    var isComplete: Bool { status == "completed" || status == "done" }
    var isFailed: Bool { status == "failed" || status == "error" }
    var progressPct: Int { Int((progress ?? 0) * 100) }
}

struct HubQuantizeTaskListResponse: Codable {
    let tasks: [HubQuantizeTask]
    let total: Int?
}

struct HubPresetListResponse: Codable {
    let presets: [HubQuantizePreset]
}

struct HubQuantizePreset: Identifiable, Codable {
    let id: String
    let name: String?
    let description: String?
    let targetFormat: String?
    let bits: Int?
    let groupSize: Int?
    let estimatedSizeReduction: Double?
}

// MARK: - Cluster / Smart Scheduling (issue #63 sub-feature 4)

struct HubClusterNodeListResponse: Codable {
    let nodes: [HubClusterNode]
    let total: Int?
}

struct HubClusterNode: Identifiable, Codable, Hashable {
    let id: String
    let name: String?
    let host: String?
    let port: Int?
    let status: String?
    let models: [String]?
    let gpuType: String?
    let memoryGB: Double?
    let lastSeen: String?
    let cpuUsage: Double?
    let gpuUsage: Double?
    let memoryUsed: Double?

    var isOnline: Bool { status == "online" || status == "active" }

    var healthStatus: HubNodeHealth {
        guard isOnline else { return .offline }
        if let cpu = cpuUsage, cpu > 0.9 { return .overloaded }
        if let gpu = gpuUsage, gpu > 0.9 { return .overloaded }
        if let mem = memoryUsed, let total = memoryGB, mem / total > 0.9 { return .overloaded }
        return .healthy
    }
}

enum HubNodeHealth: String {
    case healthy = "健康"
    case overloaded = "过载"
    case offline = "离线"

    var icon: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .overloaded: return "exclamationmark.triangle.fill"
        case .offline: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .healthy: return "green"
        case .overloaded: return "orange"
        case .offline: return "red"
        }
    }
}

struct HubClusterTopologyResponse: Codable {
    let nodes: [HubClusterNode]
    let edges: [HubClusterEdge]
    let localNode: String?
}

struct HubClusterEdge: Codable, Identifiable {
    let id: String
    let from: String
    let to: String
    let latency: Double?
    let bandwidth: Double?
}

struct HubRouteInferenceRequest: Codable {
    let modelId: String
    let messages: [HubChatMessage]
    let mode: String

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case messages
        case mode
    }
}

struct HubChatMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Monitor

struct HubMonitorResponse: Codable {
    let cpu: HubCpuStats?
    let gpu: HubGpuStats?
    let memory: HubMemoryStats?
    let disk: HubDiskStats?
    let activeDownloads: Int?
    let activeQuantize: Int?
    let uptime: String?
}

struct HubCpuStats: Codable {
    let usage: Double?
    let cores: Int?
    let temperature: Double?
}

struct HubGpuStats: Codable {
    let usage: Double?
    let memoryUsed: Double?
    let memoryTotal: Double?
    let temperature: Double?
    let type: String?
}

struct HubMemoryStats: Codable {
    let used: Double?
    let total: Double?
    let swap: Double?
}

struct HubDiskStats: Codable {
    let used: Double?
    let total: Double?
    let modelsPath: String?
    let modelsSize: Double?
}

// MARK: - Auth (issue #63 sub-feature 2 & 5)

struct HubAPIKeyListResponse: Codable {
    let items: [HubAPIKey]?
    let total: Int?

    var keys: [HubAPIKey] { items ?? [] }
}

struct HubAPIKeyResponse: Codable {
    let id: String?
    let name: String?
    let key: String?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, key
        case isActive = "is_active"
    }
}

struct HubAPIKey: Identifiable, Codable {
    let id: String
    let name: String?
    let prefix: String?
    let allowedModels: [String]?
    let allowedModules: [String]?
    let qpsLimit: Int?
    let rateLimitQpm: Int?
    let isActive: Bool?
    let createdAt: String?
    let lastUsed: String?

    var effectiveQPSLimit: Int? { qpsLimit ?? rateLimitQpm }

    enum CodingKeys: String, CodingKey {
        case id, name
        case prefix = "key_prefix"
        case allowedModels = "allowed_models"
        case allowedModules = "allowed_modules"
        case qpsLimit = "qps_limit"
        case rateLimitQpm = "rate_limit_qpm"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastUsed = "last_used_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        prefix = try c.decodeIfPresent(String.self, forKey: .prefix)
        qpsLimit = try c.decodeIfPresent(Int.self, forKey: .qpsLimit)
        rateLimitQpm = try c.decodeIfPresent(Int.self, forKey: .rateLimitQpm)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        lastUsed = try c.decodeIfPresent(String.self, forKey: .lastUsed)
        allowedModels = try HubAPIKey.parseStringList(c, .allowedModels)
        allowedModules = try HubAPIKey.parseStringList(c, .allowedModules)
    }

    private static func parseStringList(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> [String]? {
        if let arr = try? c.decode([String].self, forKey: key) { return arr }
        if let s = try c.decodeIfPresent(String.self, forKey: key), !s.isEmpty {
            return s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return nil
    }
}

struct HubAPIKeyUsageResponse: Codable {
    let keyId: String
    let currentQps: Double?
    let currentQpm: Int?
    let totalRequests: Int?
    let windowStart: String?
    let windowEnd: String?
}

// MARK: - Module definitions (issue #63 sub-feature 2)

enum HubModelModule: String, CaseIterable, Identifiable {
    case nlp = "NLP"
    case cv = "CV"
    case audio = "Audio"
    case multimodal = "Multimodal"
    case code = "Code"
    case science = "Science"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nlp: return "text.bubble"
        case .cv: return "eye"
        case .audio: return "waveform"
        case .multimodal: return "square.on.square.intersection"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .science: return "flask"
        }
    }

    var color: String {
        switch self {
        case .nlp: return "blue"
        case .cv: return "purple"
        case .audio: return "green"
        case .multimodal: return "orange"
        case .code: return "cyan"
        case .science: return "pink"
        }
    }
}

// MARK: - System

struct HubHealthResponse: Codable {
    let status: String?
    let version: String?
    let uptime: String?
    let mlxConnected: Bool?
    let storage: HubDiskStats?
}

struct HubStorageResponse: Codable {
    let total: Double?
    let used: Double?
    let models: HubStorageBreakdown?
    let cache: HubStorageBreakdown?
}

struct HubStorageBreakdown: Codable {
    let size: Double?
    let count: Int?
    let path: String?
}

struct HubAuditLogResponse: Codable {
    let logs: [HubAuditEntry]
    let total: Int?
}

struct HubAuditEntry: Identifiable, Codable {
    let id: String
    let action: String?
    let source: String?
    let resource: String?
    let user: String?
    let timestamp: String?
    let details: String?
}

// MARK: - Hardware

struct HubHardwareResponse: Codable {
    let chip: String?
    let cpuCores: Int?
    let gpuCores: Int?
    let memoryGB: Double?
    let swapGB: Double?
    let diskGB: Double?
    let diskFree: Double?
    let metalSupport: Bool?
    let aneSupport: Bool?
    let neuralEngineCores: Int?
}

// MARK: - Benchmarks (issue #63 sub-feature 3)

struct HubBenchmarkCompareResponse: Codable {
    let benchmarks: [HubBenchmarkEntry]
}

struct HubBenchmarkListResponse: Codable {
    let benchmarks: [HubBenchmarkEntry]
    let total: Int?
}

struct HubBenchmarkEntry: Identifiable, Codable {
    let id: String
    let modelId: String?
    let modelName: String?
    let template: String?
    let tokensPerSecond: Double?
    let timeToFirstToken: Double?
    let memoryPeak: Double?
    let score: Double?
    let accuracy: Double?
    let completedAt: String?
}

struct HubBenchmarkDetail: Codable {
    let id: String
    let modelId: String?
    let modelName: String?
    let template: String?
    let tokensPerSecond: Double?
    let timeToFirstToken: Double?
    let memoryPeak: Double?
    let score: Double?
    let accuracy: Double?
    let completedAt: String?
    let perTokenLatency: Double?
    let firstTokenLatency: Double?
    let throughputBatch1: Double?
    let throughputBatch2: Double?
    let throughputBatch4: Double?
    let throughputBatch8: Double?
    let memoryFootprint: Double?
    let prefillLatency: Double?
    let decodeLatency: Double?
}

struct HubThresholdConfig: Codable {
    var accuracyThreshold: Double = 0.7
    var scoreThreshold: Double = 50.0
    var perModel: [String: PerModelThreshold] = [:]

    struct PerModelThreshold: Codable {
        var accuracyThreshold: Double?
        var scoreThreshold: Double?
    }

    func accuracyThreshold(for modelId: String) -> Double {
        perModel[modelId]?.accuracyThreshold ?? accuracyThreshold
    }

    func scoreThreshold(for modelId: String) -> Double {
        perModel[modelId]?.scoreThreshold ?? scoreThreshold
    }
}

// MARK: - Inference

struct HubInferenceResponse: Codable {
    let id: String?
    let content: String?
    let model: String?
    let usage: HubInferenceUsage?
    let routedTo: String?
    let routeMode: String?
}

struct HubInferenceUsage: Codable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

// MARK: - Dashboard aggregation

struct HubDashboardStats {
    var totalModels: Int = 0
    var downloadedModels: Int = 0
    var activeModels: Int = 0
    var pinnedModels: Int = 0
    var totalSizeGB: Double = 0
    var downloadsInProgress: Int = 0
    var quantizeInProgress: Int = 0
    var clusterNodesOnline: Int = 0
    var clusterNodesTotal: Int = 0
    var servingModels: Int = 0
    var mlxConnected: Bool = false
}

// MARK: - Serve (deploy model to MLX)

struct HubServeResponse: Codable {
    let modelId: String?
    let status: String?
    let host: String?
    let port: Int?
}

struct HubServeRequest: Codable {
    let modelId: String
    let autoStart: Bool?
    let ttlSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case autoStart = "auto_start"
        case ttlSeconds = "ttl_seconds"
    }
}

// MARK: - Deployments

struct HubDeploymentListResponse: Codable {
    let deployments: [HubDeployment]
    let total: Int?
}

struct HubDeployment: Identifiable, Codable, Hashable {
    let id: String
    let modelId: String?
    let modelName: String?
    let status: String?
    let strategy: String?
    let scale: Int?
    let canaryPercent: Int?
    let createdAt: String?
    let updatedAt: String?

    var isRunning: Bool { status == "running" || status == "active" }
    var isFailed: Bool { status == "failed" || status == "error" }

    var statusLabel: String {
        switch status {
        case "pending": return "等待中"
        case "running", "active": return "运行中"
        case "stopped": return "已停止"
        case "failed", "error": return "失败"
        default: return status ?? "未知"
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: HubDeployment, rhs: HubDeployment) -> Bool { lhs.id == rhs.id }
}

struct HubDeploymentCreateRequest: Codable {
    let modelId: String
    let strategy: String?
    let scale: Int?
    let canaryPercent: Int?
    let autoStart: Bool?

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case strategy
        case scale
        case canaryPercent = "canary_percent"
        case autoStart = "auto_start"
    }
}

struct HubDeploymentMetricsResponse: Codable {
    let deploymentId: String?
    let requestsPerSecond: Double?
    let avgLatencyMs: Double?
    let errorRate: Double?
    let tokensPerSecond: Double?
    let activeConnections: Int?
}

// MARK: - Evaluations

struct HubEvaluationListResponse: Codable {
    let evaluations: [HubEvaluation]
    let total: Int?
}

struct HubEvaluation: Identifiable, Codable {
    let id: String
    let modelId: String?
    let modelName: String?
    let template: String?
    let status: String?
    let scores: [String: Double]?
    let overallScore: Double?
    let createdAt: String?
    let completedAt: String?

    var isComplete: Bool { status == "completed" || status == "done" }
    var isFailed: Bool { status == "failed" || status == "error" }
}

struct HubEvaluationCreateRequest: Codable {
    let modelId: String
    let template: String?
    let config: [String: String]?

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case template, config
    }
}

struct HubEvaluationCompareResponse: Codable {
    let evaluations: [HubEvaluation]
}

// MARK: - Tenants

struct HubTenantListResponse: Codable {
    let tenants: [HubTenant]
    let total: Int?
}

struct HubTenant: Identifiable, Codable, Hashable {
    let id: String
    let name: String?
    let role: String?
    let allowedModels: [String]?
    let allowedModules: [String]?
    let qpsLimit: Int?
    let isActive: Bool?
    let createdAt: String?

    var roleLabel: String {
        switch role {
        case "admin": return "管理员"
        case "developer": return "开发者"
        case "viewer": return "只读"
        default: return role ?? "自定义"
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: HubTenant, rhs: HubTenant) -> Bool { lhs.id == rhs.id }
}

struct HubTenantCreateRequest: Codable {
    let name: String
    let role: String?
    let allowedModels: [String]?
    let allowedModules: [String]?
    let qpsLimit: Int?
}

struct HubRoleListResponse: Codable {
    let items: [HubRole]?
    let total: Int?

    var roles: [HubRole] { items ?? [] }
}

struct HubRole: Identifiable, Codable, Hashable {
    let id: String
    let tenantId: String?
    let name: String?
    let permissions: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case tenantId = "tenant_id"
        case name, permissions
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var permissionsList: [String] {
        permissions?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: HubRole, rhs: HubRole) { lhs.id == rhs.id }
}

// MARK: - Webhooks

struct HubWebhookListResponse: Codable {
    let webhooks: [HubWebhook]
    let total: Int?
}

struct HubWebhook: Identifiable, Codable {
    let id: String
    let url: String?
    let events: [String]?
    let isActive: Bool?
    let hmacSecret: String?
    let createdAt: String?
    let lastTriggered: String?
}

struct HubWebhookCreateRequest: Codable {
    let url: String
    let events: [String]?
    let isActive: Bool?
}

// MARK: - Ratings

struct HubRatingListResponse: Codable {
    let ratings: [HubRating]
    let total: Int?
}

struct HubRating: Identifiable, Codable {
    let id: String
    let modelId: String?
    let score: Int?
    let summary: String?
    let userId: String?
    let createdAt: String?
}

struct HubRatingCreateRequest: Codable {
    let modelId: String
    let score: Int
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case score, summary
    }
}

struct HubRatingSummaryResponse: Codable {
    let modelId: String?
    let avgScore: Double?
    let totalCount: Int?
}

// MARK: - Favorites

struct HubFavoriteListResponse: Codable {
    let favorites: [HubFavorite]
    let total: Int?
}

struct HubFavorite: Identifiable, Codable {
    let id: String
    let modelId: String?
    let modelName: String?
    let createdAt: String?
}

struct HubFavoriteToggleRequest: Codable {
    let modelId: String

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
    }
}

// MARK: - Branches

struct HubBranchListResponse: Codable {
    let items: [HubBranch]?
    let total: Int?
    var branches: [HubBranch] { items ?? [] }
}

struct HubBranch: Identifiable, Codable {
    let id: String
    let modelId: String?
    let name: String?
    let baseVersionId: String?
    let headVersionId: String?
    let status: String?
    let description: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case modelId = "model_id"
        case name
        case baseVersionId = "base_version_id"
        case headVersionId = "head_version_id"
        case status
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isActive: Bool { status == "active" }
    var isMerged: Bool { status == "merged" }
}

struct HubBranchCreateRequest: Codable {
    let modelId: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case name
    }
}

struct HubBranchMergeRequest: Codable {
    let branchId: String

    enum CodingKeys: String, CodingKey {
        case branchId = "branch_id"
    }
}

// MARK: - Security

struct HubSecurityScanResponse: Codable {
    let scanId: String?
    let modelId: String?
    let status: String?
    let issues: [HubSecurityIssue]?
    let scannedAt: String?
}

struct HubSecurityIssue: Identifiable, Codable {
    let id: String
    let severity: String?
    let type: String?
    let description: String?
    let recommendation: String?
}

// MARK: - Watermark

struct HubWatermarkResponse: Codable {
    let modelId: String?
    let status: String?
    let watermarkId: String?
    let verified: Bool?
    let embeddedAt: String?
}

struct HubWatermarkRequest: Codable {
    let modelId: String
    let watermarkText: String?

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case watermarkText = "watermark_text"
    }
}

// MARK: - Encryption

struct HubEncryptionResponse: Codable {
    let modelId: String?
    let status: String?
    let algorithm: String?
    let encryptedAt: String?
}

struct HubEncryptionRequest: Codable {
    let modelId: String
    let algorithm: String?

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case algorithm
    }
}

// MARK: - Approvals

struct HubApprovalListResponse: Codable {
    let approvals: [HubApproval]
    let total: Int?
}

struct HubApproval: Identifiable, Codable {
    let id: String
    let modelId: String?
    let modelName: String?
    let operation: String?
    let level: String?
    let status: String?
    let requestedBy: String?
    let reviewedBy: String?
    let createdAt: String?
    let reviewedAt: String?
    let comment: String?

    var levelLabel: String {
        switch level {
        case "L1": return "L1 自动审批"
        case "L2": return "L2 主管审批"
        case "L3": return "L3 安全审批"
        default: return level ?? "未知"
        }
    }

    var isPending: Bool { status == "pending" }
}

struct HubApprovalSubmitRequest: Codable {
    let modelId: String
    let operation: String
    let level: String?

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case operation, level
    }
}

struct HubApprovalReviewRequest: Codable {
    let approved: Bool
    let comment: String?
}

// MARK: - Recommend

struct HubRecommendResponse: Codable {
    let recommendations: [HubRecommendItem]
}

struct HubRecommendItem: Identifiable, Codable {
    let id: String
    let modelId: String?
    let modelName: String?
    let score: Double?
    let reason: String?
    let task: String?
}

// MARK: - Adapt (auto-migration)

struct HubAdaptAssessResponse: Codable {
    let modelId: String?
    let compatible: Bool?
    let issues: [String]?
    let recommendations: [String]?
}

struct HubAdaptPlanResponse: Codable {
    let modelId: String?
    let steps: [HubAdaptStep]?
    let estimatedTime: String?
}

struct HubAdaptStep: Identifiable, Codable {
    let id: String
    let step: String?
    let description: String?
    let status: String?
}

struct HubAdaptExecuteResponse: Codable {
    let taskId: String?
    let modelId: String?
    let status: String?
    let progress: Double?
}

// MARK: - Sync

struct HubSyncPushResponse: Codable {
    let syncId: String?
    let modelIds: [String]?
    let targetNode: String?
    let status: String?
}

struct HubSyncPullResponse: Codable {
    let syncId: String?
    let modelIds: [String]?
    let sourceNode: String?
    let status: String?
}

struct HubSyncManifestResponse: Codable {
    let models: [HubSyncManifestEntry]?
}

struct HubSyncManifestEntry: Identifiable, Codable {
    let id: String
    let modelId: String?
    let nodeName: String?
    let version: String?
    let syncedAt: String?
}

// MARK: - Per-model inference stats

struct HubModelInferenceStatsListResponse: Codable {
    let stats: [HubModelInferenceStats]
    let total: Int?
}

struct HubModelInferenceStats: Codable, Identifiable {
    let id: String
    let modelId: String?
    let modelName: String?
    let requestsPerMin: Double?
    let avgLatencyMs: Double?
    let tokensPerSecond: Double?
    let activeSessions: Int?
    let memoryMB: Double?
    let node: String?
    let source: String?
    let uptime: String?

    enum CodingKeys: String, CodingKey {
        case id
        case modelId = "model_id"
        case modelName = "model_name"
        case requestsPerMin = "requests_per_min"
        case avgLatencyMs = "avg_latency_ms"
        case tokensPerSecond = "tokens_per_second"
        case activeSessions = "active_sessions"
        case memoryMB = "memory_mb"
        case node, source, uptime
    }
}
