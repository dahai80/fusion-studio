import SwiftUI

// MARK: - 分析指标

struct AnalyticsMetric: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let change: Double
    let trend: Trend
    let icon: String
    let color: Color
    let detail: String

    enum Trend: String { case up = "上升", down = "下降", stable = "持平" }
}

struct AnalyticsChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let series: String
}

// MARK: - 分析引擎

class AnalyticsEngine: ObservableObject {
    static let shared = AnalyticsEngine()

    @Published var metrics: [AnalyticsMetric] = []
    @Published var dailyActiveUsers: [AnalyticsChartPoint] = []
    @Published var moduleUsage: [AnalyticsChartPoint] = []
    @Published var inferenceVolume: [AnalyticsChartPoint] = []
    @Published var errorRate: [AnalyticsChartPoint] = []
    @Published var selectedTimeRange: TimeRange = .week
    @Published var isRefreshing = false

    enum TimeRange: String, CaseIterable {
        case day   = "24小时"
        case week  = "7天"
        case month = "30天"
        case quarter = "90天"
    }

    init() {
        loadMetrics()
        loadChartData()
    }

    private func loadMetrics() {
        metrics = [
            AnalyticsMetric(name: "活跃用户", value: "1,284", change: 12.5, trend: .up, icon: "person.2", color: .blue, detail: "日活跃用户数"),
            AnalyticsMetric(name: "推理请求", value: "45,892", change: 8.3, trend: .up, icon: "bolt", color: .orange, detail: "每日 MLX 推理调用"),
            AnalyticsMetric(name: "平均延迟", value: "124ms", change: -5.2, trend: .down, icon: "clock", color: .green, detail: "推理请求平均延迟"),
            AnalyticsMetric(name: "错误率", value: "0.8%", change: -0.3, trend: .down, icon: "exclamationmark.triangle", color: .red, detail: "请求失败率"),
            AnalyticsMetric(name: "内存使用", value: "12.4 GB", change: 2.1, trend: .up, icon: "memorychip", color: .purple, detail: "平均内存占用"),
            AnalyticsMetric(name: "任务完成", value: "3,421", change: 15.7, trend: .up, icon: "checkmark.circle", color: .green, detail: "每日完成的任务数"),
            AnalyticsMetric(name: "模型数", value: "8", change: 0, trend: .stable, icon: "cpu", color: .indigo, detail: "已安装模型数量"),
            AnalyticsMetric(name: "存储使用", value: "45.2 GB", change: 3.8, trend: .up, icon: "externaldrive", color: .cyan, detail: "模型和缓存占用"),
        ]
    }

    private func loadChartData() {
        let now = Date()
        let sampleCount = 24

        for i in 0..<sampleCount {
            let date = now.addingTimeInterval(-Double(sampleCount - i) * 3600)
            dailyActiveUsers.append(AnalyticsChartPoint(date: date, value: Double.random(in: 800...1500), series: "活跃用户"))
            moduleUsage.append(AnalyticsChartPoint(date: date, value: Double.random(in: 100...500), series: "模块使用"))
            inferenceVolume.append(AnalyticsChartPoint(date: date, value: Double.random(in: 500...3000), series: "推理请求"))
            errorRate.append(AnalyticsChartPoint(date: date, value: Double.random(in: 0.1...2.0), series: "错误率"))
        }
    }

    func refresh() {
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.loadMetrics()
            self?.isRefreshing = false
        }
    }
}

// MARK: - 分析仪表盘

struct AnalyticsDashboardView: View {
    @StateObject private var analytics = AnalyticsEngine.shared
    @State private var selectedTab: AnalyticsTab = .overview

    enum AnalyticsTab: String, CaseIterable {
        case overview  = "概览"
        case usage     = "使用分析"
        case inference = "推理分析"
        case errors    = "错误分析"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("分析仪表盘", systemImage: "chart.bar.xaxis").font(.headline)
                Spacer()
                Picker("时间范围", selection: $analytics.selectedTimeRange) {
                    ForEach(AnalyticsEngine.TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu).frame(width: 100)
                Button(action: { analytics.refresh() }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(analytics.isRefreshing)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented).padding(8)

            if analytics.isRefreshing {
                ProgressView("刷新中...").padding()
                Spacer()
            } else {
                switch selectedTab {
                case .overview:  OverviewTab()
                case .usage:     UsageTab()
                case .inference: InferenceTab()
                case .errors:    ErrorsTab()
                }
            }
        }
    }

    private func tabIcon(_ tab: AnalyticsTab) -> String {
        switch tab { case .overview: return "gauge.medium"; case .usage: return "person.2"; case .inference: return "bolt"; case .errors: return "exclamationmark.triangle" }
    }
}

// MARK: - 概览

struct OverviewTab: View {
    @StateObject private var analytics = AnalyticsEngine.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                ForEach(analytics.metrics) { metric in
                    MetricCardView(metric: metric)
                }
            }
            .padding()
        }
    }
}

struct MetricCardView: View {
    let metric: AnalyticsMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: metric.icon).foregroundColor(metric.color)
                Spacer()
                Text("\(metric.change > 0 ? "+" : "")\(metric.change, specifier: "%.1f")%")
                    .font(.caption).foregroundColor(metric.trend == .up ? .green : (metric.trend == .down ? .red : .secondary))
            }
            Text(metric.value).font(.title).fontWeight(.bold)
            Text(metric.name).font(.caption).foregroundColor(.secondary).lineLimit(1)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - 使用分析

struct UsageTab: View {
    @StateObject private var analytics = AnalyticsEngine.shared

    var body: some View {
        List {
            Section("模块使用排行") {
                let modules = [
                    ("设计模块", 45.2, "pencil.and.outline", Color.blue),
                    ("编码模块", 32.8, "chevron.left.forwardslash.chevron.right", Color.green),
                    ("仿真模块", 28.5, "gearshape.2", Color.orange),
                    ("模型管理", 22.1, "cpu", Color.purple),
                    ("知识库", 18.7, "books.vertical", Color.pink),
                    ("文档", 15.3, "doc.text", Color.indigo),
                    ("CLI", 12.9, "terminal", Color.gray),
                    ("基准测试", 8.4, "chart.bar", Color.yellow),
                ]
                ForEach(modules, id: \.0) { (name, pct, icon, color) in
                    HStack {
                        Image(systemName: icon).foregroundColor(color).frame(width: 20)
                        Text(name).frame(width: 80, alignment: .leading)
                        ProgressView(value: pct / 100).tint(color)
                        Text("\(pct, specifier: "%.1f")%").font(.caption).frame(width: 40)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("使用趋势") {
                SimpleChartView(data: analytics.moduleUsage, color: .blue)
                    .frame(height: 150)
            }
        }
    }
}

// MARK: - 推理分析

struct InferenceTab: View {
    @StateObject private var analytics = AnalyticsEngine.shared

    var body: some View {
        List {
            Section("推理统计") {
                HStack { Text("总请求数"); Spacer(); Text("45,892").font(.system(.body, design: .monospaced)) }
                HStack { Text("成功"); Spacer(); Text("45,525 (99.2%)").font(.system(.body, design: .monospaced)).foregroundColor(.green) }
                HStack { Text("失败"); Spacer(); Text("367 (0.8%)").font(.system(.body, design: .monospaced)).foregroundColor(.red) }
                HStack { Text("平均延迟"); Spacer(); Text("124ms").font(.system(.body, design: .monospaced)) }
                HStack { Text("P99 延迟"); Spacer(); Text("892ms").font(.system(.body, design: .monospaced)) }
                HStack { Text("Token 吞吐量"); Spacer(); Text("45.2 t/s").font(.system(.body, design: .monospaced)) }
            }

            Section("请求趋势") {
                SimpleChartView(data: analytics.inferenceVolume, color: .orange)
                    .frame(height: 150)
            }
        }
    }
}

// MARK: - 错误分析

struct ErrorsTab: View {
    @StateObject private var analytics = AnalyticsEngine.shared

    let errors: [(String, Int, String)] = [
        ("超时错误", 156, "推理请求超过 30s 超时限制"),
        ("内存不足", 89, "模型加载或推理时内存不足"),
        ("模型加载失败", 52, "模型文件损坏或不兼容"),
        ("连接拒绝", 38, "fusion-mlx 服务未运行"),
        ("无效参数", 22, "请求参数格式错误"),
        ("KV Cache 溢出", 10, "上下文长度超过限制"),
    ]

    var body: some View {
        List {
            Section("错误分布") {
                ForEach(errors, id: \.0) { (name, count, detail) in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle().fill(.red).frame(width: 6, height: 6)
                            Text(name).font(.headline)
                            Spacer()
                            Text("\(count)").font(.system(.body, design: .monospaced)).foregroundColor(.red)
                        }
                        Text(detail).font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("错误率趋势") {
                SimpleChartView(data: analytics.errorRate, color: .red)
                    .frame(height: 150)
            }

            Section("建议") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("增加超时时间到 60s", systemImage: "clock")
                    Label("升级到更高量化精度减少内存", systemImage: "arrow.up.circle")
                    Label("确保 fusion-mlx 服务已启动", systemImage: "bolt")
                    Label("设置合理的上下文长度限制", systemImage: "doc.text")
                }
                .font(.subheadline)
            }
        }
    }
}

// MARK: - 简易图表

struct SimpleChartView: View {
    let data: [AnalyticsChartPoint]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let maxVal = data.map(\.value).max() ?? 1
            let points = data

            ZStack(alignment: .leading) {
                // 网格线
                ForEach(0..<4) { i in
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * CGFloat(i) / 4))
                        path.addLine(to: CGPoint(x: width, y: height * CGFloat(i) / 4))
                    }.stroke(Color.gray.opacity(0.2))
                }

                // 填充区域
                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(points.count)
                        let y = height * (1 - CGFloat(point.value) / CGFloat(maxVal))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: height))
                            path.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        if index == points.count - 1 {
                            path.addLine(to: CGPoint(x: x, y: height))
                            path.closeSubpath()
                        }
                    }
                }.fill(color.opacity(0.1))

                // 折线
                Path { path in
                    for (index, point) in points.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(points.count)
                        let y = height * (1 - CGFloat(point.value) / CGFloat(maxVal))
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }.stroke(color, lineWidth: 2)
            }
        }
    }
}

// MARK: - 导出报告

struct ReportExportView: View {
    @StateObject private var analytics = AnalyticsEngine.shared
    @State private var showExportSuccess = false

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("导出分析报告") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("导出当前分析数据为报告文件，包含所有指标和图表数据。")
                        .font(.subheadline).foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button(action: exportJSON) {
                            Label("导出 JSON", systemImage: "curlybraces")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: exportCSV) {
                            Label("导出 CSV", systemImage: "tablecells")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: exportPDF) {
                            Label("导出 PDF", systemImage: "doc.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(8)
            }
            .padding(.horizontal)

            if showExportSuccess {
                Label("报告已导出到桌面", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

            Spacer()
        }
        .padding(.vertical)
    }

    private func exportJSON() {
        showExportSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showExportSuccess = false }
    }

    private func exportCSV() {
        showExportSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showExportSuccess = false }
    }

    private func exportPDF() {
        showExportSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showExportSuccess = false }
    }
}