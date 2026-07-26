// Callers: ModuleDetailView routing.
// Affected API: CLIView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

/// CLI 命令预设
struct CLIPreset: Identifiable {
    let id: String
    let title: String
    let command: String
    let description: String
    let category: CLICategory
    let icon: String
    let dangerLevel: Int  // 0=safe, 1=caution, 2=destructive

    enum CLICategory: String, CaseIterable {
        case model    = "模型管理"
        case kb       = "知识库"
        case bench    = "基准测试"
        case service  = "服务管理"
        case desk     = "桌面自动化"
        case utility  = "工具"

        var icon: String {
            switch self {
            case .model:   return "cpu"
            case .kb:      return "books.vertical"
            case .bench:   return "chart.bar"
            case .service: return "gearshape.2"
            case .desk:    return "desktopcomputer"
            case .utility: return "wrench.and.screwdriver"
            }
        }
    }
}

// MARK: - 预设命令

let cliPresets: [CLIPreset] = [
    // 模型管理
    CLIPreset(id: "model-list", title: "列出模型", command: "fusion model list", description: "列出所有本地 MLX 模型", category: .model, icon: "list.bullet", dangerLevel: 0),
    CLIPreset(id: "model-pull", title: "下载模型", command: "fusion model pull", description: "从 Model-Hub 下载模型", category: .model, icon: "icloud.and.arrow.down", dangerLevel: 0),
    CLIPreset(id: "model-delete", title: "删除模型", command: "fusion model delete", description: "删除本地模型", category: .model, icon: "trash", dangerLevel: 2),

    // 知识库
    CLIPreset(id: "kb-list", title: "知识库列表", command: "fusion kb list", description: "列出所有知识库", category: .kb, icon: "list.bullet", dangerLevel: 0),
    CLIPreset(id: "kb-create", title: "创建知识库", command: "fusion kb create", description: "创建新的知识库", category: .kb, icon: "plus.circle", dangerLevel: 0),
    CLIPreset(id: "kb-ingest", title: "导入文档", command: "fusion kb ingest", description: "导入文档到知识库", category: .kb, icon: "doc.badge.plus", dangerLevel: 0),

    // 基准测试
    CLIPreset(id: "bench-speed", title: "速度测试", command: "fusion bench speed", description: "Token 生成速度测试", category: .bench, icon: "speedometer", dangerLevel: 0),
    CLIPreset(id: "bench-mem", title: "内存测试", command: "fusion bench mem", description: "内存使用分析", category: .bench, icon: "memorychip", dangerLevel: 0),
    CLIPreset(id: "bench-ctx", title: "上下文测试", command: "fusion bench ctx", description: "上下文长度压力测试", category: .bench, icon: "doc.text.magnifyingglass", dangerLevel: 0),

    // 服务管理
    CLIPreset(id: "svc-status", title: "服务状态", command: "fusion service status", description: "查看所有服务状态", category: .service, icon: "info.circle", dangerLevel: 0),
    CLIPreset(id: "svc-start", title: "启动服务", command: "fusion service start", description: "启动服务", category: .service, icon: "play.circle", dangerLevel: 0),
    CLIPreset(id: "svc-stop", title: "停止服务", command: "fusion service stop", description: "停止服务", category: .service, icon: "stop.circle", dangerLevel: 1),

    // 桌面自动化
    CLIPreset(id: "desk-list", title: "模板列表", command: "fusion desk list", description: "列出自动化模板", category: .desk, icon: "list.bullet", dangerLevel: 0),
    CLIPreset(id: "desk-run", title: "运行模板", command: "fusion desk run", description: "执行自动化模板", category: .desk, icon: "play", dangerLevel: 1),
]

// MARK: - 命令历史

struct CommandHistory: Identifiable {
    let id = UUID()
    let timestamp: Date
    let command: String
    let output: String
    let exitCode: Int32
    let duration: TimeInterval
}

// MARK: - 主视图

struct CLIView: View {
    @Environment(\.studioTheme) private var theme
    @State private var commandInput = ""
    @State private var history: [CommandHistory] = []
    @State private var isExecuting = false
    @State private var selectedCategory: CLIPreset.CLICategory?
    @State private var showHistory = true
    @State private var historyFilter = ""

    var filteredHistory: [CommandHistory] {
        if historyFilter.isEmpty { return history }
        return history.filter { $0.command.localizedCaseInsensitiveContains(historyFilter) }
    }

    var body: some View {
        HSplitView {
            // 左侧：预设命令面板
            VStack(spacing: 0) {
                Text("快捷命令")
                    .font(.headline)
                    .padding(8)

                List {
                    ForEach(CLIPreset.CLICategory.allCases, id: \.self) { category in
                        Section {
                            let presets = cliPresets.filter { $0.category == category }
                            ForEach(presets) { preset in
                                PresetCommandRow(preset: preset)
                                    .onTapGesture {
                                        runPreset(preset)
                                    }
                            }
                        } header: {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200, maxWidth: 280)

            // 右侧：命令执行区
            VStack(spacing: 0) {
                // 命令输入栏
                HStack {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.green)
                        .font(.system(size: 14, weight: .bold))
                    TextField("输入 fusion 命令...", text: $commandInput)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit {
                            executeCommand(commandInput)
                        }
                        .disabled(isExecuting)

                    if isExecuting {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    }

                    Button(action: { executeCommand(commandInput) }) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(commandInput.isEmpty || isExecuting)

                    Button(action: { history.removeAll() }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(theme.surfaceSecondary)

                Divider()

                // 历史输出
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if filteredHistory.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer().frame(height: 40)
                                    Image(systemName: "terminal")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                    Text("从左侧选择快捷命令，或直接输入命令")
                                        .foregroundColor(.secondary)
                                    Text("提示: 输入 help 查看可用命令")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }

                            ForEach(filteredHistory) { entry in
                                CommandOutputView(entry: entry)
                                    .id(entry.id)
                            }
                        }
                    }
                    .background(Color.black.opacity(0.85))
                    .onChange(of: history.count) { _ in
                        withAnimation {
                            proxy.scrollTo(history.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 400)
    }

    private func runPreset(_ preset: CLIPreset) {
        if preset.dangerLevel >= 2 {
            let alert = NSAlert()
            alert.messageText = "确认执行"
            alert.informativeText = "此操作将 \(preset.description)。确定要继续吗？"
            alert.addButton(withTitle: "取消")
            alert.addButton(withTitle: "继续")
            alert.alertStyle = .warning
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        commandInput = preset.command
        executeCommand(preset.command)
    }

    private func executeCommand(_ cmd: String) {
        guard !cmd.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isExecuting = true
        let startTime = Date()

        Task {
            let (output, exitCode) = await runShell(cmd)
            let duration = Date().timeIntervalSince(startTime)

            await MainActor.run {
                let entry = CommandHistory(
                    timestamp: startTime,
                    command: cmd,
                    output: output,
                    exitCode: exitCode,
                    duration: duration
                )
                history.append(entry)
                commandInput = ""
                isExecuting = false
            }
        }
    }

    private func runShell(_ cmd: String) async -> (String, Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", cmd]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            let combined = [output, error].filter { !$0.isEmpty }.joined(separator: "\n")
            return (combined, task.terminationStatus)
        } catch {
            return ("执行失败: \(error.localizedDescription)", -1)
        }
    }
}

// MARK: - 预设命令行

struct PresetCommandRow: View {
    let preset: CLIPreset
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: preset.icon)
                .foregroundColor(dangerColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(preset.title)
                    .font(.subheadline)
                Text(preset.command)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .font(.system(.caption, design: .monospaced))
            }

            Spacer()

            if isHovered {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var dangerColor: Color {
        switch preset.dangerLevel {
        case 0: return .green
        case 1: return .orange
        case 2: return .red
        default: return .secondary
        }
    }
}

// MARK: - 命令输出视图

struct CommandOutputView: View {
    let entry: CommandHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 命令头
            HStack {
                Text("$ \(entry.command)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
                Text("\(String(format: "%.2f", entry.duration))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))

            // 输出
            if !entry.output.isEmpty {
                Text(entry.output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(entry.exitCode == 0 ? .white : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .textSelection(.enabled)
            }

            // 退出码
            HStack {
                Text("Exit code: \(entry.exitCode)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(entry.exitCode == 0 ? .green : .red)
                Spacer()
                Text(entry.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)

            Divider()
                .background(Color.gray.opacity(0.2))
        }
    }
}