// MlxModelDTO - fusion-mlx /admin/api/* JSON 响应数据类型。
// 复用自 fusion-mac Sources/Net/DTO/{HFTaskDTO,ModelsDTO}.swift，精简到引导所需。
// 配合 MlxHTTPClient 的 convertFromSnakeCase 解码 / convertToSnakeCase 编码。

import Foundation

struct EmptyResponse: Decodable {}

struct SimpleStatusResponse: Codable, Sendable {
    let status: String?
    let message: String?
    let success: Bool?
}

// MARK: - HF 下载任务

struct HFTaskListResponse: Codable, Sendable {
    let tasks: [HFTaskDTO]
}

struct HFTaskDTO: Codable, Equatable, Sendable, Identifiable {
    let taskId: String
    let repoId: String
    let status: String
    let progress: Double
    let totalSize: Int64
    let downloadedSize: Int64
    let error: String
    let createdAt: Double
    let startedAt: Double
    let completedAt: Double
    let retryCount: Int

    var id: String { taskId }

    enum Status: String {
        case pending, downloading, completed, failed, cancelled, paused
    }
    var statusEnum: Status? { Status(rawValue: status) }
    var isActive: Bool { statusEnum == .pending || statusEnum == .downloading }
}

struct StartHFDownloadRequest: Encodable, Sendable {
    let repoId: String
    let hfToken: String
}

struct StartHFDownloadResponse: Decodable, Sendable {
    let success: Bool
    let task: HFTaskDTO?
}

// MARK: - HF 模型发现

struct HFRecommendedResponse: Codable, Sendable {
    let trending: [HFModelInfo]
    let popular: [HFModelInfo]
}

struct HFSearchResponse: Codable, Sendable {
    let models: [HFModelInfo]
    let total: Int?
}

struct HFModelInfo: Codable, Equatable, Sendable, Identifiable {
    let repoId: String
    let name: String?
    let downloads: Int?
    let likes: Int?
    let trendingScore: Double?
    let size: Int64?
    let sizeFormatted: String?
    let params: Int64?
    let paramsFormatted: String?
    var id: String { repoId }
}

// MARK: - 已加载模型池

struct ListModelsResponse: Codable, Sendable {
    let models: [ModelDTO]
}

struct ModelDTO: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String?
    let modelPath: String?
    let loaded: Bool?
    let isLoading: Bool?
    let estimatedSize: Int64?
    let estimatedSizeFormatted: String?
    let pinned: Bool?
    let isDefault: Bool?
    let engineType: String?
    let modelType: String?
    let configModelType: String?
}

// MARK: - API Key 设置

struct SetupApiKeyRequest: Encodable, Sendable {
    let apiKey: String
    let apiKeyConfirm: String
}
