import SwiftUI

/// 全局设置面板
struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @Environment(\.dismiss) var dismiss

    enum SettingsTab: String, CaseIterable {
        case general    = "通用"
        case hardware   = "硬件加速"
        case network    = "网络 & 离线"
        case quant      = "量化预设"
        case workspace  = "工作区"

        var icon: String {
            switch self {
            case .general:   return "gearshape"
            case .hardware:  return "cpu"
            case .network:   return "antenna.radiowaves.left.and.right"
            case .quant:     return "dial.medium"
            case .workspace: return "folder"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            HardwareSettingsView()
                .tabItem { Label("硬件加速", systemImage: "cpu") }
                .tag(SettingsTab.hardware)

            NetworkSettingsView()
                .tabItem { Label("网络 & 离线", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(SettingsTab.network)

            QuantSettingsView()
                .tabItem { Label("量化预设", systemImage: "dial.medium") }
                .tag(SettingsTab.quant)

            WorkspaceSettingsView()
                .tabItem { Label("工作区", systemImage: "folder") }
                .tag(SettingsTab.workspace)
        }
        .frame(width: 600, height: 450)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("关闭") { dismiss() }
            }
        }
    }
}

// MARK: - 各设置子页面

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoStartMLX") private var autoStartMLX = true
    @AppStorage("minimizeToMenuBar") private var minimizeToMenuBar = false
    @AppStorage("language") private var language = "zh-CN"

    var body: some View {
        Form {
            Section("启动") {
                Toggle("登录时启动 Fusion Studio", isOn: $launchAtLogin)
                Toggle("自动启动 fusion-mlx 服务", isOn: $autoStartMLX)
            }
            Section("窗口") {
                Toggle("最小化到菜单栏", isOn: $minimizeToMenuBar)
            }
            Section("语言") {
                Picker("界面语言", selection: $language) {
                    Text("中文").tag("zh-CN")
                    Text("English").tag("en-US")
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

    var body: some View {
        Form {
            Section("硬件偏好") {
                Picker("首选设备", selection: $preferredDevice) {
                    Text("自动").tag("auto")
                    Text("GPU (Metal)").tag("metal")
                    Text("ANE").tag("ane")
                    Text("CPU Only").tag("cpu")
                }
                Toggle("启用 Metal 加速", isOn: $enableMetal)
                Toggle("启用 ANE 加速", isOn: $enableANE)
            }
            Section("内存限制") {
                VStack(alignment: .leading) {
                    Slider(value: $maxMemory, in: 4...64, step: 2) {
                        Text("最大统一内存: \(Int(maxMemory)) GB")
                    }
                    Text("fusion-mlx 推理可用最大内存")
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

    var body: some View {
        Form {
            Section("离线策略") {
                Toggle("强制离线模式", isOn: $offlineMode)
                    .help("开启后，所有网络请求将被拦截")
                if offlineMode {
                    Text("✅ 当前为离线模式，数据不会离开本机")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            Section("网络权限") {
                Toggle("允许模型下载", isOn: $allowModelDownload)
                    .disabled(offlineMode)
                Toggle("检查版本更新", isOn: $allowUpdateCheck)
                    .disabled(offlineMode)
            }
        }
        .padding()
    }
}

struct QuantSettingsView: View {
    @AppStorage("defaultQuant") private var defaultQuant = "4bit"
    @AppStorage("defaultFormat") private var defaultFormat = "mlx"

    let quantOptions = ["2bit", "3bit", "4bit", "5bit", "6bit", "8bit", "fp16"]
    let formatOptions = ["mlx", "gguf", "safetensors"]

    var body: some View {
        Form {
            Section("量化预设") {
                Picker("默认量化精度", selection: $defaultQuant) {
                    ForEach(quantOptions, id: \.self) { q in
                        Text(q).tag(q)
                    }
                }
                Picker("默认模型格式", selection: $defaultFormat) {
                    ForEach(formatOptions, id: \.self) { f in
                        Text(f.uppercased()).tag(f)
                    }
                }
            }
            Section("说明") {
                Text("4bit 是精度与性能的最佳平衡点\n2bit 极端压缩（适合 8GB 内存设备）\n8bit/fp16 最高精度（需要 32GB+ 内存）")
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

    var body: some View {
        Form {
            Section("工作区目录") {
                HStack {
                    TextField("路径", text: $workspacePath)
                        .textFieldStyle(.roundedBorder)
                    Button("浏览...") {
                        showFilePicker = true
                    }
                }
                Text("所有设计文件、代码工程、仿真场景、模型权重将统一存放于此")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Section("自动管理") {
                Toggle("自动创建项目子目录", isOn: .constant(true))
                Toggle("启用 Git 版本管理", isOn: .constant(false))
                Toggle("自动本地备份", isOn: .constant(true))
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