import SwiftUI
import os.log

private let dashboardLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Dashboard")

/// Minimal collaboration dashboard (audit 0912 方案四): task list with
/// status + acceptance state, plan statuses, agent busy states and pending
/// guard approvals — one `desk.task.dashboard` round-trip per refresh.
/// Accept/reject buttons drive `desk.agent.accept` (rejected auto-reopens
/// the task on the cowork side).
struct SpaceTaskDashboardView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var tasks: [[String: Any]] = []
    @State private var plans: [[String: Any]] = []
    @State private var agents: [[String: Any]] = []
    @State private var pendingApprovals: [[String: Any]] = []
    @State private var isLoading = false
    @State private var lastError = ""
    @State private var busyTaskId = ""
    // realtime activity stream (desk.events.subscribe + poll loop)
    @State private var streamEvents: [[String: Any]] = []
    @State private var streamSubId = ""
    @State private var streamTask: Task<Void, Never>?
    // retrospective history (复盘, desk.retrospective.list)
    @State private var retrospectives: [[String: Any]] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if isLoading {
                ProgressView().padding()
                Spacer()
            } else if !lastError.isEmpty {
                errorView
                Spacer()
            } else {
                content
            }
        }
        .onAppear {
            load()
            startStream()
        }
        .onDisappear { streamTask?.cancel() }
    }

    /// Subscribe once, then poll the subscriber queue on a light timer and
    /// merge into the feed (dedup by event_id). Fall back to recent buffer
    /// for the initial fill when the subscription isn't ready yet.
    private func startStream() {
        guard streamTask == nil else { return }
        streamTask = Task {
            if let sub = try? await ipc.deskEventsSubscribe() {
                streamSubId = sub["sub_id"] as? String ?? ""
            }
            if streamSubId.isEmpty {
                if let recent = try? await ipc.deskEventsRecent(since: Date().timeIntervalSince1970 - 300) {
                    merge(events: recent["events"] as? [[String: Any]] ?? [])
                }
            }
            while !Task.isCancelled {
                if !streamSubId.isEmpty, let poll = try? await ipc.deskEventsPoll(subId: streamSubId) {
                    merge(events: poll["events"] as? [[String: Any]] ?? [])
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func merge(events: [[String: Any]]) {
        guard !events.isEmpty else { return }
        let known = Set(streamEvents.compactMap { $0["event_id"] as? String })
        let fresh = events.filter { !known.contains($0["event_id"] as? String ?? "") }
        guard !fresh.isEmpty else { return }
        streamEvents = (streamEvents + fresh).suffix(50)
        // a node_denied / permission_request event means a new approval may be waiting
        if fresh.contains(where: { ["node_denied", "permission_request"].contains($0["event_type"] as? String ?? "") }) {
            load()
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("任务看板")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            if !pendingApprovals.isEmpty {
                Text("待审批 \(pendingApprovals.count)")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.18))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            Spacer()
            Button(action: { load() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var errorView: some View {
        VStack(spacing: theme.spacingXS) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20))
                .foregroundStyle(theme.textTertiary)
            Text(lastError)
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
            Button("重试") { load() }
                .font(.system(size: 9))
                .foregroundStyle(theme.accent)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                if !pendingApprovals.isEmpty { approvalsSection }
                if !tasks.isEmpty { tasksSection }
                if !plans.isEmpty { plansSection }
                if !agents.isEmpty { agentsSection }
                if !streamEvents.isEmpty { streamSection }
                if !retrospectives.isEmpty { retrospectiveSection }
                if tasks.isEmpty && plans.isEmpty && agents.isEmpty && streamEvents.isEmpty && retrospectives.isEmpty {
                    emptyView
                }
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.bottom, theme.spacingM)
        }
    }

    private var emptyView: some View {
        VStack(spacing: theme.spacingXS) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 20))
                .foregroundStyle(theme.textTertiary)
            Text("暂无协作任务 — 下发任务后此处显示进度与验收状态")
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    private var approvalsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            sectionTitle("待审批", icon: "shield.lefthalf.filled")
            ForEach(Array(pendingApprovals.enumerated()), id: \.offset) { _, item in
                let actionId = str(item["action_id"] ?? item["node_id"] ?? item["task_id"] ?? item["id"])
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionId)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.text)
                        if let c = item["content"] as? String, !c.isEmpty {
                            Text(c)
                                .font(.system(size: 8))
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    if busyTaskId == actionId {
                        ProgressView().controlSize(.mini)
                    } else {
                        Button("批准") { confirmGuard(actionId, true) }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.green)
                            .buttonStyle(.plain)
                        Button("拒绝") { confirmGuard(actionId, false) }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                    }
                    Text(str(item["risk_level"] ?? ""))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            sectionTitle("任务", icon: "checklist")
            ForEach(Array(tasks.enumerated()), id: \.offset) { _, t in
                taskRow(t)
            }
        }
    }

    private func taskRow(_ t: [String: Any]) -> some View {
        let status = str(t["status"])
        let acc = str(t["acceptance_status"])
        let taskId = str(t["task_id"])
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                statusBadge(status)
                if !acc.isEmpty { acceptanceBadge(acc) }
                if let rc = t["retry_count"] as? Int, rc > 0 {
                    Text("重试×\(rc)")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                if let elapsed = t["elapsed"] as? Double {
                    Text(String(format: "%.1fs", elapsed))
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Text(str(t["description"]).isEmpty ? taskId : str(t["description"]))
                .font(.system(size: 10))
                .foregroundStyle(theme.text)
                .lineLimit(2)
            if !str(t["acceptance_criteria"]).isEmpty {
                Text("验收: \(str(t["acceptance_criteria"]))")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }
            if !str(t["error"]).isEmpty {
                Text(str(t["error"]))
                    .font(.system(size: 8))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
            if status == "completed" || status == "failed" {
                HStack(spacing: theme.spacingS) {
                    if busyTaskId == taskId {
                        ProgressView().controlSize(.mini)
                    } else {
                        Button("通过") { accept(taskId, "accepted") }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.green)
                            .buttonStyle(.plain)
                        Button("驳回") { accept(taskId, "rejected") }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.orange)
                            .buttonStyle(.plain)
                        Button("重开") { reopen(taskId) }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.accent)
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(8)
        .background(theme.groupBg)
        .cornerRadius(6)
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            sectionTitle("计划", icon: "flowchart")
            ForEach(Array(plans.enumerated()), id: \.offset) { _, p in
                HStack {
                    statusBadge(str(p["status"]))
                    Text(str(p["workflow_name"]))
                        .font(.system(size: 10))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Text("\(str(p["plan_id"]).suffix(8))")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            sectionTitle("角色", icon: "person.2")
            ForEach(Array(agents.enumerated()), id: \.offset) { _, a in
                let st = str(a["status"] ?? a["state"])
                let cur = str(a["current_task"])
                HStack {
                    Circle()
                        .fill(st == "busy" || st == "running" ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)
                    Text(str(a["agent_id"]))
                        .font(.system(size: 10))
                        .foregroundStyle(theme.text)
                    if !cur.isEmpty {
                        Text("→ \(cur.suffix(10))")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Spacer()
                    Text(st)
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(.vertical, 1)
            }
        }
    }

    /// Live event feed (realtime activity stream, newest first).
    private var streamSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 5, height: 5)
                sectionTitle("实时动态", icon: "dot.radiowaves.left.and.right")
                Spacer()
                Text("每 2s 刷新")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            ForEach(Array(streamEvents.reversed().enumerated()), id: \.offset) { _, e in
                eventRow(e)
            }
        }
    }

    /// Retrospective history (复盘): recent plan outcomes from the
    /// trajectory pool, newest first.
    private var retrospectiveSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            sectionTitle("复盘历史", icon: "clock.arrow.circlepath")
            ForEach(Array(retrospectives.enumerated()), id: \.offset) { _, r in
                HStack {
                    statusBadge(str(r["status"]))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(str(r["workflow_name"]).isEmpty ? String(str(r["plan_id"]).suffix(10)) : str(r["workflow_name"]))
                            .font(.system(size: 10))
                            .foregroundStyle(theme.text)
                        if let failed = r["failed_tasks"] as? [String], !failed.isEmpty {
                            Text("失败: \(failed.joined(separator: ", ").prefix(40))")
                                .font(.system(size: 8))
                                .foregroundStyle(.red)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if let ts = r["ts"] as? Double {
                        Text(Date(timeIntervalSince1970: ts).formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func eventRow(_ e: [String: Any]) -> some View {
        let type = str(e["event_type"])
        let (icon, color): (String, Color) = {
            switch type {
            case "workflow_start": return ("play.fill", .blue)
            case "workflow_end": return ("flag.checkered", .green)
            case "workflow_cancel": return ("stop.fill", .gray)
            case "node_start": return ("arrow.right.circle", .blue)
            case "node_end": return ("checkmark.circle", .green)
            case "node_denied": return ("hand.raised.fill", .red)
            case "permission_request": return ("lock.shield", .orange)
            default: return ("circle.fill", .gray)
            }
        }()
        let ts = (e["timestamp"] as? Double).map { Date(timeIntervalSince1970: $0) }
        return HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(type)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.text)
                    if let name = e["node_name"] as? String, !name.isEmpty {
                        Text(name)
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    if let ts = ts {
                        Text(ts.formatted(date: .omitted, time: .standard))
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                if let d = e["data"] as? [String: Any], !d.isEmpty {
                    Text(compactData(d))
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 1)
    }

    private func compactData(_ d: [String: Any]) -> String {
        return d.sorted { "\($0.key)" < "\($1.key)" }
            .prefix(3)
            .map { "\($0.key)=\(String("\($0.value)".prefix(40)))" }
            .joined(separator: " ")
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(title).font(.system(size: theme.footnoteSize, weight: .semibold))
        }
        .foregroundStyle(theme.textSecondary)
    }

    private func statusBadge(_ s: String) -> some View {
        let (label, color): (String, Color) = {
            switch s {
            case "completed", "success": return ("已完成", .green)
            case "failed": return ("失败", .red)
            case "skipped": return ("跳过", .gray)
            case "running": return ("运行中", .orange)
            case "cancelled": return ("已取消", .gray)
            case "pending": return ("待执行", .blue)
            case "partial": return ("部分完成", .orange)
            default: return (s.isEmpty ? "-" : s, .secondary)
            }
        }()
        return Text(label)
            .font(.system(size: 8, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func acceptanceBadge(_ s: String) -> some View {
        let (label, color): (String, Color) = {
            switch s {
            case "accepted": return ("验收通过", .green)
            case "rejected": return ("已驳回", .red)
            case "pending": return ("待验收", .blue)
            default: return (s, .secondary)
            }
        }()
        return Text(label)
            .font(.system(size: 8, weight: .semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func str(_ v: Any?) -> String {
        return v as? String ?? (v.map { "\($0)" } ?? "")
    }

    // MARK: - Actions

    private func load() {
        isLoading = tasks.isEmpty
        lastError = ""
        Task {
            do {
                let result = try await ipc.taskDashboard()
                let d = result["dashboard"] as? [String: Any] ?? result
                await MainActor.run {
                    tasks = d["tasks"] as? [[String: Any]] ?? []
                    plans = d["plans"] as? [[String: Any]] ?? []
                    agents = d["agents"] as? [[String: Any]] ?? []
                    pendingApprovals = d["pending_approvals"] as? [[String: Any]]
                        ?? d["pending_guard"] as? [[String: Any]] ?? []
                    isLoading = false
                }
                // 复盘历史 is independent of the main payload — fetch best-effort
                if let retro = try? await ipc.retrospectiveList(limit: 10) {
                    let rows = retro["retrospectives"] as? [[String: Any]] ?? []
                    await MainActor.run { retrospectives = rows }
                }
            } catch {
                dashboardLog.error("taskDashboard failed: \(error.localizedDescription)")
                await MainActor.run {
                    lastError = "看板加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func accept(_ taskId: String, _ verdict: String) {
        busyTaskId = taskId
        Task {
            do {
                _ = try await ipc.agentAcceptTask(taskId: taskId, verdict: verdict)
                dashboardLog.info("accept \(taskId) -> \(verdict)")
            } catch {
                dashboardLog.error("accept failed: \(error.localizedDescription)")
            }
            await MainActor.run {
                busyTaskId = ""
                load()
            }
        }
    }

    private func reopen(_ taskId: String) {
        busyTaskId = taskId
        Task {
            do {
                _ = try await ipc.agentReopenTask(taskId: taskId)
                dashboardLog.info("reopen \(taskId)")
            } catch {
                dashboardLog.error("reopen failed: \(error.localizedDescription)")
            }
            await MainActor.run {
                busyTaskId = ""
                load()
            }
        }
    }

    private func confirmGuard(_ actionId: String, _ approved: Bool) {
        busyTaskId = actionId
        Task {
            do {
                _ = try await ipc.deskPermissionConfirmGuard(actionId: actionId, approved: approved)
                dashboardLog.info("guard confirm \(actionId) approved=\(approved)")
            } catch {
                dashboardLog.error("guard confirm failed: \(error.localizedDescription)")
            }
            await MainActor.run {
                busyTaskId = ""
                load()
            }
        }
    }
}
