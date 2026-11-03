import Foundation
import os.log

// #424 P1-4: WorkflowExecutor seam (plan §6.4) + StepEvent 流 + AgentStudioExecutor。
//   真执行: 包装既有 agent-studio UDS graph.execute 契约 (audit §2.1), 不新增下游要求。
//   本 surface 零假动画 (#419 后续: canvas 执行反馈全部来自真实 StepEvent)。

private let executorLog = Logger(subsystem: "com.fusion.studio", category: "WorkflowExecutor")

// MARK: - StepEvent (plan §6.4: langflow ag_ui-shaped)

enum StepEvent: Equatable, Sendable {
    case runStarted(runId: String)
    case stepStarted(nodeId: String)
    case stepFinished(nodeId: String, output: String)
    case stepError(nodeId: String, message: String)
    case runFinished(summary: String)
    case tokenStream(nodeId: String, chunk: String)

    var nodeId: String? {
        switch self {
        case .stepStarted(let n), .stepFinished(let n, _), .stepError(let n, _), .tokenStream(let n, _):
            return n
        default: return nil
        }
    }
}

// MARK: - Executor seam

// @MainActor: 实现类持有 AgentBridge (MainActor); 收窄 conformance 隔离域
@MainActor
protocol WorkflowExecutor: AnyObject {
    var kind: String { get }
    var supportedNodeTypes: Set<NodeTypeKey> { get }
    func run(_ graph: WorkflowGraph, inputs: [String: JSONValue]) -> AsyncThrowingStream<StepEvent, Error>
    func cancel(runId: String) async throws
}

// MARK: - AgentStudioExecutor

// 包装 AgentBridge graph CRUD + executeGraph。执行前置 save (graph 无 backendId 时 create, 有则 update),
//   后 executeGraph 返回批量 AgentEventModel — 映射为 StepEvent 流。
@MainActor
final class AgentStudioExecutor: WorkflowExecutor {
    let kind = "agent-studio"

    // agent-studio 后端消费的节点类型 (audit §2.1: type 字符串直传)。未注册类型 → not-supported badge。
    let supportedNodeTypes: Set<NodeTypeKey> = [
        .start, .end, .llm, .tool, .condition, .loop,
        .knowledgeRetrieval, .agent, .questionClassifier, .httpRequest,
    ]

    private let codec = AgentStudioCodec()
    private weak var bridge: AgentBridge?
    private let graphService: AgentGraphServiceProviding
    // run() 入参为值语义, backendId 写回经此表 (调用方 save 前取用)
    private var backendIdByGraph: [UUID: String] = [:]

    func backendId(for graphId: UUID) -> String? {
        backendIdByGraph[graphId]
    }

    // graphService 可注入 (测试 mock); 默认走 AgentBridge facade
    init(bridge: AgentBridge?, graphService: AgentGraphServiceProviding? = nil) {
        self.bridge = bridge
        self.graphService = graphService ?? BridgeGraphService(bridge: bridge)
    }

    func run(_ graph: WorkflowGraph, inputs: [String: JSONValue]) -> AsyncThrowingStream<StepEvent, Error> {
        let runId = "run_\(UUID().uuidString.prefix(8))"
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    continuation.yield(.runStarted(runId: runId))
                    // 前置同步: 本地 flow → 后端 graph (无 backendId create / 有 update)
                    let backendId = try await syncGraph(graph)
                    executorLog.info("run \(runId, privacy: .public): synced backend graph id=\(backendId)")
                    let inputText = inputs["input"]?.stringValue ?? ""
                    let events = try await executeOnBackend(id: backendId, input: inputText)
                    var lastError: String?
                    for ev in events {
                        let nodeId = ev.node_id ?? "?"
                        switch ev.type.lowercased() {
                        case let t where t.contains("start") && !t.contains("run"):
                            continuation.yield(.stepStarted(nodeId: nodeId))
                        case let t where t.contains("error") || t.contains("fail"):
                            let msg = ev.data?["message"]?.stringValue ?? ev.data.map { "\($0)" } ?? "step failed"
                            lastError = msg
                            continuation.yield(.stepError(nodeId: nodeId, message: msg))
                        case let t where t.contains("token") || t.contains("delta"):
                            if let chunk = ev.data?["text"]?.stringValue ?? ev.data?["chunk"]?.stringValue {
                                continuation.yield(.tokenStream(nodeId: nodeId, chunk: chunk))
                            }
                        case let t where t.contains("finish") || t.contains("complete") || t.contains("end"):
                            let out = ev.data?["output"]?.stringValue ?? ev.data?["result"]?.stringValue ?? ""
                            continuation.yield(.stepFinished(nodeId: nodeId, output: out))
                        default:
                            continuation.yield(.stepFinished(nodeId: nodeId, output: ev.data.map { "\($0)" } ?? ""))
                        }
                    }
                    if let err = lastError {
                        continuation.yield(.runFinished(summary: "failed: \(err)"))
                    } else {
                        continuation.yield(.runFinished(summary: "\(events.count) events"))
                    }
                    continuation.finish()
                } catch {
                    executorLog.error("run \(runId, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func cancel(runId: String) async throws {
        executorLog.info("cancel run \(runId, privacy: .public)")
        graphService.cancelExecution()
    }

    // create/update graph → 返回 backend graph id (backendId 写回入参)
    private func syncGraph(_ input: WorkflowGraph) async throws -> String {
        var graph = input
        let backendModel = try codec.toBackend(graph)
        if let existing = graph.backendId, !existing.isEmpty {
            _ = try await graphService.updateGraph(id: existing, name: backendModel.name, nodes: backendModel.nodes, edges: backendModel.edges)
            return existing
        }
        let created = try await graphService.createGraph(name: backendModel.name, nodes: backendModel.nodes, edges: backendModel.edges)
        graph.backendId = created.id
        backendIdByGraph[graph.id] = created.id
        return created.id
    }

    private func executeOnBackend(id: String, input: String) async throws -> [AgentEventModel] {
        guard let bridge = bridge else { throw BridgeError.notConnected }
        return try await bridge.executeGraph(id: id, input: input)
    }
}

// MARK: - graph CRUD 抽象 (executor 可测性: mock transport 注入点)

@MainActor
protocol AgentGraphServiceProviding: AnyObject {
    func createGraph(name: String, nodes: [NodeConfigModel], edges: [EdgeModel]) async throws -> AgentGraphModel
    func updateGraph(id: String, name: String?, nodes: [NodeConfigModel]?, edges: [EdgeModel]?) async throws -> AgentGraphModel?
    func cancelExecution()
}

@MainActor
final class BridgeGraphService: AgentGraphServiceProviding {
    private weak var bridge: AgentBridge?

    init(bridge: AgentBridge?) {
        self.bridge = bridge
    }

    func createGraph(name: String, nodes: [NodeConfigModel], edges: [EdgeModel]) async throws -> AgentGraphModel {
        guard let bridge = bridge else { throw BridgeError.notConnected }
        return try await bridge.createGraph(name: name, nodes: nodes, edges: edges)
    }

    func updateGraph(id: String, name: String?, nodes: [NodeConfigModel]?, edges: [EdgeModel]?) async throws -> AgentGraphModel? {
        guard let bridge = bridge else { throw BridgeError.notConnected }
        return try await bridge.updateGraph(id: id, name: name, nodes: nodes, edges: edges)
    }

    func cancelExecution() {
        bridge?.cancelExecution()
    }
}
