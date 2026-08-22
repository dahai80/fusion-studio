// Callers: ModuleDetailView routing.
// Affected API: TrainingView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import os.log

private let trainLogger = Logger(subsystem: "com.fusion.studio", category: "TrainingView")

// MARK: - 训练配置

struct TrainingConfig {
    var modelName: String = "qwen3.5-9b-4bit"
    var method: TrainingMethod = .lora
    var loraRank: Int = 16
    var loraAlpha: Double = 32.0
    var loraDropout: Double = 0.05
    var targetModules: [String] = ["q_proj", "v_proj"]
    var learningRate: Double = 2e-4
    var numEpochs: Int = 3
    var batchSize: Int = 1
    var maxSeqLength: Int = 1024
    var warmupSteps: Int = 100
    var saveEvery: Int = 500
    var dataset: String = ""
    var useQuad: Bool = true
    var useGradientCheckpointing: Bool = true
    var optimizer: OptimizerType = .adamW

    enum TrainingMethod: String, CaseIterable {
        case lora
        case qlora
        case full

        var localizedName: String {
            switch self {
            case .lora:  return I18nManager.shared.t(.train_method_lora)
            case .qlora: return I18nManager.shared.t(.train_method_qlora)
            case .full:  return I18nManager.shared.t(.train_method_full)
            }
        }
    }
    enum OptimizerType: String, CaseIterable {
        case adamW = "AdamW"
        case sgd   = "SGD"
        case adam  = "Adam"
    }
}

// MARK: - 训练状态

struct TrainingStatus {
    var isRunning: Bool = false
    var currentEpoch: Int = 0
    var totalEpochs: Int = 3
    var currentStep: Int = 0
    var totalSteps: Int = 1000
    var loss: Double = 0
    var learningRate: Double = 0
    var progress: Double = 0
    var elapsedTime: TimeInterval = 0
    var estimatedTimeRemaining: TimeInterval = 0
    var log: [String] = []
}

// MARK: - 训练管理器

class TrainingManager: ObservableObject {
    static let shared = TrainingManager()

    @Published var config = TrainingConfig()
    @Published var status = TrainingStatus()
    @Published var checkpoints: [Checkpoint] = []
    @Published var selectedModel: String = ""

    struct Checkpoint: Identifiable {
        let id = UUID()
        let name: String
        let step: Int
        let loss: Double
        let date: Date
        let size: String
    }

    init() {
        loadSampleCheckpoints()
    }

    private func loadSampleCheckpoints() {
        checkpoints = [
            Checkpoint(name: "checkpoint-500", step: 500, loss: 0.32, date: Date().addingTimeInterval(-3600), size: "45 MB"),
            Checkpoint(name: "checkpoint-1000", step: 1000, loss: 0.18, date: Date(), size: "45 MB"),
        ]
    }

    func startTraining() {
        status.isRunning = true
        status.log = [I18nManager.shared.t(.train_log_start)]
        status.log.append(I18nManager.shared.tf(.train_log_model, config.modelName))
        status.log.append(I18nManager.shared.tf(.train_log_method, config.method.localizedName))
        status.log.append(I18nManager.shared.tf(.train_log_lr_val, config.learningRate))
        status.log.append(I18nManager.shared.tf(.train_log_epochs, config.numEpochs))
        status.log.append(I18nManager.shared.tf(.train_log_batch, config.batchSize))
        status.log.append("")

        let totalSteps = config.numEpochs * 100
        status.totalSteps = totalSteps
        status.totalEpochs = config.numEpochs

        // 通过 fusion-mlx HTTP API 调用训练
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let url = URL(string: "\(FusionConfig.shared.mlxBaseURL)/v1/training/start")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = [
                    "model": config.modelName,
                    "method": config.method.rawValue,
                    "learning_rate": config.learningRate,
                    "num_epochs": config.numEpochs,
                    "batch_size": config.batchSize,
                    "lora_rank": config.loraRank,
                    "lora_alpha": config.loraAlpha,
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                request.timeoutInterval = 3600
                trainLogger.info("submit training: model=\(self.config.modelName, privacy: .public) method=\(self.config.method.rawValue, privacy: .public)")

                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse,
                   httpResp.statusCode == 200,
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let trainingId = json["training_id"] as? String ?? "unknown"
                    await MainActor.run {
                        self.status.log.append(I18nManager.shared.tf(.train_log_submitted, trainingId))
                        self.status.log.append(I18nManager.shared.t(.train_log_bg_started))
                        self.status.isRunning = false
                        let newCheckpoint = Checkpoint(name: "training-\(trainingId.prefix(8))", step: 0, loss: 0, date: Date(), size: I18nManager.shared.t(.train_ckpt_in_progress))
                        self.checkpoints.append(newCheckpoint)
                        self.objectWillChange.send()
                    }
                } else {
                    let errorBody = String(data: data, encoding: .utf8) ?? I18nManager.shared.t(.train_log_unknown_error)
                    await MainActor.run {
                        self.status.log.append(I18nManager.shared.tf(.train_log_mlx_error, errorBody))
                        self.status.isRunning = false
                        self.objectWillChange.send()
                    }
                }
            } catch {
                trainLogger.error("training API failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
                    self.status.log.append(I18nManager.shared.tf(.train_log_api_failed, error.localizedDescription))
                    self.status.log.append(I18nManager.shared.t(.train_log_ensure_mlx))
                    self.status.isRunning = false
                    self.objectWillChange.send()
                }
            }
        }
    }

    func stopTraining() {
        status.isRunning = false
        status.log.append(I18nManager.shared.t(.train_log_paused))
        objectWillChange.send()
    }

    func reset() {
        status = TrainingStatus()
        objectWillChange.send()
    }
}

// MARK: - 训练面板

struct TrainingView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var manager = TrainingManager.shared
    @State private var selectedTab: TrainingTab = .config

    enum TrainingTab: String, CaseIterable {
        case config
        case monitor
        case checkpoints
        case dataset

        var localizedName: String {
            switch self {
            case .config:      return I18nManager.shared.t(.train_tab_config)
            case .monitor:     return I18nManager.shared.t(.train_tab_monitor)
            case .checkpoints: return I18nManager.shared.t(.train_tab_checkpoints)
            case .dataset:     return I18nManager.shared.t(.train_tab_dataset)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(I18nManager.shared.t(.train_header), systemImage: "brain").font(.headline)
                Spacer()
                if manager.status.isRunning {
                    Button(I18nManager.shared.t(.train_btn_stop)) { manager.stopTraining() }
                        .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
                } else {
                    Button(I18nManager.shared.t(.train_btn_start)) { manager.startTraining() }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(TrainingTab.allCases, id: \.self) { tab in
                    Label(tab.localizedName, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented).padding(8)

            switch selectedTab {
            case .config:     TrainingConfigView()
            case .monitor:    TrainingMonitorView()
            case .checkpoints: CheckpointsView()
            case .dataset:    TrainingDatasetView()
            }
        }
    }

    private func tabIcon(_ tab: TrainingTab) -> String {
        switch tab {
        case .config: return "gearshape"; case .monitor: return "gauge.medium"
        case .checkpoints: return "clock.arrow.circlepath"; case .dataset: return "doc.text"
        }
    }
}

// MARK: - 训练配置

struct TrainingConfigView: View {
    @StateObject private var manager = TrainingManager.shared

    var body: some View {
        Form {
            Section(I18nManager.shared.t(.train_sec_model)) {
                Picker(I18nManager.shared.t(.train_label_base_model), selection: $manager.config.modelName) {
                    Text("qwen3.5-9b-4bit").tag("qwen3.5-9b-4bit")
                    Text("llama3-8b-4bit").tag("llama3-8b-4bit")
                    Text("deepseek-coder-6.7b-4bit").tag("deepseek-coder-6.7b-4bit")
                }
                Picker(I18nManager.shared.t(.train_label_method), selection: $manager.config.method) {
                    ForEach(TrainingConfig.TrainingMethod.allCases, id: \.self) { m in
                        Text(m.localizedName).tag(m)
                    }
                }
            }

            Section(I18nManager.shared.t(.train_sec_lora_params)) {
                Stepper(I18nManager.shared.tf(.train_label_rank, manager.config.loraRank), value: $manager.config.loraRank, in: 4...128, step: 4)
                HStack {
                    Text(I18nManager.shared.tf(.train_label_alpha, manager.config.loraAlpha))
                    Slider(value: $manager.config.loraAlpha, in: 8...128, step: 8)
                }
                HStack {
                    Text(I18nManager.shared.tf(.train_label_dropout, manager.config.loraDropout))
                    Slider(value: $manager.config.loraDropout, in: 0...0.5, step: 0.05)
                }
                Text(I18nManager.shared.tf(.train_label_target_modules, manager.config.targetModules.joined(separator: ", ")))
                    .font(.caption).foregroundColor(.secondary)
            }

            Section(I18nManager.shared.t(.train_sec_train_params)) {
                HStack {
                    Text(I18nManager.shared.tf(.train_label_lr, manager.config.learningRate))
                    Slider(value: $manager.config.learningRate, in: 1e-6...1e-3, step: 1e-6)
                }
                Stepper(I18nManager.shared.tf(.train_label_epochs, manager.config.numEpochs), value: $manager.config.numEpochs, in: 1...20)
                Picker(I18nManager.shared.t(.train_label_optimizer), selection: $manager.config.optimizer) {
                    ForEach(TrainingConfig.OptimizerType.allCases, id: \.self) { o in Text(o.rawValue).tag(o) }
                }
                Stepper(I18nManager.shared.tf(.train_label_batch_size, manager.config.batchSize), value: $manager.config.batchSize, in: 1...8)
                Stepper(I18nManager.shared.tf(.train_label_max_seq, manager.config.maxSeqLength), value: $manager.config.maxSeqLength, in: 256...8192, step: 256)
                Stepper(I18nManager.shared.tf(.train_label_warmup, manager.config.warmupSteps), value: $manager.config.warmupSteps, in: 0...1000, step: 50)
            }

            Section(I18nManager.shared.t(.train_sec_optimize)) {
                Toggle(I18nManager.shared.t(.train_toggle_quad), isOn: $manager.config.useQuad)
                Toggle(I18nManager.shared.t(.train_toggle_grad_ckpt), isOn: $manager.config.useGradientCheckpointing)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - 训练监控

struct TrainingMonitorView: View {
    @StateObject private var manager = TrainingManager.shared

    var body: some View {
        if !manager.status.isRunning && manager.status.log.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "gauge.medium").font(.system(size: 40)).foregroundColor(.secondary)
                Text(I18nManager.shared.t(.train_monitor_empty)).foregroundColor(.secondary)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                // 指标卡片
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                    MetricCard(title: I18nManager.shared.t(.train_metric_loss), value: String(format: "%.4f", manager.status.loss), unit: "", progress: 0.5, color: .blue)
                    MetricCard(title: I18nManager.shared.t(.train_metric_lr), value: String(format: "%.2e", manager.status.learningRate), unit: "", progress: 0.3, color: .green)
                    MetricCard(title: "Epoch", value: "\(manager.status.currentEpoch)", unit: "/\(manager.status.totalEpochs)", progress: Double(manager.status.currentEpoch) / Double(max(manager.status.totalEpochs, 1)), color: .orange)
                    MetricCard(title: "Step", value: "\(manager.status.currentStep)", unit: "/\(manager.status.totalSteps)", progress: Double(manager.status.currentStep) / Double(max(manager.status.totalSteps, 1)), color: .purple)
                    MetricCard(title: I18nManager.shared.t(.train_metric_elapsed), value: formatTime(manager.status.elapsedTime), unit: "", progress: 0.5, color: .pink)
                    MetricCard(title: I18nManager.shared.t(.train_metric_remaining), value: formatTime(manager.status.estimatedTimeRemaining), unit: "", progress: 0.5, color: .indigo)
                }
                .padding(8)

                // 进度条
                if manager.status.isRunning {
                    ProgressView(value: manager.status.progress)
                        .tint(.accentColor).padding(.horizontal)
                    Text("\(Int(manager.status.progress * 100))%").font(.caption).foregroundColor(.secondary)
                }

                Divider()

                // 日志
                GroupBox(I18nManager.shared.t(.train_log_title)) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(manager.status.log.indices, id: \.self) { i in
                                    Text(manager.status.log[i])
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(manager.status.log[i].hasPrefix("✅") ? .green : (manager.status.log[i].hasPrefix("⏸️") ? .orange : .secondary))
                                        .id(i)
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .onChange(of: manager.status.log.count) { _, _ in
                            withAnimation { proxy.scrollTo(manager.status.log.count - 1, anchor: .bottom) }
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600
        let m = Int(interval) / 60 % 60
        let s = Int(interval) % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}

// MARK: - 检查点

struct CheckpointsView: View {
    @StateObject private var manager = TrainingManager.shared

    var body: some View {
        if manager.checkpoints.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 40)).foregroundColor(.secondary)
                Text(I18nManager.shared.t(.train_ckpt_empty)).foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List {
                ForEach(manager.checkpoints.reversed()) { cp in
                    HStack(spacing: 10) {
                        Image(systemName: "checkpoint").foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cp.name).font(.headline)
                            Text("Step \(cp.step) · Loss: \(String(format: "%.4f", cp.loss))").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(cp.date, style: .time).font(.caption).foregroundColor(.secondary)
                            Text(cp.size).font(.caption2).foregroundColor(.secondary)
                        }
                        Button(I18nManager.shared.t(.train_btn_load)) { }.buttonStyle(.bordered).controlSize(.small)
                        Button(I18nManager.shared.t(.train_btn_export)) { }.buttonStyle(.bordered).controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - 数据集

struct TrainingDatasetView: View {
    @StateObject private var manager = TrainingManager.shared
    @State private var datasetFormat = "jsonl"
    @State private var datasetPath = ""

    let formats = ["jsonl", "csv", "txt", "alpaca", "sharegpt"]

    var body: some View {
        Form {
            Section(I18nManager.shared.t(.train_sec_dataset)) {
                HStack {
                    TextField(I18nManager.shared.t(.train_label_dataset_path), text: $datasetPath)
                        .textFieldStyle(.roundedBorder)
                    Button(I18nManager.shared.t(.train_btn_browse)) { }
                        .buttonStyle(.bordered)
                }
                Picker(I18nManager.shared.t(.train_label_format), selection: $datasetFormat) {
                    ForEach(formats, id: \.self) { f in Text(f.uppercased()).tag(f) }
                }
            }

            Section(I18nManager.shared.t(.train_sec_format_example)) {
                if datasetFormat == "jsonl" {
                    Text(I18nManager.shared.t(.train_sample_jsonl))
                        .font(.system(.caption, design: .monospaced))
                } else if datasetFormat == "alpaca" {
                    Text(I18nManager.shared.t(.train_sample_alpaca))
                        .font(.system(.caption, design: .monospaced))
                } else {
                    Text(I18nManager.shared.t(.train_sample_csv))
                        .font(.system(.caption, design: .monospaced))
                }
            }

            Section(I18nManager.shared.t(.train_sec_preprocess)) {
                Toggle(I18nManager.shared.t(.train_toggle_auto_convert), isOn: .constant(true))
                Toggle(I18nManager.shared.t(.train_toggle_dedup), isOn: .constant(true))
                Toggle(I18nManager.shared.t(.train_toggle_filter_long), isOn: .constant(true))
                Stepper(I18nManager.shared.tf(.train_label_max_length, manager.config.maxSeqLength), value: $manager.config.maxSeqLength, in: 256...8192, step: 256)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

// MARK: - 模型导出

struct ModelExportView: View {
    @State private var exportFormat = "mlx"
    @State private var exportQuant = "4bit"
    @State private var exportPath = ""
    @State private var isExporting = false
    @State private var progress: Double = 0

    let formats = ["mlx", "gguf", "safetensors", "coreml", "onnx"]
    let quants = ["2bit", "3bit", "4bit", "5bit", "6bit", "8bit", "fp16"]

    var body: some View {
        VStack(spacing: 16) {
            GroupBox(I18nManager.shared.t(.train_export_title)) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker(I18nManager.shared.t(.train_label_export_format), selection: $exportFormat) {
                        ForEach(formats, id: \.self) { f in Text(f.uppercased()).tag(f) }
                    }
                    Picker(I18nManager.shared.t(.train_label_quant), selection: $exportQuant) {
                        ForEach(quants, id: \.self) { q in Text(q).tag(q) }
                    }
                    HStack {
                        TextField(I18nManager.shared.t(.train_label_export_path), text: $exportPath)
                            .textFieldStyle(.roundedBorder)
                        Button(I18nManager.shared.t(.train_btn_browse)) { }
                            .buttonStyle(.bordered)
                    }
                    Button(action: startExport) {
                        Label(isExporting ? I18nManager.shared.t(.train_btn_exporting) : I18nManager.shared.t(.train_btn_start_export), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExporting || exportPath.isEmpty)

                    if isExporting {
                        ProgressView(value: progress)
                        Text("\(Int(progress * 100))%").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }
            .padding(.horizontal)

            GroupBox(I18nManager.shared.t(.train_export_supported)) {
                VStack(alignment: .leading, spacing: 4) {
                    ExportRow("MLX", I18nManager.shared.t(.train_export_mlx_desc))
                    ExportRow("GGUF", I18nManager.shared.t(.train_export_gguf_desc))
                    ExportRow("Core ML", I18nManager.shared.t(.train_export_coreml_desc))
                    ExportRow("ONNX", I18nManager.shared.t(.train_export_onnx_desc))
                    ExportRow("SafeTensors", I18nManager.shared.t(.train_export_safetensors_desc))
                }
                .padding(8)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }

    private func startExport() {
        isExporting = true
        progress = 0
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
            progress += Double.random(in: 0.05...0.1)
            if progress >= 1.0 { timer.invalidate(); isExporting = false; progress = 0 }
        }
    }
}

struct ExportRow: View {
    let name: String; let desc: String
    init(_ name: String, _ desc: String) { self.name = name; self.desc = desc }
    var body: some View {
        HStack {
            Text(name).font(.subheadline).fontWeight(.bold).frame(width: 80, alignment: .leading)
            Text(desc).font(.caption).foregroundColor(.secondary)
        }
    }
}
