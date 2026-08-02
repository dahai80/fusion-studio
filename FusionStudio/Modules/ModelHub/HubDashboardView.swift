// Callers: ModelHubMainView contentArea switch on .dashboard.
// Affected API: ModelHubAPIClient listModels/listDownloads/listRunningQuantize/listClusterNodes/getRealtimeMonitor.
// Data schemas: HubDashboardStats, HubModel, HubMonitorResponse.
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let dashLog = Logger(subsystem: "com.fusion.studio", category: "HubDashboard")

struct HubDashboardView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme

    @State private var stats = HubDashboardStats()
    @State private var recentModels: [HubModel] = []
    @State private var monitor: HubMonitorResponse?
    @State private var isLoading = false
    @State private var lastError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                statsGrid
                quickActions
                recentSection
                systemOverview
            }
            .padding(theme.spacingL)
        }
        .overlay { if isLoading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) } }
        .task { await loadDashboard() }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
        ], spacing: theme.spacingM) {
            HubStatCard(title: "本地模型", value: "\(stats.downloadedModels)", icon: "internaldrive", color: .blue)
            HubStatCard(title: "活跃模型", value: "\(stats.activeModels)", icon: "bolt.fill", color: .green)
            HubStatCard(title: "下载中", value: "\(stats.downloadsInProgress)", icon: "arrow.down.circle", color: .orange)
            HubStatCard(title: "总存储", value: String(format: "%.1f GB", stats.totalSizeGB), icon: "harddrive", color: .purple)
            HubStatCard(title: "置顶", value: "\(stats.pinnedModels)", icon: "pin.fill", color: .yellow)
            HubStatCard(title: "量化中", value: "\(stats.quantizeInProgress)", icon: "arrow.triangle.2.circlepath", color: .cyan)
            HubStatCard(title: "集群节点", value: "\(stats.clusterNodesOnline)/\(stats.clusterNodesTotal)", icon: "server.rack", color: .indigo)
            HubStatCard(title: "模型总数", value: "\(stats.totalModels)", icon: "cube.box", color: .gray)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("快捷操作")
                .font(.system(size: theme.headlineSize, weight: .semibold))
                .foregroundStyle(theme.text)

            HStack(spacing: theme.spacingM) {
                QuickActionButton(title: "搜索市场", icon: "magnifyingglass", color: .blue) {
                    dashLog.info("Quick action: search market")
                }
                QuickActionButton(title: "下载模型", icon: "icloud.and.arrow.down", color: .green) {
                    dashLog.info("Quick action: download model")
                }
                QuickActionButton(title: "量化模型", icon: "arrow.triangle.2.circlepath", color: .orange) {
                    dashLog.info("Quick action: quantize model")
                }
                QuickActionButton(title: "系统清理", icon: "trash.circle", color: .red) {
                    Task { await cleanupSystem() }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("最近模型")
                .font(.system(size: theme.headlineSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if recentModels.isEmpty {
                Text("暂无模型")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(theme.spacingL)
            } else {
                ForEach(recentModels.prefix(5)) { model in
                    HStack(spacing: theme.spacingM) {
                        Image(systemName: model.isActive == true ? "bolt.fill" : "cube")
                            .foregroundStyle(model.isActive == true ? .green : theme.textTertiary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayTitle)
                                .font(.system(size: theme.textSize, weight: .medium))
                                .foregroundStyle(theme.text)
                            HStack(spacing: theme.spacingS) {
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
                    .padding(theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfacePrimary))
                }
            }
        }
    }

    private var systemOverview: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("系统概览")
                .font(.system(size: theme.headlineSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if let mon = monitor {
                HStack(spacing: theme.spacingL) {
                    if let cpu = mon.cpu {
                        MetricView(label: "CPU", value: String(format: "%.0f%%", cpu.usage ?? 0), icon: "cpu")
                    }
                    if let gpu = mon.gpu {
                        MetricView(label: "GPU", value: String(format: "%.0f%%", gpu.usage ?? 0), icon: "gpu")
                    }
                    if let mem = mon.memory {
                        MetricView(label: "内存", value: String(format: "%.1f/%.1f GB", mem.used ?? 0, mem.total ?? 0), icon: "memorychip")
                    }
                    if let disk = mon.disk {
                        MetricView(label: "磁盘", value: String(format: "%.0f/%.0f GB", disk.used ?? 0, disk.total ?? 0), icon: "harddrive")
                    }
                    if let up = mon.uptime {
                        MetricView(label: "运行时间", value: up, icon: "clock")
                    }
                }
            } else {
                Text("加载中...")
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    private func loadDashboard() async {
        isLoading = true
        lastError = nil
        do {
            async let modelsResp = client.listModels()
            async let downloadsResp = client.listDownloads()
            async let quantizeResp = client.listRunningQuantize()
            async let clusterResp = client.listClusterNodes()
            async let monitorResp = client.getRealtimeMonitor()

            let models = try await modelsResp
            let downloads = try await downloadsResp
            let running = try await quantizeResp
            let cluster = try await clusterResp
            monitor = try await monitorResp

            stats = HubDashboardStats(
                totalModels: models.total ?? models.models.count,
                downloadedModels: models.models.filter { $0.isDownloaded == true }.count,
                activeModels: models.models.filter { $0.isActive == true }.count,
                pinnedModels: models.models.filter { $0.isPinned == true }.count,
                totalSizeGB: models.models.reduce(0) { $0 + $1.sizeGB },
                downloadsInProgress: downloads.tasks.filter { !$0.isComplete && !$0.isFailed }.count,
                quantizeInProgress: running.tasks.filter { !$0.isComplete && !$0.isFailed }.count,
                clusterNodesOnline: cluster.nodes.filter { $0.isOnline }.count,
                clusterNodesTotal: cluster.total ?? cluster.nodes.count
            )
            recentModels = Array(models.models.prefix(10))
            dashLog.info("Dashboard loaded: \(stats.totalModels) models, \(stats.downloadedModels) downloaded")
        } catch {
            lastError = error.localizedDescription
            dashLog.warning("Dashboard load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func cleanupSystem() async {
        do {
            _ = try await client.cleanupSystem()
            dashLog.info("System cleanup triggered")
        } catch {
            dashLog.error("Cleanup failed: \(error.localizedDescription)")
        }
    }
}

struct HubStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: theme.titleSize, weight: .bold))
                .foregroundStyle(theme.text)
            Text(title)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingM)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(theme.surfacePrimary))
    }
}

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @Environment(\.studioTheme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: theme.spacingXS) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.text)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacingM)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(theme.surfacePrimary))
        }
        .buttonStyle(.plain)
    }
}

private struct MetricView: View {
    let label: String
    let value: String
    let icon: String
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.secondary)
            Text(value).font(.system(size: theme.footnoteSize, weight: .medium)).foregroundStyle(theme.text)
            Text(label).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
        }
    }
}
