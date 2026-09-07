import Foundation
import os.log

// ARCH-1 (PR-C1) Phase 5: Routing 行为迁入。MultiNodeEngine 留 1 行 stub 转发 (保外部签名)。
//   Routing 域 0 @Published — 纯方法域 (路由策略查询/设置)。
//   协调器 (handleError/assertNoSplitBrain) 留 engine → 经 bridge?.X reach-through。
//   HTTP infra (get/post, session, baseURL, authHeaders) 留 engine → 经 bridge?.X reach-through。
//   canMutate/activeMasterHost (engine 计算属性) → bridge?.canMutate / bridge?.activeMasterHost。

private let mnRoutingLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeRoutingService")

extension MultiNodeRoutingState {

    func fetchRoutingSummary(completion: @escaping (Result<RoutingSummary, Error>) -> Void) {
        bridge?.get("/api/routing/summary") { result in completion(result) }
    }

    func setRoutingStrategy(_ strategy: String) async throws {
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "setRouting", targetNode: nil, targetTask: nil,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        do {
            _ = try await bridge?.post("/api/routing/strategy", body: ["strategy": strategy])
            ClusterAuditor.shared.record(action: "setRouting", targetNode: nil, targetTask: nil,
                                         result: "ok", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "setRouting", targetNode: nil, targetTask: nil,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }
}
