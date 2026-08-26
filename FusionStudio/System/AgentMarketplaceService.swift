// ARCH-1: Marketplace Operations 从 AgentBridge God-object 抽出, facade extension。
// @Published marketplaceEntries/marketplaceCategories + ipcClient 仍存 AgentBridge (extension 不可声明存储), 本文件只搬方法体, 行为零变。
// marketplaceInstall 留 AgentBridge.swift: 依赖 Self.parseAgentModel (cross-domain private static 跨文件不可访问) + 写共享 agents 数组, 待 Graph/Agent 域整批同迁。
// parseMarketplaceEntry (marketplace-specific private static) 同搬本文件: 仅 3 调用方 (marketplaceSearch/Get/Publish) 全在本 extension, 同文件 private 可达, Self 解析不变。
// marketplaceEntries @Published 有外部 SwiftUI 读 (TemplateMarketView), @Published 留主类 extension 写 self.marketplaceEntries, 观察链不变。

import os.log

private let agentMarketplaceLog = Logger(subsystem: "com.fusion.studio", category: "AgentMarketplaceService")

extension AgentBridge {

    // MARK: - Marketplace Operations

    func marketplaceSearch(query: String = "", category: String = "", tags: [String] = []) async throws -> [MarketplaceEntryModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
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
        guard let client = ipcClient else { throw BridgeError.notConnected }
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
        guard let client = ipcClient else { throw BridgeError.notConnected }
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
        guard let client = ipcClient else {
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
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.marketplaceUnpublish(entryId: entryId)
            return result["unpublished"] as? Bool ?? true
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchMarketplaceCategories() async throws -> [String] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
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

    // marketplace-specific parser, file-private (private = 文件作用域), 仅本 extension 3 方法调用, Self 解析不变。
    private static func parseMarketplaceEntry(from dict: [String: Any]) -> MarketplaceEntryModel? {
        guard let entryId = dict["entry_id"] as? String ?? dict["id"] as? String,
              let name = dict["name"] as? String else {
            return nil
        }
        return MarketplaceEntryModel(
            id: entryId,
            name: name,
            author: dict["author"] as? String ?? "",
            description: dict["description"] as? String ?? "",
            category: dict["category"] as? String ?? "",
            tags: dict["tags"] as? [String] ?? [],
            version: dict["version"] as? String ?? "1.0.0",
            rating: dict["rating"] as? Double ?? 0.0,
            downloads: dict["downloads"] as? Int ?? 0,
            created_at: dict["created_at"] as? String ?? "",
            updated_at: dict["updated_at"] as? String ?? ""
        )
    }
}
