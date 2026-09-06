import SwiftUI
import os.log

private let agentCanvasViewLog = Logger(subsystem: "com.fusion.studio", category: "agent-workflow-canvas")

struct AgentWorkflowCanvasView: View {
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    let mode: Mode
    var onSave: () -> Void
    let toastManager: FusionToastManager

    enum Mode { case create, edit(AgentGraphModel) }

    @StateObject private var delegate: AgentWorkflowCanvasDelegate
    @State private var executeInput = ""
    @State private var isExecuting = false
    @State private var executionResult = ""

    init(mode: Mode, toastManager: FusionToastManager, onSave: @escaping () -> Void) {
        self.mode = mode
        self.toastManager = toastManager
        self.onSave = onSave
        let graph: AgentGraphModel? = {
            if case .edit(let g) = mode { return g } else { return nil }
        }()
        _delegate = StateObject(wrappedValue: AgentWorkflowCanvasDelegate(bridge: AgentBridge(), graph: graph))
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkflowCanvasView(delegate: delegate, graphName: $delegate.graphName) {
                onSave()
            }
            .environmentObject(bridge)
            Divider()
            executeStrip
        }
        .onAppear { delegate.bridge = bridge }
    }

    private var executeStrip: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingS) {
                TextField(I18nManager.shared.t(.wf_cv_testRun) + " input", text: $executeInput)
                    .textFieldStyle(.roundedBorder)
                Button(action: { executeGraph() }) {
                    Label(
                        isExecuting ? I18nManager.shared.t(.wf_cv_running) : I18nManager.shared.t(.wf_cv_testRun),
                        systemImage: isExecuting ? "stop" : "play"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExecuting || delegate.graphId == nil)
                .controlSize(.small)
                if isExecuting {
                    Button("Cancel") { bridge.cancelExecution() }
                        .controlSize(.small)
                }
            }
            ScrollView {
                Text(executionResult.isEmpty ? "—" : executionResult)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
        }
        .padding(theme.spacingS)
        .background(theme.contentBg)
    }

    private func executeGraph() {
        guard let gid = delegate.graphId else { return }
        isExecuting = true
        executionResult = ""
        agentCanvasViewLog.info("executeGraph start id=\(gid, privacy: .public)")
        Task {
            do {
                let events = try await bridge.executeGraph(id: gid, input: executeInput)
                var output = ""
                for ev in events {
                    let nodeId = ev.node_id ?? "?"
                    output += "[\(ev.type)] \(nodeId)"
                    if let data = ev.data, !data.isEmpty {
                        output += ": \(data.map { "\($0)=\(jsonValueString($1))" }.joined(separator: " "))"
                    }
                    output += "\n"
                }
                if output.isEmpty { output = "Workflow completed (no events)" }
                executionResult = output
                agentCanvasViewLog.info("executeGraph success id=\(gid, privacy: .public) events=\(events.count)")
                toastManager.show(style: .success, title: "Workflow Complete", message: delegate.graphName)
            } catch {
                executionResult = "Error: \(error.localizedDescription)"
                agentCanvasViewLog.error("executeGraph failed id=\(gid, privacy: .public) err=\(error.localizedDescription, privacy: .public)")
                toastManager.show(style: .error, title: "Execution Failed", message: error.localizedDescription)
            }
            isExecuting = false
        }
    }
}

private func jsonValueString(_ v: JSONValue) -> String {
    switch v {
    case .string(let s): return s
    case .double(let d): return String(d)
    case .bool(let b): return String(b)
    case .object(let o): return "{\(o.count)}"
    case .array(let a): return "[\(a.count)]"
    }
}
