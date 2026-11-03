import SwiftUI
import os.log

// #423 P1-3 mount wrapper (plan §6.3 GraphFlowBuilderView)。
//   canvas + inspector + executor + flow store 组装; 接入 AgentTaskViews DetailMode。
//   create 模式: 空 graph (start+end 种子); edit 模式: 本地 flow 优先 (backendId 关联), 无则从后端 graph 解码。
//   保存: codec.toBackend → 后端 create/update + 本地 flow store 落盘 (secret 占位符, #425)。

private let builderLog = Logger(subsystem: "com.fusion.studio", category: "GraphFlowBuilder")

struct GraphFlowBuilderView: View {
    enum Mode {
        case create
        case edit(AgentGraphModel)
    }

    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme
    let mode: Mode
    let toastManager: FusionToastManager
    let onSave: () -> Void

    @State private var graph = WorkflowGraph(name: "Untitled flow")
    @State private var flowStore = WorkflowFlowStore()
    @State private var loaded = false
    @State private var isSaving = false
    @State private var executor: AgentStudioExecutor?

    var body: some View {
        GraphCanvasView(
            graph: $graph,
            executor: executor,
            toast: toastManager,
            flowStore: flowStore
        )
        .toolbar {
            ToolbarItem {
                FusionButton("Save", icon: "square.and.arrow.down", style: .primary, size: .small, isDisabled: isSaving) {
                    Task { await save() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard !loaded else { return }
        loaded = true
        if executor == nil {
            executor = AgentStudioExecutor(bridge: bridge)
        }
        switch mode {
        case .create:
            graph = Self.seedGraph()
            builderLog.info("builder create mode, seed graph")
        case .edit(let backend):
            // 本地 flow 关联优先 (backend_id); 无本地副本 → 从后端 graph 解码
            if let local = try? flowStore.listFlows().first(where: { $0.backendId == backend.id }) {
                graph = local
                builderLog.info("builder edit mode: local flow id=\(local.id.uuidString) backend=\(backend.id, privacy: .public)")
            } else {
                graph = AgentStudioCodec().fromBackend(backend)
                graph.backendId = backend.id
                builderLog.info("builder edit mode: decoded backend graph id=\(backend.id, privacy: .public)")
            }
        }
    }

    private func save() async {
        guard !graph.name.isEmpty else {
            toastManager.show(style: .error, title: "Save failed", message: "Flow name is empty")
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            // run() 期间 executor 可能已 create 后端图 — 收编其 backendId, 防重复建图
            if graph.backendId == nil, let runCreated = executor?.backendId(for: graph.id) {
                graph.backendId = runCreated
                builderLog.info("adopted backend id from run: \(runCreated, privacy: .public)")
            }
            let codec = AgentStudioCodec()
            let backendModel = try codec.toBackend(graph)
            let saved: AgentGraphModel
            if let existing = graph.backendId, !existing.isEmpty {
                saved = try await bridge.updateGraph(id: existing, name: backendModel.name, nodes: backendModel.nodes, edges: backendModel.edges)
                    ?? backendModel
            } else {
                saved = try await bridge.createGraph(name: backendModel.name, nodes: backendModel.nodes, edges: backendModel.edges)
                graph.backendId = saved.id
            }
            // 本地落盘 (secret 已是占位符; strip 在 inspector 写入时完成)
            try flowStore.save(graph)
            builderLog.info("flow saved backend=\(saved.id, privacy: .public) nodes=\(graph.nodes.count)")
            toastManager.show(style: .success, title: "Flow saved", message: graph.name)
            onSave()
        } catch {
            builderLog.error("flow save failed: \(error.localizedDescription, privacy: .public)")
            toastManager.show(style: .error, title: "Save failed", message: error.localizedDescription)
        }
    }

    // 种子 graph: start → end (可执行最小流)
    static func seedGraph() -> WorkflowGraph {
        var g = WorkflowGraph(name: "Untitled flow")
        let start = WorkflowNode(type: .start, position: GraphPoint(x: 80, y: 160))
        let end = WorkflowNode(type: .end, position: GraphPoint(x: 360, y: 160))
        g.nodes = [start, end]
        g.edges = [WorkflowEdge(sourceNode: start.id, sourcePort: "out", targetNode: end.id, targetPort: "in")]
        return g
    }
}
