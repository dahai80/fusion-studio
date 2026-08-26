import SwiftUI
import os.log

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

        var icon: String {
            switch self {
            case .general:    return "gearshape"
            case .modelSlots: return "circle.grid.2x2.fill"
            case .hardware:   return "cpu"
            case .network:    return "antenna.radiowaves.left.and.right"
            case .quant:      return "dial.medium"
            case .workspace:  return "folder"
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

    var body: some View {
        Form {
            Section(i18n.t(.sec_startup)) {
                Toggle(i18n.t(.launchAtLogin), isOn: $launchAtLogin)
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
    @AppStorage("offlineMode") private var offlineMode = true
    @AppStorage("allowModelDownload") private var allowModelDownload = true
    @AppStorage("allowUpdateCheck") private var allowUpdateCheck = true
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