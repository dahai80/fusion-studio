# fusion-identity Integration — Design Spec

> Status: DRAFT. Issue #394. Multi-tenant PRD §4. Shell = client of fusion-identity.

## Context

`fusion-identity` (port 11470, `POST /api/v1/auth/login`, JWT HS256, sole tenant registry) is the ecosystem's identity layer. fusion-studio (the SwiftUI Shell) currently has **no** integration: no login, no JWT, no `X-Tenant-Id` on downstream calls, and `HubPermissionView` manages tenants/roles against model-hub's local registry (a function PRD §3 reserves for fusion-identity).

**Upstream enforcement is opt-in / absent today:** model-hub uses `X-API-Key` (no JWT); cowork has `FUSION_IDENTITY_ENABLED` defaulting OFF; the central UDS daemon (`daemon_server.py`) does not read tenant/auth from JSON-RPC params. So attaching headers/params is forward-looking — a no-op until upstream services install tenant middleware, but the client must be ready first.

**Locked decisions (user-approved 2026-09-04):**
1. **Full forward-looking** — login flow + Keychain JWT + tenant/role resolution + attach `Authorization: Bearer` + `X-Tenant-Id` on ALL downstream (UDS JSON-RPC params + HTTP headers). No-op until upstream enforces; client ready.
2. **Identity-gated retire** — when fusion-identity reachable + user logged in, `HubPermissionView` sources from identity API and hides local create/delete; when identity unreachable, falls back to current model-hub local UI (no hard break for single-machine dev).

## Out of scope (upstream, issue-first per repo rule)

- Modifying fusion-agent-studio `daemon_server.py` to consume `_auth` from JSON-RPC params.
- Modifying fusion-model-hub to accept JWT/`X-Tenant-Id` (still `X-API-Key`).
- Modifying fusion-cowork (its `FUSION_IDENTITY_ENABLED` opt-in is upstream-owned).
- The `install_tenant_middleware` data-plane — Shell is a client, not a data-plane service.

These are filed as upstream issues (issue-first, PR-after). The Shell integration is built against the identity **API contract** (frozen surface in fusion-identity `CLAUDE.md`) and degrades gracefully when the service is absent.

## Architecture

New `IdentityService` (ObservableObject) is the single source of truth for auth state, injected at app root alongside `AppState`/`IPCClient`. All bridges read identity headers/params from it; none own JWT logic.

```
┌─────────────┐   login   ┌────────────────┐
│ LoginView   │──────────▶│ IdentityService│── Keychain (jwt, refresh) ──▶
└─────────────┘           │  @MainActor    │── GET /tenants  ──▶ tenant/role
       ▲                  └───────┬────────┘
       │ no cached JWT / 401       │ headers/params
┌──────┴───────┐          ┌────────▼─────────┐
│  AppState    │          │ IPCClient        │ UDS: params["_auth"] = {jwt, tid}
│ (launch gate)│          │ + HTTP bridges   │ HTTP: Authorization + X-Tenant-Id
└──────────────┘          └──────────────────┘
```

### Identity service contract (Swift)

`IdentityService: ObservableObject` in `FusionStudio/Common/IdentityService.swift`.

Published state:
- `state: AuthState` — enum `.loggedOut | .loggingIn | .loggedIn(session) | .error(String)`
- `session: IdentitySession?` — `{ jwt: String, refreshToken: String, tenantId: String, tenantName: String, role: String, scopes: [String], expiresAt: Date }` (jwt/refresh held in memory; Keychain is the persistent store)
- `isIdentityReachable: Bool` — health probe `GET http://127.0.0.1:11470/health` (5s timeout, app-level scenePhase poll like F-A9, 30s interval)

Methods (all async, `@MainActor` for published state; network off MainActor):
- `probeHealth() async -> Bool`
- `login(username:password:) async throws` — `POST /api/v1/auth/login` → JWT + refresh → store Keychain + populate session (decode claims `tid/role/scope/exp` locally).
- `resolveSession() async` — on launch: if Keychain JWT present + not expired → decode + verify via `POST /api/v1/auth/verify` (service-token gated; if verify 401, try refresh); if expired → refresh; if refresh fails → loggedOut.
- `refresh() async throws` — `POST /api/v1/auth/refresh`.
- `logout() async` — `POST /api/v1/auth/revoke` (best-effort) → clear Keychain + session.
- `downstreamHeaders() -> [String: String]` — `["Authorization": "Bearer \(jwt)", "X-Tenant-Id": tenantId]` when `.loggedIn`, else `[:]`. **Never logs jwt value.**
- `downstreamAuthParams() -> [String: Any]` — `["_auth": ["jwt": jwt, "tid": tenantId]]` when loggedIn, else `[:]` for UDS JSON-RPC params.
- `handle401() async` — on 401 from downstream: one refresh attempt; if still failing → `.loggedOut` + surface re-login.

### Keychain storage

New wrappers in `KeychainStore.swift` (mirror existing `readClusterToken`/`writeClusterToken` non-optional `String` pattern):
- `readIdentityJWT() -> String`, `writeIdentityJWT(_:) -> Bool`
- `readIdentityRefresh() -> String`, `writeIdentityRefresh(_:) -> Bool`
- Clear both on logout. Service/account keys distinct from cluster token.

### Login UI

`FusionStudio/Common/IdentityLoginView.swift` — SwiftUI sheet, shown when:
- identity reachable AND no valid session (launch or post-401).
Fields: username, password (SecureField), submit, error row. On success → dismiss + `resolveSession`. Default bootstrap hint (`admin/adminpass`) shown as placeholder text only.

Gate: if `isIdentityReachable == false` → skip login entirely (single-machine dev mode, no identity). No blocking.

### HubPermissionView re-source (identity-gated retire)

- New computed `useIdentity: Bool` = `IdentityService.shared.isIdentityReachable && session != nil`.
- When `useIdentity`:
  - tenant list from `GET /api/v1/tenants` (tenant_admin) or decoded JWT `tid`.
  - hide `createTenantSheet` / `deleteTenant` / local role create/delete buttons.
  - tenant/role display read-only from identity session.
- When `!useIdentity`: current behavior unchanged (model-hub `client.listTenants()` etc.).
- No model-hub tenant API calls removed — gated behind `useIdentity == false`.

### Downstream header/param attachment

Two paths:

1. **UDS JSON-RPC** (`IPCClient.call`/`callOnce`): inject `params["_auth"] = downstreamAuthParams()["_auth"]` when loggedIn. daemon ignores unknown field today (JSON-RPC extra params are tolerated). Logging: method only, never `_auth` contents.
2. **HTTP REST** (`ModelHubAPIClient`, `SimulationBridge`, `DocBridge` HTTP sites): call `IdentityService.shared.downstreamHeaders()` and `setValue` for each, in addition to existing `X-API-Key` (model-hub keeps its key; identity headers are additive). When loggedOut, attach nothing (preserves today's behavior). **`MlxHTTPClient` is excluded** — fusion-mlx (port 11434) is the single-tenant inference engine (own `auth.api_key`), not a multi-tenant service; identity headers do not apply.

Attachment is centralized via a helper to avoid 157-call-site scatter:
- UDS: one injection point in `IPCClient.call` (merges `_auth` into params). Injected only when `.loggedIn`.
- HTTP: each bridge's `addAuth`-equivalent gains an `addIdentityHeaders(&request)` call. Bounded set of `addAuth` sites (~4 bridges: ModelHub, Simulation, Doc, plus any cowork-HTTP), not every call site.

### Token refresh + 401 handling

- Proactive: on app foreground (scenePhase), if `expiresAt - now < 60s` → `refresh()`.
- Reactive: bridges catch 401 → call `IdentityService.shared.handle401()` → retry once → if still 401, surface re-login (LoginView re-shown).
- Guard against refresh loops: `handle401` single-flight (in-flight flag).

## Data flow

1. App launch → `IdentityService.resolveSession()` (Keychain → decode → verify/refresh) → set `state`.
2. If reachable + loggedOut → `AppState` shows LoginView.
3. Login → JWT → session → bridges now attach headers/params.
4. Downstream call → header/param attached → service (today: ignores; future: enforces) → response.
5. 401 → `handle401` → refresh → retry or re-login.

## Error handling

- Identity unreachable at launch: `isIdentityReachable=false`, skip login, no headers attached, app runs in single-machine mode (current behavior). Log `.info` "identity not reachable, single-machine mode".
- Login 401: surface "invalid credentials", keep LoginView.
- Verify 401 on resolve: try refresh; refresh 401 → loggedOut + re-login.
- Refresh network error: keep current session if not yet expired (best-effort); if expired → loggedOut.
- Downstream 401: refresh once, retry once, then re-login. Never silently swallow.
- All identity errors: log category `"identity"`, `.error` level, message only (no jwt/refresh values, `.public` for tenant id).

## Testing

Unit tests (`Tests/UnitTests/IdentityIntegrationTests.swift`, mirror Audit0902 patterns, `@testable import FusionStudio`, `@MainActor`):
- `test_login_populatesSession` — mock URLProtocol returns fake JWT → session.tenantId/role decoded.
- `test_resolveSession_keychainValid` — Keychain JWT + claims → `.loggedIn` without network (verify mocked).
- `test_resolveSession_expired_refreshes` — expired exp → refresh called → new session.
- `test_downstreamHeaders_loggedIn` — loggedIn → headers contain `Authorization: Bearer ...` + `X-Tenant-Id`.
- `test_downstreamHeaders_loggedOut` — loggedOut → headers empty `[:]`.
- `test_downstreamAuthParams_loggedIn` — loggedIn → params `["_auth": ["jwt":..,"tid":..]]`.
- `test_handle401_refreshThenRelogin` — 401 → refresh success → retry; refresh fail → loggedOut.
- `test_useIdentity_gate` — `IdentityService.isIdentityReachable=true + session != nil` → HubPermissionView `useIdentity == true`; unreachable → `false`.
- `test_keychain_jwtNeverLogged` — structural: grep `IdentityService.swift` for no `logger.*jwt` value interpolation (only "saved"/"set"/"cleared").

JWT decode: local base64 decode of claims (no external dep; Foundation). Verify call: mocked URLProtocol. Identity health probe: mocked.

## i18n

New keys in `I18nKey` enum + 4 lang JSON: `identity_login_title`, `identity_login_username`, `identity_login_password`, `identity_login_submit`, `identity_login_error`, `identity_login_bootstrap_hint`, `identity_login_loggedOut_banner`, `identity_tenant_from_identity`. Access via `@StateObject I18nManager.shared` + `i18n.t(.key)` — NOT `@EnvironmentObject I18nService`.

## File map

| File | Role |
|------|------|
| `FusionStudio/Common/IdentityService.swift` (new) | Auth state machine, login/refresh/verify/resolve, headers/params |
| `FusionStudio/Common/IdentityLoginView.swift` (new) | Login sheet UI |
| `FusionStudio/Common/KeychainStore.swift` (modify) | JWT/refresh wrappers |
| `FusionStudio/FusionStudioApp.swift` (modify) | inject `IdentityService` env object, launch `resolveSession` |
| `FusionStudio/Bridge/IPCClient.swift` (modify) | inject `_auth` into params in `call` |
| `FusionStudio/Modules/ModelHub/ModelHubAPIClient.swift` (modify) | `addIdentityHeaders` in `addAuth` |
| `FusionStudio/Modules/Simulation/*` SimulationBridge HTTP (modify) | identity headers |
| `FusionStudio/Bridge/DocBridge.swift` (modify, HTTP sites only) | identity headers |
| `FusionStudio/Modules/ModelHub/HubPermissionView.swift` (modify) | `useIdentity` gate, re-source tenant/role |
| `FusionStudio/Common/I18nService.swift` (modify) | new keys |
| `FusionStudio/Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json` (modify) | translations |
| `Tests/UnitTests/IdentityIntegrationTests.swift` (new) | unit tests |

## Risks

- **Header attachment is a no-op today** — services ignore `Authorization`/`X-Tenant-Id`. Acceptable: forward-looking, client-ready, zero behavior change until upstream enforces. Documented in commit + upstream issues.
- **UDS `_auth` param** — daemon ignores extra JSON-RPC params (tolerated by spec). If a future daemon rejects unknown params, injection must be gated on identity reachable. Mitigation: inject `_auth` only when `state == .loggedIn` (already the design); logged-out → no injection.
- **LoginView blocks UX** — only shown when identity reachable + loggedOut. Single-machine dev (identity absent) never sees it. Gate is `isIdentityReachable`.
- **HubPermissionView dual-source complexity** — `useIdentity` gate keeps two paths. Acceptable per user decision (no hard break). Tested both branches.
- **JWT decode without a library** — base64 decode of the middle segment + JSON. HS256 verify is NOT done client-side (trust the issuer; `verify` endpoint is the authority). Claims read locally for UI (tid/role/exp). Mitigation: treat locally-decoded role as advisory (matches upstream "role re-verification on every protected call" philosophy); authoritative role comes from `/tenants` or `verify`.
- **Refresh token in Keychain** — refresh token is long-lived. Same Keychain protection as cluster token. Cleared on logout.

## Upstream issues to file (issue-first, not blocking this PR)

1. fusion-agent-studio: `daemon_server.py` consume `_auth` (jwt/tid) from JSON-RPC params → enforce tenant context on UDS calls.
2. fusion-model-hub: accept `Authorization: Bearer` + `X-Tenant-Id` alongside `X-API-Key` (identity-aware mode).
3. fusion-cowork: document `FUSION_IDENTITY_ENABLED` production path + Shell integration contract (already has opt-in).
