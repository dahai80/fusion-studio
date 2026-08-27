// F-I7: CodeEditorView.swift 拆分 — 终端视图 (独立组件)。
// 迁自 CodeEditorView.swift: TerminalView。
// TerminalLine 模型迁在 CodeModels.swift; TerminalView 引用 FusionConfig.shared.mlxPort (Common/, 模块 internal)。

import SwiftUI

// MARK: - Terminal View

struct TerminalView: View {
    @StateObject private var i18n = I18nManager.shared
    @State private var output: [TerminalLine] = []
    @State private var currentInput: String = ""
    @State private var didInitBanner = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(i18n.t(.fc_terminal)).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                Spacer()
                Button(i18n.t(.fc_clear)) { output = [] }.buttonStyle(.borderless).controlSize(.small).font(.system(size: 10))
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
        .onAppear {
            guard !didInitBanner else { return }
            didInitBanner = true
            output = [
                TerminalLine(text: i18n.t(.fc_term_banner), type: .info),
                TerminalLine(text: i18n.t(.fc_term_help_hint), type: .info),
                TerminalLine(text: "", type: .input)
            ]
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
        case "help": return i18n.t(.fc_term_commands)
        case "clear": output = []; return ""
        case "status": return "Fusion Studio v1.0 | MLX: running | fusion-code: ready"
        case "mlx": return "fusion-mlx: localhost:\(FusionConfig.shared.mlxPort) | model: qwen3.5-9b-4bit"
        default: return String(format: i18n.t(.fc_term_unknown), cmd)
        }
    }
}
