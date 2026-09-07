import Foundation
import os.log

// ARCH-1 (PR-C1) Phase 3: Task 行为迁入。MultiNodeEngine 留 1 行 stub 转发 (保外部签名:
//   TaskManager/ContentView/其他 view 读站点 0 改)。
//   跨域写 (clusterHealth: resetFailureState; nodeState: confirmedOffline) 经
//   self.bridge?.<domain>.X reach-through。
//   协调器 (handleError/recomputeCanMutate/assertNoSplitBrain) 留 engine → 经 bridge?.X reach-through。
//   HTTP infra (get/post/put/delete, session, baseURL, authHeaders) 留 engine → 经 bridge?.X reach-through。
//   canMutate/activeMasterHost (engine 计算属性) → bridge?.canMutate / bridge?.activeMasterHost。
//   static generateIdempotencyKey → MultiNodeEngine.generateIdempotencyKey()。

private let mnTaskLog = Logger(subsystem: "com.fusion.studio", category: "MultiNodeTaskService")

extension MultiNodeTaskState {

    func fetchTasks() {
        bridge?.get("/api/tasks") { [weak self] (result: Result<TaskListResponse, Error>) in
            switch result {
            case .success(let resp):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // 审计0902 A5 (P2): tasks 全量替换无 cap, 后端返 >500 则绕过 taskSubmit LRU cap 500。
                    //   cap 500 与单机 task 列表一致, 超限只保前 500 (按后端返回序, 通常近时间序)。
                    var fetched = resp.tasks
                    if fetched.count > 500 {
                        fetched = Array(fetched.prefix(500))
                    }
                    self.tasks = fetched
                    self.bridge?.clusterHealthState.resetFailureState(context: "tasks")
                    self.detectDuplicateExecution()
                }
            case .failure(let error):
                self?.bridge?.handleError(error, context: "tasks")
            }
        }
    }

    // F-A13: 扫 tasks 找疑似重复执行 (assignedNodes>=2 && running && mode!=data_parallel)。
    // data_parallel 多节点 = 合法分片; pipeline/inference 单节点意图, 多节点 = 疑似 submit 重复。
    func detectDuplicateExecution() {
        let dups = tasks.filter { task in
            task.assignedNodes.count >= 2 &&
            task.status == .running &&
            task.mode != "data_parallel"
        }.map { $0.id }
        if dups != duplicateExecutionTaskIds {
            duplicateExecutionTaskIds = dups
            if !dups.isEmpty {
                mnTaskLog.error("F-A13 suspected duplicate execution: tasks=\(dups) (>=2 running nodes, mode!=data_parallel)")
            } else {
                mnTaskLog.info("F-A13 duplicate execution cleared")
            }
        }
    }

    func fetchTaskProgress(taskId: String, completion: @escaping (Result<TaskProgress, Error>) -> Void) {
        bridge?.get("/api/v1/tasks/\(taskId)/progress") { result in completion(result) }
    }

    func fetchTaskTimeline(taskId: String, completion: @escaping (Result<TaskTimeline, Error>) -> Void) {
        bridge?.get("/api/v1/tasks/\(taskId)/timeline") { result in completion(result) }
    }

    func cancelTask(taskId: String) async throws {
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "cancel", targetNode: nil, targetTask: taskId,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        do {
            try bridge?.assertNoSplitBrain()
            _ = try await bridge?.post("/api/tasks/\(taskId)/cancel", body: ["reason": "cancelled_by_user"])
            fetchTasks()
            ClusterAuditor.shared.record(action: "cancel", targetNode: nil, targetTask: taskId,
                                         result: "ok", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "cancel", targetNode: nil, targetTask: taskId,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }

    func degradeTask(taskId: String, targetModel: String? = nil) async throws {
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "degrade", targetNode: nil, targetTask: taskId,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        do {
            try bridge?.assertNoSplitBrain()
            var body: [String: Any] = [:]
            if let m = targetModel { body["target_model"] = m }
            _ = try await bridge?.post("/api/tasks/\(taskId)/degrade", body: body)
            fetchTasks()
            ClusterAuditor.shared.record(action: "degrade", targetNode: nil, targetTask: taskId,
                                         result: "ok", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "degrade", targetNode: nil, targetTask: taskId,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }

    func migrateTask(taskId: String, targetNodeId: String) async throws {
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "migrate", targetNode: nil, targetTask: taskId,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        do {
            try bridge?.assertNoSplitBrain()
            _ = try await bridge?.post("/api/tasks/\(taskId)/migrate", body: ["target_node_id": targetNodeId])
            fetchTasks()
            ClusterAuditor.shared.record(action: "migrate", targetNode: targetNodeId, targetTask: taskId,
                                         result: "ok", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
        } catch {
            ClusterAuditor.shared.record(action: "migrate", targetNode: targetNodeId, targetTask: taskId,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }

    func migrateTask(taskId: String, targetNodeId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await migrateTask(taskId: taskId, targetNodeId: targetNodeId)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func submitTask(name: String, mode: String, modelName: String, priority: Int = 5, requiredCapability: String? = nil, excludeNodes: [String]? = nil) async throws -> [String: Any] {
        let idemKey = MultiNodeEngine.generateIdempotencyKey()
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "submit", targetNode: nil, targetTask: nil,
                                         result: "blocked", idempotencyKey: idemKey, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        do {
            try bridge?.assertNoSplitBrain()
            var body: [String: Any] = ["name": name, "mode": mode, "model_name": modelName, "priority": priority]
            if let cap = requiredCapability { body["required_capability"] = cap }
            // 审计0830 P1-调度-3: retryTask 透传 exclude_nodes 含原失败节点, 后端排除则不重命中同一故障节点。
            //   后端 submit 端点当前可能忽略此字段 (上游缺口 https://github.com/dahai80/fusion-multi-nodes/issues/70),
            //   客户端传递为前置; 后端支持后即生效, 无害。
            if let ex = excludeNodes, !ex.isEmpty { body["exclude_nodes"] = ex }
            mnTaskLog.info("submitTask idempotencyKey=\(idemKey, privacy: .public)")
            let result = try await bridge?.post("/api/tasks/submit", body: body, idempotencyKey: idemKey) ?? [:]
            fetchTasks()
            bridge?.clusterHealthState.fetchClusterStats()
            ClusterAuditor.shared.record(action: "submit", targetNode: nil, targetTask: nil,
                                         result: "ok", idempotencyKey: idemKey, masterHost: bridge?.activeMasterHost)
            return result
        } catch {
            ClusterAuditor.shared.record(action: "submit", targetNode: nil, targetTask: nil,
                                         result: "failed", idempotencyKey: idemKey, masterHost: bridge?.activeMasterHost)
            throw error
        }
    }

    // F-A12: 失败 task 重试需带原 task 的 assignedNodes 黑名单 + 原 requiredCapability/priority。
    // 后端 submit 端点无 exclude_nodes 字段 (fusion-multi-nodes 上游缺口 https://github.com/dahai80/fusion-multi-nodes/issues/70) → 客户端止血:
    // 保留原参数 + assignedNodes 全 offline 则阻断重试 (防 "无限重试同一个坑"), 健康则重新 submit。
    func retryTask(_ task: ClusterTask) async throws -> [String: Any] {
        guard bridge?.canMutate ?? false else {
            ClusterAuditor.shared.record(action: "retry", targetNode: nil, targetTask: task.id,
                                         result: "blocked", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.writeDisabled
        }
        try bridge?.assertNoSplitBrain()
        let assigned = task.assignedNodes
        // 审计0830 P1-调度-5: 用 confirmedOffline 滞后确认, 瞬态抖动不误判全 offline 阻断重试。
        let offlineAssigned = assigned.filter { bridge?.nodeState.confirmedOffline(nodeId: $0) ?? true }
        if !assigned.isEmpty && offlineAssigned.count == assigned.count {
            mnTaskLog.error("F-A12 retry blocked: all assigned nodes offline. task=\(task.id) assigned=\(assigned)")
            ClusterAuditor.shared.record(action: "retry", targetNode: nil, targetTask: task.id,
                                         result: "failed", idempotencyKey: nil, masterHost: bridge?.activeMasterHost)
            throw EngineError.retryNoHealthyNode
        }
        let origPriority = task.priority ?? 5
        let origCap = task.requiredCapability
        mnTaskLog.info("F-A12 retry: task=\(task.id) assigned=\(assigned) offline=\(offlineAssigned) priority=\(origPriority) cap=\(origCap ?? "nil")")
        // 审计0830 P1-调度-3: 透传 offlineAssigned 作 exclude_nodes, 后端排除则重试不命中同一故障节点。
        // submitTask 内部生成 idemKey 并审计 "ok"/"failed", retry 不重复审计成功路径。
        return try await submitTask(
            name: task.name, mode: task.mode, modelName: task.modelName,
            priority: origPriority, requiredCapability: origCap,
            excludeNodes: offlineAssigned
        )
    }
}
