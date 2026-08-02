// Callers: ModelHubMainView contentArea switch on .market.
// Affected API: ModelHubAPIClient searchMarket/createDownload.
// Data schemas: HubMarketSearchResponse, HubMarketModel, HubDownloadTaskResponse.
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
    @State private var selectedModel: HubMarketModel?
    @State private var downloadingIds: Set<String> = []
    @State private var lastError: String?

    private let sources = ["all", "huggingface", "modelscope", "private"]
    private let tasks = ["all", "text-generation", "code", "vision", "embedding", "audio", "multimodal"]
    private let formats = ["all", "mlx", "safetensors", "gguf", "onnx"]

    var body: some View {
        HStack(spacing: 0) {
            searchPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            detailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        Text(sourceLabel(s)).tag(s)
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
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
        }
        .background(theme.surfaceSecondary)
    }

    private var resultList: some View {
        List(searchResults, selection: $selectedModel) { model in
            MarketModelRow(model: model, isDownloading: downloadingIds.contains(model.id))
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
            Text("支持多源搜索、格式筛选、任务分类")
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

                        HStack(spacing: theme.spacingM) {
                            if let src = model.source { HubTagBadge(text: sourceLabel(src), color: .blue) }
                            if let fmt = model.format { HubTagBadge(text: fmt.uppercased(), color: .purple) }
                            if let q = model.quantization { HubTagBadge(text: q, color: .orange) }
                            if let t = model.task { HubTagBadge(text: t, color: .green) }
                            if let p = model.parameters { HubTagBadge(text: p, color: .cyan) }
                        }

                        if let desc = model.description, !desc.isEmpty {
                            GroupBox {
                                Text(desc).font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingS) {
                            if let sz = model.sizeFormatted, !sz.isEmpty { HubDetailCell(label: "大小", value: sz) }
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

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        lastError = nil
        Task { @MainActor in
            do {
                let resp = try await client.searchMarket(
                    query: searchText,
                    source: selectedSource == "all" ? nil : selectedSource,
                    task: selectedTask == "all" ? nil : selectedTask,
                    format: selectedFormat == "all" ? nil : selectedFormat
                )
                searchResults = resp.results
                marketLog.info("Market search: \(searchText) → \(searchResults.count) results")
            } catch {
                lastError = error.localizedDescription
                marketLog.warning("Market search failed: \(error.localizedDescription)")
            }
            isSearching = false
        }
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
        case "private": return "私有仓库"
        default: return "全部来源"
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

struct HubMarketModelRow: View {
    let model: HubMarketModel
    let isDownloading: Bool
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayTitle)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                HStack(spacing: theme.spacingS) {
                    if let src = model.source { Text(src).font(.caption).foregroundStyle(.secondary) }
                    if let fmt = model.format { Text(fmt.uppercased()).font(.caption).foregroundStyle(.secondary) }
                    if let sz = model.sizeFormatted, !sz.isEmpty { Text(sz).font(.caption).foregroundStyle(.secondary) }
                    if let dl = model.downloads { Text("↓\(dl)").font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            if isDownloading {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HubTagBadge: View {
    let text: String
    let color: Color
    @Environment(\.studioTheme) private var theme

    var body: some View {
        Text(text)
            .font(.system(size: theme.captionSize))
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
