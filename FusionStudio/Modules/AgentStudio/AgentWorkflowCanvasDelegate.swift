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
        switch node.wrappedValue.type {
        case .start, .end: return nil
        default: return AnyView(AgentNodeConfigSection(node: node))
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
        agentCanvasLog.info("Agent workflow layout persisted on next full save (\(layout.count) nodes)")
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

private struct AgentNodeConfigSection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(node.type.rawValue.uppercased())
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
    }
}
