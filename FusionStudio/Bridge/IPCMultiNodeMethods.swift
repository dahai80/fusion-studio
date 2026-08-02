// Callers: HubClusterView, HubLocalStorageView, ClusterOverviewView, TaskMonitorView, RoutingStrategyView
// Affected API: fusion-multi-node MasterServer REST API (34 endpoints on port 11452)
// Data schemas: MultiNodeNodeInfo, MultiNodeTaskInfo, MultiNodeKVEntry, MultiNodeAlert
// User instruction: "#74 multi-node 集群同步上游已完成，#61 的 6 项整改马上进行"

import Foundation
import os.log

private let mnLog = Logger(subsystem: "com.fusion.studio", category: "MultiNode")

extension IPCClient {

    private var multiNodeBaseURL: String {
        "http://\(FusionConfig.shared.modelHubHost):11452"
    }

    private func mnRequest(_ method: String, path: String, body: [String: Any]? = nil, timeout: TimeInterval = 15) async throws -> [String: Any] {
        guard let url = URL(string: "\(multiNodeBaseURL)\(path)") else {
            throw IPCError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw IPCError.invalidResponse
        }
        guard http.statusCode >= 200 && http.statusCode < 300 else {
            var errMsg = "HTTP \(http.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                errMsg = detail
            }
            mnLog.error("MultiNode \(method) \(path) failed: \(errMsg)")
            throw IPCError.rpcError(code: http.statusCode, message: errMsg)
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }

    // MARK: - Health

    func mnHealth() async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/health")
    }

    // MARK: - Cluster Sync (Issue #5)

    func mnGetModelManifest(modelName: String) async throws -> [String: Any] {
        let encoded = modelName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? modelName
        return try await mnRequest("GET", path: "/api/models/\(encoded)/manifest")
    }

    func mnIncrementalSync(modelName: String, sourceHost: String, sourcePort: Int = 11452, remoteManifest: [String: Any]? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [
            "model_name": modelName,
            "source_host": sourceHost,
            "source_port": sourcePort,
        ]
        if let remoteManifest = remoteManifest {
            body["remote_manifest"] = remoteManifest
        }
        return try await mnRequest("POST", path: "/api/sync/incremental", body: body)
    }

    func mnClusterSyncStatus() async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/cluster/status")
    }

    func mnGetNodeLoad(nodeId: String) async throws -> [String: Any] {
        let encoded = nodeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? nodeId
        return try await mnRequest("GET", path: "/api/nodes/\(encoded)/load")
    }

    // MARK: - Manual Join (M1-05)

    func mnManualJoin(nodeId: String, hostname: String, ipAddress: String, port: Int = 11445) async throws -> [String: Any] {
        try await mnRequest("POST", path: "/api/join", body: [
            "node_id": nodeId,
            "hostname": hostname,
            "ip_address": ipAddress,
            "port": port,
        ])
    }

    // MARK: - Node Management

    func mnRegisterNode(nodeId: String, hostname: String, ipAddress: String, port: Int = 11445, arch: String = "arm64", totalMemoryGb: Double = 0, availableMemoryGb: Double = 0, cpuCores: Int = 0, gpuCores: Int = 0, deviceModel: String = "", umaSizeGb: Double = 0, mlxVersion: String = "", role: String = "worker", tags: [String] = [], activeTasks: Int = 0, maxTasks: Int = 4, networkRttMs: Double = 0) async throws -> [String: Any] {
        try await mnRequest("POST", path: "/api/nodes/register", body: [
            "node_id": nodeId,
            "hostname": hostname,
            "ip_address": ipAddress,
            "port": port,
            "arch": arch,
            "total_memory_gb": totalMemoryGb,
            "available_memory_gb": availableMemoryGb,
            "cpu_cores": cpuCores,
            "gpu_cores": gpuCores,
            "device_model": deviceModel,
            "uma_size_gb": umaSizeGb,
            "mlx_version": mlxVersion,
            "role": role,
            "tags": tags,
            "active_tasks": activeTasks,
            "max_tasks": maxTasks,
            "network_rtt_ms": networkRttMs,
        ])
    }

    func mnHeartbeat(nodeId: String, availableMemoryGb: Double? = nil, activeTasks: Int? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["node_id": nodeId]
        if let v = availableMemoryGb { body["available_memory_gb"] = v }
        if let v = activeTasks { body["active_tasks"] = v }
        return try await mnRequest("POST", path: "/api/nodes/heartbeat", body: body)
    }

    func mnReportFault(nodeId: String, faultType: String, message: String = "") async throws -> [String: Any] {
        try await mnRequest("POST", path: "/api/nodes/fault", body: [
            "node_id": nodeId,
            "fault_type": faultType,
            "message": message,
        ])
    }

    func mnUpdateLoad(nodeId: String, umaUsedRatio: Double, cpuPercent: Double, metalUtil: Double, taskQueueLen: Int, netRttMs: Double) async throws -> [String: Any] {
        try await mnRequest("POST", path: "/api/nodes/load", body: [
            "node_id": nodeId,
            "uma_used_ratio": umaUsedRatio,
            "cpu_percent": cpuPercent,
            "metal_util": metalUtil,
            "task_queue_len": taskQueueLen,
            "net_rtt_ms": netRttMs,
        ])
    }

    func mnListNodes() async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/nodes")
    }

    func mnGetNode(nodeId: String) async throws -> [String: Any] {
        let encoded = nodeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? nodeId
        return try await mnRequest("GET", path: "/api/nodes/\(encoded)")
    }

    func mnUnregisterNode(nodeId: String) async throws -> [String: Any] {
        let encoded = nodeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? nodeId
        return try await mnRequest("DELETE", path: "/api/nodes/\(encoded)")
    }

    // MARK: - Routing

    func mnSetRoutingStrategy(strategy: String) async throws -> [String: Any] {
        try await mnRequest("POST", path: "/api/routing/strategy", body: ["strategy": strategy])
    }

    func mnRoutingSummary() async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/routing/summary")
    }

    // MARK: - Task Management

    func mnSubmitTask(name: String, modelId: String, modelName: String = "", mode: String = "data", timeoutSeconds: Int = 300, user: String = "", requiredCapability: String = "", preferredNodeId: String = "", priority: Int = 0) async throws -> [String: Any] {
        var body: [String: Any] = [
            "name": name,
            "model_id": modelId,
            "mode": mode,
            "timeout_seconds": timeoutSeconds,
            "user": user,
        ]
        if !modelName.isEmpty { body["model_name"] = modelName }
        if !requiredCapability.isEmpty { body["required_capability"] = requiredCapability }
        if !preferredNodeId.isEmpty { body["preferred_node_id"] = preferredNodeId }
        if priority > 0 { body["priority"] = priority }
        return try await mnRequest("POST", path: "/api/tasks/submit", body: body, timeout: 30)
    }

    func mnListTasks() async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/tasks")
    }

    func mnGetTask(taskId: String) async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/tasks/\(taskId)")
    }

    func mnCancelTask(taskId: String, reason: String = "") async throws -> [String: Any] {
        try await mnRequest("POST", path: "/api/tasks/\(taskId)/cancel", body: ["reason": reason])
    }

    func mnDegradeTask(taskId: String) async throws -> [String: Any] {
        try await mnRequest("POST", path: "/api/tasks/\(taskId)/degrade")
    }

    func mnMigrateTask(taskId: String) async throws -> [String: Any] {
        try await mnRequest("POST", path: "/api/tasks/\(taskId)/migrate")
    }

    // MARK: - KV Cache

    func mnRegisterKV(cacheId: String, modelName: String, nodeId: String, sizeMb: Double = 0, ttlSeconds: Int = 3600) async throws -> [String: Any] {
        try await mnRequest("POST", path: "/api/kv/register", body: [
            "cache_id": cacheId,
            "model_name": modelName,
            "node_id": nodeId,
            "size_mb": sizeMb,
            "ttl_seconds": ttlSeconds,
        ])
    }

    func mnFindKV(modelName: String) async throws -> [String: Any] {
        let encoded = modelName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? modelName
        return try await mnRequest("GET", path: "/api/kv/find/\(encoded)")
    }

    // MARK: - Cluster Stats

    func mnClusterStats() async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/cluster/stats")
    }

    // MARK: - V1 Monitoring

    func mnV1ClusterStats() async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/v1/cluster/stats")
    }

    func mnV1NodeMetrics(nodeId: String) async throws -> [String: Any] {
        let encoded = nodeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? nodeId
        return try await mnRequest("GET", path: "/api/v1/nodes/\(encoded)/metrics")
    }

    func mnV1TaskProgress(taskId: String) async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/v1/tasks/\(taskId)/progress")
    }

    func mnV1TaskTimeline(taskId: String) async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/v1/tasks/\(taskId)/timeline")
    }

    // MARK: - Autoscaler (M10-04)

    func mnGetAutoscalerConfig() async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/v1/autoscaler/config")
    }

    func mnUpdateAutoscalerConfig(minNodes: Int? = nil, maxNodes: Int? = nil, scaleUpThreshold: Double? = nil, scaleDownThreshold: Double? = nil, cooldownSeconds: Int? = nil, idleTimeoutSeconds: Int? = nil, checkInterval: Int? = nil, rebalanceThreshold: Double? = nil) async throws -> [String: Any] {
        var body: [String: Any] = [:]
        if let v = minNodes { body["min_nodes"] = v }
        if let v = maxNodes { body["max_nodes"] = v }
        if let v = scaleUpThreshold { body["scale_up_threshold"] = v }
        if let v = scaleDownThreshold { body["scale_down_threshold"] = v }
        if let v = cooldownSeconds { body["cooldown_seconds"] = v }
        if let v = idleTimeoutSeconds { body["idle_timeout_seconds"] = v }
        if let v = checkInterval { body["check_interval"] = v }
        if let v = rebalanceThreshold { body["rebalance_threshold"] = v }
        return try await mnRequest("PUT", path: "/api/v1/autoscaler/config", body: body)
    }

    func mnUpdateAutoscalerPolicy(policy: String) async throws -> [String: Any] {
        try await mnRequest("PUT", path: "/api/v1/autoscaler/config", body: ["policy": policy])
    }

    // MARK: - Observability (M8)

    func mnExportLogs(format: String = "json", since: Double = 0, nodeId: String = "") async throws -> [String: Any] {
        var params = [URLQueryItem]()
        params.append(URLQueryItem(name: "fmt", value: format))
        if since > 0 { params.append(URLQueryItem(name: "since", value: String(since))) }
        if !nodeId.isEmpty { params.append(URLQueryItem(name: "node_id", value: nodeId)) }
        var comps = URLComponents(string: "\(multiNodeBaseURL)/api/v1/observability/logs/export")!
        comps.queryItems = params
        guard let url = comps.url else { throw IPCError.invalidRequest }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode >= 200, http.statusCode < 300 else {
            throw IPCError.invalidResponse
        }
        if format == "csv" {
            let text = String(data: data, encoding: .utf8) ?? ""
            return ["csv": text]
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return [:]
    }

    func mnGetOptimizationSuggestions() async throws -> [String: Any] {
        try await mnRequest("GET", path: "/api/v1/observability/suggestions")
    }

    func mnGetActiveAlerts(severity: String = "") async throws -> [String: Any] {
        var path = "/api/v1/observability/alerts"
        if !severity.isEmpty {
            let encoded = severity.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? severity
            path += "?severity=\(encoded)"
        }
        return try await mnRequest("GET", path: path)
    }
}
