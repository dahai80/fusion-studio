import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ProjectModuleView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    @State private var projects: [[String: Any]] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateDialog = false
    @State private var selectedProjectId: String?

    var body: some View {
        HStack(spacing: 0) {
            projectListView
            Rectangle().fill(theme.separator).frame(width: 1)
            if let pid = selectedProjectId {
                ProjectDetailView(projectId: pid)
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadProjects() }
    }

    private var projectListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(eyebrow: "Fusion Studio", title: "Projects", subtitle: "管理你的 AI 项目、指令和知识库")
                .padding(.bottom, theme.spacingS)

            HStack {
                Button(action: { showCreateDialog = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: theme.iconM))
                }
                .buttonStyle(.plain)
                .help("新建项目")
                Spacer()
                Button(action: { loadProjects() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.bottom, theme.spacingS)

            if isLoading {
                ProgressView()
                    .padding()
            } else if let err = errorMessage {
                Text(err)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(.red)
                    .padding(.horizontal, theme.spacingM)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(projects.indices, id: \.self) { idx in
                            projectRow(projects[idx], index: idx)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }
        }
        .frame(minWidth: 260, maxWidth: 320)
        .sheet(isPresented: $showCreateDialog) {
            ProjectCreateDialog(onCreated: { _ in loadProjects() })
        }
    }

    private func projectRow(_ p: [String: Any], index: Int) -> some View {
        let pid = p["id"] as? String ?? ""
        let name = p["name"] as? String ?? "Untitled"
        let desc = p["description"] as? String ?? ""
        let isStarred = p["is_starred"] as? Bool ?? false
        let isActive = selectedProjectId == pid
        return Button(action: { selectedProjectId = pid }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: isStarred ? "star.fill" : "folder")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(isStarred ? .yellow : theme.textTertiary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(isActive ? theme.accent : theme.text)
                        .lineLimit(1)
                    if !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isActive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(isActive ? theme.accent.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("选择一个项目查看详情")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadProjects() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await ipc.projectCall(method: "project.list", params: [:])
                projLog.info("project.list loaded: \(result.count) keys")
                if let items = result["items"] as? [[String: Any]] {
                    await MainActor.run { projects = items; isLoading = false }
                } else {
                    await MainActor.run { projects = [result]; isLoading = false }
                }
            } catch {
                projLog.error("project.list failed: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct ProjectCreateDialog: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var ragMode = "AUTO"
    @State private var isCreating = false

    let onCreated: ([String: Any]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("新建项目")
                .font(.system(size: theme.headlineSize, weight: .bold))

            TextField("项目名称", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("描述（可选）", text: $description)
                .textFieldStyle(.roundedBorder)

            Picker("RAG 模式", selection: $ragMode) {
                Text("AUTO").tag("AUTO")
                Text("MANUAL").tag("MANUAL")
                Text("OFF").tag("OFF")
            }

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("创建") { createProject() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || isCreating)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createProject() {
        isCreating = true
        Task {
            do {
                var params: [String: Any] = ["name": name, "rag_mode": ragMode]
                if !description.isEmpty { params["description"] = description }
                let result = try await ipc.projectCall(method: "project.create", params: params)
                projLog.info("project.created: \(result)")
                await MainActor.run { onCreated(result); dismiss() }
            } catch {
                projLog.error("project.create failed: \(error.localizedDescription)")
                await MainActor.run { isCreating = false }
            }
        }
    }
}

struct ProjectDetailView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let projectId: String
    @State private var project: [String: Any]?
    @State private var isLoading = false
    @State private var activeTab = ProjectTab.instructions

    private enum ProjectTab: Int, CaseIterable {
        case instructions = 0
        case knowledge = 1
        case chats = 2

        var item: FusionTabItem {
            switch self {
            case .instructions: return FusionTabItem(title: "指令", icon: "text.alignleft")
            case .knowledge:    return FusionTabItem(title: "知识库", icon: "folder.badge.gearshape")
            case .chats:        return FusionTabItem(title: "会话", icon: "bubble.left.and.bubble.right")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let p = project {
                projectHeader(p)
                FusionTabBar(
                    selected: Binding(
                        get: { activeTab.rawValue },
                        set: { if let t = ProjectTab(rawValue: $0) { activeTab = t } }
                    ),
                    tabs: ProjectTab.allCases.map { $0.item }
                )
                .padding(.horizontal, theme.spacingM)
                switch activeTab {
                case .instructions:
                    ProjectInstructionsPanel(projectId: projectId)
                case .knowledge:
                    KnowledgeBaseTreeView(projectId: projectId)
                case .chats:
                    ProjectChatsPanel(projectId: projectId)
                }
            } else {
                Text("加载中…")
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadProject() }
    }

    private func projectHeader(_ p: [String: Any]) -> some View {
        HStack(spacing: theme.spacingM) {
            let isStarred = p["is_starred"] as? Bool ?? false
            Image(systemName: isStarred ? "star.fill" : "folder.fill")
                .font(.system(size: theme.iconL))
                .foregroundStyle(isStarred ? .yellow : theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(p["name"] as? String ?? "Untitled")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                if let desc = p["description"] as? String, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private func loadProject() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.projectCall(method: "project.get", params: ["project_id": projectId])
                projLog.info("project.get loaded: \(projectId)")
                await MainActor.run { project = result; isLoading = false }
            } catch {
                projLog.error("project.get failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct ProjectInstructionsPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let projectId: String
    @State private var instructions: String = ""
    @State private var isEditing = false
    @State private var editedText: String = ""
    @State private var editMode: InstructionEditMode = .markdown
    @State private var charCount: Int = 0
    @State private var showVersionHistory = false
    @State private var snapshots: [[String: Any]] = []

    private let maxChars = 10000

    private enum InstructionEditMode: String, CaseIterable {
        case markdown = "Markdown"
        case richText = "富文本"

        var icon: String {
            switch self {
            case .markdown: return "text.alignleft"
            case .richText: return "text.append"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                HStack {
                    Text("项目指令")
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                    Spacer()
                    if isEditing {
                        ForEach(InstructionEditMode.allCases, id: \.self) { mode in
                            Button(action: { editMode = mode }) {
                                HStack(spacing: 2) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 10))
                                    Text(mode.rawValue)
                                        .font(.system(size: theme.captionSize, weight: .medium))
                                }
                                .foregroundStyle(editMode == mode ? theme.accentText : theme.textSecondary)
                                .padding(.horizontal, theme.spacingS)
                                .padding(.vertical, theme.spacingXS)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .fill(editMode == mode ? theme.accent : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        Text("\(charCount)/\(maxChars)")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(charCount > maxChars ? .red : theme.textTertiary)
                        Button("保存") { saveInstructions() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        Button("取消") {
                            isEditing = false
                            editedText = instructions
                        }
                        .controlSize(.small)
                    } else {
                        Button(action: { editedText = instructions; isEditing = true }) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .help("编辑指令")
                        Button(action: { showVersionHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.plain)
                        .help("版本历史")
                    }
                }

                if isEditing {
                    TextEditor(text: $editedText)
                        .font(.system(size: theme.textSize, design: editMode == .markdown ? .monospaced : .default))
                        .frame(minHeight: 300)
                        .padding(theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadius)
                                .fill(theme.inputBg)
                        )
                        .onChange(of: editedText) { _, newText in
                            charCount = newText.count
                        }
                } else {
                    Text(instructions.isEmpty ? "暂无指令，点击编辑添加" : instructions)
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(instructions.isEmpty ? theme.textTertiary : theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(theme.spacingS)
                }
            }
            .padding(theme.spacingL)
        }
        .onAppear { loadInstructions() }
        .sheet(isPresented: $showVersionHistory) {
            InstructionVersionSheet(projectId: projectId, snapshots: snapshots, onRestore: { text in
                instructions = text
                editedText = text
            })
        }
    }

    private func loadInstructions() {
        Task {
            do {
                let result = try await ipc.projectCall(method: "project.instruction_get", params: ["project_id": projectId])
                if let text = result["instruction"] as? String {
                    await MainActor.run {
                        instructions = text
                        editedText = text
                        charCount = text.count
                    }
                }
                let snapResult = try await ipc.projectCall(method: "project.instruction_snapshots", params: ["project_id": projectId])
                if let items = snapResult["snapshots"] as? [[String: Any]] {
                    await MainActor.run { snapshots = items }
                }
            } catch {
                projLog.error("instruction_get failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveInstructions() {
        guard charCount <= maxChars else { return }
        Task {
            do {
                _ = try await ipc.projectCall(method: "project.instruction_save", params: [
                    "project_id": projectId,
                    "instruction": editedText,
                ])
                await MainActor.run { instructions = editedText; isEditing = false }
                projLog.info("instruction saved for \(projectId)")
            } catch {
                projLog.error("instruction_save failed: \(error.localizedDescription)")
            }
        }
    }
}

struct InstructionVersionSheet: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let projectId: String
    let snapshots: [[String: Any]]
    let onRestore: (String) -> Void

    @State private var showRestoreConfirm = false
    @State private var restoreText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("指令版本历史")
                    .font(.system(size: theme.textSize, weight: .bold))
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(theme.spacingM)

            if snapshots.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.textTertiary)
                    Text("暂无版本记录")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(snapshots.indices, id: \.self) { idx in
                            let snap = snapshots[idx]
                            let label = snap["label"] as? String ?? "auto"
                            let ts = snap["created_at"] as? String ?? ""
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(label)
                                        .font(.system(size: theme.textSize, weight: .medium))
                                    Text(ts)
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.textSecondary)
                                }
                                Spacer()
                                Button("恢复") {
                                    if let text = snap["instruction"] as? String {
                                        restoreText = text
                                        showRestoreConfirm = true
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, theme.spacingXS)
                        }
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
        .alert("恢复此版本？", isPresented: $showRestoreConfirm) {
            Button("恢复") {
                onRestore(restoreText)
                dismiss()
            }
            Button("取消", role: .cancel) { }
        }
    }
}

struct KnowledgeBaseTreeView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let projectId: String
    @State private var artifacts: [[String: Any]] = []
    @State private var isLoading = false
    @State private var showAddFile = false
    @State private var addFilePath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("知识库文件")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                Spacer()
                Button(action: { showAddFile = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                .help("添加文件到知识库")
                Button(action: { loadArtifacts() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingM)

            if isLoading {
                ProgressView().padding()
            } else if artifacts.isEmpty {
                Text("暂无知识库文件")
                    .foregroundStyle(theme.textTertiary)
                    .padding(theme.spacingL)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(artifacts.indices, id: \.self) { idx in
                            kbFileRow(artifacts[idx])
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                }
            }
        }
        .onAppear { loadArtifacts() }
        .alert("添加知识库文件", isPresented: $showAddFile) {
            TextField("文件路径", text: $addFilePath)
            Button("添加") { addFileToKb() }
            Button("取消", role: .cancel) { addFilePath = "" }
        }
    }

    private func kbFileRow(_ a: [String: Any]) -> some View {
        let name = a["name"] as? String ?? a["file_name"] as? String ?? a["artifact_id"] as? String ?? "?"
        let aType = a["artifact_type"] as? String ?? a["file_type"] as? String ?? "document"
        let fileId = a["id"] as? String ?? a["file_id"] as? String ?? ""
        return HStack(spacing: theme.spacingS) {
            Image(systemName: iconForType(aType))
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 20)
            Text(name)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .lineLimit(1)
            Spacer()
            Button(action: { removeFileFromKb(fileId) }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("从知识库移除")
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 4)
    }

    private func iconForType(_ t: String) -> String {
        switch t {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "app": return "app.badge"
        case "image": return "photo"
        case "document": return "doc.text"
        default: return "doc"
        }
    }

    private func loadArtifacts() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.projectCall(method: "project.kb.list", params: ["project_id": projectId])
                if let items = result["files"] as? [[String: Any]] {
                    await MainActor.run { artifacts = items; isLoading = false }
                } else {
                    await MainActor.run { artifacts = []; isLoading = false }
                }
            } catch {
                projLog.error("project.kb.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func addFileToKb() {
        guard !addFilePath.isEmpty else { return }
        Task {
            do {
                _ = try await ipc.projectCall(method: "project.kb.add", params: [
                    "project_id": projectId,
                    "file_path": addFilePath,
                ])
                await MainActor.run { addFilePath = "" }
                projLog.info("kb file added: \(addFilePath)")
                loadArtifacts()
            } catch {
                projLog.error("project.kb.add failed: \(error.localizedDescription)")
            }
        }
    }

    private func removeFileFromKb(_ fileId: String) {
        Task {
            do {
                _ = try await ipc.projectCall(method: "project.kb.remove", params: [
                    "project_id": projectId,
                    "file_id": fileId,
                ])
                projLog.info("kb file removed: \(fileId)")
                loadArtifacts()
            } catch {
                projLog.error("project.kb.remove failed: \(error.localizedDescription)")
            }
        }
    }
}

struct ProjectChatsPanel: View {
    @Environment(\.studioTheme) private var theme

    let projectId: String

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30))
                .foregroundStyle(theme.textTertiary)
            Text("项目会话")
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text("此项目的对话历史将显示在这里")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
