import Foundation
import SwiftUI
import os.log
// Callers: UpstreamServiceManager, ContentView, SettingsView
// Affected API: multi-node health endpoint port
// Data: @AppStorage port properties
// User instruction: "修复issue #111" — add multiNodePort=11452

private let fusionConfigLog = Logger(subsystem: "com.fusion.studio", category: "FusionConfig")

/// 模型档位：小（日常对话）/ 代码 / 复杂事务
enum ModelSlot: String, CaseIterable, Identifiable {
    case small, code, heavy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small: return "小模型"
        case .code: return "代码模型"
        case .heavy: return "复杂模型"
        }
    }
    var icon: String {
        switch self {
        case .small: return "hare"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .heavy: return "brain.head.profile"
        }
    }
}

/// 用模型场景：决定默认档位（对话->小、code->代码、agent/artifacts->复杂）
enum ModelScene: String, CaseIterable, Identifiable {
    case chat, code, agent, artifacts
    var id: String { rawValue }
    var label: String {
        switch self {
        case .chat: return "对话"
        case .code: return "代码"
        case .agent: return "Agent"
        case .artifacts: return "Artifacts"
        }
    }
}

/// 统一全局配置模型
/// 将所有 @AppStorage 集中管理，替代分散在各 View 中的存储属性
class FusionConfig: ObservableObject {
    static let shared = FusionConfig()

    // MARK: - 通用
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("autoStartMLX") var autoStartMLX = true
    @AppStorage("minimizeToMenuBar") var minimizeToMenuBar = false
    @AppStorage("language") var language = "zh-CN"

    // MARK: - 硬件加速
    @AppStorage("preferredDevice") var preferredDevice = "auto"
    @AppStorage("maxMemory") var maxMemory = 16.0
    @AppStorage("enableANE") var enableANE = true
    @AppStorage("enableMetal") var enableMetal = true

    // MARK: - 网络 & 离线
    @AppStorage("offlineMode") var offlineMode = true
    @AppStorage("allowModelDownload") var allowModelDownload = true
    @AppStorage("allowUpdateCheck") var allowUpdateCheck = true

    // MARK: - 量化预设
    @AppStorage("defaultQuant") var defaultQuant = "4bit"
    @AppStorage("defaultFormat") var defaultFormat = "mlx"

    // MARK: - 工作区
    @AppStorage("workspacePath") var workspacePath = "~/FusionStudio/workspace"

    // MARK: - IPC
    @AppStorage("ipcSocketPath") var ipcSocketPath = "/tmp/fusion-studio.sock"

    // MARK: - MLX
    @AppStorage("mlxHost") var mlxHost = "localhost"
    @AppStorage("mlxPort") var mlxPort = 11432
    @AppStorage("mlxApiKey") var mlxApiKey = ""
    @AppStorage("mlxModel") var mlxModel = ""
    @AppStorage("mlxPath") var mlxPath = ""

    // MARK: - 模型档位（小/代码/复杂）+ 场景默认映射
    // Callers: FusionModelPicker/WelcomeView/SettingsView/CodeMainView/AgentStudioView/DesignBridge
    // 场景映射：对话->小、code->代码、agent/artifacts->复杂；设置可改每场景默认档
    @AppStorage("mlxModelSmall") var mlxModelSmall = ""
    @AppStorage("mlxModelCode") var mlxModelCode = ""
    @AppStorage("mlxModelHeavy") var mlxModelHeavy = ""
    @AppStorage("defaultSlotChat") var defaultSlotChat = ModelSlot.small.rawValue
    @AppStorage("defaultSlotCode") var defaultSlotCode = ModelSlot.code.rawValue
    @AppStorage("defaultSlotAgent") var defaultSlotAgent = ModelSlot.heavy.rawValue
    @AppStorage("defaultSlotArtifacts") var defaultSlotArtifacts = ModelSlot.heavy.rawValue

    // User instruction: "所有的项目要有一个配置文件，配置类的卸载配置文件里面，不能写死在代码里面"
    // Importers/callers: IPCClient.swift reads FusionConfig.shared.artifactsEngineURL; ArtifactsPanel reads via IPCClient
    // Affected API: new @AppStorage fields artifactsEngineHost/artifactsEnginePort, computed property artifactsEngineURL
    // Data schemas: @AppStorage (UserDefaults) persistence for host/port

    // MARK: - Artifacts Engine
    @AppStorage("artifactsEngineHost") var artifactsEngineHost = "127.0.0.1"
    @AppStorage("artifactsEnginePort") var artifactsEnginePort = 11451

    /// Artifacts Engine 服务地址
    var artifactsEngineURL: String { "http://\(artifactsEngineHost):\(artifactsEnginePort)" }

    // MARK: - Fusion-RAG
    // callers: RAGAPIClient.swift reads FusionConfig.shared.fusionRagURL / fusionRagApiKey
    // API: fusion-rag HTTP API on port 11436, auth via X-API-Key header
    // schema: @AppStorage persistence, same pattern as mlxHost/mlxPort
    // user instruction: "完成所有待办任务"
    @AppStorage("fusionRagHost") var fusionRagHost = "127.0.0.1"
    @AppStorage("fusionRagPort") var fusionRagPort = 11436
    @AppStorage("fusionRagApiKey") var fusionRagApiKey = ""
    @AppStorage("fusionRagEmbed") var fusionRagEmbed = "BGE-M3"

    /// Fusion-RAG 服务地址
    var fusionRagURL: String { "http://\(fusionRagHost):\(fusionRagPort)" }

    /// Fusion-Code API 服务地址
    var fusionCodeURL: String { "http://127.0.0.1:\(fusionCodePort)" }

    // MARK: - Upstream Services
    // Callers: UpstreamServiceManager reads these to locate each upstream repo's start.sh.
    // Affected API: @AppStorage upstream*Path fields + upstreamAutoStartCritical + expandedUpstreamPath(_:).
    // Data schemas: @AppStorage (UserDefaults) string paths with ~ expansion.
    // User instruction: "在所有依赖的上游模块根目录创建start.sh，在fusion-studio启动时需要检测上游服务是否启动，如果没有启动，尝试调用start.sh启动上游服务，如果启动不成功，fusion-studio要展示服务不存在，或者服务启动失败等等"
    @AppStorage("upstreamAgentStudioPath") var upstreamAgentStudioPath = "~/fusion/fusion-agent-studio"
    @AppStorage("upstreamMlxPath") var upstreamMlxPath = "~/claude-home/fusion-mlx"
    @AppStorage("upstreamArtifactsPath") var upstreamArtifactsPath = "~/fusion/fusion-artifacts-engine"
    @AppStorage("upstreamRagPath") var upstreamRagPath = "~/fusion/fusion-kb"
    @AppStorage("upstreamMultiNodePath") var upstreamMultiNodePath = "~/fusion/fusion-multi-node"
    @AppStorage("upstreamFusionCodePath") var upstreamFusionCodePath = "~/fusion/fusion-code"
    @AppStorage("upstreamSciencePath") var upstreamSciencePath = "~/fusion/fusion-science"
    // Callers: SimulationBridge (baseURL), UpstreamServiceManager (health + repoPath).
    // Affected API: @AppStorage simulationHost/simulationPort + simulationBaseURL computed property.
    // Data schemas: @AppStorage (UserDefaults) host/port, port 11455 = fusion-sim FastAPI dashboard (--gui).
    // User instruction: "在左侧菜单增加 fusion simulation,fusion-studio负责GUI，和~/fusion/fuison-simulation项目集成起来"
    @AppStorage("upstreamSimulationPath") var upstreamSimulationPath = "~/fusion/fusion-simulation"
    @AppStorage("fusionCodePort") var fusionCodePort = 11441
    @AppStorage("upstreamAutoStartCritical") var upstreamAutoStartCritical = true

    // MARK: - Upstream Service Ports
    @AppStorage("coworkSyncPort") var coworkSyncPort = 11437
    @AppStorage("coworkMcpPort") var coworkMcpPort = 11438
    @AppStorage("modelHubHost") var modelHubHost = "127.0.0.1"
    @AppStorage("modelHubPort") var modelHubPort = 11444
    @AppStorage("modelHubApiKey") var modelHubApiKey = ""
    @AppStorage("securityPort") var securityPort = 11442
    @AppStorage("fusionDeskPort") var fusionDeskPort = 9761
    @AppStorage("fusionDocPort") var fusionDocPort = 11449
    @AppStorage("fusionBenchPort") var fusionBenchPort = 11450
    @AppStorage("agentStudioHttpPort") var agentStudioHttpPort = 11453
    @AppStorage("multiNodePort") var multiNodePort = 11452
    @AppStorage("scienceHost") var scienceHost = "127.0.0.1"
    @AppStorage("sciencePort") var sciencePort = 8200

    /// Fusion-Science 服务地址
    var scienceBaseURL: String { "http://\(scienceHost):\(sciencePort)" }

    // Callers: SimulationBridge, UpstreamServiceManager. Port 11455 = fusion-sim dashboard (--gui).
    @AppStorage("simulationHost") var simulationHost = "127.0.0.1"
    @AppStorage("simulationPort") var simulationPort = 11455

    /// Fusion-Simulation 服务地址（FastAPI 控制面，需 fusion-sim service start --gui）
    var simulationBaseURL: String { "http://\(simulationHost):\(simulationPort)" }

    /// 展开 ~/ 路径为绝对路径
    func expandedUpstreamPath(_ raw: String) -> String {
        (raw as NSString).expandingTildeInPath
    }

    // MARK: - 模型档位 helpers
    /// 该档配置的 model id
    func slotModel(_ slot: ModelSlot) -> String {
        switch slot {
        case .small: return mlxModelSmall
        case .code: return mlxModelCode
        case .heavy: return mlxModelHeavy
        }
    }
    /// 设置某档模型
    func setSlotModel(_ slot: ModelSlot, _ model: String) {
        switch slot {
        case .small: mlxModelSmall = model
        case .code: mlxModelCode = model
        case .heavy: mlxModelHeavy = model
        }
    }
    /// 场景的默认档位
    func defaultSlot(for scene: ModelScene) -> ModelSlot {
        switch scene {
        case .chat: return ModelSlot(rawValue: defaultSlotChat) ?? .small
        case .code: return ModelSlot(rawValue: defaultSlotCode) ?? .code
        case .agent: return ModelSlot(rawValue: defaultSlotAgent) ?? .heavy
        case .artifacts: return ModelSlot(rawValue: defaultSlotArtifacts) ?? .heavy
        }
    }
    /// 场景的默认 model id（档位空则回退 mlxModel）
    func defaultModel(for scene: ModelScene) -> String {
        let m = slotModel(defaultSlot(for: scene))
        return m.isEmpty ? mlxModel : m
    }

    // MARK: - 便捷方法

    /// 是否处于离线模式
    var isOffline: Bool { offlineMode }

    /// MLX 服务地址
    var mlxBaseURL: String { "http://\(mlxHost):\(mlxPort)" }

    /// MLX API Key — 解析优先级与上游 fusion-mlx _resolve_api_key 对齐：
    /// 1) 用户在 Settings 显式设置 (mlxApiKey @AppStorage)
    /// 2) 进程环境变量 FUSION_MLX_API_KEY（fusion-mlx/fusion-gateway 启动时注入）
    /// 3) ~/.fusion-mlx/settings.json -> auth.api_key
    var mlxResolvedApiKey: String {
        if !mlxApiKey.isEmpty {
            fusionConfigLog.info("mlxResolvedApiKey: source=user-settings")
            return mlxApiKey
        }
        if let envKey = ProcessInfo.processInfo.environment["FUSION_MLX_API_KEY"], !envKey.isEmpty {
            fusionConfigLog.info("mlxResolvedApiKey: source=FUSION_MLX_API_KEY env")
            return envKey
        }
        if let data = try? Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory() + "/.fusion-mlx/settings.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let auth = json["auth"] as? [String: Any],
           let key = auth["api_key"] as? String, !key.isEmpty {
            fusionConfigLog.info("mlxResolvedApiKey: source=settings.json")
            return key
        }
        fusionConfigLog.warning("mlxResolvedApiKey: no key resolved (env/settings both empty)")
        return ""
    }

    /// 展开的工作区路径
    var expandedWorkspacePath: String {
        (workspacePath as NSString).expandingTildeInPath
    }

    /// 展开的 MLX 路径
    var expandedMLXPath: String {
        if mlxPath.isEmpty {
            return NSHomeDirectory() + "/.fusion-mlx"
        }
        return (mlxPath as NSString).expandingTildeInPath
    }

    /// 重置所有配置为默认值
    func resetToDefaults() {
        launchAtLogin = false
        autoStartMLX = true
        minimizeToMenuBar = false
        language = "zh-CN"

        preferredDevice = "auto"
        maxMemory = 16.0
        enableANE = true
        enableMetal = true

        offlineMode = true
        allowModelDownload = true
        allowUpdateCheck = true

        defaultQuant = "4bit"
        defaultFormat = "mlx"

        workspacePath = "~/FusionStudio/workspace"
        ipcSocketPath = "/tmp/fusion-studio.sock"
        mlxHost = "localhost"
        mlxPort = 11432
        mlxModel = ""
        mlxModelSmall = ""
        mlxModelCode = ""
        mlxModelHeavy = ""
        defaultSlotChat = ModelSlot.small.rawValue
        defaultSlotCode = ModelSlot.code.rawValue
        defaultSlotAgent = ModelSlot.heavy.rawValue
        defaultSlotArtifacts = ModelSlot.heavy.rawValue
        mlxPath = ""

        artifactsEngineHost = "127.0.0.1"
        artifactsEnginePort = 11451

        fusionRagHost = "127.0.0.1"
        fusionRagPort = 11436
        fusionRagApiKey = ""

        upstreamAgentStudioPath = "~/fusion/fusion-agent-studio"
        upstreamMlxPath = "~/claude-home/fusion-mlx"
        upstreamArtifactsPath = "~/fusion/fusion-artifacts-engine"
        upstreamRagPath = "~/fusion/fusion-kb"
        upstreamMultiNodePath = "~/fusion/fusion-multi-node"
        upstreamFusionCodePath = "~/fusion/fusion-code"
        upstreamSciencePath = "~/fusion/fusion-science"
        upstreamSimulationPath = "~/fusion/fusion-simulation"
        fusionCodePort = 11441
        upstreamAutoStartCritical = true

        coworkSyncPort = 11437
        coworkMcpPort = 11438
        modelHubHost = "127.0.0.1"
        modelHubPort = 11444
        modelHubApiKey = ""
        securityPort = 11442
        fusionDeskPort = 9761
        fusionDocPort = 11449
        fusionBenchPort = 11450
        agentStudioHttpPort = 11453
        scienceHost = "127.0.0.1"
        sciencePort = 8200
        simulationHost = "127.0.0.1"
        simulationPort = 11455
    }
}
