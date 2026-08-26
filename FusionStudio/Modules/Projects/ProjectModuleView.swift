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

// MARK: - Sort Option

private enum ProjectModuleSort: String, CaseIterable {
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

// MARK: - GUI-5: Card Three-dot Menu

private enum ProjectCardAction {
    case star, rename, duplicate, export, archive, unarchive, delete, settings
}

private struct ProjectCardMenu: View {
    let project: FusionProject
    let onAction: (ProjectCardAction, FusionProject) -> Void

    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var showDeleteConfirm = false
    @State private var showDuplicateDialog = false
    @State private var showRenameDialog = false
    @State private var renameText = ""

    var body: some View {
        Menu {
            Button(action: { onAction(.star, project) }) {
                Label(project.isStarred ? i18n.t(.proj_menuUnstar) : i18n.t(.proj_menuStar),
                      systemImage: project.isStarred ? "star.slash" : "star")
            }
            Button(action: { renameText = project.name; showRenameDialog = true }) {
                Label(i18n.t(.proj_menuRename), systemImage: "pencil")
            }
            Button(action: { showDuplicateDialog = true }) {
                Label(i18n.t(.proj_menuDuplicate), systemImage: "doc.on.doc")
            }
            Button(action: { onAction(.export, project) }) {
                Label(i18n.t(.proj_menuExport), systemImage: "square.and.arrow.up")
            }
            Divider()
            if project.isArchived {
                Button(action: { onAction(.unarchive, project) }) {
                    Label(i18n.t(.proj_unarchiveBtn), systemImage: "archivebox")
                }
            } else {
                Button(action: { onAction(.archive, project) }) {
                    Label(i18n.t(.proj_menuArchive), systemImage: "archivebox")
                }
            }
            Button(role: .destructive, action: { showDeleteConfirm = true }) {
                Label(i18n.t(.proj_menuDelete), systemImage: "trash")
            }
            Divider()
            Button(action: { onAction(.settings, project) }) {
                Label(i18n.t(.proj_menuSettings), systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: theme.iconXS, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .alert(i18n.t(.proj_deleteAlertTitle), isPresented: $showDeleteConfirm) {
            Button(i18n.t(.cancel), role: .cancel) {}
            Button(i18n.t(.proj_deleteConfirm), role: .destructive) {
                onAction(.delete, project)
            }
        } message: {
            Text(String(format: i18n.t(.proj_deleteAlertMsgFmt), project.name))
        }
        .sheet(isPresented: $showDuplicateDialog) {
            // GUI-6: Duplicate Dialog
            ProjectDuplicateDialog(project: project)
        }
        .sheet(isPresented: $showRenameDialog) {
            VStack(spacing: theme.spacingM) {
                Text(i18n.t(.proj_renameTitle))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                TextField(i18n.t(.proj_namePh), text: $renameText)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(i18n.t(.cancel)) { showRenameDialog = false }
                    Spacer()
                    Button(i18n.t(.save)) {
                        Task { await renameProject() }
                        showRenameDialog = false
                    }
                    .disabled(renameText.isEmpty)
                }
            }
            .padding(theme.spacingL)
            .frame(width: 360)
        }
    }

    private func renameProject() async {
        do {
            _ = try await ipc.projectUpdate(projectId: project.id, fields: ["name": renameText])
            projLog.info("Project renamed: \(renameText)")
        } catch {
            projLog.error("renameProject failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - GUI-3: Create Project Dialog

struct ProjectCreateDialog: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var instructions = ""
    @State private var ragMode = RAGMode.AUTO
    @State private var promptMergeMode = PromptMergeMode.AGENT_FIRST
    @State private var selectedAgentId: String?
    @State private var availableAgents: [AgentMeta] = []
    @State private var isCreating = false
    @State private var editMode: InstructionEditMode = .markdown

    private let maxChars = 10000

    let onCreated: ([String: Any]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(i18n.t(.proj_createTitle))
                .font(.system(size: theme.headlineSize, weight: .bold))

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_createNameLabel))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.proj_namePh), text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_createDescLabel))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.proj_createDescPh), text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            // Instructions
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(i18n.t(.proj_createInstructions))
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    ForEach(InstructionEditMode.allCases, id: \.self) { mode in
                        Button(action: { editMode = mode }) {
                            Text(mode.localLabel)
                                .font(.system(size: 9, weight: editMode == mode ? .bold : .regular))
                                .foregroundStyle(editMode == mode ? theme.accent : theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(String(format: i18n.t(.proj_createCharCountFmt), instructions.count, maxChars))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(instructions.count > maxChars ? .red : theme.textTertiary)
                }
                TextEditor(text: $instructions)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .frame(height: 80)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.textTertiary.opacity(0.2)))
                Text(i18n.t(.proj_createInstructionsHint))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textQuaternary)
            }

            // Default Agent
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_createDefaultAgent))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Menu {
                    Button(i18n.t(.proj_createNoAgent)) { selectedAgentId = nil }
                    Divider()
                    ForEach(availableAgents) { agent in
                        Button(agent.name) { selectedAgentId = agent.id }
                    }
                    Divider()
                    Button(i18n.t(.proj_createGotoAgentStudio)) { }
                } label: {
                    HStack {
                        Image(systemName: "robot")
                        Text(selectedAgentId.flatMap { id in availableAgents.first(where: { $0.id == id })?.name } ?? i18n.t(.proj_createNoAgentShort))
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: theme.footnoteSize))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.textTertiary.opacity(0.2)))
                }
                .menuStyle(.borderlessButton)
            }

            // Prompt merge mode
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_createPromptMerge))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $promptMergeMode) {
                    Text(i18n.t(.proj_createMergeAgentFirst)).tag(PromptMergeMode.AGENT_FIRST)
                    Text(i18n.t(.proj_createMergeProjectOnly)).tag(PromptMergeMode.PROJECT_ONLY)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))
            }

            // RAG Mode
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_createRagMode))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $ragMode) {
                    Text(i18n.t(.proj_createRagAuto)).tag(RAGMode.AUTO)
                    Text(i18n.t(.proj_createRagManual)).tag(RAGMode.MANUAL)
                    Text(i18n.t(.proj_createRagOff)).tag(RAGMode.OFF)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))
            }

            Spacer(minLength: 0)

            HStack {
                Button(i18n.t(.cancel)) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(i18n.t(.proj_createBtn)) { createProject() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || isCreating)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 520, height: 600)
        .onAppear { loadAgents() }
    }

    private func loadAgents() {
        Task {
            do {
                let result = try await ipc.projectAgentList()
                if let items = result["agents"] as? [[String: Any]] ?? result["items"] as? [[String: Any]] {
                    await MainActor.run {
                        availableAgents = items.compactMap { AgentMeta.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadAgents failed: \(error.localizedDescription)")
            }
        }
    }

    private func createProject() {
        isCreating = true
        Task {
            do {
                let result = try await ipc.projectCreate(
                    name: name, description: description,
                    defaultAgentId: selectedAgentId,
                    ragMode: ragMode.rawValue,
                    promptMergeMode: promptMergeMode.rawValue
                )
                projLog.info("Project created: \(name)")
                await MainActor.run { onCreated(result); dismiss() }
            } catch {
                projLog.error("project.create failed: \(error.localizedDescription)")
                await MainActor.run { isCreating = false }
            }
        }
    }
}

private enum InstructionEditMode: String, CaseIterable {
    case markdown = "Markdown"
    case richText = "富文本"

    var localLabel: String {
        switch self {
        case .markdown: return I18nManager.shared.t(.proj_editModeMarkdown)
        case .richText: return I18nManager.shared.t(.proj_editModeRichText)
        }
    }
}

// MARK: - GUI-6: Duplicate Dialog

private struct ProjectDuplicateDialog: View {
    let project: FusionProject
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ipc: IPCClient

    @State private var newName: String
    @State private var includeSessions = false
    @State private var isDuplicating = false

    init(project: FusionProject) {
        self.project = project
        _newName = State(initialValue: project.name + I18nManager.shared.t(.proj_dupCopySuffix))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(i18n.t(.proj_dupTitle))
                .font(.system(size: theme.headlineSize, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_dupNameLabel))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.proj_namePh), text: $newName)
                    .textFieldStyle(.roundedBorder)
            }

            Text(i18n.t(.proj_dupScope))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Picker("", selection: $includeSessions) {
                Text(i18n.t(.proj_dupScopeInstructionsOnly)).tag(false)
                Text(i18n.t(.proj_dupScopeWithSnapshots)).tag(true)
            }
            .pickerStyle(.radioGroup)
            .font(.system(size: theme.captionSize))

            Spacer(minLength: 0)

            HStack {
                Button(i18n.t(.cancel)) { dismiss() }
                Spacer()
                Button(i18n.t(.proj_dupBtn)) { duplicateProject() }
                    .disabled(newName.isEmpty || isDuplicating)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 280)
    }

    private func duplicateProject() {
        isDuplicating = true
        Task {
            do {
                _ = try await ipc.projectDuplicate(projectId: project.id, name: newName)
                projLog.info("Project duplicated: \(newName)")
                await MainActor.run { dismiss() }
            } catch {
                projLog.error("duplicateProject failed: \(error.localizedDescription)")
                await MainActor.run { isDuplicating = false }
            }
        }
    }
}

// MARK: - GUI-4: Project Detail View (Core Page)

struct ProjectDetailView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let project: FusionProject
    @State private var activeTab: ProjectDetailTab = .instructions
    @State private var showSettings = false
    @State private var showCoWorkDialog = false
    @State private var showAgentPreview = false

    private enum ProjectDetailTab: Int, CaseIterable {
        case instructions = 0
        case knowledge = 1
        case chats = 2

        var item: FusionTabItem {
            switch self {
            case .instructions: return FusionTabItem(title: I18nManager.shared.t(.proj_tabInstructions), icon: "text.alignleft")
            case .knowledge:    return FusionTabItem(title: I18nManager.shared.t(.proj_tabKnowledge), icon: "folder.badge.gearshape")
            case .chats:        return FusionTabItem(title: I18nManager.shared.t(.proj_tabChats), icon: "bubble.left.and.bubble.right")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // GUI-4 Header bar
            projectHeaderBar

            // Tab bar
            FusionTabBar(
                selected: Binding(
                    get: { activeTab.rawValue },
                    set: { if let t = ProjectDetailTab(rawValue: $0) { activeTab = t } }
                ),
                tabs: ProjectDetailTab.allCases.map { $0.item }
            )
            .padding(.horizontal, theme.spacingM)

            // Tab content
            Group {
                switch activeTab {
                case .instructions:
                    ProjectInstructionsPanel(projectId: project.id)
                case .knowledge:
                    KnowledgeBaseTreeView(projectId: project.id)
                case .chats:
                    ProjectChatsPanel(projectId: project.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSettings) {
            ProjectSettingsPanel(project: project)
        }
        .sheet(isPresented: $showCoWorkDialog) {
            CoWorkImportDialog(project: project)
        }
        .sheet(isPresented: $showAgentPreview) {
            ProjectAgentPreview(project: project)
        }
    }

    // GUI-4: Header — back / name / star / menu / agent / CoWork

    private var projectHeaderBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: project.isStarred ? "star.fill" : "folder.fill")
                .font(.system(size: theme.iconM))
                .foregroundStyle(project.isStarred ? .yellow : theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                if project.isArchived {
                    Text(i18n.t(.proj_detailArchived))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }

            // Star toggle
            Button(action: { toggleStar() }) {
                Image(systemName: project.isStarred ? "star.fill" : "star")
                    .foregroundStyle(project.isStarred ? .yellow : theme.textTertiary)
            }
            .buttonStyle(.plain)

            // GUI-5: Global 3-dot menu
            ProjectGlobalMenu(project: project)

            Spacer()

            // Agent selector
            if let agentName = project.agentName {
                Button(action: { showAgentPreview = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "robot")
                            .font(.system(size: theme.iconXS))
                        Text(agentName)
                            .font(.system(size: theme.footnoteSize))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.accent.opacity(0.3)))
                }
                .buttonStyle(.plain)
            }

            // CoWork import
            Button(action: { showCoWorkDialog = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: theme.iconXS))
                    Text(i18n.t(.proj_detailImportCowork))
                        .font(.system(size: theme.footnoteSize))
                }
                .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(project.isArchived)

            // Settings
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private func toggleStar() {
        Task {
            do {
                _ = try await ipc.projectStar(projectId: project.id, starred: !project.isStarred)
            } catch {
                projLog.error("toggleStar failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GUI-5: Global Three-dot Menu (in detail header)

private struct ProjectGlobalMenu: View {
    let project: FusionProject
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @EnvironmentObject var ipc: IPCClient
    @State private var showDeleteConfirm = false
    @State private var showDuplicateDialog = false

    var body: some View {
        Menu {
            Button(action: { toggleStar() }) {
                Label(project.isStarred ? i18n.t(.proj_menuUnstar) : i18n.t(.proj_menuStar),
                      systemImage: project.isStarred ? "star.slash" : "star")
            }
            Button(action: { }) {
                Label(i18n.t(.proj_menuRename), systemImage: "pencil")
            }
            Button(action: { showDuplicateDialog = true }) {
                Label(i18n.t(.proj_menuDuplicate), systemImage: "doc.on.doc")
            }
            Button(action: { exportProject() }) {
                Label(i18n.t(.proj_menuExport), systemImage: "square.and.arrow.up")
            }
            if project.isArchived {
                Button(action: { unarchiveProject() }) {
                    Label(i18n.t(.proj_unarchiveBtn), systemImage: "archivebox")
                }
            } else {
                Button(action: { archiveProject() }) {
                    Label(i18n.t(.proj_menuArchive), systemImage: "archivebox")
                }
            }
            Divider()
            Button(role: .destructive, action: { showDeleteConfirm = true }) {
                Label(i18n.t(.proj_menuDelete), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
        }
        .menuStyle(.borderlessButton)
        // GUI-20: Delete confirmation
        .alert(i18n.t(.proj_deleteAlertTitle), isPresented: $showDeleteConfirm) {
            Button(i18n.t(.cancel), role: .cancel) {}
            Button(i18n.t(.proj_deleteConfirm), role: .destructive) { deleteProject() }
        } message: {
            Text(String(format: i18n.t(.proj_deleteAlertMsgFullFmt), project.name, project.fileCount, project.chatCount))
        }
        .sheet(isPresented: $showDuplicateDialog) {
            ProjectDuplicateDialog(project: project)
        }
    }

    private func toggleStar() {
        Task { _ = try await ipc.projectStar(projectId: project.id, starred: !project.isStarred) }
    }
    private func archiveProject() {
        Task { _ = try await ipc.projectArchive(projectId: project.id) }
    }
    private func unarchiveProject() {
        Task { _ = try await ipc.projectUnarchive(projectId: project.id) }
    }
    private func exportProject() {
        Task { _ = try await ipc.projectExport(projectId: project.id) }
    }
    private func deleteProject() {
        Task {
            do {
                if !project.isArchived {
                    _ = try await ipc.projectArchive(projectId: project.id)
                }
                try await ipc.projectDelete(projectId: project.id)
                await MainActor.run {
                    let pm = FusionProjectManager.shared
                    pm.projects.removeAll { $0.id == project.id }
                    if pm.activeProject?.id == project.id {
                        pm.activeProject = nil
                        pm.activeChat = nil
                        pm.activeChatMessages = []
                    }
                }
                projLog.info("deleted project \(project.id)")
            } catch {
                projLog.error("deleteProject failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GUI-4 Left Panel: Instructions (Collapsible Section)

struct ProjectInstructionsPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let projectId: String
    @State private var instructions: String = ""
    @State private var isEditing = false
    @State private var editedText: String = ""
    @State private var editMode: InstructionEditMode = .markdown
    @State private var showVersionHistory = false
    @State private var snapshots: [InstructionSnapshot] = []
    @State private var isSaving = false

    private let maxChars = 10000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                // Section header
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(theme.accent)
                    Text(i18n.t(.proj_instTitle))
                        .font(.system(size: theme.textSize, weight: .semibold))
                    Spacer()
                    if isEditing {
                        Button(i18n.t(.save)) {
                            saveInstructions()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                        .disabled(isSaving)
                        Button(i18n.t(.cancel)) {
                            isEditing = false
                            editedText = instructions
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textTertiary)
                    } else {
                        Button(action: { isEditing = true; editedText = instructions }) {
                            Image(systemName: "pencil")
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        // GUI-15: Version history button
                        Button(action: { loadSnapshots(); showVersionHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Edit mode toggle
                if isEditing {
                    HStack {
                        ForEach(InstructionEditMode.allCases, id: \.self) { mode in
                            Button(action: { editMode = mode }) {
                                Text(mode.localLabel)
                                    .font(.system(size: 9, weight: editMode == mode ? .bold : .regular))
                                    .foregroundStyle(editMode == mode ? theme.accent : theme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Text(String(format: i18n.t(.proj_createCharCountFmt), editedText.count, maxChars))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(editedText.count > maxChars ? .red : theme.textTertiary)
                    }
                }

                // Content
                if isEditing {
                    TextEditor(text: $editedText)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .frame(minHeight: 120)
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .stroke(theme.textTertiary.opacity(0.2)))
                } else {
                    if instructions.isEmpty {
                        VStack(spacing: theme.spacingXS) {
                            Image(systemName: "text.alignleft")
                                .font(.system(size: 20))
                                .foregroundStyle(theme.textQuaternary)
                            Text(i18n.t(.proj_instEmpty))
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.textTertiary)
                            Text(i18n.t(.proj_instEmptyHint))
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textQuaternary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacingL)
                    } else {
                        Text(instructions)
                            .font(.system(size: theme.footnoteSize, design: editMode == .markdown ? .monospaced : .default))
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(theme.spacingL)
        }
        .sheet(isPresented: $showVersionHistory) {
            // GUI-15: Instruction Version History
            InstructionVersionHistory(projectId: projectId, snapshots: snapshots)
        }
        .onAppear { loadInstructions() }
    }

    private func loadInstructions() {
        Task {
            do {
                let result = try await ipc.projectInstructionGet(projectId: projectId)
                if let content = result["content"] as? String {
                    await MainActor.run { self.instructions = content }
                }
            } catch {
                projLog.error("loadInstructions failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveInstructions() {
        isSaving = true
        Task {
            do {
                _ = try await ipc.projectInstructionSave(projectId: projectId, content: editedText)
                await MainActor.run {
                    self.instructions = editedText
                    self.isEditing = false
                    self.isSaving = false
                }
                projLog.info("Instructions saved for project \(projectId)")
            } catch {
                projLog.error("saveInstructions failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func loadSnapshots() {
        Task {
            do {
                let result = try await ipc.projectInstructionSnapshots(projectId: projectId)
                if let items = result["items"] as? [[String: Any]] ?? result["snapshots"] as? [[String: Any]] {
                    await MainActor.run {
                        self.snapshots = items.compactMap { snap in
                            guard let id = snap["id"] as? String,
                                  let content = snap["content"] as? String else { return nil }
                            return InstructionSnapshot(
                                id: id,
                                label: snap["label"] as? String ?? "V1",
                                content: content,
                                createdAt: ISO8601DateFormatter().date(from: snap["created_at"] as? String ?? "") ?? Date()
                            )
                        }
                    }
                }
            } catch {
                projLog.error("loadSnapshots failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GUI-15: Instruction Version History

private struct InstructionVersionHistory: View {
    let projectId: String
    let snapshots: [InstructionSnapshot]
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ipc: IPCClient

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.proj_instHistoryTitle))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            if snapshots.isEmpty {
                Text(i18n.t(.proj_instHistoryEmpty))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingS) {
                        ForEach(Array(snapshots.enumerated()), id: \.element.id) { idx, snap in
                            HStack(alignment: .top, spacing: theme.spacingS) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(idx == 0 ? "●" : "○")
                                            .foregroundStyle(idx == 0 ? theme.accent : theme.textTertiary)
                                        Text(String(format: i18n.t(.proj_instHistoryCurrentFmt), snapshots.count - idx))
                                            .font(.system(size: theme.footnoteSize, weight: .medium))
                                        Text("— \(relativeTime(snap.createdAt))")
                                            .font(.system(size: theme.captionSize))
                                            .foregroundStyle(theme.textTertiary)
                                        if idx == 0 {
                                            Text(i18n.t(.proj_instHistoryCurrentTag))
                                                .font(.system(size: 9))
                                                .foregroundStyle(theme.accent)
                                        }
                                    }
                                    Text(String(snap.content.prefix(80)))
                                        .font(.system(size: theme.captionSize, design: .monospaced))
                                        .foregroundStyle(theme.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                if idx != 0 {
                                    Button(i18n.t(.proj_instHistoryRestore)) {
                                        restoreSnapshot(snap)
                                    }
                                    .font(.system(size: theme.captionSize))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(theme.accent)
                                }
                                if snapshots.count > 1 {
                                    Button(role: .destructive) {
                                        deleteSnapshot(snap)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: theme.captionSize))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(theme.spacingS)
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(theme.textTertiary.opacity(0.04)))
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button(i18n.t(.close)) { dismiss() }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 400)
    }

    private func restoreSnapshot(_ snap: InstructionSnapshot) {
        Task {
            do {
                _ = try await ipc.projectInstructionSnapshotRestore(snapshotId: snap.id)
                projLog.info("Instruction restored to snapshot \(snap.id)")
                dismiss()
            } catch {
                projLog.error("restoreSnapshot failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteSnapshot(_ snap: InstructionSnapshot) {
        Task {
            do {
                _ = try await ipc.projectInstructionSnapshotDelete(snapshotId: snap.id)
                projLog.info("Instruction snapshot deleted \(snap.id)")
            } catch {
                projLog.error("deleteSnapshot failed: \(error.localizedDescription)")
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return String(format: i18n.t(.proj_minAgoFmt), Int(interval / 60)) }
        if interval < 86400 { return String(format: i18n.t(.proj_hourAgoFmt), Int(interval / 3600)) }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - GUI-4 + GUI-18: Knowledge Base Tree View

struct KnowledgeBaseTreeView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let projectId: String
    @State private var folders: [KnowledgeFolder] = []
    @State private var files: [KnowledgeFile] = []
    @State private var expandedFolders: Set<String> = []
    @State private var showAddFilePicker = false
    @State private var showAddFolderDialog = false
    @State private var newFolderName = ""
    @State private var selectedFileId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                // Header
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                        .foregroundStyle(theme.accent)
                    Text(i18n.t(.proj_kbTitle))
                        .font(.system(size: theme.textSize, weight: .semibold))
                    Text(String(format: i18n.t(.proj_kbFileCountFmt), files.count))
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()

                    Button(action: { showAddFolderDialog = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                            Text(i18n.t(.proj_kbFolder))
                        }
                        .font(.system(size: theme.captionSize))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)

                    Button(action: { showAddFilePicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text(i18n.t(.proj_kbAddFile))
                        }
                        .font(.system(size: theme.captionSize))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                }

                // Tree
                if files.isEmpty && folders.isEmpty {
                    emptyKnowledgeState
                } else {
                    // Root-level files (no folder)
                    let rootFiles = files.filter { f in f.folderId == nil }
                    ForEach(rootFiles) { file in
                        knowledgeFileRow(file)
                    }

                    // Folders with their files
                    ForEach(folders) { folder in
                        folderSection(folder)
                    }
                }
            }
            .padding(theme.spacingL)
        }
        .fileImporter(isPresented: $showAddFilePicker,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            handleFileImport(result)
        }
        .alert(i18n.t(.proj_kbNewFolderAlert), isPresented: $showAddFolderDialog) {
            TextField(i18n.t(.proj_kbFolderNamePh), text: $newFolderName)
            Button(i18n.t(.cancel), role: .cancel) { newFolderName = "" }
            Button(i18n.t(.proj_kbCreate)) {
                createFolder()
                newFolderName = ""
            }
            .disabled(newFolderName.isEmpty)
        }
        .onAppear {
            loadKnowledge()
        }
    }

    private var emptyKnowledgeState: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(theme.textQuaternary)
            Text(i18n.t(.proj_kbEmpty))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.proj_kbEmptyHint))
                .font(.system(size: 9))
                .foregroundStyle(theme.textQuaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingXL)
    }

    private func folderSection(_ folder: KnowledgeFolder) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Folder header
            Button(action: {
                if expandedFolders.contains(folder.id) {
                    expandedFolders.remove(folder.id)
                } else {
                    expandedFolders.insert(folder.id)
                }
            }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: expandedFolders.contains(folder.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(width: 10)
                    Image(systemName: "folder.fill")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: theme.iconXS))
                    Text(folder.name)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Text("\(folder.fileCount)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Files in folder
            if expandedFolders.contains(folder.id) {
                let folderFiles = files.filter { $0.folderId == folder.id }
                ForEach(folderFiles) { file in
                    HStack(spacing: theme.spacingXS) {
                        Text("    ")
                        knowledgeFileRow(file)
                    }
                }
            }
        }
    }

    // GUI-18: File row with index status
    private func knowledgeFileRow(_ file: KnowledgeFile) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: fileIcon(for: file.fileName))
                .font(.system(size: theme.iconXS))
                .foregroundStyle(theme.textTertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.fileName)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    // GUI-18: Index status
                    statusIcon(file.indexStatus)
                    if file.tokenCount > 0 {
                        Text("(\(file.tokenCount) tokens)")
                            .foregroundStyle(theme.textQuaternary)
                    }
                }
                .font(.system(size: 8, design: .monospaced))
            }

            Spacer()

            // GUI-8: File context menu
            KnowledgeFileMenu(file: file, projectId: projectId)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(selectedFileId == file.id ? theme.accent.opacity(0.08) : .clear)
        )
    }

    @ViewBuilder
    private func statusIcon(_ status: String) -> some View {
        switch status {
        case "ready", "indexed":
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(i18n.t(.proj_kbStatusIndexed))
                    .foregroundStyle(.green)
            }
        case "indexing":
            HStack(spacing: 2) {
                ProgressView()
                    .scaleEffect(0.5)
                Text(i18n.t(.proj_kbStatusIndexing))
                    .foregroundStyle(.orange)
            }
        case "failed":
            HStack(spacing: 2) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(i18n.t(.proj_kbStatusFailed))
                    .foregroundStyle(.red)
            }
        default:
            HStack(spacing: 2) {
                Image(systemName: "clock")
                    .foregroundStyle(theme.textQuaternary)
                Text(i18n.t(.proj_kbStatusPending))
                    .foregroundStyle(theme.textQuaternary)
            }
        }
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "md", "txt": return "doc.text"
        case "csv": return "tablecells"
        case "png", "jpg", "jpeg", "webp": return "photo"
        default: return "doc"
        }
    }

    private func loadKnowledge() {
        Task {
            do {
                async let foldersResult = ipc.projectFolderList(projectId: projectId)
                async let filesResult = ipc.projectKnowledgeFileList(projectId: projectId)
                let f = try await foldersResult
                let fl = try await filesResult
                await MainActor.run {
                    if let items = f["items"] as? [[String: Any]] ?? f["folders"] as? [[String: Any]] {
                        self.folders = items.compactMap { KnowledgeFolder.fromDict($0) }
                    }
                    if let items = fl["items"] as? [[String: Any]] ?? fl["files"] as? [[String: Any]] {
                        self.files = items.compactMap { KnowledgeFile.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadKnowledge failed: \(error.localizedDescription)")
            }
        }
    }

    private func createFolder() {
        Task {
            do {
                _ = try await ipc.projectFolderCreate(projectId: projectId, name: newFolderName)
                loadKnowledge()
            } catch {
                projLog.error("createFolder failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                Task {
                    do {
                        _ = try await ipc.projectKnowledgeFileUpload(
                            projectId: projectId,
                            sourcePath: url.path,
                            originalName: url.lastPathComponent
                        )
                        loadKnowledge()
                    } catch {
                        projLog.error("file upload failed: \(error.localizedDescription)")
                    }
                }
            }
        case .failure(let error):
            projLog.error("file import failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - GUI-8: Knowledge File Context Menu

private struct KnowledgeFileMenu: View {
    let file: KnowledgeFile
    let projectId: String
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        Menu {
            Button(action: { previewFile() }) {
                Label(i18n.t(.proj_kbMenuPreview), systemImage: "eye")
            }
            Button(action: {}) {
                Label(i18n.t(.proj_kbMenuRename), systemImage: "pencil")
            }
            Button(action: {}) {
                Label(i18n.t(.proj_kbMenuReplace), systemImage: "arrow.2.circlepath")
            }
            Button(action: {}) {
                Label(i18n.t(.proj_kbMenuMove), systemImage: "folder")
            }
            Divider()
            Button(role: .destructive, action: { removeFile() }) {
                Label(i18n.t(.proj_kbMenuRemove), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
        }
        .menuStyle(.borderlessButton)
    }

    private func previewFile() {
        projLog.info("Preview file: \(file.fileName)")
    }

    private func removeFile() {
        Task {
            do {
                try await ipc.projectKnowledgeFileDelete(fileId: file.id)
            } catch {
                projLog.error("removeFile failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GUI-4 + GUI-7: Chats Panel

struct ProjectChatsPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var agentBridge: AgentBridge
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let projectId: String
    @State private var chats: [ProjectChat] = []
    @State private var activeChatId: String?
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var refocusTrigger = 0
    @State private var selectedModel: String = ""
    @StateObject private var voiceInput = VoiceInputManager()
    @State private var ragMode: RAGMode = .AUTO
    @State private var showRAGScopeSelector = false
    @State private var showSnapshots = false
    @State private var tokenUsed: Int = 0
    @State private var tokenBudget: Int = 128000
    @State private var showAgentConfig = false
    @State private var showRAGConfig = false
    @State private var snapshots: [ChatSnapshot] = []
    @State private var selectedChatForMenu: ProjectChat?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: Chat list
            VStack(alignment: .leading, spacing: 0) {
                // Chat list header
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundStyle(theme.accent)
                    Text(i18n.t(.proj_chatsTitle))
                        .font(.system(size: theme.textSize, weight: .semibold))
                    Text("\(chats.count)")
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    Button(action: { createNewChat() }) {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(chats) { chat in
                            chatRow(chat)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }

                // Snapshots section
                if !snapshots.isEmpty {
                    Divider()
                    HStack {
                        Image(systemName: "camera")
                            .font(.system(size: theme.iconXS))
                        Text(i18n.t(.proj_chatsSnapshots))
                            .font(.system(size: theme.captionSize, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.top, theme.spacingXS)

                    ForEach(snapshots) { snap in
                        HStack {
                            Image(systemName: "photo")
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textTertiary)
                            Text(snap.label)
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text(String(format: i18n.t(.proj_chatsSnapMsgCountFmt), snap.messageCount))
                                .font(.system(size: 8))
                                .foregroundStyle(theme.textQuaternary)
                        }
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, 3)
                    }
                }
            }
            .frame(width: 200)

            Rectangle().fill(theme.separator).frame(width: 1)

            // Right: Chat canvas
            VStack(spacing: 0) {
                if let chatId = activeChatId {
                    chatCanvas(chatId: chatId)
                } else {
                    Spacer()
                    VStack(spacing: theme.spacingS) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.textQuaternary)
                        Text(i18n.t(.proj_chatsEmpty))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            loadChats()
            loadSnapshots()
            refreshBudget()
        }
        .alert(i18n.t(.proj_chatsHint), isPresented: $showError, presenting: errorMessage) { _ in
            Button(i18n.t(.ok), role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    private func chatRow(_ chat: ProjectChat) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: chat.isStarred ? "star.fill" : "bubble.left.fill")
                .font(.system(size: 9))
                .foregroundStyle(chat.isStarred ? .yellow : theme.textTertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text(chat.title)
                    .font(.system(size: theme.footnoteSize, weight: activeChatId == chat.id ? .semibold : .regular))
                    .foregroundStyle(activeChatId == chat.id ? theme.accent : theme.text)
                    .lineLimit(1)
                Text("\(chat.messageCount) msgs · \(chat.tokenUsage) tokens")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(theme.textQuaternary)
            }

            Spacer()

            // GUI-7: Chat three-dot menu
            ChatContextMenu(chat: chat, projectId: projectId)
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(activeChatId == chat.id ? theme.accent.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            activeChatId = chat.id
            loadMessages(chatId: chat.id)
        }
    }

    // MARK: GUI-4: Chat Canvas

    private func chatCanvas(chatId: String) -> some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacingS) {
                        ForEach(messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                    }
                    .padding(theme.spacingM)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // GUI-4: Bottom input bar — Agent / RAG / Attachments / Send
            chatInputBar(chatId: chatId)
        }
    }

    // GUI-22: RAG source annotation in messages
    private func messageBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == "user"
        return HStack(alignment: .top, spacing: theme.spacingS) {
            if isUser { Spacer(minLength: 40) }

            Image(systemName: isUser ? "person.fill" : "robot")
                .font(.system(size: theme.iconS))
                .foregroundStyle(isUser ? theme.textSecondary : theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(msg.content)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)

                // GUI-22: RAG sources
                if let sources = msg.ragSources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 8))
                            Text(i18n.t(.proj_ragSources))
                        }
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)

                        ForEach(sources, id: \.self) { source in
                            Text("📄 \(source)")
                                .font(.system(size: 8))
                                .foregroundStyle(theme.textTertiary)
                        }

                        HStack(spacing: 4) {
                            Text(String(format: i18n.t(.proj_ragModeLabelFmt), ragMode.rawValue))
                            if ragMode == .MANUAL {
                                Button(i18n.t(.proj_ragSwitchAuto)) { ragMode = .AUTO }
                                    .font(.system(size: 8))
                            } else if ragMode == .AUTO {
                                Button(i18n.t(.proj_ragSwitchManual)) { ragMode = .MANUAL }
                                    .font(.system(size: 8))
                            }
                        }
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textQuaternary)
                    }
                    .padding(theme.spacingXS)
                    .background(RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(theme.accent.opacity(0.06)))
                }
            }
            .padding(theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isUser ? theme.accent.opacity(0.12) : theme.textTertiary.opacity(0.04))
            )

            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, theme.spacingM)
    }

    // GUI-4 + GUI-12: Bottom bar with Agent / RAG / Budget / Send
    private func chatInputBar(chatId: String) -> some View {
        VStack(spacing: 0) {
            // GUI-12: Context budget bar
            contextBudgetBar

            Divider()
            HStack(spacing: theme.spacingS) {
                // Agent selector (GUI-10) + config button
                Menu {
                    Button(i18n.t(.proj_inputUseDefaultAgent)) { }
                    Button(i18n.t(.proj_inputGenericChat)) { }
                    Divider()
                    Button(i18n.t(.proj_inputPreviewAgent)) { }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "robot")
                            .font(.system(size: theme.iconXS))
                        Text("Agent")
                            .font(.system(size: theme.captionSize))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                    }
                    .foregroundStyle(theme.accent)
                }
                .menuStyle(.borderlessButton)

                // FS-2: Agent config button
                Button(action: { showAgentConfig = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)

                // RAG mode (GUI-17)
                Menu {
                    Button(i18n.t(.proj_inputRagAuto)) { ragMode = .AUTO }
                    Button(i18n.t(.proj_inputRagManual)) { ragMode = .MANUAL; showRAGScopeSelector = true }
                    Button(i18n.t(.proj_inputRagOff)) { ragMode = .OFF }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: theme.iconXS))
                        Text(String(format: i18n.t(.proj_inputRagLabelFmt), ragMode.rawValue))
                            .font(.system(size: theme.captionSize))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                    }
                    .foregroundStyle(ragMode == .OFF ? theme.textTertiary : theme.accent)
                }
                .menuStyle(.borderlessButton)

                // FS-3: RAG config button
                Button(action: { showRAGConfig = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)

                // Attachments dropdown
                Menu {
                    Button(i18n.t(.proj_inputAttachTemp)) { }
                    Button(i18n.t(.proj_inputAttachScreenshot)) { }
                    Button(i18n.t(.proj_inputAttachWebSearch)) { }
                    Button(i18n.t(.proj_inputAttachSkill)) { }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .menuStyle(.borderlessButton)

                // Input field — 多行输入框，占两行高度
                SendableTextEditor(
                    text: $inputText,
                    placeholder: i18n.t(.proj_inputPlaceholder),
                    font: .systemFont(ofSize: theme.footnoteSize),
                    textColor: NSColor.labelColor,
                    placeholderColor: NSColor.tertiaryLabelColor,
                    maxHeight: 60,
                    onSend: { sendMessage(chatId: chatId) },
                    refocusTrigger: $refocusTrigger
                )
                .frame(minHeight: 36, maxHeight: 60)

                FusionModelPicker(scene: .agent, selection: $selectedModel, models: agentBridge.mlxState.models, onChange: { id in
                    projLog.info("Project chat model selected: \(id)")
                })

                VoiceInputButton(voice: voiceInput, text: $inputText, onSend: { sendMessage(chatId: chatId) })

                // Send
                Button(action: { sendMessage(chatId: chatId) }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(inputText.isEmpty ? theme.textTertiary : theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
        }
        .sheet(isPresented: $showRAGScopeSelector) {
            RAGScopeSelector(projectId: projectId, ragMode: $ragMode)
        }
        .sheet(isPresented: $showAgentConfig) {
            AgentConfigSheet(projectId: projectId)
        }
        .sheet(isPresented: $showRAGConfig) {
            RAGConfigSheet(projectId: projectId, ragMode: $ragMode)
        }
    }

    // GUI-12: Context budget bar
    private var contextBudgetBar: some View {
        let ratio = tokenBudget > 0 ? Double(tokenUsed) / Double(tokenBudget) : 0
        return HStack(spacing: 8) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 9))
                .foregroundStyle(ratio > 0.9 ? theme.accentDestructive : theme.textTertiary)
            Text(formatTokenCount(tokenUsed))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.text)
            Text("/")
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
            Text(formatTokenCount(tokenBudget))
                .font(.system(size: 10))
                .foregroundStyle(theme.textTertiary)
            ProgressView(value: ratio)
                .progressViewStyle(.linear)
                .tint(ratio > 0.9 ? theme.accentDestructive : ratio > 0.7 ? .yellow : theme.accent)
                .frame(maxWidth: 120)
            Text(String(format: "%.0f%%", ratio * 100))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(ratio > 0.9 ? theme.accentDestructive : theme.textTertiary)
            if ratio > 0.9 {
                Text(i18n.t(.proj_budgetLow))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.accentDestructive)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, 3)
        .background(theme.surfaceSecondary)
    }

    private func formatTokenCount(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000.0) }
        return "\(n)"
    }

    private func refreshBudget() {
        Task {
            do {
                let r = try await ipc.contextBudget()
                let used = r["used"] as? Int ?? r["token_used"] as? Int ?? 0
                let budget = r["budget"] as? Int ?? r["total_budget"] as? Int ?? 128000
                await MainActor.run { tokenUsed = used; tokenBudget = budget }
            } catch {
                projLog.error("refreshBudget failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Actions

    private func loadChats() {
        Task {
            do {
                let result = try await ipc.projectChatList(projectId: projectId)
                if let items = result["items"] as? [[String: Any]] ?? result["chats"] as? [[String: Any]] {
                    await MainActor.run {
                        self.chats = items.compactMap { ProjectChat.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadChats failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadSnapshots() {
        Task {
            do {
                let result = try await ipc.projectChatSnapshotList(chatId: activeChatId ?? "")
                if let items = result["items"] as? [[String: Any]] ?? result["snapshots"] as? [[String: Any]] {
                    await MainActor.run {
                        self.snapshots = items.compactMap { d in
                            ChatSnapshot(
                                id: d["id"] as? String ?? "",
                                chatId: d["chat_id"] as? String ?? "",
                                label: d["label"] as? String ?? "Snapshot",
                                messageCount: d["message_count"] as? Int ?? 0,
                                createdAt: ISO8601DateFormatter().date(from: d["created_at"] as? String ?? "") ?? Date()
                            )
                        }
                    }
                }
            } catch {
                projLog.error("loadSnapshots failed: \(error.localizedDescription)")
            }
        }
    }

    private func createNewChat() {
        Task {
            do {
                let result = try await ipc.projectChatCreate(projectId: projectId, title: "New Chat")
                let chat = ProjectChat.fromDict(result)
                await MainActor.run {
                    self.chats.insert(chat, at: 0)
                    self.activeChatId = chat.id
                }
                projLog.info("Chat created in project \(projectId)")
            } catch {
                projLog.error("createNewChat failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = String(format: i18n.t(.proj_chatsCreateFailFmt), error.localizedDescription)
                    self.showError = true
                }
            }
        }
    }

    private func loadMessages(chatId: String) {
        Task {
            do {
                let result = try await ipc.projectMessageList(chatId: chatId)
                if let items = result["items"] as? [[String: Any]] ?? result["messages"] as? [[String: Any]] {
                    await MainActor.run {
                        self.messages = items.compactMap { ChatMessage.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadMessages failed: \(error.localizedDescription)")
            }
        }
    }

    private func sendMessage(chatId: String) {
        if voiceInput.isRecording {
            let transcript = voiceInput.stopRecording()
            let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                inputText += (inputText.isEmpty ? "" : " ") + trimmed
            }
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task {
            do {
                let result = try await ipc.projectMessageAdd(
                    chatId: chatId, content: text,
                    ragMode: ragMode == .OFF ? nil : ragMode.rawValue
                )
                let userMsg = ChatMessage.fromDict(result)
                await MainActor.run { self.messages.append(userMsg) }
                await generateReply(chatId: chatId)
            } catch {
                projLog.error("sendMessage failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = String(format: i18n.t(.proj_chatsSendFailFmt), error.localizedDescription)
                    self.showError = true
                }
            }
        }
    }

    // 生成 AI 回复：用当前会话历史调 MLX /v1/chat/completions，回填到 messages。
    // 上游 project.chat.message.add 暂不接 role 字段（强制 user），assistant 回复先本地展示，
    // 待上游 PR 支持后落库。
    private func generateReply(chatId: String) async {
        let cfg = FusionConfig.shared
        let model = selectedModel.isEmpty ? cfg.defaultModel(for: .agent) : selectedModel
        if model.isEmpty {
            projLog.error("generateReply: no model selected, cannot infer")
            await MainActor.run {
                self.errorMessage = i18n.t(.proj_chatsNoModel)
                self.showError = true
            }
            return
        }
        var hist: [[String: Any]] = []
        for m in messages {
            hist.append(["role": m.role, "content": m.content])
        }
        do {
            let reply = try await agentBridge.infer(messages: hist, model: model)
            let assistantMsg = ChatMessage(id: UUID().uuidString, role: "assistant", content: reply)
            await MainActor.run { self.messages.append(assistantMsg) }
            projLog.info("generateReply: reply \(reply.count) chars for chat \(chatId)")
        } catch {
            projLog.error("generateReply infer failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = String(format: i18n.t(.proj_chatsReplyFailFmt), error.localizedDescription)
                self.showError = true
            }
        }
    }
}

// MARK: - GUI-7: Chat Context Menu

private struct ChatContextMenu: View {
    let chat: ProjectChat
    let projectId: String
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var showDeleteConfirm = false

    var body: some View {
        Menu {
            Button(action: { toggleStar() }) {
                Label(chat.isStarred ? i18n.t(.proj_chatMenuUnstar) : i18n.t(.proj_chatMenuStar),
                      systemImage: chat.isStarred ? "star.slash" : "star")
            }
            Button(action: {}) {
                Label(i18n.t(.proj_chatMenuRename), systemImage: "pencil")
            }
            Divider()
            // GUI-7: Fork & Snapshot (Fusion unique)
            Button(action: { forkChat() }) {
                Label(i18n.t(.proj_chatMenuFork), systemImage: "arrow.triangle.branch")
            }
            Button(action: { createSnapshot() }) {
                Label(i18n.t(.proj_chatMenuSnapshot), systemImage: "camera")
            }
            Divider()
            Button(action: {}) {
                Label(i18n.t(.proj_chatMenuMove), systemImage: "arrow.right.doc")
            }
            Button(action: {}) {
                Label(i18n.t(.proj_chatMenuRemove), systemImage: "doc.text.magnifyingglass")
            }
            Divider()
            Button(role: .destructive, action: { showDeleteConfirm = true }) {
                Label(i18n.t(.proj_chatMenuDelete), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 8))
                .foregroundStyle(theme.textTertiary)
        }
        .menuStyle(.borderlessButton)
        .alert(i18n.t(.proj_chatDeleteAlertTitle), isPresented: $showDeleteConfirm) {
            Button(i18n.t(.cancel), role: .cancel) {}
            Button(i18n.t(.delete), role: .destructive) { deleteChat() }
        }
    }

    private func toggleStar() {
        Task {
            _ = try await ipc.projectChatStar(chatId: chat.id, starred: !chat.isStarred)
        }
    }

    private func forkChat() {
        Task {
            _ = try await ipc.projectChatFork(chatId: chat.id, label: nil)
            projLog.info("Chat forked: \(chat.id)")
        }
    }

    private func createSnapshot() {
        Task {
            _ = try await ipc.projectChatSnapshotCreate(chatId: chat.id, label: nil)
            projLog.info("Snapshot created for chat: \(chat.id)")
        }
    }

    private func deleteChat() {
        Task {
            try await ipc.projectChatDelete(chatId: chat.id)
        }
    }
}

// MARK: - FS-2: Agent Config Sheet

struct AgentConfigSheet: View {
    let projectId: String
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAgentId: String?
    @State private var availableAgents: [AgentMeta] = []
    @State private var promptMergeMode: PromptMergeMode = .AGENT_FIRST
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            Text(i18n.t(.proj_agentConfigTitle))
                .font(.system(size: theme.headlineSize, weight: .bold))

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_agentConfigDefault))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Menu {
                    Button(i18n.t(.proj_createNoAgent)) { selectedAgentId = nil }
                    Divider()
                    ForEach(availableAgents) { agent in
                        Button(agent.name) { selectedAgentId = agent.id }
                    }
                } label: {
                    HStack {
                        Text(agentDisplayName)
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: theme.footnoteSize))
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.textTertiary.opacity(0.2)))
                }
                .menuStyle(.borderlessButton)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_agentConfigPromptMerge))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $promptMergeMode) {
                    Text(i18n.t(.proj_createMergeAgentFirst)).tag(PromptMergeMode.AGENT_FIRST)
                    Text(i18n.t(.proj_createMergeProjectOnly)).tag(PromptMergeMode.PROJECT_ONLY)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Button(i18n.t(.save)) { saveConfig() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.accent))
                    .disabled(isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 360)
        .onAppear { loadAgents() }
    }

    private var agentDisplayName: String {
        selectedAgentId.flatMap { id in availableAgents.first(where: { $0.id == id })?.name } ?? i18n.t(.proj_createNoAgentShort)
    }

    private func loadAgents() {
        Task {
            do {
                let result = try await ipc.projectAgentList()
                if let items = result["agents"] as? [[String: Any]] ?? result["items"] as? [[String: Any]] {
                    await MainActor.run { availableAgents = items.compactMap { AgentMeta.fromDict($0) } }
                }
            } catch {
                projLog.error("AgentConfigSheet loadAgents failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveConfig() {
        isSaving = true
        Task {
            do {
                _ = try await ipc.projectAgentSet(projectId: projectId, agentId: selectedAgentId,
                                                   mergeMode: promptMergeMode.rawValue)
                projLog.info("AgentConfig saved for project \(projectId)")
                await MainActor.run { dismiss() }
            } catch {
                projLog.error("AgentConfig save failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - FS-3: RAG Config Sheet

struct RAGConfigSheet: View {
    let projectId: String
    @Binding var ragMode: RAGMode
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var ragTopK: Int = 5
    @State private var ragThreshold: Double = 0.5
    @State private var isSaving = false
    @State private var showScopeSelector = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            Text(i18n.t(.proj_ragConfigTitle))
                .font(.system(size: theme.headlineSize, weight: .bold))

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_ragConfigMode))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $ragMode) {
                    Text(i18n.t(.proj_createRagAuto)).tag(RAGMode.AUTO)
                    Text(i18n.t(.proj_createRagManual)).tag(RAGMode.MANUAL)
                    Text(i18n.t(.proj_inputRagOff)).tag(RAGMode.OFF)
                }
                .pickerStyle(.segmented)
                .font(.system(size: theme.captionSize))
            }

            if ragMode != .OFF {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Text(String(format: i18n.t(.proj_ragConfigTopKFmt), ragTopK))
                            .font(.system(size: theme.captionSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                    }
                    Slider(value: Binding(
                        get: { Double(ragTopK) },
                        set: { ragTopK = Int($0) }
                    ), in: 1...20, step: 1)
                    .tint(theme.accent)
                }

                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Text(String(format: i18n.t(.proj_ragConfigThresholdFmt), String(format: "%.2f", ragThreshold)))
                            .font(.system(size: theme.captionSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                    }
                    Slider(value: $ragThreshold, in: 0.1...0.99, step: 0.05)
                        .tint(theme.accent)
                }
            }

            if ragMode == .MANUAL {
                Button(action: { showScopeSelector = true }) {
                    Label(i18n.t(.proj_ragConfigSelectScope), systemImage: "folder.badge.plus")
                }
                .font(.system(size: theme.footnoteSize))
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Button(i18n.t(.save)) { saveConfig() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.accent))
                    .disabled(isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 420)
        .onAppear { loadCurrentConfig() }
        .sheet(isPresented: $showScopeSelector) {
            RAGScopeSelector(projectId: projectId, ragMode: $ragMode)
        }
    }

    private func loadCurrentConfig() {
        Task {
            do {
                let r = try await ipc.projectRagConfigGet(projectId: projectId)
                let topK = r["top_k"] as? Int ?? r["rag_top_k"] as? Int ?? 5
                let threshold = r["threshold"] as? Double ?? r["rag_threshold"] as? Double ?? 0.5
                await MainActor.run { ragTopK = topK; ragThreshold = threshold }
            } catch {
                projLog.error("RAGConfigSheet load failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveConfig() {
        isSaving = true
        Task {
            do {
                _ = try await ipc.projectRagConfigSet(projectId: projectId, ragMode: ragMode.rawValue,
                                                       ragTopK: ragTopK, ragThreshold: ragThreshold)
                projLog.info("RAGConfig saved for project \(projectId)")
                await MainActor.run { dismiss() }
            } catch {
                projLog.error("RAGConfig save failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - GUI-9: Project Settings Panel

struct ProjectSettingsPanel: View {
    let project: FusionProject
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var desc: String
    @State private var selectedAgentId: String?
    @State private var promptMergeMode: PromptMergeMode
    @State private var ragMode: RAGMode
    @State private var ragTopK: Int
    @State private var ragThreshold: Double
    @State private var availableAgents: [AgentMeta] = []
    @State private var isSaving = false

    init(project: FusionProject) {
        self.project = project
        _name = State(initialValue: project.name)
        _desc = State(initialValue: project.description)
        _selectedAgentId = State(initialValue: project.defaultAgentId)
        _promptMergeMode = State(initialValue: project.promptMergeMode)
        _ragMode = State(initialValue: project.ragMode)
        _ragTopK = State(initialValue: project.ragTopK)
        _ragThreshold = State(initialValue: project.ragThreshold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            Text(String(format: i18n.t(.proj_settingsTitleFmt), project.name))
                .font(.system(size: theme.headlineSize, weight: .bold))

            // Basic info
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_settingsBasicInfo))
                    .font(.system(size: theme.textSize, weight: .semibold))
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.proj_settingsNameLabel))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                    TextField(i18n.t(.proj_namePh), text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.proj_settingsDescLabel))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                    TextField(i18n.t(.proj_settingsDescPh), text: $desc)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Divider()

            // Agent config
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_settingsAgentConfig))
                    .font(.system(size: theme.textSize, weight: .semibold))

                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.proj_agentConfigDefault))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                    Menu {
                        Button(i18n.t(.proj_createNoAgent)) { selectedAgentId = nil }
                        Divider()
                        ForEach(availableAgents) { agent in
                            Button(agent.name) { selectedAgentId = agent.id }
                        }
                    } label: {
                        HStack {
                            Text(agentDisplayName)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .font(.system(size: theme.footnoteSize))
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .stroke(theme.textTertiary.opacity(0.2)))
                    }
                    .menuStyle(.borderlessButton)
                }

                Text(i18n.t(.proj_settingsPromptMerge))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                Picker("", selection: $promptMergeMode) {
                    Text(i18n.t(.proj_settingsMergeAgentFirst)).tag(PromptMergeMode.AGENT_FIRST)
                    Text(i18n.t(.proj_settingsMergeProjectOnly)).tag(PromptMergeMode.PROJECT_ONLY)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))
            }

            Divider()

            // RAG config
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.proj_settingsRagConfig))
                    .font(.system(size: theme.textSize, weight: .semibold))

                Picker(i18n.t(.proj_ragConfigMode), selection: $ragMode) {
                    Text(i18n.t(.proj_settingsRagAuto)).tag(RAGMode.AUTO)
                    Text(i18n.t(.proj_settingsRagManual)).tag(RAGMode.MANUAL)
                    Text(i18n.t(.proj_createRagOff)).tag(RAGMode.OFF)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))

                HStack(spacing: theme.spacingM) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.proj_settingsTopK))
                        Picker("", selection: $ragTopK) {
                            ForEach(1...20, id: \.self) { k in
                                Text("\(k)").tag(k)
                            }
                        }
                        .frame(width: 80)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.proj_settingsThreshold))
                        Picker("", selection: $ragThreshold) {
                            ForEach(Array(stride(from: 0.1, through: 0.99, by: 0.05)), id: \.self) { v in
                                Text(String(format: "%.2f", v)).tag(v)
                            }
                        }
                        .frame(width: 80)
                    }
                }
                .font(.system(size: theme.captionSize))
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                Button(i18n.t(.proj_settingsSaveBtn)) { saveSettings() }
                    .disabled(isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 560, height: 620)
        .onAppear { loadAgents() }
    }

    private var agentDisplayName: String {
        selectedAgentId.flatMap { id in availableAgents.first(where: { $0.id == id })?.name } ?? i18n.t(.proj_createNoAgentShort)
    }

    private func loadAgents() {
        Task {
            do {
                let result = try await ipc.projectAgentList()
                if let items = result["agents"] as? [[String: Any]] ?? result["items"] as? [[String: Any]] {
                    await MainActor.run {
                        availableAgents = items.compactMap { AgentMeta.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadAgents failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveSettings() {
        isSaving = true
        Task {
            do {
                _ = try await ipc.projectUpdate(projectId: project.id, fields: ["name": name, "description": desc])
                _ = try await ipc.projectAgentSet(projectId: project.id, agentId: selectedAgentId,
                                                    mergeMode: promptMergeMode.rawValue)
                _ = try await ipc.projectRagConfigSet(projectId: project.id, ragMode: ragMode.rawValue,
                                                        ragTopK: ragTopK, ragThreshold: ragThreshold)
                projLog.info("Settings saved for project \(project.id)")
                await MainActor.run { dismiss() }
            } catch {
                projLog.error("saveSettings failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - GUI-11: Agent Preview Card

private struct ProjectAgentPreview: View {
    let project: FusionProject
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Image(systemName: "robot")
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(theme.accent)
                Text(project.agentName ?? i18n.t(.proj_previewUnbound))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            if let binding = project.agentBinding {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    if let prompt = binding.agentPrompt {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(i18n.t(.proj_previewRole))
                                .font(.system(size: theme.captionSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            Text(String(prompt.prefix(200)))
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.text)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.proj_previewActiveConfig))
                            .font(.system(size: theme.captionSize, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                        Text(String(format: i18n.t(.proj_previewPromptStrategyFmt), binding.mergeMode == .AGENT_FIRST ? i18n.t(.proj_previewPromptAgentFirst) : i18n.t(.proj_previewPromptProjectOnly)))
                        Text(String(format: i18n.t(.proj_previewRagModeFmt), project.ragMode.rawValue, project.ragTopK, String(project.ragThreshold)))
                        Text(i18n.t(.proj_previewAccessKb))
                    }
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                }
            } else {
                Text(i18n.t(.proj_previewUnboundHint))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 0)

            HStack {
                Button(i18n.t(.proj_previewGotoAgentStudio)) { }
                    .font(.system(size: theme.footnoteSize))
                Spacer()
                Button(i18n.t(.close)) { dismiss() }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400, height: 320)
    }
}

// MARK: - GUI-13: CoWork Import Dialog

private struct CoWorkImportDialog: View {
    let project: FusionProject
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ipc: IPCClient

    @State private var selectedSpaceId: String?
    @State private var includeKnowledge = true
    @State private var includeSnapshots = false
    @State private var isImporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.proj_coworkTitle))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.proj_coworkTarget))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                Text(i18n.t(.proj_coworkTargetPlaceholder))
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
            }

            Text(i18n.t(.proj_coworkSyncContent))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Toggle(i18n.t(.proj_coworkSyncKnowledge), isOn: $includeKnowledge)
            Toggle(i18n.t(.proj_coworkSyncSnapshots), isOn: $includeSnapshots)

            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(i18n.t(.proj_coworkWarning))
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                Button(i18n.t(.proj_coworkConfirm)) { importToCoWork() }
                    .disabled(isImporting)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 340)
    }

    private func importToCoWork() {
        isImporting = true
        Task {
            do {
                _ = try await ipc.projectCoworkTrigger(
                    projectId: project.id,
                    action: "import",
                    payload: [
                        "include_knowledge": includeKnowledge,
                        "include_snapshots": includeSnapshots
                    ]
                )
                projLog.info("Imported to CoWork from project \(project.id)")
                await MainActor.run { dismiss() }
            } catch {
                projLog.error("importToCoWork failed: \(error.localizedDescription)")
                await MainActor.run { isImporting = false }
            }
        }
    }
}

// MARK: - GUI-17: RAG Scope Selector (MANUAL mode)

private struct RAGScopeSelector: View {
    let projectId: String
    @Binding var ragMode: RAGMode
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ipc: IPCClient

    @State private var folders: [KnowledgeFolder] = []
    @State private var files: [KnowledgeFile] = []
    @State private var selectedFolderIds: Set<String> = []
    @State private var selectedFileIds: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.proj_ragScopeTitle))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Picker(i18n.t(.proj_ragScopeMode), selection: $ragMode) {
                Text(i18n.t(.proj_ragScopeAuto)).tag(RAGMode.AUTO)
                Text(i18n.t(.proj_ragScopeManual)).tag(RAGMode.MANUAL)
            }
            .pickerStyle(.radioGroup)
            .font(.system(size: theme.captionSize))

            if ragMode == .MANUAL {
                Text(i18n.t(.proj_ragScopeSpecify))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacingXS) {
                        ForEach(folders) { folder in
                            HStack {
                                Toggle(folder.name, isOn: Binding(
                                    get: { selectedFolderIds.contains(folder.id) },
                                    set: { v in
                                        if v { selectedFolderIds.insert(folder.id) } else { selectedFolderIds.remove(folder.id) }
                                    }
                                ))
                                .font(.system(size: theme.footnoteSize))
                            }

                            let folderFiles = files.filter { $0.folderId == folder.id }
                            ForEach(folderFiles) { file in
                                HStack {
                                    Text("    ")
                                    Toggle(file.fileName, isOn: Binding(
                                        get: { selectedFileIds.contains(file.id) },
                                        set: { v in
                                            if v { selectedFileIds.insert(file.id) } else { selectedFileIds.remove(file.id) }
                                        }
                                    ))
                                    .font(.system(size: theme.captionSize))
                                }
                            }
                        }

                        let rootFiles = files.filter { $0.folderId == nil }
                        ForEach(rootFiles) { file in
                            Toggle(file.fileName, isOn: Binding(
                                get: { selectedFileIds.contains(file.id) },
                                set: { v in
                                    if v { selectedFileIds.insert(file.id) } else { selectedFileIds.remove(file.id) }
                                }
                            ))
                            .font(.system(size: theme.footnoteSize))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                Button(i18n.t(.proj_ragScopeConfirm)) {
                    saveRAGConfig()
                    dismiss()
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 460)
        .onAppear { loadKnowledge() }
    }

    private func loadKnowledge() {
        Task {
            do {
                async let f = ipc.projectFolderList(projectId: projectId)
                async let fl = ipc.projectKnowledgeFileList(projectId: projectId)
                let foldersResult = try await f
                let filesResult = try await fl
                await MainActor.run {
                    if let items = foldersResult["items"] as? [[String: Any]] ?? foldersResult["folders"] as? [[String: Any]] {
                        self.folders = items.compactMap { KnowledgeFolder.fromDict($0) }
                    }
                    if let items = filesResult["items"] as? [[String: Any]] ?? filesResult["files"] as? [[String: Any]] {
                        self.files = items.compactMap { KnowledgeFile.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadKnowledge failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveRAGConfig() {
        Task {
            do {
                _ = try await ipc.projectRagConfigSet(
                    projectId: projectId,
                    ragMode: ragMode.rawValue
                )
            } catch {
                projLog.error("saveRAGConfig failed: \(error.localizedDescription)")
            }
        }
    }
}
