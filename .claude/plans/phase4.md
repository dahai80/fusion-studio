# Phase 4: Design↔Code 联动 + 端到端工作流闭环

## 目标

打通 Design 模块与 Code 模块的壁垒，实现"设计即代码"闭环：Design 产出 → 自动同步到 Code 项目 → Code 修改 → 回流到 Design 预览。

## 背景

Phase 1-3 完成后 Fusion Design 已具备：
- AI 对话生成 HTML/React 组件 + 实时预览
- Design Token 系统 + 多页设计 + 版本管理
- Artifact↔文件双向同步 + project_id 隔离 + metadata
- ScreenshotImporter/FigmaBridge stub（待上游）

但 Design 产出仍是"孤岛"——生成的代码无法无缝流入 Code 模块的项目文件系统，Code 模块的修改也无法回流到 Design 预览。

## 任务清单

### Task 1: DesignArtifactExporter — 设计代码导出到项目文件
- 新建 `Modules/Design/DesignArtifactExporter.swift`
- 功能：将 Design 产出的 HTML/React/SwiftUI 代码写入 FusionProject.rootPath 下对应目录
- 目录结构约定：`{rootPath}/.fusion-design/{artifactName}/{version}.{ext}`
- 利用已有 `DesignBridge.syncArtifactToFile()` + artifact.sync API
- 支持批量导出（所有 pages → 项目目录）
- 导出后自动触发 Code 模块文件树刷新

### Task 2: DesignCodeLink — Design↔Code 双向绑定
- 新建 `Modules/Design/DesignCodeLink.swift`
- 功能：监视 `.fusion-design/` 目录变更，检测到代码变化时回流到 Design 预览
- 使用 FileWatcher（已有 System/FileWatcher.swift）或 FSEvents
- 当检测到文件变更：读取新内容 → 更新 DesignBridge.currentPage.code → 触发预览刷新
- 双向冲突策略：以时间戳最新的为准，冲突时弹 toast 提示

### Task 3: CodeModuleDesignBridge — Code 模块内嵌设计预览
- 修改 `Modules/Code/FusionCodeView.swift`
- 在 Code 模块侧边栏新增"Design Preview"标签页
- 当打开 `.fusion-design/` 下的文件时，自动显示 DesignPreviewView 预览
- 点击预览中的组件可跳转到 Design 模块继续迭代

### Task 4: DesignWorkflowOrchestrator — 端到端工作流编排
- 新建 `Modules/Design/DesignWorkflowOrchestrator.swift`
- 提供三种工作流入口：
  1. **Design→Code**: 生成设计 → 导出代码 → 打开 Code 模块编辑
  2. **Code→Design**: 选中 HTML/React 文件 → 导入到 Design 模块 → AI 迭代
  3. **Screenshot→Design→Code**: 截图导入 → AI 生成 → 导出代码（链路已打通，只需串联）
- 在 DesignChatPanel 底部工具栏添加"Export to Code"按钮
- 在 CodeMainView 文件右键菜单添加"Open in Design"选项

### Task 5: ArtifactVersionDiff — 版本差异可视化
- 新建 `Modules/Design/ArtifactVersionDiff.swift`
- 利用 artifact.version_list API 获取历史版本
- 对比相邻版本的代码差异，渲染 diff 视图（增/删/改高亮）
- 在 DesignChatPanel 版本历史列表中点击版本对可展开 diff
- 使用 NSDiffableDataSource 或简单的行级对比

### Task 6: 测试 + 文档
- 扩展 `DesignBridgeTests.swift`：导出/同步/冲突测试
- 更新 `docs/claude_design_insight.md` Phase 4 记录
- 更新 README.md Design 模块功能描述

## 文件变更预估

| 文件 | 操作 | 预估行数 |
|------|------|----------|
| `Modules/Design/DesignArtifactExporter.swift` | 新建 | ~200 |
| `Modules/Design/DesignCodeLink.swift` | 新建 | ~180 |
| `Modules/Design/DesignWorkflowOrchestrator.swift` | 新建 | ~250 |
| `Modules/Design/ArtifactVersionDiff.swift` | 新建 | ~220 |
| `Modules/Code/FusionCodeView.swift` | 修改 | +80 |
| `Modules/Design/DesignChatPanel.swift` | 修改 | +40 |
| `Modules/Design/DesignBridge.swift` | 修改 | +30 |
| `Navigation/CodeMainView.swift` | 修改 | +30 |
| `Tests/UnitTests/DesignBridgeTests.swift` | 修改 | +30 |

## 依赖

- Phase 1-3 已完成 ✅
- artifact.sync API 已存在 ✅
- FileWatcher 已存在 ✅
- project_id + metadata 已接入 ✅

## 不依赖上游

Phase 4 所有功能均在客户端侧实现，不阻塞任何上游 PR。
