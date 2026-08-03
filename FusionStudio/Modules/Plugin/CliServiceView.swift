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
                Text("CLI 服务").font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.textPrimary)
                Spacer()
                Button("清屏") { outputLines.removeAll() }.font(.system(size: 11)).foregroundStyle(theme.textTertiary).buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.vertical, 10).background(theme.backgroundSecondary)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(outputLines.indices, id: \.self) { idx in
                            Text(outputLines[idx]).font(.system(size: 12, design: .monospaced)).foregroundStyle(lineColor(outputLines[idx])).textSelection(.enabled)
                        }
                    }.padding(12)
                }.background(theme.backgroundPrimary)
                .onChange(of: outputLines.count) { _ in if let last = outputLines.indices.last { proxy.scrollTo(last, anchor: .bottom) } }
            }
            HStack(spacing: 8) {
                Text(">").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(theme.accent)
                TextField("输入命令...", text: $commandInput).font(.system(size: 12, design: .monospaced)).textFieldStyle(.plain).onSubmit { executeCommand() }
                Button(action: executeCommand) { Image(systemName: "play.fill").font(.system(size: 11)).foregroundStyle(isRunning ? theme.textTertiary : theme.accent) }.buttonStyle(.plain).disabled(isRunning)
            }.padding(.horizontal, 16).padding(.vertical, 10).background(theme.backgroundSecondary)
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
        do {
            try process.run()
            pipe.fileHandleForReading.readabilityHandler = { handler in
                let data = handler.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    output.split(separator: "\n").forEach { line in
                        DispatchQueue.main.async { outputLines.append(String(line)) }
                    }
                }
                if !process.isRunning {
                    handler.readabilityHandler = nil
                    DispatchQueue.main.async { isRunning = false }
                }
            }
        } catch {
            outputLines.append("错误: \(error.localizedDescription)")
            isRunning = false
        }
    }

    private func lineColor(_ line: String) -> Color {
        if line.hasPrefix("> ") { return theme.accent }
        if line.hasPrefix("错误") { return theme.danger }
        return theme.textPrimary
    }
}
