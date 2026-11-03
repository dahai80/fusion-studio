import Foundation
import os.log

// #432 P3-2: 运行历史 + 回放 diff (plan §7.3)。
//   WorkflowRunRecord 落 runs/<flowId>.json (数组 cap 20, LRU); LocalExecutor 每轮收尾追加;
//   diff: 两轮 nodeStatuses 逐节点比对 (same/changed/onlyA/onlyB)。

private let runHistLog = Logger(subsystem: "com.fusion.studio", category: "RunHistory")

struct WorkflowRunRecord: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var startedAt: Double
    var finishedAt: Double
    var summary: String
    var ok: Bool
    // nodeId → 终态 ("finished:<output前80字>" / "error:<msg前80字>")
    var nodeStatuses: [String: String]

    init(id: String, startedAt: Double, finishedAt: Double, summary: String, ok: Bool, nodeStatuses: [String: String]) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.summary = summary
        self.ok = ok
        self.nodeStatuses = nodeStatuses
    }
}

// 运行间 diff (replay 对比)
enum RunDiff {
    enum Row: Equatable {
        case same(nodeId: String, value: String)
        case changed(nodeId: String, before: String, after: String)
        case onlyA(nodeId: String, value: String)
        case onlyB(nodeId: String, value: String)
    }

    static func compare(_ a: WorkflowRunRecord, _ b: WorkflowRunRecord) -> [Row] {
        var rows: [Row] = []
        let ids = Set(a.nodeStatuses.keys).union(b.nodeStatuses.keys).sorted()
        for id in ids {
            switch (a.nodeStatuses[id], b.nodeStatuses[id]) {
            case let (va?, vb?) where va == vb:
                rows.append(.same(nodeId: id, value: va))
            case let (va?, vb?):
                rows.append(.changed(nodeId: id, before: va, after: vb))
            case let (va?, nil):
                rows.append(.onlyA(nodeId: id, value: va))
            case let (nil, vb?):
                rows.append(.onlyB(nodeId: id, value: vb))
            default:
                break
            }
        }
        return rows
    }
}

// 存储: <root>/runs/<flowId>.json — [WorkflowRunRecord] (cap 20)
struct RunHistoryStore {
    let root: URL

    init(root: URL? = nil) {
        if let root = root {
            self.root = root
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.root = base.appendingPathComponent("FusionStudio/workflows/runs", isDirectory: true)
        }
    }

    private func url(_ flowId: UUID) -> URL { root.appendingPathComponent("\(flowId.uuidString).json") }

    func append(_ flowId: UUID, _ record: WorkflowRunRecord) {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var runs = history(of: flowId)
        runs.insert(record, at: 0)
        if runs.count > 20 {
            runs = Array(runs.prefix(20))
        }
        do {
            try JSONEncoder().encode(runs).write(to: url(flowId), options: .atomic)
            runHistLog.info("run recorded flow=\(flowId.uuidString.prefix(8)) ok=\(record.ok) nodes=\(record.nodeStatuses.count)")
        } catch {
            runHistLog.error("run record write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func history(of flowId: UUID) -> [WorkflowRunRecord] {
        guard let data = try? Data(contentsOf: url(flowId)),
              let runs = try? JSONDecoder().decode([WorkflowRunRecord].self, from: data) else {
            return []
        }
        return runs
    }
}
