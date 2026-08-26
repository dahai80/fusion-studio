// ARCH-1 / F-A1: Planner Operations 从 AgentBridge God-object 抽出, facade extension。
// @Published currentPlan/plans 仍存 AgentBridge (extension 不可声明存储属性), 本文件只搬方法体, 行为零变。
// parsePlanModel (private static, 8 调用方全本域) 随域同迁 — private = 文件作用域,
//   同文件 extension Self.parsePlanModel 可达, 同 #287 parseMarketplaceEntry / Graph parseGraphModel 范式。
// Logger: 主类 private logger file-scoped 不可跨文件, 本文件自有 agentPlannerLog 替代 (2 logger. 处)。

import Foundation
import os.log

private let agentPlannerLog = Logger(subsystem: "com.fusion.studio", category: "AgentPlannerService")

extension AgentBridge {

    // MARK: - Planner Operations

    func plannerCreatePlan(task: String, context: String = "", files: [String]? = nil) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentPlannerLog.info("plannerCreatePlan: task=\(task)")
        do {
            let result = try await client.plannerCreatePlan(task: task, context: context, files: files)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.create_plan response")
            }
            self.moduleState.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerGetPlan(planId: String) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerGetPlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.get_plan response")
            }
            self.moduleState.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerApprovePlan(planId: String) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerApprovePlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.approve_plan response")
            }
            self.moduleState.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerRejectPlan(planId: String, reason: String = "") async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerRejectPlan(planId: planId, reason: reason)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.reject_plan response")
            }
            self.moduleState.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerExecuteStep(planId: String, stepId: String) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerExecuteStep(planId: planId, stepId: stepId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.execute_step response")
            }
            self.moduleState.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerExecutePlan(planId: String) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerExecutePlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.execute_plan response")
            }
            self.moduleState.currentPlan = plan
            return plan
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchPlans(status: String = "") async throws -> [PlanModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerListPlans(status: status)
            let plansData = result["plans"] as? [[String: Any]] ?? []
            var parsed: [PlanModel] = []
            for p in plansData {
                if let plan = Self.parsePlanModel(from: p) {
                    parsed.append(plan)
                }
            }
            self.moduleState.plans = parsed
            agentPlannerLog.info("fetchPlans: received \(parsed.count) plans")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func plannerCancelPlan(planId: String) async throws -> PlanModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.plannerCancelPlan(planId: planId)
            guard let plan = Self.parsePlanModel(from: result) else {
                throw BridgeError.decodeError("Failed to parse planner.cancel_plan response")
            }
            self.moduleState.currentPlan = plan
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
