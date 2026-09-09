import SwiftUI
import os.log

private let evidenceDiagLog = Logger(subsystem: "com.fusion.studio", category: "EvidenceDiagnosticsView")

// M2-5: EvidenceDiagnostics — failed execution list + evidence_ref display.
// Fallback mode (upstream #316 evidence.list/evidence.failure not yet implemented):
// filters task.list for status=failed client-side, shows evidence_ref path.
// Full mode (post-#316): evidence.list + evidence.failure RPCs for dedicated listing.
struct EvidenceDiagnosticsView: View {
    @EnvironmentObject var teamBridge: TeamBridge

    private var failedTasks: [TeamTask] {
        teamBridge.tasks.filter { $0.status == "failed" }
    }

    private var tasksWithEvidence: [TeamTask] {
        failedTasks.filter { $0.hasEvidence }
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            if failedTasks.isEmpty {
                emptyState
            } else {
                failedTaskList
            }
        }
        .onAppear {
            Task { await teamBridge.refreshTasks() }
            evidenceDiagLog.info("EvidenceDiagnosticsView appeared failed=\(self.failedTasks.count)")
        }
    }

    // MARK: - Summary

    private var summaryBar: some View {
        HStack(spacing: 16) {
            summaryItem(count: failedTasks.count, label: "Failed", color: .red)
            summaryItem(count: tasksWithEvidence.count, label: "With Evidence", color: .orange)
            summaryItem(count: failedTasks.count - tasksWithEvidence.count, label: "No Evidence", color: .secondary)
            Spacer()
            if teamBridge.isLoading {
                ProgressView().scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func summaryItem(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - List

    private var failedTaskList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(failedTasks) { task in
                    FailedTaskCard(task: task)
                }
            }
            .padding(8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
            Text("No failed executions")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Failed task card

private struct FailedTaskCard: View {
    let task: TeamTask
    @State private var showEvidenceDetail: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                Text(task.title.isEmpty ? task.id : task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                Spacer()
                if task.priority > 5 {
                    Text("P\(task.priority)")
                        .font(.system(size: 10))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(3)
                }
            }
            if !task.ownerAgent.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(task.ownerAgent)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            if task.hasEvidence {
                DisclosureGroup(isExpanded: $showEvidenceDetail) {
                    evidenceDetail
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                        Text("Evidence")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "doc.slash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("No evidence file")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private var evidenceDetail: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !task.graphId.isEmpty {
                detailRow(label: "Graph", value: task.graphId)
            }
            if !task.evidenceRef.isEmpty {
                detailRow(label: "Evidence Path", value: task.evidenceRef)
            }
            if !task.resourceLeaseId.isEmpty {
                detailRow(label: "Lease", value: task.resourceLeaseId)
            }
            Text("Full evidence available via graph.status RPC (daemon reads evidence internally)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
