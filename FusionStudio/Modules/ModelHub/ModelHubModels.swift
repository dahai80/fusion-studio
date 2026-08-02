// Callers: ModelHubAPIClient decodes these; all Model Hub views use them as data source.
// Affected API: Codable DTOs matching fusion-model-hub /api/v1/* JSON responses.
// Data schemas: JSON response shapes from upstream routers (models/quantize/downloads/cluster/monitor/auth/system/hardware/benchmarks).
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

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
    let name: String?
    let displayName: String?
    let modelPath: String?
    let engineType: String?
    let format: String?
    let sizeBytes: Int?
    let quantization: String?
    let parameters: String?
    let family: String?
    let isDownloaded: Bool?
    let isActive: Bool?
    let isPinned: Bool?
    let allowedModules: [String]?
    let versions: [HubModelVersion]?
    let source: String?
    let description: String?
    let tags: [String]?
    let downloads: Int?
    let likes: Int?
    let license: String?
    let task: String?
    let createdAt: String?
    let updatedAt: String?

    var displayTitle: String { displayName ?? name ?? id }
    var sizeGB: Double { Double(sizeBytes ?? 0) / 1_073_741_824.0 }
    var sizeFormatted: String { String(format: "%.1f GB", sizeGB) }

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

// MARK: - Cluster

struct HubClusterNodeListResponse: Codable {
    let nodes: [HubClusterNode]
    let total: Int?
}

struct HubClusterNode: Identifiable, Codable {
    let id: String
    let name: String?
    let host: String?
    let port: Int?
    let status: String?
    let models: [String]?
    let gpuType: String?
    let memoryGB: Double?
    let lastSeen: String?

    var isOnline: Bool { status == "online" || status == "active" }
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

// MARK: - Auth

struct HubAPIKeyListResponse: Codable {
    let keys: [HubAPIKey]
    let total: Int?
}

struct HubAPIKeyResponse: Codable {
    let key: HubAPIKey
    let rawKey: String?
}

struct HubAPIKey: Identifiable, Codable {
    let id: String
    let name: String?
    let prefix: String?
    let allowedModels: [String]?
    let allowedModules: [String]?
    let rateLimitQpm: Int?
    let isActive: Bool?
    let createdAt: String?
    let lastUsed: String?
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

// MARK: - Benchmarks

struct HubBenchmarkCompareResponse: Codable {
    let benchmarks: [HubBenchmarkEntry]
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
    let completedAt: String?
}

// MARK: - Inference

struct HubInferenceResponse: Codable {
    let id: String?
    let content: String?
    let model: String?
    let usage: HubInferenceUsage?
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
}
