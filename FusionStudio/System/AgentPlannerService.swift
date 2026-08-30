// ARCH-1 PR4 (#359 facade-delegate): Planner Operations 从 AgentBridge God-object 迁入 ModuleState 域。
//   本文件含 2 extension:
//     1) extension ModuleState — 8 真实方法体 (plannerCreatePlan/Get/Approve/Reject/ExecuteStep/ExecutePlan/fetchPlans/cancelPlan, 自持 ipcClient)。
//     2) extension AgentBridge — 8 个 1 行 facade stub 委托到 moduleState.X(), 保外部 call site 签名零变。
//   parsePlanModel (private static, 8 调用方全本域) 随域同迁 — private = 文件作用域, 同文件 extension Self.parsePlanModel 可达。
//   parsePlanModel 调 AgentBridge.decodeCodable (nonisolated static, 非 AgentBridge @MainActor 类型亦可达)。Self=ModuleState 后仍可达。
//   @Published currentPlan/plans 在 ModuleState 域 (外部 SwiftUI 读), 经 bridge.moduleState.X 不变。
//   ipcClient 为 internal (非 private): 跨文件 extension 访问, Swift private=文件作用域 (同 PR1/PR2/PR3 坑)。

import Foundation
import os.log

private let agentPlannerLog = Logger(subsystem: "com.fusion.studio", category: "AgentPlannerService")

// MARK: - Planner Operations (行为落地 ModuleState 域)
extension ModuleState {

    func plannerCreatePlan(task: String, context: String = "", files: [String]? = nil) async throws -> PlanModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentPlannerLog.info("plannerCreatePlan: task=\(task)")
        do {
            let result = try await client.plannerCreatePlan(task: task, context: context, files: files)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.create_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerGetPlan(planId: String) async throws -> PlanModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerGetPlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.get_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerApprovePlan(planId: String) async throws -> PlanModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerApprovePlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.approve_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerRejectPlan(planId: String, reason: String = "") async throws -> PlanModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerRejectPlan(planId: planId, reason: reason)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.reject_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerExecuteStep(planId: String, stepId: String) async throws -> PlanModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerExecuteStep(planId: planId, stepId: stepId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.execute_step response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerExecutePlan(planId: String) async throws -> PlanModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerExecutePlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.execute_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchPlans(status: String = "") async throws -> [PlanModel] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerListPlans(status: status)
            let plansData = result["plans"] as? [[String: Any]] ?? []
            var parsed: [PlanModel] = []
            for p in plansData {
                if let plan = Self.parsePlanModel(from: p) {
                    parsed.append(plan)
                }
            }
            self.plans = parsed
            agentPlannerLog.info("fetchPlans: received \(parsed.count) plans")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerCancelPlan(planId: String) async throws -> PlanModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerCancelPlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.cancel_plan response")
            }
            self.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    // MARK: - Planner Parsing

    private static func parsePlanModel(from dict: [String: Any]) -> PlanModel? {
        // F-I4: Codable 强类型解码 (PlanModel.init(from:) 保 plan_id/id dual-key; PlanStepModel.init(from:) 保 step_id/id)。
        // 保留原 guard 语义: id 或 task 缺失 → 返 nil (caller throw "Failed to parse")。
        // Self=ModuleState; decodeCodable 是 AgentBridge nonisolated static, 显式 AgentBridge.decodeCodable 限定可达。
        guard let plan = AgentBridge.decodeCodable(PlanModel.self, from: dict, context: "plan") else {
            return nil
        }
        if plan.id.isEmpty || plan.task.isEmpty {
            agentPlannerLog.warning("parsePlanModel: id or task empty after decode, dropping — id=\(plan.id, privacy: .public)")
            return nil
        }
        return plan
    }
}

// MARK: - Planner Operations (facade-delegate stubs — 行为已迁 ModuleState 域)
// ARCH-1 PR4: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func plannerCreatePlan(task: String, context: String = "", files: [String]? = nil) async throws -> PlanModel {
        try await moduleState.plannerCreatePlan(task: task, context: context, files: files)
    }

    func plannerGetPlan(planId: String) async throws -> PlanModel {
        try await moduleState.plannerGetPlan(planId: planId)
    }

    func plannerApprovePlan(planId: String) async throws -> PlanModel {
        try await moduleState.plannerApprovePlan(planId: planId)
    }

    func plannerRejectPlan(planId: String, reason: String = "") async throws -> PlanModel {
        try await moduleState.plannerRejectPlan(planId: planId, reason: reason)
    }

    func plannerExecuteStep(planId: String, stepId: String) async throws -> PlanModel {
        try await moduleState.plannerExecuteStep(planId: planId, stepId: stepId)
    }

    func plannerExecutePlan(planId: String) async throws -> PlanModel {
        try await moduleState.plannerExecutePlan(planId: planId)
    }

    func fetchPlans(status: String = "") async throws -> [PlanModel] {
        try await moduleState.fetchPlans(status: status)
    }

    func plannerCancelPlan(planId: String) async throws -> PlanModel {
        try await moduleState.plannerCancelPlan(planId: planId)
    }
}
