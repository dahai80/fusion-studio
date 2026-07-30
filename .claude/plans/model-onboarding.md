# 主模型引导复用方案

## 目标
把 fusion-mac 首次模型引导（WelcomeWindow 全套）复用到 fusion-studio，作为"打开应用设置/获取主模型"入口。让用户首次进入时被引导选择并下载主模型，选定后下发到 fusion-mlx 后端。

## 决策（已与用户确认）
- 引导范围：全 6 步原样搬（intro / setup / hardwareDetect / modelSource / recommend / complete）
- 触发：启动自动（`@AppStorage("mlxModel")` 为空则弹）+ 手动重入
- 下载通道：直连 fusion-mlx HTTP 11434（复用 FusionClient，对齐 FusionConfig）
- ModelHubView：暂不动，引导独立落地

## 现状关键事实
- fusion-studio `IPCClient` 无 `model.list/pull/del`；`ModelHubView` 全 mock（硬编码 5 模型 + 假下载进度 + activateModel 不调 set_model）
- fusion-studio 已有 HTTP 基础：`FusionConfig.mlxBaseURL`（http://localhost:11434）、`mlxResolvedApiKey`（已对齐 `~/.fusion-mlx/settings.json` auth.api_key 解析）、`@AppStorage("mlxModel")` 主模型位
- fusion-mac 引导：HTTP REST `/admin/api/hf/*`、FusionClient（cookie session + apiKey login）、引导内模型硬编码推荐、下载 fire-and-forget、引导后 DownloadsScreenVM 1Hz 轮询 `/admin/api/hf/tasks`、NSWindow 680×620 + NSHostingController

## 搬运清单（fusion-mac -> fusion-studio）
| 源 apps/fusion-mac/Sources/ | 目标 fusion-studio/ | 说明 |
|---|---|---|
| Welcome/WelcomeWindow.swift | FusionStudio/Onboarding/WelcomeView.swift | 引导 UI + VM + 窗口控制器 + 6 步 Body + UI 积木（1593 行） |
| Net/FusionClient.swift | FusionStudio/Bridge/MlxHTTPClient.swift | HTTP 客户端 |
| Net/Endpoints.swift | 合入 MlxHTTPClient | API 路径常量 |
| Net/DTO/HFTaskDTO.swift | FusionStudio/Bridge/MlxModelDTO.swift | HFTaskDTO/HFModelInfo/StartHFDownloadRequest |
| Net/DTO/ModelsDTO.swift | 合入 MlxModelDTO | 模型列表 DTO |
| Config/APIKeyGenerator.swift | FusionStudio/Onboarding/APIKeyGenerator.swift | setup 步随机 key 生成 |

**不搬**：AppConfig（用 FusionConfig 融合）、AppServices（用 @EnvironmentObject）、ServerProcess/PythonRuntime（fusion-studio 用 UpstreamServiceManager 自启 mlx）、swift-markdown-ui + ModelCardSheet（recommend 步模型 README 简化为纯文本）、Theme/（用 StudioTheme 适配）。

## 适配点
1. **主题**：53 处 `.fusionDisplay/.fusionText/.fusionMono/.fusion()` -> `.font(.system(size: theme.xxx))` + FusionButton/FusionCard + `theme.spacing*/accent`
2. **配置融合**：setup 步 port/modelDir/apiKey 写入 `FusionConfig.mlxHost/mlxPort/mlxApiKey/mlxPath`（@AppStorage），不再写独立 settings.json
3. **下载通道**：MlxHTTPClient baseURL=`FusionConfig.mlxBaseURL`（11434），apiKey=`mlxResolvedApiKey`；默认端口 11435 -> 11434
4. **首次检测**：`AppConfig.hasExistingConfig` -> `@AppStorage("mlxModel").isEmpty`
5. **服务启动**：`startServer()` 不 spawn 子进程，改为确认 `UpstreamServiceManager` mlx 服务 running（ensureCriticalRunning + health 探测），引导内下载入口在 mlx running 后才开放（修正原引导时序缺陷）
6. **窗口**：复刻 `WelcomeWindowController`（NSWindow 680×620 + NSHostingController）
7. **触发**：`FusionStudioApp.onAppear` 检测 mlxModel 空 -> `presentWelcome()`；`SettingsView` 加"重新选择主模型"按钮手动重入
8. **模型落地**：recommend 步选定 -> 写 `@AppStorage("mlxModel")` + `agentBridge.mlxSetModel(model:)`（IPC set_model）+ 确保 mlx running
9. **依赖注入**：fusion-mac `AppServices`（@Observable .environment）-> fusion-studio `@EnvironmentObject`（agentBridge / ipcClient / upstreamManager）

## 实现阶段（每阶段 checkpoint 编译验证）
1. **HTTP 层**：搬 MlxHTTPClient + Endpoints + MlxModelDTO，对齐 FusionConfig.mlxBaseURL + mlxResolvedApiKey，编译通过
2. **引导 UI**：搬 WelcomeView + VM + 窗口控制器，主题适配 StudioTheme，编译通过
3. **触发接入**：FusionStudioApp.onAppear 首次检测弹窗 + SettingsView 手动重入入口
4. **模型落地**：recommend 选定 -> mlxModel + mlxSetModel + mlx running 确认
5. **真实下载验证**：起 fusion-mlx（~/claude-home/fusion-mlx/start.sh start），跑引导下载一个模型，确认进度与 set_model 生效

## 风险与注意
- WelcomeWindow 1593 行 + 依赖，搬运适配量大，严格分阶段、控制 token（Rule 6）
- 11434 是否暴露 `/admin/api/hf/*` 需验证（start.sh 启动的 `fusion_mlx serve` 应与 fusion-mac spawn 同套，阶段 5 验证）
- api_key 鉴权方式：fusion-mac FusionClient 用 cookie session + `/admin/api/login`；fusion-studio `mlxResolvedApiKey` 提供 key，需对齐 login 流程（复用 FusionClient 即可，阶段 1 验证）
- swift-markdown-ui 不搬：recommend 步模型 README 展示简化为纯文本/描述
- 遵循约束：4 倍缩进、无 docstring、默认带日志（Logger subsystem com.fusion.studio）、不读图片
