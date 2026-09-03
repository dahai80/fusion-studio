import SwiftUI
import os.log

private let writeBtnLog = Logger(subsystem: "com.fusion.studio", category: "ClusterWriteButton")

struct ClusterWriteButton: View {
    @ObservedObject var engine: MultiNodeEngine
    @StateObject private var i18n = I18nManager.shared
    let title: String
    let action: String
    var targetNode: String? = nil
    var targetTask: String? = nil
    var idempotencyKey: String? = nil
    let perform: () async throws -> Void

    @State private var isPerforming = false

    var body: some View {
        Button(action: {
            guard MultiNodeEngine.shouldEnableWrite(canMutate: engine.canMutate) else {
                writeBtnLog.warning("write blocked: action=\(self.action, privacy: .public) canMutate=false")
                ClusterAuditor.shared.record(action: action, targetNode: targetNode,
                                             targetTask: targetTask, result: "blocked",
                                             idempotencyKey: idempotencyKey, masterHost: engine.activeMasterHost)
                return
            }
            isPerforming = true
            Task {
                do {
                    try await perform()
                    ClusterAuditor.shared.record(action: action, targetNode: targetNode,
                                                 targetTask: targetTask, result: "ok",
                                                 idempotencyKey: idempotencyKey, masterHost: engine.activeMasterHost)
                } catch {
                    writeBtnLog.error("write failed: action=\(self.action, privacy: .public) err=\(error.localizedDescription, privacy: .public)")
                    ClusterAuditor.shared.record(action: action, targetNode: targetNode,
                                                 targetTask: targetTask, result: "failed",
                                                 idempotencyKey: idempotencyKey, masterHost: engine.activeMasterHost)
                }
                isPerforming = false
            }
        }) {
            if isPerforming {
                ProgressView().controlSize(.small)
            } else {
                Text(title)
            }
        }
        .disabled(!engine.canMutate || isPerforming)
        .help(engine.canMutate ? "" : i18n.t(.mn_writeDisabled_help))
    }
}
