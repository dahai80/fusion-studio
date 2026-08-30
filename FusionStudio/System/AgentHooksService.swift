// ARCH-1 PR3 (#359 facade-delegate): Hooks Operations 从 AgentBridge God-object 迁入 ConfigState 域。
//   本文件含 2 extension:
//     1) extension ConfigState — 3 真实方法体 (fetchHooks/hooksRegister/hooksTest, 自持 ipcClient + hooksFetchedAt TTL)。
//     2) extension AgentBridge — 3 个 1 行 facade stub 委托到 configState.X(), 保外部 call site 签名零变。
//   0 private 静态依赖, 0 持久状态, 0 跨域实例调用。最薄叶 silo。
//   @Published hooks 在 ConfigState 域 (外部 SwiftUI 读 AgentConfigTabs), 经 bridge.configState.hooks 不变。

import Foundation
import os.log

private let agentHooksLog = Logger(subsystem: "com.fusion.studio", category: "AgentHooksService")

// MARK: - Hooks Operations (行为落地 ConfigState 域)
extension ConfigState {

    func fetchHooks() async {
        if let t = self.hooksFetchedAt, Date().timeIntervalSince(t) < 30 { return }
        self.hooksFetchedAt = Date()
        guard let client = self.ipcClient else { return }
        do {
            let result = try await client.hooksList()
            self.hooks = ConfigState.capConfigArray(result["hooks"] as? [[String: Any]] ?? [])
            agentHooksLog.info("Fetched \(self.hooks.count) hooks")
        } catch {
            agentHooksLog.debug("fetchHooks failed: \(error.localizedDescription)")
        }
    }

    func hooksRegister(event: String, agentId: String, action: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        let result = try await client.hooksRegister(event: event, agentId: agentId, action: action)
        self.hooksFetchedAt = nil
        await fetchHooks()
        return result
    }

    func hooksTest(hookId: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        return try await client.hooksTest(hookId: hookId)
    }
}

// MARK: - Hooks Operations (facade-delegate stubs — 行为已迁 ConfigState 域)
extension AgentBridge {

    func fetchHooks() async {
        await configState.fetchHooks()
    }

    func hooksRegister(event: String, agentId: String, action: String) async throws -> [String: Any] {
        try await configState.hooksRegister(event: event, agentId: agentId, action: action)
    }

    func hooksTest(hookId: String) async throws -> [String: Any] {
        try await configState.hooksTest(hookId: hookId)
    }
}
