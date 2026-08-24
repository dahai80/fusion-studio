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

    private func executeCommand() {
        let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        outputLines.append("> \(cmd)")
        commandInput = ""
        isRunning = true
        log.info("CLI executing: \(cmd)")
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", cmd]
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
