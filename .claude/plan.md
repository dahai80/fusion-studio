// Callers: ModuleDetailView, HubClusterView, HubLocalStorageView, IPCClient, AppState
// Affected API: fusion-multi-node REST API (34 endpoints on port 11452), fusion-model-hub cluster proxy (4 endpoints on port 11444)
// Data schemas: HubClusterNode, HubClusterTopologyResponse, MultiNodeTask, MultiNodeNode DTOs
// User instruction: "#74 multi-node 集群同步上游已完成，#61 的 6 项整改马上进行"

# 计划：#74 Multi-Node 集群 API 适配 + #61 架构整改

## 任务 A：#74 Multi-Node 集群同步 API 适配

### 问题
- `IPCClient.multiNodeCall` 用 JSON-RPC 格式调 HTTP，但上游 `fusion-multi-node` 用 **REST API** (`/api/...`)
- `HubLocalStorageView.syncToCluster()` 是空桩 TODO
- 上游有 **34 个 REST 端点**，当前 IPCClient 只映射了 4 个

### 方案
1. **重写 IPCClient Multi-Node 区段** — 从 JSON-RPC 改为 REST，端口 11452
   - 新增全部 34 个端点映射：节点/集群/同步/路由/任务/KV/监控/自动伸缩/可观测
2. **HubLocalStorageView.syncToCluster()** — 接入 `ipc.triggerIncrementalSync()`
3. **HubClusterView** — 补充节点注册、任务提交、路由策略等面板
4. **ModelHubModels.swift** — 新增 MultiNode 相关 DTO

## 任务 B：#61 架构合规整改

### B1: 巨型文件拆分 — AgentStudioView (5397行 → 8个文件)

| 新文件 | 内容 | 估算行数 |
|--------|------|----------|
| `AgentModels.swift` | AgentType/Agent/AgentTask/AgentWorkflow | ~170 |
| `AgentOrchestrator.swift` | AgentOrchestrator class | ~170 |
| `AgentStudioView.swift` | AgentStudioView 主视图 (保留) | ~180 |
| `AgentListViews.swift` | AgentListView + BackendAgentDetailView | ~700 |
| `AgentConfigViews.swift` | ConfigureAgentSheet + AgentDetailView + CreateAgentSheet | ~750 |
| `AgentTaskViews.swift` | TaskList/Create + WorkflowList/Detail/Create | ~660 |
| `AgentConfigTabs.swift` | 14 个 Config Tab (Team/Cron/Hooks/.../Style) | ~1840 |
| `AgentDashboardViews.swift` | DashboardTab + MarketplaceTab + ConversationView + SoulEditor | ~900 |

### B2: 巨型文件拆分 — IPCClient (3204行 → 7个文件)

| 新文件 | 内容 | 估算行数 |
|--------|------|----------|
| `IPCClient.swift` | class 定义 + 连接/JSON-RPC/UDS/读取/便捷方法 + 小 namespace | ~930 |
| `IPCAgentMethods.swift` | Agent CRUD/Lifecycle + Marketplace | ~380 |
| `IPCProjectMethods.swift` | project.* 15+ 方法 | ~380 |
| `IPCSpaceMethods.swift` | desk.space.* 11+ 方法 | ~470 |
| `IPCMultiNodeMethods.swift` | multi-node REST (重写扩展) | ~300 |
| `IPCFSBMethods.swift` | FSB REST 端点 | ~330 |
| `IPCArtifactsMethods.swift` | Artifacts Engine | ~410 |

### B3: 空壳目录清理
- 删除 `Services/supervisor/` 和 `Services/file-daemon/`

### B4: 模块重叠消除
- `Agent/` (仅 AgentDropdown.swift) → 合入 `AIAgent/`
- `KB/` (仅 KBView.swift) → 合入 `KnowledgeBase/`
- `teamCollab` Module case → 重定向到 `cowork`
- `agent` Module case → 重定向到 `aiAgentDashboard`

### B5: 硬编码 L5 模块
- `eduK12` case 标注 `// TODO: migrate to dynamic plugin`
- 暂不改动态插件架构

## 执行顺序

1. **Phase 1**: #74 IPCClient multi-node REST 重写 + HubLocalStorageView TODO 修复
2. **Phase 2**: AgentStudioView 拆分 (8 文件)
3. **Phase 3**: IPCClient 拆分 (7 文件)
4. **Phase 4**: 空壳清理 + 模块重叠消除
5. **Phase 5**: 构建/测试验证 + 提交

每个 Phase 完成后立即 `swift build` 验证。
