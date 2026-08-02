// Callers: ModelHubMainView contentArea switch on .localStorage.
// Affected API: ModelHubAPIClient listModels/deleteModel/batchDeleteModels/pinModel/setModelModules.
// Data schemas: HubModel, HubModelListResponse.
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let storageLog = Logger(subsystem: "com.fusion.studio", category: "HubLocalStorage")

struct HubLocalStorageView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject private var config: FusionConfig

    @State private var models: [HubModel] = []
    @State private var selectedModel: HubModel?
    @State private var searchText = ""
    @State private var selectedFamily: String = "全部"
    @State private var isLoading = false
    @State private var lastError: String?

    private var families: [String] {
        let fams = Set(models.compactMap(\.family)).sorted()
        return ["全部"] + fams
    }

    private var filteredModels: [HubModel] {
        var result = models
        if !searchText.isEmpty {
            result = result.filter { $0.displayTitle.localizedCaseInsensitiveContains(searchText) || $0.id.localizedCaseInsensitiveContains(searchText) }
        }
        if selectedFamily != "全部" {
            result = result.filter { $0.family == selectedFamily }
        }
        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            listPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            detailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadModels() }
    }

    private var listPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索本地模型...", text: $searchText).textFieldStyle(.plain)
                if isLoading { ProgressView().controlSize(.small) }
                Button(action: { Task { await loadModels() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(theme.spacingS)
            .background(theme.surfaceSecondary)

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

            Divider()

            List(filteredModels, selection: $selectedModel) { model in
                LocalModelRow(model: model)
                    .tag(model)
                    .onTapGesture { selectedModel = model }
            }
            .listStyle(.plain)

            if let err = lastError {
                Text(err).font(.caption).foregroundStyle(.red).padding(4)
            }
        }
        .frame(minWidth: 320, maxWidth: 450)
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
                            if model.isActive == true {
                                Label("当前使用", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }

                        HStack(spacing: theme.spacingM) {
                            if let fam = model.family { HubTagBadge(text: fam, color: .blue) }
                            if let fmt = model.format { HubTagBadge(text: fmt.uppercased(), color: .purple) }
                            if let q = model.quantization { HubTagBadge(text: q, color: .orange) }
                            if let p = model.parameters { HubTagBadge(text: p, color: .cyan) }
                            if model.sizeGB > 0 { HubTagBadge(text: model.sizeFormatted, color: .gray) }
                        }

                        HStack(spacing: theme.spacingM) {
                            Button(model.isPinned == true ? "取消置顶" : "置顶") {
                                togglePin(model)
                            }
                            .buttonStyle(.bordered)

                            Button("删除") {
                                deleteModel(model)
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(.red)
                        }

                        GroupBox("基本信息") {
                            VStack(alignment: .leading, spacing: 6) {
                                HubDetailCell(label: "ID", value: model.id)
                                if let path = model.modelPath { HubDetailCell(label: "路径", value: path) }
                                if let src = model.source { HubDetailCell(label: "来源", value: src) }
                                if let eng = model.engineType { HubDetailCell(label: "引擎", value: eng) }
                                if let lic = model.license { HubDetailCell(label: "许可", value: lic) }
                            }
                        }

                        if let mods = model.allowedModules, !mods.isEmpty {
                            GroupBox("允许模块") {
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
                    }
                    .padding(theme.spacingL)
                }
            } else {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "internaldrive").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("选择模型查看详情")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

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

    private func togglePin(_ model: HubModel) {
        Task { @MainActor in
            do {
                let pin = model.isPinned != true
                _ = try await client.pinModel(modelId: model.id, pin: pin)
                if let idx = models.firstIndex(where: { $0.id == model.id }) {
                    models[idx] = HubModel(
                        id: models[idx].id, name: models[idx].name, displayName: models[idx].displayName,
                        modelPath: models[idx].modelPath, engineType: models[idx].engineType,
                        format: models[idx].format, sizeBytes: models[idx].sizeBytes,
                        quantization: models[idx].quantization, parameters: models[idx].parameters,
                        family: models[idx].family, isDownloaded: models[idx].isDownloaded,
                        isActive: models[idx].isActive, isPinned: pin,
                        allowedModules: models[idx].allowedModules, versions: models[idx].versions,
                        source: models[idx].source, description: models[idx].description,
                        tags: models[idx].tags, downloads: models[idx].downloads,
                        likes: models[idx].likes, license: models[idx].license,
                        task: models[idx].task, createdAt: models[idx].createdAt,
                        updatedAt: models[idx].updatedAt
                    )
                    selectedModel = models[idx]
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
                if selectedModel?.id == model.id { selectedModel = models.first }
                storageLog.info("Deleted model: \(model.id)")
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}

private struct LocalModelRow: View {
    let model: HubModel
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Circle()
                .fill(model.isActive == true ? Color.green : (model.isDownloaded == true ? Color.blue : Color.gray))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayTitle)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                HStack(spacing: 6) {
                    if let fam = model.family { Text(fam).font(.caption).foregroundStyle(.secondary) }
                    if let q = model.quantization { Text(q).font(.caption).foregroundStyle(.secondary) }
                    if model.sizeGB > 0 { Text(model.sizeFormatted).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            if model.isPinned == true {
                Image(systemName: "pin.fill").font(.caption).foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

