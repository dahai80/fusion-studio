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
    @Environment(\.studioTheme) private var theme
    @StateObject private var workspace = ProjectWorkspace.shared
    @StateObject private var agent = CodeAgent.shared
    @State private var searchText = ""
    @State private var expandedSections: Set<SidebarSection> = [.code, .chats, .projects, .mlx, .multiNode]

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    newChatButton

                    ForEach(SidebarSection.allCases) { section in
                        sectionGroup(section)
                    }

                    Spacer(minLength: theme.spacing2XL)

                    recentsSection
                }
            }

            Rectangle().fill(theme.separator).frame(height: 1)
            bottomBar
        }
        .frame(width: appState.sidebarWidth)
        .background(.ultraThinMaterial)
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
    }

    @ViewBuilder
    private func sectionContent(_ section: SidebarSection) -> some View {
        switch section {
        case .chats:
            chatsContent
        case .projects:
            projectsContent
        case .artifacts:
            artifactsContent
        case .code:
            codeModulesContent
        case .customize:
            customizeContent
        case .design:
            designContent
        case .agent:
            agentModulesContent
        case .mlx:
            moduleListContent(.mlx)
        case .multiNode:
            moduleListContent(.multiNode)
        case .fusionProjects:
            fusionProjectsSidebarContent
        case .cowork:
            coworkSidebarContent
        case .fsb:
            fsbSidebarContent
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

    private var projectsContent: some View {
        VStack(spacing: 0) {
            if workspace.recentProjects.isEmpty {
                Text("No projects yet")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.vertical, theme.spacingS)
                    .padding(.leading, theme.spacing2XL)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(workspace.recentProjects.prefix(5)) { project in
                    projectRow(project)
                }
            }

            Button(action: { workspace.openLocalFolder() }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconXS))
                    Text("Open Project")
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

    private var customizeContent: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "paintpalette")
                .font(.system(size: theme.iconXS))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 20)
            Text("Coming Soon")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
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

    private var fusionProjectsSidebarContent: some View {
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
                    if let url = URL(string: "https://github.com/fusion-ml/fusion-studio/releases") {
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
