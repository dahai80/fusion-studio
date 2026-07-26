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

    @State private var kvStats: KVStatsResponse?
    @State private var hardware: AgentHardwareInfo?
    @State private var searchModel = ""
    @State private var foundEntry: KVCacheEntry?
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: "KV 缓存", subtitle: "管理集群 KV 缓存、查看命中率和节点分布")

                statsStrip
                searchSection
                hardwareSection
                byModelSection
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
        .onAppear {
            loadStats()
            loadHardware()
        }
    }

    private var statsStrip: some View {
        HStack(spacing: theme.spacingM) {
            MetricStripCard(
                icon: "internaldrive",
                label: "总条目",
                value: "\(kvStats?.totalEntries ?? 0)",
                subtitle: "缓存条目数"
            )
            MetricStripCard(
                icon: "arrow.down.doc",
                label: "总大小",
                value: String(format: "%.1fMB", kvStats?.totalSizeMb ?? 0),
                subtitle: "缓存占用空间"
            )
            MetricStripCard(
                icon: "chart.line.uptrend.xyaxis",
                label: "命中率",
                value: String(format: "%.0f%%", (kvStats?.hitRate ?? 0) * 100),
                subtitle: "KV 缓存命中",
                dotColor: (kvStats?.hitRate ?? 0) > 0.5 ? theme.greenDot : theme.amberDot
            )
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingL)
    }

    private var searchSection: some View {
        ListGroup {
            StudioSectionHeader(title: "查找缓存")

            HStack(spacing: theme.spacingM) {
                TextField("输入模型名称查找 KV 缓存...", text: $searchModel)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))

                FusionButton("查找", icon: "magnifyingglass", style: .secondary, size: .small, isLoading: isSearching, isDisabled: searchModel.trimmingCharacters(in: .whitespaces).isEmpty) {
                    searchKV()
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)

            if let err = searchError {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.amberDot)
                    Text(err).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
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
                    StudioSectionHeader(title: "Agent 硬件")
                    if let nid = hw.nodeId {
                        StudioRow(label: "节点", sublabel: nil) {
                            Text(nid).font(.system(size: theme.footnoteSize, design: .monospaced))
                        }
                    }
                    if let cpu = hw.cpuCores {
                        StudioRow(label: "CPU", sublabel: nil) {
                            Text("\(cpu) cores").font(.system(size: theme.footnoteSize))
                        }
                    }
                    if let mem = hw.memoryGB {
                        StudioRow(label: "内存", sublabel: nil) {
                            Text(String(format: "%.0f GB", mem)).font(.system(size: theme.footnoteSize))
                        }
                    }
                    if let gpu = hw.gpuCores {
                        StudioRow(label: "GPU", sublabel: nil) {
                            Text("\(gpu) cores").font(.system(size: theme.footnoteSize))
                        }
                    }
                    if let model = hw.deviceModel {
                        StudioRow(label: "设备", sublabel: nil, isLast: true) {
                            Text(model).font(.system(size: theme.footnoteSize))
                        }
                    }
                }
            }
        }
    }

    private var byModelSection: some View {
        Group {
            if let byModel = kvStats?.byModel, !byModel.isEmpty {
                ListGroup {
                    StudioSectionHeader(title: "按模型分布")
                    ForEach(Array(byModel.keys.sorted()), id: \.self) { model in
                        if let info = byModel[model] {
                            HStack(spacing: theme.spacingM) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model)
                                        .font(.system(size: theme.footnoteSize, weight: .medium))
                                        .foregroundStyle(theme.text)
                                        .lineLimit(1)
                                    Text("\(info.count) 条")
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
                case .failure(let err):
                    kvLog.error("KV stats failed: \(err.localizedDescription)")
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
                case .failure(let err):
                    self.searchError = "未找到该模型的 KV 缓存: \(err.localizedDescription)"
                    kvLog.debug("KV find failed: \(err.localizedDescription)")
                }
            }
        }
    }
}
