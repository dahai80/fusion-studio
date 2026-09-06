# Reusable Drag-Canvas Public Component Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract FSBWorkflowCanvasView's drag UX into a generic reusable `WorkflowCanvasView<NodeType>` shell; add a graphical drag editor for Agent Workflows (replacing form-based sheets); delete dead DAGCanvasView.

**Architecture:** Generic SwiftUI shell parameterized by a `WorkflowCanvasDelegate` protocol (associatedtype NodeType + AnyView inspector). Two adapters: FSB (refactor existing, fsb.* RPC) and Agent (new, bridge graph API). Agent WorkflowListView routes create/edit to the Agent canvas inline in its HSplitView detail pane; form sheets deleted.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 14+, zero external deps. JSON-RPC 2.0 over UDS for FSB; AgentBridge graph API for Agent.

**Spec:** `docs/superpowers/specs/2026-09-06-workflow-canvas-shared-component-design.md`

## Global Constraints

- Only modify fusion-studio repo. 4-space multiples indent, no docstrings, `os.log` logging on every non-trivial path.
- Build gate (TRUTH): `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0. Local `swift test`=0 (toolchain drift); CI macOS-14/Xcode 15.x authoritative.
- i18n: every user-visible string → `I18nKey` case in `FusionStudio/Common/I18nService.swift` + entry in all 4 lang JSON (`en-US.json`/`zh-CN.json`/`ja-JP.json`/`ko-KR.json`).
- Zero external Swift deps. Package.swift uses directory-based sources (`path: "FusionStudio"`) — new files auto-include; no Package.swift edits.
- Never print api_key to stdout/transcript.
- FSB refactor preserves behavior 1:1: `fsbSaveCanvasLayout` debounce, graphDefinition shape, all fsb.* RPC signatures unchanged.
- Match existing patterns: `@Environment(\.studioTheme)`, `FusionButton`, `Logger(subsystem: "com.fusion.studio", category:)`, `I18nManager.shared.t(.key)`.

---

## File Structure

### New files
- `FusionStudio/Components/WorkflowCanvasView.swift` — generic shell + `CanvasNode`/`CanvasEdge`/`CanvasToolbarLabel` + `WorkflowCanvasDelegate` protocol. ~900 LOC.
- `FusionStudio/Modules/FSB/FSBWorkflowCanvasDelegate.swift` — FSB adapter + `FSBNodeType` (moved). ~250 LOC.
- `FusionStudio/Modules/AgentStudio/AgentWorkflowCanvasDelegate.swift` — Agent adapter + `AgentNodeType`. ~180 LOC.
- `FusionStudio/Modules/AgentStudio/AgentWorkflowCanvasView.swift` — wrapper + Execute strip. ~120 LOC.

### Modified
- `FusionStudio/Modules/FSB/FSBWorkflowCanvasView.swift` — 1120 → ~60 LOC thin wrapper.
- `FusionStudio/Modules/AgentStudio/AgentTaskViews.swift` — delete `WorkflowDetailView`/`EditWorkflowSheet`/`CreateWorkflowSheet`; `WorkflowListView` detail → state machine.
- `FusionStudio/Common/I18nService.swift` — add `wf_cv_*` + `CanvasToolbarLabel` cases to `I18nKey` enum.
- `FusionStudio/Resources/i18n/{en-US,zh-CN,ja-JP,ko-KR}.json` — new key entries.

### Deleted
- `FusionStudio/DAG/DAGCanvasView.swift` (557 LOC).

---

## Tasks

### Task 1: Shared types + protocol + CanvasToolbarLabel

**Files:**
- Create: `FusionStudio/Components/WorkflowCanvasView.swift` (types + protocol ONLY this task; shell view body in Task 2)

**Interfaces:**
- Consumes: `JSONValue` from `FusionStudio/System/AgentBridge.swift:48` (Codable, Equatable; cases string/double/bool/object/array; `var stringValue: String?`).
- Produces: `CanvasNode<NodeType>`, `CanvasEdge`, `CanvasToolbarLabel` enum, `WorkflowCanvasDelegate` protocol. Later tasks reference these names verbatim.

- [ ] **Step 1: Write the types + protocol skeleton**

Create `FusionStudio/Components/WorkflowCanvasView.swift`. Put ONLY these declarations (no view body yet):

```swift
import SwiftUI

struct CanvasNode<NodeType: Hashable & RawRepresentable>: Identifiable where NodeType.RawValue == String {
    let id: String
    var type: NodeType
    var label: String
    var position: CGPoint
    var config: [String: JSONValue]
    init(id: String = "n_\(UUID().uuidString.prefix(8))", type: NodeType, label: String, position: CGPoint, config: [String: JSONValue] = [:]) {
        self.id = id
        self.type = type
        self.label = label
        self.position = position
        self.config = config
    }
}

struct CanvasEdge: Identifiable {
    let id: String
    var sourceId: String
    var targetId: String
    var condition: String?
    init(id: String = "e_\(UUID().uuidString.prefix(8))", sourceId: String, targetId: String, condition: String? = nil) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
        self.condition = condition
    }
}

enum CanvasToolbarLabel: String, CaseIterable {
    case autoLayout, saveLayout, testRun, save, running, saving
    case nodeTypes, hintDrag, hintRightClick, hintConnect
    case nodeName, deleteNode, inspectorReadOnly, inspectorEdit, wfName
    case addNode
}

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

    @ViewBuilder func configSection(for node: Binding<CanvasNode<NodeType>>) -> AnyView?

    func save(graphName: String, nodes: [CanvasNode<NodeType>], edges: [CanvasEdge]) async throws
    func load() async throws -> (name: String, nodes: [CanvasNode<NodeType>], edges: [CanvasEdge])
    func persistLayout(_ layout: [String: CGPoint]) async
}
```

- [ ] **Step 2: Build gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build -c debug 2>&1 | tail -20`
Expected: EXIT=0 (protocol + types unused compile fine; no conformers yet).

- [ ] **Step 3: Commit**

```bash
git add FusionStudio/Components/WorkflowCanvasView.swift
git commit -m "feat(workflows): add shared CanvasNode/CanvasEdge + WorkflowCanvasDelegate protocol"
```

### Task 2: Generic shell view body

**Files:**
- Modify: `FusionStudio/Components/WorkflowCanvasView.swift` (add `WorkflowCanvasView<Delegate>` struct after the protocol)

**Interfaces:**
- Consumes: `WorkflowCanvasDelegate`, `CanvasNode`, `CanvasEdge`, `CanvasToolbarLabel` (Task 1). Exact FSB structure to mirror (see Source map below).
- Produces: `WorkflowCanvasView<Delegate>` view — FSB adapter (Task 3) and Agent adapter (Task 5) embed it.

**Source map (FSBWorkflowCanvasView.swift — copy interaction logic verbatim, de-FSB the types):**
- `@State` list: L15-36 (nodes/edges/selectedNodeId/hoveredNodeId/canvasOffset/canvasScale/connectingFrom/mousePos/connectors/skills/isSaving/showAddNode/addNodePos/isRunning/runningNodeId/inspectorReadOnly/layoutSaveTask/lastSavedPositions).
- `body` (VStack toolbar / HStack palette+canvas+configPanel / onAppear load / sheet addNode): L136-151.
- `canvasToolbar`: L158-209.
- `nodePalette` + `nodePaletteItem` + `.onDrag`: L211-307.
- `canvasArea` (grid + TimelineView Canvas drawEdges + connect-preview + nodeOverlay + `.gesture(canvasMagnifyGesture)` + `.onDrop`): L308-398.
- `drawEdges`: L335-389.
- `nodeOverlay` + `fsbNodeCard` + `outputPort` + `inputPort`: L399-546.
- `connectorConfigSection`/`skillConfigSection`/`conditionConfigSection`/`approvalConfigSection`/`outputConfigSection`: L547-758 (these move to the FSB adapter in Task 3 — NOT in shell).
- `canvasPanGesture`/`canvasMagnifyGesture`/`nodeDragGesture`: L760-820.
- `selectNode`/`addNodeAtPos`/`deleteNode`/`addEdge`/`updateNodeLabel`/`updateNodeConfig`/`autoLayout`/`topologicalSort`: L821-909.
- `loadWorkflow`/`scheduleLayoutSave`/`saveCanvasLayout`/`saveWorkflow`/`mergeConfig`/`runTest`/`handleDrop`: L911-1120 (load/save/persist move to delegates; drop/autoLayout/runTest stay in shell).

- [ ] **Step 1: Write the shell struct skeleton**

Add to `WorkflowCanvasView.swift`:

```swift
struct WorkflowCanvasView<Delegate: WorkflowCanvasDelegate>: View where Delegate.NodeType: Hashable, Delegate.NodeType: CaseIterable, Delegate.NodeType: RawRepresentable, Delegate.NodeType.RawValue == String {
    @ObservedObject var delegate: Delegate
    @Binding var graphName: String
    var onSave: () -> Void

    @State private var nodes: [CanvasNode<Delegate.NodeType>] = []
    @State private var edges: [CanvasEdge] = []
    @State private var selectedNodeId: String? = nil
    @State private var hoveredNodeId: String? = nil
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var connectingFrom: String? = nil
    @State private var mousePos: CGPoint = .zero
    @State private var isSaving = false
    @State private var showAddNode = false
    @State private var addNodePos: CGPoint = .zero
    @State private var isRunning = false
    @State private var runningNodeId: String? = nil
    @State private var inspectorReadOnly = true
    @State private var layoutSaveTask: Task<Void, Never>? = nil
    @State private var lastSavedPositions: [String: CGPoint] = [:]

    @Environment(\.studioTheme) var theme

    private let nodeWidth: CGFloat = 180
    private let nodeHeight: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            canvasToolbar
            Divider()
            HStack(spacing: 0) {
                nodePalette
                Divider()
                canvasArea
                if selectedNodeId != nil {
                    Divider()
                    nodeConfigPanel
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear { Task { try? await loadGraph() } }
        .sheet(isPresented: $showAddNode) { addNodeSheet }
    }
    // TODO Task 2 Step 2: fill body subviews + gestures + logic
}
```

- [ ] **Step 2: Fill subviews + gestures + logic (copy from FSB, de-FSB)**

Copy these from `FSBWorkflowCanvasView.swift` into the shell, applying the substitutions listed. Read each FSB line range with the Read tool first so the copy is exact.

**Substitution rules (apply to every copied block):**
- `FSBNodeType` → `Delegate.NodeType`.
- `FSBGraphNode` → `CanvasNode<Delegate.NodeType>`.
- `FSBGraphEdge` → `CanvasEdge`.
- `node.type` (was FSBNodeType) → unchanged (now generic NodeType).
- `node.config["k"] as? String` → `node.config["k"]?.stringValue`.
- `node.config["k"] = someString` → `node.config["k"] = .string(someString)`.
- `i18n.t(.fsb_cv_*)` literal labels → `delegate.toolbarLabel(.<kind>)` (kinds: autoLayout/saveLayout/testRun/running/saving/save/nodeTypes/hintDrag/hintRightClick/hintConnect/nodeName/deleteNode/inspectorReadOnly/inspectorEdit/wfName/addNode). For `.save` reuse `.save` → `delegate.toolbarLabel(.save)`.
- `FSBNodeType.allCases` in nodePalette → `delegate.canvasNodeTypes`.
- `type.icon`/`type.color`/`type.displayName` (computed props on enum) → `delegate.icon(type)`/`delegate.color(type)`/`delegate.displayName(type)`.
- Inspector config sections (`connectorConfigSection` etc.) → NOT in shell. `nodeConfigPanel` calls `delegate.configSection(for:)` where FSB had the inline per-type switch.
- `loadWorkflow` → renamed `loadGraph`; body: `let (name, n, e) = try await delegate.load(); graphName = name; nodes = n; edges = e; lastSavedPositions = Dictionary(uniqueKeysWithValues: n.map { ($0.id, $0.position) })`.
- `saveCanvasLayout` → body: `let layout = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.position) }); await delegate.persistLayout(layout)`.
- `saveWorkflow` → renamed `saveGraph`; body: `isSaving = true; defer { isSaving = false }; do { try await delegate.save(graphName: graphName, nodes: nodes, edges: edges); onSave() } catch { log error }`.
- `runTest`/`handleDrop`/`autoLayout`/`topologicalSort`/`addNodeAtPos`/`deleteNode`/`addEdge`/`updateNodeLabel`/`updateNodeConfig`/`selectNode` → copy verbatim, apply substitution rules.
- `addNodeAtPos` id gen: `delegate.nodeID()`; `addEdge` id gen: `delegate.edgeID(from:to:)`.
- `.onDrop(of: ["com.fusion.fsb.node"], ...)` provider string → `["com.fusion.canvas.node"]` (shared).
- `.onDrag` provider carrying `type.rawValue` → unchanged (rawValue is String).
- `nodeConfigPanel` structure: name TextField (label `delegate.toolbarLabel(.nodeName)`) + `delegate.configSection(for: nodeBinding)` + inspectorReadOnly toggle (label `delegate.toolbarLabel(.inspectorReadOnly/Edit)`) + delete button (label `delegate.toolbarLabel(.deleteNode)`).
- Logger: `private let canvasLog = Logger(subsystem: "com.fusion.studio", category: "workflow-canvas")`.

- [ ] **Step 3: Build gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build -c debug 2>&1 | tail -30`
Expected: EXIT=0. (No conformer uses the shell yet, but it must typecheck. If `@ViewBuilder func configSection → AnyView?` causes issues, confirm `nodeConfigPanel` handles nil: `if let section = delegate.configSection(for: binding) { section }`.)

- [ ] **Step 4: Build tests gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build --build-tests 2>&1 | tail -20`
Expected: EXIT=0.

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Components/WorkflowCanvasView.swift
git commit -m "feat(workflows): generic WorkflowCanvasView shell (drag/drop/pan/zoom/autoLayout)"
```

### Task 3: FSB adapter

**Files:**
- Create: `FusionStudio/Modules/FSB/FSBWorkflowCanvasDelegate.swift`
- Modify: `FusionStudio/Modules/FSB/FSBWorkflowCanvasView.swift` → thin wrapper

**Interfaces:**
- Consumes: `WorkflowCanvasView`, `WorkflowCanvasDelegate`, `CanvasNode`, `CanvasEdge`, `CanvasToolbarLabel` (Tasks 1-2). `IPCClient` fsb RPC methods: `fsbListConnectors(wsId:)`/`fsbListSkills(wsId:)`/`fsbGetWorkflow(wsId:wfId:)`/`fsbCreateWorkflow(wsId:name:displayName:description:slashCommand:graphDefinition:)`/`fsbUpdateWorkflow(wsId:wfId:name:displayName:description:enabled:graphDefinition:schedule:)`/`fsbSaveCanvasLayout(wsId:wfId:layout:)` (all in `FusionStudio/Bridge/IPCErrorAndREST.swift`, return `[String: Any]` or `[[String: Any]]`).
- Produces: `FSBWorkflowCanvasDelegate` (ObservableObject) + `FSBNodeType` (moved out of FSBWorkflowCanvasView). FSB module call sites to `FSBWorkflowCanvasView(...)` unchanged.

- [ ] **Step 1: Move FSBNodeType + create delegate**

Create `FusionStudio/Modules/FSB/FSBWorkflowCanvasDelegate.swift`. Move `enum FSBNodeType` (FSBWorkflowCanvasView.swift L38-82) here verbatim — BUT make it top-level (not nested) so the adapter can name it. Keep `icon`/`color`/`displayName` computed props on the enum (adapter delegates to these or copies — keep on enum, adapter's `icon()`/`color()`/`displayName()` forward to `type.icon`/`type.color`/`type.displayName`).

Then add the delegate class:

```swift
@MainActor
final class FSBWorkflowCanvasDelegate: ObservableObject, WorkflowCanvasDelegate {
    typealias NodeType = FSBNodeType

    @Published var connectors: [[String: Any]] = []
    @Published var skills: [[String: Any]] = []
    let ipc: IPCClient
    let workspaceId: String
    var workflowId: String?
    @Published var workflowName: String = ""
    @Published var slashCommand: String = ""

    init(ipc: IPCClient, workspaceId: String, workflowId: String?) {
        self.ipc = ipc
        self.workspaceId = workspaceId
        self.workflowId = workflowId
    }

    var canvasNodeTypes: [FSBNodeType] { FSBNodeType.allCases }
    func displayName(_ t: FSBNodeType) -> String { t.displayName }
    func icon(_ t: FSBNodeType) -> String { t.icon }
    func color(_ t: FSBNodeType) -> Color { t.color }
    func defaultLabel(_ t: FSBNodeType) -> String { t.displayName }
    func nodeID() -> String { "n_\(UUID().uuidString.prefix(8))" }
    func edgeID(from: String, to: String) -> String { "e_\(UUID().uuidString.prefix(8))" }
    func toolbarLabel(_ kind: CanvasToolbarLabel) -> String {
        switch kind {
        case .autoLayout: return I18nManager.shared.t(.fsb_cv_autoLayout)
        case .saveLayout: return I18nManager.shared.t(.fsb_cv_saveLayout)
        case .testRun: return I18nManager.shared.t(.fsb_cv_testRun)
        case .running: return I18nManager.shared.t(.fsb_cv_running)
        case .saving: return I18nManager.shared.t(.fsb_cv_saving)
        case .save: return I18nManager.shared.t(.save)
        case .nodeTypes: return I18nManager.shared.t(.fsb_cv_nodeTypes)
        case .hintDrag: return I18nManager.shared.t(.fsb_cv_hintDrag)
        case .hintRightClick: return I18nManager.shared.t(.fsb_cv_hintRightClick)
        case .hintConnect: return I18nManager.shared.t(.fsb_cv_hintConnect)
        case .nodeName: return I18nManager.shared.t(.fsb_cv_nodeName)
        case .deleteNode: return I18nManager.shared.t(.fsb_cv_deleteNode)
        case .inspectorReadOnly: return I18nManager.shared.t(.fsb_cv_inspectorReadOnly)
        case .inspectorEdit: return I18nManager.shared.t(.fsb_cv_inspectorEdit)
        case .wfName: return I18nManager.shared.t(.fsb_cv_wfName)
        case .addNode: return I18nManager.shared.t(.fsb_cv_nodeTypes)
        }
    }
    // TODO Step 2: configSection, save, load, persistLayout
}
```

- [ ] **Step 2: configSection — port the 5 inspector sections**

Add to `FSBWorkflowCanvasDelegate`. Copy the 5 inspector section bodies verbatim from `FSBWorkflowCanvasView.swift` L547-758 (`connectorConfigSection`/`skillConfigSection`/`conditionConfigSection`/`approvalConfigSection`/`outputConfigSection`). Convert each to take `node: Binding<CanvasNode<FSBNodeType>>` and read/write via `node.wrappedValue.config["k"]?.stringValue` / `node.wrappedValue.config["k"] = .string(...)`. Keep `connectors`/`skills` @Published reads (now on the delegate, `self.connectors`).

`configSection(for:)`:

```swift
func configSection(for node: Binding<CanvasNode<FSBNodeType>>) -> AnyView? {
    switch node.wrappedValue.type {
    case .CONNECTOR_NODE: return AnyView(connectorConfigSection(node: node))
    case .SKILL_NODE: return AnyView(skillConfigSection(node: node))
    case .CONDITION_NODE: return AnyView(conditionConfigSection(node: node))
    case .APPROVAL_GATE_NODE: return AnyView(approvalConfigSection(node: node))
    case .OUTPUT_NODE: return AnyView(outputConfigSection(node: node))
    default: return nil
    }
}
```

- [ ] **Step 3: save / load / persistLayout — port FSB RPC logic**

Copy `loadWorkflow` (L911-981), `saveWorkflow` (L1020-1075), `saveCanvasLayout` (L991-1018), `mergeConfig` (L1077-1082), `parseNodePosition` (L117-134) bodies from FSBWorkflowCanvasView into the delegate, adapting:
- `nodes`/`edges`/`workflowName` are now method params/return (not @State): `save` takes `graphName:nodes:edges:` and maps CanvasNode→`[String:Any]` node dict (same shape `mergeConfig`/`saveWorkflow` builds — type=rawValue, label, position, config). `load` returns `(name, [CanvasNode], [CanvasEdge])` parsing `fsbGetWorkflow` result via `parseNodePosition` + config dict → `[String: JSONValue]` (convert each Any value to JSONValue: String→.string, Number→.double, Bool→.bool, dict→.object, array→.array).
- `persistLayout(_:)`: copy `saveCanvasLayout` body (build `layout: [String: [String: CGFloat]]`, call `ipc.fsbSaveCanvasLayout`). Debounce stays in shell's `scheduleLayoutSave`.
- `scheduleLayoutSave` debounce logic stays in the SHELL (Task delay 1.5s), not the delegate — delegate only does the network call.

- [ ] **Step 4: Shrink FSBWorkflowCanvasView to wrapper**

Replace the entire 1120-line `FSBWorkflowCanvasView` with a thin wrapper. Keep the same external init signature so call sites unchanged. Read existing call sites first: `grep -rn "FSBWorkflowCanvasView(" FusionStudio/` to capture the init params used.

```swift
struct FSBWorkflowCanvasView: View {
    @EnvironmentObject private var ipc: IPCClient
    let workspaceId: String
    var workflowId: String?
    @StateObject private var delegate: FSBWorkflowCanvasDelegate

    init(workspaceId: String, workflowId: String? = nil) {
        self.workspaceId = workspaceId
        self.workflowId = workflowId
        // IPCClient not available at init; injected in onAppear via setIPC
        _delegate = StateObject(wrappedValue: FSBWorkflowCanvasDelegate(ipc: IPCClient(), workspaceId: workspaceId, workflowId: workflowId))
    }

    var body: some View {
        WorkflowCanvasView(delegate: delegate, graphName: $delegate.workflowName) {}
            .onAppear { delegate.ipc = ipc }
    }
}
```
NOTE: if existing call sites pass `ipc` explicitly or the FSB view reads ipc differently, match the real signature found in grep. If `@EnvironmentObject ipc` is wrong (FSB may inject via `@EnvironmentObject`), confirm against the current `FSBWorkflowCanvasView` property declarations (read its L1-14).

- [ ] **Step 5: Build gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build -c debug 2>&1 | tail -30`
Expected: EXIT=0. Fix every FSB call site broken by the enum move / wrapper change.

- [ ] **Step 6: Build tests gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build --build-tests 2>&1 | tail -20`
Expected: EXIT=0.

- [ ] **Step 7: Commit**

```bash
git add FusionStudio/Modules/FSB/FSBWorkflowCanvasDelegate.swift FusionStudio/Modules/FSB/FSBWorkflowCanvasView.swift
git commit -m "refactor(fsb): extract FSBWorkflowCanvasDelegate, shrink FSBWorkflowCanvasView to wrapper"
```

### Task 4: FSB smoke verification (manual checkpoint)

**Files:** none (verification only)

- [ ] **Step 1: Build release app**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build -c debug 2>&1 | tail -5`
Expected: EXIT=0.

- [ ] **Step 2: Launch app + FSB module smoke**

Launch FusionStudio, navigate to FSB module, open an existing workflow (or create). Verify:
- Node palette shows 7 node types with icons.
- Drag a node from palette onto canvas — node appears.
- Click output port of one node, then input port of another — edge drawn.
- Pan (drag canvas bg) + zoom (magnify) work.
- AutoLayout button rearranges.
- Save button persists; reopen shows saved positions.
- Inspector panel shows per-type config (connector picker, skill picker, condition expr, approval, output).

If any regression: fix in `FSBWorkflowCanvasDelegate.swift` / `WorkflowCanvasView.swift` before proceeding. FSB behavior MUST be 1:1.

- [ ] **Step 3: Commit any fixes**

```bash
git add -A && git commit -m "fix(fsb): canvas adapter behavior alignment post-extract"
```
(or no commit if no fixes needed)

### Task 5: AgentNodeType + Agent adapter

**Files:**
- Create: `FusionStudio/Modules/AgentStudio/AgentWorkflowCanvasDelegate.swift`

**Interfaces:**
- Consumes: `WorkflowCanvasDelegate`, `CanvasNode`, `CanvasEdge`, `CanvasToolbarLabel` (Task 1-2). AgentBridge graph API: `bridge.createGraph(name:nodes:[NodeConfigModel]:edges:[EdgeModel]) → AgentGraphModel` (`AgentGraphService.swift:60`), `bridge.updateGraph(id:name?:nodes?:edges?:) → AgentGraphModel?` (L125), `bridge.graphGet(graphId:) → AgentGraphModel?` (L107). Models: `NodeConfigModel{id,type:String,config:[String:JSONValue],position:PositionModel?}` (AgentBridge.swift:107), `EdgeModel{id,source,target,condition:String?}` (L114), `PositionModel{x,y:Double}` (L102), `AgentGraphModel{id,name,nodes,edges,...}` (L121).
- Produces: `AgentNodeType` enum (11 cases), `AgentWorkflowCanvasDelegate` (ObservableObject). Task 6 embeds it.

- [ ] **Step 1: Write AgentNodeType enum**

In `AgentWorkflowCanvasDelegate.swift`, top-level enum (11 cases from `DAGCanvasView.swift` L22-23 + icon/color/displayName):

```swift
enum AgentNodeType: String, CaseIterable {
    case start, llm, tool, condition, loop, end
    case errorHandler, retriever, router, memory, humanInLoop

    var icon: String {
        switch self {
        case .start: return "play.circle.fill"
        case .llm: return "brain"
        case .tool: return "wrench.and.screwdriver"
        case .condition: return "arrow.triangle.branch"
        case .loop: return "arrow.clockwise"
        case .end: return "stop.circle.fill"
        case .errorHandler: return "exclamationmark.triangle"
        case .retriever: return "magnifyingglass"
        case .router: return "arrow.triangle.swap"
        case .memory: return "internaldrive"
        case .humanInLoop: return "person.crop.circle.badge.questionmark"
        }
    }
    var color: Color {
        switch self {
        case .start: return .green
        case .llm: return .purple
        case .tool: return .blue
        case .condition: return .orange
        case .loop: return .cyan
        case .end: return .gray
        case .errorHandler: return .red
        case .retriever: return .teal
        case .router: return .indigo
        case .memory: return .brown
        case .humanInLoop: return .pink
        }
    }
}
```

- [ ] **Step 2: Write AgentWorkflowCanvasDelegate**

```swift
@MainActor
final class AgentWorkflowCanvasDelegate: ObservableObject, WorkflowCanvasDelegate {
    typealias NodeType = AgentNodeType

    let bridge: AgentBridge
    var graphId: String?
    @Published var graphName: String = ""

    init(bridge: AgentBridge, graph: AgentGraphModel?) {
        self.bridge = bridge
        self.graphId = graph?.id
        self.graphName = graph?.name ?? ""
    }

    var canvasNodeTypes: [AgentNodeType] { AgentNodeType.allCases }
    func displayName(_ t: AgentNodeType) -> String { I18nManager.shared.t(t.i18nKey) }
    func icon(_ t: AgentNodeType) -> String { t.icon }
    func color(_ t: AgentNodeType) -> Color { t.color }
    func defaultLabel(_ t: AgentNodeType) -> String { displayName(t) }
    func nodeID() -> String { "n_\(UUID().uuidString.prefix(8))" }
    func edgeID(from: String, to: String) -> String { "e_\(UUID().uuidString.prefix(8))" }
    func toolbarLabel(_ kind: CanvasToolbarLabel) -> String {
        switch kind {
        case .autoLayout: return I18nManager.shared.t(.wf_cv_autoLayout)
        case .saveLayout: return I18nManager.shared.t(.wf_cv_saveLayout)
        case .testRun: return I18nManager.shared.t(.wf_cv_testRun)
        case .running: return I18nManager.shared.t(.wf_cv_running)
        case .saving: return I18nManager.shared.t(.wf_cv_saving)
        case .save: return I18nManager.shared.t(.save)
        case .nodeTypes: return I18nManager.shared.t(.wf_cv_nodeTypes)
        case .hintDrag: return I18nManager.shared.t(.wf_cv_hintDrag)
        case .hintRightClick: return I18nManager.shared.t(.wf_cv_hintRightClick)
        case .hintConnect: return I18nManager.shared.t(.wf_cv_hintConnect)
        case .nodeName: return I18nManager.shared.t(.wf_cv_nodeName)
        case .deleteNode: return I18nManager.shared.t(.wf_cv_deleteNode)
        case .inspectorReadOnly: return I18nManager.shared.t(.wf_cv_inspectorReadOnly)
        case .inspectorEdit: return I18nManager.shared.t(.wf_cv_inspectorEdit)
        case .wfName: return I18nManager.shared.t(.wf_cv_wfName)
        case .addNode: return I18nManager.shared.t(.wf_cv_nodeTypes)
        }
    }

    func configSection(for node: Binding<CanvasNode<AgentNodeType>>) -> AnyView? {
        // v1: minimal — start/end no config; others show read-only type + config-JSON editor
        switch node.wrappedValue.type {
        case .start, .end: return nil
        default: return AnyView(AgentNodeConfigSection(node: node))
        }
    }

    func save(graphName: String, nodes: [CanvasNode<AgentNodeType>], edges: [CanvasEdge]) async throws {
        let nodeModels = nodes.map { n in
            NodeConfigModel(id: n.id, type: n.type.rawValue, config: mergeLabelIntoConfig(n.config, label: n.label), position: PositionModel(x: n.position.x, y: n.position.y))
        }
        let edgeModels = edges.map { e in EdgeModel(id: e.id, source: e.sourceId, target: e.targetId, condition: e.condition) }
        if let gid = graphId {
            _ = try await bridge.updateGraph(id: gid, name: graphName, nodes: nodeModels, edges: edgeModels)
        } else {
            let created = try await bridge.createGraph(name: graphName, nodes: nodeModels, edges: edgeModels)
            self.graphId = created.id
        }
    }

    func load() async throws -> (name: String, nodes: [CanvasNode<AgentNodeType>], edges: [CanvasEdge]) {
        guard let gid = graphId, let g = try await bridge.graphGet(graphId: gid) else {
            return (graphName, [], [])
        }
        self.graphName = g.name
        let cnodes = g.nodes.map { nm in
            CanvasNode(id: nm.id, type: AgentNodeType(rawValue: nm.type) ?? .llm, label: labelFromConfig(nm.config), position: CGPoint(x: nm.position?.x ?? 0, y: nm.position?.y ?? 0), config: nm.config)
        }
        let cedges = g.edges.map { e in CanvasEdge(id: e.id, sourceId: e.source, targetId: e.target, condition: e.condition) }
        return (g.name, cnodes, cedges)
    }

    func persistLayout(_ layout: [String: CGPoint]) async {
        // Agent graph API has no layout endpoint; positions saved on full Save.
        agentCanvasLog.info("Agent workflow layout persisted on next full save (\(layout.count) nodes)")
    }

    private func mergeLabelIntoConfig(_ config: [String: JSONValue], label: String) -> [String: JSONValue] {
        var c = config
        c["label"] = .string(label)
        return c
    }
    private func labelFromConfig(_ config: [String: JSONValue]) -> String {
        config["label"]?.stringValue ?? ""
    }
}

private let agentCanvasLog = Logger(subsystem: "com.fusion.studio", category: "agent-workflow-canvas")
```

Add `var i18nKey: I18nKey` computed prop on `AgentNodeType` mapping each case to its `wf_cv_node_*` key (defined in Task 7). For Task 5 build, if `wf_cv_*` keys don't exist yet, use a temporary `displayName` returning `rawValue.capitalized` and add the i18nKey mapping in Task 7. **Decision: add `wf_cv_*` keys in Task 7; Task 5 uses `I18nManager.shared.t(t.i18nKey)` but the cases are added to `I18nKey` in Task 7 — to keep Task 5 build green, add the 11 `wf_cv_node_*` cases to `I18nKey` HERE (Task 5 Step 2b) with placeholder English, full 4-lang in Task 7.**

- [ ] **Step 2b: Add 11 wf_cv_node_* cases to I18nKey (placeholder en only, for green build)**

In `FusionStudio/Common/I18nService.swift`, add to `enum I18nKey` (near the `fsb_cv_node_*` cases ~L3257):

```swift
case wf_cv_node_start, wf_cv_node_llm, wf_cv_node_tool, wf_cv_node_condition
case wf_cv_node_loop, wf_cv_node_end, wf_cv_node_error_handler, wf_cv_node_retriever
case wf_cv_node_router, wf_cv_node_memory, wf_cv_node_human_in_loop
case wf_cv_wfName, wf_cv_autoLayout, wf_cv_saveLayout, wf_cv_testRun, wf_cv_running, wf_cv_saving
case wf_cv_nodeTypes, wf_cv_hintDrag, wf_cv_hintRightClick, wf_cv_hintConnect
case wf_cv_nodeName, wf_cv_deleteNode, wf_cv_inspectorReadOnly, wf_cv_inspectorEdit
case wf_cv_config, wf_cv_newWorkflow
```

Add `i18nKey` on AgentNodeType:
```swift
var i18nKey: I18nKey {
    switch self {
    case .start: return .wf_cv_node_start
    case .llm: return .wf_cv_node_llm
    case .tool: return .wf_cv_node_tool
    case .condition: return .wf_cv_node_condition
    case .loop: return .wf_cv_node_loop
    case .end: return .wf_cv_node_end
    case .errorHandler: return .wf_cv_node_error_handler
    case .retriever: return .wf_cv_node_retriever
    case .router: return .wf_cv_node_router
    case .memory: return .wf_cv_node_memory
    case .humanInLoop: return .wf_cv_node_human_in_loop
    }
}
```

The `I18nManager.t(.key)` for keys missing from JSON returns the raw key string — acceptable for green build; Task 7 fills all 4 lang JSON.

- [ ] **Step 3: AgentNodeConfigSection view**

Add a small view in the same file:

```swift
private struct AgentNodeConfigSection: View {
    @Binding var node: CanvasNode<AgentNodeType>
    @Environment(\.studioTheme) var theme
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(node.type.rawValue.uppercased())
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
    }
}
```

- [ ] **Step 4: Build gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build -c debug 2>&1 | tail -30`
Expected: EXIT=0.

- [ ] **Step 5: Build tests gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build --build-tests 2>&1 | tail -20`
Expected: EXIT=0.

- [ ] **Step 6: Commit**

```bash
git add FusionStudio/Modules/AgentStudio/AgentWorkflowCanvasDelegate.swift FusionStudio/Common/I18nService.swift
git commit -m "feat(workflows): add AgentWorkflowCanvasDelegate + AgentNodeType (11 node types)"
```

### Task 6: AgentWorkflowCanvasView wrapper + Execute strip

**Files:**
- Create: `FusionStudio/Modules/AgentStudio/AgentWorkflowCanvasView.swift`

**Interfaces:**
- Consumes: `WorkflowCanvasView`, `AgentWorkflowCanvasDelegate` (Task 5). `bridge.executeGraph(id:input:) → [AgentEventModel]` (`AgentGraphService` / AgentBridge), `bridge.cancelExecution()`. `AgentEventModel{type, node_id, data}` (AgentBridge.swift:205).
- Produces: `AgentWorkflowCanvasView` — embedded by `WorkflowListView` (Task 7).

- [ ] **Step 1: Write the wrapper + Execute strip**

```swift
struct AgentWorkflowCanvasView: View {
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    let mode: Mode
    var onSave: () -> Void
    let toastManager: FusionToastManager

    enum Mode { case create, edit(AgentGraphModel) }

    @StateObject private var delegate: AgentWorkflowCanvasDelegate
    @State private var executeInput = ""
    @State private var isExecuting = false
    @State private var executionResult = ""

    init(mode: Mode, toastManager: FusionToastManager, onSave: @escaping () -> Void) {
        self.mode = mode
        self.toastManager = toastManager
        self.onSave = onSave
        let graph: AgentGraphModel? = { if case .edit(let g) = mode { return g } else { return nil } }()
        _delegate = StateObject(wrappedValue: AgentWorkflowCanvasDelegate(bridge: AgentBridge(), graph: graph))
    }

    var body: some View {
        VStack(spacing: 0) {
            WorkflowCanvasView(delegate: delegate, graphName: $delegate.graphName) {
                onSave()
            }
            .environmentObject(bridge)
            Divider()
            executeStrip
        }
        .onAppear { delegate.bridge = bridge }
    }

    private var executeStrip: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingS) {
                TextField(I18nManager.shared.t(.wf_cv_testRun) + " input", text: $executeInput)
                    .textFieldStyle(.roundedBorder)
                Button(action: { executeGraph() }) {
                    Label(isExecuting ? I18nManager.shared.t(.wf_cv_running) : I18nManager.shared.t(.wf_cv_testRun), systemImage: isExecuting ? "stop" : "play")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExecuting || delegate.graphId == nil)
                .controlSize(.small)
                if isExecuting {
                    Button("Cancel") { bridge.cancelExecution() }
                        .controlSize(.small)
                }
            }
            ScrollView {
                Text(executionResult.isEmpty ? "—" : executionResult)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
        }
        .padding(theme.spacingS)
        .background(theme.contentBg)
    }

    private func executeGraph() {
        guard let gid = delegate.graphId else { return }
        isExecuting = true
        executionResult = ""
        Task {
            do {
                let events = try await bridge.executeGraph(id: gid, input: executeInput)
                var output = ""
                for ev in events {
                    let nodeId = ev.node_id ?? "?"
                    output += "[\(ev.type)] \(nodeId)"
                    if let data = ev.data, !data.isEmpty {
                        output += ": \(data.map { "\($0)=\($1)" }.joined(separator: " "))"
                    }
                    output += "\n"
                }
                if output.isEmpty { output = "Workflow completed (no events)" }
                executionResult = output
                toastManager.show(style: .success, title: "Workflow Complete", message: delegate.graphName)
            } catch {
                executionResult = "Error: \(error.localizedDescription)"
                toastManager.show(style: .error, title: "Execution Failed", message: error.localizedDescription)
            }
            isExecuting = false
        }
    }
}
```

NOTE: `AgentBridge()` placeholder init in `init` — replaced in `.onAppear` with the real `@EnvironmentObject bridge`. If `AgentBridge` has no parameterless init, capture bridge differently: read how `WorkflowListView` accesses bridge (`@EnvironmentObject private var bridge: AgentBridge` — AgentTaskViews.swift L771) and pass it. If `StateObject` can't take the env bridge at init time, restructure: make `delegate` a plain `@State` var created in `.onAppear`, OR pass bridge via a closure. Verify against AgentBridge init signature before committing.

- [ ] **Step 2: Build gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build -c debug 2>&1 | tail -30`
Expected: EXIT=0.

- [ ] **Step 3: Build tests gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build --build-tests 2>&1 | tail -20`
Expected: EXIT=0.

- [ ] **Step 4: Commit**

```bash
git add FusionStudio/Modules/AgentStudio/AgentWorkflowCanvasView.swift
git commit -m "feat(workflows): add AgentWorkflowCanvasView wrapper with Execute strip"
```

### Task 7: Wire into WorkflowListView + delete form sheets

**Files:**
- Modify: `FusionStudio/Modules/AgentStudio/AgentTaskViews.swift`

**Interfaces:**
- Consumes: `AgentWorkflowCanvasView` (Task 6). Current `WorkflowListView` (L768-958), `WorkflowDetailView` (L961-1183), `EditWorkflowSheet` (L1185-1340), `CreateWorkflowSheet` (L1342-end).
- Produces: rewired `WorkflowListView` with inline canvas detail pane; `WorkflowDetailView`/`EditWorkflowSheet`/`CreateWorkflowSheet` deleted.

- [ ] **Step 1: Add DetailMode state machine to WorkflowListView**

In `WorkflowListView` (L768), replace `@State private var selectedGraph: AgentGraphModel?` and `@State private var showCreateWorkflow = false` with:

```swift
private enum DetailMode {
    case empty
    case creating
    case editing(AgentGraphModel)
}
@State private var detailMode: DetailMode = .empty
```

Keep `@State private var searchText`, `@State private var isLoading`, `let toastManager`.

- [ ] **Step 2: Rewire body detail pane**

Replace the `HSplitView` body (L786-797) detail branch:

```swift
var body: some View {
    HSplitView {
        workflowListPanel
            .frame(minWidth: 240, idealWidth: 320, maxWidth: 420)

        detailView
            .frame(minWidth: 900)
    }
    .toolbar {
        ToolbarItem {
            FusionButton("Refresh", icon: "arrow.clockwise", style: .secondary, size: .small, isDisabled: isLoading) {
                Task { await refreshGraphs() }
            }
        }
        ToolbarItem {
            FusionButton("Create Workflow", icon: "plus", style: .primary, size: .small) {
                detailMode = .creating
            }
        }
    }
    .task {
        if bridge.agentState.graphs.isEmpty {
            await loadGraphs()
        }
    }
}

@ViewBuilder
private var detailView: some View {
    switch detailMode {
    case .empty:
        emptyWorkflowPlaceholder
    case .creating:
        AgentWorkflowCanvasView(mode: .create, toastManager: toastManager) {
            Task { await refreshGraphs() }
        }
    case .editing(let graph):
        AgentWorkflowCanvasView(mode: .edit(graph), toastManager: toastManager) {
            Task { await refreshGraphs() }
        }
    }
}
```

Remove the `.sheet(isPresented: $showCreateWorkflow)` modifier entirely.

- [ ] **Step 3: Rewire workflowListPanel tap + delete**

In `workflowListPanel` `ForEach` (the `.onTapGesture` ~L929), change `selectedGraph = graph` + graphGet to:

```swift
.onTapGesture {
    Task {
        if let fresh = try? await bridge.graphGet(graphId: graph.id) {
            detailMode = .editing(fresh)
        } else {
            detailMode = .editing(graph)
        }
    }
}
```

In `deleteGraph` (L930), change `if selectedGraph?.id == graph.id { selectedGraph = nil }` → `if case .editing(let g) = detailMode, g.id == graph.id { detailMode = .empty }`.

- [ ] **Step 4: Delete WorkflowDetailView + EditWorkflowSheet + CreateWorkflowSheet**

Delete the entire `WorkflowDetailView` struct (L961-1183), `EditWorkflowSheet` struct (L1185-1340), and `CreateWorkflowSheet` struct (L1342 to end of file). Their helper structs (`EditNodeRow`/`EditEdgeRow`/`NodeRowData`/`EdgeRowData`) — grep for other uses; if none outside the deleted sheets, delete them too.

Run: `grep -rn "WorkflowDetailView\|EditWorkflowSheet\|CreateWorkflowSheet\|EditNodeRow\|EditEdgeRow\|NodeRowData\|EdgeRowData" FusionStudio/`
Delete only what's exclusively used by the deleted sheets.

- [ ] **Step 5: Build gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build -c debug 2>&1 | tail -30`
Expected: EXIT=0. Fix any remaining references to deleted symbols.

- [ ] **Step 6: Build tests gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build --build-tests 2>&1 | tail -20`
Expected: EXIT=0.

- [ ] **Step 7: Commit**

```bash
git add FusionStudio/Modules/AgentStudio/AgentTaskViews.swift
git commit -m "feat(workflows): route Agent workflow create/edit to graphical canvas; delete form sheets"
```

### Task 8: Delete DAGCanvasView

**Files:**
- Delete: `FusionStudio/DAG/DAGCanvasView.swift`

- [ ] **Step 1: Confirm zero callers**

Run: `grep -rn "DAGCanvasView\|DAGViewModel\|DAGNode\b\|DAGEdge\b\|DAGNodeCard" FusionStudio/`
Expected: only self-references in `DAGCanvasView.swift` + maybe comments. If any live caller exists, STOP and report.

- [ ] **Step 2: Delete the file**

```bash
git rm FusionStudio/DAG/DAGCanvasView.swift
```

If the `DAG/` directory becomes empty, leave it (SPM handles empty dirs fine) or `rmdir` if clean.

- [ ] **Step 3: Build gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build -c debug 2>&1 | tail -20`
Expected: EXIT=0.

- [ ] **Step 4: Build tests gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build --build-tests 2>&1 | tail -20`
Expected: EXIT=0.

- [ ] **Step 5: Commit**

```bash
git commit -m "chore(workflows): delete dead DAGCanvasView (superseded by shared canvas)"
```

### Task 9: i18n — fill all 4 lang JSON

**Files:**
- Modify: `FusionStudio/Resources/i18n/en-US.json`, `zh-CN.json`, `ja-JP.json`, `ko-KR.json`

- [ ] **Step 1: Add English entries**

Add to `en-US.json` (keys from Task 5 Step 2b):

```json
"wf_cv_node_start": "Start",
"wf_cv_node_llm": "LLM",
"wf_cv_node_tool": "Tool",
"wf_cv_node_condition": "Condition",
"wf_cv_node_loop": "Loop",
"wf_cv_node_end": "End",
"wf_cv_node_error_handler": "Error Handler",
"wf_cv_node_retriever": "Retriever",
"wf_cv_node_router": "Router",
"wf_cv_node_memory": "Memory",
"wf_cv_node_human_in_loop": "Human in Loop",
"wf_cv_wfName": "Workflow Name",
"wf_cv_autoLayout": "Auto Layout",
"wf_cv_saveLayout": "Save Layout",
"wf_cv_testRun": "Test Run",
"wf_cv_running": "Running...",
"wf_cv_saving": "Saving...",
"wf_cv_nodeTypes": "Node Types",
"wf_cv_hintDrag": "Drag a node onto the canvas",
"wf_cv_hintRightClick": "Right-click canvas to add a node",
"wf_cv_hintConnect": "Click output port then input port to connect",
"wf_cv_nodeName": "Node Name",
"wf_cv_deleteNode": "Delete Node",
"wf_cv_inspectorReadOnly": "Read Only",
"wf_cv_inspectorEdit": "Edit",
"wf_cv_config": "Config",
"wf_cv_newWorkflow": "New Workflow"
```

- [ ] **Step 2: Add zh-CN entries**

```json
"wf_cv_node_start": "开始",
"wf_cv_node_llm": "大模型",
"wf_cv_node_tool": "工具",
"wf_cv_node_condition": "条件",
"wf_cv_node_loop": "循环",
"wf_cv_node_end": "结束",
"wf_cv_node_error_handler": "错误处理",
"wf_cv_node_retriever": "检索器",
"wf_cv_node_router": "路由",
"wf_cv_node_memory": "记忆",
"wf_cv_node_human_in_loop": "人工介入",
"wf_cv_wfName": "工作流名称",
"wf_cv_autoLayout": "自动布局",
"wf_cv_saveLayout": "保存布局",
"wf_cv_testRun": "测试运行",
"wf_cv_running": "运行中...",
"wf_cv_saving": "保存中...",
"wf_cv_nodeTypes": "节点类型",
"wf_cv_hintDrag": "将节点拖到画布上",
"wf_cv_hintRightClick": "右键画布添加节点",
"wf_cv_hintConnect": "点击输出端口再点输入端口连接",
"wf_cv_nodeName": "节点名称",
"wf_cv_deleteNode": "删除节点",
"wf_cv_inspectorReadOnly": "只读",
"wf_cv_inspectorEdit": "编辑",
"wf_cv_config": "配置",
"wf_cv_newWorkflow": "新建工作流"
```

- [ ] **Step 3: Add ja-JP entries**

```json
"wf_cv_node_start": "開始",
"wf_cv_node_llm": "LLM",
"wf_cv_node_tool": "ツール",
"wf_cv_node_condition": "条件",
"wf_cv_node_loop": "ループ",
"wf_cv_node_end": "終了",
"wf_cv_node_error_handler": "エラーハンドラ",
"wf_cv_node_retriever": "検索器",
"wf_cv_node_router": "ルータ",
"wf_cv_node_memory": "メモリ",
"wf_cv_node_human_in_loop": "ヒューマンインザループ",
"wf_cv_wfName": "ワークフロー名",
"wf_cv_autoLayout": "自動レイアウト",
"wf_cv_saveLayout": "レイアウト保存",
"wf_cv_testRun": "テスト実行",
"wf_cv_running": "実行中...",
"wf_cv_saving": "保存中...",
"wf_cv_nodeTypes": "ノードタイプ",
"wf_cv_hintDrag": "ノードをキャンバスにドラッグ",
"wf_cv_hintRightClick": "右クリックでノード追加",
"wf_cv_hintConnect": "出力ポート→入力ポートをクリックで接続",
"wf_cv_nodeName": "ノード名",
"wf_cv_deleteNode": "ノード削除",
"wf_cv_inspectorReadOnly": "読み取り専用",
"wf_cv_inspectorEdit": "編集",
"wf_cv_config": "設定",
"wf_cv_newWorkflow": "新規ワークフロー"
```

- [ ] **Step 4: Add ko-KR entries**

```json
"wf_cv_node_start": "시작",
"wf_cv_node_llm": "LLM",
"wf_cv_node_tool": "도구",
"wf_cv_node_condition": "조건",
"wf_cv_node_loop": "루프",
"wf_cv_node_end": "종료",
"wf_cv_node_error_handler": "오류 처리",
"wf_cv_node_retriever": "검색기",
"wf_cv_node_router": "라우터",
"wf_cv_node_memory": "메모리",
"wf_cv_node_human_in_loop": "사람 개입",
"wf_cv_wfName": "워크플로 이름",
"wf_cv_autoLayout": "자동 배치",
"wf_cv_saveLayout": "배치 저장",
"wf_cv_testRun": "테스트 실행",
"wf_cv_running": "실행 중...",
"wf_cv_saving": "저장 중...",
"wf_cv_nodeTypes": "노드 유형",
"wf_cv_hintDrag": "노드를 캔버스로 드래그",
"wf_cv_hintRightClick": "캔버스 우클릭으로 노드 추가",
"wf_cv_hintConnect": "출력 포트 클릭 후 입력 포트 클릭하여 연결",
"wf_cv_nodeName": "노드 이름",
"wf_cv_deleteNode": "노드 삭제",
"wf_cv_inspectorReadOnly": "읽기 전용",
"wf_cv_inspectorEdit": "편집",
"wf_cv_config": "구성",
"wf_cv_newWorkflow": "새 워크플로"
```

- [ ] **Step 5: Validate JSON**

Run: `cd /Users/dahai/fusion/fusion-studio && for f in en-US zh-CN ja-JP ko-KR; do python3 -c "import json; json.load(open('FusionStudio/Resources/i18n/$f.json'))" && echo "$f OK"; done`
Expected: all 4 "OK".

- [ ] **Step 6: Build gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build -c debug 2>&1 | tail -10 && swift build --build-tests 2>&1 | tail -10`
Expected: EXIT=0 both.

- [ ] **Step 7: Commit**

```bash
git add FusionStudio/Resources/i18n/
git commit -m "i18n(workflows): add wf_cv_* keys to all 4 languages"
```

### Task 10: Final cleanup + verification

**Files:** possibly comments across modified files

- [ ] **Step 1: No dead references**

Run: `grep -rn "DAGCanvasView\|CreateWorkflowSheet\|EditWorkflowSheet\|WorkflowDetailView" FusionStudio/`
Expected: none (or only innocuous comments). Clean any stragglers.

- [ ] **Step 2: Full build gate**

Run: `cd /Users/dahai/fusion/fusion-studio && swift build -c debug 2>&1 | tail -10 && swift build --build-tests 2>&1 | tail -10`
Expected: EXIT=0 both.

- [ ] **Step 3: Agent smoke (manual)**

Launch app → Agent → Workflows → "Create Workflow" → drag palette node to canvas → connect ports → Save → appears in list → reopen (edit) → positions preserved → Execute → events render in strip.

- [ ] **Step 4: Commit cleanup if any**

```bash
git add -A && git commit -m "chore(workflows): final cleanup"
```
(or skip if nothing to clean)

- [ ] **Step 5: Push branch + PR**

```bash
git push -u origin feat/workflow-canvas-shared-component
```
Create PR (EN): title `feat(workflows): extract reusable drag-canvas component, add graphical Agent workflow editor`. Body references the spec, the 3-canvas evaluation, shared shell + adapters, deletions, build-gate-green per phase. Per CLAUDE.md: English on GitHub.

## Risks & mitigations (carried from spec)

1. Generic + associatedtype + AnyView — delegate is `ObservableObject`, shell `@ObservedObject var delegate: Delegate` (concrete generic). AnyView only at inspector boundary.
2. FSB `[String:Any]` → `[String:JSONValue]` — adapter converts; round-trip through JSON dict preserved.
3. FSB behavior regression — Task 4 manual smoke gate.
4. Agent graph no layout endpoint — `persistLayout` no-op, full Save persists positions.
5. Execute logic relocation — copied verbatim into `AgentWorkflowCanvasView.executeGraph`.
6. SPM — confirmed directory-based (`path: "FusionStudio"`), no Package.swift edits.
