// Callers: AIAgentConfigView knowledge tab, AIAgentDashboardView "新建知识库" quick action
// Affected API: ipc.projectList/projectCreate/projectDelete/projectGet/projectUpdate,
//   ipc.projectInstructionGet/Save, projectArtifactList/Remove
// Data schema: backend project { id, name, description, status, created_at, artifacts[] }
// User instruction: "补建知识库管理独立视图 — PRD Prototype 7"

import SwiftUI
import os.log

private let kbLog = Logger(subsystem: "com.fusion.studio", category: "AIAgent.KnowledgeBase")

struct AIAgentKnowledgeBaseView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme

    @State private var projects: [[String: Any]] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var selectedProjectId: String?
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            if isLoading {
                Spacer()
                ProgressView("加载中...")
                Spacer()
            } else if filteredProjects.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                projectList
            }
        }
        .background(theme.contentBg)
        .onAppear { loadProjects() }
        .sheet(isPresented: $showCreateSheet) {
            CreateProjectSheet { name, desc in
                createProject(name: name, description: desc)
            }
        }
        .sheet(isPresented: $showDetail) {
            if let pid = selectedProjectId {
                KBProjectDetailView(projectId: pid)
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingM) {
            Text("知识库管理")
                .font(.system(size: theme.titleSize, weight: .bold))
                .foregroundStyle(theme.text)
            Spacer()
            HStack(spacing: theme.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                TextField("搜索项目...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.text)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .background(theme.surfaceElevated)
            .cornerRadius(theme.cornerRadiusSmall)

            Button(action: { showCreateSheet = true }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "plus")
                    Text("新建项目")
                }
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
                .background(theme.accent)
                .cornerRadius(theme.cornerRadiusSmall)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingS) {
                ForEach(Array(filteredProjects.enumerated()), id: \.offset) { _, project in
                    projectRow(project)
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)
        }
    }

    private func projectRow(_ project: [String: Any]) -> some View {
        let pid = project["id"] as? String ?? ""
        let name = project["name"] as? String ?? "未命名"
        let desc = project["description"] as? String ?? ""
        let status = project["status"] as? String ?? "active"
        let createdAt = project["created_at"] as? Double ?? 0

        return HStack(spacing: theme.spacingM) {
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.auxiliary)
                    Text(name)
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    statusBadge(status)
                }
                if !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                Text("创建于 \(formatTimestamp(createdAt))")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            HStack(spacing: theme.spacingS) {
                Button("详情") {
                    selectedProjectId = pid
                    showDetail = true
                }
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.accent)
                .buttonStyle(.plain)

                Button("删除") {
                    deleteProject(id: pid)
                }
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.accentDestructive)
                .buttonStyle(.plain)
            }
        }
        .padding(theme.spacingM)
        .background(theme.surfaceElevated)
        .cornerRadius(theme.cornerRadius)
        .onTapGesture {
            selectedProjectId = pid
            showDetail = true
        }
    }

    private func statusBadge(_ status: String) -> some View {
        let color = status == "active" ? theme.accent : theme.textTertiary
        return Text(status == "active" ? "活跃" : status)
            .font(.system(size: theme.captionSize, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("暂无知识库项目")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Text("创建项目，上传文档，为 Agent 提供知识支撑")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var filteredProjects: [[String: Any]] {
        if searchText.isEmpty { return projects }
        return projects.filter { proj in
            let name = proj["name"] as? String ?? ""
            let desc = proj["description"] as? String ?? ""
            return name.localizedCaseInsensitiveContains(searchText)
                || desc.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func loadProjects() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.projectList()
                let list = result["projects"] as? [[String: Any]] ?? []
                kbLog.info("Loaded \(list.count) projects")
                await MainActor.run { projects = list; isLoading = false }
            } catch {
                kbLog.error("Load projects failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func createProject(name: String, description: String) {
        Task {
            do {
                _ = try await ipc.projectCreate(name: name, description: description)
                kbLog.info("Project created: \(name)")
                loadProjects()
            } catch {
                kbLog.error("Create project failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteProject(id: String) {
        Task {
            do {
                _ = try await ipc.projectDelete(projectId: id)
                kbLog.info("Project deleted: \(id)")
                loadProjects()
            } catch {
                kbLog.error("Delete project failed: \(error.localizedDescription)")
            }
        }
    }

    private func formatTimestamp(_ ts: Double) -> String {
        guard ts > 0 else { return "-" }
        let date = Date(timeIntervalSince1970: ts)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Create Project Sheet

private struct CreateProjectSheet: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let onCreate: (String, String) -> Void

    @State private var name = ""
    @State private var description = ""

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("新建知识库项目")
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("项目名称")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField("输入项目名称", text: $name)
                    .textFieldStyle(.plain)
                    .padding(theme.spacingS)
                    .background(theme.surfaceElevated)
                    .cornerRadius(theme.cornerRadiusSmall)
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.text)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("项目描述")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextEditor(text: $description)
                    .frame(height: 80)
                    .padding(theme.spacingXS)
                    .background(theme.surfaceElevated)
                    .cornerRadius(theme.cornerRadiusSmall)
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.text)
            }

            HStack(spacing: theme.spacingM) {
                Button("取消") { dismiss() }
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                    .buttonStyle(.plain)
                Spacer()
                Button("创建") {
                    guard !name.isEmpty else { return }
                    onCreate(name, description)
                    dismiss()
                }
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
                .background(theme.accent)
                .cornerRadius(theme.cornerRadiusSmall)
                .buttonStyle(.plain)
                .disabled(name.isEmpty)
            }

            Spacer()
        }
        .padding(theme.spacingXL)
        .frame(width: 420, height: 320)
        .background(theme.contentBg)
    }
}

// MARK: - Project Detail View

private struct KBProjectDetailView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let projectId: String

    @State private var project: [String: Any]?
    @State private var artifacts: [[String: Any]] = []
    @State private var instruction: String = ""
    @State private var isLoading = true
    @State private var activeTab: DetailTab = .files

    enum DetailTab: String, CaseIterable {
        case files = "文件"
        case instruction = "指令"
        case agents = "关联Agent"
    }

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            tabPicker
            Rectangle().fill(theme.separator).frame(height: 1)
            if isLoading {
                Spacer()
                ProgressView("加载中...")
                Spacer()
            } else {
                tabContent
            }
        }
        .frame(minWidth: 560, minHeight: 480)
        .background(theme.contentBg)
        .onAppear { loadDetail() }
    }

    private var detailHeader: some View {
        HStack(spacing: theme.spacingM) {
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(project?["name"] as? String ?? "项目详情")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text(project?["description"] as? String ?? "")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Button("关闭") { dismiss() }
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button(tab.rawValue) {
                    activeTab = tab
                }
                .font(.system(size: theme.footnoteSize, weight: activeTab == tab ? .semibold : .regular))
                .foregroundStyle(activeTab == tab ? theme.accent : theme.textSecondary)
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
                .background(activeTab == tab ? theme.accent.opacity(0.1) : Color.clear)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacingL)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .files: filesTab
        case .instruction: instructionTab
        case .agents: agentsTab
        }
    }

    private var filesTab: some View {
        VStack(spacing: 0) {
            if artifacts.isEmpty {
                Spacer()
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.textTertiary)
                    Text("暂无文件")
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(Array(artifacts.enumerated()), id: \.offset) { _, artifact in
                        artifactRow(artifact)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func artifactRow(_ artifact: [String: Any]) -> some View {
        let aid = artifact["id"] as? String ?? ""
        let title = artifact["title"] as? String ?? artifact["filename"] as? String ?? "未命名"
        let type = artifact["type"] as? String ?? "text"

        return HStack(spacing: theme.spacingM) {
            Image(systemName: artifactIcon(type))
                .font(.system(size: theme.iconL))
                .foregroundStyle(theme.auxiliary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.text)
                Text(type)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Button("移除") {
                removeArtifact(id: aid)
            }
            .font(.system(size: theme.captionSize))
            .foregroundStyle(theme.accentDestructive)
            .buttonStyle(.plain)
        }
        .padding(.vertical, theme.spacingXS)
    }

    private var instructionTab: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("项目指令")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            TextEditor(text: $instruction)
                .font(.system(size: theme.textSize, design: .monospaced))
                .foregroundStyle(theme.text)
                .padding(theme.spacingS)
                .background(theme.surfaceElevated)
                .cornerRadius(theme.cornerRadiusSmall)
                .frame(minHeight: 200)

            HStack {
                Spacer()
                Button("保存指令") {
                    saveInstruction()
                }
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
                .background(theme.accent)
                .cornerRadius(theme.cornerRadiusSmall)
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(theme.spacingL)
    }

    private var agentsTab: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("绑定此知识库的 Agent")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            let boundAgents = bridge.agents.filter { agent in
                let kbIds = agent.knowledge_base_ids ?? []
                return kbIds.contains(projectId)
            }

            if boundAgents.isEmpty {
                Spacer()
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "person.2")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.textTertiary)
                    Text("暂无 Agent 绑定此知识库")
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            } else {
                List(boundAgents) { agent in
                    HStack(spacing: theme.spacingM) {
                        Image(systemName: "cpu")
                            .foregroundStyle(theme.accent)
                        Text(agent.name)
                            .foregroundStyle(theme.text)
                        Spacer()
                        Text(agent.model)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(theme.spacingL)
    }

    private func loadDetail() {
        isLoading = true
        Task {
            do {
                async let projResult = ipc.projectGet(projectId: projectId)
                async let artResult = ipc.projectArtifactList(projectId: projectId)
                async let instrResult = ipc.projectInstructionGet(projectId: projectId)

                let proj = try await projResult
                let art = try await artResult
                let instr = try await instrResult

                let instrContent = instr["content"] as? String ?? ""
                let artList = art["artifacts"] as? [[String: Any]] ?? []

                kbLog.info("Project detail loaded: \(artList.count) artifacts")
                await MainActor.run {
                    project = proj
                    artifacts = artList
                    instruction = instrContent
                    isLoading = false
                }
            } catch {
                kbLog.error("Load project detail failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func removeArtifact(id: String) {
        Task {
            do {
                _ = try await ipc.projectArtifactRemove(artifactId: id)
                kbLog.info("Artifact removed: \(id)")
                loadDetail()
            } catch {
                kbLog.error("Remove artifact failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveInstruction() {
        Task {
            do {
                _ = try await ipc.projectInstructionSave(projectId: projectId, content: instruction)
                kbLog.info("Instruction saved for project: \(projectId)")
            } catch {
                kbLog.error("Save instruction failed: \(error.localizedDescription)")
            }
        }
    }

    private func artifactIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "pdf": return "doc.fill"
        case "markdown", "md": return "doc.text.fill"
        case "csv": return "tablecells.fill"
        case "image", "png", "jpg": return "photo.fill"
        default: return "doc.text"
        }
    }
}
