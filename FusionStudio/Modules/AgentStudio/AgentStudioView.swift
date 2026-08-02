import SwiftUI
import Combine
import os.log

struct AgentStudioView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @EnvironmentObject private var bridge: AgentBridge
    @StateObject private var screenContext = ScreenContextManager()
    @StateObject private var fileWatcher = FileWatcher()
    @StateObject private var toastManager = FusionToastManager()
    @State private var selectedTab: Int = 0
    @State private var showCreateAgent = false

    @Environment(\.studioTheme) var theme

    private var taskCount: Int {
        orchestrator.tasks.filter { $0.status != .completed }.count
    }

    private var unreadCount: Int {
        orchestrator.conversationLog.count
    }

    private var contextTitle: String {
        let ctx = screenContext.currentContext
        if ctx.activeAppName.isEmpty {
            return "Agent Studio"
        }
        return ctx.activeAppName
    }

    private var bridgeSubtitle: String {
        bridge.isConnected ? "Backend Connected" : "Backend Offline"
    }

    var body: some View {
        VStack(spacing: 0) {
            contextBar

            ScreenHeader(
                eyebrow: "Agent Studio",
                title: contextTitle,
                subtitle: bridgeSubtitle
            )

            FusionTabBar(selected: $selectedTab, tabs: [
                FusionTabItem(title: "Agents", icon: "person.2", badge: nil),
                FusionTabItem(title: "Tasks", icon: "checklist", badge: taskCount > 0 ? taskCount : nil),
                FusionTabItem(title: "Workflows", icon: "arrow.triangle.branch", badge: nil),
                FusionTabItem(title: "Dashboard", icon: "chart.bar", badge: nil),
                FusionTabItem(title: "Team", icon: "person.3", badge: nil),
                FusionTabItem(title: "Memory", icon: "brain.head.profile", badge: nil),
                FusionTabItem(title: "Safety", icon: "shield.lefthalf.filled", badge: nil),
                FusionTabItem(title: "Planner", icon: "list.number", badge: nil),
                FusionTabItem(title: "Connectors", icon: "link", badge: nil),
                FusionTabItem(title: "API Keys", icon: "key", badge: nil),
                FusionTabItem(title: "Styles", icon: "paintbrush", badge: nil),
                FusionTabItem(title: "Analytics", icon: "chart.xyaxis.line", badge: nil),
                FusionTabItem(title: "Alerts", icon: "bell", badge: nil),
                FusionTabItem(title: "Cron", icon: "clock.arrow.2.circlepath", badge: nil),
                FusionTabItem(title: "Hooks", icon: "point.3.connected.trianglepath.dotted", badge: nil),
                FusionTabItem(title: "RAG", icon: "doc.text.magnifyingglass", badge: nil),
                FusionTabItem(title: "Tools", icon: "wrench.and.screwdriver", badge: nil),
                FusionTabItem(title: "Skills", icon: "wand.and.stars", badge: nil),
                FusionTabItem(title: "Marketplace", icon: "bag", badge: nil),
                FusionTabItem(title: "Chat", icon: "bubble.left.and.bubble.right", badge: unreadCount > 0 ? unreadCount : nil),
            ])

            Divider().foregroundStyle(theme.separator)

            Group {
                switch selectedTab {
                case 0: AgentListView(toastManager: toastManager)
                case 1: AgentTaskListView(toastManager: toastManager)
                case 2: WorkflowListView(toastManager: toastManager)
                case 3: DashboardTabView(toastManager: toastManager)
                case 4: TeamTabView(toastManager: toastManager)
                case 5: MemoryTabView(toastManager: toastManager)
                case 6: SafetyTabView(toastManager: toastManager)
                case 7: PlannerTabView(toastManager: toastManager)
                case 8: ConnectorTabView(toastManager: toastManager)
                case 9: ApikeyTabView(toastManager: toastManager)
                case 10: StyleTabView(toastManager: toastManager)
                case 11: AnalyticsTabView(toastManager: toastManager)
                case 12: AlertTabView(toastManager: toastManager)
                case 13: CronTabView(toastManager: toastManager)
                case 14: HooksTabView(toastManager: toastManager)
                case 15: RagTabView(toastManager: toastManager)
                case 16: ToolsTabView(toastManager: toastManager)
                case 17: SkillsTabView(toastManager: toastManager)
                case 18: MarketplaceTabView(toastManager: toastManager)
                case 19: ConversationView(toastManager: toastManager)
                default: AgentListView(toastManager: toastManager)
                }
            }
            .animation(theme.springDefault, value: selectedTab)
        }
        .background(theme.windowBg)
        .toast(manager: toastManager)
        .sheet(isPresented: $showCreateAgent) {
            CreateAgentSheet { name, type, model, systemPrompt, temperature, maxTokens, tools, capabilities, safetyLevel, tags, soul, memory, agentsMd, graphId in
                createAgentViaBridge(name: name, type: type, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags, soul: soul, memory: memory, agentsMd: agentsMd)
            }
        }
        .onAppear {
            screenContext.startMonitoring()
            agentStudioLog.info("AgentStudioView appeared")
            Task {
                do {
                    try await bridge.checkHealth()
                    try await bridge.fetchAgents()
                    try await bridge.fetchGraphs()
                    agentStudioLog.info("Bridge health check passed, fetched \(bridge.agents.count) agents, \(bridge.graphs.count) graphs")
                } catch {
                    agentStudioLog.warning("Bridge connection failed on appear: \(error)")
                }
            }
        }
        .onDisappear {
            screenContext.stopMonitoring()
            fileWatcher.stopWatching()
            agentStudioLog.info("AgentStudioView disappeared")
        }
    }

    private var contextBar: some View {
        let ctx = screenContext.currentContext
        let hasContext = !ctx.activeAppName.isEmpty || !ctx.windowTitle.isEmpty
        return Group {
            if hasContext {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "contextualmenu.and.cursorarrow")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                    if !ctx.activeAppName.isEmpty {
                        Text(ctx.activeAppName)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                    if !ctx.windowTitle.isEmpty {
                        Text(ctx.windowTitle)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingXS)
                .background(theme.surfaceSecondary)
            }
        }
    }

    private func createAgentViaBridge(name: String, type: AgentType, model: String, systemPrompt: String, temperature: Double, maxTokens: Int, tools: [String], capabilities: [String], safetyLevel: String, tags: [String], soul: String, memory: String, agentsMd: String) {
        orchestrator.createAgent(name: name, type: type, model: model, systemPrompt: systemPrompt, temperature: temperature, maxTokens: maxTokens, tools: tools, capabilities: capabilities, safetyLevel: safetyLevel, tags: tags)
        toastManager.show(style: .success, title: "Agent Created", message: "\(name) is ready locally")

        Task {
            do {
                let _ = try await bridge.agentCreate(
                    name: name,
                    model: model.isEmpty ? type.defaultModel : model,
                    systemPrompt: systemPrompt.isEmpty ? type.defaultSystemPrompt : systemPrompt,
                    temperature: temperature,
                    maxTokens: maxTokens,
                    tools: tools,
                    capabilities: capabilities,
                    safetyLevel: safetyLevel,
                    tags: tags,
                    soul: soul,
                    memory: memory,
                    agentsMd: agentsMd
                )
                try await bridge.fetchAgents()
                agentStudioLog.info("Created agent via bridge: \(name)")
                toastManager.show(style: .success, title: "Backend Synced", message: "\(name) persisted to backend")
            } catch {
                agentStudioLog.error("Failed to create agent via bridge: \(error)")
                toastManager.show(style: .warning, title: "Backend Sync", message: "Agent created locally but backend sync failed")
            }
        }
    }
}
