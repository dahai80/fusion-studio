# Reusable Drag-Canvas Public Component — Design

## Context

**Problem.** Agent → Workflows → Create/Edit Workflow uses a **form-based** UI (`CreateWorkflowSheet`, `EditWorkflowSheet` in `FusionStudio/Modules/AgentStudio/AgentTaskViews.swift`): user types node IDs, picks types from pickers, adds one node/edge row at a time. This is not a langflow-style graphical drag editor. User wants drag-to-build.

**Existing canvases (evaluated):**

| File | LOC | Real drag editor? | Backend model | Wired? |
|---|---|---|---|---|
| `WorkflowDagCanvas.swift` (CoWork) | 112 | No — synthetic decorative thumbnail generated from `nodeCount` | none | yes (read-only widget) |
| `DAGCanvasView.swift` (DAG/) | 557 | Partial — node drag + edge-draw + context-add + Run/Save, but no pan/zoom, no click-port-connect, no inspector | Agent `NodeConfigModel`/`EdgeModel` | No — dead code, zero callers |
| `FSBWorkflowCanvasView.swift` (FSB) | 1120 | **Yes — full UX**: drag-from-palette drop, click-port-to-connect edge, pan/zoom, grid, topo-sort autoLayout, run-sim, per-type inspector, layout persist | FSB `FSBGraphNode`/`FSBGraphEdge` + `ipc.fsb.*` | yes (FSB module) |

**Decision (user-approved):** `FSBWorkflowCanvasView` is the best drag UX. Extract its interaction shell into a **generic reusable public component** parameterized by a protocol (node types, model shape, persist/load callbacks). FSB and Agent each supply an adapter. Replace Agent's form-based Create/Edit with the Agent adapter. **Inline detail pane** (not modal sheet) — langflow-style persistent workspace with list on left. **Delete** the dead half-built `DAGCanvasView.swift`.

**Outcome.** One shared `WorkflowCanvasView` component, two adapters, Agent Workflows gets graphical drag editing, FSB behavior preserved 1:1, no duplicate canvas code, dead DAGCanvasView removed.

## Global Constraints

- Only modify fusion-studio repo.
- 4-space multiples indent, no docstrings, clean code, `os.log` logging on every non-trivial path.
- Build gate (TRUTH): `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0. Local `swift test`=0 (toolchain drift Swift 6.3.3/macOS 26); CI macOS-14/Xcode 15.x authoritative.
- i18n: every user-visible string → `I18nKey` enum case in `FusionStudio/Common/I18nService.swift` + entry in all 4 lang JSON (`en-US.json`, `zh-CN.json`, `ja-JP.json`, `ko-KR.json`).
- Zero external Swift dependencies (Package.swift unchanged).
- Never print api_key to stdout/transcript.
- FSB refactor must preserve behavior 1:1: fsbSaveCanvasLayout debounce, graphDefinition shape, all fsb.* RPC signatures.
- Match existing patterns: `@Environment(\.studioTheme)`, `FusionButton`, `FusionCard`, `Logger(subsystem: "com.fusion.studio", category:)`.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  AgentStudioView  (Workflows tab, index 2)              │
│   └─ WorkflowListView  (HSplitView)                     │
│        ├─ workflowListPanel (left)  ── select/create    │
│        └─ detail area (right)                           │
│             state: .empty | .editing(graph?) | .creating │
│             └─ AgentWorkflowCanvasView                  │
│                  └─ WorkflowCanvasView<AgentNodeType>   │  ◄── shared shell
│                       (drag/drop, port-connect,         │
│                        pan/zoom, grid, autoLayout, run) │
│                  adapter: AgentWorkflowCanvasDelegate   │
│                       save/load → bridge graph API      │
│                                                         │
│  FSB module (unchanged surface):                        │
│   └─ FSBWorkflowCanvasView (wrapper, ~300 LOC)          │
│        └─ WorkflowCanvasView<FSBNodeType>  ◄── same shell│
│        adapter: FSBWorkflowCanvasDelegate               │
│                       save/load → ipc.fsb.* RPC         │
└─────────────────────────────────────────────────────────┘
```

**Layers:**
1. **Shared shell** `WorkflowCanvasView<NodeType>` — pure interaction (drag, connect, pan, zoom, autoLayout, run-sim). Knows nothing about FSB or Agent backends. Owns all canvas `@State` (offset/scale/connectingFrom/mousePos/selectedNodeId/...).
2. **Shared types** `CanvasNode<NodeType>` / `CanvasEdge` — generic value types the shell mutates. Decoupled from both FSBGraphNode and NodeConfigModel.
3. **Protocol** `WorkflowCanvasDelegate` — the adapter boundary. Shell calls delegate for: type metadata (icon/color/name), id generation, config-inspector view, and persistence (save/load). Each backend supplies a concrete delegate.
4. **FSB adapter** — `FSBWorkflowCanvasDelegate`: converts CanvasNode↔FSBGraphNode, calls `ipc.fsb.*`, supplies the 5 per-type inspector sections (connector/skill/condition/approval/output).
5. **Agent adapter** — `AgentWorkflowCanvasDelegate`: converts CanvasNode↔NodeConfigModel (fills `position`), calls `bridge.createGraph`/`updateGraph`/`graphGet`, supplies minimal inspector (label + type + config JSON for v1).

## Component: WorkflowCanvasView (generic shell)

Generic over `NodeType: Hashable, CaseIterable, RawRepresentable where RawValue == String`.

```swift
struct WorkflowCanvasView<Delegate: WorkflowCanvasDelegate>: View where Delegate.NodeType: Hashable, Delegate.NodeType: CaseIterable, Delegate.NodeType: RawRepresentable, Delegate.NodeType.RawValue == String {
    @ObservedObject var delegate: Delegate
    let graphNameBinding: Binding<String>
    let onSave: () -> Void           // post-save callback (e.g. refresh list)
    // internal @State: nodes, edges, canvasOffset, canvasScale, connectingFrom,
    //   mousePos, selectedNodeId, hoveredNodeId, showAddNode, addNodePos,
    //   isRunning, runningNodeId, inspectorReadOnly, layoutSaveTask, lastSavedPositions
}
```

**View structure** (lifted verbatim from FSBWorkflowCanvasView, de-FSB'd):
- `canvasToolbar` — name field + autoLayout/saveLayout/testRun/save buttons (labels via delegate metadata where type-specific).
- `nodePalette` — `ForEach(delegate.canvasNodeTypes)` items, `.onDrag` provider carrying `type.rawValue`, hint texts.
- `canvasArea` — grid background + `TimelineView(.animation)` Canvas drawing edges + live connect-preview curve + `nodeOverlay`.
- `nodeOverlay` — `ForEach(nodes)` → `nodeCard` positioned by offset/scale, `.gesture(nodeDragGesture)`, `.onTapGesture select`, `.onHover`.
- `nodeCard` — outputPort (click → start connect) + icon + label + inputPort (click → complete connect). Inspector toggle lives in config panel.
- `nodeConfigPanel` — name TextField + `delegate.configSection(for:)` + delete button. Shown when `selectedNodeId != nil`.
- `addNodeSheet` + `canvasContextMenu` — type grid / context add.
- Gestures: `canvasPanGesture`, `canvasMagnifyGesture`, `nodeDragGesture` (all unchanged from FSB).
- `autoLayout` / `topologicalSort` — unchanged, operate on CanvasNode/CanvasEdge.
- `runTest` — unchanged sim.
- `saveCanvasLayout` / `scheduleLayoutSave` — **delegated**: shell calls `delegate.persistLayout(...)`; FSB adapter keeps the debounced fsbSaveCanvasLayout; Agent adapter persists positions into the graph's node.config or a layout field (v1: fold into config["position"], same as FSB mergeConfig).

## CanvasNode / CanvasEdge (shared value types)

```swift
struct CanvasNode<NodeType: Hashable & RawRepresentable>: Identifiable where NodeType.RawValue == String {
    let id: String
    var type: NodeType
    var label: String
    var position: CGPoint
    var config: [String: JSONValue]     // JSONValue from AgentBridge.swift
    init(id: String = "n_\(UUID().uuidString.prefix(8))", type: NodeType, label: String, position: CGPoint, config: [String: JSONValue] = [:])
}

struct CanvasEdge: Identifiable {
    let id: String
    var sourceId: String
    var targetId: String
    var condition: String?
    init(id: String = "e_\(UUID().uuidString.prefix(8))", sourceId: String, targetId: String, condition: String? = nil)
}
```

`JSONValue` (existing, `AgentBridge.swift:48`) is already `Codable, Equatable` and used by `NodeConfigModel.config`. Reuse it — no new type. FSB's `[String: Any]` config converts to `[String: JSONValue]` in the adapter (FSB graphDefinition round-trips JSON dicts).

## WorkflowCanvasDelegate protocol

```swift
@MainActor
protocol WorkflowCanvasDelegate: AnyObject, ObservableObject {
    associatedtype NodeType: Hashable, CaseIterable, RawRepresentable where NodeType.RawValue == String

    var canvasNodeTypes: [NodeType] { get }
    func displayName(_ t: NodeType) -> String
    func icon(_ t: NodeType) -> String
    func color(_ t: NodeType) -> Color
    func defaultLabel(_ t: NodeType) -> String
    func nodeID() -> String
    func edgeID(from: String, to: String) -> String
    func toolbarLabel(_ kind: CanvasToolbarLabel) -> String

    // nil = no config section for this type
    @ViewBuilder func configSection(for node: Binding<CanvasNode<NodeType>>) -> AnyView?

    // full graph save (toolbar Save)
    func save(graphName: String, nodes: [CanvasNode<NodeType>], edges: [CanvasEdge]) async throws
    // initial load (existing graph)
    func load() async throws -> (name: String, nodes: [CanvasNode<NodeType>], edges: [CanvasEdge])
    // debounced layout-only persist (drag end)
    func persistLayout(_ layout: [String: CGPoint]) async
}
```

`@ViewBuilder func configSection` returns `AnyView?` because the shell is generic and cannot know the concrete inspector view. Adapter wraps its per-type SwiftUI in `AnyView`. (Swift `@ViewBuilder` + protocol + associatedtype + AnyView is the established pattern for type-erased subviews in SwiftUI.)

## FSB adapter

`FSBWorkflowCanvasDelegate: ObservableObject` (new file `FusionStudio/Modules/FSB/FSBWorkflowCanvasDelegate.swift`):
- `NodeType = FSBNodeType` (the 7 FSB types, moved to stay in FSB module or shared — see File structure).
- `canvasNodeTypes = FSBNodeType.allCases`.
- `displayName/icon/color/defaultLabel` — verbatim from current FSBWorkflowCanvasView enum (i18n via `.fsb_cv_node_*` keys).
- `configSection` — returns the 5 existing inspector sections (connector/skill/condition/approval/output) as `AnyView`. Bodies copied verbatim from current FSB file; they read `node.config` (now `[String: JSONValue]`).
- `save` — builds graphDefinition dict (same shape as current `saveWorkflow`), calls `ipc.fsbCreateWorkflow`/`fsbUpdateWorkflow`.
- `load` — calls `ipc.fsbGetWorkflow` + `fsbListConnectors`/`fsbListSkills`, parses graphDefinition → CanvasNode/CanvasEdge (same `parseNodePosition` logic).
- `persistLayout` — calls `ipc.fsbSaveCanvasLayout` (same debounce handled by shell's `scheduleLayoutSave`).
- Holds `ipc: IPCClient`, `workspaceId`, `workflowId`, `connectors`, `skills` as `@Published` for inspector pickers.

`FSBWorkflowCanvasView` shrinks to a thin wrapper (~60 LOC): instantiates `FSBWorkflowCanvasDelegate`, embeds `WorkflowCanvasView<FSBWorkflowCanvasDelegate>`, passes `workflowName` binding + `onSave`. FSB module's call sites unchanged.

## Agent adapter

`AgentWorkflowCanvasDelegate: ObservableObject` (new file `FusionStudio/Modules/AgentStudio/AgentWorkflowCanvasDelegate.swift`):
- `NodeType = AgentNodeType` (new enum, 11 cases from DAGCanvasView: start/llm/tool/condition/loop/end/errorHandler/retriever/router/memory/humanInLoop). Icon/color/displayName verbatim from DAGCanvasView's enum + AgentTaskViews `nodeTypeIcon/Color`.
- `configSection` (v1): minimal — label is edited in shell's name field; config section returns a read-only type display + optional config-JSON TextEditor for advanced users. nil for start/end (no config).
- `save`:
  - new graph → `bridge.createGraph(name:nodes:edges:)`, nodes mapped `CanvasNode → NodeConfigModel(id, type: rawValue, config, position: PositionModel(x,y))` (**fills position — the field CreateWorkflowSheet left nil**).
  - existing → `bridge.updateGraph(id:name:nodes:edges:)`.
- `load` → `bridge.graphGet(graphId:)` → map `NodeConfigModel → CanvasNode` (position from `PositionModel`, label from `config["label"]`).
- `persistLayout` — v1: fold positions into next full save (no separate layout RPC for Agent graphs; Agent graph API has no layout endpoint). `persistLayout` is a no-op for Agent (positions saved on full Save). Shell still calls it; adapter logs "layout persisted on next save".
- Holds `bridge: AgentBridge`, `graphId: String?`, `graphName`.

`AgentWorkflowCanvasView` (new file `FusionStudio/Modules/AgentStudio/AgentWorkflowCanvasView.swift`, ~80 LOC): instantiates delegate, embeds `WorkflowCanvasView<AgentWorkflowCanvasDelegate>`, adds an Execute strip (input + Run button + result) below or in toolbar — reusing `WorkflowDetailView`'s execute logic.

## Wiring into WorkflowListView / WorkflowDetailView

`WorkflowListView` detail area becomes a state machine (no sheets for create/edit):

```swift
private enum DetailMode {
    case empty
    case creating                              // new canvas, unsaved
    case editing(AgentGraphModel)              // existing graph canvas
}
@State private var detailMode: DetailMode = .empty
```

- List panel: tapping a graph → `detailMode = .editing(graph)`. "Create Workflow" button → `detailMode = .creating`.
- Detail area switch:
  - `.empty` → `emptyWorkflowPlaceholder` (current).
  - `.creating` → `AgentWorkflowCanvasView(mode: .create, onSave: { detailMode = .editing(fresh) ; await refreshGraphs() })`.
  - `.editing(graph)` → `AgentWorkflowCanvasView(mode: .edit(graph), onSave: { await refreshGraphs() })`.
- `CreateWorkflowSheet` + `EditWorkflowSheet` deleted; their create/update bridge calls move into the delegate's `save`.
- `WorkflowDetailView` (form-based node/edge read-only list + Execute card) deleted — its Execute logic moves into `AgentWorkflowCanvasView`. The graph's nodes/edges are now visualized in the canvas, not listed.

## Deletions

- `CreateWorkflowSheet` (AgentTaskViews.swift:1344) — removed.
- `EditWorkflowSheet` (AgentTaskViews.swift, ~the block before CreateWorkflowSheet) — removed.
- `WorkflowDetailView` (AgentTaskViews.swift:961) — removed (Execute logic relocated to AgentWorkflowCanvasView).
- `DAGCanvasView.swift` (DAG/, 557 LOC, zero callers) — deleted entirely. Its `DAGNode`/`DAGEdge`/`DAGLayout`/`DAGViewModel`/`DAGNodeCard` all die; their useful bits (node types, icons) move into `AgentNodeType`.
- `WorkflowDagCanvas.swift` (CoWork) — **left as-is**. It's a decorative SpaceListView widget, not a workflow editor; out of scope.

## i18n

New `I18nKey` cases for Agent canvas (namespace `wf_cv_*` to mirror `fsb_cv_*`):
- `wf_cv_node_start/llm/tool/condition/loop/end/error_handler/retriever/router/memory/human_in_loop` (11 node-type display names)
- `wf_cv_wfName`, `wf_cv_autoLayout`, `wf_cv_saveLayout`, `wf_cv_testRun`, `wf_cv_running`, `wf_cv_saving`, `wf_cv_nodeTypes`, `wf_cv_hintDrag`, `wf_cv_hintRightClick`, `wf_cv_hintConnect`, `wf_cv_nodeName`, `wf_cv_deleteNode`, `wf_cv_inspectorReadOnly`, `wf_cv_inspectorEdit`, `wf_cv_config`, `wf_cv_newWorkflow`
- Reuse generic `.save`, `.close` already present.

Each new case → entry in all 4 lang JSON. English source-of-truth; zh-CN/ja-JP/ko-KR translated. FSB's existing `fsb_cv_*` keys stay (FSB adapter reuses them) — no duplication: shell uses delegate's `displayName` which routes to the adapter's keys.

The shared shell itself is **i18n-agnostic**: it calls `delegate.displayName(type)` and uses a few generic keys (autoLayout/saveLayout/testRun/...). Those generic canvas-action keys — define as `cv_*` shared keys used by BOTH FSB and Agent shells? **Decision: NO** — keep FSB on `fsb_cv_*` (existing, don't churn FSB i18n) and Agent on `wf_cv_*`. The shell receives toolbar labels via delegate too: add `func toolbarLabel(_ kind: CanvasToolbarLabel) -> String` to the protocol (kinds: autoLayout, saveLayout, testRun, save, running, saving, nodeTypes, hintDrag, hintRightClick, hintConnect, nodeName, deleteNode, inspectorReadOnly, inspectorEdit). Each adapter maps to its own keys. Shell stays string-free.

## File structure

### New files
- `FusionStudio/Components/WorkflowCanvasView.swift` (~900 LOC) — generic shell + `CanvasNode`/`CanvasEdge` types + `CanvasToolbarLabel` enum.
- `FusionStudio/Modules/FSB/FSBWorkflowCanvasDelegate.swift` (~250 LOC) — FSB adapter + FSBNodeType (moved here from FSBWorkflowCanvasView).
- `FusionStudio/Modules/AgentStudio/AgentWorkflowCanvasDelegate.swift` (~180 LOC) — Agent adapter + AgentNodeType.
- `FusionStudio/Modules/AgentStudio/AgentWorkflowCanvasView.swift` (~120 LOC) — wrapper + Execute strip.

### Modified files
- `FusionStudio/Modules/FSB/FSBWorkflowCanvasView.swift` — 1120 → ~60 LOC thin wrapper.
- `FusionStudio/Modules/AgentStudio/AgentTaskViews.swift` — delete WorkflowDetailView/EditWorkflowSheet/CreateWorkflowSheet; WorkflowListView detail area → state machine. ~700 LOC removed, ~40 added.
- `FusionStudio/Common/I18nService.swift` — add `wf_cv_*` + `CanvasToolbarLabel`-mapped keys (via delegate) cases to `I18nKey` enum.
- `FusionStudio/Resources/i18n/{en-US,zh-CN,ja-JP,ko-KR}.json` — add new key entries.

### Deleted files
- `FusionStudio/DAG/DAGCanvasView.swift` (557 LOC).

### SPM
- `Package.swift` uses directory-based sources (confirm in Phase 1) — new files auto-include; deleted file auto-excluded.

## Phased execution

Build-gate checkpoint after each phase: `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0.

- **Phase 1 — Shared shell + types, FSB green.** Create `WorkflowCanvasView.swift` with generic shell + CanvasNode/CanvasEdge/CanvasToolbarLabel + protocol. Create `FSBWorkflowCanvasDelegate.swift` (move FSBNodeType + inspector + fsb RPC). Shrink `FSBWorkflowCanvasView.swift` to wrapper. FSB module compiles + behavior identical. Build gate. **Manual FSB smoke: open FSB workflow, drag/connect/save.**
- **Phase 2 — Agent adapter + wrapper.** Create `AgentNodeType` + `AgentWorkflowCanvasDelegate` + `AgentWorkflowCanvasView` (with Execute strip). Not yet wired into WorkflowListView. Build gate (compiles standalone).
- **Phase 3 — Wire Agent Workflows + delete forms.** WorkflowListView state machine; route create/edit to AgentWorkflowCanvasView; delete WorkflowDetailView/EditWorkflowSheet/CreateWorkflowSheet. Build gate.
- **Phase 4 — Delete DAGCanvasView.** Remove file; confirm no references. Build gate.
- **Phase 5 — i18n.** Add `wf_cv_*` + toolbar-label keys to I18nKey enum + 4 lang JSON. Build gate. **Manual Agent smoke: create workflow via drag, save, reopen, execute.**
- **Phase 6 — cleanup + final gate.** Remove dead comments, verify. Full build gate + `swift build --build-tests`.

## Risks & mitigations

1. **Generic + associatedtype + AnyView complexity.** Swift protocol with associatedtype + `@ViewBuilder func → AnyView?` is fiddly. Mitigation: delegate is `ObservableObject` (not a struct protocol), shell takes `@ObservedObject var delegate: Delegate` — concrete generic, no existential. AnyView only at the inspector boundary.
2. **FSB `[String:Any]` config → `[String:JSONValue]`.** FSB inspector pickers read `node.config["connectorKey"] as? String`. Conversion: adapter stores config as JSONValue; FSB-side reads use a small `jsonString(_:_:)` helper. Round-trip through fsb graphDefinition JSON dict preserved (JSONValue encodes to same JSON shape).
3. **FSB behavior regression.** fsbSaveCanvasLayout debounce + graphDefinition shape must not change. Mitigation: Phase 1 manual FSB smoke; adapter bodies copied verbatim where possible.
4. **Agent graph has no layout endpoint.** `persistLayout` is no-op for Agent; positions lost until full Save. Mitigation: shell's Save button always persists full graph incl. positions; auto-save-on-drag-end (like FSB) is Agent v2.
5. **WorkflowDetailView Execute logic relocation.** Must preserve `executeGraph` event rendering + cancelExecution. Mitigation: copy verbatim into AgentWorkflowCanvasView Execute strip.
6. **SPM source discovery.** Confirm `Package.swift` is directory-based before Phase 1; if explicit file list, add/delete accordingly.

## Verification

- **Per-phase build gate:** `swift build -c debug 2>&1 | tail -20` EXIT=0 AND `swift build --build-tests 2>&1 | tail -20` EXIT=0.
- **FSB smoke (Phase 1):** launch app → FSB module → open existing workflow → drag node, connect edge, autoLayout, save, reopen → positions + graph preserved.
- **Agent smoke (Phase 5):** launch app → Agent → Workflows → Create Workflow → drag palette node to canvas → connect ports → save → appears in list → reopen (edit) → positions preserved → Execute → events render.
- **CI (authoritative):** branch → GitHub Actions macOS-14 → Build&Test / Code Quality / Security Audit 3-green.
- **No dead refs:** after deletions, `grep -rn "DAGCanvasView\|CreateWorkflowSheet\|EditWorkflowSheet\|WorkflowDetailView" FusionStudio/` returns only comments/none.

## Branch / PR

- Branch: `feat/workflow-canvas-shared-component` (fork from master).
- PR title (EN): `feat(workflows): extract reusable drag-canvas component, add graphical Agent workflow editor`.
- Body: reference user request, FSB-vs-Agent-vs-DAG evaluation, shared shell + adapters, deletions, build-gate-green per phase.
- Merge: squash → master. Next release v0.1.63.
