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

    @State private var searchText = ""
    @State private var searchResults: [HubMarketModel] = []
    @State private var isSearching = false
    @State private var selectedSource: String = "all"
    @State private var selectedTask: String = "all"
    @State private var selectedFormat: String = "all"
    @State private var selectedParamSize: String = "all"
    @State private var mlxOnly = false
    @State private var selectedModel: HubMarketModel?
    @State private var downloadingIds: Set<String> = []
    @State private var lastError: String?
    @State private var ragDefaultId: String?

    private let sources = ["all", "huggingface", "modelscope", "local"]
    private let tasks = ["all", "text-generation", "code", "vision", "embedding", "audio", "multimodal"]
    private let formats = ["all", "mlx", "safetensors", "gguf", "onnx"]
    private let paramSizes = [
        ("all", "全部参数量"),
        ("tiny", "< 1B"),
        ("small", "1B-7B"),
        ("medium", "7B-13B"),
        ("large", "13B-70B"),
        ("xlarge", "> 70B"),
    ]

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
            TextField("搜索模型...", text: $searchText)
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
                Picker("来源", selection: $selectedSource) {
                    ForEach(sources, id: \.self) { s in
                        Label(sourceLabel(s), systemImage: sourceIcon(s)).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Picker("任务", selection: $selectedTask) {
                    ForEach(tasks, id: \.self) { t in Text(taskLabel(t)).tag(t) }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Picker("格式", selection: $selectedFormat) {
                    ForEach(formats, id: \.self) { f in Text(f == "all" ? "全部格式" : f.uppercased()).tag(f) }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Picker("参数量", selection: $selectedParamSize) {
                    ForEach(paramSizes, id: \.0) { p in Text(p.1).tag(p.0) }
                }
                .pickerStyle(.menu)
                .controlSize(.small)

                Toggle(isOn: $mlxOnly) {
                    Text("MLX Only")
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
        List(searchResults, selection: $selectedModel) { model in
            MarketModelRow(model: model, isDownloading: downloadingIds.contains(model.id), isRAGDefault: ragDefaultId == model.id)
                .tag(model)
                .onTapGesture { selectedModel = model }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "globe").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("搜索 HuggingFace / ModelScope / 私有仓库模型")
                .foregroundStyle(theme.textSecondary)
            Text("支持多源搜索、格式筛选、参数量筛选、任务分类")
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
                                Button("下载") {
                                    startDownload(model)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        HStack(spacing: theme.spacingS) {
                            if let src = model.source { HubTagBadge(text: sourceLabel(src), icon: sourceIcon(src), color: sourceColor(src)) }
                            if let fmt = model.format { HubTagBadge(text: fmt.uppercased(), color: .purple) }
                            if let q = model.quantization { HubTagBadge(text: q, color: .orange) }
                            if let t = model.task { HubTagBadge(text: t, color: .green) }
                            if let p = model.parameters { HubTagBadge(text: p, color: .cyan) }
                            if ragDefaultId == model.id { HubTagBadge(text: "RAG 默认", color: .mint) }
                        }

                        // PRD: 设为RAG默认嵌入模型
                        if model.task == "embedding" {
                            Button(action: { setRAGDefault(model) }) {
                                Label(
                                    ragDefaultId == model.id ? "当前 RAG 默认嵌入模型" : "设为 RAG 默认嵌入模型",
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
                            if !model.sizeFormatted.isEmpty { HubDetailCell(label: "大小", value: model.sizeFormatted) }
                            if let dl = model.downloads { HubDetailCell(label: "下载量", value: "\(dl)") }
                            if let lk = model.likes { HubDetailCell(label: "点赞", value: "\(lk)") }
                            if let lic = model.license { HubDetailCell(label: "许可", value: lic) }
                            if let auth = model.author { HubDetailCell(label: "作者", value: auth) }
                            if let repo = model.repoId { HubDetailCell(label: "Repo", value: repo) }
                        }
                    }
                    .padding(theme.spacingL)
                }
            } else {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("选择模型查看详情")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchText.isEmpty else { return }
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
                searchResults = results
                marketLog.info("Market search: \(searchText) → \(searchResults.count) results")
            } catch {
                lastError = error.localizedDescription
                marketLog.warning("Market search failed: \(error.localizedDescription)")
            }
            isSearching = false
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
                lastError = "下载失败: \(error.localizedDescription)"
                marketLog.error("Download failed: \(error.localizedDescription)")
            }
            downloadingIds.remove(model.id)
        }
    }

    private func sourceLabel(_ s: String) -> String {
        switch s {
        case "huggingface": return "HuggingFace"
        case "modelscope": return "ModelScope"
        case "local": return "本地"
        default: return "全部来源"
        }
    }

    private func sourceIcon(_ s: String) -> String {
        switch s {
        case "huggingface": return "h.square.fill"
        case "modelscope": return "m.square.fill"
        case "local": return "internaldrive"
        default: return "globe"
        }
    }

    private func sourceColor(_ s: String) -> Color {
        switch s {
        case "huggingface": return .yellow
        case "modelscope": return .blue
        case "local": return .gray
        default: return .green
        }
    }

    private func taskLabel(_ t: String) -> String {
        switch t {
        case "text-generation": return "文本生成"
        case "code": return "代码"
        case "vision": return "视觉"
        case "embedding": return "嵌入"
        case "audio": return "音频"
        case "multimodal": return "多模态"
        default: return "全部任务"
        }
    }
}

private struct MarketModelRow: View {
    let model: HubMarketModel
    let isDownloading: Bool
    let isRAGDefault: Bool
    @Environment(\.studioTheme) private var theme

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
                }
                HStack(spacing: theme.spacingS) {
                    if let src = model.source { Text(sourceShortLabel(src)).font(.caption).foregroundStyle(.secondary) }
                    if let fmt = model.format { Text(fmt.uppercased()).font(.caption).foregroundStyle(.secondary) }
                    if !model.sizeFormatted.isEmpty { Text(model.sizeFormatted).font(.caption).foregroundStyle(.secondary) }
                    if let dl = model.downloads { Text("↓\(dl)").font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            if isDownloading {
                ProgressView().controlSize(.small)
            } else {
                Button("下载") { quickDownload() }
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
        case "local": return "本地"
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
