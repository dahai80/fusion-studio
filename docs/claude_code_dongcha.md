# Claude.ai Code vs Fusion Studio Code — 洞察报告

> 日期: 2026-07-27
> 目标: 对标 Claude.ai Code (agentic coding tool)，找出 Fusion Studio Code 的差距并制定改进计划

---

## 1. 核心差异：Agentic vs Chat-Only

| 维度 | Claude.ai Code | Fusion Studio Code 当前 |
|------|----------------|------------------------|
| **本质** | Agentic 编码工具 — 自主读代码、改文件、跑命令、验证结果 | Chat-Only AI 助手 — 只能聊天回答，不能编辑文件 |
| **代码编辑** | 多文件自主编辑 + diff 可视化 + inline comment | ❌ 没有代码编辑器，AI 生成的代码只能复制 |
| **文件写入** | 直接写入磁盘，checkpoint 可回滚 | ❌ 文件树只读，无法保存/写回 |
| **终端** | 集成真终端，可跑测试/启动服务 | ❌ TerminalView 是模拟的，不连真 shell |
| **Diff** | 文件列表 + inline 变更 + 逐行评论 | ❌ 无 diff 视图 |
| **Git** | commit/branch/PR/CI 监控 | 仅 git clone + status --porcelain |
| **语法高亮** | Monaco Editor 全功能高亮 | ❌ AI 返回代码纯文本展示 |
| **LSP** | 插件集成，类型错误/跳转定义/查找引用 | ❌ 无 |
| **Artifacts** | 交互式网页发布层（不是编码主机制） | 有，但与 Code 模块未打通 |
| **Subagent** | 深度 3 嵌套，20 并发，agent teams | ❌ 单线程推理 |
| **MCP** | 连接外部服务(Google Drive/Jira/数据库) | ❌ 无 |
| **权限模式** | 5 级：Manual/Accept Edits/Plan/Auto/Bypass | 无权限控制 |
| **多平台** | CLI + VS Code + JetBrains + Desktop + Web | macOS SwiftUI 单平台 |

---

## 2. Claude Code Agentic Loop（核心机制）

```
┌─────────────────────────────────────────────────┐
│                  USER TASK                       │
│  "Fix the login bug and add rate limiting"      │
└──────────────────────┬──────────────────────────┘
                       ▼
          ┌────────────────────────┐
          │   1. Gather Context    │ ← 搜索文件、读代码、理解项目
          └────────────┬───────────┘
                       ▼
          ┌────────────────────────┐
          │   2. Take Action       │ ← 编辑文件、跑命令、创建文件
          └────────────┬───────────┘
                       ▼
          ┌────────────────────────┐
          │   3. Verify Results    │ ← 跑测试、检查输出、确认修复
          └────────────┬───────────┘
                       │
              ┌────────┴────────┐
              │ 结果 OK？        │
              ├── 否 ──→ 回到 1  │
              └── 是 ──→ 完成    │
              └─────────────────┘
```

**关键**: 用户可随时打断、纠正、重定向。AI 不是建议者，是执行者。

**Fusion Studio 当前**: 只有 loop 的第 1 步（Gather Context via CodeAgent.askAI），没有第 2 步（Take Action）和第 3 步（Verify Results）。

---

## 3. Claude Code UI 架构

### Desktop App (Code Tab)
```
┌──────────────────────────────────────────────────────────┐
│ Session Sidebar │  Chat Pane  │  Diff/Editor/Browser     │
│                 │             │  (draggable panes)        │
│ ● session 1    │ User: ...   │ ┌──────┬──────┐          │
│ ○ session 2    │             │ │ File │ Diff │          │
│ ○ session 3    │ Claude:     │ │ List │      │          │
│                 │ - edit a.ts │ │      │      │          │
│                 │ - run test  │ │      │      │          │
│                 │ +12 -3      │ └──────┴──────┘          │
│                 │             │                           │
│                 │ [input box] │  [terminal] [browser]     │
└──────────────────────────────────────────────────────────┘
```

### 关键 UI 元素
- **Diff Indicator**: 每次编辑后显示 +N -N，点击展开 diff
- **Diff View**: 左侧文件列表 + 右侧 inline 变更 + 逐行评论
- **File Editor Pane**: 单独的编辑面板，可做 spot edits
- **Terminal Pane**: 集成真终端 (Cmd+Ctrl+\`)
- **Browser Pane**: 预览运行中的应用
- **PR 按钮**: 直接从 diff view 创建 PR
- **Permission Mode**: 下拉选择权限级别

---

## 4. Fusion Studio Code 现状详解

### 已有能力
| 能力 | 实现 | 质量 |
|------|------|------|
| AI 聊天 | CodeAgent.askAI() → AgentBridge.infer() → MLX HTTP | ✅ 可用 |
| 模型选择 | fetchModels() + Effort(5级) + Thinking 模式 | ✅ 完善 |
| 文件树 | ProjectWorkspace 递归扫描(depth 6) + 搜索 | ✅ 可用 |
| AI 上下文 | addFileContext() 注入选中文件到 prompt | ✅ 有用 |
| Git clone | GitURLDetectionBar + Process 执行 git clone | ✅ 可用 |
| 项目管理 | RecentProject 持久化 + openLocalFolder | ✅ 可用 |
| Quick Actions | 5 个预设动作(Write/Learn/Code/Life/Claude's choice) | ⚠️ 基础 |
| Welcome Screen | 4 个卡片(Open Project/Explain/Review/Test) | ⚠️ 基础 |

### 缺失能力（按严重程度）
| # | 缺失 | 影响 | 难度 |
|---|------|------|------|
| 1 | **代码编辑器** | 无法编辑文件，AI 生成代码无处落地 | 高 |
| 2 | **Diff 视图** | 无法审查 AI 建议的变更 | 中 |
| 3 | **文件写回** | AI 无法实际修改项目代码 | 中 |
| 4 | **真终端** | 无法运行测试/启动服务验证结果 | 中 |
| 5 | **语法高亮** | 代码可读性差 | 中 |
| 6 | **Git 集成** | 无法 commit/push/PR | 低 |
| 7 | **Streaming** | 代码生成等待时间长，体验断裂 | 低 |
| 8 | **LSP** | 无自动补全/类型检查 | 高 |
| 9 | **Subagent** | 单线程，复杂任务慢 | 高 |
| 10 | **Apply Suggestion** | AI 建议无法一键应用到文件 | 中 |

---

## 5. 改进计划

### P0 — 核心能力缺失，必须先做

| # | 改进项 | 方案 | 影响范围 |
|---|--------|------|----------|
| 1 | **代码编辑器** | WKWebView + Monaco Editor（VS Code 同款编辑器），已有 WKWebView 模式(Design/Artifacts) | CodeEditorView.swift, 新建 MonacoEditorView.swift |
| 2 | **Diff 视图** | Monaco Diff Editor（内置 diff 功能），左侧原文件，右侧 AI 建议 | 新建 DiffView.swift |
| 3 | **文件写回** | ProjectWorkspace.write(file:content:) 写入磁盘 + checkpoint 机制 | CodeEditorView.swift, ProjectWorkspace |
| 4 | **AI → 编辑器** | AI 生成代码后显示 "Apply" 按钮，点击写入编辑器 | ChatContentView, MessageBubble |
| 5 | **统一视图** | 合并 CodeMainView 和 CodeView 为一个三栏布局 | CodeMainView.swift, CodeEditorView.swift |

### P1 — 体验提升

| # | 改进项 | 方案 | 影响范围 |
|---|--------|------|----------|
| 6 | **集成终端** | PTY 进程 + NSTask，参考 SwiftTerm | 新建 TerminalView.swift |
| 7 | **Diff Indicator** | AI 编辑后显示 +N -N，点击展开 diff | ChatContentView |
| 8 | **Streaming 输出** | AgentBridge.infer() 支持 SSE streaming | AgentBridge.swift, 上游 fusion-mlx |
| 9 | **Git 深度集成** | commit/diff/stash/branch 管理 | 新建 GitManager.swift |
| 10 | **权限模式** | 3 级：Manual / Accept Edits / Auto | CodeAgent, ProjectWorkspace |

### P2 — 高级功能

| # | 改进项 | 方案 | 影响范围 |
|---|--------|------|----------|
| 11 | **LSP 集成** | SourceKit-LSP (Swift) + JSON-RPC 桥接 | 新建 LSPClient.swift |
| 12 | **Apply Suggestion Flow** | AI 建议 → inline diff preview → confirm → 写入 | MessageBubble, DiffView |
| 13 | **Subagent** | 多 context 并行推理 | AgentBridge, 上游 fusion-mlx |
| 14 | **MCP 连接器** | Model Context Protocol 客户端 | 新建 MCPClient.swift |
| 15 | **CLAUDE.md 等价** | 项目级指令文件自动加载 | CodeAgent |

### P3 — 生态整合

| # | 改进项 | 方案 | 影响范围 |
|---|--------|------|----------|
| 16 | **Code ↔ Artifacts** | 代码结果发布为 artifact，artifact 代码回流编辑器 | CodeEditorView, ArtifactsPanel |
| 17 | **CI/CD 监控** | GitHub Actions 状态轮询 | 新建 CIClient.swift |
| 18 | **Skills 系统** | 可复用工作流包（/review, /deploy） | 新建 SkillManager.swift |
| 19 | **Code Review** | 多 agent PR 分析 | AgentBridge |

---

## 5.1 落地进度

### P0 — 已完成 ✅

| # | 改进项 | 状态 | 产出 |
|---|--------|------|------|
| 1 | 代码编辑器 | ✅ 完成 | `MonacoEditorView.swift` — WKWebView + Monaco Editor 0.52.2, 21 语言高亮 |
| 2 | Diff 视图 | ✅ 完成 | `MonacoDiffView` 内置在 MonacoEditorView.swift, FusionCodeView 右面板 Diff tab |
| 3 | 文件写回 | ✅ 完成 | `ProjectWorkspace.write()` + checkpoint 机制 + `undoLastWrite()` |
| 4 | AI → 编辑器 | ✅ 完成 | `CodeMessageBubble` Apply 按钮 → diff 预览 → 写入文件 |
| 5 | 统一三栏布局 | ✅ 完成 | `FusionCodeView.swift` — Sidebar(240px) \| Chat \| Editor/Diff/Terminal |

### 上游 Issue — 已提交

| 仓库 | Issue | 内容 |
|------|-------|------|
| fusion-code | [#4](https://github.com/dahai80/fusion-code/issues/4) | File edit API (read/write/diff/apply_patch/search) |
| fusion-code | [#5](https://github.com/dahai80/fusion-code/issues/5) | Command execution API (exec/processes/kill) |
| fusion-mlx | [#223](https://github.com/dahai80/fusion-mlx/issues/223) | Multi-context parallel inference |
| fusion-artifacts-engine | [#3](https://github.com/dahai80/fusion-artifacts-engine/issues/3) | Code ↔ Artifact bidirectional sync |
| fusion-agent-studio | [#2](https://github.com/dahai80/fusion-agent-studio/issues/2) | Agent task routing API for Code module |
| fusion-mlx | [#224](https://github.com/dahai80/fusion-mlx/issues/224) | SSE streaming for /v1/chat/completions |

### P1 — 已完成 ✅

| # | 改进项 | 状态 | 产出 |
|---|--------|------|------|
| 6 | 集成终端 (PTY) | ✅ 完成 | `PTYTerminalView.swift` — 真实 PTY 终端 (openpty + zsh)，替代原来的模拟终端 |
| 7 | Diff Indicator (+N -N) | ✅ 完成 | `CodeMessageBubble` 增加 `computeDiffStats()` + `diffIndicatorBadge` 显示 +N -N |
| 8 | Streaming 输出 | ✅ 完成 | `AgentBridge.inferStream()` — SSE 流式推理 + 上游 issue #224 |
| 9 | Git 深度集成 | ✅ 完成 | `GitManager.swift` + `FusionGitPanel` — commit/branch/stash/diff/discard/push/pull |
| 10 | 权限模式 | ⏭️ 跳过 | 优先级低，后续再做 |

### P2 — 待开始

| # | 改进项 | 优先级 |
|---|--------|--------|
| 11 | LSP 集成 (SourceKit-LSP) | 高 |
| 12 | Apply Suggestion Flow 优化 | 中 |
| 13 | Subagent 多 context 并行 | 中 |
| 14 | MCP 连接器 | 中 |
| 15 | CLAUDE.md 等价 (项目级指令) | 低 |

---

## 6. 目标架构：三栏布局

对标 Claude Desktop Code Tab，Fusion Studio Code 应该是：

```
┌──────────────────────────────────────────────────────────────┐
│              Fusion Code — Agentic Coding                    │
├──────────┬──────────────────┬───────────────────────────────┤
│          │                  │                               │
│ Sidebar  │   Chat Panel     │   Editor/Diff/Terminal        │
│          │                  │   (tabbed panes)              │
│ 📁 Files │  User: Fix the  │  ┌─────┬──────┬──────────┐   │
│ 🔀 Git   │  login bug      │  │Edit │ Diff │ Terminal │   │
│ 💬 Chat  │                  │  │     │      │          │   │
│ ⚙️ Config│  Claude:        │  │     │      │          │   │
│          │  - Edit auth.swift│  │     │      │          │   │
│          │  - Run tests     │  │     │      │          │   │
│          │  +12 -3 ▼       │  │     │      │          │   │
│          │                  │  └─────┴──────┴──────────┘   │
│          │  [input box]     │                               │
│          │  📎 🎤 ⚡model   │  [preview] [browser]          │
└──────────┴──────────────────┴───────────────────────────────┘
```

### 关键交互流

```
用户输入 → AI 读取项目文件 → AI 生成代码 → Diff 预览 → 用户确认 → 写入文件 → 跑测试 → 验证
                ↑                                                          │
                └──────────── 失败则重试 ←──────────────────────────────────┘
```

---

## 7. 技术选型

### 代码编辑器：Monaco Editor via WKWebView

**为什么选 Monaco**:
- VS Code 同款编辑器，功能完备（语法高亮、多光标、minimap、搜索替换）
- 内置 Diff Editor，开箱即用
- Web-based，WKWebView 嵌入零成本
- 已有 WKWebView 模式（Design 模块、Artifacts HTML 预览）
- 200+ 语言语法支持

**实现路径**:
1. 新建 `MonacoEditorView.swift` — WKWebView wrapper
2. 打包 Monaco 静态资源到 app bundle（monaco-editor npm 包 → minified）
3. JS bridge: `window.postMessage` ↔ `WKScriptMessageHandler`
4. API: `setContent(path:language:content:)`, `getContent()`, `setDiff(original:modified:)`, `onContentChange(callback:)`

### 终端：PTY + NSTask + 自绘

- 创建 PTY (posix_openpt) fork 子进程
- NSTask 执行 /bin/zsh
- 自绘终端输出（简单的 TextView 即可）
- 输入通过 PTY 写入
- 足够跑 git/test/build 命令，不需要完整终端模拟
- 避免引入外部 Swift 依赖，符合项目约定

---

## 8. 上游依赖（需提 Issue）

### fusion-code
- **Issue**: 暴露文件编辑 API — `code.edit_file(path, content, start_line, end_line)` 支持精确行范围替换
- **Issue**: 暴露命令执行 API — `code.execute(command, cwd)` 支持在项目目录执行 shell 命令
- **Issue**: Diff 生成 API — `code.diff(file, original, modified)` 返回结构化 diff
- **Issue**: AI 生成代码的 streaming + apply 模式

### fusion-mlx
- **Issue**: Streaming output (已在 #222 提出)
- **Issue**: 多 context 并行推理 — subagent 需要独立的推理 context

### fusion-artifacts-engine
- **Issue**: Code ↔ Artifact 双向转换 — 代码结果发布为 artifact，artifact 代码回流编辑器
