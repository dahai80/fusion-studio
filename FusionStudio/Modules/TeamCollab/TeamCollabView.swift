// Callers: ModuleDetailView routes `case .teamCollab: TeamCollabView()`; driven by AppState.selectedModule.
// Affected API: TeamCollabView (3-pane container), TeamCollabArea enum (8 cases), 8 area views,
//   shared components StatTile/AgentAvatar/AgentStatusPill/PatternCard/CircuitBar.
// Data schemas: reads TeamCollabStore (@StateObject) -> SwarmAgent/TaskDelegation/HandoffRecord/
//   PlazaChannel/PlazaMessage/FMStats/OrchestrationPattern/SubGraphInfo (defined in TeamCollabModels.swift).
// User instruction: "帮我用 UI/UX Pro Max 为 fusion-agent-studio的团队协作管理相关能力 设计一套完整的 macOS 原生风格GUI…三栏布局：侧边导航 + 主工作区 + 右侧属性面板…玻璃态+轻微拟物，符合 Apple Human Interface Guidelines"

import SwiftUI
import os.log

private let teamViewLog = Logger(subsystem: "com.fusion.studio", category: "TeamCollabView")

enum TeamCollabArea: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case agents = "TeamAgents"
    case orchestration = "Orchestration"
    case channels = "Channels"
    case delegations = "Delegations"
    case monitor = "Monitor"
    case health = "Health"
    case subGraphs = "SubGraphs"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .overview: return I18nManager.shared.t(.tc_area_overview)
        case .agents: return I18nManager.shared.t(.tc_area_agents)
        case .orchestration: return I18nManager.shared.t(.tc_area_orchestration)
        case .channels: return I18nManager.shared.t(.tc_area_channels)
        case .delegations: return I18nManager.shared.t(.tc_area_delegations)
        case .monitor: return I18nManager.shared.t(.tc_area_monitor)
        case .health: return I18nManager.shared.t(.tc_area_health)
        case .subGraphs: return I18nManager.shared.t(.tc_area_subgraphs)
        }
    }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .agents: return "person.3.fill"
        case .orchestration: return "flowchart.fill"
        case .channels: return "bubble.left.and.bubble.right.fill"
        case .delegations: return "arrow.triangle.turn.up.right.diamond.fill"
        case .monitor: return "waveform.path.ecg"
        case .health: return "heart.text.square.fill"
        case .subGraphs: return "rectangle.connected.to.line.below.fill"
        }
    }
}

struct TeamCollabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme
    @StateObject private var store = TeamCollabStore()
    @State private var area: TeamCollabArea = .overview

    var body: some View {
        HStack(spacing: 0) {
            areaRail
            Rectangle().fill(theme.separator).frame(width: 1)
            areaContent
        }
        .background(theme.contentBg)
        .environmentObject(store)
    }

    private var areaRail: some View {
        VStack(spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: theme.iconL, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(I18nManager.shared.t(.tc_title))
                    .font(.system(size: theme.titleSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingL)
            .padding(.bottom, theme.spacingM)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(TeamCollabArea.allCases) { a in
                        areaRow(a)
                    }
                }
                .padding(.horizontal, theme.spacingS)
                .padding(.bottom, theme.spacingL)
            }
        }
        .frame(width: 200)
        .background(.ultraThinMaterial)
    }

    private func areaRow(_ a: TeamCollabArea) -> some View {
        let isActive = area == a
        return Button(action: {
            withAnimation(theme.springSnappy) { area = a }
            teamViewLog.info("Area selected: \(a.rawValue)")
        }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: a.icon)
                    .font(.system(size: theme.iconM, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? theme.accent : theme.textSecondary)
                    .frame(width: theme.iconL)
                Text(a.localizedName)
                    .font(.system(size: theme.smallTextSize, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? theme.text : theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.12) : Color.clear)
            )
            .overlay(alignment: .leading) {
                if isActive {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(theme.accent)
                        .frame(width: 3, height: 18)
                        .padding(.leading, 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var areaContent: some View {
        switch area {
        case .overview: OverviewArea()
        case .agents: AgentsArea()
        case .orchestration: OrchestrationArea()
        case .channels: ChannelsArea()
        case .delegations: DelegationsArea()
        case .monitor: MonitorArea()
        case .health: HealthArea()
        case .subGraphs: SubGraphsArea()
        }
    }
}

// MARK: - Shared components

struct StatTile: View {
    @Environment(\.studioTheme) private var theme
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconM, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value)
                .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text)
            Text(label)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .strokeBorder(theme.groupBorder, lineWidth: 0.5)
        )
    }
}

struct AgentAvatar: View {
    let name: String
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

struct AgentStatusPill: View {
    @Environment(\.studioTheme) private var theme
    let status: AgentStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(status.dot).frame(width: 6, height: 6)
            Text(status.label)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(status.dot.opacity(0.12))
        )
    }
}

struct CircuitBar: View {
    @Environment(\.studioTheme) private var theme
    let state: CircuitBreakerState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(state.isOpen ? I18nManager.shared.t(.tc_circuit_open) : I18nManager.shared.t(.tc_circuit_closed))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(state.isOpen ? theme.redDot : theme.greenDot)
                Spacer()
                Text("\(state.failures)/\(state.threshold)")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.rowSep).frame(height: 4)
                    Capsule()
                        .fill(state.isOpen ? theme.redDot : theme.accent)
                        .frame(width: geo.size.width * min(1, state.progress), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

struct RouterCard: View {
    @Environment(\.studioTheme) private var theme
    let router: IndependentRouter
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack {
                    Image(systemName: router.icon)
                        .font(.system(size: theme.iconL, weight: .semibold))
                        .foregroundStyle(isActive ? theme.accentText : theme.accent)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: theme.iconM))
                            .foregroundStyle(theme.accent)
                    }
                }
                Text(router.label)
                    .font(.system(size: theme.smallTextSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(router.desc)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(theme.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .fill(isActive ? theme.accent : theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .strokeBorder(isActive ? theme.accent : theme.groupBorder, lineWidth: isActive ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PatternCard: View {
    @Environment(\.studioTheme) private var theme
    let pattern: OrchestrationPattern
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack {
                    Image(systemName: pattern.icon)
                        .font(.system(size: theme.iconL, weight: .semibold))
                        .foregroundStyle(isActive ? theme.accentText : theme.accent)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: theme.iconM))
                            .foregroundStyle(theme.accent)
                    }
                }
                Text(pattern.label)
                    .font(.system(size: theme.smallTextSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(pattern.desc)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(theme.spacingM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .fill(isActive ? theme.accent : theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .strokeBorder(isActive ? theme.accent : theme.groupBorder, lineWidth: isActive ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overview

struct OverviewArea: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var store: TeamCollabStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                ScreenHeader(eyebrow: "Team Collaboration", title: I18nManager.shared.t(.tc_ov_eyebrow_title), subtitle: I18nManager.shared.t(.tc_ov_subtitle))

                HStack(spacing: theme.spacingM) {
                    StatTile(icon: "checkmark.circle.fill", value: "\(store.onlineCount)/\(store.agents.count)", label: I18nManager.shared.t(.tc_ov_stat_online), tint: .green)
                    StatTile(icon: "exclamationmark.octagon.fill", value: "\(store.trippedCount)", label: I18nManager.shared.t(.tc_ov_stat_tripped), tint: .red)
                    StatTile(icon: "arrow.triangle.turn.up.right.circle.fill", value: "\(store.runningDelegations)", label: I18nManager.shared.t(.tc_ov_stat_running), tint: .orange)
                    StatTile(icon: "pause.circle.fill", value: "\(store.suspendedChannels)", label: I18nManager.shared.t(.tc_ov_stat_suspended), tint: .gray)
                }

                HStack(alignment: .top, spacing: theme.spacingM) {
                    activePatternCard
                    healthMiniCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                FusionCard(header: I18nManager.shared.t(.tc_ov_recent_delegations), headerIcon: "list.bullet.clipboard") {
                    VStack(spacing: 0) {
                        ForEach(store.delegations.prefix(4)) { d in
                            delegationRow(d)
                            if d.id != store.delegations.prefix(4).last?.id {
                                Rectangle().fill(theme.rowSep).frame(height: 0.5)
                            }
                        }
                    }
                }
            }
            .padding(theme.spacingL)
        }
    }

    private var activePatternCard: some View {
        FusionCard(header: I18nManager.shared.t(.tc_ov_active_pattern), headerIcon: "flowchart.fill") {
            HStack(spacing: theme.spacingM) {
                Image(systemName: store.activePattern.icon)
                    .font(.system(size: theme.iconXL, weight: .semibold))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.activePattern.label)
                        .font(.system(size: theme.titleSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text(store.activePattern.desc)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var healthMiniCard: some View {
        FusionCard(header: I18nManager.shared.t(.tc_ov_health_summary), headerIcon: "heart.text.square") {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                healthLine(I18nManager.shared.t(.tc_ov_health_online), store.onlineCount, .green)
                healthLine(I18nManager.shared.t(.tc_ov_health_busy), store.agents.filter { $0.status == .busy }.count, .orange)
                healthLine(I18nManager.shared.t(.tc_ov_health_tripped), store.trippedCount, .red)
                healthLine(I18nManager.shared.t(.tc_ov_health_offline), store.offlineCount, .gray)
            }
        }
    }

    private func healthLine(_ label: String, _ count: Int, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
            Spacer()
            Text("\(count)").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
        }
    }

    private func delegationRow(_ d: TaskDelegation) -> some View {
        HStack(spacing: theme.spacingM) {
            Text(d.createdAt).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary).frame(width: 40, alignment: .leading)
            Text(d.task).font(.system(size: theme.footnoteSize, weight: .medium)).foregroundStyle(theme.text).lineLimit(1)
            Spacer()
            Text("\(d.delegator) -> \(d.delegatee)")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
            delegationPill(d.status)
        }
        .padding(.vertical, theme.spacingS)
    }

    private func delegationPill(_ s: DelegationStatus) -> some View {
        let tint: Color = {
            switch s {
            case .done: return .green
            case .running: return .blue
            case .pending: return .gray
            case .failed: return .red
            case .escalated: return .orange
            }
        }()
        return Text(s.label)
            .font(.system(size: theme.captionSize, weight: .medium))
            .foregroundColor(tint)
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.12)))
    }
}

// MARK: - Agents

struct AgentsArea: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var store: TeamCollabStore
    @State private var selectedId: String? = "p1a2b3c4"

    var body: some View {
        HStack(spacing: 0) {
            agentsList
            Rectangle().fill(theme.separator).frame(width: 1)
            detailPanel
        }
    }

    private var agentsList: some View {
        ScrollView {
            VStack(spacing: theme.spacingS) {
                ForEach(store.agents) { agent in
                    agentCard(agent)
                }
            }
            .padding(theme.spacingL)
        }
        .frame(maxWidth: .infinity)
    }

    private func agentCard(_ agent: SwarmAgent) -> some View {
        let isSelected = selectedId == agent.id
        return Button(action: {
            selectedId = agent.id
            teamViewLog.info("Agent selected: \(agent.id)")
        }) {
            HStack(spacing: theme.spacingM) {
                AgentAvatar(name: agent.name, color: agent.identityColor, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(agent.name).font(.system(size: theme.smallTextSize, weight: .semibold)).foregroundStyle(theme.text)
                        Text(agent.roleLabel).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                        Spacer()
                        AgentStatusPill(status: agent.status)
                    }
                    Text(agent.capabilities.joined(separator: " · "))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(theme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .fill(isSelected ? theme.accent.opacity(0.08) : theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? theme.accent : theme.groupBorder, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var detailPanel: some View {
        if let id = selectedId, let agent = store.agent(byId: id) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingL) {
                    HStack(spacing: theme.spacingM) {
                        AgentAvatar(name: agent.name, color: agent.identityColor, size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(agent.name).font(.system(size: theme.titleSize, weight: .bold)).foregroundStyle(theme.text)
                            Text("\(agent.roleLabel) · \(agent.model)").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                            AgentStatusPill(status: agent.status)
                        }
                        Spacer()
                    }

                    detailSection(I18nManager.shared.t(.tc_agent_id)) { Text(agent.id).font(.system(size: theme.footnoteSize, design: .monospaced)).foregroundStyle(theme.textTertiary) }
                    detailSection(I18nManager.shared.t(.tc_agent_capabilities)) {
                        FlowChips(items: agent.capabilities, tint: agent.identityColor)
                    }
                    detailSection(I18nManager.shared.t(.tc_agent_handoff)) {
                        FlowChips(items: agent.handoffTargets.map { store.agentName(byId: $0) }, tint: theme.accent)
                    }
                    detailSection(I18nManager.shared.t(.tc_agent_task_stats)) {
                        HStack(spacing: theme.spacingL) {
                            statPair(I18nManager.shared.t(.tc_agent_done), "\(agent.tasksDone)")
                            statPair(I18nManager.shared.t(.tc_agent_active), "\(agent.tasksActive)")
                            statPair(I18nManager.shared.t(.tc_agent_max_hops), "\(agent.maxHops)")
                        }
                    }
                    detailSection(I18nManager.shared.t(.tc_agent_circuit)) { CircuitBar(state: agent.circuit) }
                }
                .padding(theme.spacingL)
            }
            .frame(width: 320)
            .background(theme.surfaceSecondary)
        } else {
            emptyDetail
        }
    }

    private func detailSection<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(title).font(.system(size: theme.captionSize, weight: .semibold)).foregroundStyle(theme.textTertiary)
            content()
        }
    }

    private func statPair(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: theme.bodySize, weight: .semibold, design: .rounded)).foregroundStyle(theme.text)
            Text(label).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "person.crop.circle.badge.questionmark").font(.system(size: 36)).foregroundStyle(theme.textTertiary)
            Text(I18nManager.shared.t(.tc_agent_empty)).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textTertiary)
        }
        .frame(width: 320)
        .background(theme.surfaceSecondary)
    }
}

struct FlowChips: View {
    @Environment(\.studioTheme) private var theme
    let items: [String]
    let tint: Color

    var body: some View {
        HStack(spacing: theme.spacingS) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(tint)
                    .padding(.horizontal, theme.spacingS)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(tint.opacity(0.12)))
            }
        }
    }
}

// MARK: - Orchestration

struct OrchestrationArea: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var store: TeamCollabStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                ScreenHeader(eyebrow: I18nManager.shared.t(.tc_orch_eyebrow), title: I18nManager.shared.t(.tc_orch_title), subtitle: I18nManager.shared.t(.tc_orch_subtitle))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: theme.spacingM), GridItem(.flexible(), spacing: theme.spacingM), GridItem(.flexible(), spacing: theme.spacingM)], spacing: theme.spacingM) {
                    ForEach(OrchestrationPattern.allCases) { p in
                        PatternCard(pattern: p, isActive: store.activePattern == p) {
                            withAnimation(theme.springSnappy) { store.activePattern = p }
                            teamViewLog.info("Pattern activated: \(p.rawValue)")
                        }
                    }
                }

                FusionCard(header: I18nManager.shared.t(.tc_orch_pattern_info), headerIcon: "info.circle") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        Text(store.activePattern.label)
                            .font(.system(size: theme.bodySize, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Text(store.activePattern.desc)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                        Text(String(format: I18nManager.shared.t(.tc_orch_impl), store.activePattern.rawValue))
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingM)
                }

                ScreenHeader(eyebrow: I18nManager.shared.t(.tc_router_eyebrow), title: I18nManager.shared.t(.tc_router_title), subtitle: I18nManager.shared.t(.tc_router_subtitle))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: theme.spacingM), GridItem(.flexible(), spacing: theme.spacingM), GridItem(.flexible(), spacing: theme.spacingM)], spacing: theme.spacingM) {
                    ForEach(IndependentRouter.allCases) { r in
                        RouterCard(router: r, isActive: store.activeRouter == r) {
                            withAnimation(theme.springSnappy) { store.activeRouter = r }
                            teamViewLog.info("Router activated: \(r.rawValue)")
                        }
                    }
                }

                FusionCard(header: I18nManager.shared.t(.tc_router_info), headerIcon: "info.circle") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        Text(store.activeRouter.label)
                            .font(.system(size: theme.bodySize, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Text(store.activeRouter.desc)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(theme.spacingM)
                }
            }
            .padding(theme.spacingL)
        }
    }
}

// MARK: - Channels (Plaza)

struct ChannelsArea: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var store: TeamCollabStore
    @State private var selectedChannel: String? = "ch-prd77"

    var body: some View {
        HStack(spacing: 0) {
            channelList
            Rectangle().fill(theme.separator).frame(width: 1)
            messagePanel
        }
    }

    private var channelList: some View {
        ScrollView {
            VStack(spacing: theme.spacingS) {
                ForEach(store.channels) { ch in
                    channelRow(ch)
                }
            }
            .padding(theme.spacingL)
        }
        .frame(width: 240)
        .background(theme.surfaceSecondary)
    }

    private func channelRow(_ ch: PlazaChannel) -> some View {
        let isSelected = selectedChannel == ch.id
        return Button(action: { selectedChannel = ch.id }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: ch.isSuspended ? "pause.circle.fill" : "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(ch.isSuspended ? theme.redDot : theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ch.name).font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text).lineLimit(1)
                    Text(String(format: I18nManager.shared.t(.tc_ch_rounds), "\(ch.currentRound)", "\(ch.maxRounds)", "\(ch.participants.count)"))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
            }
            .padding(theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isSelected ? theme.accent.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var messagePanel: some View {
        if let id = selectedChannel, let ch = store.channels.first(where: { $0.id == id }) {
            VStack(spacing: 0) {
                channelHeader(ch)
                Divider().background(theme.separator)
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        ForEach(ch.messages) { msg in
                            messageRow(msg)
                        }
                    }
                    .padding(theme.spacingL)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func channelHeader(_ ch: PlazaChannel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ch.name).font(.system(size: theme.titleSize, weight: .semibold)).foregroundStyle(theme.text)
                Text(ch.participants.joined(separator: " · "))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if ch.isSuspended {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(I18nManager.shared.t(.tc_ch_suspended))
                }
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.redDot)
                .padding(.horizontal, theme.spacingS)
                .padding(.vertical, 4)
                .background(Capsule().fill(theme.redDot.opacity(0.12)))
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(I18nManager.shared.t(.tc_ch_rounds_label)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                Text("\(ch.currentRound)/\(ch.maxRounds)").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(ch.currentRound >= ch.maxRounds ? theme.redDot : theme.text)
            }
        }
        .padding(theme.spacingL)
    }

    private func messageRow(_ msg: PlazaMessage) -> some View {
        HStack(alignment: .top, spacing: theme.spacingM) {
            let isHuman = msg.sender == "human"
            AgentAvatar(name: msg.sender, color: isHuman ? .gray : senderColor(msg.sender), size: 32)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: theme.spacingS) {
                    Text(msg.sender).font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(isHuman ? theme.textTertiary : theme.text)
                    Text(msg.timestamp).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                    Text("R\(msg.round)")
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(theme.accent.opacity(0.12)))
                }
                mentionText(msg.content)
            }
            Spacer()
        }
    }

    private func mentionText(_ text: String) -> some View {
        let parts = text.components(separatedBy: "@")
        return HStack(spacing: 0) {
            ForEach(parts.indices, id: \.self) { idx in
                let part = parts[idx]
                if idx == 0 {
                    Text(part).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.text)
                } else {
                    let nameLen = part.firstIndex(where: { $0.isWhitespace || $0.isPunctuation }) ?? part.endIndex
                    Text("@\(part[..<nameLen])")
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text(String(part[nameLen...]))
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.text)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func senderColor(_ name: String) -> Color {
        store.agents.first { $0.name == name }?.identityColor ?? .blue
    }
}

// MARK: - Delegations + Handoff timeline

struct DelegationsArea: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var store: TeamCollabStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                ScreenHeader(eyebrow: I18nManager.shared.t(.tc_del_eyebrow), title: I18nManager.shared.t(.tc_del_title), subtitle: I18nManager.shared.t(.tc_del_subtitle))

                FusionCard(header: I18nManager.shared.t(.tc_del_tasks), headerIcon: "arrow.triangle.turn.up.right.circle") {
                    VStack(spacing: 0) {
                        ForEach(store.delegations) { d in
                            delegationDetailRow(d)
                            if d.id != store.delegations.last?.id {
                                Rectangle().fill(theme.rowSep).frame(height: 0.5)
                            }
                        }
                    }
                }

                FusionCard(header: I18nManager.shared.t(.tc_del_handoff), headerIcon: "arrow.right.arrow.left.circle") {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(store.handoffs.enumerated()), id: \.element.id) { idx, h in
                            HStack(alignment: .top, spacing: theme.spacingM) {
                                VStack(spacing: 0) {
                                    Circle().fill(theme.accent).frame(width: 10, height: 10)
                                    if idx < store.handoffs.count - 1 {
                                        Rectangle().fill(theme.rowSep).frame(width: 1.5, height: 36)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("\(h.fromAgent) -> \(h.toAgent)")
                                            .font(.system(size: theme.footnoteSize, weight: .semibold))
                                            .foregroundStyle(theme.text)
                                        Spacer()
                                        Text("hop \(h.hopCount)").font(.system(size: theme.captionSize, design: .monospaced)).foregroundStyle(theme.accent)
                                        Text(h.timestamp).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                                    }
                                    Text(h.summary).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                                    Text("task \(h.taskId)").font(.system(size: theme.captionSize, design: .monospaced)).foregroundStyle(theme.textTertiary)
                                }
                            }
                            .padding(.vertical, theme.spacingS)
                        }
                    }
                    .padding(theme.spacingM)
                }
            }
            .padding(theme.spacingL)
        }
    }

    private func delegationDetailRow(_ d: TaskDelegation) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Text(d.task).font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                Text(d.createdAt).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
            }
            HStack(spacing: theme.spacingL) {
                metaPair(I18nManager.shared.t(.tc_del_meta_delegator), "\(d.delegator) -> \(d.delegatee)")
                metaPair(I18nManager.shared.t(.tc_del_meta_trigger), d.triggerCondition)
                metaPair(I18nManager.shared.t(.tc_del_meta_deliverable), d.deliverable)
            }
            HStack {
                Text("hop \(d.hopCount)").font(.system(size: theme.captionSize, design: .monospaced)).foregroundStyle(theme.accent)
                Spacer()
                Text(d.result.isEmpty ? d.status.label : d.result)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(d.status == .done ? .green : (d.status == .escalated ? .orange : theme.textSecondary))
            }
        }
        .padding(.vertical, theme.spacingM)
    }

    private func metaPair(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
            Text(value).font(.system(size: theme.captionSize, weight: .medium)).foregroundStyle(theme.textSecondary)
        }
    }
}

// MARK: - Monitor (FMProtocol)

struct MonitorArea: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var store: TeamCollabStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                ScreenHeader(eyebrow: I18nManager.shared.t(.tc_mon_eyebrow), title: I18nManager.shared.t(.tc_mon_title), subtitle: I18nManager.shared.t(.tc_mon_subtitle))

                HStack(spacing: theme.spacingM) {
                    StatTile(icon: "paperplane.fill", value: "\(store.fmStats.sent)", label: I18nManager.shared.t(.tc_mon_sent), tint: .blue)
                    StatTile(icon: "tray.fill", value: "\(store.fmStats.received)", label: I18nManager.shared.t(.tc_mon_received), tint: .green)
                    StatTile(icon: "arrow.triangle.branch", value: "\(store.fmStats.routed)", label: I18nManager.shared.t(.tc_mon_routed), tint: .teal)
                }

                HStack(spacing: theme.spacingM) {
                    StatTile(icon: "doc.on.doc", value: "\(store.fmStats.droppedDedup)", label: I18nManager.shared.t(.tc_mon_dedup), tint: .gray)
                    StatTile(icon: "hand.raised.fill", value: "\(store.fmStats.circuitBlocked)", label: I18nManager.shared.t(.tc_mon_blocked), tint: .red)
                    StatTile(icon: "repeat", value: "\(store.fmStats.maxRounds)", label: I18nManager.shared.t(.tc_mon_max_rounds), tint: .orange)
                }

                FusionCard(header: I18nManager.shared.t(.tc_mon_traffic), headerIcon: "chart.bar.fill") {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        fmBar(I18nManager.shared.t(.tc_mon_sent), store.fmStats.sent, .blue)
                        fmBar(I18nManager.shared.t(.tc_mon_received), store.fmStats.received, .green)
                        fmBar(I18nManager.shared.t(.tc_mon_routed), store.fmStats.routed, .teal)
                        fmBar(I18nManager.shared.t(.tc_mon_dedup), store.fmStats.droppedDedup, .gray)
                        fmBar(I18nManager.shared.t(.tc_mon_blocked), store.fmStats.circuitBlocked, .red)
                    }
                    .padding(theme.spacingM)
                }

                FusionCard(header: I18nManager.shared.t(.tc_mon_route_priority), headerIcon: "arrow.up.arrow.down.circle") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        routeLine("1", I18nManager.shared.t(.tc_mon_route_mention), "MentionRouter.route_by_mention")
                        routeLine("2", I18nManager.shared.t(.tc_mon_route_p2p), "FMProtocol.send -> recipient")
                        routeLine("3", I18nManager.shared.t(.tc_mon_route_turn), "TurnManager.next_turn (skip tripped)")
                    }
                    .padding(theme.spacingM)
                }
            }
            .padding(theme.spacingL)
        }
    }

    private func fmBar(_ label: String, _ value: Int, _ color: Color) -> some View {
        let maxVal = max(store.fmStats.sent, 1)
        return HStack(spacing: theme.spacingM) {
            Text(label).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary).frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(value) / CGFloat(maxVal), height: 10)
            }
            .frame(height: 10)
            Text("\(value)").font(.system(size: theme.captionSize, weight: .medium, design: .rounded)).foregroundStyle(theme.text).frame(width: 36, alignment: .trailing)
        }
    }

    private func routeLine(_ idx: String, _ title: String, _ impl: String) -> some View {
        HStack(spacing: theme.spacingS) {
            Text(idx).font(.system(size: theme.captionSize, weight: .bold, design: .rounded)).foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.text)
                Text(impl).font(.system(size: theme.captionSize, design: .monospaced)).foregroundStyle(theme.textTertiary)
            }
        }
    }
}

// MARK: - Health (Circuit Breakers)

struct HealthArea: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var store: TeamCollabStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                ScreenHeader(eyebrow: I18nManager.shared.t(.tc_health_eyebrow), title: I18nManager.shared.t(.tc_health_title), subtitle: I18nManager.shared.t(.tc_health_subtitle))

                HStack(spacing: theme.spacingM) {
                    StatTile(icon: "checkmark.shield.fill", value: "\(store.agents.filter { !$0.circuit.isOpen }.count)", label: I18nManager.shared.t(.tc_health_stat_closed), tint: .green)
                    StatTile(icon: "exclamationmark.shield.fill", value: "\(store.agents.filter { $0.circuit.isOpen }.count)", label: I18nManager.shared.t(.tc_health_stat_open), tint: .red)
                    StatTile(icon: "arrow.up.right.square.fill", value: "\(store.delegations.filter { $0.status == .escalated }.count)", label: I18nManager.shared.t(.tc_health_stat_escalated), tint: .orange)
                }

                FusionCard(header: I18nManager.shared.t(.tc_health_agent_circuit), headerIcon: "shield.lefthalf.filled") {
                    VStack(spacing: theme.spacingM) {
                        ForEach(store.agents) { agent in
                            HStack(spacing: theme.spacingM) {
                                AgentAvatar(name: agent.name, color: agent.identityColor, size: 36)
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(agent.name).font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
                                        AgentStatusPill(status: agent.status)
                                        Spacer()
                                        if agent.circuit.isOpen {
                                            Text(String(format: I18nManager.shared.t(.tc_health_cooldown), Int(agent.circuit.resetInSeconds)))
                                                .font(.system(size: theme.captionSize, weight: .medium))
                                                .foregroundStyle(theme.redDot)
                                        }
                                    }
                                    CircuitBar(state: agent.circuit)
                                }
                            }
                            .padding(theme.spacingS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(agent.circuit.isOpen ? theme.redDot.opacity(0.06) : theme.surfacePrimary)
                            )
                        }
                    }
                    .padding(theme.spacingM)
                }
            }
            .padding(theme.spacingL)
        }
    }
}

// MARK: - SubGraphs

struct SubGraphsArea: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var store: TeamCollabStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                ScreenHeader(eyebrow: I18nManager.shared.t(.tc_sub_eyebrow), title: I18nManager.shared.t(.tc_sub_title), subtitle: I18nManager.shared.t(.tc_sub_subtitle))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: theme.spacingM), GridItem(.flexible(), spacing: theme.spacingM)], spacing: theme.spacingM) {
                    ForEach(store.subGraphs) { sg in
                        subGraphCard(sg)
                    }
                }
            }
            .padding(theme.spacingL)
        }
    }

    private func subGraphCard(_ sg: SubGraphInfo) -> some View {
        let statusColor: Color = {
            switch sg.status {
            case "active": return .green
            case "idle": return .gray
            default: return .orange
            }
        }()
        return VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: "rectangle.connected.to.line.below")
                    .font(.system(size: theme.iconL, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(sg.name).font(.system(size: theme.smallTextSize, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                Text(sg.status)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, theme.spacingS).padding(.vertical, 3)
                    .background(Capsule().fill(statusColor.opacity(0.12)))
            }
            HStack(spacing: theme.spacingL) {
                metaPair(I18nManager.shared.t(.tc_sub_nodes), "\(sg.nodeCount)")
                metaPair(I18nManager.shared.t(.tc_sub_edges), "\(sg.edgeCount)")
                metaPair(I18nManager.shared.t(.tc_sub_entry), sg.entryNode)
            }
            HStack {
                Image(systemName: "clock").font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                Text(String(format: I18nManager.shared.t(.tc_sub_last_run), sg.lastRun)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                Spacer()
                Text(sg.id).font(.system(size: theme.captionSize, design: .monospaced)).foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .strokeBorder(theme.groupBorder, lineWidth: 0.5)
        )
    }

    private func metaPair(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: theme.footnoteSize, weight: .semibold, design: .rounded)).foregroundStyle(theme.text)
            Text(label).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
        }
    }
}
