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
    @AppStorage("mlxPort") var mlxPort = 8000
    @AppStorage("mlxModel") var mlxModel = ""
    @AppStorage("mlxPath") var mlxPath = ""

    // MARK: - 便捷方法

    /// 是否处于离线模式
    var isOffline: Bool { offlineMode }

    /// MLX 服务地址
    var mlxBaseURL: String { "http://\(mlxHost):\(mlxPort)" }

    /// 展开的工作区路径
    var expandedWorkspacePath: String {
        (workspacePath as NSString).expandingTildeInPath
    }

    /// 展开的 MLX 路径
    var expandedMLXPath: String {
        if mlxPath.isEmpty {
            return NSHomeDirectory() + "/claude-home/fusion-mlx"
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
        mlxPort = 8000
        mlxModel = ""
        mlxPath = ""
    }
}