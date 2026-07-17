import SwiftUI
import AppKit

/// 代码编辑器组件 — 基于 SwiftUI 原生实现
struct CodeEditorView: View {
    @State private var code: String = "// Welcome to Fusion Code\n// Start coding here...\n\nfunc main() {\n    print(\"Hello, Fusion Studio!\")\n}\n"
    @State private var selectedLanguage: String = "swift"
    @State private var fontSize: CGFloat = 14

    let languages = ["swift", "python", "rust", "javascript", "typescript", "html", "css", "json", "yaml"]

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Picker("语言", selection: $selectedLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang.uppercased()).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { runCode() }) {
                        Label("运行", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button(action: { formatCode() }) {
                        Label("格式化", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(action: { copyCode() }) {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Slider(value: $fontSize, in: 10...24, step: 1)
                        .frame(width: 80)
                        .help("字号")
                    Text("\(Int(fontSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 代码编辑区
            ScrollView([.horizontal, .vertical]) {
                TextEditor(text: $code)
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(minWidth: 600, minHeight: 300)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))

            // 底部状态栏
            HStack {
                Text("\(code.split(separator: "\n").count) 行")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(selectedLanguage.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private func runCode() {
        // 后续实现：调用 fusion-coder 执行
        print("运行代码: \(selectedLanguage)")
    }

    private func formatCode() {
        // 后续实现：代码格式化
        print("格式化代码")
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
    }
}

/// 集成终端组件
struct TerminalView: View {
    @State private var output: [TerminalLine] = [
        TerminalLine(text: "Fusion Studio Terminal v0.1", type: .info),
        TerminalLine(text: "Type 'help' for available commands", type: .info),
        TerminalLine(text: "", type: .input)
    ]
    @State private var currentInput: String = ""
    @State private var scrollToBottom = false

    var body: some View {
        VStack(spacing: 0) {
            // 终端标题栏
            HStack {
                Label("终端", systemImage: "terminal")
                    .font(.caption)
                Spacer()
                Button(action: clearTerminal) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 终端输出
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(output) { line in
                            Text(line.attributedString)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .id(line.id)
                        }

                        // 输入行
                        HStack(spacing: 0) {
                            Text("$ ")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.green)
                            TextField("", text: $currentInput)
                                .font(.system(size: 12, design: .monospaced))
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    executeCommand(currentInput)
                                }
                        }
                        .padding(.vertical, 2)
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.85))
                .foregroundColor(.white)
                .onChange(of: output.count) { _ in
                    withAnimation {
                        proxy.scrollTo(output.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func executeCommand(_ cmd: String) {
        guard !cmd.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        output.append(TerminalLine(text: "$ \(cmd)", type: .input))

        // 模拟命令执行
        Task {
            let result = await runShellCommand(cmd)
            if !result.isEmpty {
                output.append(TerminalLine(text: result, type: .output))
            }
            output.append(TerminalLine(text: "", type: .input))
        }

        currentInput = ""
    }

    private func runShellCommand(_ cmd: String) async -> String {
        // 后续实现：通过 IPC 调用实际 shell
        switch cmd.lowercased() {
        case "help":
            return """
            可用命令:
              help   - 显示帮助
              clear  - 清屏
              status - 查看服务状态
              mlx    - 查看 MLX 状态
            """
        case "clear":
            await MainActor.run { clearTerminal() }
            return ""
        case "status":
            return "Fusion Studio v0.1 | MLX: 运行中 | 内存: 12.4GB/32GB"
        case "mlx":
            return "fusion-mlx: 运行中 (localhost:8000)\n模型: qwen3.5-9b-4bit\n量化: 4bit"
        default:
            return "未知命令: \(cmd)\n输入 'help' 查看可用命令"
        }
    }

    private func clearTerminal() {
        output = [TerminalLine(text: "终端已清空", type: .info)]
    }
}

struct TerminalLine: Identifiable {
    let id = UUID()
    let text: String
    let type: LineType

    enum LineType {
        case input
        case output
        case info
    }

    var attributedString: AttributedString {
        var attr = AttributedString(text)
        switch type {
        case .input:
            attr.foregroundColor = .green
        case .output:
            attr.foregroundColor = .white
        case .info:
            attr.foregroundColor = .cyan
        }
        attr.font = .system(size: 12, design: .monospaced)
        return attr
    }
}