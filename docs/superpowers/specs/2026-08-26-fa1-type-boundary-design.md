# F-A1 deep / F-I1 — AgentBridge 类型边界重构 (state-split)

> 审计 0825 F-A1 + F-I1 (验收 P0 阻断, 同根)。用户决策: state-split (F-A5 风格), 7 域, AgentBridge 内部持有域对象。本 spec 经 brainstorming 4 节逐节审批。

## 上下文

审计 0825 (`/Users/dahai/fusion/audit/fusion-studio-audit-report-0825.md`) 两项验收阻断 (同根):

- **F-A1** — AgentBridge "拆分" 是统计幻觉: ARCH-1 声称 3244→2395 "God-object 拆分完成", 实测主类仍 2401 行、48 个 `@Published`、85 方法、18 个 MARK 域仍住主类。13+ facade **全是 `extension AgentBridge`**, 无一是独立类型 — 全共享 `self.ipcClient`、`self.agents`/`self.templates`/`self.graphs` 等存储。该设计会导致任何给域加方法都重新膨胀主类, ARCH-1 的 23% 减行是统计幻觉, 职责数量从未减少。3 月债: facade 涨到 20+ 时主类 @Published 池膨胀到 80+, 每个新 facade 都得主类同步加存储属性。
- **F-I1** — AgentBridge MARK block 错摆, 跨域 @Published 混放: 域边界靠 MARK 注释, 重构时注释和实际不同步。3 月债: **"域边界应从 MARK 注释升级为类型边界 (每域独立 struct/actor 持自己的 @Published, AgentBridge 持域对象引用)"**; 否则错摆是慢性病。

**根治**: 把 48 个 @Published 从 AgentBridge 主类 MARK 分区, 升级为 7 个独立 `ObservableObject` 域类型, AgentBridge 持 `let` 域引用。复用 F-A5 (PR#315) 已验证的 AppState 拆 4 域模式。

## 决策摘要

经 brainstorming 4 节逐节审批, 用户决策 (verbatim 记录):

1. **重构形状** = State-split (F-A5 风格): 每域 = 独立 ObservableObject 持自己的 @Published; AgentBridge 持域对象 `let` 引用。facade 逻辑**保持** `extension AgentBridge`, 经 `self.<state>.X` reach-through。修 @Published 池膨胀 + 每域 SwiftUI 重绘粒度。最低风险, 字面满足审计 3 月债。(否决: 全服务抽取 — 17 facade 重定位 + 跨域路由 + 共享 parser 解耦, churn 最大)
2. **域数量** = 7 域 (否决 17 域 1:1 facade 过碎 / 5 粗域过大)。F-A5 = 4 域 / 17 props (密度 ~4); 本 = 7 域 / 48 props (密度 ~7)。
3. **持有 + 注入** = AgentBridge 内部构造域对象 (`let mlxState = MLXState()`), 暴露为 let 属性; 视图读 `bridge.mlxState.models`。**不改 FusionStudioApp.swift** (仍 `@StateObject agentBridge = AgentBridge()`, 仍单 `.environmentObject(agentBridge)`)。(否决 app 级拆 — 38 读端文件各自选域 @EnvironmentObject, over-engineered)
4. **重观察策略** = 自动追踪域: SwiftUI 经 body 内 `bridge.<state>.X` 自动订阅该域 ObservableObject (域是 `let` 稳定身份)。每域独立重绘粒度 = 审计目标, 无手工 objectWillChange 转发。(否决转发至 bridge — 丢粒度, 部分消解审计根治)

## 第 1 节 — 域归属 (7 域)

7 个域 ObservableObject, 全 `final class XState: ObservableObject`, 新文件 `FusionStudio/System/AgentBridgeDomains.swift`:

| 域 | @Published (count) | 写来源 (facade / 主类) |
|---|---|---|
| **RuntimeState** | isConnected, isExecuting, events (3) | 主类 (checkHealth/executeGraph/fetchTasks events) |
| **MLXState** | models, mlxRunning, mlxLoadedModels, mlxPort (4) | AgentMlxService facade + 主类 mlxStatus |
| **AgentState** | agents, currentAgent, agentSkills, agentSoul, marketplaceEntries, marketplaceCategories, agentVersionHistory, auditTrail, sessionLogs, activeSessionId, streamingContent, isAgentStreaming, lastToolCalls, graphs, dashboardData (15) | AgentOpsService + AgentGraphService + AgentMarketplaceService facade (最大域) |
| **ModuleState** | plans, currentPlan, ragResults, memoryEntries, memoryCount, safetyCheckResult, safetyPendingActions, templates, deployFormats, tools, ragSources, lastSkillResult, lastResearchResult (13) | AgentPlanner/RAG/Memory/Safety/Template/Deploy facade + 主类 (fetchTools/skillExecute/researchAdaptive) |
| **TaskState** | tasks, projects (2) | 主类 (fetchTasks/taskSubmit/taskDelete/taskCancel/taskRerun/taskSchedule*/updateTask 等 21 func) |
| **ConfigState** | connectors, apikeys, styles, hooks, analyticsData, alerts, swarmAgents, plazaChannels, cronJobs (9) | Connector/Style/Hooks/Analytics/Team/Cron facade + 主类 (fetchApikeys/fetchCronJobs) |
| **ProjectChatState** | chatMessages, isInferring (2) | AgentProjectChatService facade (0 SwiftUI 读, write-only) |

**合计 48 @Published** (3+4+15+13+2+9+2)。原 spec 漏 `graphs` (AgentGraphService:43 唯一写) + 误摆 `dashboardData` 到 RuntimeState (其唯一写 AgentOpsService:235 = AgentState facade, 交叉域写)。两独立 investigator 复核修正: `graphs`→AgentState, `dashboardData`→AgentState (消除唯一交叉域写, 恢复 "0 跨域写")。

**留在 AgentBridge** (不入任何域 — 跨域基础设施):
- `ipcClient: IPCClient?` (var) — 所有 facade 经 `self.ipcClient` reach
- 10 个 TTL 时间戳 (apikeysFetchedAt / projectsFetchedAt / tasksFetchedAt / cronJobsFetchedAt / stylesFetchedAt / hooksFetchedAt / connectorsFetchedAt / alertsFetchedAt + mlxStatusTimer / mlxStatusFetchedAt)
- 熔断器 (backendConsecutiveFailures / backendCircuitOpen / backendFailureThreshold) + taskHandlesLock / taskRunHandles
- parsing helper: anyToJSONValue (internal static, 跨文件 AgentGraphService 调); parseEventModel / jsonValueToAny (private static, 主类同文件)
- `private let logger` / `private let agentBridgeStaticLog`

**调研结论** (4 个独立 investigator agent 验证, 非自述; 第 4 轮复核修 3 处 spec 漏):
- 48 个真实 @Published (grep "63" 含注释提及; 实测 48)。
- **0 跨域 @Published 写** (修正后) — 原漏 `graphs` + 误摆 `dashboardData`。修正后 `graphs`/`dashboardData` 归 AgentState, 消除唯一交叉域写 (AgentOpsService:235 写 dashboardData = 同域 AgentState)。重大去风险成立。
- **1 跨域读**: AgentProjectChatService:50 读 `models` (MLXState 域) 经 `MLXModelInfo.preferredDefault(in: models)`。
- **0 `$bridge.X` 绑定** — 迁移是纯属性重命名, 无 Binding<> 管道。
- 38 读端文件; ChatSessionStore 唯一非视图读端 (models); AgentConfigTabs 最重 (12 distinct props)。
- **`ragResults` 0 写者** (ModuleState 域, reader-only @Published, 无人写) — 迁声明不动写; 保留 @Published, 待上游/未来补写。文档化。
- **`graphs` 11 读端** (DAGCanvasView:114/155 + AgentTaskViews:298/782/783/820/835/848/871 + AgentStudioView:113 + AgentGraphService 自身 diff guard) — 原 spec 漏, 本修正补入 AgentState。
- 11 个 write-only @Published (0 SwiftUI 读)。
- 21 个主类 func 写 @Published (留协调者, reach 域)。
- 3 个搁浅方法 (parser 耦合, 不写 @Published): marketplaceInstall 在 Ops (写 agentState.agents — 同域, 无隐患); templateInstantiate / deployImport 在 Graph (写无 @Published)。

## 第 2 节 — AgentBridge 作协调者 + facade reach-through

AgentBridge 退为协调者, 持 7 个 `let` 域引用:

```swift
@MainActor
final class AgentBridge: ObservableObject {
    let runtimeState = RuntimeState()
    let mlxState = MLXState()
    let agentState = AgentState()
    let moduleState = ModuleState()
    let taskState = TaskState()
    let configState = ConfigState()
    let projectChatState = ProjectChatState()

    var ipcClient: IPCClient?      // 留, facade 经 self.ipcClient
    private let logger = Logger(subsystem: "com.fusion.studio", category: "AgentBridge")
    // TTL 时间戳 / 熔断器 / task handles — 全留此
}
```

### Facade mechanics — 结构不变, 只写目标偏移

```swift
// AgentMlxService.swift (extension AgentBridge) — 前:
self.models = parsed
self.mlxRunning = true
// 后:
self.mlxState.models = parsed
self.mlxState.mlxRunning = true
```

`self.ipcClient` reach 不变 (facade 仍是 bridge extension)。parsing helper 留原处 (parseAgentModel private static 在 AgentOpsService 同文件 11 调用方 — 不需搬)。

### 主类 func (21 个) 同样 reach 域

`self.taskState.tasks = parsed` 替 `self.tasks = parsed`。`setIPCClient` 改 `client.$isConnected.assign(to: &$runtimeState.isConnected)`。

### 重观察 — 自动追踪域

SwiftUI 经 body 内 `bridge.<state>.X` 自动订阅该域 ObservableObject (域是 `let` 稳定身份, bridge 持同一实例)。视图读 `bridge.agentState.agents` → 只 AgentState 观察者重绘; MLXState 变化不触发该视图。每域独立重绘粒度 = 审计目标。**无手工 objectWillChange 转发**。AgentBridge 仍 ObservableObject (ipcClient/TTL/熔断器 等非域状态 + bridge 自身生命周期)。

### 域对象间通信

域是被动 @Published 持有者。跨域读 (`models` from ProjectChat): `MLXModelInfo.preferredDefault(in: self.mlxState.models)` — 一行重命名, mlxState 是 bridge `let` 可达。无跨域写 → 无域间写依赖。

## 第 3 节 — 读端迁移模式

38 读端文件。迁移 = 机械重命名。3 种读端形状:

**形状 A — 直接属性读** (绝大多数):
```swift
// 前 (AgentConfigTabs.swift 读 12 props):
bridge.agents
bridge.marketplaceEntries
bridge.connectors
// 后:
bridge.agentState.agents
bridge.agentState.marketplaceEntries
bridge.configState.connectors
```

**形状 B — `bridge.X` 其中 X 留 bridge** (基础设施, 无域): `bridge.ipcClient` — 不变。

**形状 C — 非视图读端** (ChatSessionStore.swift): 持 `weak var agentBridge: AgentBridge?`, 读 `bridge.models` → `bridge.mlxState.models`。同重命名, 3 站点。

### 属性 → 域路由表 (机械查表)

| 属性 | 新路径 |
|---|---|
| isConnected, isExecuting, events | bridge.runtimeState.X |
| models, mlxRunning, mlxLoadedModels, mlxPort | bridge.mlxState.X |
| agents, currentAgent, agentSkills, agentSoul, marketplaceEntries, marketplaceCategories, agentVersionHistory, auditTrail, sessionLogs, activeSessionId, streamingContent, isAgentStreaming, lastToolCalls, graphs, dashboardData | bridge.agentState.X |
| plans, currentPlan, ragResults, memoryEntries, memoryCount, safetyCheckResult, safetyPendingActions, templates, deployFormats, tools, ragSources, lastSkillResult, lastResearchResult | bridge.moduleState.X |
| tasks, projects | bridge.taskState.X |
| connectors, apikeys, styles, hooks, analyticsData, alerts, swarmAgents, plazaChannels, cronJobs | bridge.configState.X |
| chatMessages, isInferring | bridge.projectChatState.X |
| ipcClient | bridge.ipcClient (不变) |

### 迁移工具

每文件 whole-word 替换 `bridge.<prop>` / `agentBridge.<prop>` 按路由表。按域顺序避免前缀碰撞 (e.g. `bridge.agents` 匹配 `bridge.agents\b`, 不撞已改的 `bridge.agentState.agents`)。验证: 无属性名是另一路径段前缀。

### 关键点

- **0 `$bridge.X` 绑定** → 无 Binding<> 重写。
- **11 write-only @Published** (0 读端) → 只迁声明 + facade 写, 不碰读端。
- `currentAgent` 读 1 文件 (AgentListViews, write-only onAppear) → `bridge.agentState.currentAgent`。
- `streamingContent` / `isAgentStreaming` 写者在 AgentDashboardViews → `bridge.agentState.X`。

## 第 4 节 — 分阶段落地 + 风险/门禁

7 域, 每域一 build-gated 检查点。按依赖 + 风险排序 (独立叶域先):

| 阶段 | 域 | Props | Facade/主类写来源 | 读端文件 | 门禁 |
|---|---|---|---|---|---|
| 0 | scaffold | — | 建 AgentBridgeDomains.swift 7 空域类 + AgentBridge `let` 引用 (尚未迁 @Published) | 0 | build EXIT=0 |
| 1 | MLXState | 4 | AgentMlxService + 主类 mlxStatus | SettingsView(3) +13 via models | build + tests |
| 2 | ConfigState | 9 | Connector/Style/Hooks/Analytics/Team/Cron + 主类 (apikeys/cron) | AgentConfigTabs(8), DouyinOpView(cron) | build + tests |
| 3 | TaskState | 2 | 主类 (21 task func) | AgentTaskViews/ConfigTabs/StudioView | build + tests |
| 4 | ProjectChatState | 2 | AgentProjectChatService | 0 (write-only) | build + tests |
| 5 | ModuleState | 13 | Planner/RAG/Memory/Safety/Template/Deploy + 主类 | MemoryView/SafetyView/Planner/Deploy/AgentConfigTabs/Desk/DocTemplate | build + tests |
| 6 | AgentState | 15 | AgentOpsService + AgentGraphService + AgentMarketplaceService | AgentListViews/AgentDashboardViews/TemplateMarketView/AIAgent*(7)/DAGCanvasView/AgentTaskViews(graphs) | build + tests |
| 7 | RuntimeState | 3 | 主类 (checkHealth/executeGraph/events) | AgentStudioView/DeskView/PluginEcosystem/DocSidebar/AgentDashboardViews | build + tests, 最终 |

**修正注** (第 4 轮复核): 原 Phase 6=13 (漏 graphs) / Phase 7=4 (误含 dashboardData)。`graphs` (AgentGraphService:43 写) + `dashboardData` (AgentOpsService:235 写, 原 RuntimeState = 唯一交叉域写) 归 AgentState (Phase 6)。消除交叉域写, Phase 7 降至 3 props。`graphs` 11 读端 (DAGCanvasView + AgentTaskViews + AgentStudioView) 随 Phase 6 迁。

### 每阶段 mechanics (确定性, 每阶段同)

1. 移 N 个 @Published 声明: AgentBridge.swift → AgentBridgeDomains.swift 域类。
2. 域的非-@Published 状态 (TTL 时间戳等): 若 facade 拥有, 移入域; 否则留 bridge + facade reach `self.<state>.X`。
3. Facade 写: `self.X` → `self.<state>.X`。
4. 主类写 (21 func): `self.X` → `self.<state>.X`。
5. 读端文件: 按路由表重命名 (whole-word, 仅本阶段 props)。
6. 门禁: `swift build -c debug` EXIT=0 + `swift build -c release` EXIT=0 + `swift test` 184/184。

### 风险登记

- **R1 — TTL 时间戳归属**: 8 时间戳 `internal` (facade 跨文件 reach)。时间戳移入域则 facade reach `self.<state>.xxxFetchedAt` (可行, 域是同 `let` 引用)。**决策: 时间戳留 bridge** — 它们由主类 func (fetchApikeys/fetchTasks/fetchCronJobs) 写, 这些 func 留 bridge; facade 写的时间戳 (styles/hooks/connectors/alerts) reach `self.stylesFetchedAt` 仍在 bridge。避免时间戳与其写 func 拆散。文档化。
- **R2 — 熔断器 + task handles**: 留 bridge (主类私有, 无域触)。
- **R3 — `models` 跨域读** (ProjectChat 读 MLXState.models): `MLXModelInfo.preferredDefault(in: self.mlxState.models)` — 一行重命名, 可行。
- **R4 — 搁浅方法** (marketplaceInstall 在 Ops 写 agents; templateInstantiate/deployImport 在 Graph 写无): 无跨域 @Published 写。marketplaceInstall 写 `self.agentState.agents` (其家 AgentOpsService 同 AgentState 域) — 实际正确, 无隐患。
- **R5 — SwiftUI 经 `let` 自动追踪**: 已验证模式 (F-A5 NavigationState 经 `appState.navState` let 工作)。build+tests+run 验证。
- **R6 — SourceKit 假阳性**: 已知 (同模块 Cannot find X) — build EXIT=0 为准, 忽略 indexer 噪声。

### 回滚

每阶段 = 分支上 1 commit。某阶段破则 revert 该 commit。阶段排序使早期不依赖晚期 (Phase 1 MLXState 独立于 Phase 6 AgentState)。

## 验证门禁

**每阶段**: `swift build -c debug` EXIT=0 (~24s) + `swift build -c release` EXIT=0 (~3-4min) + `swift test` 184/184 pass。SourceKit 同模块 "Cannot find" = 假阳性, build EXIT=0 为准。

**最终**: debug+release EXIT=0, 184 tests, CI 3/3 (Code Quality + Security Audit + Swift Build & Test) 全绿, 然后 `gh pr merge --merge --delete-branch` (直接 merge 已授权)。本地 Swift 比 CI macos-14 宽松 → release build 必跑 (CI 严, 暴本地假绿)。

**逻辑验证** (不启动 MLX): app 启动 → 各域 @Published 初值正确; 切 Tab → 仅该域观察者重绘; facade fetch → 写 `self.<state>.X` → 对应读端刷新。

**清理**: 无过程数据 (纯客户端类型重构, 无临时文件/模型加载)。

## 关联

- 审计: `fusion/audit/fusion-studio-audit-report-0825.md` F-A1 (验收 P0, L62-72) + F-I1 (L406-414), 同根 3 月债 "类型边界升级"。
- 复用: F-A5 (PR#315) AppState 拆 4 域 ObservableObject 已验证模式 — [[audit-fa5-appstate-split]]。
- facade 基线: ARCH-1 (PR#283-292) 13 facade 抽取 (统计幻觉根因, 本根治); [[arch1-extract-memory-facade]]。
- 互补: F-A2子2 (PR#318) TTL fetch 缓存时间戳 — 本重构迁移时间戳归属 (R1); [[audit-fa2-ttl-cache-mlx-visibility]]。
- 互补: F-I3 (PR#325) RPC 方法名常量 — 本重构不动 RPC 调用, 仅 @Published 持有边界; [[audit-fi3-rpc-method-constants]]。
- 下版: v0.1.48 含本 F-A1 deep / F-I1 (验收阻断清除)。
- 后续验收项 (逐项): F-I4 (Codable 13 parsers) / F-I5 (test coverage) / F-I7 (split AgentStudioView/CodeEditorView) / F-I11 (i18n deferred) / F-I12 (libs 评估)。
