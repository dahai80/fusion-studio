import Foundation
import os.log

// Callers: TrainerBridge (FusionStudio/System/TrainerBridge.swift).
// Affected API: trainer.* IPC methods over UDS /tmp/fusion-studio.sock → fusion-agent-studio TrainerDispatcher.
// Data schemas: TrainerConfig JSON payload, run/progress/preset/dataset/adapter dicts.
// User instruction: "continue Task" — fusion-trainer RunManager GUI panel (#175)

private let trainerIPCLog = Logger(subsystem: "com.fusion.studio", category: "IPCTrainer")

extension IPCClient {

    // MARK: - Runs (start / list / status / progress / stop)

    func trainerStartSft(config: [String: Any]) async throws -> [String: Any] {
        trainerIPCLog.info("trainer.start_sft")
        return try await call(method: RPCMethod.trainerStartSft, params: ["config": config])
    }

    func trainerStartRlsl(config: [String: Any]) async throws -> [String: Any] {
        trainerIPCLog.info("trainer.start_rlsl")
        return try await call(method: RPCMethod.trainerStartRlsl, params: ["config": config])
    }

    func trainerRunsList(limit: Int = 50) async throws -> [String: Any] {
        return try await call(method: RPCMethod.trainerRunsList, params: ["limit": limit])
    }

    func trainerRunsStatusFull(runId: String) async throws -> [String: Any] {
        return try await call(method: RPCMethod.trainerRunsStatusFull, params: ["run_id": runId])
    }

    func trainerRunsProgress(runId: String, sinceStep: Int = -1) async throws -> [String: Any] {
        return try await call(method: RPCMethod.trainerRunsProgress, params: ["run_id": runId, "since_step": sinceStep])
    }

    func trainerRunsStop(runId: String) async throws -> [String: Any] {
        trainerIPCLog.info("trainer.runs.stop run_id=\(runId, privacy: .public)")
        return try await call(method: RPCMethod.trainerRunsStop, params: ["run_id": runId])
    }

    // MARK: - Presets / datasets / adapters / info

    func trainerPresetsList(kind: String = "") async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if !kind.isEmpty { params["kind"] = kind }
        return try await call(method: RPCMethod.trainerPresetsList, params: params)
    }

    func trainerDatasetsList() async throws -> [String: Any] {
        return try await call(method: RPCMethod.trainerDatasetsList, params: [:])
    }

    func trainerDatasetsPreview(name: String, limit: Int = 5) async throws -> [String: Any] {
        return try await call(method: RPCMethod.trainerDatasetsPreview, params: ["name": name, "limit": limit])
    }

    func trainerAdaptersList(model: String = "") async throws -> [String: Any] {
        var params: [String: Any] = [:]
        if !model.isEmpty { params["model"] = model }
        return try await call(method: RPCMethod.trainerAdaptersList, params: params)
    }

    func trainerAdaptersDelete(name: String) async throws -> [String: Any] {
        trainerIPCLog.info("trainer.adapters.delete name=\(name, privacy: .public)")
        return try await call(method: RPCMethod.trainerAdaptersDelete, params: ["name": name])
    }

    func trainerInfoFull() async throws -> [String: Any] {
        return try await call(method: RPCMethod.trainerInfoFull, params: [:])
    }
}
