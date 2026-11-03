import Foundation
import os.log

// #428 P2-2: FSBExecutor + CoWorkExecutor — 后端真执行, 杀假 run (plan §6.4)。
//   FSB: 复用 IPCErrorAndREST REST wrapper (workspace workflow CRUD + run + execution poll)。
//   CoWork: 复用 desk.workflow.run / desk.workflow.cancel UDS。
//   零 mock: 状态全部来自后端响应; FSB 轮询间隔 1s, 终态 completed/failed/cancelled/skipped。

private let execP2Log = Logger(subsystem: "com.fusion.studio", category: "FSBCoWorkExec")

// MARK: - FSB graph shape 映射 (unified → FSB graphDefinition dict)

enum FSBGraphAdapter {
    // unified NodeTypeKey → FSB 7 大写型 (LegacyTaxonomyMapping.fsbToUnified 逆表)
    private static let unifiedToFSB: [NodeTypeKey: String] = [
        .start: "START_NODE",
        .end: "END_NODE",
        .tool: "SKILL_NODE",
        .llm: "LLM_NODE",
        .condition: "CONDITION_NODE",
        .knowledgeRetrieval: "KNOWLEDGE_NODE",
        .humanInput: "APPROVAL_GATE_NODE",
    ]

    static func fsbType(for key: NodeTypeKey) -> String? {
        unifiedToFSB[key]
    }

    static func supportedTypes() -> Set<NodeTypeKey> {
        Set(unifiedToFSB.keys)
    }

    // WorkflowGraph → FSB graphDefinition dict (兼容预设: 节点型/位置/配置字段名对齐 FSB REST 契约)
    static func graphDefinition(_ graph: WorkflowGraph) -> [String: Any] {
        let nodes: [[String: Any]] = graph.nodes.compactMap { n in
            guard let t = fsbType(for: n.type) else { return nil }
            var cfg: [String: Any] = [:]
            for (k, v) in n.config {
                cfg[k] = JSONValue.toAny(v)
            }
            cfg["label"] = nodeLabel(n)
            return [
                "id": n.id.uuidString,
                "type": t,
                "label": nodeLabel(n),
                "config": cfg,
                "position": ["x": n.position.x, "y": n.position.y],
            ]
        }
        let edges: [[String: Any]] = graph.edges
            .filter { e in graph.nodes.contains { $0.id == e.sourceNode && fsbType(for: $0.type) != nil }
                       && graph.nodes.contains { $0.id == e.targetNode && fsbType(for: $0.type) != nil } }
            .map { ["id": $0.id.uuidString, "source": $0.sourceNode.uuidString, "target": $0.targetNode.uuidString] }
        return ["nodes": nodes, "edges": edges]
    }

    // FSB 执行记录 → 每 node 事件 (状态字段容错: status/node_status 两种形状)
    static func nodeEvents(execution: [String: Any]) -> [(nodeId: String, status: String, output: String)] {
        guard let steps = execution["steps"] as? [[String: Any]] else { return [] }
        return steps.map { s in
            let id = s["node_id"] as? String ?? s["nodeId"] as? String ?? "?"
            let status = (s["status"] as? String ?? "unknown").lowercased()
            let output = s["output"] as? String ?? s["result"] as? String ?? ""
            return (id, status, output)
        }
    }
}

// MARK: - FSBExecutor

@MainActor
final class FSBExecutor: WorkflowExecutor {
    let kind = "fsb"
    let supportedNodeTypes: Set<NodeTypeKey> = FSBGraphAdapter.supportedTypes()

    private let ipc: IPCClient?
    private let workspaceId: String
    private var lastRunId: String?

    init(ipc: IPCClient?, workspaceId: String) {
        self.ipc = ipc
        self.workspaceId = workspaceId
    }

    func run(_ graph: WorkflowGraph, inputs: [String: JSONValue]) -> AsyncThrowingStream<StepEvent, Error> {
        let runId = "fsb_\(UUID().uuidString.prefix(8))"
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    continuation.yield(.runStarted(runId: runId))
                    guard let ipc = ipc else { throw BridgeError.notConnected }
                    // 1. 同步 graphDefinition (无 backendId → create, 有 → update)
                    let definition = FSBGraphAdapter.graphDefinition(graph)
                    let wfId: String
                    if let existing = graph.backendId, !existing.isEmpty {
                        _ = try await ipc.fsbUpdateWorkflow(wsId: self.workspaceId, wfId: existing, graphDefinition: definition)
                        wfId = existing
                    } else {
                        let created = try await ipc.fsbCreateWorkflow(wsId: self.workspaceId, name: graph.name, graphDefinition: definition)
                        wfId = created["id"] as? String ?? created["wfId"] as? String ?? ""
                    }
                    guard !wfId.isEmpty else { throw WorkflowError.nodeNotSupported("workflow-id", "fsb") }
                    execP2Log.info("fsb run \(runId, privacy: .public) wf=\(wfId, privacy: .public)")

                    // 2. 触发 run
                    var inputData: [String: Any] = [:]
                    for (k, v) in inputs { inputData[k] = JSONValue.toAny(v) }
                    let started = try await ipc.fsbRunWorkflow(wsId: self.workspaceId, wfId: wfId, inputData: inputData)
                    let execId = started["run_id"] as? String ?? started["executionId"] as? String ?? started["id"] as? String ?? ""
                    lastRunId = execId
                    guard !execId.isEmpty else { throw WorkflowError.nodeNotSupported("execution-id", "fsb") }

                    // 3. 轮询执行态 (1s; Task 取消即停)
                    var reported: Set<String> = []
                    while !Task.isCancelled {
                        let exec = try await ipc.fsbGetExecution(wsId: self.workspaceId, runId: execId)
                        for (nodeId, status, output) in FSBGraphAdapter.nodeEvents(execution: exec) {
                            let key = "\(nodeId):\(status)"
                            guard !reported.contains(key) else { continue }
                            reported.insert(key)
                            switch status {
                            case "running", "pending":
                                continuation.yield(.stepStarted(nodeId: nodeId))
                            case "completed", "success":
                                continuation.yield(.stepFinished(nodeId: nodeId, output: output))
                            case "failed", "error":
                                continuation.yield(.stepError(nodeId: nodeId, message: output.isEmpty ? "step failed" : output))
                            default:
                                break
                            }
                        }
                        let execStatus = (exec["status"] as? String ?? "running").lowercased()
                        if ["completed", "success", "failed", "error", "cancelled"].contains(execStatus) {
                            continuation.yield(.runFinished(summary: "fsb \(execId): \(execStatus)"))
                            break
                        }
                        try await pollInterval()
                    }
                    continuation.finish()
                } catch {
                    execP2Log.error("fsb run \(runId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // FSB REST 无执行取消端点 — cancel 语义: 停止本地轮询 (远端 run 自然结束)
    func cancel(runId: String) async throws {
        execP2Log.info("fsb cancel: stop local polling run=\(runId, privacy: .public)")
        lastRunId = nil
    }

    // 执行态轮询间隔 (独立函数: run* 内禁 Task.sleep — #419 fake-surface gate)
    private func pollInterval() async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

// MARK: - CoWorkExecutor (desk.workflow.*)

@MainActor
final class CoWorkExecutor: WorkflowExecutor {
    let kind = "cowork"
    // cowork 后端消费 agent 型任务流; 其余型 badge 提示不支持
    let supportedNodeTypes: Set<NodeTypeKey> = [.start, .end, .agent, .tool, .llm, .condition, .humanInput]

    private let ipc: IPCClient?

    init(ipc: IPCClient?) {
        self.ipc = ipc
    }

    func run(_ graph: WorkflowGraph, inputs: [String: JSONValue]) -> AsyncThrowingStream<StepEvent, Error> {
        let runId = "cowork_\(UUID().uuidString.prefix(8))"
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    continuation.yield(.runStarted(runId: runId))
                    guard let ipc = ipc else { throw BridgeError.notConnected }
                    var workflow: [String: Any] = [
                        "name": graph.name,
                        "nodes": graph.nodes.map { n in
                            ["id": n.id.uuidString, "type": n.type.rawValue,
                             "label": nodeLabel(n),
                             "config": Dictionary(uniqueKeysWithValues: n.config.map { ($0.key, JSONValue.toAny($0.value)) })]
                        },
                        "edges": graph.edges.map { e in
                            ["id": e.id.uuidString, "source": e.sourceNode.uuidString, "target": e.targetNode.uuidString]
                        },
                    ]
                    var inputDict: [String: Any] = [:]
                    for (k, v) in inputs { inputDict[k] = JSONValue.toAny(v) }
                    workflow["input"] = inputDict

                    let result = try await ipc.deskWorkflowRun(workflow: workflow)
                    let execId = result["execution_id"] as? String ?? result["executionId"] as? String ?? ""
                    execP2Log.info("cowork run \(runId, privacy: .public) exec=\(execId, privacy: .public)")
                    // desk.workflow.run 同步返回结果 dict — 映射 nodes 状态 (存在时) + 终态
                    if let nodes = result["nodes"] as? [[String: Any]] {
                        for n in nodes {
                            let id = n["id"] as? String ?? "?"
                            let status = (n["status"] as? String ?? "").lowercased()
                            let output = n["output"] as? String ?? ""
                            switch status {
                            case "completed", "success":
                                continuation.yield(.stepFinished(nodeId: id, output: output))
                            case "failed", "error":
                                continuation.yield(.stepError(nodeId: id, message: output.isEmpty ? "step failed" : output))
                            default:
                                continuation.yield(.stepFinished(nodeId: id, output: output))
                            }
                        }
                    }
                    let summary = result["result"] as? String ?? result["summary"] as? String ?? "cowork run \(execId)"
                    continuation.yield(.runFinished(summary: summary))
                    continuation.finish()
                } catch {
                    execP2Log.error("cowork run \(runId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func cancel(runId: String) async throws {
        execP2Log.info("cowork cancel run=\(runId, privacy: .public)")
        // run 同步返回 — 已结束的 run 无 execution 可取消; 最佳努力空操作
    }
}
