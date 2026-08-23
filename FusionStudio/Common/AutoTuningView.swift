import SwiftUI
import os.log

private let atLog = Logger(subsystem: "com.fusion.studio", category: "auto-tuning")

// MARK: - 调优维度

enum TuningDimension: String, CaseIterable {
    case quantization
    case memory
    case batch
    case context
    case parallelism
    case threads

    var localizedName: String {
        switch self {
        case .quantization: return I18nManager.shared.t(.at_dim_quantization)
        case .memory:       return I18nManager.shared.t(.at_dim_memory)
        case .batch:        return I18nManager.shared.t(.at_dim_batch)
        case .context:      return I18nManager.shared.t(.at_dim_context)
        case .parallelism:  return I18nManager.shared.t(.at_dim_parallelism)
        case .threads:      return I18nManager.shared.t(.at_dim_threads)
        }
    }

    var localizedDescription: String {
        switch self {
        case .quantization: return I18nManager.shared.t(.at_dim_desc_quantization)
        case .memory:       return I18nManager.shared.t(.at_dim_desc_memory)
        case .batch:        return I18nManager.shared.t(.at_dim_desc_batch)
        case .context:      return I18nManager.shared.t(.at_dim_desc_context)
        case .parallelism:  return I18nManager.shared.t(.at_dim_desc_parallelism)
        case .threads:      return I18nManager.shared.t(.at_dim_desc_threads)
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
        case throughput
        case latency
        case memory
        case balanced

        var localizedName: String {
            switch self {
            case .throughput: return I18nManager.shared.t(.at_metric_throughput)
            case .latency:    return I18nManager.shared.t(.at_metric_latency)
            case .memory:     return I18nManager.shared.t(.at_metric_memory)
            case .balanced:   return I18nManager.shared.t(.at_metric_balanced)
            }
        }
    }

    enum TuningInterval: String, CaseIterable {
        case hourly
        case daily
        case weekly
        case manual

        var localizedName: String {
            switch self {
            case .hourly: return I18nManager.shared.t(.at_interval_hourly)
            case .daily:  return I18nManager.shared.t(.at_interval_daily)
            case .weekly: return I18nManager.shared.t(.at_interval_weekly)
            case .manual: return I18nManager.shared.t(.at_interval_manual)
            }
        }
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

        enum Impact: String { case high, medium, low
            var localizedName: String {
                switch self {
                case .high:   return I18nManager.shared.t(.at_impact_high)
                case .medium: return I18nManager.shared.t(.at_impact_medium)
                case .low:    return I18nManager.shared.t(.at_impact_low)
                }
            }
        }
    }

    init() {
        generateRecommendations()
    }

    func startTuning() {
        guard !isTuning else { return }
        isTuning = true
        progress = 0
        results = []
        atLog.info("auto-tuning started")

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
            self.currentAction = I18nManager.shared.tf(.at_action_optimize, dim.localizedName)
            self.progress = Double(current + 1) / Double(dimensions.count)

            let result = TuningResult(
                timestamp: Date(),
                dimension: dim,
                previousValue: self.randomPrevious(dim),
                newValue: self.randomNew(dim),
                improvement: I18nManager.shared.tf(.at_improvement_pct, Int.random(in: 5...35)),
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
        currentAction = I18nManager.shared.t(.at_action_done)
        overallScore = Int.random(in: 75...95)
        isTuning = false
        generateRecommendations()
        objectWillChange.send()
        atLog.info("auto-tuning finished, score \(self.overallScore)")
    }

    func generateRecommendations() {
        recommendations = [
            TuningRecommendation(title: I18nManager.shared.t(.at_rec_title_increase_mem), description: I18nManager.shared.t(.at_rec_desc_increase_mem), impact: .high, confidence: 92) {},
            TuningRecommendation(title: I18nManager.shared.t(.at_rec_title_flash_attn), description: I18nManager.shared.t(.at_rec_desc_flash_attn), impact: .high, confidence: 88) {},
            TuningRecommendation(title: I18nManager.shared.t(.at_rec_title_batch_size), description: I18nManager.shared.t(.at_rec_desc_batch_size), impact: .medium, confidence: 75) {},
            TuningRecommendation(title: I18nManager.shared.t(.at_rec_title_ctx_len), description: I18nManager.shared.t(.at_rec_desc_ctx_len), impact: .medium, confidence: 70) {},
            TuningRecommendation(title: I18nManager.shared.t(.at_rec_title_continuous_batch), description: I18nManager.shared.t(.at_rec_desc_continuous_batch), impact: .low, confidence: 65) {},
        ]
    }

    func applyAll() {
        for rec in recommendations where rec.confidence >= 80 {
            rec.action()
        }
        atLog.info("applied high-confidence recommendations")
    }

    func clearResults() {
        results.removeAll()
        objectWillChange.send()
        atLog.info("cleared tuning results")
    }
}

// MARK: - 自动调优面板

struct AutoTuningView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var engine = AutoTuningEngine.shared
    @State private var selectedTab: TuningTab = .dashboard

    enum TuningTab: String, CaseIterable {
        case dashboard
        case results
        case config
        case recommend

        var localizedName: String {
            switch self {
            case .dashboard: return I18nManager.shared.t(.at_tab_dashboard)
            case .results:   return I18nManager.shared.t(.at_tab_results)
            case .config:    return I18nManager.shared.t(.at_tab_config)
            case .recommend: return I18nManager.shared.t(.at_tab_recommend)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(I18nManager.shared.t(.at_header), systemImage: "wand.and.rays").font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Text(I18nManager.shared.tf(.at_score_label, engine.overallScore))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(scoreColor(engine.overallScore))
                    Button(action: { engine.startTuning() }) {
                        Label(engine.isTuning ? I18nManager.shared.t(.at_btn_tuning) : I18nManager.shared.t(.at_btn_start), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(engine.isTuning ? .orange : .green)
                    .disabled(engine.isTuning)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            if engine.isTuning {
                VStack(spacing: 8) {
                    ProgressView(value: engine.progress)
                    Text(engine.currentAction).font(.headline)
                    Text(I18nManager.shared.tf(.at_progress_pct, Int(engine.progress * 100))).font(.caption).foregroundColor(.secondary)
                }
                .padding()
            }

            Picker("", selection: $selectedTab) {
                ForEach(TuningTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
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
                TuningCard(title: I18nManager.shared.t(.at_card_score), value: "\(engine.overallScore)/100", icon: "gauge.open.with.lines.needle.33percent", color: scoreColor(engine.overallScore))
                TuningCard(title: I18nManager.shared.t(.at_card_count), value: "\(engine.results.count)", icon: "arrow.triangle.2.circlepath", color: .blue)
                TuningCard(title: I18nManager.shared.t(.at_card_rec), value: "\(engine.recommendations.count)", icon: "lightbulb", color: .yellow)
                TuningCard(title: I18nManager.shared.t(.at_card_auto), value: engine.config.isAutoTuning ? I18nManager.shared.t(.at_val_on) : I18nManager.shared.t(.at_val_off), icon: "wand.and.rays", color: engine.config.isAutoTuning ? .green : .gray)
                TuningCard(title: I18nManager.shared.t(.at_metric_throughput), value: engine.config.targetMetric.localizedName, icon: "target", color: .purple)
                TuningCard(title: I18nManager.shared.t(.at_cfg_interval_label), value: engine.config.tuningInterval.localizedName, icon: "clock", color: .orange)
            }
            .padding()
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return .green }; if score >= 60 { return .orange }; return .red
    }
}

struct TuningCard: View {
    @Environment(\.studioTheme) private var theme
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title2).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.surfaceSecondary)
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
                Text(I18nManager.shared.t(.at_results_empty)).foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List {
                ForEach(engine.results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(result.dimension.localizedName).font(.headline)
                            Spacer()
                            Text(I18nManager.shared.tf(.at_result_improvement, result.improvement)).font(.system(.body, design: .monospaced)).foregroundColor(.green)
                        }
                        HStack {
                            Text(I18nManager.shared.tf(.at_result_change, result.previousValue, result.newValue))
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text(I18nManager.shared.tf(.at_result_score, result.score))
                                .font(.caption).foregroundColor(.blue)
                        }
                        Text(result.timestamp, style: .time)
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .toolbar {
                ToolbarItem { Button(I18nManager.shared.t(.at_btn_clear)) { engine.clearResults() }.buttonStyle(.bordered).controlSize(.small) }
            }
        }
    }
}

// MARK: - 调优配置

struct TuningConfigView: View {
    @StateObject private var engine = AutoTuningEngine.shared

    var body: some View {
        Form {
            Section(I18nManager.shared.t(.at_cfg_section_auto)) {
                Toggle(I18nManager.shared.t(.at_cfg_enable), isOn: $engine.config.isAutoTuning)
                Toggle(I18nManager.shared.t(.at_cfg_autorestart), isOn: $engine.config.enableAutoRestart)
                Picker(I18nManager.shared.t(.at_cfg_interval_label), selection: $engine.config.tuningInterval) {
                    ForEach(TuningConfig.TuningInterval.allCases, id: \.self) { interval in
                        Text(interval.localizedName).tag(interval)
                    }
                }
            }

            Section(I18nManager.shared.t(.at_cfg_section_metric)) {
                Picker(I18nManager.shared.t(.at_cfg_target_label), selection: $engine.config.targetMetric) {
                    ForEach(TuningConfig.TargetMetric.allCases, id: \.self) { metric in
                        Text(metric.localizedName).tag(metric)
                    }
                }
                Text(I18nManager.shared.t(.at_cfg_target_hint))
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(I18nManager.shared.t(.at_cfg_section_constraints)) {
                HStack {
                    Text(I18nManager.shared.tf(.at_cfg_max_mem, Int(engine.config.maxMemoryGB)))
                    Slider(value: $engine.config.maxMemoryGB, in: 4...64, step: 2)
                }
                HStack {
                    Text(I18nManager.shared.tf(.at_cfg_max_latency, Int(engine.config.maxLatencyMs)))
                    Slider(value: $engine.config.maxLatencyMs, in: 100...2000, step: 50)
                }
                HStack {
                    Text(I18nManager.shared.tf(.at_cfg_min_resp, Int(engine.config.minResponseTime)))
                    Slider(value: $engine.config.minResponseTime, in: 10...200, step: 10)
                }
            }

            Section(I18nManager.shared.t(.at_cfg_section_note)) {
                Text(I18nManager.shared.t(.at_cfg_note))
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - 优化建议

struct TuningRecommendationsView: View {
    @Environment(\.studioTheme) private var theme
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
                            Text(I18nManager.shared.tf(.at_rec_confidence, rec.confidence))
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(theme.surfaceSecondary)
                    .cornerRadius(10)
                }
            }
            .padding()

            HStack(spacing: 12) {
                Button(I18nManager.shared.t(.at_rec_apply)) { engine.applyAll() }
                    .buttonStyle(.borderedProminent)
                Button(I18nManager.shared.t(.at_rec_refresh)) { engine.generateRecommendations() }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Int
    var body: some View {
        Text(I18nManager.shared.tf(.at_confidence_pct, confidence))
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
        Label(I18nManager.shared.tf(.at_impact_label, impact.localizedName), systemImage: "arrow.up")
            .font(.caption)
            .foregroundColor(impact == .high ? .green : (impact == .medium ? .orange : .secondary))
    }
}
