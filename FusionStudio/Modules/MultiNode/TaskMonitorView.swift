import SwiftUI
import os.log

private let taskLog = Logger(subsystem: "com.fusion.studio", category: "TaskMonitor")

struct TaskMonitorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme

    @State private var selectedTab: TaskTab = .all
    @State private var searchText = ""
    @State private var showMigrateSheet = false
    @State private var migrateTaskId = ""
    @State private var migrateTargetNode = ""
    @State private var isMigrating = false

    enum TaskTab: String, CaseIterable {
        case all = "全部"
        case running = "运行中"
        case completed = "已完成"
        case failed = "失败"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: "任务监控", subtitle: "实时跟踪任务执行状态与进度")

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
            Text("迁移任务")
                .font(.system(size: theme.bodySize, weight: .bold))
                .foregroundStyle(theme.text)

            StudioRow(label: "任务ID") {
                Text(migrateTaskId)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
            }

            StudioRow(label: "目标节点") {
                Picker("选择节点", selection: $migrateTargetNode) {
                    Text("请选择").tag("")
                    ForEach(engine.nodes, id: \.id) { node in
                        Text("\(node.name) (\(node.status.rawValue))").tag(node.id)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: theme.spacingM) {
                FusionButton("取消", icon: "xmark", style: .secondary, size: .regular) {
                    showMigrateSheet = false
                }
                FusionButton("确认迁移", icon: "arrow.right.circle", style: .primary, size: .regular,
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
                    Text(tab.rawValue)
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
            MetricStripCard(icon: "list.bullet.clipboard", label: "总任务", value: "\(engine.tasks.count)", subtitle: "全部任务")
            MetricStripCard(icon: "play.circle", label: "运行中", value: "\(engine.tasks.filter { $0.status == .running }.count)", subtitle: "正在执行", dotColor: theme.greenDot)
            MetricStripCard(icon: "exclamationmark.triangle", label: "失败", value: "\(engine.tasks.filter { $0.status == .failed }.count)", subtitle: "需要关注", dotColor: theme.redDot)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingM)
    }

    private var taskListSection: some View {
        ListGroup {
            StudioSectionHeader(title: "任务列表 (\(filteredTasks.count))")

            HStack(spacing: theme.spacingS) {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.textTertiary)
                TextField("搜索任务...", text: $searchText)
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
                        Button("取消任务") {
                            Task { try? await engine.cancelTask(taskId: task.id) }
                        }
                        Button("降级任务") {
                            Task { try? await engine.degradeTask(taskId: task.id) }
                        }
                        Button("迁移任务") {
                            migrateTaskId = task.id
                            migrateTargetNode = ""
                            showMigrateSheet = true
                        }
                    }
                    if task.status == .failed {
                        Button("重试") {
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
                Text("暂无\(selectedTab.rawValue)任务")
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
}
