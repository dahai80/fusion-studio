import SwiftUI

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
        case lora  = "LoRA"
        case qlora = "QLoRA"
        case full  = "全量微调"
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
        status.log = ["开始训练..."]
        status.log.append(" 模型: \(config.modelName)")
        status.log.append(" 方法: \(config.method.rawValue)")
        status.log.append(" 学习率: \(config.learningRate)")
        status.log.append(" Epochs: \(config.numEpochs)")
        status.log.append(" Batch: \(config.batchSize)")
        status.log.append("")

        let totalSteps = config.numEpochs * 100
        status.totalSteps = totalSteps
        status.totalEpochs = config.numEpochs
        let start = Date()

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.status.currentStep += 1
            self.status.progress = Double(self.status.currentStep) / Double(totalSteps)
            self.status.currentEpoch = min(self.status.currentStep / 100 + 1, self.config.numEpochs)
            self.status.loss = Double.random(in: 0.1...0.8) * (1 - self.status.progress * 0.5)
            self.status.learningRate = self.config.learningRate * (1 - self.status.progress * 0.9)
            self.status.elapsedTime = Date().timeIntervalSince(start)
            self.status.estimatedTimeRemaining = self.status.elapsedTime / max(self.status.progress, 0.01) - self.status.elapsedTime

            if self.status.currentStep % 10 == 0 {
                self.status.log.append("Step \(self.status.currentStep)/\(totalSteps): loss=\(String(format: "%.4f", self.status.loss)) lr=\(String(format: "%.6f", self.status.learningRate))")
            }

            if self.status.currentStep >= totalSteps {
                timer.invalidate()
                self.status.log.append("")
                self.status.log.append("✅ 训练完成!")
                let newCheckpoint = Checkpoint(name: "checkpoint-\(self.status.currentStep)", step: self.status.currentStep, loss: self.status.loss, date: Date(), size: "45 MB")
                self.checkpoints.append(newCheckpoint)
                self.status.isRunning = false
                self.objectWillChange.send()
            }
        }
    }

    func stopTraining() {
        status.isRunning = false
        status.log.append("⏸️ 训练已暂停")
        objectWillChange.send()
    }

    func reset() {
        status = TrainingStatus()
        objectWillChange.send()
    }
}

// MARK: - 训练面板

struct TrainingView: View {
    @StateObject private var manager = TrainingManager.shared
    @State private var selectedTab: TrainingTab = .config

    enum TrainingTab: String, CaseIterable {
        case config     = "训练配置"
        case monitor    = "训练监控"
        case checkpoints = "检查点"
        case dataset    = "数据集"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("模型训练", systemImage: "brain").font(.headline)
                Spacer()
                if manager.status.isRunning {
                    Button("停止训练") { manager.stopTraining() }
                        .buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
                } else {
                    Button("开始训练") { manager.startTraining() }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(TrainingTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
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
            Section("模型") {
                Picker("基础模型", selection: $manager.config.modelName) {
                    Text("qwen3.5-9b-4bit").tag("qwen3.5-9b-4bit")
                    Text("llama3-8b-4bit").tag("llama3-8b-4bit")
                    Text("deepseek-coder-6.7b-4bit").tag("deepseek-coder-6.7b-4bit")
                }
                Picker("训练方法", selection: $manager.config.method) {
                    ForEach(TrainingConfig.TrainingMethod.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
            }

            Section("LoRA 参数") {
                Stepper("Rank: \(manager.config.loraRank)", value: $manager.config.loraRank, in: 4...128, step: 4)
                HStack {
                    Text("Alpha: \(String(format: "%.0f", manager.config.loraAlpha))")
                    Slider(value: $manager.config.loraAlpha, in: 8...128, step: 8)
                }
                HStack {
                    Text("Dropout: \(String(format: "%.2f", manager.config.loraDropout))")
                    Slider(value: $manager.config.loraDropout, in: 0...0.5, step: 0.05)
                }
                Text("目标模块: \(manager.config.targetModules.joined(separator: ", "))")
                    .font(.caption).foregroundColor(.secondary)
            }

            Section("训练参数") {
                HStack {
                    Text("学习率: \(String(format: "%.0e", manager.config.learningRate))")
                    Slider(value: $manager.config.learningRate, in: 1e-6...1e-3, step: 1e-6)
                }
                Stepper("Epochs: \(manager.config.numEpochs)", value: $manager.config.numEpochs, in: 1...20)
                Picker("优化器", selection: $manager.config.optimizer) {
                    ForEach(TrainingConfig.OptimizerType.allCases, id: \.self) { o in Text(o.rawValue).tag(o) }
                }
                Stepper("Batch Size: \(manager.config.batchSize)", value: $manager.config.batchSize, in: 1...8)
                Stepper("最大序列长度: \(manager.config.maxSeqLength)", value: $manager.config.maxSeqLength, in: 256...8192, step: 256)
                Stepper("Warmup Steps: \(manager.config.warmupSteps)", value: $manager.config.warmupSteps, in: 0...1000, step: 50)
            }

            Section("优化") {
                Toggle("4bit 量化训练 (QLoRA)", isOn: $manager.config.useQuad)
                Toggle("梯度检查点", isOn: $manager.config.useGradientCheckpointing)
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
                Text("配置训练参数并开始训练").foregroundColor(.secondary)
                Spacer()
            }
        } else {
            VStack(spacing: 0) {
                // 指标卡片
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                    MetricCard(title: "损失", value: String(format: "%.4f", manager.status.loss), unit: "", progress: 0.5, color: .blue)
                    MetricCard(title: "学习率", value: String(format: "%.2e", manager.status.learningRate), unit: "", progress: 0.3, color: .green)
                    MetricCard(title: "Epoch", value: "\(manager.status.currentEpoch)", unit: "/\(manager.status.totalEpochs)", progress: Double(manager.status.currentEpoch) / Double(max(manager.status.totalEpochs, 1)), color: .orange)
                    MetricCard(title: "Step", value: "\(manager.status.currentStep)", unit: "/\(manager.status.totalSteps)", progress: Double(manager.status.currentStep) / Double(max(manager.status.totalSteps, 1)), color: .purple)
                    MetricCard(title: "已用时间", value: formatTime(manager.status.elapsedTime), unit: "", progress: 0.5, color: .pink)
                    MetricCard(title: "预计剩余", value: formatTime(manager.status.estimatedTimeRemaining), unit: "", progress: 0.5, color: .indigo)
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
                GroupBox("训练日志") {
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
                Text("训练完成后将自动保存检查点").foregroundColor(.secondary)
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
                        Button("加载") { }.buttonStyle(.bordered).controlSize(.small)
                        Button("导出") { }.buttonStyle(.bordered).controlSize(.small)
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
            Section("数据集") {
                HStack {
                    TextField("数据集路径", text: $datasetPath)
                        .textFieldStyle(.roundedBorder)
                    Button("浏览") { }
                        .buttonStyle(.bordered)
                }
                Picker("格式", selection: $datasetFormat) {
                    ForEach(formats, id: \.self) { f in Text(f.uppercased()).tag(f) }
                }
            }

            Section("格式示例") {
                if datasetFormat == "jsonl" {
                    Text("""
                    {"prompt": "你好", "completion": "你好！有什么可以帮助你的吗？"}
                    {"prompt": "什么是 MLX？", "completion": "MLX 是 Apple 的机器学习框架..."}
                    """).font(.system(.caption, design: .monospaced))
                } else if datasetFormat == "alpaca" {
                    Text("""
                    {"instruction": "解释什么是机器学习", "input": "", "output": "机器学习是 AI 的一个分支..."}
                    """).font(.system(.caption, design: .monospaced))
                } else {
                    Text("CSV 格式: prompt,completion\n你好,你好！有什么可以帮助你的吗？")
                        .font(.system(.caption, design: .monospaced))
                }
            }

            Section("数据预处理") {
                Toggle("自动格式转换", isOn: .constant(true))
                Toggle("数据去重", isOn: .constant(true))
                Toggle("过滤过长样本", isOn: .constant(true))
                Stepper("最大长度: \(manager.config.maxSeqLength)", value: $manager.config.maxSeqLength, in: 256...8192, step: 256)
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
            GroupBox("导出模型") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("导出格式", selection: $exportFormat) {
                        ForEach(formats, id: \.self) { f in Text(f.uppercased()).tag(f) }
                    }
                    Picker("量化精度", selection: $exportQuant) {
                        ForEach(quants, id: \.self) { q in Text(q).tag(q) }
                    }
                    HStack {
                        TextField("导出路径", text: $exportPath)
                            .textFieldStyle(.roundedBorder)
                        Button("浏览") { }
                            .buttonStyle(.bordered)
                    }
                    Button(action: startExport) {
                        Label(isExporting ? "导出中..." : "开始导出", systemImage: "square.and.arrow.up")
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

            GroupBox("支持的导出格式") {
                VStack(alignment: .leading, spacing: 4) {
                    ExportRow("MLX", "Apple Silicon 原生格式，推理最快")
                    ExportRow("GGUF", "llama.cpp 兼容格式，跨平台")
                    ExportRow("Core ML", "Apple 端侧推理格式，适配 iOS")
                    ExportRow("ONNX", "开放神经网络交换格式")
                    ExportRow("SafeTensors", "安全张量格式")
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