import SwiftUI
import os.log

enum AgentNodeType: String, CaseIterable {
    case start, llm, tool, condition, loop, end
    case errorHandler, retriever, router, memory, humanInLoop

    var icon: String {
        switch self {
        case .start: return "play.circle.fill"
        case .llm: return "brain"
        case .tool: return "wrench.and.screwdriver"
        case .condition: return "arrow.triangle.branch"
        case .loop: return "arrow.clockwise"
        case .end: return "stop.circle.fill"
        case .errorHandler: return "exclamationmark.triangle"
        case .retriever: return "magnifyingglass"
        case .router: return "arrow.triangle.swap"
        case .memory: return "internaldrive"
        case .humanInLoop: return "person.crop.circle.badge.questionmark"
        }
    }

    var color: Color {
        switch self {
        case .start: return .green
        case .llm: return .purple
        case .tool: return .blue
        case .condition: return .orange
        case .loop: return .cyan
        case .end: return .gray
        case .errorHandler: return .red
        case .retriever: return .teal
        case .router: return .indigo
        case .memory: return .brown
        case .humanInLoop: return .pink
        }
    }

    var i18nKey: I18nKey {
        switch self {
        case .start: return .wf_cv_node_start
        case .llm: return .wf_cv_node_llm
        case .tool: return .wf_cv_node_tool
        case .condition: return .wf_cv_node_condition
        case .loop: return .wf_cv_node_loop
        case .end: return .wf_cv_node_end
        case .errorHandler: return .wf_cv_node_error_handler
        case .retriever: return .wf_cv_node_retriever
        case .router: return .wf_cv_node_router
        case .memory: return .wf_cv_node_memory
        case .humanInLoop: return .wf_cv_node_human_in_loop
        }
    }
}

private let agentCanvasLog = Logger(subsystem: "com.fusion.studio", category: "agent-workflow-canvas")

@MainActor
final class AgentWorkflowCanvasDelegate: ObservableObject, WorkflowCanvasDelegate {
    typealias NodeType = AgentNodeType

    var bridge: AgentBridge
    var graphId: String?
    @Published var graphName: String = ""

    init(bridge: AgentBridge, graph: AgentGraphModel?) {
        self.bridge = bridge
        self.graphId = graph?.id
        self.graphName = graph?.name ?? ""
    }

    var canvasNodeTypes: [AgentNodeType] { AgentNodeType.allCases }
    func displayName(_ t: AgentNodeType) -> String { I18nManager.shared.t(t.i18nKey) }
    func icon(_ t: AgentNodeType) -> String { t.icon }
    func color(_ t: AgentNodeType) -> Color { t.color }
    func defaultLabel(_ t: AgentNodeType) -> String { displayName(t) }
    func nodeID() -> String { "n_\(UUID().uuidString.prefix(8))" }
    func edgeID(from: String, to: String) -> String { "e_\(UUID().uuidString.prefix(8))" }

    func toolbarLabel(_ kind: CanvasToolbarLabel) -> String {
        switch kind {
        case .autoLayout: return I18nManager.shared.t(.wf_cv_autoLayout)
        case .saveLayout: return I18nManager.shared.t(.wf_cv_saveLayout)
        case .testRun: return I18nManager.shared.t(.wf_cv_testRun)
        case .running: return I18nManager.shared.t(.wf_cv_running)
        case .saving: return I18nManager.shared.t(.wf_cv_saving)
        case .save: return I18nManager.shared.t(.save)
        case .close: return I18nManager.shared.t(.close)
        case .nodeTypes: return I18nManager.shared.t(.wf_cv_nodeTypes)
        case .hintDrag: return I18nManager.shared.t(.wf_cv_hintDrag)
        case .hintRightClick: return I18nManager.shared.t(.wf_cv_hintRightClick)
        case .hintConnect: return I18nManager.shared.t(.wf_cv_hintConnect)
        case .nodeName: return I18nManager.shared.t(.wf_cv_nodeName)
        case .deleteNode: return I18nManager.shared.t(.wf_cv_deleteNode)
        case .inspectorReadOnly: return I18nManager.shared.t(.wf_cv_inspectorReadOnly)
        case .inspectorEdit: return I18nManager.shared.t(.wf_cv_inspectorEdit)
        case .wfName: return I18nManager.shared.t(.wf_cv_wfName)
        case .addNode: return I18nManager.shared.t(.wf_cv_nodeTypes)
        }
    }

    @ViewBuilder
    func configSection(for node: Binding<CanvasNode<AgentNodeType>>) -> AnyView? {
        let models = bridge.mlxState.models.map { $0.id }
        switch node.wrappedValue.type {
        case .start, .end: return nil
        case .llm: return AnyView(AgentLLMSection(node: node, models: models))
        case .tool: return AnyView(AgentToolSection(node: node))
        case .condition: return AnyView(AgentConditionSection(node: node))
        case .loop: return AnyView(AgentLoopSection(node: node))
        case .errorHandler: return AnyView(AgentErrorHandlerSection(node: node))
        case .retriever: return AnyView(AgentRetrieverSection(node: node))
        case .router: return AnyView(AgentRouterSection(node: node))
        case .memory: return AnyView(AgentMemorySection(node: node))
        case .humanInLoop: return AnyView(AgentHumanInLoopSection(node: node))
        }
    }

    func save(graphName: String, nodes: [CanvasNode<AgentNodeType>], edges: [CanvasEdge]) async throws {
        let nodeModels = nodes.map { n in
            NodeConfigModel(
                id: n.id,
                type: n.type.rawValue,
                config: mergeLabelIntoConfig(n.config, label: n.label),
                position: PositionModel(x: n.position.x, y: n.position.y)
            )
        }
        let edgeModels = edges.map { e in
            EdgeModel(id: e.id, source: e.sourceId, target: e.targetId, condition: e.condition)
        }
        if let gid = graphId {
            _ = try await bridge.updateGraph(id: gid, name: graphName, nodes: nodeModels, edges: edgeModels)
            agentCanvasLog.info("updateGraph id=\(gid, privacy: .public) nodes=\(nodeModels.count) edges=\(edgeModels.count)")
        } else {
            let created = try await bridge.createGraph(name: graphName, nodes: nodeModels, edges: edgeModels)
            self.graphId = created.id
            agentCanvasLog.info("createGraph id=\(created.id, privacy: .public) nodes=\(nodeModels.count) edges=\(edgeModels.count)")
        }
    }

    func load() async throws -> (name: String, nodes: [CanvasNode<AgentNodeType>], edges: [CanvasEdge]) {
        guard let gid = graphId, let g = try await bridge.graphGet(graphId: gid) else {
            return (graphName, [], [])
        }
        self.graphName = g.name
        let cnodes = g.nodes.map { nm in
            CanvasNode(
                id: nm.id,
                type: AgentNodeType(rawValue: nm.type) ?? .llm,
                label: labelFromConfig(nm.config),
                position: CGPoint(x: nm.position?.x ?? 0, y: nm.position?.y ?? 0),
                config: nm.config
            )
        }
        let cedges = g.edges.map { e in
            CanvasEdge(id: e.id, sourceId: e.source, targetId: e.target, condition: e.condition)
        }
        agentCanvasLog.info("load graphId=\(gid, privacy: .public) nodes=\(cnodes.count) edges=\(cedges.count)")
        return (g.name, cnodes, cedges)
    }

    func persistLayout(_ layout: [String: CGPoint]) async {
        // 审计0907 P2-1: 旧日志 "layout persisted" 误导 (实为 no-op, 位置随下次 full save 持久化)。
        //   改准确描述: 布局暂存内存, 下次 save() 整图提交时一并落盘。
        agentCanvasLog.info("Agent workflow layout staged in memory (\(layout.count) nodes); persisted on next full save()")
    }

    private func mergeLabelIntoConfig(_ config: [String: JSONValue], label: String) -> [String: JSONValue] {
        var c = config
        c["label"] = .string(label)
        return c
    }

    private func labelFromConfig(_ config: [String: JSONValue]) -> String {
        config["label"]?.stringValue ?? ""
    }
}

private extension JSONValue {
    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        return nil
    }
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}

// 审计0907 P1-1: Agent 工作流画布 inspector 仅显示节点类型名, 无真实配置字段。
//   补 per-type 配置区 (镜像 FSB 模式), 写入 node.config:[String:JSONValue], save() 经 mergeLabelIntoConfig 持久化。
//   上游 _handle_graph_create/_update 只读 type/label/model/system_prompt 4 字段 (见 upstream issue),
//   其余字段先存 config, 上游扩展后即生效。LLM model 取 bridge.mlxState.models (实时拉取)。
private struct ConfigFieldLabel: View {
    let key: I18nKey
    @Environment(\.studioTheme) private var theme
    var body: some View {
        Text(I18nManager.shared.t(key))
            .font(.system(size: theme.captionSize, weight: .medium))
            .foregroundStyle(theme.textSecondary)
    }
}

private struct ConfigHint: View {
    let key: I18nKey
    @Environment(\.studioTheme) private var theme
    var body: some View {
        Text(I18nManager.shared.t(key))
            .font(.system(size: 11))
            .foregroundStyle(theme.textTertiary)
    }
}

private struct AgentLLMSection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    let models: [String]
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ConfigFieldLabel(key: .wf_cv_cfgModel)
            let current = node.config["model"]?.stringValue ?? (models.first ?? "")
            if models.isEmpty {
                Text(current.isEmpty ? "—" : current)
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            } else {
                Picker(I18nManager.shared.t(.wf_cv_cfgModel), selection: Binding(
                    get: { current },
                    set: { v in node.config["model"] = .string(v) }
                )) {
                    ForEach(models, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .labelsHidden()
            }

            ConfigFieldLabel(key: .wf_cv_cfgSystemPrompt)
            TextEditor(text: Binding(
                get: { node.config["system_prompt"]?.stringValue ?? "" },
                set: { v in node.config["system_prompt"] = .string(v) }
            ))
            .font(.system(size: theme.captionSize, design: .monospaced))
            .frame(height: 80)
            .padding(theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.surfaceElevated)
            )

            HStack(spacing: theme.spacingS) {
                VStack(alignment: .leading, spacing: 2) {
                    ConfigFieldLabel(key: .wf_cv_cfgTemperature)
                    let temp = node.config["temperature"]?.doubleValue ?? 0.7
                    TextField("0.7", value: Binding(
                        get: { temp },
                        set: { v in node.config["temperature"] = .double(v) }
                    ), format: .number.precision(.fractionLength(1)))
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 2) {
                    ConfigFieldLabel(key: .wf_cv_cfgMaxTokens)
                    let mt = Int(node.config["max_tokens"]?.doubleValue ?? 2048)
                    TextField("2048", value: Binding(
                        get: { mt },
                        set: { v in node.config["max_tokens"] = .double(Double(v)) }
                    ), format: .number)
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                }
            }

            ConfigHint(key: .wf_cv_cfgHint)
        }
    }
}

private struct AgentToolSection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    @Environment(\.studioTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ConfigFieldLabel(key: .wf_cv_cfgTools)
            TextEditor(text: Binding(
                get: { node.config["tools"]?.stringValue ?? "" },
                set: { v in node.config["tools"] = .string(v) }
            ))
            .font(.system(size: theme.captionSize, design: .monospaced))
            .frame(height: 60)
            .padding(theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.surfaceElevated)
            )
            ConfigHint(key: .wf_cv_cfgHint)
        }
    }
}

private struct AgentConditionSection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    @Environment(\.studioTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ConfigFieldLabel(key: .wf_cv_cfgCondition)
            TextEditor(text: Binding(
                get: { node.config["expression"]?.stringValue ?? "" },
                set: { v in node.config["expression"] = .string(v) }
            ))
            .font(.system(size: theme.captionSize, design: .monospaced))
            .frame(height: 60)
            .padding(theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.surfaceElevated)
            )
            ConfigHint(key: .wf_cv_cfgHint)
        }
    }
}

private struct AgentLoopSection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    @Environment(\.studioTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ConfigFieldLabel(key: .wf_cv_cfgLoopCount)
            let cnt = Int(node.config["count"]?.doubleValue ?? 3)
            Stepper(value: Binding(
                get: { cnt },
                set: { v in node.config["count"] = .double(Double(v)) }
            ), in: 1...100) {
                Text("\(cnt)")
                    .font(.system(size: theme.captionSize, design: .monospaced))
            }
            ConfigHint(key: .wf_cv_cfgHint)
        }
    }
}

private struct AgentRetrieverSection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    @Environment(\.studioTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ConfigFieldLabel(key: .wf_cv_cfgQuery)
            TextEditor(text: Binding(
                get: { node.config["query"]?.stringValue ?? "" },
                set: { v in node.config["query"] = .string(v) }
            ))
            .font(.system(size: theme.captionSize, design: .monospaced))
            .frame(height: 60)
            .padding(theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.surfaceElevated)
            )
            ConfigHint(key: .wf_cv_cfgHint)
        }
    }
}

private struct AgentMemorySection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    @Environment(\.studioTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ConfigFieldLabel(key: .wf_cv_cfgMemoryOp)
            let op = node.config["op"]?.stringValue ?? "store"
            Picker(I18nManager.shared.t(.wf_cv_cfgMemoryOp), selection: Binding(
                get: { op },
                set: { v in node.config["op"] = .string(v) }
            )) {
                Text("store").tag("store")
                Text("recall").tag("recall")
                Text("forget").tag("forget")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            ConfigHint(key: .wf_cv_cfgHint)
        }
    }
}

private struct AgentRouterSection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    @Environment(\.studioTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ConfigFieldLabel(key: .wf_cv_cfgRouterTarget)
            TextField(I18nManager.shared.t(.wf_cv_cfgRouterTarget), text: Binding(
                get: { node.config["target"]?.stringValue ?? "" },
                set: { v in node.config["target"] = .string(v) }
            ))
            .font(.system(size: theme.captionSize, design: .monospaced))
            .textFieldStyle(.roundedBorder)
            ConfigHint(key: .wf_cv_cfgHint)
        }
    }
}

private struct AgentHumanInLoopSection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    @Environment(\.studioTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ConfigFieldLabel(key: .wf_cv_cfgHumanMsg)
            TextEditor(text: Binding(
                get: { node.config["message"]?.stringValue ?? "" },
                set: { v in node.config["message"] = .string(v) }
            ))
            .font(.system(size: theme.captionSize, design: .monospaced))
            .frame(height: 60)
            .padding(theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.surfaceElevated)
            )
            ConfigHint(key: .wf_cv_cfgHint)
        }
    }
}

private struct AgentErrorHandlerSection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    @Environment(\.studioTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ConfigFieldLabel(key: .wf_cv_cfgErrAction)
            let act = node.config["action"]?.stringValue ?? "retry"
            Picker(I18nManager.shared.t(.wf_cv_cfgErrAction), selection: Binding(
                get: { act },
                set: { v in node.config["action"] = .string(v) }
            )) {
                Text("retry").tag("retry")
                Text("fallback").tag("fallback")
                Text("abort").tag("abort")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            ConfigHint(key: .wf_cv_cfgHint)
        }
    }
}
