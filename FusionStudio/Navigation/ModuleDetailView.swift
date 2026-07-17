import SwiftUI

struct ModuleDetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.selectedModule {
            case .dashboard:
                DashboardView()
            case .design:
                DesignView()
            case .code:
                CodeView()
            case .simulation:
                SimulationView()
            case .modelHub:
                ModelHubView()
            case .multimodal:
                MultiModalView()
            case .training:
                TrainingView()
            case .cli:
                CLIView()
            case .doc:
                DocView()
            case .kb:
                KBView()
            case .bench:
                BenchView()
            case .desk:
                DeskView()
            case .dataTools:
                DataToolsView()
            case .agent:
                AgentStudioView()
            case .plugin:
                PluginView()
            case .security:
                SecurityView()
            case .analytics:
                AnalyticsDashboardView()
            case .collab:
                CollaborateView()
            case .tuning:
                AutoTuningView()
            case .external:
                ExternalIntegrationsView()
            case .docgen:
                DocGeneratorView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 各模块占位视图（后续逐步替换为真实实现）

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("控制台")
                    .font(.largeTitle)
                    .bold()

                // 环境状态卡片
                EnvironmentHealthCard()

                // 任务队列
                TaskQueueView()

                // 硬件监控
                HardwareMonitorView()
            }
            .padding()
        }
    }
}

struct DesignView: View {
    var body: some View {
        WebViewContainer(url: "http://localhost:8080")
            .overlay {
                if !isServiceRunning {
                    ServiceNotRunningView(serviceName: "Fusion-Design")
                }
            }
    }

    private var isServiceRunning: Bool { true }
}

struct CodeView: View {
    var body: some View {
        VStack(spacing: 0) {
            CodeEditorView()
            Divider()
            TerminalView()
                .frame(height: 200)
        }
    }
}

// MARK: - 辅助组件

struct ServiceNotRunningView: View {
    let serviceName: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("\(serviceName) 服务未启动")
                .font(.title2)
            Text("请先在「控制台」中启动服务")
                .foregroundColor(.secondary)
        }
    }
}