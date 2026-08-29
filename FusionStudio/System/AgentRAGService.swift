// ARCH-1: RAG 操作从 AgentBridge God-object (3167行) 抽出, facade extension。
// @Published ragResults/ragSources + ipcClient 仍存 AgentBridge (extension 不可声明存储属性),
// 本文件只搬方法体, 行为零变。外部唯一调用方: AgentConfigTabs RAGTabView (ragQuery/ragRetrieve/ragVectorSearch)。
// ragResults/ragSources 经查 0 外部 SwiftUI 读 (write-only 状态), 抽取纯代码组织无行为风险。

import os.log

private let agentRAGLog = Logger(subsystem: "com.fusion.studio", category: "AgentRAGService")

extension AgentBridge {

    // MARK: - RAG Operations

    func ragQuery(query: String, config: [String: Any] = [:], model: String = "", systemPrompt: String = "") async throws -> RAGResultModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentRAGLog.info("ragQuery: query=\(query)")
        do {
            let result = try await client.ragQuery(query: query, config: config, model: model, systemPrompt: systemPrompt)
            // F-I4: 手动 result["answer"] as? String → decodeCodable 强类型解码 (init(from:) ?? default 宽容)。query 调用方注入, 解码后覆盖。
            guard var ragResult = AgentBridge.decodeCodable(RAGResultModel.self, from: result, context: "ragQuery") else {
                agentRAGLog.error("ragQuery decode failed, keys=\(result.keys.sorted())")
                throw BridgeError.ipcError("ragQuery parse failed")
            }
            ragResult.query = query
            self.moduleState.ragResults.append(ragResult)
            // PERF-3: ragResults 无上限 append, 长会话无限增长内存。保留最近 50 条 (LRU 语义: 旧结果越早越无回看价值), 超额丢弃最旧。
            if self.moduleState.ragResults.count > 50 {
                self.moduleState.ragResults.removeFirst(self.moduleState.ragResults.count - 50)
            }
            return ragResult
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func ragRetrieve(query: String, config: [String: Any] = [:]) async throws -> [String] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.ragRetrieve(query: query, config: config)
            return result["documents"] as? [String] ?? []
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func ragVectorSearch(query: String, limit: Int = 10, threshold: Double = 0.5) async throws -> [String] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentRAGLog.info("ragVectorSearch: query=\(query) limit=\(limit)")
        do {
            let result = try await client.ragVectorSearch(query: query, limit: limit, threshold: threshold)
            let docs = result["documents"] as? [String] ?? result["results"] as? [String] ?? []
            self.moduleState.ragSources = docs
            return docs
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }
}
