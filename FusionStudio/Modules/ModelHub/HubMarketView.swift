// Callers: ModelHubMainView contentArea switch on .market.
// Affected API: ModelHubAPIClient searchMarket/createDownload.
// Data schemas: HubMarketSearchResponse, HubMarketModel, HubDownloadTaskResponse.
// PRD: Market + "设为RAG默认嵌入模型" + param-size/MLX-only filters
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let marketLog = Logger(subsystem: "com.fusion.studio", category: "HubMarket")

struct HubMarketView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var searchText = ""
    @State private var searchResults: [HubMarketModel] = []
    @State private var isSearching = false
    @State private var selectedSource: String = "all"
    @State private var selectedTask: String = "all"
    @State private var selectedFormat: String = "all"
    @State private var selectedParamSize: String = "all"
    @State private var mlxOnly = false
    @State private var localOnly = false
    @State private var selectedModel: HubMarketModel?
    @State private var downloadingIds: Set<String> = []
    @State private var lastError: String?
    @State private var ragDefaultId: String?
    @State private var currentPage = 1
    @State private var totalResults = 0
    @State private var ratingSummaries: [String: HubRatingSummaryResponse] = [:]

    private let sources = ["all", "huggingface", "modelscope", "local", "private"]
    private let tasks = ["all", "text-generation", "code", "vision", "embedding", "audio", "multimodal"]
    private let formats = ["all", "mlx", "safetensors", "gguf", "onnx"]
    private let paramSizes = [
        ("all", "all"),
        ("tiny", "< 1B"),
        ("small", "1B-7B"),
        ("medium", "7B-13B"),
        ("large", "13B-70B"),
        ("xlarge", "> 70B"),
    ]

    private func paramSizeLabel(_ id: String) -> String {
        if id == "all" { return i18n.t(.hub_mkt_paramSizeAll) }
        return paramSizes.first(where: { $0.0 == id })?.1 ?? id
    }

    var body: some View {
        HStack(spacing: 0) {
            searchPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            detailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { ragDefaultId = UserDefaults.standard.string(forKey: "hubRAGDefaultModelId") }
    }

    private var searchPanel: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            if isSearching {
                ProgressView().controlSize(.small).padding()
            } else if searchResults.isEmpty && !searchText.isEmpty {
                emptyState
            } else {
                resultList
            }
            if let err = lastError {
                Text(err).font(.caption).foregroundStyle(.red).padding(.horizontal, 8).padding(.vertical, 4)
            }
        }
        .frame(minWidth: 360, maxWidth: 500)
    }

    private var searchBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(i18n.t(.hub_mkt_searchPlaceholder), text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit { performSearch() }
            Button(action: performSearch) {
                Image(systemName: "arrow.right.circle")
            }
            .buttonStyle(.plain)
            .disabled(searchText.isEmpty || isSearching)
        }
        .padding(theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingS) {
                Picker(i18n.t(.hub_mkt_pickerSource), selection: $selectedSource) {
                    ForEach(sources, id: \.self) { s in
                        Label(sourceLabel(s), systemImage: sourceIcon(s)).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Picker(i18n.t(.hub_mkt_pickerTask), selection: $selectedTask) {
                    ForEach(tasks, id: \.self) { t in Text(taskLabel(t)).tag(t) }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Picker(i18n.t(.hub_mkt_pickerFormat), selection: $selectedFormat) {
                    ForEach(formats, id: \.self) { f in Text(f == "all" ? i18n.t(.hub_mkt_formatAll) : f.uppercased()).tag(f) }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Picker(i18n.t(.hub_mkt_pickerParam), selection: $selectedParamSize) {
                    ForEach(paramSizes, id: \.0) { p in Text(paramSizeLabel(p.0)).tag(p.0) }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Toggle(isOn: $mlxOnly) {
                    Text("MLX Only")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)

                Toggle(isOn: $localOnly) {
                    Text(i18n.t(.hub_mkt_localOnly))
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
        }
        .background(theme.surfaceSecondary)
    }

    private var resultList: some View {
        List(selection: $selectedModel) {
            ForEach(searchResults) { model in
                MarketModelRow(model: model, isDownloading: downloadingIds.contains(model.id), isRAGDefault: ragDefaultId == model.id, ratingSummary: ratingSummaries[model.id])
                    .tag(model)
                    .onTapGesture { selectedModel = model }
            }
            if searchResults.count < totalResults {
                Button(action: loadMore) {
                    HStack {
                        Spacer()
                        Text(String(format: i18n.t(.hub_mkt_loadMoreFmt), searchResults.count, totalResults))
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.accent)
                        Spacer()
                    }
                    .padding(.vertical, theme.spacingS)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "globe").font(.system(size: 48)).foregroundStyle(.secondary)
            Text(i18n.t(.hub_mkt_emptyTitle))
                .foregroundStyle(theme.textSecondary)
            Text(i18n.t(.hub_mkt_emptyHint))
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailPanel: some View {
        Group {
            if let model = selectedModel {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        HStack {
                            Text(model.displayTitle)
                                .font(.system(size: theme.largeTitleSize, weight: .bold))
                                .foregroundStyle(theme.text)
                            Spacer()
                            if downloadingIds.contains(model.id) {
                                ProgressView().controlSize(.small)
                            } else {
                                HStack(spacing: theme.spacingS) {
                                    Button(i18n.t(.hub_mkt_download)) {
                                        startDownload(model)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    if model.format != "mlx" {
                                        Button(i18n.t(.hub_mkt_convertMLX)) {
                                            startMLXDownload(model)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    Button(i18n.t(.hub_mkt_addBenchmark)) {
                                        triggerBenchmark(model)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }

                        HStack(spacing: theme.spacingS) {
                            if let src = model.source { HubTagBadge(text: sourceLabel(src), icon: sourceIcon(src), color: sourceColor(src)) }
                            if let fmt = model.format { HubTagBadge(text: fmt.uppercased(), color: .purple) }
                            if let q = model.quantization { HubTagBadge(text: q, color: .orange) }
                            if let t = model.task { HubTagBadge(text: t, color: .green) }
                            if let p = model.parameters { HubTagBadge(text: p, color: .cyan) }
                            if ragDefaultId == model.id { HubTagBadge(text: i18n.t(.hub_mkt_ragDefault), color: .mint) }
                            if let hint = fusionModuleHint(task: model.task) { HubTagBadge(text: hint, icon: "star.circle", color: .blue) }
                        }

                        if let summary = ratingSummaries[model.id], let avg = summary.avgScore {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(avg.rounded()) ? "star.fill" : "star")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.yellow)
                                }
                                Text(String(format: "%.1f", avg))
                                    .font(.system(size: theme.captionSize, weight: .medium))
                                    .foregroundStyle(theme.textSecondary)
                                if let cnt = summary.totalCount, cnt > 0 {
                                    Text("(\(cnt))").font(.caption).foregroundStyle(theme.textTertiary)
                                }
                            }
                        }

                        // PRD: 设为RAG默认嵌入模型
                        if model.task == "embedding" {
                            Button(action: { setRAGDefault(model) }) {
                                Label(
                                    ragDefaultId == model.id ? i18n.t(.hub_mkt_ragDefaultCurrent) : i18n.t(.hub_mkt_ragDefaultSet),
                                    systemImage: ragDefaultId == model.id ? "checkmark.circle.fill" : "text.badge.star"
                                )
                                .font(.system(size: theme.textSize, weight: .medium))
                                .foregroundStyle(ragDefaultId == model.id ? .mint : theme.accent)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, theme.spacingXS)
                        }

                        if let desc = model.description, !desc.isEmpty {
                            GroupBox {
                                Text(desc).font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingS) {
                            if !model.sizeFormatted.isEmpty { HubDetailCell(label: i18n.t(.hub_mkt_size), value: model.sizeFormatted) }
                            if let dl = model.downloads { HubDetailCell(label: i18n.t(.hub_mkt_downloads), value: "\(dl)") }
                            if let lk = model.likes { HubDetailCell(label: i18n.t(.hub_mkt_likes), value: "\(lk)") }
                            if let lic = model.license { HubDetailCell(label: i18n.t(.hub_mkt_license), value: lic) }
                            if let auth = model.author { HubDetailCell(label: i18n.t(.hub_mkt_author), value: auth) }
                            if let repo = model.repoId { HubDetailCell(label: "Repo", value: repo) }
                        }
                    }
                    .padding(theme.spacingL)
                }
            } else {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text(i18n.t(.hub_mkt_selectModelHint))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        currentPage = 1
        isSearching = true
        lastError = nil
        Task { @MainActor in
            do {
                var effectiveFormat = selectedFormat == "all" ? nil : selectedFormat
                if mlxOnly { effectiveFormat = "mlx" }
                let resp = try await client.searchMarket(
                    query: searchText,
                    source: selectedSource == "all" ? nil : selectedSource,
                    task: selectedTask == "all" ? nil : selectedTask,
                    format: effectiveFormat,
                    limit: 40
                )
                var results = resp.results
                if selectedParamSize != "all" {
                    results = results.filter { matchesParamSize($0, bucket: selectedParamSize) }
                }
                if localOnly {
                    results = results.filter { $0.source == "local" }
                }
                totalResults = resp.total ?? results.count
                searchResults = results
                loadRatings(for: results)
                marketLog.info("Market search: \(searchText) → \(searchResults.count) results")
            } catch {
                lastError = BridgeError.sanitize(error)
                marketLog.warning("Market search failed: \(error.localizedDescription)")
            }
            isSearching = false
        }
    }

    private func loadMore() {
        currentPage += 1
        Task { @MainActor in
            do {
                var effectiveFormat = selectedFormat == "all" ? nil : selectedFormat
                if mlxOnly { effectiveFormat = "mlx" }
                let offset = searchResults.count
                let resp = try await client.searchMarket(
                    query: searchText,
                    source: selectedSource == "all" ? nil : selectedSource,
                    task: selectedTask == "all" ? nil : selectedTask,
                    format: effectiveFormat,
                    limit: 20
                )
                var more = resp.results
                if selectedParamSize != "all" {
                    more = more.filter { matchesParamSize($0, bucket: selectedParamSize) }
                }
                if localOnly {
                    more = more.filter { $0.source == "local" }
                }
                searchResults.append(contentsOf: more)
                loadRatings(for: more)
                marketLog.info("Market load more: +\(more.count) results")
            } catch {
                marketLog.warning("Market load more failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadRatings(for models: [HubMarketModel]) {
        for model in models {
            Task { @MainActor in
                if let summary = try? await client.getRatingSummary(modelId: model.id) {
                    ratingSummaries[model.id] = summary
                }
            }
        }
    }

    private func matchesParamSize(_ model: HubMarketModel, bucket: String) -> Bool {
        guard let params = model.parameters else { return true }
        let lowered = params.lowercased()
        let numStr = lowered.replacingOccurrences(of: "b", with: "")
        guard let num = Double(numStr) else { return true }
        switch bucket {
        case "tiny": return num < 1
        case "small": return num >= 1 && num < 7
        case "medium": return num >= 7 && num < 13
        case "large": return num >= 13 && num < 70
        case "xlarge": return num >= 70
        default: return true
        }
    }

    private func setRAGDefault(_ model: HubMarketModel) {
        ragDefaultId = model.id
        UserDefaults.standard.set(model.id, forKey: "hubRAGDefaultModelId")
        UserDefaults.standard.set(model.repoId ?? model.id, forKey: "hubRAGDefaultRepoId")
        marketLog.info("RAG default set: \(model.id)")
    }

    private func startDownload(_ model: HubMarketModel) {
        let repoId = model.repoId ?? model.id
        downloadingIds.insert(model.id)
        Task { @MainActor in
            do {
                let source = model.source ?? "huggingface"
                let format = model.format ?? "mlx"
                let quant = model.quantization ?? "4bit"
                _ = try await client.createDownload(repoId: repoId, source: source, format: format, quantization: quant)
                marketLog.info("Download started: \(repoId)")
            } catch {
                lastError = String(format: i18n.t(.hub_mkt_downloadFailFmt), error.localizedDescription)
                marketLog.error("Download failed: \(error.localizedDescription)")
            }
            downloadingIds.remove(model.id)
        }
    }

    private func startMLXDownload(_ model: HubMarketModel) {
        let repoId = model.repoId ?? model.id
        downloadingIds.insert(model.id)
        Task { @MainActor in
            do {
                _ = try await client.createDownload(repoId: repoId, source: model.source ?? "huggingface", format: "mlx", quantization: "4bit")
                marketLog.info("MLX download started: \(repoId)")
            } catch {
                lastError = String(format: i18n.t(.hub_mkt_mlxFailFmt), error.localizedDescription)
                marketLog.error("MLX download failed: \(error.localizedDescription)")
            }
            downloadingIds.remove(model.id)
        }
    }

    private func triggerBenchmark(_ model: HubMarketModel) {
        Task { @MainActor in
            do {
                _ = try await client.triggerBenchmark(modelId: model.id)
                marketLog.info("Benchmark triggered for: \(model.id)")
            } catch {
                lastError = String(format: i18n.t(.hub_mkt_benchFailFmt), error.localizedDescription)
                marketLog.error("Benchmark trigger failed: \(error.localizedDescription)")
            }
        }
    }

    private func fusionModuleHint(task: String?) -> String? {
        switch task {
        case "text-generation", "conversational": return "→ Fusion Chat"
        case "code", "text2code": return "→ Fusion Code"
        case "embedding", "feature-extraction": return "→ Fusion RAG"
        case "image-generation", "text-to-image": return "→ Fusion Design"
        case "visual-question-answering", "multimodal": return "→ Fusion Design"
        default: return nil
        }
    }

    private func sourceLabel(_ s: String) -> String {
        switch s {
        case "huggingface": return "HuggingFace"
        case "modelscope": return "ModelScope"
        case "local": return i18n.t(.hub_mkt_sourceLocal)
        case "private": return i18n.t(.hub_mkt_sourcePrivate)
        default: return i18n.t(.hub_mkt_sourceAll)
        }
    }

    private func sourceIcon(_ s: String) -> String {
        switch s {
        case "huggingface": return "h.square.fill"
        case "modelscope": return "m.square.fill"
        case "local": return "internaldrive"
        case "private": return "lock.fill"
        default: return "globe"
        }
    }

    private func sourceColor(_ s: String) -> Color {
        switch s {
        case "huggingface": return .yellow
        case "modelscope": return .blue
        case "local": return .gray
        case "private": return .pink
        default: return .green
        }
    }

    private func taskLabel(_ t: String) -> String {
        switch t {
        case "text-generation": return i18n.t(.hub_mkt_taskTextGen)
        case "code": return i18n.t(.hub_mkt_taskCode)
        case "vision": return i18n.t(.hub_mkt_taskVision)
        case "embedding": return i18n.t(.hub_mkt_taskEmbedding)
        case "audio": return i18n.t(.hub_mkt_taskAudio)
        case "multimodal": return i18n.t(.hub_mkt_taskMultimodal)
        default: return i18n.t(.hub_mkt_taskAll)
        }
    }
}

private struct MarketModelRow: View {
    let model: HubMarketModel
    let isDownloading: Bool
    let isRAGDefault: Bool
    var ratingSummary: HubRatingSummaryResponse?
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: model.sourceIcon)
                .foregroundStyle(sourceColor(model.source))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(model.displayTitle)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    if isRAGDefault {
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.mint)
                    }
                    if let avg = ratingSummary?.avgScore {
                        HStack(spacing: 1) {
                            Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(.yellow)
                            Text(String(format: "%.1f", avg)).font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: theme.spacingS) {
                    if let src = model.source { Text(sourceShortLabel(src)).font(.caption).foregroundStyle(.secondary) }
                    if let fmt = model.format { Text(fmt.uppercased()).font(.caption).foregroundStyle(.secondary) }
                    if !model.sizeFormatted.isEmpty { Text(model.sizeFormatted).font(.caption).foregroundStyle(.secondary) }
                    if let dl = model.downloads { Text("↓\(dl)").font(.caption).foregroundStyle(.secondary) }
                    if let task = model.task {
                        switch task {
                        case "text-generation", "conversational": Text("Chat").font(.system(size: 9, weight: .medium)).foregroundStyle(.blue)
                        case "code": Text("Code").font(.system(size: 9, weight: .medium)).foregroundStyle(.cyan)
                        case "embedding", "feature-extraction": Text("RAG").font(.system(size: 9, weight: .medium)).foregroundStyle(.mint)
                        default: EmptyView()
                        }
                    }
                }
            }
            Spacer()
            if isDownloading {
                ProgressView().controlSize(.small)
            } else {
                Button(i18n.t(.hub_mkt_download)) { quickDownload() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
            }
        }
        .padding(.vertical, 4)
    }

    private func sourceShortLabel(_ s: String) -> String {
        switch s {
        case "huggingface": return "HF"
        case "modelscope": return "MS"
        case "local": return i18n.t(.hub_mkt_sourceLocal)
        default: return s
        }
    }

    private func sourceColor(_ s: String?) -> Color {
        switch s {
        case "huggingface": return .yellow
        case "modelscope": return .blue
        case "local": return .gray
        default: return .green
        }
    }

    private func quickDownload() {
        guard let repoId = model.repoId else { return }
        Task { @MainActor in
            let client = ModelHubAPIClient.shared
            do {
                _ = try await client.createDownload(
                    repoId: repoId,
                    source: model.source ?? "huggingface",
                    format: model.format ?? "mlx",
                    quantization: model.quantization ?? "4bit"
                )
                marketLog.info("Quick download: \(repoId)")
            } catch {
                marketLog.error("Quick download failed: \(error.localizedDescription)")
            }
        }
    }
}

struct HubTagBadge: View {
    let text: String
    var icon: String? = nil
    let color: Color
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8))
            }
            Text(text)
                .font(.system(size: theme.captionSize))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

struct HubDetailCell: View {
    let label: String
    let value: String
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(theme.textTertiary)
            Text(value).font(.system(size: theme.footnoteSize, weight: .medium)).foregroundStyle(theme.text)
        }
        .padding(theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
    }
}
