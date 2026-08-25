# Model Hub — 配置/下载/修改模型 流程 + GUI 草图

## 一、完整流程

```
启动 Fusion Studio
  │
  ├─ 首次? ──→ WelcomeView 6步引导
  │              │
  │              ① intro
  │              ② setup: 端口 + API Key
  │                 └─→ fusion-mlx POST /admin/api/setup-api-key
  │              ③ 硬件检测 (本地 sysctl)
  │              ④ 模型源: HF / HF-Mirror / ModelScope
  │              ⑤ 推荐模型
  │                 ├─ mlx 可达? ──→ fusion-mlx GET /admin/api/hf/recommended
  │                 └─ mlx 不可达 ──→ presets 4个默认 (Qwen3.5-9B / Llama3-8B / DeepSeek-Coder / Qwen2-VL)
  │                 选择+下载 ──→ fusion-mlx POST /admin/api/hf/download
  │                 下载进度   ──→ fusion-mlx GET /admin/api/hf/tasks (轮询)
  │                 保存配置   ──→ FusionConfig.mlxModel + AgentBridge.mlxSetModel (IPC)
  │              ⑥ complete → 进入主界面
  │
  └─ 非首次 ──→ 主界面
                 │
                 ├─ 侧边栏底部: 🟢 Qwen3.5-9B  [⚙️]
                 │    │                    │
                 │    点模型名             点⚙️
                 │    ↓                    ↓
                 │  ModelQuickSheet     ModelHubView
                 │  (快速切换)           (完整管理)
                 │
                 └─ Code/Agent 场景内
                      └─ modelSelector → FusionModelPicker
                           │
                           无模型 → 红色提示 + 引导去下载
                           有模型 → 下拉切换
                           底部   → "管理模型..." → ModelHubView
```

## 二、后台调用映射

```
┌─────────────────────────────────────────────────────────────┐
│                     Fusion Studio GUI                        │
│                                                              │
│  WelcomeView      ModelQuickSheet    ModelHubView   CodeMain │
│      │                  │                 │             │     │
└──────┼──────────────────┼─────────────────┼─────────────┼─────┘
       │                  │                 │             │
       ▼                  ▼                 ▼             ▼
┌──────────────────────────────────────────────────────────────┐
│                      Bridge 层                                │
│                                                               │
│  MlxHTTPClient (HTTP)          AgentBridge (IPC JSON-RPC)    │
│    listModels                    models 缓存                 │
│    getHFRecommended             mlxSetModel                  │
│    searchHFModels               fetchModels                  │
│    startHFDownload                                           │
│    listHFTasks                                               │
│    cancelHFDownload                                          │
│    setupApiKey                                               │
└──────────┬───────────────────────────────────┬───────────────┘
           │                                   │
           ▼                                   ▼
┌─────────────────────┐            ┌────────────────────┐
│   fusion-mlx        │            │   central router   │
│   HTTP :11434       │            │   daemon_server.py │
│                     │            │                    │
│  /admin/api/models  │            │  mlx.set_model     │
│  /admin/api/hf/*    │            │  mlx.start/stop    │
│  /admin/api/login   │            │  env.health_check  │
│  /admin/api/setup-* │            │                    │
└──────────┬──────────┘            └────────────────────┘
           │
           ▼
┌─────────────────────┐
│  HuggingFace        │
│  hf-mirror.com      │
│  (下载模型文件)      │
└─────────────────────┘
```

## 三、GUI 草图

### 3a. 侧边栏底部 — 模型状态栏 (bug21 核心)

```
┌──────────────────────┐
│  📌 Fusion-MLX       │
│  ├ Dashboard         │
│  ├ 模型              │
│  ├ Tuning            │
│  └ Bench             │
│  📌 Fusion-Code      │
│  ├ Code Editor       │
│  └ ...               │
│                      │
├──────────────────────┤ ← 分隔线
│ 🟢 Qwen3.5-9B  [⚙] │ ← 底部固定
└──────────────────────┘
  ↑ 状态点: 🟢已加载 🟡下载中 🔴未加载 ⚫mlx离线
  ↑ 点模型名 → ModelQuickSheet
  ↑ 点⚙ → 跳转 ModelHubView
```

### 3b. ModelQuickSheet — 快速切换浮层

```
┌─────────────────────────────┐
│  切换模型              [管理]│
├─────────────────────────────┤
│  ● Qwen3.5-9B  (当前) 5.2G │
│  ○ Llama3-8B          4.8G │
│  ○ DeepSeek-Coder     3.9G │
├─────────────────────────────┤
│  [+ 下载更多模型...]        │──→ 弹出 DownloadModelView
└─────────────────────────────┘

操作 → 调用:
  点击切换 → AgentBridge.mlxSetModel (IPC)
  下载更多 → MlxHTTPClient.startHFDownload (HTTP)
  管理     → 导航到 ModelHubView
```

### 3c. ModelHubView — 完整管理 (已有，需增强)

```
┌──────────────┬──────────────────────────────────┐
│ 🔍 搜索模型   │  Qwen3.5 9B                      │
│              │  ─────────────                    │
│ [全部][Qwen] │  Family: Qwen   Params: 9B       │
│ [Llama]      │  Quant: 4bit    Format: MLX      │
│ [DeepSeek]   │  Size: 5.2 GB                     │
│ [Phi]        │                                   │
│              │  ┌─────────┐ ┌──────┐ ┌──────┐   │
│ ── 已加载 ── │  │ ▶ 激活  │ │ 🗑 删除│ │ ⬇ 下载│   │
│ ● Qwen3.5-9B│  └─────────┘ └──────┘ └──────┘   │
│ ● Llama3-8B │                                   │
│              │  ── 基本信息 ──                    │
│ ── 推荐 ──   │  ID: qwen3.5-9b-4bit             │
│ ○ DeepSeek   │  Path: ~/.fusion-mlx/models/...  │
│ ○ Qwen2-VL  │  HF Repo: mlx-community/...       │
│              │                                   │
│ ── 下载中 ── │  ── 下载进度 ──                    │
│ ⏳ Phi3  45% │  ████████░░░ 45%                  │
└──────────────┴──────────────────────────────────┘
  ↑ 左列                    右列详情 ↑

操作 → 调用:
  列出已加载  → MlxHTTPClient.listModels (HTTP)
  推荐模型    → MlxHTTPClient.getHFRecommended (HTTP)
  搜索        → MlxHTTPClient.searchHFModels (HTTP)
  下载        → MlxHTTPClient.startHFDownload (HTTP)
  进度轮询    → MlxHTTPClient.listHFTasks (HTTP, 3s)
  取消下载    → MlxHTTPClient.cancelHFDownload (HTTP)
  激活        → AgentBridge.mlxSetModel (IPC)
  删除        → MlxHTTPClient DELETE /admin/api/models/{id} (待实现)
```

### 3d. Code 场景 — 对话框内模型选择器

```
┌─────────────────────────────────────────────┐
│                                             │
│         Good morning, user                  │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ How can I help you today?           │    │  ← 3行高,居中
│  │                                     │    │
│  ├─────────────────────────────────────┤    │
│  │ [+]   Qwen3.5-9B ▾  Effort ▾  🎤 🎙│    │  ← 底部工具栏
│  └─────────────────────────────────────┘    │
│                                             │
│  [Write] [Learn] [Code] [Life] [Choice]    │
│                                             │
└─────────────────────────────────────────────┘
         ↑ maxW:680 居中

  模型选择器 → FusionModelPicker
    无模型 → 红点 + "选择模型" 提示
    有模型 → 下拉列表 + 底部"管理模型..."
  🎤 micButton  → 弹出音量/录音设置
  🎙 voiceButton → 语音模式切换
```

### 3e. WelcomeView 推荐步骤 — mlx离线fallback

```
┌─────────────────────────────────────┐
│  推荐配置                            │
│                                     │
│  [Agent] [编程] [对话]  ← 用例选择   │
│                                     │
│  ┌─ 配置三档模型 ──────────────┐     │
│  │ 小模型  [Qwen3.5-9B     ▾] │     │
│  │ 代码模型[DeepSeek-Coder ▾] │     │
│  │ 复杂模型[Llama3-8B      ▾] │     │
│  └─────────────────────────────┘     │
│                                     │
│  ┌─ 推荐下载 ─────────────────┐     │
│  │ ☑ Qwen3.5-9B   5.2G ⬇    │     │  ← mlx在线: HF API
│  │ ☐ Llama3-8B     4.8G      │     │
│  │ ☐ DeepSeek-Coder 3.9G     │     │
│  │   [全选]    [下载 (1)]     │     │
│  └─────────────────────────────┘     │
│                                     │
│  ⚠️ fusion-mlx 未启动,推荐为默认列表 │  ← mlx离线: presets
│     启动后可下载更多模型              │
└─────────────────────────────────────┘
```

## 四、API 调用速查

| 步骤 | GUI | → Bridge | → 后台 |
|------|-----|----------|--------|
| 首次鉴权 | WelcomeView setup步 | MlxHTTPClient.setupApiKey | fusion-mlx POST /admin/api/setup-api-key |
| 查本地模型 | WelcomeView/ModelHub | MlxHTTPClient.listModels | fusion-mlx GET /admin/api/models |
| 获取推荐 | WelcomeView/ModelHub | MlxHTTPClient.getHFRecommended | fusion-mlx GET /admin/api/hf/recommended |
| 搜索模型 | ModelHub | MlxHTTPClient.searchHFModels | fusion-mlx GET /admin/api/hf/search |
| 下载模型 | WelcomeView/ModelHub | MlxHTTPClient.startHFDownload | fusion-mlx POST /admin/api/hf/download |
| 下载进度 | ModelHub | MlxHTTPClient.listHFTasks | fusion-mlx GET /admin/api/hf/tasks |
| 取消下载 | ModelHub | MlxHTTPClient.cancelHFDownload | fusion-mlx POST /admin/api/hf/cancel/{id} |
| 切换模型 | QuickSheet/Code | AgentBridge.mlxSetModel | 中央路由 daemon_server.py IPC mlx.set_model |
| 删除模型 | ModelHub | MlxHTTPClient (DELETE) | fusion-mlx DELETE /admin/api/models/{id} |
