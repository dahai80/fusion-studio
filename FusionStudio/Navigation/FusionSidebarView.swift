// Callers: ContentView (expandable sidebar between IconRail and workspace).
// Affected API: FusionSidebarView (collapsible sidebar, shows content for active section).
// Data schemas: SidebarSection, SidebarItem (from AppState), ProjectWorkspace.recentProjects, CodeAgent.conversation.
// User instruction: "点击open sidebar，sidebar顶端有搜索按钮和隐藏sidebar按钮，在Design菜单下面有Recents 记录，最下面显示用户名和下载按钮"

import SwiftUI
import AppKit
import os.log

private let sidebarLog = Logger(subsystem: "com.fusion.studio", category: "FusionSidebar")

struct FusionSidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var douyinBridge: DouyinOperationBridge
    @Environment(\.studioTheme) private var theme
    @StateObject private var workspace = ProjectWorkspace.shared
    @StateObject private var agent = CodeAgent.shared
    @State private var searchText = ""
    // Callers: ContentView, IconRailView. Affected API: SidebarSection.doc, AppState.activeSection.
    // Data schemas: SidebarSection.allCases auto-includes .doc. User instruction: "在左侧菜单增加 fusion doc"
    @State private var expandedSections: Set<SidebarSection> = [.code, .chats, .projects, .agent, .mlx, .rag, .doc, .simulation, .douyinOperation]

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollViewReader { proxy in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 0).id("sidebarScrollTop")

                            newChatButton

                            ForEach(SidebarSection.allCases) { section in
                                if section == .aiAgent || section == .mlx {
                                    Rectangle()
                                        .fill(theme.separator)
                                        .frame(height: 1)
                                        .padding(.vertical, theme.spacingXS)
                                        .padding(.horizontal, theme.spacingM)
                                }
                                sectionGroup(section)
                            }

                            Spacer(minLength: theme.spacing2XL)

                            recentsSection

                            Color.clear.frame(height: 0).id("sidebarScrollBottom")
                        }
                    }

                    HStack(spacing: 6) {
                        Button(action: { withAnimation { proxy.scrollTo("sidebarScrollTop", anchor: .top) } }) {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(theme.textSecondary)
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                        .help("上移")

                        Button(action: { withAnimation { proxy.scrollTo("sidebarScrollBottom", anchor: .bottom) } }) {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(theme.textSecondary)
                                .background(Circle().fill(.ultraThinMaterial))
                        }
                        .buttonStyle(.plain)
                        .help("下移")
                    }
                    .padding(.trailing, theme.spacingS)
                    .padding(.bottom, theme.spacingS)
                }
            }

            Rectangle().fill(theme.separator).frame(height: 1)
            bottomBar
        }
        .frame(width: appState.sidebarWidth)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Sidebar")
    }

    private var searchBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.text)

            Spacer()

            Button(action: {
                withAnimation(theme.springSnappy) {
                    appState.isSidebarCollapsed = true
                }
            }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Hide Sidebar (⌘\\)")
            .accessibilityIdentifier("sidebar.hide")
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private var newChatButton: some View {
        Button(action: {
            agent.clearConversation()
            appState.activeSection = .code
            appState.selectedModule = .code
            appState.selectedSheet = .code
            sidebarLog.info("New chat started")
        }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "plus")
                    .font(.system(size: theme.iconS, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .frame(width: 20)

                Text("New Chat")
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)

                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, theme.spacingXS)
        .accessibilityIdentifier("chat.new")
    }

    private func sectionGroup(_ section: SidebarSection) -> some View {
        VStack(spacing: 0) {
            sectionHeader(section)

            if expandedSections.contains(section) {
                sectionContent(section)
            }
        }
    }

    private func sectionHeader(_ section: SidebarSection) -> some View {
        Button(action: { toggleSection(section) }) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 12)

                Text(section.rawValue.uppercased())
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .kerning(0.5)

                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingXS)
            .padding(.top, theme.spacingS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("section.\(section.rawValue)")
    }

    @ViewBuilder
    private func sectionContent(_ section: SidebarSection) -> some View {
        switch section {
        case .chats:
            chatsContent
        case .projects:
            projectsSidebarContent
        case .artifacts:
            artifactsContent
        case .code:
            codeModulesContent
        case .design:
            designContent
        case .rag:
            ragSidebarContent
        case .agent:
            agentModulesContent
        case .aiAgent:
            moduleListContent(.aiAgent)
        case .cowork:
            coworkSidebarContent
        case .mlx:
            moduleListContent(.mlx)
        case .modelHub:
            moduleListContent(.modelHub)
        case .multiNode:
            moduleListContent(.multiNode)
        case .fsb:
            fsbSidebarContent
        case .science:
            moduleListContent(.science)
        case .finance:
            moduleListContent(.finance)
        case .pluginEcosystem:
            moduleListContent(.pluginEcosystem)
        case .cliService:
            moduleListContent(.cliService)
        case .doc:
            moduleListContent(.doc)
        // Callers: FusionSidebarView sectionGroup via SidebarSection.allCases.
        // Affected API: sectionContent routing for simulation section.
        // Data schemas: SidebarSection.simulation -> moduleListContent(.simulation) -> Module.simulation.
        // User instruction: "在左侧菜单增加 fusion simulation"
        case .simulation:
            moduleListContent(.simulation)
        case .health:
            moduleListContent(.health)
        // Callers: FusionSidebarView sectionGroup via SidebarSection.allCases. Phase 4 GUI。
        case .douyinOperation:
            douyinSidebarContent
        }
    }

    private var chatsContent: some View {
        VStack(spacing: 0) {
            let userMsgs = agent.conversation.filter { $0.role == "user" }
            if userMsgs.isEmpty {
                Text("No conversations yet")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.vertical, theme.spacingS)
                    .padding(.leading, theme.spacing2XL)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(userMsgs.suffix(5).reversed()) { msg in
                    chatRow(msg)
                }
            }
        }
    }

    // Callers: FusionSidebarView.sectionContent(.douyinOperation). Phase 4 GUI：库存速览侧栏 + 看板入口.
    // fix: 侧栏抖音运营组只显示统计无点击入口, activeSection 无法切到 .douyinOperation → 主区进不了 DouyinOperationView.
    // 加「运营看板」按钮切 activeSection, 与 chatRow 切 .chats 同模式.
    private var douyinSidebarContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Button(action: {
                withAnimation(theme.springSnappy) {
                    appState.activeSection = .douyinOperation
                }
                sidebarLog.info("Open douyin operation dashboard")
            }) {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.accent)
                    Text("运营看板")
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack {
                Image(systemName: "tray").foregroundStyle(theme.amberDot).font(.system(size: 11))
                Text("待发布").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                Spacer()
                Text("\(douyinBridge.queueCounts.pending)").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
            }
            HStack {
                Image(systemName: "checkmark.circle").foregroundStyle(theme.greenDot).font(.system(size: 11))
                Text("已发布").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                Spacer()
                Text("\(douyinBridge.queueCounts.published)").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
            }
            HStack {
                Image(systemName: "flame").foregroundStyle(theme.accent).font(.system(size: 11))
                Text("爆款").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                Spacer()
                Text("\(douyinBridge.winning.hotCount)").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
            }
            Text("点击「运营看板」进入主区操作造片 / 发布 / 评论 / 进化")
                .font(.system(size: 11)).foregroundStyle(theme.textTertiary)
                .padding(.top, theme.spacingS)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    private func chatRow(_ msg: CodeAgent.CodeMessage) -> some View {
        Button(action: {
            appState.activeSection = .chats
            appState.selectedModule = .code
            appState.selectedSheet = .code
        }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "message")
                    .font(.system(size: theme.iconXS))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 20)

                Text(msg.content.prefix(40))
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)

                Spacer()

                Text(msg.timestamp, style: .time)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textQuaternary)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var projectsSidebarContent: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(theme.springSnappy) {
                    appState.selectedModule = .fusionProjects
                }
            }) {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.accent)
                    Text("新建项目")
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.text)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            if !workspace.recentProjects.isEmpty {
                ForEach(workspace.recentProjects.prefix(5)) { project in
                    projectRow(project)
                }
            }

            Button(action: { workspace.openLocalFolder() }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: theme.iconXS))
                    Text("Open Local Folder")
                        .font(.system(size: theme.footnoteSize))
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, theme.spacing2XL)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func projectRow(_ project: RecentProject) -> some View {
        Button(action: { workspace.openRecent(project) }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "folder.fill")
                    .font(.system(size: theme.iconXS))
                    .foregroundStyle(theme.accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(project.path)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var artifactsContent: some View {
        VStack(spacing: 0) {
            let sidebarArtifacts = ArtifactSidebarCache.shared.artifacts
            if sidebarArtifacts.isEmpty {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "cube.box")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                        .frame(width: 20)
                    Text("No artifacts yet")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
            } else {
                ForEach(sidebarArtifacts.prefix(10)) { artifact in
                    sidebarArtifactRow(artifact)
                }
            }

            Button(action: {
                appState.activeSection = .artifacts
                sidebarLog.info("Navigated to artifacts panel")
            }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "cube.box")
                        .font(.system(size: theme.iconXS))
                    Text("Open Artifacts")
                        .font(.system(size: theme.footnoteSize))
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, theme.spacing2XL)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func sidebarArtifactRow(_ artifact: ArtifactModel) -> some View {
        Button(action: {
            appState.activeSection = .artifacts
            sidebarLog.info("Selected artifact: \(artifact.name)")
        }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: iconForArtifactType(artifact.type))
                    .font(.system(size: theme.iconXS))
                    .foregroundStyle(colorForArtifactType(artifact.type))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(artifact.name)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(artifact.type.uppercased())
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(theme.textTertiary)
                        Text("v\(artifact.currentVersion)")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconForArtifactType(_ type: String) -> String {
        switch type.lowercased() {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "markdown": return "doc.text"
        case "html": return "globe"
        case "react": return "atom"
        case "data": return "tablecells"
        default: return "doc"
        }
    }

    private func colorForArtifactType(_ type: String) -> Color {
        switch type.lowercased() {
        case "code": return .blue
        case "markdown": return .purple
        case "html": return .orange
        case "react": return .cyan
        case "data": return .green
        default: return .gray
        }
    }

    private var codeModulesContent: some View {
        VStack(spacing: 0) {
            ForEach(SidebarSection.code.modules) { module in
                moduleRow(module)
            }
        }
    }

    private var designContent: some View {
        VStack(spacing: 0) {
            ForEach(SidebarSection.design.modules) { module in
                moduleRow(module)
            }
        }
    }

    private var agentModulesContent: some View {
        VStack(spacing: 0) {
            ForEach(SidebarSection.agent.modules) { module in
                moduleRow(module)
            }
        }
    }

    private func moduleListContent(_ section: SidebarSection) -> some View {
        VStack(spacing: 0) {
            ForEach(section.modules) { module in
                moduleRow(module)
            }
        }
    }

    private var coworkSidebarContent: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(theme.springSnappy) {
                    appState.selectedModule = .cowork
                }
            }) {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.accent)
                    Text("新建协作空间")
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.text)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
        }
    }

    private func moduleRow(_ module: Module) -> some View {
        let isActive = appState.selectedModule == module
        return Button(action: {
            withAnimation(theme.springSnappy) {
                appState.selectedModule = module
                appState.selectedSheet = module.sheet
            }
            sidebarLog.info("Selected module: \(module.rawValue)")
        }) {
            HStack(spacing: theme.spacingS) {
                ZStack(alignment: .leading) {
                    if isActive {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(theme.accent)
                            .frame(width: 3, height: 16)
                            .offset(x: -theme.spacingXS)
                    }

                    Image(systemName: module.icon)
                        .font(.system(size: theme.iconS, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
                        .frame(width: 20)
                }

                Text(module.rawValue)
                    .font(.system(size: theme.textSize, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? theme.text : theme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("module.\(module.rawValue)")
    }

    private var recentsSection: some View {
        Group {
            if !workspace.recentProjects.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("RECENTS")
                        .font(.system(size: theme.captionSize, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .kerning(0.5)
                        .padding(.horizontal, theme.spacingM)

                    ForEach(workspace.recentProjects.prefix(3)) { recent in
                        recentRow(recent)
                    }
                }
            }
        }
    }

    private func recentRow(_ recent: RecentProject) -> some View {
        Button(action: { workspace.openRecent(recent) }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "clock")
                    .font(.system(size: theme.iconXS))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(recent.name)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(relativeTime(recent.lastOpened))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Circle()
                    .fill(theme.accent.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(theme.accent)
                    }

                Text(NSUserName())
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    if let url = URL(string: "https://github.com/dahai80/fusion-studio") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Download")
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
        }
    }

    private var ragSidebarContent: some View {
        VStack(spacing: 0) {
            ForEach(SidebarSection.rag.modules) { module in
                moduleRow(module)
            }
        }
    }

    private func toggleSection(_ section: SidebarSection) {
        withAnimation(theme.springDefault) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    private var fsbSidebarContent: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(theme.springSnappy) {
                    appState.selectedModule = .fsb
                }
            }) {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.accent)
                    Text("新建工作台")
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.text)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}
