# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Build (debug)
swift build -c debug

# Build (release)
swift build -c release

# Run all tests
swift test

# Full build pipeline (SPM build + app packaging; 无本地 Rust 后台服务, 见 #296)
./Scripts/build.sh              # default: release
./Scripts/build.sh debug        # debug build
./Scripts/build.sh package      # package .app bundle
./Scripts/build.sh sign         # code sign + notarize
./Scripts/build.sh dmg          # create DMG

# Start all backend services
./Scripts/start.sh

# 无本地 Rust 后台服务 (env-daemon 已删除, env.* 由中央路由 daemon_server.py 实现)
```

### 本地 0 测试 = toolchain drift, 非回归

本地 `swift test` 返回 **0 tests** —— 这不是测试丢失/回归，是 toolchain drift：
本地 Swift 6.3.3 / macOS 26 / Testing Library 1902 **不发现 XCTest** 用例（`swift test list` 能枚举 ~205 用例，但执行 = 0）。
CI（GitHub Actions macOS-14 + Xcode 15.x）`set -o pipefail && swift test 2>&1` 是**权威 gate**（~204 用例，~13-18min cold build）。
本地与 CI 同一 `swift test` 命令，仅 toolchain 不同；无本地 flag 可恢复发现。判定测试绿否，以 CI 为准。


## Architecture

Fusion Studio is a unified macOS native desktop client for the Fusion-MLX local AI ecosystem. It consolidates 25+ modules into a single SwiftUI app, running 100% offline on Apple Silicon.

### 5-Layer Stack

1. **App Layer** — SwiftUI main program (navigation, settings, health check, task manager)
2. **Container Layer** — Module containers (WKWebView for Design, native editors for Code, Metal views for Simulation)
3. **Bridge Layer** — JSON-RPC 2.0 over Unix Domain Socket (`/tmp/fusion-studio.sock`)
4. **Service Layer** — 中央路由 daemon_server.py (Python, fusion-agent-studio): env.* · hardware.metrics · memory · safety · mlx.* 经此统一
5. **Base Layer** — Apple Silicon native (MLX, Metal, ANE, VideoToolbox, PyBullet)

### Key Patterns

- **State management**: `AppState` (ObservableObject) injected via `@EnvironmentObject` — the central hub for navigation (`Module`, `ProductSheet`, `SidebarSection` enums) and UI state
- **IPC**: `IPCClient` handles all backend communication via JSON-RPC 2.0; methods are name-spaced `service.method` (e.g., `env.health_check`, `mlx.start`, `model.list`)
- **Module routing**: `Module` enum (64 cases) → `ProductSheet` (20 cases) → `SidebarSection` (22 sections). `SectionContentView` switches on `activeSection`
- **Layout**: 4-column HStack — IconRailView | FusionSidebarView | WorkspaceArea | InspectorPanel
- **Theme**: `StudioTheme` with dark-first design, accent `#007AFF`, `.ultraThinMaterial` vibrancy. Applied via `.studioThemed()` modifier
- **Zero external Swift dependencies** — Package.swift has no dependencies; everything is self-contained

### Source Layout

```
FusionStudio/
├── FusionStudioApp.swift    # @main entry, creates 27 @StateObject, injects via .environmentObject()
├── ContentView.swift        # 4-column layout root
├── Common/                  # AppState, FusionConfig, I18nService, PluginService, SecurityService, CollaborationService
├── Bridge/                  # IPCClient (JSON-RPC 2.0 client), FusionCoderBridge
├── System/                  # AgentBridge (1736 lines, agent orchestration), AgentBridgeDomains, SandboxManager, ScreenContext, FileWatcher
├── Navigation/              # FusionSidebarView, IconRailView, InspectorPanel, ChatsPanel, ProjectsPanel, ArtifactsPanel
├── Modules/                 # module view entries (subdirs + root files); largest single file: AgentBridge 1736 lines (System/)
├── Components/              # Reusable UI: FusionButton, FusionCard, FusionProgressRing, FusionTabBar, FusionTag, FusionToast
├── Theme/                   # StudioTheme (dark/light themes)
├── DAG/                     # DAGCanvasView
├── Settings/                # SettingsView
├── Environment/             # EnvironmentHealthCard
├── TaskManager/             # TaskQueueView, HardwareMonitorView
└── Resources/               # AppIcon PNGs, Entitlements.plist

Services/                    # 空 (env-daemon/mlx-daemon 已删除, 见 #296)
                             # env.* · hardware.metrics 由中央路由 daemon_server.py 实现
                             # IPCClient 走 /tmp/fusion-studio.sock UDS 到该路由
```

### Environment Objects (injected at app root)

| Object | Role |
|--------|------|
| `AppState` | Navigation, UI state, health status |
| `IPCClient` | JSON-RPC backend communication |
| `AgentBridge` | Agent orchestration, KV ops, task routing |
| `TaskManager` | Background task queue |
| `SandboxManager` | Security sandboxing |
| `ScreenContextManager` | System-level awareness (FSEvents, Accessibility) |
| `MultiNodeEngine` | Cluster/multi-node coordination |

### IPC API Namespaces (JSON-RPC 2.0 over UDS)

- `env.*` — health_check, repair, repair_all
- `mlx.*` — start, stop, restart, status, health, set_model
- `design.*` — generate, export_code
- `task.*` — submit, status
- `ping` — health check

> 注: `model.*` (list/pull/del) 与 `sim.*` (run/stop/status) 走 **HTTP REST**, 非 JSON-RPC。
> `model.*` → ModelHubAPIClient 经 fusion-mlx `/admin/api/models`; `sim.*` → SimulationBridge 经 fusion-sim `:11455/api/*`。

## Conventions

- Swift tools version 5.9, macOS 14+ target
- Indentation: multiples of 4 spaces
- Logging: use `os.log` with `Logger(subsystem: "com.fusion.studio", category: "...")`
- Large monolithic views are the norm (AgentBridge 1736 lines; AgentStudioView refactored to 8.9K via ARCH-1 facade split) — follow existing pattern when adding features
- Module views live in `FusionStudio/Modules/` as single files or subdirectories
- Chinese UI strings are used in Module enum rawValues and some labels
- Backend services: 无本地守护进程 (Services/ 空, 见 #296); env.* · hardware.metrics 等由中央路由 daemon_server.py (fusion-agent-studio) 经 UDS 提供
