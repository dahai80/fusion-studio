// Callers: ContentView, ModuleDetailView, AppState, FusionSidebarView, RAGMainView, RAG/* (8 views), RAGAPIClient.
// Affected API: REST 127.0.0.1:11436 (fusion-rag 34 endpoints), Module.rag/.kb, SidebarSection.ragSheet, FusionConfig.fusionRagURL/apiKey.
// Data schemas: KBInfo, KBSearchResult, KBAskResult, KBDocument, KBStats + RAGSection enum (8 cases).
// User instruction: "研读/Users/dahai/fusion/architecture/fusion-rag-prd-ar.md，在左侧菜单增加 fusion rag ,但fusion-studio负责GUI，和~/fusion/fuison-rag项目集成起来，包括GUI和workflow，usercase，全面集成,实现fusion rag，领先claude rag，最后要完成端到端测试，确保系统可用"

# Fusion RAG 端到端集成计划

## 调研结论（已实测验证）

**核心发现：Fusion RAG 的 GUI 已 90% 建成，但被碎片化成两个菜单入口。** 真正符合 PRD 8 节设计的实现已存在并可工作，任务本质是**整合 + 验证**，而非新建。

### 实测事实
- **后端 fusion-rag v0.6.3** 运行中：`127.0.0.1:11436`，12 个知识库，`embedding_available:true`，34 个 endpoint，鉴权关闭（无需 key）。
- **`RAGMainView.swift`（171 行）= PRD 对齐的统一入口**：`RAGSection` 枚举恰好 8 个 case，与 PRD 第 1 页完全一致：知识库总览/文件目录管理/嵌入模型配置/检索策略配置/权限管控/向量库运维/RAG调用日志/检索性能评测。
- **8 个真实视图**在 `RAG/`（共 4106 行，229-355 行/个），全部用 `RAGAPIClient.shared`。
- **`RAGAPIClient.swift`（796 行）**：baseURL=`FusionConfig`（默认 127.0.0.1:11436），apiKey 经 `X-API-Key` 头（空=不发送），30+ 方法覆盖 bases/documents/search/ask/auth/versions/scan/watch/permissions/bench/audit/templates/projects。
- **`ContentView.swift:161` 已路由 `.rag -> RAGMainView()`**（正确的 8 节视图）。

### 碎片化问题（需整合）
1. **`Module.kb`="知识库"** 是死菜单项：`ContentView` 无 `.kb` case -> 点击无反应。出现在 `AppState.swift:101/117/371`。
2. **`ModuleDetailView.swift:31`**（`.kb->KBView()`）和 **`:77`**（`.rag->RAGPipelineView()`）是死分支--`ContentView` 直接处理 `.rag`，不经过 `ModuleDetailView`。
3. **814 行遗留视图**（`KBView` 164、`RAGPipelineView` 46、`KBListView` 205、`KBChatView` 140、`KBSettingsView` 72、`SearchDebugView` 187）是死代码--`RAG/` 视图不引用它们，仅经死分支可达。
4. **上游 bug**：`routes_project.py` 经 `routes.py:212` 挂载，但运行时 `GET /kb/projects/test/kb` 和 `/kb/kb/projects/test/kb` 均 404（项目-KB 映射端点不可达）。非 8 核心节功能，按 issue->PR 流程处理。

## 成功标准
1. 左侧菜单**单一** "Fusion RAG" 入口 -> `RAGMainView`（8 个 PRD 节）。
2. `swift build -c debug` 通过。
3. 端到端：通过 `RAGAPIClient` 的调用路径对实时后端验证 KB CRUD->文档摄入->向量检索->RAG ask（带引用）->鉴权 key->版本快照均可用；解码与 Codable 结构对齐。
4. 7 个 PRD 用例均有 GUI 对应（无桩）。
5. 上游 projects router 404 已提 issue。
6. README + memory 更新。

## 实施步骤

### Phase 1 - 整合菜单（外科手术式，3 文件）
- **`AppState.swift`**：
  - 从 `ragSheet` 子列表移除 `.kb`（行 101、117、371），仅保留 `.rag`。
  - `.rag` rawValue `"RAG"` -> `"Fusion RAG"`（PRD："fusion-kb 改名为 fusion-rag"）。
  - 删除 `case kb` 定义以彻底去重（含 icon/sheet 映射）。
- **`ModuleDetailView.swift`**：删除死分支 `.kb->KBView()`（行 31）与 `.rag->RAGPipelineView()`（行 77）。
- **不删 814 行遗留视图文件**（降低风险；已无引用，编译无害），仅在 README 标注为 deprecated。
- 结果：单一 "Fusion RAG" 入口。

### Phase 2 - 构建 + 端到端验证（核心交付）
1. `swift build -c debug` 确认整合可编译。
2. 对实时后端（11436）按 `RAGAPIClient` 路径用 curl 复刻客户端调用，逐项验证 + 审计解码：
   - `GET /kb/status`（12 KBs）、`GET /kb/bases`
   - `POST /kb/bases`（建库）、`POST /kb/bases/{id}/documents/ingest`（摄入）、`POST /kb/bases/{id}/search`（检索）、`POST /kb/bases/{id}/ask`（RAG 带 citations）
   - `POST GET /kb/auth/keys`（鉴权）、`POST /kb/bases/{id}/versions`（快照）
   - `POST /kb/bases/{id}/bench`（评测）、permissions/audit/templates
3. 对比返回 JSON 与客户端 Codable 结构（`KBInfo`、`KBSearchResult`、`KBAskResult` 等），修复任何字段名/类型不匹配。
4. 启动 app 确认无崩溃启动。

### Phase 3 - 上游 issue（projects router 404）
- 在 fusion-rag 提 issue：`routes_project` 端点运行时 404（挂载/前缀 bug）。
- 按 issue->PR->code 流程；**不直接改 fusion-rag**。非阻塞性，不影响 8 核心节。

### Phase 4 - 用例/工作流 GUI 完整性审计
- 逐节确认 8 个 `RAG/` 视图非桩、功能可用。
- 映射 PRD 7 用例到 GUI；确认摄入->嵌入->存储->检索->重排->答案+引用 工作流在 GUI 暴露。

### Phase 5 - 文档
- 更新 fusion-studio README（RAG 模块说明）。
- 更新 memory `rag-gui-integration-complete.md`（当前陈旧，改为实测状态）。

## 取舍说明
- **不删遗留 814 行**：Rule 3 外科手术；删 6 文件风险高且非用户目标。仅断开引用。
- **E2E 范围**：headless 无法驱动 SwiftUI 交互，故 E2E = 构建通过 + 客户端 HTTP 层对实时后端成功 + 解码对齐 + app 启动不崩。这是 headless 下最接近 GUI E2E 的可行验证。
- **上游修复**：仅提 issue，不阻塞主集成（projects 映射非核心节）。
