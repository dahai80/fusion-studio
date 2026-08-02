# Fusion-Code Modernization GUI Plan

## Context

PRD: `/Users/dahai/fusion/architecture/coding-modenization-enhance.md`
Upstream: `fusion-code-modenization` (Python library, NO REST server)
Current GUI: `FusionStudio/Modules/Code/` (8 files, 5087 lines)

## Key Problem

Upstream has rich Python classes (SessionEngine, SnapshotManager, WorkflowExecutor, MemoryTierManager, SandboxPolicy, SandboxAudit) but **no REST API server**. Existing FusionCodeBridge connects to port 11441 which doesn't expose these new APIs.

**Strategy**: Build GUI with local file-based bridge for snapshot/memory/sandbox (filesystem ops), and REST calls for session/workflow/chat (need server). File upstream issue for REST API.

## PRD Gap Analysis (Current vs Target)

| PRD Feature | Current State | Gap | Approach |
|-------------|---------------|-----|----------|
| A: Session sidebar (parallel N sessions) | Simple picker popover | **Missing** | New `FCSessionSidebar` |
| B: File explorer (sandbox/ignore/context) | Basic FileTreeView | **Partial** | Enhance + sandbox overlay |
| C: Diff (line-by-line accept/reject, side-by-side, patch) | Basic diff tab | **Missing** | New `FCDiffReviewView` |
| Web Preview tab | Missing | **Missing** | New `FCWebPreview` |
| Session state machine (7 states) | N/A | **Missing** | New `FCSessionState` |
| Snapshot/rewind | Basic undo | **Missing** | New `FCSnapshotManager` |
| FUSION.md 3-tier memory | /memory command | **Missing** | New `FCMemoryEditor` |
| Dynamic Workflow | N/A | **Missing** | New `FCWorkflowViews` |
| 3-mode Sandbox + audit | 2-tier permission | **Missing** | New `FCSandboxViews` |
| Cluster node assignment | N/A | **Missing** | Reuse IPCMultiNodeMethods |
| Slash commands /rewind /sandbox /audit /plan | 14 basic commands | **Partial** | Extend list |
| Layout mode toggle | 3 fixed panels | **Missing** | 4-col/3-col/2-col/chat-only |

## File Plan

### New Files (FusionStudio/Modules/Code/)

1. **FCSessionModels.swift** (~200 lines)
   - `FCSessionState` enum: idle/running/waitingApproval/paused/completed/failed/clusterRunning
   - `FCSessionConfig` struct: workingDir, model, temperature, securityMode, allowedDirs
   - `FCSessionDetail` struct: id, name, state, config, messageCount, createdAt, clusterNode
   - `FCSnapshotInfo` struct: id, label, createdAt, deltaCount

2. **FCSessionSidebar.swift** (~600 lines)
   - Full sidebar with session list, status indicators, right-click context menu
   - New session sheet (name, workingDir, model, securityMode)
   - Grouping toggle: by project / by state / flat
   - Context menu: clone, snapshot, rewind, archive, assign cluster node

3. **FCSnapshotManager.swift** (~350 lines)
   - Read `.fusion/snapshots/` JSON files directly (no REST needed)
   - createSnapshot, restoreSnapshot, rewind, listSnapshots
   - Snapshot diff viewer (before/after)

4. **FCMemoryEditor.swift** (~500 lines)
   - 3-tier tab: Global (~/.fusion/FUSION.md) | Project (./FUSION.md) | Directory (subdir/FUSION.md)
   - Markdown editor with template generation
   - /init one-click project initialization
   - Directory memory scanner

5. **FCSandboxViews.swift** (~400 lines)
   - `FCSandboxConfigSheet`: mode selector (readonly/manual/auto), allowed dirs, denied files/commands
   - `FCAuditLogView`: audit table, filter allowed/blocked, export CSV
   - `.fusionignore` editor

6. **FCWorkflowViews.swift** (~500 lines)
   - `FCWorkflowPlanView`: decomposed subtasks as DAG
   - `FCWorkflowProgressView`: live subtask execution progress
   - Template picker (generic/legacy_migration/security_scan/batch_api)
   - REST calls when server available, stub otherwise

7. **FCDiffReviewView.swift** (~400 lines)
   - Side-by-side and unified diff toggle
   - Per-line accept/reject
   - Accept all / Reject all / Export patch
   - Three-color markup (added/deleted/modified)

8. **FCWebPreview.swift** (~150 lines)
   - WKWebView wrapper for local dev server
   - URL bar + refresh + back/forward

### Modified Files

9. **FusionCodeBridge.swift** — Add methods:
   - Session CRUD: create/pause/resume/clone/delete (REST)
   - Snapshot: list/create/restore/rewind (local file)
   - Memory: load/save/init tiers (local file)
   - Sandbox: load/save policy, query audit (local file)
   - Workflow: decompose/execute/status (REST)
   - Cluster: assign node (REST via IPCMultiNodeMethods)

10. **FusionCodeView.swift** — Layout restructure:
    - 4-column: SessionSidebar | FileTree | Chat | RightPanel
    - Layout mode toggle buttons
    - New @State for sessions, snapshots, sandbox, workflow
    - Enhanced slash commands: /rewind, /sandbox, /audit, /plan

11. **FusionCodeDialogs.swift** — Add new dialogs:
    - Session settings sheet
    - Snapshot creation/restore sheet
    - Cluster node picker

## Implementation Phases

### Phase 1: Session Engine + Sidebar (core differentiator)
- FCSessionModels.swift
- FCSessionSidebar.swift
- FusionCodeBridge session methods
- FusionCodeView 4-column layout restructure
- Build verify

### Phase 2: Snapshot/Rewind + Diff Enhancement
- FCSnapshotManager.swift
- FCDiffReviewView.swift
- Snapshot context menu in sidebar
- Enhanced diff panel
- Build verify

### Phase 3: Memory 3-Tier + Sandbox
- FCMemoryEditor.swift
- FCSandboxViews.swift
- FusionCodeBridge memory/sandbox/audit methods
- Build verify

### Phase 4: Dynamic Workflow
- FCWorkflowViews.swift
- FusionCodeBridge workflow methods
- Template picker
- Build verify

### Phase 5: Web Preview + Cluster + Polish
- FCWebPreview.swift
- Cluster node assignment
- Layout mode toggle
- Final build verify + commit

## Upstream Issue

File issue on fusion-code-modenization for REST API server (FastAPI + uvicorn) on port 11441, exposing:
- Session CRUD + state transitions
- Workflow decompose/execute/merge
- Chat streaming (WebSocket)
- Audit log query/export
