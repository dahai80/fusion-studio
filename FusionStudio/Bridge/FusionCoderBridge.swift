import Foundation
import Combine

/// FusionCoder 桥接 — 调用真实的 fusion-coder CLI
/// 通过子进程执行 fusion-coder 命令，获取 AI 编码辅助
class FusionCoderBridge: ObservableObject {
    static let shared = FusionCoderBridge()

    @Published var isRunning = false
    @Published var lastOutput = ""
    @Published var lastError: String?

    private let queue = DispatchQueue(label: "com.fusion-studio.fusion-coder", qos: .userInitiated)

    /// 找到 fusion-coder 可执行路径
    private var fusionCoderPath: String {
        // 优先使用项目内的 fusion-coder
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let projectPath = "\(home)/fusion/fusion-coder"
        if FileManager.default.fileExists(atPath: "\(projectPath)/pyproject.toml") {
            return "cd \(projectPath) && python3 -m fusion_coder"
        }
        // 回退到 PATH 中的 fusion-coder
        return "fusion-coder"
    }

    /// 执行命令并返回结果
    @discardableResult
    func execute(arguments: [String], input: String? = nil) async throws -> String {
        await MainActor.run { isRunning = true }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else { return }

                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/zsh")
                task.arguments = ["-c", "\(self.fusionCoderPath) \(arguments.joined(separator: " "))"]

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

    /// 运行 fusion-coder -p <prompt> 单次提示
    func runPrompt(_ prompt: String, model: String = "") async throws -> String {
        var args = ["-p", "\"\(prompt.replacingOccurrences(of: "\"", with: "\\\""))\""]
        if !model.isEmpty { args += ["--model", model] }
        return try await execute(arguments: args)
    }

    /// 运行 fusion-coder doctor 诊断
    func doctor() async throws -> String {
        return try await execute(arguments: ["doctor"])
    }

    /// 运行 fusion-coder run <prompt> 运行任务
    func runTask(_ prompt: String, model: String = "") async throws -> String {
        var args = ["run", "\"\(prompt.replacingOccurrences(of: "\"", with: "\\\""))\""]
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

    /// 运行代码 — 通过 fusion-coder 执行代码
    func runCode(_ code: String, language: String) async throws -> String {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("fusion_run_\(UUID().uuidString.prefix(8)).\(languageExtension(language))")
        try code.write(to: tempFile, atomically: true, encoding: .utf8)

        let runner: String
        switch language {
        case "python": runner = "python3"
        case "swift":  runner = "swift"
        case "rust":   runner = "rustc"
        case "js", "javascript": runner = "node"
        case "ts", "typescript": runner = "npx ts-node"
        default:       runner = "python3"
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", "\(runner) \(tempFile.path) 2>&1"]

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