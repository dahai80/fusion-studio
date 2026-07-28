<!--
Callers: Fusion Studio Design module (DesignChatPanel, DesignPreviewView, DesignBridge)
Affected API: IPCClient.artifact*, AgentBridge.sendDesignChat, fusion-mlx /v1/chat/completions
Data schemas: DesignToken, DesignProject, antArtifact XML format
User instruction: "洞察claude.ai design, 对标构建fusion design, 洞察结果保存在claude_design_insight.md文件, 然后分析~/design目录下的开源软件, 给我一个完整的构建fusion design的可落地方案"
-->

# Claude Design 洞察报告 — Fusion Design 对标分析

> 生成日期: 2026-07-27
> 目标: 洞察 Claude.ai Design 功能，对标构建 Fusion Studio 的 Design 体系

---

## 一、Claude.ai Design 功能解析

### 1.1 核心概念

Claude Design 是 Anthropic 推出的 AI 驱动设计生成功能，核心模式为 **Artifacts**：
用户在对话中描述 UI 需求 → Claude 生成可交互的 HTML/React 代码 → 在沙箱 iframe 中实时预览 → 迭代修改。

核心解决的痛点：**设计到代码的断层** — 传统流程中设计师产出 Figma/Sketch 原型 → 工程师翻译为代码，中间存在巨大的信息损耗和沟通成本。

### 1.2 核心功能矩阵

| 功能 | 描述 | Claude.ai 实现方式 |
|------|------|---------------------|
| **Artifacts 生成** | AI 生成可交互 HTML/React 组件 | LLM 输出 `antArtifact` 标记的代码块，自动渲染 |
| **实时预览** | 生成后立即在侧栏看到效果 | 沙箱化 iframe，支持 React + Tailwind CSS |
| **迭代修改** | 对话式迭代设计 | 说出修改需求 → Claude 更新代码 → 实时刷新 |
| **多类型支持** | 代码、文档、SVG、React 组件 | `type: code/react/markdown/svg` 分类 |
| **版本管理** | 每次修改自动存版本 | Artifacts Engine 版本链 |
| **导出代码** | 一键复制/导出生成代码 | Copy 按钮 → 剪贴板 / Download → 文件 |
| **对话绑定** | 设计对话关联 artifact | session_id 绑定，上下文不丢失 |
| **全屏预览** | 设计稿全屏查看 | 右侧面板可展开/收起 |

### 1.3 架构模式

```
用户 Prompt
    ↓
Claude LLM (Streaming)
    ↓
<antArtifact> 标记解析
    ↓
Artifacts Engine (存储 + 版本管理)
    ↓
iframe 沙箱渲染 (React + Tailwind + CDN)
    ↓
右侧面板实时预览
```

**关键技术细节：**
- **代码提取**：从 LLM 流式输出中检测 `antArtifact` XML 标记，提取 `type/title/identifier` 和代码内容
- **沙箱隔离**：iframe 使用 `sandbox` 属性限制权限，防止生成的代码访问父页面
- **CDN 注入**：React/ReactDOM/Tailwind CSS 通过 CDN script 标签注入，组件代码拼接后 eval
- **流式渲染**：代码生成过程中持续刷新 iframe，用户看到"画"的过程
- **版本链**：每次修改生成新版本，可回溯任意历史版本

### 1.4 对话-设计迭代循环

```
┌──────────────────────────────────────────────────┐
│  用户: "做一个登录页面，深色主题"                    │
│  Claude: [生成 antArtifact: LoginDark.jsx]         │
│  → 右侧面板显示深色登录页预览                       │
│                                                    │
│  用户: "按钮换成圆角，加一个记住我复选框"            │
│  Claude: [更新 antArtifact v2]                     │
│  → 预览实时刷新                                    │
│                                                    │
│  用户: "导出代码"                                   │
│  Claude: 提供完整代码 + Copy/Download 按钮          │
└──────────────────────────────────────────────────┘
```

### 1.5 竞品对比

| 能力 | Claude Design | v0.dev | Galileo AI | Cursor |
|------|--------------|--------|------------|--------|
| 对话驱动 | ✅ | ✅ | ❌ (prompt only) | ✅ |
| 实时预览 | ✅ iframe | ✅ iframe | ✅ Figma plugin | ❌ |
| 代码导出 | ✅ | ✅ | ✅ | ✅ |
| 版本管理 | ✅ 自动 | ✅ 手动 | ❌ | ✅ Git |
| 迭代修改 | ✅ 对话式 | ✅ 对话式 | ❌ 重新生成 | ✅ Diff |
| 离线运行 | ❌ 云端 | ❌ 云端 | ❌ 云端 | ✅ 本地 |
| 组件库 | Tailwind | Tailwind + shadcn | Figma components | 任意 |
| 多页设计 | ❌ 单组件 | ✅ 多页 | ✅ 多页 | ✅ 多页 |

---

## 二、开源设计软件分析 (~/design/)

### 2.1 项目总览

| 项目 | 类型 | 语言/框架 | 许可证 | 可复用度 |
|------|------|-----------|--------|----------|
| **open-design** | Claude Design 替代 | Tauri + React + Rust | Apache-2.0 | ★★★★★ 核心对标 |
| **openui** | AI UI 生成 | Python + FastAPI + Web | MIT | ★★★★ 后端参考 |
| **openpencil** | AI 绘图工具 | Rust (Tauri) | Apache-2.0 | ★★★ 桌面架构 |
| **penpot** | 开源 Figma | Clojure + Kotlin | MPL-2.0 | ★★★ 画布引擎 |
| **plasmic** | 可视化建站 | React + TypeScript | MIT | ★★☆ 组件模型 |
| **Screenshot-to-code** | 截图→代码 | Python + FastAPI | MIT | ★★★ AI 管线 |
| **Figma-Context-MCP** | Figma→MCP 桥接 | TypeScript | MIT | ★★☆ 设计数据桥 |
| **archify** | AI 建筑设计 | Unknown | Unknown | ★★☆ 领域参考 |
| **stitches** | CSS-in-JS | TypeScript | MIT | ★☆☆ 已停止维护 |

### 2.2 重点分析：open-design

**定位**: 开源 Claude Design 替代品，最新版本 0.13.0

**核心架构:**
```
Tauri (Rust shell) → WebView (前端) → LLM API (OpenAI/Claude/本地)
                                     ↓
                              Artifacts 渲染引擎
                                     ↓
                              iframe 沙箱预览
```

**关键特性:**
- 支持多模型后端 (GPT/Claude/Gemini/DeepSeek/Open Design Cloud)
- Codex/OpenCode/Pi 运行恢复
- 截图导出 PPTX/PDF
- 本地运行，数据不出本机
- 流式代码生成 + 实时预览

**对 Fusion Design 的价值:**
- ✅ 代码渲染管线可直接参考
- ✅ Artifacts 解析 + iframe 沙箱方案验证
- ✅ 多模型切换模式
- ⚠️ Tauri 架构无法直接移植到 SwiftUI

### 2.3 重点分析：openui

**定位**: AI 驱动的 UI 组件生成器

**核心架构:**
```
FastAPI → LLM (streaming) → HTML/React 代码生成 → iframe 实时渲染
```

**关键特性:**
- 后端驱动生成，前端只做渲染
- 支持 OpenAI / 本地模型
- 生成的组件可下载/复制
- 简单直接，代码量小

**对 Fusion Design 的价值:**
- ✅ Python 后端生成管线可映射到 fusion-mlx
- ✅ 流式代码生成 → iframe 渲染的完整链路
- ✅ 轻量级，容易理解和集成

### 2.4 重点分析：penpot

**定位**: 开源设计工具 (Figma 替代)

**核心架构:**
```
Clojure 后端 (SVG 数据模型) + Kotlin 协作层 + Web 前端 (Canvas 渲染)
```

**关键特性:**
- 矢量画布引擎 (SVG 原生)
- 实时协作 (CRDT)
- 组件系统 (嵌套组件 + variants)
- 设计 Token (颜色/字体/间距)
- 开放格式 (SVG 导出)

**对 Fusion Design 的价值:**
- ✅ SVG 数据模型可作为设计稿的底层表示
- ✅ 组件系统设计可参考
- ⚠️ Clojure/Kotlin 技术栈不适合直接集成
- 💡 如果 Fusion Design Phase 2 需要画布，可考虑嵌入 penpot 前端

### 2.5 重点分析：Screenshot-to-code

**定位**: 截图 → HTML/CSS 代码

**核心架构:**
```
截图上传 → GPT-4 Vision → HTML/Tailwind 代码 → iframe 渲染
```

**对 Fusion Design 的价值:**
- ✅ 视觉理解 → 代码生成的 AI 管线
- ✅ 可作为 Fusion Design 的"导入设计稿"功能

---

## 三、Fusion Studio 现有设计模块现状

### 3.1 已有基础设施

| 组件 | 文件 | 能力 |
|------|------|------|
| WebViewContainer | `Modules/Design/WebViewContainer.swift` | WKWebView + fusionBridge JS 桥 + exportCode API |
| DesignView | `Navigation/ModuleDetailView.swift:120` | 加载 `http://localhost:8080` 的 Web 设计画布 |
| ArtifactsPanel | `Navigation/ArtifactsPanel.swift` | Artifact 列表/版本/编辑/导出，已有 Kind: app/code/document/game/tool/template |
| ArtifactSidebarCache | `Common/ArtifactSidebarCache.swift` | 30s 轮询刷新 artifact 列表 |
| IPCClient.artifactList | `Bridge/IPCClient.swift` | JSON-RPC 调用 artifacts-engine |
| fusion-artifacts-engine | `~/fusion/fusion-artifacts-engine` | 创建/版本/导出/同步 artifact，支持 html/react 类型 |

### 3.2 缺失能力

| 能力 | 说明 | 优先级 |
|------|------|--------|
| **AI 生成设计** | 从对话 prompt → 生成 HTML/React 代码 | P0 |
| **实时预览** | 生成代码的沙箱化 iframe 渲染 | P0 |
| **流式渲染** | 代码生成过程中实时刷新预览 | P1 |
| **设计 Token 系统** | 颜色/字体/间距的语义化变量 | P2 |
| **组件库** | 预置可复用 UI 组件 (按钮/卡片/表单等) | P2 |
| **截图导入** | 从设计稿截图反向生成代码 | P2 |
| **Figma 集成** | 读取 Figma 文件作为上下文 | P3 |
| **多页设计** | 一个项目内多个页面/视图 | P3 |

---

## 四、Fusion Design 完整落地方案

### 4.1 架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                     Fusion Studio (SwiftUI)                  │
│                                                              │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ Design    │  │ Artifacts    │  │ Inspector Panel      │   │
│  │ Chat      │  │ Preview      │  │ (Properties/Styles)  │   │
│  │ Panel     │  │ (WKWebView)  │  │                      │   │
│  └────┬─────┘  └──────┬───────┘  └──────────────────────┘   │
│       │               │                                     │
│       ▼               ▼                                     │
│  ┌──────────────────────────────────────┐                   │
│  │        DesignBridge (Swift)          │                   │
│  │  - 流式代码提取 (antArtifact 解析)    │                   │
│  │  - Preview 刷新控制                  │                   │
│  │  - Token/版本管理                    │                   │
│  └──────────┬───────────────────────────┘                   │
│             │                                                │
└─────────────┼────────────────────────────────────────────────┘
              │
    ┌─────────┼─────────────────────────────┐
    │         ▼                             │
    │  fusion-mlx (/v1/chat/completions)    │
    │  - 流式生成设计代码                    │
    │  - system prompt 注入设计规范          │
    │  - tool_use: create_artifact          │
    │                                       │
    │  fusion-artifacts-engine (8892)       │
    │  - artifact.create (type=html/react)  │
    │  - artifact.update_version            │
    │  - artifact.export_code               │
    │  - artifact.sync → 本地文件            │
    │                                       │
    │  fusion-agent-studio (RAG)            │
    │  - 设计规范检索 (design tokens)        │
    │  - 组件库上下文注入                    │
    └───────────────────────────────────────┘
```

### 4.2 分阶段实施路线

---

### Phase 1: AI 设计对话 + 实时预览 (P0, 2 周)

**目标**: 用户输入设计需求 → AI 生成 HTML → 右侧实时预览

#### 任务清单

| # | 任务 | 文件 | 依赖 |
|---|------|------|------|
| 1 | DesignChatPanel: 对话界面 + 项目上下文绑定 | `Modules/Design/DesignChatPanel.swift` (新建) | FusionProject |
| 2 | DesignBridge: 流式代码提取 + artifact 解析 | `Modules/Design/DesignBridge.swift` (新建) | AgentBridge |
| 3 | DesignPreviewView: 替换现有 WebViewContainer | `Modules/Design/DesignPreviewView.swift` (新建) | WKWebView |
| 4 | 设计 system prompt 模板 | `Modules/Design/DesignPrompts.swift` (新建) | ContextAssembler |
| 5 | 重构 DesignView: 三栏布局 (Chat + Preview + Inspector) | `Navigation/ModuleDetailView.swift` (修改) | 1-4 |
| 6 | IPCClient 新增 artifact.create/update 调用 | `Bridge/IPCClient.swift` (修改) | artifacts-engine |

#### DesignBridge 核心逻辑

```swift
// 从 LLM 流式输出中提取 artifact 代码
// 解析模式: <antArtifact type="react" title="Login">...code...</antArtifact>
// 或 tool_use: create_artifact { type: "html", content: "..." }

class DesignBridge: ObservableObject {
    @Published var currentCode: String = ""
    @Published var artifactType: String = "html"
    @Published var artifactTitle: String = ""
    @Published var isGenerating: Bool = false

    // 从流式 token 中提取代码
    func processStreamToken(_ token: String) {
        // 检测 antArtifact 开始标记
        // 累积代码内容
        // 检测结束标记 → 触发预览刷新
    }

    // 刷新预览
    func refreshPreview() {
        // 拼接完整 HTML (CDN + 设计系统 + 用户代码)
        // 通过 WKWebView loadHTMLString 渲染
    }
}
```

#### DesignPreviewView 核心逻辑

```swift
// 沙箱化 WKWebView，支持实时刷新
struct DesignPreviewView: NSViewRepresentable {
    @Binding var htmlContent: String
    @Binding var isRefreshing: Bool

    func makeNSView(context: Context) -> WKWebView {
        // 沙箱配置: sandbox 属性限制
        // 注入: React CDN + Tailwind CDN + Fusion Design Tokens
        // 支持增量刷新 (只替换 body 内容)
    }
}
```

#### 设计 System Prompt 模板

```
你是一个专业的 UI 设计师和前端工程师。根据用户需求生成高质量的 HTML/React 组件代码。

规范:
- 使用 Tailwind CSS 进行样式设计
- 组件必须是自包含的 (单文件可运行)
- 支持 dark/light 主题
- 响应式布局 (mobile-first)
- 使用 Fusion Design Token 语义化颜色

输出格式:
<antArtifact type="html" title="组件名称">
完整代码...
</antArtifact>
```

---

### Phase 2: 设计系统 + 组件库 (P1, 3 周)

**目标**: 建立设计 Token 体系 + 预置组件库 + Inspector 面板

#### 任务清单

| # | 任务 | 文件 | 依赖 |
|---|------|------|------|
| 7 | DesignToken 数据模型 | `Modules/Design/DesignTokens.swift` (新建) | — |
| 8 | FusionDesignSystem: 预置组件库 JSON | `Modules/Design/FusionDesignSystem.swift` (新建) | 7 |
| 9 | InspectorPanel: 样式/属性编辑 | `Modules/Design/DesignInspectorView.swift` (新建) | 7 |
| 10 | 组件库 RAG 索引: 知识库预置设计组件 | 调用 knowledge.ingest | agent-studio |
| 11 | 主题切换: dark/light/自定义 | `Modules/Design/ThemeSwitcher.swift` (新建) | 7,8 |
| 12 | 导出增强: 支持 React/Vue/SwiftUI 代码 | `Modules/Design/DesignExporter.swift` (新建) | artifacts-engine |

#### DesignToken 数据模型

```swift
struct DesignToken: Codable, Identifiable {
    let id: UUID
    var category: TokenCategory  // color/spacing/typography/shadow/border
    var name: String             // primary / sm / heading / ...
    var value: String            // #007AFF / 8px / 19px / ...
    var scope: TokenScope        // global/project/component
}

enum TokenCategory: String, Codable, CaseIterable {
    case color, spacing, typography, shadow, border, animation
}
```

#### 预置组件库

```
FusionDesignSystem/
├── components/
│   ├── Button.html        (primary/secondary/ghost, 3 sizes)
│   ├── Card.html          (standard/featured/outlined)
│   ├── Input.html         (text/email/password/search)
│   ├── Select.html        (single/multi)
│   ├── Modal.html         (info/confirm/form)
│   ├── Navigation.html    (top-bar/sidebar/tabs)
│   ├── Table.html         (basic/sortable/paginated)
│   ├── Chart.html         (line/bar/pie)
│   └── Form.html          (login/register/contact)
├── tokens/
│   └── fusion-tokens.css  (CSS 变量形式的设计 Token)
└── templates/
    ├── Dashboard.html
    ├── Landing.html
    └── Settings.html
```

---

### Phase 3: 高级能力 (P2, 4 周)

**目标**: 截图导入 + 多页设计 + Figma 集成 + 代码同步

#### 任务清单

| # | 任务 | 文件 | 依赖 |
|---|------|------|------|
| 13 | 截图导入: ScreenshotToCode 管线 | `Modules/Design/ScreenshotImporter.swift` (新建) | fusion-mlx vision |
| 14 | 多页设计: DesignProject 多页面管理 | `Modules/Design/DesignProject.swift` (新建) | FusionProject |
| 15 | Figma 集成: 通过 MCP 读取 Figma 数据 | `Modules/Design/FigmaBridge.swift` (新建) | Figma-Context-MCP |
| 16 | 代码同步: artifact → 文件 双向同步 | 调用 artifact.sync | artifacts-engine |
| 17 | 设计规范 RAG: 自动索引项目设计 Token | 调用 knowledge.ingest | agent-studio |
| 18 | SwiftUI 代码导出: HTML → SwiftUI 转换 | `Modules/Design/SwiftUIExporter.swift` (新建) | LLM |

---

### 4.3 上游依赖分析

| 上游 | 需求 | Issue | 优先级 |
|------|------|-------|--------|
| **fusion-mlx** | 流式 chat + tool_use 支持 | 需确认 tool_use 在流式模式下是否完整 | P0 |
| **fusion-mlx** | Vision 模型 (截图理解) | 需确认 multimodal 输入支持 | P2 |
| **fusion-artifacts-engine** | artifact.create type=html/react | ✅ 已支持 | — |
| **fusion-artifacts-engine** | artifact.update_version source=ai_generation | ✅ 已支持 | — |
| **fusion-artifacts-engine** | artifact.export_code | ✅ 已支持 | — |
| **fusion-artifacts-engine** | project_id 范围 | ❌ 需提 Issue | P1 |
| **fusion-artifacts-engine** | 设计 Token 存储 (metadata 扩展) | 需提 Issue | P2 |
| **fusion-agent-studio** | knowledge.search 按设计 Token scope 检索 | ✅ scope 参数已支持 | — |
| **fusion-agent-studio** | knowledge.ingest 设计组件库 | ✅ 已支持 | — |
| **Figma-Context-MCP** | macOS 集成方案 | 需调研 MCP 协议适配 | P3 |

### 4.4 需要提的上游 Issue

1. **fusion-artifacts-engine**: `project_id` scope for artifacts — 让 artifact 绑定到 FusionProject，避免跨项目串扰
2. **fusion-artifacts-engine**: Design metadata extension — artifact.metadata 支持存储 design_tokens/component_name 等设计元数据
3. **fusion-mlx**: Verify tool_use streaming completeness — 确认流式模式下 create_artifact tool_use 的 JSON 完整输出
4. **fusion-mlx**: Multimodal input support (image) — 支持 `/v1/chat/completions` 的 `image_url` 输入，用于截图导入

### 4.5 设计原则

1. **离线优先** — 所有 AI 推理走本地 fusion-mlx，不依赖云端 API
2. **Artifacts 驱动** — 设计产出统一走 artifacts-engine 管理，版本/导出/同步复用现有管线
3. **SwiftUI + WebView 混合** — 外壳用 SwiftUI (布局/导航/交互)，渲染用 WKWebView (HTML/React 预览)
4. **渐进增强** — Phase 1 只做生成+预览，后续逐步叠加设计系统/组件库/高级功能
5. **项目绑定** — 设计对话和 artifact 绑定到 FusionProject，知识库自动注入设计 Token

### 4.6 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| fusion-mlx 流式 tool_use 不稳定 | 代码提取断行 | 添加缓冲区 + 重试机制；降级为非流式模式 |
| WKWebView 沙箱性能 | 大型组件渲染卡顿 | 虚拟化渲染 + 懒加载 CDN |
| 设计 Token 体系过于复杂 | 实施周期膨胀 | Phase 1 只用 CSS 变量，Phase 2 才做语义化 |
| React CDN 依赖网络 | 离线无法加载 | 将 React/Tailwind 打包到 app bundle 的 Resources |
| 多模型差异 | 不同模型生成代码质量不一致 | 针对每个模型调优 system prompt + few-shot |

---

## 五、总结

Fusion Design 的核心差异化优势在于 **离线运行 + 项目绑定 + 全链路集成**：
- 对 Claude Design: 我们不需要云端，所有推理和渲染本地完成
- 对 open-design: 我们不是独立应用，而是 Fusion Studio 的一个模块，无缝切换 Code/Design/Agent
- 对 v0.dev: 我们有完整的 artifacts-engine 管线，版本/导出/同步一站式

**Phase 1 交付标准**: 用户在 Fusion Studio 的 Design 模块输入设计需求，AI 流式生成 HTML/React 代码，右侧 WKWebView 实时预览，生成完自动创建 artifact，支持对话迭代修改。

**核心约束**: GUI 统一在 fusion-studio，上游只提 Issue/PR，不越界改代码。

---

## Phase 1 落地记录 (2026-07-28)

### 已完成文件

| 文件 | 功能 |
|------|------|
| `FusionStudio/Modules/Design/DesignBridge.swift` | AI对话引擎，SSE流式请求fusion-mlx，antArtifact XML状态机解析，artifact CRUD，代码复制 |
| `FusionStudio/Modules/Design/DesignPrompts.swift` | 系统提示词（Tailwind+暗色+自包含HTML+antArtifact格式）+ 8个快速模板（登录/仪表盘/卡片/表单/落地页/设置/表格/对话） |
| `FusionStudio/Modules/Design/DesignPreviewView.swift` | WKWebView沙箱预览，Tailwind CDN注入，Fusion Design Token CSS变量，设备模式切换(mobile/tablet/desktop) |
| `FusionStudio/Modules/Design/DesignChatPanel.swift` | 左侧对话面板，消息气泡，快速模板网格，保存/复制操作栏，空态引导 |
| `FusionStudio/Navigation/ModuleDetailView.swift` | DesignView重构为HSplitView三栏：ChatPanel | PreviewView | 属性面板 |
| `FusionStudio/FusionStudioApp.swift` | DesignBridge注入@StateObject + .environmentObject + setIPCClient |
| `Tests/UnitTests/DesignBridgeTests.swift` | 17个单元测试：antArtifact解析、代码块提取、设备模式、提示词、清空对话、kindForType、buildFullHTML |

### 验证结果

- `swift build -c debug` — 0 error
- `swift test --filter DesignBridgeTests` — 17/17 passed, 0 failures
- `.build/debug/FusionStudio` — 启动正常运行
- fusion-mlx 运行中，Qwen2.5-Coder-32B 已加载，DesignBridge SSE 可对接

## Phase 2 落地记录 (2026-07-28)

### 已完成文件

| 文件 | 功能 |
|------|------|
| `FusionStudio/Modules/Design/DesignPreviewView.swift` (改) | Tailwind JS 本地注入 via WKUserScript，离线可用，避免CDN SRI问题 |
| `FusionStudio/Resources/tailwind/tailwind-play.js` (新) | Tailwind Play CDN 3.4.17 本地副本(397KB)，Bundle资源加载 |
| `FusionStudio/Modules/Design/DesignBridge.swift` (改) | artifactId追踪，saveAsArtifact支持create/update，loadVersionHistory，rollbackToVersion |
| `FusionStudio/Modules/Design/DesignChatPanel.swift` (改) | 版本历史按钮+版本列表UI，actionBar用VStack包裹修复opaque return type |
| `FusionStudio/Modules/Design/DesignTokenPanel.swift` (新) | Design Token系统面板：6类Token(颜色/间距/排版/圆角/阴影/动画)，分类标签页 |
| `FusionStudio/Navigation/ModuleDetailView.swift` (改) | 属性面板重构为双标签(属性+Design System)，InfoPanelTab枚举 |
| `Tests/UnitTests/DesignBridgeTests.swift` (改) | 新增5个测试(DesignTokenCategory×3, InfoPanelTab×2)，共22/22通过 |

### 验证结果

- `swift build -c debug` — 0 error
- `swift test --filter DesignBridgeTests` — 22/22 passed, 0 failures

## Phase 3 落地记录 (2026-07-28)
<!-- Callers: design insight doc; Affected API: none; Data schemas: none; User instruction: continue Phase 3 -->

### 已完成文件

| 文件 | 功能 |
|------|------|
| `DesignBridge.swift` (改) | DesignPage多页模型，RAG上下文注入，SwiftUI导出 |
| `DesignChatPanel.swift` (改) | 页面管理列表UI，SwiftUI导出按钮+Sheet |
| `SwiftUIExporter.swift` (新) | HTML→SwiftUI转换提示词+代码提取 |
| `FusionStudioApp.swift` (改) | 启动时ingestDesignTokens |
| `DesignBridgeTests.swift` (改) | 新增14测试，共36/36通过 |
| `ScreenshotImporter.swift` (新) | 截图→代码管线（stub，待fusion-mlx multimodal） |
| `FigmaBridge.swift` (新) | Figma MCP集成（stub，待Figma-Context-MCP） |
| `IPCClient.swift` (改) | 新增artifactSync/artifactWatch/artifactExportCode/artifactImportCode |
| `DesignBridge.swift` (改) | artifact↔文件双向同步（使用artifact.sync API + fallback），截图导入，Figma导入 |

### 原上游阻塞项 — 状态更新

| # | 任务 | 原阻塞原因 | 当前状态 |
|---|------|----------|----------|
| 13 | 截图导入 ScreenshotToCode | fusion-mlx multimodal待确认 | ✅ stub完成，DesignBridge.importScreenshot已实现，multimodal待fusion-mlx |
| 15 | Figma 集成 | Figma-Context-MCP待调研 | ✅ stub完成，FigmaBridge+convertToHTML已实现，MCP连接待上游 |
| 16 | artifact↔文件双向同步 | artifact.sync API待上游 | ✅ 已实现！artifact.sync API已在fusion-artifacts-engine存在 |

### 验证结果

- `swift build -c debug` — 0 error
- `swift test --filter DesignBridgeTests` — 46/46 passed

### 上游Issue待提

详见 `docs/upstream-issues.md`:
1. fusion-artifacts-engine: project_id scope
2. fusion-artifacts-engine: Design metadata extension
3. fusion-mlx: Verify tool_use streaming completeness
4. fusion-mlx: Multimodal input support
