# Claude Projects 洞察报告 — Fusion Studio 对标分析

> 生成日期: 2026-07-27
> 目标: 洞察 Claude.ai Projects 功能，对标构建 Fusion Studio 的 Projects 体系

---

## 一、Claude.ai Projects 功能解析

### 1.1 核心概念

Claude Projects 是 Anthropic 于 2024 年推出的项目级 AI 上下文管理功能，解决的核心问题是：
**在长周期多轮对话中，AI 缺乏持久的项目级上下文，每次新对话都从零开始。**

### 1.2 核心功能矩阵

| 功能 | 描述 | Claude.ai 实现 |
|------|------|----------------|
| **项目创建** | 创建独立的项目空间 | Sidebar 左侧 Projects 入口，支持命名+描述 |
| **知识库 (Knowledge)** | 上传文件作为项目永久上下文 | 支持上传 PDF/代码/文档，自动解析为上下文注入 system prompt |
| **自定义指令 (Custom Instructions)** | 项目级 system prompt | 每个项目可设置专属指令，每次对话自动注入 |
| **项目对话** | 对话绑定项目上下文 | 在项目内开启的对话自动携带知识库+自定义指令 |
| **对话历史** | 项目内对话持久化 | 对话列表按项目分组，支持恢复历史对话 |
| **文件管理** | 知识库文件增删改 | 支持拖拽上传、删除、更新知识库文件 |
| **Token 预算** | 知识库 token 用量可视化 | 显示知识库已用/总量 token 统计 |
| **与 Claude Code 集成** | Projects → Code 的上下文传递 | Claude Code 读取项目 CLAUDE.md 作为等效知识库 |

### 1.3 架构模式

```
┌─────────────────────────────────────────────┐
│                Claude.ai Web                │
├─────────────┬───────────────────────────────┤
│  Project    │  Conversation                 │
│  ┌────────┐ │  ┌─────────────────────────┐  │
│  │Knowledge│ │  │ Messages + System Prompt │  │
│  │ (files) │ │  │ = Custom Instructions   │  │
│  ├────────┤ │  │ + Knowledge Summary     │  │
│  │Custom  │ │  │ + User Messages          │  │
│  │Instruc.│ │  └─────────────────────────┘  │
│  ├────────┤ │                                │
│  │Chats   │ │                                │
│  │(history)│ │                                │
│  └────────┘ │                                │
└─────────────┴───────────────────────────────┘
         │
         ▼
    Anthropic API (cloud)
    - Knowledge → RAG / full injection
    - Custom Instructions → system prepend
    - Sessions → server-side persistence
```

### 1.4 关键设计决策

1. **知识库注入策略**: 小文件直接注入 system prompt，大文件用 RAG 检索
2. **项目隔离**: 每个项目独立的知识库和自定义指令，互不干扰
3. **对话继承**: 项目内对话自动继承项目上下文，无需手动指定
4. **Token 预算管理**: 知识库有 token 上限，用户需要权衡内容量

---

## 二、Fusion Studio 现状分析

### 2.1 已有能力

| 能力 | 当前状态 | 文件 |
|------|----------|------|
| 项目列表 | ✅ `ProjectsPanel` — 列表/搜索/排序/新建 | `Navigation/ProjectsPanel.swift` |
| 项目模型 | ✅ `RecentProject` — name/path/gitURL/lastOpened | `Modules/Code/CodeEditorView.swift:99` |
| 项目工作区 | ✅ `ProjectWorkspace` — projectRoot/files/recentProjects | `Modules/Code/CodeEditorView.swift:117` |
| 文件树浏览 | ✅ `CodeFile` 目录树加载 | `Modules/Code/CodeEditorView.swift` |
| Git 管理 | ✅ `GitManager` — branch/commit/stash/diff/push/pull | `Modules/Code/GitManager.swift` |
| Monaco 编辑器 | ✅ `MonacoEditorView` — 代码编辑+diff | `Modules/Code/MonacoEditorView.swift` |
| PTY 终端 | ✅ `PTYTerminalView` — 真实 shell | `Modules/Code/PTYTerminalView.swift` |
| Agent 对话 | ✅ `AgentBridge.infer()` — 非流式推理 | `System/AgentBridge.swift` |
| Agent 流式 | ✅ `AgentBridge.inferStream()` — SSE token 流 | `System/AgentBridge.swift` |
| Artifacts 管理 | ✅ `ArtifactsPanel` — 产物面板 | `Navigation/ArtifactsPanel.swift` |
| IPC 通信 | ✅ `IPCClient` — JSON-RPC 2.0 | `Bridge/IPCClient.swift` |

### 2.2 缺失能力 (对比 Claude Projects)

| 缺失功能 | 优先级 | 说明 |
|----------|--------|------|
| **项目级知识库** | P0 | 无知识库上传/管理/注入机制 |
| **项目级自定义指令** | P0 | 无项目专属 system prompt 配置 |
| **项目级对话历史** | P0 | 对话不绑定项目，刷新即丢失 |
| **知识库 RAG 检索** | P1 | 无向量检索能力 |
| **CLAUDE.md 自动读取** | P1 | 不像 Claude Code 读取项目根 CLAUDE.md |
| **Token 预算可视化** | P2 | 无知识库 token 统计 |
| **项目模板** | P2 | 无预置项目模板 (如 Python/React/Rust) |
| **多项目并行** | P2 | 单项目工作区，无项目切换保持状态 |

### 2.3 上游服务能力盘点

| 上游项目 | 现有项目相关能力 | 缺失能力 |
|----------|-----------------|----------|
| **fusion-mlx** | OpenAI-compat `/v1/chat/completions`、model list、SSE streaming | 无 session 管理、无知识库 API、无 embedding API |
| **fusion-code** | memdir (MEMORY.md)、session history、CLAUDE.md 读取、agent memory | 无项目知识库管理、无 RAG pipeline、无项目级 API |
| **fusion-artifacts-engine** | Artifact CRUD、版本管理、ref injection、token counting | 无项目级作用域、无知识库概念、session 级别非项目级 |
| **fusion-agent-studio** | KnowledgeEngine (sqlite-vec + FTS5 RAG)、AgentContext、session persistence | 无项目级隔离、无文件上传 API、无自定义指令管理 |
| **fusion-security** | Scanner (规则+AI)、FixGenerator、ReportGenerator | 无项目概念、纯扫描工具 |

---

## 三、Fusion Studio Projects 架构设计

### 3.1 目标架构

```
┌─────────────────────────────────────────────────────────┐
│                   Fusion Studio App                      │
├──────────┬──────────┬─────────────┬─────────────────────┤
│ Projects │  Chat    │   Editor    │    Inspector         │
│ Panel    │  Panel   │   + Diff    │    Panel             │
│          │          │   + Term    │                      │
├──────────┴──────────┴─────────────┴─────────────────────┤
│               FusionProjectManager                       │
│  ┌──────────┐ ┌────────────┐ ┌───────────────────────┐  │
│  │ Project  │ │ Knowledge  │ │ Custom Instructions   │  │
│  │ CRUD     │ │ Manager    │ │ Manager               │  │
│  └──────────┘ └────────────┘ └───────────────────────┘  │
│  ┌──────────┐ ┌────────────┐ ┌───────────────────────┐  │
│  │ Session  │ │ Context    │ │ Token Budget          │  │
│  │ Manager  │ │ Assembler  │ │ Tracker               │  │
│  └──────────┘ └────────────┘ └───────────────────────┘  │
├─────────────────────────────────────────────────────────┤
│               IPC Bridge (JSON-RPC 2.0)                  │
├──────────┬──────────┬─────────────┬─────────────────────┤
│fusion-mlx│fusion-code│artifacts-eg │ agent-studio        │
│inference │memdir+ctx │artifact mgmt│knowledge RAG        │
└──────────┴──────────┴─────────────┴─────────────────────┘
```

### 3.2 数据模型

```swift
struct FusionProject: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var rootPath: String
    var customInstructions: String
    var knowledgeFiles: [KnowledgeFile]
    var sessions: [ProjectSession]
    var createdAt: Date
    var updatedAt: Date
    var settings: ProjectSettings
}

struct KnowledgeFile: Identifiable, Codable {
    let id: UUID
    var fileName: String
    var filePath: String
    var fileSize: Int64
    var tokenCount: Int
    var addedAt: Date
    var scope: KnowledgeScope
}

enum KnowledgeScope: String, Codable {
    case project
    case session
    case global
}

struct ProjectSession: Identifiable, Codable {
    let id: UUID
    var projectId: UUID
    var title: String
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date
    var model: String
    var tokenUsage: Int
}

struct ProjectSettings: Codable {
    var defaultModel: String = ""
    var temperature: Double = 0.7
    var maxTokens: Int = 4096
    var autoLoadClaudeMd: Bool = true
    var autoScanKnowledge: Bool = true
}
```

### 3.3 Context Assembler (上下文组装器)

核心组件，负责将项目上下文组装为 LLM 可用的 system prompt:

```swift
class ContextAssembler {
    func assemble(project: FusionProject, session: ProjectSession?) -> [Message] {
        var systemParts: [String] = []

        // 1. 基础身份
        systemParts.append("You are Fusion Studio AI assistant.")

        // 2. 项目自定义指令
        if !project.customInstructions.isEmpty {
            systemParts.append("## Project Instructions\n\(project.customInstructions)")
        }

        // 3. CLAUDE.md (如果存在且开启)
        if project.settings.autoLoadClaudeMd {
            let claudeMd = loadClaudeMd(from: project.rootPath)
            if !claudeMd.isEmpty {
                systemParts.append("## Project CLAUDE.md\n\(claudeMd)")
            }
        }

        // 4. 知识库内容 (小文件直接注入，大文件 RAG)
        let knowledgeContext = assembleKnowledge(project.knowledgeFiles, query: nil)
        if !knowledgeContext.isEmpty {
            systemParts.append("## Project Knowledge\n\(knowledgeContext)")
        }

        // 5. 项目结构摘要
        let structure = summarizeProjectStructure(project.rootPath)
        systemParts.append("## Project Structure\n\(structure)")

        return [.system(systemParts.joined(separator: "\n\n"))]
    }
}
```

### 3.4 项目存储

```
~/.fusion-studio/
├── projects/
│   ├── {project-id}/
│   │   ├── project.json
│   │   ├── instructions.md
│   │   ├── knowledge/
│   │   │   ├── {file-id}.meta
│   │   │   └── {file-id}.content
│   │   ├── sessions/
│   │   │   └── {session-id}.json
│   │   └── settings.json
│   └── index.json
└── knowledge.db
```

---

## 四、实施路线图

### Phase 1: P0 — 项目基础设施 (1-2 周)

| # | 任务 | 涉及文件 | 上游依赖 |
|---|------|----------|----------|
| 1 | `FusionProject` 数据模型 + CRUD | 新建 `Common/FusionProject.swift` | 无 |
| 2 | `FusionProjectManager` 单例管理器 | 新建 `Common/FusionProjectManager.swift` | 无 |
| 3 | 项目级自定义指令存储/读取 | `FusionProjectManager` | 无 |
| 4 | `ContextAssembler` 上下文组装 | 新建 `Common/ContextAssembler.swift` | 无 |
| 5 | CLAUDE.md 自动读取 | `ContextAssembler` | 无 |
| 6 | 对话绑定项目 + 历史持久化 | 修改 `AgentBridge.swift` | 无 |
| 7 | ProjectsPanel 增强 (知识库/指令入口) | 修改 `Navigation/ProjectsPanel.swift` | 无 |

### Phase 2: P1 — 知识库 + RAG (2-3 周)

| # | 任务 | 涉及文件 | 上游依赖 |
|---|------|----------|----------|
| 8 | 知识库文件上传/管理 UI | 新建 `Common/KnowledgeManager.swift` + UI | 无 |
| 9 | 知识库文件解析 (PDF/MD/代码) | 新建 `Common/KnowledgeParser.swift` | fusion-mlx embedding API |
| 10 | RAG 检索集成 | `ContextAssembler` | agent-studio KnowledgeEngine API |
| 11 | Token 预算计算 | `KnowledgeManager` | fusion-artifacts-engine token_counter |
| 12 | 项目设置面板 | 新建 `Settings/ProjectSettingsView.swift` | 无 |

### Phase 3: P2 — 高级功能 (2-3 周)

| # | 任务 | 涉及文件 | 上游依赖 |
|---|------|----------|----------|
| 13 | 项目模板 (Python/React/Rust) | `FusionProjectManager` | 无 |
| 14 | 多项目并行 + 状态保持 | `FusionProjectManager` + ContentView | 无 |
| 15 | 知识库变更热更新 | `KnowledgeManager` + FileWatcher | 无 |
| 16 | 项目导入/导出 | `FusionProjectManager` | 无 |

---

## 五、上游 Issue 清单

### 5.1 fusion-mlx

| # | 标题 | 描述 | 优先级 |
|---|------|------|--------|
| 1 | 请求: Embedding API 端点 | `/v1/embeddings` 端点，用于知识库向量化。当前仅支持 completions，缺少 embedding 接口，阻碍 RAG 实现 | P1 |
| 2 | 请求: Session 管理增强 | 添加 session 概念到 API，支持按 session 追踪 token 用量、对话历史、上下文窗口管理 | P1 |
| 3 | 请求: 知识库上下文注入 | 在 chat completions API 中支持 `project_context` 字段，自动将项目知识库内容注入 system prompt | P2 |

### 5.2 fusion-code

| # | 标题 | 描述 | 优先级 |
|---|------|------|--------|
| 4 | 请求: 项目级 API 暴露 | 当前 memdir/session 功能仅在 CLI 内部使用。请求暴露项目级 API (JSON-RPC/HTTP)，供 Fusion Studio 调用 | P0 |
| 5 | 请求: CLAUDE.md 解析库 | 将 CLAUDE.md 解析逻辑抽离为独立模块，供外部项目集成 | P1 |
| 6 | 请求: Session History 导出 | 支持将 session history 导出为 JSON，供 Fusion Studio 项目面板展示 | P1 |

### 5.3 fusion-artifacts-engine

| # | 标题 | 描述 | 优先级 |
|---|------|------|--------|
| 7 | 请求: 项目级作用域 | 当前 artifact 仅绑定 session_id。请求添加 `project_id` 作用域，支持项目级 artifact 管理 | P0 |
| 8 | 请求: Token Counter API 暴露 | 将 token_counter 模块暴露为独立 API，供 Fusion Studio 计算知识库 token 预算 | P1 |

### 5.4 fusion-agent-studio

| # | 标题 | 描述 | 优先级 |
|---|------|------|--------|
| 9 | 请求: KnowledgeEngine HTTP API | 当前 KnowledgeEngine 仅可 Python 调用。请求暴露 HTTP API (端口 8893)，供 Fusion Studio 直接调用 RAG 检索 | P0 |
| 10 | 请求: 项目级 scope 隔离 | KnowledgeEngine.search() 支持 scope 参数，但无项目级自动隔离。请求添加 `project_id` scope | P1 |
| 11 | 请求: 文件上传 + 自动 ingest | 添加文件上传 API，自动解析 (PDF/MD/code) 并 ingest 到知识库 | P1 |

### 5.5 fusion-security

| # | 标题 | 描述 | 优先级 |
|---|------|------|--------|
| 12 | 请求: 项目级扫描结果缓存 | 支持按 project_id 缓存扫描结果，避免重复扫描未变更文件 | P2 |
| 13 | 请求: 增量扫描 API | 添加 `scan_incremental` API，仅扫描 git diff 变更的文件 | P2 |

---

## 六、关键设计决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 知识库存储 | 本地文件 + SQLite | 离线优先，零云依赖 |
| RAG 实现 | 优先 agent-studio KnowledgeEngine | 已有 sqlite-vec + FTS5，不重复造轮子 |
| 上下文注入 | system prompt 直接注入 (小文件) + RAG (大文件) | 与 Claude Projects 一致，简单可靠 |
| Embedding | 待 fusion-mlx 支持 embedding API | 目前 agent-studio 用 stub embedding，需上游支持 |
| 项目持久化 | JSON 文件 + SQLite 索引 | 简单可调试，符合 Fusion Studio 零依赖原则 |
| Session 管理 | 本地 Swift 实现 | 不依赖上游 session API，快速落地 |
| Token 计数 | 本地估算 + artifacts-engine API | 短期本地估算，长期调用上游 API |

---

## 七、风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| fusion-mlx 无 embedding API | RAG 向量化受阻 | 短期用 agent-studio stub embedding；中期提 Issue + PR |
| agent-studio KnowledgeEngine 无 HTTP API | 无法直接调用 RAG | 短期本地 FTS5；中期集成 subprocess 调用 |
| 大知识库 token 溢出 | 上下文窗口超限 | 实现 token budget 追踪 + 自动截断/分块 |
| 知识库文件格式多样 | 解析复杂 | 首期支持 .md/.txt/.swift/.py；后续扩展 PDF |

---

## 八、总结

Fusion Studio 当前具备项目管理的基础骨架 (ProjectsPanel/ProjectWorkspace/GitManager)，但缺少 Claude Projects 的三大核心能力：
1. **项目级知识库** — 上传文件作为持久上下文
2. **项目级自定义指令** — 项目专属 system prompt
3. **项目级对话历史** — 对话绑定项目，支持恢复

实施路径: **Phase 1 先在 Fusion Studio 内部完成数据模型 + 上下文组装 + 对话绑定**，不阻塞于上游 API；**Phase 2 推动上游 Issue 落地后集成 RAG**。

核心原则: **离线优先、零云依赖、本地优先、渐进集成**。

---

## 九、实施状态 (2026-07-27 更新)

### 已完成

| 任务 | 文件 | 状态 |
|------|------|------|
| FusionProject 数据模型 | `FusionStudio/Common/FusionProject.swift` | ✅ |
| FusionProjectManager CRUD + 持久化 | `FusionStudio/Common/FusionProject.swift` | ✅ |
| ContextAssembler 上下文组装 | `FusionStudio/Common/ContextAssembler.swift` | ✅ |
| AgentBridge 项目对话绑定 | `FusionStudio/System/AgentBridge.swift` | ✅ |
| ProjectsPanel 增强 (知识库/指令/会话/设置) | `FusionStudio/Navigation/ProjectsPanel.swift` | ✅ |
| RAG 集成 (knowledge.search) | `FusionStudio/Common/ContextAssembler.swift` | ✅ |
| Embedding API 客户端 (/v1/embeddings) | `FusionStudio/Common/ContextAssembler.swift` | ✅ |
| IPCClient knowledge.ingest/delete/list | `FusionStudio/Bridge/IPCClient.swift` | ✅ |
| FusionProjectManager.knowledgeIngestToRAG | `FusionStudio/Common/FusionProject.swift` | ✅ |

### 架构设计决策

1. **去掉 inout 参数** — `@Published` 的 willSet 闭包会捕获 inout，导致编译错误。改为 `projectId: UUID` 参数 + 直接修改 `projects[idx]` 的模式
2. **IPCClient 注入** — ContextAssembler 和 FusionProjectManager 通过 `setIPCClient()` 注入，在 FusionStudioApp.onAppear 统一设置
3. **RAG 增强** — `assembleWithRAG()` 先调本地知识库拼接，再通过 IPCClient 调 agent-studio 的 `knowledge.search` 获取语义搜索结果
4. **Embedding 客户端** — 直接 HTTP 调用 fusion-mlx 的 `/v1/embeddings` 端点，OpenAI 兼容格式
5. **SettingsTabContent 独立 struct** — 避免 @State 在 computed property 中的问题

### 上游依赖状态

| 上游 | 需求 | 状态 |
|------|------|------|
| fusion-agent-studio KnowledgeEngine | RAG search + ingest | ✅ `knowledge.search`/`ingest`/`delete`/`list` JSON-RPC 可用 |
| fusion-mlx embedding API | 向量化 | ✅ `/v1/embeddings` HTTP 端点可用 |
| fusion-artifacts-engine project_id | 项目级产物范围 | ❌ 尚未支持，待上游 Issue 落地 |
