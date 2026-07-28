# Claude.ai Artifacts vs Fusion Studio Artifacts — 洞察报告

> 日期: 2026-07-27
> 目标: 对标 claude.ai/artifacts，找出 Fusion Studio Artifacts 的差距并制定改进计划

---

## 1. 核心差异：交互范式

| 维度 | Claude.ai | Fusion Studio 当前 |
|------|-----------|-------------------|
| **创建范式** | AI 对话驱动 — 选模板后进入聊天，描述需求，AI 生成 artifact | 手动表单 — 选模板后填表单(Name/Type/Content)，手动写代码 |
| **模板选择后** | → 进入 Chat Composer，用户说"做一个待办应用"，AI 实时生成 | → 弹出 CreateArtifactSheet，预填模板代码，用户手动编辑 |
| **预览** | Chat + Preview 分栏，AI 边生成边渲染 | 选中 artifact 后右侧 detail 才预览，创建时无预览 |
| **版本** | 每轮对话自动产生版本，可回滚 | 手动 save version + changelog |
| **Artifact Kind** | `app/code/document/game/template/tool` 6 种语义 Kind | `code/markdown/html/react/data` 5 种技术 Type |

---

## 2. 模板数据对比

### Claude.ai 7 模板 (artifactCreateOptions.ts)

| # | ID | Label | Kind | Title | Description |
|---|---|---|---|---|---|
| 1 | `apps-and-websites` | Apps and websites | `app` | New app or website | A new interactive artifact for a website, app surface, or product workflow. |
| 2 | `documents-and-templates` | Documents and templates | `document` | New document or template | A structured artifact for a document, repeatable template, or formatted brief. |
| 3 | `games` | Games | `game` | New game | A playable artifact for a game, simulation, or interactive challenge. |
| 4 | `productivity-tools` | Productivity tools | `tool` | New productivity tool | A utility artifact for planning, tracking, calculating, or repeatable work. |
| 5 | `creative-projects` | Creative projects | `template` | New creative project | A visual or expressive artifact for creative exploration and presentation. |
| 6 | `quiz-or-survey` | Quiz or survey | `template` | New quiz or survey | A question-led artifact for collecting answers, testing knowledge, or guiding choices. |
| 7 | `start-from-scratch` | Start from scratch | `app` | Untitled artifact | A blank artifact canvas ready for a custom idea. |

### Fusion Studio 当前实现

| # | ID | Label | Type | Description |
|---|---|---|---|---|
| 1 | `apps-websites` | Apps and Websites | `html` | Build interactive web apps, dashboards, and full websites |
| 2 | `documents-templates` | Documents and Templates | `markdown` | Create structured documents, reports, and reusable templates |
| 3 | `games` | Games | `html` | Design and build interactive games and simulations |
| 4 | `productivity-tools` | Productivity Tools | `html` | Build calculators, planners, trackers, and automation tools |
| 5 | `creative-projects` | Creative Projects | `html` | Create art generators, music visualizers, and creative experiments |
| 6 | `quiz-survey` | Quiz or Survey | `html` | Build interactive quizzes, surveys, and assessment forms |
| 7 | `scratch` | Start from Scratch | `code` | Begin with a blank canvas and build anything you want |

**关键问题**: Apps/Games/Productivity/Creative/Quiz 在 Claude.ai 是不同 kind，在我们全是 `type: "html"`，用户无法从列表区分。

---

## 3. 卡片布局与交互对比

| | Claude.ai | Fusion Studio |
|---|-----------|---------------|
| 桌面列数 | `grid-cols-4` | `grid-cols-2` |
| 卡片高度 | `h-28` (112px) 紧凑 | ~150px 偏高 |
| 选中态 | 其他卡片 `disabled + opacity-50` | 无（点击直接 dismiss） |
| 图标 hover | `rotate ±2° + scale-1.05` 微动效 | 仅 border 高亮 |
| 卡片内布局 | desktop: flex-col icon top + label bottom | flex-row icon left + label right |
| Prompt 文案 | "Let's get cooking! Pick an artifact category or start building your idea from scratch." | "Select a template to get started, or start from scratch" |

---

## 4. 创建流程对比

### Claude.ai 流程
```
选模板 → Chat Composer → 用户描述需求 → AI 实时生成 → 侧边预览 → 迭代修改
```

### Fusion Studio 当前流程
```
选模板 → CreateArtifactSheet 表单 → 手填 Name/Type/Content → 创建 → 选中后预览
```

**核心差距**: 模板只是静态代码片段，没有 AI 参与。Claude 的模板选择是 AI 对话的入口，不是代码模板。

---

## 5. 安全沙箱对比

| | Claude.ai | Fusion Studio |
|---|-----------|---------------|
| 渲染 | `<iframe sandbox="">` 最严格 | WKWebView 无沙箱限制 |
| 脚本执行 | 严格沙箱内执行 | 完全开放 |
| 外部链接 | 沙箱内禁止，需确认 | 自动 `NSWorkspace.shared.open` |

---

## 6. 改进计划

### P0 — 必须立即做

| # | 改进项 | 说明 | 影响范围 |
|---|--------|------|----------|
| 1 | 引入 `kind` 语义字段 | `ArtifactTemplate` + `ArtifactModel` 增加 `kind: app/game/tool/document/template/code`，列表和详情用 kind 展示 | ArtifactsPanel.swift |
| 2 | 模板选择 → AI 对话流程 | 选完模板不弹表单，打开 Agent 对话面板，预填 system prompt 含模板 kind，AI 生成内容 | ArtifactsPanel.swift, AgentBridge.swift |

### P1 — 重要体验提升

| # | 改进项 | 说明 | 影响范围 |
|---|--------|------|----------|
| 3 | 4 列网格 + 紧凑卡片 | `grid-cols-4`，卡片高度 ~112px | TemplatePickerSheet |
| 4 | 选中态交互 | 选一个后其他 disabled + 半透明 | TemplatePickerSheet |
| 5 | 图标 hover 微动效 | rotate ±2° + scale 1.05 | TemplatePickerSheet |
| 6 | Prompt 文案对齐 | "Let's get cooking!" 风格 | TemplatePickerSheet |

### P2 — 体验打磨

| # | 改进项 | 说明 | 影响范围 |
|---|--------|------|----------|
| 7 | 创建过程实时预览 | side-by-side layout | ArtifactsPanel + AgentBridge |
| 8 | 版本自动追踪 | 每轮对话自动产生版本 | 需上游 fusion-artifacts-engine 支持 |

### P3 — 安全加固

| # | 改进项 | 说明 | 影响范围 |
|---|--------|------|----------|
| 9 | WKWebView 沙箱 | 限制 script/form/same-origin | HTMLPreviewView |

---

## 7. 上游依赖（需提 Issue）

### fusion-artifacts-engine

- **Issue #1**: [add `kind` semantic field](https://github.com/dahai80/fusion-artifacts-engine/issues/1)
- **Issue #2**: [automatic version tracking](https://github.com/dahai80/fusion-artifacts-engine/issues/2)

- **Issue**: Artifact 数据模型缺少 `kind` 字段 — 需要支持 `app/game/tool/document/template/code` 语义分类，当前只有 `type` (技术格式)
- **Issue**: `artifact.create` API 应接受 `kind` 参数，并在 `artifact.list` 返回中包含
- **Issue**: 版本自动追踪 — 对话驱动的创建模式下，每轮 AI 修改应自动产生版本，无需手动 changelog

### fusion-code (Agent 对话)

- **Issue #3**: [artifact creation chat API](https://github.com/dahai80/fusion-code/issues/3)

- **Issue**: 需要暴露 "创建 artifact 对话" 接口 — 接收 kind + user prompt，返回生成的 artifact content
- **Issue**: 对话过程中需要 artifact 实时预览回调（streaming）

### fusion-mlx

- **Issue #222**: [streaming output support](https://github.com/dahai80/fusion-mlx/issues/222)

- **Issue**: artifact 生成需要本地模型支持 streaming output，当前若无 streaming 则创建体验断裂
