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
    case overview = "概览"
    case agents = "团队 Agents"
    case orchestration = "编排模式"
    case channels = "协作频道"
    case delegations = "任务委派"
    case monitor = "实时监控"
    case health = "健康熔断"
    case subGraphs = "子图注册"

    var id: String { rawValue }

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
                Text("团队协作")
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
                Text(a.rawValue)
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
                Text(state.isOpen ? "熔断开启" : "熔断关闭")
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
                ScreenHeader(eyebrow: "Team Collaboration", title: "协作总览", subtitle: "Agent 团队编排 · 蜂群委派 · 频道协商 · 熔断健康")

                HStack(spacing: theme.spacingM) {
                    StatTile(icon: "checkmark.circle.fill", value: "\(store.onlineCount)/\(store.agents.count)", label: "在线 Agents", tint: .green)
                    StatTile(icon: "exclamationmark.octagon.fill", value: "\(store.trippedCount)", label: "熔断 Agents", tint: .red)
                    StatTile(icon: "arrow.triangle.turn.up.right.circle.fill", value: "\(store.runningDelegations)", label: "执行中委派", tint: .orange)
                    StatTile(icon: "pause.circle.fill", value: "\(store.suspendedChannels)", label: "挂起频道", tint: .gray)
                }

                HStack(alignment: .top, spacing: theme.spacingM) {
                    activePatternCard
                    healthMiniCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                FusionCard(header: "最近委派", headerIcon: "list.bullet.clipboard") {
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
        FusionCard(header: "当前编排模式", headerIcon: "flowchart.fill") {
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
        FusionCard(header: "健康摘要", headerIcon: "heart.text.square") {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                healthLine("在线", store.onlineCount, .green)
                healthLine("繁忙", store.agents.filter { $0.status == .busy }.count, .orange)
                healthLine("熔断", store.trippedCount, .red)
                healthLine("离线", store.offlineCount, .gray)
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
                        Text(agent.role).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
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
                            Text("\(agent.role) · \(agent.model)").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                            AgentStatusPill(status: agent.status)
                        }
                        Spacer()
                    }

                    detailSection("Agent ID") { Text(agent.id).font(.system(size: theme.footnoteSize, design: .monospaced)).foregroundStyle(theme.textTertiary) }
                    detailSection("能力 Capabilities") {
                        FlowChips(items: agent.capabilities, tint: agent.identityColor)
                    }
                    detailSection("交接目标 Handoff Targets") {
                        FlowChips(items: agent.handoffTargets.map { store.agentName(byId: $0) }, tint: theme.accent)
                    }
                    detailSection("任务统计") {
                        HStack(spacing: theme.spacingL) {
                            statPair("已完成", "\(agent.tasksDone)")
                            statPair("进行中", "\(agent.tasksActive)")
                            statPair("最大跳数", "\(agent.maxHops)")
                        }
                    }
                    detailSection("熔断器 Circuit Breaker") { CircuitBar(state: agent.circuit) }
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
            Text("选择一个 Agent 查看详情").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textTertiary)
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
                ScreenHeader(eyebrow: "Orchestration Patterns", title: "编排模式", subtitle: "fusion-agent-studio MultiAgentOrchestrator 的 6 种协作模式")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: theme.spacingM), GridItem(.flexible(), spacing: theme.spacingM), GridItem(.flexible(), spacing: theme.spacingM)], spacing: theme.spacingM) {
                    ForEach(OrchestrationPattern.allCases) { p in
                        PatternCard(pattern: p, isActive: store.activePattern == p) {
                            withAnimation(theme.springSnappy) { store.activePattern = p }
                            teamViewLog.info("Pattern activated: \(p.rawValue)")
                        }
                    }
                }

                FusionCard(header: "模式说明", headerIcon: "info.circle") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        Text(store.activePattern.label)
                            .font(.system(size: theme.bodySize, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Text(store.activePattern.desc)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                        Text("对应实现: agent_runtime/orchestrator.py · \(store.activePattern.rawValue)()")
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingM)
                }

                ScreenHeader(eyebrow: "Independent Routers", title: "独立路由", subtitle: "SwarmRouter / Plaza / FMProtocol — 独立于 Orchestrator 的路由模式")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: theme.spacingM), GridItem(.flexible(), spacing: theme.spacingM), GridItem(.flexible(), spacing: theme.spacingM)], spacing: theme.spacingM) {
                    ForEach(IndependentRouter.allCases) { r in
                        RouterCard(router: r, isActive: store.activeRouter == r) {
                            withAnimation(theme.springSnappy) { store.activeRouter = r }
                            teamViewLog.info("Router activated: \(r.rawValue)")
                        }
                    }
                }

                FusionCard(header: "路由说明", headerIcon: "info.circle") {
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
                    Text("轮次 \(ch.currentRound)/\(ch.maxRounds) · \(ch.participants.count) 人")
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
                    Text("已熔断挂起")
                }
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.redDot)
                .padding(.horizontal, theme.spacingS)
                .padding(.vertical, 4)
                .background(Capsule().fill(theme.redDot.opacity(0.12)))
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("轮次").font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
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
                ScreenHeader(eyebrow: "Task Delegation", title: "任务委派", subtitle: "SwarmRouter 委派链 · 跳数受控 · 自动升级")

                FusionCard(header: "委派任务", headerIcon: "arrow.triangle.turn.up.right.circle") {
                    VStack(spacing: 0) {
                        ForEach(store.delegations) { d in
                            delegationDetailRow(d)
                            if d.id != store.delegations.last?.id {
                                Rectangle().fill(theme.rowSep).frame(height: 0.5)
                            }
                        }
                    }
                }

                FusionCard(header: "交接时间线 Handoff", headerIcon: "arrow.right.arrow.left.circle") {
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
                metaPair("委派", "\(d.delegator) -> \(d.delegatee)")
                metaPair("触发", d.triggerCondition)
                metaPair("交付物", d.deliverable)
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
                ScreenHeader(eyebrow: "FMProtocol Monitor", title: "实时监控", subtitle: "消息收发 · 去重 · 熔断拦截 · 轮转路由")

                HStack(spacing: theme.spacingM) {
                    StatTile(icon: "paperplane.fill", value: "\(store.fmStats.sent)", label: "已发送 sent", tint: .blue)
                    StatTile(icon: "tray.fill", value: "\(store.fmStats.received)", label: "已接收 received", tint: .green)
                    StatTile(icon: "arrow.triangle.branch", value: "\(store.fmStats.routed)", label: "已路由 routed", tint: .teal)
                }

                HStack(spacing: theme.spacingM) {
                    StatTile(icon: "doc.on.doc", value: "\(store.fmStats.droppedDedup)", label: "去重丢弃 dedup", tint: .gray)
                    StatTile(icon: "hand.raised.fill", value: "\(store.fmStats.circuitBlocked)", label: "熔断拦截 blocked", tint: .red)
                    StatTile(icon: "repeat", value: "\(store.fmStats.maxRounds)", label: "最大轮次 maxRounds", tint: .orange)
                }

                FusionCard(header: "消息流量分布", headerIcon: "chart.bar.fill") {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        fmBar("已发送", store.fmStats.sent, .blue)
                        fmBar("已接收", store.fmStats.received, .green)
                        fmBar("已路由", store.fmStats.routed, .teal)
                        fmBar("去重丢弃", store.fmStats.droppedDedup, .gray)
                        fmBar("熔断拦截", store.fmStats.circuitBlocked, .red)
                    }
                    .padding(theme.spacingM)
                }

                FusionCard(header: "路由优先级", headerIcon: "arrow.up.arrow.down.circle") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        routeLine("1", "@mention 指定目标", "MentionRouter.route_by_mention")
                        routeLine("2", "点对点 recipient", "FMProtocol.send -> recipient")
                        routeLine("3", "轮转下一跳", "TurnManager.next_turn (排除熔断)")
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
                ScreenHeader(eyebrow: "Circuit Breaker Health", title: "健康熔断", subtitle: "阈值 3 次失败即熔断 · 30s 半开重试 · 自动升级")

                HStack(spacing: theme.spacingM) {
                    StatTile(icon: "checkmark.shield.fill", value: "\(store.agents.filter { !$0.circuit.isOpen }.count)", label: "熔断关闭", tint: .green)
                    StatTile(icon: "exclamationmark.shield.fill", value: "\(store.agents.filter { $0.circuit.isOpen }.count)", label: "熔断开启", tint: .red)
                    StatTile(icon: "arrow.up.right.square.fill", value: "\(store.delegations.filter { $0.status == .escalated }.count)", label: "已自动升级", tint: .orange)
                }

                FusionCard(header: "Agent 熔断器", headerIcon: "shield.lefthalf.filled") {
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
                                            Text("冷却 \(Int(agent.circuit.resetInSeconds))s")
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
                ScreenHeader(eyebrow: "Sub-Graph Registry", title: "子图注册", subtitle: "可复用 AgentGraph · 节点/边 · 入口节点 · 运行状态")

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
                metaPair("节点", "\(sg.nodeCount)")
                metaPair("边", "\(sg.edgeCount)")
                metaPair("入口", sg.entryNode)
            }
            HStack {
                Image(systemName: "clock").font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                Text("最近运行 \(sg.lastRun)").font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
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
