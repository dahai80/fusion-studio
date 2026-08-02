// Callers: ModelHubMainView contentArea switch on .monitor.
// Affected API: ModelHubAPIClient getRealtimeMonitor/getHardware/getSystemStorage/getAuditLog.
// Data schemas: HubMonitorResponse, HubHardwareResponse, HubStorageResponse, HubAuditLogResponse.
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let monLog = Logger(subsystem: "com.fusion.studio", category: "HubMonitor")

struct HubMonitorView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme

    @State private var monitor: HubMonitorResponse?
    @State private var hardware: HubHardwareResponse?
    @State private var storage: HubStorageResponse?
    @State private var auditLogs: [HubAuditEntry] = []
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var pollTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                hardwareSection
                realtimeSection
                storageSection
                auditSection
            }
            .padding(theme.spacingL)
        }
        .overlay { if isLoading && monitor == nil { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) } }
        .task { await loadAll(); startPolling() }
        .onDisappear { stopPolling() }
    }

    private var hardwareSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("硬件信息")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if let hw = hardware {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingS) {
                        if let chip = hw.chip { HWCard(label: "芯片", value: chip, icon: "cpu") }
                        if let cores = hw.cpuCores { HWCard(label: "CPU 核心", value: "\(cores)", icon: "cpu") }
                        if let gpu = hw.gpuCores { HWCard(label: "GPU 核心", value: "\(gpu)", icon: "gpu") }
                        HWCard(label: "内存", value: String(format: "%.0f GB", hw.memoryGB), icon: "memorychip")
                        HWCard(label: "磁盘", value: String(format: "%.0f GB", hw.diskGB), icon: "harddrive")
                        HWCard(label: "可用", value: String(format: "%.0f GB", hw.diskFree), icon: "harddrive")
                        if hw.metalSupport == true { HWCard(label: "Metal", value: "支持", icon: "gpu") }
                        if hw.aneSupport == true { HWCard(label: "ANE", value: "支持", icon: "brain") }
                        if let ne = hw.neuralEngineCores, ne > 0 { HWCard(label: "NE 核心", value: "\(ne)", icon: "brain") }
                    }
                } else {
                    Text("加载中...").foregroundStyle(theme.textTertiary)
                }
            }
            .padding(8)
        }
    }

    private var realtimeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("实时监控")
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
                                Text("内存").font(.caption).foregroundStyle(theme.textTertiary)
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
                                Text("磁盘").font(.caption).foregroundStyle(theme.textTertiary)
                                let used = disk.used ?? 0
                                let total = disk.total ?? 1
                                Text(String(format: "%.0f / %.0f GB", used, total))
                                    .font(.system(size: theme.titleSize, weight: .bold))
                                    .foregroundStyle(used / total > 0.9 ? .red : theme.text)
                                if let modelSize = disk.modelsSize, modelSize > 0 {
                                    Text(String(format: "模型: %.1f GB", modelSize)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
                        }
                    }
                    HStack(spacing: theme.spacingL) {
                        if let dl = mon.activeDownloads { Label("下载: \(dl)", systemImage: "arrow.down.circle").font(.caption) }
                        if let qz = mon.activeQuantize { Label("量化: \(qz)", systemImage: "arrow.triangle.2.circlepath").font(.caption) }
                        if let up = mon.uptime { Label("运行: \(up)", systemImage: "clock").font(.caption) }
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text("加载中...").foregroundStyle(theme.textTertiary)
                }
            }
            .padding(8)
        }
    }

    private var storageSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("存储详情")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if let stor = storage {
                    let usedPct = stor.total ?? 0 > 0 ? (stor.used ?? 0) / (stor.total ?? 1) : 0
                    ProgressView(value: usedPct)
                        .tint(usedPct > 0.9 ? .red : .accentColor)
                    Text(String(format: "已使用 %.1f / %.1f GB (%.0f%%)", stor.used ?? 0, stor.total ?? 0, usedPct * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let models = stor.models {
                        HStack {
                            Text("模型").frame(width: 60, alignment: .leading)
                            Text(String(format: "%.1f GB", models.size ?? 0))
                            Spacer()
                            Text("\(models.count ?? 0) 个")
                        }
                        .font(.caption)
                    }
                    if let cache = stor.cache {
                        HStack {
                            Text("缓存").frame(width: 60, alignment: .leading)
                            Text(String(format: "%.1f GB", cache.size ?? 0))
                            Spacer()
                            Text("\(cache.count ?? 0) 个")
                        }
                        .font(.caption)
                    }

                    HStack {
                        Button("扫描重复") { Task { await scanDuplicates() } }
                            .buttonStyle(.bordered).controlSize(.small)
                        Button("清理系统") { Task { await cleanupSystem() } }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                } else {
                    Text("加载中...").foregroundStyle(theme.textTertiary)
                }
            }
            .padding(8)
        }
    }

    private var auditSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("操作日志")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if auditLogs.isEmpty {
                    Text("暂无操作日志").foregroundStyle(theme.textTertiary)
                } else {
                    ForEach(auditLogs.prefix(20)) { entry in
                        HStack(spacing: theme.spacingS) {
                            Text(entry.timestamp ?? "").font(.caption2).foregroundStyle(.secondary).frame(width: 140, alignment: .leading)
                            Text(entry.action ?? "").font(.caption).foregroundStyle(theme.text)
                            Spacer()
                            if let res = entry.resource { Text(res).font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private func loadAll() async {
        isLoading = true
        do {
            async let monResp = client.getRealtimeMonitor()
            async let hwResp = client.getHardware()
            async let storResp = client.getSystemStorage()
            async let logResp = client.getAuditLog(limit: 50)
            monitor = try await monResp
            hardware = try await hwResp
            storage = try await storResp
            auditLogs = (try await logResp).logs
        } catch {
            lastError = error.localizedDescription
            monLog.warning("Monitor load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func scanDuplicates() async {
        do {
            _ = try await client.scanDuplicates()
            monLog.info("Duplicate scan triggered")
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func cleanupSystem() async {
        do {
            _ = try await client.cleanupSystem()
            monLog.info("System cleanup triggered")
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                if let mon = try? await client.getRealtimeMonitor() { monitor = mon }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
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
