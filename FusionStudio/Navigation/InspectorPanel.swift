// Callers: ContentView three-column layout.
// Affected API: InspectorPanel (280pt right inspector with context switching).
// Data schemas: InspectorContext enum (from AppState).
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import os.log

private let inspectorLog = Logger(subsystem: "com.fusion.studio", category: "InspectorPanel")

struct InspectorPanel: View {
    @EnvironmentObject var navState: NavigationState
    @EnvironmentObject var uiPanelState: UIPanelState
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
                    uiPanelState.isInspectorVisible = false
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
                switch uiPanelState.inspectorContext {
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
                    // Callers: ContentView InspectorPanel, DesignCanvasView node.select → DesignInspectorState → AppState.inspectorContext
                    // Affected API: InspectorPanel switch on .node context, DesignInspectorView for design section
                    // Data schemas: InspectorContext.node(id), AppState.activeSection
                    if navState.activeSection == .design {
                        DesignInspectorView()
                    } else {
                        EmptyView()
                    }
                case .clusterTask(let id):
                    EmptyView()
                }
            }
            .padding(theme.spacingM)
        }
    }

    private var titleForContext: String {
        switch uiPanelState.inspectorContext {
        case .none: return "Inspector"
        case .agent(let id): return "Agent"
        case .dagNode(let id): return "Node"
        case .task(let id): return "Task"
        case .settings: return "Settings"
        case .custom(let title): return title
        case .node: return navState.activeSection == .design ? "样式检查器" : "节点"
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
