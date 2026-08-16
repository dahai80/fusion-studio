// Callers: FusionStudioApp (@StateObject injection), DouyinOperationView (@EnvironmentObject).
// Affected API: DouyinOperationBridge - 读 fusion-operation out/ops/* 业务数据 + IPC graph.create/execute 调 agent-studio 跑抖音运营 DAG。
// Data schemas: DouyinQueueCounts, DouyinWinningPatterns, DouyinStatsSnapshot, DouyinQueueItem。
// User instruction: "fusion-operation 是业务层，调 fusion-xx 完成业务；fusion-studio 负责 GUI" + ~/operation/reconstruct-operation.md Phase 4。

import Foundation
import Combine
import os.log

private let douyinBridgeLog = Logger(subsystem: "com.fusion.studio", category: "DouyinOperationBridge")

struct DouyinQueueCounts: Hashable {
    var pending: Int = 0
    var published: Int = 0
    var failed: Int = 0
}

struct DouyinQueueItem: Identifiable, Hashable {
    let id: String
    let title: String
    let status: String
    let hookVariant: String
    let createdAt: Double
    let videoPath: String
    let hasVideo: Bool
}

struct DouyinStatsSnapshot: Identifiable, Hashable {
    let id: String
    let vid: String
    let title: String
    let plays: Int
    let likes: Int
    let comments: Int
    let shares: Int
    let interactionRate: Double
    let stage: String
    let ageHours: Double
    let snapshotAt: String
}

struct DouyinWinningPatterns: Hashable {
    var updatedAt: String = ""
    var samples: Int = 0
    var hotCount: Int = 0
    var winningTopics: [String] = []
    var winningHooks: [String] = []
    var losingPatterns: [String] = []
    var titleFormula: String = ""
}

struct DouyinRunResult: Hashable {
    var graphId: String = ""
    var status: String = ""
    var eventCount: Int = 0
    var success: Bool = false
    var message: String = ""
}

struct DouyinCronJob: Identifiable, Hashable {
    let id: String
    let name: String
    let expression: String
    let graphId: String
    let enabled: Bool
    let nextRun: Double
    let lastRun: Double
    let inputData: String
}

struct DouyinCronExecution: Identifiable, Hashable {
    let id: String
    let jobId: String
    let startedAt: Double
    let finishedAt: Double
    let status: String
    let error: String
    let resultPreview: String
}

class DouyinOperationBridge: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    @Published var isLoading: Bool = false

    @Published var queueCounts: DouyinQueueCounts = DouyinQueueCounts()
    @Published var pendingItems: [DouyinQueueItem] = []
    @Published var publishedItems: [DouyinQueueItem] = []
    @Published var failedItems: [DouyinQueueItem] = []

    @Published var winning: DouyinWinningPatterns = DouyinWinningPatterns()
    @Published var statsSnapshots: [DouyinStatsSnapshot] = []
    @Published var repliedIds: [String] = []

    @Published var lastRunResult: DouyinRunResult?
    @Published var runningAction: String = ""

    @Published var cronJobs: [DouyinCronJob] = []
    @Published var cronExecutions: [DouyinCronExecution] = []
    @Published var cronLoading: Bool = false

    @Published var opsRoot: String

    private var graphIdCache: [String: String] = [:]

    private let fileManager = FileManager.default
    private var pollTimer: Timer?

    init(opsRoot: String = "~/fusion/fusion-operation/out") {
        self.opsRoot = (opsRoot as NSString).expandingTildeInPath
        refreshAll()
        douyinBridgeLog.info("DouyinOperationBridge init opsRoot=\(self.opsRoot, privacy: .public)")
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - 路径解析

    private var queueDir: String { "\(opsRoot)/queue" }
    private var opsDir: String { "\(opsRoot)/ops" }
    private var pendingDir: String { "\(queueDir)/pending" }
    private var publishedDir: String { "\(queueDir)/published" }
    private var failedDir: String { "\(queueDir)/failed" }
    private var winningPath: String { "\(opsDir)/winning_patterns.json" }
    private var statsPath: String { "\(opsDir)/stats_history.jsonl" }
    private var repliedPath: String { "\(opsDir)/replied.json" }

    var graphsDir: String {
        let root = (opsRoot as NSString).deletingLastPathComponent
        return "\(root)/graphs"
    }

    private func graphPath(_ name: String) -> String { "\(graphsDir)/\(name).json" }

    // MARK: - 全量刷新（读盘）

    func refreshAll() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let pending = self.readQueueItems(dir: self.pendingDir)
            let published = self.readQueueItems(dir: self.publishedDir)
            let failed = self.readQueueItems(dir: self.failedDir)
            var counts = DouyinQueueCounts()
            counts.pending = pending.count
            counts.published = published.count
            counts.failed = failed.count

            var win = DouyinWinningPatterns()
            if let data = self.readFile(self.winningPath) {
                win = self.parseWinning(data) ?? DouyinWinningPatterns()
            }
            var snaps: [DouyinStatsSnapshot] = []
            if let data = self.readFile(self.statsPath) {
                snaps = self.parseStatsHistory(data)
            }
            var replied: [String] = []
            if let data = self.readFile(self.repliedPath) {
                replied = self.parseReplied(data)
            }

            let connected = self.fileManager.fileExists(atPath: self.opsDir)
            var err: String?
            if !connected {
                err = "未找到 \(self.opsDir)，请确认 fusion-operation 已运行并产出 out/ 数据"
            }

            DispatchQueue.main.async {
                self.queueCounts = counts
                self.pendingItems = Array(pending.prefix(20))
                self.publishedItems = Array(published.prefix(20))
                self.failedItems = Array(failed.prefix(20))
                self.winning = win
                self.statsSnapshots = snaps
                self.repliedIds = replied
                self.isConnected = connected
                self.lastError = err
                douyinBridgeLog.info("DouyinOperationBridge refresh: pending=\(counts.pending) published=\(counts.published) failed=\(counts.failed) snaps=\(snaps.count)")
            }
        }
    }

    // MARK: - 文件读取

    private func readFile(_ path: String) -> Data? {
        guard fileManager.fileExists(atPath: path) else { return nil }
        return fileManager.contents(atPath: path)
    }

    private func readQueueItems(dir: String) -> [DouyinQueueItem] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: dir) else { return [] }
        var items: [DouyinQueueItem] = []
        for name in names where name.hasSuffix(".json") {
            let path = "\(dir)/\(name)"
            guard let data = fileManager.contents(atPath: path),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            let id = obj["id"] as? String ?? name
            let title = (obj["title"] as? String) ?? (obj["topic"] as? String) ?? name
            let status = obj["status"] as? String ?? "unknown"
            let variant = obj["hook_variant"] as? String ?? "-"
            let createdAt = (obj["created_at"] as? Double) ?? 0
            let videoPath = obj["video_path"] as? String ?? ""
            let hasVideo = !videoPath.isEmpty && fileManager.fileExists(atPath: videoPath)
            items.append(DouyinQueueItem(
                id: id, title: title, status: status, hookVariant: variant,
                createdAt: createdAt, videoPath: videoPath, hasVideo: hasVideo
            ))
        }
        items.sort { $0.createdAt > $1.createdAt }
        return items
    }

    private func parseWinning(_ data: Data) -> DouyinWinningPatterns? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var w = DouyinWinningPatterns()
        w.updatedAt = obj["updated_at"] as? String ?? ""
        w.samples = (obj["samples"] as? Int) ?? 0
        w.hotCount = (obj["hot_count"] as? Int) ?? 0
        w.winningTopics = obj["winning_topics"] as? [String] ?? []
        w.winningHooks = obj["winning_hooks"] as? [String] ?? []
        w.losingPatterns = obj["losing_patterns"] as? [String] ?? []
        w.titleFormula = obj["title_formula"] as? String ?? ""
        return w
    }

    private func parseStatsHistory(_ data: Data) -> [DouyinStatsSnapshot] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var latest: [String: DouyinStatsSnapshot] = [:]
        for line in text.split(separator: "\n") {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }
            let vid = obj["vid"] as? String ?? ""
            guard !vid.isEmpty else { continue }
            let snap = DouyinStatsSnapshot(
                id: "\(vid)_\(obj["snapshot_at"] as? String ?? "")",
                vid: vid,
                title: obj["title"] as? String ?? "",
                plays: (obj["plays"] as? Int) ?? 0,
                likes: (obj["likes"] as? Int) ?? 0,
                comments: (obj["comments"] as? Int) ?? 0,
                shares: (obj["shares"] as? Int) ?? 0,
                interactionRate: (obj["interaction_rate"] as? Double) ?? 0,
                stage: obj["stage"] as? String ?? "",
                ageHours: (obj["age_hours"] as? Double) ?? 0,
                snapshotAt: obj["snapshot_at"] as? String ?? ""
            )
            latest[vid] = snap
        }
        var arr = Array(latest.values)
        arr.sort { $0.plays > $1.plays }
        return arr
    }

    private func parseReplied(_ data: Data) -> [String] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        return obj["replied_ids"] as? [String] ?? []
    }

    // MARK: - 执行运营 DAG（IPC graph.create + graph.execute）

    func runGraph(
        graphName: String,
        variables: [String: Any] = [:],
        input: String = "",
        actionLabel: String,
        ipc: IPCClient?
    ) {
        guard let ipc = ipc else {
            publishError("IPC 未连接，无法调用 agent-studio")
            return
        }
        DispatchQueue.main.async {
            self.runningAction = actionLabel
            self.isLoading = true
            self.lastError = nil
        }
        douyinBridgeLog.info("runGraph start: \(graphName, privacy: .public) action=\(actionLabel, privacy: .public) vars=\(variables.keys, privacy: .public)")

        Task {
            do {
                let graphId = try await ensureGraph(graphName: graphName, ipc: ipc)
                var params: [String: Any] = ["graph_id": graphId]
                if !input.isEmpty { params["input"] = input }
                if !variables.isEmpty { params["variables"] = variables }
                let resp = try await ipc.call(method: "graph.execute", params: params)
                let status = resp["status"] as? String ?? "unknown"
                let events = resp["events"] as? [Any] ?? []
                let ok = status == "completed"
                let result = DouyinRunResult(
                    graphId: graphId,
                    status: status,
                    eventCount: events.count,
                    success: ok,
                    message: ok ? "执行完成，共 \(events.count) 个事件" : "执行状态: \(status)"
                )
                DispatchQueue.main.async {
                    self.lastRunResult = result
                    self.isLoading = false
                    self.runningAction = ""
                    self.refreshAll()
                }
                douyinBridgeLog.info("runGraph done: \(graphName, privacy: .public) status=\(status, privacy: .public) events=\(events.count)")
            } catch {
                self.publishError("runGraph \(graphName) 失败: \(error.localizedDescription)")
            }
        }
    }

    private func ensureGraph(graphName: String, ipc: IPCClient) async throws -> String {
        if let cached = graphIdCache[graphName], !cached.isEmpty {
            return cached
        }
        let path = graphPath(graphName)
        guard let data = readFile(path) else {
            throw NSError(domain: "DouyinOperationBridge", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Graph 文件不存在: \(path)"])
        }
        guard let graphData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "DouyinOperationBridge", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Graph JSON 解析失败: \(path)"])
        }
        let resp = try await ipc.call(method: "graph.create", params: [
            "name": graphName,
            "graph_data": graphData,
        ])
        guard let graphId = resp["graph_id"] as? String, !graphId.isEmpty else {
            throw NSError(domain: "DouyinOperationBridge", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "graph.create 未返回 graph_id"])
        }
        graphIdCache[graphName] = graphId
        douyinBridgeLog.info("ensureGraph created: \(graphName, privacy: .public) -> \(graphId, privacy: .public)")
        return graphId
    }

    // MARK: - 便捷动作

    func produceOne(topic: String, hookVariant: String, ipc: IPCClient?) {
        var vars: [String: Any] = ["hook_variant": hookVariant]
        if !topic.isEmpty { vars["topic"] = topic }
        runGraph(graphName: "douyin_batch_produce", variables: vars,
                 actionLabel: "造片（\(hookVariant)）", ipc: ipc)
    }

    func publishFromQueue(dryRun: Bool, ipc: IPCClient?) {
        runGraph(graphName: "douyin_queue_publish",
                 variables: ["dry_run": dryRun ? "true" : "false"],
                 actionLabel: dryRun ? "发布(dry_run)" : "真实发布", ipc: ipc)
    }

    func replyComments(ipc: IPCClient?) {
        runGraph(graphName: "douyin_comment_reply", actionLabel: "评论回复", ipc: ipc)
    }

    func evolve(ipc: IPCClient?) {
        runGraph(graphName: "douyin_evolve", actionLabel: "进化分析", ipc: ipc)
    }

    func repairPublish(ipc: IPCClient?) {
        runGraph(graphName: "douyin_repair_publish", actionLabel: "差片修复", ipc: ipc)
    }

    // MARK: - 发布计划（cron 调度，agent-studio issue #139 → PR #140）

    // 抖音运营 cron job id 前缀, 用于从全部 cron job 中筛出本看板注册的计划.
    static let cronIdPrefix = "douyin_publish_plan_"

    // Graph D 库存发布 graph 名, cron 计划绑定它.
    static let publishGraphName = "douyin_queue_publish"

    // 高峰时段发布计划默认 cron: 每天两个高峰窗口各发 1 条 (12:05 / 19:05).
    static let defaultPeakCron = "5 12,19 * * *"

    func registerPublishPlan(expression: String, dryRun: Bool, ipc: IPCClient?) {
        guard let ipc = ipc else {
            publishError("IPC 未连接，无法注册发布计划")
            return
        }
        DispatchQueue.main.async {
            self.cronLoading = true
            self.lastError = nil
        }
        let inputData = "{\"dry_run\":\"\(dryRun ? "true" : "false")\"}"
        douyinBridgeLog.info("registerPublishPlan: expr=\(expression, privacy: .public) dryRun=\(dryRun)")
        Task {
            do {
                let graphId = try await ensureGraph(graphName: Self.publishGraphName, ipc: ipc)
                let jobId = Self.cronIdPrefix + expression.replacingOccurrences(of: " ", with: "_")
                let resp = try await ipc.call(method: "cron.register", params: [
                    "id": jobId,
                    "name": "抖音高峰发布计划",
                    "expression": expression,
                    "graph_id": graphId,
                    "input_data": inputData,
                    "enabled": true,
                    "max_retries": 0,
                ])
                let ok = (resp["status"] as? String) == "ok"
                DispatchQueue.main.async {
                    self.cronLoading = false
                    self.lastRunResult = DouyinRunResult(
                        graphId: graphId,
                        status: ok ? "registered" : "failed",
                        eventCount: 0,
                        success: ok,
                        message: ok ? "发布计划已注册，等待高峰时段自动触发" : "注册失败"
                    )
                    self.refreshCron(ipc: ipc)
                }
            } catch {
                self.publishError("注册发布计划失败: \(error.localizedDescription)")
            }
        }
    }

    func unregisterPlan(jobId: String, ipc: IPCClient?) {
        guard let ipc = ipc else { return }
        DispatchQueue.main.async { self.cronLoading = true }
        douyinBridgeLog.info("unregisterPlan: \(jobId, privacy: .public)")
        Task {
            do {
                _ = try await ipc.call(method: "cron.unregister", params: ["id": jobId])
                DispatchQueue.main.async {
                    self.cronLoading = false
                    self.refreshCron(ipc: ipc)
                }
            } catch {
                self.publishError("取消计划失败: \(error.localizedDescription)")
            }
        }
    }

    func refreshCron(ipc: IPCClient?) {
        guard let ipc = ipc else { return }
        Task {
            do {
                let result = try await ipc.call(method: "cron.list", params: [:])
                let raw = (result["jobs"] as? [[String: Any]]) ?? []
                let jobs: [DouyinCronJob] = raw.compactMap { parseCronJob($0) }
                    .filter { $0.id.hasPrefix(Self.cronIdPrefix) }
                DispatchQueue.main.async { self.cronJobs = jobs }
                if let first = jobs.first {
                    let exeResult = try await ipc.call(method: "cron.list_executions", params: ["job_id": first.id, "limit": 20])
                    let exes = ((exeResult["executions"] as? [[String: Any]]) ?? []).compactMap { parseCronExecution($0) }
                    DispatchQueue.main.async { self.cronExecutions = exes }
                } else {
                    DispatchQueue.main.async { self.cronExecutions = [] }
                }
            } catch {
                douyinBridgeLog.error("refreshCron failed: \(error, privacy: .public)")
            }
        }
    }

    private func parseCronJob(_ obj: [String: Any]) -> DouyinCronJob? {
        guard let id = obj["id"] as? String else { return nil }
        return DouyinCronJob(
            id: id,
            name: obj["name"] as? String ?? "",
            expression: obj["expression"] as? String ?? "",
            graphId: obj["graph_id"] as? String ?? "",
            enabled: obj["enabled"] as? Bool ?? true,
            nextRun: (obj["next_run"] as? Double) ?? 0,
            lastRun: (obj["last_run"] as? Double) ?? 0,
            inputData: obj["input_data"] as? String ?? ""
        )
    }

    private func parseCronExecution(_ obj: [String: Any]) -> DouyinCronExecution? {
        guard let id = obj["id"] as? String else { return nil }
        return DouyinCronExecution(
            id: id,
            jobId: obj["job_id"] as? String ?? "",
            startedAt: (obj["started_at"] as? Double) ?? 0,
            finishedAt: (obj["finished_at"] as? Double) ?? 0,
            status: obj["status"] as? String ?? "",
            error: obj["error"] as? String ?? "",
            resultPreview: obj["result_preview"] as? String ?? ""
        )
    }

    // MARK: - 轮询

    func startPolling(interval: TimeInterval = 30) {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
        douyinBridgeLog.info("Polling started (\(interval)s)")
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func publishError(_ msg: String) {
        douyinBridgeLog.error("\(msg, privacy: .public)")
        DispatchQueue.main.async {
            self.lastError = msg
            self.isLoading = false
            self.runningAction = ""
        }
    }
}
