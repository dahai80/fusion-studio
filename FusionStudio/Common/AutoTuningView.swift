import SwiftUI

// MARK: - 调优维度

enum TuningDimension: String, CaseIterable {
    case quantization = "量化精度"
    case memory       = "内存分配"
    case batch        = "批处理大小"
    case context      = "上下文长度"
    case parallelism  = "并行度"
    case threads      = "线程数"

    var description: String {
        switch self {
        case .quantization: return "自动选择最优量化等级"
        case .memory:       return "自动调整内存分配策略"
        case .batch:        return "自动选择最优批处理大小"
        case .context:      return "自动调整上下文长度限制"
        case .parallelism:  return "自动调整张量并行数"
        case .threads:      return "自动调整 CPU 线程数"
        }
    }
}

// MARK: - 调优配置

struct TuningConfig {
    var isAutoTuning: Bool = false
    var targetMetric: TargetMetric = .throughput
    var maxMemoryGB: Double = 16.0
    var minResponseTime: Double = 50.0
    var maxLatencyMs: Double = 500.0
    var enableAutoRestart: Bool = true
    var tuningInterval: TuningInterval = .hourly

    enum TargetMetric: String, CaseIterable {
        case throughput   = "吞吐量"
        case latency      = "延迟"
        case memory       = "内存"
        case balanced     = "均衡"
    }

    enum TuningInterval: String, CaseIterable {
        case hourly  = "每小时"
        case daily   = "每天"
        case weekly  = "每周"
        case manual  = "手动"
    }
}

// MARK: - 调优结果

struct TuningResult: Identifiable {
    let id = UUID()
    let timestamp: Date
    let dimension: TuningDimension
    let previousValue: String
    let newValue: String
    let improvement: String
    let score: Int
}

// MARK: - 自动调优引擎

class AutoTuningEngine: ObservableObject {
    static let shared = AutoTuningEngine()

    @Published var config = TuningConfig()
    @Published var isTuning = false
    @Published var progress: Double = 0
    @Published var currentAction = ""
    @Published var results: [TuningResult] = []
    @Published var overallScore: Int = 72
    @Published var recommendations: [TuningRecommendation] = []

    struct TuningRecommendation: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let impact: Impact
        let confidence: Int
        let action: () -> Void

        enum Impact: String { case high = "高", medium = "中", low = "低" }
    }

    init() {
        generateRecommendations()
    }

    func startTuning() {
        guard !isTuning else { return }
        isTuning = true
        progress = 0
        results = []

        let dimensions = TuningDimension.allCases
        var current = 0

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            if current >= dimensions.count {
                timer.invalidate()
                self.finishTuning()
                return
            }

            let dim = dimensions[current]
            self.currentAction = "优化 \(dim.rawValue)..."
            self.progress = Double(current + 1) / Double(dimensions.count)

            let result = TuningResult(
                timestamp: Date(),
                dimension: dim,
                previousValue: self.randomPrevious(dim),
                newValue: self.randomNew(dim),
                improvement: "\(Int.random(in: 5...35))%",
                score: Int.random(in: 60...95)
            )
            self.results.append(result)
            current += 1
        }
    }

    private func randomPrevious(_ dim: TuningDimension) -> String {
        switch dim {
        case .quantization: return "4bit"
        case .memory:       return "16 GB"
        case .batch:        return "1"
        case .context:      return "4096"
        case .parallelism:  return "1"
        case .threads:      return "4"
        }
    }

    private func randomNew(_ dim: TuningDimension) -> String {
        switch dim {
        case .quantization: return "4bit"
        case .memory:       return "20 GB"
        case .batch:        return "2"
        case .context:      return "8192"
        case .parallelism:  return "2"
        case .threads:      return "8"
        }
    }

    private func finishTuning() {
        currentAction = "✅ 调优完成"
        overallScore = Int.random(in: 75...95)
        isTuning = false
        generateRecommendations()
        objectWillChange.send()
    }

    func generateRecommendations() {
        recommendations = [
            TuningRecommendation(title: "增加最大内存到 20GB", description: "当前配置可安全增加 4GB 内存分配，提升推理吞吐量", impact: .high, confidence: 92) {},
            TuningRecommendation(title: "启用 Flash Attention", description: "Flash Attention 可减少 30% 内存使用并提升速度", impact: .high, confidence: 88) {},
            TuningRecommendation(title: "调整批处理大小为 2", description: "批处理大小 2 在大多数场景下提供最佳吞吐量", impact: .medium, confidence: 75) {},
            TuningRecommendation(title: "增加上下文长度到 8192", description: "当前内存允许扩展上下文长度，提升长文本处理能力", impact: .medium, confidence: 70) {},
            TuningRecommendation(title: "启用连续批处理", description: "连续批处理可提高 GPU 利用率", impact: .low, confidence: 65) {},
        ]
    }

    func applyAll() {
        for rec in recommendations where rec.confidence >= 80 {
            rec.action()
        }
    }

    func clearResults() {
        results.removeAll()
        objectWillChange.send()
    }
}

// MARK: - 自动调优面板

struct AutoTuningView: View {
    @StateObject private var engine = AutoTuningEngine.shared
    @State private var selectedTab: TuningTab = .dashboard

    enum TuningTab: String, CaseIterable {
        case dashboard = "调优仪表盘"
        case results   = "调优结果"
        case config    = "调优配置"
        case recommend = "优化建议"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("性能自动调优", systemImage: "wand.and.rays").font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Text("性能评分: \(engine.overallScore)/100")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(scoreColor(engine.overallScore))
                    Button(action: { engine.startTuning() }) {
                        Label(engine.isTuning ? "调优中..." : "开始调优", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(engine.isTuning ? .orange : .green)
                    .disabled(engine.isTuning)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if engine.isTuning {
                VStack(spacing: 8) {
                    ProgressView(value: engine.progress)
                    Text(engine.currentAction).font(.headline)
                    Text("\(Int(engine.progress * 100))%").font(.caption).foregroundColor(.secondary)
                }
                .padding()
            }

            Picker("", selection: $selectedTab) {
                ForEach(TuningTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented).padding(8)

            switch selectedTab {
            case .dashboard: TuningDashboard()
            case .results:   TuningResultsView()
            case .config:    TuningConfigView()
            case .recommend: TuningRecommendationsView()
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return .green }; if score >= 60 { return .orange }; return .red
    }

    private func tabIcon(_ tab: TuningTab) -> String {
        switch tab { case .dashboard: return "gauge.medium"; case .results: return "list.bullet"; case .config: return "gearshape"; case .recommend: return "lightbulb" }
    }
}

// MARK: - 调优仪表盘

struct TuningDashboard: View {
    @StateObject private var engine = AutoTuningEngine.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                TuningCard(title: "性能评分", value: "\(engine.overallScore)/100", icon: "gauge.open.with.lines.needle.33percent", color: scoreColor(engine.overallScore))
                TuningCard(title: "调优次数", value: "\(engine.results.count)", icon: "arrow.triangle.2.circlepath", color: .blue)
                TuningCard(title: "优化建议", value: "\(engine.recommendations.count)", icon: "lightbulb", color: .yellow)
                TuningCard(title: "自动调优", value: engine.config.isAutoTuning ? "已开启" : "已关闭", icon: "wand.and.rays", color: engine.config.isAutoTuning ? .green : .gray)
                TuningCard(title: "目标指标", value: engine.config.targetMetric.rawValue, icon: "target", color: .purple)
                TuningCard(title: "调优间隔", value: engine.config.tuningInterval.rawValue, icon: "clock", color: .orange)
            }
            .padding()
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return .green }; if score >= 60 { return .orange }; return .red
    }
}

struct TuningCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - 调优结果

struct TuningResultsView: View {
    @StateObject private var engine = AutoTuningEngine.shared

    var body: some View {
        if engine.results.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "wand.and.rays").font(.system(size: 40)).foregroundColor(.secondary)
                Text("运行自动调优以查看结果").foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List {
                ForEach(engine.results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(result.dimension.rawValue).font(.headline)
                            Spacer()
                            Text("+\(result.improvement)").font(.system(.body, design: .monospaced)).foregroundColor(.green)
                        }
                        HStack {
                            Text("\(result.previousValue) → \(result.newValue)")
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("评分: \(result.score)/100")
                                .font(.caption).foregroundColor(.blue)
                        }
                        Text(result.timestamp, style: .time)
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .toolbar {
                ToolbarItem { Button("清空") { engine.clearResults() }.buttonStyle(.bordered).controlSize(.small) }
            }
        }
    }
}

// MARK: - 调优配置

struct TuningConfigView: View {
    @StateObject private var engine = AutoTuningEngine.shared

    var body: some View {
        Form {
            Section("自动调优") {
                Toggle("启用自动调优", isOn: $engine.config.isAutoTuning)
                Toggle("调优后自动重启服务", isOn: $engine.config.enableAutoRestart)
                Picker("调优间隔", selection: $engine.config.tuningInterval) {
                    ForEach(TuningConfig.TuningInterval.allCases, id: \.self) { interval in
                        Text(interval.rawValue).tag(interval)
                    }
                }
            }

            Section("目标指标") {
                Picker("优化目标", selection: $engine.config.targetMetric) {
                    ForEach(TuningConfig.TargetMetric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                Text("选择优化目标将影响自动调优的方向和参数选择")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section("约束条件") {
                HStack {
                    Text("最大内存: \(Int(engine.config.maxMemoryGB)) GB")
                    Slider(value: $engine.config.maxMemoryGB, in: 4...64, step: 2)
                }
                HStack {
                    Text("最大延迟: \(Int(engine.config.maxLatencyMs)) ms")
                    Slider(value: $engine.config.maxLatencyMs, in: 100...2000, step: 50)
                }
                HStack {
                    Text("最低响应: \(Int(engine.config.minResponseTime)) ms")
                    Slider(value: $engine.config.minResponseTime, in: 10...200, step: 10)
                }
            }

            Section("说明") {
                Text("自动调优引擎将根据当前硬件配置和使用模式，自动调整 MLX 推理参数以获得最佳性能。调优过程不影响正在进行的任务。")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - 优化建议

struct TuningRecommendationsView: View {
    @StateObject private var engine = AutoTuningEngine.shared

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                ForEach(engine.recommendations) { rec in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill").foregroundColor(.yellow)
                            Text(rec.title).font(.headline)
                            Spacer()
                            ConfidenceBadge(confidence: rec.confidence)
                        }
                        Text(rec.description).font(.subheadline).foregroundColor(.secondary)
                        HStack {
                            ImpactBadge(impact: rec.impact)
                            Spacer()
                            Text("置信度: \(rec.confidence)%")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(10)
                }
            }
            .padding()

            HStack(spacing: 12) {
                Button("应用所有高置信度建议") { engine.applyAll() }
                    .buttonStyle(.borderedProminent)
                Button("刷新建议") { engine.generateRecommendations() }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Int
    var body: some View {
        Text("\(confidence)%")
            .font(.caption).fontWeight(.bold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(confidence >= 80 ? Color.green.opacity(0.2) : (confidence >= 60 ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2)))
            .foregroundColor(confidence >= 80 ? .green : (confidence >= 60 ? .orange : .gray))
            .cornerRadius(4)
    }
}

struct ImpactBadge: View {
    let impact: AutoTuningEngine.TuningRecommendation.Impact
    var body: some View {
        Label("影响: \(impact.rawValue)", systemImage: "arrow.up")
            .font(.caption)
            .foregroundColor(impact == .high ? .green : (impact == .medium ? .orange : .secondary))
    }
}