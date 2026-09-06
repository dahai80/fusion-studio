import SwiftUI
import os.log

struct CanvasNode<NodeType: Hashable & RawRepresentable>: Identifiable where NodeType.RawValue == String {
    let id: String
    var type: NodeType
    var label: String
    var position: CGPoint
    var config: [String: JSONValue]
    init(id: String = "n_\(UUID().uuidString.prefix(8))", type: NodeType, label: String, position: CGPoint, config: [String: JSONValue] = [:]) {
        self.id = id
        self.type = type
        self.label = label
        self.position = position
        self.config = config
    }
}

struct CanvasEdge: Identifiable {
    let id: String
    var sourceId: String
    var targetId: String
    var condition: String?
    init(id: String = "e_\(UUID().uuidString.prefix(8))", sourceId: String, targetId: String, condition: String? = nil) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
        self.condition = condition
    }
}

enum CanvasToolbarLabel: String, CaseIterable {
    case autoLayout, saveLayout, testRun, save, running, saving
    case nodeTypes, hintDrag, hintRightClick, hintConnect
    case nodeName, deleteNode, inspectorReadOnly, inspectorEdit, wfName
    case addNode, close
}

@MainActor
protocol WorkflowCanvasDelegate: AnyObject, ObservableObject {
    associatedtype NodeType: Hashable, CaseIterable, RawRepresentable where NodeType.RawValue == String

    var canvasNodeTypes: [NodeType] { get }
    var supportsTestRun: Bool { get }
    func displayName(_ t: NodeType) -> String
    func icon(_ t: NodeType) -> String
    func color(_ t: NodeType) -> Color
    func defaultLabel(_ t: NodeType) -> String
    func nodeID() -> String
    func edgeID(from: String, to: String) -> String
    func toolbarLabel(_ kind: CanvasToolbarLabel) -> String

    @ViewBuilder func configSection(for node: Binding<CanvasNode<NodeType>>) -> AnyView?

    func save(graphName: String, nodes: [CanvasNode<NodeType>], edges: [CanvasEdge]) async throws
    func load() async throws -> (name: String, nodes: [CanvasNode<NodeType>], edges: [CanvasEdge])
    func persistLayout(_ layout: [String: CGPoint]) async
}

extension WorkflowCanvasDelegate {
    var supportsTestRun: Bool { false }
}

private let canvasLog = Logger(subsystem: "com.fusion.studio", category: "WorkflowCanvas")

struct WorkflowCanvasView<Delegate: WorkflowCanvasDelegate>: View where Delegate.NodeType: Hashable, Delegate.NodeType: CaseIterable, Delegate.NodeType: RawRepresentable, Delegate.NodeType.RawValue == String {
    @ObservedObject var delegate: Delegate
    @Binding var graphName: String
    var onSave: () -> Void

    @State private var nodes: [CanvasNode<Delegate.NodeType>] = []
    @State private var edges: [CanvasEdge] = []
    @State private var selectedNodeId: String? = nil
    @State private var hoveredNodeId: String? = nil
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var connectingFrom: String? = nil
    @State private var mousePos: CGPoint = .zero
    @State private var isSaving = false
    @State private var showAddNode = false
    @State private var addNodePos: CGPoint = .zero
    @State private var inspectorReadOnly = true
    @State private var layoutSaveTask: Task<Void, Never>? = nil
    @State private var lastSavedPositions: [String: CGPoint] = [:]
    @State private var isRunning = false
    @State private var runningNodeId: String? = nil

    @Environment(\.studioTheme) private var theme

    private let nodeWidth: CGFloat = 180
    private let nodeHeight: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            canvasToolbar
            Divider()
            HStack(spacing: 0) {
                nodePalette
                Divider()
                canvasArea
                if selectedNodeId != nil {
                    Divider()
                    nodeConfigPanel
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear { Task { try? await loadGraph() } }
        .sheet(isPresented: $showAddNode) { addNodeSheet }
    }

    // MARK: - Toolbar

    private var canvasToolbar: some View {
        HStack(spacing: theme.spacingM) {
            TextField(delegate.toolbarLabel(.wfName), text: $graphName)
                .textFieldStyle(.plain)
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
                .frame(width: 180)

            Spacer()

            HStack(spacing: theme.spacingS) {
                Button(action: { autoLayout() }) {
                    Label(delegate.toolbarLabel(.autoLayout), systemImage: "rectangle.grid.3x3")
                        .font(.system(size: theme.captionSize))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { Task { await saveCanvasLayout() } }) {
                    Label(delegate.toolbarLabel(.saveLayout), systemImage: "rectangle.dashed.and.paperclip")
                        .font(.system(size: theme.captionSize))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(nodes.isEmpty)

                if delegate.supportsTestRun {
                    Button(action: { Task { await runTest() } }) {
                        Label(isRunning ? delegate.toolbarLabel(.running) : delegate.toolbarLabel(.testRun), systemImage: isRunning ? "stop" : "play")
                            .font(.system(size: theme.captionSize))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isRunning || nodes.isEmpty)
                }

                Button(action: { Task { await saveGraph() } }) {
                    Label(isSaving ? delegate.toolbarLabel(.saving) : delegate.toolbarLabel(.save), systemImage: "square.and.arrow.down")
                        .font(.system(size: theme.captionSize))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isSaving)
            }
        }
        .padding(theme.spacingS)
        .background(theme.contentBg)
    }

    // MARK: - Node Palette

    private var nodePalette: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(delegate.toolbarLabel(.nodeTypes))
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(theme.spacingS)

            ForEach(delegate.canvasNodeTypes, id: \.self) { type in
                nodePaletteItem(type: type)
            }
            .padding(.horizontal, theme.spacingS)

            Spacer()

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(delegate.toolbarLabel(.hintDrag))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                Text(delegate.toolbarLabel(.hintRightClick))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                Text(delegate.toolbarLabel(.hintConnect))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingS)
        }
        .frame(width: 160)
        .background(theme.contentBg)
    }

    @ViewBuilder
    private func nodePaletteItem(type: Delegate.NodeType) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: delegate.icon(type))
                .foregroundStyle(delegate.color(type))
                .frame(width: 16)
            Text(delegate.displayName(type))
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.text)
        }
        .padding(theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(theme.separator, lineWidth: 0.5)
        )
        .onDrag {
            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: "com.fusion.canvas.node", visibility: .ownProcess) { completion in
                let data = type.rawValue.data(using: .utf8)
                completion(data, nil)
                return Progress(totalUnitCount: 1)
            }
            return provider
        }
        .padding(.bottom, theme.spacingXS)
    }

    // MARK: - Canvas Area

    private var canvasArea: some View {
        ZStack {
            canvasBackground
            TimelineView(.animation) { _ in
                Canvas { ctx, size in
                    drawEdges(ctx: ctx, size: size)
                    if let fromId = connectingFrom, let fromNode = nodes.first(where: { $0.id == fromId }) {
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let srcPt = CGPoint(
                            x: center.x + (fromNode.position.x + nodeWidth) * canvasScale + canvasOffset.width,
                            y: center.y + (fromNode.position.y + nodeHeight / 2) * canvasScale + canvasOffset.height
                        )
                        var path = Path()
                        path.move(to: srcPt)
                        let midX = (srcPt.x + mousePos.x) / 2
                        path.addCurve(to: mousePos, control1: CGPoint(x: midX, y: srcPt.y), control2: CGPoint(x: midX, y: mousePos.y))
                        ctx.stroke(path, with: .color(theme.accent.opacity(0.5)), lineWidth: 2)
                    }
                }
                .allowsHitTesting(false)
            }
            nodeOverlay
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gesture(canvasPanGesture)
        .gesture(canvasMagnifyGesture)
        .contextMenu { canvasContextMenu }
        .onDrop(of: ["com.fusion.canvas.node"], isTargeted: nil) { providers in
            handleDrop(providers)
            return true
        }
    }

    private var canvasBackground: some View {
        Rectangle()
            .fill(theme.contentBg)
            .overlay(
                Canvas { ctx, size in
                    let gridSpacing: CGFloat = 30 * canvasScale
                    if gridSpacing < 5 { return }
                    let ox = canvasOffset.width.truncatingRemainder(dividingBy: gridSpacing)
                    let oy = canvasOffset.height.truncatingRemainder(dividingBy: gridSpacing)
                    for x in stride(from: ox, to: size.width, by: gridSpacing) {
                        for y in stride(from: oy, to: size.height, by: gridSpacing) {
                            let rect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                            ctx.fill(Path(rect), with: .color(theme.separator.opacity(0.3)))
                        }
                    }
                }
            )
    }

    private func drawEdges(ctx: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for edge in edges {
            guard let src = nodes.first(where: { $0.id == edge.sourceId }),
                  let tgt = nodes.first(where: { $0.id == edge.targetId }) else { continue }

            let srcPt = CGPoint(
                x: center.x + (src.position.x + nodeWidth) * canvasScale + canvasOffset.width,
                y: center.y + (src.position.y + nodeHeight / 2) * canvasScale + canvasOffset.height
            )
            let tgtPt = CGPoint(
                x: center.x + tgt.position.x * canvasScale + canvasOffset.width,
                y: center.y + (tgt.position.y + nodeHeight / 2) * canvasScale + canvasOffset.height
            )

            var path = Path()
            let midX = (srcPt.x + tgtPt.x) / 2
            path.move(to: srcPt)
            path.addCurve(to: tgtPt, control1: CGPoint(x: midX, y: srcPt.y), control2: CGPoint(x: midX, y: tgtPt.y))

            let edgeColor = theme.separator
            ctx.stroke(path, with: .color(edgeColor), lineWidth: 1.5)

            if let cond = edge.condition {
                let labelPos = CGPoint(x: midX, y: (srcPt.y + tgtPt.y) / 2 - 10)
                ctx.draw(
                    Text(cond).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary),
                    at: labelPos
                )
            }

            let arrowSize: CGFloat = 8
            let angle = atan2(tgtPt.y - srcPt.y, tgtPt.x - srcPt.x)
            var arrow = Path()
            arrow.move(to: tgtPt)
            arrow.addLine(to: CGPoint(x: tgtPt.x - arrowSize * cos(angle - 0.4), y: tgtPt.y - arrowSize * sin(angle - 0.4)))
            arrow.addLine(to: CGPoint(x: tgtPt.x - arrowSize * cos(angle + 0.4), y: tgtPt.y - arrowSize * sin(angle + 0.4)))
            arrow.closeSubpath()
            ctx.fill(arrow, with: .color(edgeColor))
        }
    }

    private var nodeOverlay: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                ForEach(nodes) { node in
                    let pos = CGPoint(
                        x: center.x + node.position.x * canvasScale + canvasOffset.width,
                        y: center.y + node.position.y * canvasScale + canvasOffset.height
                    )
                    nodeCard(node: node)
                        .position(x: pos.x + nodeWidth / 2 * canvasScale, y: pos.y + nodeHeight / 2 * canvasScale)
                        .scaleEffect(canvasScale)
                        .gesture(nodeDragGesture(node: node))
                        .onTapGesture { selectNode(node.id) }
                        .onHover { h in hoveredNodeId = h ? node.id : nil }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func nodeCard(node: CanvasNode<Delegate.NodeType>) -> some View {
        let isSelected = selectedNodeId == node.id
        let isHovered = hoveredNodeId == node.id
        let isRunningNode = runningNodeId == node.id

        HStack(spacing: theme.spacingS) {
            outputPort(node: node)
            Image(systemName: delegate.icon(node.type))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isRunningNode ? Color.white : delegate.color(node.type))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isRunningNode ? delegate.color(node.type) : delegate.color(node.type).opacity(0.15))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(node.label)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(delegate.displayName(node.type))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            inputPort(node: node)
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, theme.spacingXS)
        .frame(width: nodeWidth, height: nodeHeight)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(isSelected ? theme.accent : (isHovered ? theme.accent.opacity(0.4) : theme.separator), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? theme.accent.opacity(0.2) : .black.opacity(0.1), radius: isSelected ? 8 : 3, y: 2)
    }

    @ViewBuilder
    private func outputPort(node: CanvasNode<Delegate.NodeType>) -> some View {
        let isConnecting = connectingFrom == node.id
        Circle()
            .fill(isConnecting ? theme.accent : theme.textTertiary.opacity(0.5))
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(theme.contentBg, lineWidth: 2))
            .onTapGesture {
                if connectingFrom == nil {
                    connectingFrom = node.id
                    canvasLog.info("connecting from \(node.id)")
                }
            }
    }

    @ViewBuilder
    private func inputPort(node: CanvasNode<Delegate.NodeType>) -> some View {
        let canConnect = connectingFrom != nil && connectingFrom != node.id
        Circle()
            .fill(canConnect ? theme.accent : theme.textTertiary.opacity(0.5))
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(theme.contentBg, lineWidth: 2))
            .onTapGesture {
                if let fromId = connectingFrom, fromId != node.id {
                    addEdge(from: fromId, to: node.id)
                    connectingFrom = nil
                }
            }
    }

    // MARK: - Node Config Panel

    private var nodeConfigPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                if let nodeId = selectedNodeId,
                   let idx = nodes.firstIndex(where: { $0.id == nodeId }) {
                    let node = nodes[idx]
                    HStack {
                        Image(systemName: delegate.icon(node.type))
                            .foregroundStyle(delegate.color(node.type))
                        Text(delegate.displayName(node.type))
                            .font(.system(size: theme.textSize, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Spacer()
                        Button(action: { inspectorReadOnly.toggle() }) {
                            Image(systemName: inspectorReadOnly ? "lock" : "pencil")
                                .foregroundStyle(inspectorReadOnly ? theme.textTertiary : theme.accent)
                        }
                        .buttonStyle(.plain)
                        .help(inspectorReadOnly ? delegate.toolbarLabel(.inspectorEdit) : delegate.toolbarLabel(.inspectorReadOnly))
                        Button(action: { selectedNodeId = nil }) {
                            Image(systemName: "xmark")
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    Group {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            Text(delegate.toolbarLabel(.nodeName))
                                .font(.system(size: theme.captionSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            TextField(delegate.toolbarLabel(.nodeName), text: Binding(
                                get: { nodes[idx].label },
                                set: { v in updateNodeLabel(nodeId, label: v) }
                            ))
                            .textFieldStyle(.plain)
                            .padding(theme.spacingXS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(theme.surfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.separator, lineWidth: 0.5)
                            )
                        }

                        if let section = delegate.configSection(for: Binding(
                            get: { nodes[idx] },
                            set: { nodes[idx] = $0 }
                        )) {
                            section
                        } else {
                            Text(delegate.toolbarLabel(.inspectorReadOnly))
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                                .padding(theme.spacingS)
                        }

                        Divider()

                        Button(role: .destructive, action: { deleteNode(nodeId) }) {
                            Label(delegate.toolbarLabel(.deleteNode), systemImage: "trash")
                                .font(.system(size: theme.captionSize))
                        }
                        .controlSize(.small)
                    }
                    .disabled(inspectorReadOnly)
                }
            }
            .padding(theme.spacingM)
        }
        .frame(width: 260)
        .background(theme.contentBg)
    }

    // MARK: - Add Node Sheet

    private var addNodeSheet: some View {
        VStack(spacing: theme.spacingM) {
            HStack {
                Text(delegate.toolbarLabel(.addNode))
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(delegate.toolbarLabel(.close)) { showAddNode = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textTertiary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingS) {
                ForEach(delegate.canvasNodeTypes, id: \.self) { type in
                    Button(action: {
                        addNodeAtPos(type: type, pos: addNodePos)
                        showAddNode = false
                    }) {
                        HStack(spacing: theme.spacingS) {
                            Image(systemName: delegate.icon(type))
                                .foregroundStyle(delegate.color(type))
                            Text(delegate.displayName(type))
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.text)
                        }
                        .padding(theme.spacingS)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(theme.surfaceElevated)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400, height: 300)
    }

    // MARK: - Canvas Context Menu

    @ViewBuilder
    private var canvasContextMenu: some View {
        ForEach(delegate.canvasNodeTypes, id: \.self) { type in
            Button {
                addNodeAtPos(type: type, pos: CGPoint(
                    x: CGFloat.random(in: -200...200),
                    y: CGFloat.random(in: -150...150)
                ))
            } label: {
                Label(delegate.displayName(type), systemImage: delegate.icon(type))
            }
        }
    }

    // MARK: - Gestures

    private var canvasPanGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if connectingFrom != nil {
                    mousePos = value.location
                } else {
                    canvasOffset = CGSize(
                        width: canvasOffset.width + value.translation.width,
                        height: canvasOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                if connectingFrom != nil {
                    connectingFrom = nil
                }
            }
    }

    private var canvasMagnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                canvasScale = min(max(canvasScale * scale, 0.3), 3.0)
            }
    }

    private func nodeDragGesture(node: CanvasNode<Delegate.NodeType>) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
                    let dx = value.translation.width / canvasScale
                    let dy = value.translation.height / canvasScale
                    nodes[idx].position = CGPoint(
                        x: nodes[idx].position.x + dx,
                        y: nodes[idx].position.y + dy
                    )
                }
            }
            .onEnded { _ in
                scheduleLayoutSave()
            }
    }

    // MARK: - Node Operations

    private func selectNode(_ id: String) {
        selectedNodeId = id
        canvasLog.info("selected node: \(id)")
    }

    private func addNodeAtPos(type: Delegate.NodeType, pos: CGPoint) {
        let node = CanvasNode(id: delegate.nodeID(), type: type, label: delegate.defaultLabel(type), position: pos)
        nodes.append(node)
        canvasLog.info("added node: \(node.id) type=\(type.rawValue)")
    }

    private func deleteNode(_ id: String) {
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.sourceId == id || $0.targetId == id }
        if selectedNodeId == id { selectedNodeId = nil }
        canvasLog.info("deleted node: \(id)")
    }

    private func addEdge(from: String, to: String) {
        let exists = edges.contains { $0.sourceId == from && $0.targetId == to }
        guard !exists else { return }
        let edge = CanvasEdge(id: delegate.edgeID(from: from, to: to), sourceId: from, targetId: to)
        edges.append(edge)
        canvasLog.info("added edge: \(from) -> \(to)")
    }

    private func updateNodeLabel(_ id: String, label: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].label = label
    }

    private func autoLayout() {
        let hSpacing: CGFloat = 220
        let vSpacing: CGFloat = 120

        let sorted = topologicalSort()
        var levels: [String: Int] = [:]
        for node in sorted {
            let maxPredLevel = edges
                .filter { $0.targetId == node.id }
                .compactMap { levels[$0.sourceId] }
                .max() ?? -1
            levels[node.id] = maxPredLevel + 1
        }

        let byLevel = Dictionary(grouping: nodes) { levels[$0.id] ?? 0 }
        for (level, levelNodes) in byLevel {
            let totalWidth = CGFloat(levelNodes.count - 1) * hSpacing
            let startX = -totalWidth / 2
            for (col, node) in levelNodes.enumerated() {
                let newPos = CGPoint(x: startX + CGFloat(col) * hSpacing, y: CGFloat(level) * vSpacing)
                if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
                    nodes[idx].position = newPos
                }
            }
        }
        canvasOffset = .zero
        canvasScale = 1.0
        canvasLog.info("auto-layout applied")
    }

    private func topologicalSort() -> [CanvasNode<Delegate.NodeType>] {
        var inDegree: [String: Int] = [:]
        for node in nodes { inDegree[node.id] = 0 }
        for edge in edges { inDegree[edge.targetId, default: 0] += 1 }

        var queue = nodes.filter { (inDegree[$0.id] ?? 0) == 0 }
        var result: [CanvasNode<Delegate.NodeType>] = []

        while !queue.isEmpty {
            let current = queue.removeFirst()
            result.append(current)
            for edge in edges where edge.sourceId == current.id {
                inDegree[edge.targetId, default: 0] -= 1
                if inDegree[edge.targetId] == 0,
                   let n = nodes.first(where: { $0.id == edge.targetId }) {
                    queue.append(n)
                }
            }
        }
        return result.isEmpty ? nodes : result
    }

    private func runTest() async {
        guard !isRunning else { return }
        let sorted = topologicalSort()
        isRunning = true
        canvasLog.info("runTest: simulating \(sorted.count) nodes")
        for node in sorted {
            runningNodeId = node.id
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { break }
        }
        runningNodeId = nil
        isRunning = false
        canvasLog.info("runTest: simulation complete")
    }

    // MARK: - Data

    private func loadGraph() async throws {
        do {
            let (name, n, e) = try await delegate.load()
            graphName = name
            nodes = n
            edges = e
            lastSavedPositions = Dictionary(uniqueKeysWithValues: n.map { ($0.id, $0.position) })
            canvasLog.info("loaded graph name=\(name, privacy: .public) nodes=\(n.count) edges=\(e.count)")
        } catch {
            canvasLog.error("load graph failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func scheduleLayoutSave() {
        layoutSaveTask?.cancel()
        layoutSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
            await saveCanvasLayout()
        }
    }

    private func saveCanvasLayout() async {
        guard !nodes.isEmpty else { return }
        var changed = false
        var layout: [String: CGPoint] = [:]
        for n in nodes {
            let x = n.position.x.isFinite ? n.position.x : 0
            let y = n.position.y.isFinite ? n.position.y : 0
            let pos = CGPoint(x: x, y: y)
            layout[n.id] = pos
            if let last = lastSavedPositions[n.id], last != pos {
                changed = true
            } else if lastSavedPositions[n.id] == nil {
                changed = true
            }
        }
        guard changed else { canvasLog.info("canvas-layout skip: no change"); return }
        await delegate.persistLayout(layout)
        for n in nodes { lastSavedPositions[n.id] = n.position }
        canvasLog.info("canvas-layout saved nodes=\(layout.count)")
    }

    private func saveGraph() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await delegate.save(graphName: graphName, nodes: nodes, edges: edges)
            canvasLog.info("saved graph name=\(graphName, privacy: .public) nodes=\(nodes.count) edges=\(edges.count)")
            onSave()
        } catch {
            canvasLog.error("save graph failed: \(error.localizedDescription)")
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "com.fusion.canvas.node", options: nil) { data, _ in
            guard let data = data as? Data,
                  let typeStr = String(data: data, encoding: .utf8),
                  let type = Delegate.NodeType(rawValue: typeStr) else { return }
            Task { @MainActor in
                addNodeAtPos(type: type, pos: CGPoint(
                    x: CGFloat.random(in: -150...150),
                    y: CGFloat.random(in: -100...100)
                ))
            }
        }
    }
}
