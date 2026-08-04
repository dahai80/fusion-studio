// Importers/callers: FusionStudioApp (.sheet 首次启动呈现), SettingsView (手动重入).
// Affected API: WelcomeView/WelcomeViewModel, 依赖 FusionConfig/MlxHTTPClient/AgentBridge/UpstreamServiceManager/IPCClient/APIKeyGenerator.
// Data schemas: WelcomeStep/ModelOption/HardwareInfo (本文件私有). User instruction: "你首先把这部分复用过来"

// WelcomeView - 首次启动模型引导，复用自 fusion-mac WelcomeWindow.swift。
// 适配 fusion-studio：不 spawn mlx，改为 ensureCriticalRunning + setupApiKey + 设默认模型；
// 裁掉 basePath/modelDir/启动参数面板（fusion-studio 不管理模型目录与 spawn）。

import SwiftUI
import os.log

enum WelcomeStep: Equatable, Sendable {
    case intro, setup, hardwareDetect, modelSource, recommend, complete
}

@MainActor
final class WelcomeViewModel: ObservableObject {
    @Published var step: WelcomeStep = .intro
    @Published var portText: String = "11432"
    @Published var apiKey: String = ""
    @Published var apiKeyVisible: Bool = false
    @Published var lastError: String?
    @Published var isStarting = false
    @Published var modelSource: String = "huggingface"
    @Published var useCase: String = "agent"
    @Published var selectedModels: Set<String> = []
    @Published var modelDownloads: [String: String] = [:]
    @Published var downloadErrors: [String: String] = [:]
    @Published var startCompleted = false
    @Published var hardware: HardwareInfo?
    @Published var localModels: [ModelDTO] = []
    @Published var selectedLocalModel: String?
    @Published var selectedSmall: String?
    @Published var selectedCode: String?
    @Published var selectedHeavy: String?
    @Published var hfRecommended: [HFModelInfo] = []

    var onFinish: (() -> Void)?

    private var config: FusionConfig?
    private var mlxHTTP: MlxHTTPClient?
    private var agentBridge: AgentBridge?
    private var upstreamManager: UpstreamServiceManager?
    private var ipcClient: IPCClient?
    private let log = Logger(subsystem: "com.fusion.studio", category: "WelcomeViewModel")

    struct ModelOption: Identifiable {
        let id: String
        let displayName: String
        let reason: String
    }
    struct HardwareInfo {
        let chip: String
        let cpuCores: Int
        let memoryGB: Double
        let bandwidthGBs: Int?
        let diskFreeGB: Double
    }

    func bind(config: FusionConfig, mlxHTTP: MlxHTTPClient, agentBridge: AgentBridge, upstreamManager: UpstreamServiceManager, ipcClient: IPCClient) {
        self.config = config
        self.mlxHTTP = mlxHTTP
        self.agentBridge = agentBridge
        self.upstreamManager = upstreamManager
        self.ipcClient = ipcClient
        portText = String(config.mlxPort)
        apiKey = config.mlxResolvedApiKey
        hardware = detectHardware()
        Task { await loadLocalModels() }
    }

    // 加载外部 mlx 已有本地模型，供引导选择主模型（fusion-studio 复用外部 mlx，本地通常已有模型）
    func loadLocalModels() async {
        guard let client = mlxHTTP else { return }
        do {
            let resp = try await client.listModels()
            self.localModels = resp.models
            if selectedLocalModel == nil {
                self.selectedLocalModel = resp.models.first(where: { $0.isDefault == true })?.id ?? resp.models.first?.id
            }
            defaultSlotsIfNeeded(resp.models)
            log.info("local models loaded: \(resp.models.count)")
        } catch {
            log.error("listModels failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            let rec = try await client.getHFRecommended(mlxOnly: true)
            var seen = Set<String>()
            self.hfRecommended = (rec.trending + rec.popular).filter { seen.insert($0.repoId).inserted }
            log.info("hf recommended loaded: \(self.hfRecommended.count)")
        } catch {
            log.error("getHFRecommended failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // 三档默认值：小=最小、复杂=最大、代码=含 code/coder 否则同小档
    private func defaultSlotsIfNeeded(_ models: [ModelDTO]) {
        guard !models.isEmpty else { return }
        let sorted = models.sorted { (a, b) in
            (a.estimatedSize ?? 0) < (b.estimatedSize ?? 0)
        }
        if selectedSmall == nil { selectedSmall = sorted.first?.id }
        if selectedHeavy == nil { selectedHeavy = sorted.last?.id }
        if selectedCode == nil {
            let code = models.first { m in
                let n = (m.displayName ?? m.id).lowercased()
                return n.contains("code") || n.contains("coder")
            }
            selectedCode = code?.id ?? selectedSmall
        }
        log.info("slots defaulted: small=\(self.selectedSmall ?? "nil", privacy: .public) code=\(self.selectedCode ?? "nil", privacy: .public) heavy=\(self.selectedHeavy ?? "nil", privacy: .public)")
    }

    func slotBinding(_ slot: ModelSlot) -> Binding<String> {
        Binding(
            get: {
                switch slot {
                case .small: return self.selectedSmall ?? ""
                case .code: return self.selectedCode ?? ""
                case .heavy: return self.selectedHeavy ?? ""
                }
            },
            set: { newVal in
                let v = newVal.isEmpty ? nil : newVal
                switch slot {
                case .small: self.selectedSmall = v
                case .code: self.selectedCode = v
                case .heavy: self.selectedHeavy = v
                }
            }
        )
    }

    // MARK: - 推荐模型（按用例 + RAM + 芯片筛选，复用自 fusion-mac）
    // 推荐模型来自外部 mlx 的 /admin/api/hf/recommended（真实 mlx-community 仓库），
    // 按内存与用例过滤，避免硬编码虚构仓库名导致下载 404。
    var recommendedModels: [ModelOption] {
        let ramGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let headroomGB = ramGB * 0.6
        var pool = hfRecommended
        pool = pool.filter { m in
            guard let p = m.params, p > 0 else { return true }
            let needGB = Double(p) / 2.0 / 1_000_000_000
            return needGB < headroomGB
        }
        if useCase == "coding" {
            let code = pool.filter { m in
                let n = (m.name ?? m.repoId).lowercased()
                return n.contains("code") || n.contains("coder")
            }
            if !code.isEmpty { pool = code }
        }
        pool.sort { (a, b) in (a.downloads ?? 0) > (b.downloads ?? 0) }
        return Array(pool.prefix(6)).map { m in
            let size = m.paramsFormatted ?? m.sizeFormatted ?? "—"
            let dl = m.downloads ?? 0
            return ModelOption(id: m.repoId, displayName: m.name ?? m.repoId, reason: "\(size) · \(dl) 次下载")
        }
    }

    func toggleModel(_ repoId: String) {
        if selectedModels.contains(repoId) { selectedModels.remove(repoId) }
        else { selectedModels.insert(repoId) }
    }
    func selectAllRecommended() {
        selectedModels = Set(recommendedModels.map(\.id))
    }
    func downloadSelectedModels() {
        guard let client = mlxHTTP else { return }
        for repoId in selectedModels {
            guard modelDownloads[repoId] != "downloading" else { continue }
            modelDownloads[repoId] = "downloading"
            Task { @MainActor in
                do {
                    let resp = try await client.startHFDownload(repoId: repoId, hfToken: "")
                    self.modelDownloads[repoId] = resp.success ? "done" : "error"
                    if !resp.success { self.downloadErrors[repoId] = "Failed to start" }
                } catch {
                    self.modelDownloads[repoId] = "error"
                    self.downloadErrors[repoId] = error.localizedDescription
                }
            }
        }
    }

    func regenerateApiKey() {
        apiKey = APIKeyGenerator.random()
        lastError = nil
    }

    // MARK: - 步骤流转
    func next() {
        switch step {
        case .intro: step = .setup
        case .setup: if validateSetup() { step = .hardwareDetect }
        case .hardwareDetect: step = .modelSource
        case .modelSource: step = .recommend
        case .recommend, .complete: break
        }
    }
    func back() {
        switch step {
        case .setup: step = .intro
        case .hardwareDetect: step = .setup
        case .modelSource: step = .hardwareDetect
        case .recommend: step = .modelSource
        default: break
        }
    }

    func validateSetup() -> Bool {
        let portStr = portText.trimmingCharacters(in: .whitespaces)
        guard let port = Int(portStr), (1...65535).contains(port) else {
            lastError = "端口需为 1-65535 的数字"; return false
        }
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        if key.isEmpty { lastError = "请生成或填写 API Key"; return false }
        if key.count < 4 || key.contains(where: { $0.isWhitespace }) {
            lastError = "API Key 至少 4 字符且无空白"; return false
        }
        lastError = nil
        return true
    }

    // MARK: - 保存配置并进入主页面（服务后台启动，不阻塞）
    // 上游关键服务由 FusionStudioApp.onAppear 的 ensureCriticalRunning 后台拉起；
    // 引导只负责即时落地三档模型配置 + 鉴权/默认模型写入，随即进入主页面。
    func startServer() async {
        guard validateSetup() else { return }
        lastError = nil
        if let p = Int(portText.trimmingCharacters(in: .whitespaces)), (1...65535).contains(p) {
            config?.mlxPort = p
        }
        // 三档模型落地（小/代码/复杂），主模型兼容字段跟随小档（系统初始默认小模型）
        if let s = selectedSmall { config?.mlxModelSmall = s }
        if let c = selectedCode { config?.mlxModelCode = c }
        if let h = selectedHeavy { config?.mlxModelHeavy = h }
        let mainModel = selectedSmall ?? selectedLocalModel ?? selectedModels.first
        if let mid = mainModel { config?.mlxModel = mid }
        log.info("slots saved: small=\(self.selectedSmall ?? "nil", privacy: .public) code=\(self.selectedCode ?? "nil", privacy: .public) heavy=\(self.selectedHeavy ?? "nil", privacy: .public); entering main page, services start in background")
        // 后台完成服务配置（鉴权/默认模型），不阻塞进入主页面
        Task { await self.configureBackendInBackground(mainModel: mainModel) }
        startCompleted = true
        onFinish?()
    }

    // 后台配置：写鉴权 Key + 设默认模型。捕获 self 保持引用，WelcomeView 释放后仍可完成。
    private func configureBackendInBackground(mainModel: String?) async {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        if !key.isEmpty, let client = mlxHTTP {
            do {
                _ = try await client.setupApiKey(key, confirm: key)
                log.info("setupApiKey ok (background)")
            } catch {
                log.info("setupApiKey skipped: \(error.localizedDescription, privacy: .public)")
            }
        }
        if let mid = mainModel, let bridge = agentBridge {
            do {
                _ = try await bridge.mlxSetModel(model: mid)
                log.info("set default model (small slot, background): \(mid, privacy: .public)")
            } catch {
                log.error("set model failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - 硬件检测
    func detectHardware() -> HardwareInfo {
        let chip = detectChipName()
        let cores = ProcessInfo.processInfo.processorCount
        let mem = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let bw = gpuBandwidthFromChip(chip)
        let freeBytes = (try? FileManager.default.attributesOfFileSystem(forPath: "/")[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
        return HardwareInfo(chip: chip, cpuCores: cores, memoryGB: mem, bandwidthGBs: bw, diskFreeGB: freeBytes / 1_073_741_824)
    }
    func detectChipName() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
    func gpuBandwidthFromChip(_ chip: String) -> Int? {
        let table: [(String, Int)] = [
            ("M1 Ultra", 800), ("M1 Max", 400), ("M1 Pro", 200), ("M1", 68),
            ("M2 Ultra", 800), ("M2 Max", 400), ("M2 Pro", 200), ("M2", 100),
            ("M3 Max", 300), ("M3 Pro", 150), ("M3", 92),
            ("M4 Max", 546), ("M4 Pro", 273), ("M4", 120),
            ("M5 Max", 546), ("M5 Pro", 273), ("M5", 120),
        ]
        for (k, v) in table { if chip.contains(k) { return v } }
        return nil
    }
}

struct WelcomeView: View {
    private let config = FusionConfig.shared
    @EnvironmentObject private var mlxHTTP: MlxHTTPClient
    @EnvironmentObject private var agentBridge: AgentBridge
    @EnvironmentObject private var upstreamManager: UpstreamServiceManager
    @EnvironmentObject private var ipcClient: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var vm = WelcomeViewModel()

    var onFinish: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                stepContent
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingL)
            }
            footer
        }
        .frame(width: 680, height: 620)
        .background(theme.surfacePrimary)
        .onAppear {
            vm.bind(config: config, mlxHTTP: mlxHTTP, agentBridge: agentBridge, upstreamManager: upstreamManager, ipcClient: ipcClient)
            vm.onFinish = onFinish
        }
    }

    @ViewBuilder private var stepContent: some View {
        switch vm.step {
        case .intro: WelcomeIntroStep(vm: vm)
        case .setup: WelcomeSetupStep(vm: vm)
        case .hardwareDetect: WelcomeHardwareStep(vm: vm)
        case .modelSource: WelcomeModelSourceStep(vm: vm)
        case .recommend: WelcomeRecommendStep(vm: vm)
        case .complete: WelcomeCompleteStep(vm: vm)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(theme.rowSep).frame(height: 1)
            HStack(spacing: theme.spacingM) {
                if vm.step == .intro || vm.step == .complete {
                    Spacer()
                } else {
                    FusionButton("返回", icon: "chevron.left", style: .secondary, size: .regular) { vm.back() }
                }
                Spacer()
                if let err = vm.lastError {
                    Text(err).font(.system(size: 11)).foregroundStyle(theme.accentDestructive).lineLimit(1)
                }
                Spacer()
                primaryButton
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)
        }
        .background(theme.surfaceSecondary)
    }

    @ViewBuilder private var primaryButton: some View {
        switch vm.step {
        case .intro:
            FusionButton("开始使用", icon: "arrow.right", style: .primary, size: .regular) { vm.next() }
        case .setup:
            FusionButton("继续", style: .primary, size: .regular) { vm.next() }
        case .hardwareDetect:
            FusionButton("继续", style: .primary, size: .regular) { vm.next() }
        case .modelSource:
            FusionButton("继续", style: .primary, size: .regular) { vm.next() }
        case .recommend:
            FusionButton("保存并进入", icon: "arrow.right", style: .primary, size: .regular) {
                Task { await vm.startServer() }
            }
        case .complete:
            FusionButton("完成", icon: "checkmark", style: .primary, size: .regular) { vm.onFinish?() }
        }
    }
}

private func welcomeHeader(_ theme: StudioTheme, _ title: String, _ sub: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(theme.text)
        Text(sub).font(.system(size: 13)).foregroundStyle(theme.textTertiary)
    }
}

// MARK: - Intro
struct WelcomeIntroStep: View {
    @ObservedObject var vm: WelcomeViewModel
    @Environment(\.studioTheme) var theme
    var body: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()
            Image(systemName: "cpu")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(theme.accent)
            Text("Fusion MLX").font(.system(size: 40, weight: .bold)).foregroundStyle(theme.text)
            Text("本地 AI，无需等待").font(.system(size: 20, weight: .semibold)).foregroundStyle(theme.textSecondary)
            Text("首次启动引导：选择并下载主模型，配置本地推理服务。")
                .font(.system(size: 13)).foregroundStyle(theme.textTertiary).multilineTextAlignment(.center)
            HStack(spacing: theme.spacingM) {
                featurePill("bolt.fill", "本地推理")
                featurePill("memorychip", "MLX 加速")
                featurePill("sparkles", "智能缓存")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func featurePill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(theme.accent)
        .padding(.horizontal, theme.spacingM).padding(.vertical, 6)
        .background(theme.accentSoft)
        .clipShape(Capsule())
    }
}

// MARK: - Setup
struct WelcomeSetupStep: View {
    @ObservedObject var vm: WelcomeViewModel
    @Environment(\.studioTheme) var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            welcomeHeader(theme, "配置本地服务", "fusion-mlx 已独立运行，此处确认连接端口与 API Key。")
            FusionCard(style: .bordered, header: "基础配置", headerIcon: "slider.horizontal.3") {
                VStack(spacing: theme.spacingM) {
                    HStack {
                        Text("端口").font(.system(size: 13)).foregroundStyle(theme.textSecondary).frame(width: 80, alignment: .leading)
                        TextField("11432", text: $vm.portText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                        Spacer()
                    }
                    HStack {
                        Text("API Key").font(.system(size: 13)).foregroundStyle(theme.textSecondary).frame(width: 80, alignment: .leading)
                        Group {
                            if vm.apiKeyVisible {
                                TextField("API Key", text: $vm.apiKey)
                            } else {
                                SecureField("API Key", text: $vm.apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        Button { vm.apiKeyVisible.toggle() } label: {
                            Image(systemName: vm.apiKeyVisible ? "eye.slash" : "eye").font(.system(size: 12))
                        }.buttonStyle(.plain)
                        FusionButton("重新生成", icon: "arrow.clockwise", style: .secondary, size: .small) { vm.regenerateApiKey() }
                    }
                    Text("API Key 用于鉴权，已写入 ~/.fusion-mlx/settings.json。可重新生成或沿用已有。")
                        .font(.system(size: 11)).foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Hardware
struct WelcomeHardwareStep: View {
    @ObservedObject var vm: WelcomeViewModel
    @Environment(\.studioTheme) var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            welcomeHeader(theme, "硬件检测", "当前 Mac 硬件信息，用于推荐合适的模型。")
            FusionCard(style: .bordered, header: "硬件信息", headerIcon: "cpu") {
                VStack(spacing: theme.spacingS) {
                    row("芯片", vm.hardware?.chip ?? "未知")
                    row("CPU 核数", "\(vm.hardware?.cpuCores ?? 0)")
                    row("GPU", vm.hardware?.chip ?? "Apple Silicon")
                    row("统一内存", String(format: "%.0f GB", vm.hardware?.memoryGB ?? 0))
                    row("内存带宽", vm.hardware?.bandwidthGBs.map { "\($0) GB/s" } ?? "未知")
                    row("磁盘可用", String(format: "%.0f GB", vm.hardware?.diskFreeGB ?? 0))
                }
            }
            Spacer()
        }
    }
    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 13)).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(v).font(.system(size: 13, weight: .medium)).foregroundStyle(theme.text)
        }
    }
}

// MARK: - ModelSource
struct WelcomeModelSourceStep: View {
    @ObservedObject var vm: WelcomeViewModel
    @Environment(\.studioTheme) var theme
    private let sources: [(id: String, name: String, url: String, icon: String, hint: String)] = [
        ("huggingface", "Hugging Face", "hub.huggingface.co", "globe", "国际默认源"),
        ("hf-mirror", "HF Mirror", "hf-mirror.com", "globe.asia.australia.fill", "国内镜像，速度更快"),
        ("modelscope", "ModelScope", "modelscope.cn", "globe.asia.australia.fill", "国内备选源"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            welcomeHeader(theme, "模型源", "选择下载镜像。国内用户建议选 HF Mirror 或 ModelScope。")
            VStack(spacing: theme.spacingM) {
                ForEach(sources.indices, id: \.self) { i in
                    sourceCard(sources[i])
                }
            }
            Spacer()
        }
    }
    private func sourceCard(_ s: (id: String, name: String, url: String, icon: String, hint: String)) -> some View {
        let selected = vm.modelSource == s.id
        return Button { vm.modelSource = s.id } label: {
            HStack(spacing: theme.spacingM) {
                Image(systemName: s.icon).font(.system(size: 18)).foregroundStyle(selected ? theme.accent : theme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.text)
                    Text(s.url).font(.system(size: 11, design: .monospaced)).foregroundStyle(theme.textTertiary)
                    Text(s.hint).font(.system(size: 11)).foregroundStyle(theme.textTertiary)
                }
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent) }
            }
            .padding(theme.spacingL)
            .background(selected ? theme.accentSoft : theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                    .stroke(selected ? theme.accent : theme.inputBorder, lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recommend
struct WelcomeRecommendStep: View {
    @ObservedObject var vm: WelcomeViewModel
    @Environment(\.studioTheme) var theme
    private let useCases: [(id: String, name: String, icon: String)] = [
        ("agent", "Agent", "brain.head.profile"),
        ("coding", "编程", "chevron.left.forwardslash.chevron.right"),
        ("chat", "对话", "bubble.left.and.bubble.right"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingL) {
            welcomeHeader(theme, "推荐配置", "按用例与硬件推荐模型，勾选后下载并设为主模型。")
            HStack(spacing: theme.spacingS) {
                ForEach(useCases.indices, id: \.self) { i in
                    useCaseButton(useCases[i])
                }
            }
            if !vm.localModels.isEmpty {
                FusionCard(style: .bordered, header: "配置三档模型 (\(vm.localModels.count) 个本地模型)", headerIcon: "circle.grid.2x2") {
                    VStack(spacing: theme.spacingS) {
                        slotPickerRow(.small)
                        slotPickerRow(.code)
                        slotPickerRow(.heavy)
                    }
                }
            }
            FusionCard(style: .bordered, header: "推荐下载", headerIcon: "square.and.arrow.down") {
                VStack(spacing: theme.spacingS) {
                    if vm.recommendedModels.isEmpty {
                        Text(vm.hfRecommended.isEmpty ? "正在加载推荐模型，可先从上方本地模型选择主模型…" : "暂无匹配当前硬件的推荐模型，可从上方本地模型选择。")
                            .font(.system(size: 12)).foregroundStyle(theme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(vm.recommendedModels) { m in
                            modelRow(m)
                        }
                        HStack {
                            FusionButton("全选", style: .secondary, size: .small) { vm.selectAllRecommended() }
                            Spacer()
                            FusionButton("下载 (\(vm.selectedModels.count))", icon: "arrow.down.circle", style: .primary, size: .small, isDisabled: vm.selectedModels.isEmpty) {
                                vm.downloadSelectedModels()
                            }
                        }
                        .padding(.top, theme.spacingS)
                    }
                }
            }
            Spacer()
        }
    }
    private func useCaseButton(_ uc: (id: String, name: String, icon: String)) -> some View {
        let selected = vm.useCase == uc.id
        return Button { vm.useCase = uc.id } label: {
            HStack(spacing: 6) {
                Image(systemName: uc.icon).font(.system(size: 12))
                Text(uc.name).font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(selected ? theme.accentText : theme.textSecondary)
            .padding(.horizontal, theme.spacingL).padding(.vertical, theme.spacingS)
            .background(selected ? theme.accent : theme.controlBg)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    private func modelRow(_ m: WelcomeViewModel.ModelOption) -> some View {
        let selected = vm.selectedModels.contains(m.id)
        let status = vm.modelDownloads[m.id]
        return HStack(spacing: theme.spacingM) {
            Button { vm.toggleModel(m.id) } label: {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? theme.accent : theme.textTertiary)
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.displayName).font(.system(size: 13, weight: .medium)).foregroundStyle(theme.text)
                Text(m.reason).font(.system(size: 11)).foregroundStyle(theme.textTertiary)
            }
            Spacer()
            statusView(status)
        }
        .padding(.vertical, 4)
    }
    @ViewBuilder private func statusView(_ status: String?) -> some View {
        if status == "downloading" {
            HStack(spacing: 4) { ProgressView().controlSize(.small); Text("下载中").font(.system(size: 11)).foregroundStyle(theme.textTertiary) }
        } else if status == "done" {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent)
        } else if status == "error" {
            Text("失败").font(.system(size: 11)).foregroundStyle(theme.accentDestructive)
        } else {
            Text("待下载").font(.system(size: 11)).foregroundStyle(theme.textTertiary)
        }
    }
    private func slotPickerRow(_ slot: ModelSlot) -> some View {
        HStack(spacing: theme.spacingM) {
            Label(slot.label, systemImage: slot.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.text)
                .frame(width: 92, alignment: .leading)
            Picker(selection: vm.slotBinding(slot)) {
                Text("未选择").tag("")
                ForEach(vm.localModels) { m in
                    Text(m.displayName ?? m.id).tag(m.id)
                }
            } label: { EmptyView() }
            .pickerStyle(.menu)
            .labelsHidden()
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Complete
struct WelcomeCompleteStep: View {
    @ObservedObject var vm: WelcomeViewModel
    @Environment(\.studioTheme) var theme
    var body: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(theme.accent)
            Text("设置完成").font(.system(size: 32, weight: .bold)).foregroundStyle(theme.text)
            Text("fusion-mlx 已就绪：http://\(vm.portText)").font(.system(size: 14, design: .monospaced)).foregroundStyle(theme.textSecondary)
            if let m = vm.selectedSmall {
                Text("小模型档：\(m)").font(.system(size: 13)).foregroundStyle(theme.textTertiary)
            } else {
                Text("未配置模型，可稍后在设置中配置").font(.system(size: 13)).foregroundStyle(theme.textTertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
