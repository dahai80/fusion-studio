import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

// MARK: - GUI-2: Project List Page (Main Module View)

struct ProjectModuleView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var projects: [FusionProject] = []
    @State private var archivedProjects: [FusionProject] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateDialog = false
    @State private var selectedProjectId: String?
    @State private var searchText = ""
    @State private var sortOption: ProjectModuleSort = .lastUpdated
    @State private var showUpstreamWarning = false

    private var activeProjects: [FusionProject] {
        projects.filter { !$0.isArchived }
    }

    private var filteredActive: [FusionProject] {
        var result = activeProjects
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return sortOption.sort(result)
    }

    var body: some View {
        HStack(spacing: 0) {
            projectListView
            Rectangle().fill(theme.separator).frame(width: 1)
            if let pid = selectedProjectId,
               let project = projects.first(where: { $0.id == pid }) ?? archivedProjects.first(where: { $0.id == pid }) {
                ProjectDetailView(project: project)
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadProjects()
            Task { await checkUpstream() }
        }
    }

    // MARK: GUI-2 Left: Project List

    private var projectListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(eyebrow: "Fusion Studio", title: "Projects",
                         subtitle: i18n.t(.proj_subtitle))
                .padding(.bottom, theme.spacingS)

            // Search + Sort + New
            HStack(spacing: theme.spacingS) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                    TextField(i18n.t(.proj_searchPh), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.footnoteSize))
                }
                .padding(.horizontal, theme.spacingS)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.textTertiary.opacity(0.08)))

                Menu {
                    ForEach(ProjectModuleSort.allCases, id: \.self) { opt in
                        Button(action: { sortOption = opt }) {
                            HStack {
                                Text(opt.localLabel)
                                if sortOption == opt { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                }
                .menuStyle(.borderlessButton)

                Button(action: { showCreateDialog = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .help(i18n.t(.proj_newHelp))
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.bottom, theme.spacingS)

            // Upstream warning banner
            if showUpstreamWarning {
                upstreamBanner
            }

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let err = errorMessage {
                Text(err)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(.red)
                    .padding(.horizontal, theme.spacingM)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        // Active projects
                        ForEach(filteredActive) { project in
                            projectCard(project)
                        }

                        // Archived section
                        if !archivedProjects.isEmpty {
                            HStack {
                                Rectangle().fill(theme.textTertiary.opacity(0.2))
                                    .frame(height: 1)
                                Text(String(format: i18n.t(.proj_archivedFmt), archivedProjects.count))
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textTertiary)
                                Rectangle().fill(theme.textTertiary.opacity(0.2))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, theme.spacingS)
                            .padding(.horizontal, theme.spacingM)

                            ForEach(archivedProjects) { project in
                                archivedProjectCard(project)
                            }
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }
        }
        .frame(minWidth: 280, maxWidth: 340)
        .sheet(isPresented: $showCreateDialog) {
            // GUI-3: Create Project Dialog
            ProjectCreateDialog(onCreated: { _ in loadProjects() })
        }
    }

    // MARK: GUI-2 Card: Project Card

    private func projectCard(_ project: FusionProject) -> some View {
        let isActive = selectedProjectId == project.id
        return Button(action: { selectedProjectId = project.id }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: project.isStarred ? "star.fill" : "folder.fill")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(project.isStarred ? .yellow : theme.accent)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(isActive ? theme.accent : theme.text)
                        .lineLimit(1)

                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: theme.spacingS) {
                        Label(String(format: i18n.t(.proj_fileCountFmt), project.fileCount), systemImage: "doc")
                        Label(String(format: i18n.t(.proj_chatCountFmt), project.chatCount), systemImage: "bubble.left")
                        if let agent = project.agentName {
                            Label(agent, systemImage: "robot")
                        }
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    // GUI-5: Three-dot menu
                    ProjectCardMenu(project: project, onAction: handleCardAction)
                    Text(relativeTime(project.updatedAt))
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textQuaternary)
                }
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.12) : theme.textTertiary.opacity(0.04))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func archivedProjectCard(_ project: FusionProject) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "archivebox")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(project.name + i18n.t(.proj_archivedSuffix))
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: theme.spacingS) {
                    Label(String(format: i18n.t(.proj_fileCountFmt), project.fileCount), systemImage: "doc")
                    Label(String(format: i18n.t(.proj_chatCountFmt), project.chatCount), systemImage: "bubble.left")
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(theme.textQuaternary)
            }
            Spacer()
            Button(i18n.t(.proj_unarchiveBtn)) {
                Task { await unarchiveProject(project.id) }
            }
            .font(.system(size: theme.captionSize))
            .buttonStyle(.plain)
            .foregroundStyle(theme.accent)

            ProjectCardMenu(project: project, onAction: handleCardAction)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.textTertiary.opacity(0.03))
        )
    }

    // MARK: GUI-21: Upstream Degraded Banner

    private var upstreamBanner: some View {
        Button(action: { showUpstreamWarning.toggle() }) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(i18n.t(.proj_upstreamBanner))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(Color.orange.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, theme.spacingM)
        .padding(.bottom, theme.spacingXS)
    }

    private var emptyStateView: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.proj_emptyDetail))
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Actions

    private func handleCardAction(_ action: ProjectCardAction, project: FusionProject) {
        switch action {
        case .star:
            Task { await starProject(project.id, starred: !project.isStarred) }
        case .rename:
            break
        case .duplicate:
            break
        case .export:
            Task { await exportProject(project.id) }
        case .archive:
            Task { await archiveProject(project.id) }
        case .unarchive:
            Task { await unarchiveProject(project.id) }
        case .delete:
            Task { await deleteProjectCard(project.id) }
        case .settings:
            selectedProjectId = project.id
        }
    }

    private func loadProjects() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await ipc.projectList(includeArchived: true)
                if let items = result["items"] as? [[String: Any]] {
                    let all = items.map { FusionProject.fromDict($0) }
                    await MainActor.run {
                        self.projects = all.filter { !$0.isArchived }
                        self.archivedProjects = all.filter { $0.isArchived }
                        self.isLoading = false
                    }
                    projLog.info("Loaded \(all.count) projects")
                } else {
                    await MainActor.run { self.isLoading = false }
                }
            } catch {
                projLog.error("project.list failed: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = String(format: i18n.t(.proj_loadFailFmt), error.localizedDescription)
                    isLoading = false
                }
            }
        }
    }

    private func starProject(_ pid: String, starred: Bool) async {
        do {
            _ = try await ipc.projectStar(projectId: pid, starred: starred)
            loadProjects()
        } catch {
            projLog.error("starProject failed: \(error.localizedDescription)")
        }
    }

    private func archiveProject(_ pid: String) async {
        do {
            _ = try await ipc.projectArchive(projectId: pid)
            loadProjects()
        } catch {
            projLog.error("archiveProject failed: \(error.localizedDescription)")
        }
    }

    private func unarchiveProject(_ pid: String) async {
        do {
            _ = try await ipc.projectUnarchive(projectId: pid)
            loadProjects()
        } catch {
            projLog.error("unarchiveProject failed: \(error.localizedDescription)")
        }
    }

    private func exportProject(_ pid: String) async {
        do {
            _ = try await ipc.projectExport(projectId: pid)
            projLog.info("Project exported: \(pid)")
        } catch {
            projLog.error("exportProject failed: \(error.localizedDescription)")
        }
    }

    // 卡片菜单删除：归档优先再物理删除，与 ProjectGlobalMenu.deleteProject 对齐 (上游 PR #115)
    private func deleteProjectCard(_ pid: String) async {
        do {
            let target = projects.first { $0.id == pid } ?? archivedProjects.first { $0.id == pid }
            if let p = target, !p.isArchived {
                _ = try await ipc.projectArchive(projectId: pid)
            }
            try await ipc.projectDelete(projectId: pid)
            projLog.info("deleted project via card menu: \(pid)")
            await MainActor.run {
                let pm = FusionProjectManager.shared
                pm.projects.removeAll { $0.id == pid }
                if pm.activeProject?.id == pid {
                    pm.activeProject = nil
                    pm.activeChat = nil
                    pm.activeChatMessages = []
                }
            }
            loadProjects()
        } catch {
            projLog.error("deleteProjectCard failed: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = String(format: i18n.t(.proj_deleteFailFmt), error.localizedDescription)
            }
        }
    }

    private func checkUpstream() async {
        do {
            let result = try await ipc.projectUpstreamHealth()
            let degraded = (result["rag"] as? String == "down") || (result["mlx"] as? String == "down")
            await MainActor.run { showUpstreamWarning = degraded }
        } catch {
            await MainActor.run { showUpstreamWarning = true }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return String(format: i18n.t(.proj_minAgoFmt), Int(interval / 60)) }
        if interval < 86400 { return String(format: i18n.t(.proj_hourAgoFmt), Int(interval / 3600)) }
        if interval < 604800 { return String(format: i18n.t(.proj_dayAgoFmt), Int(interval / 3600)) }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Shared enums (used cross-file by extracted subviews)

enum ProjectModuleSort: String, CaseIterable {
    case lastUpdated = "最近更新"
    case dateCreated = "创建时间"
    case alphabetical = "名称排序"

    var localLabel: String {
        switch self {
        case .lastUpdated: return I18nManager.shared.t(.proj_sortLastUpdated)
        case .dateCreated: return I18nManager.shared.t(.proj_sortDateCreated)
        case .alphabetical: return I18nManager.shared.t(.proj_sortAlphabetical)
        }
    }

    func sort(_ projects: [FusionProject]) -> [FusionProject] {
        switch self {
        case .lastUpdated: return projects.sorted { $0.updatedAt > $1.updatedAt }
        case .dateCreated: return projects.sorted { $0.createdAt > $1.createdAt }
        case .alphabetical: return projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}

enum ProjectCardAction {
    case star, rename, duplicate, export, archive, unarchive, delete, settings
}

enum InstructionEditMode: String, CaseIterable {
    case markdown = "Markdown"
    case richText = "富文本"

    var localLabel: String {
        switch self {
        case .markdown: return I18nManager.shared.t(.proj_editModeMarkdown)
        case .richText: return I18nManager.shared.t(.proj_editModeRichText)
        }
    }
}

