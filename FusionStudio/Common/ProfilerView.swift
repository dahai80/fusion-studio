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
    var thermalState: String = "normal"
    var thermalStateLabel: String {
        switch thermalState {
        case "critical": return I18nManager.shared.t(.prof_thermal_critical)
        case "warning": return I18nManager.shared.t(.prof_thermal_warning)
        default: return I18nManager.shared.t(.prof_thermal_normal)
        }
    }
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

        enum AlertSeverity: String { case info = "info", warning = "warning", critical = "critical"
            var localizedName: String {
                switch self {
                case .info: return I18nManager.shared.t(.prof_sev_info)
                case .warning: return I18nManager.shared.t(.prof_sev_warning)
                case .critical: return I18nManager.shared.t(.prof_sev_critical)
                }
            }
        }
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
            alerts.append(ProfilerAlert(severity: .critical, message: I18nManager.shared.tf(.prof_alert_mem_high_fmt, Int(m.memoryUsage)), timestamp: Date(), suggestion: I18nManager.shared.t(.prof_sugg_close_model)))
        }
        if m.cpuUsage > 80 {
            alerts.append(ProfilerAlert(severity: .warning, message: I18nManager.shared.tf(.prof_alert_cpu_high_fmt, Int(m.cpuUsage)), timestamp: Date(), suggestion: I18nManager.shared.t(.prof_sugg_check_bg)))
        }
        if m.thermalState == "critical" {
            alerts.append(ProfilerAlert(severity: .critical, message: I18nManager.shared.t(.prof_alert_thermal_high), timestamp: Date(), suggestion: I18nManager.shared.t(.prof_sugg_pause_infer)))
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
        case dashboard = "dashboard"
        case alerts    = "alerts"
        case optimize  = "optimize"
        case timeline  = "timeline"
        var localizedName: String {
            switch self {
            case .dashboard: return I18nManager.shared.t(.prof_tab_dashboard)
            case .alerts:    return I18nManager.shared.t(.prof_tab_alerts)
            case .optimize:  return I18nManager.shared.t(.prof_tab_optimize)
            case .timeline:  return I18nManager.shared.t(.prof_tab_timeline)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Label(I18nManager.shared.t(.prof_title), systemImage: "speedometer")
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Text(I18nManager.shared.tf(.prof_score_fmt, profiler.metrics.score))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(scoreColor)
                    Button(action: { profiler.isProfiling ? profiler.stopProfiling() : profiler.startProfiling() }) {
                        Label(profiler.isProfiling ? I18nManager.shared.t(.prof_btn_stop) : I18nManager.shared.t(.prof_btn_start), systemImage: profiler.isProfiling ? "stop.fill" : "play.fill")
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
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
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
                MetricGauge(title: I18nManager.shared.t(.prof_metric_mem), value: "\(Int(profiler.metrics.memoryUsage)) GB", icon: "memorychip", color: .green, progress: profiler.metrics.memoryUsage / 32)
                MetricGauge(title: "GPU", value: "\(Int(profiler.metrics.gpuUsage))%", icon: "square.grid.3x3.fill", color: .purple, progress: profiler.metrics.gpuUsage / 100)
                MetricGauge(title: "FPS", value: "\(Int(profiler.metrics.fps))", icon: "play.display", color: .orange, progress: profiler.metrics.fps / 120)
                MetricGauge(title: I18nManager.shared.t(.prof_metric_frame), value: "\(Int(profiler.metrics.frameTime))ms", icon: "clock", color: .pink, progress: profiler.metrics.frameTime / 50)
                MetricGauge(title: I18nManager.shared.t(.prof_metric_draw), value: "\(profiler.metrics.drawCalls)", icon: "square.grid.3x3.topleft.filled", color: .indigo, progress: min(Double(profiler.metrics.drawCalls) / 2000, 1))
                MetricGauge(title: I18nManager.shared.t(.prof_metric_mlx), value: "\(Int(profiler.metrics.mlxInferenceMs))ms", icon: "bolt", color: .yellow, progress: profiler.metrics.mlxInferenceMs / 200)
                MetricGauge(title: I18nManager.shared.t(.prof_metric_thermal), value: profiler.metrics.thermalStateLabel, icon: "thermometer.sun", color: profiler.metrics.thermalState == "normal" ? .green : .red, progress: profiler.metrics.thermalState == "normal" ? 0.2 : 0.8)
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
                    Text(I18nManager.shared.t(.prof_alerts_empty)).foregroundColor(.secondary)
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
            ToolbarItem { Button(I18nManager.shared.t(.prof_btn_clear)) { profiler.clearAlerts() }.buttonStyle(.bordered).controlSize(.small) }
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
                    Text(I18nManager.shared.t(.prof_opt_empty))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text(I18nManager.shared.t(.prof_opt_empty_hint))
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
                            Label(I18nManager.shared.tf(.prof_rec_impact_fmt, rec.impact), systemImage: "arrow.up").font(.caption)
                            Spacer()
                            Label(I18nManager.shared.tf(.prof_rec_effort_fmt, rec.effort), systemImage: "hammer").font(.caption)
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
            ToolbarItem { Button(I18nManager.shared.t(.prof_btn_refresh)) { profiler.generateRecommendations() }.buttonStyle(.bordered).controlSize(.small) }
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
                Text(I18nManager.shared.t(.prof_timeline_empty)).foregroundColor(.secondary)
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
                    Circle().fill(Color.green).frame(width: 8, height: 8); Text(I18nManager.shared.t(.prof_metric_mem)).font(.caption)
                    Spacer()
                    Text(I18nManager.shared.tf(.prof_recent_seconds_fmt, profiler.history.suffix(100).count)).font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // 数据表格
                List(profiler.history.reversed().prefix(50)) { m in
                    HStack {
                        Text(I18nManager.shared.tf(.prof_tbl_cpu_fmt, Int(m.cpuUsage))).font(.caption).frame(width: 80)
                        Text(I18nManager.shared.tf(.prof_tbl_mem_fmt, Int(m.memoryUsage))).font(.caption).frame(width: 80)
                        Text(I18nManager.shared.tf(.prof_tbl_gpu_fmt, Int(m.gpuUsage))).font(.caption).frame(width: 80)
                        Text(I18nManager.shared.tf(.prof_tbl_fps_fmt, Int(m.fps))).font(.caption).frame(width: 60)
                        Text(I18nManager.shared.tf(.prof_tbl_mlx_fmt, Int(m.mlxInferenceMs))).font(.caption).frame(width: 80)
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
            GroupBox(I18nManager.shared.t(.prof_mem_overview)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(I18nManager.shared.t(.prof_mem_inuse)).foregroundColor(.secondary)
                        Spacer()
                        Text(I18nManager.shared.tf(.prof_mem_usage_fmt, Int(profiler.metrics.memoryUsage)))
                            .font(.system(.body, design: .monospaced))
                    }
                    ProgressView(value: profiler.metrics.memoryUsage / 32)
                        .tint(profiler.metrics.memoryUsage > 28 ? .red : .blue)
                    Text(I18nManager.shared.t(.prof_mem_advice))
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox(I18nManager.shared.t(.prof_mem_dist)) {
                VStack(spacing: 6) {
                    if profiler.metrics.memoryUsage <= 0 {
                        Text(I18nManager.shared.t(.prof_mem_no_dist))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        MemRow(I18nManager.shared.t(.prof_mem_weights), "—", 0)
                        MemRow("KV Cache", "—", 0)
                        MemRow(I18nManager.shared.t(.prof_mem_app), "—", 0)
                        MemRow(I18nManager.shared.t(.prof_mem_syscache), "—", 0)
                        MemRow(I18nManager.shared.t(.prof_mem_other), "—", 0)
                    }
                }
                .padding(8)
            }

            Button(action: { showLeakCheck = true }) {
                Label(I18nManager.shared.t(.prof_btn_leak), systemImage: "stethoscope")
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
            Text(I18nManager.shared.t(.prof_leak_title)).font(.title2).bold()

            if !isRunning && results.isEmpty {
                Text(I18nManager.shared.t(.prof_leak_desc))
                    .foregroundColor(.secondary)
                Button(I18nManager.shared.t(.prof_leak_start)) { runLeakCheck() }
                    .buttonStyle(.borderedProminent)
            }

            if isRunning {
                ProgressView(value: progress)
                Text(I18nManager.shared.tf(.prof_leak_scanning_fmt, Int(progress * 100)))
                    .font(.caption).foregroundColor(.secondary)
            }

            if !results.isEmpty {
                List(results, id: \.self) { result in
                    Label(result, systemImage: result.hasPrefix("\u{2705}") ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.hasPrefix("\u{2705}") ? .green : .red)
                }
                .frame(minHeight: 100)
            }

            if !isRunning && !results.isEmpty {
                Button(I18nManager.shared.t(.prof_btn_close)) { dismiss() }.buttonStyle(.borderedProminent)
            }
        }
        .padding().frame(width: 360, height: 300)
    }

    private func runLeakCheck() {
        // 假泄漏检测结果已清理：需接通真实内存诊断后实现
        results = ["\u{26A0}\u{FE0F} " + I18nManager.shared.t(.prof_leak_no_data)]
        isRunning = false
    }
}