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
        case model    = "model"
        case kb       = "kb"
        case bench    = "bench"
        case service  = "service"
        case desk     = "desk"
        case utility  = "utility"

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

        var localizedName: String {
            switch self {
            case .model:   return I18nManager.shared.t(.cli_cat_model)
            case .kb:      return I18nManager.shared.t(.cli_cat_kb)
            case .bench:   return I18nManager.shared.t(.cli_cat_bench)
            case .service: return I18nManager.shared.t(.cli_cat_service)
            case .desk:    return I18nManager.shared.t(.cli_cat_desk)
            case .utility: return I18nManager.shared.t(.cli_cat_utility)
            }
        }
    }
}

// MARK: - 预设命令

var cliPresets: [CLIPreset] {
    [
    // 模型管理
    CLIPreset(id: "model-list", title: I18nManager.shared.t(.cli_preset_model_list_title), command: "fusion model list", description: I18nManager.shared.t(.cli_preset_model_list_desc), category: .model, icon: "list.bullet", dangerLevel: 0),
    CLIPreset(id: "model-pull", title: I18nManager.shared.t(.cli_preset_model_pull_title), command: "fusion model pull", description: I18nManager.shared.t(.cli_preset_model_pull_desc), category: .model, icon: "icloud.and.arrow.down", dangerLevel: 0),
    CLIPreset(id: "model-delete", title: I18nManager.shared.t(.cli_preset_model_delete_title), command: "fusion model delete", description: I18nManager.shared.t(.cli_preset_model_delete_desc), category: .model, icon: "trash", dangerLevel: 2),

    // 知识库
    CLIPreset(id: "kb-list", title: I18nManager.shared.t(.cli_preset_kb_list_title), command: "fusion kb list", description: I18nManager.shared.t(.cli_preset_kb_list_desc), category: .kb, icon: "list.bullet", dangerLevel: 0),
    CLIPreset(id: "kb-create", title: I18nManager.shared.t(.cli_preset_kb_create_title), command: "fusion kb create", description: I18nManager.shared.t(.cli_preset_kb_create_desc), category: .kb, icon: "plus.circle", dangerLevel: 0),
    CLIPreset(id: "kb-ingest", title: I18nManager.shared.t(.cli_preset_kb_ingest_title), command: "fusion kb ingest", description: I18nManager.shared.t(.cli_preset_kb_ingest_desc), category: .kb, icon: "doc.badge.plus", dangerLevel: 0),

    // 基准测试
    CLIPreset(id: "bench-speed", title: I18nManager.shared.t(.cli_preset_bench_speed_title), command: "fusion bench speed", description: I18nManager.shared.t(.cli_preset_bench_speed_desc), category: .bench, icon: "speedometer", dangerLevel: 0),
    CLIPreset(id: "bench-mem", title: I18nManager.shared.t(.cli_preset_bench_mem_title), command: "fusion bench mem", description: I18nManager.shared.t(.cli_preset_bench_mem_desc), category: .bench, icon: "memorychip", dangerLevel: 0),
    CLIPreset(id: "bench-ctx", title: I18nManager.shared.t(.cli_preset_bench_ctx_title), command: "fusion bench ctx", description: I18nManager.shared.t(.cli_preset_bench_ctx_desc), category: .bench, icon: "doc.text.magnifyingglass", dangerLevel: 0),

    // 服务管理
    CLIPreset(id: "svc-status", title: I18nManager.shared.t(.cli_preset_svc_status_title), command: "fusion service status", description: I18nManager.shared.t(.cli_preset_svc_status_desc), category: .service, icon: "info.circle", dangerLevel: 0),
    CLIPreset(id: "svc-start", title: I18nManager.shared.t(.cli_preset_svc_start_title), command: "fusion service start", description: I18nManager.shared.t(.cli_preset_svc_start_desc), category: .service, icon: "play.circle", dangerLevel: 0),
    CLIPreset(id: "svc-stop", title: I18nManager.shared.t(.cli_preset_svc_stop_title), command: "fusion service stop", description: I18nManager.shared.t(.cli_preset_svc_stop_desc), category: .service, icon: "stop.circle", dangerLevel: 1),

    // 桌面自动化
    CLIPreset(id: "desk-list", title: I18nManager.shared.t(.cli_preset_desk_list_title), command: "fusion desk list", description: I18nManager.shared.t(.cli_preset_desk_list_desc), category: .desk, icon: "list.bullet", dangerLevel: 0),
    CLIPreset(id: "desk-run", title: I18nManager.shared.t(.cli_preset_desk_run_title), command: "fusion desk run", description: I18nManager.shared.t(.cli_preset_desk_run_desc), category: .desk, icon: "play", dangerLevel: 1),
    ]
}

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
                Text(I18nManager.shared.t(.cli_quick_commands))
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
                            Label(category.localizedName, systemImage: category.icon)
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
                    TextField(I18nManager.shared.t(.cli_ph_input_cmd), text: $commandInput)
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
                                    Text(I18nManager.shared.t(.cli_msg_select_or_input))
                                        .foregroundColor(.secondary)
                                    Text(I18nManager.shared.t(.cli_hint_help))
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
            alert.messageText = I18nManager.shared.t(.cli_alert_confirm)
            alert.informativeText = String(format: I18nManager.shared.t(.cli_alert_will_do), preset.description)
            alert.addButton(withTitle: I18nManager.shared.t(.cli_btn_cancel))
            alert.addButton(withTitle: I18nManager.shared.t(.cli_btn_continue))
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
            // 并发全量读: 各管道阻塞至 EOF(进程退出关管道), 无 64KB 上限, 无死锁
            // async let 在并发执行器跑, 避免 waitUntilExit 后单线程串行读的死锁
            async let outData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            async let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            let output = String(data: await outData, encoding: .utf8) ?? ""
            let error = String(data: await errData, encoding: .utf8) ?? ""
            let combined = [output, error].filter { !$0.isEmpty }.joined(separator: "\n")
            return (combined, task.terminationStatus)
        } catch {
            return (String(format: I18nManager.shared.t(.cli_err_exec_failed), error.localizedDescription), -1)
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