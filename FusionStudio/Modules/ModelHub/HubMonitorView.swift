// Callers: ModelHubMainView contentArea switch on .monitor.
// Affected API: ModelHubAPIClient getRealtimeMonitor/getHardware/getSystemStorage/getAuditLog
//   + listModels/listDeployments/getModelStats (new).
// Data schemas: HubMonitorResponse, HubHardwareResponse, HubStorageResponse, HubAuditLogResponse,
//   HubModel, HubDeployment, HubModelInferenceStats.
// PRD: Monitor + per-model inference stats + source filter + deployment metrics + health dots
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let monLog = Logger(subsystem: "com.fusion.studio", category: "HubMonitor")

struct HubMonitorView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var monitor: HubMonitorResponse?
    @State private var hardware: HubHardwareResponse?
    @State private var storage: HubStorageResponse?
    @State private var auditLogs: [HubAuditEntry] = []
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var pollTimer: Timer?
    @State private var statsTimer: Timer?

    // Audit filter
    @State private var auditSourceFilter: String = "all"
    @State private var auditPage = 1

    // Per-model inference stats
    @State private var modelStats: [HubModelInferenceStats] = []
    @State private var allModels: [HubModel] = []
    @State private var sourceFilter: String = "all"

    // Deployment metrics
    @State private var deployments: [HubDeployment] = []
    @State private var deploymentMetrics: [String: HubDeploymentMetricsResponse] = [:]
    @State private var selectedDeploymentId: String?

    private let auditSources = ["all", "Chat", "Code", "RAG", "Design", "CLI", "API"]
    private let sourceOptions = ["all", "local", "hub", "custom"]

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                hardwareSection
                realtimeSection
                modelInferenceSection
                deploymentMetricsSection
                storageSection
                auditSection
            }
            .padding(theme.spacingL)
        }
        .overlay { if isLoading && monitor == nil { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) } }
        .task { await loadAll(); startPolling() }
        .onDisappear { stopPolling() }
    }

    // MARK: - Hardware Section (unchanged)

    private var hardwareSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text(i18n.t(.hub_hardwareInfo))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if let hw = hardware {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingS) {
                        if let chip = hw.chip { HWCard(label: i18n.t(.hub_chip), value: chip, icon: "cpu") }
                        if let cores = hw.cpuCores { HWCard(label: i18n.t(.hub_cpuCores), value: "\(cores)", icon: "cpu") }
                        if let gpu = hw.gpuCores { HWCard(label: i18n.t(.hub_gpuCores), value: "\(gpu)", icon: "gpu") }
                        if let mem = hw.memoryGB { HWCard(label: i18n.t(.hub_memory), value: String(format: "%.0f GB", mem), icon: "memorychip") }
                        if let disk = hw.diskGB { HWCard(label: i18n.t(.hub_disk), value: String(format: "%.0f GB", disk), icon: "harddrive") }
                        if let free = hw.diskFree { HWCard(label: i18n.t(.hub_available), value: String(format: "%.0f GB", free), icon: "harddrive") }
                        if hw.metalSupport == true { HWCard(label: "Metal", value: i18n.t(.hub_supported), icon: "gpu") }
                        if hw.aneSupport == true { HWCard(label: "ANE", value: i18n.t(.hub_supported), icon: "brain") }
                        if let ne = hw.neuralEngineCores, ne > 0 { HWCard(label: i18n.t(.hub_neCores), value: "\(ne)", icon: "brain") }
                    }
                } else {
                    Text(i18n.t(.hub_loading)).foregroundStyle(theme.textTertiary)
                }
            }
            .padding(8)
        }
    }

    // MARK: - Realtime Section (unchanged)

    private var realtimeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text(i18n.t(.hub_realtimeMonitor))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if let mon = monitor {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingM) {
                        if let cpu = mon.cpu {
                            VStack(spacing: 4) {
                                Text("CPU").font(.caption).foregroundStyle(theme.textTertiary)
                                Text(String(format: "%.0f%%", cpu.usage ?? 0))
                                    .font(.system(size: theme.titleSize, weight: .bold))
                                    .foregroundStyle(cpu.usage ?? 0 > 80 ? .red : theme.text)
                                if let temp = cpu.temperature {
                                    Text(String(format: "%.0f°C", temp)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
                        }
                        if let gpu = mon.gpu {
                            VStack(spacing: 4) {
                                Text("GPU").font(.caption).foregroundStyle(theme.textTertiary)
                                Text(String(format: "%.0f%%", gpu.usage ?? 0))
                                    .font(.system(size: theme.titleSize, weight: .bold))
                                    .foregroundStyle(gpu.usage ?? 0 > 80 ? .red : theme.text)
                                if let memUsed = gpu.memoryUsed, let memTotal = gpu.memoryTotal {
                                    Text(String(format: "%.1f/%.1f GB", memUsed, memTotal)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
                        }
                        if let mem = mon.memory {
                            VStack(spacing: 4) {
                                Text(i18n.t(.hub_memory)).font(.caption).foregroundStyle(theme.textTertiary)
                                let used = mem.used ?? 0
                                let total = mem.total ?? 1
                                Text(String(format: "%.1f / %.1f GB", used, total))
                                    .font(.system(size: theme.titleSize, weight: .bold))
                                    .foregroundStyle(used / total > 0.85 ? .red : theme.text)
                                if let swap = mem.swap, swap > 0 {
                                    Text(String(format: "Swap: %.1f GB", swap)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
                        }
                        if let disk = mon.disk {
                            VStack(spacing: 4) {
                                Text(i18n.t(.hub_disk)).font(.caption).foregroundStyle(theme.textTertiary)
                                let used = disk.used ?? 0
                                let total = disk.total ?? 1
                                Text(String(format: "%.0f / %.0f GB", used, total))
                                    .font(.system(size: theme.titleSize, weight: .bold))
                                    .foregroundStyle(used / total > 0.9 ? .red : theme.text)
                                if let modelSize = disk.modelsSize, modelSize > 0 {
                                    Text(String(format: i18n.t(.hub_modelSizeFmt), modelSize)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
                        }
                    }
                    HStack(spacing: theme.spacingL) {
                        if let dl = mon.activeDownloads { Label(String(format: i18n.t(.hub_downloadLabel), dl), systemImage: "arrow.down.circle").font(.caption) }
                        if let qz = mon.activeQuantize { Label(String(format: i18n.t(.hub_quantLabel), qz), systemImage: "arrow.triangle.2.circlepath").font(.caption) }
                        if let up = mon.uptime { Label(String(format: i18n.t(.hub_runningLabel), up), systemImage: "clock").font(.caption) }
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text(i18n.t(.hub_loading)).foregroundStyle(theme.textTertiary)
                }
            }
            .padding(8)
        }
    }

    // MARK: - Per-model Inference Stats (NEW)

    private var modelInferenceSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                HStack {
                    Text(i18n.t(.hub_modelInferenceStats))
                        .font(.system(size: theme.headlineSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()

                    Picker(i18n.t(.hub_source), selection: $sourceFilter) {
                        ForEach(sourceOptions, id: \.self) { s in
                            Text(sourceFilterLabel(s)).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)

                    Button(action: { Task { await loadModelStats() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                if filteredModelRows.isEmpty {
                    Text(i18n.t(.hub_noInferenceData)).foregroundStyle(theme.textTertiary)
                } else {
                    modelStatsTableHeader
                    ForEach(filteredModelRows) { row in
                        modelStatsRow(row)
                    }
                    HStack {
                        Spacer()
                        Text(i18n.t(.hub_autoRefresh10s))
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .padding(8)
        }
    }

    private var modelStatsTableHeader: some View {
        HStack(spacing: 0) {
            Text("").frame(width: 16)
            Text(i18n.t(.hub_modelName))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(i18n.t(.hub_requestsPerMin))
                .frame(width: 72, alignment: .trailing)
            Text(i18n.t(.hub_latencyMs))
                .frame(width: 72, alignment: .trailing)
            Text("Tokens/s")
                .frame(width: 72, alignment: .trailing)
            Text(i18n.t(.hub_activeSessions))
                .frame(width: 72, alignment: .trailing)
            Text(i18n.t(.hub_memory))
                .frame(width: 72, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(theme.textTertiary)
        .padding(.horizontal, 4)
    }

    private func modelStatsRow(_ row: ModelStatRow) -> some View {
        HStack(spacing: 0) {
            healthDot(for: row.health)
                .frame(width: 16)

            Text(row.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.requestsPerMin)
                .frame(width: 72, alignment: .trailing)

            Text(row.avgLatencyMs)
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(latencyColor(row.avgLatencyMsValue))

            Text(row.tokensPerSec)
                .frame(width: 72, alignment: .trailing)

            Text(row.activeSessions)
                .frame(width: 72, alignment: .trailing)

            Text(row.memory)
                .frame(width: 72, alignment: .trailing)
        }
        .font(.system(size: theme.footnoteSize))
        .foregroundStyle(theme.text)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(theme.surfaceSecondary.opacity(0.4))
        )
    }

    // MARK: - Deployment Metrics Section (NEW)

    private var deploymentMetricsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                HStack {
                    Text(i18n.t(.hub_deployMetrics))
                        .font(.system(size: theme.headlineSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()

                    if !activeDeployments.isEmpty {
                        Text(String(format: i18n.t(.hub_activeDeploymentsFmt), activeDeployments.count))
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }

                    Button(action: { Task { await loadDeployments() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                if activeDeployments.isEmpty {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "shippingbox")
                            .foregroundStyle(theme.textTertiary)
                        Text(i18n.t(.hub_noActiveDeployments))
                            .foregroundStyle(theme.textTertiary)
                    }
                } else {
                    ForEach(activeDeployments) { dep in
                        deploymentMetricRow(dep)
                    }
                }
            }
            .padding(8)
        }
    }

    private func deploymentMetricRow(_ dep: HubDeployment) -> some View {
        let m = deploymentMetrics[dep.id]
        return HStack(spacing: theme.spacingM) {
            Circle()
                .fill(depStatusColor(dep.status))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(dep.modelName ?? dep.modelId ?? dep.id)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                HStack(spacing: theme.spacingS) {
                    Text(dep.statusLabel)
                        .font(.caption)
                    if let s = dep.scale {
                        Text(String(format: i18n.t(.hub_copiesFmt), s)).font(.caption)
                    }
                    if let c = dep.canaryPercent {
                        Text(String(format: i18n.t(.hub_grayCanary), c)).font(.caption)
                    }
                }
                .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            if let metrics = m {
                HStack(spacing: theme.spacingM) {
                    depMiniMetric("RPS", value: metrics.requestsPerSecond.map { String(format: "%.1f", $0) } ?? "--")
                    depMiniMetric(i18n.t(.hub_latencyLabel), value: metrics.avgLatencyMs.map { String(format: "%.0fms", $0) } ?? "--")
                    depMiniMetric(i18n.t(.hub_errorRate), value: metrics.errorRate.map { String(format: "%.1f%%", $0 * 100) } ?? "--")
                    depMiniMetric("T/s", value: metrics.tokensPerSecond.map { String(format: "%.0f", $0) } ?? "--")
                }
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceSecondary.opacity(0.3))
        )
        .onTapGesture {
            selectedDeploymentId = dep.id
            Task { await loadDeploymentMetrics(dep) }
        }
    }

    private func depMiniMetric(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.text)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(width: 56)
    }

    // MARK: - Storage Section (unchanged)

    private var storageSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text(i18n.t(.hub_storageDetail))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if let stor = storage {
                    let totalVal = stor.total ?? 0
                    let usedVal = stor.used ?? 0
                    let usedPct = totalVal > 0 ? usedVal / totalVal : 0
                    ProgressView(value: usedPct)
                        .tint(usedPct > 0.9 ? .red : .accentColor)
                    Text(String(format: i18n.t(.hub_usedStorageFmt), usedVal, totalVal, usedPct * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let models = stor.models {
                        HStack {
                            Text(i18n.t(.hub_model)).frame(width: 60, alignment: .leading)
                            Text(String(format: "%.1f GB", models.size ?? 0))
                            Spacer()
                            Text(String(format: i18n.t(.hub_countItemsFmt), models.count ?? 0))
                        }
                        .font(.caption)
                    }
                    if let cache = stor.cache {
                        HStack {
                            Text(i18n.t(.hub_cache)).frame(width: 60, alignment: .leading)
                            Text(String(format: "%.1f GB", cache.size ?? 0))
                            Spacer()
                            Text(String(format: i18n.t(.hub_countItemsFmt), cache.count ?? 0))
                        }
                        .font(.caption)
                    }

                    HStack {
                        Button(i18n.t(.hub_scanDuplicates)) { Task { await scanDuplicates() } }
                            .buttonStyle(.bordered).controlSize(.small)
                        Button(i18n.t(.hub_cleanupSystem)) { Task { await cleanupSystem() } }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                } else {
                    Text(i18n.t(.hub_loading)).foregroundStyle(theme.textTertiary)
                }
            }
            .padding(8)
        }
    }

    // MARK: - Audit Section (unchanged)

    private var auditSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack {
                    Text(i18n.t(.hub_auditLog))
                        .font(.system(size: theme.headlineSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()

                    Picker(i18n.t(.hub_source), selection: $auditSourceFilter) {
                        ForEach(auditSources, id: \.self) { s in
                            Text(s == "all" ? i18n.t(.hub_allSources) : s).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)

                    Button(i18n.t(.hub_exportCsv)) {
                        exportAuditCSV()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if filteredAuditLogs.isEmpty {
                    Text(i18n.t(.hub_noAuditLogs)).foregroundStyle(theme.textTertiary)
                } else {
                    ForEach(filteredAuditLogs.prefix(30)) { entry in
                        HStack(spacing: theme.spacingS) {
                            Text(entry.timestamp ?? "").font(.caption2).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
                            if let action = entry.action {
                                Text(action).font(.caption).foregroundStyle(theme.text)
                            }
                            Spacer()
                            if let src = entry.source {
                                Text(src).font(.caption2)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            if let res = entry.resource { Text(res).font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                    if auditLogs.count > 30 {
                        Text(String(format: i18n.t(.hub_auditShowingFmt), auditLogs.count))
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .padding(8)
        }
    }

    // MARK: - Computed helpers

    private var filteredAuditLogs: [HubAuditEntry] {
        if auditSourceFilter == "all" { return auditLogs }
        return auditLogs.filter { $0.source == auditSourceFilter }
    }

    private var activeDeployments: [HubDeployment] {
        deployments.filter { $0.isRunning || $0.status == "pending" }
    }

    private var filteredModelRows: [ModelStatRow] {
        let rows = buildModelStatRows()
        if sourceFilter == "all" { return rows }
        return rows.filter { $0.source == sourceFilter }
    }

    // MARK: - Health dot helper

    private func healthDot(for health: ModelHealth) -> some View {
        Circle()
            .fill(healthColor(health))
            .frame(width: 8, height: 8)
            .help(healthLabel(health))
    }

    private func healthColor(_ health: ModelHealth) -> Color {
        switch health {
        case .healthy: return .green
        case .warning: return .yellow
        case .error: return .red
        }
    }

    private func healthLabel(_ health: ModelHealth) -> String {
        switch health {
        case .healthy: return i18n.t(.hub_health_healthy)
        case .warning: return i18n.t(.hub_health_warning)
        case .error: return i18n.t(.hub_health_error)
        }
    }

    private func depStatusColor(_ status: String?) -> Color {
        switch status {
        case "running", "active": return .green
        case "stopped": return .gray
        case "pending": return .orange
        case "failed", "error": return .red
        default: return .secondary
        }
    }

    private func sourceFilterLabel(_ s: String) -> String {
        switch s {
        case "all": return i18n.t(.hub_allSources)
        case "local": return i18n.t(.hub_sourceLocal)
        case "hub": return "Hub"
        case "custom": return i18n.t(.hub_custom)
        default: return s
        }
    }

    private func latencyColor(_ msStr: String) -> Color {
        guard let val = Double(msStr) else { return theme.text }
        if val > 2000 { return .red }
        if val > 800 { return .yellow }
        return theme.text
    }

    // MARK: - Model stat row builder

    private enum ModelHealth { case healthy, warning, error }

    private struct ModelStatRow: Identifiable {
        let id: String
        let name: String
        let source: String
        let requestsPerMin: String
        let avgLatencyMs: String
        let avgLatencyMsValue: String
        let tokensPerSec: String
        let activeSessions: String
        let memory: String
        let health: ModelHealth
    }

    private func buildModelStatRows() -> [ModelStatRow] {
        var rows: [ModelStatRow] = []

        for stat in modelStats {
            let rpm = stat.requestsPerMin.map { String(format: "%.0f", $0) } ?? "--"
            let avgLat = stat.avgLatencyMs.map { String(format: "%.0f", $0) } ?? "--"
            let tps = stat.tokensPerSecond.map { String(format: "%.1f", $0) } ?? "--"
            let memMB = stat.memoryMB ?? 0
            let memStr = memMB > 1024
                ? String(format: "%.1f GB", memMB / 1024.0)
                : memMB > 0 ? String(format: "%.0f MB", memMB) : "--"
            let sessions = stat.activeSessions.map { "\($0)" } ?? "--"

            let health: ModelHealth
            if stat.avgLatencyMs ?? 0 > 2000 {
                health = .error
            } else if stat.tokensPerSecond ?? 0 < 5.0 && stat.activeSessions ?? 0 == 0 {
                health = .warning
            } else {
                health = .healthy
            }

            rows.append(ModelStatRow(
                id: stat.id,
                name: stat.modelName ?? stat.modelId ?? stat.id,
                source: stat.source ?? "local",
                requestsPerMin: rpm,
                avgLatencyMs: avgLat,
                avgLatencyMsValue: avgLat,
                tokensPerSec: tps,
                activeSessions: sessions,
                memory: memStr,
                health: health
            ))
        }

        for model in allModels {
            if rows.contains(where: { $0.id == model.id }) { continue }
            let isActive = model.isActive == true || model.isServing == true
            if !isActive { continue }

            let memStr = model.sizeBytes.map { bytes in
                let gb = Double(bytes) / 1_073_741_824.0
                return String(format: "%.1f GB", gb)
            } ?? "--"

            rows.append(ModelStatRow(
                id: model.id,
                name: model.displayTitle,
                source: model.source ?? "local",
                requestsPerMin: "--",
                avgLatencyMs: "--",
                avgLatencyMsValue: "0",
                tokensPerSec: "--",
                activeSessions: "--",
                memory: memStr,
                health: .warning
            ))
        }

        return rows
    }

    // MARK: - Data loading

    private func loadAll() async {
        isLoading = true
        do {
            async let monResp = client.getRealtimeMonitor()
            async let hwResp = client.getHardware()
            async let storResp = client.getSystemStorage()
            async let logResp = client.getAuditLog(limit: 100)
            async let modelsResp = client.listModels()
            async let depResp = client.listDeployments()
            async let statsResp = client.getModelStats()

            monitor = try await monResp
            hardware = try await hwResp
            storage = try await storResp
            auditLogs = (try await logResp).logs
            allModels = (try await modelsResp).models
            deployments = (try await depResp).deployments
            modelStats = (try await statsResp).stats

            monLog.info("Monitor loaded: \(allModels.count) models, \(deployments.count) deployments, \(modelStats.count) stats")

            await loadActiveDeploymentMetrics()
        } catch {
            lastError = BridgeError.sanitize(error)
            monLog.warning("Monitor load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func loadModelStats() async {
        do {
            async let statsResp = client.getModelStats()
            async let modelsResp = client.listModels()
            modelStats = (try await statsResp).stats
            allModels = (try await modelsResp).models
            monLog.info("Model stats refreshed: \(modelStats.count) stats")
        } catch {
            monLog.warning("Model stats refresh failed: \(error.localizedDescription)")
        }
    }

    private func loadDeployments() async {
        do {
            let resp = try await client.listDeployments()
            deployments = resp.deployments
            monLog.info("Deployments loaded: \(deployments.count)")
            await loadActiveDeploymentMetrics()
        } catch {
            monLog.warning("Deployments load failed: \(error.localizedDescription)")
        }
    }

    private func loadActiveDeploymentMetrics() async {
        for dep in deployments where dep.isRunning {
            await loadDeploymentMetrics(dep)
        }
    }

    private func loadDeploymentMetrics(_ dep: HubDeployment) async {
        do {
            let m = try await client.getDeploymentMetrics(id: dep.id)
            deploymentMetrics[dep.id] = m
            monLog.info("Deployment metrics loaded for \(dep.id)")
        } catch {
            monLog.warning("Deployment metrics failed for \(dep.id): \(error.localizedDescription)")
        }
    }

    private func scanDuplicates() async {
        do {
            _ = try await client.scanDuplicates()
            monLog.info("Duplicate scan triggered")
        } catch {
            lastError = BridgeError.sanitize(error)
        }
    }

    private func cleanupSystem() async {
        do {
            _ = try await client.cleanupSystem()
            monLog.info("System cleanup triggered")
        } catch {
            lastError = BridgeError.sanitize(error)
        }
    }

    private func exportAuditCSV() {
        let logs = filteredAuditLogs
        var csv = i18n.t(.hub_csvHeader)
        for entry in logs {
            let fields = [
                entry.id,
                entry.timestamp ?? "",
                entry.action ?? "",
                entry.source ?? "",
                entry.resource ?? "",
                entry.user ?? "",
                (entry.details ?? "").replacingOccurrences(of: "\"", with: "\"\""),
            ]
            csv += fields.map { "\"\($0)\"" }.joined(separator: ",") + "\n"
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "audit_log_\(Int(Date().timeIntervalSince1970)).csv"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                    monLog.info("Audit CSV exported: \(url.path)")
                } catch {
                    monLog.error("CSV export failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                if let mon = try? await client.getRealtimeMonitor() { monitor = mon }
            }
        }
        statsTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                await loadModelStats()
                await loadActiveDeploymentMetrics()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        statsTimer?.invalidate()
        statsTimer = nil
    }
}

private struct HWCard: View {
    let label: String
    let value: String
    let icon: String
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundStyle(theme.textTertiary)
                Text(value).font(.system(size: theme.footnoteSize, weight: .medium)).foregroundStyle(theme.text)
            }
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, 4)
    }
}
