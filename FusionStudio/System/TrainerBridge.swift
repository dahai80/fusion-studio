import Foundation
import os.log

// Callers: TrainerView + subviews (FusionStudio/Modules/Trainer/), FusionStudioApp.swift injection.
// Affected API: TrainerBridge @MainActor ObservableObject — wraps trainer.* IPC methods on IPCClient.
// Data schemas: TrainerRun / TrainerPreset / TrainerDataset / TrainerAdapter / progress-event dicts from fusion-agent-studio TrainerDispatcher → fusion-trainer RunManager.
// User instruction: "continue Task" — fusion-trainer RunManager GUI panel (#175)

struct TrainerRun: Codable, Identifiable, Hashable {
    var id: String { run_id }
    var run_id: String
    var method: String
    var model: String
    var status: String
    var created_at: String
    var progress: Double
    var current_step: Int
    var total_steps: Int
    var error: String?

    static func from(_ d: [String: Any]) -> TrainerRun {
        let total = d["total_steps"] as? Int ?? 0
        let step = d["step"] as? Int ?? d["current_step"] as? Int ?? 0
        let progress: Double
        if let p = d["progress"] as? Double {
            progress = p
        } else if total > 0 {
            progress = Double(step) / Double(total)
        } else {
            progress = 0
        }
        let createdStr: String
        if let s = d["created_at"] as? String {
            createdStr = s
        } else if let epoch = d["created"] as? Int {
            createdStr = TrainerRun.formatEpoch(epoch)
        } else if let epoch = d["created"] as? Double {
            createdStr = TrainerRun.formatEpoch(Int(epoch))
        } else {
            createdStr = ""
        }
        return TrainerRun(
            run_id: d["run_id"] as? String ?? "",
            method: d["method"] as? String ?? "",
            model: d["model"] as? String ?? "",
            status: d["status"] as? String ?? "unknown",
            created_at: createdStr,
            progress: progress,
            current_step: step,
            total_steps: total,
            error: d["error"] as? String
        )
    }

    private static func formatEpoch(_ epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }
}

struct TrainerPreset: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var kind: String
    var memory_estimate_gb: Double
    var summary: String
    var config: [String: TrainerAnyCodable]

    static func from(_ d: [String: Any]) -> TrainerPreset {
        TrainerPreset(
            name: d["name"] as? String ?? "",
            kind: d["kind"] as? String ?? "",
            memory_estimate_gb: d["memory_estimate_gb"] as? Double ?? 0,
            summary: d["summary"] as? String ?? "",
            config: TrainerAnyCodable.from(d["config"] as? [String: Any] ?? [:])
        )
    }
}

struct TrainerDataset: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var path: String
    var samples: Int
    var format: String

    static func from(_ d: [String: Any]) -> TrainerDataset {
        TrainerDataset(
            name: d["name"] as? String ?? "",
            path: d["path"] as? String ?? "",
            samples: d["samples"] as? Int ?? 0,
            format: d["format"] as? String ?? ""
        )
    }
}

struct TrainerAdapter: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var model: String
    var path: String
    var method: String

    static func from(_ d: [String: Any]) -> TrainerAdapter {
        TrainerAdapter(
            name: d["name"] as? String ?? "",
            model: d["model"] as? String ?? "",
            path: d["path"] as? String ?? "",
            method: d["method"] as? String ?? ""
        )
    }
}

struct TrainerProgressEvent: Codable, Identifiable, Hashable {
    var id: Int { step }
    var step: Int
    var metric: String
    var value: Double
    var ts: String

    static func from(_ d: [String: Any]) -> TrainerProgressEvent {
        let step = d["step"] as? Int ?? 0
        // 优先用已归一化的 metric/value (旧客户端格式)
        if let metric = d["metric"] as? String, !metric.isEmpty {
            let value: Double
            if let v = d["value"] as? Double { value = v }
            else if let v = d["value"] as? Int { value = Double(v) }
            else { value = 0 }
            return TrainerProgressEvent(
                step: step, metric: metric, value: value,
                ts: d["ts"] as? String ?? ""
            )
        }
        // 归一化原始 fusion-mlx event (RunManager run_progress 原样透传):
        // type=train_loss → metric="train_loss", value=train_loss
        // type=val_loss   → metric="val_loss",   value=val_loss
        if let type = d["type"] as? String {
            let metric = type
            let value: Double
            if let v = d[metric] as? Double { value = v }
            else if let v = d[metric] as? Int { value = Double(v) }
            else { value = 0 }
            return TrainerProgressEvent(
                step: step, metric: metric, value: value,
                ts: d["ts"] as? String ?? ""
            )
        }
        return TrainerProgressEvent(step: step, metric: "", value: 0, ts: d["ts"] as? String ?? "")
    }
}

// Lightweight Any wrapper for nested config dicts coming back over IPC.
// Renamed TrainerAnyCodable to avoid collision with MultiNode.AnyCodable.
struct TrainerAnyCodable: Codable, Hashable {
    let value: Any
    static func from(_ d: [String: Any]) -> [String: TrainerAnyCodable] {
        d.reduce(into: [String: TrainerAnyCodable]()) { acc, kv in
            acc[kv.key] = TrainerAnyCodable(value: kv.value)
        }
    }
    init(value: Any) { self.value = value }
    init(from decoder: Decoder) throws { self.value = try decoder.singleValueContainer().decode(TrainerAnyDecodable.self).value }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if let v = value as? String { try c.encode(v) }
        else if let v = value as? Double { try c.encode(v) }
        else if let v = value as? Int { try c.encode(v) }
        else if let v = value as? Bool { try c.encode(v) }
        else { try c.encodeNil() }
    }
    func hash(into hasher: inout Hasher) { hasher.combine(String(describing: value)) }
    static func == (lhs: TrainerAnyCodable, rhs: TrainerAnyCodable) -> Bool { String(describing: lhs.value) == String(describing: rhs.value) }
}

private struct TrainerAnyDecodable: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { self.value = v }
        else if let v = try? c.decode(Double.self) { self.value = v }
        else if let v = try? c.decode(Bool.self) { self.value = v }
        else { self.value = "" }
    }
}

@MainActor
final class TrainerBridge: ObservableObject {

    @Published var isConnected: Bool = false
    @Published var runs: [TrainerRun] = []
    @Published var selectedRun: TrainerRun?
    @Published var progressEvents: [TrainerProgressEvent] = []
    @Published var presets: [TrainerPreset] = []
    @Published var datasets: [TrainerDataset] = []
    @Published var adapters: [TrainerAdapter] = []
    @Published var datasetPreview: String = ""
    @Published var info: [String: TrainerAnyCodable] = [:]
    @Published var isStarting: Bool = false
    @Published var isPolling: Bool = false
    @Published var lastError: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "TrainerBridge")
    private var ipcClient: IPCClient?
    private var pollTask: Task<Void, Never>?
    private var lastSeenStep: Int = -1

    func setIPCClient(_ client: IPCClient) {
        self.ipcClient = client
        client.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
        logger.info("TrainerBridge connected to IPCClient")
    }

    // MARK: - Runs

    func refreshRuns(limit: Int = 50) async {
        guard let client = ipcClient else { logger.warning("refreshRuns: no ipcClient"); return }
        do {
            let result = try await client.trainerRunsList(limit: limit)
            let list = (result["runs"] as? [[String: Any]] ?? []).map { TrainerRun.from($0) }
            self.runs = list
            logger.info("refreshRuns: \(list.count) runs")
        } catch {
            self.lastError = "runs.list: \(error.localizedDescription)"
            logger.error("refreshRuns: \(error)")
        }
    }

    func selectRun(_ run: TrainerRun?) {
        selectedRun = run
        progressEvents = []
        lastSeenStep = -1
        guard let run = run else { return }
        Task { await fetchFullStatus(runId: run.run_id) }
    }

    func fetchFullStatus(runId: String) async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.trainerRunsStatusFull(runId: runId)
            // RunManager 返回顶层平铺 dict (无 "run" 包装); 兼容旧带包装的返回
            let runDict = (result["run"] as? [String: Any]) ?? result
            if runDict["run_id"] != nil {
                let updated = TrainerRun.from(runDict)
                if let idx = runs.firstIndex(where: { $0.run_id == runId }) {
                    runs[idx] = updated
                }
                if selectedRun?.run_id == runId { selectedRun = updated }
            }
            logger.info("fetchFullStatus: \(runId)")
        } catch {
            self.lastError = "runs.status_full: \(error.localizedDescription)"
            logger.error("fetchFullStatus: \(error)")
        }
    }

    func startPollingProgress(runId: String) {
        stopPollingProgress()
        isPolling = true
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollProgressOnce(runId: runId)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self = self, let sel = self.selectedRun, sel.run_id == runId else { break }
                if sel.status == "completed" || sel.status == "failed" || sel.status == "stopped" { break }
            }
            // 审计0827 #15: TrainerBridge 类已 @MainActor, pollTask Task 继承调用方 MainActor 上下文, MainActor.run 冗余, 直接赋值。
            self?.isPolling = false
        }
    }

    func stopPollingProgress() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }

    private func pollProgressOnce(runId: String) async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.trainerRunsProgress(runId: runId, sinceStep: lastSeenStep)
            let events = (result["events"] as? [[String: Any]] ?? []).map { TrainerProgressEvent.from($0) }
            if let last = events.last { lastSeenStep = max(lastSeenStep, last.step) }
            if !events.isEmpty {
                progressEvents.append(contentsOf: events)
                // F-perf-1: progressEvents 无界增长 (长训练 1k+ steps) → 内存膨胀。
                // 保留最近 500 (镜像 StreamingBridge/DocBridge suffix cap 模式)。
                if progressEvents.count > 500 {
                    progressEvents = Array(progressEvents.suffix(500))
                }
            }
            // RunManager run_progress 返回顶层平铺 (run_id/status), 无 "run" 包装; 兼容旧返回
            let runDict = (result["run"] as? [String: Any]) ?? result
            if runDict["run_id"] != nil {
                let updated = TrainerRun.from(runDict)
                if let idx = runs.firstIndex(where: { $0.run_id == runId }) { runs[idx] = updated }
                if selectedRun?.run_id == runId { selectedRun = updated }
            }
            logger.info("pollProgressOnce: \(runId) +\(events.count) events")
        } catch {
            logger.error("pollProgressOnce: \(error)")
        }
    }

    func stopRun(runId: String) async {
        guard let client = ipcClient else { return }
        do {
            _ = try await client.trainerRunsStop(runId: runId)
            await fetchFullStatus(runId: runId)
            logger.info("stopRun: \(runId)")
        } catch {
            self.lastError = "runs.stop: \(error.localizedDescription)"
            logger.error("stopRun: \(error)")
        }
    }

    func startSft(config: [String: Any]) async {
        guard let client = ipcClient else { return }
        isStarting = true
        defer { isStarting = false }
        do {
            let result = try await client.trainerStartSft(config: config)
            if let runId = result["run_id"] as? String {
                await refreshRuns()
                if let run = runs.first(where: { $0.run_id == runId }) { selectRun(run) }
                startPollingProgress(runId: runId)
                logger.info("startSft: \(runId, privacy: .public)")
            }
        } catch {
            self.lastError = "start_sft: \(error.localizedDescription)"
            logger.error("startSft: \(error)")
        }
    }

    func startRlsl(config: [String: Any]) async {
        guard let client = ipcClient else { return }
        isStarting = true
        defer { isStarting = false }
        do {
            let result = try await client.trainerStartRlsl(config: config)
            if let runId = result["run_id"] as? String {
                await refreshRuns()
                if let run = runs.first(where: { $0.run_id == runId }) { selectRun(run) }
                startPollingProgress(runId: runId)
                logger.info("startRlsl: \(runId, privacy: .public)")
            }
        } catch {
            self.lastError = "start_rlsl: \(error.localizedDescription)"
            logger.error("startRlsl: \(error)")
        }
    }

    // MARK: - Registry

    func refreshPresets(kind: String = "") async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.trainerPresetsList(kind: kind)
            let list = (result["presets"] as? [[String: Any]] ?? []).map { TrainerPreset.from($0) }
            self.presets = list
            logger.info("refreshPresets: \(list.count)")
        } catch {
            self.lastError = "presets.list: \(error.localizedDescription)"
            logger.error("refreshPresets: \(error)")
        }
    }

    func refreshDatasets() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.trainerDatasetsList()
            let list = (result["datasets"] as? [[String: Any]] ?? []).map { TrainerDataset.from($0) }
            self.datasets = list
            logger.info("refreshDatasets: \(list.count)")
        } catch {
            self.lastError = "datasets.list: \(error.localizedDescription)"
            logger.error("refreshDatasets: \(error)")
        }
    }

    func previewDataset(name: String, limit: Int = 5) async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.trainerDatasetsPreview(name: name, limit: limit)
            if let samples = result["samples"] as? [Any] {
                let data = try JSONSerialization.data(withJSONObject: samples, options: [.prettyPrinted])
                self.datasetPreview = String(data: data, encoding: .utf8) ?? ""
            } else if let raw = result["preview"] as? String {
                self.datasetPreview = raw
            }
            logger.info("previewDataset: \(name)")
        } catch {
            self.lastError = "datasets.preview: \(error.localizedDescription)"
            logger.error("previewDataset: \(error)")
        }
    }

    func refreshAdapters(model: String = "") async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.trainerAdaptersList(model: model)
            let list = (result["adapters"] as? [[String: Any]] ?? []).map { TrainerAdapter.from($0) }
            self.adapters = list
            logger.info("refreshAdapters: \(list.count)")
        } catch {
            self.lastError = "adapters.list: \(error.localizedDescription)"
            logger.error("refreshAdapters: \(error)")
        }
    }

    func deleteAdapter(name: String) async {
        guard let client = ipcClient else { return }
        do {
            _ = try await client.trainerAdaptersDelete(name: name)
            await refreshAdapters()
            logger.info("deleteAdapter: \(name)")
        } catch {
            self.lastError = "adapters.delete: \(error.localizedDescription)"
            logger.error("deleteAdapter: \(error)")
        }
    }

    func refreshInfo() async {
        guard let client = ipcClient else { return }
        do {
            let result = try await client.trainerInfoFull()
            self.info = TrainerAnyCodable.from(result)
            logger.info("refreshInfo")
        } catch {
            self.lastError = "info_full: \(error.localizedDescription)"
            logger.error("refreshInfo: \(error)")
        }
    }
}
