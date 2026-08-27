import SwiftUI
import os.log

private let log = Logger(subsystem: "com.fusion.studio", category: "CliServiceView")

struct CliServiceView: View {
    @Environment(\.studioTheme) private var theme
    @State private var commandInput: String = ""
    @State private var outputLines: [String] = []
    @State private var isRunning: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "terminal").font(.system(size: 18, weight: .semibold)).foregroundStyle(theme.accent)
                Text(I18nManager.shared.t(.plugin_cli_title)).font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                Button(I18nManager.shared.t(.plugin_cli_btn_clear)) { outputLines.removeAll() }.font(.system(size: 11)).foregroundStyle(theme.textTertiary).buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.vertical, 10).background(theme.surfaceSecondary)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(outputLines.indices, id: \.self) { idx in
                            Text(outputLines[idx]).font(.system(size: 12, design: .monospaced)).foregroundStyle(lineColor(outputLines[idx])).textSelection(.enabled)
                        }
                    }.padding(12)
                }.background(theme.contentBg)
                .onChange(of: outputLines.count) { _ in if let last = outputLines.indices.last { proxy.scrollTo(last, anchor: .bottom) } }
            }
            HStack(spacing: 8) {
                Text(">").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(theme.accent)
                TextField(I18nManager.shared.t(.plugin_cli_ph_input), text: $commandInput).font(.system(size: 12, design: .monospaced)).textFieldStyle(.plain).onSubmit { executeCommand() }
                Button(action: executeCommand) { Image(systemName: "play.fill").font(.system(size: 11)).foregroundStyle(isRunning ? theme.textTertiary : theme.accent) }.buttonStyle(.plain).disabled(isRunning)
            }.padding(.horizontal, 16).padding(.vertical, 10).background(theme.surfaceSecondary)
        }.onAppear { log.info("CliServiceView appeared") }
    }

    // F-A17 审计0827 #3: 对齐 CLIView — env 剥敏感键 + PATH 锁防劫持; dangerPatterns 高危关键字拦截 + confirmDangerous 二次确认
    private static let dangerPatterns: [String] = [
        "rm -rf", "rm -fr", "curl | sh", "curl|sh", "wget | sh", "wget|sh",
        "mkfs", "dd if=", "> /dev/sd", "shutdown", "halt", "reboot", "kill -9",
        "$(", "`", "/dev/tcp/", "nc -e", "bash -i", "mkfifo", "chmod +x"
    ]

    private func confirmDangerous(_ cmd: String) -> Bool {
        let lower = cmd.lowercased()
        guard Self.dangerPatterns.contains(where: { lower.contains($0) }) else { return true }
        let alert = NSAlert()
        alert.messageText = I18nManager.shared.t(.cli_block_title)
        alert.informativeText = I18nManager.shared.t(.cli_block_msg)
        alert.addButton(withTitle: I18nManager.shared.t(.cli_btn_cancel))
        alert.addButton(withTitle: I18nManager.shared.t(.cli_block_continue))
        alert.alertStyle = .critical
        return alert.runModal() == .alertSecondButtonReturn
    }

    private func executeCommand() {
        let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        // F-A17 审计0827 #3: 粘贴不可信文本高危关键字拦截, 二次确认放行 (用户知情)
        guard confirmDangerous(cmd) else {
            outputLines.append("> \(cmd) [\(I18nManager.shared.t(.cli_btn_cancel))]")
            commandInput = ""
            log.info("CLI blocked by danger check: \(cmd, privacy: .public)")
            return
        }
        outputLines.append("> \(cmd)")
        commandInput = ""
        isRunning = true
        log.info("CLI executing: \(cmd, privacy: .public)")
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", cmd]
        // F-A17 审计0827 #3: env 剥敏感键 (TOKEN/KEY/SECRET/PASSWORD/CREDENTIAL/API_KEY) + 锁 PATH 防 PATH 劫持
        var env = ProcessInfo.processInfo.environment
        let sensitiveKeys = env.keys.filter {
            $0.contains("TOKEN") || $0.contains("KEY") || $0.contains("SECRET") ||
            $0.contains("PASSWORD") || $0.contains("CREDENTIAL") || $0 == "API_KEY"
        }
        for k in sensitiveKeys { env.removeValue(forKey: k) }
        env["PATH"] = "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"
        process.environment = env
        process.standardOutput = pipe
        process.standardError = pipe

        // readabilityHandler 只管数据: 有数据追加行, EOF(空 availableData)清自身
        let readHandle = pipe.fileHandleForReading
        readHandle.readabilityHandler = { handler in
            let data = handler.availableData
            if data.isEmpty {
                // EOF: 进程已关管道, 清 handler 避免泄漏
                handler.readabilityHandler = nil
                return
            }
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                output.split(separator: "\n", omittingEmptySubsequences: false).forEach { line in
                    let lineStr = String(line)
                    DispatchQueue.main.async { outputLines.append(lineStr) }
                }
            }
        }
        // terminationHandler 是退出权威信号: 清 handler + 收尾残留 + 复位 isRunning
        // 修复 BUG-9: 原 readabilityHandler 内轮询 isRunning 存在竞态, 退出无尾数据时漏判致 FD 泄漏
        process.terminationHandler = { proc in
            readHandle.readabilityHandler = nil
            let rest = readHandle.readDataToEndOfFile()
            if let restStr = String(data: rest, encoding: .utf8), !restStr.isEmpty {
                restStr.split(separator: "\n", omittingEmptySubsequences: false).forEach { line in
                    let lineStr = String(line)
                    DispatchQueue.main.async { outputLines.append(lineStr) }
                }
            }
            let status = proc.terminationStatus
            DispatchQueue.main.async {
                isRunning = false
                if status != 0 {
                    outputLines.append("\(I18nManager.shared.t(.plugin_cli_err_prefix)): exit \(status)")
                }
                log.info("CLI exit status: \(status)")
            }
        }

        do {
            try process.run()
        } catch {
            readHandle.readabilityHandler = nil
            outputLines.append("\(I18nManager.shared.t(.plugin_cli_err_prefix)): \(error.localizedDescription)")
            isRunning = false
        }
    }

    private func lineColor(_ line: String) -> Color {
        if line.hasPrefix("> ") { return theme.accent }
        if line.hasPrefix(I18nManager.shared.t(.plugin_cli_err_prefix)) { return theme.accentDestructive }
        return theme.text
    }
}
