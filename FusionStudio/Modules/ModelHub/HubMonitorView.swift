// Callers: ModelHubMainView contentArea switch on .monitor.
// Affected API: ModelHubAPIClient getRealtimeMonitor/getHardware/getSystemStorage/getAuditLog.
// Data schemas: HubMonitorResponse, HubHardwareResponse, HubStorageResponse, HubAuditLogResponse.
// PRD: Monitor + call-source filter + audit log CSV export
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

    // Audit filter
    @State private var auditSourceFilter: String = "all"
    @State private var auditPage = 1

    private let auditSources = ["all", "Chat", "Code", "RAG", "Design", "CLI", "API"]

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
                        if let mem = hw.memoryGB { HWCard(label: "内存", value: String(format: "%.0f GB", mem), icon: "memorychip") }
                        if let disk = hw.diskGB { HWCard(label: "磁盘", value: String(format: "%.0f GB", disk), icon: "harddrive") }
                        if let free = hw.diskFree { HWCard(label: "可用", value: String(format: "%.0f GB", free), icon: "harddrive") }
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
                    let totalVal = stor.total ?? 0
                    let usedVal = stor.used ?? 0
                    let usedPct = totalVal > 0 ? usedVal / totalVal : 0
                    ProgressView(value: usedPct)
                        .tint(usedPct > 0.9 ? .red : .accentColor)
                    Text(String(format: "已使用 %.1f / %.1f GB (%.0f%%)", usedVal, totalVal, usedPct * 100))
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

    // PRD: call-source filter + CSV export
    private var auditSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                HStack {
                    Text("操作日志")
                        .font(.system(size: theme.headlineSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()

                    Picker("来源", selection: $auditSourceFilter) {
                        ForEach(auditSources, id: \.self) { s in
                            Text(s == "all" ? "全部来源" : s).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)

                    Button("导出 CSV") {
                        exportAuditCSV()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if filteredAuditLogs.isEmpty {
                    Text("暂无操作日志").foregroundStyle(theme.textTertiary)
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
                        Text("显示前 30 条，共 \(auditLogs.count) 条")
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .padding(8)
        }
    }

    private var filteredAuditLogs: [HubAuditEntry] {
        if auditSourceFilter == "all" { return auditLogs }
        return auditLogs.filter { $0.source == auditSourceFilter }
    }

    // MARK: - Data loading

    private func loadAll() async {
        isLoading = true
        do {
            async let monResp = client.getRealtimeMonitor()
            async let hwResp = client.getHardware()
            async let storResp = client.getSystemStorage()
            async let logResp = client.getAuditLog(limit: 100)
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

    private func exportAuditCSV() {
        let logs = filteredAuditLogs
        var csv = "ID,时间,操作,来源,资源,用户,详情\n"
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
