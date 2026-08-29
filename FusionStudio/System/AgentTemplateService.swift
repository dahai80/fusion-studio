// ARCH-1: Template Operations 从 AgentBridge God-object 抽出, facade extension。
// @Published templates + ipcClient 仍存 AgentBridge (extension 不可声明存储), 本文件只搬方法体, 行为零变。
// templateInstantiate 留 AgentBridge.swift: 依赖 Self.parseGraphModel (private static L2948, 跨文件不可访问),
// 待 Graph 域抽取时与 parseGraphModel 同搬。外部唯一 AgentBridge 调用方: TemplateMarketView (templateInstantiate)。
// templates @Published 经查 0 外部 SwiftUI 读 (write-only), 抽取纯代码组织无行为风险。

import Foundation
import os.log

private let agentTemplateLog = Logger(subsystem: "com.fusion.studio", category: "AgentTemplateService")

extension AgentBridge {

    // MARK: - Template Operations

    func fetchTemplates(category: String = "") async throws -> [TemplateModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
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
            self.moduleState.templates = parsed
            agentTemplateLog.info("fetchTemplates: received \(parsed.count) templates")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func templateGet(templateId: String) async throws -> TemplateModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
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
