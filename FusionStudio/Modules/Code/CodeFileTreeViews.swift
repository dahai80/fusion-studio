// F-I7: CodeEditorView.swift 拆分 — 文件树三件套紧耦合 (递归)。
// 迁自 CodeEditorView.swift: FileTreeView / FileTreeLevel / FileTreeRow。
// FileTreeRow codeEditLog 用 5 次 (共享在 CodeView.swift)。

import SwiftUI
import AppKit

// MARK: - File Tree View

struct FileTreeView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var workspace = ProjectWorkspace.shared
    @StateObject private var agent = CodeAgent.shared
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(spacing: 0) {
            if workspace.hasProject || workspace.isLoading {
                projectHeader
                searchField
                if workspace.isLoading {
                    loadingView
                } else {
                    fileTreeContent
                }
            } else {
                emptyState
            }
        }
        .background(theme.surfaceSecondary)
    }

    private var projectHeader: some View {
        HStack(spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.projectName)
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                HStack(spacing: theme.spacingXS) {
                    if !workspace.gitBranch.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: theme.captionSize))
                            Text(workspace.gitBranch)
                                .font(.system(size: theme.captionSize))
                        }
                        .foregroundStyle(theme.textSecondary)
                    }
                    Text(String(format: i18n.t(.fc_files_count), workspace.totalFileCount))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            Button(action: { workspace.closeProject() }) {
                Image(systemName: "xmark")
                    .font(.system(size: theme.iconXS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help(i18n.t(.fc_close_project))

            Button(action: { workspace.openLocalFolder() }) {
                Image(systemName: "plus")
                    .font(.system(size: theme.iconS, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .help(i18n.t(.fc_open_another))
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var searchField: some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.iconXS))
                .foregroundStyle(theme.textTertiary)
            TextField(i18n.t(.fc_search_files), text: $workspace.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: theme.footnoteSize))
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.inputBg)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
        .padding(.horizontal, theme.spacingS)
        .padding(.bottom, theme.spacingXS)
    }

    private var loadingView: some View {
        VStack(spacing: theme.spacingS) {
            Spacer().frame(height: theme.spacingXL)
            ProgressView()
                .controlSize(.regular)
            Text(workspace.loadMessage)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
            ProgressView(value: workspace.loadProgress)
                .tint(theme.accent)
                .padding(.horizontal, theme.spacingL)
            Spacer()
        }
    }

    private var fileTreeContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                FileTreeLevel(files: filteredFiles, depth: 0)
            }
        }
    }

    private var filteredFiles: [CodeFile] {
        if workspace.searchText.isEmpty { return workspace.files }
        return filterFiles(workspace.files, query: workspace.searchText.lowercased())
    }

    private func filterFiles(_ files: [CodeFile], query: String) -> [CodeFile] {
        var result: [CodeFile] = []
        for f in files {
            if f.isDirectory {
                let filteredChildren = filterFiles(f.children ?? [], query: query)
                if !filteredChildren.isEmpty {
                    result.append(CodeFile(
                        id: f.id, name: f.name, path: f.path, content: f.content,
                        language: f.language, isModified: f.isModified, isDirectory: true,
                        children: filteredChildren, isExpanded: true,
                        relativePath: f.relativePath, fileSize: f.fileSize
                    ))
                }
            } else {
                if f.name.lowercased().contains(query) || f.relativePath.lowercased().contains(query) {
                    result.append(f)
                }
            }
        }
        return result
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.fc_no_project_open))
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text(i18n.t(.fc_open_folder_browse))
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)

            FusionButton(i18n.t(.fc_open_project), icon: "folder.badge.plus", style: .tinted, size: .regular) {
                workspace.openLocalFolder()
            }
            .padding(.top, theme.spacingS)
            Spacer()
        }
    }
}

// MARK: - File Tree Level (Recursive)

struct FileTreeLevel: View {
    let files: [CodeFile]
    let depth: Int
    @Environment(\.studioTheme) var theme
    @StateObject private var workspace = ProjectWorkspace.shared
    @StateObject private var agent = CodeAgent.shared

    var body: some View {
        ForEach(files) { file in
            FileTreeRow(file: file, depth: depth)
            if file.isDirectory && file.isExpanded, let children = file.children {
                FileTreeLevel(files: children, depth: depth + 1)
            }
        }
    }
}

struct FileTreeRow: View {
    let file: CodeFile
    let depth: Int
    @Environment(\.studioTheme) var theme
    @StateObject private var workspace = ProjectWorkspace.shared
    @StateObject private var agent = CodeAgent.shared
    @StateObject private var i18n = I18nManager.shared
    @EnvironmentObject var ipc: IPCClient
    @State private var kbBuilding = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: theme.spacingXS) {
            Color.clear.frame(width: CGFloat(depth) * 16)

            if file.isDirectory {
                Image(systemName: file.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 12)
                    .onTapGesture {
                        toggleDirectory()
                    }
            } else {
                Color.clear.frame(width: 12)
            }

            Image(systemName: CodeFile.iconForFile(file))
                .font(.system(size: theme.iconS))
                .foregroundStyle(file.isDirectory ? theme.accent : theme.textSecondary)

            Text(file.name)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.text)
                .lineLimit(1)

            Spacer()

            if file.isModified {
                Circle()
                    .fill(theme.amberDot)
                    .frame(width: 6, height: 6)
            }

            if !file.isDirectory && agent.fileContexts.contains(where: { $0.id == file.id }) {
                Image(systemName: "link")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, 3)
        .background(isHovered ? theme.hoverBg : (workspace.selectedFile?.id == file.id ? theme.selBg : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: theme.rowRadius, style: .continuous))
        .onHover { hovering in isHovered = hovering }
        .onTapGesture {
            if file.isDirectory {
                toggleDirectory()
            } else {
                selectFile()
            }
        }
// #49 Adding KB context menu items: 添加到知识库, 索引到 RAG
// Affected API: IPCClient.kbBuild(), kbStatus(), kbQuery()
// Data schemas: POST /api/kb/build {path, scope}, GET /api/kb/status, POST /api/kb/query
// User instruction: #49 文件树右键「加入知识库」菜单
        .contextMenu {
            if !file.isDirectory {
                Button(i18n.t(.fc_show_in_finder)) {
                    NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                }
                Button(i18n.t(.fc_copy_path)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(file.relativePath, forType: .string)
                }
                Divider()
                if agent.fileContexts.contains(where: { $0.id == file.id }) {
                    Button(i18n.t(.fc_remove_context)) { agent.removeFileContext(file) }
                } else {
                    Button(i18n.t(.fc_add_to_context)) { agent.addFileContext(file) }
                }
                Divider()
                Button(i18n.t(.fc_add_to_kb)) { addToKnowledgeBase(file) }
                Button(i18n.t(.fc_index_to_rag)) { indexToRAG(file) }
            }
            if file.isDirectory {
                Button(i18n.t(.fc_show_in_finder)) {
                    NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                }
                Button(i18n.t(.fc_add_dir_to_kb)) { addToKnowledgeBase(file) }
            }
        }
    }

    private func toggleDirectory() {
        if let idx = workspace.files.firstIndex(where: { $0.id == file.id }) {
            workspace.files[idx].isExpanded.toggle()
        } else {
            _ = toggleInNested(files: workspace.files, id: file.id)
        }
    }

    private func toggleInNested(files: [CodeFile], id: String) -> Bool {
        for i in files.indices {
            if files[i].id == id {
                workspace.objectWillChange.send()
                return true
            }
            if files[i].isDirectory, var children = files[i].children {
                if toggleInNested(files: children, id: id) {
                    for j in children.indices {
                        if children[j].id == id {
                            children[j].isExpanded.toggle()
                            break
                        }
                    }
                    return true
                }
            }
        }
        return false
    }

    private func selectFile() {
        workspace.selectedFile = file
        agent.currentFile = file
        agent.addFileContext(file)
        codeEditLog.info("Selected file: \(file.name)")
    }

    private func addToKnowledgeBase(_ f: CodeFile) {
        kbBuilding = true
        Task {
            do {
                _ = try await ipc.kbBuild(path: f.path)
                codeEditLog.info("Added to KB: \(f.path)")
            } catch {
                codeEditLog.error("KB add failed: \(error.localizedDescription)")
            }
            await MainActor.run { kbBuilding = false }
        }
    }

    private func indexToRAG(_ f: CodeFile) {
        kbBuilding = true
        Task {
            do {
                let content = try String(contentsOfFile: f.path, encoding: .utf8)
                _ = try await ipc.knowledgeIngest(content: content, scope: "code", metadata: ["path": f.path])
                codeEditLog.info("Indexed to RAG: \(f.path)")
            } catch {
                codeEditLog.error("RAG index failed: \(error.localizedDescription)")
            }
            await MainActor.run { kbBuilding = false }
        }
    }
}
