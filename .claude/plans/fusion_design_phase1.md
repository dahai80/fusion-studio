<!--
Callers: FusionStudioApp (injects DesignBridge), DesignView (renders 3-panel layout), DesignChatPanel (chat UI)
Affected API: DesignBridge.sendDesignChat, DesignPreviewView (NSViewRepresentable), AgentBridge.inferStream (called, not modified)
Data schemas: DesignMessage (role/content/timestamp), antArtifact XML parsing state machine
User instruction: "按照你的方案和优先级启动落地" — implementing Fusion Design Phase 1 per claude_design_insight.md plan
-->

# Fusion Design Phase 1 实施计划

## 目标
用户在 Fusion Studio 的 Design 模块输入设计需求 → AI 流式生成 HTML/React 代码 → 右侧 WKWebView 实时预览 → 自动创建 artifact → 支持对话迭代修改

## 实施步骤

### Step 1: 创建 DesignBridge — 流式代码提取 + artifact 解析引擎
- **文件**: `FusionStudio/Modules/Design/DesignBridge.swift` (新建)
- **职责**:
  - ObservableObject，管理设计对话的 AI 流式输出
  - 从流式 token 中解析 `<antArtifact>` XML 标记，提取 type/title/identifier + 代码内容
  - 累积代码 → 触发预览刷新
  - 生成完成后自动创建 artifact (调用 IPCClient)
  - 维护设计对话历史 (messages 数组)
- **关键方法**:
  - `sendDesignChat(_:projectId:)` — 发送设计对话，调用 AgentBridge.inferStream
  - `processStreamToken(_:)` — 解析 antArtifact 标记
  - `refreshPreview()` — 通知 WKWebView 刷新
  - `saveAsArtifact()` — 调用 IPCClient.artifactCreate 保存
- **复用**: AgentBridge.inferStream 已有完整的流式推理管线，DesignBridge 直接调用

### Step 2: 创建 DesignPrompts — 设计 System Prompt 模板
- **文件**: `FusionStudio/Modules/Design/DesignPrompts.swift` (新建)
- **职责**:
  - 定义设计专用 system prompt
  - 包含 Tailwind CSS + Fusion Design Token 规范
  - 指导 LLM 输出 `<antArtifact>` 格式
  - 提供几种模板: 网页设计/组件设计/仪表盘/登录页等

### Step 3: 创建 DesignPreviewView — 沙箱化 WKWebView 实时预览
- **文件**: `FusionStudio/Modules/Design/DesignPreviewView.swift` (新建)
- **职责**:
  - NSViewRepresentable，包装 WKWebView
  - 接收 HTML 字符串，拼接 CDN (Tailwind) + 用户代码
  - 支持增量刷新 (evaluateJavaScript 替换 body)
  - 沙箱化: 限制网络请求、禁用 alert/prompt
  - 支持设备模拟 (mobile/tablet/desktop 宽度切换)
- **注意**: React CDN 在离线模式下不可用，Phase 1 先支持纯 HTML + Tailwind + 内联 JS

### Step 4: 创建 DesignChatPanel — 设计对话界面
- **文件**: `FusionStudio/Modules/Design/DesignChatPanel.swift` (新建)
- **职责**:
  - 左侧对话面板，显示设计对话历史
  - 输入框 + 发送按钮
  - 流式显示 AI 回复 (逐字显示)
  - 显示代码生成状态 (生成中/已完成)
  - 快捷操作按钮: 重新生成/保存 artifact/导出代码

### Step 5: 重构 DesignView — 三栏布局
- **文件**: `FusionStudio/Navigation/ModuleDetailView.swift` (修改 DesignView)
- **职责**:
  - 替换现有简单的 WebViewContainer 为三栏布局:
    - 左: DesignChatPanel (对话, ~300pt)
    - 中: DesignPreviewView (预览, 弹性宽度)
    - 右: 设计信息面板 (artifact 列表, 可选, ~240pt)
  - 使用 HSplitView 实现可调整宽度
  - 保留 fallback: 如果 DesignBridge 未初始化，显示原有 WebViewContainer

### Step 6: FusionStudioApp 注入 DesignBridge
- **文件**: `FusionStudio/FusionStudioApp.swift` (修改)
- **职责**:
  - 添加 `@StateObject private var designBridge = DesignBridge()`
  - 注入 `.environmentObject(designBridge)`
  - 在 onAppear 中调用 `designBridge.setIPCClient(ipcClient)`

## 依赖关系
- Step 1 (DesignBridge) 和 Step 2 (DesignPrompts) 无外部依赖，可并行
- Step 3 (DesignPreviewView) 依赖 Step 1 的输出格式
- Step 4 (DesignChatPanel) 依赖 Step 1 (DesignBridge)
- Step 5 (DesignView 重构) 依赖 Step 3 + Step 4
- Step 6 (App 注入) 依赖 Step 1

## 文件变更清单
| 文件 | 操作 | 行数估算 |
|------|------|----------|
| `Modules/Design/DesignBridge.swift` | 新建 | ~200 |
| `Modules/Design/DesignPrompts.swift` | 新建 | ~80 |
| `Modules/Design/DesignPreviewView.swift` | 新建 | ~180 |
| `Modules/Design/DesignChatPanel.swift` | 新建 | ~250 |
| `Navigation/ModuleDetailView.swift` | 修改 DesignView | ~60 |
| `FusionStudioApp.swift` | 修改 | ~5 |

## 不变的部分
- WebViewContainer.swift 保留不动 (作为 fallback)
- ArtifactsPanel.swift 保持不变 (Design 模块通过 IPCClient 直接调用 artifact API)
- AgentBridge.swift 不修改 (DesignBridge 直接调用其 inferStream)
- IPCClient.swift 不修改 (已有所有需要的 artifact API)
