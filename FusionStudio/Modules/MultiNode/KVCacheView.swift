// Importers/callers: ModuleDetailView (routing .kvCache)
// Affected API: engine.findKVCache(), engine.fetchAgentKVStats(), engine.fetchAgentHardware()
// Data schemas: KVCacheEntry, KVStatsResponse, ModelKVInfo, AgentHardwareInfo
// User verbatim: "做一遍检查，所有需要GUI的都要在fusion-studio落地"

import SwiftUI
import os.log

private let kvLog = Logger(subsystem: "com.fusion.studio", category: "KVCache")

struct KVCacheView: View {
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var kvStats: KVStatsResponse?
    @State private var hardware: AgentHardwareInfo?
    @State private var searchModel = ""
    @State private var foundEntry: KVCacheEntry?
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var agentHealthy: Bool?
    @State private var warmModel = ""
    @State private var warmPrompt = ""
    @State private var isWarming = false
    @State private var warmResult: Int?
    @State private var transferTargetNode = ""
    @State private var isTransferring = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: i18n.t(.mn_kv_title), subtitle: i18n.t(.mn_kv_subtitle))

                statsStrip
                healthStrip
                searchSection
                warmSection
                transferSection
                hardwareSection
                byModelSection
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
        .onAppear {
            loadStats()
            loadHardware()
            checkHealth()
        }
    }

    private var statsStrip: some View {
        HStack(spacing: theme.spacingM) {
            MetricStripCard(
                icon: "internaldrive",
                label: i18n.t(.mn_kv_totalEntries),
                value: "\(kvStats?.totalEntries ?? 0)",
                subtitle: i18n.t(.mn_kv_cacheEntries)
            )
            MetricStripCard(
                icon: "arrow.down.doc",
                label: i18n.t(.mn_kv_totalSize),
                value: String(format: "%.1fMB", kvStats?.totalSizeMb ?? 0),
                subtitle: i18n.t(.mn_kv_cacheSpace)
            )
            MetricStripCard(
                icon: "chart.line.uptrend.xyaxis",
                label: i18n.t(.mn_kv_hitRate),
                value: String(format: "%.0f%%", (kvStats?.hitRate ?? 0) * 100),
                subtitle: i18n.t(.mn_kv_hitRateSub),
                dotColor: (kvStats?.hitRate ?? 0) > 0.5 ? theme.greenDot : theme.amberDot
            )
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingL)
    }

    private var searchSection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_kv_findCache))

            HStack(spacing: theme.spacingM) {
                TextField(i18n.t(.mn_kv_searchPh), text: $searchModel)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))

                FusionButton(i18n.t(.mn_kv_findBtn), icon: "magnifyingglass", style: .secondary, size: .small, isLoading: isSearching, isDisabled: searchModel.trimmingCharacters(in: .whitespaces).isEmpty) {
                    searchKV()
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)

            if let error = searchError {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.amberDot)
                    Text(error).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingXS)
            }

            if let entry = foundEntry {
                HStack(spacing: theme.spacingL) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.cacheId)
                            .font(.system(size: theme.footnoteSize, design: .monospaced))
                            .foregroundStyle(theme.text)
                        Text("Node: \(entry.nodeId)")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Spacer()
                    Text(String(format: "%.1fMB", entry.sizeMb))
                        .font(.system(size: theme.footnoteSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                    Text("×\(entry.accessCount)")
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
            }
        }
    }

    private var hardwareSection: some View {
        Group {
            if let hw = hardware {
                ListGroup {
                    StudioSectionHeader(title: i18n.t(.mn_kv_hwTitle))
                    if let nid = hw.nodeId {
                        StudioRow(label: i18n.t(.mn_kv_node), sublabel: nil) {
                            Text(nid).font(.system(size: theme.footnoteSize, design: .monospaced))
                        }
                    }
                    if let cpu = hw.cpuCores {
                        StudioRow(label: "CPU", sublabel: nil) {
                            Text("\(cpu) cores").font(.system(size: theme.footnoteSize))
                        }
                    }
                    if let mem = hw.memoryGB {
                        StudioRow(label: i18n.t(.mn_kv_memory), sublabel: nil) {
                            Text(String(format: "%.0f GB", mem)).font(.system(size: theme.footnoteSize))
                        }
                    }
                    if let gpu = hw.gpuCores {
                        StudioRow(label: "GPU", sublabel: nil) {
                            Text("\(gpu) cores").font(.system(size: theme.footnoteSize))
                        }
                    }
                    if let model = hw.deviceModel {
                        StudioRow(label: i18n.t(.mn_kv_device), sublabel: nil, isLast: true) {
                            Text(model).font(.system(size: theme.footnoteSize))
                        }
                    }
                }
            }
        }
    }

    private var healthStrip: some View {
        HStack(spacing: theme.spacingS) {
            Circle()
                .fill(agentHealthy == true ? theme.greenDot : (agentHealthy == false ? theme.redDot : theme.textTertiary))
                .frame(width: 8, height: 8)
            Text(agentHealthy == true ? i18n.t(.mn_kv_agentOnline) : (agentHealthy == false ? i18n.t(.mn_kv_agentOffline) : i18n.t(.mn_kv_checking)))
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            FusionButton(i18n.t(.refresh), icon: "arrow.clockwise", style: .ghost, size: .small) {
                checkHealth()
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingM)
    }

    private var warmSection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_kv_warmTitle))
            HStack(spacing: theme.spacingM) {
                TextField(i18n.t(.mn_kv_modelName), text: $warmModel)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                TextField(i18n.t(.mn_kv_warmPrompt), text: $warmPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize))
                FusionButton(i18n.t(.mn_kv_warmBtn), icon: "flame", style: .secondary, size: .small,
                    isLoading: isWarming, isDisabled: warmModel.trimmingCharacters(in: .whitespaces).isEmpty) {
                    warmKV()
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)

            if let warmed = warmResult {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.greenDot)
                    Text(String(format: i18n.t(.mn_kv_warmedFmt), warmed)).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingXS)
            }
        }
    }

    private var transferSection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_kv_transferTitle))
            HStack(spacing: theme.spacingM) {
                TextField(i18n.t(.mn_kv_targetNode), text: $transferTargetNode)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                FusionButton(i18n.t(.mn_kv_transferBtn), icon: "arrow.right.circle", style: .secondary, size: .small,
                    isLoading: isTransferring, isDisabled: foundEntry == nil || transferTargetNode.trimmingCharacters(in: .whitespaces).isEmpty) {
                    transferKV()
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
        }
    }

    private var byModelSection: some View {
        Group {
            if let byModel = kvStats?.byModel, !byModel.isEmpty {
                ListGroup {
                    StudioSectionHeader(title: i18n.t(.mn_kv_byModelTitle))
                    ForEach(Array(byModel.keys.sorted()), id: \.self) { model in
                        if let info = byModel[model] {
                            HStack(spacing: theme.spacingM) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model)
                                        .font(.system(size: theme.footnoteSize, weight: .medium))
                                        .foregroundStyle(theme.text)
                                        .lineLimit(1)
                                    Text(String(format: i18n.t(.mn_kv_countFmt), info.count))
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.textTertiary)
                                }
                                Spacer()
                                Text(String(format: "%.1fMB", info.sizeMb))
                                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                                    .foregroundStyle(theme.textSecondary)
                                if let avg = info.avgAccessCount {
                                    Text("avg ×\(String(format: "%.1f", avg))")
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.textTertiary)
                                }
                            }
                            .padding(.horizontal, theme.spacingL)
                            .padding(.vertical, theme.spacingS)
                        }
                    }
                }
            }
        }
    }

    private func loadStats() {
        engine.fetchAgentKVStats { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let s):
                    self.kvStats = s
                    kvLog.info("KV stats loaded: \(s.totalEntries) entries")
                case .failure(let error):
                    kvLog.error("KV stats failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadHardware() {
        engine.fetchAgentHardware { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let hw):
                    self.hardware = hw
                case .failure:
                    kvLog.debug("Agent hardware not available")
                }
            }
        }
    }

    private func searchKV() {
        let model = searchModel.trimmingCharacters(in: .whitespaces)
        guard !model.isEmpty else { return }
        isSearching = true
        searchError = nil
        foundEntry = nil
        kvLog.info("Searching KV cache for: \(model)")

        engine.findKVCache(modelName: model) { result in
            DispatchQueue.main.async {
                isSearching = false
                switch result {
                case .success(let entry):
                    self.foundEntry = entry
                    kvLog.info("Found KV cache: \(entry.cacheId)")
                case .failure(let error):
                    self.searchError = String(format: i18n.t(.mn_kv_notFoundFmt), error.localizedDescription)
                    kvLog.debug("KV find failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func checkHealth() {
        engine.checkAgentHealth { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ok):
                    self.agentHealthy = ok
                case .failure:
                    self.agentHealthy = false
                }
            }
        }
    }

    private func warmKV() {
        let model = warmModel.trimmingCharacters(in: .whitespaces)
        guard !model.isEmpty else { return }
        isWarming = true
        warmResult = nil
        let prompts = warmPrompt.trimmingCharacters(in: .whitespaces).isEmpty
            ? [model] : warmPrompt.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        engine.agentKVWarm(modelName: model, prompts: prompts) { result in
            DispatchQueue.main.async {
                isWarming = false
                switch result {
                case .success(let count):
                    self.warmResult = count
                    loadStats()
                    kvLog.info("KV warmed: \(count) entries")
                case .failure(let error):
                    kvLog.error("KV warm failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func transferKV() {
        guard let entry = foundEntry else { return }
        let target = transferTargetNode.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }
        isTransferring = true
        engine.agentKVTransfer(cacheId: entry.cacheId, targetNode: target) { result in
            DispatchQueue.main.async {
                isTransferring = false
                switch result {
                case .success(let ok):
                    if ok {
                        kvLog.info("KV transferred: \(entry.cacheId) -> \(target)")
                        loadStats()
                    } else {
                        kvLog.error("KV transfer returned false")
                    }
                case .failure(let error):
                    kvLog.error("KV transfer failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
