import Foundation
import Combine
import os.log

/// FusionCoder 桥接 — 调用真实的 fusion-coder CLI
/// 通过子进程执行 fusion-coder 命令，获取 AI 编码辅助
class FusionCoderBridge: ObservableObject {
    static let shared = FusionCoderBridge()

    @Published var isRunning = false
    @Published var lastOutput = ""
    @Published var lastError: String?

    private let queue = DispatchQueue(label: "com.fusion-studio.fusion-coder", qos: .userInitiated)

    /// fusion-coder 启动信息: executableURL + currentDirectoryURL + 初始参数前缀
    private struct CoderLaunch {
        let executableURL: URL
        let cwd: URL?
        let prefixArgs: [String]
    }

    /// 解析 fusion-coder 启动方式 (不拼 shell, 不走 PATH 盲查)
    private func coderLaunch() -> CoderLaunch? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let projectPath = "\(home)/fusion/fusion-coder"
        if FileManager.default.fileExists(atPath: "\(projectPath)/pyproject.toml") {
            return CoderLaunch(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                cwd: URL(fileURLWithPath: projectPath),
                prefixArgs: ["-m", "fusion_coder"]
            )
        }
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["fusion-coder"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = Pipe()
        do {
            try which.run()
            which.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
                return CoderLaunch(
                    executableURL: URL(fileURLWithPath: path),
                    cwd: nil,
                    prefixArgs: []
                )
            }
        } catch {
            Logger(subsystem: "com.fusion.studio", category: "FusionCoderBridge").error("定位 fusion-coder 失败: \(error.localizedDescription)")
        }
        return nil
    }

    /// 执行命令并返回结果 (无 shell, 参数数组直传, 避免 zsh -c 注入)
    @discardableResult
    func execute(arguments: [String], input: String? = nil) async throws -> String {
        await MainActor.run { isRunning = true }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else { return }

                guard let launch = self.coderLaunch() else {
                    DispatchQueue.main.async { self.isRunning = false }
                    continuation.resume(throwing: NSError(
                        domain: "FusionCoderBridge", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "fusion-coder 未找到"]
                    ))
                    return
                }

                let task = Process()
                task.executableURL = launch.executableURL
                task.arguments = launch.prefixArgs + arguments
                if let cwd = launch.cwd { task.currentDirectoryURL = cwd }

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                task.standardOutput = outputPipe
                task.standardError = errorPipe

                if let input = input {
                    let inputPipe = Pipe()
                    inputPipe.fileHandleForWriting.write(input.data(using: .utf8)!)
                    inputPipe.fileHandleForWriting.closeFile()
                    task.standardInput = inputPipe
                }

                do {
                    try task.run()
                    task.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""

                    DispatchQueue.main.async {
                        self.lastOutput = output
                        self.lastError = error.isEmpty ? nil : error
                        self.isRunning = false
                    }

                    continuation.resume(returning: output)
                } catch {
                    DispatchQueue.main.async {
                        self.lastError = error.localizedDescription
                        self.isRunning = false
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 运行 fusion-coder -p <prompt> 单次提示 (prompt 作裸参数, 不经 shell 转义)
    func runPrompt(_ prompt: String, model: String = "") async throws -> String {
        var args = ["-p", prompt]
        if !model.isEmpty { args += ["--model", model] }
        return try await execute(arguments: args)
    }

    /// 运行 fusion-coder doctor 诊断
    func doctor() async throws -> String {
        return try await execute(arguments: ["doctor"])
    }

    /// 运行 fusion-coder run <prompt> 运行任务 (prompt 作裸参数)
    func runTask(_ prompt: String, model: String = "") async throws -> String {
        var args = ["run", prompt]
        if !model.isEmpty { args += ["--model", model] }
        return try await execute(arguments: args)
    }

    /// 解释代码 — 调用 fusion-coder 的 AI 解释能力
    func explainCode(_ code: String, language: String) async throws -> String {
        let prompt = "解释以下 \(language) 代码的功能和实现原理：\n\n```\(language)\n\(code)\n```"
        return try await runPrompt(prompt)
    }

    /// 审查代码 — 调用 fusion-coder 的代码审查能力
    func reviewCode(_ code: String, language: String) async throws -> String {
        let prompt = "审查以下 \(language) 代码，指出潜在问题、安全漏洞和改进建议：\n\n```\(language)\n\(code)\n```"
        return try await runPrompt(prompt)
    }

    /// 优化代码 — 调用 fusion-coder 的优化能力
    func optimizeCode(_ code: String, language: String) async throws -> String {
        let prompt = "优化以下 \(language) 代码的性能和可读性：\n\n```\(language)\n\(code)\n```"
        return try await runPrompt(prompt)
    }

    /// 生成测试 — 调用 fusion-coder 的测试生成能力
    func generateTests(_ code: String, language: String) async throws -> String {
        let prompt = "为以下 \(language) 代码生成单元测试用例：\n\n```\(language)\n\(code)\n```"
        return try await runPrompt(prompt)
    }

    /// 运行代码 — 通过子进程执行代码文件 (无 shell, executableURL + 参数数组)
    func runCode(_ code: String, language: String) async throws -> String {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("fusion_run_\(UUID().uuidString.prefix(8)).\(languageExtension(language))")
        try code.write(to: tempFile, atomically: true, encoding: .utf8)

        let executable: String
        var args: [String]
        switch language {
        case "python":
            executable = "/usr/bin/python3"; args = [tempFile.path]
        case "swift":
            executable = "/usr/bin/swift"; args = [tempFile.path]
        case "rust":
            executable = "/usr/bin/rustc"; args = [tempFile.path]
        case "js", "javascript":
            executable = "/usr/local/bin/node"; args = [tempFile.path]
        case "ts", "typescript":
            executable = "/usr/local/bin/npx"; args = ["ts-node", tempFile.path]
        default:
            executable = "/usr/bin/python3"; args = [tempFile.path]
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        try task.run()
        task.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        try? FileManager.default.removeItem(at: tempFile)
        return output
    }

    private func languageExtension(_ language: String) -> String {
        switch language {
        case "python": return "py"
        case "swift":  return "swift"
        case "rust":   return "rs"
        case "javascript", "js": return "js"
        case "typescript", "ts": return "ts"
        default: return "txt"
        }
    }
}