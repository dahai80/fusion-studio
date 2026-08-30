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
    @StateObject private var i18n = I18nManager.shared

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

    private var policies: [(String, String, String)] {
        [
            ("auto", i18n.t(.hub_policyAuto), i18n.t(.hub_policyAutoDesc)),
            ("pinned", i18n.t(.hub_policyPinned), i18n.t(.hub_policyPinnedDesc)),
            ("on_demand", i18n.t(.hub_policyOnDemand), i18n.t(.hub_policyOnDemandDesc)),
        ]
    }

    private var tabItems: [(Int, String, String)] {
        [
            (0, "arrow.down.circle", i18n.t(.hub_downloadSched)),
            (1, "gearshape.2", i18n.t(.hub_computeSchedPolicy)),
            (2, "lock.shield", i18n.t(.hub_modulePermission)),
            (3, "gauge.with.dots.needle.67percent", i18n.t(.hub_apiThrottle)),
            (4, "timer", i18n.t(.hub_modelTTLTab)),
            (5, "speedometer", i18n.t(.hub_autoBenchmark)),
        ]
    }

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
            Text(i18n.t(.hub_downloadTask))
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)
            Spacer()
            let active = tasks.filter { $0.status == "downloading" || $0.status == "pending" }.count
            if active > 0 {
                Text(String(format: i18n.t(.hub_activeDownloadsFmt), active))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
            }
            Button(i18n.t(.hub_newDownload)) { showNewDownload = true }
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
                    Text(i18n.t(.hub_noDownloadTasks))
                        .foregroundStyle(theme.textSecondary)
                    Button(i18n.t(.hub_downloadNewModel)) { showNewDownload = true }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(tasks) { task in
                    DownloadTaskRow(task: task)
                }
                .listStyle(.plain)
            }
            if let error = lastError {
                Text(error).font(.caption).foregroundStyle(.red).padding(4)
            }
        }
    }

    private var newDownloadSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.hub_newDownload)).font(.title2).bold()
            TextField(i18n.t(.hub_modelIdPlaceholder), text: $newModelId).textFieldStyle(.roundedBorder)
            TextField(i18n.t(.hub_downloadUrlPlaceholder), text: $newSourceUrl).textFieldStyle(.roundedBorder)
            HStack {
                Button(i18n.t(.hub_cancelBtn)) { showNewDownload = false }.buttonStyle(.bordered)
                Button(i18n.t(.hub_startDownload)) {
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
                Text(i18n.t(.hub_globalModelLoadPolicy))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(i18n.t(.hub_unifiedFusionApp))
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
                Text(i18n.t(.hub_pinnedWhitelist))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(i18n.t(.hub_pinnedWhitelistNote))
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)

                let pinned = models.filter { $0.isPinned == true }
                if pinned.isEmpty {
                    Text(i18n.t(.hub_noPinnedModels))
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
                    Text(i18n.t(.hub_loading)).foregroundStyle(theme.textTertiary)
                }
            }
            .padding(8)
        }
    }

    private var idleTimeoutSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text(i18n.t(.hub_idleAutoReclaim))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                HStack(spacing: theme.spacingS) {
                    Text(i18n.t(.hub_idlePrefix))
                        .foregroundStyle(theme.text)
                    TextField("", value: $idleTimeoutMin, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text(i18n.t(.hub_idleUnloadHint))
                        .foregroundStyle(theme.textSecondary)
                }

                if idleTimeoutMin < 5 {
                    Text(i18n.t(.hub_idleTooLowWarn))
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
                Text(i18n.t(.hub_clusterSchedConfig))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                Toggle(isOn: $clusterRouteEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(i18n.t(.hub_enableCrossNodeRouting))
                            .foregroundStyle(theme.text)
                        Text(i18n.t(.hub_localResourceClusterHint))
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Toggle(isOn: $clusterCacheShared) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(i18n.t(.hub_clusterSharedCache))
                            .foregroundStyle(theme.text)
                        Text(i18n.t(.hub_multiNodeSyncHint))
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
                Text(i18n.t(.hub_clusterNodeHealth))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if clusterNodes.isEmpty {
                    Text(i18n.t(.hub_noClusterNodes))
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
                Text(i18n.t(.hub_moduleAccessPerm))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text(i18n.t(.hub_controlModuleModelHint))
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
                    Text(i18n.t(.hub_noModelData))
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
            Text(i18n.t(.hub_model))
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

            Button(i18n.t(.hub_editPermissionBtn)) {
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
            Text(String(format: i18n.t(.hub_editPermTitleFmt), model.displayTitle))
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

            if let error = lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button(i18n.t(.hub_cancelBtn)) {
                    editingModelId = nil
                    showPermEditSheet = false
                }.buttonStyle(.bordered)
                Button(i18n.t(.hub_saveBtn)) {
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
                lastError = BridgeError.sanitize(error)
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
                Text(i18n.t(.hub_apiThrottleConfig))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text(i18n.t(.hub_controlRateConcurrencyHint))
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
        }
    }

    private var throttleGlobalSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text(i18n.t(.hub_defaultThrottlePolicy))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                HStack(spacing: theme.spacingL) {
                    HStack(spacing: theme.spacingS) {
                        Text(i18n.t(.hub_rpmLabelColon))
                            .foregroundStyle(theme.text)
                        TextField("", value: $defaultRPM, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    HStack(spacing: theme.spacingS) {
                        Text(i18n.t(.hub_maxConcurrencyColon))
                            .foregroundStyle(theme.text)
                        TextField("", value: $defaultConcurrent, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }

                if defaultRPM <= 0 {
                    Text(i18n.t(.hub_rpmMustPositive))
                        .font(.caption).foregroundStyle(.orange)
                }
                if defaultConcurrent <= 0 {
                    Text(i18n.t(.hub_concurrencyMustPositive))
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            .padding(8)
        }
    }

    private var throttlePerModelSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text(i18n.t(.hub_perModelThrottle))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(i18n.t(.hub_unconfiguredUsesDefault))
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)

                if models.isEmpty {
                    Text(i18n.t(.hub_noModels))
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
                                Text(String(format: i18n.t(.hub_concurrencyFmt), c.concurrent))
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                            } else {
                                Text(String(format: i18n.t(.hub_rpmDefaultFmt), defaultRPM))
                                    .font(.caption)
                                    .foregroundStyle(theme.textTertiary)
                                Text(String(format: i18n.t(.hub_concurrencyDefaultFmt), defaultConcurrent))
                                    .font(.caption)
                                    .foregroundStyle(theme.textTertiary)
                            }

                            Spacer()

                            Button(cfg != nil ? i18n.t(.hub_edit) : i18n.t(.hub_sourceCustom)) {
                                throttleEditModelId = model.id
                                throttleEditRPM = cfg?.rpm ?? defaultRPM
                                throttleEditConcurrent = cfg?.concurrent ?? defaultConcurrent
                                showThrottleEdit = true
                                schedLog.info("Edit throttle for model: \(model.id)")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)

                            if cfg != nil {
                                Button(i18n.t(.hub_reset)) {
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
            Text(String(format: i18n.t(.hub_throttleConfigTitleFmt), throttleEditModelId))
                .font(.title3).bold()

            HStack(spacing: theme.spacingL) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.hub_rpmLabel))
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                    TextField("", value: $throttleEditRPM, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.hub_maxConcurrency))
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                    TextField("", value: $throttleEditConcurrent, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }

            HStack {
                Button(i18n.t(.hub_cancelBtn)) { showThrottleEdit = false }.buttonStyle(.bordered)
                Button(i18n.t(.hub_saveBtn)) {
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
                Text(i18n.t(.hub_modelTTL))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text(i18n.t(.hub_setIdleUnloadCountdown))
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
        }
    }

    private var ttlActiveSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text(i18n.t(.hub_activeModelCountdown))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                let serving = models.filter { $0.isServing == true }
                if serving.isEmpty {
                    VStack(spacing: theme.spacingS) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text(i18n.t(.hub_noActiveModels))
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
                    Text(i18n.t(.hub_permanentResidentNoTTL))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            if let ttl = model.ttlSeconds, ttl > 0 {
                let remaining = ttlRemainingSeconds(model: model)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(remaining > 0 ? formatDuration(remaining) : i18n.t(.hub_expired))
                        .font(.system(size: theme.textSize, weight: .semibold, design: .monospaced))
                        .foregroundStyle(remaining > 300 ? theme.accent : remaining > 60 ? .orange : .red)
                    Text(i18n.t(.hub_remainingTime))
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
                Text(i18n.t(.hub_ttlConfigNote))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "info.circle").foregroundStyle(theme.accent)
                        Text(i18n.t(.hub_ttlServeParamNote))
                            .foregroundStyle(theme.textSecondary)
                            .font(.system(size: theme.textSize))
                    }
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "clock").foregroundStyle(.orange)
                        Text(i18n.t(.hub_idleAfterTTLUnload))
                            .foregroundStyle(theme.textSecondary)
                            .font(.system(size: theme.textSize))
                    }
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "pin.fill").foregroundStyle(.green)
                        Text(i18n.t(.hub_pinnedNoTTLNote))
                            .foregroundStyle(theme.textSecondary)
                            .font(.system(size: theme.textSize))
                    }
                }

                let withTTL = models.filter { ($0.ttlSeconds ?? 0) > 0 }
                if !withTTL.isEmpty {
                    Divider()
                    Text(i18n.t(.hub_configuredTTLModels))
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
        if seconds <= 0 { return i18n.t(.hub_durationZero) }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: i18n.t(.hub_durationHMSFmt), h, m, s) }
        if m > 0 { return String(format: i18n.t(.hub_durationMSFmt), m, s) }
        return String(format: i18n.t(.hub_durationSFmt), s)
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
                Text(i18n.t(.hub_autoBenchmarkTab))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text(i18n.t(.hub_autoBenchAfterQuantOrDownload))
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
                        Text(i18n.t(.hub_enableAutoBenchmark))
                            .foregroundStyle(theme.text)
                        Text(i18n.t(.hub_autoBenchQuantOrDownloadShort))
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
                Text(i18n.t(.hub_scheduledBenchmark))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                HStack(spacing: theme.spacingM) {
                    ForEach([("daily", i18n.t(.hub_daily)), ("weekly", i18n.t(.hub_weekly)), ("monthly", i18n.t(.hub_monthly))], id: \.0) { option in
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
                    Text(i18n.t(.hub_scheduledBenchNote))
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
                    Text(i18n.t(.hub_benchIncludedModels))
                        .font(.system(size: theme.headlineSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Button(i18n.t(.hub_selectModel)) {
                        showAutoBenchModelPicker = true
                        schedLog.info("Open auto-bench model picker")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                let selectedIds = autoBenchModelIds.split(separator: ",").map { String($0) }
                if selectedIds.isEmpty || autoBenchModelIds.isEmpty {
                    Text(i18n.t(.hub_noModelWillTestAll))
                        .foregroundStyle(theme.textTertiary)
                        .font(.system(size: theme.textSize))
                } else {
                    let selected = models.filter { selectedIds.contains($0.id) }
                    if selected.isEmpty {
                        Text(String(format: i18n.t(.hub_selectedModelsLoadingFmt), selectedIds.count))
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
                Text(i18n.t(.hub_testStatus))
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                HStack(spacing: theme.spacingL) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.hub_autoTest))
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                        Text(autoBenchEnabled ? i18n.t(.hub_enabled) : i18n.t(.hub_notEnabled))
                            .font(.system(size: theme.textSize, weight: .medium))
                            .foregroundStyle(autoBenchEnabled ? .green : theme.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.hub_executionFrequency))
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                        Text(scheduleLabel(autoBenchSchedule))
                            .font(.system(size: theme.textSize, weight: .medium))
                            .foregroundStyle(theme.text)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.hub_testModelCount))
                            .font(.caption)
                            .foregroundStyle(theme.textTertiary)
                        let count = autoBenchModelIds.isEmpty ? models.filter { $0.isDownloaded == true }.count : autoBenchModelIds.split(separator: ",").count
                        Text("\(count)")
                            .font(.system(size: theme.textSize, weight: .medium))
                            .foregroundStyle(theme.text)
                    }
                }

                Button(i18n.t(.hub_runBenchmarkNow)) {
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
        case "daily": return i18n.t(.hub_daily)
        case "weekly": return i18n.t(.hub_weekly)
        case "monthly": return i18n.t(.hub_monthly)
        default: return schedule
        }
    }

    private var autoBenchModelPickerSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.hub_selectBenchModels)).font(.title3).bold()

            let currentSelected = Set(autoBenchModelIds.split(separator: ",").map { String($0) })
            let downloadable = models.filter { $0.isDownloaded == true }

            if downloadable.isEmpty {
                Text(i18n.t(.hub_noDownloadedModels))
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

            Button(i18n.t(.hub_done)) { showAutoBenchModelPicker = false }
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
                lastError = BridgeError.sanitize(error)
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
            lastError = BridgeError.sanitize(error)
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
                lastError = BridgeError.sanitize(error)
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
                    if let error = task.error, !error.isEmpty {
                        Text(error).font(.caption).foregroundStyle(.red).lineLimit(1)
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
