// ARCH-1 PR4 (#359 facade-delegate): Memory Operations + parseMemoryEntry 从 AgentBridge God-object 迁入 ModuleState 域。
//   本文件含 2 extension:
//     1) extension ModuleState — 6 真实方法体 (memoryStore/memoryRecall/fetchRecentMemories/memoryDelete/memoryDeleteScope/fetchMemoryCount, 自持 ipcClient) + 域内 parser parseMemoryEntry。
//     2) extension AgentBridge — 6 个 1 行 facade stub 委托到 moduleState.X(), 保外部 call site 签名零变。
//   parseMemoryEntry (private static, 4 调用方全 Memory 域) 随域同迁 — private = Swift 文件作用域, 同文件 extension Self.parseMemoryEntry 可达。
//   parseMemoryEntry 调 bare decodeCodable → Self=ModuleState 后须显式 AgentBridge.decodeCodable 限定 (nonisolated static)。
//   parseMemoryEntry 无 UUID/Date 依赖 → 仅 import os.log, 无 Foundation。
//   @Published memoryEntries/memoryCount 在 ModuleState 域 (外部 SwiftUI 读 MemoryView/AgentConfigTabs), 经 bridge.moduleState.X 不变。
//   ipcClient 为 internal (非 private): 跨文件 extension 访问, Swift private=文件作用域 (同 PR1/PR2/PR3 坑)。

import os.log

private let agentMemoryLog = Logger(subsystem: "com.fusion.studio", category: "AgentMemoryService")

// MARK: - Memory Operations (行为落地 ModuleState 域)
extension ModuleState {

    func memoryStore(content: String, scope: String = "default", tags: String = "", importance: Int = 5, metadata: [String: Any]? = nil, tier: String = "") async throws -> MemoryEntryModel {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        agentMemoryLog.info("memoryStore: scope=\(scope)")
        do {
            let result = try await client.memoryStore(content: content, scope: scope, tags: tags, importance: importance, metadata: metadata, tier: tier)
            guard let entry = Self.parseMemoryEntry(from: result) else {
                throw BridgeError.decodeError("Failed to parse memory.store response")
            }
            return entry
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func memoryRecall(query: String, scope: String = "", limit: Int = 10, minImportance: Int = 0, tier: String = "") async throws -> [MemoryEntryModel] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
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

            throw bridgeErr
        }
    }

    func fetchRecentMemories(scope: String = "", limit: Int = 20, minImportance: Int = 0, tier: String = "") async throws -> [MemoryEntryModel] {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
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

            throw bridgeErr
        }
    }

    // MAINT: memoryGet 删除 — 0 前端调用方 (UI 只读 memoryEntries 列表, 无单条详情视图)。后端 memory.get RPC 不动 (跨工程)。

    func memoryDelete(entryId: String) async throws -> Bool {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryDelete(entryId: entryId)
            return result["deleted"] as? Bool ?? false
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func memoryDeleteScope(scope: String) async throws -> Int {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryDeleteScope(scope: scope)
            return result["count"] as? Int ?? 0
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    func fetchMemoryCount(scope: String = "", tier: String = "") async throws -> Int {
        guard let client = self.ipcClient else { throw BridgeError.notConnected }
        do {
            let result = try await client.memoryCount(scope: scope, tier: tier)
            let count = result["count"] as? Int ?? 0
            self.memoryCount = count
            return count
        } catch let error as IPCError {
            let bridgeErr = BridgeError.ipcError(error.localizedDescription)

            throw bridgeErr
        }
    }

    // MARK: - Memory Parsing Helper (domain parser, file-private, 仅本 extension 调用)

    // F-I4: parseMemoryEntry 委托 decodeCodable (init(from:) dual-key entry_id/id + guard id/content 缺一 throw → caller nil)。
    // Self=ModuleState; decodeCodable 是 AgentBridge nonisolated static, 显式 AgentBridge.decodeCodable 限定可达。
    private static func parseMemoryEntry(from dict: [String: Any]) -> MemoryEntryModel? {
        return AgentBridge.decodeCodable(MemoryEntryModel.self, from: dict, context: "memoryEntry")
    }
}

// MARK: - Memory Operations (facade-delegate stubs — 行为已迁 ModuleState 域)
// ARCH-1 PR4: 本 extension 仅 1 行委托, 保外部 call site (bridge.X) 签名零变。
extension AgentBridge {

    func memoryStore(content: String, scope: String = "default", tags: String = "", importance: Int = 5, metadata: [String: Any]? = nil, tier: String = "") async throws -> MemoryEntryModel {
        try await moduleState.memoryStore(content: content, scope: scope, tags: tags, importance: importance, metadata: metadata, tier: tier)
    }

    func memoryRecall(query: String, scope: String = "", limit: Int = 10, minImportance: Int = 0, tier: String = "") async throws -> [MemoryEntryModel] {
        try await moduleState.memoryRecall(query: query, scope: scope, limit: limit, minImportance: minImportance, tier: tier)
    }

    func fetchRecentMemories(scope: String = "", limit: Int = 20, minImportance: Int = 0, tier: String = "") async throws -> [MemoryEntryModel] {
        try await moduleState.fetchRecentMemories(scope: scope, limit: limit, minImportance: minImportance, tier: tier)
    }

    func memoryDelete(entryId: String) async throws -> Bool {
        try await moduleState.memoryDelete(entryId: entryId)
    }

    func memoryDeleteScope(scope: String) async throws -> Int {
        try await moduleState.memoryDeleteScope(scope: scope)
    }

    func fetchMemoryCount(scope: String = "", tier: String = "") async throws -> Int {
        try await moduleState.fetchMemoryCount(scope: scope, tier: tier)
    }
}
