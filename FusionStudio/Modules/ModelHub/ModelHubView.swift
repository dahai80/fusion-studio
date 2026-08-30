// Callers: ModuleDetailView routing.
// Affected API: MlxHTTPClient (listModels/listHFTasks/getHFRecommended/startHFDownload/searchHFModels).
// Data schemas: ModelInfo, ModelDTO, HFTaskDTO, HFModelInfo.

import SwiftUI
import os.log

private let hubLog = Logger(subsystem: "com.fusion.studio", category: "ModelHub")

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
    var hfRepoId: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        lhs.id == rhs.id
    }

    static func from(dto: ModelDTO, activeModelId: String?) -> ModelInfo {
        let sizeGB = Double(dto.estimatedSize ?? 0) / 1_073_741_824.0
        let name = dto.displayName ?? dto.id
        let family = extractFamily(from: name)
        let params = extractParams(from: name)
        let quant = extractQuant(from: name)
        return ModelInfo(
            id: dto.id,
            name: name,
            path: dto.modelPath ?? "",
            sizeGB: sizeGB,
            quantization: quant,
            format: "mlx",
            family: family,
            parameters: params,
            isDownloaded: true,
            isActive: dto.id == activeModelId || dto.isDefault == true,
            downloadProgress: 0,
            description: "\(name) — \(dto.engineType ?? "text") model",
            hfRepoId: dto.id
        )
    }

    static func from(hf: HFModelInfo) -> ModelInfo {
        let sizeGB = Double(hf.size ?? 0) / 1_073_741_824.0
        let name = hf.name ?? hf.repoId
        let family = extractFamily(from: name)
        let params = hf.paramsFormatted ?? extractParams(from: name)
        return ModelInfo(
            id: hf.repoId,
            name: name,
            path: "",
            sizeGB: sizeGB,
            quantization: extractQuant(from: hf.repoId),
            format: "mlx",
            family: family,
            parameters: params,
            isDownloaded: false,
            isActive: false,
            downloadProgress: 0,
            description: hf.sizeFormatted ?? "HuggingFace model",
            hfRepoId: hf.repoId
        )
    }

    static let presets: [ModelInfo] = [
        ModelInfo(id: "qwen3.5-9b-4bit", name: "Qwen3.5 9B", path: "", sizeGB: 5.2, quantization: "4bit", format: "mlx", family: "Qwen", parameters: "9B", isDownloaded: false, isActive: false, downloadProgress: 0, description: "hub_mv_descQwen35", hfRepoId: "mlx-community/Qwen3.5-9B-4bit"),
        ModelInfo(id: "llama3-8b-4bit", name: "Llama 3 8B", path: "", sizeGB: 4.8, quantization: "4bit", format: "mlx", family: "Llama", parameters: "8B", isDownloaded: false, isActive: false, downloadProgress: 0, description: "hub_mv_descLlama3", hfRepoId: "mlx-community/Meta-Llama-3-8B-Instruct-4bit"),
        ModelInfo(id: "deepseek-coder-6.7b-4bit", name: "DeepSeek Coder 6.7B", path: "", sizeGB: 3.9, quantization: "4bit", format: "mlx", family: "DeepSeek", parameters: "6.7B", isDownloaded: false, isActive: false, downloadProgress: 0, description: "hub_mv_descDeepseek", hfRepoId: "mlx-community/deepseek-coder-6.7b-instruct-4bit"),
        ModelInfo(id: "qwen2-vl-7b-4bit", name: "Qwen2-VL 7B", path: "", sizeGB: 4.2, quantization: "4bit", format: "mlx", family: "Qwen", parameters: "7B", isDownloaded: false, isActive: false, downloadProgress: 0, description: "hub_mv_descQwenVL", hfRepoId: "mlx-community/Qwen2-VL-7B-Instruct-4bit"),
    ]

    private static func extractFamily(from name: String) -> String {
        let n = name.lowercased()
        if n.contains("qwen") { return "Qwen" }
        if n.contains("llama") { return "Llama" }
        if n.contains("deepseek") { return "DeepSeek" }
        if n.contains("mistral") || n.contains("mixtral") { return "Mistral" }
        if n.contains("phi") { return "Phi" }
        if n.contains("gemma") { return "Gemma" }
        if n.contains("stable-diffusion") || n.contains("sd3") { return "Stable Diffusion" }
        if n.contains("flux") { return "Flux" }
        return "Other"
    }

    private static func extractParams(from name: String) -> String {
        let patterns = [#"(\d+\.?\d*[Bb])"#]
        for p in patterns {
            if let range = name.range(of: p, options: .regularExpression) {
                return String(name[range]).uppercased()
            }
        }
        return "?"
    }

    private static func extractQuant(from name: String) -> String {
        let n = name.lowercased()
        if n.contains("fp16") || n.contains("f16") { return "fp16" }
        if n.contains("8bit") || n.contains("-8b") { return "8bit" }
        if n.contains("4bit") || n.contains("-4b") { return "4bit" }
        if n.contains("3bit") || n.contains("-3b") { return "3bit" }
        if n.contains("2bit") || n.contains("-2b") { return "2bit" }
        return "4bit"
    }
}

// MARK: - 主视图

struct ModelHubView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @EnvironmentObject private var config: FusionConfig
    @EnvironmentObject private var agentBridge: AgentBridge
    @State private var models: [ModelInfo] = []
    @State private var selectedModel: ModelInfo?
    @State private var searchText = ""
    @State private var selectedFamily: String = "全部"
    @State private var showDownloadSheet = false
    @State private var isRefreshing = false
    @State private var pollTimer: Timer?
    @State private var lastError: String?

    private var activeModelId: String? {
        config.mlxModel.isEmpty ? nil : config.mlxModel
    }

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
            VStack(spacing: 0) {
                UpstreamServiceStatusBanner(serviceId: "fusion-model-hub")
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(i18n.t(.hub_mv_searchPlaceholder), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(theme.surfaceSecondary)

                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(families, id: \.self) { family in
                            let isSelected = selectedFamily == family
                            Button(family == "全部" ? i18n.t(.hub_mv_catAll) : family) {
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

                if models.isEmpty && isRefreshing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading models...")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredModels, selection: $selectedModel) { model in
                        ModelRow(model: model)
                            .tag(model)
                            .onTapGesture { selectedModel = model }
                    }
                    .listStyle(.plain)
                }

                if let error = lastError {
                    Text(error)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
            .frame(minWidth: 280, maxWidth: 350)

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
                    Text(i18n.t(.hub_mv_selectModelHint))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { showDownloadSheet = true }) {
                    Label(i18n.t(.hub_mv_downloadModel), systemImage: "icloud.and.arrow.down")
                }
                Button(action: refreshModels) {
                    Label(i18n.t(.hub_mv_refresh), systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .sheet(isPresented: $showDownloadSheet) {
            DownloadModelView(onDownload: { repoId in
                startHFDownload(repoId: repoId)
            })
        }
        .onAppear {
            refreshModels()
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    private func refreshModels() {
        isRefreshing = true
        lastError = nil
        Task { @MainActor in
            do {
                let client = MlxHTTPClient(config: config)
                let resp = try await client.listModels()
                var loaded: [ModelInfo] = []
                for dto in resp.models {
                    loaded.append(ModelInfo.from(dto: dto, activeModelId: activeModelId))
                }
                hubLog.info("Loaded \(loaded.count) models from fusion-mlx")

                let hfResp = try await client.getHFRecommended(mlxOnly: true)
                var recommended: [ModelInfo] = []
                let loadedIds = Set(loaded.map(\.id))
                for hf in hfResp.trending + hfResp.popular {
                    guard !loadedIds.contains(hf.repoId) else { continue }
                    recommended.append(ModelInfo.from(hf: hf))
                }
                hubLog.info("Loaded \(recommended.count) recommended HF models")

                models = loaded + recommended
                if selectedModel == nil { selectedModel = models.first }
            } catch {
                hubLog.warning("Failed to fetch from API: \(error.localizedDescription), using presets")
                if models.isEmpty {
                    models = ModelInfo.presets
                }
                lastError = "API unavailable — showing offline models"
            }
            isRefreshing = false
        }
    }

    private func startHFDownload(repoId: String) {
        Task { @MainActor in
            do {
                let client = MlxHTTPClient(config: config)
                let resp = try await client.startHFDownload(repoId: repoId)
                if resp.success, let task = resp.task {
                    hubLog.info("Started HF download: \(task.taskId) for \(repoId)")
                    if let idx = models.firstIndex(where: { $0.hfRepoId == repoId }) {
                        models[idx].downloadProgress = 0.01
                    }
                }
            } catch {
                hubLog.error("HF download failed: \(error.localizedDescription)")
                lastError = "Download failed: \(error.localizedDescription)"
            }
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                await pollDownloadProgress()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollDownloadProgress() async {
        let downloading = models.filter { $0.downloadProgress > 0 && !$0.isDownloaded }
        guard !downloading.isEmpty else { return }
        do {
            let client = MlxHTTPClient(config: config)
            let resp = try await client.listHFTasks()
            let taskMap = Dictionary(uniqueKeysWithValues: resp.tasks.map { ($0.repoId, $0) })
            for i in models.indices {
                guard models[i].downloadProgress > 0, !models[i].isDownloaded else { continue }
                if let task = taskMap[models[i].hfRepoId] {
                    models[i].downloadProgress = task.progress
                    if task.statusEnum == .completed {
                        models[i].isDownloaded = true
                        models[i].downloadProgress = 0
                        hubLog.info("Download completed: \(models[i].name)")
                    } else if task.statusEnum == .failed {
                        models[i].downloadProgress = 0
                        lastError = "Download failed: \(models[i].name)"
                    }
                }
            }
        } catch {
            hubLog.debug("Poll download progress failed: \(error.localizedDescription)")
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
        config.mlxModel = model.id
        Task { @MainActor in
            do {
                _ = try await agentBridge.mlxSetModel(model: model.id)
                hubLog.info("Activated model: \(model.id)")
            } catch {
                hubLog.error("Failed to set model via IPC: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 模型行

struct ModelRow: View {
    let model: ModelInfo
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 2) {
                Circle()
                    .fill(model.isActive ? Color.green : (model.isDownloaded ? Color.blue : Color.gray))
                    .frame(width: 8, height: 8)
                Text(model.isActive ? i18n.t(.hub_mv_active) : (model.isDownloaded ? i18n.t(.hub_mv_ready) : i18n.t(.hub_mv_notDownloaded)))
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
                    Text(model.quantization.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if model.isDownloaded && model.sizeGB > 0 {
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
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(model.name)
                            .font(.largeTitle)
                            .bold()
                        Spacer()
                        if model.isActive {
                            Label(i18n.t(.hub_mv_currentUse), systemImage: "checkmark.circle.fill")
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

                HStack(spacing: 12) {
                    if !model.isDownloaded && model.downloadProgress == 0 {
                        Button(action: { onDelete() }) {
                            Label(i18n.t(.hub_mv_download), systemImage: "icloud.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if model.isDownloaded && !model.isActive {
                        Button(action: onActivate) {
                            Label(i18n.t(.hub_mv_activate), systemImage: "play.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if model.isDownloaded {
                        Button(action: onDelete) {
                            Label(i18n.t(.delete), systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)

                if model.downloadProgress > 0 && model.downloadProgress < 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: model.downloadProgress)
                        Text(String(format: i18n.t(.hub_mv_downloadingFmt), Int(model.downloadProgress * 100)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                GroupBox(i18n.t(.hub_mv_basicInfo)) {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(i18n.t(.hub_mv_modelId), model.id)
                        if !model.path.isEmpty {
                            DetailRow(i18n.t(.hub_mv_path), model.path)
                        }
                        if model.sizeGB > 0 {
                            DetailRow(i18n.t(.hub_mv_size), "\(String(format: "%.1f", model.sizeGB)) GB")
                        }
                        DetailRow(i18n.t(.hub_mv_format), model.format.uppercased())
                        DetailRow(i18n.t(.hub_mv_quant), model.quantization)
                        DetailRow(i18n.t(.hub_mv_family), model.family)
                        DetailRow(i18n.t(.hub_mv_params), model.parameters)
                        if !model.hfRepoId.isEmpty {
                            DetailRow("HF Repo", model.hfRepoId)
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                if !model.description.isEmpty {
                    GroupBox(i18n.t(.hub_mv_description)) {
                        Text(localizedDescription(model.description))
                            .font(.body)
                            .padding(8)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func localizedDescription(_ s: String) -> String {
        if s.hasPrefix("hub_"), let key = I18nKey(rawValue: s) {
            return i18n.t(key)
        }
        return s
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
    @EnvironmentObject private var config: FusionConfig
    @Environment(\.dismiss) var dismiss
    @StateObject private var i18n = I18nManager.shared
    @State private var repoId = ""
    @State private var hfToken = ""
    @State private var searchQuery = ""
    @State private var searchResults: [HFModelInfo] = []
    @State private var isSearching = false
    @State private var recommended: [HFModelInfo] = []
    @State private var isLoadingRecommended = false
    let onDownload: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(i18n.t(.hub_mv_downloadModel))
                .font(.title2)
                .bold()

            HStack {
                TextField(i18n.t(.hub_mv_searchHF), text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { searchHF() }
                Button(i18n.t(.hub_mv_search)) { searchHF() }
                    .buttonStyle(.bordered)
                    .disabled(searchQuery.isEmpty || isSearching)
            }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            }

            if !searchResults.isEmpty {
                List(searchResults, id: \.repoId) { hf in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hf.name ?? hf.repoId)
                                .font(.system(size: 13, weight: .medium))
                            HStack(spacing: 8) {
                                if let sz = hf.sizeFormatted {
                                    Text(sz).font(.caption).foregroundColor(.secondary)
                                }
                                if let dl = hf.downloads {
                                    Text("\(dl) downloads").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Button(i18n.t(.hub_mv_download)) {
                            onDownload(hf.repoId)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .frame(minHeight: 120, maxHeight: 200)
            }

            Divider()

            if !recommended.isEmpty {
                Text(i18n.t(.hub_mv_recommended))
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                List(recommended.prefix(5), id: \.repoId) { hf in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hf.name ?? hf.repoId)
                                .font(.system(size: 13, weight: .medium))
                            if let sz = hf.sizeFormatted {
                                Text(sz).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button(i18n.t(.hub_mv_download)) {
                            onDownload(hf.repoId)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .frame(minHeight: 80, maxHeight: 160)
            } else if isLoadingRecommended {
                ProgressView()
                    .controlSize(.small)
            }

            Divider()

            TextField(i18n.t(.hub_mv_repoIdHint), text: $repoId)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

            SecureField(i18n.t(.hub_mv_hfTokenOptional), text: $hfToken)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button(i18n.t(.cancel)) { dismiss() }
                    .buttonStyle(.bordered)
                Button(i18n.t(.hub_mv_download)) {
                    onDownload(repoId)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(repoId.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
        .onAppear {
            loadRecommended()
        }
    }

    private func searchHF() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        Task { @MainActor in
            do {
                let client = MlxHTTPClient(config: config)
                let resp = try await client.searchHFModels(query: searchQuery, limit: 10)
                searchResults = resp.models
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }

    private func loadRecommended() {
        isLoadingRecommended = true
        Task { @MainActor in
            do {
                let client = MlxHTTPClient(config: config)
                let resp = try await client.getHFRecommended(mlxOnly: true)
                var seen = Set<String>()
                var deduped: [HFModelInfo] = []
                for hf in resp.trending + resp.popular {
                    if seen.insert(hf.repoId).inserted { deduped.append(hf) }
                }
                recommended = Array(deduped.prefix(10))
            } catch {
                recommended = []
            }
            isLoadingRecommended = false
        }
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
