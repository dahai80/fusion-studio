import SwiftUI

struct ModuleDetailView: View {
    @EnvironmentObject var navState: NavigationState

    var body: some View {
        Group {
            switch navState.selectedModule {
            case .dashboard:
                DashboardView()
            case .design:
                DesignView()
            case .code:
                CodeView()
            // Callers: ModuleDetailView switch on appState.selectedModule.
            // Affected API: .simulation now renders SimulationWorkbenchView (was local SimulationView Metal demo).
            // Data schemas: Module.simulation. User instruction: "和~/fusion/fuison-simulation项目集成起来"
            case .simulation:
                SimulationWorkbenchView()
            case .modelHub:
                ModelHubMainView()
            case .multimodal:
                MultiModalView()
            case .training:
                TrainingView()
            case .cli:
                CLIView()
            case .doc:
                DocView()
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
            case .clusterSync:
                ClusterSyncView()
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
                RAGMainView()
            case .memory:
                MemoryView()
            case .planner:
                PlannerView()
            case .deploy:
                DeployView()
            case .operations:
                OperationsView()
            // Callers: ModuleDetailView routing. Affected API: verify.verify, budget.set/status. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
            case .eduK12:
                EduK12View()
            case .verification:
                VerificationView()
            case .tokenBudget:
                TokenBudgetView()
            case .safety:
                SafetyView()
            case .tools:
                ToolBrowserView()
            case .agentDashboard:
                AgentDashboardView()
            case .teamCollab:
                TeamCollabView()
            case .chat:
                UnifiedChatView()
            case .fusionProjects:
                ProjectModuleView()
            case .cowork:
                SpaceListView()
            case .artifactsRepo:
                ArtifactsRepositoryView()
            case .fsb:
                FSBWorkspaceView()
            // Callers: SectionContentView routes via selectedModule. Affected API: ipc.agent*, AgentBridge.
            // Data schemas: AgentModel. User instruction: "按照GUI草图实现fusion-ai-agent"
            case .aiAgentDashboard:
                AIAgentDashboardView()
            case .aiAgentList:
                AIAgentListView()
            case .aiAgentChat:
                AIAgentChatView()
            case .aiAgentObserver:
                AIAgentObserverView()
            case .aiAgentKnowledgeBase:
                AIAgentKnowledgeBaseView()
            case .science:
                ScienceWorkbenchView()
            case .finance:
                FinanceWorkbenchView()
            case .health:
                HealthWorkbenchView()
            case .pluginConfig:
                PluginConfigView()
            case .pluginStatus:
                PluginStatusView()
            case .pluginToken:
                PluginTokenDashboard()
            case .pluginVram:
                PluginVramView()
            case .pluginLog:
                PluginLogViewer()
            case .pluginMcp:
                PluginMcpView()
            // Callers: ModuleDetailView switch on appState.selectedModule.
            // Affected API: .trainer renders TrainerView (RunManager GUI via trainer.* IPC).
            // Data schemas: TrainerRun/TrainerPreset/TrainerDataset/TrainerAdapter. User instruction: "continue Task" — Task #5 (#175)
            case .trainer:
                TrainerView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

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
                    UpstreamServiceStatusView()
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

                ListGroup {
                    ProfilerDashboard()
                        .padding(14)
                }

                ListGroup {
                    ProfilerAlertsView()
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

// Callers: SectionContentView routes to DesignView when Design module is active.
// Affected API: DesignView (added DesignCanvasView toggle with DesignCanvasMode),
//   DesignBridge (selectedNodeID binding), DesignCanvasView (wasm canvas).
// Data schemas: DesignCanvasMode enum (preview/canvas), BridgeCommand/BridgeEvent JSON.
// User instruction: "现在开始实施" — Task #5: Fusion-Studio 加载 wasm 画布

enum DesignCanvasMode: String, CaseIterable {
    case preview = "preview"
    case canvas = "canvas"

    var label: String {
        switch self {
        case .preview: return "Preview"
        case .canvas: return "Canvas"
        }
    }

    var icon: String {
        switch self {
        case .preview: return "safari"
        case .canvas: return "square.on.square"
        }
    }
}

struct DesignView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var designBridge: DesignBridge

    @State private var deviceMode: PreviewDeviceMode = .desktop
    @State private var canvasMode: DesignCanvasMode = .preview
    @State private var selectedNodeID: String?

    var body: some View {
        HSplitView {
            DesignChatPanel()

            canvasContent
                .frame(minWidth: 340, idealWidth: 600)

            designInfoPanel
                .frame(minWidth: 150, idealWidth: 260, maxWidth: 320)
        }
        .background(theme.contentBg)
    }

    private var canvasContent: some View {
        VStack(spacing: 0) {
            canvasModeBar
            switch canvasMode {
            case .preview:
                DesignPreviewView(
                    htmlContent: $designBridge.currentArtifactCode,
                    deviceMode: deviceMode
                )
            case .canvas:
                DesignCanvasView(
                    selectedNodeID: $selectedNodeID
                )
            }
        }
    }

    private var canvasModeBar: some View {
        HStack(spacing: theme.spacingS) {
            ForEach(DesignCanvasMode.allCases, id: \.self) { mode in
                Button(action: { canvasMode = mode }) {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10))
                        Text(mode.label)
                            .font(.system(size: theme.captionSize, weight: .medium))
                    }
                    .foregroundStyle(canvasMode == mode ? theme.accentText : theme.textSecondary)
                    .padding(.horizontal, theme.spacingS)
                    .padding(.vertical, theme.spacingXS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(canvasMode == mode ? theme.accent : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(mode == .preview ? "1" : "2", modifiers: .command)
            }
            Spacer()
            if canvasMode == .canvas {
                Button(action: { designBridge.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("z", modifiers: .command)
                .help("Undo (⌘Z)")
                Button(action: { designBridge.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .help("Redo (⇧⌘Z)")
            }
            if canvasMode == .canvas, let nodeID = selectedNodeID {
                Text("Node: \(nodeID)")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, theme.spacingXS)
        .background(theme.surfaceElevated)
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
                case .layers:
                    DesignLayersView(selectedNodeID: $selectedNodeID)
                case .tokens:
                    DesignTokenPanel()
                case .designSystems:
                    DesignSystemListView()
                case .lint:
                    DesignLintPanel()
                case .codegen:
                    CodegenTargetPanel()
                case .ecosystem:
                    EcosystemSyncPanel()
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
                    designThemeSection
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

    private var designThemeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("设计主题")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: theme.spacingS) {
                ForEach(["dark", "light"], id: \.self) { mode in
                    Button(action: { designBridge.switchTheme(mode) }) {
                        HStack(spacing: 4) {
                            Image(systemName: mode == "dark" ? "moon.fill" : "sun.max.fill")
                                .font(.system(size: 10))
                            Text(mode == "dark" ? "深色" : "浅色")
                                .font(.system(size: theme.captionSize, weight: .medium))
                        }
                        .foregroundStyle(designBridge.activeTheme == mode ? theme.accentText : theme.textSecondary)
                        .padding(.horizontal, theme.spacingS)
                        .padding(.vertical, theme.spacingXS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(designBridge.activeTheme == mode ? theme.accent : theme.groupBg)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// Callers: ModuleDetailView.designInfoPanel; Affected API: InfoPanelTab enum (new);
// Data schemas: 2 cases with rawValue + icon; User instruction: Task #33
enum InfoPanelTab: String, CaseIterable {
    case properties = "属性"
    case layers = "图层"
    case tokens = "Design System"
    case designSystems = "系统"
    case lint = "规范检查"
    case codegen = "代码导出"
    case ecosystem = "生态联动"
    var icon: String {
        switch self {
        case .properties: return "info.circle"
        case .layers: return "square.3.layers.3d"
        case .tokens: return "paintpalette"
        case .designSystems: return "square.stack.3d.up"
        case .lint: return "checkmark.shield"
        case .codegen: return "chevron.left.forwardslash.chevron.right"
        case .ecosystem: return "arrow.triangle.2.circlepath"
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