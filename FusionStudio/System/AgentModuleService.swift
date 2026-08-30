// ARCH-1 PR4 (#359 facade-delegate): Module Operations (tools + skill + research) 从 AgentBridge God-object 迁入 ModuleState 域。
//   本文件含 2 extension:
//     1) extension ModuleState — 6 真实方法体 (fetchTools/toolDynamicRegister/toolDynamicUnregister/getTool + skillExecute/researchAdaptive, 自持 ipcClient)。
//     2) extension AgentBridge — 6 个 1 行 facade stub 委托到 moduleState.X(), 保外部 call site 签名零变。
//   这 6 方法原在 AgentBridge.swift 主类 (非既有 service 文件), 与既有 6 Module service 文件 (Planner/RAG/Memory/Safety/Deploy/Template) 同域。
//   0 private 静态依赖, 0 跨域实例调用, 0 TTL。Module 域写 tools/lastSkillResult/lastResearchResult @Published (有外部 SwiftUI 读 ToolsTabView/SkillsTabView)。
//   ipcClient 为 internal (非 private): 跨文件 extension 访问, Swift private=文件作用域 (同 PR1/PR2/PR3 坑)。

import Foundation
import os.log

private let agentModuleLog = Logger(subsystem: "com.fusion.studio", category: "AgentModuleService")

// MARK: - Tool Operations (行为落地 ModuleState 域)
extension ModuleState {

    func fetchTools() async throws -> [[String: Any]] {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        agentModuleLog.info("fetchTools")
        do {
            let result = try await client.call(method: RPCMethod.toolList, params: [:])
            let tools = result["tools"] as? [[String: Any]] ?? []
            self.tools = tools
            return tools
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            agentModuleLog.error("fetchTools: \(error)")
            throw bridgeErr
        }
    }

    func toolDynamicRegister(name: String, description: String, parameters: [String: Any], code: String = "") async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentModuleLog.info("toolDynamicRegister: \(name)")
        do {
            let result = try await client.toolDynamicRegister(name: name, description: description, parameters: parameters, code: code)
            try await fetchTools()
            return result
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func toolDynamicUnregister(name: String) async throws -> Bool {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentModuleLog.info("toolDynamicUnregister: \(name)")
        do {
            _ = try await client.toolDynamicUnregister(name: name)
            try await fetchTools()
            return true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func getTool(name: String) async throws -> [String: Any] {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        agentModuleLog.info("getTool: \(name)")
        do {
            return try await client.call(method: RPCMethod.toolGet, params: ["name": name])
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            agentModuleLog.error("getTool: \(error)")
            throw bridgeErr
        }
    }

    // MARK: - Skill + Research Operations

    func skillExecute(agentId: String, skillName: String, input: String, tools: [String] = []) async throws -> String {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentModuleLog.info("skillExecute: agent=\(agentId) skill=\(skillName)")
        do {
            let result = try await client.skillExecute(agentId: agentId, skillName: skillName, input: input, tools: tools)
            let output = result["result"] as? String ?? result["output"] as? String ?? ""
            self.lastSkillResult = output
            return output
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func researchAdaptive(question: String, maxSteps: Int = 10, webSearch: Bool = true) async throws -> String {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentModuleLog.info("researchAdaptive: question=\(question) maxSteps=\(maxSteps)")
        do {
            let result = try await client.researchAdaptive(question: question, maxSteps: maxSteps, webSearch: webSearch)
            let summary = result["summary"] as? String ?? result["result"] as? String ?? ""
            self.lastResearchResult = summary
            return summary
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }
}

// MARK: - Tool + Skill + Research Operations (facade-delegate stubs — 行为已迁 ModuleState 域)
// ARCH-1 PR4: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func fetchTools() async throws -> [[String: Any]] {
        try await moduleState.fetchTools()
    }

    func toolDynamicRegister(name: String, description: String, parameters: [String: Any], code: String = "") async throws -> [String: Any] {
        try await moduleState.toolDynamicRegister(name: name, description: description, parameters: parameters, code: code)
    }

    func toolDynamicUnregister(name: String) async throws -> Bool {
        try await moduleState.toolDynamicUnregister(name: name)
    }

    func getTool(name: String) async throws -> [String: Any] {
        try await moduleState.getTool(name: name)
    }

    func skillExecute(agentId: String, skillName: String, input: String, tools: [String] = []) async throws -> String {
        try await moduleState.skillExecute(agentId: agentId, skillName: skillName, input: input, tools: tools)
    }

    func researchAdaptive(question: String, maxSteps: Int = 10, webSearch: Bool = true) async throws -> String {
        try await moduleState.researchAdaptive(question: question, maxSteps: maxSteps, webSearch: webSearch)
    }
}
