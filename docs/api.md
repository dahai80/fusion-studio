# Fusion Studio API Documentation

> **Version**: 1.0.0 · **Protocol**: JSON-RPC 2.0 over Unix Domain Socket
> **Modules**: 20+ · **Test Coverage**: 60+ tests

---

## Overview

Fusion Studio uses **JSON-RPC 2.0** over a **Unix Domain Socket** for all inter-process communication between the SwiftUI frontend and the Rust/Python backend services.

### Connection

- **Socket Path**: `/tmp/fusion-studio.sock` (configurable via `FusionConfig.ipcSocketPath`)
- **Permissions**: `0600` (owner read/write only)
- **Transport**: Unix Domain Socket, stream mode
- **Protocol**: JSON-RPC 2.0, line-delimited (each message ends with `\n`)

### Message Format

**Request**:
```json
{"jsonrpc": "2.0", "id": 1, "method": "service.method", "params": {...}}
```
**Success Response**:
```json
{"jsonrpc": "2.0", "id": 1, "result": {...}}
```
**Error Response**:
```json
{"jsonrpc": "2.0", "id": 1, "error": {"code": -32601, "message": "Unknown method"}}
```

### Standard Error Codes

| Code | Meaning |
|------|---------|
| `-32700` | Parse error |
| `-32600` | Invalid request |
| `-32601` | Method not found |
| `-32603` | Internal error |

---

## Methods

### Environment Service (`env.*`)

#### `env.health_check`

Run all environment health checks (7 items).

**Response**: Array of `{id, label, status, detail, fixable}`

| Check ID | Check | Detection |
|----------|-------|-----------|
| `xcode` | Xcode CLI Tools | `xcode-select -p` |
| `homebrew` | Homebrew | `brew --version` |
| `python` | Python 3.11+ | `python3 --version` |
| `mlx` | MLX framework | `import mlx` |
| `pybullet` | PyBullet | `import pybullet` |
| `rust` | Rust toolchain | `rustc --version` |
| `fusion-mlx` | fusion-mlx service | HTTP `localhost:8000/v1/models` |

#### `env.repair`

Repair a specific check item. `params: {"item_id": "mlx"}`

**Response**: `{item_id, success, message, logs}`

#### `env.repair_all`

Repair all failed items automatically.

#### `ping`

Health check: `{"pong": true, "version": "1.0.0"}`

---

### MLX Service (`mlx.*`)

| Method | Params | Description |
|--------|--------|-------------|
| `mlx.start` | `{"model": "..."}` | Start fusion-mlx service |
| `mlx.stop` | — | Stop fusion-mlx service |
| `mlx.restart` | — | Restart fusion-mlx service |
| `mlx.status` | — | Get full service status |
| `mlx.health` | — | Quick health check |
| `mlx.set_model` | `{"model": "..."}` | Set active model |

**mlx.status Response**:
```json
{"running": true, "pid": 12345, "host": "localhost", "port": 8000,
 "health": {"status": "healthy", "http_code": 200},
 "model": "qwen3.5-9b-4bit", "quant": "4bit", "max_memory_gb": 16}
```

---

### Hardware Monitor (`hardware.*`)

#### `hardware.metrics`

Get current hardware metrics: memory, CPU, GPU, MLX.

**Response**:
```json
{"memory": {"total_gb": 32, "used_gb": 12.5},
 "cpu": {"percent": 23.5},
 "gpu": {"raw": "GPU Power: 5W"},
 "mlx": {"info": "Metal device: Apple M3 Pro"}}
```

---

### Task Service (`task.*`)

| Method | Params | Description |
|--------|--------|-------------|
| `task.submit` | `{"type": "...", ...}` | Submit background task |

**Task Types**: `inference`, `compile`, `export`, `simulation`, `batch`, `download`

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│  Application Layer (SwiftUI) — 20 modules                    │
├──────────────────────────────────────────────────────────────┤
│  Container Layer — WKWebView + Native Components             │
├──────────────────────────────────────────────────────────────┤
│  Bridge Layer — Unix Socket + JSON-RPC 2.0                   │
├──────────────────────────────────────────────────────────────┤
│  Service Layer — Rust/Python Daemon Processes                │
│  env-daemon · mlx-daemon · supervisor                        │
├──────────────────────────────────────────────────────────────┤
│  Base Layer — fusion-mlx (Apple Silicon Native)              │
│  LLM · Image · Speech · OCR · Video · Training               │
└──────────────────────────────────────────────────────────────┘
```

### Module List (20+)

| # | Module | Type | File |
|---|--------|------|------|
| 1 | Dashboard | Core | `Navigation/ModuleDetailView.swift` |
| 2 | Design | Container | `Modules/Design/WebViewContainer.swift` |
| 3 | Code | Core | `Modules/Code/CodeEditorView.swift` |
| 4 | Simulation | Container | `Modules/Simulation/SimulationView.swift` |
| 5 | Model Hub | Core | `Modules/ModelHub/ModelHubView.swift` |
| 6 | MultiModal | Core | `Modules/MultiModalView.swift` |
| 7 | Training | Core | `Modules/TrainingView.swift` |
| 8 | CLI | Core | `Modules/CLI/CLIView.swift` |
| 9 | Doc | Core | `Modules/Doc/DocView.swift` |
| 10 | KB | Service | `Modules/KB/KBView.swift` |
| 11 | Bench | Core | `Modules/Bench/BenchView.swift` |
| 12 | Desk | Core | `Modules/Desk/DeskView.swift` |
| 13 | Data Tools | Core | `Modules/DataToolsView.swift` |
| 14 | Agent Studio | Service | `Modules/AgentStudioView.swift` |
| 15 | Plugin | Service | `Common/PluginService.swift` |
| 16 | Security | Service | `Common/SecurityService.swift` |
| 17 | Analytics | Service | `Common/AnalyticsDashboardView.swift` |
| 18 | Collaboration | Service | `Common/CollaborationService.swift` |
| 19 | Auto Tuning | Service | `Common/AutoTuningView.swift` |
| 20 | External Integrations | Service | `Common/ExternalIntegrationsView.swift` |
| 21 | Doc Generator | Service | `Common/DocGeneratorView.swift` |
| 22 | Industry Scenarios | Service | `Modules/IndustryScenariosView.swift` |
| 23 | Operations | Service | `Modules/OperationsView.swift` |
| 24 | License | Service | `Modules/LicenseView.swift` |

---

## Swift Client API

```swift
let client = IPCClient()  // Default socket path

// Environment
func healthCheck() async throws -> [String: Any]
func repair(itemId: String) async throws -> [String: Any]
func repairAll() async throws -> [String: Any]

// MLX
func startMLX(model: String) async throws -> [String: Any]
func stopMLX() async throws -> [String: Any]
func mlxStatus() async throws -> [String: Any]
func hardwareMetrics() async throws -> [String: Any]

// Tasks
func submitTask(type: String, params: [String: Any]) async throws -> [String: Any]
func ping() async throws -> Bool
```

**Error Handling**:
```swift
do { try await client.healthCheck() }
catch IPCError.disconnected { /* reconnect */ }
catch IPCError.rpcError(let code, let message) { /* handle RPC error */ }
```

---

## Backend Services

### env-daemon (Rust)

- Async JSON-RPC server using `tokio`
- Automatic crash recovery with exponential backoff (max 5 retries)
- 30-second accept timeout for heartbeat
- Socket permissions: `0600`
- **Source**: `Services/env-daemon/src/main.rs`

### mlx-daemon (Python)

- MLX process lifecycle management
- Health check via HTTP polling
- Hardware metrics collection
- HTTP JSON-RPC server on port `8001`
- **Source**: `Services/mlx-daemon/daemon.py`

---

## Security

- **Socket**: `0600` permissions, owner-only access
- **Input Validation**: All JSON-RPC parameters validated server-side
- **Timeout**: 30-second accept timeout prevents hung connections
- **Crash Recovery**: Automatic restart with exponential backoff
- **No Authentication**: Local-only IPC, no auth needed