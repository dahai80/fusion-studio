import Foundation
import os.log

// ARCH-1 (PR-C1) Phase 2: ClusterHealth 行为迁入。MultiNodeEngine 留 1 行 stub 转发 (保外部签名:
//   ContentView/PollingService/其他 62 view 读站点 0 改)。
//   跨域写 (splitBrain: knownLeaderEpoch/Id/Token; polling: consecutiveFailuresByContext;
//   nodeState: nodeOfflineStreak) 经 self.bridge?.<domain>.X reach-through。
//   协调器 (handleError/recomputeCanMutate/assertNoSplitBrain) 留 engine → 经 bridge?.X reach-through。
//   HTTP infra (get/post/put/delete, session, baseURL, authHeaders) 留 engine → 经 bridge?.X reach-through。

private let mnClusterHealthLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeClusterHealthService")

extension MultiNodeClusterHealthState {

    // F-R6: 成功路径重置失败状态。fetch 成功即清该路 stale + 该路连续失败计数, 恢复 online。
    // 审计0827 §3.5: 按 context 复位, 非全局清零 — 避免交叉复位掩盖其余持续失败路径。
    func resetFailureState(context: String) {
        nodesStale = false
        bridge?.pollingState.consecutiveFailuresByContext[context] = 0
        // 任一路成功即认为集群可达; 离线态由 handleError 按各路独立判定。
        // B3: successful recovery clears MasterPool failover cycle cap.
        if !isConnected { isConnected = true; MasterPool.shared.markRecovered() }
        // Track B: 成功恢复时同步 activeMasterHost。
        bridge?.recomputeCanMutate()
    }

    func fetchClusterStats() {
        bridge?.get("/api/v1/cluster/stats") { [weak self] (result: Result<V1ClusterStatsResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.clusterStats = ClusterStats.from(resp)
                    self.resetFailureState(context: "cluster_stats")
                    self.lastError = nil
                    // #76/#77: 刷新领导纪元 + per-leader token (stats cluster sub-dict 携带)。
                    //   epoch/leader_id 与 /api/nodes 同源, 此处同步 knownLeaderEpoch/knownLeaderId 兜底
                    //   (stats 与 nodes 轮询独立, 任一先到即缓存)。token 仅 stats 暴露, 此处刷新。
                    if let epoch = resp.cluster.epoch {
                        if epoch > (self.bridge?.splitBrainState.knownLeaderEpoch ?? 0) {
                            self.bridge?.splitBrainState.knownLeaderEpoch = epoch
                        }
                        self.bridge?.splitBrainState.knownLeaderId = resp.cluster.leaderId
                    }
                    if let token = resp.cluster.leaderToken, !token.isEmpty {
                        self.bridge?.splitBrainState.knownLeaderToken = token
                    }
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "cluster_stats")
            }
        }
    }

    func checkHealth() {
        bridge?.get("/api/health") { [weak self] (result: Result<HealthResponse, Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isConnected = true
                    self.lastError = nil
                    // 审计0827 §3.5: health 路 success 复位其 context 失败计数。
                    self.bridge?.pollingState.consecutiveFailuresByContext["health"] = 0
                    self.bridge?.recomputeCanMutate()
                    // 审计v0.1.58 P1-2: failover 探测完成复位 (非 5s 定时器), 保证探测真正结束才放下次.
                    self.failoverProbeInflight = false
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "health")
                DispatchQueue.main.async { [weak self] in
                    self?.failoverProbeInflight = false
                }
            }
        }
    }
}
