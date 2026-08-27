import SwiftUI
import Combine
import os.log

// MARK: - CronTabView

struct CronTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var selectedTaskId: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scheduled Tasks")
                        .font(.system(size: theme.titleSize, weight: .bold))
                        .foregroundStyle(theme.text)
                    Text("Cron jobs registered by Task → Schedule / Once. Create tasks in the Tasks tab.")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                FusionButton("Refresh", icon: "arrow.clockwise", style: .secondary, size: .small) {
                    Task { await bridge.fetchCronJobs() }
                }
            }
            .padding(theme.spacingM)

            if bridge.configState.cronJobs.isEmpty {
                Spacer()
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 36))
                    .foregroundStyle(theme.textTertiary)
                Text("No scheduled tasks")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, theme.spacingS)
                Text("Create a Task with Schedule or Once trigger to add a cron job.")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingXL)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.cronJobs.enumerated()), id: \.offset) { idx, job in
                        cronRow(job, isLast: idx == bridge.configState.cronJobs.count - 1)
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchCronJobs() } }
        .sheet(item: Binding(
            get: { selectedTaskId.map { IdentifiableString(value: $0) } },
            set: { selectedTaskId = $0?.value }
        )) { wrap in
            AgentTaskDetailView(taskId: wrap.value, toastManager: toastManager)
        }
    }

    private func cronRow(_ job: [String: Any], isLast: Bool) -> some View {
        let name = job["name"] as? String ?? "Unknown"
        let expression = job["expression"] as? String ?? (job["schedule"] as? String ?? "")
        let cronId = job["id"] as? String ?? job["cron_id"] as? String ?? ""
        let enabled = job["enabled"] as? Bool ?? true
        let nextRun = job["next_run"] as? Double ?? 0
        let graphId = job["graph_id"] as? String ?? ""
        let inputRaw = job["input_data"] as? String ?? ""
        let linkedTaskId = parseTaskId(from: inputRaw)
        let linkedTask = linkedTaskId.flatMap { id in bridge.taskState.tasks.first(where: { $0.id == id }) }

        return StudioRow(
            label: name,
            sublabel: rowSublabel(expression: expression, graphId: graphId, linkedTask: linkedTask, linkedTaskId: linkedTaskId, nextRun: nextRun),
            isLast: isLast
        ) {
            FusionTag(enabled ? "active" : "paused", color: enabled ? .green : .gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let tid = linkedTaskId { selectedTaskId = tid }
        }
        .contextMenu {
            if let tid = linkedTaskId {
                Button("Open Task") { selectedTaskId = tid }
            }
            Button("Unregister", role: .destructive) {
                Task { await unregisterCron(cronId, name: name) }
            }
        }
    }

    private func rowSublabel(expression: String, graphId: String, linkedTask: TaskModel?, linkedTaskId: String?, nextRun: Double) -> String {
        var parts: [String] = []
        if !expression.isEmpty { parts.append(expression) }
        if let linkedTask {
            parts.append("→ task: \(linkedTask.title)")
        } else if let linkedTaskId {
            parts.append("→ task: \(linkedTaskId)")
        } else if !graphId.isEmpty {
            let gname = bridge.graphName(for: graphId)
            parts.append("→ \(gname.isEmpty ? "workflow" : gname)")
        } else {
            parts.append("→ (no graph)")
        }
        if nextRun > 0 {
            let fmt = DateFormatter()
            fmt.dateFormat = "MM-dd HH:mm"
            parts.append("next: \(fmt.string(from: Date(timeIntervalSince1970: nextRun)))")
        }
        return parts.joined(separator: "  ")
    }

    private func parseTaskId(from inputRaw: String) -> String? {
        guard let data = inputRaw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return obj["task_id"] as? String
    }

    private func unregisterCron(_ id: String, name: String) async {
        do {
            _ = try await bridge.cronUnregister(cronId: id)
            toastManager.show(style: .info, title: "Removed", message: name)
            await bridge.fetchCronJobs()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}

private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}
