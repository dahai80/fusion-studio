// ARCH-1: Style Operations 从 AgentBridge God-object 抽出, facade extension。
// 3 方法 (fetchStyles/styleCreate/styleDelete), 0 private 静态依赖, 0 持久状态, 0 跨域实例调用。最薄叶 silo。
// styleCreate/styleDelete 调 await fetchStyles() (本文件同域, extension 内可达)。
// @Published styles (L2050) 留主类 (extension 不可声明存储, 有外部 SwiftUI 读 AgentConfigTabs/AgentConfigViews)。
//   extension 写 self.configState.styles, 观察链不变。
// ipcClient 仍存 AgentBridge, extension 读 self.ipcClient。logger private → 文件级 agentStyleLog。

import Foundation
import os.log

private let agentStyleLog = Logger(subsystem: "com.fusion.studio", category: "AgentStyleService")

extension AgentBridge {

    // MARK: - Style Operations

    func fetchStyles() async {
        if let t = stylesFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        stylesFetchedAt = Date()
        guard let client = ipcClient else { return }
        do {
            let result = try await client.styleList()
            self.configState.styles = result["styles"] as? [[String: Any]] ?? []
            agentStyleLog.info("Fetched \(self.configState.styles.count) styles")
        } catch {
            agentStyleLog.debug("fetchStyles failed: \(error.localizedDescription)")
        }
    }

    func styleCreate(name: String, template: String, rules: [String: Any] = [:]) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.styleCreate(name: name, template: template, rules: rules)
        stylesFetchedAt = nil
        await fetchStyles()
        return result
    }

    func styleDelete(styleId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.styleDelete(styleId: styleId)
        stylesFetchedAt = nil
        await fetchStyles()
        return result
    }
}
