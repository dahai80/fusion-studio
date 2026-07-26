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
            case .clusterOverview:
                ClusterOverviewView()
            case .clusterTopology:
                ClusterTopologyView()
            case .taskMonitor:
                TaskMonitorView()
            case .alertCenter:
                AlertCenterView()
            case .nodeActions:
                NodeActionsView()
            case .submitTask:
                SubmitTaskView()
            case .taskProgress:
                TaskProgressView()
            case .routingStrategy:
                RoutingStrategyView()
            case .kvCache:
                KVCacheView()
            case .serviceWeb:
                ServiceWebView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 各模块占位视图（后续逐步替换为真实实现）

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.studioTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Fusion Studio", title: "Dashboard", subtitle: "Command center — health checks, tasks, and hardware monitoring.")

                ListGroup {
                    EnvironmentHealthCard()
                        .padding(14)
                }

                ListGroup {
                    TaskQueueView()
                        .padding(14)
                }

                ListGroup {
                    HardwareMonitorView()
                        .padding(14)
                }
            }
            .padding(.bottom, 20)
        }
        .background(theme.contentBg)
    }
}

struct DesignView: View {
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            WebViewContainer(url: "http://localhost:8080", isLoading: $isLoading, error: $loadError)

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("正在连接 Fusion-Design 服务...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                    Text("无法加载设计画布")
                        .font(.title2)
                        .bold()
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text("请确保 Fusion-Design 服务已启动 (localhost:8080)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadError = nil
                        isLoading = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
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