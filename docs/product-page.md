---
doc_id: fusion-studio/product-page
product: fusion-studio
class: app
entry: guided-ui
doc_type: product-page
title: { zh: "Fusion Studio 产品页", en: "Fusion Studio product page" }
audience: engineer
status: draft
version: 0.1.66
updated: 2026-11-07
owner: @dahai
source_of_truth:
  - README.md
  - CLAUDE.md
  - Package.swift
  - Scripts/build.sh
---

# Fusion Studio 产品页（Product Page）

> 定位：Fusion-MLX 本地 AI 生态的统一 macOS 桌面客户端。SwiftUI 原生 App，用户在图形界面里直接驱动设计、编码、仿真、多模态、训练、数据分析、智能体、知识库、自动化等模块（README.md）。
> Positioning: the unified macOS native desktop client for the Fusion-MLX local AI ecosystem. A SwiftUI app whose users drive design, code, simulation, multimodal, training, data-analysis, agent, knowledge-base and automation modules from a GUI (README.md).

## 网格定位（Grid position）

- class = `app`：面向最终用户的桌面产品，用户通过 UI 完成任务。
- entry = `guided-ui`：主入口是 SwiftUI 窗口（`FusionStudioApp.swift` 为 `@main`），不是 CLI 或 API。
- 证据：`Package.swift` 声明可执行目标 `FusionStudio`（macOS 14+）；`FusionStudio/` 下是 `Modules/`、`Navigation/`、`Components/` 等 UI 层目录；`Scripts/build.sh` 产出 `.app` 与 DMG。

## 用户能力（What users no longer have to do）

| 能力 | 用户不再需要做 | 约束 / 限制 |
|------|----------------|-------------|
| 统一工作台 | 不用在多个终端、浏览器标签和散落的目录之间切换（README.md "Before/After" 对照表） | 需要本机运行 macOS 14+ 且为 Apple Silicon |
| 本地推理对话 | 不用自己 curl MLX HTTP API；App 内聊天走 MLX/网关 | 推理依赖 fusion-mlx（`:11434`）或 fusion-gateway（`:11432`）已在本地运行 |
| 后端服务纳管 | 不用逐个执行各 `fusion-*` 的 `start.sh`；`Scripts/start.sh` 委托 fusion-supervisor 统一 start/stop/status | 依赖 fusion-supervisor 与各上游仓库已安装 |
| 多语言界面 | 不用改代码切语言；内置 en-US / zh-CN / ja-JP / ko-KR 四套词典（`Resources/i18n/`） | 新增文案需同时维护四个 JSON 文件 |
| 端点与密钥 | 不用改配置文件；Settings 里的 `@AppStorage` 键可直接覆盖各服务 host/port，密钥进 Keychain | MLX 地址默认字面量 `127.0.0.1:11434`；用 `localhost` 可能被 `::1`（OrbStack/Docker）劫持 |
| 工作流编排 | 不用手写 DAG；工作流画布支持模板库、运行历史与 diff（v0.1.66，issue #421-#433） | 画布执行仍依赖 cowork/FSB/本地执行器可用 |

## 架构摘要（Architecture summary）

五层（CLAUDE.md §Architecture）：SwiftUI App 层 → 模块容器层 → IPC 桥层（JSON-RPC 2.0 over UDS `/tmp/fusion-studio.sock` + 按服务 HTTP REST）→ 中央路由 `daemon_server.py`（位于 fusion-agent-studio）→ 基础服务层（fusion-mlx 等）。本仓库自 #296/#298 起不再包含本地 Rust/Python 守护进程。

## 边界（Boundaries）

- 上游问题（IPC 方法缺失、RPC schema 漂移、后端 bug）在本仓库只提 issue，不改上游代码；开放项记录在 `docs/upstream-issues.md`。
- 部分能力仍是壳界面，覆盖情况见 `docs/studio-integration.md`。
- 本地 `swift test` 在当前工具链（Swift 6.3.3 / macOS 26）只发现不执行用例；以 CI 为准（详见 troubleshooting）。

## 文档地图（Doc map）

- 快速上手：`docs/get-started.md`
- 故障排查：`docs/troubleshooting.md`
- IPC 方法参考：`docs/api.md`
- 上游端点与覆盖：`docs/upstream-http-endpoints.md`、`docs/studio-integration.md`
