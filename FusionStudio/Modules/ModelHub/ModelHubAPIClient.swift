// Callers: ModelHubMainView, DashboardView, MarketView, LocalStorageView, ConvertQuantView, etc.
// Affected API: fusion-model-hub REST API on port 11444, prefix /api/v1, 20+ endpoints.
// Data schemas: Codable DTOs from ModelHubModels.swift.
// User instruction: issue #63 — market search, modules, benchmarks, scheduling, QPS

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

    func pinModel(modelId: String, pin: Bool) async throws -> HubSimpleResponse {
        if pin {
            return try await post("/api/v1/models/\(modelId)/pin", json: ["pinned": pin])
        } else {
            return try await delete("/api/v1/models/\(modelId)/pin")
        }
    }

    // MARK: - Serve (deploy to MLX)

    func serveModel(modelId: String, autoStart: Bool = true, ttlSeconds: Int? = nil) async throws -> HubServeResponse {
        var json: [String: Any] = ["model_id": modelId, "auto_start": autoStart]
        if let ttlSeconds { json["ttl_seconds"] = ttlSeconds }
        return try await post("/api/v1/models/\(modelId)/serve", json: json)
    }

    func unserveModel(modelId: String) async throws -> HubSimpleResponse {
        try await delete("/api/v1/models/\(modelId)/serve")
    }

    func getServeStatus(modelId: String) async throws -> HubServeResponse {
        try await get("/api/v1/models/\(modelId)/serve")
    }

    // MARK: - Modules (PUT to match upstream)

    func setModelModules(modelId: String, modules: [String]) async throws -> HubSimpleResponse {
        try await put("/api/v1/models/\(modelId)/modules", json: ["allowed_modules": modules])
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

    func cancelDownload(taskId: String) async throws -> HubSimpleResponse {
        try await delete("/api/v1/downloads/\(taskId)")
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

    func startLayeredQuantize(modelId: String, format: String = "mlx", bits: Int = 4, kvCacheOptimize: Bool = false, attentionQuantize: Bool = false) async throws -> HubQuantizeTaskResponse {
        var json: [String: Any] = [
            "model_id": modelId,
            "target_format": format,
            "bits": bits,
        ]
        if kvCacheOptimize { json["kv_cache_optimize"] = true }
        if attentionQuantize { json["attention_layer_quantize"] = true }
        return try await post("/api/v1/quantize/layered", json: json)
    }

    func getLayeredQuantizeJob(taskId: String) async throws -> HubQuantizeTask {
        try await get("/api/v1/quantize/layered/jobs/\(taskId)")
    }

    func evaluateQuantize(taskId: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/quantize/evaluate", json: ["task_id": taskId])
    }

    func applyQuantizePreset(name: String, modelId: String) async throws -> HubQuantizeTaskResponse {
        try await post("/api/v1/quantize/presets/\(name)/apply", json: ["model_id": modelId])
    }

    func compareQuantize(taskId: String) async throws -> HubBenchmarkCompareResponse {
        try await get("/api/v1/quantize/\(taskId)/compare")
    }

    // MARK: - Benchmarks (issue #63 sub-feature 3)

    func triggerBenchmark(modelId: String, template: String = "general") async throws -> HubSimpleResponse {
        try await post("/api/v1/benchmarks/trigger", json: ["model_id": modelId, "template": template])
    }

    func getBenchmarkCompare(modelIds: [String]) async throws -> HubBenchmarkCompareResponse {
        try await get("/api/v1/benchmarks/compare", query: [
            URLQueryItem(name: "model_ids", value: modelIds.joined(separator: ",")),
        ])
    }

    func listBenchmarks(limit: Int = 50) async throws -> HubBenchmarkListResponse {
        try await get("/api/v1/benchmarks", query: [
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    func getBenchmarkDetail(id: String) async throws -> HubBenchmarkDetail {
        try await get("/api/v1/benchmarks/\(id)")
    }

    // MARK: - Cluster / Smart Scheduling (issue #63 sub-feature 4)

    func listClusterNodes() async throws -> HubClusterNodeListResponse {
        try await get("/api/v1/cluster/nodes")
    }

    func syncClusterModel(modelId: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/cluster/sync-model", json: ["model_id": modelId])
    }

    func routeInference(modelId: String, messages: [[String: String]], mode: String = "auto") async throws -> HubInferenceResponse {
        try await post("/api/v1/cluster/route-inference", json: [
            "model_id": modelId,
            "messages": messages,
            "mode": mode,
        ])
    }

    func getClusterTopology() async throws -> HubClusterTopologyResponse {
        try await get("/api/v1/cluster/topology")
    }

    // MARK: - Monitor

    func getRealtimeMonitor() async throws -> HubMonitorResponse {
        try await get("/api/v1/monitor/realtime")
    }

    func getModelStats() async throws -> HubModelInferenceStatsListResponse {
        try await get("/api/v1/monitor/model-stats")
    }

    // MARK: - Auth / API Keys (issue #63 sub-feature 5)

    func listAPIKeys() async throws -> HubAPIKeyListResponse {
        try await get("/api/v1/auth/keys")
    }

    func createAPIKey(name: String, allowedModels: [String]? = nil, allowedModules: [String]? = nil, qpsLimit: Int? = nil) async throws -> HubAPIKeyResponse {
        var json: [String: Any] = ["name": name]
        if let allowedModels { json["allowed_models"] = allowedModels.joined(separator: ",") }
        if let allowedModules { json["allowed_modules"] = allowedModules.joined(separator: ",") }
        if let qpsLimit { json["qps_limit"] = qpsLimit }
        return try await post("/api/v1/auth/keys", json: json)
    }

    func deactivateAPIKey(keyId: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/auth/keys/\(keyId)/deactivate", json: [:])
    }

    func getAPIKeyUsage(keyId: String) async throws -> HubAPIKeyUsageResponse {
        try await get("/api/v1/auth/keys/\(keyId)/usage")
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

    func updateVersionStatus(versionId: String, status: String) async throws -> HubSimpleResponse {
        try await put("/api/v1/versions/\(versionId)/status", json: ["status": status])
    }

    func promoteVersion(versionId: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/versions/\(versionId)/promote", json: [:])
    }

    func deprecateVersion(versionId: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/versions/\(versionId)/deprecate", json: [:])
    }

    func retireVersion(versionId: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/versions/\(versionId)/retire", json: [:])
    }

    // MARK: - Deployments

    func listDeployments() async throws -> HubDeploymentListResponse {
        try await get("/api/v1/deployments")
    }

    func createDeployment(modelId: String, strategy: String? = nil, scale: Int? = nil, canaryPercent: Int? = nil) async throws -> HubDeployment {
        var json: [String: Any] = ["model_id": modelId]
        if let strategy { json["strategy"] = strategy }
        if let scale { json["scale"] = scale }
        if let canaryPercent { json["canary_percent"] = canaryPercent }
        return try await post("/api/v1/deployments", json: json)
    }

    func getDeployment(id: String) async throws -> HubDeployment {
        try await get("/api/v1/deployments/\(id)")
    }

    func stopDeployment(id: String) async throws -> HubSimpleResponse {
        try await post("/api/v1/deployments/\(id)/stop", json: [:])
    }

    func deleteDeployment(id: String) async throws -> HubSimpleResponse {
        try await delete("/api/v1/deployments/\(id)")
    }

    func scaleDeployment(id: String, scale: Int) async throws -> HubSimpleResponse {
        try await post("/api/v1/deployments/\(id)/scale", json: ["scale": scale])
    }

    func grayReleaseDeployment(id: String, canaryPercent: Int) async throws -> HubSimpleResponse {
        try await post("/api/v1/deployments/\(id)/gray", json: ["gray_traffic_ratio": canaryPercent])
    }

    func getDeploymentMetrics(id: String) async throws -> HubDeploymentMetricsResponse {
        try await get("/api/v1/deployments/\(id)/metrics")
    }

    // MARK: - Evaluations

    func listEvaluations(modelId: String? = nil) async throws -> HubEvaluationListResponse {
        var query: [URLQueryItem] = []
        if let modelId { query.append(URLQueryItem(name: "model_id", value: modelId)) }
        return try await get("/api/v1/evaluations", query: query)
    }

    func createEvaluation(modelId: String, template: String? = nil) async throws -> HubEvaluation {
        var json: [String: Any] = ["model_id": modelId]
        if let template { json["template"] = template }
        return try await post("/api/v1/evaluations", json: json)
    }

    func getEvaluation(id: String) async throws -> HubEvaluation {
        try await get("/api/v1/evaluations/\(id)")
    }

    func deleteEvaluation(id: String) async throws -> HubSimpleResponse {
        try await delete("/api/v1/evaluations/\(id)")
    }

    func compareEvaluations(ids: [String]) async throws -> HubEvaluationCompareResponse {
        try await get("/api/v1/evaluations/compare", query: [
            URLQueryItem(name: "evaluation_ids", value: ids.joined(separator: ",")),
        ])
    }

    // MARK: - Tenants

    func listTenants() async throws -> HubTenantListResponse {
        try await get("/api/v1/tenants")
    }

    func createTenant(name: String, role: String? = nil, allowedModels: [String]? = nil, allowedModules: [String]? = nil, qpsLimit: Int? = nil) async throws -> HubTenant {
        var json: [String: Any] = ["name": name]
        if let role { json["role"] = role }
        if let allowedModels { json["allowed_models"] = allowedModels }
        if let allowedModules { json["allowed_modules"] = allowedModules }
        if let qpsLimit { json["qps_limit"] = qpsLimit }
        return try await post("/api/v1/tenants", json: json)
    }

    func updateTenant(id: String, role: String? = nil, allowedModels: [String]? = nil, allowedModules: [String]? = nil, qpsLimit: Int? = nil) async throws -> HubTenant {
        var json: [String: Any] = [:]
        if let role { json["role"] = role }
        if let allowedModels { json["allowed_models"] = allowedModels }
        if let allowedModules { json["allowed_modules"] = allowedModules }
        if let qpsLimit { json["qps_limit"] = qpsLimit }
        return try await put("/api/v1/tenants/\(id)", json: json)
    }

    func deleteTenant(id: String) async throws -> HubSimpleResponse {
        try await delete("/api/v1/tenants/\(id)")
    }

    // MARK: - Roles

    func listRoles(tenantId: String) async throws -> HubRoleListResponse {
        try await get("/api/v1/tenants/\(tenantId)/roles")
    }

    func createRole(tenantId: String, name: String, permissions: [String]? = nil) async throws -> HubRole {
        var json: [String: Any] = ["name": name]
        if let permissions { json["permissions"] = permissions.joined(separator: ",") }
        return try await post("/api/v1/tenants/\(tenantId)/roles", json: json)
    }

    func updateRole(tenantId: String, roleId: String, name: String? = nil, permissions: [String]? = nil) async throws -> HubRole {
        var json: [String: Any] = [:]
        if let name { json["name"] = name }
        if let permissions { json["permissions"] = permissions.joined(separator: ",") }
        return try await put("/api/v1/tenants/\(tenantId)/roles/\(roleId)", json: json)
    }

    func deleteRole(tenantId: String, roleId: String) async throws -> HubSimpleResponse {
        try await delete("/api/v1/tenants/\(tenantId)/roles/\(roleId)")
    }

    // MARK: - Webhooks

    func listWebhooks() async throws -> HubWebhookListResponse {
        try await get("/api/v1/webhooks")
    }

    func createWebhook(url: String, events: [String]? = nil) async throws -> HubWebhook {
        var json: [String: Any] = ["url": url]
        if let events { json["events"] = events }
        return try await post("/api/v1/webhooks", json: json)
    }

    func deleteWebhook(id: String) async throws -> HubSimpleResponse {
        try await delete("/api/v1/webhooks/\(id)")
    }

    // MARK: - Security

    func triggerSecurityScan(modelId: String) async throws -> HubSecurityScanResponse {
        try await post("/api/v1/security/scan", json: ["model_id": modelId])
    }

    func getSecurityScanResult(modelId: String) async throws -> HubSecurityScanResponse {
        try await get("/api/v1/security/scan/\(modelId)")
    }

    // MARK: - Watermark

    func embedWatermark(modelId: String, text: String? = nil) async throws -> HubWatermarkResponse {
        var json: [String: Any] = ["model_id": modelId]
        if let text { json["watermark_text"] = text }
        return try await post("/api/v1/watermark/embed", json: json)
    }

    func verifyWatermark(modelId: String) async throws -> HubWatermarkResponse {
        try await post("/api/v1/watermark/verify", json: ["model_id": modelId])
    }

    // MARK: - Encryption

    func encryptModel(modelId: String, algorithm: String? = nil) async throws -> HubEncryptionResponse {
        var json: [String: Any] = ["model_id": modelId]
        if let algorithm { json["algorithm"] = algorithm }
        return try await post("/api/v1/encryption/encrypt", json: json)
    }

    func decryptModel(modelId: String) async throws -> HubEncryptionResponse {
        try await post("/api/v1/encryption/decrypt", json: ["model_id": modelId])
    }

    func getEncryptionStatus(modelId: String) async throws -> HubEncryptionResponse {
        try await get("/api/v1/encryption/status/\(modelId)")
    }

    // MARK: - Approvals

    func listApprovals(status: String? = nil) async throws -> HubApprovalListResponse {
        var query: [URLQueryItem] = []
        if let status { query.append(URLQueryItem(name: "status", value: status)) }
        return try await get("/api/v1/approvals", query: query)
    }

    func submitApproval(modelId: String, operation: String, level: String? = nil) async throws -> HubApproval {
        var json: [String: Any] = ["model_id": modelId, "operation": operation]
        if let level { json["level"] = level }
        return try await post("/api/v1/approvals", json: json)
    }

    func approveRequest(id: String, comment: String? = nil) async throws -> HubSimpleResponse {
        var json: [String: Any] = ["approved": true]
        if let comment { json["comment"] = comment }
        return try await post("/api/v1/approvals/\(id)/approve", json: json)
    }

    func rejectRequest(id: String, comment: String? = nil) async throws -> HubSimpleResponse {
        var json: [String: Any] = ["approved": false]
        if let comment { json["comment"] = comment }
        return try await post("/api/v1/approvals/\(id)/reject", json: json)
    }

    // MARK: - Ratings

    func listRatings(modelId: String) async throws -> HubRatingListResponse {
        try await get("/api/v1/models/\(modelId)/ratings")
    }

    func createRating(modelId: String, score: Int, summary: String? = nil) async throws -> HubRating {
        var json: [String: Any] = ["model_id": modelId, "score": score]
        if let summary { json["summary"] = summary }
        return try await post("/api/v1/models/\(modelId)/ratings", json: json)
    }

    func getRatingSummary(modelId: String) async throws -> HubRatingSummaryResponse {
        try await get("/api/v1/models/\(modelId)/ratings/summary")
    }

    // MARK: - Favorites

    func listFavorites() async throws -> HubFavoriteListResponse {
        try await get("/api/v1/favorites")
    }

    func addFavorite(modelId: String) async throws -> HubFavorite {
        try await post("/api/v1/favorites", json: ["model_id": modelId])
    }

    func removeFavorite(modelId: String) async throws -> HubSimpleResponse {
        try await delete("/api/v1/favorites/\(modelId)")
    }

    // MARK: - Branches

    func listBranches(modelId: String) async throws -> HubBranchListResponse {
        try await get("/api/v1/models/\(modelId)/branches")
    }

    func createBranch(modelId: String, name: String) async throws -> HubBranch {
        try await post("/api/v1/models/\(modelId)/branches", json: ["name": name])
    }

    func mergeBranch(branchId: String) async throws -> HubBranch {
        try await post("/api/v1/models/branches/\(branchId)/merge", json: [:])
    }

    func deleteBranch(branchId: String) async throws -> HubSimpleResponse {
        try await delete("/api/v1/models/branches/\(branchId)")
    }

    // MARK: - Recommend

    func getRecommendations(task: String? = nil, limit: Int = 10) async throws -> HubRecommendResponse {
        var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let task { query.append(URLQueryItem(name: "task", value: task)) }
        return try await get("/api/v1/recommend", query: query)
    }

    func getQuickRecommend() async throws -> HubRecommendResponse {
        try await get("/api/v1/recommend/quick")
    }

    // MARK: - Adapt

    func assessAdapt(modelId: String) async throws -> HubAdaptAssessResponse {
        try await post("/api/v1/adapt/assess", json: ["model_id": modelId])
    }

    func planAdapt(modelId: String) async throws -> HubAdaptPlanResponse {
        try await post("/api/v1/adapt/plan", json: ["model_id": modelId])
    }

    func executeAdapt(modelId: String) async throws -> HubAdaptExecuteResponse {
        try await post("/api/v1/adapt/execute", json: ["model_id": modelId])
    }

    // MARK: - Sync

    func pushSync(modelIds: [String], targetNode: String) async throws -> HubSyncPushResponse {
        try await post("/api/v1/sync/push", json: ["model_ids": modelIds, "target_node": targetNode])
    }

    func pullSync(modelIds: [String], sourceNode: String) async throws -> HubSyncPullResponse {
        try await post("/api/v1/sync/pull", json: ["model_ids": modelIds, "source_node": sourceNode])
    }

    // MARK: - Hardware refresh

    func refreshHardware() async throws -> HubHardwareResponse {
        try await post("/api/v1/hardware/refresh", json: [:])
    }

    // MARK: - Health check

    func checkConnection() async {
        do {
            let _: HubHealthResponse = try await get("/api/v1/system/health")
            isConnected = true
            lastError = nil
        } catch {
            isConnected = false
            lastError = BridgeError.sanitize(error)
            apiLog.warning("Model-Hub connection failed: \(error.localizedDescription)")
        }
    }

    // MARK: - HTTP helpers

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var comps = URLComponents(string: "\(baseURL)\(path)")!
        if !query.isEmpty { comps.queryItems = query }
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        try addAuth(&request)
        return try await execute(request)
    }

    func post<T: Decodable>(_ path: String, json: [String: Any] = [:]) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        try addAuth(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        return try await execute(request)
    }

    private func put<T: Decodable>(_ path: String, json: [String: Any] = [:]) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        try addAuth(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        return try await execute(request)
    }

    private func patch<T: Decodable>(_ path: String, json: [String: Any] = [:]) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        try addAuth(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: json)
        return try await execute(request)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try addAuth(&request)
        return try await execute(request)
    }

    // Callers: get/post/put/patch/delete helpers all call addAuth() before execute()
    // Affected API: every ModelHubAPIClient HTTP request -> upstream fusion-model-hub X-API-Key header
    // Data schemas:
    // User instruction: "和~/fusion/fuison-models-hub项目集成起来...最后要完成端到端测试，确保系统可用"
    // 审计0902 R7 (P2): 旧实现空 apiKey 静默跳过认证头 (fail-open) → 请求裸发 → 上游 401 →
    //   httpError(401) 误诊为服务端故障, UI 报 "401" 而非 "未配置凭据"。
    //   修复: 空 key fail-fast 抛 unauthenticated, 对齐 MlxHTTPClient L178-180。
    private func addAuth(_ request: inout URLRequest) throws {
        guard !apiKey.isEmpty else {
            apiLog.error("addAuth: modelHubApiKey 为空, fail-fast unauthenticated (不裸发请求)")
            throw HubAPIError.unauthenticated
        }
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
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
    // 审计0902 R7 (P2): 空 apiKey fail-fast (非静默跳过认证头)。缺 key 误诊为服务端 401,
    //   对齐 MlxHTTPError.unauthenticated (MlxHTTPClient L178-180)。
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response"
        case .httpError(let code, let body): return "HTTP \(code): \(body.prefix(100))"
        case .decodeError(let msg): return "Decode error: \(msg)"
        case .unauthenticated: return "未配置 ModelHub API Key, 请先在设置中填写凭据"
        }
    }
}
