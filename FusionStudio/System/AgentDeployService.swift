// ARCH-1: Deploy Operations 从 AgentBridge God-object 抽出, facade extension。
// @Published deployFormats + ipcClient 仍存 AgentBridge (extension 不可声明存储), 本文件只搬方法体, 行为零变。
// deployImport 留 AgentBridge.swift: 依赖 Self.parseGraphModel (private static 跨文件不可访问),
// 待 Graph 域抽取时与 parseGraphModel + 5 graph 方法 + templateInstantiate 同搬。
// deployFormats @Published 有 3 外部 SwiftUI 读 (DeployView), @Published 留主类, extension 写 self.moduleState.deployFormats, 观察链不变。

import Foundation
import os.log

private let agentDeployLog = Logger(subsystem: "com.fusion.studio", category: "AgentDeployService")

extension AgentBridge {

    // MARK: - Deploy Operations

    func deployExport(graphId: String, format: String = "json", filepath: String = "", withServer: Bool = true, port: Int = 8000) async throws -> [String: Any] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentDeployLog.info("deployExport: graphId=\(graphId) format=\(format)")
        do {
            return try await client.deployExport(graphId: graphId, format: format, filepath: filepath, withServer: withServer, port: port)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchDeployFormats() async throws -> [DeployFormatModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.deployListFormats()
            let formatsData = result["formats"] as? [[String: Any]] ?? []
            // F-I4: 手动 f["format"] as? String → decodeCodable 强类型解码 (init(from:) 派生 id=format, 缺键 ?? default)。
            var parsed: [DeployFormatModel] = []
            for f in formatsData {
                guard let fmt = AgentBridge.decodeCodable(DeployFormatModel.self, from: f, context: "deployFormat") else {
                    agentDeployLog.warning("fetchDeployFormats: skip undecodable format entry, keys=\(f.keys.sorted())")
                    continue
                }
                parsed.append(fmt)
            }
            self.moduleState.deployFormats = parsed
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }
}
