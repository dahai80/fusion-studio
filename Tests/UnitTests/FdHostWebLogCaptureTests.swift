// Callers: Swift test runner (swift test).
// Reads: FdHostWebLogCapture persist + throttle.
// User instruction: #372 OPS-13 fd-host-web log.capture.dump consumer.

import XCTest
@testable import FusionStudio

final class FdHostWebLogCaptureTests: XCTestCase {

    // MARK: - persist

    func testPersistWritesJsonWithTimestampAndEntries() throws {
        let entries: [[String: Any]] = [
            ["level": "error", "ts_ms": 1234.0, "msg": "boom"],
            ["level": "warn", "ts_ms": 5678.0, "msg": "careful"]
        ]
        let path = FdHostWebLogCapture.shared.persist(entries: entries, timestamp: 1693500000)
        XCTAssertNotNil(path)
        guard let p = path else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: p))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schema"] as? String, "fd-host-web-log")
        XCTAssertEqual(json?["schema_version"] as? Int, 1)
        XCTAssertEqual(json?["captured_at_ms"] as? Int64, 1693500000)
        XCTAssertEqual(json?["entry_count"] as? Int, 2)
        let arr = json?["entries"] as? [[String: Any]]
        XCTAssertEqual(arr?.count, 2)
        XCTAssertEqual(arr?[0]["level"] as? String, "error")
        XCTAssertEqual(arr?[0]["ts_ms"] as? Double, 1234.0)
        XCTAssertEqual(arr?[0]["msg"] as? String, "boom")
        try? FileManager.default.removeItem(atPath: p)
    }

    func testPersistEmptyEntriesReturnsNil() {
        let path = FdHostWebLogCapture.shared.persist(entries: [], timestamp: 1693500000)
        XCTAssertNil(path)
    }

    func testPersistTruncatesOversizedMessage() throws {
        let huge = String(repeating: "x", count: 50_000)
        let entries: [[String: Any]] = [["level": "error", "ts_ms": 1.0, "msg": huge]]
        let path = FdHostWebLogCapture.shared.persist(entries: entries, timestamp: 1693500001)
        XCTAssertNotNil(path)
        guard let p = path else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: p))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let arr = json?["entries"] as? [[String: Any]]
        let msg = arr?[0]["msg"] as? String ?? ""
        XCTAssertLessThan(msg.count, 50_000)
        XCTAssertTrue(msg.contains("[truncated]"))
        try? FileManager.default.removeItem(atPath: p)
    }

    // MARK: - throttle

    func testThrottleAllowsFirstThenBlocks() {
        let cap = FdHostWebLogCapture.shared
        cap.resetThrottleForTest()
        XCTAssertTrue(cap.canForegroundDump())
        XCTAssertTrue(cap.triggerForegroundDump())
        XCTAssertFalse(cap.canForegroundDump())
        XCTAssertFalse(cap.triggerForegroundDump())
    }
}
