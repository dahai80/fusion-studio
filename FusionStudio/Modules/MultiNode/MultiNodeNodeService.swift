import Foundation
import os.log

// ARCH-1 (PR-C1) Phase 2: Node 行为迁入。MultiNodeEngine 留 1 行 stub 转发 (保外部签名:
//   ContentView/PollingService/其他 view 读站点 0 改)。
//   跨域写 (splitBrain: splitBrainConfirmCount/ResolvedConfirmCount/Detected/knownLeaderEpoch/Id;
//   clusterHealth: resetFailureState; polling: consecutiveFailuresByContext) 经
//   self.bridge?.<domain>.X reach-through。
//   协调器 (handleError/recomputeCanMutate/assertNoSplitBrain) 留 engine → 经 bridge?.X reach-through。
//   HTTP infra (get/post/put/delete, session, baseURL, authHeaders) 留 engine → 经 bridge?.X reach-through。
//   canMutate/activeMasterHost (engine 计算属性) → bridge?.canMutate / bridge?.activeMasterHost。

private let mnNodeLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeNodeService")

extension MultiNodeNodeState {

    func fetchNodes() {
        bridge?.get("/api/nodes") { [weak self] (result: Result<NodeListResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.nodes = Array(resp.nodes.prefix(500))
                    self.bridge?.clusterHealthState.resetFailureState(context: "nodes")
                    // F-A11 split-brain 检测 — 三层确定性信号, 取代旧 master-count heuristic:
                    //   1. #72 partitioned (server 权威: 少数派, 无法达仲裁) — 有则直接用, 无歧义。
                    //   2. #76 epoch/leader_id — epoch==0+leaderId=="" = 单权威 (单master/active-active, 无脑裂概念);
                    //      HA 模式收到 epoch < 已知最大值 = stale leader 视图 = 写禁用。
                    //   3. 旧版 fallback: 上游未暴露 partitioned/epoch (nil) → 退回 master-count heuristic (连续 N 轮 >1 master)。
                    // 审计v0.1.58 P1 residual: 上游 #76/#77 已合 (PR#78), 此处接通确定性信号; heuristic 仅兼容旧版。
                    let nowPartitioned = resp.partitioned
                    let nowEpoch = resp.epoch
                    let nowLeaderId = resp.leaderId
                    let isSingleAuthority = (nowEpoch == 0 && (nowLeaderId?.isEmpty ?? true))
                    let sb = self.bridge?.splitBrainState

                    if let partitioned = nowPartitioned {
                        // #72 权威信号优先 — server 已判定少数派脑裂。
                        if partitioned {
                            sb?.splitBrainConfirmCount += 1
                            sb?.splitBrainResolvedConfirmCount = 0
                            if sb?.splitBrainDetected == false && (sb?.splitBrainConfirmCount ?? 0) >= (sb?.splitBrainConfirmThreshold ?? 2) {
                                sb?.splitBrainDetected = true
                                mnNodeLog.error("F-A11 split-brain confirmed (#72 partitioned=true) across \(sb?.splitBrainConfirmCount ?? 0) rounds — writes blocked")
                            }
                        } else {
                            sb?.splitBrainResolvedConfirmCount += 1
                            if sb?.splitBrainDetected == true
                                && (sb?.splitBrainResolvedConfirmCount ?? 0) >= (sb?.splitBrainConfirmThreshold ?? 2) {
                                mnNodeLog.info("F-A11 split-brain resolved (#72 partitioned=false) across \(sb?.splitBrainResolvedConfirmCount ?? 0) rounds, unblocking writes")
                                sb?.splitBrainDetected = false
                                sb?.splitBrainConfirmCount = 0
                            }
                        }
                    } else if let epoch = nowEpoch, !isSingleAuthority {
                        // #76 HA 模式 — stale leader 视图 (epoch < 已知最大) = 脑裂迹象。
                        let knownMax = sb?.knownLeaderEpoch ?? 0
                        if epoch < knownMax {
                            sb?.splitBrainConfirmCount += 1
                            sb?.splitBrainResolvedConfirmCount = 0
                            if sb?.splitBrainDetected == false && (sb?.splitBrainConfirmCount ?? 0) >= (sb?.splitBrainConfirmThreshold ?? 2) {
                                sb?.splitBrainDetected = true
                                mnNodeLog.error("F-A11 split-brain confirmed (#76 stale epoch=\(epoch) < known=\(knownMax), leader=\(nowLeaderId ?? "-", privacy: .public)) — writes blocked")
                            }
                        } else {
                            if epoch > knownMax { sb?.knownLeaderEpoch = epoch }
                            sb?.knownLeaderId = nowLeaderId
                            sb?.splitBrainResolvedConfirmCount += 1
                            if sb?.splitBrainDetected == true
                                && (sb?.splitBrainResolvedConfirmCount ?? 0) >= (sb?.splitBrainConfirmThreshold ?? 2) {
                                mnNodeLog.info("F-A11 split-brain resolved (#76 epoch=\(epoch) ≥ known, leader=\(nowLeaderId ?? "-", privacy: .public)), unblocking writes")
                                sb?.splitBrainDetected = false
                                sb?.splitBrainConfirmCount = 0
                            }
                        }
                    } else {
                        // 旧版上游 (partitioned/epoch nil) — 退回 master-count heuristic。
                        // 单权威 (epoch 0 + 空 leader) 也走此分支: 无脑裂概念, masterCount≤1 不报。
                        let masterCount = resp.nodes.filter { $0.isMaster }.count
                        if masterCount > 1 {
                            sb?.splitBrainConfirmCount += 1
                            sb?.splitBrainResolvedConfirmCount = 0
                            if sb?.splitBrainDetected == false && (sb?.splitBrainConfirmCount ?? 0) >= (sb?.splitBrainConfirmThreshold ?? 2) {
                                sb?.splitBrainDetected = true
                                mnNodeLog.error("F-A11 split-brain confirmed (heuristic: \(masterCount) masters across \(sb?.splitBrainConfirmCount ?? 0) rounds) — writes blocked")
                            }
                        } else {
                            sb?.splitBrainResolvedConfirmCount += 1
                            if sb?.splitBrainDetected == true
                                && (sb?.splitBrainResolvedConfirmCount ?? 0) >= (sb?.splitBrainConfirmThreshold ?? 2) {
                                mnNodeLog.info("F-A11 split-brain resolved (heuristic: ≤1 master across \(sb?.splitBrainResolvedConfirmCount ?? 0) rounds), unblocking writes")
                                sb?.splitBrainDetected = false
                                sb?.splitBrainConfirmCount = 0
                            }
                        }
                    }
                    // Track B: split-brain 状态变更后刷新 activeMasterHost (canMutate 计算属性自动反映)。
                    self.bridge?.recomputeCanMutate()
                    // 审计0830 P1-调度-5: per-node offline 连续计数, 供 confirmedOffline 滞后决策。
                    for n in resp.nodes {
                        if n.effectiveStatus == .offline {
                            self.nodeOfflineStreak[n.id, default: 0] += 1
                        } else {
                            self.nodeOfflineStreak[n.id] = 0
                        }
                    }
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "nodes")
            }
        }
    }

    func fetchPendingNodes() {
        bridge?.get("/api/nodes/pending") { [weak self] (result: Result<PendingNodeListResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    let capped = Array(resp.pending.prefix(500))
                    if capped.count < resp.pending.count {
                        mnNodeLog.warning("pendingNodes truncated: \(resp.pending.count) -> \(capped.count)")
                    }
                    self.pendingNodes = capped
                }
            case .failure:
                mnNodeLog.debug("Pending nodes endpoint not available")
            }
        }
    }

    func fetchNodeMetrics(nodeId: String) {
        bridge?.get("/api/v1/nodes/\(nodeId)/metrics") { [weak self] (result: Result<NodeMetricsResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.nodeMetricsRaw[nodeId] = resp
                    self.nodeMetrics[nodeId] = LoadMetrics.from(resp)
                    MultiNodeEngine.capDict(&self.nodeMetricsRaw, 100)
                    MultiNodeEngine.capDict(&self.nodeMetrics, 500)
                }
            case .failure(let error):
                mnNodeLog.error("Failed to fetch metrics for \(nodeId): \(error.localizedDescription)")
            }
        }
    }

    func fetchNodeMetrics(nodeId: String, completion: @escaping (Result<LoadMetrics, Error>) -> Void) {
        bridge?.get("/api/v1/nodes/\(nodeId)/metrics") { [weak self] (result: Result<NodeMetricsResponse, Error>) in
            switch result {
            case .success(let resp):
                let metrics = LoadMetrics.from(resp)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.nodeMetricsRaw[nodeId] = resp
                    self.nodeMetrics[nodeId] = metrics
                    MultiNodeEngine.capDict(&self.nodeMetricsRaw, 100)
                    MultiNodeEngine.capDict(&self.nodeMetrics, 500)
                }
                completion(.success(metrics))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchModelManifest(modelName: String, completion: @escaping (Result<ModelManifest, Error>) -> Void) {
        bridge?.get("/api/models/\(modelName)/manifest") { [weak self] (result: Result<ModelManifest, Error>) in
            switch result {
            case .success(let manifest):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.modelManifests[modelName] = manifest
                    MultiNodeEngine.capDict(&self.modelManifests, 50)
                }
                completion(.success(manifest))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchNodeLoad(nodeId: String, completion: @escaping (Result<NodeLoadReport, Error>) -> Void) {
        bridge?.get("/api/nodes/\(nodeId)/load") { [weak self] (result: Result<NodeLoadReport, Error>) in
            switch result {
            case .success(let report):
                DispatchQueue.main.async { self?.nodeLoads[nodeId] = report }
                completion(.success(report))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchAllNodeLoads() {
        let live = nodes.filter { $0.effectiveStatus == .online || $0.effectiveStatus == .busy }
        let liveIds = Set(live.map { $0.id })
        let stale = nodeLoads.keys.filter { !liveIds.contains($0) }
        if !stale.isEmpty {
            for k in stale { nodeLoads.removeValue(forKey: k) }
            mnNodeLog.info("nodeLoads evicted \(stale.count) offline entries")
        }
        if live.count > nodeLoadSampleCap {
            let sampled = live.sorted { a, b in
                let la = nodeLoads[a.id]?.cpuPercent ?? 0
                let lb = nodeLoads[b.id]?.cpuPercent ?? 0
                return la > lb
            }.prefix(nodeLoadSampleCap)
            mnNodeLog.warning("node_loads sampled \(sampled.count)/\(live.count) (cap=\(self.nodeLoadSampleCap)); full load available via fetchNodeLoad(nodeId:)")
            for node in sampled { fetchNodeLoad(nodeId: node.id) { _ in } }
        } else {
            for node in live { fetchNodeLoad(nodeId: node.id) { _ in } }
        }
    }

    func removeNode(nodeId: String) async throws {
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "remove", targetNode: nodeId, targetTask: nil,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        do {
            try bridge?.assertNoSplitBrain()
            try await bridge?.delete("/api/nodes/\(nodeId)")
            fetchNodes()
            bridge?.clusterHealthState.fetchClusterStats()
            ClusterAuditor.shared.record(action: "remove", targetNode: nodeId, targetTask: nil,
                                         result: "ok", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "remove", targetNode: nodeId, targetTask: nil,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }

    func approveNode(nodeId: String, approvedBy: String = "admin") async throws {
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "approve", targetNode: nodeId, targetTask: nil,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        do {
            try bridge?.assertNoSplitBrain()
            _ = try await bridge?.post("/api/nodes/approve", body: ["node_id": nodeId, "approved_by": approvedBy])
            fetchPendingNodes()
            fetchNodes()
            bridge?.clusterHealthState.fetchClusterStats()
            ClusterAuditor.shared.record(action: "approve", targetNode: nodeId, targetTask: nil,
                                         result: "ok", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "approve", targetNode: nodeId, targetTask: nil,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }

    func rejectNode(nodeId: String, reason: String = "") async throws {
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "reject", targetNode: nodeId, targetTask: nil,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        do {
            try bridge?.assertNoSplitBrain()
            _ = try await bridge?.post("/api/nodes/reject", body: ["node_id": nodeId, "reason": reason])
            fetchPendingNodes()
            ClusterAuditor.shared.record(action: "reject", targetNode: nodeId, targetTask: nil,
                                         result: "ok", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "reject", targetNode: nodeId, targetTask: nil,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }

    func joinNode(ipAddress: String, port: Int, token: String? = nil) async throws -> [String: Any] {
        // 审计v0.1.58 P0-multinode-1: join 是写操作, 必经 canMutate+split-brain 门.
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "join", targetNode: ipAddress, targetTask: nil,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        try bridge?.assertNoSplitBrain()
        var body: [String: Any] = ["ip_address": ipAddress, "port": port]
        if let t = token { body["token"] = t }
        do {
            let resp = try await bridge?.post("/api/join", body: body) ?? [:]
            ClusterAuditor.shared.record(action: "join", targetNode: ipAddress, targetTask: nil,
                                         result: "ok", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            return resp
        } catch {
            ClusterAuditor.shared.record(action: "join", targetNode: ipAddress, targetTask: nil,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }
}
