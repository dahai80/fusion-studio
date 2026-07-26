// Callers: AgentStudioView workflow tab, standalone DAG editor.
// Affected API: DAGCanvasView (120fps Canvas DAG), DAGViewModel, DAGNodeCard.
// Data schemas: DAGNode, DAGEdge, DAGLayout.
// User instruction: "落地外壳（SwiftUI）：负责 120fps 的极致交互、系统级感知（FSEvents, Accessibility）和沙箱管理。调用 frontend-design 来做好 UI 和 UX 交互设计"

import SwiftUI
import os.log

struct DAGNode: Identifiable, Equatable {
    let id: String
    var type: NodeType
    var label: String
    var position: CGPoint
    var state: NodeState

    enum NodeType: String, CaseIterable {
        case start, llm, tool, condition, loop, end, errorHandler

        var icon: String {
            switch self {
            case .start: "play.circle.fill"
            case .llm: "brain"
            case .tool: "wrench.and.screwdriver"
            case .condition: "arrow.triangle.branch"
            case .loop: "arrow.clockwise"
            case .end: "stop.circle.fill"
            case .errorHandler: "exclamationmark.triangle"
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

    private let logger = Logger(subsystem: "com.fusion.studio", category: "DAGCanvas")
    private var simulationTimer: Timer?

    func loadFromGraph(nodes: [DAGNode], edges: [DAGEdge]) {
        layout.nodes = nodes
        layout.edges = edges
        autoLayout()
        logger.info("Loaded DAG with \(nodes.count) nodes, \(edges.count) edges")
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

    func startSimulation() {
        isSimulating = true
        simulationStep = 0
        for i in layout.nodes.indices { layout.nodes[i].state = .idle }
        for i in layout.edges.indices { layout.edges[i].isAnimated = false }

        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceSimulation()
            }
        }
        logger.info("DAG simulation started")
    }

    func stopSimulation() {
        isSimulating = false
        simulationTimer?.invalidate()
        simulationTimer = nil
        for i in layout.nodes.indices { layout.nodes[i].state = .idle }
        for i in layout.edges.indices { layout.edges[i].isAnimated = false }
        logger.info("DAG simulation stopped")
    }

    private func advanceSimulation() {
        let sortedNodes = layout.nodes.sorted { $0.position.x < $1.position.x }
        guard simulationStep < sortedNodes.count else {
            stopSimulation()
            return
        }

        let node = sortedNodes[simulationStep]
        if let idx = layout.nodes.firstIndex(where: { $0.id == node.id }) {
            layout.nodes[idx].state = .running
        }

        if simulationStep > 0 {
            let prevNode = sortedNodes[simulationStep - 1]
            if let idx = layout.nodes.firstIndex(where: { $0.id == prevNode.id }) {
                layout.nodes[idx].state = .completed
            }
            if let eIdx = layout.edges.firstIndex(where: { $0.sourceId == prevNode.id && $0.targetId == node.id }) {
                layout.edges[eIdx].isAnimated = true
            }
        }

        simulationStep += 1
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
    @Environment(\.studioTheme) var theme

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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                FusionButton(viewModel.isSimulating ? "Stop" : "Run", icon: viewModel.isSimulating ? "stop.fill" : "play.fill", style: viewModel.isSimulating ? .destructive : .primary, size: .small) {
                    if viewModel.isSimulating { viewModel.stopSimulation() } else { viewModel.startSimulation() }
                }
                FusionButton("Reset", icon: "arrow.counterclockwise", style: .secondary, size: .small) {
                    viewModel.stopSimulation()
                }
            }
        }
        .onAppear {
            viewModel.loadFromGraph(nodes: sampleNodes, edges: sampleEdges)
        }
    }

    private var sampleNodes: [DAGNode] {
        [
            DAGNode(id: "start", type: .start, label: "Start", position: CGPoint(x: -300, y: 0), state: .idle),
            DAGNode(id: "llm1", type: .llm, label: "LLM Analyze", position: CGPoint(x: -100, y: -60), state: .idle),
            DAGNode(id: "tool1", type: .tool, label: "Search Tool", position: CGPoint(x: -100, y: 60), state: .idle),
            DAGNode(id: "cond1", type: .condition, label: "Check Result", position: CGPoint(x: 100, y: 0), state: .idle),
            DAGNode(id: "llm2", type: .llm, label: "LLM Generate", position: CGPoint(x: 300, y: 0), state: .idle),
            DAGNode(id: "end", type: .end, label: "End", position: CGPoint(x: 500, y: 0), state: .idle),
        ]
    }

    private var sampleEdges: [DAGEdge] {
        [
            DAGEdge(id: "e1", sourceId: "start", targetId: "llm1", label: nil, isAnimated: false),
            DAGEdge(id: "e2", sourceId: "start", targetId: "tool1", label: nil, isAnimated: false),
            DAGEdge(id: "e3", sourceId: "llm1", targetId: "cond1", label: nil, isAnimated: false),
            DAGEdge(id: "e4", sourceId: "tool1", targetId: "cond1", label: nil, isAnimated: false),
            DAGEdge(id: "e5", sourceId: "cond1", targetId: "llm2", label: "yes", isAnimated: false),
            DAGEdge(id: "e6", sourceId: "llm2", targetId: "end", label: nil, isAnimated: false),
        ]
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
