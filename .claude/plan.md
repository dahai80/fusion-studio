# Fusion Design GUI 完整实现计划（对标 Claude Design）

// Callers: ModuleDetailView.swift:203 DesignView(), AppState.swift:105 Module.design, FusionSidebarView
// Affected API: DesignBridge (CLI calls + skill dispatch), DesignChatPanel (quick prompts + screenshot), 7 InfoPanelTab views, DesignPrompts (8 skills)
// Data schemas: DesignMessage, ArtifactParseResult, DesignPage, PenDocument/PenNode (fd-canvas-core), DesignSystem/Token (fd-design-system), LintResult (fd-design-lint), CodegenTarget (fd-codegen), ExportFormat (fd-export), EcosystemTarget (fd-ecosystem)
// User instruction: "洞察claude design，按照GUI草图实现fusion design，和~/fusion/fusion-design配合，端到端完成fusion design，注意你负责GUI侧，只能改fusion-design的代码，对其他模块有问题和要求，提issue和pr，一定要做的比claude design更有竞争力"

## 差距分析

| 维度 | Claude Design | Fusion Design 当前 | 行动 |
|------|--------------|-------------------|------|
| AI 生成 | ✅ 文字→线框→高保真 | ✅ HTTP 流式推理已通 | 保持 |
| 矢量画布 | ❌ 纯图片不可编辑 | ✅ WASM 画布已有 | 完善 Inspector/Layers |
| 设计系统 | ❌ 无 | ⚠️ 3 套内置但 GUI 未接 CLI | **接通 CLI** |
| 规范检查 | ❌ 无 | ⚠️ GUI 空壳 | **接通 lint CLI** |
| 代码导出 | ✅ 单向 HTML/Tailwind | ⚠️ GUI 空壳 | **接通 codegen CLI** |
| 生态联动 | ✅ 单向 Design→Code | ⚠️ IPC 空壳 | **接通 ecosystem** |
| 版本管理 | ⚠️ 简单命名 | ⚠️ 有结构无 diff | **接通 diff CLI** |
| 素材库 | ✅ 云端上传 | ⚠️ 截图导入空壳 | **完善 ScreenshotImporter** |
| 快捷指令 | ✅ 基础 10 条 | ✅ 8 条模板 | 扩展 8 大 Design Skills |
| 主题切换 | ❌ 无 | ⚠️ GUI 有但未接 CLI | **接通 theme CLI** |

## 实施计划（5 Phase，每 Phase 端到端可验收）

### Phase 1: CLI Bridge 基础打通
**文件**: DesignBridge.swift
- 新增 `runFusionDesign(_ args: [String]) -> String` 通用 CLI 调用
- 新增 `runFusionDesignStream(_ args: [String], onToken: (String)->Void)` 流式调用
- 解析 `fusion-design` 二进制路径（`/usr/local/bin/fusion-design` 或 `~/.cargo/bin/fusion-design`）
- parse-html 集成确认：AI HTML → CLI parse-html → PenDocument JSON → Canvas 渲染
- export/export-batch 集成：DesignArtifactExporter → CLI export

### Phase 2: 8 大 Design Skills 接入
**文件**: DesignPrompts.swift, DesignChatPanel.swift
- 扩展 DesignPrompts：新增 image_to_ui/screenshot_to_ui/partial_edit/local_edit/sim_panel/multi_variants/spec_doc/page_flow
- DesignChatPanel 快捷指令分组：🎨生成 / 📸多模态 / ✏️编辑 / 📋文档 / 🔍检查
- ScreenshotImporter 完善：NSPasteboard + NSOpenPanel + 拖拽 → base64 → CLI generate with image
- 每个技能调用对应 CLI 命令或 DesignBridge 方法

### Phase 3: 信息面板 7 Tab 端到端
**文件**: DesignInspectorView, DesignLayersView, DesignTokenPanel, DesignSystemListView, DesignLintPanel, CodegenTargetPanel, EcosystemSyncPanel
- 属性 Tab：选中节点 → 显示 NodeStyle 全字段 → 编辑 → mutateCanvasNode
- 图层 Tab：lastRenderedDocumentJSON → 解析 PenDocument 树 → 显隐/锁定
- DS Token Tab：CLI list-design-systems + token-css → 展示+编辑
- 系统 Tab：CLI list-design-systems → 激活/预览
- 规范 Tab：CLI lint → 违规列表 → 一键修复
- 代码 Tab：CLI codegen → 4 目标代码生成
- 生态 Tab：CLI export --ipc_base + IPC 目录监听 + 模板保存/搜索

### Phase 4: 版本管理 + 工作流 + 主题
**文件**: ArtifactVersionDiff, DesignWorkflowOrchestrator, ThemeSwitcher
- 版本 Diff：CLI diff → 双栏对比 + 差异高亮
- 工作流：步骤条可视化 + 自动推进
- 主题：CLI theme → Token 切换 → 画布实时更新

### Phase 5: 打磨超越
**文件**: ScreenshotImporter, DesignCanvasView, DesignArtifactExporter, 弹窗
- 素材库增强：批量上传 + 标注 + 配色提取
- 画布右键菜单完善
- 局部重绘（选中节点 → AI 仅生成该区域）
- 设计规则锁定弹窗
- 多格式导出弹窗

## 不做的事
- 不改 fusion-design 后端代码（有问题提 issue/PR）
- 不改其他模块代码
- 不做 V2/V3 远期功能（团队协作、资产市场等）

## 修改文件范围（15 个文件，全在 FusionStudio/Modules/Design/）
1. DesignBridge.swift — CLI 调用核心
2. DesignChatPanel.swift — 快捷指令 + skill
3. DesignPrompts.swift — 8 大 skill 模板
4. DesignInspectorView.swift — 属性编辑
5. DesignLayersView.swift — 图层树
6. DesignTokenPanel.swift — Token 管理
7. DesignSystemListView.swift — 设计系统
8. DesignLintPanel.swift — 规范检查
9. CodegenTargetPanel.swift — 代码导出
10. EcosystemSyncPanel.swift — 生态联动
11. ArtifactVersionDiff.swift — 版本对比
12. DesignWorkflowOrchestrator.swift — 工作流
13. ThemeSwitcher.swift — 主题
14. ScreenshotImporter.swift — 截图导入
15. DesignArtifactExporter.swift — 导出

## 验收标准
每 Phase：swift build -c debug 零错误 + 核心路径端到端可运行
