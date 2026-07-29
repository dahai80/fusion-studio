// Callers: ModuleDetailView routing.
// Affected API: ModelHubView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

/// 模型元数据
struct ModelInfo: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var path: String
    var sizeGB: Double
    var quantization: String
    var format: String
    var family: String
    var parameters: String
    var isDownloaded: Bool
    var isActive: Bool
    var downloadProgress: Double
    var description: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        lhs.id == rhs.id
    }

    static let presets: [ModelInfo] = [
        ModelInfo(id: "qwen3.5-9b-4bit", name: "Qwen3.5 9B", path: "~/.fusion-mlx/models/qwen3.5-9b-4bit", sizeGB: 5.2, quantization: "4bit", format: "mlx", family: "Qwen", parameters: "9B", isDownloaded: false, isActive: false, downloadProgress: 0, description: "通义千问 3.5，9B 参数，4bit 量化，适合通用对话和代码生成"),
        ModelInfo(id: "llama3-8b-4bit", name: "Llama 3 8B", path: "~/.fusion-mlx/models/llama3-8b-4bit", sizeGB: 4.8, quantization: "4bit", format: "mlx", family: "Llama", parameters: "8B", isDownloaded: false, isActive: false, downloadProgress: 0, description: "Meta Llama 3，8B 参数，4bit 量化，高质量通用模型"),
        ModelInfo(id: "deepseek-coder-6.7b-4bit", name: "DeepSeek Coder 6.7B", path: "~/.fusion-mlx/models/deepseek-coder-6.7b-4bit", sizeGB: 3.9, quantization: "4bit", format: "mlx", family: "DeepSeek", parameters: "6.7B", isDownloaded: false, isActive: false, downloadProgress: 0, description: "DeepSeek 代码专用模型，6.7B 参数，4bit 量化"),
        ModelInfo(id: "qwen2-vl-7b-4bit", name: "Qwen2-VL 7B", path: "~/.fusion-mlx/models/qwen2-vl-7b-4bit", sizeGB: 4.2, quantization: "4bit", format: "mlx", family: "Qwen", parameters: "7B", isDownloaded: false, isActive: false, downloadProgress: 0, description: "Qwen2 视觉语言模型，支持图像理解"),
        ModelInfo(id: "sd3.5-medium", name: "Stable Diffusion 3.5", path: "~/.fusion-mlx/models/sd3.5-medium", sizeGB: 6.5, quantization: "fp16", format: "mlx", family: "Stable Diffusion", parameters: "2.5B", isDownloaded: false, isActive: false, downloadProgress: 0, description: "文生图模型，支持 txt2img / img2img"),
    ]
}

// MARK: - 主视图

struct ModelHubView: View {
    @Environment(\.studioTheme) private var theme
    @State private var models: [ModelInfo] = ModelInfo.presets
    @State private var selectedModel: ModelInfo?
    @State private var searchText = ""
    @State private var selectedFamily: String = "全部"
    @State private var showDownloadSheet = false
    @State private var isRefreshing = false

    var filteredModels: [ModelInfo] {
        var result = models
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if selectedFamily != "全部" {
            result = result.filter { $0.family == selectedFamily }
        }
        return result
    }

    var families: [String] {
        ["全部"] + Set(models.map(\.family)).sorted()
    }

    var body: some View {
        HSplitView {
            // 左侧：模型列表
            VStack(spacing: 0) {
                UpstreamServiceStatusBanner(serviceId: "fusion-model-hub")
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索模型...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(theme.surfaceSecondary)

                Divider()

                // 分类筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(families, id: \.self) { family in
                            let isSelected = selectedFamily == family
                            Button(family) {
                                selectedFamily = family
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(isSelected ? Color.accentColor : nil)
                        }
                    }
                    .padding(8)
                }

                Divider()

                // 模型列表
                List(filteredModels, selection: $selectedModel) { model in
                    ModelRow(model: model)
                        .tag(model)
                        .onTapGesture { selectedModel = model }
                }
                .listStyle(.plain)
            }
            .frame(minWidth: 280, maxWidth: 350)

            // 右侧：详情面板
            if let model = selectedModel {
                ModelDetailView(
                    model: Binding(
                        get: { model },
                        set: { newValue in
                            if let idx = models.firstIndex(where: { $0.id == model.id }) {
                                models[idx] = newValue
                            }
                        }
                    ),
                    onDelete: { deleteModel(model) },
                    onActivate: { activateModel(model) }
                )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "cpu")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("选择一个模型查看详情")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { showDownloadSheet = true }) {
                    Label("下载模型", systemImage: "icloud.and.arrow.down")
                }

                Button(action: refreshModels) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .sheet(isPresented: $showDownloadSheet) {
            DownloadModelView { model in
                models.append(model)
            }
        }
    }

    private func refreshModels() {
        isRefreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isRefreshing = false
        }
    }

    private func deleteModel(_ model: ModelInfo) {
        models.removeAll { $0.id == model.id }
        if selectedModel?.id == model.id {
            selectedModel = models.first
        }
    }

    private func activateModel(_ model: ModelInfo) {
        for idx in models.indices {
            models[idx].isActive = models[idx].id == model.id
        }
    }
}

// MARK: - 模型行

struct ModelRow: View {
    let model: ModelInfo

    var body: some View {
        HStack(spacing: 10) {
            // 状态指示
            VStack(spacing: 2) {
                Circle()
                    .fill(model.isActive ? Color.green : (model.isDownloaded ? Color.blue : Color.gray))
                    .frame(width: 8, height: 8)
                Text(model.isActive ? "活跃" : (model.isDownloaded ? "就绪" : "未下载"))
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(model.family)
                        .font(.caption)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(3)
                    Text(model.parameters)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(model.quantization.uppercased())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if model.isDownloaded {
                    Text("\(String(format: "%.1f", model.sizeGB)) GB")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if model.downloadProgress > 0 {
                    ProgressView(value: model.downloadProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 100)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 模型详情

struct ModelDetailView: View {
    @Binding var model: ModelInfo
    let onDelete: () -> Void
    let onActivate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 头部
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(model.name)
                            .font(.largeTitle)
                            .bold()
                        Spacer()
                        if model.isActive {
                            Label("当前使用", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }

                    HStack(spacing: 12) {
                        Label(model.family, systemImage: "cube")
                        Label(model.parameters, systemImage: "brain")
                        Label(model.quantization.uppercased(), systemImage: "dial.medium")
                        Label(model.format.uppercased(), systemImage: "doc")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Divider()

                // 操作按钮
                HStack(spacing: 12) {
                    if !model.isDownloaded {
                        Button(action: startDownload) {
                            Label("下载", systemImage: "icloud.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if model.isDownloaded && !model.isActive {
                        Button(action: onActivate) {
                            Label("激活", systemImage: "play.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button(action: onDelete) {
                        Label("删除", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                // 下载进度
                if model.downloadProgress > 0 && model.downloadProgress < 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: model.downloadProgress)
                        Text("下载中... \(Int(model.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                // 基本信息
                GroupBox("基本信息") {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow("模型 ID", model.id)
                        DetailRow("路径", model.path)
                        DetailRow("大小", "\(String(format: "%.1f", model.sizeGB)) GB")
                        DetailRow("格式", model.format.uppercased())
                        DetailRow("量化", model.quantization)
                        DetailRow("家族", model.family)
                        DetailRow("参数", model.parameters)
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                // 描述
                GroupBox("描述") {
                    Text(model.description)
                        .font(.body)
                        .padding(8)
                }
                .padding(.horizontal)

                // 量化选项
                GroupBox("量化选项") {
                    VStack(spacing: 8) {
                        QuantOptionRow("2bit", "极端压缩，适合 8GB 设备", "2.6 GB", model.quantization == "2bit")
                        QuantOptionRow("3bit", "平衡压缩", "3.9 GB", model.quantization == "3bit")
                        QuantOptionRow("4bit", "推荐，精度与性能最佳平衡", "5.2 GB", model.quantization == "4bit")
                        QuantOptionRow("8bit", "高精度，需要 32GB+ 内存", "10.4 GB", model.quantization == "8bit")
                        QuantOptionRow("fp16", "最高精度，需要 64GB+ 内存", "20.8 GB", model.quantization == "fp16")
                    }
                    .padding(8)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func startDownload() {
        model.downloadProgress = 0.01
        // 模拟下载进度
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if model.downloadProgress >= 1.0 {
                model.isDownloaded = true
                model.downloadProgress = 0
                timer.invalidate()
            } else {
                model.downloadProgress += Double.random(in: 0.02...0.08)
            }
        }
        // 保存 timer 引用（需在 struct 中添加 @State 持有）
        _ = timer
    }
}



struct QuantOptionRow: View {
    let name: String
    let description: String
    let size: String
    let isSelected: Bool

    init(_ name: String, _ description: String, _ size: String, _ isSelected: Bool) {
        self.name = name
        self.description = description
        self.size = size
        self.isSelected = isSelected
    }

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .regular)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(size)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - 下载模型对话框

struct DownloadModelView: View {
    @Environment(\.dismiss) var dismiss
    @State private var modelURL = ""
    @State private var modelName = ""
    @State private var selectedPreset = ""
    let onDownload: (ModelInfo) -> Void

    let presets = [
        ("qwen3.5-9b-4bit", "Qwen3.5 9B (4bit) - 5.2 GB"),
        ("llama3-8b-4bit", "Llama 3 8B (4bit) - 4.8 GB"),
        ("deepseek-coder-6.7b-4bit", "DeepSeek Coder 6.7B (4bit) - 3.9 GB"),
        ("qwen2-vl-7b-4bit", "Qwen2-VL 7B (4bit) - 4.2 GB"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("下载模型")
                .font(.title2)
                .bold()

            Picker("预设模型", selection: $selectedPreset) {
                Text("选择预设...").tag("")
                ForEach(presets, id: \.0) { id, name in
                    Text(name).tag(id)
                }
            }
            .onChange(of: selectedPreset) { newValue in
                if !newValue.isEmpty {
                    modelName = newValue
                }
            }

            Divider()
                .frame(width: 300)

            TextField("或输入模型名称", text: $modelName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)
                Button("下载") {
                    let model = ModelInfo(
                        id: modelName.lowercased().replacingOccurrences(of: " ", with: "-"),
                        name: modelName,
                        path: "~/.fusion-mlx/models/\(modelName.lowercased())",
                        sizeGB: 0,
                        quantization: "4bit",
                        format: "mlx",
                        family: "Unknown",
                        parameters: "?",
                        isDownloaded: false,
                        isActive: false,
                        downloadProgress: 0.01,
                        description: "正在下载..."
                    )
                    onDownload(model)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(modelName.isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}
