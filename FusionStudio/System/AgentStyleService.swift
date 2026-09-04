// ARCH-1 PR3 (#359 facade-delegate): Style Operations 从 AgentBridge God-object 迁入 ConfigState 域。
//   本文件含 2 extension:
//     1) extension ConfigState — 3 真实方法体 (fetchStyles/styleCreate/styleDelete, 自持 ipcClient + stylesFetchedAt TTL)。
//     2) extension AgentBridge — 3 个 1 行 facade stub 委托到 configState.X(), 保外部 call site 签名零变。
//   0 private 静态依赖, 0 持久状态, 0 跨域实例调用。最薄叶 silo。styleCreate/Delete 调 fetchStyles (同域 extension 内可达)。
//   @Published styles 在 ConfigState 域 (外部 SwiftUI 读 AgentConfigTabs/AgentConfigViews), 经 bridge.configState.styles 不变。

import Foundation
import os.log

private let agentStyleLog = Logger(subsystem: "com.fusion.studio", category: "AgentStyleService")

// MARK: - Style Operations (行为落地 ConfigState 域)
extension ConfigState {

    func fetchStyles() async {
        if let t = self.stylesFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        self.stylesFetchedAt = Date()
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.styleList()
            self.styles = ConfigState.capConfigArray(result["styles"] as? [[String: Any]] ?? [])
            agentStyleLog.info("Fetched \(self.styles.count) styles")
        } catch {
            agentStyleLog.debug("fetchStyles failed: \(error.localizedDescription)")
        }
    }

    func styleCreate(name: String, template: String, rules: [String: Any] = [:]) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        let result = try await client.styleCreate(name: name, template: template, rules: rules)
        self.stylesFetchedAt = nil
        await fetchStyles()
        return result
    }

    func styleDelete(styleId: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        let result: [String: Any]
        do {
            result = try await client.styleDelete(styleId: styleId)
        } catch {
            // 审计product-0905 FUNC-9: 上游 style.delete 未实现 (-32601, 后端仅 apply/create/get/list) → 友好降级, 不裸泄 "Method not found"。
            if RPCMethodAvailability.shared.handleRPCError(error, method: RPCMethod.styleDelete) {
                throw BridgeError.featureUnavailable(RPCMethod.styleDelete)
            }
            throw error
        }
        self.stylesFetchedAt = nil
        await fetchStyles()
        return result
    }
}

// MARK: - Style Operations (facade-delegate stubs — 行为已迁 ConfigState 域)
extension AgentBridge {

    func fetchStyles() async {
        await configState.fetchStyles()
    }

    func styleCreate(name: String, template: String, rules: [String: Any] = [:]) async throws -> [String: Any] {
        try await configState.styleCreate(name: name, template: template, rules: rules)
    }

    func styleDelete(styleId: String) async throws -> [String: Any] {
        try await configState.styleDelete(styleId: styleId)
    }
}
