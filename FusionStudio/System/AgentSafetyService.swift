// ARCH-1: Safety Operations 从 AgentBridge God-object 抽出, facade extension。
// 6 方法 (safetyCheck/safetyEvaluateAction/safetyApproveAction/safetyRejectAction/fetchPendingSafetyActions/safetyAddPolicy),
//   0 private 静态依赖, 0 跨域实例调用。叶 silo (域内 SafetyCheckModel/SafetyActionModel 构造, 无 parser, 无持久状态)。
// safetyEvaluateAction/fetchPendingSafetyActions 用 UUID().uuidString → import Foundation。
// @Published safetyCheckResult(L336)/safetyPendingActions(L337) 留主类 (extension 不可声明存储, 有外部 SwiftUI 读 AgentConfigTabs/SafetyView)。
//   extension 写 self.prop, 观察链不变。
// ipcClient 仍存 AgentBridge, extension 读 self.ipcClient。logger private → 文件级 agentSafetyLog。

import Foundation
import os.log

private let agentSafetyLog = Logger(subsystem: "com.fusion.studio", category: "AgentSafetyService")

extension AgentBridge {

    // MARK: - Safety Operations

    func safetyCheck(content: String, context: String = "") async throws -> SafetyCheckModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentSafetyLog.info("safetyCheck")
        do {
            let result = try await client.safetyCheck(content: content, context: context)
            let check = SafetyCheckModel(
                level: result["level"] as? String ?? "L1",
                violations: result["violations"] as? [String] ?? [],
                approved: result["approved"] as? Bool ?? true
            )
            self.moduleState.safetyCheckResult = check
            return check
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func safetyEvaluateAction(category: String, content: String = "", context: String = "") async throws -> SafetyActionModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyEvaluateAction(category: category, content: content, context: context)
            return SafetyActionModel(
                id: result["action_id"] as? String ?? UUID().uuidString,
                category: category,
                status: result["status"] as? String ?? "pending",
                content: content
            )
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func safetyApproveAction(actionId: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyApproveAction(actionId: actionId)
            return result["approved"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func safetyRejectAction(actionId: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyRejectAction(actionId: actionId)
            return result["rejected"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchPendingSafetyActions() async throws -> [SafetyActionModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyGetPendingActions()
            let actionsData = result["actions"] as? [[String: Any]] ?? []
            var parsed: [SafetyActionModel] = []
            for a in actionsData {
                parsed.append(SafetyActionModel(
                    id: a["action_id"] as? String ?? a["id"] as? String ?? UUID().uuidString,
                    category: a["category"] as? String ?? "",
                    status: a["status"] as? String ?? "pending",
                    content: a["content"] as? String ?? ""
                ))
            }
            self.moduleState.safetyPendingActions = parsed
            agentSafetyLog.info("fetchPendingSafetyActions: \(parsed.count) pending")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func safetyAddPolicy(category: String, description: String = "", defaultLevel: String = "L2", requiresDiff: Bool = false) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.safetyAddPolicy(category: category, description: description, defaultLevel: defaultLevel, requiresDiff: requiresDiff)
            return result["added"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }
}
