<div align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-brightgreen" alt="macOS">
  <img src="https://img.shields.io/badge/Apple%20Silicon-M1--M5-orange" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Swift-5.9-red" alt="Swift">
  <img src="https://img.shields.io/badge/Rust-2021-purple" alt="Rust">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
  <img src="https://img.shields.io/badge/status-V1.0-yellow" alt="V1.0">
  <img src="https://img.shields.io/badge/modules-20-success" alt="20 Modules">
</div>

<h1 align="center">⚡ Fusion Studio</h1>
<p align="center"><strong>Fusion-MLX 本地 AI 生态的统一 macOS 桌面客户端</strong></p>
<p align="center"><em>一个 App 收口所有能力 — 设计 · 编码 · 仿真 · 多模态 · 训练 · 数据分析 · 智能体 · 知识库 · 自动化。100% 本地离线，Apple Silicon 原生。</em></p>

---

## 📋 概述

**Fusion Studio** 是整个 [Fusion-MLX](https://github.com/dahai80?tab=repositories) 本地 AI 生态的统一 macOS 原生桌面应用。它将 **20 个模块**、6 个产品阶段收口为一个完整的用户体验，彻底消除多终端切换、多浏览器标签页、多目录散落的痛点。

### 为什么要用 Fusion Studio？

| 之前（零散模式） | 之后（统一入口） |
|-----------------|-----------------|
| 🖥️ 5+ 个终端窗口 | 📱 **单一 macOS App** |
| 🌐 浏览器标签页散落 | 🎨 **内置画布 + 编辑器** |
| 📁 多个项目目录 | 📂 **统一工作区** |
| ⚠️ 手动处理依赖问题 | 🔧 **一键修复** |
| 🐌 云端 API 延迟 | ⚡ **本地 MLX 推理** |

### 生态定位

```
fusion-mlx (推理引擎, Metal, KV Cache, 量化, 多模态)
        ↓
Fusion Studio (统一 macOS 桌面客户端)
        ↓
设计 · 编码 · 仿真 · 多模态 · 训练 · 数据 · 智能体 · 知识库 · 测评 · 自动化
```

---

## ✨ 功能总览（20 个模块）

### 🎯 核心平台

| 功能 | 描述 |
|------|------|
| 🔧 **环境自检** | 自动检测 Xcode CLI、Homebrew、Python、MLX、PyBullet、Rust |
| 🛠️ **一键修复** | 自动安装所有依赖 |
| ⚙️ **统一设置** | 硬件加速、离线模式、量化预设、工作区 |
| 📊 **硬件监控** | 实时 CPU/GPU/内存/MLX 指标 |
| 📋 **全局任务队列** | 带持久化的后台任务管理 |
| 🔌 **插件系统** | 第三方扩展支持 |
| ♿ **无障碍** | VoiceOver、键盘导航、减少动态效果 |
| 🌐 **国际化** | 中文、English、日本語、한국어 |
| 🔒 **安全中心** | 沙箱、文件访问控制、完整性检查 |

### 🧩 完整模块列表

| # | 模块 | 图标 | 状态 | 描述 |
|---|------|------|------|------|
| 1 | 🏠 **控制台** | `square.grid.2x2` | ✅ 稳定 | 指挥中心、环境自检、任务队列、硬件监控 |
| 2 | 🎨 **设计** | `pencil.and.outline` | ✅ 稳定 | AI 矢量画布、WKWebView、导出代码 |
| 3 | 💻 **编码** | `chevron.left.forwardslash.chevron.right` | ✅ 稳定 | 代码编辑器 + 集成终端，9 种语言 |
| 4 | 🤖 **仿真** | `gearshape.2` | ✅ 稳定 | PyBullet 物理引擎、3D 视口、场景编辑 |
| 5 | 📦 **模型** | `cpu` | ✅ 稳定 | 模型下载/激活/量化管理 |
| 6 | 🖼️ **多模态** | `photo.on.rectangle` | ✅ 稳定 | 文生图/图生图/OCR/语音转文字/文字转语音 |
| 7 | 🧠 **训练** | `brain` | ✅ 稳定 | LoRA/QLoRA 微调、监控、检查点、模型导出 |
| 8 | ⌨️ **命令行** | `terminal` | ✅ 稳定 | CLI 图形化面板、18 个预设命令、执行历史 |
| 9 | 📄 **文档** | `doc.text` | ✅ 稳定 | 文档编辑器、Markdown、分类管理 |
| 10 | 📚 **知识库** | `books.vertical` | ✅ 稳定 | RAG 检索、文档索引、向量搜索 |
| 11 | 📊 **测评** | `chart.bar` | ✅ 稳定 | 速度/内存/上下文/质量基准测试 |
| 12 | 🧹 **自动化** | `desktopcomputer` | ✅ 稳定 | 桌面自动化、6 个预设模板 |
| 13 | 📈 **数据工具** | `tablecells` | ✅ 稳定 | CSV 导入/导出、统计、图表、SQL 查询 |
| 14 | 🤝 **智能体** | `person.2.fill` | ✅ 稳定 | 多智能体编排、工作流、任务委派 |
| 15 | 🔌 **插件** | `puzzlepiece.extension` | ✅ 稳定 | 插件管理器、市场、开发工具 |
| 16 | 🔒 **安全** | `shield.checkered` | ✅ 稳定 | 安全扫描、事件监控、配置加固 |
| 17 | 📊 **分析** | `chart.bar.xaxis` | ✅ 稳定 | 使用分析、推理统计、错误分析 |
| 18 | 👥 **协作** | `person.2` | ✅ 稳定 | 局域网发现、实时聊天、资源共享 |
| 19 | ⚡ **调优** | `wand.and.rays` | ✅ 稳定 | MLX 自动调优、性能优化 |
| 20 | 🔗 **外部集成** | `link.circle` | ✅ 稳定 | GitHub/Jira/Slack/OpenAI 兼容 API |
| 21 | 📝 **文档生成** | `doc.badge.gearshape` | ✅ 稳定 | 自动生成 API/架构/更新日志/README |
| 22 | 🏭 **行业场景** | `square.stack.3d.forward.dottedline` | ✅ 稳定 | 12 个行业预制场景模板 |
| 23 | 🔧 **运维** | `antenna.radiowaves.left.and.right` | ✅ 稳定 | 服务管理、告警规则、运维日志 |
| 24 | 🔑 **授权** | `key.fill` | ✅ 稳定 | 商业授权、激活、版本对比 |

---

## 🏗️ 架构

```
┌──────────────────────────────────────────────────────────────┐
│  📱 应用层 — SwiftUI 原生桌面（20 个模块导航）               │
│  导航 · 设置 · 环境自检 · 任务管理 · 硬件监控                │
├──────────────────────────────────────────────────────────────┤
│  🛠️ 容器层 — WKWebView + 原生组件（Design/Code/Simulation）│
├──────────────────────────────────────────────────────────────┤
│  🔗 桥接层 — Unix Domain Socket + JSON-RPC 2.0              │
├──────────────────────────────────────────────────────────────┤
│  ⚙️ 服务层 — Rust/Python 守护进程                            │
│  env-daemon · mlx-daemon · supervisor                       │
├──────────────────────────────────────────────────────────────┤
│  🧠 底座层 — fusion-mlx（Apple Silicon 原生）                │
│  LLM · 文生图 · 语音 · OCR · 视频 · 训练                    │
└──────────────────────────────────────────────────────────────┘
```

### 技术栈

| 层级 | 技术 | 选型理由 |
|------|------|----------|
| UI 框架 | **SwiftUI** | macOS 原生，最优性能，Apple Silicon 优化 |
| 内嵌网页 | **WKWebView** | 复用 Fusion-Design 画布 |
| IPC | **Unix Socket + JSON-RPC 2.0** | 轻量、零依赖、跨语言 |
| 后台服务 | **Rust** + **Python** | Rust 高性能，Python 复用 MLX |
| 推理引擎 | **fusion-mlx** | Apple Silicon MLX、多模态、量化 |
| 存储 | **SQLite + UserDefaults** | 零配置、本地优先、加密 |
| 打包 | **Xcode Archive + 公证 + DMG** | 标准 macOS 分发 |

---

## 🚀 快速开始

### 前置要求

- macOS 14+（Sonoma 或更高）
- Apple Silicon（M1–M5）
- [Xcode CLI Tools](https://developer.apple.com/download/all/) (`xcode-select --install`)
- [Homebrew](https://brew.sh)

### 一键安装

```bash
git clone https://github.com/dahai80/fusion-studio.git
cd fusion-studio
./Scripts/setup.sh
```

### 手动安装

```bash
brew install cmake glfw glew
pip3 install mlx pybullet psutil
cd Services/env-daemon && cargo build --release && cd ../..
swift build -c release
./Scripts/start.sh
```

### 上游服务（自动启动）

Fusion Studio 依赖上游生态服务。启动时逐个探测，关键服务通过上游仓库的
`start.sh` 自动拉起（非阻塞--socket 就绪后 `IPCClient` 每 3s 自动重连）。

| 服务 | start.sh | 端点 | 关键 |
|------|----------|------|------|
| fusion-mlx | `~/claude-home/fusion-mlx/start.sh` | `localhost:11434` | ✅ |
| fusion-agent-studio | `~/fusion/fusion-agent-studio/start.sh` | `/tmp/fusion-studio.sock` (UDS) | ✅ |
| fusion-artifacts-engine | `~/fusion/fusion-artifacts-engine/start.sh` | `127.0.0.1:8892` | ✅ |
| fusion-kb (RAG) | `~/fusion/fusion-kb/start.sh` | `127.0.0.1:11436` | 可选 |
| fusion-multi-node | `~/fusion/fusion-multi-node/start.sh` | `127.0.0.1:9753` | 可选 |
| fusion-design | (CLI 工具，无 start.sh) | - | 不适用 |

- 关键服务按顺序自动启动：mlx -> agent-studio -> artifacts-engine。
- 可选服务仅探测状态，需在 UI 手动启动。
- 每个 `start.sh` 支持 `start | stop | restart | status`（退出码 0 = 运行中）。
- Dashboard 展示每个服务状态（运行中 / 未启动 / 服务不存在 / 启动失败），提供
  启动 / 停止 / 重试；关键服务缺失或启动失败时顶部展示横幅。
- 上游仓库路径与自动启动开关位于设置页（`FusionConfig.upstream*Path`、
  `upstreamAutoStartCritical`，默认开启）。

### 构建分发包

```bash
./Scripts/build.sh all    # 完整构建
./Scripts/build.sh dmg    # 生成 DMG 安装包
```

---

## 🗂️ 项目结构

```
fusion-studio/
├── FusionStudio.xcodeproj/       # Xcode 工程
├── Package.swift                  # Swift Package Manager
├── FusionStudio/                 # SwiftUI 源代码（50+ 文件）
│   ├── FusionStudioApp.swift     # @main 入口
│   ├── ContentView.swift          # 主布局
│   ├── Navigation/               # 侧边栏（20 个模块路由）
│   ├── Environment/              # 环境自检引擎
│   ├── TaskManager/              # 任务队列 + 硬件监控
│   ├── Bridge/                   # IPC 客户端
│   ├── Modules/                  # 模块容器（20+ 模块）
│   └── Common/                   # 共享服务（20+ 文件）
├── Services/                     # 后台守护进程
│   ├── env-daemon/               # Rust — 环境自检 + 修复
│   └── mlx-daemon/               # Python — MLX 服务管理
├── Scripts/                      # 构建脚本
├── Tests/                        # 60+ 测试用例
├── .github/workflows/            # CI/CD 流水线
├── README.md                     # 英文文档
└── README_CN.md                  # 本文件
```

---

## 🛡️ 安全与隐私

- **🔒 100% 本地离线** — 开启离线模式后，零外部网络请求
- **📡 无遥测** — 无分析、无回传、无更新检查
- **🏠 仅本地** — 所有数据存储在本地
- **🔐 沙箱** — 文件访问控制、输入过滤、完整性检查
- **⚡ 无云 API** — 硬编码为 fusion-mlx，无第三方后端

---

## 🛣️ 开发路线图

| 阶段 | 重点 | 模块数 | 状态 |
|------|------|--------|------|
| **V0.1 MVP** | 主框架 + 设计 + 编码 + 环境自检 | 5 | ✅ 完成 |
| **V0.2** | 全部模块 + 联动 + 日志 + CLI | 9 | ✅ 完成 |
| **V1.0** | 自动化 + 更新 + 备份 + 安全 | 5 | ✅ 完成 |
| **Phase 4** | 协作 + 插件 + CI/CD | 5 | ✅ 完成 |
| **Phase 5** | 智能体 + RAG + Profiler + i18n | 5 | ✅ 完成 |
| **Phase 6** | 测试 + 引导 + 安全 + 无障碍 | 6 | ✅ 完成 |
| **Phase 7** | 多模态 + 训练 + 数据 + 行业 | 6 | ✅ 完成 |

---

## 📄 许可证

MIT License。详见 [LICENSE](LICENSE)。

---

<p align="center">
  <strong>Fusion Studio</strong> — 一个 App，掌控所有 Fusion 能力。100% 本地，100% 属于你。
</p>
<p align="center">
  <sub>为 Apple Silicon 倾心打造 · 20 个模块 · 50,000+ 行 Swift 代码</sub>
</p>