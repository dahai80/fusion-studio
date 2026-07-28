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
                MLXOptimizerView()
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
            case .rag:
                RAGPipelineView()
            case .memory:
                MemoryView()
            case .planner:
                PlannerView()
            case .deploy:
                DeployView()
            case .operations:
                OperationsView()
            case .eduK12:
                EduK12View()
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

// Refactored DesignView: 3-panel HSplitView layout per Phase 1 plan.
// Callers: SectionContentView routes to DesignView when Design module is active.
// Affected API: DesignView (replaced WebViewContainer with DesignChatPanel + DesignPreviewView + info panel).
// Data schemas: reads DesignBridge.currentArtifactCode/Title/Type; DesignPreviewView.PreviewDeviceMode.
// User instruction: "按照你的方案和优先级启动落地"

struct DesignView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var designBridge: DesignBridge

    @State private var deviceMode: PreviewDeviceMode = .desktop

    var body: some View {
        HSplitView {
            DesignChatPanel()

            DesignPreviewView(
                htmlContent: $designBridge.currentArtifactCode,
                deviceMode: deviceMode
            )
            .frame(minWidth: 400, idealWidth: 600)

            designInfoPanel
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)
        }
        .background(theme.contentBg)
    }

    // Callers: DesignView body; Affected API: designInfoPanel (tabbed: 属性 + Design System);
    // Data schemas: InfoPanelTab enum, DesignTokenPanel; User instruction: Task #33 Design Token 系统
    @State private var infoPanelTab: InfoPanelTab = .properties

    private var designInfoPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: theme.spacingS) {
                ForEach(InfoPanelTab.allCases, id: \.self) { tab in
                    Button(action: { infoPanelTab = tab }) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10))
                            Text(tab.rawValue)
                                .font(.system(size: theme.captionSize, weight: .medium))
                        }
                        .foregroundStyle(infoPanelTab == tab ? theme.accentText : theme.textSecondary)
                        .padding(.horizontal, theme.spacingS)
                        .padding(.vertical, theme.spacingXS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(infoPanelTab == tab ? theme.accent : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(theme.spacingS)

            Rectangle().fill(theme.separator).frame(height: 1)

            Group {
                switch infoPanelTab {
                case .properties:
                    propertiesContent
                case .tokens:
                    DesignTokenPanel()
                }
            }
        }
        .background(theme.surfaceElevated)
    }

    private var propertiesContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                if designBridge.currentArtifactTitle.isEmpty {
                    VStack(spacing: theme.spacingS) {
                        Image(systemName: "info.circle")
                            .font(.system(size: theme.iconL))
                            .foregroundStyle(theme.textTertiary)
                        Text("发送设计请求后\n查看属性信息")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    artifactInfoSection
                    deviceModeSection
                    codeStatsSection
                }
            }
            .padding(theme.spacingM)
        }
    }

    private var artifactInfoSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("Artifact")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            HStack {
                Text("标题")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text(designBridge.currentArtifactTitle)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
            }

            HStack {
                Text("类型")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text(designBridge.currentArtifactType.uppercased())
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
        }
    }

    private var deviceModeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("预览设备")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: theme.spacingS) {
                ForEach(PreviewDeviceMode.allCases, id: \.self) { mode in
                    Button(action: { deviceMode = mode }) {
                        Image(systemName: mode.icon)
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(deviceMode == mode ? theme.accent : theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacingXS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(deviceMode == mode ? theme.accent.opacity(0.15) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(mode.label)
                }
            }
        }
    }

    private var codeStatsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("代码统计")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            let code = designBridge.currentArtifactCode
            HStack {
                Text("行数")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text("\(code.filter { $0 == "\n" }.count + 1)")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
            }

            HStack {
                Text("字符")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text("\(code.count)")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
            }
        }
    }
}

// Callers: ModuleDetailView.designInfoPanel; Affected API: InfoPanelTab enum (new);
// Data schemas: 2 cases with rawValue + icon; User instruction: Task #33
enum InfoPanelTab: String, CaseIterable {
    case properties = "属性"
    case tokens = "Design System"
    var icon: String {
        switch self {
        case .properties: return "info.circle"
        case .tokens: return "paintpalette"
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