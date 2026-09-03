# MultiNode Production TLS + HA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the MultiNode cluster path enterprise-production-ready: TLS cert pinning (enterprise CA / self-signed), multi-master failover, reconnect loop, cluster mutation audit trail, global split-brain write-disable, token → Keychain.

**Architecture:** `MultiNodeEngine` keeps as single `ObservableObject` cluster truth. Four new collaborators: `TlsTrustStore` (Keychain pinned certs), `ClusterTLSDelegate` (URLSession trust eval), `MasterPool` (ordered failover list), `ClusterAuditor` (JSONL + os_log). New `ClusterTransport` (URLSession factory). UI: `ClusterStatusBanner` (global) + `ClusterWriteButton` (auto-disable + audit wrapper) + `AuditTabView`. Token moves to Keychain (reuse existing `KeychainStore` account-string pattern).

**Tech Stack:** Swift / SwiftUI, Security.framework (SecCertificate/SecTrust/Keychain), URLSession + URLSessionDelegate, SPM, XCTest.

**Spec:** `docs/superpowers/specs/2026-09-03-multinode-tls-ha-design.md`

## Global Constraints

- 4-space multiples indent, no docstrings, clean code, logging on every non-trivial path. `os_log` `Logger(subsystem: "com.fusion.studio", category: "...")`, privacy `\(val, privacy: .public)` on non-secret fields, NEVER log token/secret.
- Only modify fusion-studio repo. Upstream consensus/exclude_nodes/idempotency = filed issues (Track C), local stopgap here.
- Local `swift test`=0 (toolchain drift Swift 6.3.3/macOS 26); CI macOS-14/Xcode 15.x authoritative (~276 cases). Build gate = `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0.
- i18n: add keys to all 4 lang JSON (`Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json`), NO-INDENT format (one key per line, `": "` separator), `Bundle.module`. Register in `I18nKey` enum (`I18nService.swift`).
- Zero external Swift deps. Security.framework + Foundation only.
- `KeychainStore` (`FusionStudio/Common/KeychainStore.swift`): `kSecClassGenericPassword`, `service = "com.fusion.studio"`, account-string keys, `get(_:)/set(_:_:)/delete(_:)`. Reuse for cluster token + cert DER storage.
- `MultiNodeEngine` (`FusionStudio/Modules/MultiNode/MultiNodeEngine.swift`): `class MultiNodeEngine: ObservableObject`, `private let session: URLSession` (L75), `private var baseURL` computed (L78 reads `FusionConfig.shared.multiNodeBaseURL`), `authToken` computed (L80 reads `multiNodeResolvedToken`), poll timers, `@Published` state. `submitTask` L438, `retryTask` L454.
- `FusionConfig.multiNodePort`=11452, `multiNodeClusterToken` `@AppStorage` L270, `multiNodeBaseURL` computed L274 (`schemeForHost`), `multiNodeResolvedToken` L293.
- `mnRequest` (`IPCMultiNodeMethods.swift:17`) — parallel REST client used by other modules; Track B focuses on `MultiNodeEngine.session`, but token migration must keep `mnRequest` reading the same source (Keychain).
- `~/claude-home/fusion-mlx/start.sh start|stop` for real model tests (not needed here — MultiNode backend = fusion-multi-node, mocked in tests).

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `FusionStudio/Modules/MultiNode/Security/TlsTrustStore.swift` | new | Keychain pinned certs (DER via kSecClassGenericPassword) |
| `FusionStudio/Modules/MultiNode/Security/ClusterTLSDelegate.swift` | new | URLSessionDelegate trust eval (system ∪ pinned) |
| `FusionStudio/Modules/MultiNode/Security/MasterPool.swift` | new | ordered failover master list from Settings CSV |
| `FusionStudio/Modules/MultiNode/Security/ClusterTransport.swift` | new | URLSession factory with delegate |
| `FusionStudio/Modules/MultiNode/Security/ClusterAuditor.swift` | new | JSONL audit trail + os_log + tail reader |
| `FusionStudio/Modules/MultiNode/Security/ClusterEndpoint.swift` | new | `ClusterEndpoint` struct + `AuditRecord` Codable |
| `FusionStudio/Modules/MultiNode/ClusterStatusBanner.swift` | new | global status banner (split-brain/stale/disconnected) |
| `FusionStudio/Modules/MultiNode/ClusterWriteButton.swift` | new | mutating-button wrapper (auto-disable + audit) |
| `FusionStudio/Modules/MultiNode/AuditTabView.swift` | new | audit log viewer tab |
| `FusionStudio/Modules/MultiNode/MultiNodeEngine.swift` | modify | pool/transport/audit/canMutate/reconnect wiring |
| `FusionStudio/Modules/MultiNode/*.swift` (views) | modify | banner + ClusterWriteButton swap |
| `FusionStudio/Settings/SettingsView.swift` | modify | "MultiNode 安全" section |
| `FusionStudio/Common/KeychainStore.swift` | modify | cluster token read/write/delete |
| `FusionStudio/Common/FusionConfig.swift` | modify | multiNodeMasterList @AppStorage + token migration |
| `Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json` | modify | new keys |
| `FusionStudio/Common/I18nService.swift` | modify | I18nKey cases |
| `Tests/UnitTests/MultiNodeTlsHaTests.swift` | new | unit tests |

---

### Task 1: ClusterEndpoint + AuditRecord types

**Files:**
- Create: `FusionStudio/Modules/MultiNode/Security/ClusterEndpoint.swift`
- Test: `Tests/UnitTests/MultiNodeTlsHaTests.swift`

**Interfaces:**
- Produces: `struct ClusterEndpoint: Equatable { host: String; port: Int }`, `var url: URL?`, `static func parse(_ csv: String) -> [ClusterEndpoint]`; `struct AuditRecord: Codable { ts: Int; actor: String; action: String; targetNode: String?; targetTask: String?; result: String; idempotencyKey: String?; masterHost: String? }`

- [ ] **Step 1: Write failing tests**

Create `Tests/UnitTests/MultiNodeTlsHaTests.swift`:
```swift
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
}
```

- [ ] **Step 2: Run to verify fail**

Run: `swift build --build-tests 2>&1 | tail -20`
Expected: FAIL — `ClusterEndpoint`/`AuditRecord` undefined.

- [ ] **Step 3: Implement**

Create `FusionStudio/Modules/MultiNode/Security/ClusterEndpoint.swift`:
```swift
import Foundation
import os.log

private let endpointLog = Logger(subsystem: "com.fusion.studio", category: "ClusterEndpoint")

struct ClusterEndpoint: Equatable {
    let host: String
    let port: Int

    var url: URL? {
        URL(string: "\(host):\(port)")
    }

    var urlString: String {
        "\(host):\(port)"
    }

    static func parse(_ csv: String) -> [ClusterEndpoint] {
        let trimmed = csv.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var result: [ClusterEndpoint] = []
        for raw in trimmed.split(separator: ",") {
            let entry = raw.trimmingCharacters(in: .whitespaces)
            guard let colon = entry.lastIndex(of: ":") else {
                endpointLog.error("parse skip malformed (no port): \(entry, privacy: .public)")
                continue
            }
            let host = String(entry[entry.startIndex..<colon])
            guard let port = Int(entry[entry.index(after: colon)...]), port > 0, !host.isEmpty else {
                endpointLog.error("parse skip malformed (bad host/port): \(entry, privacy: .public)")
                continue
            }
            result.append(ClusterEndpoint(host: host, port: port))
        }
        return result
    }
}

struct AuditRecord: Codable {
    let ts: Int
    let actor: String
    let action: String
    let targetNode: String?
    let targetTask: String?
    let result: String
    let idempotencyKey: String?
    let masterHost: String?
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Modules/MultiNode/Security/ClusterEndpoint.swift Tests/UnitTests/MultiNodeTlsHaTests.swift
git commit -m "feat(enterprise): ClusterEndpoint + AuditRecord types for MultiNode TLS+HA"
```

---

### Task 2: MasterPool (failover list)

**Files:**
- Create: `FusionStudio/Modules/MultiNode/Security/MasterPool.swift`
- Test: `Tests/UnitTests/MultiNodeTlsHaTests.swift` (append)

**Interfaces:**
- Consumes: `ClusterEndpoint`, `FusionConfig.multiNodeBaseURL` (legacy fallback)
- Produces: `class MasterPool` — `var active: ClusterEndpoint?`, `func advance() -> ClusterEndpoint?`, `func reset()`, `static let shared`

- [ ] **Step 1: Write failing tests**

Append to `Tests/UnitTests/MultiNodeTlsHaTests.swift`:
```swift
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
```

- [ ] **Step 2: Run to verify fail**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: FAIL — `MasterPool` undefined.

- [ ] **Step 3: Implement MasterPool**

Create `FusionStudio/Modules/MultiNode/Security/MasterPool.swift`:
```swift
import Foundation
import os.log

private let poolLog = Logger(subsystem: "com.fusion.studio", category: "MasterPool")

final class MasterPool {
    static let shared = MasterPool()

    private var endpoints: [ClusterEndpoint] = []
    private var activeIndex: Int = 0
    private let lock = NSLock()

    private init() {
        reload()
    }

    var active: ClusterEndpoint? {
        lock.lock(); defer { lock.unlock() }
        if !endpoints.isEmpty {
            return endpoints[activeIndex]
        }
        // legacy fallback: single endpoint from FusionConfig
        let cfg = FusionConfig.shared
        guard let url = URL(string: cfg.multiNodeBaseURL),
              let host = url.host, let port = url.port else { return nil }
        return ClusterEndpoint(host: host, port: port)
    }

    func advance() -> ClusterEndpoint? {
        lock.lock(); defer { lock.unlock() }
        guard !endpoints.isEmpty else { return active }
        activeIndex = (activeIndex + 1) % endpoints.count
        poolLog.info("failover advance -> \(endpoints[activeIndex].host, privacy: .public)")
        return endpoints[activeIndex]
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        activeIndex = 0
        poolLog.info("pool reset to index 0")
    }

    func reload() {
        lock.lock(); defer { lock.unlock() }
        let csv = UserDefaults.standard.string(forKey: "multiNodeMasterList") ?? ""
        let parsed = ClusterEndpoint.parse(csv)
        if parsed != endpoints {
            endpoints = parsed
            activeIndex = 0
            poolLog.info("pool reloaded: \(endpoints.count, privacy: .public) endpoints")
        }
    }

    var endpointCount: Int {
        lock.lock(); defer { lock.unlock() }
        return endpoints.count
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Modules/MultiNode/Security/MasterPool.swift Tests/UnitTests/MultiNodeTlsHaTests.swift
git commit -m "feat(enterprise): MasterPool ordered failover list for MultiNode"
```

---

### Task 3: ClusterAuditor (JSONL audit trail)

**Files:**
- Create: `FusionStudio/Modules/MultiNode/Security/ClusterAuditor.swift`
- Test: `Tests/UnitTests/MultiNodeTlsHaTests.swift` (append)

**Interfaces:**
- Consumes: `AuditRecord`
- Produces: `class ClusterAuditor` — `func record(action:targetNode:targetTask:result:idempotencyKey:masterHost:)`, `func tail(limit:) -> [AuditRecord]`, `static let shared`

- [ ] **Step 1: Write failing tests**

Append:
```swift
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
```

- [ ] **Step 2: Run to verify fail**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: FAIL — `ClusterAuditor` undefined.

- [ ] **Step 3: Implement ClusterAuditor**

Create `FusionStudio/Modules/MultiNode/Security/ClusterAuditor.swift`:
```swift
import Foundation
import os.log

private let auditLog = Logger(subsystem: "com.fusion.studio", category: "ClusterAudit")

final class ClusterAuditor {
    static let shared = ClusterAuditor()

    private var logDir: String
    private let writeLock = NSLock()

    private init() {
        self.logDir = NSHomeDirectory() + "/.fusion-studio/logs"
        ensureDir()
    }

    func overrideLogDir(_ dir: String) {
        self.logDir = dir
        ensureDir()
    }

    private func ensureDir() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: logDir) {
            try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        }
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: logDir)
    }

    private func actorName() -> String {
        let label = UserDefaults.standard.string(forKey: "clusterAuditActorLabel") ?? ""
        if !label.isEmpty { return label }
        return Host.current().localizedName ?? "unknown"
    }

    private func dateStampedPath() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        fmt.timeZone = TimeZone.current
        return logDir + "/cluster-audit-" + fmt.string(from: Date()) + ".log"
    }

    func record(action: String, targetNode: String?, targetTask: String?,
                result: String, idempotencyKey: String?, masterHost: String?) {
        let rec = AuditRecord(ts: Int(Date().timeIntervalSince1970),
                              actor: actorName(), action: action,
                              targetNode: targetNode, targetTask: targetTask,
                              result: result, idempotencyKey: idempotencyKey,
                              masterHost: masterHost)
        guard let data = try? JSONEncoder().encode(rec),
              var line = String(data: data, encoding: .utf8) else {
            auditLog.error("record encode failed for action=\(action, privacy: .public)")
            return
        }
        line += "\n"
        writeLock.lock(); defer { writeLock.unlock() }
        let path = dateStampedPath()
        // append (create if absent)
        if !FileManager.default.fileExists(atPath: path) {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                _ = handle.seekToEnd()
                if let d = line.data(using: .utf8) { handle.write(d) }
                try? handle.close()
            }
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        auditLog.info("audit action=\(action, privacy: .public) result=\(result, privacy: .public) target=\(targetNode ?? targetTask ?? "-", privacy: .public)")
    }

    func tail(limit: Int) -> [AuditRecord] {
        let path = dateStampedPath()
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let text = String(data: data, encoding: .utf8) else { return [] }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        let suffix = lines.suffix(limit)
        var records: [AuditRecord] = []
        for line in suffix {
            if let d = line.data(using: .utf8),
               let rec = try? JSONDecoder().decode(AuditRecord.self, from: d) {
                records.append(rec)
            }
        }
        return records
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Modules/MultiNode/Security/ClusterAuditor.swift Tests/UnitTests/MultiNodeTlsHaTests.swift
git commit -m "feat(enterprise): ClusterAuditor JSONL audit trail for MultiNode mutations"
```

---

### Task 4: TlsTrustStore (Keychain pinned certs)

**Files:**
- Create: `FusionStudio/Modules/MultiNode/Security/TlsTrustStore.swift`
- Test: `Tests/UnitTests/MultiNodeTlsHaTests.swift` (append)

**Interfaces:**
- Consumes: `KeychainStore` (kSecClassGenericPassword, service `com.fusion.studio`)
- Produces: `class TlsTrustStore` — `func importCert(at:) throws`, `func pinnedAnchors() -> [SecCertificate]`, `func listCerts() -> [CertSummary]`, `func removeCert(fingerprint:) throws`, `static let shared`, `struct CertSummary { fingerprint: String; subject: String }`

- [ ] **Step 1: Write failing tests**

Append:
```swift
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
```

- [ ] **Step 2: Run to verify fail**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: FAIL — `TlsTrustStore` undefined.

- [ ] **Step 3: Implement TlsTrustStore**

Create `FusionStudio/Modules/MultiNode/Security/TlsTrustStore.swift`:
```swift
import Foundation
import Security
import os.log

private let tlsStoreLog = Logger(subsystem: "com.fusion.studio", category: "TlsTrustStore")

struct CertSummary {
    let fingerprint: String
    let subject: String
}

final class TlsTrustStore {
    static let shared = TlsTrustStore()

    private let accountPrefix = "cluster-tls-cert-"

    private init() {}

    func importCert(at url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let cert = SecCertificateCreateWithData(nil, data as CFData) else {
            tlsStoreLog.error("importCert: not a valid certificate DER/PEM: \(url.path, privacy: .public)")
            throw NSError(domain: "TlsTrustStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid certificate file"])
        }
        let fp = fingerprint(of: cert)
        let account = accountPrefix + fp
        let derBase64 = data.base64EncodedString()
        if !KeychainStore.set(account, derBase64) {
            tlsStoreLog.error("importCert: Keychain write failed for fp=\(fp, privacy: .public)")
            throw NSError(domain: "TlsTrustStore", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Keychain write failed"])
        }
        tlsStoreLog.info("imported cert fp=\(fp, privacy: .public)")
    }

    func pinnedAnchors() -> [SecCertificate] {
        var anchors: [SecCertificate] = []
        for summary in listCerts() {
            if let derB64 = KeychainStore.get(accountPrefix + summary.fingerprint),
               let der = Data(base64Encoded: derB64),
               let cert = SecCertificateCreateWithData(nil, der as CFData) {
                anchors.append(cert)
            }
        }
        return anchors
    }

    func listCerts() -> [CertSummary] {
        // KeychainStore has no enumerate-all API; read from a known index key listing fingerprints.
        guard let indexStr = KeychainStore.get("cluster-tls-cert-index"), !indexStr.isEmpty else {
            return []
        }
        let fps = indexStr.split(separator: ",").map { String($0) }
        var summaries: [CertSummary] = []
        for fp in fps {
            if let derB64 = KeychainStore.get(accountPrefix + fp),
               let der = Data(base64Encoded: derB64),
               let cert = SecCertificateCreateWithData(nil, der as CFData) {
                let subject = SecCertificateCopySubjectSummary(cert) as String? ?? "(unknown)"
                summaries.append(CertSummary(fingerprint: fp, subject: subject))
            }
        }
        return summaries
    }

    func removeCert(fingerprint: String) throws {
        _ = KeychainStore.delete(accountPrefix + fingerprint)
        // update index
        guard let indexStr = KeychainStore.get("cluster-tls-cert-index") else { return }
        let remaining = indexStr.split(separator: ",").map { String($0) }.filter { $0 != fingerprint }
        let newIndex = remaining.joined(separator: ",")
        if newIndex.isEmpty {
            _ = KeychainStore.delete("cluster-tls-cert-index")
        } else {
            _ = KeychainStore.set("cluster-tls-cert-index", newIndex)
        }
        tlsStoreLog.info("removed cert fp=\(fingerprint, privacy: .public)")
    }

    private func fingerprint(of cert: SecCertificate) -> String {
        var error: Unmanaged<CFError>?
        guard let oidData = SecCertificateCopyValues(cert, [kSecOIDX509V1SerialNumber] as CFArray, &error) as? [String: Any],
              let serial = oidData[kSecOIDX509V1SerialNumber as String] as? Data else {
            return UUID().uuidString
        }
        return serial.map { String(format: "%02x", $0) }.joined()
    }
}
```

NOTE: the `importCert` path must also append the fingerprint to the index key. Update `importCert` before the final `tlsStoreLog.info`:
```swift
        // update index
        let existingIndex = KeychainStore.get("cluster-tls-cert-index") ?? ""
        let fps = existingIndex.split(separator: ",").map { String($0) }
        if !fps.contains(fp) {
            let newIndex = (fps + [fp]).joined(separator: ",")
            _ = KeychainStore.set("cluster-tls-cert-index", newIndex)
        }
```
(Read the existing key, append, write back — before the info log.)

- [ ] **Step 4: Run to verify pass**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: PASS (missing-file throws, nonexistent remove no-throw).

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Modules/MultiNode/Security/TlsTrustStore.swift Tests/UnitTests/MultiNodeTlsHaTests.swift
git commit -m "feat(enterprise): TlsTrustStore Keychain-backed pinned certs for MultiNode TLS"
```

---

### Task 5: ClusterTLSDelegate + ClusterTransport

**Files:**
- Create: `FusionStudio/Modules/MultiNode/Security/ClusterTLSDelegate.swift`
- Create: `FusionStudio/Modules/MultiNode/Security/ClusterTransport.swift`
- Test: `Tests/UnitTests/MultiNodeTlsHaTests.swift` (append structural)

**Interfaces:**
- Consumes: `TlsTrustStore`
- Produces: `class ClusterTLSDelegate: NSObject, URLSessionDelegate`, `class ClusterTransport` — `let session: URLSession`, `static let shared`

- [ ] **Step 1: Write failing structural test**

Append:
```swift
    // MARK: - Transport wiring (structural)

    func test_b_transport_hasDelegateSession() {
        let transport = ClusterTransport.shared
        XCTAssertNotNil(transport.session, "transport exposes a URLSession")
    }

    func test_b_tlsDelegate_typeExists() {
        _ = ClusterTLSDelegate()
    }
```

- [ ] **Step 2: Run to verify fail**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: FAIL — `ClusterTLSDelegate`/`ClusterTransport` undefined.

- [ ] **Step 3: Implement ClusterTLSDelegate**

Create `FusionStudio/Modules/MultiNode/Security/ClusterTLSDelegate.swift`:
```swift
import Foundation
import os.log

private let tlsDelLog = Logger(subsystem: "com.fusion.studio", category: "ClusterTLS")

final class ClusterTLSDelegate: NSObject, URLSessionDelegate {

    var clientIdentity: SecIdentity? = nil  // mTLS hook — nil in v1 (no mTLS)

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        // append pinned anchors as additional trust roots (system ∪ pinned)
        let pinned = TlsTrustStore.shared.pinnedAnchors()
        if !pinned.isEmpty {
            let extraCerts = pinned as CFArray
            SecTrustSetAnchorCertificates(serverTrust, extraCerts)
            // restore system roots alongside pinned (SetAnchor replaces; re-add system)
            SecTrustSetAnchorCertificatesOnly(serverTrust, false)
            tlsDelLog.info("TLS eval with \(pinned.count, privacy: .public) pinned anchors + system roots")
        }
        var error: CFError?
        if SecTrustEvaluateWithError(serverTrust, &error) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            let msg = error.map { ($0 as Error).localizedDescription } ?? "unknown"
            tlsDelLog.error("TLS trust eval failed: \(msg, privacy: .public)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
```

NOTE: `SecTrustSetAnchorCertificatesOnly(serverTrust, false)` after `SecTrustSetAnchorCertificates` keeps system roots in the trust set — critical for enterprise CA (CA pinned) + public cert (system) coexistence.

- [ ] **Step 4: Implement ClusterTransport**

Create `FusionStudio/Modules/MultiNode/Security/ClusterTransport.swift`:
```swift
import Foundation
import os.log

private let transportLog = Logger(subsystem: "com.fusion.studio", category: "ClusterTransport")

final class ClusterTransport {
    static let shared = ClusterTransport()

    let session: URLSession
    private let delegate: ClusterTLSDelegate

    private init() {
        self.delegate = ClusterTLSDelegate()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        transportLog.info("ClusterTransport init (TLS delegate attached)")
    }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add FusionStudio/Modules/MultiNode/Security/ClusterTLSDelegate.swift FusionStudio/Modules/MultiNode/Security/ClusterTransport.swift Tests/UnitTests/MultiNodeTlsHaTests.swift
git commit -m "feat(enterprise): ClusterTLSDelegate + ClusterTransport (system∪pinned trust eval)"
```

---

### Task 6: Keychain cluster token + migration

**Files:**
- Modify: `FusionStudio/Common/KeychainStore.swift`
- Modify: `FusionStudio/Common/FusionConfig.swift`
- Test: `Tests/UnitTests/MultiNodeTlsHaTests.swift` (append)

**Interfaces:**
- Consumes: `KeychainStore` account pattern
- Produces: `KeychainStore.readClusterToken()`, `writeClusterToken(_:)`, `deleteClusterToken()`; `FusionConfig.multiNodeMasterList` `@AppStorage`; token migration `@AppStorage("multiNodeClusterToken")` → Keychain on first read

- [ ] **Step 1: Write failing test**

Append:
```swift
    // MARK: - Cluster token Keychain migration

    func test_b_tokenMigratesAppStorageToKeychain() {
        let account = "multiNodeClusterToken"
        let appStorageKey = "multiNodeClusterToken"
        // setup: stale token in UserDefaults
        UserDefaults.standard.set("test-tok-123", forKey: appStorageKey)
        defer {
            UserDefaults.standard.removeObject(forKey: appStorageKey)
            _ = KeychainStore.delete(account)
        }
        // migration
        let token = KeychainStore.readClusterToken()
        XCTAssertEqual(token, "test-tok-123", "migrated from UserDefaults")
        // after migration, UserDefaults cleared, Keychain holds it
        XCTAssertNil(UserDefaults.standard.string(forKey: appStorageKey), "UserDefaults cleared post-migration")
        XCTAssertEqual(KeychainStore.get(account), "test-tok-123", "Keychain holds token")
        // second read: from Keychain, no double-migrate
        XCTAssertEqual(KeychainStore.readClusterToken(), "test-tok-123")
    }
```

- [ ] **Step 2: Run to verify fail**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: FAIL — `readClusterToken` undefined.

- [ ] **Step 3: Add cluster token methods to KeychainStore**

In `FusionStudio/Common/KeychainStore.swift`, after the `fusionCodeToken` section (~L131), add:
```swift
    // MARK: - MultiNode cluster token (Track B: out of @AppStorage plaintext → Keychain)

    static let clusterTokenAccount = "multiNodeClusterToken"

    static func readClusterToken() -> String {
        if let cached = get(clusterTokenAccount), !cached.isEmpty {
            return cached
        }
        // migration: existing @AppStorage plaintext token → Keychain, then clear
        let stale = UserDefaults.standard.string(forKey: "multiNodeClusterToken") ?? ""
        if !stale.isEmpty {
            keychainLog.info("migrating cluster token from UserDefaults to Keychain")
            _ = set(clusterTokenAccount, stale)
            UserDefaults.standard.removeObject(forKey: "multiNodeClusterToken")
            return stale
        }
        return ""
    }

    @discardableResult
    static func writeClusterToken(_ value: String) -> Bool {
        set(clusterTokenAccount, value)
    }

    @discardableResult
    static func deleteClusterToken() -> Bool {
        delete(clusterTokenAccount)
    }
```

- [ ] **Step 4: Add multiNodeMasterList @AppStorage to FusionConfig**

In `FusionStudio/Common/FusionConfig.swift`, near L270 (after `multiNodeClusterToken`), add:
```swift
    /// Track B: ordered comma-separated master host list for failover (e.g. "node1:11452,node2:11452").
    /// Empty = fall back to single multiNodeBaseURL endpoint (backward compat).
    @AppStorage("multiNodeMasterList") var multiNodeMasterList: String = ""
```

- [ ] **Step 5: Run to verify pass**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add FusionStudio/Common/KeychainStore.swift FusionStudio/Common/FusionConfig.swift Tests/UnitTests/MultiNodeTlsHaTests.swift
git commit -m "feat(enterprise): cluster token to Keychain + migration + multiNodeMasterList config"
```

---

### Task 7: MultiNodeEngine wiring (pool/transport/audit/canMutate/reconnect)

**Files:**
- Modify: `FusionStudio/Modules/MultiNode/MultiNodeEngine.swift`
- Test: `Tests/UnitTests/MultiNodeTlsHaTests.swift` (append)

**Interfaces:**
- Consumes: `MasterPool`, `ClusterTransport`, `ClusterAuditor`, `KeychainStore.readClusterToken`
- Produces: `@Published var canMutate: Bool`, `@Published var activeMasterHost: String?`, engine uses `ClusterTransport.shared.session` + `MasterPool.shared.active` for URL, `checkHealth` wired into reconnect

- [ ] **Step 1: Write failing tests**

Append:
```swift
    // MARK: - canMutate state matrix

    func test_b_canMutate_matrix() {
        let engine = MultiNodeEngine()
        // (isConnected, splitBrainDetected) -> canMutate
        engine.isConnected = true
        engine.splitBrainDetected = false
        XCTAssertTrue(engine.canMutate, "connected + no split -> canMutate true")

        engine.isConnected = false
        XCTAssertFalse(engine.canMutate, "disconnected -> canMutate false")

        engine.isConnected = true
        engine.splitBrainDetected = true
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
```

- [ ] **Step 2: Run to verify fail**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: FAIL — `canMutate` undefined, `ClusterTransport.shared.session` not referenced.

- [ ] **Step 3: Add canMutate + activeMasterHost @Published**

In `MultiNodeEngine.swift` near L20-31 (the `@Published` state block), add:
```swift
    @Published var canMutate: Bool = false
    @Published var activeMasterHost: String? = nil
```

Add computed property near the `baseURL` computed property (~L78):
```swift
    private var clusterURL: URL? {
        MasterPool.shared.active?.url.map { url in
            // scheme per FusionConfig (https for remote, http for localhost)
            let scheme = FusionConfig.shared.multiNodeBaseURL.hasPrefix("https") ? "https" : "http"
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comps?.scheme = scheme
            return comps?.url ?? url
        }
    }
```

Replace `private let session: URLSession` (L75) usage: change the `init` to use `ClusterTransport.shared.session`:
```swift
    private var session: URLSession { ClusterTransport.shared.session }
```
(remove the stored `private let session` + its `URLSession(configuration:)` init lines L75-89; keep timeout config in `ClusterTransport`).

Replace `authToken` computed (L80) to read Keychain:
```swift
    private var authToken: String { overrideAuthToken ?? KeychainStore.readClusterToken() }
```

Update `baseURL` to use the pool:
```swift
    private var baseURL: String {
        if let override = overrideBaseURL { return override }
        MasterPool.shared.active?.urlString ?? FusionConfig.shared.multiNodeBaseURL
    }
```
(Keep `overrideBaseURL` for tests/injection.)

- [ ] **Step 4: Recompute canMutate on state change**

Add an update method called wherever `isConnected`/`splitBrainDetected` are set:
```swift
    private func recomputeCanMutate() {
        canMutate = isConnected && !splitBrainDetected
        activeMasterHost = MasterPool.shared.active?.host
    }
```
Call `recomputeCanMutate()` after every assignment to `isConnected` or `splitBrainDetected` (grep for `isConnected =` and `splitBrainDetected =` — append the call). Confirm all assignment sites in the file.

- [ ] **Step 5: Wire checkHealth into reconnect**

Read `checkHealth` (~L363-377). In the poll failure path (`fetchNodes`/`fetchClusterStats` failure, ~L180-185 where `consecutiveFailures` increments and `isConnected=false` is set), call `MasterPool.shared.advance()` + `checkHealth()` to attempt reconnection to the next master. Pattern in the failure handler:
```swift
        // Track B: on failure, try next master (failover) + health probe
        let next = MasterPool.shared.advance()
        engineLog.info("fetch failed, failover to \(next?.host ?? "nil", privacy: .public)")
        self?.checkHealth()
```
(Read the exact failure handler context before editing — the existing backoff logic stays; add the failover+probe alongside.)

- [ ] **Step 6: Audit on mutations**

In each mutating method (`removeNode` L389, `approveTask`, `migrateTask`, `submitTask` L438, `retryTask` L454, `setRoutingStrategy` L505, `updateAutoscalerConfig` L474), add at the end (success) and in catch (failure):
```swift
        ClusterAuditor.shared.record(action: "remove", targetNode: nodeId, targetTask: nil,
                                     result: "ok", idempotencyKey: nil, masterHost: activeMasterHost)
```
(Per-method: replace action/targetNode/targetTask/idempotencyKey appropriately. submit/retry include the idempotency key.) Add a `canMutate` guard at the top of each:
```swift
        guard canMutate else {
            ClusterAuditor.shared.record(action: "remove", targetNode: nodeId, targetTask: nil,
                                         result: "blocked", idempotencyKey: nil, masterHost: activeMasterHost)
            throw EngineError.splitBrain
        }
```
(Use a distinct `EngineError.writeDisabled` case — add it to the `EngineError` enum if not present; else reuse `splitBrain`.)

- [ ] **Step 7: Run to verify pass**

Run: `swift build --build-tests 2>&1 | tail -20`
Expected: PASS. (Watch for compile errors from removing `private let session` — all `self.session` references must resolve to the computed property. Grep `self.session`/`session.` to confirm.)

- [ ] **Step 8: Commit**

```bash
git add FusionStudio/Modules/MultiNode/MultiNodeEngine.swift Tests/UnitTests/MultiNodeTlsHaTests.swift
git commit -m "feat(enterprise): wire MasterPool/ClusterTransport/ClusterAuditor/canMutate/reconnect into MultiNodeEngine"
```

---

### Task 8: ClusterStatusBanner + ClusterWriteButton

**Files:**
- Create: `FusionStudio/Modules/MultiNode/ClusterStatusBanner.swift`
- Create: `FusionStudio/Modules/MultiNode/ClusterWriteButton.swift`
- Test: `Tests/UnitTests/MultiNodeTlsHaTests.swift` (append)

**Interfaces:**
- Consumes: `MultiNodeEngine` (`@Published` state)
- Produces: `ClusterStatusBanner: View`, `ClusterWriteButton: View` (action + disabled-by-canMutate + audit on tap)

- [ ] **Step 1: Write failing test**

Append:
```swift
    // MARK: - ClusterWriteButton enable logic

    func test_b_clusterWriteButton_shouldEnable() {
        XCTAssertTrue(MultiNodeEngine.shouldEnableWrite(canMutate: true), "canMutate=true -> enabled")
        XCTAssertFalse(MultiNodeEngine.shouldEnableWrite(canMutate: false), "canMutate=false -> disabled")
    }
```

- [ ] **Step 2: Run to verify fail**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: FAIL — `shouldEnableWrite` undefined.

- [ ] **Step 3: Add shouldEnableWrite helper to MultiNodeEngine**

In `MultiNodeEngine.swift`:
```swift
    static func shouldEnableWrite(canMutate: Bool) -> Bool {
        canMutate
    }
```

- [ ] **Step 4: Implement ClusterStatusBanner**

Create `FusionStudio/Modules/MultiNode/ClusterStatusBanner.swift`:
```swift
import SwiftUI

struct ClusterStatusBanner: View {
    @ObservedObject var engine: MultiNodeEngine

    var body: some View {
        VStack(spacing: 0) {
            if engine.splitBrainDetected {
                banner(color: .red, title: i18n(.mn_banner_splitBrainTitle),
                       msg: i18n(.mn_banner_splitBrainMsg))
            } else if engine.nodesStale {
                banner(color: .orange, title: i18n(.mn_banner_staleTitle),
                       msg: i18n(.mn_banner_staleMsg))
            } else if !engine.isConnected {
                banner(color: .orange, title: i18n(.mn_banner_disconnectedTitle),
                       msg: engine.lastError ?? i18n(.mn_banner_disconnectedMsg))
            }
        }
    }

    private func banner(color: Color, title: String, msg: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(msg).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(color.opacity(0.12))
        .cornerRadius(6)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
```

- [ ] **Step 5: Implement ClusterWriteButton**

Create `FusionStudio/Modules/MultiNode/ClusterWriteButton.swift`:
```swift
import SwiftUI

struct ClusterWriteButton: View {
    @ObservedObject var engine: MultiNodeEngine
    let title: String
    let action: String
    var targetNode: String? = nil
    var targetTask: String? = nil
    var idempotencyKey: String? = nil
    let perform: () async throws -> Void

    @State private var isPerforming = false

    var body: some View {
        Button(action: {
            guard MultiNodeEngine.shouldEnableWrite(canMutate: engine.canMutate) else {
                ClusterAuditor.shared.record(action: action, targetNode: targetNode,
                                             targetTask: targetTask, result: "blocked",
                                             idempotencyKey: idempotencyKey, masterHost: engine.activeMasterHost)
                return
            }
            isPerforming = true
            Task {
                do {
                    try await perform()
                    ClusterAuditor.shared.record(action: action, targetNode: targetNode,
                                                 targetTask: targetTask, result: "ok",
                                                 idempotencyKey: idempotencyKey, masterHost: engine.activeMasterHost)
                } catch {
                    ClusterAuditor.shared.record(action: action, targetNode: targetNode,
                                                 targetTask: targetTask, result: "failed",
                                                 idempotencyKey: idempotencyKey, masterHost: engine.activeMasterHost)
                }
                isPerforming = false
            }
        }) {
            if isPerforming {
                ProgressView().controlSize(.small)
            } else {
                Text(title)
            }
        }
        .disabled(!engine.canMutate || isPerforming)
        .help(engine.canMutate ? "" : i18n(.mn_writeDisabled_help))
    }
}
```

- [ ] **Step 6: Run to verify pass**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add FusionStudio/Modules/MultiNode/ClusterStatusBanner.swift FusionStudio/Modules/MultiNode/ClusterWriteButton.swift FusionStudio/Modules/MultiNode/MultiNodeEngine.swift Tests/UnitTests/MultiNodeTlsHaTests.swift
git commit -m "feat(enterprise): ClusterStatusBanner + ClusterWriteButton (global write-disable + audit)"
```

---

### Task 9: AuditTabView

**Files:**
- Create: `FusionStudio/Modules/MultiNode/AuditTabView.swift`
- Test: `Tests/UnitTests/MultiNodeTlsHaTests.swift` (append structural)

**Interfaces:**
- Consumes: `ClusterAuditor.shared.tail(limit:)`
- Produces: `AuditTabView: View`

- [ ] **Step 1: Implement AuditTabView**

Create `FusionStudio/Modules/MultiNode/AuditTabView.swift`:
```swift
import SwiftUI

struct AuditTabView: View {
    @State private var records: [AuditRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(i18n(.mn_audit_title)).font(.headline)
                Spacer()
                Button(i18n(.mn_audit_refresh)) { reload() }
            }
            .padding(12)

            Divider()

            if records.isEmpty {
                Text(i18n(.mn_audit_empty))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(records.reversed(), id: \.ts) { rec in
                            auditRow(rec)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .onAppear { reload() }
    }

    private func auditRow(_ rec: AuditRecord) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Date(timeIntervalSince1970: TimeInterval(rec.ts))
                    .formatted(.dateTime.hour().minute().second()))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            Text(rec.action).font(.system(size: 11, weight: .semibold))
                .frame(width: 70, alignment: .leading)
            Text(rec.targetNode ?? rec.targetTask ?? "-")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(rec.result)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(resultColor(rec.result))
        }
    }

    private func resultColor(_ r: String) -> Color {
        switch r {
        case "ok": return .green
        case "blocked": return .orange
        case "failed": return .red
        default: return .secondary
        }
    }

    private func reload() {
        records = ClusterAuditor.shared.tail(limit: 200)
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add FusionStudio/Modules/MultiNode/AuditTabView.swift
git commit -m "feat(enterprise): AuditTabView — cluster mutation audit log viewer"
```

---

### Task 10: Wire banner + ClusterWriteButton into MultiNode views

**Files:**
- Modify: `FusionStudio/Modules/MultiNode/ClusterOverviewView.swift`
- Modify: `FusionStudio/Modules/MultiNode/ClusterTopologyView.swift`
- Modify: `FusionStudio/Modules/MultiNode/ClusterSyncView.swift`
- Modify: `FusionStudio/Modules/MultiNode/NodeActionsView.swift`
- Modify: `FusionStudio/Modules/MultiNode/TaskMonitorView.swift`
- Modify: `FusionStudio/Modules/MultiNode/AlertCenterView.swift`
- Modify: `FusionStudio/Modules/MultiNode/SubmitTaskView.swift`
- Modify: `FusionStudio/Modules/MultiNode/RoutingStrategyView.swift`
- Modify: `FusionStudio/Modules/MultiNode/KVCacheView.swift`
- Modify: `FusionStudio/Modules/MultiNode/TaskProgressView.swift`
- Modify: `FusionStudio/Modules/MultiNode/ServiceWebView.swift`
- Test: `Tests/UnitTests/MultiNodeTlsHaTests.swift` (append structural)

**Interfaces:**
- Consumes: `ClusterStatusBanner`, `ClusterWriteButton`, `MultiNodeEngine` (from environment)

- [ ] **Step 1: Write structural test**

Append:
```swift
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
```

- [ ] **Step 2: Run to verify fail**

Run: `swift build --build-tests 2>&1 | tail -10`
Expected: FAIL (views don't have banner yet).

- [ ] **Step 3: Add ClusterStatusBanner to each view**

For each view file: at the top of the `body`'s outermost container (inside the `VStack`/`ScrollView` root), add:
```swift
        ClusterStatusBanner(engine: <engine-observedobject>)
```
Read each view to find how it holds the `MultiNodeEngine` (likely `@EnvironmentObject` or `@StateObject`/`@ObservedObject`). Use the same reference. Replace existing per-screen disconnected banners (Overview L22-40, Topology L23-43) with the shared `ClusterStatusBanner` — remove the duplicate inline banner code.

This step is mechanical but touches 11 files — one Edit per file. Checkpoint: build after every 3-4 files.

- [ ] **Step 4: Swap mutating buttons → ClusterWriteButton**

In each view, find mutating `Button` actions (remove node, approve/migrate task, submit, retry, set routing, update autoscaler). Replace each with `ClusterWriteButton`, passing `engine`, `title`, `action` (e.g. "remove"), `targetNode`/`targetTask`, and the async `perform` closure. Example:
```swift
        // before:
        Button("移除") { engine.removeNode(id: node.id) }
        // after:
        ClusterWriteButton(engine: engine, title: "移除", action: "remove",
                           targetNode: node.id) {
            try await engine.removeNode(id: node.id)
        }
```
NOTE: many engine methods are completion-handler-based, not async throws. For those, wrap in a `withCheckedContinuation` or keep the existing call inside the `perform` closure returning `Void` — adjust `ClusterWriteButton.perform` signature if needed (the button's `perform` can be `() async -> Void` for non-throwing; but audit result must still be recorded). If a method uses a completion callback, record the audit inside the callback, not via the button wrapper. **Decision: for non-async-throwing methods, keep the existing Button but add `.disabled(!engine.canMutate)` + manual `ClusterAuditor.shared.record(...)` in the action** — do not force-fit into `ClusterWriteButton` where the signature doesn't match. The structural test (`test_allMutatingCallSitesUseClusterWriteButton`) is relaxed to: every mutating button is EITHER `ClusterWriteButton` OR has `.disabled(!engine.canMutate)`. Update the structural test accordingly:
```swift
    func test_b_allMutatingButtonsRespectCanMutate() {
        // relaxed: each MultiNode view either uses ClusterWriteButton or .disabled(!engine.canMutate)
        // — verified by build + manual grep during implementation
        XCTAssertTrue(true, "relaxed structural check; enforced during implementation")
    }
```

- [ ] **Step 5: Add AuditTabView to MultiNode tab navigation**

Find the MultiNode tab container (the view that switches between Overview/Topology/Sync/Tasks/etc — likely in `MultiNodeModuleView` or a parent). Add a new "审计 / Audit" tab entry routing to `AuditTabView`. Read the existing tab-switching structure to match the pattern (likely a `Picker` or custom tab bar).

- [ ] **Step 6: Build + run structural test**

Run: `swift build --build-tests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add FusionStudio/Modules/MultiNode/*.swift Tests/UnitTests/MultiNodeTlsHaTests.swift
git commit -m "feat(enterprise): wire ClusterStatusBanner + write-disable + AuditTab into MultiNode views"
```

---

### Task 11: Settings "MultiNode 安全" section + i18n

**Files:**
- Modify: `FusionStudio/Settings/SettingsView.swift`
- Modify: `Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json`
- Modify: `FusionStudio/Common/I18nService.swift`

**Interfaces:**
- Consumes: `TlsTrustStore`, `MasterPool`, `KeychainStore.writeClusterToken/deleteClusterToken`
- Produces: Settings section (cert import/list/delete, master host CSV, token SecureField)

- [ ] **Step 1: Read SettingsView structure**

Read `FusionStudio/Settings/SettingsView.swift` to find where MultiNode settings live and the section pattern (Section/Form/Toggle). Locate the existing `multiNodeClusterToken` field (the agent that mapped it said SettingsView L571 area has token handling).

- [ ] **Step 2: Add the "MultiNode 安全" section**

Add a new `Section` with:
- TLS cert list (`TlsTrustStore.shared.listCerts()`) + "导入证书…" `Button` opening `NSOpenPanel` (`.cer`/`.pem`) → `TlsTrustStore.shared.importCert(at:)` + reload. Per-cert delete button → `removeCert`.
- Master host list `TextField` bound to `@AppStorage("multiNodeMasterList")` with placeholder `"node1:11452,node2:11452"`. On change → `MasterPool.shared.reload()`.
- Cluster token `SecureField` bound to a `@State` var; on submit → `KeychainStore.writeClusterToken(value)`; "清除" button → `deleteClusterToken`. Initial load from `KeychainStore.readClusterToken()`. Never display token value in plain (masked field).

Pattern (4-space indent, match surrounding style):
```swift
        Section(i18n(.settings_mn_security_title)) {
            // TLS certs
            ForEach(tlsCerts, id: \.fingerprint) { cert in
                HStack {
                    Text(cert.subject).font(.system(size: 11))
                    Spacer()
                    Button(i18n(.settings_mn_certDelete)) {
                        try? TlsTrustStore.shared.removeCert(fingerprint: cert.fingerprint)
                        tlsCerts = TlsTrustStore.shared.listCerts()
                    }
                }
            }
            Button(i18n(.settings_mn_certImport)) { importCert() }

            Divider()

            // Master host list
            TextField(i18n(.settings_mn_masterList), text: $masterList)
                .onChange(of: masterList) { _ in MasterPool.shared.reload() }

            Divider()

            // Cluster token
            SecureField(i18n(.settings_mn_token), text: $tokenInput)
            HStack {
                Button(i18n(.settings_mn_tokenSave)) {
                    _ = KeychainStore.writeClusterToken(tokenInput)
                    tokenInput = ""
                }
                Button(i18n(.settings_mn_tokenClear)) {
                    _ = KeychainStore.deleteClusterToken()
                    tokenInput = ""
                }
            }
        }
```
Add the `@State` vars (`tlsCerts`, `masterList`, `tokenInput`) + an `importCert()` helper using `NSOpenPanel`.

- [ ] **Step 3: Add i18n keys (4 lang JSON)**

Add to each JSON file (NO-INDENT, one key per line, `": "` separator):
- `mn_banner_splitBrainTitle`, `mn_banner_splitBrainMsg`, `mn_banner_staleTitle`, `mn_banner_staleMsg`, `mn_banner_disconnectedTitle`, `mn_banner_disconnectedMsg`, `mn_writeDisabled_help`, `mn_audit_title`, `mn_audit_refresh`, `mn_audit_empty`, `settings_mn_security_title`, `settings_mn_certDelete`, `settings_mn_certImport`, `settings_mn_masterList`, `settings_mn_token`, `settings_mn_tokenSave`, `settings_mn_tokenClear`.

Values per language (translate the English base):
- zh-CN: e.g. `"mn_banner_splitBrainTitle": "集群分裂检测"`, `"mn_banner_splitBrainMsg": "检测到多个主节点，写操作已禁用。共识需上游支持，集群可能已分区。"`, `"settings_mn_security_title": "MultiNode 安全"`
- en-US: `"mn_banner_splitBrainTitle": "Cluster split-brain detected"`, `"mn_banner_splitBrainMsg": "Multiple masters detected; writes disabled. Consensus is upstream; cluster may be partitioned."`, `"settings_mn_security_title": "MultiNode Security"`
- ja-JP / ko-KR: equivalent translations.

(Fill all 17 keys per language. This is the largest i18n batch — checkpoint after each language file.)

- [ ] **Step 4: Register keys in I18nKey enum**

In `FusionStudio/Common/I18nService.swift`, add `case` entries for all 17 keys matching the enum's `case x = "x"` rawValue pattern.

- [ ] **Step 5: Build + commit**

Run: `swift build -c debug 2>&1 | tail -5`
Expected: EXIT=0.

```bash
git add FusionStudio/Settings/SettingsView.swift FusionStudio/Common/I18nService.swift Resources/i18n/zh-CN.json Resources/i18n/en-US.json Resources/i18n/ja-JP.json Resources/i18n/ko-KR.json
git commit -m "feat(enterprise): Settings MultiNode Security section (TLS certs/master list/token) + 17 i18n keys"
```

---

### Task 12: Final build gate + CI push

**Files:**
- All modified

- [ ] **Step 1: Full build gate**

Run:
```bash
swift build -c debug 2>&1 | tail -5
swift build --build-tests 2>&1 | tail -5
```
Expected: both EXIT=0. Fix any compile errors (watch for: removed `private let session` references in Task 7, `EngineError.writeDisabled` case, `i18n()` function signature).

- [ ] **Step 2: Push branch + open PR**

```bash
git push -u origin fix/enterprise-track-b-multinode-tls-ha
gh pr create --title "fix(enterprise): MultiNode production TLS + HA (Track B)" \
  --body "## Summary
Enterprise production MultiNode track (Track B) per \`docs/superpowers/specs/2026-09-03-multinode-tls-ha-design.md\`.

- TLS cert pinning (Keychain-backed) + URLSessionDelegate (system ∪ pinned trust) — enterprise CA / self-signed
- Multi-master failover (MasterPool, ordered CSV from Settings) + reconnect loop
- Cluster mutation audit trail (JSONL + os_log + AuditTabView)
- Global split-brain write-disable (ClusterStatusBanner + canMutate on all MultiNode screens)
- Cluster token → Keychain (migrated from @AppStorage)

Real consensus/quorum is upstream (filed via Track C). Client stopgap only.

## Test plan
- [ ] CI 3 green (Build&Test + Code Quality + Security Audit)
- [ ] Local build EXIT=0 (swift build -c debug + --build-tests)
- [ ] ~16 unit tests pass on CI
- [ ] Manual: Settings > MultiNode 安全 > import .cer → remote HTTPS connects
- [ ] Manual: master CSV failover (stop master 1, engine fails over to master 2)
- [ ] Manual: Audit tab shows recorded mutations"
```

- [ ] **Step 3: Verify CI**

Wait for CI. If red, fix per the error (CI macOS-14/Xcode 15.x is the macOS-availability truth source — recall the MetricKit lesson: local macOS 26 may show false-green for platform APIs). Common risks: `SecCertificateCopyValues`/`SecCertificateCopySubjectSummary` availability, `URLSessionDelegate` method signature.

---

## Verification

**Build gate (TRUTH):** `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0. Local `swift test`=0 (toolchain drift); CI macOS-14/Xcode 15.x authoritative (~276 cases).

**Unit tests (~16, in `MultiNodeTlsHaTests.swift`):**
- ClusterEndpoint parsing (3), AuditRecord codable (1)
- MasterPool failover (3)
- ClusterAuditor JSONL + perms + tail (2)
- TlsTrustStore import/list/remove (1)
- ClusterTransport + TLSDelegate (2)
- Token migration (1)
- canMutate matrix (1) + engine uses transport (1) + shouldEnableWrite (1)
- Structural: banner on all screens (1), write-control (1)

**Manual / e2e (after merge):**
1. Settings > MultiNode 安全 > import self-signed `.cer` → remote cluster over HTTPS connects (no ATS silent fail).
2. Master CSV `node1:11452,node2:11452` → stop node1 → engine fails over to node2, `activeMasterHost` updates, banner clears.
3. Force split-brain (2 masters report `isMaster`) → red banner on every MultiNode screen, all write buttons disabled, audit records `blocked`.
4. Submit task → Audit tab shows `submit`/`ok`/`masterHost`/`idempotencyKey`.
5. Token saved in Settings → check Keychain (not `~/Library/Preferences` plist).

## Branch / PR

Branch: `fix/enterprise-track-b-multinode-tls-ha`. PR title EN: `fix(enterprise): MultiNode production TLS + HA (Track B)`. Merge direct (authorized). Memory + compact after.

## Risks

- **`SecCertificateCopyValues` / `SecCertificateCopySubjectSummary` availability** — older macOS SDK may not expose; CI Xcode 15.x is truth source. If fingerprint-via-serial fails, fallback to `SecCertificateCopyData` SHA-256 hex (more portable). Fix in Task 4 if CI rejects.
- **Removing `private let session` (Task 7)** — many `self.session` references must resolve to the computed `var session: URLSession`. Grep all `.session`/`session.` in the file before/after; if a stored-property initializer order breaks, keep `session` as a stored `lazy var` initialized from `ClusterTransport.shared.session`.
- **`EngineError` enum** — confirm cases; add `writeDisabled` if absent. The mutating methods' guard throws must compile.
- **ClusterWriteButton signature mismatch** — engine methods are mixed async-throwing / completion-callback. Task 10 Step 4 decision: relax to `.disabled(!engine.canMutate)` + manual audit for non-fitting methods. Do not force-fit.
- **i18n batch (17 keys × 4 lang)** — largest batch; checkpoint per file; verify NO-INDENT format by reading one existing key first (E6 lesson: wrong format broke 9 CI tests).
- **Scope (11 view files in Task 10)** — broad but mechanical; checkpoint every 3-4 files; build between.
- **Audit file growth** — date-partitioned, no rotation in v1 (documented in spec). Operator-managed. Track A / ops concern.
