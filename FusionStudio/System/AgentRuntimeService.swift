// ARCH-1 PR2 (#359 facade-delegate): Runtime Operations 从 AgentBridge God-object 迁入 RuntimeState 域。
//   本文件含 2 extension:
//     1) extension RuntimeState — 3 真实方法体 (健康检查 + 执行取消, 自持 ipcClient ref)。
//     2) extension AgentBridge — 3 个 1 行 facade stub 委托到 runtimeState.X(), 保外部 call site 签名零变。
//   SwiftUI 仅观察 AgentBridge (82 @EnvironmentObject), 0 直接域观察 → 0 view 改动。永久中间人 stub。
//   isConnected/isExecuting/events @Published 仍在 RuntimeState 域, 外部读经 bridge.runtimeState.X (let 稳定身份), 观察链不变。
// 耦合未迁: executeGraph/taskExecuteImmediate 留 AgentBridge (跨域协调器 + guard + Self.parseEventModel + 写共享 events)。
//   setIPCClient Combine sink (写 runtimeState.isConnected) 留主类, RuntimeState 仅获 ipcClient ref。

import Foundation
import os.log

private let agentRuntimeLog = Logger(subsystem: "com.fusion.studio", category: "AgentRuntimeService")

// MARK: - Runtime Operations (行为落地 RuntimeState 域)
extension RuntimeState {

    // MARK: - Health Check

    func checkHealth() async throws -> Bool {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        do {
            let result = try await client.call(method: RPCMethod.ping)
            let pong = result["pong"] as? Bool ?? false
            self.isConnected = pong
            agentRuntimeLog.info("checkHealth: connected=\(pong)")
            return pong
        } catch let error as IPCError {
            self.isConnected = false
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            agentRuntimeLog.error("checkHealth: \(error)")
            throw bridgeErr
        }
    }

    func fullHealthCheck() async throws -> [String: Any] {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        let result: [String: Any]
        do {
            result = try await withThrowingTaskGroup(of: [String: Any].self) { group in
                group.addTask {
                    try await client.call(method: RPCMethod.envHealthCheck)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 8_000_000_000)
                    throw BridgeError.timeout
                }
                guard let value = try await group.next() else {
                    throw BridgeError.timeout
                }
                group.cancelAll()
                return value
            }
        } catch BridgeError.timeout {
            self.isConnected = false
            agentRuntimeLog.error("fullHealthCheck: timeout after 8s (env.health_check did not respond)")
            throw BridgeError.timeout
        }
        self.isConnected = true
        return result
    }

    func cancelExecution() {
        agentRuntimeLog.info("cancelExecution")
        self.isExecuting = false
    }
}

// MARK: - Runtime Operations (facade-delegate stubs — 行为已迁 RuntimeState 域)
// ARCH-1 PR2: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func checkHealth() async throws -> Bool {
        try await runtimeState.checkHealth()
    }

    func fullHealthCheck() async throws -> [String: Any] {
        try await runtimeState.fullHealthCheck()
    }

    func cancelExecution() {
        runtimeState.cancelExecution()
    }
}
