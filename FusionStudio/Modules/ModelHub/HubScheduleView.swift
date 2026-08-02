// Callers: ModelHubMainView contentArea switch on .schedule.
// Affected API: ModelHubAPIClient listDownloads/createDownload/getDownload + scheduling config.
// Data schemas: HubDownloadTask, HubDownloadListResponse, HubDownloadTaskResponse, HubMonitorResponse.
// PRD Page 5: 算力调度策略 + 下载调度合并页
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let schedLog = Logger(subsystem: "com.fusion.studio", category: "HubSchedule")

struct HubScheduleView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme

    @State private var selectedTab = 0
    @State private var tasks: [HubDownloadTask] = []
    @State private var monitor: HubMonitorResponse?
    @State private var models: [HubModel] = []
    @State private var clusterNodes: [HubClusterNode] = []
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var pollTimer: Timer?

    // Schedule config
    @AppStorage("hubSchedulePolicy") private var schedulePolicy = "auto"
    @AppStorage("hubIdleTimeoutMin") private var idleTimeoutMin = 10
    @AppStorage("hubClusterRouteEnabled") private var clusterRouteEnabled = true
    @AppStorage("hubClusterCacheShared") private var clusterCacheShared = true

    // New download form
    @State private var showNewDownload = false
    @State private var newModelId = ""
    @State private var newSourceUrl = ""

    private let policies = [
        ("auto", "智能自动调度", "根据请求自动加载/卸载，推荐"),
        ("pinned", "手动固定常驻", "模型常驻内存，不自动卸载"),
        ("on_demand", "用完即卸载", "每次请求后立即卸载，最省内存"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            if selectedTab == 0 {
                downloadTab
            } else {
                scheduleTab
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadAll(); startPolling() }
        .onDisappear { stopPolling() }
        .sheet(isPresented: $showNewDownload) { newDownloadSheet }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            Button(action: { selectedTab = 0 }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "arrow.down.circle").font(.system(size: 14))
                    Text("下载调度")
                        .font(.system(size: theme.textSize, weight: selectedTab == 0 ? .semibold : .regular))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == 0 ? theme.accent.opacity(0.1) : .clear)
                .foregroundStyle(selectedTab == 0 ? theme.accent : theme.textSecondary)
            }
            .buttonStyle(.plain)

            Button(action: { selectedTab = 1 }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "gearshape.2").font(.system(size: 14))
                    Text("算力调度策略")
                        .font(.system(size: theme.textSize, weight: selectedTab == 1 ? .semibold : .regular))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == 1 ? theme.accent.opacity(0.1) : .clear)
                .foregroundStyle(selectedTab == 1 ? theme.accent : theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
    }

    // MARK: - Download Tab

    private var downloadTab: some View {
        VStack(spacing: 0) {
            downloadHeader
            Divider()
            downloadList
        }
    }

    private var downloadHeader: some View {
        HStack {
            Text("下载任务")
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)
            Spacer()
            let active = tasks.filter { $0.status == "downloading" || $0.status == "pending" }.count
            if active > 0 {
                Text("\(active) 个下载中")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
            Button("新建下载") { showNewDownload = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(theme.spacingM)
    }

    private var downloadList: some View {
        Group {
            if isLoading && tasks.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tasks.isEmpty {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "arrow.down.circle").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("暂无下载任务")
                        .foregroundStyle(theme.textSecondary)
                    Button("下载新模型") { showNewDownload = true }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(tasks) { task in
                    DownloadTaskRow(task: task)
                }
                .listStyle(.plain)
            }
            if let err = lastError {
                Text(err).font(.caption).foregroundStyle(.red).padding(4)
            }
        }
    }

    private var newDownloadSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("新建下载").font(.title2).bold()
            TextField("模型 ID", text: $newModelId).textFieldStyle(.roundedBorder)
            TextField("下载地址 (https://...)", text: $newSourceUrl).textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showNewDownload = false }.buttonStyle(.bordered)
                Button("开始下载") {
                    startDownload()
                    showNewDownload = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newModelId.isEmpty || newSourceUrl.isEmpty)
            }
        }
        .padding()
        .frame(width: 440)
    }

    // MARK: - Schedule Tab (PRD Page 5)

    private var scheduleTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                globalPolicySection
                pinnedWhitelistSection
                idleTimeoutSection
                clusterScheduleSection
                clusterHealthSection
            }
            .padding(theme.spacingL)
        }
    }

    private var globalPolicySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("全局模型加载策略")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text("全 Fusion 应用统一生效")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)

                ForEach(policies, id: \.0) { policy in
                    Button(action: { schedulePolicy = policy.0 }) {
                        HStack(spacing: theme.spacingS) {
                            Image(systemName: schedulePolicy == policy.0 ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(schedulePolicy == policy.0 ? theme.accent : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(policy.1)
                                    .font(.system(size: theme.textSize, weight: .medium))
                                    .foregroundStyle(theme.text)
                                Text(policy.2)
                                    .font(.caption)
                                    .foregroundStyle(theme.textTertiary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }

    private var pinnedWhitelistSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("常驻内存白名单")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text("名单内模型永久驻留内存，不会被自动卸载")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)

                let pinned = models.filter { $0.isPinned == true }
                if pinned.isEmpty {
                    Text("暂无常驻模型")
                        .foregroundStyle(theme.textTertiary)
                        .padding(.vertical, theme.spacingS)
                } else {
                    ForEach(pinned) { model in
                        HStack(spacing: theme.spacingS) {
                            Image(systemName: "pin.fill").foregroundStyle(.orange)
                            Text(model.displayTitle)
                                .font(.system(size: theme.textSize))
                                .foregroundStyle(theme.text)
                            Spacer()
                            if model.sizeGB > 0 {
                                Text(model.sizeFormatted).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if models.isEmpty {
                    Text("加载中...").foregroundStyle(theme.textTertiary)
                }
            }
            .padding(8)
        }
    }

    private var idleTimeoutSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("闲置自动回收")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                HStack(spacing: theme.spacingS) {
                    Text("闲置")
                        .foregroundStyle(theme.text)
                    TextField("", value: $idleTimeoutMin, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("分钟触发模型卸载，释放统一内存")
                        .foregroundStyle(theme.textSecondary)
                }

                if idleTimeoutMin < 5 {
                    Text("⚠️ 低于 5 分钟可能导致频繁加载/卸载，影响响应速度")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(8)
        }
    }

    private var clusterScheduleSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("集群调度配置")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                Toggle(isOn: $clusterRouteEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("开启跨节点推理路由")
                            .foregroundStyle(theme.text)
                        Text("本机资源不足时自动分配至集群空闲 Mac 执行推理")
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Toggle(isOn: $clusterCacheShared) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("集群全局共享模型缓存")
                            .foregroundStyle(theme.text)
                        Text("多节点只需下载一次模型文件，自动增量同步")
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .padding(8)
        }
    }

    // issue #63 sub-feature 4: cluster node health overview
    private var clusterHealthSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("集群节点健康状态")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if clusterNodes.isEmpty {
                    Text("未检测到集群节点")
                        .foregroundStyle(theme.textTertiary)
                        .padding(.vertical, theme.spacingS)
                } else {
                    ForEach(clusterNodes) { node in
                        HStack(spacing: theme.spacingS) {
                            Image(systemName: node.healthStatus.icon)
                                .foregroundStyle(colorForHealth(node.healthStatus))
                            Text(node.name ?? node.id)
                                .font(.system(size: theme.textSize))
                                .foregroundStyle(theme.text)
                            Spacer()
                            if let cpu = node.cpuUsage {
                                Text(String(format: "CPU %.0f%%", cpu * 100))
                                    .font(.caption).foregroundStyle(cpu > 0.9 ? .red : .secondary)
                            }
                            if let gpu = node.gpuUsage {
                                Text(String(format: "GPU %.0f%%", gpu * 100))
                                    .font(.caption).foregroundStyle(gpu > 0.9 ? .red : .secondary)
                            }
                            Text(node.healthStatus.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color(
                                    node.healthStatus == .healthy ? .green :
                                    node.healthStatus == .overloaded ? .orange : .red
                                ).opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private func colorForHealth(_ health: HubNodeHealth) -> Color {
        switch health {
        case .healthy: return .green
        case .overloaded: return .orange
        case .offline: return .red
        }
    }

    // MARK: - Data loading

    private func loadAll() async {
        isLoading = true
        do {
            async let tasksResp = client.listDownloads()
            async let monitorResp = client.getRealtimeMonitor()
            async let modelsResp = client.listModels()
            async let nodesResp = client.listClusterNodes()
            tasks = try await tasksResp.tasks
            monitor = try await monitorResp
            models = try await modelsResp.models
            clusterNodes = try await nodesResp.nodes
        } catch {
            lastError = error.localizedDescription
            schedLog.warning("Load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func startDownload() {
        Task { @MainActor in
            do {
                _ = try await client.createDownload(repoId: newModelId, source: newSourceUrl.isEmpty ? "huggingface" : newSourceUrl)
                schedLog.info("Download started: \(newModelId)")
                await loadAll()
                newModelId = ""
                newSourceUrl = ""
            } catch {
                lastError = error.localizedDescription
                schedLog.error("Download start failed: \(error.localizedDescription)")
            }
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { await loadAll() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

private struct DownloadTaskRow: View {
    let task: HubDownloadTask
    @Environment(\.studioTheme) private var theme

    private var isComplete: Bool { task.status == "completed" }
    private var isFailed: Bool { task.status == "failed" || task.status == "cancelled" }
    private var isActive: Bool { task.status == "downloading" || task.status == "pending" }

    private var statusIcon: String {
        if isComplete { return "checkmark.circle.fill" }
        if isFailed { return "xmark.circle.fill" }
        return "arrow.down.circle"
    }

    private var statusColor: Color {
        if isComplete { return .green }
        if isFailed { return .red }
        return .orange
    }

    private var progressPct: Int {
        guard let p = task.progress else { return 0 }
        return Int(min(max(p * 100, 0), 100))
    }

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: statusIcon).foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.repoId ?? task.id)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(task.status ?? "unknown").font(.caption).foregroundStyle(.secondary)
                    if let err = task.error, !err.isEmpty {
                        Text(err).font(.caption).foregroundStyle(.red).lineLimit(1)
                    }
                }
            }
            Spacer()
            if isActive {
                VStack(alignment: .trailing, spacing: 2) {
                    ProgressView(value: task.progress ?? 0, total: 1.0).frame(width: 100)
                    Text("\(progressPct)%").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
