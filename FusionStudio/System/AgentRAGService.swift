// ARCH-1 PR4 (#359 facade-delegate): RAG Operations 从 AgentBridge God-object 迁入 ModuleState 域。
//   本文件含 2 extension:
//     1) extension ModuleState — 3 真实方法体 (ragQuery/ragRetrieve/ragVectorSearch, 自持 ipcClient)。
//     2) extension AgentBridge — 3 个 1 行 facade stub 委托到 moduleState.X(), 保外部 call site 签名零变。
//   外部唯一调用方: AgentConfigTabs RAGTabView (ragQuery/ragRetrieve/ragVectorSearch), 经 bridge.X 不变。
//   ragResults/ragSources 在 ModuleState 域 (ragResults LRU cap50 PERF-3, write-only 状态 0 外部 SwiftUI 读)。
//   ipcClient 为 internal (非 private): 跨文件 extension 访问, Swift private=文件作用域 (同 PR1/PR2/PR3 坑)。

import os.log

private let agentRAGLog = Logger(subsystem: "com.fusion.studio", category: "AgentRAGService")

// MARK: - RAG Operations (行为落地 ModuleState 域)
extension ModuleState {

    func ragQuery(query: String, config: [String: Any] = [:], model: String = "", systemPrompt: String = "") async throws -> RAGResultModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentRAGLog.info("ragQuery: query=\(query)")
        do {
            let result = try await client.ragQuery(query: query, config: config, model: model, systemPrompt: systemPrompt)
            // F-I4: 手动 result["answer"] as? String → decodeCodable 强类型解码 (init(from:) ?? default 宽容)。query 调用方注入, 解码后覆盖。
            guard var ragResult = AgentBridge.decodeCodable(RAGResultModel.self, from: result, context: "ragQuery") else {
                agentRAGLog.error("ragQuery decode failed, keys=\(result.keys.sorted())")
                throw BridgeError.ipcError("ragQuery parse failed")
            }
            ragResult.query = query
            self.ragResults.append(ragResult)
            // PERF-3: ragResults 无上限 append, 长会话无限增长内存。保留最近 50 条 (LRU 语义: 旧结果越早越无回看价值), 超额丢弃最旧。
            if self.ragResults.count > 50 {
                self.ragResults.removeFirst(self.ragResults.count - 50)
            }
            return ragResult
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func ragRetrieve(query: String, config: [String: Any] = [:]) async throws -> [String] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.ragRetrieve(query: query, config: config)
            return result["documents"] as? [String] ?? []
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func ragVectorSearch(query: String, limit: Int = 10, threshold: Double = 0.5) async throws -> [String] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentRAGLog.info("ragVectorSearch: query=\(query) limit=\(limit)")
        do {
            let result = try await client.ragVectorSearch(query: query, limit: limit, threshold: threshold)
            let docs = result["documents"] as? [String] ?? result["results"] as? [String] ?? []
            self.ragSources = docs
            return docs
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }
}

// MARK: - RAG Operations (facade-delegate stubs — 行为已迁 ModuleState 域)
// ARCH-1 PR4: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func ragQuery(query: String, config: [String: Any] = [:], model: String = "", systemPrompt: String = "") async throws -> RAGResultModel {
        try await moduleState.ragQuery(query: query, config: config, model: model, systemPrompt: systemPrompt)
    }

    func ragRetrieve(query: String, config: [String: Any] = [:]) async throws -> [String] {
        try await moduleState.ragRetrieve(query: query, config: config)
    }

    func ragVectorSearch(query: String, limit: Int = 10, threshold: Double = 0.5) async throws -> [String] {
        try await moduleState.ragVectorSearch(query: query, limit: limit, threshold: threshold)
    }
}
