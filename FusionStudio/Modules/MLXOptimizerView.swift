// Callers: ModuleDetailView routing.
// Affected API: MLXOptimizerView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

// MARK: - 模型优化配置

struct ModelOptimizationConfig {
    var quantization: QuantizationLevel = .q4
    var useKVCache: Bool = true
    var maxContextLength: Int = 4096
    var batchSize: Int = 1
    var useMetal: Bool = true
    var useANE: Bool = false
    var maxMemoryGB: Double = 16.0
    var enableContinuousBatching: Bool = false
    var tensorParallelism: Int = 1
    var enableFlashAttention: Bool = true

    enum QuantizationLevel: String, CaseIterable {
        case q2 = "2bit"
        case q3 = "3bit"
        case q4 = "4bit"
        case q5 = "5bit"
        case q6 = "6bit"
        case q8 = "8bit"
        case fp16 = "fp16"

        var memoryGB: Double {
            switch self {
            case .q2: return 2.6; case .q3: return 3.9; case .q4: return 5.2
            case .q5: return 6.5; case .q6: return 7.8; case .q8: return 10.4
            case .fp16: return 20.8
            }
        }
        var speed: String {
            switch self {
            case .q2: return I18nManager.shared.t(.mlo_q_speed_fastest)
            case .q3: return I18nManager.shared.t(.mlo_q_speed_veryfast)
            case .q4: return I18nManager.shared.t(.mlo_q_speed_recommended)
            case .q5: return I18nManager.shared.t(.mlo_q_speed_medium)
            case .q6: return I18nManager.shared.t(.mlo_q_speed_slow)
            case .q8: return I18nManager.shared.t(.mlo_q_speed_vslow)
            case .fp16: return I18nManager.shared.t(.mlo_q_speed_slowest)
            }
        }
    }
}

// MARK: - 推理统计

struct InferenceStats: Identifiable {
    let id = UUID()
    let timestamp: Date
    let tokensPerSecond: Double
    let memoryUsed: Double
    let latencyMs: Double
    let modelName: String
    let quantLevel: String
}

// MARK: - MLX 优化器

class MLXOptimizer: ObservableObject {
    static let shared = MLXOptimizer()

    @Published var config = ModelOptimizationConfig()
    @Published var stats: [InferenceStats] = []
    @Published var isBenchmarking = false
    @Published var benchmarkProgress: Double = 0
    @Published var recommendedConfig: ModelOptimizationConfig?

    func runBenchmark() {
        isBenchmarking = true
        benchmarkProgress = 0
        stats = []

        // 调用 fusion-mlx 的基准测试 API
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let url = URL(string: "\(FusionConfig.shared.mlxBaseURL)/v1/benchmarks")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = ["model": "auto"]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                request.timeoutInterval = 300

                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse,
                   httpResp.statusCode == 200,
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]] {
                    for r in results {
                        let stat = InferenceStats(
                            timestamp: Date(),
                            tokensPerSecond: r["tokens_per_second"] as? Double ?? 0,
                            memoryUsed: r["memory_gb"] as? Double ?? 0,
                            latencyMs: r["latency_ms"] as? Double ?? 0,
                            modelName: r["model"] as? String ?? "unknown",
                            quantLevel: r["quantization"] as? String ?? "4bit"
                        )
                        await MainActor.run { self.stats.append(stat) }
                    }
                }
                await MainActor.run {
                    self.isBenchmarking = false
                    self.generateRecommendation()
                    self.objectWillChange.send()
                }
            } catch {
                await MainActor.run {
                    self.isBenchmarking = false
                    self.objectWillChange.send()
                }
            }
        }
    }

    private func generateRecommendation() {
        guard let best = stats.max(by: { $0.tokensPerSecond < $1.tokensPerSecond }) else { return }
        if let level = ModelOptimizationConfig.QuantizationLevel.allCases.first(where: { $0.rawValue == best.quantLevel }) {
            var rec = ModelOptimizationConfig()
            rec.quantization = level
            recommendedConfig = rec
        }
    }

    func applyRecommendation() {
        guard let rec = recommendedConfig else { return }
        config = rec
    }

    func clearStats() { stats.removeAll(); recommendedConfig = nil }
}

// MARK: - MLX 优化视图

struct MLXOptimizerView: View {
    @EnvironmentObject private var bridge: AgentBridge
    @StateObject private var optimizer = MLXOptimizer.shared
    @State private var selectedTab: OptimizerTab = .config
    @State private var mlxStatusInfo: [String: Any] = [:]
    @State private var hwMetrics: [String: Any] = [:]
    @State private var isLoadingStatus = false

    enum OptimizerTab: String, CaseIterable {
        case config
        case server
        case bench
        case stats
        case recommend

        var localizedName: String {
            switch self {
            case .config:    return I18nManager.shared.t(.mlo_tab_config)
            case .server:    return I18nManager.shared.t(.mlo_tab_server)
            case .bench:     return I18nManager.shared.t(.mlo_tab_bench)
            case .stats:     return I18nManager.shared.t(.mlo_tab_stats)
            case .recommend: return I18nManager.shared.t(.mlo_tab_recommend)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(OptimizerTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            switch selectedTab {
            case .config:    OptimizerConfigView()
            case .server:    ServerControlView(bridge: bridge, mlxStatusInfo: $mlxStatusInfo, hwMetrics: $hwMetrics, isLoadingStatus: $isLoadingStatus)
            case .bench:     BenchmarkView()
            case .stats:     InferenceStatsView()
            case .recommend: RecommendationView()
            }
        }
        .onAppear {
            Task { await refreshServerStatus() }
        }
    }

    private func refreshServerStatus() async {
        isLoadingStatus = true
        if let status = try? await bridge.mlxStatus() { mlxStatusInfo = status }
        if let metrics = try? await bridge.hardwareMetrics() { hwMetrics = metrics }
        isLoadingStatus = false
    }

    private func tabIcon(_ tab: OptimizerTab) -> String {
        switch tab {
        case .config:    return "slider.horizontal.3"
        case .server:    return "server.rack"
        case .bench:     return "speedometer"
        case .stats:     return "chart.bar"
        case .recommend: return "wand.and.stars"
        }
    }
}

// MARK: - 优化配置

struct OptimizerConfigView: View {
    @StateObject private var optimizer = MLXOptimizer.shared

    var body: some View {
        Form {
            Section(I18nManager.shared.t(.mlo_sec_quant)) {
                Picker(I18nManager.shared.t(.mlo_quant_precision), selection: $optimizer.config.quantization) {
                    ForEach(ModelOptimizationConfig.QuantizationLevel.allCases, id: \.self) { q in
                        Text("\(q.rawValue) (\(q.speed), ~\(q.memoryGB, specifier: "%.1f")GB)").tag(q)
                    }
                }
                HStack {
                    Text(I18nManager.shared.tf(.mlo_est_mem_fmt, optimizer.config.quantization.memoryGB))
                    Spacer()
                    Text(I18nManager.shared.tf(.mlo_speed_label_fmt, optimizer.config.quantization.speed))
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }

            Section(I18nManager.shared.t(.mlo_sec_mem)) {
                HStack {
                    Text(I18nManager.shared.tf(.mlo_max_mem_fmt, Int(optimizer.config.maxMemoryGB)))
                    Slider(value: $optimizer.config.maxMemoryGB, in: 4...64, step: 2)
                }
                HStack {
                    Text(I18nManager.shared.tf(.mlo_ctx_len_fmt, optimizer.config.maxContextLength))
                    Slider(value: Binding(get: { Double(optimizer.config.maxContextLength) }, set: { optimizer.config.maxContextLength = Int($0) }), in: 1024...32768, step: 1024)
                }
            }

            Section(I18nManager.shared.t(.mlo_sec_accel)) {
                Toggle(I18nManager.shared.t(.mlo_metal_gpu), isOn: $optimizer.config.useMetal)
                Toggle(I18nManager.shared.t(.mlo_ane), isOn: $optimizer.config.useANE)
                Toggle(I18nManager.shared.t(.mlo_flash_attn), isOn: $optimizer.config.enableFlashAttention)
                Toggle(I18nManager.shared.t(.mlo_kv_cache), isOn: $optimizer.config.useKVCache)
                Toggle(I18nManager.shared.t(.mlo_cont_batch), isOn: $optimizer.config.enableContinuousBatching)
            }

            Section(I18nManager.shared.t(.mlo_sec_parallel)) {
                Picker(I18nManager.shared.t(.mlo_tensor_parallel), selection: $optimizer.config.tensorParallelism) {
                    Text(I18nManager.shared.t(.mlo_default)).tag(1)
                    Text("2").tag(2)
                    Text("4").tag(4)
                }
                Picker(I18nManager.shared.t(.mlo_batch_size), selection: $optimizer.config.batchSize) {
                    Text("1").tag(1); Text("2").tag(2); Text("4").tag(4); Text("8").tag(8)
                }
            }

            Section(I18nManager.shared.t(.mlo_sec_mem_est)) {
                let estimated = optimizer.config.quantization.memoryGB + Double(optimizer.config.maxContextLength) / 4096 * 0.5
                HStack {
                    Text(I18nManager.shared.t(.mlo_model_weights))
                    Spacer()
                    Text("\(optimizer.config.quantization.memoryGB, specifier: "%.1f") GB")
                }
                HStack {
                    Text(I18nManager.shared.t(.mlo_kv_cache))
                    Spacer()
                    Text("\(Double(optimizer.config.maxContextLength) / 4096 * 0.5, specifier: "%.1f") GB")
                }
                HStack {
                    Text(I18nManager.shared.t(.mlo_total_est))
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(estimated, specifier: "%.1f") GB")
                        .fontWeight(.bold)
                }
                if estimated > optimizer.config.maxMemoryGB {
                    Label(I18nManager.shared.t(.mlo_mem_over_limit), systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundColor(.orange)
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - 基准测试

struct BenchmarkView: View {
    @StateObject private var optimizer = MLXOptimizer.shared

    var body: some View {
        VStack {
            if optimizer.stats.isEmpty && !optimizer.isBenchmarking {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "speedometer").font(.system(size: 40)).foregroundColor(.secondary)
                    Text(I18nManager.shared.t(.mlo_bench_empty_desc)).foregroundColor(.secondary)
                    Button(I18nManager.shared.t(.mlo_bench_start)) { optimizer.runBenchmark() }.buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else if optimizer.isBenchmarking {
                VStack(spacing: 16) {
                    ProgressView(value: optimizer.benchmarkProgress)
                    Text(I18nManager.shared.tf(.mlo_bench_running_fmt, Int(optimizer.benchmarkProgress * 100)))
                        .font(.headline)
                    Text(I18nManager.shared.t(.mlo_bench_running_desc))
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding()
                Spacer()
            } else {
                HStack {
                    Text(I18nManager.shared.t(.mlo_bench_results)).font(.headline)
                    Spacer()
                    Button(I18nManager.shared.t(.mlo_bench_rerun)) { optimizer.runBenchmark() }.buttonStyle(.bordered).controlSize(.small)
                    Button(I18nManager.shared.t(.mlo_bench_clear)) { optimizer.clearStats() }.buttonStyle(.bordered).controlSize(.small)
                }
                .padding(.horizontal)

                List(optimizer.stats) { stat in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stat.quantLevel).font(.headline).foregroundColor(.accentColor)
                            Text(stat.modelName).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            let speedStr = String(format: "%.1f", stat.tokensPerSecond)
                            let memStr = String(format: "%.1f", stat.memoryUsed)
                            Text("\(speedStr) t/s").font(.system(.body, design: .monospaced))
                            Text("\(memStr) GB").font(.caption).foregroundColor(.secondary)
                        }
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(stat.latencyMs, specifier: "%.0f")ms").font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - 推理统计

struct InferenceStatsView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var optimizer = MLXOptimizer.shared

    var body: some View {
        if optimizer.stats.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "chart.bar").font(.system(size: 40)).foregroundColor(.secondary)
                Text(I18nManager.shared.t(.mlo_stats_empty)).foregroundColor(.secondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                    ForEach(optimizer.stats) { stat in
                        VStack(spacing: 8) {
                            Text(stat.quantLevel).font(.title2).bold().foregroundColor(.accentColor)
                            Divider()
                            StatRow(label: I18nManager.shared.t(.mlo_stat_speed), value: String(format: "%.1f", stat.tokensPerSecond) + " t/s")
                            StatRow(label: I18nManager.shared.t(.mlo_stat_mem), value: String(format: "%.1f", stat.memoryUsed) + " GB")
                            StatRow(label: I18nManager.shared.t(.mlo_stat_latency), value: String(format: "%.0f", stat.latencyMs) + " ms")
                            if let best = optimizer.stats.max(by: { $0.tokensPerSecond < $1.tokensPerSecond }),
                               best.quantLevel == stat.quantLevel {
                                Text(I18nManager.shared.t(.mlo_recommended_badge)).font(.caption).foregroundColor(.orange)
                            }
                        }
                        .padding()
                        .background(theme.surfaceSecondary)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }
}

struct StatRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(.caption, design: .monospaced))
        }
    }
}

// MARK: - 推荐配置

struct RecommendationView: View {
    @StateObject private var optimizer = MLXOptimizer.shared

    var body: some View {
        VStack(spacing: 20) {
            if let rec = optimizer.recommendedConfig {
                Spacer()
                Image(systemName: "wand.and.stars").font(.system(size: 48)).foregroundColor(.accentColor)
                Text(I18nManager.shared.t(.mlo_rec_title)).font(.largeTitle).bold()

                GroupBox(I18nManager.shared.t(.mlo_rec_suggestion)) {
                    VStack(alignment: .leading, spacing: 8) {
                        RecRow(I18nManager.shared.t(.mlo_rec_quant), rec.quantization.rawValue)
                        RecRow(I18nManager.shared.t(.mlo_rec_metal), rec.useMetal ? I18nManager.shared.t(.mlo_enabled) : I18nManager.shared.t(.mlo_disabled))
                        RecRow(I18nManager.shared.t(.mlo_rec_flash_attn), rec.enableFlashAttention ? I18nManager.shared.t(.mlo_enabled) : I18nManager.shared.t(.mlo_disabled))
                        RecRow(I18nManager.shared.t(.mlo_rec_kv_cache), rec.useKVCache ? I18nManager.shared.t(.mlo_enabled) : I18nManager.shared.t(.mlo_disabled))
                        RecRow(I18nManager.shared.t(.mlo_rec_ctx_len), "\(rec.maxContextLength)")
                        RecRow(I18nManager.shared.t(.mlo_rec_max_mem), "\(Int(rec.maxMemoryGB)) GB")
                        RecRow(I18nManager.shared.t(.mlo_rec_est_perf), String(format: "%.0f", optimizer.stats.first(where: { $0.quantLevel == rec.quantization.rawValue })?.tokensPerSecond ?? 0) + " t/s")
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                Button(action: { optimizer.applyRecommendation() }) {
                    Label(I18nManager.shared.t(.mlo_rec_apply), systemImage: "checkmark")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer()
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "lightbulb").font(.system(size: 40)).foregroundColor(.secondary)
                    Text(I18nManager.shared.t(.mlo_rec_empty_desc)).foregroundColor(.secondary)
                    Button(I18nManager.shared.t(.mlo_rec_run_bench)) { optimizer.runBenchmark() }.buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
        }
    }
}

struct RecRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - 模型转换工具

struct ModelConversionView: View {
    @State private var sourcePath = ""
    @State private var targetFormat = "mlx"
    @State private var targetQuant = "4bit"
    @State private var isConverting = false
    @State private var progress: Double = 0
    @State private var log: String = ""

    let formats = ["mlx", "gguf", "safetensors", "onnx", "coreml"]

    var body: some View {
        VStack(spacing: 16) {
            GroupBox(I18nManager.shared.t(.mlo_conv_title)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField(I18nManager.shared.t(.mlo_conv_source_ph), text: $sourcePath)
                            .textFieldStyle(.roundedBorder)
                        Button(I18nManager.shared.t(.mlo_conv_browse)) { }
                            .buttonStyle(.bordered)
                    }
                    Picker(I18nManager.shared.t(.mlo_conv_target_fmt), selection: $targetFormat) {
                        ForEach(formats, id: \.self) { fmt in Text(fmt.uppercased()).tag(fmt) }
                    }
                    Picker(I18nManager.shared.t(.mlo_quant_precision), selection: $targetQuant) {
                        Text("2bit").tag("2bit"); Text("3bit").tag("3bit"); Text("4bit").tag("4bit")
                        Text("8bit").tag("8bit"); Text("fp16").tag("fp16")
                    }
                    Button(action: convert) {
                        Label(isConverting ? I18nManager.shared.t(.mlo_conv_converting) : I18nManager.shared.t(.mlo_conv_start), systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isConverting || sourcePath.isEmpty)

                    if isConverting {
                        ProgressView(value: progress)
                        Text("\(Int(progress * 100))%").font(.caption).foregroundColor(.secondary)
                    }

                    if !log.isEmpty {
                        ScrollView {
                            Text(log).font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
                        }
                        .frame(height: 80)
                        .background(Color.black.opacity(0.05)).cornerRadius(4)
                    }
                }
                .padding(8)
            }
            .padding(.horizontal)
            Spacer()
        }
        .padding(.vertical)
    }

    private func convert() {
        isConverting = true; progress = 0
        log = I18nManager.shared.tf(.mlo_conv_log_start_fmt, sourcePath, targetFormat.uppercased(), targetQuant)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            progress += 0.1
            log += I18nManager.shared.tf(.mlo_conv_log_progress_fmt, Int(progress * 100))
            if progress >= 1.0 {
                log += I18nManager.shared.tf(.mlo_conv_log_done_fmt, targetFormat.uppercased(), targetQuant)
                timer.invalidate(); isConverting = false
            }
        }
    }
}

// MARK: - 服务器控制

struct ServerControlView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var bridge: AgentBridge
    @Binding var mlxStatusInfo: [String: Any]
    @Binding var hwMetrics: [String: Any]
    @Binding var isLoadingStatus: Bool
    @State private var restartModel = ""
    @State private var statusText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 服务器控制
                GroupBox(I18nManager.shared.t(.mlo_server_ctrl)) {
                    HStack(spacing: 12) {
                        Button(action: { Task { try? await bridge.startMLX(model: restartModel); await refresh() } }) {
                            Label(I18nManager.shared.t(.mlo_server_start), systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button(action: { Task { try? await bridge.stopMLX(); await refresh() } }) {
                            Label(I18nManager.shared.t(.mlo_server_stop), systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)

                        Button(action: { Task { try? await bridge.restartMLX(model: restartModel); await refresh() } }) {
                            Label(I18nManager.shared.t(.mlo_server_restart), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Button(action: { Task { await refresh() } }) {
                            Image(systemName: "arrow.clockwise.circle")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                    .padding(8)
                }

                // 服务器状态
                GroupBox(I18nManager.shared.t(.mlo_server_status)) {
                    if isLoadingStatus {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if mlxStatusInfo.isEmpty {
                        Text(I18nManager.shared.t(.mlo_server_not_connected)).foregroundColor(.secondary).padding(8)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(mlxStatusInfo.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack {
                                    Text(key).foregroundColor(.secondary).frame(width: 120, alignment: .leading)
                                    Text(String(describing: value)).font(.system(.body, design: .monospaced))
                                    Spacer()
                                }
                            }
                        }
                        .padding(8)
                    }
                }

                // 硬件指标
                GroupBox(I18nManager.shared.t(.mlo_hw_metrics)) {
                    if hwMetrics.isEmpty {
                        Text(I18nManager.shared.t(.mlo_hw_no_data)).foregroundColor(.secondary).padding(8)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(hwMetrics.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                HStack {
                                    Text(key).foregroundColor(.secondary).frame(width: 120, alignment: .leading)
                                    Text(String(describing: value)).font(.system(.body, design: .monospaced))
                                    Spacer()
                                }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .padding()
        }
    }

    private func refresh() async {
        isLoadingStatus = true
        if let status = try? await bridge.mlxStatus() { mlxStatusInfo = status }
        if let metrics = try? await bridge.hardwareMetrics() { hwMetrics = metrics }
        isLoadingStatus = false
    }
}
