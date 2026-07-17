import Foundation
import SwiftUI
import Combine

// MARK: - 任务状态

enum TaskStatus: String, Codable {
    case pending   = "排队中"
    case running   = "运行中"
    case paused    = "已暂停"
    case completed = "已完成"
    case failed    = "失败"
    case cancelled = "已取消"

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
}

enum TaskType: String, Codable, CaseIterable {
    case inference  = "推理"
    case compile    = "编译"
    case export     = "导出"
    case simulation = "仿真"
    case batch      = "批量"
    case download   = "下载"

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
            progressLabel: "等待中",
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
            task.progressLabel = "启动中..."
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
            task.progressLabel = "完成"
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
    @StateObject private var manager = TaskManager.shared
    @State private var selectedTask: TaskItem?
    @State private var showClearAlert = false
    @State private var filterType: TaskType?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Label("任务队列", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Text("\(manager.activeCount) 活跃 / \(manager.queueCount) 排队")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 统计栏
            HStack(spacing: 16) {
                StatBadge(count: manager.activeCount, label: "运行中", color: .blue)
                StatBadge(count: manager.queueCount, label: "排队", color: .gray)
                StatBadge(count: manager.completedCount, label: "完成", color: .green)
                StatBadge(count: manager.failedCount, label: "失败", color: .red)
                Spacer()
                Toggle("完成", isOn: $manager.showCompleted)
                    .controlSize(.small)
                    .toggleStyle(.checkbox)
                Toggle("取消", isOn: $manager.showCancelled)
                    .controlSize(.small)
                    .toggleStyle(.checkbox)
                Button("清除") { showClearAlert = true }
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
                        Text("暂无任务")
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
                                    Button("暂停") { manager.pause(task.id) }
                                }
                                if task.status == .paused {
                                    Button("恢复") { manager.resume(task.id) }
                                }
                                if task.status == .pending || task.status == .running || task.status == .paused {
                                    Button("取消", role: .destructive) { manager.cancel(task.id) }
                                }
                                if task.status == .completed || task.status == .failed || task.status == .cancelled {
                                    Button("删除") {
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
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .alert("清除任务", isPresented: $showClearAlert) {
            Button("清除已完成", action: { manager.clearCompleted() })
            Button("清除全部", role: .destructive, action: { manager.clearAll() })
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要清除任务吗？")
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
                    Text(task.type.rawValue)
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
                Button("关闭") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }

            Divider()

            // 基本信息
            GroupBox("基本信息") {
                VStack(alignment: .leading, spacing: 6) {
                    TaskDetailRow("任务 ID", task.id)
                    TaskDetailRow("类型", task.type.rawValue)
                    TaskDetailRow("状态", task.status.rawValue)
                    TaskDetailRow("创建时间", task.createdAt.formatted(date: .numeric, time: .shortened))
                    if let start = task.startedAt {
                        TaskDetailRow("开始时间", start.formatted(date: .numeric, time: .shortened))
                    }
                    if let _ = task.startedAt {
                        TaskDetailRow("耗时", task.formattedDuration)
                    }
                }
                .padding(8)
            }

            // 进度
            GroupBox("进度") {
                VStack(spacing: 8) {
                    ProgressView(value: task.progress)
                        .tint(task.status.color)
                    Text("\(Int(task.progress * 100))% - \(task.progressLabel)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            // 子任务
            if !task.subtasks.isEmpty {
                GroupBox("子任务") {
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
                GroupBox("错误信息") {
                    Text(error)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(8)
                }
            }

            // 结果
            if let result = task.result {
                GroupBox("结果") {
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
                Button("添加推理任务") {
                    let id = manager.submit(title: "Qwen3.5 推理", type: .inference, subtasks: ["加载模型", "处理提示词", "生成回应"])
                    simulateTask(id)
                }
                .buttonStyle(.borderedProminent)
                .disabled(demoRunning)

                Button("添加批量导出") {
                    manager.submit(title: "导出设计稿 (3个)", type: .export, subtasks: ["导出 Page 1", "导出 Page 2", "导出 Page 3"])
                }
                .disabled(demoRunning)

                Button("添加下载任务") {
                    let id = manager.submit(title: "下载 Qwen3.5 9B", type: .download, subtasks: ["下载分片 1/4", "下载分片 2/4", "下载分片 3/4", "合并文件"])
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
                manager.complete(id, result: ["size": "5.2 GB", "path": "~/.fusion/models/qwen3.5-9b-4bit", "duration": "\(step)s"])
                timer.invalidate()
                demoRunning = false
            }
        }
    }
}