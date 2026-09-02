import SwiftUI
import os.log
import ServiceManagement

/// 全局设置面板
struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) var dismiss

    enum SettingsTab: String, CaseIterable {
        case general    = "通用"
        case modelSlots = "模型档位"
        case hardware   = "硬件加速"
        case network    = "网络 & 离线"
        case quant      = "量化预设"
        case workspace  = "工作区"
        case mlxConnection = "MLX 连接"

        var icon: String {
            switch self {
            case .general:    return "gearshape"
            case .modelSlots: return "circle.grid.2x2.fill"
            case .hardware:   return "cpu"
            case .network:    return "antenna.radiowaves.left.and.right"
            case .quant:      return "dial.medium"
            case .workspace:  return "folder"
            case .mlxConnection: return "server.rack"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem { Label(i18n.t(.tab_general), systemImage: "gearshape") }
                .tag(SettingsTab.general)

            ModelSlotsSettingsView()
                .tabItem { Label(i18n.t(.tab_modelSlots), systemImage: "circle.grid.2x2.fill") }
                .tag(SettingsTab.modelSlots)

            HardwareSettingsView()
                .tabItem { Label(i18n.t(.tab_hardware), systemImage: "cpu") }
                .tag(SettingsTab.hardware)

            NetworkSettingsView()
                .tabItem { Label(i18n.t(.tab_network), systemImage: "antenna.radiowaves.left.and.right") }
                .tag(SettingsTab.network)

            QuantSettingsView()
                .tabItem { Label(i18n.t(.tab_quant), systemImage: "dial.medium") }
                .tag(SettingsTab.quant)

            WorkspaceSettingsView()
                .tabItem { Label(i18n.t(.tab_workspace), systemImage: "folder") }
                .tag(SettingsTab.workspace)

            MlxConnectionSettingsView()
                .tabItem { Label(i18n.t(.tab_mlxConnection), systemImage: "server.rack") }
                .tag(SettingsTab.mlxConnection)
        }
        .frame(width: 600, height: 450)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(i18n.t(.closeBtn)) { dismiss() }
            }
        }
    }
}

// MARK: - 各设置子页面

struct GeneralSettingsView: View {
    @EnvironmentObject private var uiPanelState: UIPanelState
    @StateObject private var i18n = I18nManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoStartMLX") private var autoStartMLX = true
    @AppStorage("minimizeToMenuBar") private var minimizeToMenuBar = false

    private let settingsLog = Logger(subsystem: "com.fusion.studio", category: "Settings")

    // F-ops-3: drive macOS SMAppService.mainApp (macOS 13+) so the Login Items toggle
    // actually registers/unregisters with the system, not just flips a stored bool.
    private func syncLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
                settingsLog.info("F-ops-3: launchAtLogin registered via SMAppService")
            } else {
                try service.unregister()
                settingsLog.info("F-ops-3: launchAtLogin unregistered via SMAppService")
            }
        } catch {
            settingsLog.error("F-ops-3: SMAppService \(enabled ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
    }

    var body: some View {
        Form {
            Section(i18n.t(.sec_startup)) {
                Toggle(i18n.t(.launchAtLogin), isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        syncLaunchAtLogin(newValue)
                    }
                ))
                Toggle(i18n.t(.autoStartMLX), isOn: $autoStartMLX)
                Button(i18n.t(.reselectMainModel)) {
                    uiPanelState.showWelcome = true
                }
            }
            Section(i18n.t(.sec_window)) {
                Toggle(i18n.t(.minimizeToMenuBar), isOn: $minimizeToMenuBar)
            }
            Section(i18n.t(.sec_language)) {
                Picker(i18n.t(.interfaceLanguage), selection: Binding(
                    get: { i18n.currentLanguage.rawValue },
                    set: { newVal in
                        if let lang = AppLanguage(rawValue: newVal) {
                            i18n.currentLanguage = lang
                            settingsLog.info("Language switched to \(lang.rawValue)")
                        }
                    }
                )) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text("\(lang.flag) \(lang.displayName)").tag(lang.rawValue)
                    }
                }
            }
        }
        .padding()
    }
}

struct HardwareSettingsView: View {
    @AppStorage("preferredDevice") private var preferredDevice = "auto"
    @AppStorage("maxMemory") private var maxMemory = 16.0
    @AppStorage("enableANE") private var enableANE = true
    @AppStorage("enableMetal") private var enableMetal = true
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        Form {
            Section(i18n.t(.sec_hwPref)) {
                Picker(i18n.t(.preferredDevice), selection: $preferredDevice) {
                    Text(i18n.t(.dev_auto)).tag("auto")
                    Text(i18n.t(.dev_metal)).tag("metal")
                    Text(i18n.t(.dev_ane)).tag("ane")
                    Text(i18n.t(.dev_cpu)).tag("cpu")
                }
                Toggle(i18n.t(.enableMetal), isOn: $enableMetal)
                Toggle(i18n.t(.enableANE), isOn: $enableANE)
            }
            Section(i18n.t(.sec_memLimit)) {
                VStack(alignment: .leading) {
                    Slider(value: $maxMemory, in: 4...64, step: 2) {
                        Text(String(format: i18n.t(.maxUnifiedMemory), Int(maxMemory)))
                    }
                    Text(i18n.t(.mlxMemoryHint))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct NetworkSettingsView: View {
    private let netSettingsLog = Logger(subsystem: "com.fusion.studio", category: "Settings.Network")
    @AppStorage("offlineMode") private var offlineMode = true
    @AppStorage("allowModelDownload") private var allowModelDownload = true
    @AppStorage("allowUpdateCheck") private var allowUpdateCheck = true
    // F-ops-8: 本地崩溃遥测 opt-in toggle (默认 OFF, 零网络上传, 仅落盘 ~/.fusion-studio/logs/crash-*.log)。
    @AppStorage("enableCrashTelemetry") private var enableCrashTelemetry = false
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        Form {
            Section(i18n.t(.sec_offlinePolicy)) {
                Toggle(i18n.t(.forceOffline), isOn: $offlineMode)
                    .help(i18n.t(.forceOfflineHelp))
                if offlineMode {
                    Text(i18n.t(.offlineActive))
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            Section(i18n.t(.sec_netPerms)) {
                Toggle(i18n.t(.allowModelDownload), isOn: $allowModelDownload)
                    .disabled(offlineMode)
                Toggle(i18n.t(.checkUpdates), isOn: $allowUpdateCheck)
                    .disabled(offlineMode)
            }
            Section(i18n.t(.sec_telemetry)) {
                Toggle(i18n.t(.enableCrashTelemetry), isOn: Binding(
                    get: { enableCrashTelemetry },
                    set: { newValue in
                        enableCrashTelemetry = newValue
                        if newValue {
                            CrashReporter.shared.start()
                            netSettingsLog.info("F-ops-8: crash telemetry enabled by user")
                        }
                    }
                ))
                .help(i18n.t(.enableCrashTelemetryHelp))
            }
        }
        .padding()
    }
}

struct QuantSettingsView: View {
    @AppStorage("defaultQuant") private var defaultQuant = "4bit"
    @AppStorage("defaultFormat") private var defaultFormat = "mlx"
    @StateObject private var i18n = I18nManager.shared

    let quantOptions = ["2bit", "3bit", "4bit", "5bit", "6bit", "8bit", "fp16"]
    let formatOptions = ["mlx", "gguf", "safetensors"]

    var body: some View {
        Form {
            Section(i18n.t(.sec_quantPreset)) {
                Picker(i18n.t(.defaultQuant), selection: $defaultQuant) {
                    ForEach(quantOptions, id: \.self) { q in
                        Text(q).tag(q)
                    }
                }
                Picker(i18n.t(.defaultFormat), selection: $defaultFormat) {
                    ForEach(formatOptions, id: \.self) { f in
                        Text(f.uppercased()).tag(f)
                    }
                }
            }
            Section(i18n.t(.sec_note)) {
                Text(i18n.t(.quantNote))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct WorkspaceSettingsView: View {
    @AppStorage("workspacePath") private var workspacePath = "~/FusionStudio/workspace"
    @State private var showFilePicker = false
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        Form {
            Section(i18n.t(.sec_wsDir)) {
                HStack {
                    TextField(i18n.t(.path), text: $workspacePath)
                        .textFieldStyle(.roundedBorder)
                    Button(i18n.t(.browse)) {
                        showFilePicker = true
                    }
                }
                Text(i18n.t(.wsHint))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section(i18n.t(.sec_autoMgmt)) {
                Toggle(i18n.t(.autoProjectSubdir), isOn: .constant(true))
                Toggle(i18n.t(.enableGit), isOn: .constant(false))
                Toggle(i18n.t(.autoBackup), isOn: .constant(true))
            }
        }
        .padding()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder],
            onCompletion: { result in
                if case .success(let url) = result {
                    workspacePath = url.path
                }
            }
        )
    }
}

// MARK: - 模型档位设置

struct ModelSlotsSettingsView: View {
    @EnvironmentObject private var bridge: AgentBridge
    @ObservedObject private var config = FusionConfig.shared
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared
    private let log = Logger(subsystem: "com.fusion.studio", category: "Settings.ModelSlots")

    private var chatModels: [MLXModelInfo] {
        let chat = bridge.mlxState.models.filter { $0.isTextChatModel }
        return chat.isEmpty ? bridge.mlxState.models : chat
    }

    private func slotBinding(_ slot: ModelSlot) -> Binding<String> {
        Binding(
            get: { config.slotModel(slot) },
            set: { config.setSlotModel(slot, $0); log.info("slot=\(slot.rawValue) model=\($0)") }
        )
    }

    private func sceneSlotBinding(_ scene: ModelScene) -> Binding<ModelSlot> {
        Binding(
            get: { config.defaultSlot(for: scene) },
            set: { newVal in
                switch scene {
                case .chat: config.defaultSlotChat = newVal.rawValue
                case .code: config.defaultSlotCode = newVal.rawValue
                case .agent: config.defaultSlotAgent = newVal.rawValue
                case .artifacts: config.defaultSlotArtifacts = newVal.rawValue
                }
                log.info("scene=\(scene.rawValue) defaultSlot=\(newVal.rawValue)")
            }
        )
    }

    var body: some View {
        Form {
            Section(i18n.t(.sec_slotModels)) {
                if chatModels.isEmpty {
                    Text(i18n.t(.noLocalModels))
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                }
                ForEach(ModelSlot.allCases) { slot in
                    Picker(selection: slotBinding(slot)) {
                        Text(i18n.t(.notSet)).tag("")
                        ForEach(chatModels) { m in
                            Text(m.name).tag(m.id)
                        }
                    } label: {
                        Label(slot.label, systemImage: slot.icon)
                    }
                    .pickerStyle(.menu)
                }
            }
            Section(i18n.t(.sec_sceneDefault)) {
                ForEach(ModelScene.allCases) { scene in
                    Picker(selection: sceneSlotBinding(scene)) {
                        ForEach(ModelSlot.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    } label: {
                        Label(scene.label, systemImage: "scope")
                    }
                    .pickerStyle(.menu)
                }
            }
            Section(i18n.t(.sec_note)) {
                Text(i18n.t(.slotNote))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            Section(i18n.t(.fa2_mlxPoolStatus)) {
                HStack(spacing: theme.spacingS) {
                    Circle()
                        .fill(bridge.mlxState.mlxRunning ? theme.blueDot : theme.textTertiary)
                        .frame(width: 8, height: 8)
                    Text(bridge.mlxState.mlxRunning
                         ? i18n.t(.fa2_mlxRunning)
                         : i18n.t(.fa2_mlxStopped))
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Text("\(bridge.mlxState.mlxLoadedModels.count) \(i18n.t(.fa2_mlxModelsLoaded))")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                    if bridge.mlxState.mlxPort > 0 {
                        Text(":\(bridge.mlxState.mlxPort)")
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                if !bridge.mlxState.mlxLoadedModels.isEmpty {
                    Text(bridge.mlxState.mlxLoadedModels.joined(separator: ", "))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(3)
                }
            }
        }
        .padding()
        .onAppear {
            Task { try? await bridge.fetchModels() }
        }
    }
}

// MARK: - MLX 连接设置 (#381: 控件从死代码 CustomizePanel 迁入可达 SettingsView)

struct MlxConnectionSettingsView: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject private var config = FusionConfig.shared
    @State private var editingApiKey = false
    @State private var apiKeyInput = ""
    @State private var editingMlxEndpoint = false
    @State private var mlxHostInput = ""
    @State private var mlxPortInput = ""
    @StateObject private var i18n = I18nManager.shared
    private let log = Logger(subsystem: "com.fusion.studio", category: "Settings.MlxConnection")

    private var configured: Bool { !config.mlxResolvedApiKey.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text(i18n.t(.sec_auth))
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.bottom, theme.spacingXS)
                settingRow("MLX API Key", configured ? "已配置" : "未配置") {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: configured ? "checkmark.seal.fill" : "exclamationmark.triangle")
                            .foregroundStyle(configured ? theme.successText : theme.errorText)
                        Button(editingApiKey ? "取消" : "修改") {
                            if editingApiKey {
                                editingApiKey = false
                                apiKeyInput = ""
                            } else {
                                apiKeyInput = ""
                                editingApiKey = true
                            }
                            log.info("API key edit mode: \(editingApiKey)")
                        }
                        .font(.system(size: theme.captionSize))
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                    }
                }
                if editingApiKey {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        SecureField("输入新的 API Key", text: $apiKeyInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: theme.textSize, design: .monospaced))
                            .padding(theme.spacingS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(theme.inputBg)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .stroke(theme.inputBorder, lineWidth: 1)
                            }
                        Button("保存") {
                            saveApiKey(apiKeyInput)
                            editingApiKey = false
                            apiKeyInput = ""
                        }
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.leading, theme.spacingM)
                }
                Divider().padding(.vertical, theme.spacingXS)
                Text(i18n.t(.sec_endpoint))
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.bottom, theme.spacingXS)
                settingRow("MLX 端点覆盖", "ON 时使用下方地址，忽略环境变量 (FUSION_MLX_PORT 等)") {
                    Toggle("", isOn: $config.mlxEndpointOverrideEnabled)
                        .toggleStyle(.switch).controlSize(.small).labelsHidden()
                }
                if config.mlxEndpointOverrideEnabled {
                    settingRow("MLX Host", "直连 MLX 服务地址 (默认 127.0.0.1，非 gateway)") {
                        HStack(spacing: theme.spacingS) {
                            Image(systemName: editingMlxEndpoint ? "checkmark.seal.fill" : "pencil")
                                .foregroundStyle(editingMlxEndpoint ? theme.successText : theme.accent)
                            Button(editingMlxEndpoint ? "完成" : "修改") {
                                if editingMlxEndpoint {
                                    saveMlxEndpoint(mlxHostInput, mlxPortInput)
                                    editingMlxEndpoint = false
                                } else {
                                    mlxHostInput = config.mlxHost
                                    mlxPortInput = String(config.mlxPort)
                                    editingMlxEndpoint = true
                                }
                                log.info("MLX endpoint edit mode: \(editingMlxEndpoint)")
                            }
                            .font(.system(size: theme.captionSize))
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.accent)
                        }
                    }
                    if editingMlxEndpoint {
                        VStack(alignment: .leading, spacing: theme.spacingXS) {
                            TextField("Host (如 127.0.0.1)", text: $mlxHostInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: theme.textSize, design: .monospaced))
                                .padding(theme.spacingS)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .fill(theme.inputBg)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }
                            TextField("Port (如 11434)", text: $mlxPortInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: theme.textSize, design: .monospaced))
                                .padding(theme.spacingS)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .fill(theme.inputBg)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .stroke(theme.inputBorder, lineWidth: 1)
                                }
                            Button("保存") {
                                saveMlxEndpoint(mlxHostInput, mlxPortInput)
                                editingMlxEndpoint = false
                            }
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.accent)
                            .disabled(mlxHostInput.trimmingCharacters(in: .whitespaces).isEmpty
                                      || Int(mlxPortInput) == nil || (Int(mlxPortInput) ?? 0) <= 0)
                        }
                        .padding(.leading, theme.spacingM)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func settingRow<C: View>(_ title: String, _ desc: String, @ViewBuilder control: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Spacer()
                control()
            }
            Text(desc)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func saveApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let settingsPath = NSHomeDirectory() + "/.fusion-mlx/settings.json"
        let url = URL(fileURLWithPath: settingsPath)
        do {
            var settings: [String: Any] = [:]
            if let data = try? Data(contentsOf: url),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                settings = existing
            }
            var auth = settings["auth"] as? [String: Any] ?? [:]
            auth["api_key"] = trimmed
            settings["auth"] = auth
            let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settingsPath)
            config.mlxApiKey = trimmed
            log.info("API key saved: Keychain (primary) + settings.json 0600, config refreshed")
        } catch {
            log.error("Failed to save API key: \(error.localizedDescription)")
        }
    }

    private func saveMlxEndpoint(_ host: String, _ port: String) {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        let trimmedPort = port.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty, let portInt = Int(trimmedPort), portInt > 0 else {
            log.error("saveMlxEndpoint: invalid input host=\(trimmedHost) port=\(trimmedPort), skip")
            return
        }
        config.mlxHost = trimmedHost
        config.mlxPort = portInt
        config.mlxEndpointOverrideEnabled = true
        log.info("MLX endpoint saved: \(trimmedHost):\(portInt) override=on (env ignored)")
    }
}