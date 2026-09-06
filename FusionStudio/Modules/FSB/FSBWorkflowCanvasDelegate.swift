import SwiftUI
import os.log

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

private let fsbCanvasLog = Logger(subsystem: "com.fusion.studio", category: "FSBCanvasDelegate")

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

@MainActor
final class FSBWorkflowCanvasDelegate: ObservableObject, WorkflowCanvasDelegate {
    typealias NodeType = FSBNodeType

    @Published var connectors: [[String: Any]] = []
    @Published var skills: [[String: Any]] = []
    var ipc: IPCClient
    let workspaceId: String
    var workflowId: String?
    @Published var workflowName: String = ""
    @Published var slashCommand: String = ""

    init(ipc: IPCClient, workspaceId: String, workflowId: String?) {
        self.ipc = ipc
        self.workspaceId = workspaceId
        self.workflowId = workflowId
    }

    var canvasNodeTypes: [FSBNodeType] { FSBNodeType.allCases }
    var supportsTestRun: Bool { true }
    func displayName(_ t: FSBNodeType) -> String { t.displayName }
    func icon(_ t: FSBNodeType) -> String { t.icon }
    func color(_ t: FSBNodeType) -> Color { t.color }
    func defaultLabel(_ t: FSBNodeType) -> String { t.displayName }
    func nodeID() -> String { "n_\(UUID().uuidString.prefix(8))" }
    func edgeID(from: String, to: String) -> String { "e_\(UUID().uuidString.prefix(8))" }

    func toolbarLabel(_ kind: CanvasToolbarLabel) -> String {
        switch kind {
        case .autoLayout: return I18nManager.shared.t(.fsb_cv_autoLayout)
        case .saveLayout: return I18nManager.shared.t(.fsb_cv_saveLayout)
        case .testRun: return I18nManager.shared.t(.fsb_cv_testRun)
        case .running: return I18nManager.shared.t(.fsb_cv_running)
        case .saving: return I18nManager.shared.t(.fsb_cv_saving)
        case .save: return I18nManager.shared.t(.save)
        case .close: return I18nManager.shared.t(.close)
        case .nodeTypes: return I18nManager.shared.t(.fsb_cv_nodeTypes)
        case .hintDrag: return I18nManager.shared.t(.fsb_cv_hintDrag)
        case .hintRightClick: return I18nManager.shared.t(.fsb_cv_hintRightClick)
        case .hintConnect: return I18nManager.shared.t(.fsb_cv_hintConnect)
        case .nodeName: return I18nManager.shared.t(.fsb_cv_nodeName)
        case .deleteNode: return I18nManager.shared.t(.fsb_cv_deleteNode)
        case .inspectorReadOnly: return I18nManager.shared.t(.fsb_cv_inspectorReadOnly)
        case .inspectorEdit: return I18nManager.shared.t(.fsb_cv_inspectorEdit)
        case .wfName: return I18nManager.shared.t(.fsb_cv_wfName)
        case .addNode: return I18nManager.shared.t(.fsb_cv_nodeTypes)
        }
    }

    @ViewBuilder
    func configSection(for node: Binding<CanvasNode<FSBNodeType>>) -> AnyView? {
        switch node.wrappedValue.type {
        case .CONNECTOR_NODE: return AnyView(FSBConnectorSection(node: node, delegate: self))
        case .SKILL_NODE: return AnyView(FSBSkillSection(node: node, delegate: self))
        case .CONDITION_NODE: return AnyView(FSBConditionSection(node: node))
        case .APPROVAL_GATE_NODE: return AnyView(FSBApprovalSection(node: node))
        case .OUTPUT_NODE: return AnyView(FSBOutputSection(node: node))
        default: return nil
        }
    }

    // MARK: - Save / Load / PersistLayout

    nonisolated static func parseNodePosition(node: [String: Any], fallbackIndex: Int) -> CGPoint {
        func pt(_ dict: [String: Any]?) -> CGPoint? {
            guard let dict = dict else { return nil }
            let x = (dict["x"] as? Double) ?? (dict["x"] as? Int).map(Double.init)
            let y = (dict["y"] as? Double) ?? (dict["y"] as? Int).map(Double.init)
            guard let x = x, let y = y, x.isFinite, y.isFinite else { return nil }
            return CGPoint(x: x, y: y)
        }
        if let p = pt(node["position"] as? [String: Any]) {
            return p
        }
        if let cfg = node["config"] as? [String: Any], let p = pt(cfg["position"] as? [String: Any]) {
            return p
        }
        let col = fallbackIndex % 3
        let row = fallbackIndex / 3
        return CGPoint(x: -200 + CGFloat(col) * 220, y: -150 + CGFloat(row) * 120)
    }

    private func toJSONValue(_ v: Any) -> JSONValue? {
        if let v = v as? Bool { return .bool(v) }
        if let v = v as? Double { return .double(v) }
        if let v = v as? Int { return .double(Double(v)) }
        if let v = v as? String { return .string(v) }
        if let v = v as? [String: Any] {
            var dict: [String: JSONValue] = [:]
            for (k, vv) in v { if let jv = toJSONValue(vv) { dict[k] = jv } }
            return .object(dict)
        }
        if let v = v as? [Any] {
            return .array(v.compactMap { toJSONValue($0) })
        }
        return nil
    }

    private func fromJSONValue(_ v: JSONValue) -> Any {
        switch v {
        case .string(let s): return s
        case .double(let d): return d
        case .bool(let b): return b
        case .object(let d): return d.mapValues { fromJSONValue($0) }
        case .array(let a): return a.map { fromJSONValue($0) }
        }
    }

    private func mergeConfig(_ base: [String: JSONValue], label: String, position: CGPoint) -> [String: Any] {
        var result = base.mapValues { fromJSONValue($0) }
        result["label"] = label
        result["position"] = ["x": Double(position.x), "y": Double(position.y)]
        return result
    }

    func load() async throws -> (name: String, nodes: [CanvasNode<FSBNodeType>], edges: [CanvasEdge]) {
        async let connResult = ipc.fsbListConnectors(wsId: workspaceId)
        async let skillResult = ipc.fsbListSkills(wsId: workspaceId)

        do {
            let conns = try await connResult
            let sks = try await skillResult
            self.connectors = conns
            self.skills = sks
        } catch {
            fsbCanvasLog.error("load connectors/skills failed: \(error.localizedDescription)")
        }

        guard let wfId = workflowId else {
            let name = I18nManager.shared.t(.fsb_cv_newWorkflow)
            let startNode = CanvasNode<FSBNodeType>(type: .START_NODE, label: I18nManager.shared.t(.fsb_cv_node_start), position: CGPoint(x: 0, y: 0))
            let endNode = CanvasNode<FSBNodeType>(type: .END_NODE, label: I18nManager.shared.t(.fsb_cv_node_end), position: CGPoint(x: 300, y: 0))
            return (name, [startNode, endNode], [])
        }

        do {
            let wf = try await ipc.fsbGetWorkflow(wsId: workspaceId, wfId: wfId)
            let name = wf["displayName"] as? String ?? wf["name"] as? String ?? ""
            self.workflowName = name
            self.slashCommand = wf["slashCommand"] as? String ?? ""

            var loadedNodes: [CanvasNode<FSBNodeType>] = []
            var loadedEdges: [CanvasEdge] = []

            if let graph = wf["graphDefinition"] as? [String: Any] {
                let graphNodes = graph["nodes"] as? [[String: Any]] ?? []
                let graphEdges = graph["edges"] as? [[String: Any]] ?? []
                for (idx, n) in graphNodes.enumerated() {
                    let rawCfg = (n["config"] as? [String: Any]) ?? [:]
                    let pos = Self.parseNodePosition(node: n, fallbackIndex: idx)
                    let nodeId = n["id"] as? String ?? UUID().uuidString
                    let cfgJSON: [String: JSONValue] = rawCfg.compactMapValues { toJSONValue($0) }
                    let label = rawCfg["label"] as? String ?? I18nManager.shared.t(.fsb_unnamed)
                    loadedNodes.append(CanvasNode<FSBNodeType>(
                        id: nodeId,
                        type: FSBNodeType(rawValue: n["type"] as? String ?? "SKILL_NODE") ?? .SKILL_NODE,
                        label: label,
                        position: pos,
                        config: cfgJSON
                    ))
                }
                loadedEdges = graphEdges.map { e in
                    CanvasEdge(
                        id: e["id"] as? String ?? UUID().uuidString,
                        sourceId: e["source"] as? String ?? "",
                        targetId: e["target"] as? String ?? "",
                        condition: e["condition"] as? String
                    )
                }
            }
            fsbCanvasLog.info("loaded wf=\(wfId, privacy: .public) nodes=\(loadedNodes.count) edges=\(loadedEdges.count)")
            return (name, loadedNodes, loadedEdges)
        } catch {
            fsbCanvasLog.error("load workflow failed: \(error.localizedDescription)")
            throw error
        }
    }

    func save(graphName: String, nodes: [CanvasNode<FSBNodeType>], edges: [CanvasEdge]) async throws {
        let graphDef: [String: Any] = [
            "nodes": nodes.map { n in
                [
                    "id": n.id,
                    "type": n.type.rawValue,
                    "config": mergeConfig(n.config, label: n.label, position: n.position)
                ] as [String: Any]
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

        if let wfId = workflowId {
            _ = try await ipc.fsbUpdateWorkflow(
                wsId: workspaceId,
                wfId: wfId,
                name: graphName,
                displayName: graphName,
                graphDefinition: graphDef
            )
            fsbCanvasLog.info("updated workflow: \(wfId, privacy: .public)")
        } else {
            _ = try await ipc.fsbCreateWorkflow(
                wsId: workspaceId,
                name: graphName.replacingOccurrences(of: " ", with: "_").lowercased(),
                displayName: graphName,
                slashCommand: slashCommand,
                graphDefinition: graphDef
            )
            fsbCanvasLog.info("created workflow: \(graphName, privacy: .public)")
        }
    }

    func persistLayout(_ layout: [String: CGPoint]) async {
        guard let wfId = workflowId, !layout.isEmpty else { return }
        var dict: [String: [String: CGFloat]] = [:]
        for (id, pos) in layout {
            let x = pos.x.isFinite ? pos.x : 0
            let y = pos.y.isFinite ? pos.y : 0
            dict[id] = ["x": x, "y": y]
        }
        do {
            let resp = try await ipc.fsbSaveCanvasLayout(wsId: workspaceId, wfId: wfId, layout: dict)
            let ok = resp["success"] as? Bool ?? false
            if ok {
                fsbCanvasLog.info("canvas-layout saved wf=\(wfId, privacy: .public) nodes=\(dict.count)")
            } else {
                fsbCanvasLog.error("canvas-layout rejected: \(resp, privacy: .public)")
            }
        } catch {
            fsbCanvasLog.error("canvas-layout save failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Inspector Section Views

private struct FSBConnectorSection: View {
    @Binding var node: CanvasNode<FSBNodeType>
    @ObservedObject var delegate: FSBWorkflowCanvasDelegate
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(I18nManager.shared.t(.fsb_cv_connector))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            let currentKey = node.config["connectorKey"]?.stringValue ?? ""
            Picker(I18nManager.shared.t(.fsb_cv_selectConnector), selection: Binding(
                get: { currentKey },
                set: { v in node.config["connectorKey"] = .string(v) }
            )) {
                Text(I18nManager.shared.t(.fsb_cv_notSelected)).tag("")
                ForEach(delegate.connectors.indices, id: \.self) { idx in
                    let key = delegate.connectors[idx]["connectorKey"] as? String ?? ""
                    Text(key).tag(key)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(I18nManager.shared.t(.fsb_cv_action))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                TextField("action key", text: Binding(
                    get: { node.config["actionKey"]?.stringValue ?? "" },
                    set: { v in node.config["actionKey"] = .string(v) }
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
}

private struct FSBSkillSection: View {
    @Binding var node: CanvasNode<FSBNodeType>
    @ObservedObject var delegate: FSBWorkflowCanvasDelegate
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(I18nManager.shared.t(.fsb_cv_skill))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            let currentSkillId = node.config["skillId"]?.stringValue ?? ""
            Picker(I18nManager.shared.t(.fsb_cv_selectSkill), selection: Binding(
                get: { currentSkillId },
                set: { v in node.config["skillId"] = .string(v) }
            )) {
                Text(I18nManager.shared.t(.fsb_cv_notSelected)).tag("")
                ForEach(delegate.skills.indices, id: \.self) { idx in
                    let sid = delegate.skills[idx]["skillId"] as? String ?? ""
                    let name = delegate.skills[idx]["displayName"] as? String ?? delegate.skills[idx]["name"] as? String ?? sid
                    Text(name).tag(sid)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(I18nManager.shared.t(.fsb_cv_promptTpl))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                TextEditor(text: Binding(
                    get: { node.config["promptTemplate"]?.stringValue ?? "" },
                    set: { v in node.config["promptTemplate"] = .string(v) }
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
}

private struct FSBConditionSection: View {
    @Binding var node: CanvasNode<FSBNodeType>
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(I18nManager.shared.t(.fsb_cv_conditionExpr))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
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

            Text(I18nManager.shared.t(.fsb_cv_conditionHint))
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
        }
    }
}

private struct FSBApprovalSection: View {
    @Binding var node: CanvasNode<FSBNodeType>
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(I18nManager.shared.t(.fsb_cv_approvalConfig))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            let mode = node.config["approvalMode"]?.stringValue ?? "write_only"
            Picker(I18nManager.shared.t(.fsb_cv_approvalMode), selection: Binding(
                get: { mode },
                set: { v in node.config["approvalMode"] = .string(v) }
            )) {
                Text(I18nManager.shared.t(.fsb_cv_writeOnly)).tag("write_only")
                Text(I18nManager.shared.t(.fsb_cv_allOps)).tag("all")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(I18nManager.shared.t(.fsb_cv_approvalNote))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                TextEditor(text: Binding(
                    get: { node.config["approvalMessage"]?.stringValue ?? "" },
                    set: { v in node.config["approvalMessage"] = .string(v) }
                ))
                .font(.system(size: theme.captionSize))
                .frame(height: 60)
                .padding(theme.spacingXS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
            }

            let timeout = Int(node.config["timeoutSeconds"]?.doubleValue ?? 3600)
            Stepper(String(format: I18nManager.shared.t(.fsb_cv_timeoutFmt), timeout), value: Binding(
                get: { timeout },
                set: { v in node.config["timeoutSeconds"] = .double(Double(v)) }
            ), in: 60...86400, step: 60)
            .font(.system(size: theme.captionSize))
        }
    }
}

private struct FSBOutputSection: View {
    @Binding var node: CanvasNode<FSBNodeType>
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(I18nManager.shared.t(.fsb_cv_outputFormat))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            let fmt = node.config["outputFormat"]?.stringValue ?? "text"
            Picker(I18nManager.shared.t(.fsb_cv_format), selection: Binding(
                get: { fmt },
                set: { v in node.config["outputFormat"] = .string(v) }
            )) {
                Text(I18nManager.shared.t(.fsb_cv_plainText)).tag("text")
                Text("JSON").tag("json")
                Text("Markdown").tag("markdown")
                Text("CSV").tag("csv")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
    }
}
