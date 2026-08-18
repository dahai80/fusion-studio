// Callers: ModelHubMainView contentArea switch on .localStorage.
// Affected API: ModelHubAPIClient listModels/deleteModel/batchDeleteModels/pinModel/setModelModules/listVersions.
// Data schemas: HubModel, HubModelListResponse, HubModelVersion.
// PRD: Local Storage + batch operations + version management
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let storageLog = Logger(subsystem: "com.fusion.studio", category: "HubLocalStorage")

struct HubLocalStorageView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var models: [HubModel] = []
    @State private var selectedModel: HubModel?
    @State private var searchText = ""
    @State private var selectedFamily: String = "全部"
    @State private var selectedCategory: String = "全部"
    @State private var isLoading = false
    @State private var lastError: String?

    // Batch mode
    @State private var batchMode = false
    @State private var selectedIds: Set<String> = []

    // Version management
    @State private var versions: [HubModelVersion] = []
    @State private var loadingVersions = false

    // Batch quantize
    @State private var showBatchQuantize = false
    @State private var batchQuantBits = 4
    @State private var batchQuantFormat = "mlx"

    // Serve
    @State private var servingModelIds: Set<String> = []

    private let categories = [
        "全部", "通用对话", "代码专属", "向量嵌入", "图像多模态", "私有模型"
    ]

    private var families: [String] {
        let fams = Set(models.compactMap(\.family)).sorted()
        return ["全部"] + fams
    }

    private func catName(_ cat: String) -> String {
        switch cat {
        case "全部": return i18n.t(.hub_ls_catAll)
        case "通用对话": return i18n.t(.hub_ls_catChat)
        case "代码专属": return i18n.t(.hub_ls_catCode)
        case "向量嵌入": return i18n.t(.hub_ls_catEmbed)
        case "图像多模态": return i18n.t(.hub_ls_catVision)
        case "私有模型": return i18n.t(.hub_ls_catPrivate)
        case "已固定": return i18n.t(.hub_ls_catPinned)
        case "推理中": return i18n.t(.hub_ls_catServing)
        case "语言模型": return i18n.t(.hub_ls_catLLM)
        case "视觉模型": return i18n.t(.hub_ls_catVLM)
        case "嵌入模型": return i18n.t(.hub_ls_catEmbedM)
        case "代码模型": return i18n.t(.hub_ls_catCodeM)
        case "音频模型": return i18n.t(.hub_ls_catAudioM)
        case "MLX格式": return i18n.t(.hub_ls_catMLX)
        case "GGUF格式": return i18n.t(.hub_ls_catGGUF)
        default: return cat
        }
    }

    private var filteredModels: [HubModel] {
        var result = models
        if !searchText.isEmpty {
            result = result.filter {
                $0.displayTitle.localizedCaseInsensitiveContains(searchText) || $0.id.localizedCaseInsensitiveContains(searchText)
            }
        }
        if selectedCategory != "全部" {
            result = result.filter { matchesCategory($0, category: selectedCategory) }
        }
        if selectedFamily != "全部" {
            result = result.filter { $0.family == selectedFamily }
        }
        return result
    }

    private var selectedCount: Int { selectedIds.count }
    private var batchSelectedModels: [HubModel] { models.filter { selectedIds.contains($0.id) } }

    var body: some View {
        HStack(spacing: 0) {
            listPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            detailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadModels() }
        .sheet(isPresented: $showBatchQuantize) { batchQuantizeSheet }
    }

    // MARK: - List Panel

    private var listPanel: some View {
        HStack(spacing: 0) {
            categoryTree
            Rectangle().fill(theme.separator).frame(width: 1)
            VStack(spacing: 0) {
                searchBar
                filterBar
                batchToolbar
                Divider()
                modelList
                if let err = lastError {
                    Text(err).font(.caption).foregroundStyle(.red).padding(4)
                }
            }
        }
        .frame(minWidth: 320, maxWidth: 500)
    }

    private var categoryTree: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(i18n.t(.hub_ls_category))
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, theme.spacingS)
                .padding(.top, theme.spacingM)
                .padding(.bottom, theme.spacingXS)

            ForEach(categories, id: \.self) { cat in
                Button(action: { selectedCategory = cat }) {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: categoryIcon(cat))
                            .font(.system(size: 12))
                            .foregroundStyle(selectedCategory == cat ? theme.accent : theme.textSecondary)
                            .frame(width: 16)
                        Text(catName(cat))
                            .font(.system(size: theme.footnoteSize, weight: selectedCategory == cat ? .medium : .regular))
                            .foregroundStyle(selectedCategory == cat ? theme.text : theme.textSecondary)
                        Spacer()
                        let count = cat == "全部" ? models.count : models.filter { matchesCategory($0, category: cat) }.count
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(selectedCategory == cat ? theme.accent.opacity(0.08) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(width: 130)
        .background(theme.surfaceSecondary)
    }

    private var searchBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(i18n.t(.hub_ls_searchPlaceholder), text: $searchText).textFieldStyle(.plain)
            if isLoading { ProgressView().controlSize(.small) }
            Button(action: { Task { await loadModels() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(families, id: \.self) { fam in
                    Button(fam) { selectedFamily = fam }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(selectedFamily == fam ? Color.accentColor : nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(theme.surfaceSecondary)
    }

    private var batchToolbar: some View {
        HStack(spacing: theme.spacingS) {
            Toggle(isOn: $batchMode) {
                Text(i18n.t(.hub_ls_batchMode)).font(.system(size: theme.captionSize))
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            if batchMode {
                if selectedCount > 0 {
                    Text(String(format: i18n.t(.hub_ls_selectedCountFmt), selectedCount))
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                    Button(i18n.t(.hub_ls_selectAll)) {
                        selectedIds = Set(filteredModels.map(\.id))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    Button(i18n.t(.hub_ls_batchDelete)) {
                        batchDelete()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundStyle(.red)
                    Button(i18n.t(.hub_ls_batchQuantize)) {
                        showBatchQuantize = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundStyle(.orange)
                    Button(i18n.t(.hub_ls_syncCluster)) {
                        syncToCluster()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    Button(i18n.t(.hub_ls_exportPath)) {
                        exportPaths()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                Spacer()
            }
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, 4)
        .background(theme.surfaceSecondary)
    }

    private var modelList: some View {
        List(filteredModels, selection: $selectedModel) { model in
            LocalModelRow(model: model, batchMode: batchMode, isSelected: selectedIds.contains(model.id), isServing: servingModelIds.contains(model.id))
                .tag(model)
                .onTapGesture {
                    if batchMode {
                        if selectedIds.contains(model.id) {
                            selectedIds.remove(model.id)
                        } else {
                            selectedIds.insert(model.id)
                        }
                    } else {
                        selectedModel = model
                        loadVersionsFor(model)
                    }
                }
        }
        .listStyle(.plain)
    }

    // MARK: - Detail Panel

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
                            if model.isActive == true {
                                Label(i18n.t(.hub_ls_currentUse), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }

                        HStack(spacing: theme.spacingM) {
                            if let fam = model.family { HubTagBadge(text: fam, color: .blue) }
                            if let fmt = model.format { HubTagBadge(text: fmt.uppercased(), color: .purple) }
                            if let q = model.quantization { HubTagBadge(text: q, color: .orange) }
                            if let p = model.parameters { HubTagBadge(text: p, color: .cyan) }
                            if model.sizeGB > 0 { HubTagBadge(text: model.sizeFormatted, color: .gray) }
                            if model.isServing == true || servingModelIds.contains(model.id) {
                                HubTagBadge(text: i18n.t(.hub_ls_serving), icon: "bolt.fill", color: .green)
                            }
                            if let hint = model.fusionModuleHint { HubTagBadge(text: hint, icon: "star.circle", color: .blue) }
                        }

                        if let compat = model.compatibleFormats, !compat.isEmpty {
                            HStack(spacing: theme.spacingS) {
                                Text(i18n.t(.hub_ls_compatFormats)).font(.caption).foregroundStyle(theme.textTertiary)
                                ForEach(compat, id: \.self) { fmt in
                                    HubTagBadge(text: fmt.uppercased(), color: .secondary)
                                }
                            }
                        }

                        HStack(spacing: theme.spacingS) {
                            Button(model.isPinned == true ? i18n.t(.hub_ls_unpin) : i18n.t(.hub_ls_pin)) {
                                togglePin(model)
                            }
                            .buttonStyle(.bordered)

                            if servingModelIds.contains(model.id) || model.isServing == true {
                                Button(i18n.t(.hub_ls_stopServe)) {
                                    stopServing(model)
                                }
                                .buttonStyle(.bordered)
                                .foregroundStyle(.orange)
                            } else {
                                Button(i18n.t(.hub_ls_startServe)) {
                                    startServing(model)
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            Button(i18n.t(.delete)) {
                                deleteModel(model)
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.red)
                        }

                        GroupBox(i18n.t(.hub_ls_basicInfo)) {
                            VStack(alignment: .leading, spacing: 6) {
                                HubDetailCell(label: "ID", value: model.id)
                                if let path = model.modelPath { HubDetailCell(label: i18n.t(.hub_ls_path), value: path) }
                                if let src = model.source { HubDetailCell(label: i18n.t(.hub_ls_source), value: src) }
                                if let eng = model.engineType { HubDetailCell(label: i18n.t(.hub_ls_engine), value: eng) }
                                if let lic = model.license { HubDetailCell(label: i18n.t(.hub_ls_license), value: lic) }
                            }
                        }

                        if let mods = model.allowedModules, !mods.isEmpty {
                            GroupBox(i18n.t(.hub_ls_allowedModules)) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 4) {
                                        ForEach(mods, id: \.self) { mod in
                                            Text(mod).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.accentColor.opacity(0.1)).clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }

                        // PRD: Version management
                        versionSection(for: model)
                    }
                    .padding(theme.spacingL)
                }
            } else {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "internaldrive").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text(i18n.t(.hub_ls_selectModelHint))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func versionSection(for model: HubModel) -> some View {
        GroupBox(i18n.t(.hub_ls_versionMgmt)) {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack {
                    Text(i18n.t(.hub_ls_versionList))
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Button(action: { loadVersionsFor(model) }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                }

                if loadingVersions {
                    ProgressView().controlSize(.small)
                } else if versions.isEmpty {
                    Text(i18n.t(.hub_ls_noVersions))
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                } else {
                    ForEach(versions) { ver in
                        HStack(spacing: theme.spacingS) {
                            Image(systemName: ver.statusEnum.icon).foregroundStyle(color(for: ver.statusEnum.color))
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(ver.version ?? ver.id)
                                        .font(.system(size: theme.textSize))
                                        .foregroundStyle(theme.text)
                                    Text(ver.statusEnum.label)
                                        .font(.system(size: 9, weight: .medium))
                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Capsule().fill(color(for: ver.statusEnum.color).opacity(0.15)))
                                        .foregroundStyle(color(for: ver.statusEnum.color))
                                }
                                HStack(spacing: 8) {
                                    if let fmt = ver.format { Text(fmt).font(.caption).foregroundStyle(.secondary) }
                                    if let q = ver.quantization { Text(q).font(.caption).foregroundStyle(.secondary) }
                                    if let sz = ver.sizeBytes {
                                        Text(String(format: "%.1f GB", Double(sz) / 1_073_741_824.0))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            HStack(spacing: 4) {
                                Button(i18n.t(.hub_ls_rollback)) { rollbackVersion(ver) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .foregroundStyle(.orange)
                                if ver.statusEnum == .draft {
                                    Button(i18n.t(.hub_ls_publish)) { promoteVersion(ver) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        .foregroundStyle(.green)
                                }
                                if ver.statusEnum == .published {
                                    Button(i18n.t(.hub_ls_deprecate)) { deprecateVersion(ver) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        .foregroundStyle(.yellow)
                                }
                                if ver.statusEnum == .deprecated {
                                    Button(i18n.t(.hub_ls_retire)) { retireVersion(ver) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadModels() async {
        isLoading = true
        lastError = nil
        do {
            let resp = try await client.listModels()
            models = resp.models
            storageLog.info("Loaded \(models.count) local models")
        } catch {
            lastError = error.localizedDescription
            storageLog.warning("Load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func loadVersionsFor(_ model: HubModel) {
        versions = []
        loadingVersions = true
        Task { @MainActor in
            do {
                let resp = try await client.listVersions(modelId: model.id)
                versions = resp.versions
                storageLog.info("Loaded \(versions.count) versions for \(model.id)")
            } catch {
                storageLog.warning("Load versions failed: \(error.localizedDescription)")
            }
            loadingVersions = false
        }
    }

    private func color(for name: String) -> Color {
        switch name {
        case "gray": return .gray
        case "orange": return .orange
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        case "blue": return .blue
        case "purple": return .purple
        default: return .secondary
        }
    }

    private func togglePin(_ model: HubModel) {
        Task { @MainActor in
            do {
                let pin = model.isPinned != true
                _ = try await client.pinModel(modelId: model.id, pin: pin)
                if let idx = models.firstIndex(where: { $0.id == model.id }) {
                    var updated = models[idx]
                    updated.isPinned = pin
                    models[idx] = updated
                    selectedModel = updated
                }
                storageLog.info("Pin \(pin) for \(model.id)")
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func deleteModel(_ model: HubModel) {
        Task { @MainActor in
            do {
                _ = try await client.deleteModel(modelId: model.id)
                models.removeAll { $0.id == model.id }
                selectedIds.remove(model.id)
                if selectedModel?.id == model.id { selectedModel = models.first }
                storageLog.info("Deleted model: \(model.id)")
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func batchDelete() {
        let ids = Array(selectedIds)
        Task { @MainActor in
            do {
                _ = try await client.batchDeleteModels(ids: ids)
                models.removeAll { selectedIds.contains($0.id) }
                if selectedIds.contains(selectedModel?.id ?? "") { selectedModel = nil }
                storageLog.info("Batch deleted \(ids.count) models")
                selectedIds.removeAll()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Batch Quantize Sheet

    private var batchQuantizeSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.hub_ls_batchQuantTitle))
                .font(.title2)
                .bold()
            Text(String(format: i18n.t(.hub_ls_batchQuantHintFmt), selectedCount))
                .font(.caption)
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: theme.spacingM) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.hub_ls_targetFormat)).font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $batchQuantFormat) {
                        Text("MLX").tag("mlx")
                        Text("GGUF").tag("gguf")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.hub_ls_quantBits)).font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $batchQuantBits) {
                        Text("2-bit").tag(2)
                        Text("4-bit").tag(4)
                        Text("8-bit").tag(8)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(batchSelectedModels) { m in
                        HStack(spacing: 6) {
                            Image(systemName: "cpu").font(.caption).foregroundStyle(.secondary)
                            Text(m.displayTitle).font(.system(size: theme.footnoteSize))
                            if let q = m.quantization { Text("(\(q))").font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .frame(maxHeight: 150)

            if let err = lastError {
                Text(err).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button(i18n.t(.cancel)) { showBatchQuantize = false }
                    .buttonStyle(.bordered)
                Button(i18n.t(.hub_ls_startQuantize)) {
                    batchQuantize()
                    showBatchQuantize = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 420)
    }

    private func batchQuantize() {
        let ids = Array(selectedIds)
        Task { @MainActor in
            do {
                for modelId in ids {
                    _ = try await client.startQuantize(
                        modelId: modelId,
                        format: batchQuantFormat,
                        bits: batchQuantBits
                    )
                    storageLog.info("Quantize started: \(modelId) \(batchQuantFormat) \(batchQuantBits)-bit")
                }
                lastError = nil
            } catch {
                lastError = String(format: i18n.t(.hub_ls_batchQuantFailFmt), error.localizedDescription)
                storageLog.error("Batch quantize failed: \(error.localizedDescription)")
            }
        }
    }

    private func rollbackVersion(_ ver: HubModelVersion) {
        Task { @MainActor in
            do {
                _ = try await client.rollbackVersion(versionId: ver.id)
                storageLog.info("Rolled back to version: \(ver.id)")
                if let model = selectedModel {
                    loadVersionsFor(model)
                }
            } catch {
                lastError = String(format: i18n.t(.hub_ls_rollbackFailFmt), error.localizedDescription)
                storageLog.error("Rollback failed: \(error.localizedDescription)")
            }
        }
    }

    private func syncToCluster() {
        storageLog.info("Sync to cluster: \(selectedIds)")
        Task {
            do {
                for modelId in selectedIds {
                    let _: HubSimpleResponse = try await client.post("/api/v1/cluster/sync-model", json: ["model_id": modelId])
                    storageLog.info("Cluster sync started for \(modelId)")
                }
                lastError = nil
            } catch {
                storageLog.error("Cluster sync failed: \(error.localizedDescription)")
                lastError = String(format: i18n.t(.hub_ls_syncFailFmt), error.localizedDescription)
            }
        }
    }

    private func matchesCategory(_ model: HubModel, category: String) -> Bool {
        if category == "全部" { return true }
        if category == "已固定" { return model.isPinned == true }
        if category == "推理中" { return servingModelIds.contains(model.id) }
        let fam = model.family?.lowercased() ?? ""
        let task = model.task?.lowercased() ?? ""
        let fmt = model.format?.lowercased() ?? ""
        switch category {
        case "语言模型": return fam.contains("llm") || fam.contains("gpt") || fam.contains("llama") || fam.contains("qwen") || task.contains("text-generation")
        case "视觉模型": return fam.contains("vlm") || fam.contains("vision") || task.contains("image-text-to-text")
        case "嵌入模型": return fam.contains("embed") || task.contains("embeddings")
        case "代码模型": return fam.contains("code") || task.contains("code")
        case "音频模型": return fam.contains("audio") || fam.contains("whisper") || task.contains("audio")
        case "MLX格式": return fmt.contains("mlx")
        case "GGUF格式": return fmt.contains("gguf") || fmt.contains("ggml")
        case "Safetensors": return fmt.contains("safetensors")
        default: return true
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "全部": return "square.grid.2x2"
        case "已固定": return "pin.fill"
        case "推理中": return "bolt.fill"
        case "语言模型": return "text.bubble.fill"
        case "视觉模型": return "eye.fill"
        case "嵌入模型": return "link"
        case "代码模型": return "chevron.left.forwardslash.chevron.right"
        case "音频模型": return "waveform"
        case "MLX格式": return "apple.terminal"
        case "GGUF格式": return "doc.zipper"
        case "Safetensors": return "lock.shield"
        default: return "folder"
        }
    }

    private func startServing(_ model: HubModel) {
        Task { @MainActor in
            do {
                let resp = try await client.serveModel(modelId: model.id)
                servingModelIds.insert(model.id)
                storageLog.info("Serving started for \(model.id): port=\(resp.port ?? 0)")
                lastError = nil
            } catch {
                lastError = String(format: i18n.t(.hub_ls_startServeFailFmt), error.localizedDescription)
                storageLog.error("Serve failed: \(error.localizedDescription)")
            }
        }
    }

    private func stopServing(_ model: HubModel) {
        Task { @MainActor in
            do {
                _ = try await client.unserveModel(modelId: model.id)
                servingModelIds.remove(model.id)
                storageLog.info("Serving stopped for \(model.id)")
                lastError = nil
            } catch {
                lastError = String(format: i18n.t(.hub_ls_stopServeFailFmt), error.localizedDescription)
                storageLog.error("Unserve failed: \(error.localizedDescription)")
            }
        }
    }

    private func exportPaths() {
        let paths = models
            .filter { selectedIds.contains($0.id) || (selectedIds.isEmpty && $0.id == selectedModel?.id) }
            .compactMap { $0.modelPath }
            .joined(separator: "\n")
        if !paths.isEmpty {
            #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(paths, forType: .string)
            #endif
            storageLog.info("Exported \(paths.components(separatedBy: "\n").count) model paths")
        }
    }

    private func promoteVersion(_ ver: HubModelVersion) {
        Task { @MainActor in
            do {
                _ = try await client.promoteVersion(versionId: ver.id)
                storageLog.info("Promoted version: \(ver.id)")
                if let model = selectedModel { loadVersionsFor(model) }
            } catch {
                lastError = String(format: i18n.t(.hub_ls_publishFailFmt), error.localizedDescription)
                storageLog.error("Promote failed: \(error.localizedDescription)")
            }
        }
    }

    private func deprecateVersion(_ ver: HubModelVersion) {
        Task { @MainActor in
            do {
                _ = try await client.deprecateVersion(versionId: ver.id)
                storageLog.info("Deprecated version: \(ver.id)")
                if let model = selectedModel { loadVersionsFor(model) }
            } catch {
                lastError = String(format: i18n.t(.hub_ls_deprecateFailFmt), error.localizedDescription)
                storageLog.error("Deprecate failed: \(error.localizedDescription)")
            }
        }
    }

    private func retireVersion(_ ver: HubModelVersion) {
        Task { @MainActor in
            do {
                _ = try await client.retireVersion(versionId: ver.id)
                storageLog.info("Retired version: \(ver.id)")
                if let model = selectedModel { loadVersionsFor(model) }
            } catch {
                lastError = String(format: i18n.t(.hub_ls_retireFailFmt), error.localizedDescription)
                storageLog.error("Retire failed: \(error.localizedDescription)")
            }
        }
    }
}

private struct LocalModelRow: View {
    let model: HubModel
    let batchMode: Bool
    let isSelected: Bool
    var isServing: Bool = false
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        HStack(spacing: theme.spacingS) {
            if batchMode {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? theme.accent : .secondary)
            } else {
                Circle()
                    .fill(isServing ? Color.green : (model.isActive == true ? Color.blue : (model.isDownloaded == true ? Color.orange : Color.gray)))
                    .frame(width: 8, height: 8)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(model.displayTitle)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    if isServing {
                        Text(i18n.t(.hub_ls_serving))
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                            .foregroundStyle(.green)
                    }
                    if model.isPinned == true {
                        Text(i18n.t(.hub_ls_resident))
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(Color.yellow.opacity(0.15)))
                            .foregroundStyle(.yellow)
                    }
                }
                HStack(spacing: 6) {
                    if let fmt = model.format {
                        Text(fmt.uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(theme.accent.opacity(0.12)))
                            .foregroundStyle(theme.accent)
                    }
                    if let q = model.quantization {
                        Text(q)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(Color.purple.opacity(0.12)))
                            .foregroundStyle(.purple)
                    }
                    if model.sizeGB > 0 { Text(model.sizeFormatted).font(.caption).foregroundStyle(.secondary) }
                    if let hint = model.fusionModuleHint {
                        Text(hint)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(Color.cyan.opacity(0.12)))
                            .foregroundStyle(.cyan)
                    }
                }
            }
            Spacer()
            if model.isPinned == true && !isServing {
                Image(systemName: "pin.fill").font(.caption).foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}
