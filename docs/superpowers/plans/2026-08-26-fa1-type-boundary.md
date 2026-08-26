# F-A1 / F-I1 AgentBridge Type-Boundary Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate AgentBridge's 48 `@Published` properties into 7 independent domain `ObservableObject` types, satisfying audit 0825 F-A1/F-I1 (验收 P0 阻断, "拆分统计幻觉" + "域边界升级类型边界").

**Architecture:** State-split (F-A5 style). Each domain = `final class XState: ObservableObject` owning its `@Published`, in new `FusionStudio/System/AgentBridgeDomains.swift`. AgentBridge becomes coordinator holding 7 `let` domain refs. Facades stay `extension AgentBridge`, reaching `self.<state>.X`. SwiftUI auto-tracks domains through `let` refs (per-domain render granularity). 0 cross-domain writes confirmed → clean phase-able split. 0 `$bridge.X` bindings → pure rename migration.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 14+, `@MainActor`, `ObservableObject`/`@Published`, zero external deps. Test: XCTest in `Tests/UnitTests/`. Build gate: `swift build -c debug` + `swift build -c release` + `swift test` 184/184 + CI 3/3.

**Spec:** `docs/superpowers/specs/2026-08-26-fa1-type-boundary-design.md`

## Global Constraints

- Indentation: multiples of 4 spaces. No docstrings.
- All code must include `os.log` logging where logic lives (facade loggers exist; new domain classes need a logger only if they hold logic — domains are passive @Published holders, no logger needed unless a method is added).
- Build truth = `swift build EXIT=0`. SourceKit same-module "Cannot find X" = false positive (ignore; build is truth per F-I3/F-I6 lesson). Local Swift more lenient than CI macos-14 → release build MUST pass.
- Branch off current master, never commit to master directly. Push, `gh pr create`, wait CI, `gh pr merge --merge --delete-branch`. Direct merge authorized.
- 8 phases (0 scaffold + 7 domains). Each phase = 1 commit on the feature branch. Each phase build-gated (debug+release+184 tests). SourceKit noise tolerated.
- Timestamps (8 TTL `*FetchedAt` + mlxStatusTimer/mlxStatusFetchedAt), circuit breaker, task handles, ipcClient, parsing helpers stay on AgentBridge (not in domains) — per spec R1/R2.
- Git operations in English. GitHub ops default English.

---

## File Structure

**Created:**
- `FusionStudio/System/AgentBridgeDomains.swift` — 7 domain `ObservableObject` classes (RuntimeState, MLXState, AgentState, ModuleState, TaskState, ConfigState, ProjectChatState). One file, MARK-grouped per domain (matches F-A5 `AppStateDomains.swift` precedent).

**Modified (per phase, mechanical):**
- `FusionStudio/System/AgentBridge.swift` — remove migrated `@Published` declarations; add 7 `let` domain refs; shift 21 main-class funcs' writes to `self.<state>.X`; `setIPCClient` assigns `$runtimeState.isConnected`.
- 17 facade files in `FusionStudio/System/Agent*Service.swift` — shift facade writes `self.X` → `self.<state>.X`.
- 38 reader files (views/panels) — rename `bridge.X` / `agentBridge.X` → `bridge.<state>.X` per routing table.
- `FusionStudio/Bridge/ChatSessionStore.swift` — sole non-view reader; `bridge.models` → `bridge.mlxState.models`.
- `Tests/UnitTests/AgentBridgeTests.swift` — new test file, domain default-value assertions (mirrors F-A5 CoreTests pattern).

**NOT modified:**
- `FusionStudio/FusionStudioApp.swift` — AgentBridge still `@StateObject agentBridge = AgentBridge()` + single `.environmentObject(agentBridge)`. No app-level split.

---

## Task 0: Scaffold — AgentBridgeDomains.swift + bridge `let` refs + test file

**Files:**
- Create: `FusionStudio/System/AgentBridgeDomains.swift`
- Modify: `FusionStudio/System/AgentBridge.swift:322` (add `let` domain refs after class decl, before existing @Published)
- Create: `Tests/UnitTests/AgentBridgeTests.swift`

**Interfaces:**
- Produces: 7 empty domain classes (`RuntimeState`, `MLXState`, `AgentState`, `ModuleState`, `TaskState`, `ConfigState`, `ProjectChatState`) — all `final class XState: ObservableObject {}` with `init() {}`. AgentBridge exposes `let runtimeState = RuntimeState()` etc. No @Published moved yet (stays on bridge). This task only creates the types + refs so subsequent phases move @Published into them.

- [ ] **Step 1: Write AgentBridgeDomains.swift (7 empty domain classes)**

Create `FusionStudio/System/AgentBridgeDomains.swift`:

```swift
import SwiftUI
import os.log

// F-A1/F-I1: AgentBridge 48 @Published 拆 7 独立 ObservableObject 域类型 (审计 0825 验收 P0,
//   复用 F-A5 PR#315 AppState 拆 4 域已验证模式)。AgentBridge 持 let 域引用, facade 仍是
//   extension AgentBridge 经 self.<state>.X reach-through。SwiftUI 经 body 内 bridge.<state>.X
//   自动追踪域 (let 稳定身份), 每域独立重绘粒度 = 审计根治。0 跨域写确认 → 干净可分阶段。
// 域: RuntimeState / MLXState / AgentState / ModuleState / TaskState / ConfigState / ProjectChatState。

// MARK: - Runtime State (连接 / 执行 / 事件)

final class RuntimeState: ObservableObject {
    init() {}
}

// MARK: - MLX State (模型列表 / 池可见性)

final class MLXState: ObservableObject {
    init() {}
}

// MARK: - Agent State (Agent 生命周期 + Marketplace + 流式 + Graphs + Dashboard, 最大域)

final class AgentState: ObservableObject {
    init() {}
}

// MARK: - Module State (Planner + RAG + Memory + Safety + Template + Deploy + tools)

final class ModuleState: ObservableObject {
    init() {}
}

// MARK: - Task State (任务 / 项目)

final class TaskState: ObservableObject {
    init() {}
}

// MARK: - Config State (Connector + APIKey + Style + Hooks + Analytics + Team + Cron)

final class ConfigState: ObservableObject {
    init() {}
}

// MARK: - Project Chat State (会话消息 / 推理中)

final class ProjectChatState: ObservableObject {
    init() {}
}
```

- [ ] **Step 2: Add 7 `let` domain refs to AgentBridge**

In `FusionStudio/System/AgentBridge.swift`, after `final class AgentBridge: ObservableObject {` (line 322) and before `@Published var isConnected` (line 324), insert:

```swift
    // F-A1/F-I1: 7 域子对象, 各独立 ObservableObject 持自己的 @Published (见 AgentBridgeDomains.swift)。
    // 持同一实例 (let 稳定身份), SwiftUI 经 bridge.<state>.X 自动追踪。@Published 分阶段从主类迁入域。
    let runtimeState = RuntimeState()
    let mlxState = MLXState()
    let agentState = AgentState()
    let moduleState = ModuleState()
    let taskState = TaskState()
    let configState = ConfigState()
    let projectChatState = ProjectChatState()

```

- [ ] **Step 3: Write AgentBridgeTests.swift (domain ref existence + identity)**

Create `Tests/UnitTests/AgentBridgeTests.swift`:

```swift
import XCTest
@testable import FusionStudio

@MainActor
final class AgentBridgeTests: XCTestCase {
    // F-A1/F-I1: AgentBridge 持 7 域 let 引用 (稳定身份, SwiftUI 自动追踪)。
    func testDomainRefsExist() {
        let bridge = AgentBridge()
        XCTAssertNotNil(bridge.runtimeState as RuntimeState?)
        XCTAssertNotNil(bridge.mlxState as MLXState?)
        XCTAssertNotNil(bridge.agentState as AgentState?)
        XCTAssertNotNil(bridge.moduleState as ModuleState?)
        XCTAssertNotNil(bridge.taskState as TaskState?)
        XCTAssertNotNil(bridge.configState as ConfigState?)
        XCTAssertNotNil(bridge.projectChatState as ProjectChatState?)
    }

    // 域引用稳定身份: 多次访问同一实例 (SwiftUI 追踪前提)。
    func testDomainRefsStableIdentity() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.mlxState === bridge.mlxState)
        XCTAssertTrue(bridge.agentState === bridge.agentState)
    }
}
```

- [ ] **Step 4: Build debug + release, run tests**

Run: `swift build -c debug 2>&1 | tail -5; echo "DEBUG_EXIT=$?"`
Run: `swift build -c release 2>&1 | tail -5; echo "RELEASE_EXIT=$?"`
Run: `swift test 2>&1 | tail -15`
Expected: DEBUG_EXIT=0, RELEASE_EXIT=0, tests 186/186 pass (184 existing + 2 new). SourceKit "Cannot find RuntimeState" etc. = false positive; build EXIT=0 is truth.

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/System/AgentBridgeDomains.swift FusionStudio/System/AgentBridge.swift Tests/UnitTests/AgentBridgeTests.swift
git commit -m "refactor(audit): F-A1 scaffold 7 domain ObservableObjects + bridge refs

Phase 0 of F-A1/F-I1 type-boundary refactor. Creates empty domain
classes (RuntimeState/MLXState/AgentState/ModuleState/TaskState/
ConfigState/ProjectChatState) + AgentBridge let refs. No @Published
moved yet. 0 cross-domain writes confirmed, reuses F-A5 PR#315 pattern."
```

---

## Task 1: MLXState — move 4 props + facade/main writes + 14 readers

**Files:**
- Modify: `FusionStudio/System/AgentBridgeDomains.swift` (MLXState class — add 4 @Published)
- Modify: `FusionStudio/System/AgentBridge.swift` (delete 4 @Published decls L324-336 range; shift main-class `mlxStatus`/`pollMlxStatus` writes)
- Modify: `FusionStudio/System/AgentMlxService.swift` (facade writes `self.models`/`self.mlxRunning`/`self.mlxLoadedModels`/`self.mlxPort` → `self.mlxState.X`)
- Modify: 14 reader files (see Step 4) + `FusionStudio/Bridge/ChatSessionStore.swift`
- Modify: `Tests/UnitTests/AgentBridgeTests.swift` (add MLXState default-value test)

**Interfaces:**
- Consumes: Task 0 (`mlxState` ref on AgentBridge, `MLXState` class).
- Produces: `bridge.mlxState.models` / `.mlxRunning` / `.mlxLoadedModels` / `.mlxPort` as new read path for all MLX-state consumers. Downstream phases consume nothing from MLXState except Phase 4 (ProjectChat cross-domain read `self.mlxState.models`).

**Props moved this phase (4):** `models`, `mlxRunning`, `mlxLoadedModels`, `mlxPort` → `MLXState`.

- [ ] **Step 1: Write failing test — MLXState defaults**

Append to `Tests/UnitTests/AgentBridgeTests.swift`:

```swift
    // F-A1 Phase 1: MLXState 4 @Published 初值 (models 空 / mlxRunning false / mlxLoadedModels 空 / mlxPort 0)。
    func testMLXStateDefaults() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.mlxState.models.isEmpty)
        XCTAssertFalse(bridge.mlxState.mlxRunning)
        XCTAssertTrue(bridge.mlxState.mlxLoadedModels.isEmpty)
        XCTAssertEqual(bridge.mlxState.mlxPort, 0)
    }
```

Run: `swift test --filter AgentBridgeTests 2>&1 | tail -15`
Expected: FAIL — `models`/`mlxRunning`/`mlxLoadedModels`/`mlxPort` not on `mlxState` yet (compile error or wrong path). This is the red.

- [ ] **Step 2: Move 4 @Published into MLXState**

In `FusionStudio/System/AgentBridgeDomains.swift`, replace the empty `MLXState` class:

```swift
// MARK: - MLX State (模型列表 / 池可见性)

final class MLXState: ObservableObject {
    // F-A2子3: MLX 池可见性。models=可用模型列表; mlxRunning/LoadedModels/Port=池状态轮询。
    @Published var models: [MLXModelInfo] = []
    @Published var mlxRunning: Bool = false
    @Published var mlxLoadedModels: [String] = []
    @Published var mlxPort: Int = 0
    init() {}
}
```

In `FusionStudio/System/AgentBridge.swift`, delete the 4 original `@Published` declarations (`models`, `mlxRunning`, `mlxLoadedModels`, `mlxPort`) from the main-class @Published block (L324-336 range — confirm exact lines first):

Run: `grep -n "var models\|var mlxRunning\|var mlxLoadedModels\|var mlxPort" FusionStudio/System/AgentBridge.swift`

Keep `isConnected`, `isExecuting`, `events`, `dashboardData`, `chatMessages`, `isInferring` in place (other phases).

- [ ] **Step 3: Shift facade + main-class writes to `self.mlxState.X`**

In `FusionStudio/System/AgentMlxService.swift`, replace every write `self.models` → `self.mlxState.models`, `self.mlxRunning` → `self.mlxState.mlxRunning`, `self.mlxLoadedModels` → `self.mlxState.mlxLoadedModels`, `self.mlxPort` → `self.mlxState.mlxPort`. Find exact sites:

Run: `grep -n "self\.models\|self\.mlxRunning\|self\.mlxLoadedModels\|self\.mlxPort" FusionStudio/System/AgentMlxService.swift`

Apply replace-all per identifier within this file (each unambiguous — no other `mlxRunning`/`mlxLoadedModels`/`mlxPort` exists; `self.models` whole-word, `self.mlxState.models` not yet present so no collision).

In `FusionStudio/System/AgentBridge.swift`, shift main-class writes (the `mlxStatus`/`pollMlxStatus` func and any main-class `self.models`/`self.mlxRunning`/`self.mlxLoadedModels`/`self.mlxPort`):

Run: `grep -n "self\.models\|self\.mlxRunning\|self\.mlxLoadedModels\|self\.mlxPort" FusionStudio/System/AgentBridge.swift`

Replace each `self.models` → `self.mlxState.models` etc. (whole-word; `self.mlxState.X` not yet present so no collision).

- [ ] **Step 4: Rename 14 reader files + ChatSessionStore via routing table**

Reader path: `bridge.models`/`agentBridge.models`/`bridge.mlxRunning`/`bridge.mlxLoadedModels`/`bridge.mlxPort` → `bridge.mlxState.X`/`agentBridge.mlxState.X`.

Find all reader sites first:

Run: `grep -rln "\.models\b\|\.mlxRunning\|\.mlxLoadedModels\|\.mlxPort" FusionStudio/ | sort -u`

Known reader files (14 + ChatSessionStore — verify each appears in grep, line numbers may drift):
- `FusionStudio/Settings/SettingsView.swift` — models (L250/251) + mlxRunning/LoadedModels/Port (L316/318/319/324/327/328/333/334)
- `FusionStudio/Bridge/ChatSessionStore.swift` — models (L642)
- `FusionStudio/Navigation/ArtifactsPanel.swift` — models (L521)
- `FusionStudio/Navigation/ProjectsPanel.swift` — models (L739/746)
- `FusionStudio/Modules/Code/CodeMainView.swift` — models (L254)
- `FusionStudio/Modules/Chat/UnifiedChatView.swift` — models (L515)
- `FusionStudio/Modules/Design/DesignChatPanel.swift` — models (L390)
- `FusionStudio/Modules/AgentStudio/AgentConfigViews.swift` — models (L29/30/148/516/517/575/805/806/859)
- `FusionStudio/Modules/ProjectModuleView.swift` — models (L2014)
- `FusionStudio/Modules/Science/ScienceChatView.swift` — models (L282)
- `FusionStudio/Modules/Code/FusionCodeView.swift` — models (L550)
- `FusionStudio/Modules/KB/KBChatView.swift` — models (L97)
- `FusionStudio/Modules/AgentStudio/AIAgentConfigView.swift` — models (L887)

Per file, replace (whole-word, bridge AND agentBridge prefixes): `bridge.models` → `bridge.mlxState.models`, `agentBridge.models` → `agentBridge.mlxState.models`, `bridge.mlxRunning` → `bridge.mlxState.mlxRunning`, `bridge.mlxLoadedModels` → `bridge.mlxState.mlxLoadedModels`, `bridge.mlxPort` → `bridge.mlxState.mlxPort`. **Do this AFTER Step 3** so `self.mlxState.models` already exists. Anchor replacement on `bridge.`/`agentBridge.` prefix only — never bare `.models`, since `mlxState.models` contains `.models` and would false-match.

**Exclusion:** `MlxHTTPClient.swift` `config.mlxPort` reads `FusionConfig.mlxPort`, NOT AgentBridge — leave unchanged (verify it does not reference `bridge.mlxPort`/`agentBridge.mlxPort`).

- [ ] **Step 5: Verify no stale references remain**

Run: `grep -rn "bridge\.models\b\|agentBridge\.models\b\|bridge\.mlxRunning\b\|bridge\.mlxLoadedModels\b\|bridge\.mlxPort\b\|self\.models\b\|self\.mlxRunning\b\|self\.mlxLoadedModels\b\|self\.mlxPort\b" FusionStudio/`
Expected: 0 matches (all migrated to `mlxState.X`). If any remain, fix.

- [ ] **Step 6: Build debug + release, run tests**

Run: `swift build -c debug 2>&1 | tail -5; echo "DEBUG_EXIT=$?"`
Run: `swift build -c release 2>&1 | tail -5; echo "RELEASE_EXIT=$?"`
Run: `swift test 2>&1 | tail -15`
Expected: DEBUG_EXIT=0, RELEASE_EXIT=0, tests 187/187 (186 + 1 new MLXState test). SourceKit "Cannot find" = false positive.

- [ ] **Step 7: Commit**

```bash
git add FusionStudio/System/AgentBridgeDomains.swift FusionStudio/System/AgentBridge.swift FusionStudio/System/AgentMlxService.swift FusionStudio/Bridge/ChatSessionStore.swift FusionStudio/Settings/SettingsView.swift FusionStudio/Navigation/ArtifactsPanel.swift FusionStudio/Navigation/ProjectsPanel.swift FusionStudio/Modules/Code/CodeMainView.swift FusionStudio/Modules/Chat/UnifiedChatView.swift FusionStudio/Modules/Design/DesignChatPanel.swift FusionStudio/Modules/AgentStudio/AgentConfigViews.swift FusionStudio/Modules/ProjectModuleView.swift FusionStudio/Modules/Science/ScienceChatView.swift FusionStudio/Modules/Code/FusionCodeView.swift FusionStudio/Modules/KB/KBChatView.swift FusionStudio/Modules/AgentStudio/AIAgentConfigView.swift Tests/UnitTests/AgentBridgeTests.swift
git commit -m "refactor(audit): F-A1 Phase 1 MLXState move 4 @Published + readers

Moves models/mlxRunning/mlxLoadedModels/mlxPort into MLXState domain.
AgentMlxService facade + main-class mlxStatus writes reach
self.mlxState.X. 14 reader files + ChatSessionStore renamed
bridge.models -> bridge.mlxState.models etc. 0 cross-domain writes."
```

---

## Task 2: ConfigState — move 9 props + 6 facades + main writes + readers

**Files:**
- Modify: `FusionStudio/System/AgentBridgeDomains.swift` (ConfigState class — add 9 @Published)
- Modify: `FusionStudio/System/AgentBridge.swift` (delete 9 @Published decls; shift main-class `fetchApikeys`/`fetchCronJobs` writes + apikey/cron write funcs)
- Modify: 6 facade files — `AgentConnectorService.swift`, `AgentStyleService.swift`, `AgentHooksService.swift`, `AgentAnalyticsService.swift`, `AgentTeamService.swift` (swarmAgents/plazaChannels), cron funcs (in bridge or a facade)
- Modify: reader files (see Step 4 grep)
- Modify: `Tests/UnitTests/AgentBridgeTests.swift` (add ConfigState default-value test)

**Interfaces:**
- Consumes: Task 0 (`configState` ref, `ConfigState` class).
- Produces: `bridge.configState.{connectors,apikeys,styles,hooks,analyticsData,alerts,swarmAgents,plazaChannels,cronJobs}` read path.

**Props moved this phase (9):** `connectors`, `apikeys`, `styles`, `hooks`, `analyticsData`, `alerts`, `swarmAgents`, `plazaChannels`, `cronJobs` → `ConfigState`.

**Note on TTL timestamps:** Per spec R1, the 4 facade-owned TTL timestamps (`stylesFetchedAt`/`hooksFetchedAt`/`connectorsFetchedAt`/`alertsFetchedAt`) STAY on AgentBridge (their writer funcs are split across main + facade; keeping timestamps on bridge avoids splitting a timestamp from its writer). Facades reach them as `self.stylesFetchedAt` (unchanged). Only the @Published arrays move to `configState`.

- [ ] **Step 1: Write failing test — ConfigState defaults**

Append to `Tests/UnitTests/AgentBridgeTests.swift`:

```swift
    // F-A1 Phase 2: ConfigState 9 @Published 初值 (全空)。
    func testConfigStateDefaults() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.configState.connectors.isEmpty)
        XCTAssertTrue(bridge.configState.apikeys.isEmpty)
        XCTAssertTrue(bridge.configState.styles.isEmpty)
        XCTAssertTrue(bridge.configState.hooks.isEmpty)
        XCTAssertTrue(bridge.configState.analyticsData.isEmpty)
        XCTAssertTrue(bridge.configState.alerts.isEmpty)
        XCTAssertTrue(bridge.configState.swarmAgents.isEmpty)
        XCTAssertTrue(bridge.configState.plazaChannels.isEmpty)
        XCTAssertTrue(bridge.configState.cronJobs.isEmpty)
    }
```

Run: `swift test --filter AgentBridgeTests 2>&1 | tail -15`
Expected: FAIL — props not on `configState` yet.

- [ ] **Step 2: Move 9 @Published into ConfigState**

In `FusionStudio/System/AgentBridgeDomains.swift`, replace the empty `ConfigState` class. **Important:** copy the EXACT type + default from AgentBridge.swift for each prop (find via grep first):

Run: `grep -n "var connectors\|var apikeys\|var styles\|var hooks\|var analyticsData\|var alerts\|var swarmAgents\|var plazaChannels\|var cronJobs" FusionStudio/System/AgentBridge.swift`

Record each prop's declared type + default, then write:

```swift
// MARK: - Config State (Connector + APIKey + Style + Hooks + Analytics + Team + Cron)

final class ConfigState: ObservableObject {
    @Published var connectors: [/* exact type from grep */] = /* default */
    @Published var apikeys: [/* exact type */] = /* default */
    @Published var styles: [/* exact type */] = /* default */
    @Published var hooks: [/* exact type */] = /* default */
    @Published var analyticsData: [/* exact type */] = /* default */
    @Published var alerts: [/* exact type */] = /* default */
    @Published var swarmAgents: [/* exact type */] = /* default */
    @Published var plazaChannels: [/* exact type */] = /* default */
    @Published var cronJobs: [/* exact type */] = /* default */
    init() {}
}
```

(Engineer MUST replace `/* exact type */` with the real type copied verbatim from the grep output — these are concrete model types e.g. `[ConnectorConfig]`, `[APIKeyEntry]`, not placeholders. This step is not done until every placeholder is filled with the real type from AgentBridge.swift.)

In `FusionStudio/System/AgentBridge.swift`, delete the 9 original `@Published` declarations.

- [ ] **Step 3: Shift facade + main-class writes to `self.configState.X`**

Per facade, find writes:

Run: `grep -n "self\.connectors\|self\.apikeys\|self\.styles\|self\.hooks\|self\.analyticsData\|self\.alerts\|self\.swarmAgents\|self\.plazaChannels\|self\.cronJobs" FusionStudio/System/AgentConnectorService.swift FusionStudio/System/AgentStyleService.swift FusionStudio/System/AgentHooksService.swift FusionStudio/System/AgentAnalyticsService.swift FusionStudio/System/AgentTeamService.swift FusionStudio/System/AgentBridge.swift`

Replace each `self.connectors` → `self.configState.connectors` etc. across all 6 files. Whole-word; `self.configState.X` not yet present in these files so no collision.

**Keep** the facade-owned TTL timestamp reads/writes (`self.stylesFetchedAt` etc.) unchanged on bridge per R1 — only the @Published arrays move.

- [ ] **Step 4: Rename reader files via routing table**

Find all reader sites:

Run: `grep -rln "\.connectors\b\|\.apikeys\b\|\.styles\b\|\.hooks\b\|\.analyticsData\b\|\.alerts\b\|\.swarmAgents\b\|\.plazaChannels\b\|\.cronJobs\b" FusionStudio/ | sort -u`

Known readers (verify against grep, may include `AgentConfigTabs.swift`, `DouyinOpView.swift`, `AnalyticsDashboardView.swift`, `CronView`/task sched views). Per file, replace `bridge.X`/`agentBridge.X` → `bridge.configState.X`/`agentBridge.configState.X` for these 9 props only. Anchor on `bridge.`/`agentBridge.` prefix to avoid false-matching `configState.X` later.

- [ ] **Step 5: Verify no stale references**

Run: `grep -rn "bridge\.connectors\b\|bridge\.apikeys\b\|bridge\.styles\b\|bridge\.hooks\b\|bridge\.analyticsData\b\|bridge\.alerts\b\|bridge\.swarmAgents\b\|bridge\.plazaChannels\b\|bridge\.cronJobs\b\|self\.connectors\b\|self\.apikeys\b\|self\.styles\b\|self\.hooks\b\|self\.analyticsData\b\|self\.alerts\b\|self\.swarmAgents\b\|self\.plazaChannels\b\|self\.cronJobs\b" FusionStudio/`
Expected: 0 matches.

- [ ] **Step 6: Build debug + release, run tests**

Run: `swift build -c debug 2>&1 | tail -5; echo "DEBUG_EXIT=$?"`
Run: `swift build -c release 2>&1 | tail -5; echo "RELEASE_EXIT=$?"`
Run: `swift test 2>&1 | tail -15`
Expected: DEBUG_EXIT=0, RELEASE_EXIT=0, tests 188/188.

- [ ] **Step 7: Commit**

```bash
git add -A FusionStudio/System/AgentBridgeDomains.swift FusionStudio/System/AgentBridge.swift FusionStudio/System/AgentConnectorService.swift FusionStudio/System/AgentStyleService.swift FusionStudio/System/AgentHooksService.swift FusionStudio/System/AgentAnalyticsService.swift FusionStudio/System/AgentTeamService.swift Tests/UnitTests/AgentBridgeTests.swift
# add reader files modified in Step 4 per grep
git commit -m "refactor(audit): F-A1 Phase 2 ConfigState move 9 @Published + readers

Moves connectors/apikeys/styles/hooks/analyticsData/alerts/
swarmAgents/plazaChannels/cronJobs into ConfigState domain. 6 facade
+ main-class writes reach self.configState.X. TTL timestamps stay on
bridge (R1). Reader files renamed per routing table."
```

---

## Task 3: TaskState — move 2 props + 21 main-class task funcs + readers

**Files:**
- Modify: `FusionStudio/System/AgentBridgeDomains.swift` (TaskState class — add 2 @Published)
- Modify: `FusionStudio/System/AgentBridge.swift` (delete 2 @Published decls `tasks`/`projects`; shift all 21 main-class task/project funcs' writes)
- Modify: reader files (see Step 4)
- Modify: `Tests/UnitTests/AgentBridgeTests.swift` (add TaskState default-value test)

**Interfaces:**
- Consumes: Task 0 (`taskState` ref, `TaskState` class).
- Produces: `bridge.taskState.tasks` / `bridge.taskState.projects` read path.

**Props moved this phase (2):** `tasks`, `projects` → `TaskState`.

**Note:** Both props are written ONLY by main-class funcs (fetchTasks/fetchProjects/taskSubmit/taskDelete/taskCancel/taskRerun/taskSchedule*/updateTask — 21 funcs). No facade writes them. TTL timestamps (`tasksFetchedAt`/`projectsFetchedAt`) STAY on bridge per R1.

- [ ] **Step 1: Write failing test — TaskState defaults**

Append to `Tests/UnitTests/AgentBridgeTests.swift`:

```swift
    // F-A1 Phase 3: TaskState 2 @Published 初值 (tasks/projects 空)。
    func testTaskStateDefaults() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.taskState.tasks.isEmpty)
        XCTAssertTrue(bridge.taskState.projects.isEmpty)
    }
```

Run: `swift test --filter AgentBridgeTests 2>&1 | tail -15`
Expected: FAIL — props not on `taskState` yet.

- [ ] **Step 2: Move 2 @Published into TaskState**

In `FusionStudio/System/AgentBridgeDomains.swift`, replace the empty `TaskState` class (copy exact types from grep):

Run: `grep -n "var tasks\|var projects" FusionStudio/System/AgentBridge.swift`

```swift
// MARK: - Task State (任务 / 项目)

final class TaskState: ObservableObject {
    @Published var tasks: [/* exact type from grep */] = /* default */
    @Published var projects: [/* exact type from grep */] = /* default */
    init() {}
}
```

(Engineer fills real types from grep — e.g. `[AgentTask]`, `[ProjectInfo]`. Not done until placeholders filled.)

In `FusionStudio/System/AgentBridge.swift`, delete the 2 original `@Published` declarations.

- [ ] **Step 3: Shift main-class writes to `self.taskState.X`**

Find all writes (main class only — no facades write tasks/projects):

Run: `grep -n "self\.tasks\|self\.projects" FusionStudio/System/AgentBridge.swift`

Replace each `self.tasks` → `self.taskState.tasks`, `self.projects` → `self.taskState.projects`. Whole-word. `self.taskState.X` not yet present, no collision.

**Keep** `self.tasksFetchedAt`/`self.projectsFetchedAt` unchanged on bridge (R1).

- [ ] **Step 4: Rename reader files via routing table**

Find all reader sites:

Run: `grep -rln "\.tasks\b\|\.projects\b" FusionStudio/ | sort -u`

Known readers (verify against grep): task monitor views (`TaskMonitorView`, `AgentTaskViews`), `AgentConfigTabs`, `ProjectsPanel`, `ProjectModuleView`, `StudioView`/`AgentStudioView`. Per file, replace `bridge.tasks`/`agentBridge.tasks` → `bridge.taskState.tasks`/`agentBridge.taskState.tasks`, `bridge.projects`/`agentBridge.projects` → `bridge.taskState.projects`/`agentBridge.taskState.projects`. Anchor on `bridge.`/`agentBridge.` prefix only.

**Caution:** `.tasks` may match unrelated identifiers (e.g. a local `Array` named `tasks`, `taskRunHandles`, `backendCircuitOpen`). The `bridge.`/`agentBridge.` prefix anchors to AgentBridge read-sites; do NOT bare-replace `.tasks`. Verify each grep hit is a `bridge.tasks`/`agentBridge.tasks` read before replacing.

- [ ] **Step 5: Verify no stale references**

Run: `grep -rn "bridge\.tasks\b\|bridge\.projects\b\|agentBridge\.tasks\b\|agentBridge\.projects\b\|self\.tasks\b\|self\.projects\b" FusionStudio/`
Expected: 0 matches.

- [ ] **Step 6: Build debug + release, run tests**

Run: `swift build -c debug 2>&1 | tail -5; echo "DEBUG_EXIT=$?"`
Run: `swift build -c release 2>&1 | tail -5; echo "RELEASE_EXIT=$?"`
Run: `swift test 2>&1 | tail -15`
Expected: DEBUG_EXIT=0, RELEASE_EXIT=0, tests 189/189.

- [ ] **Step 7: Commit**

```bash
git add -A FusionStudio/System/AgentBridgeDomains.swift FusionStudio/System/AgentBridge.swift Tests/UnitTests/AgentBridgeTests.swift
# add reader files modified in Step 4 per grep
git commit -m "refactor(audit): F-A1 Phase 3 TaskState move 2 @Published + readers

Moves tasks/projects into TaskState domain. 21 main-class task/project
funcs reach self.taskState.X. TTL timestamps (tasksFetchedAt/
projectsFetchedAt) stay on bridge (R1). Reader files renamed."
```

---

## Task 4: ProjectChatState — move 2 props + facade writes + cross-domain read

**Files:**
- Modify: `FusionStudio/System/AgentBridgeDomains.swift` (ProjectChatState class — add 2 @Published)
- Modify: `FusionStudio/System/AgentBridge.swift` (delete 2 @Published decls `chatMessages`/`isInferring`)
- Modify: `FusionStudio/System/AgentProjectChatService.swift` (facade writes + cross-domain read `self.models`)
- Modify: `Tests/UnitTests/AgentBridgeTests.swift` (add ProjectChatState default-value test)

**Interfaces:**
- Consumes: Task 0 (`projectChatState` ref, `ProjectChatState` class) + Task 1 (`bridge.mlxState.models` — cross-domain read R3).
- Produces: `bridge.projectChatState.chatMessages` / `.isInferring` path.

**Props moved this phase (2):** `chatMessages`, `isInferring` → `ProjectChatState`.

**Key facts:** Both props are WRITE-ONLY (0 SwiftUI readers — per spec "11 write-only @Published"). `AgentProjectChatService` facade writes them. Cross-domain read (R3): the facade reads `self.models` (MLXState) for `MLXModelInfo.preferredDefault(in: models)` — becomes `self.mlxState.models`.

- [ ] **Step 1: Write failing test — ProjectChatState defaults**

Append to `Tests/UnitTests/AgentBridgeTests.swift`:

```swift
    // F-A1 Phase 4: ProjectChatState 2 @Published 初值 (chatMessages 空 / isInferring false)。
    func testProjectChatStateDefaults() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.projectChatState.chatMessages.isEmpty)
        XCTAssertFalse(bridge.projectChatState.isInferring)
    }
```

Run: `swift test --filter AgentBridgeTests 2>&1 | tail -15`
Expected: FAIL — props not on `projectChatState` yet.

- [ ] **Step 2: Move 2 @Published into ProjectChatState**

In `FusionStudio/System/AgentBridgeDomains.swift`, replace the empty `ProjectChatState` class (copy exact types from grep):

Run: `grep -n "var chatMessages\|var isInferring" FusionStudio/System/AgentBridge.swift`

```swift
// MARK: - Project Chat State (会话消息 / 推理中)

final class ProjectChatState: ObservableObject {
    @Published var chatMessages: [/* exact type from grep */] = /* default */
    @Published var isInferring: Bool = /* default */
    init() {}
}
```

(Engineer fills real types from grep — e.g. `[ChatMessage]`, `Bool = false`. Not done until placeholders filled.)

In `FusionStudio/System/AgentBridge.swift`, delete the 2 original `@Published` declarations.

- [ ] **Step 3: Shift facade writes to `self.projectChatState.X` + cross-domain read**

In `FusionStudio/System/AgentProjectChatService.swift`, find all writes:

Run: `grep -n "self\.chatMessages\|self\.isInferring" FusionStudio/System/AgentProjectChatService.swift FusionStudio/System/AgentBridge.swift`

Replace `self.chatMessages` → `self.projectChatState.chatMessages`, `self.isInferring` → `self.projectChatState.isInferring`.

**Cross-domain read (R3):** find the `self.models` read in this facade:

Run: `grep -n "self\.models\b\|in: models\b\|preferredDefault" FusionStudio/System/AgentProjectChatService.swift`

Replace `self.models` → `self.mlxState.models` (this is the cross-domain read; `mlxState` is bridge `let` reachable from facade extension). If the read is `MLXModelInfo.preferredDefault(in: models)` where `models` is a local/shadowed var, trace its source — it likely originates from `self.models`; change the origin to `self.mlxState.models`.

- [ ] **Step 4: Verify no stale references + no reader rename needed**

Run: `grep -rn "bridge\.chatMessages\b\|agentBridge\.chatMessages\b\|bridge\.isInferring\b\|agentBridge\.isInferring\b\|self\.chatMessages\b\|self\.isInferring\b\|self\.models\b" FusionStudio/`
Expected: `bridge.chatMessages`/`agentBridge.chatMessages`/`bridge.isInferring`/`agentBridge.isInferring` = 0 (write-only, no readers). `self.chatMessages`/`self.isInferring`/`self.models` (outside already-migrated files) = 0. If any reader of chatMessages/isInferring exists, it was misclassified — rename to `projectChatState.X`/`mlxState.models` per routing table and note in commit.

- [ ] **Step 5: Build debug + release, run tests**

Run: `swift build -c debug 2>&1 | tail -5; echo "DEBUG_EXIT=$?"`
Run: `swift build -c release 2>&1 | tail -5; echo "RELEASE_EXIT=$?"`
Run: `swift test 2>&1 | tail -15`
Expected: DEBUG_EXIT=0, RELEASE_EXIT=0, tests 190/190.

- [ ] **Step 6: Commit**

```bash
git add FusionStudio/System/AgentBridgeDomains.swift FusionStudio/System/AgentBridge.swift FusionStudio/System/AgentProjectChatService.swift Tests/UnitTests/AgentBridgeTests.swift
git commit -m "refactor(audit): F-A1 Phase 4 ProjectChatState move 2 @Published

Moves chatMessages/isInferring into ProjectChatState domain
(write-only, 0 readers). AgentProjectChatService facade writes reach
self.projectChatState.X. Cross-domain read R3: self.models ->
self.mlxState.models (MLXModelInfo.preferredDefault)."
```

---

## Task 5: ModuleState — move 13 props + 6 facades + main writes + readers

**Files:**
- Modify: `FusionStudio/System/AgentBridgeDomains.swift` (ModuleState class — add 13 @Published)
- Modify: `FusionStudio/System/AgentBridge.swift` (delete 13 @Published decls; shift main-class `fetchTools`/`skillExecute`/`researchAdaptive` writes)
- Modify: 6 facade files — `AgentPlannerService.swift`, `AgentRAGService.swift`, `AgentMemoryService.swift`, `AgentSafetyService.swift`, `AgentTemplateService.swift`, `AgentDeployService.swift`
- Modify: reader files (see Step 4 grep)
- Modify: `Tests/UnitTests/AgentBridgeTests.swift` (add ModuleState default-value test)

**Interfaces:**
- Consumes: Task 0 (`moduleState` ref, `ModuleState` class).
- Produces: `bridge.moduleState.{plans,currentPlan,ragResults,memoryEntries,memoryCount,safetyCheckResult,safetyPendingActions,templates,deployFormats,tools,ragSources,lastSkillResult,lastResearchResult}` read path.

**Props moved this phase (13):** `plans`, `currentPlan`, `ragResults`, `memoryEntries`, `memoryCount`, `safetyCheckResult`, `safetyPendingActions`, `templates`, `deployFormats`, `tools`, `ragSources`, `lastSkillResult`, `lastResearchResult` → `ModuleState`.

**Note:** `memoryCount` is a derived `Int` (count of `memoryEntries`); its writer is `AgentMemoryService`. `tools` written by main-class `fetchTools`. `lastSkillResult`/`lastResearchResult` written by main-class `skillExecute`/`researchAdaptive`. Others split across Planner/RAG/Memory/Safety/Template/Deploy facades.

**`ragResults` 0-writer (special):** investigator verified `ragResults` @L384 `[RAGResultModel]` has **no writer anywhere** (reader-only @Published, dead-set). Migration = move the declaration only; no write to shift (Step 3 grep for `self\.ragResults` returns 0 — expected). Keep `@Published` (its readers, if any, still observe). Document as write-less; upstream/future may add a writer. This is correct — migrating a 0-writer decl is still valid (gets it out of the God-class @Published pool).

- [ ] **Step 1: Write failing test — ModuleState defaults**

Append to `Tests/UnitTests/AgentBridgeTests.swift`:

```swift
    // F-A1 Phase 5: ModuleState 13 @Published 初值。
    func testModuleStateDefaults() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.moduleState.plans.isEmpty)
        XCTAssertNil(bridge.moduleState.currentPlan)
        XCTAssertTrue(bridge.moduleState.ragResults.isEmpty)
        XCTAssertTrue(bridge.moduleState.memoryEntries.isEmpty)
        XCTAssertEqual(bridge.moduleState.memoryCount, 0)
        XCTAssertNil(bridge.moduleState.safetyCheckResult)
        XCTAssertTrue(bridge.moduleState.safetyPendingActions.isEmpty)
        XCTAssertTrue(bridge.moduleState.templates.isEmpty)
        XCTAssertTrue(bridge.moduleState.deployFormats.isEmpty)
        XCTAssertTrue(bridge.moduleState.tools.isEmpty)
        XCTAssertTrue(bridge.moduleState.ragSources.isEmpty)
        XCTAssertNil(bridge.moduleState.lastSkillResult)
        XCTAssertNil(bridge.moduleState.lastResearchResult)
    }
```

Run: `swift test --filter AgentBridgeTests 2>&1 | tail -15`
Expected: FAIL — props not on `moduleState` yet. (If a prop's real default is non-nil/empty, adjust the assertion to match the grep'd default in Step 2 — the test asserts the SAME default that was on AgentBridge, now on moduleState.)

- [ ] **Step 2: Move 13 @Published into ModuleState**

In `FusionStudio/System/AgentBridgeDomains.swift`, replace the empty `ModuleState` class. Copy exact type + default per prop:

Run: `grep -n "var plans\|var currentPlan\|var ragResults\|var memoryEntries\|var memoryCount\|var safetyCheckResult\|var safetyPendingActions\|var templates\|var deployFormats\|var tools\|var ragSources\|var lastSkillResult\|var lastResearchResult" FusionStudio/System/AgentBridge.swift`

```swift
// MARK: - Module State (Planner + RAG + Memory + Safety + Template + Deploy + tools)

final class ModuleState: ObservableObject {
    @Published var plans: [/* type */] = /* default */
    @Published var currentPlan: /* type? */ = /* default */
    @Published var ragResults: [/* type */] = /* default */
    @Published var memoryEntries: [/* type */] = /* default */
    @Published var memoryCount: Int = 0
    @Published var safetyCheckResult: /* type? */ = /* default */
    @Published var safetyPendingActions: [/* type */] = /* default */
    @Published var templates: [/* type */] = /* default */
    @Published var deployFormats: [/* type */] = /* default */
    @Published var tools: [/* type */] = /* default */
    @Published var ragSources: [/* type */] = /* default */
    @Published var lastSkillResult: /* type? */ = /* default */
    @Published var lastResearchResult: /* type? */ = /* default */
    init() {}
}
```

(Engineer fills every `/* type */` from grep — concrete model types, not placeholders. Not done until all filled. Test assertions in Step 1 must match these real defaults — fix the test if a default differs.)

In `FusionStudio/System/AgentBridge.swift`, delete the 13 original `@Published` declarations.

- [ ] **Step 3: Shift facade + main-class writes to `self.moduleState.X`**

Find all writes across the 6 facades + main class:

Run: `grep -n "self\.plans\|self\.currentPlan\|self\.ragResults\|self\.memoryEntries\|self\.memoryCount\|self\.safetyCheckResult\|self\.safetyPendingActions\|self\.templates\|self\.deployFormats\|self\.tools\|self\.ragSources\|self\.lastSkillResult\|self\.lastResearchResult" FusionStudio/System/AgentPlannerService.swift FusionStudio/System/AgentRAGService.swift FusionStudio/System/AgentMemoryService.swift FusionStudio/System/AgentSafetyService.swift FusionStudio/System/AgentTemplateService.swift FusionStudio/System/AgentDeployService.swift FusionStudio/System/AgentBridge.swift`

Replace each `self.plans` → `self.moduleState.plans` etc. across all 7 files. Whole-word; `self.moduleState.X` not yet present, no collision.

**Caution on `tools`:** `self.tools` may collide with unrelated identifiers — verify grep hits are the @Published `tools` (type `[ToolInfo]` or similar), not a local. The `self.` prefix anchors to instance; if a facade has a local `tools` it would be `tools` not `self.tools`, so `self.tools` replacement is safe.

- [ ] **Step 4: Rename reader files via routing table**

Find all reader sites:

Run: `grep -rln "\.plans\b\|\.currentPlan\b\|\.ragResults\b\|\.memoryEntries\b\|\.memoryCount\b\|\.safetyCheckResult\b\|\.safetyPendingActions\b\|\.templates\b\|\.deployFormats\b\|\.tools\b\|\.ragSources\b\|\.lastSkillResult\b\|\.lastResearchResult\b" FusionStudio/ | sort -u`

Known readers (verify against grep): `MemoryView`, `SafetyView`/`SafetyPanel`, planner views, deploy views, `AgentConfigTabs`, `DeskView`, doc template views, `AgentStudioView`. Per file, replace `bridge.X`/`agentBridge.X` → `bridge.moduleState.X`/`agentBridge.moduleState.X` for these 13 props. Anchor on `bridge.`/`agentBridge.` prefix.

**Caution:** `\.tools\b` and `\.templates\b` are common words — may match unrelated view-local properties. The `bridge.`/`agentBridge.` prefix anchors to AgentBridge read-sites; verify each hit is `bridge.tools`/`agentBridge.tools` (the AgentBridge @Published) before replacing. Do not bare-replace.

- [ ] **Step 5: Verify no stale references**

Run: `grep -rn "bridge\.plans\b\|bridge\.currentPlan\b\|bridge\.ragResults\b\|bridge\.memoryEntries\b\|bridge\.memoryCount\b\|bridge\.safetyCheckResult\b\|bridge\.safetyPendingActions\b\|bridge\.templates\b\|bridge\.deployFormats\b\|bridge\.tools\b\|bridge\.ragSources\b\|bridge\.lastSkillResult\b\|bridge\.lastResearchResult\b\|self\.plans\b\|self\.currentPlan\b\|self\.ragResults\b\|self\.memoryEntries\b\|self\.memoryCount\b\|self\.safetyCheckResult\b\|self\.safetyPendingActions\b\|self\.templates\b\|self\.deployFormats\b\|self\.tools\b\|self\.ragSources\b\|self\.lastSkillResult\b\|self\.lastResearchResult\b" FusionStudio/`
Expected: 0 matches.

- [ ] **Step 6: Build debug + release, run tests**

Run: `swift build -c debug 2>&1 | tail -5; echo "DEBUG_EXIT=$?"`
Run: `swift build -c release 2>&1 | tail -5; echo "RELEASE_EXIT=$?"`
Run: `swift test 2>&1 | tail -15`
Expected: DEBUG_EXIT=0, RELEASE_EXIT=0, tests 191/191.

- [ ] **Step 7: Commit**

```bash
git add -A FusionStudio/System/AgentBridgeDomains.swift FusionStudio/System/AgentBridge.swift FusionStudio/System/AgentPlannerService.swift FusionStudio/System/AgentRAGService.swift FusionStudio/System/AgentMemoryService.swift FusionStudio/System/AgentSafetyService.swift FusionStudio/System/AgentTemplateService.swift FusionStudio/System/AgentDeployService.swift Tests/UnitTests/AgentBridgeTests.swift
# add reader files modified in Step 4 per grep
git commit -m "refactor(audit): F-A1 Phase 5 ModuleState move 13 @Published + readers

Moves plans/currentPlan/ragResults/memoryEntries/memoryCount/
safetyCheckResult/safetyPendingActions/templates/deployFormats/
tools/ragSources/lastSkillResult/lastResearchResult into ModuleState
domain. 6 facade + main-class writes reach self.moduleState.X.
Reader files renamed per routing table."
```

---

## Task 6: AgentState — move 15 props + 3 facades + readers (largest domain)

**Files:**
- Modify: `FusionStudio/System/AgentBridgeDomains.swift` (AgentState class — add 15 @Published)
- Modify: `FusionStudio/System/AgentBridge.swift` (delete 15 @Published decls incl. `graphs` L325 + `dashboardData` L331; shift any main-class writes if present)
- Modify: `FusionStudio/System/AgentOpsService.swift` (facade writes — largest facade 510 lines; incl. `dashboardData` cross-domain write L235)
- Modify: `FusionStudio/System/AgentGraphService.swift` (facade writes `graphs` L40-43)
- Modify: `FusionStudio/System/AgentMarketplaceService.swift` (facade writes `marketplaceEntries` L26 + `marketplaceCategories` L100)
- Modify: reader files (see Step 4 grep — incl. `graphs` 11 readers + `dashboardData` readers)
- Modify: `Tests/UnitTests/AgentBridgeTests.swift` (add AgentState default-value test)

**Interfaces:**
- Consumes: Task 0 (`agentState` ref, `AgentState` class).
- Produces: `bridge.agentState.{agents,currentAgent,agentSkills,agentSoul,marketplaceEntries,marketplaceCategories,agentVersionHistory,auditTrail,sessionLogs,activeSessionId,streamingContent,isAgentStreaming,lastToolCalls,graphs,dashboardData}` read path.

**Props moved this phase (15):** the 13 AgentOps props + `graphs` (AgentGraphService writer) + `dashboardData` (AgentOpsService:235 cross-domain writer, moved here to eliminate the 1 cross-domain write) → `AgentState`.

**Key facts:** 13 AgentOps props written by `AgentOpsService`. `graphs` written by `AgentGraphService:43` (sole writer; 11 readers: DAGCanvasView:114/155, AgentTaskViews:298/782/783/820/835/848/871, AgentStudioView:113, AgentGraphService self-diff-guard:40/41). `dashboardData` written by `AgentOpsService:235` (the cross-domain write the original spec missed). `marketplaceInstall` (stranded, R4) writes `agents` — same domain. `currentAgent` read 1 file (`AgentListViews`).

- [ ] **Step 1: Write failing test — AgentState defaults**

Append to `Tests/UnitTests/AgentBridgeTests.swift`:

```swift
    // F-A1 Phase 6: AgentState 15 @Published 初值 (13 AgentOps + graphs + dashboardData)。
    func testAgentStateDefaults() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.agentState.agents.isEmpty)
        XCTAssertNil(bridge.agentState.currentAgent)
        XCTAssertTrue(bridge.agentState.agentSkills.isEmpty)
        XCTAssertTrue(bridge.agentState.agentSoul.isEmpty)
        XCTAssertTrue(bridge.agentState.marketplaceEntries.isEmpty)
        XCTAssertTrue(bridge.agentState.marketplaceCategories.isEmpty)
        XCTAssertTrue(bridge.agentState.agentVersionHistory.isEmpty)
        XCTAssertTrue(bridge.agentState.auditTrail.isEmpty)
        XCTAssertTrue(bridge.agentState.sessionLogs.isEmpty)
        XCTAssertTrue(bridge.agentState.activeSessionId.isEmpty)
        XCTAssertTrue(bridge.agentState.streamingContent.isEmpty)
        XCTAssertFalse(bridge.agentState.isAgentStreaming)
        XCTAssertTrue(bridge.agentState.lastToolCalls.isEmpty)
        XCTAssertTrue(bridge.agentState.graphs.isEmpty)
        XCTAssertTrue(bridge.agentState.dashboardData.isEmpty)
    }
```

Run: `swift test --filter AgentBridgeTests 2>&1 | tail -15`
Expected: FAIL — props not on `agentState` yet. (Adjust assertions to match real grep'd defaults in Step 2 if a default differs. `agentSoul`/`activeSessionId` are `String = ""` (non-nil) per investigator — test asserts `.isEmpty` not `XCTAssertNil`; fix test if grep shows a different default.)

- [ ] **Step 2: Move 15 @Published into AgentState**

In `FusionStudio/System/AgentBridgeDomains.swift`, replace the empty `AgentState` class. Copy exact type + default per prop:

Run: `grep -n "var agents\|var currentAgent\|var agentSkills\|var agentSoul\|var marketplaceEntries\|var marketplaceCategories\|var agentVersionHistory\|var auditTrail\|var sessionLogs\|var activeSessionId\|var streamingContent\|var isAgentStreaming\|var lastToolCalls\|var graphs\|var dashboardData" FusionStudio/System/AgentBridge.swift`

```swift
// MARK: - Agent State (Agent 生命周期 + Marketplace + 流式 + Graphs + Dashboard, 最大域)

final class AgentState: ObservableObject {
    @Published var agents: [AgentModel] = []
    @Published var currentAgent: AgentModel? = nil
    @Published var agentSkills: [String] = []
    @Published var agentSoul: String = ""
    @Published var marketplaceEntries: [MarketplaceEntryModel] = []
    @Published var marketplaceCategories: [String] = []
    @Published var agentVersionHistory: [String: [[String: Any]]] = [:]
    @Published var auditTrail: [[String: Any]] = []
    @Published var sessionLogs: [[String: Any]] = []
    @Published var activeSessionId: String = ""
    @Published var streamingContent: String = ""
    @Published var isAgentStreaming: Bool = false
    @Published var lastToolCalls: [[String: Any]] = []
    @Published var graphs: [AgentGraphModel] = []
    @Published var dashboardData: [String: Any] = [:]
    init() {}
}
```

(All 15 types/defaults filled from the investigator's verified decl list — types are concrete: `AgentModel`/`MarketplaceEntryModel`/`AgentGraphModel` etc. Confirm each against the Step 2 grep before committing; fix any mismatch.)

In `FusionStudio/System/AgentBridge.swift`, delete the 15 original `@Published` declarations (incl. `graphs` @L325 and `dashboardData` @L331).

- [ ] **Step 3: Shift facade + main-class writes to `self.agentState.X`**

Find all writes across the 3 facades + main class:

Run: `grep -n "self\.agents\|self\.currentAgent\|self\.agentSkills\|self\.agentSoul\|self\.marketplaceEntries\|self\.marketplaceCategories\|self\.agentVersionHistory\|self\.auditTrail\|self\.sessionLogs\|self\.activeSessionId\|self\.streamingContent\|self\.isAgentStreaming\|self\.lastToolCalls\|self\.graphs\|self\.dashboardData" FusionStudio/System/AgentOpsService.swift FusionStudio/System/AgentGraphService.swift FusionStudio/System/AgentMarketplaceService.swift FusionStudio/System/AgentBridge.swift`

Replace each `self.agents` → `self.agentState.agents` etc. across all 4 files. Whole-word; `self.agentState.X` not yet present, no collision.

**Critical — `dashboardData` cross-domain write:** `AgentOpsService.swift:235` writes `self.dashboardData = result`. This was the 1 cross-domain write the original spec missed (dashboardData originally RuntimeState, writer in the AgentState facade). Moving `dashboardData` to AgentState + shifting this write to `self.agentState.dashboardData` ELIMINATES the cross-domain write. Verify L235 migrated.

**Critical — `graphs` diff-guard reads:** `AgentGraphService.swift:40/41` read `self.graphs` in the fetch diff-guard. These reads migrate to `self.agentState.graphs` (read-site, not write, but same migration).

- [ ] **Step 4: Rename reader files via routing table**

Find all reader sites:

Run: `grep -rln "\.agents\b\|\.currentAgent\b\|\.agentSkills\b\|\.agentSoul\b\|\.marketplaceEntries\b\|\.marketplaceCategories\b\|\.agentVersionHistory\b\|\.auditTrail\b\|\.sessionLogs\b\|\.activeSessionId\b\|\.streamingContent\b\|\.isAgentStreaming\b\|\.lastToolCalls\b\|\.graphs\b\|\.dashboardData\b" FusionStudio/ | sort -u`

Known readers (verify against grep): `AgentListViews`, `AgentDashboardViews`, `TemplateMarketView`, 7 `AIAgent*` views, **+ graphs: `DAG/DAGCanvasView.swift` (L114/155), `Modules/AgentStudio/AgentTaskViews.swift` (L298/782/783/820/835/848/871), `Modules/AgentStudio/AgentStudioView.swift` (L113)**, **+ dashboardData readers** (grep to find). Per file, replace `bridge.X`/`agentBridge.X` → `bridge.agentState.X`/`agentBridge.agentState.X` for these 15 props. Anchor on `bridge.`/`agentBridge.` prefix.

**Caution:** `\.agents\b` / `\.graphs\b` common — may match view-local arrays. The `bridge.`/`agentBridge.` prefix anchors to AgentBridge read-sites; verify each hit is `bridge.agents`/`bridge.graphs` (the @Published) before replacing. Do not bare-replace.

- [ ] **Step 5: Verify no stale references**

Run: `grep -rn "bridge\.agents\b\|bridge\.currentAgent\b\|bridge\.agentSkills\b\|bridge\.agentSoul\b\|bridge\.marketplaceEntries\b\|bridge\.marketplaceCategories\b\|bridge\.agentVersionHistory\b\|bridge\.auditTrail\b\|bridge\.sessionLogs\b\|bridge\.activeSessionId\b\|bridge\.streamingContent\b\|bridge\.isAgentStreaming\b\|bridge\.lastToolCalls\b\|bridge\.graphs\b\|bridge\.dashboardData\b\|self\.agents\b\|self\.currentAgent\b\|self\.agentSkills\b\|self\.agentSoul\b\|self\.marketplaceEntries\b\|self\.marketplaceCategories\b\|self\.agentVersionHistory\b\|self\.auditTrail\b\|self\.sessionLogs\b\|self\.activeSessionId\b\|self\.streamingContent\b\|self\.isAgentStreaming\b\|self\.lastToolCalls\b\|self\.graphs\b\|self\.dashboardData\b" FusionStudio/`
Expected: 0 matches.

- [ ] **Step 6: Build debug + release, run tests**

Run: `swift build -c debug 2>&1 | tail -5; echo "DEBUG_EXIT=$?"`
Run: `swift build -c release 2>&1 | tail -5; echo "RELEASE_EXIT=$?"`
Run: `swift test 2>&1 | tail -15`
Expected: DEBUG_EXIT=0, RELEASE_EXIT=0, tests 192/192.

- [ ] **Step 7: Commit**

```bash
git add -A FusionStudio/System/AgentBridgeDomains.swift FusionStudio/System/AgentBridge.swift FusionStudio/System/AgentOpsService.swift FusionStudio/System/AgentGraphService.swift FusionStudio/System/AgentMarketplaceService.swift Tests/UnitTests/AgentBridgeTests.swift
# add reader files modified in Step 4 per grep (incl. DAGCanvasView, AgentTaskViews, AgentStudioView, dashboardData readers)
git commit -m "refactor(audit): F-A1 Phase 6 AgentState move 15 @Published + readers

Moves agents/currentAgent/agentSkills/agentSoul/marketplaceEntries/
marketplaceCategories/agentVersionHistory/auditTrail/sessionLogs/
activeSessionId/streamingContent/isAgentStreaming/lastToolCalls +
graphs (AgentGraphService writer) + dashboardData (cross-domain write
AgentOpsService:235, eliminated by moving to AgentState) into AgentState
domain (largest, 15 props). 3 facades (Ops/Graph/Marketplace) writes
reach self.agentState.X. graphs 11 readers + dashboardData readers
renamed. 0 cross-domain writes after this phase."
```

---

## Task 7: RuntimeState — move 3 props + main writes + setIPCClient reassignment + readers (FINAL)

**Files:**
- Modify: `FusionStudio/System/AgentBridgeDomains.swift` (RuntimeState class — add 3 @Published)
- Modify: `FusionStudio/System/AgentBridge.swift` (delete last 3 @Published decls; shift main-class `checkHealth`/`executeGraph`/`fetchTasks`-events writes; **reassign `setIPCClient` sink target**)
- Modify: reader files (see Step 4 grep)
- Modify: `Tests/UnitTests/AgentBridgeTests.swift` (add RuntimeState default-value test + `setIPCClient` propagation test)

**Interfaces:**
- Consumes: Task 0 (`runtimeState` ref, `RuntimeState` class).
- Produces: `bridge.runtimeState.{isConnected,isExecuting,events}` read path. AgentBridge main-class @Published block now EMPTY (all 48 migrated across phases 1-7).

**Props moved this phase (3):** `isConnected`, `isExecuting`, `events` → `RuntimeState`.

**Note:** `dashboardData` moved to Phase 6 (AgentState, its sole writer AgentOpsService:235) — original spec mis-placed it here as the 1 cross-domain write; correcting it eliminated the cross-domain write. Phase 7 drops to 3 props.

**Key facts:** Written by main-class funcs (`checkHealth` writes `isConnected`; `executeGraph` writes `events`/`isExecuting`; `fetchTasks` appends to `events`). **`setIPCClient` assigns `client.$isConnected` to `$isConnected`** — must reassign to `$runtimeState.isConnected` (only place a `@Published` sink target changes).

- [ ] **Step 1: Write failing test — RuntimeState defaults + setIPCClient propagation**

Append to `Tests/UnitTests/AgentBridgeTests.swift`:

```swift
    // F-A1 Phase 7: RuntimeState 3 @Published 初值 (dashboardData 在 Phase 6 AgentState)。
    func testRuntimeStateDefaults() {
        let bridge = AgentBridge()
        XCTAssertFalse(bridge.runtimeState.isConnected)
        XCTAssertFalse(bridge.runtimeState.isExecuting)
        XCTAssertTrue(bridge.runtimeState.events.isEmpty)
    }

    // F-A1 Phase 7: setIPCClient 经 client.$isConnected 赋值到 $runtimeState.isConnected (sink 目标重定向)。
    func testSetIPCClientPropagatesConnectedToRuntimeState() {
        let bridge = AgentBridge()
        let client = IPCClient()
        bridge.setIPCClient(client)
        client.isConnected = true
        // Combine sink 经 DispatchQueue.main 异步 — 轮询最多 1s。
        let exp = expectation(description: "isConnected propagates to runtimeState")
        let deadline = Date().addingTimeInterval(2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
        XCTAssertTrue(bridge.runtimeState.isConnected, "setIPCClient must sink client.isConnected into runtimeState.isConnected")
    }
```

Run: `swift test --filter AgentBridgeTests 2>&1 | tail -15`
Expected: FAIL — props not on `runtimeState` yet (compile error or wrong path).

- [ ] **Step 2: Move 3 @Published into RuntimeState**

In `FusionStudio/System/AgentBridgeDomains.swift`, replace the empty `RuntimeState` class (copy exact types from grep):

Run: `grep -n "var isConnected\|var isExecuting\|var events" FusionStudio/System/AgentBridge.swift`

```swift
// MARK: - Runtime State (连接 / 执行 / 事件)

final class RuntimeState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var isExecuting: Bool = false
    @Published var events: [/* type from grep */] = /* default */
    init() {}
}
```

(Engineer fills `/* type */` for `events` from grep — investigator verified `[AgentEventModel]` @L326, default `[]`. Confirm against grep; fix if differs. `isConnected`/`isExecuting` are `Bool = false` @L324/327 — given.)

In `FusionStudio/System/AgentBridge.swift`, delete the 3 original `@Published` declarations. AgentBridge main-class @Published block is now EMPTY (all 48 migrated).

- [ ] **Step 3: Shift main-class writes to `self.runtimeState.X` + reassign setIPCClient sink**

Find all writes (main class only — no facade writes runtime props; `dashboardData` write is AgentOpsService:235, already migrated in Phase 6):

Run: `grep -n "self\.isConnected\|self\.isExecuting\|self\.events" FusionStudio/System/AgentBridge.swift`

Replace each `self.isConnected` → `self.runtimeState.isConnected`, `self.isExecuting` → `self.runtimeState.isExecuting`, `self.events` → `self.runtimeState.events`. Whole-word; `self.runtimeState.X` not yet present, no collision.

**Reassign `setIPCClient` sink** — find the assignment:

Run: `grep -n "\$isConnected\|setIPCClient\|assign(to:" FusionStudio/System/AgentBridge.swift`

Change `$isConnected` → `$runtimeState.isConnected` in the `setIPCClient` func (e.g. `client.$isConnected.assign(to: &$runtimeState.isConnected)` or `.sink { self.runtimeState.isConnected = $0 }` — match existing Combine form, only redirect target from `isConnected`/`self.isConnected` to `runtimeState.isConnected`/`self.runtimeState.isConnected`).

- [ ] **Step 4: Rename reader files via routing table**

Find all reader sites:

Run: `grep -rln "\.isConnected\b\|\.isExecuting\b\|\.events\b" FusionStudio/ | sort -u`

Known readers (verify against grep): `AgentStudioView`, `DeskView`, `PluginEcosystem`/`EcosystemSyncPanel`, doc sidebar views, `AgentDashboardViews`. Per file, replace `bridge.isConnected`/`agentBridge.isConnected` → `bridge.runtimeState.isConnected`/`agentBridge.runtimeState.isConnected`, `bridge.isExecuting` → `bridge.runtimeState.isExecuting`, `bridge.events` → `bridge.runtimeState.events`. Anchor on `bridge.`/`agentBridge.` prefix.

**Caution:** `\.isConnected\b` and `\.events\b` are common — `isConnected` may appear on `IPCClient` reads (leave `client.isConnected`/`ipcClient.isConnected` unchanged — those are IPCClient, not AgentBridge). The `bridge.`/`agentBridge.` prefix anchors to AgentBridge read-sites; verify each hit is `bridge.isConnected` (AgentBridge @Published) before replacing. `\.events\b` may match SwiftUI `.events` — `bridge.events`/`agentBridge.events` prefix disambiguates.

**Exclusion:** `client.isConnected` / `ipcClient?.isConnected` / `IPCClient.isConnected` — leave unchanged (IPCClient's own @Published, not AgentBridge's). `dashboardData` readers migrated in Phase 6, not here.

- [ ] **Step 5: Verify no stale references**

Run: `grep -rn "bridge\.isConnected\b\|bridge\.isExecuting\b\|bridge\.events\b\|agentBridge\.isConnected\b\|agentBridge\.isExecuting\b\|agentBridge\.events\b\|self\.isConnected\b\|self\.isExecuting\b\|self\.events\b" FusionStudio/`
Expected: 0 matches for `bridge.X`/`agentBridge.X`/`self.X` forms. (`client.isConnected`/`ipcClient.isConnected` legitimately remain — those are IPCClient, excluded.)

- [ ] **Step 6: Verify AgentBridge @Published block fully emptied**

Run: `grep -n "@Published" FusionStudio/System/AgentBridge.swift`
Expected: 0 `@Published` declarations on AgentBridge main class (all 48 migrated to domains). The 7 `let` domain refs remain. If any `@Published` remains, it was missed — trace to its phase, migrate it.

- [ ] **Step 7: Build debug + release, run tests**

Run: `swift build -c debug 2>&1 | tail -5; echo "DEBUG_EXIT=$?"`
Run: `swift build -c release 2>&1 | tail -5; echo "RELEASE_EXIT=$?"`
Run: `swift test 2>&1 | tail -15`
Expected: DEBUG_EXIT=0, RELEASE_EXIT=0, tests 193/193 (184 baseline + 9 domain tests: 2 ref + 1×7 domains; adjust count if a phase's test count differs).

- [ ] **Step 8: Commit**

```bash
git add -A FusionStudio/System/AgentBridgeDomains.swift FusionStudio/System/AgentBridge.swift Tests/UnitTests/AgentBridgeTests.swift
# add reader files modified in Step 4 per grep
git commit -m "refactor(audit): F-A1 Phase 7 RuntimeState move 3 @Published + setIPCClient sink (FINAL)

Moves isConnected/isExecuting/events into RuntimeState
domain. Main-class writes reach self.runtimeState.X. setIPCClient
sink target reassigned \$isConnected -> \$runtimeState.isConnected.
AgentBridge main-class @Published block now empty (all 48 migrated
across 7 domains). F-A1/F-I1 type-boundary refactor complete."
```

---

## Task 8: PR — push, CI, merge

**Files:** none (git/gh ops only).

- [ ] **Step 1: Final build gate (full)**

Run: `swift build -c debug 2>&1 | tail -5; echo "DEBUG_EXIT=$?"`
Run: `swift build -c release 2>&1 | tail -5; echo "RELEASE_EXIT=$?"`
Run: `swift test 2>&1 | tail -15`
Expected: DEBUG_EXIT=0, RELEASE_EXIT=0, all tests pass. Local Swift more lenient than CI macos-14 → release build MUST pass.

- [ ] **Step 2: Push branch + create PR**

```bash
git push -u origin HEAD
gh pr create --title "refactor(audit): F-A1/F-I1 AgentBridge type-boundary (state-split 7 domains)" --body "Audit 0825 F-A1 + F-I1 (验收 P0 阻断, 同根). 48 @Published 拆 7 独立 ObservableObject 域 (RuntimeState/MLXState/AgentState/ModuleState/TaskState/ConfigState/ProjectChatState) in AgentBridgeDomains.swift. AgentBridge 退为协调者持 let 域引用; facade 保持 extension AgentBridge 经 self.<state>.X reach-through. SwiftUI 经 body 内 bridge.<state>.X 自动追踪域 (每域独立重绘粒度 = 审计根治). 0 跨域写确认, 0 \$binding, 复用 F-A5 PR#315 已验证模式.

Phased: Phase 0 scaffold + Phases 1-7 (one domain per commit, build-gated each). 38 reader files + ChatSessionStore renamed per routing table. 9 new domain tests.

Spec: docs/superpowers/specs/2026-08-26-fa1-type-boundary-design.md
Plan: docs/superpowers/plans/2026-08-26-fa1-type-boundary.md

Closes audit F-A1, F-I1. 下版 v0.1.48." --label "refactor"
```

- [ ] **Step 3: Wait CI 3/3, then merge**

Run: `gh pr view <PR-NUM> --json statusCheckRollup -q '.statusCheckRollup'` (poll until complete)
Expected: Code Quality ✓ + Security Audit ✓ + Swift Build & Test ✓.
Run: `gh pr merge <PR-NUM> --merge --delete-branch` (direct merge authorized).
Expected: merged, branch deleted.

- [ ] **Step 4: Update memory + MEMORY.md**

Write `audit-fa1-fi1-type-boundary.md` memory (per F-A5 memory precedent): PR#, merge SHA, branch, 7 domains + 48 props + 38 readers, phased commit count, build/CI status, lessons (SourceKit false positives, release-gate caught), next-version v0.1.48. Add one-line pointer to `MEMORY.md`.

---
