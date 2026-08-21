import XCTest
@testable import FusionStudio

// Callers: UnitTests target (Package.swift .testTarget UnitTests).
// Affected API: TrainerRun/TrainerPreset/TrainerDataset/TrainerAdapter/TrainerProgressEvent model parsing.
// Data schemas: dicts matching fusion-agent-studio TrainerDispatcher → fusion-trainer RunManager output.
// User instruction: "continue Task" — Task #5 (#175) trainer GUI panel

final class TrainerModelParsingTests: XCTestCase {

    func testTrainerRunFromDict() {
        let d: [String: Any] = [
            "run_id": "run-1", "method": "sft", "model": "qwen2.5-7b-4bit",
            "status": "running", "created_at": "2026-08-18T10:00:00Z",
            "progress": 0.42, "current_step": 42, "total_steps": 100,
        ]
        let run = TrainerRun.from(d)
        XCTAssertEqual(run.run_id, "run-1")
        XCTAssertEqual(run.method, "sft")
        XCTAssertEqual(run.model, "qwen2.5-7b-4bit")
        XCTAssertEqual(run.status, "running")
        XCTAssertEqual(run.progress, 0.42, accuracy: 0.001)
        XCTAssertEqual(run.current_step, 42)
        XCTAssertEqual(run.total_steps, 100)
        XCTAssertNil(run.error)
        XCTAssertEqual(run.id, "run-1")
    }

    func testTrainerRunWithError() {
        let d: [String: Any] = ["run_id": "r2", "method": "grpo", "model": "m", "status": "failed", "error": "boom"]
        let run = TrainerRun.from(d)
        XCTAssertEqual(run.status, "failed")
        XCTAssertEqual(run.error, "boom")
    }

    func testTrainerRunDefaultsOnEmpty() {
        let run = TrainerRun.from([:])
        XCTAssertEqual(run.run_id, "")
        XCTAssertEqual(run.status, "unknown")
        XCTAssertEqual(run.progress, 0)
        XCTAssertEqual(run.total_steps, 0)
    }

    func testTrainerPresetFromDict() {
        let d: [String: Any] = [
            "name": "sft_7b_lora", "kind": "sft",
            "memory_estimate_gb": 14.5, "summary": "LoRA 7B",
            "config": ["lora_rank": 16, "lr": 1e-4] as [String: Any],
        ]
        let p = TrainerPreset.from(d)
        XCTAssertEqual(p.name, "sft_7b_lora")
        XCTAssertEqual(p.kind, "sft")
        XCTAssertEqual(p.memory_estimate_gb, 14.5, accuracy: 0.01)
        XCTAssertEqual(p.summary, "LoRA 7B")
        XCTAssertEqual(p.id, "sft_7b_lora")
        XCTAssertFalse(p.config.isEmpty)
    }

    func testTrainerDatasetFromDict() {
        let d: [String: Any] = ["name": "code_alpaca", "path": "/h/d.jsonl", "samples": 1000, "format": "messages"]
        let ds = TrainerDataset.from(d)
        XCTAssertEqual(ds.name, "code_alpaca")
        XCTAssertEqual(ds.samples, 1000)
        XCTAssertEqual(ds.format, "messages")
        XCTAssertEqual(ds.id, "code_alpaca")
    }

    func testTrainerAdapterFromDict() {
        let d: [String: Any] = ["name": "my-lora", "model": "qwen", "path": "/a", "method": "sft"]
        let ad = TrainerAdapter.from(d)
        XCTAssertEqual(ad.name, "my-lora")
        XCTAssertEqual(ad.model, "qwen")
        XCTAssertEqual(ad.method, "sft")
        XCTAssertEqual(ad.id, "my-lora")
    }

    func testTrainerProgressEventFromDict() {
        let d: [String: Any] = ["step": 5, "metric": "train_loss", "value": 2.345, "ts": "t"]
        let e = TrainerProgressEvent.from(d)
        XCTAssertEqual(e.step, 5)
        XCTAssertEqual(e.metric, "train_loss")
        XCTAssertEqual(e.value, 2.345, accuracy: 0.0001)
        XCTAssertEqual(e.id, 5)
    }

    // RunManager 平铺 schema (issue #212): step/total_steps/created(int), 无 progress/current_step/created_at
    func testTrainerRunFromFlatSchema() {
        let d: [String: Any] = [
            "run_id": "run-flat", "method": "sft", "model": "qwen",
            "status": "running", "step": 42, "total_steps": 100,
            "created": 1724210000, "error": "",
        ]
        let run = TrainerRun.from(d)
        XCTAssertEqual(run.run_id, "run-flat")
        XCTAssertEqual(run.current_step, 42)
        XCTAssertEqual(run.total_steps, 100)
        XCTAssertEqual(run.progress, 0.42, accuracy: 0.001)
        XCTAssertTrue(run.created_at.hasPrefix("2024-"), "expected ISO date from epoch, got \(run.created_at)")
        XCTAssertEqual(run.error, "")
    }

    // 原始 mlx event 归一化 (issue #212): type=train_loss + train_loss 字段 → metric/value
    func testTrainerProgressEventFromRawMlxTrainLoss() {
        let d: [String: Any] = ["type": "train_loss", "step": 42, "train_loss": 1.23, "learning_rate": 2e-5]
        let e = TrainerProgressEvent.from(d)
        XCTAssertEqual(e.step, 42)
        XCTAssertEqual(e.metric, "train_loss")
        XCTAssertEqual(e.value, 1.23, accuracy: 0.0001)
    }

    func testTrainerProgressEventFromRawMlxValLoss() {
        let d: [String: Any] = ["type": "val_loss", "step": 42, "val_loss": 1.5]
        let e = TrainerProgressEvent.from(d)
        XCTAssertEqual(e.metric, "val_loss")
        XCTAssertEqual(e.value, 1.5, accuracy: 0.0001)
    }

    func testTrainerRunProgressZeroWhenNoTotal() {
        let d: [String: Any] = ["run_id": "r", "status": "running", "step": 5]
        let run = TrainerRun.from(d)
        XCTAssertEqual(run.progress, 0)
        XCTAssertEqual(run.current_step, 5)
        XCTAssertEqual(run.total_steps, 0)
    }
}

final class TrainerBridgeStateTests: XCTestCase {

    @MainActor
    func testInitialBridgeState() {
        let bridge = TrainerBridge()
        XCTAssertTrue(bridge.runs.isEmpty)
        XCTAssertNil(bridge.selectedRun)
        XCTAssertTrue(bridge.progressEvents.isEmpty)
        XCTAssertNil(bridge.lastError)
        XCTAssertFalse(bridge.isStarting)
        XCTAssertFalse(bridge.isPolling)
    }

    @MainActor
    func testSelectRunClearsProgress() {
        let bridge = TrainerBridge()
        bridge.progressEvents = [TrainerProgressEvent.from(["step": 1, "metric": "x", "value": 1, "ts": "t"])]
        bridge.selectRun(nil)
        XCTAssertTrue(bridge.progressEvents.isEmpty)
        XCTAssertNil(bridge.selectedRun)
    }

    @MainActor
    func testStopPollingIsSafeWhenIdle() {
        let bridge = TrainerBridge()
        bridge.stopPollingProgress()
        XCTAssertFalse(bridge.isPolling)
    }
}
