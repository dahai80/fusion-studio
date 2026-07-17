# Fusion Studio API Documentation

> **Version**: 0.1.0 MVP · **Protocol**: JSON-RPC 2.0 over Unix Domain Socket

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
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "service.method",
  "params": { ... }
}
```

**Success Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": { ... }
}
```

**Error Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32601,
    "message": "Unknown method: xxx"
  }
}
```

### Standard Error Codes

| Code | Meaning |
|------|---------|
| `-32700` | Parse error — invalid JSON |
| `-32600` | Invalid request |
| `-32601` | Method not found |
| `-32603` | Internal error |

---

## Methods

### Environment Service (`env.*`)

#### `env.health_check`

Run all environment health checks.

**Parameters**: None

**Response**:
```json
{
  "result": [
    {
      "id": "xcode",
      "label": "Xcode CLI Tools",
      "status": "passed",
      "detail": "/Library/Developer/CommandLineTools",
      "fixable": true
    },
    {
      "id": "homebrew",
      "label": "Homebrew",
      "status": "passed",
      "detail": "Homebrew 4.x",
      "fixable": true
    },
    {
      "id": "python",
      "label": "Python 3.11+",
      "status": "passed",
      "detail": "Python 3.12.0",
      "fixable": true
    },
    {
      "id": "mlx",
      "label": "MLX 环境",
      "status": "failed",
      "detail": "mlx 未安装",
      "fixable": true
    },
    {
      "id": "pybullet",
      "label": "PyBullet",
      "status": "passed",
      "detail": "pybullet 4.x",
      "fixable": true
    },
    {
      "id": "rust",
      "label": "Rust 工具链",
      "status": "passed",
      "detail": "rustc 1.80.0",
      "fixable": true
    },
    {
      "id": "fusion-mlx",
      "label": "fusion-mlx 服务",
      "status": "failed",
      "detail": "未运行",
      "fixable": true
    }
  ]
}
```

**Check Items**:

| ID | Check | Detection Method |
|----|-------|-----------------|
| `xcode` | Xcode CLI Tools | `xcode-select -p` |
| `homebrew` | Homebrew | `brew --version` |
| `python` | Python 3.11+ | `python3 --version` + `pip3 --version` |
| `mlx` | MLX framework | `python3 -c "import mlx; print(mlx.__version__)"` |
| `pybullet` | PyBullet physics | `python3 -c "import pybullet; print(pybullet.__version__)"` |
| `rust` | Rust toolchain | `rustc --version` + `cargo --version` |
| `fusion-mlx` | fusion-mlx service | HTTP GET `http://localhost:8000/v1/models` |

#### `env.repair`

Repair a specific environment check item.

**Parameters**:
```json
{
  "item_id": "mlx"
}
```

**Response**:
```json
{
  "result": {
    "item_id": "mlx",
    "success": true,
    "message": "MLX 安装成功",
    "logs": ["$ pip3 install mlx", "Successfully installed mlx-0.x.x"]
  }
}
```

**Supported Repairs**:

| Item ID | Repair Action |
|---------|---------------|
| `xcode` | `xcode-select --install` |
| `homebrew` | Homebrew install script |
| `python` | `brew install python@3.11` |
| `mlx` | `pip3 install mlx` |
| `pybullet` | `pip3 install pybullet` (with fallback to source build) |
| `rust` | `curl ... sh.rustup.rs` |
| `fusion-mlx` | Start fusion-mlx server process |

#### `env.repair_all`

Repair all failed and fixable items automatically.

**Parameters**: None

**Response**: Array of `RepairResult` objects.

#### `ping`

Health check for the daemon itself.

**Parameters**: None

**Response**:
```json
{
  "result": {
    "pong": true,
    "version": "0.1.0"
  }
}
```

---

### MLX Service (`mlx.*`)

#### `mlx.start`

Start the fusion-mlx inference service.

**Parameters**:
```json
{
  "model": "qwen3.5-9b-4bit"
}
```

**Response**:
```json
{
  "result": true
}
```

#### `mlx.stop`

Stop the fusion-mlx inference service.

**Parameters**: None

**Response**:
```json
{
  "result": true
}
```

#### `mlx.restart`

Restart the fusion-mlx inference service.

**Parameters**: None

**Response**:
```json
{
  "result": true
}
```

#### `mlx.status`

Get the full status of the MLX inference service.

**Parameters**: None

**Response**:
```json
{
  "result": {
    "running": true,
    "pid": 12345,
    "host": "localhost",
    "port": 8000,
    "health": {
      "status": "healthy",
      "http_code": 200,
      "models": ["qwen3.5-9b-4bit"]
    },
    "model": "qwen3.5-9b-4bit",
    "quant": "4bit",
    "max_memory_gb": 16
  }
}
```

#### `mlx.health`

Quick health check for the MLX service.

**Parameters**: None

**Response**:
```json
{
  "result": {
    "status": "healthy",
    "http_code": 200
  }
}
```

#### `mlx.set_model`

Set the active model for the MLX service.

**Parameters**:
```json
{
  "model": "llama3-8b-4bit"
}
```

**Response**:
```json
{
  "result": {
    "status": "ok",
    "model": "llama3-8b-4bit"
  }
}
```

---

### Hardware Monitor (`hardware.*`)

#### `hardware.metrics`

Get current hardware metrics from the system.

**Parameters**: None

**Response**:
```json
{
  "result": {
    "memory": {
      "total_gb": 32.0,
      "used_gb": 12.5,
      "percent": 39.1
    },
    "cpu": {
      "percent": 23.5,
      "count": 12
    },
    "gpu": {
      "raw": "GPU Power: 5W"
    },
    "mlx": {
      "info": "Metal device: Apple M3 Pro"
    }
  }
}
```

---

### Task Service (`task.*`)

#### `task.submit`

Submit a background task for execution.

**Parameters**:
```json
{
  "type": "inference",
  "model": "qwen3.5-9b-4bit",
  "prompt": "Hello, world!"
}
```

**Response**:
```json
{
  "result": {
    "task_id": "uuid-xxxx",
    "status": "queued"
  }
}
```

**Task Types**:

| Type | Description |
|------|-------------|
| `inference` | ML model inference |
| `compile` | Code compilation |
| `export` | File export / batch export |
| `simulation` | Physics simulation run |
| `batch` | Batch processing |

---

## Swift Client API (IPCClient)

The `IPCClient` class in `FusionStudio/Bridge/IPCClient.swift` provides a Swift-native interface to all RPC methods.

### Initialization

```swift
let client = IPCClient()  // Uses default socket path
let client = IPCClient(socketPath: "/tmp/custom.sock")  // Custom path
```

### Connection State

```swift
client.isConnected  // Published property: Bool
client.lastError    // Published property: String?
```

### Methods

```swift
// Environment
func healthCheck() async throws -> [String: Any]
func repair(itemId: String) async throws -> [String: Any]
func repairAll() async throws -> [String: Any]

// MLX Service
func startMLX(model: String) async throws -> [String: Any]
func stopMLX() async throws -> [String: Any]
func mlxStatus() async throws -> [String: Any]
func hardwareMetrics() async throws -> [String: Any]

// Task
func submitTask(type: String, params: [String: Any]) async throws -> [String: Any]

// Heartbeat
func ping() async throws -> Bool
```

### Error Handling

```swift
do {
    let result = try await client.healthCheck()
    // Handle result
} catch IPCError.disconnected {
    // Handle connection lost
} catch IPCError.rpcError(let code, let message) {
    // Handle RPC error
} catch {
    // Handle other errors
}
```

### Error Types

```swift
enum IPCError: Error {
    case disconnected      // Socket not connected
    case invalidRequest    // Invalid JSON-RPC request
    case invalidResponse   // Invalid JSON-RPC response
    case rpcError(code: Int, message: String)  // Remote error
}
```

---

## Rust Server Implementation

### env-daemon

The `env-daemon` service is the main JSON-RPC server implemented in Rust.

**Architecture**:
- Single-threaded async event loop using `tokio`
- Automatic crash recovery with exponential backoff (max 5 retries)
- 30-second accept timeout for heartbeat detection
- Socket permissions set to `0600`

**Source**: `Services/env-daemon/src/main.rs`

**Core Modules**:
- `HealthChecker` — Runs all environment checks
- `RepairEngine` — Performs automated repairs

### Request Handling Flow

```
Client → Unix Socket → JSON-RPC Parser → Method Dispatch → Handler → JSON-RPC Response → Client
```

### Connection Lifecycle

1. Client connects to Unix socket
2. Server reads JSON-RPC request (line-delimited)
3. Server parses and dispatches to handler
4. Server writes JSON-RPC response (line-delimited)
5. Connection stays open for reuse, or closes

---

## Python MLX Daemon

The `mlx-daemon` is implemented in Python and manages the fusion-mlx inference service.

**Source**: `Services/mlx-daemon/daemon.py`

**Features**:
- MLX process lifecycle management (start/stop/restart)
- Health check via HTTP polling
- Hardware metrics collection (memory, CPU, GPU, MLX)
- HTTP JSON-RPC server on port `8001`

### Hardware Metrics Collection

| Metric | Method | Requirements |
|--------|--------|--------------|
| Memory | `psutil` or `vm_stat` | `psutil` recommended |
| CPU | `psutil` | `psutil` recommended |
| GPU | `powermetrics` | `sudo` access required |
| MLX | `mlx.core.metal.device_info()` | `mlx` package installed |

---

## IPC Protocol Design Rationale

| Decision | Choice | Alternative | Reason |
|----------|--------|-------------|--------|
| Transport | Unix Domain Socket | TCP, gRPC | Zero network overhead, local-only security |
| Protocol | JSON-RPC 2.0 | GraphQL, REST | Simple, language-agnostic, well-established |
| Framing | Line-delimited (newline) | Length-prefixed | Simple text parsing, human-readable |
| Async | Swift `async/await` | Callbacks | Native Swift concurrency, clean error handling |

---

## Security Considerations

1. **Socket Permissions**: Set to `0600` — only the owner can read/write
2. **No Authentication**: IPC is local-only, no auth needed
3. **Input Validation**: All JSON-RPC parameters are validated server-side
4. **Timeout**: 30-second accept timeout prevents hung connections
5. **Crash Recovery**: Automatic restart with exponential backoff

---

## Error Handling Best Practices

```swift
// Always wrap IPC calls in do-catch
do {
    let status = try await client.mlxStatus()
    if let running = status["running"] as? Bool, running {
        // Service is running
    }
} catch IPCError.disconnected {
    // Show reconnection UI
    client.connect()
} catch {
    // Log error
    print("IPC Error: \(error)")
}
```