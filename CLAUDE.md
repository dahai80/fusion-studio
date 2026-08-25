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

# Full build pipeline (Rust services + SPM + app packaging)
./Scripts/build.sh              # default: release
./Scripts/build.sh debug        # debug build
./Scripts/build.sh package      # package .app bundle
./Scripts/build.sh sign         # code sign + notarize
./Scripts/build.sh dmg          # create DMG

# Start all backend services
./Scripts/start.sh

# 无本地 Rust 后台服务 (env-daemon 已删除, env.* 由中央路由 daemon_server.py 实现)
```

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
- **Module routing**: `Module` enum (30 cases) → `ProductSheet` (4 groups: mlx/code/agentStudio/multiNode) → `SidebarSection` (6 sections). `SectionContentView` switches on `activeSection`
- **Layout**: 4-column HStack — IconRailView | FusionSidebarView | WorkspaceArea | InspectorPanel
- **Theme**: `StudioTheme` with dark-first design, accent `#007AFF`, `.ultraThinMaterial` vibrancy. Applied via `.studioThemed()` modifier
- **Zero external Swift dependencies** — Package.swift has no dependencies; everything is self-contained

### Source Layout

```
FusionStudio/
├── FusionStudioApp.swift    # @main entry, creates 7 @StateObject, injects via .environmentObject()
├── ContentView.swift        # 4-column layout root
├── Common/                  # AppState, FusionConfig, I18nService, PluginService, SecurityService, CollaborationService
├── Bridge/                  # IPCClient (JSON-RPC 2.0 client), FusionCoderBridge
├── System/                  # AgentBridge (59K, agent orchestration), SandboxManager, ScreenContext, FileWatcher
├── Navigation/              # FusionSidebarView, IconRailView, InspectorPanel, ChatsPanel, ProjectsPanel, ArtifactsPanel
├── Modules/                 # 25 module views (largest: AgentStudioView 109K, CodeEditorView 63K)
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

### IPC API Namespaces

- `env.*` — health_check, repair, repair_all
- `mlx.*` — start, stop, restart, status, health, set_model
- `model.*` — list, pull, del
- `design.*` — export_code
- `sim.*` — run, stop, status
- `task.*` — submit, status
- `ping` — health check

## Conventions

- Swift tools version 5.9, macOS 14+ target
- Indentation: multiples of 4 spaces
- Logging: use `os.log` with `Logger(subsystem: "com.fusion.studio", category: "...")`
- Large monolithic module views are the norm (AgentStudioView 109K, AgentBridge 59K, CodeEditorView 63K) — follow existing pattern when adding features
- Module views live in `FusionStudio/Modules/` as single files or subdirectories
- Chinese UI strings are used in Module enum rawValues and some labels
- Backend services: 无本地守护进程 (Services/ 空, 见 #296); env.* · hardware.metrics 等由中央路由 daemon_server.py (fusion-agent-studio) 经 UDS 提供
