// Callers: ModuleDetailView routing.
// Affected API: TaskQueueView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import Foundation
import SwiftUI
import Combine

// MARK: - 任务状态

enum TaskStatus: String, Codable {
    case pending   = "pending"
    case running   = "running"
    case paused    = "paused"
    case completed = "completed"
    case failed    = "failed"
    case cancelled = "cancelled"

    var color: Color {
        switch self {
        case .pending:   return .gray
        case .running:   return .blue
        case .paused:    return .orange
        case .completed: return .green
        case .failed:    return .red
        case .cancelled: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .pending:   return "clock"
        case .running:   return "play.circle.fill"
        case .paused:    return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed:    return "xmark.circle.fill"
        case .cancelled: return "minus.circle"
        }
    }

    var localizedName: String {
        switch self {
        case .pending:   return I18nManager.shared.t(.tq_status_pending)
        case .running:   return I18nManager.shared.t(.tq_status_running)
        case .paused:    return I18nManager.shared.t(.tq_status_paused)
        case .completed: return I18nManager.shared.t(.tq_status_completed)
        case .failed:    return I18nManager.shared.t(.tq_status_failed)
        case .cancelled: return I18nManager.shared.t(.tq_status_cancelled)
        }
    }
}

enum TaskType: String, Codable, CaseIterable {
    case inference  = "inference"
    case compile    = "compile"
    case export     = "export"
    case simulation = "simulation"
    case batch      = "batch"
    case download   = "download"

    var icon: String {
        switch self {
        case .inference:  return "bolt"
        case .compile:    return "hammer"
        case .export:     return "square.and.arrow.up"
        case .simulation: return "gearshape.2"
        case .batch:      return "square.stack.3d.forward.dottedline"
        case .download:   return "icloud.and.arrow.down"
        }
    }

    var localizedName: String {
        switch self {
        case .inference:  return I18nManager.shared.t(.tq_type_inference)
        case .compile:    return I18nManager.shared.t(.tq_type_compile)
        case .export:     return I18nManager.shared.t(.tq_type_export)
        case .simulation: return I18nManager.shared.t(.tq_type_simulation)
        case .batch:      return I18nManager.shared.t(.tq_type_batch)
        case .download:   return I18nManager.shared.t(.tq_type_download)
        }
    }
}

// MARK: - 任务项

struct TaskItem: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var type: TaskType
    var status: TaskStatus
    var progress: Double          // 0.0 ~ 1.0
    var progressLabel: String     // "45/100 tokens"
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var errorMessage: String?
    var subtasks: [SubTask]       // 子任务列表
    var result: [String: String]? // 任务结果

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TaskItem, rhs: TaskItem) -> Bool {
        lhs.id == rhs.id
    }

    struct SubTask: Identifiable, Hashable, Codable {
        let id: String
        var name: String
        var status: TaskStatus
        var progress: Double

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: SubTask, rhs: SubTask) -> Bool {
            lhs.id == rhs.id
        }
    }

    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? Date()
        return end.timeIntervalSince(start)
    }

    var formattedDuration: String {
        guard let d = duration else { return "--" }
        if d < 60 { return "\(Int(d))s" }
        if d < 3600 { return "\(Int(d / 60))m \(Int(d.truncatingRemainder(dividingBy: 60)))s" }
        return "\(Int(d / 3600))h \(Int((d.truncatingRemainder(dividingBy: 3600)) / 60))m"
    }
}

// MARK: - 任务管理器（增强版）

class TaskManager: ObservableObject {
    static let shared = TaskManager()

    @Published var tasks: [TaskItem] = []
    @Published var showCompleted = true
    @Published var showCancelled = false

    private let queue = DispatchQueue(label: "com.fusion-studio.task", qos: .utility)
    private let storage = UserDefaults.standard
    private let storageKey = "fusion_studio_tasks"
    private var activeTasks: Set<String> = []

    var activeCount: Int { tasks.filter { $0.status == .running }.count }
    var queueCount: Int { tasks.filter { $0.status == .pending }.count }
    var completedCount: Int { tasks.filter { $0.status == .completed }.count }
    var failedCount: Int { tasks.filter { $0.status == .failed }.count }

    var filteredTasks: [TaskItem] {
        tasks.filter { task in
            switch task.status {
            case .completed: return showCompleted
            case .cancelled: return showCancelled
            default:         return true
            }
        }
    }

    init() {
        loadPersistedTasks()
    }

    // MARK: - 任务操作

    /// 提交新任务
    @discardableResult
    func submit(title: String, type: TaskType, subtasks: [String] = []) -> String {
        let id = UUID().uuidString.prefix(8).lowercased()
        let task = TaskItem(
            id: String(id),
            title: title,
            type: type,
            status: .pending,
            progress: 0,
            progressLabel: I18nManager.shared.t(.tq_pl_waiting),
            createdAt: Date(),
            subtasks: subtasks.enumerated().map { i, name in
                TaskItem.SubTask(id: "sub-\(i)", name: name, status: .pending, progress: 0)
            }
        )
        DispatchQueue.main.async {
            self.tasks.append(task)
            self.persistTasks()
        }
        return String(id)
    }

    /// 开始任务
    func start(_ id: String) {
        update(id) { task in
            task.status = .running
            task.startedAt = Date()
            task.progressLabel = I18nManager.shared.t(.tq_pl_starting)
        }
    }

    /// 更新进度
    func updateProgress(_ id: String, progress: Double, label: String) {
        update(id) { task in
            task.progress = min(max(progress, 0), 1)
            task.progressLabel = label
        }
    }

    /// 暂停任务
    func pause(_ id: String) {
        update(id) { task in
            guard task.status == .running else { return }
            task.status = .paused
        }
    }

    /// 恢复任务
    func resume(_ id: String) {
        update(id) { task in
            guard task.status == .paused else { return }
            task.status = .running
        }
    }

    /// 取消任务
    func cancel(_ id: String) {
        update(id) { task in
            guard task.status == .pending || task.status == .running || task.status == .paused else { return }
            task.status = .cancelled
            task.completedAt = Date()
        }
    }

    /// 完成任务
    func complete(_ id: String, result: [String: String]? = nil) {
        update(id) { task in
            task.status = .completed
            task.progress = 1.0
            task.completedAt = Date()
            task.progressLabel = I18nManager.shared.t(.tq_pl_done)
            task.result = result
        }
    }

    /// 标记失败
    func fail(_ id: String, error: String) {
        update(id) { task in
            task.status = .failed
            task.completedAt = Date()
            task.errorMessage = error
        }
    }

    /// 更新子任务进度
    func updateSubTask(_ taskId: String, subTaskId: String, status: TaskStatus, progress: Double) {
        update(taskId) { task in
            guard let idx = task.subtasks.firstIndex(where: { $0.id == subTaskId }) else { return }
            task.subtasks[idx].status = status
            task.subtasks[idx].progress = progress
            // 自动计算总进度
            let total = Double(task.subtasks.count)
            let done = task.subtasks.reduce(0.0) { $0 + $1.progress }
            task.progress = total > 0 ? done / total : 0
            task.progressLabel = "\(Int(task.progress * 100))%"
        }
    }

    /// 清除已完成/已取消的任务
    func clearCompleted() {
        tasks.removeAll { $0.status == .completed || $0.status == .cancelled }
        persistTasks()
    }

    /// 清除所有任务
    func clearAll() {
        tasks.removeAll()
        persistTasks()
    }

    // MARK: - 内部方法

    private func update(_ id: String, block: @escaping (inout TaskItem) -> Void) {
        DispatchQueue.main.async {
            guard let idx = self.tasks.firstIndex(where: { $0.id == id }) else { return }
            block(&self.tasks[idx])
            self.persistTasks()
            self.objectWillChange.send()
        }
    }

    // MARK: - 持久化

    private func persistTasks() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let data = try? JSONEncoder().encode(self.tasks) {
                self.storage.set(data, forKey: self.storageKey)
            }
        }
    }

    private func loadPersistedTasks() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let data = self.storage.data(forKey: self.storageKey),
                  let tasks = try? JSONDecoder().decode([TaskItem].self, from: data) else { return }
            DispatchQueue.main.async {
                self.tasks = tasks
            }
        }
    }
}

// MARK: - 任务队列视图（增强版）

struct TaskQueueView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var manager = TaskManager.shared
    @State private var selectedTask: TaskItem?
    @State private var showClearAlert = false
    @State private var filterType: TaskType?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Label(I18nManager.shared.t(.tq_title), systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Text(I18nManager.shared.tf(.tq_active_queue, manager.activeCount, manager.queueCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 统计栏
            HStack(spacing: 16) {
                StatBadge(count: manager.activeCount, label: I18nManager.shared.t(.tq_stat_running), color: .blue)
                StatBadge(count: manager.queueCount, label: I18nManager.shared.t(.tq_stat_queued), color: .gray)
                StatBadge(count: manager.completedCount, label: I18nManager.shared.t(.tq_stat_completed), color: .green)
                StatBadge(count: manager.failedCount, label: I18nManager.shared.t(.tq_stat_failed), color: .red)
                Spacer()
                Toggle(I18nManager.shared.t(.tq_toggle_completed), isOn: $manager.showCompleted)
                    .controlSize(.small)
                    .toggleStyle(.checkbox)
                Toggle(I18nManager.shared.t(.tq_toggle_cancelled), isOn: $manager.showCancelled)
                    .controlSize(.small)
                    .toggleStyle(.checkbox)
                Button(I18nManager.shared.t(.tq_clear)) { showClearAlert = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(manager.tasks.isEmpty)
            }
            .font(.caption)

            // 任务列表
            if manager.filteredTasks.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(I18nManager.shared.t(.tq_empty))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                List(selection: $selectedTask) {
                    ForEach(manager.filteredTasks) { task in
                        TaskRowView(task: task)
                            .tag(task)
                            .contextMenu {
                                if task.status == .running {
                                    Button(I18nManager.shared.t(.tq_pause)) { manager.pause(task.id) }
                                }
                                if task.status == .paused {
                                    Button(I18nManager.shared.t(.tq_resume)) { manager.resume(task.id) }
                                }
                                if task.status == .pending || task.status == .running || task.status == .paused {
                                    Button(I18nManager.shared.t(.tq_cancel), role: .destructive) { manager.cancel(task.id) }
                                }
                                if task.status == .completed || task.status == .failed || task.status == .cancelled {
                                    Button(I18nManager.shared.t(.tq_delete)) {
                                        manager.tasks.removeAll { $0.id == task.id }
                                    }
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .frame(minHeight: 100)
            }
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(12)
        .alert(I18nManager.shared.t(.tq_clear_title), isPresented: $showClearAlert) {
            Button(I18nManager.shared.t(.tq_clear_completed), action: { manager.clearCompleted() })
            Button(I18nManager.shared.t(.tq_clear_all), role: .destructive, action: { manager.clearAll() })
            Button(I18nManager.shared.t(.tq_cancel), role: .cancel) {}
        } message: {
            Text(I18nManager.shared.t(.tq_clear_confirm))
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
    }
}

struct StatBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .fontWeight(.medium)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 任务行

struct TaskRowView: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: 10) {
            // 状态图标
            Image(systemName: task.status.icon)
                .foregroundColor(task.status.color)
                .frame(width: 20)

            // 任务信息
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(task.status == .running ? .semibold : .regular)
                    Spacer()
                    Text(task.type.localizedName)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(3)
                }

                HStack(spacing: 8) {
                    // 进度条
                    if task.status == .running || task.status == .paused {
                        ProgressView(value: task.progress)
                            .progressViewStyle(.linear)
                            .tint(task.status.color)
                            .frame(width: 120)
                    }

                    Text(task.progressLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if task.status == .completed || task.status == .failed {
                        Text(task.formattedDuration)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // 子任务进度
                if !task.subtasks.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(task.subtasks.prefix(5)) { sub in
                            Circle()
                                .fill(sub.status.color)
                                .frame(width: 6, height: 6)
                        }
                        if task.subtasks.count > 5 {
                            Text("+\(task.subtasks.count - 5)")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 4) {
                if task.status == .running {
                    Button(action: { TaskManager.shared.pause(task.id) }) {
                        Image(systemName: "pause.fill")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                if task.status == .paused {
                    Button(action: { TaskManager.shared.resume(task.id) }) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                if task.status == .pending || task.status == .running || task.status == .paused {
                    Button(action: { TaskManager.shared.cancel(task.id) }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(task.status == .running ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - 详情行组件

struct TaskDetailRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}

// MARK: - 任务详情

struct TaskDetailView: View {
    let task: TaskItem
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: task.status.icon)
                    .foregroundColor(task.status.color)
                    .font(.title2)
                Text(task.title)
                    .font(.title2)
                    .bold()
                Spacer()
                Button(I18nManager.shared.t(.tq_close)) { dismiss() }
                    .buttonStyle(.borderedProminent)
            }

            Divider()

            // 基本信息
            GroupBox(I18nManager.shared.t(.tq_gb_basic)) {
                VStack(alignment: .leading, spacing: 6) {
                    TaskDetailRow(I18nManager.shared.t(.tq_lbl_task_id), task.id)
                    TaskDetailRow(I18nManager.shared.t(.tq_lbl_type), task.type.localizedName)
                    TaskDetailRow(I18nManager.shared.t(.tq_lbl_status), task.status.localizedName)
                    TaskDetailRow(I18nManager.shared.t(.tq_lbl_created), task.createdAt.formatted(date: .numeric, time: .shortened))
                    if let start = task.startedAt {
                        TaskDetailRow(I18nManager.shared.t(.tq_lbl_started), start.formatted(date: .numeric, time: .shortened))
                    }
                    if let _ = task.startedAt {
                        TaskDetailRow(I18nManager.shared.t(.tq_lbl_duration), task.formattedDuration)
                    }
                }
                .padding(8)
            }

            // 进度
            GroupBox(I18nManager.shared.t(.tq_gb_progress)) {
                VStack(spacing: 8) {
                    ProgressView(value: task.progress)
                        .tint(task.status.color)
                    Text(I18nManager.shared.tf(.tq_progress_label, Int(task.progress * 100), task.progressLabel))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            // 子任务
            if !task.subtasks.isEmpty {
                GroupBox(I18nManager.shared.t(.tq_gb_subtasks)) {
                    ForEach(task.subtasks) { sub in
                        HStack {
                            Image(systemName: sub.status.icon)
                                .foregroundColor(sub.status.color)
                                .frame(width: 16)
                            Text(sub.name)
                                .font(.subheadline)
                            Spacer()
                            ProgressView(value: sub.progress)
                                .frame(width: 60)
                            Text("\(Int(sub.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 36)
                        }
                        .padding(.vertical, 2)
                    }
                    .padding(8)
                }
            }

            // 错误信息
            if let error = task.errorMessage {
                GroupBox(I18nManager.shared.t(.tq_gb_error)) {
                    Text(error)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(8)
                }
            }

            // 结果
            if let result = task.result {
                GroupBox(I18nManager.shared.t(.tq_gb_result)) {
                    ForEach(Array(result.keys.sorted()), id: \.self) { key in
                        DetailRow(key, result[key] ?? "")
                    }
                    .padding(8)
                }
            }
        }
        .padding()
        .frame(width: 420, height: 500)
    }
}

// MARK: - 模拟任务演示

struct TaskDemoView: View {
    @StateObject private var manager = TaskManager.shared
    @State private var demoRunning = false

    var body: some View {
        VStack(spacing: 12) {
            TaskQueueView()

            Divider()

            HStack {
                Button(I18nManager.shared.t(.tq_demo_inference)) {
                    let id = manager.submit(title: I18nManager.shared.t(.tq_demo_inference_title), type: .inference, subtasks: [I18nManager.shared.t(.tq_demo_sub_load_model), I18nManager.shared.t(.tq_demo_sub_process_prompt), I18nManager.shared.t(.tq_demo_sub_gen_response)])
                    simulateTask(id)
                }
                .buttonStyle(.borderedProminent)
                .disabled(demoRunning)

                Button(I18nManager.shared.t(.tq_demo_batch_export)) {
                    manager.submit(title: I18nManager.shared.tf(.tq_demo_export_title, 3), type: .export, subtasks: [I18nManager.shared.tf(.tq_demo_export_page, 1), I18nManager.shared.tf(.tq_demo_export_page, 2), I18nManager.shared.tf(.tq_demo_export_page, 3)])
                }
                .disabled(demoRunning)

                Button(I18nManager.shared.t(.tq_demo_download)) {
                    let id = manager.submit(title: I18nManager.shared.t(.tq_demo_download_title), type: .download, subtasks: [I18nManager.shared.tf(.tq_demo_dl_shard, 1, 4), I18nManager.shared.tf(.tq_demo_dl_shard, 2, 4), I18nManager.shared.tf(.tq_demo_dl_shard, 3, 4), I18nManager.shared.t(.tq_demo_dl_merge)])
                    simulateDownload(id)
                }
                .disabled(demoRunning)
            }
        }
        .padding()
    }

    private func simulateTask(_ id: String) {
        demoRunning = true
        let manager = TaskManager.shared
        manager.start(id)

        var step = 0
        Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { timer in
            step += 1
            let progress = min(Double(step) / 10.0, 1.0)
            manager.updateProgress(id, progress: progress, label: "\(step * 10)%")
            manager.updateSubTask(id, subTaskId: "sub-0", status: step <= 3 ? .running : .completed, progress: step <= 3 ? Double(step)/3.0 : 1.0)
            manager.updateSubTask(id, subTaskId: "sub-1", status: step > 3 ? (step <= 6 ? .running : .completed) : .pending, progress: step > 3 ? min(Double(step - 3) / 3.0, 1.0) : 0)
            manager.updateSubTask(id, subTaskId: "sub-2", status: step > 6 ? .running : .pending, progress: step > 6 ? min(Double(step - 6) / 4.0, 1.0) : 0)

            if progress >= 1.0 {
                manager.complete(id, result: ["tokens": "256", "latency": "1.2s", "model": "Qwen3.5 9B 4bit"])
                timer.invalidate()
                demoRunning = false
            }
        }
    }

    private func simulateDownload(_ id: String) {
        demoRunning = true
        let manager = TaskManager.shared
        manager.start(id)

        var step = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            step += 1
            let progress = min(Double(step) / 20.0, 1.0)
            manager.updateProgress(id, progress: progress, label: "\(Int(progress * 100))% - 1.2 MB/s")

            if step <= 5 {
                manager.updateSubTask(id, subTaskId: "sub-0", status: .running, progress: Double(step) / 5.0)
            } else if step <= 10 {
                manager.updateSubTask(id, subTaskId: "sub-0", status: .completed, progress: 1.0)
                manager.updateSubTask(id, subTaskId: "sub-1", status: .running, progress: Double(step - 5) / 5.0)
            } else if step <= 15 {
                manager.updateSubTask(id, subTaskId: "sub-1", status: .completed, progress: 1.0)
                manager.updateSubTask(id, subTaskId: "sub-2", status: .running, progress: Double(step - 10) / 5.0)
            } else {
                manager.updateSubTask(id, subTaskId: "sub-2", status: .completed, progress: 1.0)
                manager.updateSubTask(id, subTaskId: "sub-3", status: .running, progress: Double(step - 15) / 5.0)
            }

            if progress >= 1.0 {
                manager.complete(id, result: ["size": "5.2 GB", "path": "~/.fusion-mlx/models/qwen3.5-9b-4bit", "duration": "\(step)s"])
                timer.invalidate()
                demoRunning = false
            }
        }
    }
}