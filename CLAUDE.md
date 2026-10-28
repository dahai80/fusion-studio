# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Context

`fusion-studio/` is its own git repository living inside the `/Users/dahai/fusion` monorepo
(which has no root `.git`). Commit, branch, and PR only in this repo. Never modify sibling
`fusion-*` projects from here: when the problem is upstream (IPC method missing, RPC schema
drift, backend bug), file an issue in that project first, then a PR there, then consume the fix.
`docs/upstream-issues.md` tracks the currently open upstream items.

There are no local Rust/Python daemons in this repo anymore. `Services/` was deleted (#296/#298);
everything under `env.*`, `hardware.metrics`, `memory.*`, `safety.*`, `mlx.*` is served by the
central router `daemon_server.py` (fusion-agent-studio) over a Unix Domain Socket.

## Build, Run, Test

```bash
# Debug build (SPM is canonical; FusionStudio.xcodeproj is secondary)
swift build -c debug

# Release build
swift build -c release

# All tests (XCTest; two targets: UnitTests, IntegrationTests)
swift test

# Single test class / case
swift test --filter IPCClientTests
swift test --filter IPCClientTests/testInitialState

# Run the debug binary in a loop (kills old process, relaunches)
./Scripts/dev.sh

# Package pipeline (each stage is also callable alone)
./Scripts/build.sh app        # SPM release build + copy Info.plist
./Scripts/build.sh package    # app + Python runtime into .app bundle
./Scripts/build.sh sign
./Scripts/build.sh dmg
./Scripts/build.sh all        # app + package + sign + dmg

# Start/stop all upstream services (delegates to fusion-supervisor)
./Scripts/start.sh start|stop|restart|status [--no-app]
```

Build is pinned to `VERSION` near the top of `Scripts/build.sh` (currently `0.1.65`); bump it
before cutting a release, then tag `vX.Y.Z` (signed builds) or `vX.Y.Z-beta` when the signing
secrets are absent.

### Local `swift test` returns 0 tests — toolchain drift, not regression

On the local machine (Swift 6.3.3 / macOS 26 / Testing Library 1902) `swift test` discovers
~205 XCTest cases via `swift test list` but executes zero. This is toolchain drift, not lost
tests. CI (GitHub Actions `macos-14` + Xcode 15.x, `.github/workflows/ci.yml`) is the
authoritative gate. Do not code around local zero-test output; verify via CI and `swift test list`.

CI runs three jobs: `swift-build` (debug build + full test + release build), `lint` (build must
succeed and warnings are inspected; treat Swift 6 concurrency warnings as blocking), and
`security` (gitleaks over full history plus a plaintext-secret grep). `nightly.yml` repeats
build + tests; `release.yml` builds, packages, signs, and publishes the DMG.

## Architecture

Five layers, top to bottom:

1. **App layer** — SwiftUI (`FusionStudioApp.swift` is `@main`; 28 `@StateObject`s injected via
   `.environmentObject()`).
2. **Container layer** — module containers: native SwiftUI editors, WKWebView embeds (Design,
   Security, Doc, Bench), Metal/simulation workbench views.
3. **Bridge layer** — JSON-RPC 2.0 over UDS (`/tmp/fusion-studio.sock`) plus per-service HTTP REST
   clients.
4. **Service layer** — central router `daemon_server.py` in fusion-agent-studio, which forwards
   to upstream daemons/services.
5. **Base layer** — fusion-mlx (MLX/Metal inference) and the other fusion-* services.

### State and navigation

- `AppState` is split into four independently injected objects: `NavigationState`,
  `UIPanelState`, `HealthState`, `ThemeState`; the `AppState` facade holds the same instances so
  singletons stay consistent (F-A5). Consumers should grab the narrow object they need.
- Navigation has three enums in `Common/AppState.swift`: `Module` (53 cases, includes sub-view
  entries such as the plugin tabs), `ProductSheet` (19), `SidebarSection` (21).
  `SectionContentView` switches on `activeSection`.
- Layout is `IconRailView | FusionSidebarView (collapsible, ⌘\) | WorkspaceArea | InspectorPanel
  (⇧⌘I)`. Theme via `StudioTheme` + `.studioThemed()`; dark-first.
- App-level services also injected at the root include `IPCClient`, `AgentBridge`, `TaskManager`,
  `ScreenContextManager`, `DesignBridge`, `StreamingBridge`, `ChatSessionStore`, `DeskBridge`,
  `UpstreamServiceManager`, `MlxHTTPClient`, domain bridges (Science/Finance/Health/Simulation/
  Trainer/Speech/Douyin/Guard), `TeamBridge`, `MultiNodeEngine`.

### IPC and transport

- `IPCClient.call(method:params:) async throws -> [String: Any]` is the single JSON-RPC entry.
  Methods are name-spaced `service.method` and must be referenced through `Bridge/RPCMethod.swift`
  (200+ constants) — do not reintroduce string literals at call sites (F-I3). Compile-time
  constants and the runtime `rpc.discover` check (F-A16) are complementary.
- `IPCClient` handles timeouts, retry/backoff, circuit breaking, error sanitization
  (`BridgeError.sanitize`), and REST fallbacks. Reuse those helpers instead of raw `URLSession`.
- Major method families live in partials: `IPCAgentMethods`, `IPCArtifactsMethods`,
  `IPCProjectCoworkMethods`, `IPCExtendedMethods`, `IPCTrainerMethods`,
  `IPCConvenienceMethods`, `IPCErrorAndREST`, `DocBridge*` domain files.
- Not everything is JSON-RPC. These bypass the central router and speak HTTP/REST directly:
  `model.*` (fusion-mlx `/admin/api/models`), `sim.*` (fusion-simulation `:11455/api/*`),
  FSB, science, finance, health, and MLX inference. Cowork `desk.*` uses its own
  `/tmp/fusion-cowork.sock` (the central router does not forward `desk.*`).
- Streaming paths: `ChatSessionStore` (chat/SSE, 1.4k lines), `StreamingBridge`,
  `TeamEventStream` (team events with replay/catch-up), `EventBridge`, `ScienceSSEClient`.

### Configuration and routing

- `Common/FusionConfig.swift` is the single config surface. Per-service hosts/ports are
  `@AppStorage` keys so users can override them in Settings; add new service endpoints there,
  never inline.
- `mlxBaseURL` priority: user endpoint override (`mlxEndpointOverrideEnabled`) >
  `FUSION_GATEWAY_URL` / `FUSION_MLX_URL` > `FUSION_MLX_PORT` > default `mlxHost:mlxPort`
  (`127.0.0.1:11434`). Keep the default as literal IPv4 `127.0.0.1`; `localhost` can resolve to
  OrbStack/Docker on `::1` and hijack port 11434.
- `mlxResolvedApiKey` priority: Settings value > `FUSION_MLX_API_KEY` env > nested
  `auth.api_key` in `~/.fusion-mlx/settings.json`.
- Gateway is `:11432`; direct fusion-mlx is `:11434`. Prefer the gateway where a path supports it,
  but MLX inference from Studio is currently direct unless the user pins an override.

### I18n

`I18nService` loads four balanced JSON dictionaries from `Resources/i18n/` (`en-US`, `zh-CN`,
`ja-JP`, `ko-KR`) via `Bundle.module` (fallbacks to `Bundle.main` for the test runner). New UI
strings go through `t(...)`; keep all four files in sync. Chinese strings appear in some
`Module`/`ProductSheet` raw values and labels because they are persisted/stable identifiers.

## Conventions

- Swift tools 5.9, macOS 14+, zero external Swift package dependencies (`Package.swift` has an
  empty dependency list). Do not add SPM dependencies.
- Indentation is multiples of 4 spaces. No docstrings. Include logging for new code paths.
- Logging uses `os.log` with `Logger(subsystem: "com.fusion.studio", category: "...")`.
- UI-facing state is `@MainActor`; long file I/O must stay off the main actor
  (`nonisolated`/detached). Recent history shows Swift 6 concurrency warnings breaking CI —
  keep `@MainActor` annotations explicit on views and observable services.
- Secrets (API keys, tokens) go to Keychain via the existing security helpers; non-secret
  preferences use `UserDefaults`/`@AppStorage`.
- Comments in this repo routinely cite audit IDs or issue numbers (`审计0907 P1-8`, `F-A15`,
  `#382`). Preserve and follow that style when making non-obvious changes.
- Large monolithic views are the norm; several have already been split into "facade + domain
  service" files (`AgentBridge`, `DesignBridge`, `DocBridge`). Follow the facade-delegate pattern
  when a bridge grows past ~1,000 lines instead of adding another 100-line method to the original.
- Tests are XCTest, not Swift Testing. `MockIPCClient` exists for bridge tests.

## Further Reading

- `README.md` / `README_CN.md` — product overview, module matrix, roadmap (English is canonical;
  README changes must be English-only, Chinese goes in README_CN).
- `docs/api.md` — JSON-RPC envelope, error codes, method reference.
- `docs/upstream-http-endpoints.md` and `docs/studio-integration.md` — per-service coverage map and
  which GUI surfaces are still shells.
- `docs/upstream-issues.md` — open upstream blockers and their owning repos.
- `.github/workflows/` — the authoritative build/test/lint/security gates.
