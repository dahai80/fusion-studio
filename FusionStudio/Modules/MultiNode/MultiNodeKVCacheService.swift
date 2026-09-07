import Foundation
import os.log

// ARCH-1 (PR-C1) Phase 5: KVCache 行为迁入。MultiNodeEngine 留 1 行 stub 转发 (保外部签名)。
//   KVCache 域 0 @Published — 纯方法域。inflight 单飞保护经 bridge?.pollingState.inflightFetches/Lock reach-through。
//   协调器 (handleError/assertNoSplitBrain) 留 engine → 经 bridge?.X reach-through。
//   HTTP infra (get/post, session, agentBaseURL, authHeaders) 留 engine → 经 bridge?.X reach-through。
//   canMutate/activeMasterHost (engine 计算属性) → bridge?.canMutate / bridge?.activeMasterHost。

private let mnKVCacheLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeKVCacheService")

extension MultiNodeKVCacheState {

    func registerKVCache(cacheId: String, modelName: String, nodeId: String, sizeMb: Double, ttlSeconds: Int = 3600) async throws {
        // 审计v0.1.58 P0-multinode-1: KV register 是写操作, 必经 canMutate+split-brain 门.
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "registerKV", targetNode: nodeId, targetTask: nil,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        try bridge?.assertNoSplitBrain()
        let body: [String: Any] = [
            "cache_id": cacheId,
            "model_name": modelName,
            "node_id": nodeId,
            "size_mb": sizeMb,
            "ttl_seconds": ttlSeconds,
        ]
        do {
            _ = try await bridge?.post("/api/kv/register", body: body)
            ClusterAuditor.shared.record(action: "registerKV", targetNode: nodeId, targetTask: nil,
                                         result: "ok", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "registerKV", targetNode: nodeId, targetTask: nil,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }

    func findKVCache(modelName: String, completion: @escaping (Result<KVCacheEntry, Error>) -> Void) {
        bridge?.get("/api/kv/find/\(modelName)") { result in completion(result) }
    }

    func fetchAgentKVStats(completion: @escaping (Result<KVStatsResponse, Error>) -> Void) {
        guard let agentBaseURL = bridge?.agentBaseURL,
              let url = URL(string: "\(agentBaseURL)/api/kv/stats") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        bridge?.authHeaders(&req)
        bridge?.session.dataTask(with: req) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            do {
                let decoded = try JSONDecoder().decode(KVStatsResponse.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func agentKVLookup(modelName: String, promptHash: String, completion: @escaping (Result<KVCacheEntry, Error>) -> Void) {
        guard let agentBaseURL = bridge?.agentBaseURL,
              let url = URL(string: "\(agentBaseURL)/api/kv/lookup") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bridge?.authHeaders(&req)
        let body = ["model_name": modelName, "prompt_hash": promptHash]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        bridge?.session.dataTask(with: req) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            do {
                let decoded = try JSONDecoder().decode(KVCacheEntry.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func agentKVTransfer(cacheId: String, targetNode: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let agentBaseURL = bridge?.agentBaseURL,
              let url = URL(string: "\(agentBaseURL)/api/kv/transfer") else {
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bridge?.authHeaders(&req)
        let body = ["cache_id": cacheId, "target_node": targetNode]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        bridge?.session.dataTask(with: req) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["status"] as? String == "ok" {
                completion(.success(true))
            } else {
                completion(.success(false))
            }
        }.resume()
    }

    func agentKVWarm(modelName: String, prompts: [String], completion: @escaping (Result<Int, Error>) -> Void) {
        // 审计0827 §3.6 (P2): 无 (model) 去重, 并发 warm (多 agent / 重复点按钮) → 重复 POST
        // → MLX 后端同模型重复分配 KV cache 显存翻倍, 8-16 节点触发 GPU OOM。
        // 按 model 名单飞: in-flight 期间同 model 跳过, 回调完成才释放。
        // 审计0830 P1-调度-7: 旧 [weak self] 回调若 self 已 nil → releaseInflight no-op → key 永留 inflightFetches,
        //   后续同 model warm 恒被 skip = 永久 hang。改强引用 bridge 至回调结束 (engine 随 app 生命周期, 无提早释放风险),
        //   且全路径 (URL 构造失败 / 网络错误 / 解码失败) 经统一 release 闭包释放, 无遗漏路径。
        let inflightKey = "kv_warm:\(modelName)"
        let polling = bridge?.pollingState
        polling?.inflightLock.lock()
        if polling?.inflightFetches.contains(inflightKey) ?? false {
            polling?.inflightLock.unlock()
            mnKVCacheLog.warning("agentKVWarm skip (in-flight): \(modelName)")
            completion(.failure(EngineError.duplicateRequest))
            return
        }
        polling?.inflightFetches.insert(inflightKey)
        polling?.inflightLock.unlock()
        // 统一释放闭包: 任意出口 (含 early-return) 都经此, 保证 lock 不泄漏。
        // 强引用 bridge: 回调持有 bridge 至网络完成才释放, 避免 weak-nil 跳过 releaseInflight 致 key 永留。
        let release = { self.bridge?.pollingState.releaseInflight(inflightKey) }
        guard let agentBaseURL = bridge?.agentBaseURL,
              let url = URL(string: "\(agentBaseURL)/api/kv/warm") else {
            release()
            completion(.failure(EngineError.invalidURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        bridge?.authHeaders(&req)
        let body: [String: Any] = ["model_name": modelName, "prompts": prompts]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        // 强引用 bridge: 回调持有 bridge 至网络完成才释放, 避免 weak-nil 路径跳过 releaseInflight。
        bridge?.session.dataTask(with: req) { data, _, error in
            release()
            if let error = error { completion(.failure(error)); return }
            guard let data = data else { completion(.failure(EngineError.noData)); return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let warmed = json["warmed"] as? Int ?? 0
                    completion(.success(warmed))
                } else {
                    completion(.success(0))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
