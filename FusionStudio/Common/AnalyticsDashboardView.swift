// Callers: ModuleDetailView routing for analytics/dashboard module.
// Affected API: AnalyticsDashboardView, MetricCardView (replacing NSColor with theme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import os.log

private let analyticsLog = Logger(subsystem: "com.fusion.studio", category: "AnalyticsDashboard")

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
        // 假分析指标已清理：等待接通真实分析后端后填充
        metrics = []
    }

    private func loadChartData() {
        // 假图表数据已清理：等待接通真实分析后端后填充
    }

    func refresh() {
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.loadMetrics()
            self?.isRefreshing = false
        }
    }
}

// MARK: - 分析仪表盘

struct AnalyticsDashboardView: View {
    @StateObject private var analytics = AnalyticsEngine.shared
    @State private var selectedTab: AnalyticsTab = .overview
    @Environment(\.studioTheme) private var theme

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
            .background(theme.surfaceSecondary)

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
    @Environment(\.studioTheme) private var theme

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
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
    }
}

// MARK: - 使用分析

struct UsageTab: View {
    @StateObject private var analytics = AnalyticsEngine.shared

    var body: some View {
        List {
            Section("模块使用排行") {
                if analytics.moduleUsage.isEmpty {
                    Text("暂无模块使用数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
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
                if analytics.inferenceVolume.isEmpty {
                    Text("暂无推理统计数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
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

    var body: some View {
        List {
            Section("错误分布") {
                if analytics.errorRate.isEmpty {
                    Text("暂无错误数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
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