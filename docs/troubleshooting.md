---
doc_id: fusion-studio/troubleshooting
product: fusion-studio
class: app
entry: guided-ui
doc_type: troubleshooting
title: { zh: "Fusion Studio 故障排查", en: "Fusion Studio troubleshooting" }
audience: engineer
status: draft
version: 0.1.66
updated: 2026-11-07
owner: @dahai
source_of_truth:
  - CLAUDE.md
  - .github/workflows/ci.yml
  - Scripts/build.sh
  - docs/api.md
---

# Fusion Studio 故障排查（Troubleshooting）

> 范围：构建、测试、服务连接、配置与打包。每条给出症状 → 定位 → 处置。

## 1. 构建问题（Build）

### 1.1 CI 因 Swift 6 并发警告失败

- 症状：`.github/workflows/ci.yml` 的 `lint` job 阻塞，日志为 concurrency warning。
- 定位：本仓库约定 Swift 6 并发警告按阻塞处理（CLAUDE.md §Conventions）。
- 处置：给视图与可观察服务补显式 `@MainActor`；长文件 I/O 移出主 actor（`nonisolated` 或 detached 任务）。不要用压制警告的方式绕过。

### 1.2 SPM 依赖被改动

- 症状：构建引入第三方包。
- 定位：`Package.swift` 的依赖列表应为空（零外部 SPM 依赖是仓库约定）。
- 处置：还原依赖列表；新能力用系统框架实现。

### 1.3 构建出的 App 缺 Info.plist / 资源

- 症状：直接跑 `swift build` 产物异常或图标/词典缺失。
- 定位：SPM 是权威构建，`FusionStudio.xcodeproj` 为次要；资源经 `Bundle.module` 加载。
- 处置：分发用 `./Scripts/build.sh app`（含拷贝 Info.plist），不要直接使用裸 SPM 产物分发。

## 2. 测试问题（Tests）

### 2.1 本地 `swift test` 执行 0 个用例

- 症状：`swift test list` 发现约 205 个用例，但执行数为 0。
- 定位：本机工具链漂移（Swift 6.3.3 / macOS 26 / Testing Library 1902），非用例丢失（CLAUDE.md 有专节）。
- 处置：不要为本地输出改代码；以 CI `swift-build` job（macos-14 + Xcode 15.x）为权威门槛，本地用 `swift test --filter <Class>` 复核单个类。

## 3. 服务连接（Connectivity）

### 3.1 App 内所有模块离线

- 症状：各模块健康检查失败，UI 显示离线。
- 定位：本仓库自 #296/#298 起无本地守护进程；`env.*`、`hardware.metrics`、`memory.*`、`safety.*`、`mlx.*` 全部经中央路由 `daemon_server.py`（fusion-agent-studio）转发。
- 处置：
  ```bash
  ./Scripts/start.sh status        # 经 fusion-supervisor 查看上游状态
  ls -l /tmp/fusion-studio.sock    # 确认 UDS 存在
  ```
  上游未启动则 `./Scripts/start.sh start`；仍是离线再看 fusion-agent-studio 的路由日志。

### 3.2 模型列表拉不到 / 推理失败

- 症状：模型管理页为空，或对话无响应。
- 定位：`model.*` 不走中央路由，直连 fusion-mlx REST（`/admin/api/models`）。
- 处置：确认 fusion-mlx 在 `127.0.0.1:11434`；检查 `mlxBaseURL` 解析优先级（用户覆盖 > `FUSION_GATEWAY_URL`/`FUSION_MLX_URL` > `FUSION_MLX_PORT` > 默认）。
- 约束：默认地址必须用字面量 IPv4 `127.0.0.1`；`localhost` 可能解析到 `::1`（OrbStack/Docker）并劫持 11434 端口。

### 3.3 Cowork 功能不可用

- 症状：desk 相关面板无数据。
- 定位：cowork `desk.*` 走独立 UDS `/tmp/fusion-cowork.sock`，中央路由不转发该方法族。
- 处置：确认 fusion-cowork 服务已启动且 socket 存在；IPC 方法的权威清单见 `docs/api.md` 与 `Bridge/RPCMethod.swift`（调用点禁止字符串字面量，F-I3）。

### 3.4 仿真页面无响应

- 症状：`sim.*` 功能超时。
- 定位：`sim.*` 直连 fusion-simulation `:11455/api/*`（REST，不走中央路由）。
- 处置：确认 fusion-simulation 服务在 11455 端口存活。

## 4. 配置与密钥（Config & secrets）

### 4.1 设置的端点不生效

- 症状：Settings 改了 host/port 但请求仍打到旧地址。
- 定位：每服务 host/port 是 `@AppStorage` 键（`Common/FusionConfig.swift` 是唯一配置面）。
- 处置：在 Settings 内修改后重启对应面板；新增服务端点必须加 `@AppStorage` 键，禁止内联。

### 4.2 API Key 不生效

- 症状：需要鉴权的 MLX 请求 401。
- 定位：`mlxResolvedApiKey` 优先级：Settings 值 > `FUSION_MLX_API_KEY` 环境变量 > `~/.fusion-mlx/settings.json` 的 `auth.api_key`。
- 处置：按优先级逐层检查；密钥写入走 Keychain 助手，不落明文。

## 5. 打包与分发（Packaging）

### 5.1 DMG 版本号不对

- 定位：版本固定在 `Scripts/build.sh` 顶部 `VERSION`（当前 `0.1.66`），DMG 文件名与 Info.plist 的 `CFBundleShortVersionString` 都取自它。
- 处置：发版前先 bump `VERSION` 再 `./Scripts/build.sh all`。

### 5.2 无签名密钥时打不了正式 tag

- 定位：`./Scripts/build.sh sign` 需要签名密钥；缺失时 release 流程打 `vX.Y.Z-beta`。
- 处置：配置签名密钥后用 `vX.Y.Z` 正式 tag；否则保留 `-beta` 后缀（CLAUDE.md §Build）。

### 5.3 Python 依赖缺失（打包后功能异常）

- 症状：打包版部分仿真/训练功能报缺依赖。
- 定位：`Scripts/build.sh package` 会把 Python 运行时打进 .app；依赖清单见 `Scripts/bundle-requirements.txt` 与 `Scripts/python-standalone-pin.txt`。
- 处置：更新依赖后重新 `package`；开发期依赖装在 monorepo 共享 `.venv`（OPS-7 约定，不入系统 pip）。

## 6. 上游问题边界

上游缺陷（IPC 方法缺失、RPC schema 漂移、后端 bug）在本仓库只记录不修改：先在对应 `fusion-*` 仓库提 issue，修复后本仓库跟进消费。当前开放项与归属见 `docs/upstream-issues.md`；各 GUI 面板对上游端点的覆盖情况见 `docs/upstream-http-endpoints.md` 与 `docs/studio-integration.md`。
