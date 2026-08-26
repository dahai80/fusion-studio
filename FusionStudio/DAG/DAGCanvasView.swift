// Callers: AgentStudioView workflow tab, standalone DAG editor.
// Affected API: DAGCanvasView (120fps Canvas DAG), DAGViewModel, DAGNodeCard.
// Data schemas: DAGNode, DAGEdge, DAGLayout. Connected to AgentBridge for real graph CRUD.
// User instruction: "继续Phase 3" — P3-1 DAG Canvas连接后端

import SwiftUI
import os.log

struct DAGNode: Identifiable, Equatable {
    let id: String
    var type: NodeType
    var label: String
    var position: CGPoint
    var state: NodeState

// #45 LangGraph node types added: retriever, router, memory, humanInLoop
// Affected API: DAGViewModel, DAGNodeCard template selection
// User instruction: #45 LangGraph 可视化工作流画布面板
    enum NodeType: String, CaseIterable {
        case start, llm, tool, condition, loop, end, errorHandler, retriever, router, memory, humanInLoop

        var icon: String {
            switch self {
            case .start: "play.circle.fill"
            case .llm: "brain"
            case .tool: "wrench.and.screwdriver"
            case .condition: "arrow.triangle.branch"
            case .loop: "arrow.clockwise"
            case .end: "stop.circle.fill"
            case .errorHandler: "exclamationmark.triangle"
            case .retriever: "magnifyingglass"
            case .router: "arrow.triangle.swap"
            case .memory: "internaldrive"
            case .humanInLoop: "person.crop.circle.badge.questionmark"
            }
        }
    }

    enum NodeState: Equatable {
        case idle, running, completed, error, skipped
    }

    static func == (lhs: DAGNode, rhs: DAGNode) -> Bool { lhs.id == rhs.id }
}

struct DAGEdge: Identifiable, Equatable {
    let id: String
    var sourceId: String
    var targetId: String
    var label: String?
    var isAnimated: Bool

    static func == (lhs: DAGEdge, rhs: DAGEdge) -> Bool { lhs.id == rhs.id }
}

struct DAGLayout {
    var nodes: [DAGNode]
    var edges: [DAGEdge]
    var canvasOffset: CGSize = .zero
    var canvasScale: CGFloat = 1.0

    static let nodeWidth: CGFloat = 160
    static let nodeHeight: CGFloat = 56
}

@MainActor
class DAGViewModel: ObservableObject {
    @Published var layout: DAGLayout = DAGLayout(nodes: [], edges: [])
    @Published var selectedNodeId: String?
    @Published var hoveredNodeId: String?
    @Published var isSimulating: Bool = false
    @Published var simulationStep: Int = 0
    @Published var currentGraphId: String?
    @Published var currentGraphName: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "DAGCanvas")
    private var simulationTimer: Timer?

    func loadFromGraph(nodes: [DAGNode], edges: [DAGEdge]) {
        layout.nodes = nodes
        layout.edges = edges
        autoLayout()
        logger.info("Loaded DAG with \(nodes.count) nodes, \(edges.count) edges")
    }

    func loadFromBridge(_ bridge: AgentBridge, graphId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let gid = graphId {
                guard let graph = try await bridge.graphGet(graphId: gid) else {
                    errorMessage = "Graph not found"
                    return
                }
                currentGraphId = graph.id
                currentGraphName = graph.name
                let nodes = graph.nodes.map { DAGNode(
                    id: $0.id,
                    type: DAGNode.NodeType(rawValue: $0.type) ?? .llm,
                    label: $0.config["label"]?.stringValue ?? $0.id,
                    position: CGPoint(x: $0.position?.x ?? 0, y: $0.position?.y ?? 0),
                    state: .idle
                )}
                let edges = graph.edges.map { DAGEdge(
                    id: $0.id,
                    sourceId: $0.source,
                    targetId: $0.target,
                    label: $0.condition,
                    isAnimated: false
                )}
                loadFromGraph(nodes: nodes, edges: edges)
            } else if let first = bridge.agentState.graphs.first {
                currentGraphId = first.id
                currentGraphName = first.name
                let nodes = first.nodes.map { DAGNode(
                    id: $0.id,
                    type: DAGNode.NodeType(rawValue: $0.type) ?? .llm,
                    label: $0.config["label"]?.stringValue ?? $0.id,
                    position: CGPoint(x: $0.position?.x ?? 0, y: $0.position?.y ?? 0),
                    state: .idle
                )}
                let edges = first.edges.map { DAGEdge(
                    id: $0.id,
                    sourceId: $0.source,
                    targetId: $0.target,
                    label: $0.condition,
                    isAnimated: false
                )}
                loadFromGraph(nodes: nodes, edges: edges)
            } else {
                loadFromGraph(nodes: [], edges: [])
                logger.info("No graphs available, empty canvas")
            }
        } catch {
            errorMessage = error.localizedDescription
            logger.error("loadFromBridge: \(error.localizedDescription)")
        }
    }

    func saveToBridge(_ bridge: AgentBridge) async {
        guard let graphId = currentGraphId else {
            do {
                let nodes = layout.nodes.map { NodeConfigModel(
                    id: $0.id, type: $0.type.rawValue,
                    config: ["label": .string($0.label)],
                    position: PositionModel(x: $0.position.x, y: $0.position.y)
                )}
                let edges = layout.edges.map { EdgeModel(
                    id: $0.id, source: $0.sourceId, target: $0.targetId, condition: $0.label
                )}
                _ = try await bridge.createGraph(name: currentGraphName.isEmpty ? "Untitled" : currentGraphName, nodes: nodes, edges: edges)
                try? await bridge.fetchGraphs()
                if let created = bridge.agentState.graphs.first { currentGraphId = created.id }
                logger.info("Created new graph via bridge")
            } catch {
                errorMessage = error.localizedDescription
                logger.error("saveToBridge create: \(error.localizedDescription)")
            }
            return
        }
        do {
            let nodes = layout.nodes.map { NodeConfigModel(
                id: $0.id, type: $0.type.rawValue,
                config: ["label": .string($0.label)],
                position: PositionModel(x: $0.position.x, y: $0.position.y)
            )}
            let edges = layout.edges.map { EdgeModel(
                id: $0.id, source: $0.sourceId, target: $0.targetId, condition: $0.label
            )}
            _ = try await bridge.updateGraph(id: graphId, name: currentGraphName, nodes: nodes, edges: edges)
            logger.info("Saved graph \(graphId) via bridge")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("saveToBridge update: \(error.localizedDescription)")
        }
    }

    func executeGraph(_ bridge: AgentBridge) async {
        guard let graphId = currentGraphId else { return }
        isSimulating = true
        simulationStep = 0
        for i in layout.nodes.indices { layout.nodes[i].state = .idle }
        for i in layout.edges.indices { layout.edges[i].isAnimated = false }
        do {
            try await bridge.executeGraph(id: graphId, input: "")
            let events = bridge.events
            for (idx, ev) in events.enumerated() {
                if idx < layout.nodes.count {
                    layout.nodes[idx].state = .running
                    if idx > 0 { layout.nodes[idx - 1].state = .completed }
                    if let eIdx = layout.edges.firstIndex(where: { $0.sourceId == layout.nodes[max(0, idx - 1)].id && $0.targetId == layout.nodes[idx].id }) {
                        layout.edges[eIdx].isAnimated = true
                    }
                }
            }
            if !layout.nodes.isEmpty { layout.nodes[layout.nodes.count - 1].state = .completed }
            isSimulating = false
            logger.info("Graph execution complete: \(events.count) events")
        } catch {
            for i in layout.nodes.indices {
                if layout.nodes[i].state == .running { layout.nodes[i].state = .error }
            }
            isSimulating = false
            errorMessage = error.localizedDescription
            logger.error("executeGraph: \(error.localizedDescription)")
        }
    }

    func addNode(_ node: DAGNode) {
        layout.nodes.append(node)
        logger.info("Added node: \(node.id) type=\(node.type.rawValue)")
    }

    func removeNode(id: String) {
        layout.nodes.removeAll { $0.id == id }
        layout.edges.removeAll { $0.sourceId == id || $0.targetId == id }
        if selectedNodeId == id { selectedNodeId = nil }
        logger.info("Removed node: \(id)")
    }

    func addEdge(_ edge: DAGEdge) {
        layout.edges.append(edge)
        logger.info("Added edge: \(edge.sourceId) -> \(edge.targetId)")
    }

    func moveNode(id: String, to position: CGPoint) {
        guard let idx = layout.nodes.firstIndex(where: { $0.id == id }) else { return }
        layout.nodes[idx].position = position
    }

    func selectNode(id: String?) {
        selectedNodeId = id
    }

    func stopSimulation() {
        isSimulating = false
        simulationTimer?.invalidate()
        simulationTimer = nil
        for i in layout.nodes.indices { layout.nodes[i].state = .idle }
        for i in layout.edges.indices { layout.edges[i].isAnimated = false }
        logger.info("DAG simulation stopped")
    }

    private func autoLayout() {
        let spacing: CGFloat = 200
        let verticalSpacing: CGFloat = 100
        let sortedNodes = layout.nodes.sorted { $0.position.x < $1.position.x }

        var rows: [[DAGNode]] = []
        var currentRow: [DAGNode] = []
        var lastX: CGFloat = -.infinity

        for node in sortedNodes {
            if abs(node.position.x - lastX) > spacing / 2 && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = []
            }
            currentRow.append(node)
            lastX = node.position.x
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        for (rowIdx, row) in rows.enumerated() {
            let totalWidth = CGFloat(row.count - 1) * spacing
            let startX = -totalWidth / 2
            for (colIdx, var node) in row.enumerated() {
                node.position = CGPoint(
                    x: startX + CGFloat(colIdx) * spacing,
                    y: CGFloat(rowIdx) * verticalSpacing
                )
                if let idx = layout.nodes.firstIndex(where: { $0.id == node.id }) {
                    layout.nodes[idx].position = node.position
                }
            }
        }
    }
}

struct DAGCanvasView: View {
    @StateObject private var viewModel = DAGViewModel()
    @EnvironmentObject var bridge: AgentBridge
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) var theme
    @State private var showTemplateSelector = false
    @State private var templates: [[String: Any]] = []

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let offset = viewModel.layout.canvasOffset
                let scale = viewModel.layout.canvasScale

                for edge in viewModel.layout.edges {
                    guard let src = viewModel.layout.nodes.first(where: { $0.id == edge.sourceId }),
                          let tgt = viewModel.layout.nodes.first(where: { $0.id == edge.targetId }) else { continue }

                    let srcCenter = CGPoint(
                        x: center.x + (src.position.x + DAGLayout.nodeWidth / 2) * scale + offset.width,
                        y: center.y + (src.position.y + DAGLayout.nodeHeight / 2) * scale + offset.height
                    )
                    let tgtCenter = CGPoint(
                        x: center.x + (tgt.position.x + DAGLayout.nodeWidth / 2) * scale + offset.width,
                        y: center.y + (tgt.position.y + DAGLayout.nodeHeight / 2) * scale + offset.height
                    )

                    var path = Path()
                    let midX = (srcCenter.x + tgtCenter.x) / 2
                    path.move(to: srcCenter)
                    path.addCurve(to: tgtCenter, control1: CGPoint(x: midX, y: srcCenter.y), control2: CGPoint(x: midX, y: tgtCenter.y))

                    let edgeColor = edge.isAnimated ? theme.accent : theme.inputBorder
                    context.stroke(path, with: .color(edgeColor), lineWidth: edge.isAnimated ? 2.5 : 1.5)

                    if let label = edge.label {
                        let labelPos = CGPoint(x: midX, y: (srcCenter.y + tgtCenter.y) / 2 - 8)
                        context.draw(
                            Text(label).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary),
                            at: labelPos
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .overlay {
                GeometryReader { geo in
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    let offset = viewModel.layout.canvasOffset
                    let scale = viewModel.layout.canvasScale

                    ForEach(viewModel.layout.nodes) { node in
                        let nodePos = CGPoint(
                            x: center.x + node.position.x * scale + offset.width,
                            y: center.y + node.position.y * scale + offset.height
                        )

                        DAGNodeCard(node: node, isSelected: viewModel.selectedNodeId == node.id, isHovered: viewModel.hoveredNodeId == node.id)
                            .position(nodePos)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let dx = value.translation.width / scale
                                        let dy = value.translation.height / scale
                                        viewModel.moveNode(id: node.id, to: CGPoint(x: node.position.x + dx, y: node.position.y + dy))
                                    }
                            )
                            .onTapGesture { viewModel.selectNode(id: node.id) }
                            .onHover { hovering in
                                viewModel.hoveredNodeId = hovering ? node.id : nil
                            }
                    }
                }
            }
        }
        .background(theme.surfacePrimary)
        .contextMenu {
            ForEach(DAGNode.NodeType.allCases, id: \.self) { type in
                Button {
                    let id = "node_\(UUID().uuidString.prefix(8))"
                    viewModel.addNode(DAGNode(
                        id: id, type: type, label: type.rawValue.capitalized,
                        position: CGPoint(x: CGFloat.random(in: -200...200), y: CGFloat.random(in: -100...100)),
                        state: .idle
                    ))
                } label: {
                    Label(type.rawValue.capitalized, systemImage: type.icon)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.isLoading {
                    ProgressView().scaleEffect(0.6)
                }
                FusionButton(viewModel.isSimulating ? "Stop" : "Run", icon: viewModel.isSimulating ? "stop.fill" : "play.fill", style: viewModel.isSimulating ? .destructive : .primary, size: .small) {
                    if viewModel.isSimulating {
                        viewModel.stopSimulation()
                    } else {
                        Task { await viewModel.executeGraph(bridge) }
                    }
                }
                FusionButton("Save", icon: "square.and.arrow.down", style: .secondary, size: .small) {
                    Task { await viewModel.saveToBridge(bridge) }
                }
                FusionButton("Reload", icon: "arrow.clockwise", style: .secondary, size: .small) {
                    Task { await viewModel.loadFromBridge(bridge) }
                }
                FusionButton("模板", icon: "square.grid.3x3", style: .secondary, size: .small) {
                    showTemplateSelector = true
                }
            }
        }
        .onAppear {
            Task { await viewModel.loadFromBridge(bridge) }
        }
        .sheet(isPresented: $showTemplateSelector) {
            templateSelectorSheet
        }
    }

    private var templateSelectorSheet: some View {
        VStack(spacing: theme.spacingM) {
            HStack {
                Text("LangGraph 模板")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button("关闭") { showTemplateSelector = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textTertiary)
            }
            if templates.isEmpty {
                Text("加载模板...")
                    .foregroundStyle(theme.textTertiary)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingS) {
                        ForEach(Array(templates.enumerated()), id: \.offset) { idx, tpl in
                            templateCard(tpl)
                        }
                    }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 400)
        .onAppear { loadTemplates() }
    }

    private func templateCard(_ tpl: [String: Any]) -> some View {
        let name = tpl["name"] as? String ?? "Template"
        let desc = tpl["description"] as? String ?? ""
        let category = tpl["category"] as? String ?? ""
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Image(systemName: "square.grid.3x3")
                    .foregroundStyle(theme.accent)
                Text(name)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
            }
            if !desc.isEmpty {
                Text(desc)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            if !category.isEmpty {
                Text(category)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accentSoft.opacity(0.2))
                    .cornerRadius(4)
            }
            Button("使用模板") { instantiateTemplate(tpl) }
                .buttonStyle(.plain)
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.accent)
        }
        .padding(theme.spacingS)
        .background(theme.surfaceElevated)
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private func loadTemplates() {
        Task {
            do {
                let result = try await ipc.templateList(category: "langgraph")
                await MainActor.run {
                    templates = result["templates"] as? [[String: Any]] ?? []
                }
            } catch {
                await MainActor.run { templates = [] }
            }
        }
    }

    private func instantiateTemplate(_ tpl: [String: Any]) {
        let tplId = tpl["id"] as? String ?? ""
        Task {
            do {
                _ = try await ipc.templateInstantiate(templateId: tplId)
                await viewModel.loadFromBridge(bridge)
                showTemplateSelector = false
            } catch { }
        }
    }
}

struct DAGNodeCard: View {
    let node: DAGNode
    let isSelected: Bool
    let isHovered: Bool
    @Environment(\.studioTheme) var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: node.type.icon)
                .font(.system(size: theme.iconM, weight: .medium))
                .foregroundStyle(stateColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.label)
                    .font(.system(size: theme.smallTextSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(node.type.rawValue)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .frame(width: DAGLayout.nodeWidth, height: DAGLayout.nodeHeight)
        .background(nodeBg)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(isSelected ? theme.accent : (isHovered ? theme.accentSoft : theme.inputBorder), lineWidth: isSelected ? 2 : 1)
        }
        .studioShadow(isSelected ? theme.shadowMedium : theme.shadowSmall)
        .animation(theme.springSnappy, value: isSelected)
        .animation(theme.springSnappy, value: isHovered)
    }

    private var nodeBg: Color {
        switch node.state {
        case .idle: theme.surfaceElevated
        case .running: theme.accentSoft
        case .completed: theme.successBg
        case .error: theme.errorBg
        case .skipped: theme.surfaceSecondary
        }
    }

    private var stateColor: Color {
        switch node.state {
        case .idle: theme.accent
        case .running: theme.accent
        case .completed: theme.greenDot
        case .error: theme.redDot
        case .skipped: theme.textTertiary
        }
    }
}
