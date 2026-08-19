import SwiftUI
import os.log

private let wfLog = Logger(subsystem: "com.fusion.studio", category: "FSB.WorkflowCanvas")

struct FSBWorkflowCanvasView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var ipc: IPCClient
    @StateObject private var i18n = I18nManager.shared

    let workspaceId: String
    let workflowId: String?
    let onSave: () -> Void

    @State private var workflowName = ""
    @State private var workflowDesc = ""
    @State private var slashCommand = ""
    @State private var enabled = true
    @State private var nodes: [FSBGraphNode] = []
    @State private var edges: [FSBGraphEdge] = []
    @State private var selectedNodeId: String? = nil
    @State private var hoveredNodeId: String? = nil
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var connectingFrom: String? = nil
    @State private var mousePos: CGPoint = .zero
    @State private var connectors: [[String: Any]] = []
    @State private var skills: [[String: Any]] = []
    @State private var isSaving = false
    @State private var showAddNode = false
    @State private var addNodePos: CGPoint = .zero
    @State private var isRunning = false
    @State private var runningNodeId: String? = nil

    enum FSBNodeType: String, CaseIterable {
        case START_NODE = "START_NODE"
        case CONNECTOR_NODE = "CONNECTOR_NODE"
        case SKILL_NODE = "SKILL_NODE"
        case CONDITION_NODE = "CONDITION_NODE"
        case APPROVAL_GATE_NODE = "APPROVAL_GATE_NODE"
        case OUTPUT_NODE = "OUTPUT_NODE"
        case END_NODE = "END_NODE"

        var icon: String {
            switch self {
            case .START_NODE: return "play.circle.fill"
            case .CONNECTOR_NODE: return "plug"
            case .SKILL_NODE: return "wand.and.stars"
            case .CONDITION_NODE: return "arrow.triangle.branch"
            case .APPROVAL_GATE_NODE: return "hand.raised"
            case .OUTPUT_NODE: return "arrow.up.doc"
            case .END_NODE: return "stop.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .START_NODE: return .green
            case .CONNECTOR_NODE: return .cyan
            case .SKILL_NODE: return .purple
            case .CONDITION_NODE: return .orange
            case .APPROVAL_GATE_NODE: return .yellow
            case .OUTPUT_NODE: return .blue
            case .END_NODE: return .red
            }
        }

        var displayName: String {
            switch self {
            case .START_NODE: return I18nManager.shared.t(.fsb_cv_node_start)
            case .CONNECTOR_NODE: return I18nManager.shared.t(.fsb_cv_node_connector)
            case .SKILL_NODE: return I18nManager.shared.t(.fsb_cv_node_skill)
            case .CONDITION_NODE: return I18nManager.shared.t(.fsb_cv_node_condition)
            case .APPROVAL_GATE_NODE: return I18nManager.shared.t(.fsb_cv_node_approval)
            case .OUTPUT_NODE: return I18nManager.shared.t(.fsb_cv_node_output)
            case .END_NODE: return I18nManager.shared.t(.fsb_cv_node_end)
            }
        }
    }

    struct FSBGraphNode: Identifiable {
        let id: String
        var type: FSBNodeType
        var label: String
        var position: CGPoint
        var config: [String: Any]

        init(id: String = "n_\(UUID().uuidString.prefix(8))", type: FSBNodeType, label: String, position: CGPoint, config: [String: Any] = [:]) {
            self.id = id
            self.type = type
            self.label = label
            self.position = position
            self.config = config
        }
    }

    struct FSBGraphEdge: Identifiable {
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
        .onAppear { loadWorkflow() }
        .sheet(isPresented: $showAddNode) {
            addNodeSheet
        }
    }

    // MARK: - Toolbar

    private var canvasToolbar: some View {
        HStack(spacing: theme.spacingM) {
            HStack(spacing: theme.spacingXS) {
                TextField(i18n.t(.fsb_cv_wfName), text: $workflowName)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .frame(width: 180)
                if !slashCommand.isEmpty {
                    Text("/\(slashCommand)")
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.accentSecondary)
                        .padding(.horizontal, theme.spacingXS)
                        .padding(.vertical, 2)
                        .background(theme.accentSoft)
                        .cornerRadius(4)
                }
            }

            Spacer()

            HStack(spacing: theme.spacingS) {
                Button(action: { autoLayout() }) {
                    Label(i18n.t(.fsb_cv_autoLayout), systemImage: "rectangle.grid.3x3")
                        .font(.system(size: theme.captionSize))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { runTest() }) {
                    Label(isRunning ? i18n.t(.fsb_cv_running) : i18n.t(.fsb_cv_testRun), systemImage: isRunning ? "arrow.trianglehead.2.clockwise" : "play")
                        .font(.system(size: theme.captionSize))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isRunning)

                Button(action: { saveWorkflow() }) {
                    Label(isSaving ? i18n.t(.fsb_cv_saving) : i18n.t(.save), systemImage: "square.and.arrow.down")
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
            Text(i18n.t(.fsb_cv_nodeTypes))
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(theme.spacingS)

            ForEach(FSBNodeType.allCases, id: \.self) { type in
                nodePaletteItem(type: type)
            }
            .padding(.horizontal, theme.spacingS)

            Spacer()

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(i18n.t(.fsb_cv_hintDrag))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                Text(i18n.t(.fsb_cv_hintRightClick))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                Text(i18n.t(.fsb_cv_hintConnect))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingS)
        }
        .frame(width: 160)
        .background(theme.contentBg)
    }

    @ViewBuilder
    private func nodePaletteItem(type: FSBNodeType) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)
                .frame(width: 16)
            Text(type.displayName)
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
            provider.registerDataRepresentation(forTypeIdentifier: "com.fusion.fsb.node", visibility: .ownProcess) { completion in
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
        .onDrop(of: ["com.fusion.fsb.node"], isTargeted: nil) { providers in
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

            let isActive = runningNodeId == src.id || runningNodeId == tgt.id
            let edgeColor = isActive ? theme.accent : theme.separator
            ctx.stroke(path, with: .color(edgeColor), lineWidth: isActive ? 2.5 : 1.5)

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
                    fsbNodeCard(node: node)
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
    private func fsbNodeCard(node: FSBGraphNode) -> some View {
        let isSelected = selectedNodeId == node.id
        let isHovered = hoveredNodeId == node.id
        let isRunningNode = runningNodeId == node.id

        HStack(spacing: theme.spacingS) {
            outputPort(node: node)
            Image(systemName: node.type.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isRunningNode ? .white : node.type.color)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isRunningNode ? theme.accent : node.type.color.opacity(0.15))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(node.label)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(node.type.displayName)
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
                .fill(isRunningNode ? theme.accentSoft : theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(isSelected ? theme.accent : (isHovered ? theme.accent.opacity(0.4) : theme.separator), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? theme.accent.opacity(0.2) : .black.opacity(0.1), radius: isSelected ? 8 : 3, y: 2)
    }

    @ViewBuilder
    private func outputPort(node: FSBGraphNode) -> some View {
        let isConnecting = connectingFrom == node.id
        Circle()
            .fill(isConnecting ? theme.accent : theme.textTertiary.opacity(0.5))
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(theme.contentBg, lineWidth: 2))
            .onTapGesture {
                if connectingFrom == nil {
                    connectingFrom = node.id
                    wfLog.info("connecting from \(node.id)")
                }
            }
    }

    @ViewBuilder
    private func inputPort(node: FSBGraphNode) -> some View {
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
                if let node = nodes.first(where: { $0.id == selectedNodeId }) {
                    HStack {
                        Image(systemName: node.type.icon)
                            .foregroundStyle(node.type.color)
                        Text(node.type.displayName)
                            .font(.system(size: theme.textSize, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Spacer()
                        Button(action: { selectedNodeId = nil }) {
                            Image(systemName: "xmark")
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text(i18n.t(.fsb_ws_name))
                            .font(.system(size: theme.captionSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        TextField(i18n.t(.fsb_cv_nodeName), text: Binding(
                            get: { node.label },
                            set: { v in updateNodeLabel(node.id, label: v) }
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

                    if node.type == .CONNECTOR_NODE {
                        connectorConfigSection(node: node)
                    } else if node.type == .SKILL_NODE {
                        skillConfigSection(node: node)
                    } else if node.type == .CONDITION_NODE {
                        conditionConfigSection(node: node)
                    } else if node.type == .APPROVAL_GATE_NODE {
                        approvalConfigSection(node: node)
                    } else if node.type == .OUTPUT_NODE {
                        outputConfigSection(node: node)
                    }

                    Divider()

                    Button(role: .destructive, action: { deleteNode(node.id) }) {
                        Label(i18n.t(.fsb_cv_deleteNode), systemImage: "trash")
                            .font(.system(size: theme.captionSize))
                    }
                    .controlSize(.small)
                }
            }
            .padding(theme.spacingM)
        }
        .frame(width: 260)
        .background(theme.contentBg)
    }

    @ViewBuilder
    private func connectorConfigSection(node: FSBGraphNode) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.fsb_cv_connector))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            let currentKey = node.config["connectorKey"] as? String ?? ""
            Picker(i18n.t(.fsb_cv_selectConnector), selection: Binding(
                get: { currentKey },
                set: { v in updateNodeConfig(node.id, key: "connectorKey", value: v) }
            )) {
                Text(i18n.t(.fsb_cv_notSelected)).tag("")
                ForEach(connectors.indices, id: \.self) { idx in
                    let key = connectors[idx]["connectorKey"] as? String ?? ""
                    Text(key).tag(key)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(i18n.t(.fsb_cv_action))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                TextField("action key", text: Binding(
                    get: { node.config["actionKey"] as? String ?? "" },
                    set: { v in updateNodeConfig(node.id, key: "actionKey", value: v) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: theme.captionSize, design: .monospaced))
                .padding(theme.spacingXS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
            }
        }
    }

    @ViewBuilder
    private func skillConfigSection(node: FSBGraphNode) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.fsb_cv_skill))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            let currentSkillId = node.config["skillId"] as? String ?? ""
            Picker(i18n.t(.fsb_cv_selectSkill), selection: Binding(
                get: { currentSkillId },
                set: { v in updateNodeConfig(node.id, key: "skillId", value: v) }
            )) {
                Text(i18n.t(.fsb_cv_notSelected)).tag("")
                ForEach(skills.indices, id: \.self) { idx in
                    let sid = skills[idx]["skillId"] as? String ?? ""
                    let name = skills[idx]["displayName"] as? String ?? skills[idx]["name"] as? String ?? sid
                    Text(name).tag(sid)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(i18n.t(.fsb_cv_promptTpl))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                TextEditor(text: Binding(
                    get: { node.config["promptTemplate"] as? String ?? "" },
                    set: { v in updateNodeConfig(node.id, key: "promptTemplate", value: v) }
                ))
                .font(.system(size: theme.captionSize, design: .monospaced))
                .frame(height: 80)
                .padding(theme.spacingXS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
            }
        }
    }

    @ViewBuilder
    private func conditionConfigSection(node: FSBGraphNode) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.fsb_cv_conditionExpr))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            TextEditor(text: Binding(
                get: { node.config["expression"] as? String ?? "" },
                set: { v in updateNodeConfig(node.id, key: "expression", value: v) }
            ))
            .font(.system(size: theme.captionSize, design: .monospaced))
            .frame(height: 60)
            .padding(theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.surfaceElevated)
            )

            Text(i18n.t(.fsb_cv_conditionHint))
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
        }
    }

    @ViewBuilder
    private func approvalConfigSection(node: FSBGraphNode) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.fsb_cv_approvalConfig))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            let mode = node.config["approvalMode"] as? String ?? "write_only"
            Picker(i18n.t(.fsb_cv_approvalMode), selection: Binding(
                get: { mode },
                set: { v in updateNodeConfig(node.id, key: "approvalMode", value: v) }
            )) {
                Text(i18n.t(.fsb_cv_writeOnly)).tag("write_only")
                Text(i18n.t(.fsb_cv_allOps)).tag("all")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(i18n.t(.fsb_cv_approvalNote))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                TextEditor(text: Binding(
                    get: { node.config["approvalMessage"] as? String ?? "" },
                    set: { v in updateNodeConfig(node.id, key: "approvalMessage", value: v) }
                ))
                .font(.system(size: theme.captionSize))
                .frame(height: 60)
                .padding(theme.spacingXS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
            }

            let timeout = node.config["timeoutSeconds"] as? Int ?? 3600
            Stepper(String(format: i18n.t(.fsb_cv_timeoutFmt), timeout), value: Binding(
                get: { timeout },
                set: { v in updateNodeConfig(node.id, key: "timeoutSeconds", value: v) }
            ), in: 60...86400, step: 60)
            .font(.system(size: theme.captionSize))
        }
    }

    @ViewBuilder
    private func outputConfigSection(node: FSBGraphNode) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.fsb_cv_outputFormat))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            let fmt = node.config["outputFormat"] as? String ?? "text"
            Picker(i18n.t(.fsb_cv_format), selection: Binding(
                get: { fmt },
                set: { v in updateNodeConfig(node.id, key: "outputFormat", value: v) }
            )) {
                Text(i18n.t(.fsb_cv_plainText)).tag("text")
                Text("JSON").tag("json")
                Text("Markdown").tag("markdown")
                Text("CSV").tag("csv")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Add Node Sheet

    private var addNodeSheet: some View {
        VStack(spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.fsb_cv_addNode))
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(i18n.t(.close)) { showAddNode = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textTertiary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingS) {
                ForEach(FSBNodeType.allCases, id: \.self) { type in
                    Button(action: {
                        addNodeAtPos(type: type, pos: addNodePos)
                        showAddNode = false
                    }) {
                        HStack(spacing: theme.spacingS) {
                            Image(systemName: type.icon)
                                .foregroundStyle(type.color)
                            Text(type.displayName)
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
        ForEach(FSBNodeType.allCases, id: \.self) { type in
            Button {
                addNodeAtPos(type: type, pos: CGPoint(
                    x: CGFloat.random(in: -200...200),
                    y: CGFloat.random(in: -150...150)
                ))
            } label: {
                Label(type.displayName, systemImage: type.icon)
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

    private func nodeDragGesture(node: FSBGraphNode) -> some Gesture {
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
    }

    // MARK: - Node Operations

    private func selectNode(_ id: String) {
        selectedNodeId = id
        wfLog.info("selected node: \(id)")
    }

    private func addNodeAtPos(type: FSBNodeType, pos: CGPoint) {
        let node = FSBGraphNode(type: type, label: type.displayName, position: pos)
        nodes.append(node)
        wfLog.info("added node: \(node.id) type=\(type.rawValue)")
    }

    private func deleteNode(_ id: String) {
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.sourceId == id || $0.targetId == id }
        if selectedNodeId == id { selectedNodeId = nil }
        wfLog.info("deleted node: \(id)")
    }

    private func addEdge(from: String, to: String) {
        let exists = edges.contains { $0.sourceId == from && $0.targetId == to }
        guard !exists else { return }
        let edge = FSBGraphEdge(sourceId: from, targetId: to)
        edges.append(edge)
        wfLog.info("added edge: \(from) -> \(to)")
    }

    private func updateNodeLabel(_ id: String, label: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].label = label
    }

    private func updateNodeConfig(_ id: String, key: String, value: Any) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].config[key] = value
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
            for (col, var node) in levelNodes.enumerated() {
                let newPos = CGPoint(x: startX + CGFloat(col) * hSpacing, y: CGFloat(level) * vSpacing)
                if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
                    nodes[idx].position = newPos
                }
            }
        }
        canvasOffset = .zero
        canvasScale = 1.0
        wfLog.info("auto-layout applied")
    }

    private func topologicalSort() -> [FSBGraphNode] {
        var inDegree: [String: Int] = [:]
        for node in nodes { inDegree[node.id] = 0 }
        for edge in edges { inDegree[edge.targetId, default: 0] += 1 }

        var queue = nodes.filter { (inDegree[$0.id] ?? 0) == 0 }
        var result: [FSBGraphNode] = []

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

    // MARK: - Data

    private func loadWorkflow() {
        Task {
            async let connResult = ipc.fsbListConnectors(wsId: workspaceId)
            async let skillResult = ipc.fsbListSkills(wsId: workspaceId)

            do {
                let conns = try await connResult
                let sks = try await skillResult
                await MainActor.run {
                    connectors = conns
                    skills = sks
                }
            } catch {
                wfLog.error("load connectors/skills failed: \(error.localizedDescription)")
            }

            guard let wfId = workflowId else {
                await MainActor.run {
                    workflowName = I18nManager.shared.t(.fsb_cv_newWorkflow)
                    let startNode = FSBGraphNode(type: .START_NODE, label: I18nManager.shared.t(.fsb_cv_node_start), position: CGPoint(x: 0, y: 0))
                    let endNode = FSBGraphNode(type: .END_NODE, label: I18nManager.shared.t(.fsb_cv_node_end), position: CGPoint(x: 300, y: 0))
                    nodes = [startNode, endNode]
                    edges = []
                }
                return
            }

            do {
                let wf = try await ipc.fsbGetWorkflow(wsId: workspaceId, wfId: wfId)
                await MainActor.run {
                    workflowName = wf["displayName"] as? String ?? wf["name"] as? String ?? ""
                    workflowDesc = wf["description"] as? String ?? ""
                    slashCommand = wf["slashCommand"] as? String ?? ""
                    enabled = wf["enabled"] as? Bool ?? true

                    if let graph = wf["graphDefinition"] as? [String: Any] {
                        let graphNodes = graph["nodes"] as? [[String: Any]] ?? []
                        let graphEdges = graph["edges"] as? [[String: Any]] ?? []
                        nodes = graphNodes.map { n in
                            FSBGraphNode(
                                id: n["id"] as? String ?? UUID().uuidString,
                                type: FSBNodeType(rawValue: n["type"] as? String ?? "SKILL_NODE") ?? .SKILL_NODE,
                                label: (n["config"] as? [String: Any])?["label"] as? String ?? I18nManager.shared.t(.fsb_unnamed),
                                position: CGPoint(
                                    x: ((n["config"] as? [String: Any])?["position"] as? [String: Any])?["x"] as? CGFloat ?? CGFloat.random(in: -200...200),
                                    y: ((n["config"] as? [String: Any])?["position"] as? [String: Any])?["y"] as? CGFloat ?? CGFloat.random(in: -100...100)
                                ),
                                config: (n["config"] as? [String: Any]) ?? [:]
                            )
                        }
                        edges = graphEdges.map { e in
                            FSBGraphEdge(
                                id: e["id"] as? String ?? UUID().uuidString,
                                sourceId: e["source"] as? String ?? "",
                                targetId: e["target"] as? String ?? "",
                                condition: e["condition"] as? String
                            )
                        }
                    }
                    autoLayout()
                }
                wfLog.info("loaded workflow: \(wfId)")
            } catch {
                wfLog.error("load workflow failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveWorkflow() {
        isSaving = true
        Task {
            let graphDef: [String: Any] = [
                "nodes": nodes.map { n in
                    [
                        "id": n.id,
                        "type": n.type.rawValue,
                        "config": mergeConfig(n.config, label: n.label, position: n.position)
                    ]
                },
                "edges": edges.map { e in
                    var dict: [String: Any] = [
                        "id": e.id,
                        "source": e.sourceId,
                        "target": e.targetId
                    ]
                    if let c = e.condition { dict["condition"] = c }
                    return dict
                },
                "entryNode": nodes.first(where: { $0.type == .START_NODE })?.id ?? ""
            ]

            do {
                if let wfId = workflowId {
                    _ = try await ipc.fsbUpdateWorkflow(
                        wsId: workspaceId,
                        wfId: wfId,
                        name: workflowName,
                        displayName: workflowName,
                        description: workflowDesc,
                        enabled: enabled,
                        graphDefinition: graphDef
                    )
                    wfLog.info("updated workflow: \(wfId)")
                } else {
                    _ = try await ipc.fsbCreateWorkflow(
                        wsId: workspaceId,
                        name: workflowName.replacingOccurrences(of: " ", with: "_").lowercased(),
                        displayName: workflowName,
                        description: workflowDesc,
                        slashCommand: slashCommand,
                        graphDefinition: graphDef
                    )
                    wfLog.info("created workflow: \(workflowName)")
                }
                await MainActor.run {
                    isSaving = false
                    onSave()
                }
            } catch {
                wfLog.error("save workflow failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func mergeConfig(_ base: [String: Any], label: String, position: CGPoint) -> [String: Any] {
        var result = base
        result["label"] = label
        result["position"] = ["x": Double(position.x), "y": Double(position.y)]
        return result
    }

    private func runTest() {
        isRunning = true
        let sortedNodes = topologicalSort()
        var stepDelay: Double = 0

        for node in sortedNodes {
            let nodeId = node.id
            let delay = stepDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                runningNodeId = nodeId
                wfLog.info("running node: \(nodeId)")
            }
            stepDelay += 0.8
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + stepDelay + 0.3) {
            isRunning = false
            runningNodeId = nil
            wfLog.info("test run complete")
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "com.fusion.fsb.node", options: nil) { data, _ in
            guard let data = data as? Data,
                  let typeStr = String(data: data, encoding: .utf8),
                  let type = FSBNodeType(rawValue: typeStr) else { return }
            DispatchQueue.main.async {
                addNodeAtPos(type: type, pos: CGPoint(
                    x: CGFloat.random(in: -150...150),
                    y: CGFloat.random(in: -100...100)
                ))
            }
        }
    }
}
