// ARCH-1: Template Operations 从 AgentBridge God-object 抽出, facade extension。
// @Published templates/lastError + ipcClient 仍存 AgentBridge (extension 不可声明存储), 本文件只搬方法体, 行为零变。
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
            var parsed: [TemplateModel] = []
            for t in templatesData {
                parsed.append(TemplateModel(
                    id: t["template_id"] as? String ?? t["id"] as? String ?? UUID().uuidString,
                    name: t["name"] as? String ?? "",
                    category: t["category"] as? String ?? "",
                    description: t["description"] as? String ?? "",
                    variables: t["variables"] as? [String] ?? []
                ))
            }
            self.templates = parsed
            agentTemplateLog.info("fetchTemplates: received \(parsed.count) templates")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func templateGet(templateId: String) async throws -> TemplateModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.templateGet(templateId: templateId)
            return TemplateModel(
                id: result["template_id"] as? String ?? result["id"] as? String ?? templateId,
                name: result["name"] as? String ?? "",
                category: result["category"] as? String ?? "",
                description: result["description"] as? String ?? "",
                variables: result["variables"] as? [String] ?? []
            )
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }
}
