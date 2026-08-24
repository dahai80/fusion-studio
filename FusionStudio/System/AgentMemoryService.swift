// ARCH-1: Memory Operations + parseMemoryEntry 从 AgentBridge God-object 抽出, facade extension。
// 6 方法 (memoryStore/memoryRecall/fetchRecentMemories/memoryDelete/memoryDeleteScope/fetchMemoryCount)
//   + 域内专属 parser parseMemoryEntry (private static, 4 调用方全在 Memory 域) 同搬本文件。
// parser 同搬范式 (同 #287 parseMarketplaceEntry): private = Swift 文件作用域, 同文件 extension 方法 Self.parseMemoryEntry 编译不变。
//   parseMemoryEntry 无 UUID/Date 依赖 → 仅 import os.log, 无 Foundation。
// Memory 域: 0 跨域实例调用, 写通用 lastError error sink + 域内 memoryEntries/memoryCount @Published。
// @Published memoryEntries(L334)/memoryCount(L335) 留主类 (extension 不可声明存储, 有外部 SwiftUI 读 MemoryView/AgentConfigTabs)。
//   extension 写 self.prop, 观察链不变。
// ipcClient 仍存 AgentBridge, extension 读 self.ipcClient。logger private → 文件级 agentMemoryLog。

import os.log

private let agentMemoryLog = Logger(subsystem: "com.fusion.studio", category: "AgentMemoryService")

extension AgentBridge {

    // MARK: - Memory Operations

    func memoryStore(content: String, scope: String = "default", tags: String = "", importance: Int = 5, metadata: [String: Any]? = nil, tier: String = "") async throws -> MemoryEntryModel {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        agentMemoryLog.info("memoryStore: scope=\(scope)")
        do {
            let result = try await client.memoryStore(content: content, scope: scope, tags: tags, importance: importance, metadata: metadata, tier: tier)
            guard let entry = Self.parseMemoryEntry(from: result) else {
                throw BridgeError.decodeError("Failed to parse memory.store response")
            }
            return entry
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func memoryRecall(query: String, scope: String = "", limit: Int = 10, minImportance: Int = 0, tier: String = "") async throws -> [MemoryEntryModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryRecall(query: query, scope: scope, limit: limit, minImportance: minImportance, tier: tier)
            let entriesData = result["entries"] as? [[String: Any]] ?? []
            var parsed: [MemoryEntryModel] = []
            for e in entriesData {
                if let entry = Self.parseMemoryEntry(from: e) {
                    parsed.append(entry)
                }
            }
            self.memoryEntries = parsed
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchRecentMemories(scope: String = "", limit: Int = 20, minImportance: Int = 0, tier: String = "") async throws -> [MemoryEntryModel] {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryListRecent(scope: scope, limit: limit, minImportance: minImportance, tier: tier)
            let entriesData = result["entries"] as? [[String: Any]] ?? []
            var parsed: [MemoryEntryModel] = []
            for e in entriesData {
                if let entry = Self.parseMemoryEntry(from: e) {
                    parsed.append(entry)
                }
            }
            self.memoryEntries = parsed
            agentMemoryLog.info("fetchRecentMemories: received \(parsed.count) entries")
            return parsed
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MAINT: memoryGet 删除 — 0 前端调用方 (UI 只读 memoryEntries 列表, 无单条详情视图)。后端 memory.get RPC 不动 (跨工程)。

    func memoryDelete(entryId: String) async throws -> Bool {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryDelete(entryId: entryId)
            return result["deleted"] as? Bool ?? false
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func memoryDeleteScope(scope: String) async throws -> Int {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryDeleteScope(scope: scope)
            return result["count"] as? Int ?? 0
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    func fetchMemoryCount(scope: String = "", tier: String = "") async throws -> Int {
        guard let client = ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryCount(scope: scope, tier: tier)
            let count = result["count"] as? Int ?? 0
            self.memoryCount = count
            return count
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)
            self.lastError = bridgeErr
            throw bridgeErr
        }
    }

    // MARK: - Memory Parsing Helper (domain parser, file-private, 仅本 extension 调用)

    private static func parseMemoryEntry(from dict: [String: Any]) -> MemoryEntryModel? {
        guard let entryId = dict["entry_id"] as? String ?? dict["id"] as? String,
              let content = dict["content"] as? String else {
            return nil
        }
        return MemoryEntryModel(
            id: entryId,
            content: content,
            scope: dict["scope"] as? String ?? "default",
            tags: dict["tags"] as? String ?? "",
            importance: dict["importance"] as? Int ?? 5,
            timestamp: dict["timestamp"] as? String ?? "",
            tier: dict["tier"] as? String ?? "short_term"
        )
    }
}
