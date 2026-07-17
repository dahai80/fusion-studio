# Fusion Studio User Guide

> **Version**: 0.1.0 MVP · **Platform**: macOS 14+ (Apple Silicon)

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Interface Overview](#interface-overview)
3. [Environment Management](#environment-management)
4. [Module Guide](#module-guide)
5. [Settings & Configuration](#settings--configuration)
6. [Task Management](#task-management)
7. [Hardware Monitoring](#hardware-monitoring)
8. [Troubleshooting](#troubleshooting)
9. [FAQ](#faq)

---

## Getting Started

### First Launch

When you first launch Fusion Studio, you'll see the **Dashboard** — the command center for all your AI tools. The app will automatically run an environment health check to ensure all dependencies are properly installed.

### Step 1: Run Environment Check

1. Open Fusion Studio
2. On the Dashboard, click **"Run Health Check"** in the Environment Health card
3. Wait for all 7 checks to complete
4. Green ✅ means everything is ready
5. Red ❌ means an issue was found — click **"Fix"** to auto-repair

### Step 2: Start MLX Service

1. In Settings → General, ensure **"Auto-start fusion-mlx service"** is enabled
2. Or manually start it from the Dashboard via the service status indicator
3. Verify the MLX service is running (the bolt icon in the toolbar turns green)

### Step 3: Explore Modules

Click any module in the sidebar to open it:

| Module | What You Can Do |
|--------|----------------|
| 🎨 **Design** | Create and edit UI designs with the AI-powered canvas |
| 💻 **Code** | Write, edit, and run code with the built-in editor |
| 🤖 **Simulation** (V0.2) | Run physics simulations |
| 📦 **Model Hub** (V0.2) | Browse and manage AI models |
| 📊 **Bench** (V0.2) | Run performance benchmarks |

---

## Interface Overview

```
┌──────────────────────────────────────────────────────────────┐
│  Toolbar                                                      │
│  ┌───────┐ ┌──────────────────────────────────────────────┐  │
│  │       │ │                                              │  │
│  │ Side  │ │            Module Content                    │  │
│  │ bar   │ │                                              │  │
│  │       │ │                                              │  │
│  │  🏠   │ │                                              │  │
│  │  🎨   │ │                                              │  │
│  │  💻   │ │                                              │  │
│  │  🤖   │ │                                              │  │
│  │  📦   │ │                                              │  │
│  │  ⌨️   │ │                                              │  │
│  │  📄   │ │                                              │  │
│  │  📚   │ │                                              │  │
│  │  📊   │ │                                              │  │
│  │  🧹   │ │                                              │  │
│  └───────┘ └──────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### Toolbar Indicators

| Icon | Meaning |
|------|---------|
| 🟢 Green dot | Environment healthy |
| 🔴 Red dot | Issues found — click to view |
| 🟠 Orange dot | Repair in progress |
| ⚡ Green bolt | MLX service running |
| ⚡ Red bolt | MLX service stopped |

### Sidebar Modules

The sidebar contains 10 modules. The first 3 are available in V0.1 MVP:

1. **Dashboard** 🏠 — Command center with health check, task queue, hardware monitor
2. **Design** 🎨 — AI-powered design canvas (WKWebView)
3. **Code** 💻 — Code editor with integrated terminal
4. **Simulation** 🤖 (V0.2) — Physics simulation
5. **Model Hub** 📦 (V0.2) — Model management
6. **CLI** ⌨️ (V0.2) — Command line panel
7. **Doc** 📄 (V0.2) — Document management
8. **KB** 📚 (V0.2) — Knowledge base
9. **Bench** 📊 (V0.2) — Benchmarking
10. **Desk** 🧹 (V0.2) — Desktop automation

---

## Environment Management

### Health Check Items

The environment health check scans 7 critical components:

| # | Component | What It Checks | Common Issues |
|---|-----------|---------------|---------------|
| 1 | **Xcode CLI Tools** | `xcode-select -p` | Not installed after macOS update |
| 2 | **Homebrew** | `brew --version` | Missing after fresh install |
| 3 | **Python 3.11+** | `python3` + `pip3` | Wrong version or missing pip |
| 4 | **MLX** | Python `import mlx` | Not installed or wrong version |
| 5 | **PyBullet** | Python `import pybullet` | Compilation failure on M-series |
| 6 | **Rust Toolchain** | `rustc` + `cargo` | Not installed |
| 7 | **fusion-mlx** | HTTP `localhost:8000` | Service not running |

### One-Click Repair

When an issue is found, click the **"Fix"** button next to the failed item. The repair engine will:

1. Install the missing dependency
2. Verify the installation
3. Report success or failure with detailed logs

### Common PyBullet Issues

PyBullet often fails to compile on Apple Silicon. The repair engine handles this with:

1. First attempt: `pip3 install pybullet`
2. Fallback: `pip3 install --no-binary pybullet pybullet` (source compile)
3. If both fail: display detailed error logs for manual troubleshooting

---

## Module Guide

### 1. Dashboard (Control Center)

The Dashboard is your command center, showing:

- **Environment Health Card** — 7 check items with status indicators
- **Task Queue** — Running and pending background tasks
- **Hardware Monitor** — Real-time memory, CPU, GPU, MLX metrics

### 2. Design Canvas

The Design module embeds a WKWebView with the Fusion-Design canvas:

- Full vector canvas with zoom/pan
- AI-powered UI generation (via fusion-mlx)
- One-click code export to the Code module
- JavaScript bridge for native → web communication

**JavaScript Bridge API**:

```javascript
// Send message to native app
window.fusionStudio.sendToNative({ type: 'export_code', format: 'swiftui', data: {...} });

// Export design to code
const result = await window.fusionStudio.exportCode('react', { ... });
```

### 3. Code Editor

The Code module provides:

- **Code Editor** — Full-featured text editor with syntax highlighting
- **Integrated Terminal** — Command-line interface for running scripts
- **Toolbar** — Run, format, copy, and font size controls

**Supported Languages**: Swift, Python, Rust, JavaScript, TypeScript, HTML, CSS, JSON, YAML

**Terminal Commands**:

| Command | Description |
|---------|-------------|
| `help` | Show available commands |
| `clear` | Clear terminal |
| `status` | Show Fusion Studio service status |
| `mlx` | Show MLX inference status |

---

## Settings & Configuration

### General Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Launch at Login | Off | Auto-start Fusion Studio on login |
| Auto-start MLX | On | Auto-start fusion-mlx service |
| Minimize to Menu Bar | Off | Minimize to menu bar instead of Dock |
| Language | zh-CN | Interface language |

### Hardware Acceleration

| Setting | Default | Description |
|---------|---------|-------------|
| Preferred Device | Auto | GPU (Metal), ANE, CPU, or Auto |
| Max Memory | 16 GB | Maximum memory for MLX inference |
| Enable Metal | On | Use Metal GPU acceleration |
| Enable ANE | On | Use Apple Neural Engine |

### Network & Offline

| Setting | Default | Description |
|---------|---------|-------------|
| Offline Mode | On | Block all network requests |
| Allow Model Download | On | Permit model downloads (disabled in offline mode) |
| Allow Update Check | On | Check for app updates (disabled in offline mode) |

### Quantization Presets

| Setting | Default | Description |
|---------|---------|-------------|
| Default Quant | 4bit | 2bit/3bit/4bit/5bit/6bit/8bit/fp16 |
| Default Format | mlx | mlx/gguf/safetensors |

### Workspace

| Setting | Default | Description |
|---------|---------|-------------|
| Workspace Path | `~/FusionStudio/workspace` | Root directory for all project files |

---

## Task Management

### Submitting Tasks

Tasks can be submitted from any module. Common task types:

| Type | Example | Progress |
|------|---------|----------|
| 🔄 **Inference** | AI model inference | Progress bar |
| 🔧 **Compile** | Code compilation | Spinner |
| 📤 **Export** | File export | Progress bar |
| ⚙️ **Simulation** | Physics simulation | Status indicator |
| 📦 **Batch** | Batch processing | Queue position |

### Task Queue

The task queue shows:

- **Active tasks**: Currently running with progress %
- **Queued tasks**: Waiting in line
- **Completed tasks**: Recent finished tasks
- **Failed tasks**: Tasks that encountered errors

---

## Hardware Monitoring

The hardware monitor updates every 2 seconds, showing:

| Metric | Display | Typical Range |
|--------|---------|---------------|
| **Unified Memory** | Used GB / Total GB | 4-16 GB / 32 GB |
| **GPU Usage** | Percentage | 5-40% idle, 60-100% under load |
| **CPU Load** | Percentage | 10-30% idle, 70-100% under load |
| **MLX Status** | Active / Idle | Changes during inference |

---

## Troubleshooting

### Common Issues

#### "Cannot connect to fusion-mlx"

**Cause**: The MLX inference service is not running.

**Solution**:
1. Go to Dashboard → Environment Health Card
2. Check if "fusion-mlx service" shows ❌
3. Click "Fix" to auto-start the service
4. Or manually start: `fusion-mlx serve --port 8000`

#### "PyBullet compilation failed"

**Cause**: PyBullet requires CMake and GLFW, which may be missing.

**Solution**:
1. Run: `brew install cmake glfw glew`
2. Run: `pip3 install pybullet`
3. If still failing, check the error logs in the repair dialog

#### "Homebrew not found"

**Cause**: Homebrew is not installed.

**Solution**:
1. Click "Fix" in the health check card (auto-installs Homebrew)
2. Or manually install: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

#### "Socket connection refused"

**Cause**: The env-daemon background service is not running.

**Solution**:
1. Run: `./Scripts/start.sh` from the terminal
2. Or restart Fusion Studio (the app auto-starts the daemon)

### Logs

All service logs are written to standard output. To view logs:

```bash
# View env-daemon logs
./Services/env-daemon/target/release/env-daemon

# View mlx-daemon logs
python3 Services/mlx-daemon/daemon.py --no-daemon
```

---

## FAQ

### Q: Is Fusion Studio really 100% offline?

**A**: Yes. When Offline Mode is enabled in Settings, all network requests are blocked. No data ever leaves your machine. Model downloads can be enabled separately and are only used for initial model acquisition.

### Q: What Apple Silicon chips are supported?

**A**: All M-series chips (M1, M2, M3, M4, M5) are supported. The app is optimized for unified memory architecture and Metal/ANE acceleration.

### Q: Can I use Fusion Studio without a GPU?

**A**: Yes, but performance will be significantly reduced. The app runs on CPU-only mode, but MLX inference requires a GPU for reasonable performance.

### Q: How do I update Fusion Studio?

**A**: Auto-update is planned for V1.0. For now, pull the latest code and rebuild:

```bash
git pull origin master
./Scripts/build.sh all
```

### Q: Can I use external AI models?

**A**: Yes, Fusion Studio is compatible with any MLX-compatible model. Use the Model Hub (V0.2) or manually place models in the workspace directory.

### Q: How do I contribute?

**A**: See [CONTRIBUTING](../README.md#contributing) in the main README. We welcome pull requests, bug reports, and feature requests.

---

> **Need more help?** Open an issue on [GitHub](https://github.com/dahai80/fusion-studio/issues) or check the [ARCHITECTURE.md](../ARCHITECTURE.md) for design details.