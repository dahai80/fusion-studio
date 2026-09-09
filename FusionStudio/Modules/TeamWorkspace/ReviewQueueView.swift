import SwiftUI
import os.log

private let reviewQueueLog = Logger(subsystem: "com.fusion.studio", category: "ReviewQueueView")

// M2-3: ReviewQueue — tasks with review_state=review/needs_fix.
// Read-only mode: shows tasks awaiting review. Approve/reject buttons disabled
// (full write ops need upstream #317 task.set_review_state RPC).
// GUI 不做本地状态 — daemon SSOT, refresh on appear.
struct ReviewQueueView: View {
    @EnvironmentObject var teamBridge: TeamBridge

    private var reviewTasks: [TeamTask] {
        teamBridge.tasks.filter { $0.reviewState == "review" || $0.reviewState == "needs_fix" }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if reviewTasks.isEmpty {
                emptyState
            } else {
                reviewList
            }
        }
        .onAppear {
            Task { await teamBridge.refreshTasks() }
            reviewQueueLog.info("ReviewQueueView appeared review_count=\(self.reviewTasks.count)")
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.message")
                    .foregroundColor(.orange)
                Text("Review Queue")
                    .font(.system(size: 14, weight: .semibold))
            }
            Text("\(reviewTasks.count) pending")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text("Read-only — approve/reject needs upstream #317")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var reviewList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(reviewTasks) { task in
                    ReviewTaskCard(task: task)
                }
            }
            .padding(8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
            Text("No tasks awaiting review")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Review task card

private struct ReviewTaskCard: View {
    let task: TeamTask

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title.isEmpty ? task.id : task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                Spacer()
                reviewStateBadge
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
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 9))
                        .foregroundColor(.accentColor)
                    Text("Evidence available")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
            }
            // M2-3 write ops: disabled until upstream #317 (task.set_review_state RPC)
            HStack(spacing: 8) {
                actionButton("Approve", icon: "checkmark.circle.fill", color: .green, enabled: false)
                actionButton("Request Fix", icon: "wrench.adjustable", color: .orange, enabled: false)
                actionButton("Reject", icon: "xmark.circle.fill", color: .red, enabled: false)
                Spacer()
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private var reviewStateBadge: some View {
        let isNeedsFix = task.reviewState == "needs_fix"
        return Text(isNeedsFix ? "Needs Fix" : "Review")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isNeedsFix ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
            .cornerRadius(4)
    }

    private func actionButton(_ title: String, icon: String, color: Color, enabled: Bool) -> some View {
        Button {
            // M2-3: task.set_review_state RPC (upstream #317) — not yet available
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11))
            }
            .foregroundColor(enabled ? color : .secondary)
        }
        .disabled(!enabled)
        .help(enabled ? "" : "Requires upstream #317 (task.set_review_state RPC)")
    }
}
