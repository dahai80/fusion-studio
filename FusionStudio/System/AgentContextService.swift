// ARCH-1: Context Operations 从 AgentBridge God-object 抽出, facade extension。
// 2 薄 IPC 透传方法, 0 @Published, 0 private 静态依赖, 0 跨域实例调用。本域最简单。
// ipcClient 仍存 AgentBridge (extension 不可声明存储), extension 读 self.ipcClient。

import os.log

private let agentContextLog = Logger(subsystem: "com.fusion.studio", category: "AgentContextService")

extension AgentBridge {

    // MARK: - Context Operations

    func contextCompact(sessionId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentContextLog.info("contextCompact: sessionId=\(sessionId)")
        return try await client.contextCompact(sessionId: sessionId)
    }

    func contextUsage(sessionId: String) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentContextLog.info("contextUsage: sessionId=\(sessionId)")
        return try await client.contextUsage(sessionId: sessionId)
    }
}
