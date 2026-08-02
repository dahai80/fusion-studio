# Fusion-Doc GUI 重构计划 — PRD 对齐

## 目标
按照 `fusion-doc-prd-ar.md` 在 fusion-studio 中打造领先 Claude Office 的 AI-First Document OS GUI。

## 上游 API 现状
fusion-doc 服务端 (port 11449) 已有 **82 个 REST 路由**，PRD 要求的控制器全部存在：

| PRD 需求 | 上游控制器 | 路由数 | 状态 |
|---------|----------|-------|------|
| AI Copilot | ai-copilot.js | 7 | ✅ complete/rewrite/translate/summarize/expand/command/context |
| Office 桥接 | office.js | 8 | ✅ create/import/export/preview/merge/command/import-dir/status |
| 工作流 | workflow.js | 10 | ✅ CRUD + run/runs/seed/transition/transitions |
| 模板 | template.js | 7 | ✅ CRUD + instantiate/variables |
| 知识图谱 | graph.js | 3 | ✅ graph/search/node |
| RAG 增强 | rag-enhanced.js | 4 | ✅ enhanced-query/reindex/chunks/reindex-all |
| 版本历史 | page.js | 12 | ✅ 含 versions/diff/restore/links |
| 书架 | book.js | 5 | ✅ CRUD |
| 协作 | collaboration.js | WS | ✅ WebSocket Yjs |

**结论：上游 API 100% 就绪，GUI 侧零阻塞，无需提上游 issue。**

## 当前 GUI 现状
- `DocView.swift` (5.5K) — 仅 HSplitView + TextEditor，无 AI/Office/图谱/工作流
- 无 DocBridge — 无 REST 客户端连接 fusion-doc 服务
- Module 枚举已有 `.doc` case → DocView()
- 遵循 Code/Science 模块的成熟模式 (Bridge + 主视图 + 子视图)

## 文件结构

```
FusionStudio/
├── Bridge/
│   └── DocBridge.swift            # REST client (port 11449)
│       DocPage/DocBook/DocChapter/DocTag models (Codable)
│       DocGraphNode/DocGraphEdge models
│       DocWorkflow/DocWorkflowRun/DocTemplate models
│       DocVersion/DocVersionDiff models
│       DocCopilotRequest models
│       All API calls with Combine @Published state
│
├── Modules/Doc/
│   ├── DocView.swift              # 主容器 — 三栏布局 (侧栏|编辑器|AI面板)
│   ├── DocSidebar.swift           # 书架树 + 页面列表 + 搜索 + 分类
│   ├── DocEditorView.swift        # Markdown 编辑器 + 实时预览
│   ├── DocAICopilotView.swift     # AI Copilot 右侧面板 (续写/改写/命令/RAG)
│   ├── DocGraphView.swift         # 知识图谱 (力导向 Canvas)
│   ├── DocWorkflowView.swift      # Agent 工作流面板 (5 预置 + 自定义)
│   ├── DocTemplateView.swift      # 模板选择器 + 变量填充
│   ├── DocVersionView.swift       # 版本历史 + diff 对比
│   └── DocOfficeView.swift        # Office 文档操控 (创建/导入/导出/预览)
```

## 实施阶段

### Phase 1: DocBridge + 数据模型 + 主布局 (核心基础)
**新建**: DocBridge.swift, DocView.swift, DocSidebar.swift
**删除**: 旧 DocView.swift
- DocBridge: REST client 连接 localhost:11449
  - 书架/章节/页面 CRUD (22 routes)
  - 健康检查 + 连接状态
- DocView: 三栏 HSplitView (侧栏 | 编辑器 | AI Copilot)
- DocSidebar: 书架树形导航 + 页面列表 + 标签筛选 + 搜索

### Phase 2: AI Copilot GUI (核心差异化)
**新建**: DocEditorView.swift, DocAICopilotView.swift
- Markdown 编辑器 (TextEditor + 预览切换)
- AI 续写面板 (POST /api/copilot/complete)
- 选中改写工具栏 (rewrite/translate/summarize/expand 4 按钮)
- `/` 命令面板 (12 个 AI 命令)
- 右侧 AI 对话面板 (多轮 + RAG `?` 前缀增强查询)

### Phase 3: 知识图谱 + 版本历史
**新建**: DocGraphView.swift, DocVersionView.swift
- 力导向图 (SwiftUI Canvas + 自定义力布局)
- 三种图谱: 链接/语义/标签 切换
- 节点拖拽/点击打开/搜索高亮
- 版本列表 + diff 对比 (统一 diff 渲染) + 恢复

### Phase 4: Office + 工作流 + 模板
**新建**: DocOfficeView.swift, DocWorkflowView.swift, DocTemplateView.swift
- Office 文档创建/导入/导出/HTML 预览
- 模板库 + 变量填充 + 实例化
- Agent 工作流面板 (5 预置: 报告生成/文档翻译/知识提取/周报/论文审阅)
- 工作流执行进度可视化 (步骤状态: ✅/🔄/⏳/❌)
