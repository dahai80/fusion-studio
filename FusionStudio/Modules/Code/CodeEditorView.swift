// Callers: ModuleDetailView routing (case .code → CodeView).
// Affected API: CodeView, ProjectWorkspace, ProjectLoader, FileTreeView, OpenProjectSheet.
// Data schemas: CodeFile (added children/isExpanded/relativePath/fileSize), RecentProject, ProjectWorkspace.

import SwiftUI
import AppKit
import os.log

private let codeLog = Logger(subsystem: "com.fusion.studio", category: "FusionCode")

// MARK: - CodeFile

struct CodeFile: Identifiable, Hashable {
    let id: String
    var name: String
    var path: String
    var content: String
    var language: String
    var isModified: Bool
    var isDirectory: Bool
    var children: [CodeFile]?
    var isExpanded: Bool = false
    var relativePath: String = ""
    var fileSize: Int64 = 0

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CodeFile, rhs: CodeFile) -> Bool { lhs.id == rhs.id }

    static func languageForPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "Swift"
        case "py": return "Python"
        case "js": return "JavaScript"
        case "ts": return "TypeScript"
        case "tsx", "jsx": return "React"
        case "rs": return "Rust"
        case "go": return "Go"
        case "java": return "Java"
        case "kt": return "Kotlin"
        case "rb": return "Ruby"
        case "c", "h": return "C"
        case "cpp", "cc", "cxx", "hpp": return "C++"
        case "cs": return "C#"
        case "scala": return "Scala"
        case "sh", "bash", "zsh": return "Shell"
        case "sql": return "SQL"
        case "html": return "HTML"
        case "css": return "CSS"
        case "json": return "JSON"
        case "yaml", "yml": return "YAML"
        case "toml": return "TOML"
        case "xml": return "XML"
        case "md", "markdown": return "Markdown"
        case "dart": return "Dart"
        case "lua": return "Lua"
        case "r": return "R"
        case "zig": return "Zig"
        default: return ""
        }
    }

    static func iconForFile(_ file: CodeFile) -> String {
        if file.isDirectory { return "folder.fill" }
        let lang = file.language.isEmpty ? languageForPath(file.path) : file.language
        switch lang {
        case "Swift": return "swift"
        case "Python": return "snake"
        case "JavaScript", "TypeScript", "React": return "curlybraces"
        case "Rust": return "gearshape"
        case "Go": return "goforward"
        case "Markdown": return "doc.richtext"
        case "JSON", "YAML", "TOML": return "list.bullet.indent"
        case "HTML": return "globe"
        case "CSS": return "paintbrush"
        case "Shell": return "terminal"
        default: return "doc.text"
        }
    }

    static let skipDirectories: Set<String> = [
        ".git", ".svn", ".hg", "__pycache__", "node_modules",
        ".venv", "venv", "env", ".env", ".tox", ".mypy_cache",
        ".pytest_cache", ".ruff_cache", "build", "dist", ".build",
        "DerivedData", ".gradle", ".idea", ".vscode",
        "Pods", ".spm", "htmlcov", ".next", ".nuxt",
    ]

    static let skipFileExtensions: Set<String> = [
        "pyc", "pyo", "o", "so", "dylib", "dll", "exe",
        "class", "jar", "war", "DS_Store", "icloud",
    ]

    static let maxFileSize: Int64 = 1_024_000
}

// MARK: - RecentProject

struct RecentProject: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let gitURL: String?
    let lastOpened: Date

    init(name: String, path: String, gitURL: String? = nil) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.gitURL = gitURL
        self.lastOpened = Date()
    }
}

// MARK: - ProjectWorkspace

class ProjectWorkspace: ObservableObject {
    static let shared = ProjectWorkspace()

    @Published var projectRoot: URL?
    @Published var projectName: String = ""
    @Published var gitBranch: String = ""
    @Published var files: [CodeFile] = []
    @Published var isLoading: Bool = false
    @Published var loadProgress: Double = 0
    @Published var loadMessage: String = ""
    @Published var recentProjects: [RecentProject] = []
    @Published var selectedFile: CodeFile?
    @Published var searchText: String = ""

    private let recentKey = "fusion-studio.recent-projects"
    private var loadTask: Task<Void, Never>?
    private var checkpoints: [String: String] = [:]

    var totalFileCount: Int {
        countFiles(files)
    }

    var hasProject: Bool {
        projectRoot != nil && !files.isEmpty
    }

    private func countFiles(_ files: [CodeFile]) -> Int {
        var count = 0
        for f in files {
            if f.isDirectory {
                count += countFiles(f.children ?? [])
            } else {
                count += 1
            }
        }
        return count
    }

    init() {
        loadRecentProjects()
    }

    func openLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Open Project Folder"
        panel.prompt = "Open"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadProject(from: url)
    }

    func openSingleFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Open File"
        panel.prompt = "Open"
        panel.allowedContentTypes = [.sourceCode, .plainText, .script]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadSingleFile(from: url)
    }

    func openRecent(_ recent: RecentProject) {
        let url = URL(fileURLWithPath: recent.path)
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: recent.path, isDirectory: &isDir) {
            if isDir.boolValue {
                loadProject(from: url)
            } else {
                loadSingleFile(from: url)
            }
        } else {
            codeLog.warning("Recent project path no longer exists: \(recent.path)")
            recentProjects.removeAll { $0.id == recent.id }
            saveRecentProjects()
        }
    }

    func loadProject(from url: URL) {
        cancelLoading()
        loadTask = Task { @MainActor in
            isLoading = true
            loadProgress = 0
            loadMessage = "Scanning \(url.lastPathComponent)..."
            projectRoot = url
            projectName = url.lastPathComponent
            gitBranch = detectGitBranch(at: url)

            codeLog.info("Loading project from: \(url.path)")

            let scanned = await scanDirectory(url, depth: 0, maxDepth: 6)

            guard !Task.isCancelled else { return }
            files = scanned
            isLoading = false
            loadProgress = 1.0
            loadMessage = "Loaded \(totalFileCount) files"

            let recent = RecentProject(name: projectName, path: url.path)
            addRecentProject(recent)

            codeLog.info("Project loaded: \(self.projectName), \(self.totalFileCount) files, branch: \(self.gitBranch)")
        }
    }

    func loadSingleFile(from url: URL) {
        cancelLoading()
        loadTask = Task { @MainActor in
            isLoading = true
            loadProgress = 0
            loadMessage = "Loading \(url.lastPathComponent)..."

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = (attrs[.size] as? Int64) ?? 0
                let lang = CodeFile.languageForPath(url.path)
                let relPath = url.lastPathComponent

                let file = CodeFile(
                    id: url.path,
                    name: url.lastPathComponent,
                    path: url.path,
                    content: content,
                    language: lang,
                    isModified: false,
                    isDirectory: false,
                    children: nil,
                    isExpanded: false,
                    relativePath: relPath,
                    fileSize: fileSize
                )

                projectRoot = url.deletingLastPathComponent()
                projectName = url.lastPathComponent
                gitBranch = detectGitBranch(at: url.deletingLastPathComponent())
                files = [file]
                selectedFile = file
                isLoading = false
                loadProgress = 1.0
                loadMessage = "Loaded 1 file"

                let recent = RecentProject(name: url.lastPathComponent, path: url.path)
                addRecentProject(recent)

                codeLog.info("Single file loaded: \(url.lastPathComponent)")
            } catch {
                isLoading = false
                loadMessage = "Failed to load: \(error.localizedDescription)"
                codeLog.error("Failed to load file: \(error.localizedDescription)")
            }
        }
    }

    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    func closeProject() {
        projectRoot = nil
        projectName = ""
        gitBranch = ""
        files = []
        selectedFile = nil
        searchText = ""
        checkpoints.removeAll()
        codeLog.info("Project closed")
    }

    // MARK: - File Read/Write

    func loadFileContent(_ file: CodeFile) -> String? {
        let url = URL(fileURLWithPath: file.path)
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            codeLog.info("File content loaded: \(file.name)")
            return content
        } catch {
            codeLog.error("Failed to read file \(file.name): \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func write(file: CodeFile, content: String) -> Bool {
        let url = URL(fileURLWithPath: file.path)

        do {
            let original = try? String(contentsOf: url, encoding: .utf8)
            checkpoints[file.path] = original ?? ""

            try content.write(to: url, atomically: true, encoding: .utf8)

            if var found = findFile(in: files, path: file.path) {
                found.content = content
                found.isModified = false
                updateFile(in: &files, path: file.path, updated: found)
            }
            if selectedFile?.path == file.path {
                selectedFile?.content = content
                selectedFile?.isModified = false
            }

            codeLog.info("File saved: \(file.name), checkpoint stored")
            return true
        } catch {
            codeLog.error("Failed to write file \(file.name): \(error.localizedDescription)")
            return false
        }
    }

    func undoLastWrite(_ file: CodeFile) -> Bool {
        guard let original = checkpoints[file.path] else {
            codeLog.warning("No checkpoint for file: \(file.name)")
            return false
        }
        let url = URL(fileURLWithPath: file.path)
        do {
            try original.write(to: url, atomically: true, encoding: .utf8)
            checkpoints.removeValue(forKey: file.path)

            if selectedFile?.path == file.path {
                selectedFile?.content = original
                selectedFile?.isModified = false
            }

            codeLog.info("Checkpoint restored for: \(file.name)")
            return true
        } catch {
            codeLog.error("Failed to restore checkpoint: \(error.localizedDescription)")
            return false
        }
    }

    func hasCheckpoint(_ file: CodeFile) -> Bool {
        checkpoints[file.path] != nil
    }

    private func findFile(in files: [CodeFile], path: String) -> CodeFile? {
        for f in files {
            if f.path == path { return f }
            if f.isDirectory, let children = f.children {
                if let found = findFile(in: children, path: path) { return found }
            }
        }
        return nil
    }

    private func updateFile(in files: inout [CodeFile], path: String, updated: CodeFile) {
        for i in files.indices {
            if files[i].path == path {
                files[i] = updated
                return
            }
            if files[i].isDirectory {
                updateFile(in: &files[i].children!, path: path, updated: updated)
            }
        }
    }

    // MARK: - Scan

    private func scanDirectory(_ url: URL, depth: Int, maxDepth: Int) async -> [CodeFile] {
        guard depth < maxDepth else { return [] }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var result: [CodeFile] = []
        let sorted = contents.sorted { $0.lastPathComponent < $1.lastPathComponent }

        for (index, itemURL) in sorted.enumerated() {
            let name = itemURL.lastPathComponent

            if CodeFile.skipDirectories.contains(name) { continue }

            let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let isDir = resourceValues?.isDirectory ?? false

            if isDir {
                let children = await scanDirectory(itemURL, depth: depth + 1, maxDepth: maxDepth)
                let childCount = countFiles(children)
                if childCount > 0 {
                    let dirFile = CodeFile(
                        id: itemURL.path,
                        name: name,
                        path: itemURL.path,
                        content: "",
                        language: "",
                        isModified: false,
                        isDirectory: true,
                        children: children,
                        isExpanded: depth == 0,
                        relativePath: relativePath(from: itemURL),
                        fileSize: 0
                    )
                    result.append(dirFile)
                }
            } else {
                let ext = (name as NSString).pathExtension.lowercased()
                if CodeFile.skipFileExtensions.contains(ext) { continue }

                let fileSize = (resourceValues?.fileSize ?? 0)
                if Int64(fileSize) > CodeFile.maxFileSize { continue }

                let lang = CodeFile.languageForPath(itemURL.path)
                let relPath = relativePath(from: itemURL)

                let file = CodeFile(
                    id: itemURL.path,
                    name: name,
                    path: itemURL.path,
                    content: "",
                    language: lang,
                    isModified: false,
                    isDirectory: false,
                    children: nil,
                    isExpanded: false,
                    relativePath: relPath,
                    fileSize: Int64(fileSize)
                )
                result.append(file)
            }

            if index % 10 == 0 {
                await MainActor.run {
                    loadProgress = Double(index) / Double(sorted.count)
                    loadMessage = "Scanning \(index)/\(sorted.count)..."
                }
            }
        }

        return result
    }

    // MARK: - Git

    private func detectGitBranch(at url: URL) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        process.currentDirectoryURL = url

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let branch = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return branch.isEmpty ? "" : branch
            }
        } catch {
            codeLog.debug("git branch detection failed: \(error.localizedDescription)")
        }
        return ""
    }

    // MARK: - Recent Projects

    private func relativePath(from url: URL) -> String {
        guard let root = projectRoot else { return url.lastPathComponent }
        let rootPath = root.path + "/"
        if url.path.hasPrefix(rootPath) {
            return String(url.path.dropFirst(rootPath.count))
        }
        return url.lastPathComponent
    }

    func addRecentProject(_ project: RecentProject) {
        recentProjects.removeAll { $0.path == project.path }
        recentProjects.insert(project, at: 0)
        if recentProjects.count > 20 {
            recentProjects = Array(recentProjects.prefix(20))
        }
        saveRecentProjects()
    }

    private func saveRecentProjects() {
        do {
            let data = try JSONEncoder().encode(recentProjects)
            UserDefaults.standard.set(data, forKey: recentKey)
        } catch {
            codeLog.error("Failed to save recent projects: \(error.localizedDescription)")
        }
    }

    private func loadRecentProjects() {
        guard let data = UserDefaults.standard.data(forKey: recentKey) else { return }
        do {
            recentProjects = try JSONDecoder().decode([RecentProject].self, from: data)
        } catch {
            codeLog.error("Failed to load recent projects: \(error.localizedDescription)")
        }
    }
}

// MARK: - CodeAgent

class CodeAgent: ObservableObject {
    static let shared = CodeAgent()
    @Published var isThinking = false
    @Published var suggestions: [CodeSuggestion] = []
    @Published var conversation: [CodeMessage] = []
    @Published var currentFile: CodeFile?
    @Published var fileContexts: [CodeFile] = []
    weak var agentBridge: AgentBridge?
    var selectedModel: String = ""

    struct CodeSuggestion: Identifiable {
        let id = UUID()
        let title: String; let description: String; let code: String; let action: String
    }
    struct CodeMessage: Identifiable {
        let id = UUID()
        let role: String; let content: String; let timestamp: Date; let codeBlocks: [String]
    }

    func askAI(prompt: String, context: String = "", language: String = "", effort: String = "medium", thinking: Bool = false) {
        isThinking = true
        var fullPrompt = prompt
        if !context.isEmpty {
            fullPrompt = "Context:\n\(context)\n\n\(prompt)"
        }
        conversation.append(CodeMessage(role: "user", content: prompt, timestamp: Date(), codeBlocks: []))
        Task { [weak self] in
            guard let self = self else { return }
            do {
                guard let bridge = self.agentBridge else {
                    throw NSError(domain: "CodeAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "AgentBridge not connected"])
                }
                let messages: [[String: String]] = [
                    ["role": "user", "content": fullPrompt]
                ]
                let response = try await bridge.infer(
                    messages: messages,
                    model: self.selectedModel,
                    temperature: 0.7,
                    maxTokens: 2048,
                    effort: effort,
                    thinking: thinking
                )
                let blocks = extractCodeBlocks(from: response)
                await MainActor.run {
                    self.conversation.append(CodeMessage(role: "assistant", content: response, timestamp: Date(), codeBlocks: blocks))
                    self.isThinking = false
                    self.objectWillChange.send()
                }
            } catch {
                await MainActor.run {
                    let err = "⚠️ AI inference failed: \(error.localizedDescription)\n\nEnsure fusion-mlx is running on port 11434 and the daemon is connected."
                    self.conversation.append(CodeMessage(role: "assistant", content: err, timestamp: Date(), codeBlocks: []))
                    self.isThinking = false
                    self.objectWillChange.send()
                }
            }
        }
    }

    func addFileContext(_ file: CodeFile) {
        if !fileContexts.contains(where: { $0.id == file.id }) {
            fileContexts.append(file)
            codeLog.info("Added file context: \(file.name)")
        }
    }

    func removeFileContext(_ file: CodeFile) {
        fileContexts.removeAll { $0.id == file.id }
    }

    func buildContextString() -> String {
        var parts: [String] = []
        for f in fileContexts {
            let content: String
            if f.content.isEmpty {
                content = (try? String(contentsOfFile: f.path, encoding: .utf8)) ?? "[无法读取]"
            } else {
                content = f.content
            }
            let lang = f.language.isEmpty ? CodeFile.languageForPath(f.path) : f.language
            parts.append("File: \(f.relativePath)\n```\(lang.lowercased())\n\(content)\n```")
        }
        return parts.joined(separator: "\n\n")
    }

    func clearConversation() { conversation.removeAll(); objectWillChange.send() }
    private func extractCodeBlocks(from text: String) -> [String] {
        var blocks: [String] = []; let lines = text.split(separator: "\n"); var inBlock = false; var current = ""
        for line in lines {
            if line.hasPrefix("```") { if inBlock { blocks.append(current); current = ""; inBlock = false } else { inBlock = true } }
            else if inBlock { current += String(line) + "\n" }
        }
        return blocks
    }
}

// MARK: - CodeView

struct CodeView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var agent = CodeAgent.shared
    @StateObject private var workspace = ProjectWorkspace.shared
    @State private var showSidebar = true
    @State private var sidebarTab: SidebarTab = .chat
    @State private var inputText = ""
    @State private var showOpenProject = false
    @State private var detectedGitURL: String?

    enum SidebarTab: String, CaseIterable {
        case chat = "Chat"
        case files = "Files"
        case git = "Git"
        case preview = "Design"
    }

    var body: some View {
        HSplitView {
            if showSidebar {
                VStack(spacing: 0) {
                    sidebarTabBar
                    Divider()
                    switch sidebarTab {
                    case .chat:  ChatHistoryView()
                    case .files: FileTreeView()
                    case .git:   GitStatusView()
                    case .preview: CodeDesignPreviewPanel()
                    }
                }
                .frame(minWidth: 220, maxWidth: 300)
            }

            VStack(spacing: 0) {
                ChatContentView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                inputBar
            }
        }
        .frame(minWidth: 700, minHeight: 400)
        .sheet(isPresented: $showOpenProject) {
            OpenProjectSheet(workspace: workspace)
        }
        .onAppear {
            if workspace.hasProject {
                sidebarTab = .files
            }
        }
    }

    private var sidebarTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                Button(action: { sidebarTab = tab }) {
                    VStack(spacing: 2) {
                        Image(systemName: tabIcon(tab))
                            .font(.system(size: 12))
                        Text(tab.rawValue).font(.system(size: 9))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(sidebarTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(theme.surfaceSecondary)
    }

    private func tabIcon(_ tab: SidebarTab) -> String {
        switch tab {
        case .chat: return "message"
        case .files: return workspace.hasProject ? "folder.fill" : "folder"
        case .git: return "arrow.triangle.branch"
        case .preview: return "paintbrush"
        }
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let gitURL = detectedGitURL {
                GitURLDetectionBar(url: gitURL) {
                    detectedGitURL = nil
                } onSendAsText: {
                    inputText = detectedGitURL ?? ""
                    detectedGitURL = nil
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: { showSidebar.toggle() }) {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.borderless)
                .help("切换侧边栏")

                TextField("Ask anything — code, explain, debug, refactor...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(1...6)
                    .onSubmit { sendMessage() }
                    .onChange(of: inputText) { _, newValue in
                        detectGitURL(newValue)
                    }

                Button(action: { showAttachMenu() }) {
                    Image(systemName: "paperclip")
                }
                .buttonStyle(.borderless)
                .help("附加文件")

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(inputText.isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty || agent.isThinking)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let context = agent.buildContextString()
        agent.askAI(prompt: text, context: context)
        inputText = ""
        detectedGitURL = nil
    }

    private func detectGitURL(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("https://github.com/") || trimmed.hasPrefix("https://gitlab.com/") || trimmed.hasPrefix("https://bitbucket.org/") {
            if trimmed.hasSuffix(".git") || trimmed.split(separator: "/").count >= 5 {
                detectedGitURL = trimmed
            }
        } else {
            detectedGitURL = nil
        }
    }

    private func showAttachMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Add Folder...", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Add File...", action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Add GitHub Repo...", action: nil, keyEquivalent: "")

        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: NSApp.keyWindow?.contentView ?? NSView())
        }
    }
}

// MARK: - Git URL Detection Bar

struct GitURLDetectionBar: View {
    let url: String
    let onClone: () -> Void
    let onSendAsText: () -> Void
    @Environment(\.studioTheme) var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "link")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("检测到 Git 仓库 URL")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(url)
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            FusionButton("Clone", icon: "arrow.down.circle", style: .tinted, size: .small, action: onClone)
            FusionButton("发送", icon: "paperplane", style: .ghost, size: .small, action: onSendAsText)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.accentSoft)
        .transition(theme.transitionScale)
    }
}

// MARK: - Open Project Sheet

struct OpenProjectSheet: View {
    @ObservedObject var workspace: ProjectWorkspace
    @Environment(\.studioTheme) var theme
    @Environment(\.dismiss) var dismiss
    @State private var gitURL = ""
    @State private var gitBranch = "main"
    @State private var isCloning = false
    @State private var cloneError: String?

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            ScrollView {
                VStack(spacing: theme.spacingL) {
                    localFolderCard
                    singleFileCard
                    gitHubCard
                    dividerOr
                    dropZone
                }
                .padding(theme.spacingL)
            }
        }
        .frame(width: 520)
        .background(theme.surfacePrimary)
    }

    private var sheetHeader: some View {
        HStack {
            Text("Open Project")
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
        .background(.regularMaterial)
    }

    private var localFolderCard: some View {
        FusionCard(style: .bordered) {
            HStack(spacing: theme.spacingM) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: theme.iconXL))
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Folder")
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text("选择本地文件夹，自动扫描代码文件")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                FusionButton("Choose...", icon: "folder", style: .tinted, size: .regular) {
                    workspace.openLocalFolder()
                    if workspace.hasProject { dismiss() }
                }
            }
        }
    }

    private var singleFileCard: some View {
        FusionCard(style: .bordered) {
            HStack(spacing: theme.spacingM) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: theme.iconXL))
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Single File")
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text("打开单个文件进行编辑和 AI 辅助")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                FusionButton("Choose...", icon: "doc", style: .tinted, size: .regular) {
                    workspace.openSingleFile()
                    if workspace.hasProject { dismiss() }
                }
            }
        }
    }

    private var gitHubCard: some View {
        FusionCard(style: .bordered) {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                HStack(spacing: theme.spacingM) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: theme.iconXL))
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GitHub Repository")
                            .font(.system(size: theme.textSize, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Text("克隆远程仓库到本地工作区")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                HStack(spacing: theme.spacingS) {
                    Text("URL")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 50, alignment: .trailing)
                    TextField("https://github.com/user/repo", text: $gitURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.smallTextSize, design: .monospaced))
                        .padding(theme.spacingS)
                        .background(theme.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(gitURL.isEmpty ? theme.inputBorder : (isValidGitURL ? theme.accent : theme.accentDestructive), lineWidth: 1)
                        }
                }

                HStack(spacing: theme.spacingS) {
                    Text("Branch")
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 50, alignment: .trailing)
                    TextField("main", text: $gitBranch)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.smallTextSize))
                        .padding(theme.spacingS)
                        .background(theme.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(theme.inputBorder, lineWidth: 1)
                        }
                }

                if let error = cloneError {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.accentDestructive)
                        Text(error)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.errorText)
                    }
                }

                HStack {
                    Spacer()
                    FusionButton("Clone & Open", icon: "arrow.down.circle", style: .primary, size: .regular, isLoading: isCloning, isDisabled: !isValidGitURL) {
                        cloneRepo()
                    }
                }
            }
        }
    }

    private var dividerOr: some View {
        HStack(spacing: theme.spacingM) {
            Rectangle().fill(theme.separator).frame(height: 0.5)
            Text("或")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Rectangle().fill(theme.separator).frame(height: 0.5)
        }
    }

    private var dropZone: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: theme.iconXL))
                .foregroundStyle(theme.textTertiary)
            Text("拖拽文件或文件夹到此处")
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundStyle(theme.inputBorder)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private var isValidGitURL: Bool {
        let url = gitURL.trimmingCharacters(in: .whitespaces)
        return url.hasPrefix("https://github.com/") || url.hasPrefix("https://gitlab.com/") || url.hasPrefix("git@")
    }

    private func cloneRepo() {
        isCloning = true
        cloneError = nil
        let url = gitURL.trimmingCharacters(in: .whitespaces)
        let branch = gitBranch.trimmingCharacters(in: .whitespaces).isEmpty ? "main" : gitBranch

        Task { @MainActor in
            let workspaceDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("fusion-workspace")
            try? FileManager.default.createDirectory(at: workspaceDir, withIntermediateDirectories: true)

            let repoName = URL(string: url)?.deletingPathExtension().lastPathComponent ?? "repo-\(UUID().uuidString.prefix(6))"
            let targetDir = workspaceDir.appendingPathComponent(repoName)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["clone", "-b", branch, url, targetDir.path]
            process.currentDirectoryURL = workspaceDir

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    workspace.loadProject(from: targetDir)
                    dismiss()
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    cloneError = String(data: errorData, encoding: .utf8) ?? "Clone failed with exit code \(process.terminationStatus)"
                }
            } catch {
                cloneError = error.localizedDescription
            }
            isCloning = false
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            DispatchQueue.main.async {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        workspace.loadProject(from: url)
                    } else {
                        workspace.loadSingleFile(from: url)
                    }
                    if workspace.hasProject { dismiss() }
                }
            }
        }
        return true
    }
}

// MARK: - Chat History

struct ChatHistoryView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var agent = CodeAgent.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary).font(.caption)
                TextField("Search conversations...", text: .constant(""))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(8)

            Divider()

            if agent.conversation.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "message").font(.system(size: 20)).foregroundColor(.secondary)
                    Text("No conversations yet").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(agent.conversation.filter { $0.role == "user" }.reversed().prefix(10)) { msg in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(msg.content.prefix(60))
                                .font(.system(size: 11))
                                .lineLimit(2)
                            Text(msg.timestamp, style: .time)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(theme.surfaceSecondary)
    }
}

// MARK: - File Tree View

struct FileTreeView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var workspace = ProjectWorkspace.shared
    @StateObject private var agent = CodeAgent.shared

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
                    Text("\(workspace.totalFileCount) files")
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
            .help("Close Project")

            Button(action: { workspace.openLocalFolder() }) {
                Image(systemName: "plus")
                    .font(.system(size: theme.iconS, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .help("Open Another Project")
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var searchField: some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.iconXS))
                .foregroundStyle(theme.textTertiary)
            TextField("搜索文件...", text: $workspace.searchText)
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
            Text("No project open")
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text("Open a folder to browse files")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)

            FusionButton("Open Project", icon: "folder.badge.plus", style: .tinted, size: .regular) {
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
        .contextMenu {
            if !file.isDirectory {
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                }
                Button("复制路径") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(file.relativePath, forType: .string)
                }
                Divider()
                if agent.fileContexts.contains(where: { $0.id == file.id }) {
                    Button("移除上下文") { agent.removeFileContext(file) }
                } else {
                    Button("添加到上下文") { agent.addFileContext(file) }
                }
            }
            if file.isDirectory {
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.selectFile(file.path, inFileViewerRootedAtPath: "")
                }
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
        codeLog.info("Selected file: \(file.name)")
    }
}

// MARK: - Git Status

struct GitStatusView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var workspace = ProjectWorkspace.shared
    @State private var changes: [(String, String)] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "arrow.triangle.branch").font(.system(size: 10))
                Text(workspace.gitBranch.isEmpty ? "Not a git repo" : workspace.gitBranch)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 4)

            if !workspace.hasProject {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "arrow.triangle.branch").font(.system(size: 20)).foregroundColor(.secondary)
                    Text("Open a project to see Git status").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else if changes.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "checkmark.circle").font(.system(size: 20)).foregroundColor(.secondary)
                    Text("No changes").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(changes, id: \.0) { (file, status) in
                    HStack(spacing: 4) {
                        Text(status).font(.system(size: 9, weight: .bold))
                            .foregroundColor(status == "M" ? .orange : .green)
                            .frame(width: 16)
                        Text(file).font(.system(size: 10))
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(theme.surfaceSecondary)
        .onAppear { loadGitChanges() }
        .onChange(of: workspace.projectRoot) { _, _ in loadGitChanges() }
    }

    private func loadGitChanges() {
        guard let root = workspace.projectRoot else { changes = []; return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["status", "--porcelain"]
        process.currentDirectoryURL = root

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            changes = output.split(separator: "\n").compactMap { line in
                let parts = String(line).split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                return (String(parts[1]), String(parts[0]).trimmingCharacters(in: .whitespaces))
            }
        } catch {
            changes = []
        }
    }
}

// MARK: - Chat Content View

struct ChatContentView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var agent = CodeAgent.shared
    @StateObject private var workspace = ProjectWorkspace.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if agent.conversation.isEmpty {
                        welcomeContent
                    }

                    ForEach(agent.conversation) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }

                    if agent.isThinking {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                            Text("Thinking...").font(.system(size: 12)).foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }

                    Spacer().frame(height: 8)
                }
            }
            .onChange(of: agent.conversation.count) { _, _ in
                withAnimation { proxy.scrollTo(agent.conversation.last?.id, anchor: .bottom) }
            }
        }
        .background(theme.inputBg)
    }

    private var welcomeContent: some View {
        VStack(spacing: theme.spacingL) {
            Spacer().frame(height: 40)
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(theme.accent)
            Text("Fusion Code — AI Coding Assistant")
                .font(.system(size: theme.headlineSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Text("Claude Code compatible · Powered by fusion-mlx")
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: theme.spacingM) {
                WelcomeCard(icon: "folder.badge.plus", title: "Open Project", desc: "加载本地/Git代码", accent: true) {
                    workspace.openLocalFolder()
                }
                WelcomeCard(icon: "questionmark.circle", title: "Explain", desc: "解释代码功能") {
                    agent.askAI(prompt: "Explain the code in the current file")
                }
                WelcomeCard(icon: "ant", title: "Review", desc: "查找代码缺陷") {
                    agent.askAI(prompt: "Review the code for bugs and issues")
                }
                WelcomeCard(icon: "testtube.2", title: "Test", desc: "生成单元测试") {
                    agent.askAI(prompt: "Write unit tests for the code")
                }
            }
            .padding(.horizontal, theme.spacingXL)

            if !workspace.recentProjects.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    Text("最近打开")
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .textCase(.uppercase)
                        .kerning(0.8)
                        .padding(.horizontal, theme.spacingXL)

                    ForEach(workspace.recentProjects.prefix(5)) { recent in
                        RecentProjectRow(project: recent) {
                            workspace.openRecent(recent)
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Welcome Card

struct WelcomeCard: View {
    let icon: String
    let title: String
    let desc: String
    var accent: Bool = false
    let action: () -> Void
    @Environment(\.studioTheme) var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: theme.spacingS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(accent ? theme.accent : theme.textSecondary)
                Text(title)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(desc)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacingM)
            .background(accent ? theme.accentSoft : theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(accent ? theme.accent.opacity(0.3) : theme.inputBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Project Row

struct RecentProjectRow: View {
    let project: RecentProject
    let action: () -> Void
    @Environment(\.studioTheme) var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "folder.fill")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(project.path)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Text(relativeTime(project.lastOpened))
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textQuaternary)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 604800 { return "\(Int(interval / 86400))天前" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Suggestion Card (backward compat)

struct SuggestionCard: View {
    @Environment(\.studioTheme) private var theme
    let icon: String; let title: String; let desc: String; let prompt: String
    @StateObject private var agent = CodeAgent.shared

    var body: some View {
        Button(action: { agent.askAI(prompt: prompt) }) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 11, weight: .medium))
                Text(desc).font(.system(size: 9)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(theme.surfaceSecondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: CodeAgent.CodeMessage
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if message.role == "user" {
                    Spacer()
                    Text("You").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                } else {
                    Text("Fusion Code").font(.system(size: 11, weight: .medium)).foregroundColor(.accentColor)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text(message.content)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .background(message.role == "user" ? Color.accentColor.opacity(0.05) : Color.clear)
    }
}

// MARK: - Terminal View

struct TerminalView: View {
    @State private var output: [TerminalLine] = [
        TerminalLine(text: "Fusion Studio Terminal v1.0", type: .info),
        TerminalLine(text: "Type 'help' for available commands", type: .info),
        TerminalLine(text: "", type: .input)
    ]
    @State private var currentInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Terminal").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                Spacer()
                Button("Clear") { output = [] }.buttonStyle(.borderless).controlSize(.small).font(.system(size: 10))
            }
            .padding(.horizontal, 12).padding(.vertical, 4)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(output) { line in
                            Text(line.attributedString)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .id(line.id)
                        }
                        HStack(spacing: 0) {
                            Text("$ ").font(.system(size: 12, design: .monospaced)).foregroundColor(.green)
                            TextField("", text: $currentInput)
                                .font(.system(size: 12, design: .monospaced))
                                .textFieldStyle(.plain)
                                .onSubmit { executeCommand(currentInput) }
                        }
                        .padding(.vertical, 2)
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.85))
                .foregroundColor(.white)
                .onChange(of: output.count) { _, _ in
                    withAnimation { proxy.scrollTo(output.last?.id, anchor: .bottom) }
                }
            }
        }
    }

    private func executeCommand(_ cmd: String) {
        guard !cmd.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        output.append(TerminalLine(text: "$ \(cmd)", type: .input))
        let result = processCommand(cmd)
        if !result.isEmpty { output.append(TerminalLine(text: result, type: .output)) }
        output.append(TerminalLine(text: "", type: .input))
        currentInput = ""
    }

    private func processCommand(_ cmd: String) -> String {
        switch cmd.lowercased() {
        case "help": return "Commands: help, clear, status, mlx, python, swift"
        case "clear": output = []; return ""
        case "status": return "Fusion Studio v1.0 | MLX: running | fusion-coder: ready"
        case "mlx": return "fusion-mlx: localhost:8000 | model: qwen3.5-9b-4bit"
        default: return "Unknown: \(cmd). Type 'help'"
        }
    }
}

struct TerminalLine: Identifiable {
    let id = UUID(); let text: String; let type: LineType
    enum LineType { case input, output, info }
    var attributedString: AttributedString {
        var attr = AttributedString(text)
        switch type { case .input: attr.foregroundColor = .green; case .output: attr.foregroundColor = .white; case .info: attr.foregroundColor = .cyan }
        return attr
    }
}
