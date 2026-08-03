// Callers: ModelHubMainView contentArea switch on .schedule.
// Affected API: ModelHubAPIClient listDownloads/createDownload/getDownload + scheduling config + setModelModules + throttle + TTL + benchmark.
// Data schemas: HubDownloadTask, HubDownloadListResponse, HubDownloadTaskResponse, HubMonitorResponse.
// PRD Page 5: 算力调度策略 + 下载调度合并页 + 模块权限 + API限流 + TTL + 自动基准测试

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

    // Module permission editing
    @State private var editingModelId: String?
    @State private var editingModules: Set<String> = []
    @State private var showPermEditSheet = false

    // API throttle config
    @AppStorage("hubDefaultRPM") private var defaultRPM = 60
    @AppStorage("hubDefaultConcurrent") private var defaultConcurrent = 4
    @State private var modelThrottles: [String: HubThrottleConfig] = [:]
    @State private var showThrottleEdit = false
    @State private var throttleEditModelId = ""
    @State private var throttleEditRPM = 60
    @State private var throttleEditConcurrent = 4

    // TTL countdown
    @State private var ttlNow: Date = Date()
    @State private var ttlTimer: Timer?

    // Auto-bench config
    @AppStorage("hubAutoBenchEnabled") private var autoBenchEnabled = false
    @AppStorage("hubAutoBenchSchedule") private var autoBenchSchedule = "daily"
    @AppStorage("hubAutoBenchModelIds") private var autoBenchModelIds = ""
    @State private var showAutoBenchModelPicker = false

    private let policies = [
        ("auto", "智能自动调度", "根据请求自动加载/卸载，推荐"),
        ("pinned", "手动固定常驻", "模型常驻内存，不自动卸载"),
        ("on_demand", "用完即卸载", "每次请求后立即卸载，最省内存"),
    ]

    private let tabItems = [
        (0, "arrow.down.circle", "下载调度"),
        (1, "gearshape.2", "算力调度策略"),
        (2, "lock.shield", "模块权限"),
        (3, "gauge.with.dots.needle.67percent", "API 限流"),
        (4, "timer", "模型 TTL"),
        (5, "speedometer", "自动基准测试"),
    ]

    private let fusionModules = [
        "Fusion Chat",
        "Fusion Code",
        "Fusion RAG",
        "Fusion Design",
        "Fusion Agent",
        "Fusion Doc",
        "Fusion Cowork",
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            switch selectedTab {
            case 0: downloadTab
            case 1: scheduleTab
            case 2: modulePermissionTab
            case 3: apiThrottleTab
            case 4: modelTTLTab
            case 5: autoBenchTab
            default: EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadAll(); startPolling(); startTTLPolling() }
        .onDisappear { stopPolling(); stopTTLPolling() }
        .sheet(isPresented: $showNewDownload) { newDownloadSheet }
        .sheet(isPresented: $showThrottleEdit) { throttleEditSheet }
        .sheet(isPresented: $showAutoBenchModelPicker) { autoBenchModelPickerSheet }
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabItems, id: \.0) { tab in
                    Button(action: { selectedTab = tab.0 }) {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: tab.1).font(.system(size: 14))
                            Text(tab.2)
                                .font(.system(size: theme.textSize, weight: selectedTab == tab.0 ? .semibold : .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(selectedTab == tab.0 ? theme.accent.opacity(0.1) : .clear)
                        .foregroundStyle(selectedTab == tab.0 ? theme.accent : theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, theme.spacingL)
        }
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

    // MARK: - Tab 2: Module Permission

    private var modulePermissionTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                modulePermHeader
                modulePermGrid
            }
            .padding(theme.spacingL)
        }
    }

    private var modulePermHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("模块访问权限")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text("控制各模块可使用的模型，点击编辑权限修改")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if isLoading {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var modulePermGrid: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                Divider()
                if models.isEmpty {
                    Text("暂无模型数据")
                        .foregroundStyle(theme.textTertiary)
                        .padding(.vertical, theme.spacingL)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(models) { model in
                        modulePermRow(model: model)
                        if model.id != models.last?.id {
                            Divider().padding(.leading, 140)
                        }
                    }
                }
            }
            .padding(8)
        }
        .sheet(isPresented: $showPermEditSheet) {
            if let mid = editingModelId, let m = models.first(where: { $0.id == mid }) {
                permissionEditSheet(model: m)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("模型")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 140, alignment: .leading)
            ForEach(fusionModules, id: \.self) { mod in
                Text(mod.replacingOccurrences(of: "Fusion ", with: ""))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Color.clear.frame(width: 72)
        }
        .padding(.vertical, 6)
    }

    private func modulePermRow(model: HubModel) -> some View {
        HStack(spacing: 0) {
            Text(model.displayTitle)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            ForEach(fusionModules, id: \.self) { mod in
                let allowed = model.allowedModules?.contains(mod) ?? false
                Image(systemName: allowed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(allowed ? theme.accent : theme.textQuaternary)
                    .frame(maxWidth: .infinity)
            }

            Button("编辑权限") {
                editingModelId = model.id
                editingModules = Set(model.allowedModules ?? [])
                showPermEditSheet = true
                schedLog.info("Edit permissions for model: \(model.id)")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .frame(width: 72)
        }
        .padding(.vertical, 4)
    }

    private func permissionEditSheet(model: HubModel) -> some View {
        VStack(spacing: theme.spacingM) {
            Text("编辑权限 — \(model.displayTitle)")
                .font(.title3).bold()

            ForEach(fusionModules, id: \.self) { mod in
                Toggle(isOn: Binding(
                    get: { editingModules.contains(mod) },
                    set: { on in
                        if on { editingModules.insert(mod) }
                        else { editingModules.remove(mod) }
                    }
                )) {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: moduleIcon(mod))
                            .foregroundStyle(theme.accent)
                        Text(mod)
                            .foregroundStyle(theme.text)
                    }
                }
            }

            if let err = lastError {
                Text(err).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("取消") {
                    editingModelId = nil
                    showPermEditSheet = false
                }.buttonStyle(.bordered)
                Button("保存") {
                    saveModulePermissions(modelId: model.id)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func saveModulePermissions(modelId: String) {
        Task { @MainActor in
            do {
                _ = try await client.setModelModules(modelId: modelId, modules: Array(editingModules))
                schedLog.info("Permissions saved for \(modelId): \(editingModules)")
                editingModelId = nil
                showPermEditSheet = false
                await loadAll()
            } catch {
                lastError = error.localizedDescription
                schedLog.error("Save permissions failed: \(error.localizedDescription)")
            }
        }
    }

    private func moduleIcon(_ mod: String) -> String {
        switch mod {
        case "Fusion Chat": return "text.bubble"
        case "Fusion Code": return "chevron.left.forwardslash.chevron.right"
        case "Fusion RAG": return "doc.text.magnifyingglass"
        case "Fusion Design": return "paintbrush"
        case "Fusion Agent": return "person.wave.2"
        case "Fusion Doc": return "doc.richtext"
        case "Fusion Cowork": return "person.2"
        default: return "cube"
        }
    }

    // MARK: - Tab 3: API Throttle

    private var apiThrottleTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                throttleHeader
                throttleGlobalSection
                throttlePerModelSection
            }
            .padding(theme.spacingL)
        }
    }

    private var throttleHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("API 限流配置")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text("控制每个模型的请求速率与并发限制，防止过载")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
        }
    }

    private var throttleGlobalSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("默认限流策略")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                HStack(spacing: theme.spacingL) {
                    HStack(spacing: theme.spacingS) {
                        Text("每分钟请求数 (RPM):")
                            .foregroundStyle(theme.text)
                        TextField("", value: $defaultRPM, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    HStack(spacing: theme.spacingS) {
                        Text("最大并发数:")
                            .foregroundStyle(theme.text)
                        TextField("", value: $defaultConcurrent, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }

                if defaultRPM <= 0 {
                    Text("⚠️ RPM 必须 > 0")
                        .font(.caption).foregroundStyle(.orange)
                }
                if defaultConcurrent <= 0 {
                    Text("⚠️ 并发数必须 > 0")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            .padding(8)
        }
    }

    private var throttlePerModelSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("单模型限流配置")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text("未单独配置的模型使用默认策略")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)

                if models.isEmpty {
                    Text("暂无模型")
                        .foregroundStyle(theme.textTertiary)
                        .padding(.vertical, theme.spacingS)
                } else {
                    ForEach(models) { model in
                        let cfg = modelThrottles[model.id]
                        HStack(spacing: theme.spacingM) {
                            Circle()
                                .fill(model.isServing == true ? Color.green : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                            Text(model.displayTitle)
                                .font(.system(size: theme.textSize))
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                                .frame(width: 180, alignment: .leading)

                            if let c = cfg {
                                Text("RPM: \(c.rpm)")
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                                Text("并发: \(c.concurrent)")
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                            } else {
                                Text("RPM: \(defaultRPM) (默认)")
                                    .font(.caption)
                                    .foregroundStyle(theme.textTertiary)
                                Text("并发: \(defaultConcurrent) (默认)")
                                    .font(.caption)
                                    .foregroundStyle(theme.textTertiary)
                            }

                            Spacer()

                            Button(cfg != nil ? "编辑" : "自定义") {
                                throttleEditModelId = model.id
                                throttleEditRPM = cfg?.rpm ?? defaultRPM
                                throttleEditConcurrent = cfg?.concurrent ?? defaultConcurrent
                                showThrottleEdit = true
                                schedLog.info("Edit throttle for model: \(model.id)")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            if cfg != nil {
                                Button("重置") {
                                    modelThrottles.removeValue(forKey: model.id)
                                    schedLog.info("Reset throttle for model: \(model.id)")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(8)
        }
    }

    private var throttleEditSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("限流配置 — \(throttleEditModelId)")
                .font(.title3).bold()

            HStack(spacing: theme.spacingL) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("每分钟请求数 (RPM)")
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                    TextField("", value: $throttleEditRPM, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("最大并发数")
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                    TextField("", value: $throttleEditConcurrent, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }

            HStack {
                Button("取消") { showThrottleEdit = false }.buttonStyle(.bordered)
                Button("保存") {
                    modelThrottles[throttleEditModelId] = HubThrottleConfig(
                        modelId: throttleEditModelId,
                        rpm: max(1, throttleEditRPM),
                        concurrent: max(1, throttleEditConcurrent)
                    )
                    schedLog.info("Throttle saved for \(throttleEditModelId): rpm=\(throttleEditRPM), concurrent=\(throttleEditConcurrent)")
                    showThrottleEdit = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(throttleEditRPM <= 0 || throttleEditConcurrent <= 0)
            }
        }
        .padding()
        .frame(width: 400)
    }

    // MARK: - Tab 4: Model TTL

    private var modelTTLTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                ttlHeader
                ttlActiveSection
                ttlConfigSection
            }
            .padding(theme.spacingL)
        }
    }

    private var ttlHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("模型 TTL (存活时间)")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text("设置模型自动卸载倒计时，闲置超时后释放统一内存")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
        }
    }

    private var ttlActiveSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("活跃模型倒计时")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                let serving = models.filter { $0.isServing == true }
                if serving.isEmpty {
                    VStack(spacing: theme.spacingS) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("当前无活跃模型")
                            .foregroundStyle(theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingL)
                } else {
                    ForEach(serving) { model in
                        ttlModelRow(model: model)
                    }
                }
            }
            .padding(8)
        }
    }

    private func ttlModelRow(model: HubModel) -> some View {
        HStack(spacing: theme.spacingM) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayTitle)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                if let ttl = model.ttlSeconds, ttl > 0 {
                    Text("TTL: \(formatDuration(ttl))")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text("永久驻留 (无 TTL)")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            if let ttl = model.ttlSeconds, ttl > 0 {
                let remaining = ttlRemainingSeconds(model: model)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(remaining > 0 ? formatDuration(remaining) : "已过期")
                        .font(.system(size: theme.textSize, weight: .semibold, design: .monospaced))
                        .foregroundStyle(remaining > 300 ? theme.accent : remaining > 60 ? .orange : .red)
                    Text("剩余时间")
                        .font(.caption2)
                        .foregroundStyle(theme.textTertiary)
                }

                ProgressView(value: Double(max(0, remaining)), total: Double(ttl))
                    .frame(width: 100)
                    .tint(remaining > 300 ? theme.accent : remaining > 60 ? .orange : .red)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(theme.surfaceSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func ttlRemainingSeconds(model: HubModel) -> Int {
        guard let ttl = model.ttlSeconds, ttl > 0 else { return Int.max }
        return max(0, ttl)
    }

    private var ttlConfigSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("TTL 配置说明")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "info.circle").foregroundStyle(theme.accent)
                        Text("TTL 由模型服务部署时指定 (serve API 的 ttl_seconds 参数)")
                            .foregroundStyle(theme.textSecondary)
                            .font(.system(size: theme.textSize))
                    }
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "clock").foregroundStyle(.orange)
                        Text("闲置超过 TTL 后，模型将自动从内存卸载，释放 GPU 统一内存")
                            .foregroundStyle(theme.textSecondary)
                            .font(.system(size: theme.textSize))
                    }
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "pin.fill").foregroundStyle(.green)
                        Text("常驻模型 (pinned) 不受 TTL 限制，始终保留在内存中")
                            .foregroundStyle(theme.textSecondary)
                            .font(.system(size: theme.textSize))
                    }
                }

                let withTTL = models.filter { ($0.ttlSeconds ?? 0) > 0 }
                if !withTTL.isEmpty {
                    Divider()
                    Text("已配置 TTL 的模型")
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)

                    ForEach(withTTL) { model in
                        HStack(spacing: theme.spacingS) {
                            Circle()
                                .fill(model.isServing == true ? Color.green : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                            Text(model.displayTitle)
                                .foregroundStyle(theme.text)
                            Spacer()
                            Text("TTL: \(formatDuration(model.ttlSeconds ?? 0))")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds <= 0 { return "0秒" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)时\(m)分\(s)秒" }
        if m > 0 { return "\(m)分\(s)秒" }
        return "\(s)秒"
    }

    // MARK: - Tab 5: Auto-Bench

    private var autoBenchTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                autoBenchHeader
                autoBenchToggleSection
                autoBenchScheduleSection
                autoBenchModelSection
                autoBenchStatusSection
            }
            .padding(theme.spacingL)
        }
    }

    private var autoBenchHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("自动基准测试")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text("模型量化或下载完成后自动运行基准测试，持续追踪性能变化")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
        }
    }

    private var autoBenchToggleSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Toggle(isOn: $autoBenchEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用自动基准测试")
                            .foregroundStyle(theme.text)
                        Text("模型量化完成后、新模型下载完成后自动触发基准测试")
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .onChange(of: autoBenchEnabled) {
                    schedLog.info("Auto-bench enabled: \(autoBenchEnabled)")
                }
            }
            .padding(8)
        }
    }

    private var autoBenchScheduleSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("定时基准测试")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                HStack(spacing: theme.spacingM) {
                    ForEach([("daily", "每日"), ("weekly", "每周"), ("monthly", "每月")], id: \.0) { option in
                        Button(action: { autoBenchSchedule = option.0 }) {
                            HStack(spacing: theme.spacingXS) {
                                Image(systemName: autoBenchSchedule == option.0 ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(autoBenchSchedule == option.0 ? theme.accent : .secondary)
                                Text(option.1)
                                    .font(.system(size: theme.textSize))
                                    .foregroundStyle(autoBenchSchedule == option.0 ? theme.text : theme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(autoBenchSchedule == option.0 ? theme.accent.opacity(0.1) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if autoBenchEnabled {
                    Text("定时测试将在每日凌晨 3:00 或每周一凌晨 3:00 自动执行")
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(8)
        }
    }

    private var autoBenchModelSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                HStack {
                    Text("纳入测试的模型")
                        .font(.system(size: theme.headlineSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Button("选择模型") {
                        showAutoBenchModelPicker = true
                        schedLog.info("Open auto-bench model picker")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                let selectedIds = autoBenchModelIds.split(separator: ",").map { String($0) }
                if selectedIds.isEmpty || autoBenchModelIds.isEmpty {
                    Text("未选择模型，将测试所有已下载模型")
                        .foregroundStyle(theme.textTertiary)
                        .font(.system(size: theme.textSize))
                } else {
                    let selected = models.filter { selectedIds.contains($0.id) }
                    if selected.isEmpty {
                        Text("已选 \(selectedIds.count) 个模型 (加载中...)")
                            .foregroundStyle(theme.textTertiary)
                            .font(.system(size: theme.textSize))
                    } else {
                        ForEach(selected) { model in
                            HStack(spacing: theme.spacingS) {
                                Image(systemName: "flame")
                                    .foregroundStyle(.orange)
                                Text(model.displayTitle)
                                    .font(.system(size: theme.textSize))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                Button(action: {
                                    removeAutoBenchModel(model.id)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        let unmatched = selectedIds.filter { id in !models.contains { $0.id == id } }
                        if !unmatched.isEmpty {
                            ForEach(unmatched, id: \.self) { id in
                                HStack(spacing: theme.spacingS) {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundStyle(.secondary)
                                    Text(id)
                                        .font(.system(size: theme.textSize))
                                        .foregroundStyle(theme.textTertiary)
                                    Spacer()
                                    Button(action: { removeAutoBenchModel(id) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    private var autoBenchStatusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("测试状态")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                HStack(spacing: theme.spacingL) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("自动测试")
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                        Text(autoBenchEnabled ? "已启用" : "未启用")
                            .font(.system(size: theme.textSize, weight: .medium))
                            .foregroundStyle(autoBenchEnabled ? .green : theme.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("执行频率")
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                        Text(scheduleLabel(autoBenchSchedule))
                            .font(.system(size: theme.textSize, weight: .medium))
                            .foregroundStyle(theme.text)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("测试模型数")
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                        let count = autoBenchModelIds.isEmpty ? models.filter { $0.isDownloaded == true }.count : autoBenchModelIds.split(separator: ",").count
                        Text("\(count)")
                            .font(.system(size: theme.textSize, weight: .medium))
                            .foregroundStyle(theme.text)
                    }
                }

                Button("立即执行一次基准测试") {
                    triggerManualBench()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(models.isEmpty)
            }
            .padding(8)
        }
    }

    private func scheduleLabel(_ schedule: String) -> String {
        switch schedule {
        case "daily": return "每日"
        case "weekly": return "每周"
        case "monthly": return "每月"
        default: return schedule
        }
    }

    private var autoBenchModelPickerSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("选择基准测试模型").font(.title3).bold()

            let currentSelected = Set(autoBenchModelIds.split(separator: ",").map { String($0) })
            let downloadable = models.filter { $0.isDownloaded == true }

            if downloadable.isEmpty {
                Text("暂无已下载模型")
                    .foregroundStyle(theme.textTertiary)
            } else {
                List(downloadable) { model in
                    Button(action: {
                        if currentSelected.contains(model.id) {
                            removeAutoBenchModel(model.id)
                        } else {
                            addAutoBenchModel(model.id)
                        }
                    }) {
                        HStack(spacing: theme.spacingS) {
                            Image(systemName: currentSelected.contains(model.id) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(currentSelected.contains(model.id) ? theme.accent : .secondary)
                            Text(model.displayTitle)
                                .foregroundStyle(theme.text)
                            Spacer()
                            if model.sizeGB > 0 {
                                Text(model.sizeFormatted)
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .frame(minHeight: 300)
            }

            Button("完成") { showAutoBenchModelPicker = false }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 440, height: 500)
    }

    private func addAutoBenchModel(_ id: String) {
        var parts = autoBenchModelIds.split(separator: ",").map { String($0) }
        if !parts.contains(id) {
            parts.append(id)
            autoBenchModelIds = parts.joined(separator: ",")
            schedLog.info("Added auto-bench model: \(id)")
        }
    }

    private func removeAutoBenchModel(_ id: String) {
        var parts = autoBenchModelIds.split(separator: ",").map { String($0) }
        parts.removeAll { $0 == id }
        autoBenchModelIds = parts.joined(separator: ",")
        schedLog.info("Removed auto-bench model: \(id)")
    }

    private func triggerManualBench() {
        Task { @MainActor in
            do {
                let benchIds: [String]
                if autoBenchModelIds.isEmpty {
                    benchIds = models.filter { $0.isDownloaded == true }.map { $0.id }
                } else {
                    benchIds = autoBenchModelIds.split(separator: ",").map { String($0) }
                }
                for modelId in benchIds {
                    _ = try await client.triggerBenchmark(modelId: modelId)
                    schedLog.info("Manual benchmark triggered: \(modelId)")
                }
            } catch {
                lastError = error.localizedDescription
                schedLog.error("Manual benchmark failed: \(error.localizedDescription)")
            }
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

    private func startTTLPolling() {
        ttlTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            ttlNow = Date()
        }
    }

    private func stopTTLPolling() {
        ttlTimer?.invalidate()
        ttlTimer = nil
    }
}

// MARK: - Throttle Config

struct HubThrottleConfig {
    let modelId: String
    let rpm: Int
    let concurrent: Int
}

// MARK: - Download Task Row

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
