# Fusion Studio — 产品矩阵 GUI 覆盖深度分析

> **更新**: 2026-07-27 · **范围**: ~/fusion/fusion-* 全量扫描 + FusionStudio源码逐视图审计

---

## 一、总览：上游能力 vs Studio对接

| # | 上游项目 | 核心能力 | 上游API方式 | Studio视图 | 对接深度 | 状态 |
|---|---------|---------|-----------|----------|---------|------|
| 1 | fusion-mlx | MLX推理引擎 | HTTP(8000/11434) | DashboardView/TrainingView/MLXOptimizerView | 调用mlx.start/stop/status/health | 🟡 部分 |
| 2 | fusion-design | AI设计画布(OpenPencil) | Rust/WASM+HTTP(8080) | DesignView | WKWebView嵌入 | 🟡 部分 |
| 3 | fusion-code | 终端AI编码(Ink+React) | CLI进程 | CodeEditorView | 原生SwiftUI替代，仅CodeAgent调infer | 🟡 部分 |
| 4 | fusion-simulation | 机器人仿真训练 | CLI | SimulationView | 纯静态UI | 🔴 外壳 |
| 5 | fusion-model-hub | 模型仓库(REST API) | HTTP(多端口) | ModelHubView | 纯静态UI | 🔴 外壳 |
| 6 | fusion-cli | 统一CLI(Rust) | CLI进程 | CLIView | 纯静态UI(18个预设按钮) | 🔴 外壳 |
| 7 | fusion-doc | 智能文档(20+ API) | HTTP(11435) | DocView | 纯静态UI | 🔴 外壳 |
| 8 | fusion-kb | 向量知识库(LanceDB) | HTTP(11436) | KBView | 纯静态UI | 🔴 外壳 |
| 9 | fusion-bench | 模型测评(REST+Web) | HTTP+Next.js | BenchView | WKWebView嵌入bench站 | 🟡 部分 |
| 10 | fusion-cowork | 桌面自动化(15 MCP工具) | CLI+MCP | DeskView | 纯静态UI(模板列表) | 🔴 外壳 |
| 11 | fusion-agent-studio | Agent编排(图编辑/调试/市场) | UDS JSON-RPC | AgentStudioView | 调用agent/graph/marketplace全套 | 🟢 已接 |
| 12 | fusion-security | 代码安全审计(5阶段流水线) | HTTP(8000)+React | SecurityView | WKWebView嵌入 | 🟡 部分 |
| 13 | fusion-comfyui | ComfyUI图像/视频生成 | HTTP(8188)+WebSocket | 无 | — | ⚫ 缺失 |
| 14 | fusion-multi-node | 分布式MLX集群调度 | HTTP(9753) | MultiNode/(11视图) | 调用全套REST API | 🟢 已接 |
| 15 | fusion-trainer | SFT/RLSL训练器 | CLI | TrainingView | 纯静态UI | 🔴 外壳 |
| 16 | fusion-artifacts-engine | 产物管理(版本/安全/注入) | HTTP(8892) | ArtifactsPanel | 调用list/get/delete/version | 🟡 部分 |
| 17 | fusion-core | 共享HTTP客户端库 | Python API | 底层库 | 无需GUI | ✅ 无需 |
| 18 | fusion-plugins-ecosystem | 插件注册/MCP适配 | Python API | PluginView | 纯静态UI(本地目录扫描) | 🔴 外壳 |
| 19 | fusion-code-modelization | 代码建模/迁移/重构 | CLI | 无 | — | ⚫ 缺失 |
| 20 | fusion-science | 科研工作台(60+数据库) | CLI+Web | 无 | — | ⚫ 缺失 |
| 21 | fusion-finance | 金融分析(6估值模型) | CLI+Python API | 无 | — | ⚫ 缺失 |
| 22 | fusion-health | 医疗AI(EHR/ICD-10) | CLI+Python API | 无 | — | ⚫ 缺失 |
| 23 | fusion-k12-teacher | K12教育(课程/测评) | CLI+Python API | 无 | — | ⚫ 缺失 |

### 图例

- 🟢 **已接**: 后端API全部连通，功能可用
- 🟡 **部分**: 有后端调用但覆盖不全，或仅WebView嵌入无深度集成
- 🔴 **外壳**: 只有UI界面，无后端API调用，数据为硬编码/占位
- ⚫ **缺失**: 无任何视图

---

## 二、🔴 外壳视图详细审计

以下视图在FusionStudio中存在，但**未调用任何后端API**，数据全部硬编码：

### Modules/ 目录

| 视图文件 | Module | 硬编码内容 | 上游实际提供但未接入的能力 |
|---------|--------|----------|------------------------|
| **SimulationView.swift** | .simulation | 场景状态枚举(idle/running/paused)、FPS占位 | `env init`, `train --dataset`, `test --model`, `bench`, `dataset import/list` 全套CLI |
| **ModelHubView.swift** | .modelHub | 模型列表(硬编码名称/大小/量化)、下载进度假数据 | REST API: `/api/v1/models` CRUD, `/api/v1/versions` 生命周期, `/api/v1/quantize`, HuggingFace导入, RBAC, Webhooks, 部署灰度 |
| **CLIView.swift** | .cli | 18个命令预设按钮(纯文本) | Rust二进制: `fusion model list/pull`, `fusion kb query`, `fusion bench speed`, `fusion desk run` 等全部CLI |
| **DocView.swift** | .doc | 文档分类列表(硬编码标题/标签) | HTTP(11435): 20+ API — workspaces/books/chapters/pages/versions/links/tags/search/graph/ai/chat/ai/embeddings/rag/index/rag/query/export |
| **KBView.swift** | .kb | 知识库条目列表(硬编码标题/相关度) | HTTP(11436): `/kb/bases` CRUD, `/documents` 上传, `/scan` 扫描, `/search` 向量搜索, `/ask` RAG问答 |
| **DeskView.swift** | .desk | 自动化模板列表(10个硬编码模板) | CLI: `fusion-cowork template list/run`, `ai generate`, MCP Server 15个工具, DAG工作流引擎 |
| **TrainingView.swift** | .training | 训练参数表单(LoRA/QLoRA选项) | CLI: `fusion-trainer sft/rlsl`, `dataset import/list/info`, SFT全参数+RLSL/DPO/ORPO |
| **DataToolsView.swift** | .dataTools | 数据集列表+图表类型选择 | 无专属上游，应接fusion-artifacts-engine的data类型产物 |
| **MultiModalView.swift** | .multimodal | 任务类型标签(文生图/OCR/语音) | 应调fusion-mlx的 `/v1/images/generations`, `/v1/audio/speech`, `/v1/audio/transcriptions` |
| **OperationsView.swift** | 未路由 | CPU/内存/磁盘监控假数据 | 应接fusion-multi-node的metrics API或mlx-daemon的硬件监控 |
| **IndustryScenariosView.swift** | 未路由 | 4个行业场景卡片(金融/医疗/教育/制造) | 应接fusion-finance/health/k12/science的实际能力 |
| **LicenseView.swift** | 未路由 | 4个许可证层级(Community/Pro/Enterprise/Trial) | 无上游对应，纯本地逻辑 |
| **InteropService.swift** | 未路由 | 设计→代码→仿真事件总线(纯本地) | 应接fusion-design的export + fusion-code的API + fusion-simulation的API |

### Common/ 目录

| 视图/服务 | 硬编码内容 | 应接入的上游 |
|----------|----------|-----------|
| **AnalyticsDashboardView** | 指标卡片(假数据) | fusion-bench的stats/aggregate API |
| **AutoTuningView** | 优化维度列表(静态) | fusion-bench的auto-tune API |
| **CollaborationService** | Bonjour发现+addSamplePeers()注入假数据 | 需真实对等发现+fusion-multi-node集群协作 |
| **DocGeneratorView** | 生成选项表单(静态) | fusion-doc的AI生成API |
| **ExternalIntegrationsView** | 集成卡片列表(静态) | fusion-plugins-ecosystem的ClaudeGateway |
| **PluginService** | 本地目录扫描插件 | fusion-plugins-ecosystem的registry API |

### Navigation/ 目录

| 视图 | 硬编码内容 |
|-----|----------|
| **ChatsPanel** | ChatStore.init()硬编码示例对话，"移动到项目"为占位符 |
| **InspectorPanel** | 7个子视图中5个用硬编码值(仅Node/ClusterTask接MultiNodeEngine) |

---

## 三、🟡 部分对接详细审计

### 1. AgentStudioView - 20 tabs 全量 RPC 对接（Issue #17/#18 已落地，PR #19 合并）

**已接**: agent CRUD, graph CRUD, skill/soul管理, 市场搜索/安装, 执行/取消

**#17/#18 新增 tabs（覆盖主要 RPC 命名空间）**:
- Team / Memory / Safety / Planner - team.* / memory.* / safety.* / planner.*
- Connectors / API Keys / Styles - connector.* / 鉴权配置 / 风格
- Analytics / Alerts - 指标 / 告警
- Cron / Hooks - cron.* / hooks.*（原「Webhook/Cron触发器」）
- RAG / Tools / Skills / Marketplace - rag.* / tool.* / skill.* + research.adaptive / marketplace.*
- Chat 内 context compact/usage（原「记忆自动压缩」）
- 19 个内置工具查看/动态注册（Tools tab，原「19个内置工具的查看/配置」）
- 3 级 HITL 治理（Safety tab 的 approve/reject，原「3级HITL治理」）

**仍未接的上游能力**:
- 步进调试器 (step debugger)
- 检查点/恢复 (checkpoint/resume)
- FMP router v2 / swarm router
- 代码沙箱(sandbox-exec)
- 知识引擎(knowledge.*)
- LLM网关

### 2. MLXOptimizerView / DashboardView — mlx基础已接，缺3项

**已接**: start/stop/restart/status/health + hardware metrics

**未接**:
- 推理调用 (`mlx.infer` / `/v1/chat/completions`)
- 模型切换后的配置验证
- GPU过载检测

### 3. BenchView — WebView已嵌入，缺原生集成

**已接**: WKWebView加载bench.dpdns.org

**未接**:
- 本地benchmark REST API (`/api/benchmarks`, `/api/v1/suites`)
- 速度/内存/上下文压力测试的原生控制面板
- 量化对比、安全探测、3级质量门
- 自动调参

### 4. SecurityView — WebView已嵌入，缺原生集成

**已接**: WKWebView加载fusion-security React dashboard

**未接**:
- 5阶段流水线控制(Recon→Discover→Verify→Triage→Patch)
- `/api/v1/scans` 发起扫描
- `/api/v1/vulnerabilities` 漏洞列表
- `/api/v1/patches` 修复建议
- SARIF导出、飞书/钉钉通知集成

### 5. DesignView — WebView已嵌入，缺原生桥接

**已接**: WKWebView加载localhost:8080

**未接**:
- fusionBridge消息处理(已注册但无业务逻辑)
- 设计→代码导出 (design.export_code)
- React/HTML/Tailwind/SVG/PNG/PDF导出

### 6. CodeEditorView — CodeAgent已接，缺6项

**已接**: CodeAgent通过AgentBridge调infer

**未接**:
- 文件树与实际项目目录同步(当前为硬编码)
- LSP集成
- 调试器
- Claude Code CLI兼容
- 88个feature flag控制
- 自动compact上下文管理

### 7. ArtifactsPanel — 基础CRUD已接，缺8项

**已接**: ping, list, get_content, version_list, delete

**未接**:
- artifact.create (创建)
- artifact.update (更新)
- artifact.inject (注入回对话)
- artifact.check_safety (安全检查)
- artifact.export / export_session (导出)
- artifact.import (导入)
- artifact.version_rollback (版本回滚)

### 8. DocView / DeskView — 纯外壳，上游有完整API

**fusion-doc** 提供 HTTP(11435) 的 20+ API:
- `/api/workspaces`, `/api/books`, `/api/chapters`, `/api/pages`
- `/api/pages/:id/versions`, `/api/pages/:id/links`
- `/api/tags`, `/api/search`, `/api/graph`
- `/api/ai/chat`, `/api/ai/embeddings`
- `/api/rag/index`, `/api/rag/query`
- `/api/export/:format/:id`

**fusion-cowork** 提供 CLI + MCP:
- `fusion-cowork template list/show/run`
- `fusion-cowork ai generate/status`
- MCP Server 15个工具 (Shell, Python REPL, Web Search, Fetch URL, Apply Edit等)
- DAG工作流引擎

---

## 四、⚫ 完全缺失的项目

| 项目 | 核心能力 | API方式 | 上游已有GUI | 建议Studio实现方式 |
|------|---------|--------|-----------|-----------------|
| **fusion-comfyui** | MLX ComfyUI图像/视频生成, FLUX.2/Wan2.2/SkyReels | HTTP(8188)+WebSocket | SwiftUI App+ComfyUI Web+Gradio | WKWebView嵌入ComfyUI Web + 原生SwiftUI模型/工作流管理 |
| **fusion-code-modelization** | 代码建模/迁移(11语言), 死代码检测, 增量重构 | CLI | 无 | CodeEditorView内新增"建模/重构"标签页 |
| **fusion-science** | 科研工作台, 60+科学数据库, 3D分子可视化, 论文写作 | CLI+Web | Web UI(开发中) | 原生SwiftUI: 数据库连接器+3D可视化+文献管理 |
| **fusion-finance** | 6估值模型(DCF/Comps/LBO/DDM/Merger/Monte Carlo), 风险管理, 审计 | CLI+Python API | 无 | 原生SwiftUI: 估值仪表盘+风险热力图+报告生成 |
| **fusion-health** | EHR处理, ICD-10/CPT编码, 文献检索, 合规审计 | CLI+Python API | 无 | 原生SwiftUI: 临床摘要+编码建议+合规检查 |
| **fusion-k12-teacher** | 课程规划, 作文/数学评分, 自适应学习, 内容生成 | CLI+Python API | 无 | 原生SwiftUI: 课程编辑+评分面板+学习路径 |

---

## 五、已开发未接入路由的视图

| 视图文件 | 功能 | 后端连接 | 建议接入组 |
|---------|------|---------|----------|
| RAGPipelineView.swift | RAG检索增强 | ✅ AgentBridge.ragQuery + RAGEngine | Agent Studio |
| SafetyView.swift | 安全检查 | ✅ AgentBridge全套safety方法 | Agent Studio |
| MemoryView.swift | 智能体记忆 | ✅ AgentBridge全套memory方法 | Agent Studio |
| PlannerView.swift | 任务规划 | ✅ AgentBridge全套planner方法 | Agent Studio |
| MLXOptimizerView.swift | 模型优化 | ✅ AgentBridge mlx+hardware | MLX |
| DeployView.swift | 部署打包 | ✅ AgentBridge deploy方法 | Code |
| OperationsView.swift | 运维监控 | 🔴 硬编码 | Multi-Node |
| LicenseView.swift | 许可证 | 🔴 硬编码 | 设置页 |
| IndustryScenariosView.swift | 行业场景 | 🔴 硬编码 | Dashboard |

---

## 六、WKWebView嵌入现状

| 模块 | URL | 上游项目 | 嵌入深度 |
|------|-----|---------|---------|
| DesignView | localhost:8080 | fusion-design | 仅加载，fusionBridge未实现业务逻辑 |
| BenchView | bench.dpdns.org | fusion-bench | 远程站，无本地API联动 |
| SecurityView | localhost:3000 | fusion-security | 仅加载React dashboard |
| ServiceWebView | 127.0.0.1:9753/docs + localhost:3000 | fusion-multi-node/security | 仅API文档和bench站 |

---

## 七、统计

| 类别 | 数量 | 占比 |
|------|------|------|
| 🟢 已接(后端全通) | 2 (AgentStudio, MultiNode) | 9% |
| 🟡 部分(有调用但覆盖不全) | 9 | 39% |
| 🔴 外壳(纯UI无后端) | 11 | 48% |
| ⚫ 缺失(无视图) | 6 | — |
| 未路由(代码存在但未接入) | 9 | — |

### 按模块统计后端连接

| 后端 | IPC/HTTP方法总数 | Studio已调用 | 覆盖率 |
|------|----------------|------------|--------|
| AgentBridge (agent-studio) | ~25 | ~14 | 56% |
| IPCClient (mlx) | 6 | 5 | 83% |
| MultiNodeEngine (multi-node) | ~20 | ~20 | 100% |
| IPCClient (artifacts) | 13 | 5 | 38% |
| fusion-doc HTTP | 20+ | 0 | 0% |
| fusion-kb HTTP | 8+ | 0 | 0% |
| fusion-model-hub REST | 30+ | 0 | 0% |
| fusion-cowork CLI/MCP | 15+ | 0 | 0% |
| fusion-bench REST | 8+ | 0 (仅WebView) | ~10% |
| fusion-security REST | 8+ | 0 (仅WebView) | ~10% |
| fusion-trainer CLI | 6+ | 0 | 0% |
| fusion-simulation CLI | 6+ | 0 | 0% |

---

## 八、优先级建议

| 优先级 | 任务 | 工作量 | 收益 |
|--------|------|--------|------|
| **P0** | ✅ 部分完成（#18）：RAG/Safety/Memory/Planner 已作为 AgentStudioView tabs 落地；MLXOpt/Deploy/Operations/License/Industry 仍待独立路由 | - | 4 个后端能力已激活 |
| **P1** | ArtifactsPanel补全(增加create/update/inject/safety/export) | 2天 | 产物管理闭环 |
| **P1** | ModelHubView接入fusion-model-hub REST API | 3天 | 模型管理从假数据变真实 |
| **P1** | KBView接入fusion-kb HTTP API | 2天 | 知识库从假数据变真实 |
| **P2** | DocView接入fusion-doc HTTP API | 3天 | 文档编辑/协作/RAG可用 |
| **P2** | DeskView接入fusion-cowork MCP/CLI | 3天 | 自动化模板真实执行 |
| **P2** | SimulationView接入fusion-simulation CLI | 3天 | 仿真训练真实可用 |
| **P2** | TrainingView接入fusion-trainer CLI | 2天 | 训练任务真实提交 |
| **P2** | MultiModalView接入fusion-mlx多模态API | 2天 | 文生图/语音/OCR真实调用 |
| **P3** | BenchView原生API集成(替代纯WebView) | 3天 | 本地测评控制面板 |
| **P3** | SecurityView原生API集成 | 3天 | 扫描/漏洞/修复原生控制 |
| **P3** | DesignView fusionBridge业务逻辑实现 | 2天 | 设计→代码导出闭环 |
| **P4** | fusion-comfyui嵌入 | 5天 | 图像/视频生成新模块 |
| **P4** | fusion-code-modelization | 3天 | 代码建模/重构新标签页 |
| **P5** | fusion-finance/health/k12/science | 各3天 | 行业场景新模块 |
