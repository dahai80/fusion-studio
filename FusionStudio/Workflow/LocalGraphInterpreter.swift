import Foundation
import os.log

// #429 P2-3 + #430 P2-4: 本地图解释器 (plan §6.4 LocalInterpreter seam)。
//   拓扑逐节点执行 NodeDefinition.run, FlowState 全程穿线 (Flowise $flow.state 语义);
//   condition 分支按输出端口选边; loop/iteration 受 max_iterations 硬帽 (超出显式抛错);
//   human_input 落 checkpoint (持久化 flow metadata, 重启可恢复, #430);
//   sub_flow 从本地 flow 库装载子图内联执行 (flow-as-tool, #430)。

private let interpLog = Logger(subsystem: "com.fusion.studio", category: "GraphInterpreter")

// MARK: - Checkpoint (#430 HiTL)

struct WorkflowCheckpoint: Codable, Equatable, Sendable {
    var nodeId: UUID
    var question: String
    var answerKey: String
    var stateSnapshot: [String: JSONValue]
    var createdAt: Double
}

private enum CheckpointBridge {
    static func toValue(_ cp: WorkflowCheckpoint) -> JSONValue? {
        guard let data = try? JSONEncoder().encode(cp),
              let obj = try? JSONDecoder().decode([String: JSONValue].self, from: data) else { return nil }
        return .object(obj)
    }

    static func fromValue(_ v: JSONValue) -> WorkflowCheckpoint? {
        guard case .object(let o) = v,
              let data = try? JSONEncoder.fusionWorkflow.encode(o),
              let cp = try? JSONDecoder().decode(WorkflowCheckpoint.self, from: data) else { return nil }
        return cp
    }
}

extension WorkflowGraph {
    // checkpoint 持久化在 flow metadata — 落盘即重启可恢复 (#430 验收)
    var pendingCheckpoint: WorkflowCheckpoint? {
        get {
            guard let v = metadata["pending_checkpoint"] else { return nil }
            return CheckpointBridge.fromValue(v)
        }
        set {
            guard let cp = newValue, let v = CheckpointBridge.toValue(cp) else {
                metadata.removeValue(forKey: "pending_checkpoint")
                return
            }
            metadata["pending_checkpoint"] = v
        }
    }
}


// config 整数读取 (.string/.double 双型; 表单/落盘两种来源)
private func configInt(_ v: JSONValue?) -> Int? {
    switch v {
    case .string(let s): return Int(s)
    case .double(let d): return Int(d)
    default: return nil
    }
}

// MARK: - Interpreter

enum LocalRunOutcome: Equatable {
    case finished(summary: String)
    case checkpoint(WorkflowCheckpoint)
}

final class LocalGraphInterpreter: @unchecked Sendable {
    // 本地可执行型; 其余型显式报错 (fail visibly, 不静默跳过)
    static let locallyRunnable: Set<NodeTypeKey> = [
        .start, .end, .condition, .loop, .iteration, .variableAggregator,
        .template, .humanInput, .subFlow, .note,
    ]

    private var visitedInPath: Set<UUID> = []
    private let lock = NSLock()
    // 解释器托管的型: 无独立 run, walk switch 内特化处理
    private let interpreterManagedTypes: Set<NodeTypeKey> = [.loop, .iteration, .humanInput, .subFlow, .note]
    private var lastOutput: JSONValue? = nil

    // 从 start (或 checkpoint 节点) 顺序解释执行; yield 即时事件
    func execute(
        _ graph: WorkflowGraph,
        inputs: [String: JSONValue],
        resumeFrom: WorkflowCheckpoint? = nil,
        resumeAnswer: String? = nil,
        subFlowLoader: @escaping (String) -> WorkflowGraph? = { _ in nil },
        yield: @escaping @Sendable (StepEvent) -> Void
    ) async throws -> (LocalRunOutcome, [String: JSONValue]) {
        lock.lock()
        visitedInPath = []
        lastOutput = nil
        lock.unlock()

        let state = FlowState()
        for (k, v) in resumeFrom?.stateSnapshot ?? inputs {
            state.write(v, for: k)
        }

        guard !graph.nodes.isEmpty else {
            return (.finished(summary: "empty graph"), [:])
        }

        // 起点: resume 时从 checkpoint 节点续跑 (注入答案); 否则 start
        let startNode: WorkflowNode
        if let cp = resumeFrom, let answer = resumeAnswer {
            if let n = graph.nodes.first(where: { $0.id == cp.nodeId }) {
                state.write(.string(answer), for: cp.answerKey)
                startNode = n
                yield(.stepFinished(nodeId: cp.nodeId.uuidString, output: answer))
                interpLog.info("resume checkpoint node=\(cp.nodeId.uuidString.prefix(8))")
            } else {
                return (.finished(summary: "checkpoint node missing"), state.snapshot)
            }
        } else {
            guard let s = graph.nodes.first(where: { $0.type == .start }) ?? graph.nodes.first else {
                return (.finished(summary: "no start node"), state.snapshot)
            }
            startNode = s
        }

        let (outcome, finalState) = try await walk(
            graph: graph, from: startNode, state: state,
            resumedFrom: resumeFrom?.nodeId,
            subFlowLoader: subFlowLoader, yield: yield
        )
        return (outcome, finalState)
    }

    // MARK: walk — 沿边解释, 返回终止结果

    private func walk(
        graph: WorkflowGraph,
        from node: WorkflowNode,
        state: FlowState,
        resumedFrom: UUID? = nil,
        subFlowLoader: @escaping (String) -> WorkflowGraph?,
        yield: @escaping @Sendable (StepEvent) -> Void
    ) async throws -> (LocalRunOutcome, [String: JSONValue]) {
        var current: WorkflowNode? = node
        var steps = 0
        let maxSteps = 1000 // 防御性步帽 (边环死循环兜底)

        while let n = current {
            steps += 1
            if steps > maxSteps {
                throw WorkflowError.maxIterationsExceeded(maxSteps)
            }
            lock.lock()
            let looped = visitedInPath.contains(n.id)
            lock.unlock()
            guard !looped else {
                return (.finished(summary: "cycle detected at \(nodeLabel(n))"), state.snapshot)
            }
            lock.lock()
            visitedInPath.insert(n.id)
            lock.unlock()

            // note 不参与执行
            if n.type == .note {
                current = nextNode(graph: graph, from: n, outputPort: "out", state: state)
                continue
            }

            guard let def = NodeRegistry.shared.definition(for: n.type) else {
                throw WorkflowError.nodeNotSupported(n.type.rawValue, "local")
            }
            guard Self.locallyRunnable.contains(n.type) else {
                throw WorkflowError.nodeNotSupported(n.type.rawValue, "local (use backend executor)")
            }

            yield(.stepStarted(nodeId: n.id.uuidString))
            // 上一节点输出注入 "in" (端到端值语义: end echo / 条件链取值)
            var nodeInputs = state.snapshot
            if let last = lastOutput {
                nodeInputs["in"] = last
            }
            let managed = interpreterManagedTypes.contains(n.type)
            var result = NodeResult()
            if !managed {
                let ctx = NodeContext(
                    nodeId: n.id,
                    config: n.config,
                    inputs: nodeInputs,
                    flowState: state
                )
                result = try await def.run(ctx)
                for (k, v) in result.stateWrites {
                    state.write(v, for: k)
                }
            }
            yield(.stepFinished(nodeId: n.id.uuidString, output: JSONValue.serializeScalar(result.output ?? .string(""))))
            lastOutput = result.output

            switch n.type {
            case .end:
                return (.finished(summary: JSONValue.serializeScalar(result.output ?? .string(""))), state.snapshot)

            case .condition:
                // 输出 "true"/"false" → 选同 key 输出端口的边
                let branch = result.output?.stringValue ?? "false"
                current = nextNode(graph: graph, from: n, outputPort: branch, state: state)
                    ?? nextNode(graph: graph, from: n, outputPort: "out", state: state)

            case .humanInput:
                // resume 起点即本节点: 答案已注入, 直接过到下游
                if n.id == resumedFrom {
                    current = nextNode(graph: graph, from: n, outputPort: "out", state: state)
                    break
                }
                // #430: 落 checkpoint, 运行挂起 (上层持久化后可重启恢复)
                let cp = WorkflowCheckpoint(
                    nodeId: n.id,
                    question: n.config["question"]?.stringValue ?? "Input required",
                    answerKey: n.config["answer_key"]?.stringValue ?? "human_answer",
                    stateSnapshot: state.snapshot,
                    createdAt: Date().timeIntervalSince1970
                )
                interpLog.info("checkpoint at node=\(n.id.uuidString.prefix(8)) key=\(cp.answerKey, privacy: .public)")
                return (.checkpoint(cp), state.snapshot)

            case .subFlow:
                // #430 flow-as-tool: 本地库装载子图, 子图 start 输入 = 当前 state
                let flowName = n.config["flow_name"]?.stringValue ?? ""
                guard !flowName.isEmpty, let sub = subFlowLoader(flowName) else {
                    throw WorkflowError.nodeNotSupported("sub_flow:\(flowName)", "local (flow not found)")
                }
                interpLog.info("sub flow inline: \(flowName, privacy: .public) nodes=\(sub.nodes.count)")
                yield(.tokenStream(nodeId: n.id.uuidString, chunk: "→ \(flowName)"))
                let (subResult, _) = try await walk(graph: sub, from: sub.nodes.first(where: { $0.type == .start }) ?? sub.nodes[0],
                                               state: state, subFlowLoader: subFlowLoader, yield: yield)
                if case .finished(let subSummary) = subResult {
                    lastOutput = .string(subSummary)
                }
                if case .checkpoint(let cp) = subResult {
                    // 子图 checkpoint 上抛 (answerKey 加前缀防冲突)
                    var shifted = cp
                    shifted.answerKey = "\(flowName).\(cp.answerKey)"
                    return (.checkpoint(shifted), state.snapshot)
                }
                current = nextNode(graph: graph, from: n, outputPort: "out", state: state)

            case .iteration, .loop:
                current = try await executeLoop(
                    graph: graph, node: n, state: state,
                    subFlowLoader: subFlowLoader, yield: yield
                )

            default:
                current = nextNode(graph: graph, from: n, outputPort: "out", state: state)
            }
        }
        return (.finished(summary: "path ended"), state.snapshot)
    }

    // MARK: loop / iteration (#429)

    private func executeLoop(
        graph: WorkflowGraph,
        node: WorkflowNode,
        state: FlowState,
        subFlowLoader: @escaping (String) -> WorkflowGraph?,
        yield: @escaping @Sendable (StepEvent) -> Void
    ) async throws -> WorkflowNode? {
        let maxIters = configInt(node.config["max_iterations"]) ?? 100
        if node.type == .iteration {
            // iteration: state[key] 数组逐项执行体内节点序列 (体内 = item 输出口下游)
            let itemKey = node.config["item_key"]?.stringValue ?? "item"
            guard case .array(let items) = state.value(for: "items") ?? state.value(for: "input") ?? .array([]) else {
                throw WorkflowError.incompatiblePorts("iteration requires array state at 'items'/'input'")
            }
            guard items.count <= maxIters else {
                throw WorkflowError.maxIterationsExceeded(maxIters)
            }
            var collected: [JSONValue] = []
            for (i, item) in items.enumerated() {
                state.write(item, for: itemKey)
                yield(.tokenStream(nodeId: node.id.uuidString, chunk: "iter \(i + 1)/\(items.count)"))
                // 体: item 口第一条出边路径到回边为止 (保守: 只执行直接后继一次)
                var ran = false
                if let bodyStart = nextNode(graph: graph, from: node, outputPort: "item", state: state),
                   bodyStart.type != node.type {
                    _ = try await runBodyOnce(graph: graph, from: bodyStart, state: state, subFlowLoader: subFlowLoader, yield: yield)
                    ran = true
                }
                if ran, let v = state.value(for: "\(itemKey)_out") {
                    collected.append(v)
                } else {
                    collected.append(item) // 无体/体未产出 → identity 透传
                }
            }
            state.write(.array(collected), for: "collected")
            return nextNode(graph: graph, from: node, outputPort: "out", state: state)
        }

        // loop 语义: 每轮从 state[state_key] 读条件 (真值继续), 数值型自动 +1 当计数器;
        //   体 = "item" 口下游; 结束走 "done" 口。超 max_iterations 显式抛错 (#429 帽)。
        let stateKey = node.config["state_key"]?.stringValue ?? "loop_i"
        var iters = 0
        while isTruthy(state.value(for: stateKey)) {
            iters += 1
            if iters > maxIters {
                throw WorkflowError.maxIterationsExceeded(maxIters)
            }
            yield(.tokenStream(nodeId: node.id.uuidString, chunk: "loop \(iters)/\(maxIters)"))
            if let bodyStart = nextNode(graph: graph, from: node, outputPort: "item", state: state),
               bodyStart.id != node.id {
                _ = try await runBodyOnce(graph: graph, from: bodyStart, state: state, subFlowLoader: subFlowLoader, yield: yield)
            }
            // 数值计数器自动步进 (bool 条件由体内节点改写)
            if case .double(let d) = state.value(for: stateKey) {
                state.write(.double(d + 1), for: stateKey)
            }
        }
        interpLog.info("loop done iters=\(iters) cap=\(maxIters)")
        return nextNode(graph: graph, from: node, outputPort: "done", state: state)
    }

    // 体执行: 顺序走到再入 loop 节点/环点为止 (单轮)
    private func runBodyOnce(
        graph: WorkflowGraph,
        from start: WorkflowNode,
        state: FlowState,
        subFlowLoader: @escaping (String) -> WorkflowGraph?,
        yield: @escaping @Sendable (StepEvent) -> Void
    ) async throws {
        var current: WorkflowNode? = start
        var hops = 0
        while let n = current {
            hops += 1
            if hops > 100 { return }
            if n.type == .loop || n.type == .iteration {
                return // 回边再入 loop/iteration = 单轮体结束
            }
            guard let def = NodeRegistry.shared.definition(for: n.type), Self.locallyRunnable.contains(n.type), n.type != .note else {
                return
            }
            yield(.stepStarted(nodeId: n.id.uuidString))
            let ctx = NodeContext(nodeId: n.id, config: n.config, inputs: state.snapshot, flowState: state)
            let result = try await def.run(ctx)
            for (k, v) in result.stateWrites {
                state.write(v, for: k)
            }
            yield(.stepFinished(nodeId: n.id.uuidString, output: JSONValue.serializeScalar(result.output ?? .string(""))))
            switch n.type {
            case .end, .humanInput:
                return
            case .condition:
                let branch = result.output?.stringValue ?? "false"
                current = nextNode(graph: graph, from: n, outputPort: branch, state: state)
            default:
                current = nextNode(graph: graph, from: n, outputPort: "out", state: state)
            }
        }
    }

    private func isTruthy(_ v: JSONValue?) -> Bool {
        switch v {
        case .bool(let b): return b
        case .string(let s): return s == "true" || s == "yes" || s == "1"
        case .double(let d): return d != 0
        default: return false
        }
    }

    // 从节点某输出口找后继
    private func nextNode(graph: WorkflowGraph, from node: WorkflowNode, outputPort: String, state: FlowState) -> WorkflowNode? {
        let edge = graph.edges.first { $0.sourceNode == node.id && $0.sourcePort == outputPort }
            ?? graph.edges.first { $0.sourceNode == node.id && $0.sourcePort == "out" }
        guard let e = edge else { return nil }
        return graph.nodes.first { $0.id == e.targetNode }
    }
}

// MARK: - LocalExecutor (WorkflowExecutor seam)

@MainActor
final class LocalExecutor: WorkflowExecutor {
    let kind = "local"
    let supportedNodeTypes: Set<NodeTypeKey> = LocalGraphInterpreter.locallyRunnable

    private let flowStore: WorkflowFlowStore
    // 变量检查器数据源 (#429): 最近一轮 FlowState 快照
    private(set) var lastStateSnapshot: [String: JSONValue] = [:]
    private var activeRunId: String?

    init(flowStore: WorkflowFlowStore) {
        self.flowStore = flowStore
    }

    func run(_ inputGraph: WorkflowGraph, inputs: [String: JSONValue]) -> AsyncThrowingStream<StepEvent, Error> {
        var graph = inputGraph
        let runId = "local_\(UUID().uuidString.prefix(8))"
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    continuation.yield(.runStarted(runId: runId))
                    activeRunId = runId
                    let interpreter = LocalGraphInterpreter()
                    let (outcome, finalState) = try await interpreter.execute(
                        graph, inputs: inputs,
                        subFlowLoader: { [weak self] name in
                            self?.loadFlowByName(name)
                        },
                        yield: { @Sendable event in
                            Task { @MainActor in
                                continuation.yield(event)
                            }
                        }
                    )
                    lastStateSnapshot = finalState
                    switch outcome {
                    case .finished(let summary):
                        graph.pendingCheckpoint = nil
                        try? self.flowStore.save(graph)
                        continuation.yield(.runFinished(summary: summary))
                    case .checkpoint(let cp):
                        // checkpoint 持久化 (#430): 落盘, run 正常结束 (挂起语义)
                        graph.pendingCheckpoint = cp
                        try? self.flowStore.save(graph)
                        continuation.yield(.runFinished(summary: "waiting for human input: \(cp.question)"))
                    }
                    activeRunId = nil
                    continuation.finish()
                } catch {
                    interpLog.error("local run failed: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // #430: checkpoint 恢复 (重启后 flow metadata 仍带 pending_checkpoint)
    func resume(_ inputGraph: WorkflowGraph, answer: String) -> AsyncThrowingStream<StepEvent, Error> {
        var graph = inputGraph
        guard let cp = graph.pendingCheckpoint else {
            return run(graph, inputs: [:])
        }
        let runId = "local_\(UUID().uuidString.prefix(8))"
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                do {
                    continuation.yield(.runStarted(runId: runId))
                    let interpreter = LocalGraphInterpreter()
                    let (outcome, finalState) = try await interpreter.execute(
                        graph, inputs: [:], resumeFrom: cp, resumeAnswer: answer,
                        subFlowLoader: { [weak self] name in self?.loadFlowByName(name) },
                        yield: { @Sendable event in
                            Task { @MainActor in continuation.yield(event) }
                        }
                    )
                    lastStateSnapshot = finalState
                    switch outcome {
                    case .finished(let summary):
                        graph.pendingCheckpoint = nil
                        try? self.flowStore.save(graph)
                        continuation.yield(.runFinished(summary: summary))
                    case .checkpoint(let newCp):
                        graph.pendingCheckpoint = newCp
                        try? self.flowStore.save(graph)
                        continuation.yield(.runFinished(summary: "waiting for human input: \(newCp.question)"))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func cancel(runId: String) async throws {
        interpLog.info("local cancel run=\(runId, privacy: .public)")
        activeRunId = nil
    }

    private func loadFlowByName(_ name: String) -> WorkflowGraph? {
        guard let flows = try? flowStore.listFlows() else { return nil }
        return flows.first { $0.name == name }
    }
}
