import SwiftUI

/// 全局任务队列视图
struct TaskQueueView: View {
    @EnvironmentObject var taskManager: TaskManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("任务队列", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Text("\(taskManager.activeCount) 活跃 / \(taskManager.queueCount) 排队")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if taskManager.tasks.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无任务")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(taskManager.tasks.prefix(5)) { task in
                    TaskRowView(task: task)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct TaskRowView: View {
    let task: TaskItem

    var body: some View {
        HStack {
            Image(systemName: task.type.icon)
                .foregroundColor(task.status.color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                Text(task.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if task.status == .running {
                ProgressView()
                    .controlSize(.small)
                Text("\(Int(task.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40)
            }
            Text(task.status.text)
                .font(.caption)
                .foregroundColor(task.status.color)
                .frame(width: 60)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(task.status == .running ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - 任务数据模型

class TaskManager: ObservableObject {
    @Published var tasks: [TaskItem] = []

    var activeCount: Int { tasks.filter { $0.status == .running }.count }
    var queueCount: Int { tasks.filter { $0.status == .pending }.count }

    func submit(_ task: TaskItem) {
        tasks.append(task)
    }

    func cancel(_ id: UUID) {
        tasks.removeAll { $0.id == id }
    }
}

struct TaskItem: Identifiable {
    let id = UUID()
    let title: String
    let type: TaskType
    var status: TaskStatus
    var progress: Double

    enum TaskType: String {
        case inference = "推理"
        case compile = "编译"
        case export = "导出"
        case simulation = "仿真"
        case batch = "批量"

        var icon: String {
            switch self {
            case .inference:  return "bolt"
            case .compile:    return "hammer"
            case .export:     return "square.and.arrow.up"
            case .simulation: return "gearshape.2"
            case .batch:      return "square.stack.3d.forward.dottedline"
            }
        }
    }

    enum TaskStatus {
        case pending, running, completed, failed

        var color: Color {
            switch self {
            case .pending:   return .gray
            case .running:   return .blue
            case .completed: return .green
            case .failed:    return .red
            }
        }

        var text: String {
            switch self {
            case .pending:   return "排队中"
            case .running:   return "运行中"
            case .completed: return "已完成"
            case .failed:    return "失败"
            }
        }
    }
}