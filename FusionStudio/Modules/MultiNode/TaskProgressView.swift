// Importers/callers: ModuleDetailView, TaskMonitorView context menu
// Affected API: engine.fetchTaskProgress(), engine.fetchTaskTimeline()
// Data schemas: TaskProgress, TaskTimeline, TimelineEvent, SubTask
// User verbatim: "做一遍检查，所有需要GUI的都要在fusion-studio落地"

import SwiftUI
import os.log

private let progressLog = Logger(subsystem: "com.fusion.studio", category: "TaskProgress")

struct TaskProgressView: View {
    @EnvironmentObject var uiPanelState: UIPanelState
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var selectedTaskId: String = ""
    @State private var progress: TaskProgress?
    @State private var timeline: TaskTimeline?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: i18n.t(.mn_progress_title), subtitle: i18n.t(.mn_progress_subtitle))

                ClusterStatusBanner(engine: engine)

                taskPicker
                if let taskId = currentTaskId {
                    progressContent(taskId: taskId)
                } else {
                    emptyState
                }
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
    }

    private var currentTaskId: String? {
        if case .clusterTask(let id) = uiPanelState.inspectorContext { return id }
        return selectedTaskId.isEmpty ? nil : selectedTaskId
    }

    private var taskPicker: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_progress_selectTaskTitle))
            HStack(spacing: theme.spacingM) {
                Picker(i18n.t(.mn_progress_taskPicker), selection: $selectedTaskId) {
                    Text(i18n.t(.mn_progress_inspectorSelect)).tag("")
                    ForEach(engine.tasks) { task in
                        Text("\(task.id) — \(task.name)").tag(task.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 300)

                FusionButton(i18n.t(.mn_progress_loadDetailsBtn), icon: "arrow.clockwise", style: .secondary, size: .small, isLoading: isLoading, isDisabled: currentTaskId == nil) {
                    loadDetails()
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
        }
    }

    private func progressContent(taskId: String) -> some View {
        VStack(spacing: 0) {
            if let error = error {
                ListGroup {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.amberDot)
                        Text(error).font(.system(size: theme.smallTextSize)).foregroundStyle(theme.textSecondary)
                    }
                    .padding(theme.spacingL)
                }
            }

            if let prog = progress {
                progressBarSection(prog)
            }

            if let tl = timeline {
                timelineSection(tl)
            }

            if let task = engine.tasks.first(where: { $0.id == taskId }) {
                subTasksSection(task)
            }
        }
    }

    private func progressBarSection(_ prog: TaskProgress) -> some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_progress_execProgressTitle))

            VStack(spacing: theme.spacingM) {
                ProgressView(value: prog.progress)
                    .progressViewStyle(.linear)
                    .tint(theme.accent)

                HStack(spacing: theme.spacingL) {
                    Label("\(Int(prog.progress * 100))%", systemImage: "chart.pie")
                    Label("\(prog.completedShards)/\(prog.totalShards) shards", systemImage: "square.grid.2x2")
                    if let elapsed = prog.elapsedSeconds {
                        Label(formatDuration(elapsed), systemImage: "clock")
                    }
                    if let remaining = prog.remainingSeconds {
                        Label(String(format: i18n.t(.mn_progress_remainingFmt), formatDuration(remaining)), systemImage: "hourglass")
                    }
                }
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingL)
        }
    }

    private func timelineSection(_ tl: TaskTimeline) -> some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_progress_timelineTitle))

            ForEach(tl.events) { event in
                HStack(alignment: .top, spacing: theme.spacingM) {
                    VStack(spacing: 0) {
                        Circle().fill(theme.accent).frame(width: 8, height: 8)
                        if event.id != tl.events.last?.id {
                            Rectangle().fill(theme.accent.opacity(0.3)).frame(width: 2).frame(minHeight: 24)
                        }
                    }
                    .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.event)
                            .font(.system(size: theme.smallTextSize, weight: .medium))
                            .foregroundStyle(theme.text)
                        if let detail = event.detail {
                            Text(detail)
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textSecondary)
                        }
                        Text(event.timestamp)
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingXS)
            }
        }
    }

    private func subTasksSection(_ task: ClusterTask) -> some View {
        Group {
            if let subs = task.subTasks, !subs.isEmpty {
                ListGroup {
                    StudioSectionHeader(title: String(format: i18n.t(.mn_progress_subTasksFmt), subs.count))
                    ForEach(subs, id: \.subTaskId) { sub in
                        HStack(spacing: theme.spacingM) {
                            subStatusDot(sub.status)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.subTaskId)
                                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                                    .foregroundStyle(theme.text)
                                Text("Node: \(sub.nodeId)")
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            Spacer()
                            if let p = sub.progress {
                                Text("\(Int(p * 100))%")
                                    .font(.system(size: theme.captionSize, weight: .medium, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary)
                                ProgressView(value: p)
                                    .progressViewStyle(.linear)
                                    .frame(width: 60)
                            }
                        }
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingS)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ListGroup {
            VStack(spacing: theme.spacingM) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.textTertiary)
                Text(i18n.t(.mn_progress_emptyHint))
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacing2XL)
        }
    }

    private func subStatusDot(_ status: String) -> some View {
        let color: Color = switch status {
        case "running": theme.greenDot
        case "completed": theme.accent
        case "failed": theme.redDot
        default: theme.textTertiary
        }
        return Circle().fill(color).frame(width: 8, height: 8)
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 { return String(format: "%.0fs", seconds) }
        if seconds < 3600 { return String(format: "%.1fm", seconds / 60) }
        return String(format: "%.1fh", seconds / 3600)
    }

    private func loadDetails() {
        guard let tid = currentTaskId else { return }
        isLoading = true
        error = nil
        progressLog.info("Loading details for task: \(tid)")

        engine.fetchTaskProgress(taskId: tid) { [self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let prog):
                    self.progress = prog
                    progressLog.info("Task progress loaded: \(prog.progress)")
                case .failure(let error):
                    progressLog.error("Task progress failed: \(error.localizedDescription)")
                    self.error = String(format: i18n.t(.mn_progress_loadFailFmt), error.localizedDescription)
                }
                self.isLoading = false
            }
        }

        engine.fetchTaskTimeline(taskId: tid) { [self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tl):
                    self.timeline = tl
                case .failure(let error):
                    progressLog.debug("Timeline not available: \(error.localizedDescription)")
                }
            }
        }
    }
}
