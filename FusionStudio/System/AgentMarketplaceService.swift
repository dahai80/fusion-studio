// ARCH-1 PR5 (#359 facade-delegate): Marketplace Operations 从 AgentBridge God-object 迁入 AgentState 域。
//   本文件含 2 extension:
//     1) extension AgentState — 6 真实方法体 (marketplaceSearch/Get/Publish/Uninstall/Unpublish/fetchMarketplaceCategories, 自持 ipcClient) + parseMarketplaceEntry。
//     2) extension AgentBridge — 6 个 1 行 facade stub 委托到 agentState.X(), 保外部 call site 签名零变。
//   marketplaceInstall 留 AgentOpsService (AgentState 域, 依赖 Self.parseAgentModel 同域同文件可达), 经 bridge.marketplaceInstall stub 不变。
//   parseMarketplaceEntry (marketplace-specific private static) 同搬本文件: 仅 3 调用方 (marketplaceSearch/Get/Publish) 全在本 extension, 同文件 private 可达, Self 解析不变。
//     bare decodeCodable → AgentBridge.decodeCodable 显式限定 (Self=AgentState, decodeCodable 是 AgentBridge nonisolated static, 同 PR4 Memory parseMemoryEntry 范式)。
//   @Published marketplaceEntries/marketplaceCategories 在 AgentState 域 (marketplaceEntries 有外部 SwiftUI 读 TemplateMarketView), 经 bridge.agentState.X 不变。
//   Logger: 本文件自有 agentMarketplaceLog 替代主类 private logger (跨文件不可达)。
//   ipcClient 为 internal (非 private): 跨文件 extension 访问, Swift private=文件作用域 (同 PR1/PR2/PR3/PR4 坑)。

import os.log

private let agentMarketplaceLog = Logger(subsystem: "com.fusion.studio", category: "AgentMarketplaceService")

// MARK: - Marketplace Operations (行为落地 AgentState 域)
extension AgentState {

    // MARK: - Marketplace Operations

    func marketplaceSearch(query: String = "", category: String = "", tags: [String] = []) async throws -> [MarketplaceEntryModel] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.marketplaceSearch(query: query, category: category, tags: tags)
            let entriesData = result["entries"] as? [[String: Any]] ?? []
            var parsed: [MarketplaceEntryModel] = []
            for e in entriesData {
                if let entry = Self.parseMarketplaceEntry(from: e) {
                    parsed.append(entry)
                }
            }
            self.marketplaceEntries = parsed
            agentMarketplaceLog.info("marketplaceSearch: found \(parsed.count) entries")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func marketplaceGet(entryId: String) async throws -> MarketplaceEntryModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.marketplaceGet(entryId: entryId)
            guard let entry = Self.parseMarketplaceEntry(from: result) else {
                throw BridgeError.decodeError("Failed to parse marketplace.get response")
            }
            return entry
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func marketplacePublish(name: String, author: String = "", description: String = "", category: String = "", tags: [String] = [], version: String = "1.0.0", graphData: [String: Any] = [:]) async throws -> MarketplaceEntryModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentMarketplaceLog.info("marketplacePublish: name=\(name)")
        do {
            let result = try await client.marketplacePublish(name: name, author: author, description: description, category: category, tags: tags, version: version, graphData: graphData)
            guard let entry = Self.parseMarketplaceEntry(from: result) else {
                throw BridgeError.decodeError("Failed to parse marketplace.publish response")
            }
            return entry
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func marketplaceUninstall(entryId: String) async throws -> Bool {
        guard let client = self.ipcClient else {
            throw BridgeError.notConnected
        }
        agentMarketplaceLog.info("marketplaceUninstall: \(entryId)")
        do {
            let result = try await client.call(method: RPCMethod.marketplaceUninstall, params: ["entry_id": entryId]) as [String: Any]
            return result["success"] as? Bool ?? false
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            agentMarketplaceLog.error("marketplaceUninstall: \(error)")
            throw bridgeErr
        }
    }

    func marketplaceUnpublish(entryId: String) async throws -> Bool {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.marketplaceUnpublish(entryId: entryId)
            return result["unpublished"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchMarketplaceCategories() async throws -> [String] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.marketplaceListCategories()
            let categories = result["categories"] as? [String] ?? []
            self.marketplaceCategories = categories
            return categories
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    // F-I4: marketplace-specific parser 委托 decodeCodable (init(from:) dual-key entry_id/id + guard id/name 缺一 throw → caller nil)。
    // Self=AgentState, decodeCodable 是 AgentBridge nonisolated static → 显式限定 AgentBridge.decodeCodable (同 PR4 Memory parseMemoryEntry)。
    private static func parseMarketplaceEntry(from dict: [String: Any]) -> MarketplaceEntryModel? {
        return AgentBridge.decodeCodable(MarketplaceEntryModel.self, from: dict, context: "marketplaceEntry")
    }
}

// MARK: - Marketplace Operations (facade-delegate stubs — 行为已迁 AgentState 域)
// ARCH-1 PR5: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func marketplaceSearch(query: String = "", category: String = "", tags: [String] = []) async throws -> [MarketplaceEntryModel] {
        try await agentState.marketplaceSearch(query: query, category: category, tags: tags)
    }

    func marketplaceGet(entryId: String) async throws -> MarketplaceEntryModel {
        try await agentState.marketplaceGet(entryId: entryId)
    }

    func marketplacePublish(name: String, author: String = "", description: String = "", category: String = "", tags: [String] = [], version: String = "1.0.0", graphData: [String: Any] = [:]) async throws -> MarketplaceEntryModel {
        try await agentState.marketplacePublish(name: name, author: author, description: description, category: category, tags: tags, version: version, graphData: graphData)
    }

    func marketplaceUninstall(entryId: String) async throws -> Bool {
        try await agentState.marketplaceUninstall(entryId: entryId)
    }

    func marketplaceUnpublish(entryId: String) async throws -> Bool {
        try await agentState.marketplaceUnpublish(entryId: entryId)
    }

    func fetchMarketplaceCategories() async throws -> [String] {
        try await agentState.fetchMarketplaceCategories()
    }
}
