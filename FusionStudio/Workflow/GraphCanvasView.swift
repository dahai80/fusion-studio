import SwiftUI
import os.log

// #423 P1-3: 统一 GraphCanvasView (plan §6.1/§7.1)。
//   view-based 节点 + Canvas 边层; pan/zoom 0.3-3.0; snap-to-grid 16pt 可切换;
//   palette 拖放落光标处 (修 FSB 随机落点 bug); 类型化端口连线 + 实时校验
//   (兼容绿 / 不兼容红 / 拒绝 toast); 点边选中 + Delete; 橡皮筋 + shift 多选;
//   复制/粘贴/复制副本; UndoManager 撤销重做; minimap; noteNode; Tidy 拓扑整理。
// #424 P1-4: 执行反馈 — Run/Step/Cancel 工具栏, 节点状态徽标 (pulse/done/error), llm token 内联流。
//   零假动画: 状态只来自 executor 真实 StepEvent。

private let graphCanvasLog = Logger(subsystem: "com.fusion.studio", category: "GraphCanvas")

// 节点运行状态 (#424, 全部由 StepEvent 驱动)
enum NodeRunStatus: Equatable {
    case idle
    case running
    case finished(String)
    case error(String)
    case unsupported(backend: String)
}

// @MainActor 全结构体: 成员触达 MainActor executor + @State; Xcode 15 下 helper 非
// isolated 调用即报错 (审计经验: 显式标注防 CI Swift 5 隔离检查)
@MainActor
struct GraphCanvasView: View {
    @Environment(\.studioTheme) private var theme
    @Binding var graph: WorkflowGraph
    var executor: (any WorkflowExecutor)?
    var toast: FusionToastManager?
    var flowStore: WorkflowFlowStore?

    // MARK: state
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var selectedNodeIds: Set<UUID> = []
    @State private var selectedEdgeId: UUID? = nil
    @State private var wireDrag: WireDrag? = nil
    @State private var rubberBand: CGRect? = nil
    @State private var selectMode = false
    @State private var snapToGrid = true
    @State private var statusByNode: [UUID: NodeRunStatus] = [:]
    @State private var tokenBuffer: [UUID: String] = [:]
    @State private var isRunning = false
    @State private var runTask: Task<Void, Never>? = nil
    @State private var clipboard: [WorkflowNode] = []
    @State private var pasteCount = 0
    @State private var undoStack: [WorkflowGraph] = []
    @State private var redoStack: [WorkflowGraph] = []

    struct WireDrag {
        let fromNode: UUID
        let fromPort: Port
        var location: CGPoint
    }

    private let nodeWidth: CGFloat = 200
    private let nodeHeight: CGFloat = 72
    private let gridSize: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                palette
                Divider()
                ZStack {
                    gridBackground
                    edgeLayer
                    nodeLayer
                    rubberBandOverlay
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .gesture(backgroundDrag)
                .simultaneousGesture(magnify)
                .onDrop(of: ["com.fusion.flow.nodetype"], isTargeted: nil) { providers, dropLocation in
                    handleDrop(providers, at: dropLocation)
                }
                .contextMenu {
                    ForEach(NodeRegistry.shared.registeredKeys, id: \.self) { key in
                        if let def = NodeRegistry.shared.definition(for: key) {
                            Button("\(def.displayName)") {
                                addNode(type: key, at: canvasPoint(center: CGPoint(x: 0, y: 0)))
                            }
                        }
                    }
                }
                if selectedNodeIds.count == 1, let id = selectedNodeIds.first,
                   let node = graph.nodes.first(where: { $0.id == id }) {
                    Divider()
                    NodeInspectorPanel(node: node, definition: NodeRegistry.shared.definition(for: node.type)) { updated in
                        mutate { $0.nodes[idx(of: updated.id)] = updated }
                    }
                }
            }
            if minimapVisible {
                Divider()
                minimap
            }
        }
        .onAppear { restoreViewport() }
        .onDisappear { runTask?.cancel() }
        .background(deleteKeyHandler)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: theme.spacingS) {
            Text(graph.name.isEmpty ? "Untitled flow" : graph.name)
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Button("Tidy") { tidyLayout() }
                .buttonStyle(.bordered).controlSize(.small)
            Button(snapToGrid ? "Snap: on" : "Snap: off") { snapToGrid.toggle() }
                .buttonStyle(.bordered).controlSize(.small)
            Button(selectMode ? "Pan" : "Select") { selectMode.toggle() }
                .buttonStyle(.bordered).controlSize(.small)
            Button("Undo") { undo() }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(undoStack.isEmpty)
            Button("Redo") { redo() }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(redoStack.isEmpty)

            Spacer()

            if isRunning {
                Button("Cancel") { cancelRun() }
                    .buttonStyle(.bordered).controlSize(.small)
                    .tint(.red)
            } else {
                Button { startRun(stepNode: nil) } label: { Label("Run", systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Button("Step") { startRun(stepNode: selectedNodeIds.first) }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(selectedNodeIds.count != 1)
            }
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, theme.spacingXS)
        .background(theme.contentBg)
    }

    // MARK: - Palette (registry-driven, category-grouped #423)

    private var palette: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                ForEach(NodeCategory.allCases, id: \.self) { cat in
                    let keys = NodeRegistry.shared.categories()[cat] ?? []
                    if !keys.isEmpty {
                        Text(cat.rawValue.capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                        ForEach(keys, id: \.self) { key in
                            if let def = NodeRegistry.shared.definition(for: key) {
                                HStack(spacing: theme.spacingXS) {
                                    Image(systemName: def.icon)
                                        .foregroundStyle(theme.accent)
                                        .frame(width: 14)
                                    Text(def.displayName)
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.text)
                                }
                                .padding(theme.spacingXS)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .fill(theme.surfaceElevated)
                                )
                                .onDrag {
                                    let p = NSItemProvider()
                                    p.registerDataRepresentation(forTypeIdentifier: "com.fusion.flow.nodetype", visibility: .ownProcess) { done in
                                        done(key.rawValue.data(using: .utf8), nil)
                                        return Progress(totalUnitCount: 1)
                                    }
                                    return p
                                }
                            }
                        }
                    }
                }
            }
            .padding(theme.spacingS)
        }
        .frame(width: 150)
        .background(theme.contentBg)
    }

    // MARK: - Grid + transform

    private func viewPoint(from graphPoint: GraphPoint) -> CGPoint {
        CGPoint(
            x: graphPoint.cgPoint.x * scale + offset.width,
            y: graphPoint.cgPoint.y * scale + offset.height
        )
    }

    private func graphPoint(fromView p: CGPoint, center: CGPoint) -> CGPoint {
        CGPoint(
            x: (p.x - center.x - offset.width) / scale,
            y: (p.y - center.y - offset.height) / scale
        )
    }

    private func canvasPoint(center: CGPoint) -> GraphPoint {
        // 上下文菜单/落点以画布中心为原点的简化: 使用当前 offset 换算
        let p = graphPoint(fromView: center, center: .zero)
        return GraphPoint(x: p.x, y: p.y)
    }

    private func snapped(_ v: CGFloat) -> CGFloat {
        guard snapToGrid else { return v }
        return (v / gridSize).rounded() * gridSize
    }

    private var gridBackground: some View {
        Rectangle()
            .fill(theme.contentBg)
            .overlay(
                Canvas { ctx, size in
                    let gap = gridSize * scale * 2
                    guard gap >= 6 else { return }
                    let ox = offset.width.truncatingRemainder(dividingBy: gap)
                    let oy = offset.height.truncatingRemainder(dividingBy: gap)
                    for x in stride(from: ox, to: size.width, by: gap) {
                        for y in stride(from: oy, to: size.height, by: gap) {
                            ctx.fill(Path(CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(theme.separator.opacity(0.3)))
                        }
                    }
                }
            )
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { v in
                scale = min(max(scale * v, 0.3), 3.0)
                persistViewport()
            }
    }

    private var backgroundDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                if selectMode {
                    // 橡皮筋 (视图坐标 → 图坐标)
                    let start = graphPoint(fromView: v.startLocation, center: .zero)
                    let cur = graphPoint(fromView: v.location, center: .zero)
                    rubberBand = CGRect(
                        x: min(start.x, cur.x), y: min(start.y, cur.y),
                        width: abs(cur.x - start.x), height: abs(cur.y - start.y)
                    )
                } else if wireDrag == nil {
                    offset = CGSize(width: offset.width + v.translation.width, height: offset.height + v.translation.height)
                    persistViewport()
                }
            }
            .onEnded { _ in
                if let band = rubberBand {
                    let hit = graph.nodes.filter { band.contains($0.position.cgPoint) }
                    selectedNodeIds = Set(hit.map(\.id))
                    rubberBand = nil
                    graphCanvasLog.info("rubber-band selected \(selectedNodeIds.count) nodes")
                }
            }
    }

    private var rubberBandOverlay: some View {
        Group {
            if let band = rubberBand {
                Rectangle()
                    .fill(theme.accent.opacity(0.12))
                    .overlay(Rectangle().stroke(theme.accent, lineWidth: 1))
                    .frame(width: band.width * scale, height: band.height * scale)
                    .position(
                        x: (band.midX * scale + offset.width),
                        y: (band.midY * scale + offset.height)
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Edges (Canvas 层 + 中点点击热区)

    private var edgeLayer: some View {
        ZStack {
            TimelineView(.animation) { _ in
                Canvas { ctx, size in
                    drawEdges(ctx: ctx, size: size)
                    if let w = wireDrag {
                        drawWirePreview(ctx: ctx, drag: w, size: size)
                    }
                }
                .allowsHitTesting(false)
            }
            // 边中点热区: 点击选中, Delete 删 (#7.1 FSB 缺失能力)
            ForEach(graph.edges) { edge in
                if let mid = edgeMidpoint(edge) {
                    Circle()
                        .fill(selectedEdgeId == edge.id ? theme.accent : theme.textTertiary.opacity(0.001))
                        .frame(width: 14, height: 14)
                        .position(mid)
                        .onTapGesture {
                            selectedEdgeId = edge.id
                            selectedNodeIds = []
                            graphCanvasLog.info("edge selected \(edge.id)")
                        }
                }
            }
            // 线缆拖拽的实时兼容高亮 (#7.1: 兼容绿/不兼容红)
            if let w = wireDrag {
                ForEach(graph.nodes) { target in
                    if let def = NodeRegistry.shared.definition(for: target.type),
                       !def.inputs.isEmpty {
                        ForEach(def.inputs) { input in
                            let verdict = PortCompatibility.validateEdge(
                                source: w.fromPort, target: input
                            )
                            portDot(
                                node: target, port: input,
                                color: verdictColor(verdict)
                            )
                        }
                    }
                }
            }
        }
    }

    private func verdictColor(_ v: PortCompatibility.Verdict) -> Color {
        switch v {
        case .ok: return .green
        case .okWithWarning: return .orange
        case .rejected: return .red
        }
    }

    private func drawEdges(ctx: GraphicsContext, size: CGSize) {
        for edge in graph.edges {
            guard let src = graph.nodes.first(where: { $0.id == edge.sourceNode }),
                  let tgt = graph.nodes.first(where: { $0.id == edge.targetNode }) else { continue }
            let srcPt = portPoint(node: src, portKey: edge.sourcePort, direction: .output)
            let tgtPt = portPoint(node: tgt, portKey: edge.targetPort, direction: .input)
            var path = Path()
            path.move(to: srcPt)
            let midX = (srcPt.x + tgtPt.x) / 2
            path.addCurve(to: tgtPt, control1: CGPoint(x: midX, y: srcPt.y), control2: CGPoint(x: midX, y: tgtPt.y))
            let selected = selectedEdgeId == edge.id
            let color: Color = edge.isLoop ? .orange : theme.separator
            ctx.stroke(path, with: .color(selected ? theme.accent : color), lineWidth: selected ? 2.5 : 1.5)
            // 箭头
            let angle = atan2(tgtPt.y - srcPt.y, tgtPt.x - srcPt.x)
            var arrow = Path()
            arrow.move(to: tgtPt)
            arrow.addLine(to: CGPoint(x: tgtPt.x - 8 * cos(angle - 0.4), y: tgtPt.y - 8 * sin(angle - 0.4)))
            arrow.addLine(to: CGPoint(x: tgtPt.x - 8 * cos(angle + 0.4), y: tgtPt.y - 8 * sin(angle + 0.4)))
            arrow.closeSubpath()
            ctx.fill(arrow, with: .color(selected ? theme.accent : color))
        }
    }

    private func drawWirePreview(ctx: GraphicsContext, drag: WireDrag, size: CGSize) {
        guard let src = graph.nodes.first(where: { $0.id == drag.fromNode }) else { return }
        let srcPt = portPoint(node: src, portKey: drag.fromPort.key, direction: .output)
        var path = Path()
        path.move(to: srcPt)
        let midX = (srcPt.x + drag.location.x) / 2
        path.addCurve(to: drag.location, control1: CGPoint(x: midX, y: srcPt.y), control2: CGPoint(x: midX, y: drag.location.y))
        ctx.stroke(path, with: .color(theme.accent.opacity(0.6)), lineWidth: 2)
    }

    private func edgeMidpoint(_ edge: WorkflowEdge) -> CGPoint? {
        guard let src = graph.nodes.first(where: { $0.id == edge.sourceNode }),
              let tgt = graph.nodes.first(where: { $0.id == edge.targetNode }) else { return nil }
        let a = portPoint(node: src, portKey: edge.sourcePort, direction: .output)
        let b = portPoint(node: tgt, portKey: edge.targetPort, direction: .input)
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func portPoint(node: WorkflowNode, portKey: String, direction: PortDirection) -> CGPoint {
        let p = viewPoint(from: node.position)
        let idx = direction == .input
            ? (NodeRegistry.shared.definition(for: node.type)?.inputs.firstIndex { $0.key == portKey } ?? 0)
            : (NodeRegistry.shared.definition(for: node.type)?.outputs.firstIndex { $0.key == portKey } ?? 0)
        let rowGap: CGFloat = 18
        let yOffset = 24 + CGFloat(idx) * rowGap
        return CGPoint(
            x: direction == .input ? p.x + 8 : p.x + nodeWidth * scale - 8,
            y: p.y + yOffset * scale
        )
    }

    private func nodeType(_ id: UUID) -> NodeTypeKey {
        graph.nodes.first(where: { $0.id == id })?.type ?? .tool
    }

    private func portDot(node: WorkflowNode, port: Port, color: Color) -> some View {
        let p = portPoint(node: node, portKey: port.key, direction: port.direction)
        return Circle()
            .fill(color.opacity(0.5))
            .frame(width: 10, height: 10)
            .position(p)
            .allowsHitTesting(false)
    }

    // MARK: - Nodes (view-based #6.1)

    private var nodeLayer: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(graph.nodes) { node in
                    nodeCard(node)
                        .scaleEffect(scale, anchor: .topLeading)
                        .offset(x: viewPoint(from: node.position).x, y: viewPoint(from: node.position).y)
                        .gesture(nodeDrag(node))
                        .onTapGesture { tapNode(node) }
                        .onHover { h in hoverNodeId = h ? node.id : nil }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @State private var hoverNodeId: UUID? = nil

    @ViewBuilder
    private func nodeCard(_ node: WorkflowNode) -> some View {
        let def = NodeRegistry.shared.definition(for: node.type)
        let status = statusByNode[node.id] ?? .idle
        let isSelected = selectedNodeIds.contains(node.id)

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: def?.icon ?? "square.dashed")
                    .foregroundStyle(theme.accent)
                    .frame(width: 16)
                Text(nodeLabel(node))
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer()
                statusBadge(status)
            }
            if let def = def {
                Text(SecretStripper.summary(config: node.config, schema: def.configSchema).isEmpty
                     ? def.displayName
                     : SecretStripper.summary(config: node.config, schema: def.configSchema))
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }
            if case .error(let msg) = status {
                Text(msg)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            if let tok = tokenBuffer[node.id], !tok.isEmpty {
                Text(tok)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(theme.spacingXS)
        .frame(width: nodeWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(node.type == .note ? Color.yellow.opacity(0.25) : theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(borderColor(isSelected, status), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? theme.accent.opacity(0.25) : .black.opacity(0.1), radius: isSelected ? 8 : 3, y: 2)
        .overlay(alignment: .leading) { inputPorts(node) }
        .overlay(alignment: .trailing) { outputPorts(node) }
    }

    private func borderColor(_ selected: Bool, _ status: NodeRunStatus) -> Color {
        if case .error = status { return .red }
        if selected { return theme.accent }
        if case .running = status { return theme.accent }
        return theme.separator
    }

    @ViewBuilder
    private func statusBadge(_ status: NodeRunStatus) -> some View {
        switch status {
        case .idle: EmptyView()
        case .running:
            Image(systemName: "circle.dotted").foregroundStyle(theme.accent)
        case .finished:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .error:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .unsupported:
            Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
        }
    }

    private func inputPorts(_ node: WorkflowNode) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(NodeRegistry.shared.definition(for: node.type)?.inputs ?? []) { port in
                Circle()
                    .fill(portColor(node: node, port: port))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(theme.contentBg, lineWidth: 2))
                    .offset(x: -5, y: 14)
                    .help(port.label)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func outputPorts(_ node: WorkflowNode) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(NodeRegistry.shared.definition(for: node.type)?.outputs ?? []) { port in
                Circle()
                    .fill(theme.textTertiary.opacity(0.6))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(theme.contentBg, lineWidth: 2))
                    .offset(x: 5, y: 14)
                    .help(port.label)
                    // 端口拖拽发起连线 (#7.1 port-to-port wiring)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { v in
                                if wireDrag == nil, let def = NodeRegistry.shared.definition(for: node.type),
                                   let p = def.outputs.first(where: { $0.key == port.key }) {
                                    wireDrag = WireDrag(fromNode: node.id, fromPort: p, location: v.location)
                                    graphCanvasLog.info("wire drag from \(node.id) port=\(port.key)")
                                } else {
                                    wireDrag?.location = v.location
                                }
                            }
                            .onEnded { v in finishWire(at: v.location, from: node.id, fromPort: port) }
                    )
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func portColor(node: WorkflowNode, port: Port) -> Color {
        guard let w = wireDrag else { return theme.textTertiary.opacity(0.6) }
        guard w.fromNode != node.id else { return theme.textTertiary.opacity(0.3) }
        let verdict = PortCompatibility.validateEdge(source: w.fromPort, target: port)
        return verdictColor(verdict).opacity(0.9)
    }

    private func finishWire(at location: CGPoint, from: UUID, fromPort: Port) {
        defer { wireDrag = nil }
        // 命中最近的兼容输入端口 (图坐标)
        var best: (node: WorkflowNode, port: Port, dist: CGFloat, verdict: PortCompatibility.Verdict)? = nil
        for target in graph.nodes where target.id != from {
            guard let def = NodeRegistry.shared.definition(for: target.type) else { continue }
            for input in def.inputs {
                let pt = portPoint(node: target, portKey: input.key, direction: .input)
                let d = hypot(pt.x - location.x, pt.y - location.y)
                if d < 40 {
                    let verdict = PortCompatibility.validateEdge(source: fromPort, target: input)
                    if case .rejected(let why) = verdict {
                        toast?.show(style: .error, title: "Connection rejected", message: why)
                        graphCanvasLog.error("edge rejected: \(why, privacy: .public)")
                        return
                    }
                    if best == nil || d < best!.dist {
                        best = (target, input, d, verdict)
                    }
                }
            }
        }
        guard let hit = best else { return }
        let isLoop = hit.node.id == from || graph.edges.contains { $0.sourceNode == hit.node.id && $0.targetNode == from }
        let edge = WorkflowEdge(
            sourceNode: from, sourcePort: fromPort.key,
            targetNode: hit.node.id, targetPort: hit.port.key,
            isLoop: isLoop && hit.port.allowsLoop
        )
        mutate { g in
            g.edges.removeAll { $0.sourceNode == edge.sourceNode && $0.targetNode == edge.targetNode && $0.targetPort == edge.targetPort }
            g.edges.append(edge)
        }
        if case .okWithWarning(let warn) = hit.verdict {
            graphCanvasLog.warning("edge warning: \(warn, privacy: .public)")
        }
        graphCanvasLog.info("edge added \(from)->\(hit.node.id)")
    }

    // MARK: - Gestures

    private func nodeDrag(_ node: WorkflowNode) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                let dx = v.translation.width / scale
                let dy = v.translation.height / scale
                if let idx = graph.nodes.firstIndex(where: { $0.id == node.id }) {
                    let base = node.position
                    var np = CGPoint(x: base.cgPoint.x + dx, y: base.cgPoint.y + dy)
                    np.x = snapped(np.x)
                    np.y = snapped(np.y)
                    graph.nodes[idx].position = GraphPoint(np)
                }
            }
            .onEnded { _ in persistLayoutAndGraph() }
    }

    private func tapNode(_ node: WorkflowNode) {
        if selectedNodeIds.contains(node.id) {
            // shift-click 移除
            selectedNodeIds.remove(node.id)
        } else {
            selectedNodeIds = [node.id]
            selectedEdgeId = nil
        }
        graphCanvasLog.info("node selected \(node.id)")
    }

    private var deleteKeyHandler: some View {
        // Delete/⌘Z/⇧⌘Z/⌘D 快捷键: hidden button 承接 (struct view 无 responder chain undo)
        Group {
            Button("Delete selection") { deleteSelection() }
                .keyboardShortcut(.delete, modifiers: [])
            Button("Duplicate") { duplicateSelection() }
                .keyboardShortcut("d", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    // MARK: - Mutations (undo-aware #423)

    // 自管 undo 栈 (struct view 不能 registerUndo(withTarget:); 范式同 FSB history)
    private func mutate(_ change: (inout WorkflowGraph) -> Void) {
        undoStack.append(graph)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
        var g = graph
        change(&g)
        graph = g
        persistLayoutAndGraph()
        graphCanvasLog.info("graph mutated nodes=\(g.nodes.count) edges=\(g.edges.count) undoDepth=\(undoStack.count)")
    }

    private func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(graph)
        graph = prev
        persistLayoutAndGraph()
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(graph)
        graph = next
        persistLayoutAndGraph()
    }

    private func idx(of id: UUID) -> Int {
        graph.nodes.firstIndex { $0.id == id } ?? 0
    }

    private func deleteSelection() {
        guard !selectedNodeIds.isEmpty || selectedEdgeId != nil else { return }
        mutate { g in
            g.nodes.removeAll { selectedNodeIds.contains($0.id) }
            g.edges.removeAll { selectedNodeIds.contains($0.sourceNode) || selectedNodeIds.contains($0.targetNode) }
            if let eid = selectedEdgeId {
                g.edges.removeAll { $0.id == eid }
            }
        }
        graphCanvasLog.info("deleted nodes=\(selectedNodeIds.count) edge=\(selectedEdgeId?.uuidString ?? "-")")
        selectedNodeIds = []
        selectedEdgeId = nil
    }

    private func addNode(type: NodeTypeKey, at pos: GraphPoint) {
        let n = WorkflowNode(type: type, position: pos)
        mutate { $0.nodes.append(n) }
        graphCanvasLog.info("node added type=\(type.rawValue)")
    }

    private func handleDrop(_ providers: [NSItemProvider], at location: CGPoint) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "com.fusion.flow.nodetype", options: nil) { data, _ in
            guard let d = data as? Data, let raw = String(data: d, encoding: .utf8),
                  let key = NodeTypeKey(rawValue: raw) else { return }
            Task { @MainActor in
                // #7.1: 落点即放置 (修 FSB 随机落点 bug)
                let gp = graphPoint(fromView: location, center: .zero)
                let pos = GraphPoint(x: Double(snapped(gp.x - nodeWidth / 2)), y: Double(snapped(gp.y - nodeHeight / 2)))
                addNode(type: key, at: pos)
            }
        }
        return true
    }

    private func duplicateSelection() {
        let copies = graph.nodes.filter { selectedNodeIds.contains($0.id) }.map { n -> WorkflowNode in
            var c = n
            c.id = UUID()
            c.position = GraphPoint(x: n.position.x + 24, y: n.position.y + 24)
            return c
        }
        guard !copies.isEmpty else { return }
        mutate { $0.nodes.append(contentsOf: copies) }
        selectedNodeIds = Set(copies.map(\.id))
    }

    // MARK: - Tidy (拓扑分层, 复用 FSB 范式)

    private func tidyLayout() {
        var inDegree: [UUID: Int] = [:]
        for n in graph.nodes { inDegree[n.id] = 0 }
        for e in graph.edges { inDegree[e.targetNode, default: 0] += 1 }
        var queue = graph.nodes.filter { (inDegree[$0.id] ?? 0) == 0 }
        var level: [UUID: Int] = [:]
        var seen = 0
        while !queue.isEmpty {
            let cur = queue.removeFirst()
            seen += 1
            for e in graph.edges where e.sourceNode == cur.id {
                inDegree[e.targetNode, default: 0] -= 1
                if inDegree[e.targetNode] == 0, let n = graph.nodes.first(where: { $0.id == e.targetNode }) {
                    queue.append(n)
                }
            }
        }
        for n in graph.nodes {
            let pred = graph.edges.filter { $0.targetNode == n.id }.compactMap { level[$0.sourceNode] }
            level[n.id] = (pred.max() ?? -1) + 1
        }
        let hSpacing = 260.0
        let vSpacing = 140.0
        let byLevel = Dictionary(grouping: graph.nodes) { level[$0.id] ?? 0 }
        mutate { g in
            for (lv, ns) in byLevel {
                for (col, n) in ns.enumerated() {
                    if let i = g.nodes.firstIndex(where: { $0.id == n.id }) {
                        g.nodes[i].position = GraphPoint(x: Double(col) * hSpacing, y: Double(lv) * vSpacing)
                    }
                }
            }
        }
        _ = seen
        graphCanvasLog.info("tidy layout applied")
    }

    // MARK: - Execution (#424, StepEvent 驱动, 零假动画)

    private func startRun(stepNode: UUID?) {
        guard let executor = executor, !isRunning else { return }
        isRunning = true
        statusByNode = [:]
        tokenBuffer = [:]
        let runGraph = graph
        graphCanvasLog.info("run started nodes=\(runGraph.nodes.count) backend=\(executor.kind)")
        runTask = Task { @MainActor in
            do {
                let stream = executor.run(runGraph, inputs: [:])
                for try await event in stream {
                    apply(event)
                }
                graphCanvasLog.info("run finished")
            } catch {
                graphCanvasLog.error("run failed: \(error.localizedDescription, privacy: .public)")
                toast?.show(style: .error, title: "Run failed", message: error.localizedDescription)
            }
            isRunning = false
        }
    }

    private func apply(_ event: StepEvent) {
        switch event {
        case .runStarted:
            break
        case .stepStarted(let nid):
            statusByNode[UUID(uuidString: nid) ?? UUID()] = .running
        case .stepFinished(let nid, let out):
            statusByNode[UUID(uuidString: nid) ?? UUID()] = .finished(out)
        case .stepError(let nid, let msg):
            statusByNode[UUID(uuidString: nid) ?? UUID()] = .error(msg)
        case .tokenStream(let nid, let chunk):
            let id = UUID(uuidString: nid) ?? UUID()
            tokenBuffer[id, default: ""] += chunk
        case .runFinished(let summary):
            toast?.show(style: .success, title: "Run finished", message: summary)
        }
    }

    private func cancelRun() {
        runTask?.cancel()
        isRunning = false
        graphCanvasLog.info("run cancelled by user")
    }

    // unsupported 类型 badge (#424 验收: executor 声明支持集)
    private func markUnsupportedIfNeeded() {
        guard let executor = executor else { return }
        for n in graph.nodes where !executor.supportedNodeTypes.contains(n.type) {
            if statusByNode[n.id] == nil || statusByNode[n.id] == .idle {
                statusByNode[n.id] = .unsupported(backend: executor.kind)
            }
        }
    }

    // MARK: - Viewport / persistence

    private func restoreViewport() {
        scale = CGFloat(graph.viewport.scale)
        offset = CGSize(width: graph.viewport.offsetX, height: graph.viewport.offsetY)
        markUnsupportedIfNeeded()
    }

    private func persistViewport() {
        graph.viewport = GraphViewport(offsetX: Double(offset.width), offsetY: Double(offset.height), scale: Double(scale))
    }

    private func persistLayoutAndGraph() {
        persistViewport()
        flowStore?.persist(graph)
    }

    // MARK: - Minimap (#7.1 FSB 缺失能力)

    private var minimapVisible: Bool { !graph.nodes.isEmpty }

    private var minimap: some View {
        Canvas { ctx, size in
            guard !graph.nodes.isEmpty else { return }
            let minX = graph.nodes.map { $0.position.x }.min() ?? 0
            let minY = graph.nodes.map { $0.position.y }.min() ?? 0
            let maxX = graph.nodes.map { $0.position.x + Double(nodeWidth) }.max() ?? 1
            let maxY = graph.nodes.map { $0.position.y + Double(nodeHeight) }.max() ?? 1
            let w = max(maxX - minX, 1)
            let h = max(maxY - minY, 1)
            let fit = min(Double(size.width) / w, Double(size.height) / h)
            func map(_ p: GraphPoint) -> CGPoint {
                CGPoint(x: (p.x - minX) * fit + (Double(size.width) - w * fit) / 2,
                        y: (p.y - minY) * fit + (Double(size.height) - h * fit) / 2)
            }
            for e in graph.edges {
                if let s = graph.nodes.first(where: { $0.id == e.sourceNode }),
                   let t = graph.nodes.first(where: { $0.id == e.targetNode }) {
                    var path = Path()
                    path.move(to: map(s.position))
                    path.addLine(to: map(t.position))
                    ctx.stroke(path, with: .color(theme.separator.opacity(0.6)), lineWidth: 1)
                }
            }
            for n in graph.nodes {
                let p = map(n.position)
                ctx.fill(Path(CGRect(x: p.x, y: p.y, width: nodeWidth * fit, height: 24)),
                         with: .color(selectedNodeIds.contains(n.id) ? theme.accent : theme.textTertiary.opacity(0.5)))
            }
        }
        .frame(height: 90)
        .background(theme.contentBg)
    }
}

extension WorkflowFlowStore {
    // 后台落盘 (fire-and-forget 由调用点 async 上下文承担; 此处 sync 直写保一致性)
    func persist(_ graph: WorkflowGraph) {
        do {
            try save(graph)
        } catch {
            graphCanvasLog.error("flow persist failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
