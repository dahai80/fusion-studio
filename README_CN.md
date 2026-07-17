<div align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-brightgreen" alt="macOS">
  <img src="https://img.shields.io/badge/Apple%20Silicon-M1--M5-orange" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Swift-5.9-red" alt="Swift">
  <img src="https://img.shields.io/badge/Rust-2021-purple" alt="Rust">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
  <img src="https://img.shields.io/badge/status-MVP-yellow" alt="MVP">
</div>

<h1 align="center">⚡ Fusion Studio</h1>
<p align="center"><strong>Fusion-MLX 本地 AI 生态的统一 macOS 桌面客户端</strong></p>
<p align="center"><em>一个 App 收口所有能力 — 设计 · 编码 · 仿真 · 模型管理 · 知识库 · 基准测试 · 桌面自动化。100% 本地离线，Apple Silicon 原生。</em></p>

---

## 📋 概述

**Fusion Studio** 是整个 [Fusion-MLX](https://github.com/dahai80?tab=repositories) 本地 AI 生态的统一 macOS 原生桌面应用。它将 9+ 子产品收口为一个完整的用户体验，彻底消除多终端切换、多浏览器标签页、多目录散落的痛点。

### 为什么要用 Fusion Studio？

| 之前（零散模式） | 之后（统一入口） |
|-----------------|-----------------|
| 🖥️ 终端 1: `fusion-cli` | 📱 **单一 macOS App** |
| 🖥️ 终端 2: `fusion-coder` | 🎨 **设计画布** (WKWebView) |
| 🌐 浏览器: `fusion-design` | 💻 **代码编辑器** (内置) |
| 🖥️ 终端 3: `fusion-simulation` | 🤖 **仿真视图** (Metal) |
| 📁 多个目录 | 📂 **统一工作区** |
| ⚠️ 手动处理依赖问题 | 🔧 **一键修复** |

### 生态定位

```
fusion-mlx (推理引擎, Metal, KV Cache, 量化)
        ↓
Model-Hub / KB / Bench / Plugins (数据与评估层)
        ↓
Fusion Studio (统一 macOS 桌面客户端)
        ↓
Design · Code · Simulation · Doc · Desk · Agent-Studio (应用层)
```

---

## ✨ 功能特性

### 🎯 核心平台

- **🔧 环境自检 & 一键修复** — 自动检测 Xcode CLI、Homebrew、Python、MLX、PyBullet、Rust 工具链，一键修复
- **⚙️ 统一设置** — 硬件加速、离线模式、量化预设、工作区管理，集成在一个面板
- **📊 硬件监控** — 实时统一内存、CPU/GPU 占用率、MLX 推理状态
- **📋 全局任务队列** — 推理、编译、导出、仿真等后台任务管理

### 🧩 模块集成

| 模块 | 状态 | 描述 |
|--------|--------|-------------|
| 🎨 **Fusion-Design** | ✅ MVP | WKWebView 画布，集成 tldraw/OpenPencil |
| 💻 **Fusion Code** | ✅ MVP | 内置代码编辑器 + 集成终端 |
| 🤖 **Fusion-Simulation** | 📅 V0.2 | PyBullet 物理仿真视图 |
| 📦 **Fusion Model Hub** | 📅 V0.2 | 可视化管理面板 |
| ⌨️ **Fusion CLI** | 📅 V0.2 | CLI 图形化面板 |
| 📄 **Fusion-Doc** | 📅 V0.2 | 文档管理 |
| 📚 **Fusion-KB** | 📅 V0.2 | 知识库 RAG 检索 |
| 📊 **Fusion-Bench** | 📅 V0.2 | 基准测试仪表盘 |
| 🧹 **Fusion-Desk** | 📅 V0.2 | 桌面自动化 |

### 🔗 设计 → 代码 → 仿真 联动流水线

```
🎨 设计 UI → 💻 导出代码 → 🤖 部署为控制面板 → 🏃 运行仿真
```

---

## 🏗️ 架构

```
┌──────────────────────────────────────────────────────────────┐
│  📱 应用层 — SwiftUI 原生桌面                                │
│  导航 · 设置 · 环境自检 · 任务管理                           │
├──────────────────────────────────────────────────────────────┤
│  🛠️ 容器层 — WKWebView + 原生组件                            │
│  Design · Code · Simulation · Model Hub · CLI · Doc · KB    │
├──────────────────────────────────────────────────────────────┤
│  🔗 桥接层 — Unix Domain Socket + JSON-RPC 2.0               │
├──────────────────────────────────────────────────────────────┤
│  ⚙️ 服务层 — Rust/Python 守护进程                             │
│  env-daemon · mlx-daemon · file-daemon · supervisor          │
├──────────────────────────────────────────────────────────────┤
│  🧠 底座层 — Apple Silicon 原生                              │
│  fusion-mlx · Metal · ANE · PyBullet · VideoToolbox          │
└──────────────────────────────────────────────────────────────┘
```

### 技术栈

| 层级 | 技术 | 选型理由 |
|-------|-----------|-----------|
| UI 框架 | **SwiftUI** | macOS 原生，最优性能，Apple Silicon 优化 |
| 内嵌网页 | **WKWebView** | 复用 Fusion-Design 画布，无需重构 |
| 代码编辑器 | **CodeEditorView** (SwiftUI) | 原生集成，轻量 |
| IPC | **Unix Socket + JSON-RPC 2.0** | 轻量，零依赖，跨语言 |
| 后台服务 | **Rust** (主) + **Python** (副) | Rust 高性能/进程管理，Python 复用 MLX 代码 |
| 仿真渲染 | **Metal View + PyBullet** | 原生 GPU 加速 |
| 存储 | **SQLite** | 零配置，本地优先 |
| 打包 | **Xcode Archive + 公证 + DMG** | 标准 macOS 分发流程 |

---

## 🚀 快速开始

### 前置要求

- macOS 14+ (Sonoma 或更高)
- Apple Silicon (M1–M5)
- [Xcode CLI Tools](https://developer.apple.com/download/all/) (`xcode-select --install`)
- [Homebrew](https://brew.sh)（依赖管理）

### 一键安装

```bash
# 克隆仓库
git clone https://github.com/dahai80/fusion-studio.git
cd fusion-studio

# 运行安装脚本（自动安装所有依赖）
./Scripts/setup.sh
```

### 手动安装

```bash
# 1. 安装依赖
brew install cmake glfw glew
pip3 install mlx pybullet psutil

# 2. 构建 Rust 服务
cd Services/env-daemon && cargo build --release && cd ../..

# 3. 构建 SwiftUI App
swift build -c release

# 4. 启动所有服务
./Scripts/start.sh
```

### 构建分发包

```bash
# 完整构建：services + app + package + sign + dmg
./Scripts/build.sh all

# 或构建单个组件
./Scripts/build.sh services    # 仅构建 Rust 守护进程
./Scripts/build.sh app         # 仅构建 SwiftUI App
./Scripts/build.sh package     # 构建全部并打包 .app
./Scripts/build.sh dmg         # 生成 DMG 安装包
```

---

## 🗂️ 项目结构

```
fusion-studio/
├── FusionStudio.xcodeproj/       # Xcode 工程
├── Package.swift                  # Swift Package Manager
├── FusionStudio/                 # SwiftUI 源代码
│   ├── FusionStudioApp.swift     # @main 入口
│   ├── ContentView.swift          # 主布局 (NavigationSplitView)
│   ├── Navigation/               # 侧边栏 + 模块路由
│   ├── Settings/                 # 设置面板 (5 标签页)
│   ├── Environment/              # 环境自检引擎
│   ├── TaskManager/              # 任务队列 + 硬件监控
│   ├── Bridge/                   # IPC 客户端 (JSON-RPC)
│   ├── Modules/                  # 模块容器
│   │   ├── Design/               # WKWebView 画布
│   │   ├── Code/                 # 代码编辑器 + 终端
│   │   ├── Simulation/           # 仿真视图 (V0.2)
│   │   └── ...                   # 其他模块 (V0.2+)
│   └── Common/                   # 共享状态、配置、关于
├── Services/                     # 后台守护进程
│   ├── env-daemon/               # Rust — 环境自检 + 修复引擎
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── main.rs           # JSON-RPC 服务器（带崩溃恢复）
│   │       └── lib.rs            # HealthChecker + RepairEngine
│   └── mlx-daemon/               # Python — MLX 推理服务
│       └── daemon.py             # MLX 进程管理器 + 硬件监控
├── Scripts/                      # 构建 & 部署脚本
│   ├── setup.sh                  # 一键开发环境安装
│   ├── build.sh                  # 完整构建流水线
│   ├── start.sh                  # 启动所有服务
│   └── sign.sh                   # 代码签名 + 公证
├── Workspace/                    # 默认工作区目录
│   ├── designs/                  # 设计文件
│   ├── projects/                 # 代码工程
│   ├── simulations/              # 仿真场景
│   └── models/                   # 模型权重软链
├── ARCHITECTURE.md               # 架构文档
├── README.md                     # 英文文档
└── README_CN.md                  # 本文件
```

---

## 🛡️ 安全与隐私

- **🔒 100% 本地离线** — 开启离线模式后，零外部网络请求
- **📡 无遥测** — 无分析、无回传、无更新检查
- **🏠 仅本地** — 所有模型、数据、向量存储在本地
- **🔐 Socket 安全** — Unix socket 权限设置为 `0600`（仅所有者）
- **⚡ 无云 API** — 硬编码为 fusion-mlx，无第三方后端

---

## 🛣️ 路线图

### V0.1 MVP (当前) ✅
- [x] SwiftUI 主框架（导航、设置、环境自检）
- [x] 环境自检 & 一键修复引擎
- [x] IPC 桥接 (Unix Socket JSON-RPC)
- [x] Fusion-Design WKWebView 画布容器
- [x] Fusion Code 编辑器 + 集成终端
- [x] 全局任务队列 & 硬件监控
- [x] 统一工作区目录
- [x] Rust env-daemon 带崩溃恢复
- [x] Python mlx-daemon MLX 服务管理
- [x] 构建 & 打包脚本

### V0.2 (计划 — 2~3 周)
- [ ] Fusion-Simulation 仿真视图 (PyBullet)
- [ ] Fusion Model Hub 可视化管理
- [ ] CLI 图形化面板
- [ ] Doc/KB/Bench 基础面板
- [ ] 模块间联动 (Design ↔ Code ↔ Simulation)
- [ ] 增强任务队列（进度、暂停、取消）

### V1.0 (计划 — 1 个月+)
- [ ] 全部 9 个模块入口完成
- [ ] 应用签名、公证、DMG 分发
- [ ] 自动更新机制
- [ ] 长时运行稳定性 & 内存优化
- [ ] 用户文档 & 使用指南

### 未来
- [ ] 团队局域网协作
- [ ] 第三方插件系统
- [ ] 高级仿真参数调节
- [ ] CI/CD 流水线

---

## 🤝 贡献

欢迎贡献代码！请先阅读 [ARCHITECTURE.md](ARCHITECTURE.md) 了解架构设计，以及 [docs/](docs/) 中的详细文档。

### 开发环境

```bash
# 克隆并安装
git clone https://github.com/dahai80/fusion-studio.git
cd fusion-studio
./Scripts/setup.sh

# 开发模式运行
swift run

# 运行测试
swift test
```

---

## 📄 许可证

MIT License。详见 [LICENSE](LICENSE)。

---

## 🙏 致谢

- [fusion-mlx](https://github.com/dahai80/fusion-mlx) — Apple Silicon 模型服务
- [MLX](https://github.com/ml-explore/mlx) — Apple 机器学习框架
- [OpenPencil](https://github.com/penpot/op-openpencil) — Rust 矢量画布引擎
- 所有让本地 AI 成为可能的开源项目

---

<p align="center">
  <strong>Fusion Studio</strong> — 一个 App，掌控所有 Fusion 能力。100% 本地，100% 属于你。
</p>
<p align="center">
  <sub>为 Apple Silicon 倾心打造 ❤️</sub>
</p>