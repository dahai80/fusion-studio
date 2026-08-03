# Future Features Implementation Plan

## Scope: 11 Open Issues → 5 Phases

| Phase | Issues | Files | Est. Lines |
|-------|--------|-------|------------|
| P1: Plugin IPC + DTOs | #78-#84 foundation | PluginBridge.swift, PluginEcosystemModels.swift | ~600 |
| P2: Plugin GUI 7 views | #78-#84 | PluginEcosystemView.swift (7 tabs) | ~2800 |
| P3: Artifact IPC + GUI | #88, #90 | IPCArtifactsMethods additions, ArtifactRefRenderer | ~500 |
| P4: TaskManagementView | #89 | TaskManagementView.swift | ~600 |
| P5: Fusion-CLI Bridge | #85 | CLIBridge.swift, CliServiceView.swift | ~500 |
| **Total** | | | **~5000** |

---

## Phase 1: Plugin IPC + DTOs (Foundation for #78-#84)

### New file: FusionStudio/Bridge/PluginBridge.swift
- ObservableObject, REST client to fusion-plugins-ecosystem
- Base URL: http://{host}:{port}/rpc (JSON-RPC 2.0 over HTTP, same as FinanceBridge/DocBridge)
- Port from FusionConfig (default 11434, same as MLX)

### Methods (from issue IPC specs):
- plugins/list, plugins/install, plugins/uninstall
- plugins/config.get, plugins/config.set
- plugins/states, plugins/state.get, plugins/state.list
- plugins/token.records, plugins/token.prune
- plugins/vram.usage
- plugins/logs.stream (SSE)
- plugins/mcp.sessions, plugins/mcp.sessions.prune

### New file: FusionStudio/Modules/Plugin/PluginEcosystemModels.swift
- PluginListItem, EcosystemConfig, PluginStateInfo
- TokenRecord, VRAMUsage, MCPSession

---

## Phase 2: Plugin GUI 7 Views (#78-#84)

### New file: FusionStudio/Modules/Plugin/PluginEcosystemView.swift
7-tab tab bar (matching HubScheduleView pattern):

| Tab | Issue | Content |
|-----|-------|---------|
| 市场 | #78 | 搜索/分类/安装/卸载 |
| 配置 | #79 | EcosystemConfig 开关+数值编辑 |
| 状态 | #80 | 实时状态徽章+崩溃高亮+重启计数 |
| Token | #81 | 按 plugin/kind 聚合+趋势+汇总 |
| VRAM | #82 | 总量/已用/剩余+按插件分桶柱状图 |
| 日志 | #83 | 插件过滤+级别过滤+SSE流式+搜索 |
| MCP | #84 | 活跃会话+调用历史+超时清理+速率限制 |

Sidebar: add case pluginEcosystem to SidebarSection, route in SectionContentView

---

## Phase 3: Artifact IPC + GUI (#88, #90)

### IPC additions in IPCArtifactsMethods.swift:
- artifactPatch(artifactId, operation, anchor, content, expectedVersion)
- artifactLoad(artifactId, previewOnly, section)
- contextBudget(sessionId)

### Artifact-ref rendering (#88 ST-1):
- ArtifactRefRenderer struct in ArtifactPreviewCard.swift
- Parse [Artifact: name | ID: art_xxx] and <artifact id=...> XML
- Clickable card opens ArtifactCanvasView

### Context budget bar (#88 ST-2):
- ContextBudgetBar view (progress bar above chat input)
- Color: green(<50%), orange(50-80%), red(>80%)

### Per-artifact token cost (#88 ST-3):
- Token label on ArtifactPreviewCard
- Token ratio in ArtifactCanvasView footer

---

## Phase 4: TaskManagementView (#89)

### New file: FusionStudio/Modules/MultiNode/TaskManagementView.swift
- Table: ID | Model | Status | Node | Type | Actions
- Status badges: Running(green), Queued(yellow), Failed(red)
- Actions: Cancel, Degrade, Migrate
- Filter + Search + Submit Task sheet
- REST to fusion-multi-node localhost:9753

---

## Phase 5: Fusion-CLI Bridge (#85)

### New file: FusionStudio/Bridge/CLIBridge.swift
- ObservableObject, JSON-RPC 2.0 over UDS ~/.fusion/run/fusion-cli.sock
- Methods: service.status/start/stop, model.list/pull/info, kb.list/query, bench.speed, doc.status, rag.search, chat.complete

### New file: FusionStudio/Modules/CliServiceView.swift
- Service status dashboard + start/stop controls
- Wire to existing Module.cli case
- Add case cliService to SidebarSection

---

## Implementation Order
1. P1 → 2. P2 → 3. P3 → 4. P4 → 5. P5

## Shared Patterns
- Bridge: ObservableObject + REST/JSON-RPC + Logger + @Published
- Views: @ObservedObject + @Environment(\.studioTheme) + 4-space indent
- Sidebar: SidebarSection enum + SectionContentView switch
- DTOs: Codable + fromDict()
