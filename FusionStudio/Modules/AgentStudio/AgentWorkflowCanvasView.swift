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
    // 审计0907 P3-10: executeGraph Task 旧 fire-and-forget, view 消失后仍跑 (bridge 持 ref)。
    //   存 handle, onDisappear cancel + flag, 防超生命周期执行泄漏。
    @State private var executeTask: Task<Void, Never>?

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
            WorkflowCanvasView(delegate: delegate, graphName: $delegate.graphName, toastManager: toastManager) {
                onSave()
            }
            .environmentObject(bridge)
            Divider()
            executeStrip
        }
        // 审计0907 P2-17/P3-1: 旧 .onAppear { delegate.bridge = bridge } — init 先用空 AgentBridge(), onAppear 才换真 bridge。
        //   载入/保存首帧可能用空 bridge 失败。改 .task {} 有序注入 (在 canvas .task loadGraph 前执行, 同帧拿到真 bridge)。
        .task { delegate.bridge = bridge }
        // 审计0907 P3-10: view 消失取消进行中 executeGraph, 防超生命周期 Task 泄漏。
        .onDisappear { executeTask?.cancel(); executeTask = nil }
    }

    private var executeStrip: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingS) {
                TextField(I18nManager.shared.t(.wf_cv_testRun) + " " + I18nManager.shared.t(.wf_cv_inputSuffix), text: $executeInput)
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
                    Button(I18nManager.shared.t(.wf_cv_cancel)) { bridge.cancelExecution() }
                        .controlSize(.small)
                }
            }
            ScrollView {
                Text(executionResult.isEmpty ? I18nManager.shared.t(.wf_cv_emptyResult) : executionResult)
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
        executeTask?.cancel()
        executeTask = Task { @MainActor in
            do {
                try Task.checkCancellation()
                let events = try await bridge.executeGraph(id: gid, input: executeInput)
                try Task.checkCancellation()
                var output = ""
                for ev in events {
                    let nodeId = ev.node_id ?? "?"
                    output += "[\(ev.type)] \(nodeId)"
                    if let data = ev.data, !data.isEmpty {
                        output += ": \(data.map { "\($0)=\(jsonValueString($1))" }.joined(separator: " "))"
                    }
                    output += "\n"
                }
                if output.isEmpty { output = I18nManager.shared.t(.wf_cv_noEvents) }
                executionResult = output
                agentCanvasViewLog.info("executeGraph success id=\(gid, privacy: .public) events=\(events.count)")
                toastManager.show(style: .success, title: I18nManager.shared.t(.wf_cv_executeComplete), message: delegate.graphName)
            } catch is CancellationError {
                agentCanvasViewLog.info("executeGraph cancelled id=\(gid, privacy: .public)")
            } catch {
                executionResult = I18nManager.shared.t(.wf_cv_executeErrorPrefix) + error.localizedDescription
                agentCanvasViewLog.error("executeGraph failed id=\(gid, privacy: .public) err=\(error.localizedDescription, privacy: .public)")
                toastManager.show(style: .error, title: I18nManager.shared.t(.wf_cv_executeFailed), message: error.localizedDescription)
            }
            isExecuting = false
            executeTask = nil
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
