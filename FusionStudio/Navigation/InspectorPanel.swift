// Callers: ContentView three-column layout.
// Affected API: InspectorPanel (280pt right inspector with context switching).
// Data schemas: InspectorContext enum (from AppState).
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import os.log

private let inspectorLog = Logger(subsystem: "com.fusion.studio", category: "InspectorPanel")

struct InspectorPanel: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader
            Rectangle().fill(theme.separator).frame(height: 1)
            inspectorContent
        }
        .frame(width: 280)
        .background(theme.surfaceSecondary)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private var inspectorHeader: some View {
        HStack(spacing: theme.spacingS) {
            Text(titleForContext)
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)

            Spacer()

            Button(action: {
                withAnimation(theme.springSnappy) {
                    appState.isInspectorVisible = false
                }
            }) {
                Image(systemName: "sidebar.right")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(Color(red: 0, green: 122.0 / 255.0, blue: 1.0))
            }
            .buttonStyle(.plain)
            .help("Hide Inspector")
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(.ultraThinMaterial)
    }

    private var inspectorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                switch appState.inspectorContext {
                case .none:
                    emptyInspector
                case .agent(let id):
                    AgentInspectorContent(agentId: id)
                case .dagNode(let id):
                    DAGNodeInspectorContent(nodeId: id)
                case .task(let id):
                    TaskInspectorContent(taskId: id)
                case .settings:
                    SettingsInspectorContent()
                case .custom(let title):
                    CustomInspectorContent(title: title)
                case .node(let id):
                    NodeInspectorContent(nodeId: id)
                case .clusterTask(let id):
                    ClusterTaskInspectorContent(taskId: id)
                }
            }
            .padding(theme.spacingM)
        }
    }

    private var titleForContext: String {
        switch appState.inspectorContext {
        case .none: return "Inspector"
        case .agent(let id): return "Agent"
        case .dagNode(let id): return "Node"
        case .task(let id): return "Task"
        case .settings: return "Settings"
        case .custom(let title): return title
        case .node: return "节点"
        case .clusterTask: return "任务"
        }
    }

    private var emptyInspector: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text("No Selection")
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text("Select an element to inspect its properties")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing2XL)
    }
}

struct AgentInspectorContent: View {
    let agentId: String
    @Environment(\.studioTheme) private var theme

    var body: some View {
        inspectorSection("Agent") {
            inspectorField("ID", value: agentId)
            inspectorField("Status", value: "Active")
            inspectorField("Type", value: "LLM Agent")
        }
        inspectorSection("Configuration") {
            inspectorField("Model", value: "Fusion-MLX")
            inspectorField("Temperature", value: "0.7")
        }
    }
}

struct DAGNodeInspectorContent: View {
    let nodeId: String
    @Environment(\.studioTheme) private var theme

    var body: some View {
        inspectorSection("Node") {
            inspectorField("ID", value: nodeId)
            inspectorField("Type", value: "LLM")
        }
        inspectorSection("Properties") {
            inspectorField("Model", value: "Default")
        }
    }
}

struct TaskInspectorContent: View {
    let taskId: String
    @Environment(\.studioTheme) private var theme

    var body: some View {
        inspectorSection("Task") {
            inspectorField("ID", value: taskId)
            inspectorField("Status", value: "Pending")
        }
    }
}

struct SettingsInspectorContent: View {
    @Environment(\.studioTheme) private var theme

    var body: some View {
        inspectorSection("Quick Settings") {
            inspectorField("Theme", value: "Dark")
            inspectorField("Language", value: "中文")
        }
    }
}

struct CustomInspectorContent: View {
    let title: String
    @Environment(\.studioTheme) private var theme

    var body: some View {
        inspectorSection(title) {
            Text("Custom content")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
    }
}

struct NodeInspectorContent: View {
    let nodeId: String
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) private var theme

    @State private var metrics: LoadMetrics?
    @State private var isLoadingMetrics = false

    private var node: ClusterNode? {
        engine.nodes.first { $0.id == nodeId }
    }

    var body: some View {
        if let n = node {
            inspectorSection("节点信息") {
                inspectorField("ID", value: n.id)
                inspectorField("主机名", value: n.hostname)
                inspectorField("状态", value: n.status.rawValue)
                inspectorField("角色", value: n.role ?? "worker")
                inspectorField("IP", value: "\(n.ipAddress):\(n.port)")
            }
            inspectorSection("资源") {
                inspectorField("CPU", value: "\(n.cpuCores) 核")
                inspectorField("GPU", value: "\(n.gpuCores) 核")
                inspectorField("内存", value: String(format: "%.1f / %.0f GB", n.totalMemoryGB - n.availableMemoryGB, n.totalMemoryGB))
                inspectorField("内存占用", value: String(format: "%.0f%%", n.memoryUsageRatio * 100))
            }
            inspectorSection("任务") {
                inspectorField("活跃任务", value: "\(n.activeTasks) / \(n.maxTasks)")
                inspectorField("负载", value: String(format: "%.0f%%", n.taskLoadRatio * 100))
                inspectorField("评分", value: String(format: "%.2f", n.score))
            }
            if let m = metrics {
                inspectorSection("详细指标") {
                    inspectorField("CPU使用率", value: String(format: "%.1f%%", m.cpuPercent))
                    inspectorField("内存使用率", value: String(format: "%.1f%%", m.memoryPercent))
                    inspectorField("GPU使用率", value: String(format: "%.1f%%", m.gpuPercent))
                    inspectorField("队列长度", value: "\(m.queueLength)")
                }
            }
            FusionButton("刷新指标", icon: "arrow.clockwise", style: .ghost, size: .small,
                isLoading: isLoadingMetrics) {
                loadMetrics(nodeId: n.id)
            }
            .padding(.top, theme.spacingXS)
        } else {
            inspectorSection("节点") {
                Text("加载中...")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    private func loadMetrics(nodeId: String) {
        isLoadingMetrics = true
        engine.fetchNodeMetrics(nodeId: nodeId) { result in
            isLoadingMetrics = false
            switch result {
            case .success(let m):
                metrics = m
                inspectorLog.info("Node metrics loaded for \(nodeId)")
            case .failure(let error):
                inspectorLog.error("Metrics fetch failed: \(error.localizedDescription)")
            }
        }
    }
}

struct ClusterTaskInspectorContent: View {
    let taskId: String
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) private var theme

    private var task: ClusterTask? {
        engine.tasks.first { $0.id == taskId }
    }

    var body: some View {
        if let t = task {
            inspectorSection("任务信息") {
                inspectorField("ID", value: t.id)
                inspectorField("名称", value: t.name)
                inspectorField("模式", value: t.mode)
                inspectorField("状态", value: t.status.rawValue)
                inspectorField("模型", value: t.modelName)
                inspectorField("优先级", value: "\(t.priority ?? 5)")
            }
            inspectorSection("时间") {
                if let created = t.createdAt {
                    inspectorField("创建时间", value: formatTs(created))
                }
                if let started = t.startedAt {
                    inspectorField("开始时间", value: formatTs(started))
                }
                if let completed = t.completedAt {
                    inspectorField("完成时间", value: formatTs(completed))
                }
                if let created = t.createdAt, let completed = t.completedAt {
                    let elapsed = completed - created
                    inspectorField("耗时", value: formatDuration(elapsed))
                }
            }
            inspectorSection("分配") {
                if t.assignedNodes.isEmpty {
                    inspectorField("节点", value: "未分配")
                } else {
                    inspectorField("节点", value: t.assignedNodes.joined(separator: ", "))
                }
            }
            if let degraded = t.degradedFromModel {
                inspectorSection("降级") {
                    inspectorField("原模型", value: degraded)
                    inspectorField("降级到", value: t.modelName)
                    inspectorField("降级次数", value: "\(t.degradationCount ?? 0)")
                }
            }
        } else {
            inspectorSection("任务") {
                Text("加载中...")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    private func formatTs(_ ts: Double) -> String {
        let date = Date(timeIntervalSince1970: ts)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 { return String(format: "%.1f秒", seconds) }
        if seconds < 3600 { return String(format: "%.1f分钟", seconds / 60) }
        return String(format: "%.1f小时", seconds / 3600)
    }
}

private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color(red: 0, green: 122.0 / 255.0, blue: 1.0))
            .kerning(0.6)
        content()
    }
}

private func inspectorField(_ label: String, value: String) -> some View {
    HStack {
        Text(label)
            .font(.system(size: 12))
            .foregroundStyle(Color(white: 0.6))
        Spacer()
        Text(value)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(white: 0.85))
    }
}
