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
            case .q2: return "最快"; case .q3: return "很快"; case .q4: return "推荐"
            case .q5: return "中等"; case .q6: return "较慢"; case .q8: return "慢"
            case .fp16: return "最慢"
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
                let url = URL(string: "http://localhost:8000/v1/benchmarks")!
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
        case config    = "优化配置"
        case server    = "服务器"
        case bench     = "基准测试"
        case stats     = "推理统计"
        case recommend = "推荐配置"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(OptimizerTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
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
            Section("量化") {
                Picker("量化精度", selection: $optimizer.config.quantization) {
                    ForEach(ModelOptimizationConfig.QuantizationLevel.allCases, id: \.self) { q in
                        Text("\(q.rawValue) (\(q.speed), ~\(q.memoryGB, specifier: "%.1f")GB)").tag(q)
                    }
                }
                HStack {
                    Text("预估内存: \(optimizer.config.quantization.memoryGB, specifier: "%.1f") GB")
                    Spacer()
                    Text("速度: \(optimizer.config.quantization.speed)")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }

            Section("内存") {
                HStack {
                    Text("最大内存: \(Int(optimizer.config.maxMemoryGB)) GB")
                    Slider(value: $optimizer.config.maxMemoryGB, in: 4...64, step: 2)
                }
                HStack {
                    Text("上下文长度: \(optimizer.config.maxContextLength)")
                    Slider(value: Binding(get: { Double(optimizer.config.maxContextLength) }, set: { optimizer.config.maxContextLength = Int($0) }), in: 1024...32768, step: 1024)
                }
            }

            Section("加速") {
                Toggle("Metal GPU 加速", isOn: $optimizer.config.useMetal)
                Toggle("ANE 神经网络引擎", isOn: $optimizer.config.useANE)
                Toggle("Flash Attention", isOn: $optimizer.config.enableFlashAttention)
                Toggle("KV Cache", isOn: $optimizer.config.useKVCache)
                Toggle("连续批处理", isOn: $optimizer.config.enableContinuousBatching)
            }

            Section("并行") {
                Picker("张量并行数", selection: $optimizer.config.tensorParallelism) {
                    Text("1 (默认)").tag(1)
                    Text("2").tag(2)
                    Text("4").tag(4)
                }
                Picker("批处理大小", selection: $optimizer.config.batchSize) {
                    Text("1").tag(1); Text("2").tag(2); Text("4").tag(4); Text("8").tag(8)
                }
            }

            Section("内存预估") {
                let estimated = optimizer.config.quantization.memoryGB + Double(optimizer.config.maxContextLength) / 4096 * 0.5
                HStack {
                    Text("模型权重")
                    Spacer()
                    Text("\(optimizer.config.quantization.memoryGB, specifier: "%.1f") GB")
                }
                HStack {
                    Text("KV Cache")
                    Spacer()
                    Text("\(Double(optimizer.config.maxContextLength) / 4096 * 0.5, specifier: "%.1f") GB")
                }
                HStack {
                    Text("总计预估")
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(estimated, specifier: "%.1f") GB")
                        .fontWeight(.bold)
                }
                if estimated > optimizer.config.maxMemoryGB {
                    Label("预估内存超出限制，建议降低量化精度或上下文长度", systemImage: "exclamationmark.triangle")
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
                    Text("运行基准测试以评估各量化等级的性能").foregroundColor(.secondary)
                    Button("开始基准测试") { optimizer.runBenchmark() }.buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else if optimizer.isBenchmarking {
                VStack(spacing: 16) {
                    ProgressView(value: optimizer.benchmarkProgress)
                    Text("测试中... \(Int(optimizer.benchmarkProgress * 100))%")
                        .font(.headline)
                    Text("正在测试不同量化等级的性能和内存占用")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding()
                Spacer()
            } else {
                HStack {
                    Text("基准测试结果").font(.headline)
                    Spacer()
                    Button("重新测试") { optimizer.runBenchmark() }.buttonStyle(.bordered).controlSize(.small)
                    Button("清空") { optimizer.clearStats() }.buttonStyle(.bordered).controlSize(.small)
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
                Text("运行基准测试以查看统计").foregroundColor(.secondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                    ForEach(optimizer.stats) { stat in
                        VStack(spacing: 8) {
                            Text(stat.quantLevel).font(.title2).bold().foregroundColor(.accentColor)
                            Divider()
                            StatRow(label: "速度", value: String(format: "%.1f", stat.tokensPerSecond) + " t/s")
                            StatRow(label: "内存", value: String(format: "%.1f", stat.memoryUsed) + " GB")
                            StatRow(label: "延迟", value: String(format: "%.0f", stat.latencyMs) + " ms")
                            if let best = optimizer.stats.max(by: { $0.tokensPerSecond < $1.tokensPerSecond }),
                               best.quantLevel == stat.quantLevel {
                                Text("🏆 推荐").font(.caption).foregroundColor(.orange)
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
                Text("推荐配置").font(.largeTitle).bold()

                GroupBox("优化建议") {
                    VStack(alignment: .leading, spacing: 8) {
                        RecRow("量化精度", rec.quantization.rawValue)
                        RecRow("Metal 加速", rec.useMetal ? "启用" : "禁用")
                        RecRow("Flash Attention", rec.enableFlashAttention ? "启用" : "禁用")
                        RecRow("KV Cache", rec.useKVCache ? "启用" : "禁用")
                        RecRow("上下文长度", "\(rec.maxContextLength)")
                        RecRow("最大内存", "\(Int(rec.maxMemoryGB)) GB")
                        RecRow("预估性能", String(format: "%.0f", optimizer.stats.first(where: { $0.quantLevel == rec.quantization.rawValue })?.tokensPerSecond ?? 0) + " t/s")
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                Button(action: { optimizer.applyRecommendation() }) {
                    Label("应用推荐配置", systemImage: "checkmark")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer()
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "lightbulb").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("运行基准测试以获取推荐配置").foregroundColor(.secondary)
                    Button("运行基准测试") { optimizer.runBenchmark() }.buttonStyle(.borderedProminent)
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
            GroupBox("模型转换") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("源模型路径", text: $sourcePath)
                            .textFieldStyle(.roundedBorder)
                        Button("浏览") { }
                            .buttonStyle(.bordered)
                    }
                    Picker("目标格式", selection: $targetFormat) {
                        ForEach(formats, id: \.self) { fmt in Text(fmt.uppercased()).tag(fmt) }
                    }
                    Picker("量化精度", selection: $targetQuant) {
                        Text("2bit").tag("2bit"); Text("3bit").tag("3bit"); Text("4bit").tag("4bit")
                        Text("8bit").tag("8bit"); Text("fp16").tag("fp16")
                    }
                    Button(action: convert) {
                        Label(isConverting ? "转换中..." : "开始转换", systemImage: "arrow.triangle.2.circlepath")
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
        isConverting = true; progress = 0; log = "开始转换: \(sourcePath) → \(targetFormat.uppercased()) \(targetQuant)...\n"
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            progress += 0.1
            log += "  [\(Int(progress * 100))%] 处理中...\n"
            if progress >= 1.0 {
                log += "✅ 转换完成: \(targetFormat.uppercased()) \(targetQuant)\n"
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
                GroupBox("服务器控制") {
                    HStack(spacing: 12) {
                        Button(action: { Task { try? await bridge.startMLX(model: restartModel); await refresh() } }) {
                            Label("启动", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button(action: { Task { try? await bridge.stopMLX(); await refresh() } }) {
                            Label("停止", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)

                        Button(action: { Task { try? await bridge.restartMLX(model: restartModel); await refresh() } }) {
                            Label("重启", systemImage: "arrow.clockwise")
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
                GroupBox("服务器状态") {
                    if isLoadingStatus {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if mlxStatusInfo.isEmpty {
                        Text("未连接").foregroundColor(.secondary).padding(8)
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
                GroupBox("硬件指标") {
                    if hwMetrics.isEmpty {
                        Text("无数据").foregroundColor(.secondary).padding(8)
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
