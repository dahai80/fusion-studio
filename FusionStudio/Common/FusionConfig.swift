import Foundation
import SwiftUI

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
    @AppStorage("mlxPort") var mlxPort = 11434
    @AppStorage("mlxApiKey") var mlxApiKey = ""
    @AppStorage("mlxModel") var mlxModel = ""
    @AppStorage("mlxPath") var mlxPath = ""

    // User instruction: "所有的项目要有一个配置文件，配置类的卸载配置文件里面，不能写死在代码里面"
    // Importers/callers: IPCClient.swift reads FusionConfig.shared.artifactsEngineURL; ArtifactsPanel reads via IPCClient
    // Affected API: new @AppStorage fields artifactsEngineHost/artifactsEnginePort, computed property artifactsEngineURL
    // Data schemas: @AppStorage (UserDefaults) persistence for host/port

    // MARK: - Artifacts Engine
    @AppStorage("artifactsEngineHost") var artifactsEngineHost = "127.0.0.1"
    @AppStorage("artifactsEnginePort") var artifactsEnginePort = 8892

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

    // MARK: - 便捷方法

    /// 是否处于离线模式
    var isOffline: Bool { offlineMode }

    /// MLX 服务地址
    var mlxBaseURL: String { "http://\(mlxHost):\(mlxPort)" }

    /// MLX API Key (from ~/.fusion-mlx/settings.json)
    var mlxResolvedApiKey: String {
        if !mlxApiKey.isEmpty { return mlxApiKey }
        if let data = try? Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory() + "/.fusion-mlx/settings.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let auth = json["auth"] as? [String: Any],
           let key = auth["api_key"] as? String {
            return key
        }
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
        mlxModel = ""
        mlxPath = ""

        artifactsEngineHost = "127.0.0.1"
        artifactsEnginePort = 8892

        fusionRagHost = "127.0.0.1"
        fusionRagPort = 11436
        fusionRagApiKey = ""
    }
}
