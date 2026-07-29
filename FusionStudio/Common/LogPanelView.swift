// Callers: ModuleDetailView routing for log module.
// Affected API: LogToolbar (replacing NSColor with theme token).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import Combine

/// 日志级别
enum LogLevel: String, Codable, CaseIterable {
    case debug   = "DEBUG"
    case info    = "INFO"
    case warning = "WARN"
    case error   = "ERROR"
    case fatal   = "FATAL"

    var color: Color {
        switch self {
        case .debug:   return .gray
        case .info:    return .blue
        case .warning: return .orange
        case .error:   return .red
        case .fatal:   return .purple
        }
    }

    var icon: String {
        switch self {
        case .debug:   return "ladybug"
        case .info:    return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error:   return "xmark.octagon"
        case .fatal:   return "bolt.heart"
        }
    }
}

/// 日志条目
struct LogEntry: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let level: LogLevel
    let source: String
    let message: String
    let details: String?
    let module: String

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

/// 日志过滤器
struct LogFilter {
    var searchText: String = ""
    var levels: Set<LogLevel> = Set(LogLevel.allCases)
    var sources: Set<String> = []
    var modules: Set<String> = []
    var startDate: Date?
    var endDate: Date?
    var onlyErrors: Bool = false
}

/// 统一日志管理器
class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published var logs: [LogEntry] = []
    @Published var filter = LogFilter()
    @Published var isPaused = false
    @Published var autoScroll = true
    @Published var selectedLog: LogEntry?

    private let maxLogs = 10_000
    private let storage = UserDefaults.standard
    private let storageKey = "fusion_studio_logs"

    var filteredLogs: [LogEntry] {
        var result = logs

        if filter.onlyErrors {
            result = result.filter { $0.level == .error || $0.level == .fatal }
        }
        if !filter.searchText.isEmpty {
            result = result.filter {
                $0.message.localizedCaseInsensitiveContains(filter.searchText) ||
                $0.source.localizedCaseInsensitiveContains(filter.searchText) ||
                $0.module.localizedCaseInsensitiveContains(filter.searchText)
            }
        }
        if !filter.levels.isEmpty {
            result = result.filter { filter.levels.contains($0.level) }
        }
        if !filter.sources.isEmpty {
            result = result.filter { filter.sources.contains($0.source) }
        }
        if !filter.modules.isEmpty {
            result = result.filter { filter.modules.contains($0.module) }
        }
        if let start = filter.startDate {
            result = result.filter { $0.timestamp >= start }
        }
        if let end = filter.endDate {
            result = result.filter { $0.timestamp <= end }
        }

        return result
    }

    var availableSources: [String] {
        Array(Set(logs.map(\.source))).sorted()
    }

    var availableModules: [String] {
        Array(Set(logs.map(\.module))).sorted()
    }

    var errorCount: Int { logs.filter { $0.level == .error || $0.level == .fatal }.count }
    var warningCount: Int { logs.filter { $0.level == .warning }.count }

    init() {
        addSampleLogs()
    }

    // MARK: - 添加日志

    func addLog(level: LogLevel, source: String, module: String, message: String, details: String? = nil) {
        guard !isPaused else { return }

        let entry = LogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            level: level,
            source: source,
            message: message,
            details: details,
            module: module
        )

        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst(self.logs.count - self.maxLogs)
            }
        }
    }

    // MARK: - 便捷方法

    func info(_ source: String, _ module: String, _ message: String, details: String? = nil) {
        addLog(level: .info, source: source, module: module, message: message, details: details)
    }

    func warning(_ source: String, _ module: String, _ message: String, details: String? = nil) {
        addLog(level: .warning, source: source, module: module, message: message, details: details)
    }

    func error(_ source: String, _ module: String, _ message: String, details: String? = nil) {
        addLog(level: .error, source: source, module: module, message: message, details: details)
    }

    func debug(_ source: String, _ module: String, _ message: String, details: String? = nil) {
        addLog(level: .debug, source: source, module: module, message: message, details: details)
    }

    // MARK: - 管理

    func clearLogs() {
        logs.removeAll()
    }

    func exportLogs() -> String {
        filteredLogs.map { entry in
            "[\(entry.formattedTime)] [\(entry.level.rawValue)] [\(entry.source)] [\(entry.module)] \(entry.message)"
        }.joined(separator: "\n")
    }

    private func addSampleLogs() {
        let sampleLogs: [(LogLevel, String, String, String)] = [
            (.info, "env-daemon", "系统", "env-daemon 启动，监听: /tmp/fusion-studio.sock (权限: 0600)"),
            (.info, "env-daemon", "系统", "HealthChecker 初始化完成，准备环境检测"),
            (.info, "mlx-daemon", "系统", "MLX Daemon 管理服务启动: localhost:8001"),
            (.info, "mlx-daemon", "推理", "fusion-mlx 已启动 (PID: 12345)"),
            (.info, "mlx-daemon", "推理", "fusion-mlx 服务就绪，模型: qwen3.5-9b-4bit"),
            (.warning, "env-daemon", "环境", "PyBullet 未安装或编译失败，等待修复"),
            (.info, "FusionStudio", "IPC", "IPC 客户端连接成功"),
            (.info, "FusionStudio", "UI", "Fusion Studio v0.1.3 启动完成"),
            (.debug, "env-daemon", "网络", "Socket 连接来自: (null)"),
            (.error, "mlx-daemon", "推理", "推理请求超时 (30s)，正在重试..."),
            (.info, "mlx-daemon", "推理", "推理重试成功，延迟: 1.2s"),
            (.warning, "FusionStudio", "存储", "工作区目录不存在，正在创建: ~/FusionStudio/workspace"),
            (.info, "FusionStudio", "存储", "工作区目录创建成功"),
            (.info, "env-daemon", "环境", "环境健康检查完成: 全部通过"),
            (.debug, "mlx-daemon", "硬件", "内存使用: 12.5GB/32GB (39.1%)"),
            (.debug, "mlx-daemon", "硬件", "GPU 占用: 23%"),
            (.info, "FusionStudio", "任务", "任务队列初始化完成"),
            (.info, "FusionStudio", "UI", "侧边栏加载完成，10 个模块就绪"),
        ]

        for (level, source, module, message) in sampleLogs {
            let entry = LogEntry(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-Double(sampleLogs.firstIndex(where: { $0.2 == module && $0.1 == source && $0.3 == message }) ?? 0) * 2),
                level: level,
                source: source,
                message: message,
                details: nil,
                module: module
            )
            logs.append(entry)
        }
    }
}

// MARK: - 日志面板主视图

struct LogPanelView: View {
    @StateObject private var logManager = LogManager.shared
    @State private var selectedTab: LogTab = .live

    enum LogTab: String, CaseIterable {
        case live   = "实时日志"
        case filter = "筛选"
        case stats  = "统计"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            LogToolbar()

            Divider()

            // 标签切换
            Picker("", selection: $selectedTab) {
                ForEach(LogTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 4)

            switch selectedTab {
            case .live:
                LogListView()
            case .filter:
                LogFilterView()
            case .stats:
                LogStatsView()
            }
        }
    }
}

// MARK: - 工具栏

struct LogToolbar: View {
    @StateObject private var logManager = LogManager.shared
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            // 状态指示
            HStack(spacing: 4) {
                Circle()
                    .fill(logManager.isPaused ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(logManager.isPaused ? "已暂停" : "接收中")
                    .font(.caption)
            }

            Text("\(logManager.filteredLogs.count) 条")
                .font(.caption)
                .foregroundColor(.secondary)

            if logManager.errorCount > 0 {
                Text("\(logManager.errorCount) 错误")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            if logManager.warningCount > 0 {
                Text("\(logManager.warningCount) 警告")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()

            HStack(spacing: 4) {
                Toggle("自动滚动", isOn: $logManager.autoScroll)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)

                Button(action: { logManager.isPaused.toggle() }) {
                    Image(systemName: logManager.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(logManager.isPaused ? "恢复" : "暂停")

                Button(action: { logManager.clearLogs() }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("清除日志")

                Button(action: exportLogs) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("导出日志")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.surfaceSecondary)
    }

    private func exportLogs() {
        let content = logManager.exportLogs()

        let savePanel = NSSavePanel()
        savePanel.title = "导出日志"
        savePanel.nameFieldStringValue = "fusion-studio-logs.txt"
        savePanel.allowedContentTypes = [.plainText]

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - 日志列表

struct LogListView: View {
    @StateObject private var logManager = LogManager.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(logManager.filteredLogs) { entry in
                        LogRowView(entry: entry)
                            .id(entry.id)
                            .onTapGesture {
                                logManager.selectedLog = entry
                            }
                    }
                }
            }
            .background(Color.black.opacity(0.03))
            .onChange(of: logManager.filteredLogs.count) { oldValue, newValue in
                if logManager.autoScroll, let last = logManager.filteredLogs.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .sheet(item: $logManager.selectedLog) { entry in
            LogDetailView(entry: entry)
        }
    }
}

// MARK: - 日志行

struct LogRowView: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 8) {
            // 时间
            Text(entry.formattedTime)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .trailing)

            // 级别
            Text(entry.level.rawValue)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(entry.level.color)
                .cornerRadius(3)
                .frame(width: 44)

            // 来源
            Text(entry.source)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            // 模块
            Text(entry.module)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
                .lineLimit(1)

            // 消息
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(entry.level == .error ? Color.red.opacity(0.05) : (entry.level == .warning ? Color.orange.opacity(0.03) : Color.clear))
        .contentShape(Rectangle())
    }
}

// MARK: - 日志详情

struct LogDetailView: View {
    let entry: LogEntry
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: entry.level.icon)
                    .foregroundColor(entry.level.color)
                    .font(.title2)
                Text("日志详情")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }

            Divider()

            GroupBox("基本信息") {
                VStack(alignment: .leading, spacing: 6) {
                    DetailRow("时间", entry.formattedTime)
                    DetailRow("级别", entry.level.rawValue)
                    DetailRow("来源", entry.source)
                    DetailRow("模块", entry.module)
                }
                .padding(8)
            }

            GroupBox("消息") {
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
            }

            if let details = entry.details {
                GroupBox("详细信息") {
                    Text(details)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

// MARK: - 筛选面板

struct LogFilterView: View {
    @StateObject private var logManager = LogManager.shared

    var body: some View {
        Form {
            Section("关键字") {
                TextField("搜索日志...", text: $logManager.filter.searchText)
                    .textFieldStyle(.roundedBorder)
            }

            Section("日志级别") {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Toggle(isOn: Binding(
                        get: { logManager.filter.levels.contains(level) },
                        set: { enabled in
                            if enabled {
                                logManager.filter.levels.insert(level)
                            } else {
                                logManager.filter.levels.remove(level)
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: level.icon)
                                .foregroundColor(level.color)
                            Text(level.rawValue)
                        }
                    }
                }
                Toggle("仅显示错误/严重", isOn: $logManager.filter.onlyErrors)
            }

            Section("来源") {
                ForEach(logManager.availableSources, id: \.self) { source in
                    Toggle(source, isOn: Binding(
                        get: { logManager.filter.sources.isEmpty || logManager.filter.sources.contains(source) },
                        set: { enabled in
                            if enabled {
                                logManager.filter.sources.insert(source)
                            } else {
                                logManager.filter.sources.remove(source)
                            }
                        }
                    ))
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - 统计面板

struct LogStatsView: View {
    @StateObject private var logManager = LogManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 概览卡片
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                    StatCard(title: "总日志", value: "\(logManager.logs.count)", icon: "doc.text", color: .blue)
                    StatCard(title: "错误", value: "\(logManager.errorCount)", icon: "xmark.octagon", color: .red)
                    StatCard(title: "警告", value: "\(logManager.warningCount)", icon: "exclamationmark.triangle", color: .orange)
                    StatCard(title: "信息", value: "\(logManager.logs.filter { $0.level == .info }.count)", icon: "info.circle", color: .blue)
                    StatCard(title: "调试", value: "\(logManager.logs.filter { $0.level == .debug }.count)", icon: "ladybug", color: .gray)
                }
                .padding()

                // 来源分布
                GroupBox("日志来源分布") {
                    ForEach(logManager.availableSources, id: \.self) { source in
                        let count = logManager.logs.filter { $0.source == source }.count
                        let total = Double(max(logManager.logs.count, 1))
                        HStack {
                            Text(source)
                                .frame(width: 100, alignment: .leading)
                            ProgressView(value: Double(count) / total)
                                .tint(.blue)
                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 40)
                        }
                        .padding(.vertical, 2)
                    }
                    .padding(8)
                }
                .padding(.horizontal)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.05))
        .cornerRadius(10)
    }
}