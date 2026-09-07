import Foundation
import os.log

// ARCH-1 (PR-C1) Phase 4: Autoscaler 行为迁入。MultiNodeEngine 留 1 行 stub 转发 (保外部签名)。
//   跨域写: 0 (纯本域 @Published: autoscalerConfig/alerts/suggestions)。
//   协调器 (handleError/assertNoSplitBrain) 留 engine → 经 bridge?.X reach-through。
//   HTTP infra (get/put, session, baseURL, authHeaders) 留 engine → 经 bridge?.X reach-through。
//   canMutate/activeMasterHost (engine 计算属性) → bridge?.canMutate / bridge?.activeMasterHost。

private let mnAutoscalerLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeAutoscalerService")

extension MultiNodeAutoscalerState {

    func fetchAutoscalerConfig() {
        bridge?.get("/api/v1/autoscaler/config") { [weak self] (result: Result<AutoscalerConfig, Error>) in
            switch result {
            case .success(let config):
                DispatchQueue.main.async { self?.autoscalerConfig = config }
            case .failure:
                mnAutoscalerLog.debug("Autoscaler config not available, using default")
            }
        }
    }

    func fetchSuggestions() {
        bridge?.get("/api/v1/observability/suggestions") { [weak self] (result: Result<SuggestionsResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.suggestions = Array(resp.suggestions.prefix(200)) }
            case .failure:
                break
            }
        }
    }

    func fetchAlerts() {
        bridge?.get("/api/v1/observability/alerts") { [weak self] (result: Result<AlertsResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { self?.alerts = Array(resp.alerts.prefix(200)) }
            case .failure:
                mnAutoscalerLog.debug("Alerts endpoint not available yet")
            }
        }
    }

    func updateAutoscalerConfig(_ config: AutoscalerConfig) async throws {
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "autoscaler", targetNode: nil, targetTask: nil,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        do {
            let body: [String: Any] = [
                "min_nodes": config.minNodes,
                "max_nodes": config.maxNodes,
                "scale_up_threshold": config.scaleUpThreshold,
                "scale_down_threshold": config.scaleDownThreshold,
                "cooldown_seconds": config.cooldownSeconds,
            ]
            _ = try await bridge?.put("/api/v1/autoscaler/config", body: body)
            fetchAutoscalerConfig()
            ClusterAuditor.shared.record(action: "autoscaler", targetNode: nil, targetTask: nil,
                                         result: "ok", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "autoscaler", targetNode: nil, targetTask: nil,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }
}
