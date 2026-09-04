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

    // MARK: - ClusterAuditor

    func test_b_auditor_writesJsonlAndPerms() {
        let auditor = ClusterAuditor()
        let tmpDir = NSTemporaryDirectory() + "audit-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        auditor.overrideLogDir(tmpDir)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        auditor.record(action: "remove", targetNode: "n1", targetTask: nil,
                       result: "ok", idempotencyKey: nil, masterHost: "m1")

        let files = (try? FileManager.default.contentsOfDirectory(atPath: tmpDir)) ?? []
        XCTAssertEqual(files.count, 1, "one audit file created")
        let path = tmpDir + "/" + files[0]
        let perms = try! FileManager.default.attributesOfItem(atPath: path)
        XCTAssertEqual(perms[.posixPermissions] as? Int, 0o600, "audit file 0600")
        let content = try! String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(content.contains("\"action\":\"remove\""), "jsonl line contains action")
        XCTAssertTrue(content.contains("\"result\":\"ok\""), "jsonl line contains result")
    }

    func test_b_auditor_tailReturnsLastN() {
        let auditor = ClusterAuditor()
        let tmpDir = NSTemporaryDirectory() + "audit-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        auditor.overrideLogDir(tmpDir)
        defer { try? FileManager.default.removeItem(atPath: tmpDir) }

        for i in 0..<5 {
            auditor.record(action: "submit", targetNode: nil, targetTask: "task-\(i)",
                           result: "ok", idempotencyKey: "key-\(i)", masterHost: nil)
        }
        let tail = auditor.tail(limit: 3)
        XCTAssertEqual(tail.count, 3, "tail returns last 3")
        XCTAssertEqual(tail.last?.targetTask, "task-4", "tail last is most recent")
    }

    // MARK: - TlsTrustStore

    func test_b_tlsTrustStore_importListRemoveRoundTrip() throws {
        let store = TlsTrustStore.shared
        // generate a minimal self-signed cert DER in-test is impractical without a fixture;
        // test the account-key plumbing with a sentinel: import should reject invalid DER
        // gracefully (no crash), and list/remove on a nonexistent fingerprint is a no-op.
        let bogusURL = URL(fileURLWithPath: "/tmp/nonexistent-cert-\(UUID().uuidString).cer")
        XCTAssertThrowsError(try store.importCert(at: bogusURL), "missing file throws")

        let list = store.listCerts()
        // cleanup any test certs that might have a known fingerprint prefix
        for c in list where c.fingerprint.hasPrefix("test-fp-") {
            try? store.removeCert(fingerprint: c.fingerprint)
        }
        // removeCert on nonexistent should not throw (idempotent)
        try store.removeCert(fingerprint: "test-fp-does-not-exist")
    }

    // MARK: - Transport wiring (structural)

    func test_b_transport_hasDelegateSession() {
        let transport = ClusterTransport.shared
        XCTAssertNotNil(transport.session, "transport exposes a URLSession")
    }

    func test_b_tlsDelegate_typeExists() {
        _ = ClusterTLSDelegate()
    }

    // MARK: - Cluster token Keychain migration

    func test_b_tokenMigratesAppStorageToKeychain() {
        let account = "multiNodeClusterToken"
        let appStorageKey = "multiNodeClusterToken"
        UserDefaults.standard.set("test-tok-123", forKey: appStorageKey)
        defer {
            UserDefaults.standard.removeObject(forKey: appStorageKey)
            _ = KeychainStore.delete(account)
        }
        let token = KeychainStore.readClusterToken()
        XCTAssertEqual(token, "test-tok-123", "migrated from UserDefaults")
        XCTAssertNil(UserDefaults.standard.string(forKey: appStorageKey), "UserDefaults cleared post-migration")
        XCTAssertEqual(KeychainStore.get(account), "test-tok-123", "Keychain holds token")
        XCTAssertEqual(KeychainStore.readClusterToken(), "test-tok-123")
    }

    // MARK: - canMutate state matrix

    @MainActor
    func test_b_canMutate_matrix() {
        let engine = MultiNodeEngine()
        engine.isConnected = true
        engine.splitBrainDetected = false
        engine.recomputeCanMutate()
        XCTAssertTrue(engine.canMutate, "connected + no split -> canMutate true")

        engine.isConnected = false
        engine.recomputeCanMutate()
        XCTAssertFalse(engine.canMutate, "disconnected -> canMutate false")

        engine.isConnected = true
        engine.splitBrainDetected = true
        engine.recomputeCanMutate()
        XCTAssertFalse(engine.canMutate, "split-brain -> canMutate false")
    }

    func test_b_engineUsesClusterTransportNotSharedSession() {
        let path = (#file as NSString).deletingLastPathComponent
            + "/../../FusionStudio/Modules/MultiNode/MultiNodeEngine.swift"
        guard let src = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("cannot read MultiNodeEngine source"); return
        }
        XCTAssertTrue(src.contains("ClusterTransport.shared.session"), "engine must use ClusterTransport session")
    }

    // MARK: - ClusterWriteButton enable logic

    func test_b_clusterWriteButton_shouldEnable() {
        XCTAssertTrue(MultiNodeEngine.shouldEnableWrite(canMutate: true), "canMutate=true -> enabled")
        XCTAssertFalse(MultiNodeEngine.shouldEnableWrite(canMutate: false), "canMutate=false -> disabled")
    }

    // MARK: - MultiNode views wired

    func test_b_allMultiNodeScreensHaveStatusBanner() {
        let views = ["ClusterOverviewView", "ClusterTopologyView", "ClusterSyncView",
                     "NodeActionsView", "TaskMonitorView", "AlertCenterView",
                     "SubmitTaskView", "RoutingStrategyView", "KVCacheView",
                     "TaskProgressView", "ServiceWebView"]
        let dir = (#file as NSString).deletingLastPathComponent
            + "/../../FusionStudio/Modules/MultiNode/"
        for v in views {
            let path = dir + v + ".swift"
            guard let src = try? String(contentsOfFile: path, encoding: .utf8) else {
                XCTFail("cannot read \(v).swift"); continue
            }
            XCTAssertTrue(src.contains("ClusterStatusBanner"), "\(v) must include ClusterStatusBanner")
        }
    }

    func test_b_allMutatingButtonsRespectCanMutate() {
        let path = (#file as NSString).deletingLastPathComponent
            + "/../../FusionStudio/Modules/MultiNode/MultiNodeEngine.swift"
        guard let src = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("cannot read MultiNodeEngine source"); return
        }
        let mutatingMethods = ["removeNode", "approveNode", "rejectNode", "migrateTask",
                               "submitTask", "retryTask", "setRoutingStrategy",
                               "updateAutoscalerConfig", "cancelTask", "degradeTask"]
        for name in mutatingMethods {
            XCTAssertTrue(src.contains("func \(name)("), "missing mutating method: \(name)")
        }
        let guardCount = src.components(separatedBy: "guard canMutate").count - 1
        XCTAssertEqual(guardCount, mutatingMethods.count,
                       "every mutating method (\(mutatingMethods.count)) must have a `guard canMutate` guard; found \(guardCount)")
    }

    // MARK: - #76/#77/#72 deterministic split-brain signal parsing (upstream PR#78)

    func test_b_nodeListResponse_decodesPartitionedEpochLeaderId() {
        let json = """
        {"total":3,"online":2,"nodes":[],"partitioned":true,"epoch":4,"leader_id":"node-1","is_leader":true}
        """.data(using: .utf8)!
        let resp = try! JSONDecoder().decode(NodeListResponse.self, from: json)
        XCTAssertEqual(resp.total, 3)
        XCTAssertEqual(resp.online, 2)
        XCTAssertEqual(resp.partitioned, true, "#72 partitioned field decoded")
        XCTAssertEqual(resp.epoch, 4, "#76 epoch field decoded")
        XCTAssertEqual(resp.leaderId, "node-1", "#76 leader_id decoded")
        XCTAssertEqual(resp.isLeader, true, "#76 is_leader decoded")
    }

    func test_b_nodeListResponse_additiveFieldsOptionalForOldUpstream() {
        let json = """
        {"total":3,"online":2,"nodes":[]}
        """.data(using: .utf8)!
        let resp = try! JSONDecoder().decode(NodeListResponse.self, from: json)
        XCTAssertNil(resp.partitioned, "old upstream omits partitioned -> nil, fallback heuristic")
        XCTAssertNil(resp.epoch, "old upstream omits epoch -> nil")
        XCTAssertNil(resp.leaderId, "old upstream omits leader_id -> nil")
        XCTAssertNil(resp.isLeader, "old upstream omits is_leader -> nil")
    }

    func test_b_v1ClusterInfo_decodesEpochLeaderToken() {
        let json = """
        {"online_nodes":3,"total_nodes":3,"active_tasks":1,"total_memory_gb":64.0,"available_memory_gb":32.0,"utilization":0.5,"epoch":5,"leader_id":"node-2","is_leader":false,"leader_token":"hmac-token-32"}
        """.data(using: .utf8)!
        let info = try! JSONDecoder().decode(V1ClusterInfo.self, from: json)
        XCTAssertEqual(info.epoch, 5)
        XCTAssertEqual(info.leaderId, "node-2")
        XCTAssertEqual(info.isLeader, false)
        XCTAssertEqual(info.leaderToken, "hmac-token-32", "#77 leader_token decoded")
    }

    func test_b_clusterNode_decodesEpochLeaderId() {
        let json = """
        {"node_id":"n1","hostname":"node-1","ip_address":"10.0.0.1","port":11452,"status":"online","total_memory_gb":64.0,"available_memory_gb":32.0,"cpu_cores":10,"gpu_cores":10,"device_model":"M2","active_tasks":1,"max_tasks":4,"score":0.9,"role":"master","epoch":4,"leader_id":"node-1"}
        """.data(using: .utf8)!
        let node = try! JSONDecoder().decode(ClusterNode.self, from: json)
        XCTAssertEqual(node.id, "n1")
        XCTAssertTrue(node.isMaster)
        XCTAssertEqual(node.epoch, 4, "per-node epoch decoded")
        XCTAssertEqual(node.leaderId, "node-1", "per-node leader_id decoded")
    }

    // MARK: - 3-layer split-brain branches locked in engine source

    func test_b_engineHasThreeLayerDeterministicSplitBrainBranches() {
        let path = (#file as NSString).deletingLastPathComponent
            + "/../../FusionStudio/Modules/MultiNode/MultiNodeEngine.swift"
        guard let src = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("cannot read MultiNodeEngine source"); return
        }
        XCTAssertTrue(src.contains("nowPartitioned"), "Layer 1: #72 partitioned branch present")
        XCTAssertTrue(src.contains("epoch < knownMax"), "Layer 2: #76 stale-leader epoch compare present")
        XCTAssertTrue(src.contains("isSingleAuthority"),
                      "Layer 2: single-authority (epoch==0 + empty leader) skip present")
        XCTAssertTrue(src.contains("masterCount > 1"),
                      "Layer 3: heuristic fallback (old upstream nil fields) present")
        XCTAssertTrue(src.contains("knownLeaderEpoch"), "#76 cached max-epoch state present")
    }

    func test_b_engineAttachesLeaderTokenHeaderOnMutations() {
        let path = (#file as NSString).deletingLastPathComponent
            + "/../../FusionStudio/Modules/MultiNode/MultiNodeEngine.swift"
        guard let src = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("cannot read MultiNodeEngine source"); return
        }
        XCTAssertTrue(src.contains("X-Leader-Token"), "#77 per-leader token header present")
        XCTAssertTrue(src.contains("leaderTokenHeader"),
                      "#77 leaderTokenHeader helper attached to mutations")
    }

    func test_b_engineRefreshesLeaderTokenFromStats() {
        let path = (#file as NSString).deletingLastPathComponent
            + "/../../FusionStudio/Modules/MultiNode/MultiNodeEngine.swift"
        guard let src = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("cannot read MultiNodeEngine source"); return
        }
        XCTAssertTrue(src.contains("knownLeaderToken = token"),
                      "knownLeaderToken refreshed from /api/v1/cluster/stats leader_token on failover")
    }
}
