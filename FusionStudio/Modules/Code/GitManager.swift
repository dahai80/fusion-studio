import Foundation
import os.log

private let gitLog = Logger(subsystem: "com.fusion.studio", category: "GitManager")

class GitManager: ObservableObject {
    static let shared = GitManager()

    @Published var branch: String = ""
    @Published var changes: [GitChange] = []
    @Published var branches: [String] = []
    @Published var log: [GitLogEntry] = []
    @Published var stashList: [String] = []
    @Published var isLoading = false

    private var projectRoot: URL?

    func setProjectRoot(_ url: URL?) {
        projectRoot = url
        refresh()
    }

    func refresh() {
        guard let root = projectRoot else {
            branch = ""; changes = []; branches = []; log = []; stashList = []
            return
        }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let b = self.runGit(["rev-parse", "--abbrev-ref", "HEAD"], at: root) ?? ""
            let br = self.runGit(["branch", "--list"], at: root)?
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "* ", with: "") }
                .filter { !$0.isEmpty } ?? []
            let ch = self.parseStatus(self.runGit(["status", "--porcelain"], at: root) ?? "")
            let lg = self.parseLog(self.runGit(["log", "--oneline", "-30"], at: root) ?? "")
            let st = self.runGit(["stash", "list"], at: root)?
                .components(separatedBy: "\n")
                .filter { !$0.isEmpty } ?? []

            DispatchQueue.main.async {
                self.branch = b
                self.branches = br
                self.changes = ch
                self.log = lg
                self.stashList = st
                self.isLoading = false
                gitLog.info("Git refresh: branch=\(b), \(ch.count) changes, \(br.count) branches")
            }
        }
    }

    func commit(message: String) -> Bool {
        guard let root = projectRoot, !message.isEmpty else { return false }
        gitLog.info("Committing: \(message)")
        _ = runGit(["add", "-A"], at: root)
        let result = runGit(["commit", "-m", message], at: root)
        refresh()
        return result != nil
    }

    func checkout(branch: String) -> Bool {
        guard let root = projectRoot else { return false }
        gitLog.info("Checking out: \(branch)")
        let result = runGit(["checkout", branch], at: root)
        refresh()
        return result != nil
    }

    func createBranch(name: String) -> Bool {
        guard let root = projectRoot else { return false }
        gitLog.info("Creating branch: \(name)")
        let result = runGit(["checkout", "-b", name], at: root)
        refresh()
        return result != nil
    }

    func stash(message: String = "") -> Bool {
        guard let root = projectRoot else { return false }
        gitLog.info("Stashing changes")
        let args = message.isEmpty ? ["stash"] : ["stash", "push", "-m", message]
        let result = runGit(args, at: root)
        refresh()
        return result != nil
    }

    func stashPop() -> Bool {
        guard let root = projectRoot else { return false }
        gitLog.info("Popping stash")
        let result = runGit(["stash", "pop"], at: root)
        refresh()
        return result != nil
    }

    func diff(file: String? = nil) -> String? {
        guard let root = projectRoot else { return nil }
        var args = ["diff"]
        if let file = file { args.append(file) }
        return runGit(args, at: root)
    }

    func pull() -> Bool {
        guard let root = projectRoot else { return false }
        gitLog.info("Pulling")
        let result = runGit(["pull"], at: root)
        refresh()
        return result != nil
    }

    func push() -> Bool {
        guard let root = projectRoot else { return false }
        gitLog.info("Pushing")
        let result = runGit(["push"], at: root)
        return result != nil
    }

    func discardChanges(file: String) -> Bool {
        guard let root = projectRoot else { return false }
        gitLog.info("Discarding changes: \(file)")
        let result = runGit(["checkout", "--", file], at: root)
        refresh()
        return result != nil
    }

    // MARK: - Private

    private func runGit(_ args: [String], at root: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = root

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            // F-R7: waitUntilExit 30s 超时兜底防 git 挂起 (交互式凭证提示/网络 stall)。
            // 30s 容纳 push/fetch 正常网络耗时, 挡真挂起。超时强杀, 返回 nil 不永阻塞。
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if process.isRunning {
                    process.terminate()
                    gitLog.warning("git \(args.first ?? "") timeout 30s, force terminate")
                }
            }
            process.waitUntilExit()
            timeoutTask.cancel()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            if process.terminationStatus != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? ""
                gitLog.error("git \(args.first ?? "") failed: \(errMsg)")
                return nil
            }
            return String(data: data, encoding: .utf8)
        } catch {
            gitLog.error("git execution failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseStatus(_ output: String) -> [GitChange] {
        output.components(separatedBy: "\n").compactMap { line in
            guard line.count >= 3 else { return nil }
            let statusCode = String(line.prefix(2)).trimmingCharacters(in: .whitespaces)
            let file = String(line.dropFirst(3))
            guard !file.isEmpty else { return nil }
            return GitChange(file: file, status: statusCode)
        }
    }

    private func parseLog(_ output: String) -> [GitLogEntry] {
        output.components(separatedBy: "\n").compactMap { line in
            guard line.count > 8 else { return nil }
            let hash = String(line.prefix(7))
            let message = String(line.dropFirst(8))
            guard !message.isEmpty else { return nil }
            return GitLogEntry(hash: hash, message: message)
        }
    }
}

struct GitChange: Identifiable {
    let id = UUID()
    let file: String
    let status: String

    var statusColor: String {
        switch status {
        case "M", "MM": return "orange"
        case "A": return "green"
        case "D": return "red"
        case "??": return "blue"
        case "R": return "purple"
        default: return "gray"
        }
    }

    var statusLabel: String {
        switch status {
        case "M", "MM": return "Modified"
        case "A": return "Added"
        case "D": return "Deleted"
        case "??": return "Untracked"
        case "R": return "Renamed"
        default: return status
        }
    }
}

struct GitLogEntry: Identifiable {
    let id = UUID()
    let hash: String
    let message: String
}
