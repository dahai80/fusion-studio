// Callers: ModelHubMainView contentArea switch on .dashboard.
// Affected API: ModelHubAPIClient listModels/listDownloads/listRunningQuantize/listClusterNodes/getRealtimeMonitor.
// Data schemas: HubDashboardStats, HubModel, HubMonitorResponse.
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let dashLog = Logger(subsystem: "com.fusion.studio", category: "HubDashboard")

struct HubDashboardView: View {
    @ObservedObject var client: ModelHubAPIClient
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.studioTheme) private var theme
    var navigateTo: ((ModelHubSection) -> Void)?

    @State private var stats = HubDashboardStats()
    @State private var recentModels: [HubModel] = []
    @State private var monitor: HubMonitorResponse?
    @State private var health: HubHealthResponse?
    @State private var isLoading = false
    @State private var lastError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                statsGrid
                statusBadges
                quickActions
                recentSection
                systemOverview
            }
            .padding(theme.spacingL)
        }
        .overlay { if isLoading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) } }
        .task { await loadDashboard() }
    }

    private var statusBadges: some View {
        HStack(spacing: theme.spacingM) {
            StatusBadge(label: i18n.t(.hub_dash_mlxEngine), isOn: health?.mlxConnected ?? false, onIcon: "bolt.fill", offIcon: "bolt.slash")
            StatusBadge(label: i18n.t(.hub_dash_clusterMode), isOn: stats.clusterNodesOnline > 0, onIcon: "server.rack", offIcon: "desktopcomputer")
            StatusBadge(label: i18n.t(.hub_dash_modelService), isOn: stats.servingModels > 0, onIcon: "play.circle.fill", offIcon: "pause.circle")
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
        ], spacing: theme.spacingM) {
            HubStatCard(title: i18n.t(.hub_dash_localModels), value: "\(stats.downloadedModels)", icon: "internaldrive", color: .blue)
            HubStatCard(title: i18n.t(.hub_dash_activeModels), value: "\(stats.activeModels)", icon: "bolt.fill", color: .green)
            HubStatCard(title: i18n.t(.hub_dash_downloading), value: "\(stats.downloadsInProgress)", icon: "arrow.down.circle", color: .orange)
            HubStatCard(title: i18n.t(.hub_dash_totalStorage), value: String(format: "%.1f GB", stats.totalSizeGB), icon: "harddrive", color: .purple)
            HubStatCard(title: i18n.t(.hub_dash_pinned), value: "\(stats.pinnedModels)", icon: "pin.fill", color: .yellow)
            HubStatCard(title: i18n.t(.hub_dash_quantizing), value: "\(stats.quantizeInProgress)", icon: "arrow.triangle.2.circlepath", color: .cyan)
            HubStatCard(title: i18n.t(.hub_dash_clusterNodes), value: "\(stats.clusterNodesOnline)/\(stats.clusterNodesTotal)", icon: "server.rack", color: .indigo)
            HubStatCard(title: i18n.t(.hub_dash_totalModels), value: "\(stats.totalModels)", icon: "cube.box", color: .gray)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.hub_dash_quickActions))
                .font(.system(size: theme.headlineSize, weight: .semibold))
                .foregroundStyle(theme.text)

            HStack(spacing: theme.spacingM) {
                QuickActionButton(title: i18n.t(.hub_dash_searchMarket), icon: "magnifyingglass", color: .blue) {
                    navigateTo?(.market)
                }
                QuickActionButton(title: i18n.t(.hub_dash_downloadModel), icon: "icloud.and.arrow.down", color: .green) {
                    navigateTo?(.market)
                }
                QuickActionButton(title: i18n.t(.hub_dash_quantizeModel), icon: "arrow.triangle.2.circlepath", color: .orange) {
                    navigateTo?(.convertQuant)
                }
                QuickActionButton(title: i18n.t(.hub_dash_systemClean), icon: "trash.circle", color: .red) {
                    Task { await cleanupSystem() }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.hub_dash_recentModels))
                .font(.system(size: theme.headlineSize, weight: .semibold))
                .foregroundStyle(theme.text)

            if recentModels.isEmpty {
                Text(i18n.t(.hub_dash_noModels))
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(theme.spacingL)
            } else {
                ForEach(recentModels.prefix(5)) { model in
                    HStack(spacing: theme.spacingM) {
                        Image(systemName: model.isServing == true ? "bolt.fill" : (model.isActive == true ? "circle.fill" : "cube"))
                            .foregroundStyle(model.isServing == true ? .green : (model.isActive == true ? .yellow : theme.textTertiary))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: theme.spacingXS) {
                                Text(model.displayTitle)
                                    .font(.system(size: theme.textSize, weight: .medium))
                                    .foregroundStyle(theme.text)
                                if model.isPinned == true {
                                    Text(i18n.t(.hub_dash_resident)).font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.yellow)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.yellow.opacity(0.15)))
                                }
                                if model.isServing == true {
                                    Text(i18n.t(.hub_dash_serving)).font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.green.opacity(0.15)))
                                }
                            }
                            HStack(spacing: theme.spacingS) {
                                if let fam = model.family { Text(fam).font(.caption).foregroundStyle(.secondary) }
                                if let q = model.quantization { Text(q).font(.caption).foregroundStyle(.secondary) }
                                if model.sizeGB > 0 { Text(model.sizeFormatted).font(.caption).foregroundStyle(.secondary) }
                                if let hint = model.fusionModuleHint {
                                    Text(hint).font(.caption).foregroundStyle(.blue)
                                }
                            }
                        }
                        Spacer()
                        if let modules = model.allowedModules, !modules.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(modules.prefix(3), id: \.self) { mod in
                                    Text(mod).font(.system(size: 8))
                                        .padding(.horizontal, 3).padding(.vertical, 1)
                                        .background(Capsule().fill(theme.accent.opacity(0.1)))
                                        .foregroundStyle(theme.accent)
                                }
                            }
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
            Text(i18n.t(.hub_dash_sysOverview))
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
                        MetricView(label: i18n.t(.hub_dash_memory), value: String(format: "%.1f/%.1f GB", mem.used ?? 0, mem.total ?? 0), icon: "memorychip")
                    }
                    if let disk = mon.disk {
                        MetricView(label: i18n.t(.hub_dash_disk), value: String(format: "%.0f/%.0f GB", disk.used ?? 0, disk.total ?? 0), icon: "harddrive")
                    }
                    if let up = mon.uptime {
                        MetricView(label: i18n.t(.hub_dash_uptime), value: up, icon: "clock")
                    }
                }
            } else {
                Text(i18n.t(.hub_dash_loading))
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
            async let healthResp = client.getSystemHealth()

            let models = try await modelsResp
            let downloads = try await downloadsResp
            let running = try await quantizeResp
            let cluster = try await clusterResp
            monitor = try await monitorResp
            health = try await healthResp

            stats = HubDashboardStats(
                totalModels: models.total ?? models.models.count,
                downloadedModels: models.models.filter { $0.isDownloaded == true }.count,
                activeModels: models.models.filter { $0.isActive == true }.count,
                pinnedModels: models.models.filter { $0.isPinned == true }.count,
                totalSizeGB: models.models.reduce(0) { $0 + $1.sizeGB },
                downloadsInProgress: downloads.tasks.filter { !$0.isComplete && !$0.isFailed }.count,
                quantizeInProgress: running.tasks.filter { !$0.isComplete && !$0.isFailed }.count,
                clusterNodesOnline: cluster.nodes.filter { $0.isOnline }.count,
                clusterNodesTotal: cluster.total ?? cluster.nodes.count,
                servingModels: models.models.filter { $0.isServing == true }.count,
                mlxConnected: health?.mlxConnected ?? false
            )
            recentModels = Array(models.models.prefix(10))
            dashLog.info("Dashboard loaded: \(stats.totalModels) models, \(stats.downloadedModels) downloaded, \(stats.servingModels) serving")
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

private struct StatusBadge: View {
    let label: String
    let isOn: Bool
    let onIcon: String
    let offIcon: String
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isOn ? onIcon : offIcon)
                .font(.system(size: 10))
                .foregroundStyle(isOn ? .green : .secondary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isOn ? .green : theme.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(isOn ? Color.green.opacity(0.1) : theme.surfacePrimary)
        )
    }
}
