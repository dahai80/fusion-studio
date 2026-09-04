# fusion-identity Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate fusion-identity into fusion-studio: login flow, Keychain JWT, tenant/role resolution, and forward-looking attachment of `Authorization: Bearer` + `X-Tenant-Id` to all downstream service calls; identity-gated retire of HubPermissionView local tenant CRUD.

**Architecture:** New `IdentityService` (ObservableObject) is the single auth-state source of truth, injected at app root. Bridges read headers/params from it; none own JWT logic. UDS JSON-RPC carries `_auth` in params; HTTP REST bridges carry identity headers. LoginView shown only when identity reachable + loggedOut. HubPermissionView gates on `useIdentity` (reachable+loggedIn) to source from identity API, else falls back to model-hub local UI.

**Tech Stack:** Swift 5.9, SwiftUI, Foundation (base64 JWT decode, no external dep), os.log, Keychain Services.

**Spec:** `docs/superpowers/specs/2026-09-04-fusion-identity-integration-design.md`

## Global Constraints

- 4-space multiples indent, no docstrings, clean code, logging on every non-trivial path.
- Only modify fusion-studio repo. Upstream problems (daemon_server `_auth` consumption, model-hub identity-aware mode, cowork docs) → file issue first, then PR upstream. Do NOT edit other repos in this worktree.
- Local `swift test` = 0 cases is toolchain drift (Swift 6.3.3/macOS 26); CI macOS-14/Xcode 15.x authoritative. Build gate = `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0.
- Never log JWT/refresh-token values to stdout/os_log/transcript. Log only "saved"/"set"/"cleared"/presence. Use `privacy: .public` for tenant id, never for tokens.
- i18n: add keys to all 4 lang JSON (`Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json`) for any new user-facing string; access via `@StateObject I18nManager.shared` + `i18n.t(.key)` — NEVER `@EnvironmentObject var i18n: I18nService`.
- Match existing patterns: KeychainStore wrappers return non-optional `String` (`""` on miss, see `readClusterToken` at KeychainStore.swift:137); bridges use `guard let` + semantic Error enums; tests mirror `Tests/UnitTests/Audit0902Tests.swift` (`@testable import FusionStudio`, `@MainActor`, defer-restore @AppStorage).
- JWT decode: local base64 decode of middle segment → JSON → claims. Do NOT verify HS256 signature client-side (trust the issuer; `verify` endpoint is authority). Claims `tid`/`role`/`scope`/`exp` read locally for UI; treat decoded role as advisory.
- Header attachment is forward-looking no-op until upstream enforces — acceptable, documented.

## File Structure

| File | Responsibility |
|------|----------------|
| `FusionStudio/Common/IdentityService.swift` (new ~220 lines) | Auth state machine: login/verify/refresh/resolve/logout, Keychain persistence, downstreamHeaders/downstreamAuthParams, handle401 |
| `FusionStudio/Common/IdentityModels.swift` (new ~40 lines) | `AuthState` enum, `IdentitySession` struct |
| `FusionStudio/Common/IdentityLoginView.swift` (new ~90 lines) | Login sheet UI |
| `FusionStudio/Common/KeychainStore.swift` (modify) | `readIdentityJWT`/`writeIdentityJWT`/`readIdentityRefresh`/`writeIdentityRefresh`/`clearIdentity` wrappers |
| `FusionStudio/FusionStudioApp.swift` (modify) | inject `IdentityService` env object, launch `resolveSession` in onAppear |
| `FusionStudio/Bridge/IPCClient.swift` (modify) | inject `_auth` into params in `call` when loggedIn |
| `FusionStudio/Modules/ModelHub/ModelHubAPIClient.swift` (modify) | `addIdentityHeaders` in `addAuth` |
| `FusionStudio/Modules/ModelHub/HubPermissionView.swift` (modify) | `useIdentity` gate, re-source tenant/role from IdentityService when gated |
| `FusionStudio/Modules/Simulation/SimulationBridge.swift` (modify) | identity headers on HTTP requests |
| `FusionStudio/Bridge/DocBridge.swift` (modify, HTTP sites only) | identity headers |
| `FusionStudio/Common/I18nService.swift` (modify) | 8 new I18nKey cases |
| `FusionStudio/Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json` (modify) | translations |
| `Tests/UnitTests/IdentityIntegrationTests.swift` (new ~250 lines) | 9 unit tests |

---

### Task 1: Identity models + Keychain wrappers

**Files:**
- Create: `FusionStudio/Common/IdentityModels.swift`
- Modify: `FusionStudio/Common/KeychainStore.swift` (append identity wrappers after `writeClusterToken` ~L160)
- Test: `Tests/UnitTests/IdentityIntegrationTests.swift` (create file with Keychain test only)

**Interfaces:**
- Produces: `AuthState` enum, `IdentitySession` struct, `KeychainStore.readIdentityJWT()->String`, `writeIdentityJWT(_:)->Bool`, `readIdentityRefresh()->String`, `writeIdentityRefresh(_:)->Bool`, `clearIdentity()`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import FusionStudio

@MainActor
final class IdentityIntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        KeychainStore.clearIdentity()
    }

    override func tearDown() async throws {
        KeychainStore.clearIdentity()
        try await super.tearDown()
    }

    func test_keychain_identity_roundTrip() {
        XCTAssertEqual(KeychainStore.readIdentityJWT(), "")
        XCTAssertTrue(KeychainStore.writeIdentityJWT("jwt-abc-123"))
        XCTAssertEqual(KeychainStore.readIdentityJWT(), "jwt-abc-123")
        XCTAssertTrue(KeychainStore.writeIdentityRefresh("rf-xyz-789"))
        XCTAssertEqual(KeychainStore.readIdentityRefresh(), "rf-xyz-789")
        KeychainStore.clearIdentity()
        XCTAssertEqual(KeychainStore.readIdentityJWT(), "")
        XCTAssertEqual(KeychainStore.readIdentityRefresh(), "")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift build --build-tests 2>&1 | grep -E "error:|IdentityIntegration" | head`
Expected: FAIL — `clearIdentity` / `readIdentityJWT` undefined.

- [ ] **Step 3: Write minimal implementation**

`FusionStudio/Common/IdentityModels.swift`:
```swift
import Foundation

enum AuthState: Equatable {
    case loggedOut
    case loggingIn
    case loggedIn
    case error(String)
}

struct IdentitySession: Equatable {
    let jwt: String
    let refreshToken: String
    let tenantId: String
    let tenantName: String
    let role: String
    let scopes: [String]
    let expiresAt: Date
}
```

Append to `KeychainStore.swift` after `writeClusterToken`:
```swift
    // MARK: - Identity (fusion-identity JWT + refresh)

    static func readIdentityJWT() -> String {
        readKeychain(service: "com.fusion.studio.identity", account: "jwt") ?? ""
    }

    @discardableResult
    static func writeIdentityJWT(_ value: String) -> Bool {
        writeKeychain(service: "com.fusion.studio.identity", account: "jwt", value: value)
    }

    static func readIdentityRefresh() -> String {
        readKeychain(service: "com.fusion.studio.identity", account: "refresh") ?? ""
    }

    @discardableResult
    static func writeIdentityRefresh(_ value: String) -> Bool {
        writeKeychain(service: "com.fusion.studio.identity", account: "refresh", value: value)
    }

    static func clearIdentity() {
        deleteKeychain(service: "com.fusion.studio.identity", account: "jwt")
        deleteKeychain(service: "com.fusion.studio.identity", account: "refresh")
    }
```

NOTE: verify existing `readKeychain`/`writeKeychain`/`deleteKeychain` private helper names in KeychainStore.swift before writing — match the exact signatures the existing `readClusterToken`/`writeClusterToken` use. If they are named differently, adapt.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift build --build-tests 2>&1 | grep -E "error:|Build complete" | head`
Expected: `Build complete!` (local `swift test`=0 toolchain drift; build-tests compiles = gate).

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Common/IdentityModels.swift FusionStudio/Common/KeychainStore.swift Tests/UnitTests/IdentityIntegrationTests.swift
git commit -m "feat(identity): IdentityModels + Keychain JWT/refresh wrappers (#394)"
```

---

### Task 2: IdentityService core — login, verify, refresh, resolve, JWT decode

**Files:**
- Create: `FusionStudio/Common/IdentityService.swift`
- Test: `Tests/UnitTests/IdentityIntegrationTests.swift` (append tests)

**Interfaces:**
- Consumes: `AuthState`, `IdentitySession` (Task 1), `KeychainStore.readIdentityJWT/writeIdentityJWT/readIdentityRefresh/writeIdentityRefresh/clearIdentity` (Task 1).
- Produces: `IdentityService` (ObservableObject, @MainActor) with `state`, `session`, `isIdentityReachable`, `probeHealth()`, `login(username:password:)`, `resolveSession()`, `refresh()`, `logout()`, `downstreamHeaders()`, `downstreamAuthParams()`, `handle401()`.

- [ ] **Step 1: Write the failing tests**

Append to `IdentityIntegrationTests.swift`:
```swift
    func test_jwtDecode_claims() {
        // header.{"tid":"default","role":"tenant_admin","scope":"tenants:read","exp":9999999999}.sig
        let payload = #"{"tid":"default","role":"tenant_admin","scope":"tenants:read models:read","exp":9999999999,"sub":"usr_admin"}"#
        let b64 = IdentityService.testBase64Encode(payload)
        let claims = IdentityService.decodeClaims(jwt: "header.\(b64).sig")
        XCTAssertEqual(claims?["tid"] as? String, "default")
        XCTAssertEqual(claims?["role"] as? String, "tenant_admin")
        XCTAssertEqual(claims?["exp"] as? Int, 9999999999)
    }

    func test_downstreamHeaders_loggedOut() {
        let svc = IdentityService()
        XCTAssertEqual(svc.downstreamHeaders(), [:])
        XCTAssertEqual(svc.downstreamAuthParams(), [:])
    }

    func test_downstreamHeaders_loggedIn() {
        let svc = IdentityService()
        svc.setSessionForTest(IdentitySession(
            jwt: "jwt-123", refreshToken: "rf-456", tenantId: "default",
            tenantName: "Default", role: "tenant_admin", scopes: ["tenants:read"], expiresAt: Date().addingTimeInterval(3600)))
        let h = svc.downstreamHeaders()
        XCTAssertEqual(h["Authorization"], "Bearer jwt-123")
        XCTAssertEqual(h["X-Tenant-Id"], "default")
        let p = svc.downstreamAuthParams()
        let auth = p["_auth"] as? [String: Any]
        XCTAssertEqual(auth?["jwt"] as? String, "jwt-123")
        XCTAssertEqual(auth?["tid"] as? String, "default")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift build --build-tests 2>&1 | grep -E "error:|IdentityService" | head`
Expected: FAIL — `IdentityService` undefined.

- [ ] **Step 3: Write minimal implementation**

`FusionStudio/Common/IdentityService.swift` (skeleton — fill all methods):
```swift
import Foundation
import Combine
import os.log

@MainActor
final class IdentityService: ObservableObject {
    static let shared = IdentityService()

    @Published private(set) var state: AuthState = .loggedOut
    @Published private(set) var session: IdentitySession?
    @Published private(set) var isIdentityReachable: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "identity")
    private let base = "http://127.0.0.1:11470"
    private var refreshInFlight = false

    var isLoggedIn: Bool { if case .loggedIn = state { return true }; return false }

    func probeHealth() async -> Bool { /* GET /health 5s; set isIdentityReachable; return */ }

    func login(username: String, password: String) async throws { /* POST /api/v1/auth/login {username,password} → jwt+refresh_token+tid → store Keychain + decode claims → session → .loggedIn */ }

    func resolveSession() async { /* if Keychain jwt present: decode exp; if expired → refresh(); else verify via POST /api/v1/auth/verify (service-token best-effort, ignore if 401 on verify since we trust issuer) → set session + .loggedIn. On any failure → loggedOut. */ }

    func refresh() async throws { /* POST /api/v1/auth/refresh {refresh_token} → new jwt+refresh → store + session */ }

    func logout() async { /* POST /api/v1/auth/revoke best-effort → clearIdentity + session=nil + .loggedOut */ }

    func downstreamHeaders() -> [String: String] {
        guard let s = session else { return [:] }
        return ["Authorization": "Bearer \(s.jwt)", "X-Tenant-Id": s.tenantId]
    }

    func downstreamAuthParams() -> [String: Any] {
        guard let s = session else { return [:] }
        return ["_auth": ["jwt": s.jwt, "tid": s.tenantId] as [String: Any]]
    }

    func handle401() async { /* single-flight: if !refreshInFlight → refresh once; success→stay loggedIn; fail→logout. */ }

    // MARK: - JWT decode (no signature verify; trust issuer)

    static func decodeClaims(jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payload = String(parts[1])
        guard let data = base64UrlDecode(payload) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func testBase64Encode(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
    }

    private static func base64UrlDecode(_ s: String) -> Data? {
        var b64 = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64.append("=") }
        return Data(base64Encoded: b64)
    }

    // Test hook
    func setSessionForTest(_ s: IdentitySession) { self.session = s; self.state = .loggedIn }
}
```

Implementation rules:
- `login`: parse JSON `{access_token, refresh_token, token_type, tenant_id, ...}` (confirm exact field names by reading fusion-identity `routes/auth.py` login response schema — see interface check note below). Decode claims from `access_token` for tid/role/scope/exp. Store Keychain. Set session. Log `"login: ok tenant=\(tid, privacy: .public)"` — NEVER log jwt.
- `resolveSession`: read Keychain jwt; if empty → loggedOut (no network). If present, decode exp; if `exp < now` → try `refresh()`. Else build session from claims + `.loggedIn`. Do NOT hard-require `verify` (service-token gated, may 401); verify is optional best-effort.
- `probeHealth`: `URLSession` GET `\(base)/health` with 5s timeout; 200 → reachable=true.
- All network off MainActor (`Task.detached` or `URLSession.shared.data` which is actor-agnostic); only `@Published` writes on MainActor.
- `base64UrlDecode`: handle `-`/`_` → `+`/`/` + padding.

**Interface check note:** Before implementing `login`/`refresh`, read `fusion-identity/routes/auth.py` login + refresh response schemas to confirm exact JSON field names (`access_token` vs `jwt`, `refresh_token`, `tenant_id`). Use the real field names verbatim. This is a read of an upstream repo for the API contract — allowed (reading, not modifying).

- [ ] **Step 4: Run test to verify it passes**

Run: `swift build --build-tests 2>&1 | grep -E "error:|Build complete" | head`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Common/IdentityService.swift Tests/UnitTests/IdentityIntegrationTests.swift
git commit -m "feat(identity): IdentityService core — login/verify/refresh/resolve + JWT decode (#394)"
```

---

### Task 3: IdentityService — 401 handling + refresh single-flight test

**Files:**
- Modify: `FusionStudio/Common/IdentityService.swift` (complete `handle401`)
- Test: `Tests/UnitTests/IdentityIntegrationTests.swift` (append)

**Interfaces:**
- Consumes: `refresh()`, `logout()` (Task 2).
- Produces: `handle401()` (single-flight).

- [ ] **Step 1: Write the failing test**

```swift
    func test_handle401_refreshFail_logsOut() {
        let svc = IdentityService()
        svc.setSessionForTest(IdentitySession(
            jwt: "expired", refreshToken: "bad-rf", tenantId: "default",
            tenantName: "Default", role: "tenant_admin", scopes: [], expiresAt: Date().addingTimeInterval(-10)))
        // refresh will fail (network to 11470 absent in test env) → expect logout
        let exp = expectation(description: "logout")
        Task {
            await svc.handle401()
            XCTAssertTrue(svc.session == nil)
            if case .loggedOut = svc.state { exp.fulfill() }
        }
        wait(for: [exp], timeout: 10)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift build --build-tests 2>&1 | grep -E "error:|Build complete" | head`
Expected: build compiles but test asserts logout (local run = 0 cases drift; ensure `handle401` implemented to set `.loggedOut` on refresh failure).

- [ ] **Step 3: Write minimal implementation**

Complete `handle401()`:
```swift
    func handle401() async {
        guard !refreshInFlight else { return }
        refreshInFlight = true
        defer { refreshInFlight = false }
        do {
            try await refresh()
            logger.info("handle401: refresh succeeded, staying loggedIn")
        } catch {
            logger.error("handle401: refresh failed, logging out: \(error.localizedDescription)")
            await logout()
        }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift build --build-tests 2>&1 | grep -E "error:|Build complete" | head`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Common/IdentityService.swift Tests/UnitTests/IdentityIntegrationTests.swift
git commit -m "feat(identity): handle401 single-flight refresh-then-logout (#394)"
```

---

### Task 4: i18n keys + LoginView UI

**Files:**
- Modify: `FusionStudio/Common/I18nService.swift` (8 new cases)
- Modify: `FusionStudio/Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json`
- Create: `FusionStudio/Common/IdentityLoginView.swift`
- Test: `Tests/UnitTests/IdentityIntegrationTests.swift` (append `test_useIdentity_gate` placeholder, completed in Task 7)

**Interfaces:**
- Produces: `IdentityLoginView` (View), 8 I18nKey cases.

- [ ] **Step 1: Add i18n keys to enum**

In `I18nService.swift`, after an existing identity-adjacent case (or near `hub_` keys), add:
```swift
    case identity_login_title = "identity_login_title"
    case identity_login_username = "identity_login_username"
    case identity_login_password = "identity_login_password"
    case identity_login_submit = "identity_login_submit"
    case identity_login_error = "identity_login_error"
    case identity_login_bootstrap_hint = "identity_login_bootstrap_hint"
    case identity_loggedOut_banner = "identity_loggedOut_banner"
    case identity_tenant_from_identity = "identity_tenant_from_identity"
```

- [ ] **Step 2: Add translations to all 4 lang JSON**

en-US: `"identity_login_title": "Sign in", "identity_login_username": "Username", "identity_login_password": "Password", "identity_login_submit": "Sign in", "identity_login_error": "Invalid credentials", "identity_login_bootstrap_hint": "Default admin: admin / adminpass", "identity_loggedOut_banner": "Session expired — please sign in again", "identity_tenant_from_identity": "Tenants from fusion-identity"`

zh-CN: `"identity_login_title": "登录", "identity_login_username": "用户名", "identity_login_password": "密码", "identity_login_submit": "登录", "identity_login_error": "凭据无效", "identity_login_bootstrap_hint": "默认管理员: admin / adminpass", "identity_loggedOut_banner": "会话已过期 — 请重新登录", "identity_tenant_from_identity": "来自 fusion-identity 的租户"`

ja-JP: `"identity_login_title": "サインイン", "identity_login_username": "ユーザー名", "identity_login_password": "パスワード", "identity_login_submit": "サインイン", "identity_login_error": "認証情報が無効です", "identity_login_bootstrap_hint": "デフォルト管理者: admin / adminpass", "identity_loggedOut_banner": "セッション期限切れ — 再サインインしてください", "identity_tenant_from_identity": "fusion-identity のテナント"`

ko-KR: `"identity_login_title": "로그인", "identity_login_username": "사용자 이름", "identity_login_password": "비밀번호", "identity_login_submit": "로그인", "identity_login_error": "자격 증명이 잘못되었습니다", "identity_login_bootstrap_hint": "기본 관리자: admin / adminpass", "identity_loggedOut_banner": "세션 만료 — 다시 로그인하세요", "identity_tenant_from_identity": "fusion-identity의 테넌트"`

- [ ] **Step 3: Write LoginView**

`FusionStudio/Common/IdentityLoginView.swift`:
```swift
import SwiftUI
import os.log

struct IdentityLoginView: View {
    @StateObject private var i18n = I18nManager.shared
    @ObservedObject var service: IdentityService
    @Environment(\.studioTheme) private var theme

    @State private var username = ""
    @State private var password = ""
    @State private var error: String?
    @State private var submitting = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "identity.login")

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(i18n.t(.identity_login_title)).font(.title2.bold())
            TextField(i18n.t(.identity_login_username), text: $username)
                .textFieldStyle(.roundedBorder)
            SecureField(i18n.t(.identity_login_password), text: $password)
                .textFieldStyle(.roundedBorder)
            if let error = error {
                Text(error).foregroundStyle(.red).font(.caption)
            }
            Text(i18n.t(.identity_login_bootstrap_hint)).font(.caption2).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button {
                    Task { await submit() }
                } label: {
                    Label(i18n.t(.identity_login_submit), systemImage: "arrow.right.square.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || submitting)
            }
            if submitting { ProgressView().scaleEffect(0.8) }
        }
        .padding(24)
        .frame(width: 360)
        .background(theme.surfaceSecondary)
        .cornerRadius(12)
    }

    private func submit() async {
        submitting = true
        error = nil
        do {
            try await service.login(username: username, password: password)
            logger.info("login submitted: ok user=\(username, privacy: .public)")
        } catch {
            error = i18n.t(.identity_login_error)
            logger.error("login failed: \(error.localizedDescription)")
        }
        submitting = false
    }
}
```

- [ ] **Step 4: Build gate**

Run: `swift build -c debug 2>&1 | grep -E "error:|Build complete" | head`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Common/I18nService.swift FusionStudio/Resources/i18n/*.json FusionStudio/Common/IdentityLoginView.swift
git commit -m "feat(identity): LoginView UI + 8 i18n keys (#394)"
```

---

### Task 5: App-root injection + launch resolveSession + LoginView gate

**Files:**
- Modify: `FusionStudio/FusionStudioApp.swift`

**Interfaces:**
- Consumes: `IdentityService.shared`, `IdentityLoginView` (Tasks 2, 4).
- Produces: `IdentityService` injected as `.environmentObject`, launch `resolveSession`, conditional LoginView sheet.

- [ ] **Step 1: Inject IdentityService at app root**

In `FusionStudioApp.swift`:
- Add `@StateObject private var identityService = IdentityService.shared` alongside existing `@StateObject` declarations.
- Add `.environmentObject(identityService)` to the root view (where other `.environmentObject` calls are).
- In the `onAppear`/launch block (where other service init runs), add:
```swift
        Task {
            let reachable = await identityService.probeHealth()
            identityServiceLog.info("launch: identity reachable=\(reachable, privacy: .public)")
            if reachable {
                await identityService.resolveSession()
            }
        }
```
- Add a `Logger(subsystem: "com.fusion.studio", category: "identity.app")` at file scope.
- Add a conditional LoginView overlay/sheet driven by: `identityService.isIdentityReachable && !identityService.isLoggedIn`. Wire a `.sheet(isPresented:)` binding (computed from that condition) presenting `IdentityLoginView(service: identityService)`.

- [ ] **Step 2: Build gate**

Run: `swift build -c debug 2>&1 | grep -E "error:|Build complete" | head`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add FusionStudio/FusionStudioApp.swift
git commit -m "feat(identity): app-root injection + launch resolveSession + LoginView gate (#394)"
```

---

### Task 6: Downstream attachment — UDS `_auth` + HTTP identity headers

**Files:**
- Modify: `FusionStudio/Bridge/IPCClient.swift`
- Modify: `FusionStudio/Modules/ModelHub/ModelHubAPIClient.swift`
- Modify: `FusionStudio/Modules/Simulation/SimulationBridge.swift` (or wherever sim HTTP `URLRequest` is built — locate first)
- Modify: `FusionStudio/Bridge/DocBridge.swift` (HTTP sites only — locate first)
- Test: `Tests/UnitTests/IdentityIntegrationTests.swift` (append `test_ipc_authParamsInjected` structural)

**Interfaces:**
- Consumes: `IdentityService.shared.downstreamAuthParams()` (UDS), `downstreamHeaders()` (HTTP).
- Produces: UDS params carry `_auth`; HTTP requests carry `Authorization` + `X-Tenant-Id` when loggedIn.

- [ ] **Step 1: Write the failing test**

```swift
    func test_ipc_callInjectsAuthParams_whenLoggedIn() {
        // Structural: call() merges _auth into params when loggedIn.
        let svc = IdentityService()
        svc.setSessionForTest(IdentitySession(
            jwt: "jwt-1", refreshToken: "rf-1", tenantId: "t-1",
            tenantName: "T1", role: "member", scopes: [], expiresAt: Date().addingTimeInterval(3600)))
        let merged = IPCClient.mergedAuthParams(params: ["foo": "bar"], service: svc)
        XCTAssertEqual(merged["foo"] as? String, "bar")
        let auth = merged["_auth"] as? [String: Any]
        XCTAssertEqual(auth?["tid"] as? String, "t-1")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift build --build-tests 2>&1 | grep -E "error:|mergedAuthParams" | head`
Expected: FAIL — `mergedAuthParams` undefined.

- [ ] **Step 3: Write minimal implementation — UDS**

In `IPCClient.swift`, add a static helper (testable, no live socket needed):
```swift
    static func mergedAuthParams(params: [String: Any], service: IdentityService) -> [String: Any] {
        var merged = params
        for (k, v) in service.downstreamAuthParams() {
            merged[k] = v
        }
        return merged
    }
```

Then in `call(method:params:)` (and `callOnce`), replace `params` usage with a merge: at the top of `call`, compute `let withAuth = IdentityService.shared.isLoggedIn ? IPCClient.mergedAuthParams(params: params, service: IdentityService.shared) : params` and pass `withAuth` downstream. Guard: only inject when `isLoggedIn` (loggedOut → no injection, preserves today). Log: `ipcLog.debug("call: \(method, privacy: .public) authAttached=\(IdentityService.shared.isLoggedIn, privacy: .public)")` — never log `_auth` contents.

NOTE: `IdentityService` is `@MainActor`. `call` may run off-main. Access `IdentityService.shared` guarded — since `downstreamAuthParams()` only reads `session` (a value type), capture it on main first: wrap the merge in `await MainActor.run { ... }` or capture `let svc = IdentityService.shared` and read `svc.session` via a nonisolated accessor. Simplest: add a `nonisolated func authSnapshot() -> (jwt: String, tid: String)?` to IdentityService that reads the published `session` (Stored property reads on @MainActor require isolation — instead store session in a nonisolated `var` guarded by a lock, OR capture headers synchronously on main before the async call). Decision: in `call`, do `let authParams = await MainActor.run { IdentityService.shared.downstreamAuthParams() }` once at top, then use `authParams` in the async body. Adjust `call` signature callers minimally (call is already async).

- [ ] **Step 4: Write minimal implementation — HTTP**

In `ModelHubAPIClient.addAuth`, after the `X-API-Key` setValue, add:
```swift
        addIdentityHeaders(&request)
```
and add:
```swift
    private func addIdentityHeaders(_ request: inout URLRequest) {
        Task { @MainActor in
            for (k, v) in IdentityService.shared.downstreamHeaders() {
                request.setValue(v, forHTTPHeaderField: k)
            }
        }
    }
```
NOTE: `addAuth` is synchronous (throws, not async). `URLRequest` is a struct passed inout. Reading MainActor state synchronously is unsafe. **Decision:** make `addAuth` async, OR pre-compute identity headers once per request and pass in. Cleanest: capture identity headers in the async `get/post/put/patch/delete` wrappers (they are async) before calling `addAuth`. Change `addAuth` to `addAuth(_ request: inout URLRequest, identityHeaders: [String: String])` and in each async wrapper: `let idHeaders = await MainActor.run { IdentityService.shared.downstreamHeaders() }; try addAuth(&request, identityHeaders: idHeaders)`. Apply `idHeaders` via `setValue` inside `addAuth`.

For SimulationBridge and DocBridge HTTP sites: locate the `URLRequest` construction (`grep -n "URLRequest\|setValue\|httpMethod" <file>`), add the same `identityHeaders` capture + `setValue` loop. Only touch HTTP `URLRequest` sites, not UDS/JSON-RPC sites in DocBridge.

- [ ] **Step 5: Build + test gate**

Run: `swift build --build-tests 2>&1 | grep -E "error:|Build complete" | head`
Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add FusionStudio/Bridge/IPCClient.swift FusionStudio/Modules/ModelHub/ModelHubAPIClient.swift FusionStudio/Modules/Simulation/SimulationBridge.swift FusionStudio/Bridge/DocBridge.swift Tests/UnitTests/IdentityIntegrationTests.swift
git commit -m "feat(identity): attach _auth to UDS params + identity headers to HTTP (#394)"
```

---

### Task 7: HubPermissionView identity-gated re-source

**Files:**
- Modify: `FusionStudio/Modules/ModelHub/HubPermissionView.swift`
- Test: `Tests/UnitTests/IdentityIntegrationTests.swift` (append `test_useIdentity_gate`)

**Interfaces:**
- Consumes: `IdentityService.shared` (`isIdentityReachable`, `session`).
- Produces: `useIdentity` computed gate; tenant/role sourced from identity session when gated; local create/delete hidden.

- [ ] **Step 1: Write the failing test**

```swift
    func test_useIdentity_gate() {
        let svc = IdentityService()
        XCTAssertFalse(svc.isIdentityReachable && svc.session != nil) // default unreachable
        svc.setSessionForTest(IdentitySession(
            jwt: "j", refreshToken: "r", tenantId: "default",
            tenantName: "Default", role: "tenant_admin", scopes: [], expiresAt: Date().addingTimeInterval(3600)))
        // useIdentity = isIdentityReachable && session != nil
        // isIdentityReachable must be settable for test → add setReachableForTest
        svc.setReachableForTest(true)
        XCTAssertTrue(svc.useIdentity)
        svc.setReachableForTest(false)
        XCTAssertFalse(svc.useIdentity)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift build --build-tests 2>&1 | grep -E "error:|useIdentity|setReachableForTest" | head`
Expected: FAIL — `useIdentity`/`setReachableForTest` undefined.

- [ ] **Step 3: Write minimal implementation — IdentityService**

Add to `IdentityService.swift`:
```swift
    var useIdentity: Bool { isIdentityReachable && session != nil }
    func setReachableForTest(_ v: Bool) { isIdentityReachable = v }
```

- [ ] **Step 4: Modify HubPermissionView**

In `HubPermissionView.swift`:
- Add `@EnvironmentObject var identityService: IdentityService`.
- Add computed `private var useIdentity: Bool { identityService.useIdentity }`.
- In the tenant list render (around L240-290): when `useIdentity`, render tenant from `identityService.session` (tenantId/tenantName/role) read-only, and hide `showCreateTenant` trigger / `deleteTenant` button / local role create-delete buttons. When `!useIdentity`, current behavior.
- Add a header label `i18n.t(.identity_tenant_from_identity)` when `useIdentity`.
- Do NOT remove any model-hub tenant API methods — gate them behind `!useIdentity`.

Minimal: wrap the create/delete controls in `if !useIdentity { ... }`, and in the tenant list `if useIdentity { IdentityTenantRow(session) } else { /* existing HubTenant rows */ }`.

- [ ] **Step 5: Build + test gate**

Run: `swift build --build-tests 2>&1 | grep -E "error:|Build complete" | head`
Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add FusionStudio/Common/IdentityService.swift FusionStudio/Modules/ModelHub/HubPermissionView.swift Tests/UnitTests/IdentityIntegrationTests.swift
git commit -m "feat(identity): HubPermissionView identity-gated tenant/role re-source (#394)"
```

---

### Task 8: JWT-never-logged structural test + final build gate

**Files:**
- Test: `Tests/UnitTests/IdentityIntegrationTests.swift` (append)

- [ ] **Step 1: Write the structural test**

```swift
    func test_jwtNeverLogged() {
        // Structural: IdentityService.swift must not interpolate jwt/refreshToken values into any logger call.
        let url = URL(fileURLWithPath: #file)
        let dir = url.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FusionStudio").appendingPathComponent("Common")
        let svcFile = (try? String(contentsOf: dir.appendingPathComponent("IdentityService.swift"), encoding: .utf8)) ?? ""
        XCTAssertFalse(svcFile.contains("logger.\\(.*jwt"), "jwt value must not be logged")
        XCTAssertFalse(svcFile.contains("\\(.*jwt, privacy"), "jwt value must not be in logger interpolation")
        // Allow only presence words
        XCTAssertTrue(svcFile.contains("privacy: .public"), "expected public privacy annotations")
    }
```

- [ ] **Step 2: Build + test gate**

Run: `swift build -c debug 2>&1 | grep -E "error:|Build complete" | head`
Run: `swift build --build-tests 2>&1 | grep -E "error:|Build complete" | head`
Expected: both `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Tests/UnitTests/IdentityIntegrationTests.swift
git commit -m "test(identity): structural guard — jwt never logged (#394)"
```

---

### Task 9: File upstream issues (issue-first, not code in this repo)

**Files:** none (GitHub issues against upstream repos)

- [ ] **Step 1: File issue against fusion-agent-studio**

Title: `daemon_server.py should consume _auth (jwt/tid) from JSON-RPC params for tenant context`
Body: reference this PR's UDS `_auth` injection; explain daemon currently ignores extra params; request it read `params._auth.tid` + verify jwt via fusion-identity `/verify` and enforce tenant scoping on UDS calls. Note Shell sends `_auth` when logged in (forward-looking).

- [ ] **Step 2: File issue against fusion-model-hub**

Title: `Accept Authorization: Bearer + X-Tenant-Id alongside X-API-Key (identity-aware mode)`
Body: model-hub currently `X-API-Key` only; request an identity-aware mode accepting `Authorization: Bearer` + `X-Tenant-Id` from fusion-identity, opt-in. Shell already attaches these headers forward-looking.

- [ ] **Step 3: File issue against fusion-cowork**

Title: `Document FUSION_IDENTITY_ENABLED production path + Shell integration contract`
Body: cowork already has `FUSION_IDENTITY_ENABLED` opt-in; request production defaults doc + confirm Shell's `Authorization: Bearer` + `X-Tenant-Id` contract matches.

- [ ] **Step 4: Record issue URLs in commit + PR body**

Add the 3 issue URLs to the final PR body under "Upstream issues filed".

---

## Verification

**Build gate (TRUTH):** `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0. Local `swift test`=0 (toolchain drift); CI macOS-14/Xcode 15.x authoritative.

**Unit tests (9, in IdentityIntegrationTests.swift):**
1. `test_keychain_identity_roundTrip` — Keychain JWT/refresh write/read/clear.
2. `test_jwtDecode_claims` — local base64 decode → tid/role/exp.
3. `test_downstreamHeaders_loggedOut` — `[:]`.
4. `test_downstreamHeaders_loggedIn` — Authorization + X-Tenant-Id.
5. `test_downstreamAuthParams_loggedIn` — `_auth` dict.
6. `test_handle401_refreshFail_logsOut` — refresh fail → loggedOut.
7. `test_ipc_callInjectsAuthParams_whenLoggedIn` — UDS merge.
8. `test_useIdentity_gate` — reachable+session → true.
9. `test_jwtNeverLogged` — structural no-jwt-in-logger.

**Manual / e2e (after merge, user re-验收):**
1. Start fusion-identity (`cd ~/fusion/fusion-identity && ./start.sh start`), launch studio → LoginView appears → login `admin/adminpass` → session established, tenant "default" shown in HubPermissionView from identity.
2. Stop fusion-identity → relaunch studio → no LoginView, HubPermissionView falls back to model-hub local tenant UI.
3. Inspect (debug log) a downstream UDS call carries `_auth` when logged in; absent when logged out.
4. Expire session (wait) → 401 path → refresh or re-login.

## Branch / PR

Branch: `feat/394-fusion-identity-integration`. PR title EN: `feat(#394): integrate fusion-identity — login, Keychain JWT, downstream auth headers, identity-gated tenant UI`. CI green required. Merge direct (authorized). Memory + compact after.
