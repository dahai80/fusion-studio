import SwiftUI
import os.log

// #423 P1-3 mount wrapper (plan §6.3 GraphFlowBuilderView)。
//   canvas + inspector + executor + flow store 组装; 接入 AgentTaskViews DetailMode。
//   create 模式: 空 graph (start+end 种子); edit 模式: 本地 flow 优先 (backendId 关联), 无则从后端 graph 解码。
//   保存: codec.toBackend → 后端 create/update + 本地 flow store 落盘 (secret 占位符, #425)。
// #428 P2-2: executor 后端选择 (agent-studio / local / fsb / cowork) — 真 backend 执行, 无假 run。
// #429 P2-3: 变量检查器 (FlowState 快照)。
// #430 P2-4: checkpoint 恢复入口 (pending_checkpoint 存在 → Resume 按钮收人类输入续跑)。

private let builderLog = Logger(subsystem: "com.fusion.studio", category: "GraphFlowBuilder")

@MainActor
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
    @State private var executor: (any WorkflowExecutor)?
    // #428: 执行后端选择 (默认 agent-studio 兼容 P1 行为)
    @AppStorage("flowBuilderBackend") private var backendKind = "agent-studio"
    @AppStorage("flowBuilderFsbWorkspace") private var fsbWorkspaceId = ""
    // #429: 变量检查器
    @State private var showVariables = false
    // #430: checkpoint 人类输入
    @State private var resumeAnswer = ""
    @State private var showResumePrompt = false
    // #431: 模板画廊
    @State private var showTemplates = false
    // #432: 运行历史 + diff
    @State private var showHistory = false
    // #433: NL 构图
    @State private var showAIBuild = false

    var body: some View {
        GraphCanvasView(
            graph: $graph,
            executor: executor,
            toast: toastManager,
            flowStore: flowStore
        )
        .toolbar {
            ToolbarItem {
                Picker("Backend", selection: $backendKind) {
                    Text("agent-studio").tag("agent-studio")
                    Text("local").tag("local")
                    Text("fsb").tag("fsb")
                    Text("cowork").tag("cowork")
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                .onChange(of: backendKind) { _, _ in rebuildExecutor() }
            }
            if backendKind == "fsb" {
                ToolbarItem {
                    TextField("FSB workspace id", text: $fsbWorkspaceId)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .help("FSB workspace id (from FSB module)")
                }
            }
            ToolbarItem {
                Button {
                    showVariables = true
                } label: {
                    Label("Variables", systemImage: "curlybraces.square")
                }
                .help("Inspect FlowState snapshot from the last local run")
            }
            // #431: 模板画廊 (空图也可见, 一键实例化)
            ToolbarItem {
                Button {
                    showTemplates = true
                } label: {
                    Label("Templates", systemImage: "square.grid.2x2")
                }
                .help("Start from a template flow")
            }
            // #432: 运行历史 + 回放 diff
            ToolbarItem {
                Button {
                    showHistory = true
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .help("Recent runs and run-to-run diff")
            }
            // #433: 自然语言构图
            ToolbarItem {
                Button {
                    showAIBuild = true
                } label: {
                    Label("AI Build", systemImage: "sparkles")
                }
                .help("Describe the flow and let the model build it")
            }
            // #430: 挂起 checkpoint → 收答案续跑 (重启后 flow 落盘仍带 checkpoint)
            if graph.pendingCheckpoint != nil {
                ToolbarItem {
                    Button {
                        showResumePrompt = true
                    } label: {
                        Label("Resume", systemImage: "playpause")
                    }
                    .tint(.orange)
                    .help("Human input checkpoint pending — answer to continue")
                }
            }
            ToolbarItem {
                FusionButton("Save", icon: "square.and.arrow.down", style: .primary, size: .small, isDisabled: isSaving) {
                    Task { await save() }
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showVariables) { variablesSheet }
        .sheet(isPresented: $showResumePrompt) { resumeSheet }
        // #431: 模板画廊 — 实例化替换当前图 (新 id, 不带 checkpoint)
        .sheet(isPresented: $showTemplates) {
            TemplateGallerySheet(flowStore: flowStore) { picked in
                graph = picked
                toastManager.show(style: .success, title: "Template loaded", message: picked.name)
            }
        }
        // #432: 运行历史 + diff
        .sheet(isPresented: $showHistory) {
            RunHistorySheet(flowStore: flowStore, flowId: graph.id)
        }
        // #433: NL 构图 — plan 应用到当前图
        .sheet(isPresented: $showAIBuild) {
            AIBuildSheet(
                prompt: graph.name == "Untitled flow" ? "" : graph.name,
                infer: { messages in try await bridge.infer(messages: messages) }
            ) { plan in
                var editor = WorkflowGraphEditor(graph: graph)
                let applied = editor.applyPlan(plan)
                graph = editor.graph
                toastManager.show(
                    style: applied > 0 ? .success : .error,
                    title: applied > 0 ? "Plan applied" : "Plan skipped",
                    message: "\(applied) nodes from \"\(plan.name)\""
                )
            }
        }
    }

    // MARK: - Variables inspector (#429)

    private var variablesSheet: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("FlowState Variables")
                .font(.system(size: theme.textSize, weight: .semibold))
            let snap = currentVariableSnapshot()
            if snap.isEmpty {
                Text("No state recorded yet — run with the local backend to populate.")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            } else {
                ForEach(snap.keys.sorted(), id: \.self) { key in
                    HStack(alignment: .top) {
                        Text(key)
                            .font(.system(size: theme.footnoteSize, weight: .medium, design: .monospaced))
                            .frame(width: 140, alignment: .leading)
                        Text(JSONValue.serializeScalar(snap[key] ?? .string("")))
                            .font(.system(size: theme.footnoteSize, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(3)
                    }
                }
            }
            Spacer()
        }
        .padding(theme.spacingM)
        .frame(width: 460, height: 360)
    }

    private func currentVariableSnapshot() -> [String: JSONValue] {
        if let local = executor as? LocalExecutor, !local.lastStateSnapshot.isEmpty {
            return local.lastStateSnapshot
        }
        // 重启恢复路径: checkpoint 快照即最近已知 state
        return graph.pendingCheckpoint?.stateSnapshot ?? [:]
    }

    // MARK: - Resume (#430)

    private var resumeSheet: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("Human Input Checkpoint")
                .font(.system(size: theme.textSize, weight: .semibold))
            Text(graph.pendingCheckpoint?.question ?? "")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
            TextField("Your answer", text: $resumeAnswer)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                FusionButton("Continue", icon: "arrow.forward", style: .primary, size: .small, isDisabled: resumeAnswer.isEmpty) {
                    showResumePrompt = false
                    resumeWithAnswer()
                }
            }
        }
        .padding(theme.spacingM)
        .frame(width: 420)
    }

    private func resumeWithAnswer() {
        if !(executor is LocalExecutor) {
            // 非 local 后端: checkpoint 语义属本地解释器 — 自动切换
            executor = LocalExecutor(flowStore: flowStore)
            backendKind = "local"
        }
        guard let e = executor as? LocalExecutor else { return }
        let g = graph
        let answer = resumeAnswer
        resumeAnswer = ""
        Task { @MainActor in
            do {
                for try await _ in e.resume(g, answer: answer) {}
                // resume 期间 checkpoint 清落盘 — 从 store 取最新 graph 回填 UI
                if let fresh = try? flowStore.load(g.id) {
                    graph = fresh
                }
                toastManager.show(style: .success, title: "Flow resumed", message: g.name)
            } catch {
                toastManager.show(style: .error, title: "Resume failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Load / executor

    private func load() async {
        guard !loaded else { return }
        loaded = true
        NodeRegistry.shared.bootstrapFullSet()
        rebuildExecutor()
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

    private func rebuildExecutor() {
        switch backendKind {
        case "local":
            executor = LocalExecutor(flowStore: flowStore)
        case "fsb":
            guard !fsbWorkspaceId.isEmpty else {
                executor = nil
                builderLog.warning("fsb backend selected but workspace id empty")
                return
            }
            executor = FSBExecutor(ipc: bridge.ipcClient, workspaceId: fsbWorkspaceId)
        case "cowork":
            executor = CoWorkExecutor(ipc: bridge.ipcClient)
        default:
            executor = AgentStudioExecutor(bridge: bridge)
        }
        builderLog.info("executor rebuilt: \(backendKind, privacy: .public)")
    }

    // MARK: - Save

    private func save() async {
        guard !graph.name.isEmpty else {
            toastManager.show(style: .error, title: "Save failed", message: "Flow name is empty")
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            // run() 期间 executor 可能已 create 后端图 — 收编其 backendId, 防重复建图
            if graph.backendId == nil, let runCreated = (executor as? AgentStudioExecutor)?.backendId(for: graph.id) {
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
