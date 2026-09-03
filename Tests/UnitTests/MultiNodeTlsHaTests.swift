import XCTest
@testable import FusionStudio

@MainActor
final class MultiNodeTlsHaTests: XCTestCase {

    // MARK: - ClusterEndpoint parsing

    func test_b_endpoint_parsesCsv() {
        let eps = ClusterEndpoint.parse("node1.corp:11452,node2.corp:11452")
        XCTAssertEqual(eps.count, 2)
        XCTAssertEqual(eps[0].host, "node1.corp")
        XCTAssertEqual(eps[0].port, 11452)
        XCTAssertEqual(eps[1].host, "node2.corp")
    }

    func test_b_endpoint_emptyCsvReturnsEmpty() {
        XCTAssertEqual(ClusterEndpoint.parse("").count, 0)
        XCTAssertEqual(ClusterEndpoint.parse("  ").count, 0)
    }

    func test_b_endpoint_skipsMalformed() {
        let eps = ClusterEndpoint.parse("node1.corp:11452,badentry,node2.corp:11452")
        XCTAssertEqual(eps.count, 2, "malformed entry skipped")
    }

    func test_b_endpoint_url() {
        let ep = ClusterEndpoint(host: "node1.corp", port: 11452)
        XCTAssertNotNil(ep.url)
        XCTAssertEqual(ep.url?.host, "node1.corp")
    }

    // MARK: - AuditRecord Codable

    func test_b_auditRecord_codableRoundTrip() {
        let rec = AuditRecord(ts: 1700000000, actor: "macbook-pro", action: "remove",
                              targetNode: "node-3", targetTask: nil, result: "ok",
                              idempotencyKey: "abc-123", masterHost: "node1.corp")
        let data = try! JSONEncoder().encode(rec)
        let dec = try! JSONDecoder().decode(AuditRecord.self, from: data)
        XCTAssertEqual(dec.action, "remove")
        XCTAssertEqual(dec.targetNode, "node-3")
        XCTAssertEqual(dec.result, "ok")
        XCTAssertNil(dec.targetTask)
    }

    // MARK: - MasterPool failover

    func test_b_masterPool_parsesAndCycles() {
        let pool = MasterPool(csv: "a:1,b:2,c:3")
        XCTAssertEqual(pool.active?.host, "a")
        XCTAssertEqual(pool.advance()?.host, "b")
        XCTAssertEqual(pool.advance()?.host, "c")
        XCTAssertEqual(pool.advance()?.host, "a", "wrap-around to first")
    }

    func test_b_masterPool_resetReturnsToFirst() {
        let pool = MasterPool(csv: "a:1,b:2")
        _ = pool.advance()
        _ = pool.advance()
        pool.reset()
        XCTAssertEqual(pool.active?.host, "a")
    }

    func test_b_masterPool_emptyFallsBackToLegacy() {
        let pool = MasterPool(csv: "")
        // empty pool -> falls back to FusionConfig single endpoint
        XCTAssertNotNil(pool.active, "empty pool falls back to legacy single endpoint")
    }
}
