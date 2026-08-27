// F-I7: CodeEditorView.swift 拆分 — 两大 ObservableObject。
// 迁自 CodeEditorView.swift: ProjectWorkspace / CodeAgent。
// codeEditLog 共享在 CodeView.swift (module-internal let)。本文件用 17+1 次。

import SwiftUI
import AppKit
import os.log

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
        panel.title = I18nManager.shared.t(.fc_open_project_folder)
        panel.prompt = I18nManager.shared.t(.fc_open_folder)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadProject(from: url)
    }

    func openSingleFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = I18nManager.shared.t(.fc_open_file)
        panel.prompt = I18nManager.shared.t(.fc_open_folder)
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
            codeEditLog.warning("Recent project path no longer exists: \(recent.path)")
            recentProjects.removeAll { $0.id == recent.id }
            saveRecentProjects()
        }
    }

    func loadProject(from url: URL) {
        cancelLoading()
        loadTask = Task { @MainActor in
            isLoading = true
            loadProgress = 0
            loadMessage = String(format: I18nManager.shared.t(.fc_scanning), url.lastPathComponent)
            projectRoot = url
            projectName = url.lastPathComponent
            gitBranch = detectGitBranch(at: url)

            codeEditLog.info("Loading project from: \(url.path)")

            let scanned = await scanDirectory(url, depth: 0, maxDepth: 6)

            guard !Task.isCancelled else { return }
            files = scanned
            isLoading = false
            loadProgress = 1.0
            loadMessage = String(format: I18nManager.shared.t(.fc_loaded_files), totalFileCount)

            let recent = RecentProject(name: projectName, path: url.path)
            addRecentProject(recent)

            codeEditLog.info("Project loaded: \(self.projectName), \(self.totalFileCount) files, branch: \(self.gitBranch)")
        }
    }

    func loadSingleFile(from url: URL) {
        cancelLoading()
        loadTask = Task { @MainActor in
            isLoading = true
            loadProgress = 0
            loadMessage = String(format: I18nManager.shared.t(.fc_loading), url.lastPathComponent)

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
                loadMessage = I18nManager.shared.t(.fc_loaded_one_file)

                let recent = RecentProject(name: url.lastPathComponent, path: url.path)
                addRecentProject(recent)

                codeEditLog.info("Single file loaded: \(url.lastPathComponent)")
            } catch {
                isLoading = false
                loadMessage = String(format: I18nManager.shared.t(.fc_load_failed), error.localizedDescription)
                codeEditLog.error("Failed to load file: \(error.localizedDescription)")
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
        codeEditLog.info("Project closed")
    }

    // MARK: - File Read/Write

    func loadFileContent(_ file: CodeFile) -> String? {
        let url = URL(fileURLWithPath: file.path)
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            codeEditLog.info("File content loaded: \(file.name)")
            return content
        } catch {
            codeEditLog.error("Failed to read file \(file.name): \(error.localizedDescription)")
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

            codeEditLog.info("File saved: \(file.name), checkpoint stored")
            return true
        } catch {
            codeEditLog.error("Failed to write file \(file.name): \(error.localizedDescription)")
            return false
        }
    }

    func undoLastWrite(_ file: CodeFile) -> Bool {
        guard let original = checkpoints[file.path] else {
            codeEditLog.warning("No checkpoint for file: \(file.name)")
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

            codeEditLog.info("Checkpoint restored for: \(file.name)")
            return true
        } catch {
            codeEditLog.error("Failed to restore checkpoint: \(error.localizedDescription)")
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
                    loadMessage = String(format: I18nManager.shared.t(.fc_scanning_n), index, sorted.count)
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
            // F-R7: waitUntilExit 10s 超时兜底防 git 挂起 (如交互式凭证提示)。超时强杀。
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if process.isRunning {
                    process.terminate()
                    codeEditLog.warning("detectGitBranch timeout 10s, force terminate")
                }
            }
            process.waitUntilExit()
            timeoutTask.cancel()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let branch = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return branch.isEmpty ? "" : branch
            }
        } catch {
            codeEditLog.debug("git branch detection failed: \(error.localizedDescription)")
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
            codeEditLog.error("Failed to save recent projects: \(error.localizedDescription)")
        }
    }

    private func loadRecentProjects() {
        guard let data = UserDefaults.standard.data(forKey: recentKey) else { return }
        do {
            recentProjects = try JSONDecoder().decode([RecentProject].self, from: data)
        } catch {
            codeEditLog.error("Failed to load recent projects: \(error.localizedDescription)")
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
    @Published var scrollToMessageId: UUID?
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
        Task { [weak self, fullPrompt] in
            guard let self = self else { return }
            do {
                guard let bridge = self.agentBridge else {
                    throw NSError(domain: "CodeAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: "AgentBridge not connected"])
                }
                // Callers: CodeEditorView → agentBridge.infer. Affected API: infer [[String:Any]].
                let messages: [[String: Any]] = [
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
                    let err = "⚠️ \((error as? BridgeError)?.userMessage ?? I18nManager.shared.t(.fc_ai_unavailable))"
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
            codeEditLog.info("Added file context: \(file.name)")
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
