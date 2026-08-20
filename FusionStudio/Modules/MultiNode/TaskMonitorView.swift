import SwiftUI
import os.log

private let taskLog = Logger(subsystem: "com.fusion.studio", category: "TaskMonitor")

struct TaskMonitorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var selectedTab: TaskTab = .all
    @State private var searchText = ""
    @State private var showMigrateSheet = false
    @State private var migrateTaskId = ""
    @State private var migrateTargetNode = ""
    @State private var isMigrating = false

    enum TaskTab: String, CaseIterable {
        case all
        case running
        case completed
        case failed
        var localLabel: String {
            switch self {
            case .all: return I18nManager.shared.t(.mn_task_tab_all)
            case .running: return I18nManager.shared.t(.mn_task_tab_running)
            case .completed: return I18nManager.shared.t(.mn_task_tab_completed)
            case .failed: return I18nManager.shared.t(.mn_task_tab_failed)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: i18n.t(.mn_task_title), subtitle: i18n.t(.mn_task_subtitle))

                tabBar
                metricsStrip
                taskListSection
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
        .onAppear { engine.startPolling() }
        .onDisappear { engine.stopPolling() }
        .sheet(isPresented: $showMigrateSheet) {
            migrateSheet
        }
    }

    private var migrateSheet: some View {
        VStack(spacing: theme.spacingL) {
            Text(i18n.t(.mn_task_migrateTitle))
                .font(.system(size: theme.bodySize, weight: .bold))
                .foregroundStyle(theme.text)

            StudioRow(label: i18n.t(.mn_task_taskId)) {
                Text(migrateTaskId)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }

            StudioRow(label: i18n.t(.mn_task_targetNode)) {
                Menu {
                    Button(i18n.t(.mn_task_selectNode)) { migrateTargetNode = "" }
                    nodeMenuItems
                } label: {
                    Text(migrateTargetNode.isEmpty ? i18n.t(.mn_task_selectNode) : migrateTargetNode)
                        .font(.system(size: theme.smallTextSize, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            HStack(spacing: theme.spacingM) {
                FusionButton(i18n.t(.cancel), icon: "xmark", style: .secondary, size: .regular) {
                    showMigrateSheet = false
                }
                FusionButton(i18n.t(.mn_task_confirmMigrate), icon: "arrow.right.circle", style: .primary, size: .regular,
                    isLoading: isMigrating, isDisabled: migrateTargetNode.isEmpty) {
                    performMigration()
                }
            }
            .padding(.top, theme.spacingM)
        }
        .padding(theme.spacingXL)
        .frame(width: 420)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusLarge, style: .continuous))
    }

    private func performMigration() {
        isMigrating = true
        engine.migrateTask(taskId: migrateTaskId, targetNodeId: migrateTargetNode) { result in
            isMigrating = false
            switch result {
            case .success:
                taskLog.info("Task migrated: \(self.migrateTaskId) -> \(self.migrateTargetNode)")
                showMigrateSheet = false
            case .failure(let error):
                taskLog.error("Migration failed: \(error.localizedDescription)")
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(TaskTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(theme.springDefault) { selectedTab = tab }
                } label: {
                    Text(tab.localLabel)
                        .font(.system(size: theme.smallTextSize, weight: tab == selectedTab ? .semibold : .regular))
                        .foregroundStyle(tab == selectedTab ? theme.accent : theme.textSecondary)
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingS)
                        .background(
                            tab == selectedTab ? theme.accentSoft : Color.clear,
                            in: RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingM)
    }

    private var filteredTasks: [ClusterTask] {
        var result: [ClusterTask]
        switch selectedTab {
        case .all: result = engine.tasks
        case .running: result = engine.tasks.filter { $0.status == .running || $0.status == .pending || $0.status == .degraded }
        case .completed: result = engine.tasks.filter { $0.status == .completed || $0.status == .cancelled }
        case .failed: result = engine.tasks.filter { $0.status == .failed }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.id.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.modelName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    private var metricsStrip: some View {
        HStack(spacing: theme.spacingM) {
            MetricStripCard(icon: "list.bullet.clipboard", label: i18n.t(.mn_task_total), value: "\(engine.tasks.count)", subtitle: i18n.t(.mn_task_allTasks))
            MetricStripCard(icon: "play.circle", label: i18n.t(.mn_task_running), value: "\(engine.tasks.filter { $0.status == .running }.count)", subtitle: i18n.t(.mn_task_executing), dotColor: theme.greenDot)
            MetricStripCard(icon: "exclamationmark.triangle", label: i18n.t(.mn_task_failed), value: "\(engine.tasks.filter { $0.status == .failed }.count)", subtitle: i18n.t(.mn_task_needsAttention), dotColor: theme.redDot)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingM)
    }

    private var taskListSection: some View {
        ListGroup {
            StudioSectionHeader(title: String(format: i18n.t(.mn_task_listTitleFmt), filteredTasks.count))

            HStack(spacing: theme.spacingS) {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.textTertiary)
                TextField(i18n.t(.mn_task_searchPh), text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize))
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)

            ForEach(filteredTasks) { task in
                TaskRow(task: task, isSelected: selectedTaskId == task.id) {
                    appState.inspectorContext = .clusterTask(id: task.id)
                    appState.isInspectorVisible = true
                }
                .contextMenu {
                    if task.status == .running {
                        Button(i18n.t(.mn_task_cancelTask)) {
                            Task { try? await engine.cancelTask(taskId: task.id) }
                        }
                        Button(i18n.t(.mn_task_degradeTask)) {
                            Task { try? await engine.degradeTask(taskId: task.id) }
                        }
                        Button(i18n.t(.mn_task_migrateTask)) {
                            migrateTaskId = task.id
                            migrateTargetNode = ""
                            showMigrateSheet = true
                        }
                    }
                    if task.status == .failed {
                        Button(i18n.t(.retry)) {
                            Task {
                                _ = try? await engine.submitTask(
                                    name: task.name, mode: task.mode,
                                    modelName: task.modelName
                                )
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if task.id != filteredTasks.last?.id {
                        Rectangle().fill(theme.rowSep).frame(height: 0.5).padding(.horizontal, theme.spacingL)
                    }
                }
            }

            if filteredTasks.isEmpty {
                Text(String(format: i18n.t(.mn_task_emptyFmt), selectedTab.localLabel))
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, theme.spacing2XL)
            }
        }
    }

    private var selectedTaskId: String? {
        if case .clusterTask(let id) = appState.inspectorContext { return id }
        return nil
    }

    @ViewBuilder
    private var nodeMenuItems: some View {
        ForEach(Array(engine.nodes.enumerated()), id: \.offset) { _, node in
            Button("\(node.hostname) (\(node.status.rawValue))") {
                migrateTargetNode = node.id
            }
        }
    }
}
