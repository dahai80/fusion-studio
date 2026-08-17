// Callers: ModuleDetailView routing.
// Affected API: ProfilerView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

// MARK: - 性能指标

struct PerfMetrics: Identifiable {
    var cpuUsage: Double = 0
    var memoryUsage: Double = 0
    var gpuUsage: Double = 0
    var fps: Double = 0
    var frameTime: Double = 0
    var drawCalls: Int = 0
    var triangleCount: Int = 0
    var mlxInferenceMs: Double = 0
    var diskIO: Double = 0
    var networkIO: Double = 0
    var thermalState: String = "正常"
    var powerUsage: Double = 0
    var id: UUID = UUID()

    var score: Int {
        let cpu = max(0, 100 - Int(cpuUsage))
        let mem = max(0, 100 - Int(memoryUsage / 32 * 100))
        let gpu = max(0, 100 - Int(gpuUsage))
        let f = min(100, Int(fps / 60 * 100))
        return (cpu + mem + gpu + f) / 4
    }
}

// MARK: - Profiler 引擎

class PerformanceProfiler: ObservableObject {
    static let shared = PerformanceProfiler()

    @Published var isProfiling = false
    @Published var metrics = PerfMetrics()
    @Published var history: [PerfMetrics] = []
    @Published var alerts: [ProfilerAlert] = []
    @Published var recommendations: [ProfilerRecommendation] = []

    private var timer: Timer?
    private let maxHistory = 300

    struct ProfilerAlert: Identifiable {
        let id = UUID()
        let severity: AlertSeverity
        let message: String
        let timestamp: Date
        let suggestion: String

        enum AlertSeverity: String { case info = "提示", warning = "警告", critical = "严重" }
    }

    struct ProfilerRecommendation: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let impact: String
        let effort: String
        let category: String
        let action: () -> Void
    }

    func startProfiling() {
        isProfiling = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sampleMetrics()
        }
    }

    func stopProfiling() {
        isProfiling = false
        timer?.invalidate()
        timer = nil
    }

    private func sampleMetrics() {
        // 假采样数据已清理：等待接通真实性能 IPC 后在此填充
        // 暂不生成随机指标，避免误导
    }

    private func analyzeMetrics(_ m: PerfMetrics) {
        if m.memoryUsage > 28 {
            alerts.append(ProfilerAlert(severity: .critical, message: "内存使用过高: \(Int(m.memoryUsage))GB", timestamp: Date(), suggestion: "关闭未使用的模型或降低量化精度"))
        }
        if m.cpuUsage > 80 {
            alerts.append(ProfilerAlert(severity: .warning, message: "CPU 负载过高: \(Int(m.cpuUsage))%", timestamp: Date(), suggestion: "检查后台任务或减少并行推理"))
        }
        if m.thermalState == "严重" {
            alerts.append(ProfilerAlert(severity: .critical, message: "设备温度过高", timestamp: Date(), suggestion: "暂停推理任务，让设备降温"))
        }
        if alerts.count > 50 { alerts.removeFirst(alerts.count - 50) }
    }

    func clearAlerts() { alerts.removeAll() }
    func clearHistory() { history.removeAll() }

    func generateRecommendations() {
        // 假优化建议已清理：等待接通真实性能分析后基于实际指标生成
        recommendations = []
    }
}

// MARK: - Profiler 面板

struct ProfilerView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var profiler = PerformanceProfiler.shared
    @State private var selectedTab: ProfilerTab = .dashboard

    enum ProfilerTab: String, CaseIterable {
        case dashboard = "仪表盘"
        case alerts    = "告警"
        case optimize  = "优化建议"
        case timeline  = "时间线"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Label("性能 Profiler", systemImage: "speedometer")
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Text("评分: \(profiler.metrics.score)/100")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(scoreColor)
                    Button(action: { profiler.isProfiling ? profiler.stopProfiling() : profiler.startProfiling() }) {
                        Label(profiler.isProfiling ? "停止" : "开始", systemImage: profiler.isProfiling ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(profiler.isProfiling ? .red : .green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(ProfilerTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            switch selectedTab {
            case .dashboard: ProfilerDashboard()
            case .alerts:    ProfilerAlertsView()
            case .optimize:  ProfilerOptimizeView()
            case .timeline:  ProfilerTimelineView()
            }
        }
        .onAppear { profiler.generateRecommendations() }
    }

    private var scoreColor: Color {
        let s = profiler.metrics.score
        if s >= 80 { return .green }
        if s >= 50 { return .orange }
        return .red
    }

    private func tabIcon(_ tab: ProfilerTab) -> String {
        switch tab {
        case .dashboard: return "gauge.open.with.lines.needle.33percent"
        case .alerts:    return "exclamationmark.triangle"
        case .optimize:  return "wand.and.stars"
        case .timeline:  return "chart.xyaxis.line"
        }
    }
}

// MARK: - 仪表盘

struct ProfilerDashboard: View {
    @StateObject private var profiler = PerformanceProfiler.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                MetricGauge(title: "CPU", value: "\(Int(profiler.metrics.cpuUsage))%", icon: "cpu", color: .blue, progress: profiler.metrics.cpuUsage / 100)
                MetricGauge(title: "内存", value: "\(Int(profiler.metrics.memoryUsage)) GB", icon: "memorychip", color: .green, progress: profiler.metrics.memoryUsage / 32)
                MetricGauge(title: "GPU", value: "\(Int(profiler.metrics.gpuUsage))%", icon: "square.grid.3x3.fill", color: .purple, progress: profiler.metrics.gpuUsage / 100)
                MetricGauge(title: "FPS", value: "\(Int(profiler.metrics.fps))", icon: "play.display", color: .orange, progress: profiler.metrics.fps / 120)
                MetricGauge(title: "帧时间", value: "\(Int(profiler.metrics.frameTime))ms", icon: "clock", color: .pink, progress: profiler.metrics.frameTime / 50)
                MetricGauge(title: "绘制调用", value: "\(profiler.metrics.drawCalls)", icon: "square.grid.3x3.topleft.filled", color: .indigo, progress: min(Double(profiler.metrics.drawCalls) / 2000, 1))
                MetricGauge(title: "MLX 推理", value: "\(Int(profiler.metrics.mlxInferenceMs))ms", icon: "bolt", color: .yellow, progress: profiler.metrics.mlxInferenceMs / 200)
                MetricGauge(title: "热状态", value: profiler.metrics.thermalState, icon: "thermometer.sun", color: profiler.metrics.thermalState == "正常" ? .green : .red, progress: profiler.metrics.thermalState == "正常" ? 0.2 : 0.8)
            }
            .padding()
        }
    }
}

struct MetricGauge: View {
    @Environment(\.studioTheme) private var theme
    let title: String; let value: String; let icon: String; let color: Color; let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
            ProgressView(value: min(max(progress, 0), 1)).tint(color)
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
    }
}

// MARK: - 告警

struct ProfilerAlertsView: View {
    @StateObject private var profiler = PerformanceProfiler.shared

    var body: some View {
        VStack {
            if profiler.alerts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.circle").font(.system(size: 40)).foregroundColor(.green)
                    Text("性能良好，无告警").foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(profiler.alerts.reversed()) { alert in
                        HStack(spacing: 10) {
                            Image(systemName: alertIcon(alert.severity)).foregroundColor(alertColor(alert.severity))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.message).font(.subheadline)
                                Text(alert.suggestion).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(alert.timestamp, style: .time).font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem { Button("清空") { profiler.clearAlerts() }.buttonStyle(.bordered).controlSize(.small) }
        }
    }

    private func alertIcon(_ s: PerformanceProfiler.ProfilerAlert.AlertSeverity) -> String {
        switch s { case .info: return "info.circle"; case .warning: return "exclamationmark.triangle"; case .critical: return "xmark.octagon" }
    }
    private func alertColor(_ s: PerformanceProfiler.ProfilerAlert.AlertSeverity) -> Color {
        switch s { case .info: return .blue; case .warning: return .orange; case .critical: return .red }
    }
}

// MARK: - 优化建议

struct ProfilerOptimizeView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var profiler = PerformanceProfiler.shared

    var body: some View {
        ScrollView {
            if profiler.recommendations.isEmpty {
                VStack(spacing: 10) {
                    Spacer().frame(height: 40)
                    Image(systemName: "lightbulb.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("暂无优化建议")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("接通真实性能分析后将基于实际指标生成")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                ForEach(profiler.recommendations) { rec in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb").foregroundColor(.yellow)
                            Text(rec.title).font(.headline)
                            Spacer()
                            Text(rec.category).font(.caption2).padding(.horizontal, 4).background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                        }
                        Text(rec.description).font(.subheadline).foregroundColor(.secondary)
                        HStack {
                            Label("影响: \(rec.impact)", systemImage: "arrow.up").font(.caption)
                            Spacer()
                            Label("工作量: \(rec.effort)", systemImage: "hammer").font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(theme.surfaceSecondary)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem { Button("刷新建议") { profiler.generateRecommendations() }.buttonStyle(.bordered).controlSize(.small) }
        }
    }
}

// MARK: - 时间线

struct ProfilerTimelineView: View {
    @StateObject private var profiler = PerformanceProfiler.shared

    var body: some View {
        if profiler.history.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "chart.xyaxis.line").font(.system(size: 40)).foregroundColor(.secondary)
                Text("开始 Profiling 以查看时间线").foregroundColor(.secondary)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                // 简易图表
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let data = profiler.history.suffix(100)
                    let maxVal = data.map(\.cpuUsage).max() ?? 100

                    ZStack(alignment: .leading) {
                        // 网格线
                        ForEach(0..<4) { i in
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: height * CGFloat(i) / 4))
                                path.addLine(to: CGPoint(x: width, y: height * CGFloat(i) / 4))
                            }.stroke(Color.gray.opacity(0.2))
                        }

                        // CPU 曲线
                        Path { path in
                            for (index, m) in data.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(data.count)
                                let y = height * (1 - CGFloat(m.cpuUsage) / CGFloat(maxVal))
                                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }.stroke(Color.blue, lineWidth: 2)

                        // 内存曲线
                        Path { path in
                            for (index, m) in data.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(data.count)
                                let y = height * (1 - CGFloat(m.memoryUsage) / 32)
                                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }.stroke(Color.green, lineWidth: 2)
                    }
                }
                .frame(height: 200)
                .padding()

                HStack(spacing: 16) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8); Text("CPU").font(.caption)
                    Circle().fill(Color.green).frame(width: 8, height: 8); Text("内存").font(.caption)
                    Spacer()
                    Text("最近 \(profiler.history.suffix(100).count) 秒").font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // 数据表格
                List(profiler.history.reversed().prefix(50)) { m in
                    HStack {
                        Text("CPU: \(Int(m.cpuUsage))%").font(.caption).frame(width: 80)
                        Text("MEM: \(Int(m.memoryUsage))GB").font(.caption).frame(width: 80)
                        Text("GPU: \(Int(m.gpuUsage))%").font(.caption).frame(width: 80)
                        Text("FPS: \(Int(m.fps))").font(.caption).frame(width: 60)
                        Text("MLX: \(Int(m.mlxInferenceMs))ms").font(.caption).frame(width: 80)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - 内存分析器

struct MemoryAnalyzerView: View {
    @StateObject private var profiler = PerformanceProfiler.shared
    @State private var showLeakCheck = false

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("内存使用概览") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("使用中").foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(profiler.metrics.memoryUsage)) GB / 32 GB")
                            .font(.system(.body, design: .monospaced))
                    }
                    ProgressView(value: profiler.metrics.memoryUsage / 32)
                        .tint(profiler.metrics.memoryUsage > 28 ? .red : .blue)
                    Text("建议保持在 28GB 以下以保证推理性能")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox("内存分布") {
                VStack(spacing: 6) {
                    if profiler.metrics.memoryUsage <= 0 {
                        Text("暂无内存分布数据")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        MemRow("模型权重", "—", 0)
                        MemRow("KV Cache", "—", 0)
                        MemRow("应用", "—", 0)
                        MemRow("系统缓存", "—", 0)
                        MemRow("其他", "—", 0)
                    }
                }
                .padding(8)
            }

            Button(action: { showLeakCheck = true }) {
                Label("运行内存泄漏检测", systemImage: "stethoscope")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .sheet(isPresented: $showLeakCheck) {
            LeakCheckView()
        }
    }
}

struct MemRow: View {
    let label: String; let value: String; let fraction: Double
    init(_ label: String, _ value: String, _ fraction: Double) { self.label = label; self.value = value; self.fraction = fraction }
    var body: some View {
        HStack {
            Text(label).font(.subheadline).frame(width: 80, alignment: .leading)
            ProgressView(value: fraction).tint(.blue).frame(width: 100)
            Text(value).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
        }
    }
}

struct LeakCheckView: View {
    @Environment(\.dismiss) var dismiss
    @State private var progress: Double = 0
    @State private var results: [String] = []
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 16) {
            Text("内存泄漏检测").font(.title2).bold()

            if !isRunning && results.isEmpty {
                Text("检测将扫描应用中的循环引用和未释放对象")
                    .foregroundColor(.secondary)
                Button("开始检测") { runLeakCheck() }
                    .buttonStyle(.borderedProminent)
            }

            if isRunning {
                ProgressView(value: progress)
                Text("扫描中... \(Int(progress * 100))%")
                    .font(.caption).foregroundColor(.secondary)
            }

            if !results.isEmpty {
                List(results, id: \.self) { result in
                    Label(result, systemImage: result.hasPrefix("✅") ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.hasPrefix("✅") ? .green : .red)
                }
                .frame(minHeight: 100)
            }

            if !isRunning && !results.isEmpty {
                Button("关闭") { dismiss() }.buttonStyle(.borderedProminent)
            }
        }
        .padding().frame(width: 360, height: 300)
    }

    private func runLeakCheck() {
        // 假泄漏检测结果已清理：需接通真实内存诊断后实现
        results = ["⚠️ 内存泄漏检测尚未接入真实诊断，暂无数据"]
        isRunning = false
    }
}