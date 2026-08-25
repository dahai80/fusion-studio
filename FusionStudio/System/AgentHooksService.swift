// ARCH-1: Hooks Operations 从 AgentBridge God-object 抽出, facade extension。
// 3 方法 (fetchHooks/hooksRegister/hooksTest), 0 private 静态依赖, 0 持久状态, 0 跨域实例调用。最薄叶 silo。
// @Published hooks (L2111, 声明在 Team MARK block, 历史摆放) 留主类 (extension 不可声明存储, 有外部 SwiftUI 读 AgentConfigTabs)。
//   extension 写 self.hooks, 观察链不变。
// ipcClient 仍存 AgentBridge, extension 读 self.ipcClient。logger private → 文件级 agentHooksLog。

import os.log

private let agentHooksLog = Logger(subsystem: "com.fusion.studio", category: "AgentHooksService")

extension AgentBridge {

    // MARK: - Hooks Operations

    func fetchHooks() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.hooksList()
            self.hooks = result["hooks"] as? [[String: Any]] ?? []
            agentHooksLog.info("Fetched \(self.hooks.count) hooks")
        } catch {
            agentHooksLog.debug("fetchHooks failed: \(error.localizedDescription)")
        }
    }

    func hooksRegister(event: String, agentId: String, action: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        let result = try await client.hooksRegister(event: event, agentId: agentId, action: action)
        await fetchHooks()
        return result
    }

    func hooksTest(hookId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        return try await client.hooksTest(hookId: hookId)
    }
}
