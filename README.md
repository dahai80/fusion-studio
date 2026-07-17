<div align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-brightgreen" alt="macOS">
  <img src="https://img.shields.io/badge/Apple%20Silicon-M1--M5-orange" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Swift-5.9-red" alt="Swift">
  <img src="https://img.shields.io/badge/Rust-2021-purple" alt="Rust">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
  <img src="https://img.shields.io/badge/status-MVP-yellow" alt="MVP">
</div>

<h1 align="center">⚡ Fusion Studio</h1>
<p align="center"><strong>Unified macOS Desktop Client for the Fusion-MLX Local AI Ecosystem</strong></p>
<p align="center"><em>One app to rule them all — Design, Code, Simulation, Models, and more. 100% offline, Apple Silicon native.</em></p>

---

## 📋 Overview

**Fusion Studio** is the unified macOS native desktop application for the entire [Fusion-MLX](https://github.com/dahai80?tab=repositories) local AI ecosystem. It consolidates 9+ sub-products into a single, cohesive user experience — eliminating the pain of juggling multiple terminals, browser tabs, and scattered directories.

### Why Fusion Studio?

| Before (Scattered) | After (Unified) |
|-------------------|-----------------|
| 🖥️ Terminal 1: `fusion-cli` | 📱 **Single macOS App** |
| 🖥️ Terminal 2: `fusion-coder` | 🎨 **Design Canvas** (WKWebView) |
| 🌐 Browser: `fusion-design` | 💻 **Code Editor** (built-in) |
| 🖥️ Terminal 3: `fusion-simulation` | 🤖 **Simulation View** (Metal) |
| 📁 Multiple directories | 📂 **Unified workspace** |
| ⚠️ Manual dependency hell | 🔧 **One-click repair** |

### Ecosystem Position

```
fusion-mlx (inference engine, Metal, KV Cache, quantization)
        ↓
Model-Hub / KB / Bench / Plugins (data & evaluation layer)
        ↓
Fusion Studio (UNIFIED macOS DESKTOP APP)
        ↓
Design · Code · Simulation · Doc · Desk · Agent-Studio (application layer)
```

---

## ✨ Features

### 🎯 Core Platform

- **🔧 Environment Health Check & One-Click Repair** — Auto-detect Xcode CLI, Homebrew, Python, MLX, PyBullet, Rust toolchain; fix with one click
- **⚙️ Unified Settings** — Hardware acceleration, offline mode, quantization presets, workspace management in one place
- **📊 Hardware Monitor** — Real-time unified memory, CPU/GPU usage, MLX inference status
- **📋 Global Task Queue** — Background task management for inference, compilation, export, simulation

### 🧩 Module Integration

| Module | Status | Description |
|--------|--------|-------------|
| 🎨 **Fusion-Design** | ✅ MVP | WKWebView canvas with tldraw/OpenPencil integration |
| 💻 **Fusion Code** | ✅ MVP | Built-in code editor + integrated terminal |
| 🤖 **Fusion-Simulation** | 📅 V0.2 | PyBullet physics simulation view |
| 📦 **Fusion Model Hub** | 📅 V0.2 | Visual model management panel |
| ⌨️ **Fusion CLI** | 📅 V0.2 | GUI wrapper for CLI commands |
| 📄 **Fusion-Doc** | 📅 V0.2 | Document management |
| 📚 **Fusion-KB** | 📅 V0.2 | Knowledge base RAG retrieval |
| 📊 **Fusion-Bench** | 📅 V0.2 | Benchmark dashboard |
| 🧹 **Fusion-Desk** | 📅 V0.2 | Desktop automation |

### 🔗 Design → Code → Simulation Pipeline

```
🎨 Design UI → 💻 Export Code → 🤖 Deploy as Control Panel → 🏃 Run Simulation
```

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  📱 Application Layer — SwiftUI Native Desktop               │
│  Navigation · Settings · Health Check · Task Manager         │
├──────────────────────────────────────────────────────────────┤
│  🛠️ Container Layer — WKWebView + Native Components          │
│  Design · Code · Simulation · Model Hub · CLI · Doc · KB     │
├──────────────────────────────────────────────────────────────┤
│  🔗 Bridge Layer — Unix Domain Socket + JSON-RPC 2.0         │
├──────────────────────────────────────────────────────────────┤
│  ⚙️ Service Layer — Rust/Python Daemon Processes              │
│  env-daemon · mlx-daemon · file-daemon · supervisor          │
├──────────────────────────────────────────────────────────────┤
│  🧠 Base Layer — Apple Silicon Native                        │
│  fusion-mlx · Metal · ANE · PyBullet · VideoToolbox          │
└──────────────────────────────────────────────────────────────┘
```

### Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| UI Framework | **SwiftUI** | macOS native, best performance, Apple Silicon optimized |
| Embedded Web | **WKWebView** | Reuse Fusion-Design canvas without rewrite |
| Code Editor | **CodeEditorView** (SwiftUI) | Native integration, lightweight |
| IPC | **Unix Socket + JSON-RPC 2.0** | Lightweight, zero-dependency, cross-language |
| Backend Services | **Rust** (primary) + **Python** (secondary) | Rust for performance/process mgmt, Python for MLX reuse |
| Simulation | **Metal View + PyBullet** | Native GPU acceleration |
| Storage | **SQLite** | Zero-config, local-first |
| Packaging | **Xcode Archive + Notarization + DMG** | Standard macOS distribution |

---

## 🚀 Quick Start

### Prerequisites

- macOS 14+ (Sonoma or later)
- Apple Silicon (M1–M5)
- [Xcode CLI Tools](https://developer.apple.com/download/all/) (`xcode-select --install`)
- [Homebrew](https://brew.sh) (for dependency management)

### One-Click Setup

```bash
# Clone the repository
git clone https://github.com/dahai80/fusion-studio.git
cd fusion-studio

# Run setup script (auto-installs all dependencies)
./Scripts/setup.sh
```

### Manual Setup

```bash
# 1. Install dependencies
brew install cmake glfw glew
pip3 install mlx pybullet psutil

# 2. Build Rust services
cd Services/env-daemon && cargo build --release && cd ../..

# 3. Build SwiftUI app
swift build -c release

# 4. Start all services
./Scripts/start.sh
```

### Build Distribution Package

```bash
# Full build: services + app + package + sign + dmg
./Scripts/build.sh all

# Or build individual components
./Scripts/build.sh services    # Build Rust daemons only
./Scripts/build.sh app         # Build SwiftUI app only
./Scripts/build.sh package     # Build everything and package .app
./Scripts/build.sh dmg         # Generate DMG installer
```

---

## 🗂️ Project Structure

```
fusion-studio/
├── FusionStudio.xcodeproj/       # Xcode project
├── Package.swift                  # Swift Package Manager
├── FusionStudio/                 # SwiftUI source code
│   ├── FusionStudioApp.swift     # @main entry point
│   ├── ContentView.swift          # Main layout (NavigationSplitView)
│   ├── Navigation/               # Sidebar + module routing
│   ├── Settings/                 # Settings panels (5 tabs)
│   ├── Environment/              # Health check engine
│   ├── TaskManager/              # Task queue + hardware monitor
│   ├── Bridge/                   # IPC client (JSON-RPC)
│   ├── Modules/                  # Module containers
│   │   ├── Design/               # WKWebView canvas
│   │   ├── Code/                 # Code editor + terminal
│   │   ├── Simulation/           # Simulation view (V0.2)
│   │   └── ...                   # Other modules (V0.2+)
│   └── Common/                   # Shared state, config, about
├── Services/                     # Background daemon processes
│   ├── env-daemon/               # Rust — Health check + repair engine
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── main.rs           # JSON-RPC server with crash recovery
│   │       └── lib.rs            # HealthChecker + RepairEngine
│   └── mlx-daemon/               # Python — MLX inference service
│       └── daemon.py             # MLX process manager + hardware monitor
├── Scripts/                      # Build & deployment scripts
│   ├── setup.sh                  # One-click dev environment setup
│   ├── build.sh                  # Full build pipeline
│   ├── start.sh                  # Start all services
│   └── sign.sh                   # Code signing + notarization
├── Workspace/                    # Default workspace directory
│   ├── designs/                  # Design files
│   ├── projects/                 # Code projects
│   ├── simulations/              # Simulation scenes
│   └── models/                   # Model weight symlinks
├── ARCHITECTURE.md               # Architecture documentation
├── README.md                     # This file
└── README_CN.md                  # Chinese documentation
```

---

## 🛡️ Security & Privacy

- **🔒 100% Offline** — Zero network requests to external services when offline mode is enabled
- **📡 No Telemetry** — No analytics, no phoning home, no update checks
- **🏠 Local Only** — All models, data, and vectors stay on your machine
- **🔐 Socket Security** — Unix socket permissions set to `0600` (owner only)
- **⚡ No Cloud APIs** — Hard-coded to fusion-mlx only, no third-party backends

---

## 🛣️ Roadmap

### V0.1 MVP (Current) ✅
- [x] SwiftUI main framework (navigation, settings, health check)
- [x] Environment health check & one-click repair engine
- [x] IPC bridge (Unix Socket JSON-RPC)
- [x] Fusion-Design WKWebView canvas container
- [x] Fusion Code editor + integrated terminal
- [x] Global task queue & hardware monitor
- [x] Unified workspace directory
- [x] Rust env-daemon with crash recovery
- [x] Python mlx-daemon for MLX service management
- [x] Build & packaging scripts

### V0.2 (Planned — 2–3 weeks)
- [ ] Fusion-Simulation simulation view (PyBullet)
- [ ] Fusion Model Hub visual model management
- [ ] GUI CLI panel
- [ ] Doc/KB/Bench basic panels
- [ ] Module interop (Design ↔ Code ↔ Simulation)
- [ ] Enhanced task queue (progress, pause, cancel)

### V1.0 (Planned — 1 month+)
- [ ] All 9 module entry points complete
- [ ] App signing, notarization, DMG distribution
- [ ] Auto-update mechanism
- [ ] Long-running stability & memory optimization
- [ ] User documentation & guides

### Future
- [ ] Team LAN collaboration
- [ ] Plugin system for third-party extensions
- [ ] Advanced simulation parameters
- [ ] CI/CD pipeline

---

## 🤝 Contributing

We welcome contributions! Please check the [ARCHITECTURE.md](ARCHITECTURE.md) for design overview and [docs/](docs/) for detailed documentation.

### Development Setup

```bash
# Clone and install
git clone https://github.com/dahai80/fusion-studio.git
cd fusion-studio
./Scripts/setup.sh

# Run in development mode
swift run

# Run tests
swift test
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

- [fusion-mlx](https://github.com/dahai80/fusion-mlx) — Apple Silicon model serving
- [MLX](https://github.com/ml-explore/mlx) — Apple's machine learning framework
- [OpenPencil](https://github.com/penpot/op-openpencil) — Rust vector canvas engine
- All the open-source projects that make local AI possible

---

<p align="center">
  <strong>Fusion Studio</strong> — One App, All Fusion. 100% Local, 100% Yours.
</p>
<p align="center">
  <sub>Built with ❤️ for Apple Silicon</sub>
</p>