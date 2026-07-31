// Callers: SectionContentView (case .projects)
// Affected API: ProjectsPanel (full rewrite — uses FusionProjectManager instead of ProjectWorkspace)
// Data schemas: FusionProject, KnowledgeFile, ProjectSession, ProjectSettings, FusionProjectManager
// User instruction: "立即落地fusion projects"

import SwiftUI
import os.log

private let projectsLog = Logger(subsystem: "com.fusion.studio", category: "ProjectsPanel")

enum ProjectSortOption: String, CaseIterable {
    case lastUpdated = "Last Updated"
    case dateCreated = "Date Created"
    case alphabetical = "Alphabetical"
}

enum ProjectDetailTab: String, CaseIterable {
    case knowledge = "Knowledge"
    case instructions = "Instructions"
    case sessions = "Sessions"
    case settings = "Settings"
}

struct ProjectsPanel: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var pm = FusionProjectManager.shared
    @State private var searchText = ""
    @State private var sortOption: ProjectSortOption = .lastUpdated
    @State private var showDetail = false
    @State private var detailTab: ProjectDetailTab = .knowledge
    @State private var instructionText = ""

    private var sortedProjects: [FusionProject] {
        var result = pm.projects
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.rootPath.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortOption {
        case .lastUpdated:
            return result.sorted { $0.updatedAt > $1.updatedAt }
        case .dateCreated:
            return result.sorted { $0.createdAt > $1.createdAt }
        case .alphabetical:
            return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                projectListView
                    .frame(width: max(280, geo.size.width * 0.4))
                Rectangle().fill(theme.separator).frame(width: 1)

                if let project = pm.activeProject, showDetail {
                    projectDetailView(project)
                } else {
                    emptyDetailState
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Project List

    private var projectListView: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)

            if sortedProjects.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedProjects) { project in
                            projectRow(project)
                        }
                    }
                }
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Text("Projects")
                .font(.system(size: theme.titleSize, weight: .semibold))
                .foregroundStyle(theme.text)

            Spacer()

            Button(action: { searchText = "" }) {
                Image(systemName: searchText.isEmpty ? "magnifyingglass" : "xmark.circle.fill")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(ProjectSortOption.allCases, id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Sort:")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                    Text(sortOption.rawValue)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Button(action: { openLocalFolder() }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconXS))
                    Text("New")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                }
                .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)
            Text("Looking to start a project?")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Text("Upload materials, set custom instructions, and organize conversations in one space.")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button(action: { openLocalFolder() }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "plus")
                    Text("New Project")
                        .font(.system(size: theme.textSize, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
                .background(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(theme.accent))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectRow(_ project: FusionProject) -> some View {
        Button(action: {
            pm.openProject(project)
            showDetail = true
            instructionText = project.customInstructions
        }) {
            HStack(spacing: theme.spacingM) {
                Image(systemName: pm.activeProject?.id == project.id ? "folder.fill" : "folder")
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(pm.activeProject?.id == project.id ? theme.accent : theme.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(pm.activeProject?.id == project.id ? theme.accent.opacity(0.1) : theme.textTertiary.opacity(0.05))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)

                    HStack(spacing: theme.spacingXS) {
                        Text(project.rootPath)
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if project.hasKnowledge {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(theme.accent)
                        }
                        if project.hasInstructions {
                            Image(systemName: "text.badge.star")
                                .font(.system(size: 8))
                                .foregroundStyle(theme.accent)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(relativeTime(project.updatedAt))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                    if project.hasKnowledge {
                        Text("\(project.knowledgeFiles.count) files")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(theme.textQuaternary)
                    }
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(pm.activeProject?.id == project.id ? theme.accent.opacity(0.05) : Color.clear)
    }

    // MARK: - Project Detail

    private func projectDetailView(_ project: FusionProject) -> some View {
        VStack(spacing: 0) {
            detailHeader(project)
            Rectangle().fill(theme.separator).frame(height: 1)
            detailTabBar
            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView {
                switch detailTab {
                case .knowledge: knowledgeTab(project)
                case .instructions: instructionsTab(project)
                case .sessions: sessionsTab(project)
                case .settings: settingsTab(project)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailHeader(_ project: FusionProject) -> some View {
        HStack(spacing: theme.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: theme.titleSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(project.rootPath)
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: { pm.closeProject(); showDetail = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
    }

    private var detailTabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProjectDetailTab.allCases, id: \.self) { tab in
                Button(action: { detailTab = tab }) {
                    HStack(spacing: 4) {
                        Image(systemName: tabIcon(tab))
                            .font(.system(size: theme.iconXS))
                        Text(tab.rawValue)
                            .font(.system(size: theme.footnoteSize, weight: detailTab == tab ? .medium : .regular))
                    }
                    .foregroundStyle(detailTab == tab ? theme.accent : theme.textTertiary)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS)
                    .background(detailTab == tab ? theme.accent.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, theme.spacingXS)
    }

    private func tabIcon(_ tab: ProjectDetailTab) -> String {
        switch tab {
        case .knowledge: return "doc.text"
        case .instructions: return "text.badge.star"
        case .sessions: return "bubble.left.and.bubble.right"
        case .settings: return "gearshape"
        }
    }

    // MARK: - Knowledge Tab

    private func knowledgeTab(_ project: FusionProject) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text("Knowledge Base")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Text("\(project.totalKnowledgeTokens) tokens")
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }

            if project.knowledgeFiles.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.textTertiary)
                    Text("No knowledge files yet")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingXL)
            } else {
                ForEach(project.knowledgeFiles) { file in
                    knowledgeFileRow(file, project: project)
                }
            }

            HStack(spacing: theme.spacingS) {
                Button(action: { addKnowledgeFile() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add File")
                    }
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)

                Button(action: { scanKnowledge() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                        Text("Auto Scan")
                    }
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.spacingL)
    }

    private func knowledgeFileRow(_ file: KnowledgeFile, project: FusionProject) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Text("\(file.tokenCount) tokens")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.textQuaternary)
            }

            Spacer()

            Button(action: { removeKnowledgeFile(file.id) }) {
                Image(systemName: "minus.circle")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.textTertiary.opacity(0.05)))
    }

    // MARK: - Instructions Tab

    private func instructionsTab(_ project: FusionProject) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("Custom Instructions")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            TextEditor(text: $instructionText)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .scrollContentBackground(.hidden)
                .foregroundStyle(theme.text)
                .padding(theme.spacingS)
                .frame(minHeight: 200)
                .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .stroke(theme.textTertiary.opacity(0.2), lineWidth: 1))

            HStack {
                Text("\(estimateTokenCount(instructionText)) tokens")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.textQuaternary)
                Spacer()
                Button(action: { saveInstructions() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Save")
                    }
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingXS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.accent))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.spacingL)
        .onAppear {
            instructionText = project.customInstructions
        }
    }

    // MARK: - Sessions Tab

    private func sessionsTab(_ project: FusionProject) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text("Chat History")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Text("\(project.chats.count) sessions")
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
            }

            if project.chats.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.textTertiary)
                    Text("No chat sessions yet")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingXL)
            } else {
                ForEach(project.chats) { session in
                    sessionRow(session, project: project)
                }
            }
        }
        .padding(theme.spacingL)
    }

    private func sessionRow(_ session: ProjectSession, project: FusionProject) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                HStack(spacing: theme.spacingXS) {
                    Text("\(session.messageCount) msgs")
                    Text("·")
                    Text("\(session.tokenUsage) tokens")
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(theme.textQuaternary)
            }

            Spacer()

            Button(action: { pm.loadSession(session) }) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)

            Button(action: { deleteSession(session) }) {
                Image(systemName: "trash")
                    .font(.system(size: theme.iconXS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.textTertiary.opacity(0.05)))
    }

    // MARK: - Settings Tab

    private func settingsTab(_ project: FusionProject) -> some View {
        SettingsTabContent(project: project, theme: theme)
    }

    private var emptyDetailState: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "arrow.left")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text("Select a project")
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func openLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Open Project Folder"
        panel.prompt = "Open"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let project = pm.createProject(name: url.lastPathComponent, rootPath: url.path)
        pm.openProject(project)
        showDetail = true

        if project.settings.autoScanKnowledge {
            pm.scanKnowledgeFiles(projectId: project.id)
        }
    }

    private func addKnowledgeFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.title = "Add Knowledge Files"

        guard panel.runModal() == .OK else { return }
        guard let project = pm.activeProject else { return }

        for url in panel.urls {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attrs?[.size] as? Int64) ?? 0
            let kf = KnowledgeFile(
                fileName: url.lastPathComponent,
                filePath: url.path,
                fileSize: size,
                tokenCount: estimateTokenCountFromFile(at: url.path),
                scope: .project
            )
            pm.addKnowledgeFile(kf, projectId: project.id)
        }
    }

    private func scanKnowledge() {
        guard let project = pm.activeProject else { return }
        pm.scanKnowledgeFiles(projectId: project.id)
    }

    private func removeKnowledgeFile(_ id: String) {
        guard let project = pm.activeProject else { return }
        pm.removeKnowledgeFile(id: id, projectId: project.id)
    }

    private func saveInstructions() {
        guard var project = pm.activeProject else { return }
        project.customInstructions = instructionText
        pm.updateProject(project)
    }

    private func deleteSession(_ session: ProjectSession) {
        guard let project = pm.activeProject else { return }
        pm.deleteSession(session, projectId: project.id)
    }

    // MARK: - Helpers

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func estimateTokenCount(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    private func estimateTokenCountFromFile(at path: String) -> Int {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return 0 }
        return estimateTokenCount(content)
    }
}

// MARK: - Settings Tab (extracted to avoid @State in computed property)

private struct SettingsTabContent: View {
    let project: FusionProject
    let theme: StudioTheme

    @State private var defaultModel: String
    @State private var temperature: Double
    @State private var maxTokens: Int
    @State private var autoLoadClaudeMd: Bool
    @State private var autoScanKnowledge: Bool

    init(project: FusionProject, theme: StudioTheme) {
        self.project = project
        self.theme = theme
        _defaultModel = State(initialValue: project.settings.defaultModel)
        _temperature = State(initialValue: project.settings.temperature)
        _maxTokens = State(initialValue: project.settings.maxTokens)
        _autoLoadClaudeMd = State(initialValue: project.settings.autoLoadClaudeMd)
        _autoScanKnowledge = State(initialValue: project.settings.autoScanKnowledge)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("Project Settings")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("Default Model")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                TextField("e.g. qwen3-9b", text: $defaultModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: theme.footnoteSize))
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("Temperature: \(String(format: "%.1f", temperature))")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                Slider(value: $temperature, in: 0...2, step: 0.1)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("Max Tokens: \(maxTokens)")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                Stepper(value: $maxTokens, in: 256...8192, step: 256) {
                    Text("\(maxTokens)")
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                }
            }

            Toggle("Auto-load CLAUDE.md", isOn: $autoLoadClaudeMd)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.text)

            Toggle("Auto-scan knowledge files", isOn: $autoScanKnowledge)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.text)

            Button(action: { saveSettings() }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Save Settings")
                }
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
                .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingL)
    }

    private func saveSettings() {
        var p = project
        p.settings = ProjectSettings(
            defaultModel: defaultModel,
            temperature: temperature,
            maxTokens: maxTokens,
            autoLoadClaudeMd: autoLoadClaudeMd,
            autoScanKnowledge: autoScanKnowledge
        )
        FusionProjectManager.shared.updateProject(p)
    }
}
