# DMG Python Backend Runtime Bundling (Track A) — Design Spec

> Issue #393. Tracks the F-func-1/F-ops-5 audit finding: DMG ships zero Python, fresh Mac is dead-on-arrival.

## Problem

`build.sh:59` creates an empty `Contents/Services` — bundling started, never finished. A Mac with only the DMG has no `~/fusion`, no `.venv`, no `daemon_server.py`. `IPCClient` connects to `/tmp/fusion-studio.sock` which nothing serves → every `env.*`/`mlx.*`/`agent.*` call fails silently.

Today the Swift app launches the backend indirectly: `UpstreamServiceManager.runStartSh` (`UpstreamServiceManager.swift:480`) runs `/bin/bash <repo>/start.sh start`, where `<repo>` = `FusionConfig.upstreamAgentStudioPath` (`~/fusion/fusion-agent-studio`, FusionConfig.swift:204). Python interpreter + venv resolution is entirely inside that upstream `start.sh` (`VENV="${SCRIPT_DIR}/.venv"`) — opaque to Swift, assumes a developer monorepo.

## Decisions (locked, user-approved 2026-09-04)

1. **Scope — Minimal runtime + on-demand.** DMG ships a relocatable Python + `daemon_server.py` + its minimal Python deps only (~50–150 MB). MLX (12 GB weights) and the ~14 other upstream services are NOT bundled; pulled at first-run via a setup wizard. Degraded mode (GUI-only, no inference) if the user declines downloads.
2. **Python tech — python-build-standalone** (astral). Official relocatable CPython, `arm64-apple-darwin` `install_only` tarball, ~40 MB. Resolves its own home via relative paths → bundle-relocatable without a venv wrapper.
3. **Path strategy — Bundle-relative default, `~/fusion` override.** Resolution order: (1) explicit user override in Settings, (2) `~/fusion/fusion-agent-studio` if it exists (dev mode), (3) `Bundle.main/Contents/Services` (fresh Mac default).

## Architecture

### Build time (`Scripts/build.sh`, new `bundle_python()` stage)

Inserted after `package_app` copies the binary, before sign:

1. Download `cpython-3.12.<date>-arm64-apple-darwin-install_only.tar.gz` from python-build-standalone releases into a build cache (`~/.fusion-studio/build-cache/python/`). Skip download if cached + sha256 matches a pinned record.
2. Extract to `<app>/Contents/Services/python/`.
3. Install `daemon_server.py`'s minimal runtime deps into the bundled python's site-packages via `Contents/Services/python/bin/pip install` — **copy mode, NOT `-e`** (egg-links hold absolute paths → break on other machines). Deps sourced from the in-tree monorepo at build time:
   - `fusion-core` (~/fusion/fusion-core)
   - `fusion-identity` (~/fusion/fusion-identity)
   - `fusion-plugins-ecosystem` (~/fusion/fusion-plugins-ecosystem)
   - PyPI deps (fastapi, uvicorn, pydantic, httpx, …) — drawn from a new `Scripts/bundle-requirements.txt` minimal subset, NOT the full 3.9 GB root `.venv`.
4. Copy `fusion-agent-studio/agent_runtime/` (the `daemon_server.py` + `agent_runtime` package, ~3.8 MB) into `Contents/Services/agent_runtime/`.
5. Write a **bundle wrapper** `Contents/Services/start.sh` (fusion-studio-owned, NOT the upstream one) that:
   - `export PYTHONHOME="$SCRIPT_DIR/python"` (relocatable home)
   - `export PYTHONPATH="$SCRIPT_DIR/agent_runtime:$SCRIPT_DIR/python/lib/python3.12/site-packages"`
   - `exec "$SCRIPT_DIR/python/bin/python3" "$SCRIPT_DIR/agent_runtime/daemon_server.py" "$@"`
6. Record a manifest `Contents/Services/MANIFEST.txt` (python version+date+sha256, dep versions) for update/diagnostic checks.
7. `codesign` later signs `Contents/Services` recursively (`--deep` already in `sign_app`).

**What is NOT bundled:** MLX, fusion-mlx, fusion-store (Rust/maturin native ext — `daemon_server.py` does not import it at module top level; optional handlers degrade), fusion-cowork, fusion-rag, fusion-doc, fusion-sim, fusion-multi-node, fusion-health, fusion-security, fusion-science. These remain on-demand / `~/fusion`-sourced.

### Runtime — Swift path resolution

New `FusionConfig.resolveBackendStartSh() -> String?` (FusionConfig.swift):

```
1. if user override path set + executable → return it
2. let dev = expandedUpstreamPath(upstreamAgentStudioPath) + "/start.sh"
   if FileManager.isExecutableFile(atPath: dev) → return dev   // dev mode
3. let bundle = Bundle.main.url(forResource: "start", withExtension: "sh",
     subdirectory: "Contents/Services")  OR  Bundle.main.bundleURL + "Contents/Services/start.sh"
   if executable → return bundle                                // fresh Mac
4. return nil  → criticalBackendMissing = true (existing flag)
```

`UpstreamServiceManager.startShPath(for:)` (L406) switches from the hardcoded `expandedUpstreamPath(svc.repoPathRaw) + "/start.sh"` to `FusionConfig.shared.resolveBackendStartSh()` for the `agent-studio` service. Other upstream services keep their `~/fusion` paths (they're not bundled; on a fresh Mac they stay `.notInstalled` — expected, degraded mode).

### Runtime — first-run setup wizard (Phase 2, spec'd but deferred)

Out of scope for the first implementation PR (which delivers a working bundled daemon + path resolution). The wizard (detect `~/fusion`, offer MLX download via hf-mirror, degraded-mode banner) is a follow-up tracked under this issue. This PR ships the **bundled daemon works on a fresh Mac for all `env.*`/`agent.*`/non-MLX RPCs** milestone.

## Data flow

```
fresh Mac launch
  → ensureCriticalRunning()
  → startService(agent-studio)
  → startShPath = resolveBackendStartSh() → Contents/Services/start.sh
  → runStartSh spawns /bin/bash Contents/Services/start.sh start
  → wrapper sets PYTHONHOME/PYTHONPATH, execs bundled python daemon_server.py
  → daemon binds /tmp/fusion-studio.sock
  → IPCClient connects → env.* / agent.* / hardware.* RPCs succeed
  → mlx.* RPCs return degraded (no MLX process) until user runs wizard
```

## Error handling

- **Bundle python missing/corrupt** (MANIFEST sha256 mismatch, binary not executable): `startService` returns `.notInstalled`-equivalent, `criticalBackendMissing = true`, top banner shows "后端运行时损坏，请重新安装 Fusion Studio" (i18n key added).
- **daemon_server.py fails to bind socket** (port conflict, permissions): wrapper exits non-zero; `runStartSh` captures stderr → surfaces in `EnvironmentHealthSheet` diagnostic (existing surfacing path).
- **Optional import failure** (fusion-store native ext absent): daemon_server.py already imports these lazily inside handlers; missing pkg → handler returns RPC error, daemon stays up. No change needed upstream.

## Testing

**Unit (new `BundlePathResolutionTests.swift`, mirrors Audit0902Tests patterns):**
- `test_resolveBackendPath_prefersUserOverride`: override set + executable → returns override.
- `test_resolveBackendPath_devModeWhenFusionExists`: `~/fusion/.../start.sh` present → returns dev path even if bundle exists.
- `test_resolveBackendPath_bundleFallback`: no override, no `~/fusion` → returns bundle path (use a temp bundle URL via test injection — `resolveBackendStartSh(bundleURL:)` overload taking an explicit URL for testability).
- `test_resolveBackendPath_nilWhenNothingPresent`: all absent → nil.
- `test_bundleStartShContents_relocatable`: structural — read bundled `start.sh` from test fixture, assert it uses `$SCRIPT_DIR` not absolute paths, sets `PYTHONHOME`.

**Build gate (TRUTH):** `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0. Local `swift test`=0 (toolchain drift); CI macOS-14/Xcode 15.x authoritative.

**Manual / e2e (post-merge, user 验收):**
1. `./Scripts/build.sh package` on this Mac → `Contents/Services/python/`, `agent_runtime/`, `start.sh`, `MANIFEST.txt` exist; `python/bin/python3 --version` prints 3.12.
2. Temporarily rename `~/fusion` → app still launches, `env.health_check` RPC succeeds via bundled daemon (degraded, no MLX).
3. Restore `~/fusion` → app prefers dev path, full functionality.
4. DMG size delta measured (target < +150 MB).

## File map

| File | Change |
|------|--------|
| `Scripts/build.sh` | New `bundle_python()` stage in `package_app`; MANIFEST generation |
| `Scripts/bundle-requirements.txt` | New — minimal PyPI dep subset for daemon_server |
| `Scripts/.python-standalone-pin.txt` | New — pinned python-build-standalone release URL + sha256 |
| `FusionStudio/Common/FusionConfig.swift` | New `resolveBackendStartSh(bundleURL:)` + user-override `@AppStorage` |
| `FusionStudio/System/UpstreamServiceManager.swift` | `startShPath(for:)` uses resolver for agent-studio (L406) |
| `FusionStudio/Modules/Settings/SettingsView.swift` | New "后端运行时" section: show resolved path, override toggle/field |
| `Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json` | New keys: backend runtime banner, settings labels |
| `Tests/UnitTests/BundlePathResolutionTests.swift` | New — 5 path-resolution tests |

## Constraints

- 4-space multiples indent, no docstrings, logging on every non-trivial path.
- Only modify fusion-studio. Upstream `fusion-agent-studio/start.sh` untouched — we bundle our own wrapper.
- Never print api_key / JWT to stdout.
- python-build-standalone pinned release + sha256 verified at build (no supply-chain drift).
- Bundle path resolution must not break existing dev workflow (`~/fusion` still wins when present, unless explicit override).

## Out of scope (follow-up under #393)

- First-run MLX download wizard + degraded-mode banner UI.
- Bundling fusion-store native extension (Rust/maturin) — only if a handler proves to need it at startup.
- Auto-update of bundled python.
- Intel (x86_64) build — arm64 only this PR (DMG already arm64).
