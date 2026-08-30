// ARCH-1 PR4 (#359 facade-delegate): Safety Operations 从 AgentBridge God-object 迁入 ModuleState 域。
//   本文件含 2 extension:
//     1) extension ModuleState — 6 真实方法体 (safetyCheck/safetyEvaluateAction/safetyApproveAction/safetyRejectAction/fetchPendingSafetyActions/safetyAddPolicy, 自持 ipcClient)。
//     2) extension AgentBridge — 6 个 1 行 facade stub 委托到 moduleState.X(), 保外部 call site 签名零变。
//   0 private 静态依赖, 0 跨域实例调用。叶 silo (域内 SafetyCheckModel/SafetyActionModel 构造, 无 parser, 无持久状态)。
//   safetyEvaluateAction/fetchPendingSafetyActions 用 UUID().uuidString → import Foundation。
//   @Published safetyCheckResult/safetyPendingActions 在 ModuleState 域 (外部 SwiftUI 读 AgentConfigTabs/SafetyView), 经 bridge.moduleState.X 不变。
//   ipcClient 为 internal (非 private): 跨文件 extension 访问, Swift private=文件作用域 (同 PR1/PR2/PR3 坑)。

import Foundation
import os.log

private let agentSafetyLog = Logger(subsystem: "com.fusion.studio", category: "AgentSafetyService")

// MARK: - Safety Operations (行为落地 ModuleState 域)
extension ModuleState {

    func safetyCheck(content: String, context: String = "") async throws -> SafetyCheckModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentSafetyLog.info("safetyCheck")
        do {
            let result = try await client.safetyCheck(content: content, context: context)
            // F-I4: 手动 dict["x"] as? Type → decodeCodable 强类型解码 (init(from:) 保 ?? default 宽容)。
            guard let check = AgentBridge.decodeCodable(SafetyCheckModel.self, from: result, context: "safetyCheck") else {
                agentSafetyLog.error("safetyCheck decode failed, keys=\(result.keys.sorted())")
                throw BridgeError.ipcError("safetyCheck parse failed")
            }
            self.safetyCheckResult = check
            return check
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func safetyEvaluateAction(category: String, content: String = "", context: String = "") async throws -> SafetyActionModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyEvaluateAction(category: category, content: content, context: context)
            // F-I4: site A — id/status/reason 从 dict 解码, category/content 调用方注入 (非 dict 字段) 解码后覆盖。
            guard var action = AgentBridge.decodeCodable(SafetyActionModel.self, from: result, context: "safetyEvaluateAction") else {
                agentSafetyLog.error("safetyEvaluateAction decode failed, keys=\(result.keys.sorted())")
                throw BridgeError.ipcError("safetyEvaluateAction parse failed")
            }
            action.category = category
            action.content = content
            return action
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func safetyApproveAction(actionId: String) async throws -> Bool {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyApproveAction(actionId: actionId)
            return result["approved"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func safetyRejectAction(actionId: String) async throws -> Bool {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyRejectAction(actionId: actionId)
            return result["rejected"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchPendingSafetyActions() async throws -> [SafetyActionModel] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyGetPendingActions()
            let actionsData = result["actions"] as? [[String: Any]] ?? []
            // F-I4: site B — 列表项 dict 双键 action_id/id 由 init(from:) 解码, ?? default 宽容。
            var parsed: [SafetyActionModel] = []
            for a in actionsData {
                guard let action = AgentBridge.decodeCodable(SafetyActionModel.self, from: a, context: "safetyPendingAction") else {
                    agentSafetyLog.warning("fetchPendingSafetyActions: skip undecodable item, keys=\(a.keys.sorted())")
                    continue
                }
                parsed.append(action)
            }
            self.safetyPendingActions = parsed
            agentSafetyLog.info("fetchPendingSafetyActions: \(parsed.count) pending")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func safetyAddPolicy(category: String, description: String = "", defaultLevel: String = "L2", requiresDiff: Bool = false) async throws -> Bool {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyAddPolicy(category: category, description: description, defaultLevel: defaultLevel, requiresDiff: requiresDiff)
            return result["added"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }
}

// MARK: - Safety Operations (facade-delegate stubs — 行为已迁 ModuleState 域)
// ARCH-1 PR4: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func safetyCheck(content: String, context: String = "") async throws -> SafetyCheckModel {
        try await moduleState.safetyCheck(content: content, context: context)
    }

    func safetyEvaluateAction(category: String, content: String = "", context: String = "") async throws -> SafetyActionModel {
        try await moduleState.safetyEvaluateAction(category: category, content: content, context: context)
    }

    func safetyApproveAction(actionId: String) async throws -> Bool {
        try await moduleState.safetyApproveAction(actionId: actionId)
    }

    func safetyRejectAction(actionId: String) async throws -> Bool {
        try await moduleState.safetyRejectAction(actionId: actionId)
    }

    func fetchPendingSafetyActions() async throws -> [SafetyActionModel] {
        try await moduleState.fetchPendingSafetyActions()
    }

    func safetyAddPolicy(category: String, description: String = "", defaultLevel: String = "L2", requiresDiff: Bool = false) async throws -> Bool {
        try await moduleState.safetyAddPolicy(category: category, description: description, defaultLevel: defaultLevel, requiresDiff: requiresDiff)
    }
}
