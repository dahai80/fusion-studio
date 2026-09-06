import SwiftUI
import os.log

struct FSBWorkflowCanvasView: View {
    @ObservedObject var ipc: IPCClient
    let workspaceId: String
    let workflowId: String?
    let onSave: () -> Void
    @StateObject private var delegate: FSBWorkflowCanvasDelegate

    init(ipc: IPCClient, workspaceId: String, workflowId: String? = nil, onSave: @escaping () -> Void = {}) {
        self.ipc = ipc
        self.workspaceId = workspaceId
        self.workflowId = workflowId
        self.onSave = onSave
        _delegate = StateObject(wrappedValue: FSBWorkflowCanvasDelegate(ipc: ipc, workspaceId: workspaceId, workflowId: workflowId))
    }

    var body: some View {
        WorkflowCanvasView(delegate: delegate, graphName: $delegate.workflowName, onSave: onSave)
    }
}
