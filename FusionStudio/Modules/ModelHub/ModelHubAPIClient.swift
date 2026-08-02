// Callers: ModelHubMainView, DashboardView, MarketView, LocalStorageView, ConvertQuantView, etc.
// Affected API: fusion-model-hub REST API on port 11444, prefix /api/v1, 20+ endpoints.
// Data schemas: Codable DTOs from ModelHubModels.swift.
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import Foundation
import os.log

private let apiLog = Logger(subsystem: "com.fusion.studio", category: "ModelHubAPI")

final class ModelHubAPIClient: ObservableObject {
    static let shared = ModelHubAPIClient()

    @Published var isConnected = false
    @Published var lastError: String?

    private var baseURL: String {
        "http://\(FusionConfig.shared.modelHubHost):\(FusionConfig.shared.modelHubPort)"
    }

    private var apiKey: String {
        FusionConfig.shared.modelHubApiKey
    }

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    // MARK: - Models

    func listModels() async throws -> HubModelListResponse {
        try await get("/api/v1/models")
    }

    func getModel(modelId: String) async throws -> HubModel {
        try await get("/api/v1/models/\(modelId)")
    }

    func searchMarket(query: String, source: String? = nil, task: String? = nil, format: String? = nil, limit: Int = 20) async throws -> HubMarketSearchResponse {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let source { items.append(URLQueryItem(name: "source", value: source)) }
        if let task { items.append(URLQueryItem(name: "task", value: task)) }
        if let format { items.append(URLQueryItem(name: "format", value: format)) }
        return try await get("/api/v1/models/market/search", query: items)
    }

    func deleteModel(modelId: String) async throws -> HubSimpleResponse {
        try await delete("/api/v1/models/\(modelId)")
    }

    func batchDeleteModels(ids: [String]) async throws -> HubSimpleResponse {
        try await post("/api/v1/models/batch/delete", json: ["model_ids": ids])
    }

    func importHF(repoId: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/models/import/hf", json: ["repo_id": repoId])
    }

    func setModelModules(modelId: String, modules: [String]) async throws -> HubSimpleResponse {
        try await put("/api/v1/models/\(modelId)/modules", json: ["allowed_modules": modules])
    }

    func pinModel(modelId: String, pin: Bool) async throws -> HubSimpleResponse {
        try await post("/api/v1/models/\(modelId)/pin", json: ["pinned": pin])
    }

    // MARK: - Downloads

    func createDownload(repoId: String, source: String = "huggingface", format: String = "mlx", quantization: String = "4bit") async throws -> HubDownloadTaskResponse {
        try await post("/api/v1/downloads", json: [
            "repo_id": repoId,
            "source": source,
            "target_format": format,
            "quantization": quantization,
        ])
    }

    func listDownloads() async throws -> HubDownloadListResponse {
        try await get("/api/v1/downloads")
    }

    func getDownload(taskId: String) async throws -> HubDownloadTask {
        try await get("/api/v1/downloads/\(taskId)")
    }

    // MARK: - Quantize

    func startQuantize(modelId: String, format: String = "mlx", bits: Int = 4, preset: String? = nil) async throws -> HubQuantizeTaskResponse {
        var json: [String: Any] = [
            "model_id": modelId,
            "target_format": format,
            "bits": bits,
        ]
        if let preset { json["preset"] = preset }
        return try await post("/api/v1/quantize", json: json)
    }

    func getQuantizeTask(taskId: String) async throws -> HubQuantizeTask {
        try await get("/api/v1/quantize/\(taskId)")
    }

    func listQuantizePresets() async throws -> HubPresetListResponse {
        try await get("/api/v1/quantize/presets")
    }

    func listRunningQuantize() async throws -> HubQuantizeTaskListResponse {
        try await get("/api/v1/quantize/running")
    }

    func batchQuantize(modelIds: [String], format: String = "mlx", bits: Int = 4) async throws -> HubQuantizeTaskListResponse {
        try await post("/api/v1/quantize/batch", json: [
            "model_ids": modelIds,
            "target_format": format,
            "bits": bits,
        ])
    }

    // MARK: - Cluster

    func listClusterNodes() async throws -> HubClusterNodeListResponse {
        try await get("/api/v1/cluster/nodes")
    }

    func syncClusterModel(modelId: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/cluster/sync-model", json: ["model_id": modelId])
    }

    // MARK: - Monitor

    func getRealtimeMonitor() async throws -> HubMonitorResponse {
        try await get("/api/v1/monitor/realtime")
    }

    // MARK: - Auth / API Keys

    func listAPIKeys() async throws -> HubAPIKeyListResponse {
        try await get("/api/v1/auth/keys")
    }

    func createAPIKey(name: String, allowedModels: [String]? = nil, allowedModules: [String]? = nil, rateLimit: Int? = nil) async throws -> HubAPIKeyResponse {
        var json: [String: Any] = ["name": name]
        if let allowedModels { json["allowed_models"] = allowedModels }
        if let allowedModules { json["allowed_modules"] = allowedModules }
        if let rateLimit { json["rate_limit_qpm"] = rateLimit }
        return try await post("/api/v1/auth/keys", json: json)
    }

    func deactivateAPIKey(keyId: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/auth/keys/\(keyId)/deactivate", json: [:])
    }

    // MARK: - System

    func getSystemHealth() async throws -> HubHealthResponse {
        try await get("/api/v1/system/health")
    }

    func getSystemStorage() async throws -> HubStorageResponse {
        try await get("/api/v1/system/storage")
    }

    func scanDuplicates() async throws -> HubSimpleResponse {
        try await get("/api/v1/system/scan-duplicates")
    }

    func cleanupSystem() async throws -> HubSimpleResponse {
        try await post("/api/v1/system/cleanup", json: [:])
    }

    func getAuditLog(limit: Int = 50) async throws -> HubAuditLogResponse {
        try await get("/api/v1/system/audit", query: [URLQueryItem(name: "limit", value: String(limit))])
    }

    // MARK: - Hardware

    func getHardware() async throws -> HubHardwareResponse {
        try await get("/api/v1/hardware")
    }

    // MARK: - Benchmarks

    func triggerBenchmark(modelId: String, template: String = "general") async throws -> HubSimpleResponse {
        try await post("/api/v1/benchmarks/compare", json: ["model_id": modelId, "template": template])
    }

    func getBenchmarkCompare(modelIds: [String]) async throws -> HubBenchmarkCompareResponse {
        try await get("/api/v1/benchmarks/compare", query: [
            URLQueryItem(name: "model_ids", value: modelIds.joined(separator: ",")),
        ])
    }

    // MARK: - Inference proxy

    func inferenceChat(modelId: String, messages: [[String: String]]) async throws -> HubInferenceResponse {
        try await post("/api/v1/inference/\(modelId)/chat", json: ["messages": messages])
    }

    // MARK: - Versions

    func listVersions(modelId: String) async throws -> HubVersionListResponse {
        try await get("/api/v1/models/\(modelId)/versions")
    }

    func rollbackVersion(versionId: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/versions/\(versionId)/rollback", json: [:])
    }

    // MARK: - Health check

    func checkConnection() async {
        do {
            let _: HubHealthResponse = try await get("/api/v1/system/health")
            isConnected = true
            lastError = nil
        } catch {
            isConnected = false
            lastError = error.localizedDescription
            apiLog.warning("Model-Hub connection failed: \(error.localizedDescription)")
        }
    }

    // MARK: - HTTP helpers

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var comps = URLComponents(string: "\(baseURL)\(path)")!
        if !query.isEmpty { comps.queryItems = query }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        addAuth(&request)
        return try await execute(request)
    }

    private func post<T: Decodable>(_ path: String, json: [String: Any] = [:]) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        addAuth(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        return try await execute(request)
    }

    private func put<T: Decodable>(_ path: String, json: [String: Any] = [:]) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        addAuth(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        return try await execute(request)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addAuth(&request)
        return try await execute(request)
    }

    private func addAuth(_ request: inout URLRequest) {
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        apiLog.debug("\(request.httpMethod ?? "?") \(request.url?.path ?? "?")")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HubAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            apiLog.error("API \(http.statusCode): \(request.url?.path ?? "?") \(body.prefix(200))")
            throw HubAPIError.httpError(http.statusCode, body)
        }
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            apiLog.error("Decode failed for \(request.url?.path ?? "?"): \(error.localizedDescription)")
            throw HubAPIError.decodeError(error.localizedDescription)
        }
    }
}

enum HubAPIError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case decodeError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response"
        case .httpError(let code, let body): return "HTTP \(code): \(body.prefix(100))"
        case .decodeError(let msg): return "Decode error: \(msg)"
        }
    }
}
