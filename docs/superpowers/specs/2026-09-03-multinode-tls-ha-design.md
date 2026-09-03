# MultiNode Production TLS + HA — Design

> **Status:** Approved 2026-09-03. Implements the enterprise production MultiNode track (Track B). Brainstorming → spec → plan → implementation.

## Context

Fusion Studio's `MultiNodeEngine` is a thin HTTP client over a remote `fusion-multi-node` MasterServer (FastAPI, default `http://127.0.0.1:11452`). Enterprise production audit (`audit/fusion-studio-audit-result-product-0902.md` + `0827.md`) found the cluster path not enterprise-ready: single-master hard failure, no TLS trust control beyond macOS default ATS, token in plaintext `@AppStorage`, split-brain only a client-side `>1 master` heuristic surfaced on one screen, `nodesStale` flag implemented but never wired to any view, no audit trail of cluster mutations.

User decision (2026-09-03): cluster level = **生产可用 + TLS + HA** — production-ready remote node TLS cert validation supporting enterprise CA / self-signed pinning + failover + split-brain auto-recovery (client-side stopgap pending upstream consensus) + centralized audit logging.

This spec covers **only in-app Swift work**. Real consensus/quorum/leader-election is upstream (`fusion-multi-node`) and filed as a separate issue (Track C). The client does what it can: global write-disable on detected split-brain, failover across an operator-configured master list, trust evaluation with pinned certs, audit trail.

## Scope

In scope:
- TLS trust store (Keychain-backed pinned certs) + `URLSessionDelegate` for remote cluster HTTPS.
- Multi-master failover pool (manual ordered host list from Settings) + reconnect loop.
- Cluster mutation audit trail (local JSONL + os_log + Audit tab view).
- Global cluster-status surface: split-brain red banner + write-disable on ALL MultiNode screens; `nodesStale` amber banner; `lastError` propagation.
- Cluster token → Keychain (out of `@AppStorage`/UserDefaults).
- Settings UI: "MultiNode 安全" section (TLS cert import, master host CSV, token field masked + Keychain-backed).

Out of scope (filed upstream, Track C):
- Real consensus / quorum / leader election / fencing / epoch (fusion-multi-node).
- `exclude_nodes` honored server-side + server-side idempotency (`#23/#31`).
- Backend bundling (Track A).
- mTLS client identity (deferred — pinning import covers enterprise CA + self-signed; mTLS adds client-cert config surface, not needed for v1).

## Non-goals / explicit limitations

- **Split-brain is a heuristic, not consensus.** The client reads one master's `/api/nodes`. If two genuinely partitioned masters each report themselves sole, the client sees nothing. This spec makes the heuristic's consequence loud (global write-disable) and honest (banner text states "consensus is upstream; cluster may be partitioned"). It does not pretend to solve partition detection.
- **Failover is operator-configured, not auto-discovered.** No `/api/peers` auto-discovery (endpoint may not exist upstream; keeps client self-contained). Admin maintains the ordered master list.
- **No task-level automatic rescheduling.** Migration stays manual UI; `retryTask` stays the automated path. Automatic reschedule-on-node-death is upstream scheduling, not client work.

## Architecture

`MultiNodeEngine` remains the single `ObservableObject` source of cluster truth. Four new collaborators sit beside it; the engine delegates transport, trust, failover, and audit to them.

```
Settings ──► MasterPool (ordered [ClusterEndpoint], failover)
        ──► TlsTrustStore (Keychain pinned certs)
        ──► KeychainStore (cluster token, reuse #266)
                │
                ▼
        ClusterTransport (URLSession + ClusterTLSDelegate + MasterPool)
                │  (one active master; failover on connect failure)
                ▼
        MultiNodeEngine ──► ClusterAuditor (JSONL + os_log on every mutation)
           │  @Published: isConnected, splitBrainDetected, nodesStale,
           │              canMutate, lastError, activeMasterHost
           ▼
        MultiNode views ──► ClusterStatusBanner (global) + .clusterWriteDisabled()
                        ──► AuditTabView (reads JSONL tail)
```

## Components

### 1. TlsTrustStore.swift (new, ~120 lines)

Keychain-backed store for pinned TLS certificates. Admin imports `.cer`/`.pem` (DER/PEM `SecCertificate`) via Settings file picker.

- `func importCert(at url: URL) throws` — read file, `SecCertificateCreateWithData`, `SecItemAdd` to Keychain (service `com.fusion.studio.cluster-tls`, account = SHA-256 fingerprint).
- `func pinnedAnchors() -> [SecCertificate]` — `SecItemCopyMatching` all certs in service.
- `func removeCert(fingerprint: String) throws`.
- `func listCerts() -> [CertSummary]` (fingerprint + subject summary).
- Dedup by fingerprint. Store under `kSecClassCertificate`? No — use `kSecClassGenericPassword` wrapping the DER data (avoids system Keychain cert-item sharing/visibility surprises on macOS; keeps it app-scoped). Account = fingerprint hex.

Logger: `Logger(subsystem: "com.fusion.studio", category: "TlsTrustStore")`.

### 2. ClusterTLSDelegate.swift (new, ~80 lines)

`NSObject` + `URLSessionDelegate`. Implements `urlSession(_:didReceive:completionHandler:completionHandler:)`:

- Build `SecTrust` with `serverTrust` + append `TlsTrustStore.shared.pinnedAnchors()` as extra anchors.
- `SecTrustEvaluateWithError` → on success `.useCredential`; on failure log fingerprint mismatch (no secret leaked) + `.cancelCredentialTrusting`.
- Local `127.0.0.1`/`localhost` (scheme `http://`) never reaches delegate (plain HTTP) — delegate only attached to HTTPS sessions.
- mTLS hook: optional `clientIdentity: SecIdentity?` — v1 leaves nil (no mTLS); field reserved.

Logger: `Logger(subsystem: "com.fusion.studio", category: "ClusterTLS")`.

### 3. MasterPool.swift (new, ~90 lines)

Operator-configured ordered master list with failover.

- `struct ClusterEndpoint: Equatable { host: String; port: Int }`.
- `endpoints: [ClusterEndpoint]` parsed from `@AppStorage("multiNodeMasterList")` CSV (e.g. `node1.corp:11452,node2.corp:11452`).
- `private var activeIndex: Int = 0`.
- `var active: ClusterEndpoint?` — current master (nil if list empty).
- `func advance() -> ClusterEndpoint?` — on connect failure: `activeIndex = (activeIndex+1) % count`; returns new active. Backoff between advances delegated to caller (engine poll loop already has exponential backoff).
- `func reset()` — retry from index 0 (used on manual reconnect / Settings change).
- Notification `masterPoolChanged` when `@AppStorage` updates (observed via `UserDefaults.didChangeNotification` + diff).
- Empty list → falls back to legacy single `FusionConfig.multiNodeBaseURL` (backward compat: if `multiNodeMasterList` unset, pool = `[current single endpoint]`).

Logger: `Logger(subsystem: "com.fusion.studio", category: "MasterPool")`.

### 4. ClusterAuditor.swift (new, ~100 lines)

Append-only local audit trail of cluster mutations.

- `func record(action: String, targetNode: String?, targetTask: String?, result: String, idempotencyKey: String?, masterHost: String?)`.
- Actor: derived from `FusionConfig` — `Host.current.localizedName ?? "unknown"` + configured user label (`@AppStorage("clusterAuditActorLabel")`, default `""`).
- Writes JSONL to `~/.fusion-studio/logs/cluster-audit-YYYYMMDD.log` (dir 0700, file 0600, `FileManager.setAttributes`).
- Each line: `{"ts":<epoch>, "actor":"...", "action":"remove|approve|migrate|retry|submit|setRouting|...", "targetNode":"...", "targetTask":"...", "result":"ok|blocked|failed", "idempotencyKey":"...", "masterHost":"..."}`.
- Mirrors to `os_log` (`Logger(... category: "ClusterAudit")`) with `.public` on non-secret fields (action/target/result/masterHost), no token/secret logged.
- `func tail(limit: Int) -> [AuditRecord]` — read last N lines for Audit tab (best-effort, file may be large; read from EOF backwards in 4KB chunks).
- `AuditRecord: Codable` mirrors the JSONL schema.

### 5. MultiNodeEngine changes (modify existing)

- Replace single `baseURL` usage with `MasterPool.shared.active` → URL. All `fetch*`/`submit*`/`remove*`/etc. resolve URL from pool, not `FusionConfig.multiNodeBaseURL` directly. (Keep `multiNodeBaseURL` computed for backward-compat single-endpoint case.)
- `URLSession.shared` → `ClusterTransport.shared.session` (a `URLSession` initialized with `ClusterTLSDelegate` + `.default` config). Local `http://` endpoints: delegate attached but no-op for plain HTTP (TLS challenge not received).
- `checkHealth` (currently zero callers) → wire into poll loop: each tick, if `!isConnected`, call `checkHealth` against `MasterPool.advance()`; on success set `isConnected=true`, `activeMasterHost`, reset `consecutiveFailuresByContext`. This is the reconnect loop.
- New `@Published var canMutate: Bool` = `isConnected && !splitBrainDetected`. All mutating methods (`removeNode`, `approveTask`, `migrateTask`, `submitTask`, `retryTask`, `setRoutingStrategy`, `updateAutoscalerConfig`) guard `canMutate` first → throw `EngineError.writeDisabled` if not, and audit `result:"blocked"`.
- New `@Published var activeMasterHost: String?` — surfaces which master is active (banner + audit).
- `nodesStale` → already set; now consumed by new global banner (Component 6).
- `splitBrainDetected` → already set; now drives `canMutate` + global banner (not just topology screen).
- Every mutating method: call `ClusterAuditor.shared.record(...)` before and after (before: `result:"attempt"`? no — record once after with actual result: `ok`/`failed`/`blocked`). Include `idempotencyKey` for submit/retry.
- Token: replace `FusionConfig.multiNodeResolvedToken` (reads `@AppStorage`) with `KeychainStore.shared.readClusterToken()` (new Keychain method). Settings writes token to Keychain, not `@AppStorage`. Backward compat: on first launch migrate existing `@AppStorage("multiNodeClusterToken")` → Keychain, then clear `@AppStorage`.

### 6. UI — ClusterStatusBanner + write-disable modifier + Audit tab (new)

- **`ClusterStatusBanner.swift`** (new, ~90 lines) — SwiftUI view reading `engine.splitBrainDetected`/`nodesStale`/`isConnected`/`activeMasterHost`. Renders (priority): red split-brain (text: cluster may be partitioned, consensus is upstream, writes disabled) → amber stale (data may be outdated, still usable read-only) → orange disconnected (lastError + active master). Deep-link button → Settings MultiNode 安全.
- **`.clusterWriteDisabled()` ViewModifier** — applied to every MultiNode screen root. When `!engine.canMutate`, disables all `Button`s in subtree via `environment(\.isEnabled, false)` on mutating controls? SwiftUI has no clean "disable only mutating" — instead bind each mutating button `.disabled(!engine.canMutate)` + `.help(engine.canMutate ? "" : "集群分裂或断连，写操作已禁用")`. The modifier is a convention helper: `.clusterWriteControl(engine:engine)` that returns a configured `Button` style. Simpler: a small `ClusterWriteButton` wrapper component that takes the action + auto-disables + audit-wraps. **Decision: `ClusterWriteButton` wrapper** — explicit, no environment magic, every mutating call site uses it.
- Apply `ClusterStatusBanner` at top of each MultiNode view (`ClusterOverviewView`, `ClusterTopologyView`, `ClusterSyncView`, `NodeActionsView`, `TaskMonitorView`, `AlertCenterView`, `SubmitTaskView`, `RoutingStrategyView`, `KVCacheView`, `TaskProgressView`, `ServiceWebView`). Replace existing per-screen disconnected banners (Overview L22-40, Topology L23-43) with the shared component for consistency.
- **`AuditTabView.swift`** (new, ~80 lines) — new MultiNode tab. Reads `ClusterAuditor.shared.tail(limit: 200)`, renders chronological list (action / target / result / masterHost / timestamp). Refresh button. File path displayed (read-only).

### 7. Settings — "MultiNode 安全" section (modify SettingsView)

- New section with 3 controls:
  - **TLS 证书** — list of pinned certs (`TlsTrustStore.listCerts()`), "导入证书…" `NSOpenPanel` (`.cer`/`.pem`), per-cert delete. On import → `TlsTrustStore.importCert`.
  - **Master 主机列表** — `TextEditor`/`TextField` bound to `@AppStorage("multiNodeMasterList")` CSV. Placeholder shows format. On change → `MasterPool.shared.reset()`.
  - **集群 Token** — masked `SecureField` bound to a `@State` that on submit writes `KeychainStore.shared.writeClusterToken(value)`. Reads initial from Keychain. "清除" button. Never displays token in transcript (only masked dots in UI; logs never print token).
- i18n keys for all 3 controls + banner strings (4 lang JSON).

## Data flow

1. **Boot** — `MultiNodeEngine.init` → `MasterPool.shared` loads CSV (or legacy single endpoint) → `ClusterTransport.shared` builds `URLSession(ClusterTLSDelegate)`.
2. **Poll tick** — engine fetches `/api/nodes` via transport against `MasterPool.active`. TLS delegate evaluates trust (system ∪ pinned). On success → update `nodes`, `isConnected=true`, `activeMasterHost`. On failure → `MasterPool.advance()`, backoff, next tick retries new master. ≥3 consecutive failures across all masters → `isConnected=false`.
3. **Split-brain** — `fetchNodes` counts `isMaster` from active master's response; `≥2 masters` for `≥2` polls → `splitBrainDetected=true` → `canMutate=false` → all `ClusterWriteButton`s disabled + red banner on every screen.
4. **Mutation** — user taps `ClusterWriteButton` → guard `canMutate` (else audit `blocked` + throw) → perform HTTP → audit `ok`/`failed` with actor/action/target/masterHost/idempotencyKey.
5. **Token** — engine reads token from `KeychainStore` per request (not held in `@Published`); header `Authorization: Bearer <token>` over HTTPS (remote) — never plaintext HTTP for remote (scheme guard already enforces https for non-localhost).

## Error handling

- **TLS handshake fail** — `isConnected=false`, banner "远程集群证书不受信任 — 在设置 > MultiNode 安全导入证书", no crash, no token logged.
- **All masters unreachable** — `isConnected=false`, `nodesStale=true` (keep last snapshot), amber+orange banner, write-disable.
- **Split-brain** — `canMutate=false`, red banner, mutation attempts audited as `blocked`.
- **Keychain read fail (token)** — treat as no-token; master returns 401 → `EngineError.authFailed` (existing) + banner. Do not crash.
- **Cert import fail (bad file)** — Settings shows error, no Keychain write, log error.
- **Audit file write fail** — log error, do NOT block the mutation (audit is best-effort; a failed audit log must not prevent a legit cluster op).

## Testing

Unit tests in `Tests/UnitTests/MultiNodeTlsHaTests.swift` (new), mirroring `AuditProduct0902Tests.swift` patterns (`@testable import FusionStudio`, `@MainActor`, defer-restore):

- `test_masterPool_parsesCsvAndFailover` — CSV `"a:1,b:2"` → 2 endpoints; `advance()` cycles a→b→a.
- `test_masterPool_emptyFallsBackToLegacy` — empty CSV → single legacy `multiNodeBaseURL` endpoint.
- `test_masterPool_resetReturnsToFirst` — advance twice, `reset()` → first endpoint.
- `test_clusterAuditor_writesJsonlAndPerms` — `record(...)` → file exists, line valid JSON, `0600` perms, dir `0700`. Cleanup after.
- `test_clusterAuditor_tailReturnsLastN` — write 5 records, `tail(3)` → last 3 in order.
- `test_canMutate_matrix` — `(isConnected, splitBrainDetected)` → `canMutate`: (true,false)=true, (false,*)=false, (true,true)=false.
- `test_tlsTrustStore_importListRemoveRoundTrip` — import a self-signed cert fixture (generated in-test via `SecCertificateCreateWithData` from a DER blob), `listCerts` includes it, `removeCert` removes it. (Use a static test DER if available; else skip cert-content assertion, test only the add/remove plumbing with a minimal valid DER. If generating a valid cert in-test is impractical, mark test with `XCTSkip` on macOS CI without cert fixture and rely on structural test.)
- `test_tokenMigratesAppStorageToKeychain` — set `@AppStorage("multiNodeClusterToken")` = "test-tok", trigger migration, assert Keychain holds it + `@AppStorage` cleared. Cleanup Keychain + `@AppStorage`.
- `test_clusterWriteButton_disabledWhenNotMutatable` — structural/state: `ClusterWriteButton` with `engine.canMutate=false` → button disabled (verify via `UIButton`? no — SwiftUI; verify the binding logic via a small extracted `func shouldEnable(canMutate: Bool) -> Bool` pure helper used by the button, test that).

Structural / compile-time (grep-verify, like T1-2):
- `test_engineUsesClusterTransportNotSharedSession` — grep `MultiNodeEngine.swift` for `URLSession.shared` absence + `ClusterTransport` presence.
- `test_allMultiNodeScreensHaveStatusBanner` — grep each MultiNode view for `ClusterStatusBanner` usage.
- `test_allMutatingCallSitesUseClusterWriteButton` — grep mutating views for `ClusterWriteButton`.

Build gate (TRUTH): `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0. Local `swift test`=0 (toolchain drift); CI macOS-14/Xcode 15.x authoritative.

## Files

| File | Action | Responsibility |
|------|--------|----------------|
| `FusionStudio/Modules/MultiNode/Security/TlsTrustStore.swift` | new | Keychain pinned certs |
| `FusionStudio/Modules/MultiNode/Security/ClusterTLSDelegate.swift` | new | URLSession TLS trust eval |
| `FusionStudio/Modules/MultiNode/Security/MasterPool.swift` | new | ordered failover master list |
| `FusionStudio/Modules/MultiNode/Security/ClusterAuditor.swift` | new | JSONL audit trail + os_log |
| `FusionStudio/Modules/MultiNode/Security/ClusterTransport.swift` | new | URLSession factory w/ delegate |
| `FusionStudio/Modules/MultiNode/ClusterStatusBanner.swift` | new | global status banner view |
| `FusionStudio/Modules/MultiNode/ClusterWriteButton.swift` | new | mutating-button wrapper (auto-disable + audit) |
| `FusionStudio/Modules/MultiNode/AuditTabView.swift` | new | audit log viewer tab |
| `FusionStudio/Modules/MultiNode/MultiNodeEngine.swift` | modify | pool/transport/audit/canMutate/reconnect wiring |
| `FusionStudio/Modules/MultiNode/MultiNodeModels.swift` | modify | `AuditRecord` Codable + endpoint types if needed |
| `FusionStudio/Modules/MultiNode/*.swift` (views) | modify | add `ClusterStatusBanner`, swap mutating buttons → `ClusterWriteButton` |
| `FusionStudio/Settings/SettingsView.swift` | modify | "MultiNode 安全" section (certs/master list/token) |
| `FusionStudio/Common/KeychainStore.swift` | modify | `readClusterToken`/`writeClusterToken`/`deleteClusterToken` |
| `Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json` | modify | new keys |
| `Tests/UnitTests/MultiNodeTlsHaTests.swift` | new | tests above |

## Risks

- **`ClusterWriteButton` migration** — many mutating call sites across ~10 views. Mechanical but broad; checkpoint per view. Risk: missing a call site leaves a non-audited, non-disabled button. Mitigation: structural test `test_allMutatingCallSitesUseClusterWriteButton` + grep sweep before merge.
- **Keychain cert storage via `kSecClassGenericPassword`** — unconventional (certs usually `kSecClassCertificate`) but keeps app-scoped + avoids macOS Keychain Access prompt surprises. Risk: IT tooling expects cert items. Mitigation: documented; reversible; v2 can switch to `kSecClassCertificate` if IT requires.
- **`MasterPool` + legacy single endpoint** — backward compat must not break existing single-machine users (who use `127.0.0.1:11452` over HTTP, no TLS). Mitigation: empty `multiNodeMasterList` → pool = `[legacy single endpoint]`; HTTP for localhost; delegate no-op for plain HTTP. Tested.
- **Split-brain false positive** — `>1 master` from a single snapshot could misfire if master reports stale peer-is-also-master metadata. Mitigation: existing `≥2 consecutive polls` threshold stays; banner text is honest about limitation.
- **Audit file growth** — unbounded JSONL. Mitigation (this spec): date-partitioned files (`cluster-audit-YYYYMMDD.log`), no rotation in v1 (operator-managed); document retention in banner/Settings tooltip. (Rotation/logrotate is a Track A / ops concern, noted.)
- **TLS delegate on local HTTP** — attaching delegate to a session used for both `http://127.0.0.1` and `https://remote` is fine (challenge callback only fires for HTTPS). Verified by Apple docs. No risk.
