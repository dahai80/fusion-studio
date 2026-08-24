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

    enum Trend: String {
        case up = "up"
        case down = "down"
        case stable = "stable"

        var localizedName: String {
            switch self {
            case .up: return I18nManager.shared.t(.anl_trend_up)
            case .down: return I18nManager.shared.t(.anl_trend_down)
            case .stable: return I18nManager.shared.t(.anl_trend_stable)
            }
        }
    }
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
        case day
        case week
        case month
        case quarter

        var localizedName: String {
            switch self {
            case .day:     return I18nManager.shared.t(.anl_range_day)
            case .week:    return I18nManager.shared.t(.anl_range_week)
            case .month:   return I18nManager.shared.t(.anl_range_month)
            case .quarter: return I18nManager.shared.t(.anl_range_quarter)
            }
        }
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
        case overview
        case usage
        case inference
        case errors

        var localizedName: String {
            switch self {
            case .overview:  return I18nManager.shared.t(.anl_tab_overview)
            case .usage:     return I18nManager.shared.t(.anl_tab_usage)
            case .inference: return I18nManager.shared.t(.anl_tab_inference)
            case .errors:    return I18nManager.shared.t(.anl_tab_errors)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(I18nManager.shared.t(.anl_title), systemImage: "chart.bar.xaxis").font(.headline)
                Spacer()
                Picker(I18nManager.shared.t(.anl_pick_time_range), selection: $analytics.selectedTimeRange) {
                    ForEach(AnalyticsEngine.TimeRange.allCases, id: \.self) { range in
                        Text(range.localizedName).tag(range)
                    }
                }
                .pickerStyle(.menu).frame(width: 100)
                Button(action: { analytics.refresh() }) {
                    Label(I18nManager.shared.t(.anl_btn_refresh), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(analytics.isRefreshing)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented).padding(8)

            if analytics.isRefreshing {
                ProgressView(I18nManager.shared.t(.anl_refreshing)).padding()
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
            Section(I18nManager.shared.t(.anl_sec_module_ranking)) {
                if analytics.moduleUsage.isEmpty {
                    Text(I18nManager.shared.t(.anl_empty_module_usage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
            }

            Section(I18nManager.shared.t(.anl_sec_usage_trend)) {
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
            Section(I18nManager.shared.t(.anl_sec_inference_stats)) {
                if analytics.inferenceVolume.isEmpty {
                    Text(I18nManager.shared.t(.anl_empty_inference_stats))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
            }

            Section(I18nManager.shared.t(.anl_sec_request_trend)) {
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
            Section(I18nManager.shared.t(.anl_sec_error_dist)) {
                if analytics.errorRate.isEmpty {
                    Text(I18nManager.shared.t(.anl_empty_error_data))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
            }

            Section(I18nManager.shared.t(.anl_sec_error_rate_trend)) {
                SimpleChartView(data: analytics.errorRate, color: .red)
                    .frame(height: 150)
            }

            Section(I18nManager.shared.t(.anl_sec_suggestions)) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(I18nManager.shared.t(.anl_suggest_timeout), systemImage: "clock")
                    Label(I18nManager.shared.t(.anl_suggest_quant), systemImage: "arrow.up.circle")
                    Label(I18nManager.shared.t(.anl_suggest_mlx_service), systemImage: "bolt")
                    Label(I18nManager.shared.t(.anl_suggest_context_len), systemImage: "doc.text")
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
            GroupBox(I18nManager.shared.t(.anl_export_title)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(I18nManager.shared.t(.anl_export_desc))
                        .font(.subheadline).foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        Button(action: exportJSON) {
                            Label(I18nManager.shared.t(.anl_export_json), systemImage: "curlybraces")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: exportCSV) {
                            Label(I18nManager.shared.t(.anl_export_csv), systemImage: "tablecells")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: exportPDF) {
                            Label(I18nManager.shared.t(.anl_export_pdf), systemImage: "doc.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(8)
            }
            .padding(.horizontal)

            if showExportSuccess {
                Label(I18nManager.shared.t(.anl_export_success), systemImage: "checkmark.circle.fill")
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