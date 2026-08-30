// ARCH-1 PR4 (#359 facade-delegate): Template Operations 从 AgentBridge God-object 迁入 ModuleState 域。
//   本文件含 2 extension:
//     1) extension ModuleState — 2 真实方法体 (fetchTemplates/templateGet, 自持 ipcClient)。
//     2) extension AgentBridge — 2 个 1 行 facade stub 委托到 moduleState.X(), 保外部 call site 签名零变。
//   templateInstantiate 留 AgentBridge.swift: 依赖 Self.parseGraphModel (private static, 跨文件不可访问),
//   待 Graph 域抽取时与 parseGraphModel 同搬。外部唯一 AgentBridge 调用方: TemplateMarketView (templateInstantiate)。
//   @Published templates 在 ModuleState 域 (write-only 0 外部 SwiftUI 读), 经 bridge.moduleState.templates 不变。
//   ipcClient 为 internal (非 private): 跨文件 extension 访问, Swift private=文件作用域 (同 PR1/PR2/PR3 坑)。

import Foundation
import os.log

private let agentTemplateLog = Logger(subsystem: "com.fusion.studio", category: "AgentTemplateService")

// MARK: - Template Operations (行为落地 ModuleState 域)
extension ModuleState {

    func fetchTemplates(category: String = "") async throws -> [TemplateModel] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.templateList(category: category)
            let templatesData = result["templates"] as? [[String: Any]] ?? []
            // F-I4: site A 列表项 → decodeCodable (init(from:) dual-key template_id/id + ?? default 宽容)。
            var parsed: [TemplateModel] = []
            for t in templatesData {
                guard let tpl = AgentBridge.decodeCodable(TemplateModel.self, from: t, context: "templateList") else {
                    agentTemplateLog.warning("fetchTemplates: skip undecodable template entry, keys=\(t.keys.sorted())")
                    continue
                }
                parsed.append(tpl)
            }
            self.templates = parsed
            agentTemplateLog.info("fetchTemplates: received \(parsed.count) templates")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func templateGet(templateId: String) async throws -> TemplateModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.templateGet(templateId: templateId)
            // F-I4: site B → decodeCodable (init(from:) dual-key template_id/id + ?? default)。id 缺全部键时 fallback 调用方 templateId (保旧行为)。
            guard var tpl = AgentBridge.decodeCodable(TemplateModel.self, from: result, context: "templateGet") else {
                agentTemplateLog.error("templateGet decode failed, templateId=\(templateId, privacy: .public) keys=\(result.keys.sorted())")
                throw BridgeError.ipcError("templateGet parse failed")
            }
            if tpl.id.isEmpty {
                tpl.id = templateId
            }
            return tpl
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }
}

// MARK: - Template Operations (facade-delegate stubs — 行为已迁 ModuleState 域)
// ARCH-1 PR4: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func fetchTemplates(category: String = "") async throws -> [TemplateModel] {
        try await moduleState.fetchTemplates(category: category)
    }

    func templateGet(templateId: String) async throws -> TemplateModel {
        try await moduleState.templateGet(templateId: templateId)
    }
}
