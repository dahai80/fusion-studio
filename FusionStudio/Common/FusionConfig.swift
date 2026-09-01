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
    var localizedName: String {
        switch self {
        case .small: return I18nManager.shared.t(.mslot_small)
        case .code: return I18nManager.shared.t(.mslot_code)
        case .heavy: return I18nManager.shared.t(.mslot_heavy)
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
    var localizedName: String {
        switch self {
        case .chat: return I18nManager.shared.t(.mscene_chat)
        case .code: return I18nManager.shared.t(.mscene_code)
        case .agent: return I18nManager.shared.t(.mscene_agent)
        case .artifacts: return I18nManager.shared.t(.mscene_artifacts)
        }
    }
}

/// 统一全局配置模型
/// 将所有 @AppStorage 集中管理，替代分散在各 View 中的存储属性
class FusionConfig: ObservableObject {
    static let shared = FusionConfig()

    // F-I9 追加: 旧用户 @AppStorage 残留 11445 (与 comfyui 撞, 2026-08-24 迁 11458)。
    // 首启迁移一次, UserDefaults flag 兜底防重复。
    private static let stalePortMigratedKey = "fusionConfig.stalePortMigratedV1"
    init() {
        migrateStalePorts()
    }

    func migrateStalePorts() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.stalePortMigratedKey) else { return }
        // multiNodeAgentPort: 旧默认 11445 → 11458 (fusion-multi-nodes#22/#25 迁出, 与 comfyuiPort 撞)
        let oldAgentPort = defaults.integer(forKey: "multiNodeAgentPort")
        if oldAgentPort == 11445 {
            defaults.set(11458, forKey: "multiNodeAgentPort")
            fusionConfigLog.info("F-I9 migrate: multiNodeAgentPort 11445 → 11458 (stale comfyui conflict)")
        }
        defaults.set(true, forKey: Self.stalePortMigratedKey)
        fusionConfigLog.info("F-I9 migrate: stale port migration v1 done (oldAgentPort=\(oldAgentPort))")
    }

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
    @AppStorage("mlxPort") var mlxPort = 11434
    // #380: 用户显式覆盖 MLX 端点。ON = mlxHost:mlxPort 覆盖所有 env (FUSION_GATEWAY_URL/
    // FUSION_MLX_URL/FUSION_MLX_PORT); OFF = 保留 env 优先 (部署默认)。
    // 不改 .zshrc, 用户在 Settings UI 显式 pin 端点绕开误注入的 gateway env。
    @AppStorage("mlxEndpointOverrideEnabled") var mlxEndpointOverrideEnabled = false
    // API key 存 macOS Keychain (HIGH-2), 不再 @AppStorage 明文落 UserDefaults plist
    // didSet 写 Keychain; mlxResolvedApiKey 读取此属性 (内存缓存 = Keychain 真值)
    @Published var mlxApiKey: String = KeychainStore.get("mlxApiKey") ?? "" {
        didSet {
            if mlxApiKey.isEmpty {
                KeychainStore.delete("mlxApiKey")
            } else {
                KeychainStore.set("mlxApiKey", mlxApiKey)
            }
            fusionConfigLog.info("mlxApiKey persisted to Keychain (len \(self.mlxApiKey.count))")
        }
    }
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
    // API key 存 Keychain (HIGH-2), SecureField 绑定 $fusionRagApiKey 由 didSet 透传 Keychain
    @Published var fusionRagApiKey: String = KeychainStore.get("fusionRagApiKey") ?? "" {
        didSet {
            if fusionRagApiKey.isEmpty {
                KeychainStore.delete("fusionRagApiKey")
            } else {
                KeychainStore.set("fusionRagApiKey", fusionRagApiKey)
            }
            fusionConfigLog.info("fusionRagApiKey persisted to Keychain (len \(self.fusionRagApiKey.count))")
        }
    }
    @AppStorage("fusionRagEmbed") var fusionRagEmbed = "BGE-M3"

    /// Fusion-RAG 服务地址
    var fusionRagURL: String { "http://\(fusionRagHost):\(fusionRagPort)" }

    /// Fusion-Code API 服务地址
    var fusionCodeURL: String { "http://127.0.0.1:\(fusionCodePort)" }

    /// Fusion-Code 鉴权 API key — per-instance 随机 token (HIGH-2), 首次调用生成并落 Keychain
    // 上游契约 (fusion-code issue #132): token 同步写 ~/.fusion-studio/fusion-code.token (0600),
    // 供 fusion-code 启动读取作 ENVIRONMENT_MANAGER_AUTH_TOKEN。旧硬编码 "fg-admin-key" 已移除
    // (服务端 authToken 空=鉴权 fail-open, 固定串既不校验也无法轮换, 比不鉴权更恶劣)。
    var fusionCodeApiKey: String { KeychainStore.fusionCodeToken() }

    // MARK: - Upstream Services
    // Callers: UpstreamServiceManager reads these to locate each upstream repo's start.sh.
    // Affected API: @AppStorage upstream*Path fields + upstreamAutoStartCritical + expandedUpstreamPath(_:).
    // Data schemas: @AppStorage (UserDefaults) string paths with ~ expansion.
    // User instruction: "在所有依赖的上游模块根目录创建start.sh，在fusion-studio启动时需要检测上游服务是否启动，如果没有启动，尝试调用start.sh启动上游服务，如果启动不成功，fusion-studio要展示服务不存在，或者服务启动失败等等"
    @AppStorage("upstreamAgentStudioPath") var upstreamAgentStudioPath = "~/fusion/fusion-agent-studio"
    @AppStorage("upstreamMlxPath") var upstreamMlxPath = "~/claude-home/fusion-mlx"
    @AppStorage("upstreamArtifactsPath") var upstreamArtifactsPath = "~/fusion/fusion-artifacts-engine"
    // Callers: UpstreamServiceManager (comfyui 造片服务 repoPathRaw + health port). Affected API: start.sh path + healthEndpoint.
    // Data: @AppStorage string path + int port. fix: comfyui (文生图+TTS) 是造片链 Graph C 依赖，此前未纳入上游管理，fusion-studio 启动不会自动拉起。
    @AppStorage("upstreamComfyuiPath") var upstreamComfyuiPath = "~/fusion/fusion-comfyui"
    @AppStorage("comfyuiPort") var comfyuiPort = 11445
    // Callers: UpstreamServiceManager (repoPathRaw for fusion-rag). Affected API: start.sh path resolution.
    // Data: @AppStorage string path. User instruction: "现在还是有四个产品环境检测异常，rag，doc，science，health，请排查问题，并进行修复"
    // fix: RAG 服务实际位于 fusion-rag（非 fusion-kb，后者不存在），端口 11436。
    @AppStorage("upstreamRagPath") var upstreamRagPath = "~/fusion/fusion-rag"
    @AppStorage("upstreamMultiNodePath") var upstreamMultiNodePath = "~/fusion/fusion-multi-node"
    @AppStorage("upstreamFusionCodePath") var upstreamFusionCodePath = "~/fusion/fusion-code"
    @AppStorage("upstreamSciencePath") var upstreamSciencePath = "~/fusion/fusion-science"
    // Callers: SimulationBridge (baseURL), UpstreamServiceManager (health + repoPath).
    // Affected API: @AppStorage simulationHost/simulationPort + simulationBaseURL computed property.
    // Data schemas: @AppStorage (UserDefaults) host/port, port 11455 = fusion-sim FastAPI dashboard (--gui).
    // User instruction: "在左侧菜单增加 fusion simulation,fusion-studio负责GUI，和~/fusion/fuison-simulation项目集成起来"
    @AppStorage("upstreamSimulationPath") var upstreamSimulationPath = "~/fusion/fusion-simulation"
    @AppStorage("upstreamHealthPath") var upstreamHealthPath = "~/fusion/fusion-health"
    // #336: fusion-store L1 存储 (fs-serve 守护端口见 fusionStorePort)。
    @AppStorage("upstreamFusionStorePath") var upstreamFusionStorePath = "~/fusion/fusion-store"
    // #337: fusion-speech 语音守护 (UDS socket + HTTP 端口见 fusionSpeechSocketPath/Port)。
    @AppStorage("upstreamFusionSpeechPath") var upstreamFusionSpeechPath = "~/fusion/fusion-speech"
    @AppStorage("fusionCodePort") var fusionCodePort = 11441
    @AppStorage("upstreamAutoStartCritical") var upstreamAutoStartCritical = true

    // MARK: - Upstream Service Ports
    @AppStorage("coworkHost") var coworkHost = "127.0.0.1"
    @AppStorage("coworkSyncPort") var coworkSyncPort = 11437
    @AppStorage("coworkMcpPort") var coworkMcpPort = 11438
    @AppStorage("modelHubHost") var modelHubHost = "127.0.0.1"
    @AppStorage("modelHubPort") var modelHubPort = 11444
    // API key 存 Keychain (HIGH-2), HubPermissionView 创建后直接赋值由 didSet 透传 Keychain
    @Published var modelHubApiKey: String = KeychainStore.get("modelHubApiKey") ?? "" {
        didSet {
            if modelHubApiKey.isEmpty {
                KeychainStore.delete("modelHubApiKey")
            } else {
                KeychainStore.set("modelHubApiKey", modelHubApiKey)
            }
            fusionConfigLog.info("modelHubApiKey persisted to Keychain (len \(self.modelHubApiKey.count))")
        }
    }
    @AppStorage("securityPort") var securityPort = 11454
    @AppStorage("fusionDeskPort") var fusionDeskPort = 9761
    @AppStorage("fusionDocPort") var fusionDocPort = 11449
    @AppStorage("fusionBenchPort") var fusionBenchPort = 11450
    // #336: fusion-store fs-serve HTTP 守护 (端口 11463, FUSION_STORE_PORT 可覆盖)。
    // storage 层默认嵌入库 (无端口), 此端口仅独立监控模式启用。可选服务。
    @AppStorage("fusionStorePort") var fusionStorePort = 11463
    // #337: fusion-speech 守护 HTTP 端口 (/health, /metrics, /stream/stt WebSocket)。
    @AppStorage("fusionSpeechPort") var fusionSpeechPort = 11465
    // #337: fusion-speech UDS JSON-RPC socket 路径 (FUSION_SOCKET_DIR 可覆盖父目录)。
    @AppStorage("fusionSpeechSocketPath") var fusionSpeechSocketPath = "~/.fusion-speech/run/fusion-speech.sock"
    // #344: fusion-guard 零信任鉴权守护 UDS (UDS-only, 无 HTTP 端口; /tmp 默认, FUSION_GUARD_SOCK 可覆盖)。
    @AppStorage("fusionGuardSocketPath") var fusionGuardSocketPath = "/tmp/fusion-guard.sock"
    // #346: fusion-event 感知层守护 UDS (NDJSON JSON-RPC, /tmp 默认, FUSION_EVENT_SOCK 可覆盖)。
    @AppStorage("fusionEventSocketPath") var fusionEventSocketPath = "/tmp/fusion-event.sock"
    @AppStorage("agentStudioHttpPort") var agentStudioHttpPort = 11453
    @AppStorage("multiNodePort") var multiNodePort = 11452
    // Multi-Node Agent 端口（NodeAgent /api/* 数据端口）。原 11445 与 fusion-comfyui 实跑撞,
    // 2026-08-24 上游迁出至 11458 (fusion-multi-nodes#22/#25, port-registry.yaml)。旧用户 @AppStorage
    // 仍可能是 11445 → init migrateStalePorts 首启迁移。
    @AppStorage("multiNodeAgentPort") var multiNodeAgentPort = 11458
    // 可选：手动覆盖 cluster token（留空则读取 ~/.fusion/multi-node/.cluster_token）。
    @AppStorage("multiNodeClusterToken") var multiNodeClusterToken = ""

    /// Multi-Node Master 服务地址（FastAPI MasterServer，需 Bearer token）。
    var multiNodeBaseURL: String { "http://\(modelHubHost):\(multiNodePort)" }
    /// Multi-Node Agent 服务地址（FastAPI AgentServer，需 Bearer token）。
    // F-A8: 旧硬编码 127.0.0.1, 远程集群场景下 7 Agent KV 方法 (fetchAgentKVStats/agentKVLookup/
    // agentKVTransfer/agentKVWarm 等) 全打本地而非远程节点。改用 modelHubHost — 本地单节点
    // modelHubHost 默认 127.0.0.1 行为不变, 远程集群走远程 host。端口与 comfyui 冲突属上游问题。
    var multiNodeAgentBaseURL: String { "http://\(modelHubHost):\(multiNodeAgentPort)" }

    /// 读取 cluster token：优先手动覆盖，否则读 ~/.fusion/multi-node/.cluster_token（0600）。
    var multiNodeResolvedToken: String {
        if !multiNodeClusterToken.isEmpty { return multiNodeClusterToken }
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".fusion/multi-node/.cluster_token")
        return (try? String(contentsOfFile: path, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // Callers: UpstreamServiceManager (health endpoint), ScienceBridge. Affected API: scienceBaseURL.
    // Data: @AppStorage host/port. fix: fusion-science start.sh 默认端口 11462（非 8200），对齐上游。
    @AppStorage("scienceHost") var scienceHost = "127.0.0.1"
    @AppStorage("sciencePort") var sciencePort = 11462

    /// Fusion-Science 服务地址
    var scienceBaseURL: String { "http://\(scienceHost):\(sciencePort)" }

    // Callers: SimulationBridge, UpstreamServiceManager. Port 11455 = fusion-sim dashboard (--gui).
    @AppStorage("simulationHost") var simulationHost = "127.0.0.1"
    @AppStorage("simulationPort") var simulationPort = 11455

    /// Fusion-Simulation 服务地址（FastAPI 控制面，需 fusion-sim service start --gui）
    var simulationBaseURL: String { "http://\(simulationHost):\(simulationPort)" }

    @AppStorage("healthHost") var healthHost = "127.0.0.1"
    @AppStorage("healthPort") var healthPort = 11456

    var healthBaseURL: String { "http://\(healthHost):\(healthPort)" }

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
    /// 优先级（#380）: mlxEndpointOverrideEnabled (用户显式 pin mlxHost:mlxPort)
    ///         > FUSION_GATEWAY_URL / FUSION_MLX_URL（完整 URL，走 gateway 11432）
    ///         > FUSION_MLX_PORT（仅覆盖端口）> 默认 mlxHost:mlxPort（直连 11434）
    var mlxBaseURL: String {
        let host = mlxHost
        let port = mlxPort
        if mlxEndpointOverrideEnabled {
            fusionConfigLog.error("mlxBaseURL: source=user-override (mlxHost:mlxPort) -> \(host):\(port) (env ignored)")
            return "http://\(host):\(port)"
        }
        let env = ProcessInfo.processInfo.environment
        if let full = env["FUSION_GATEWAY_URL"] ?? env["FUSION_MLX_URL"], !full.isEmpty {
            fusionConfigLog.error("mlxBaseURL: source=FUSION_GATEWAY_URL/MLX_URL env -> \(full)")
            return full
        }
        if let portStr = env["FUSION_MLX_PORT"], let envPort = Int(portStr), envPort > 0 {
            fusionConfigLog.error("mlxBaseURL: source=FUSION_MLX_PORT env -> \(host):\(envPort)")
            return "http://\(host):\(envPort)"
        }
        return "http://\(host):\(port)"
    }

    /// MLX API Key — 解析优先级与上游 fusion-mlx _resolve_api_key 对齐：
    /// 1) 用户在 Settings 显式设置 (mlxApiKey @AppStorage)
    /// 2) 进程环境变量 FUSION_MLX_API_KEY（fusion-mlx/fusion-gateway 启动时注入）
    /// 3) ~/.fusion-mlx/settings.json -> auth.api_key
    var mlxResolvedApiKey: String {
        if !mlxApiKey.isEmpty {
            fusionConfigLog.error("mlxResolvedApiKey: source=user-settings")
            return mlxApiKey
        }
        if let envKey = ProcessInfo.processInfo.environment["FUSION_MLX_API_KEY"], !envKey.isEmpty {
            fusionConfigLog.error("mlxResolvedApiKey: source=FUSION_MLX_API_KEY env")
            return envKey
        }
        if let data = try? Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory() + "/.fusion-mlx/settings.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let auth = json["auth"] as? [String: Any],
           let key = auth["api_key"] as? String, !key.isEmpty {
            fusionConfigLog.error("mlxResolvedApiKey: source=settings.json")
            return key
        }
        fusionConfigLog.error("mlxResolvedApiKey: no key resolved (env/settings both empty)")
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
        mlxPort = 11434
        mlxEndpointOverrideEnabled = false
        mlxModel = ""
        mlxModelSmall = ""
        mlxModelCode = ""
        mlxModelHeavy = ""
        defaultSlotChat = ModelSlot.small.rawValue
        defaultSlotCode = ModelSlot.code.rawValue
        defaultSlotAgent = ModelSlot.heavy.rawValue
        defaultSlotArtifacts = ModelSlot.heavy.rawValue
        mlxPath = ""
        // 清 Keychain 内的 API key (HIGH-2): didSet 透传 delete
        mlxApiKey = ""

        artifactsEngineHost = "127.0.0.1"
        artifactsEnginePort = 11451

        fusionRagHost = "127.0.0.1"
        fusionRagPort = 11436
        fusionRagApiKey = ""

        upstreamAgentStudioPath = "~/fusion/fusion-agent-studio"
        upstreamMlxPath = "~/claude-home/fusion-mlx"
        upstreamArtifactsPath = "~/fusion/fusion-artifacts-engine"
        upstreamComfyuiPath = "~/fusion/fusion-comfyui"
        comfyuiPort = 11445
        upstreamRagPath = "~/fusion/fusion-rag"
        upstreamMultiNodePath = "~/fusion/fusion-multi-node"
        upstreamFusionCodePath = "~/fusion/fusion-code"
        upstreamSciencePath = "~/fusion/fusion-science"
        upstreamSimulationPath = "~/fusion/fusion-simulation"
        upstreamHealthPath = "~/fusion/fusion-health"
        upstreamFusionStorePath = "~/fusion/fusion-store"
        upstreamFusionSpeechPath = "~/fusion/fusion-speech"
        fusionCodePort = 11441
        upstreamAutoStartCritical = true

        coworkHost = "127.0.0.1"
        coworkSyncPort = 11437
        coworkMcpPort = 11438
        modelHubHost = "127.0.0.1"
        modelHubPort = 11444
        modelHubApiKey = ""
        securityPort = 11454
        fusionDeskPort = 9761
        fusionDocPort = 11449
        fusionBenchPort = 11450
        agentStudioHttpPort = 11453
        scienceHost = "127.0.0.1"
        sciencePort = 11462
        simulationHost = "127.0.0.1"
        simulationPort = 11455
        healthHost = "127.0.0.1"
        healthPort = 11456
        // F-I9 追加: reset 补 multiNode 端口 (此前 resetToDefaults 漏设, 走 @AppStorage 默认值不一致)
        multiNodePort = 11452
        multiNodeAgentPort = 11458
    }
}
