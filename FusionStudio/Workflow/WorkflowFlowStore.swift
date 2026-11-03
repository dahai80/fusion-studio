import Foundation
import os.log

// #426 P1-6: 本地 flow 存储 (plan §6.5 on-device flow store)。
//   Application Support/FusionStudio/workflows/{flows,templates}/*.json + snapshots/<flowId>/<ts>.json。
//   损坏文件 → 移入 corrupt/ 保留现场 + 显式抛错 (fail visibly, 不静默丢数据)。
//   调用方 (canvas .task / executor) 均在 async 上下文, 文件 I/O 不落 MainActor (PERF-4 范式)。

private let flowStoreLog = Logger(subsystem: "com.fusion.studio", category: "WorkflowFlowStore")

struct WorkflowFlowStore {
    let root: URL

    // root 可注入 (测试用临时目录); 默认 Application Support
    init(root: URL? = nil) {
        if let root = root {
            self.root = root
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.root = base.appendingPathComponent("FusionStudio/workflows", isDirectory: true)
        }
    }

    private var flowsDir: URL { root.appendingPathComponent("flows", isDirectory: true) }
    var templatesDir: URL { root.appendingPathComponent("templates", isDirectory: true) }
    private var snapshotsDir: URL { root.appendingPathComponent("snapshots", isDirectory: true) }
    private var corruptDir: URL { root.appendingPathComponent("corrupt", isDirectory: true) }

    private func ensureDirs() throws {
        for dir in [root, flowsDir, templatesDir, snapshotsDir, corruptDir] {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func flowURL(_ id: UUID) -> URL { flowsDir.appendingPathComponent("\(id.uuidString).json") }

    // MARK: - Flow CRUD

    func save(_ graph: WorkflowGraph) throws {
        try ensureDirs()
        let url = flowURL(graph.id)
        let data = try JSONEncoder.fusionWorkflow.encode(graph)
        // 原子写 (审计 F-I6 临时文件范式: .atomic)
        try data.write(to: url, options: .atomic)
        flowStoreLog.info("flow saved id=\(graph.id.uuidString) name=\(graph.name, privacy: .public) nodes=\(graph.nodes.count)")
        // 每次保存追加版本快照 (#426 per-flow version snapshots)
        try appendSnapshot(graph)
    }

    func load(_ id: UUID) throws -> WorkflowGraph {
        let url = flowURL(id)
        do {
            return try JSONDecoder.fusionWorkflow.decode(WorkflowGraph.self, from: Data(contentsOf: url))
        } catch {
            // 损坏文件 → 移 corrupt/ 留现场, 显式抛错 (验收: corrupt-file recovery, fail visibly)
            try? ensureDirs()
            let dead = corruptDir.appendingPathComponent("\(id.uuidString)-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: dead)
            flowStoreLog.error("flow load corrupt, quarantined: \(dead.path, privacy: .public) err=\(error.localizedDescription, privacy: .public)")
            throw WorkflowError.corruptFlowFile(dead.path)
        }
    }

    func listFlows() throws -> [WorkflowGraph] {
        try ensureDirs()
        let files = try FileManager.default.contentsOfDirectory(at: flowsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        var out: [WorkflowGraph] = []
        for f in files {
            do {
                out.append(try JSONDecoder.fusionWorkflow.decode(WorkflowGraph.self, from: Data(contentsOf: f)))
            } catch {
                // 列表读取容忍单个损坏 (隔离 + 日志, 不阻断其余 flow)
                let dead = corruptDir.appendingPathComponent("list-\(f.lastPathComponent)")
                try? FileManager.default.moveItem(at: f, to: dead)
                flowStoreLog.error("flow list entry corrupt, quarantined: \(dead.path, privacy: .public)")
            }
        }
        return out.sorted { $0.name < $1.name }
    }

    func delete(_ id: UUID) throws {
        try FileManager.default.removeItem(at: flowURL(id))
        try? FileManager.default.removeItem(at: snapshotsDir.appendingPathComponent(id.uuidString))
        flowStoreLog.info("flow deleted id=\(id.uuidString)")
    }

    // MARK: - Snapshots (per-flow version list, #426)

    private func appendSnapshot(_ graph: WorkflowGraph) throws {
        let dir = snapshotsDir.appendingPathComponent(graph.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ts = Int(Date().timeIntervalSince1970)
        let url = dir.appendingPathComponent("\(ts)-\(graph.name.isEmpty ? "untitled" : graph.name).json")
        try JSONEncoder.fusionWorkflow.encode(graph).write(to: url, options: .atomic)
        // 快照 LRU cap 20 (审计 P1 LRU cap 范式, 防无界增长)
        let snaps = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "json" }
            .sorted { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                < (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
        if snaps.count > 20 {
            for old in snaps.prefix(snaps.count - 20) {
                try? FileManager.default.removeItem(at: old)
            }
        }
    }

    func snapshots(for id: UUID) throws -> [WorkflowGraph] {
        let dir = snapshotsDir.appendingPathComponent(id.uuidString, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "json" }
            // 按 mtime 新→旧 (文件名时间戳秒级碰撞时 lastPathComponent 排序不可靠)
            .sorted { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                > (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
            .compactMap { try? JSONDecoder.fusionWorkflow.decode(WorkflowGraph.self, from: Data(contentsOf: $0)) }
    }

    // 回滚到某快照: 读快照 → 作为当前 flow 保存 (再次产生新快照, 可逆)
    func restore(_ snapshot: WorkflowGraph) throws {
        var g = snapshot
        g.id = snapshot.id
        try save(g)
        flowStoreLog.info("flow restored id=\(g.id.uuidString)")
    }

    // MARK: - Templates (P1 hook, P3 #431 gallery 复用)

    func saveAsTemplate(_ graph: WorkflowGraph, templateName: String) throws {
        try ensureDirs()
        var t = graph
        t.name = templateName
        let safe = templateName.replacingOccurrences(of: "/", with: "_")
        let url = templatesDir.appendingPathComponent("\(safe).json")
        try JSONEncoder.fusionWorkflow.encode(t).write(to: url, options: .atomic)
        flowStoreLog.info("template saved name=\(templateName, privacy: .public)")
    }

    func listTemplates() throws -> [WorkflowGraph] {
        try ensureDirs()
        return try FileManager.default.contentsOfDirectory(at: templatesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? JSONDecoder.fusionWorkflow.decode(WorkflowGraph.self, from: Data(contentsOf: $0)) }
    }
}

// MARK: - JSON coding helpers (日期策略固定, 跨版本 forward-compat 走 CodingKeys 演进)

extension JSONEncoder {
    static let fusionWorkflow: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}

extension JSONDecoder {
    static let fusionWorkflow = JSONDecoder()
}
