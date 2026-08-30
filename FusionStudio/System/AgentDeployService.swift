// ARCH-1 PR4 (#359 facade-delegate): Deploy Operations 从 AgentBridge God-object 迁入 ModuleState 域。
//   本文件含 2 extension:
//     1) extension ModuleState — 2 真实方法体 (deployExport/fetchDeployFormats, 自持 ipcClient)。
//     2) extension AgentBridge — 2 个 1 行 facade stub 委托到 moduleState.X(), 保外部 call site 签名零变。
//   deployImport 留 AgentBridge.swift: 依赖 Self.parseGraphModel (private static 跨文件不可访问),
//   待 Graph 域抽取时与 parseGraphModel + 5 graph 方法 + templateInstantiate 同搬。
//   @Published deployFormats 在 ModuleState 域 (3 外部 SwiftUI 读 DeployView), 经 bridge.moduleState.deployFormats 不变。
//   ipcClient 为 internal (非 private): 跨文件 extension 访问, Swift private=文件作用域 (同 PR1/PR2/PR3 坑)。

import Foundation
import os.log

private let agentDeployLog = Logger(subsystem: "com.fusion.studio", category: "AgentDeployService")

// MARK: - Deploy Operations (行为落地 ModuleState 域)
extension ModuleState {

    func deployExport(graphId: String, format: String = "json", filepath: String = "", withServer: Bool = true, port: Int = 8000) async throws -> [String: Any] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentDeployLog.info("deployExport: graphId=\(graphId) format=\(format)")
        do {
            return try await client.deployExport(graphId: graphId, format: format, filepath: filepath, withServer: withServer, port: port)
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchDeployFormats() async throws -> [DeployFormatModel] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
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
            self.deployFormats = parsed
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }
}

// MARK: - Deploy Operations (facade-delegate stubs — 行为已迁 ModuleState 域)
// ARCH-1 PR4: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func deployExport(graphId: String, format: String = "json", filepath: String = "", withServer: Bool = true, port: Int = 8000) async throws -> [String: Any] {
        try await moduleState.deployExport(graphId: graphId, format: format, filepath: filepath, withServer: withServer, port: port)
    }

    func fetchDeployFormats() async throws -> [DeployFormatModel] {
        try await moduleState.fetchDeployFormats()
    }
}
