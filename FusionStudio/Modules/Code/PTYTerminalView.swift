import SwiftUI
import AppKit
import os.log

private let ptyLog = Logger(subsystem: "com.fusion.studio", category: "PTYTerminal")

class PTYSession: ObservableObject {
    @Published var lines: [PTYLine] = []
    @Published var isRunning = false
    @Published var currentDirectory: String = NSHomeDirectory()

    private var masterFd: Int32 = -1
    private var process: Process?
    private var readSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.fusion.studio.pty-read", qos: .userInteractive)

    func start(shell: String = "/bin/zsh", directory: String? = nil) {
        guard !isRunning else { return }
        let cwd = directory ?? currentDirectory
        var masterFD: Int32 = -1
        var slaveFD: Int32 = -1

        guard openpty(&masterFD, &slaveFD, nil, nil, nil) == 0 else {
            ptyLog.error("openpty failed: \(String(cString: strerror(errno)))")
            appendLine(text: "Failed to allocate PTY: \(String(cString: strerror(errno)))", type: .error)
            return
        }

        self.masterFd = masterFD

        let ttyName = ttyname(slaveFD)
        let ttyPath = ttyName != nil ? String(cString: ttyName!) : nil
        ptyLog.info("PTY allocated: master=\(masterFD) slave=\(slaveFD) tty=\(ttyPath ?? "unknown")")

        let p = Process()
        p.executableURL = URL(fileURLWithPath: shell)
        p.currentDirectoryURL = URL(fileURLWithPath: cwd)
        p.environment = ProcessInfo.processInfo.environment.merging([
            "TERM": "xterm-256color",
            "COLORTERM": "truecolor",
            "COLUMNS": "120",
            "LINES": "40"
        ]) { _, new in new }

        let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)
        p.standardInput = slaveHandle
        p.standardOutput = slaveHandle
        p.standardError = slaveHandle

        self.process = p

        do {
            try p.run()
            close(slaveFD)
            isRunning = true
            appendLine(text: "Shell started: \(shell)", type: .info)
            startReading(masterFd: masterFD)
        } catch {
            ptyLog.error("Failed to start shell: \(error.localizedDescription)")
            appendLine(text: "Failed to start shell: \(error.localizedDescription)", type: .error)
            close(masterFD)
            close(slaveFD)
            self.masterFd = -1
        }
    }

    private func startReading(masterFd: Int32) {
        let source = DispatchSource.makeReadSource(fileDescriptor: masterFd, queue: queue)
        var buffer = [UInt8](repeating: 0, count: 4096)

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let bytesRead = Darwin.read(masterFd, &buffer, buffer.count)
            guard bytesRead > 0 else {
                if bytesRead == 0 {
                    DispatchQueue.main.async {
                        self.isRunning = false
                        self.appendLine(text: "Shell exited.", type: .info)
                    }
                }
                return
            }
            let data = Data(buffer[0..<bytesRead])
            let output = self.parseOutput(data)
            if !output.isEmpty {
                DispatchQueue.main.async {
                    for line in output {
                        self.appendLine(text: line, type: .output)
                    }
                }
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.masterFd)
            self.masterFd = -1
        }

        readSource = source
        source.resume()
    }

    private func parseOutput(_ data: Data) -> [String] {
        guard let raw = String(data: data, encoding: .utf8) else {
            return [data.map { String(format: "%02x", $0) }.joined()]
        }
        let cleaned = raw
            .replacingOccurrences(of: "\u{1B}[\\[(][0-9;?]*[A-Za-z]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\u{1B}][^\u{07}]*\u{07}", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\u{1B}[>=]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "")
        let lines = cleaned.components(separatedBy: "\n")
        return lines.filter { !$0.isEmpty || lines.count == 1 }
    }

    func write(_ input: String) {
        guard masterFd >= 0, isRunning else { return }
        let data = (input + "\n").data(using: .utf8) ?? Data()
        _ = data.withUnsafeBytes { ptr in
            Darwin.write(masterFd, ptr.baseAddress, data.count)
        }
        appendLine(text: "❯ \(input)", type: .input)
    }

    func sendCtrlC() {
        guard masterFd >= 0, isRunning else { return }
        var sigint: UInt8 = 3
        _ = Darwin.write(masterFd, &sigint, 1)
    }

    func sendCtrlD() {
        guard masterFd >= 0, isRunning else { return }
        var eot: UInt8 = 4
        _ = Darwin.write(masterFd, &eot, 1)
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
        process?.terminate()
        process = nil
        isRunning = false
        if masterFd >= 0 {
            close(masterFd)
            masterFd = -1
        }
    }

    func clear() {
        lines.removeAll()
    }

    private func appendLine(text: String, type: PTYLine.LineType) {
        lines.append(PTYLine(text: text, type: type))
        if lines.count > 5000 {
            lines.removeFirst(lines.count - 5000)
        }
    }

    deinit {
        stop()
    }
}

struct PTYLine: Identifiable {
    let id = UUID()
    let text: String
    let type: LineType
    enum LineType { case input, output, info, error }
    var attributedString: AttributedString {
        var attr = AttributedString(text)
        switch type {
        case .input: attr.foregroundColor = .green
        case .output: attr.foregroundColor = .white
        case .info: attr.foregroundColor = .cyan
        case .error: attr.foregroundColor = .red
        }
        return attr
    }
}

struct PTYTerminalView: View {
    @StateObject private var session = PTYSession()
    @State private var inputText = ""
    @Binding var workingDirectory: String?

    var body: some View {
        VStack(spacing: 0) {
            terminalToolbar
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(session.lines) { line in
                            Text(line.attributedString)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .id(line.id)
                        }
                        if session.isRunning {
                            HStack(spacing: 0) {
                                Text("❯ ").font(.system(size: 12, design: .monospaced)).foregroundColor(.green)
                                TextField("", text: $inputText)
                                    .font(.system(size: 12, design: .monospaced))
                                    .textFieldStyle(.plain)
                                    .foregroundColor(.white)
                                    .onSubmit {
                                        let cmd = inputText
                                        inputText = ""
                                        session.write(cmd)
                                    }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.9))
                .foregroundColor(.white)
                .onChange(of: session.lines.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(session.lines.last?.id, anchor: .bottom)
                    }
                }
            }
        }
        .onAppear {
            session.start(directory: workingDirectory)
        }
        .onDisappear {
            session.stop()
        }
    }

    private var terminalToolbar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(session.isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(session.isRunning ? "zsh" : "stopped")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
            Button {
                session.sendCtrlC()
            } label: {
                Text("^C").font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Button {
                session.clear()
            } label: {
                Text("Clear").font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            if session.isRunning {
                Button {
                    session.stop()
                } label: {
                    Text("Stop").font(.system(size: 10)).foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            } else {
                Button {
                    session.start(directory: workingDirectory)
                } label: {
                    Text("Restart").font(.system(size: 10)).foregroundColor(.green)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6))
    }
}
