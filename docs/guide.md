# Fusion Studio User Guide

> **Version**: 1.0.0 · **Platform**: macOS 14+ (Apple Silicon)
> **Modules**: 20+ · **Language**: 中/EN/日/韓

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

When you first launch Fusion Studio, you'll see the **Dashboard** — the command center for all 20+ modules. The app will automatically run an environment health check.

### Step 1: Run Environment Check

1. Open Fusion Studio
2. On the Dashboard, click **"Run Health Check"** in the Environment Health card
3. Wait for all 7 checks to complete
4. Green ✅ means ready; Red ❌ means issues found — click **"Fix"** to auto-repair

### Step 2: Start MLX Service

1. Settings → General → enable **"Auto-start fusion-mlx service"**
2. Or click the bolt icon in the toolbar to start manually
3. Verify: the bolt icon turns green when MLX is running

### Step 3: Explore Modules

Click any module in the sidebar. The first 6 are ready immediately:

| Module | What You Can Do |
|--------|----------------|
| 🏠 **Dashboard** | Health check, task queue, hardware monitor |
| 🎨 **Design** | AI-powered UI design canvas |
| 💻 **Code** | Code editor with integrated terminal |
| 🤖 **Simulation** | 3D physics simulation |
| 📦 **Model Hub** | Browse and manage AI models |
| 🖼️ **MultiModal** | Image generation, OCR, speech, TTS |

---

## Interface Overview

```
┌──────────────────────────────────────────────────────────────┐
│  Toolbar: Health Status | MLX Status | Settings | About      │
│  ┌──────────┐ ┌──────────────────────────────────────────┐   │
│  │ 🏠 控制台 │ │                                          │   │
│  │ 🎨 设计   │ │          Module Content                  │   │
│  │ 💻 编码   │ │                                          │   │
│  │ 🤖 仿真   │ │                                          │   │
│  │ 📦 模型   │ │                                          │   │
│  │ 🖼️ 多模态 │ │                                          │   │
│  │ 🧠 训练   │ │                                          │   │
│  │ ⌨️ 命令行 │ │                                          │   │
│  │ 📄 文档   │ │                                          │   │
│  │ 📚 知识库 │ │                                          │   │
│  │ 📊 测评   │ │                                          │   │
│  │ 🧹 自动化 │ │                                          │   │
│  │ 📈 数据   │ │                                          │   │
│  │ 🤝 智能体 │ │                                          │   │
│  │ 🔌 插件   │ │                                          │   │
│  │ 🔒 安全   │ │                                          │   │
│  │ 📊 分析   │ │                                          │   │
│  │ 👥 协作   │ │                                          │   │
│  │ ⚡ 调优   │ │                                          │   │
│  │ 🔗 外部   │ │                                          │   │
│  └──────────┘ └──────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### Toolbar Indicators

| Icon | Meaning |
|------|---------|
| 🟢 Green | Environment healthy |
| 🔴 Red | Issues found |
| ⚡ Green bolt | MLX service running |
| ⚡ Red bolt | MLX service stopped |

---

## Environment Management

### Health Check Items (7 checks)

| # | Component | Detection | Common Issues |
|---|-----------|-----------|---------------|
| 1 | **Xcode CLI Tools** | `xcode-select -p` | Missing after macOS update |
| 2 | **Homebrew** | `brew --version` | Missing after fresh install |
| 3 | **Python 3.11+** | `python3 --version` | Wrong version |
| 4 | **MLX** | `import mlx` | Not installed |
| 5 | **PyBullet** | `import pybullet` | Compilation failure |
| 6 | **Rust Toolchain** | `rustc --version` | Not installed |
| 7 | **fusion-mlx** | HTTP `localhost:8000` | Service not running |

### One-Click Repair

Click **"Fix"** next to any failed item. The repair engine will:
1. Install the missing dependency
2. Verify the installation
3. Report success/failure with logs

---

## Module Guide

### 1. Dashboard (Control Center)

- **Environment Health Card** — 7 check items with status
- **Task Queue** — Running and pending background tasks
- **Hardware Monitor** — Real-time CPU/GPU/memory/MLX metrics

### 2. Design Canvas

WKWebView with Fusion-Design canvas:
- Vector canvas with zoom/pan
- AI-powered UI generation
- One-click code export to Code module

**JavaScript Bridge**: `window.fusionStudio.sendToNative({...})`

### 3. Code Editor

- **Editor**: Syntax highlighting for 9 languages
- **Terminal**: Integrated command-line interface
- **Languages**: Swift, Python, Rust, JavaScript, TypeScript, HTML, CSS, JSON, YAML

### 4. Simulation

- 3D physics with PyBullet
- Scene list, editor, physics config
- Real-time FPS and status monitoring

### 5. Model Hub

- Model list with search and filter
- Download, activate, delete models
- Quantization options (2bit to fp16)

### 6. MultiModal

- **Text-to-Image**: Generate images from prompts
- **Image-to-Image**: Transform existing images
- **OCR**: Extract text from images
- **Speech-to-Text**: Transcribe audio
- **Text-to-Speech**: Generate speech from text

### 7. Training

- LoRA/QLoRA fine-tuning
- Training monitoring (loss, lr, epoch)
- Checkpoint management
- Model export (MLX/GGUF/CoreML/ONNX)

### 8. Data Tools

- CSV import/export
- Data statistics and summary
- Bar/line charts
- SQL query support

### 9. Agent Studio

- 5 built-in agent types (Code, Research, Design, Analysis, General)
- Task delegation and workflow orchestration
- Agent conversation log

### 10. Other Modules

| Module | Description |
|--------|-------------|
| **CLI** | 18 preset commands, execution history |
| **Doc** | Markdown document editor |
| **KB** | RAG retrieval, document indexing |
| **Bench** | Speed/memory/context benchmarks |
| **Desk** | Desktop automation templates |
| **Plugin** | Plugin manager and developer tools |
| **Security** | Security scan and event monitoring |
| **Analytics** | Usage analytics and inference stats |
| **Collaboration** | LAN peer discovery and chat |
| **Auto Tuning** | MLX performance optimization |
| **External Integrations** | GitHub/Jira/Slack/API |
| **Doc Generator** | Auto-generate documentation |
| **Industry Scenarios** | 12 pre-built templates |
| **Operations** | Service management and alerts |
| **License** | Commercial licensing and activation |

---

## Settings & Configuration

### General

| Setting | Default | Description |
|---------|---------|-------------|
| Language | zh-CN | Interface language (4 languages) |
| Auto-start MLX | On | Auto-start fusion-mlx service |
| Launch at Login | Off | Auto-start on login |
| Offline Mode | On | Block all network requests |

### Hardware

| Setting | Default | Options |
|---------|---------|---------|
| Preferred Device | Auto | GPU/ANE/CPU/Auto |
| Max Memory | 16 GB | 4-64 GB |
| Quantization | 4bit | 2bit/3bit/4bit/5bit/6bit/8bit/fp16 |

---

## Task Management

### Task Types

| Type | Description | Example |
|------|-------------|---------|
| 🔄 Inference | ML model inference | Qwen3.5 chat |
| 🔧 Compile | Code compilation | Swift build |
| 📤 Export | File export | Design export |
| ⚙️ Simulation | Physics simulation | Robot arm |
| 📦 Batch | Batch processing | Bulk export |
| 📥 Download | Model download | Qwen3.5 9B |

### Task Queue Features

- Progress tracking with sub-tasks
- Pause/Resume/Cancel support
- Persistent storage (UserDefaults)
- Task detail view with logs
- History filtering

---

## Hardware Monitoring

| Metric | Display | Range |
|--------|---------|-------|
| Memory | Used GB / Total GB | 4-16 GB / 32 GB |
| GPU | Percentage | 5-100% |
| CPU | Percentage | 10-100% |
| MLX | Active / Idle | — |

Updates every 2 seconds via `Timer.publish`.

---

## Troubleshooting

### Common Issues

**"Cannot connect to fusion-mlx"**
→ Dashboard → Health Check → Click "Fix" on fusion-mlx item

**"PyBullet compilation failed"**
→ `brew install cmake glfw glew` → `pip3 install pybullet`

**"Socket connection refused"**
→ `./Scripts/start.sh` from terminal → Restart Fusion Studio

**"MLX model not found"**
→ Model Hub → Download the model → Activate it

### Logs

```bash
# View env-daemon logs
./Services/env-daemon/target/release/env-daemon
# View mlx-daemon logs
python3 Services/mlx-daemon/daemon.py --no-daemon
```

---

## FAQ

**Q: Is Fusion Studio 100% offline?**
A: Yes. When Offline Mode is enabled, all network requests are blocked. Model downloads are optional.

**Q: What chips are supported?**
A: All M-series chips (M1-M5). Apple Silicon native.

**Q: How do I update?**
A: Settings → Check for Updates, or pull latest from GitHub and rebuild.

**Q: Can I use external models?**
A: Yes. Any MLX-compatible model works. Use Model Hub or place models in workspace.

**Q: How to contribute?**
A: Open issues/PRs on GitHub. See README for details.