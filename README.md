<div align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-brightgreen" alt="macOS">
  <img src="https://img.shields.io/badge/Apple%20Silicon-M1--M5-orange" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Swift-5.9-red" alt="Swift">
  <img src="https://img.shields.io/badge/Rust-2021-purple" alt="Rust">
  <img src="https://img.shields.io/badge/license-Apache%202.0-blue" alt="License">
  <img src="https://img.shields.io/badge/status-V0.1.39-yellow" alt="V0.1.39">
  <img src="https://img.shields.io/badge/modules-27-success" alt="27 Modules">
</div>

<h1 align="center">⚡ Fusion Studio</h1>
<p align="center"><strong>Unified macOS Desktop Client for the Fusion-MLX Local AI Ecosystem</strong></p>
<p align="center"><em>One app to rule them all — Design, Code, Simulation, MultiModal, Training, and more. 100% offline, Apple Silicon native.</em></p>

---

## 📋 Overview

**Fusion Studio** is the unified macOS native desktop application for the entire [Fusion-MLX](https://github.com/dahai80?tab=repositories) local AI ecosystem. It consolidates **27 modules** across 7 product phases into a single, cohesive user experience — eliminating the pain of juggling multiple terminals, browser tabs, and scattered directories.

### Why Fusion Studio?

| Before (Scattered) | After (Unified) |
|-------------------|-----------------|
| 🖥️ 5+ terminals for different tools | 📱 **Single macOS App** |
| 🌐 Browser tabs for design / docs | 🎨 **Built-in canvas + editor** |
| 📁 Multiple project directories | 📂 **Unified workspace** |
| ⚠️ Manual dependency hell | 🔧 **One-click repair** |
| 🐌 Cloud API latency | ⚡ **Local MLX inference** |

### Ecosystem Position

```
fusion-mlx (inference engine, Metal, KV Cache, quantization, multi-modal)
        ↓
Fusion Studio (UNIFIED macOS DESKTOP APP)
        ↓
Design · Code · Simulation · MultiModal · Training · Data · Agent · KB · Bench · Desk
```

---

## ✨ Feature Matrix (27 Modules)

### 🎯 Core Platform

| Feature | Description |
|---------|-------------|
| 🔧 **Environment Health Check** | Auto-detect Xcode CLI, Homebrew, Python, MLX, PyBullet, Rust |
| 🛠️ **One-Click Repair** | Fix all dependencies automatically |
| ⚙️ **Unified Settings** | Hardware, offline mode, quantization, workspace |
| 📊 **Hardware Monitor** | Real-time CPU/GPU/memory/MLX metrics |
| 📋 **Task System** | Unified Task with Immediate/Schedule(cron)/Once triggers, persisted via backend `task.*` RPC (task_store SQLite); optional `project_id` container with `project.list`/`project.tasks` aggregation; agent.execute/graph.execute execution + status writeback; Kanban board + detail view + auto-retry |
| 🔌 **Plugin System** | Third-party extension support |
| ♿ **Accessibility** | VoiceOver labels, keyboard navigation, reduce motion (partial — `accessibilityIdentifier` coverage in progress) |
| 🌐 **i18n** | Chinese, English, Japanese, Korean |
| 🔒 **Security Center** | SAST scan + AI fix + quality gate + runtime protection (sandbox / desensitization / injection detection) |

### 🧩 Module Overview

> **Module count**: the `Module` enum has 27 cases (below). The icon rail (`SidebarSection.allCases`) renders 20 top-level entries; the remaining modules appear as sub-items or are routed via `ModuleDetailView`.

| # | Module | Icon | Status | Description |
|---|--------|------|--------|-------------|
| 1 | 🏠 **Dashboard** | `square.grid.2x2` | ✅ Stable | Command center, health check, task queue, hardware monitor |
| 2 | 🎨 **Design** | `pencil.and.outline` | ✅ Stable | AI-powered canvas (preview + interactive node editing), 8 design skills, 7 info tabs (props/layers/tokens/design-systems/lint/codegen/ecosystem), 20 grouped quick templates, version diff, 3 workflow recipes, theme switching, design system picker, SwiftUI/React/Vue export — surpassing Claude Design |
| 3 | 💻 **Code** | `chevron.left.forwardslash.chevron.right` | 🆕 New | 5-panel layout: FileTree · Chat · Editor/Diff/Terminal + InputBar with /slash commands + 3 execution modes (Ask/Auto/Plan), KB query, memory, templates, permission tiers — surpassing Claude Code |
| 4 | 🤖 **Simulation** | `cube.transparent` | 🆕 New | fusion-simulation integration (REST :11455 + gRPC :11447): PyBullet physics, scene loader (default/pick/push), 7 sensor types (rgb/depth/segmentation/imu/force-torque/joint/contact), LLM agent policy via fusion-mlx (Bearer auth), snapshots save/restore, real-time status/timing/observations monitor, env_check |
| 5 | 📦 **Model Hub** | `cpu` | ✅ Stable | 11-section GUI + 116 API methods + 98 DTOs: Dashboard (stats+health badges+quick actions), Market (HF+ModelScope+private, pagination, rating, favorites, module hints), Local Storage (category tree, serving mgmt, version lifecycle), Convert/Quant (scene presets, layered quantize, compare, evaluate), Schedule (6 tabs: download/schedule/module-perm/throttle/TTL/auto-bench), Cluster (topology, routing, sync), Deployment (CRUD, scale, gray release, metrics), Permission (API keys+role ACL+tenants+approval), Monitor (per-model stats, source filter, deployment metrics), Benchmark (evaluations CRUD, history, accuracy alerts), Security (scan, watermark, encryption, approval) |
| 6 | 🖼️ **MultiModal** | `photo.on.rectangle` | ✅ Stable | Text-to-image, image-to-image, OCR, speech-to-text, TTS |
| 7 | 🧠 **Training** | `brain` | ✅ Stable | LoRA/QLoRA fine-tuning, monitoring, checkpoints, model export |
| 8 | ⌨️ **CLI** | `terminal` | ✅ Stable | GUI CLI panel, 18 preset commands, execution history |
| 9 | 📄 **Doc** | `doc.text` | ✅ Stable | AI-First Document OS, 12 tabs (editor/graph/versions/office/workflow/template/search/comments/favorites/files/rag/activity), 102 routes, 90+ API methods (auth/workspace/users/pages/books/chapters/tags/graph/workflow/template/office/copilot/rag/search/comment/favorite/activity/file/branding/theme/vocabulary/webhook/metadata/system/export/notification/ai/collab), 7 copilot modes, WebSocket collab client |
| 10 | 📚 **KB** | `books.vertical` | ✅ Stable | Knowledge base, RAG retrieval, document indexing |
| 11 | 📊 **Bench** | `chart.bar` | ✅ Stable | Speed/memory/context/quality benchmarks |
| 12 | 🧹 **Desk** | `desktopcomputer` | ✅ Stable | Desktop automation, 6 preset templates |
| 13 | 📈 **Data Tools** | `tablecells` | ✅ Stable | CSV import/export, statistics, charts, SQL queries |
| 14 | 🤝 **Agent** | `person.2.fill` | ✅ Stable | Multi-agent orchestration, workflows, task delegation |
| 15 | 🔌 **Plugin** | `puzzlepiece.extension` | ✅ Stable | Plugin manager, marketplace, developer tools |
| 16 | 🔒 **Security** | `shield.checkered` | ✅ Stable | 6 native tabs: Security Overview / Projects & Scans / Vulnerability List / AI Fix / Quality Gate / Runtime Protection, direct connection to fusion-security :11454 |
| 17 | 📊 **Analytics** | `chart.bar.xaxis` | ✅ Stable | Usage analytics, inference stats, error analysis |
| 18 | 👥 **Collaboration** | `person.2` | ✅ Stable | LAN peer discovery, real-time chat, shared resources |
| 19 | ⚡ **Auto Tuning** | `wand.and.rays` | ✅ Stable | MLX auto-tuning, performance optimization |
| 20 | 🔗 **External Integrations** | `link.circle` | ✅ Stable | GitHub, Jira, Slack, OpenAI-compatible API |
| 21 | 📝 **Doc Generator** | `doc.badge.gearshape` | ✅ Stable | Auto-generate API/arch/changelog/README docs |
| 22 | 🏭 **Industry Templates** | `square.stack.3d.forward.dottedline` | ✅ Stable | 12 pre-built industry scenarios |
| 23 | 🔧 **Operations** | `antenna.radiowaves.left.and.right` | ✅ Stable | Service management, alert rules, ops logs |
| 24 | 🔑 **License** | `key.fill` | ✅ Stable | Commercial licensing, activation, tier comparison |
| 25 | 🌐 **Multi-Node** | `network` | 🆕 New | Cluster overview, topology, task monitor, alerts, KV cache, autoscaler, routing — real API on port 9753, offline status banner |
| 26 | 🏢 **FSB** | `building.2.crop.circle` | 🆕 New | AI workflow automation for small business — Connectors, Skills, Workflows, Approval gates — 57 IPC methods, 4 GUI views, HTTP REST backend |
| 27 | 🔍 **RAG** | `magnifyingglass.circle` | 🆕 New | Full-featured RAG management — Dashboard, Files, Search Config, Permissions, Vector Ops, Call Log, Bench Eval, Search — 8 sidebar sections, 35+ upstream API endpoints, real HTTP REST integration |

### 📦 Artifacts Integration

Fusion Studio integrates with [fusion-artifacts-engine](https://github.com/dahai80/fusion-artifacts-engine) for persistent artifact management — surpassing Claude Artifacts with explicit version snapshots, sandbox rendering, folder/tag organization, and project KB migration.

**5 GUI Views** (matching PRD wireframes):

| View | File | Key Features |
|------|------|-------------|
| Global Repository | `ArtifactsRepositoryView` | List/grid toggle, sort, scope filter (all/mine/starred/pinned), folder sidebar, pagination, recycle bin |
| Preview Card | `ArtifactPreviewCard` | Mini sandbox preview (HTML/SVG), render-type icon + color, tag chips, folder badge, version badge |
| Full-Screen Canvas | `ArtifactCanvasView` | Preview/Code tabs, sandbox rendering (HTML/CSS/JS/SVG/Mermaid/Markdown), unsaved banner, snapshot, rename, duplicate |
| Version History | `ArtifactVersionHistoryPanel` | Snapshot creation, version diff, rollback with named snapshot preservation |
| Share Dialog | `ArtifactShareDialog` | Permission + expiry, share link generation, existing share list, revoke |
| Tag/Folder Manager | `ArtifactTagFolderPopover` | Add/remove tags, move to folder, from canvas toolbar |

**Competitive Differentiators vs Claude Artifacts**:

| Feature | Claude Artifacts | Fusion Artifacts |
|---------|-----------------|------------------|
| Version management | Implicit auto-save | **Explicit version snapshots + rollback + diff** |
| Code editing | View-only | **Direct edit + Save with unsaved tracking** |
| Organization | Flat list | **Folders + tags + scope filters + sort** |
| Project integration | None | **Move to Project KB** (`artifact.move_to_project_kb`) |
| Ownership | None | **Star/Pin/Ownership scope filter** |
| Deletion | Permanent | **Recycle bin with restore + auto-purge** |
| Sharing | None | **Permission levels + expiry + revoke** |
| Preview | HTML only | **HTML/SVG/Mermaid/Markdown sandbox rendering** |

**Backend API Coverage** (40+ methods via `IPCClient`):

| Category | Methods |
|----------|---------|
| Core CRUD | `artifact.create/get/get_content/list/delete/update/rename` |
| Version | `artifact.version_list/version_rollback/create_snapshot/list_snapshots` |
| Extended | `artifact.star/pin/duplicate/list_all` |
| Share | `artifact.create_share/get_shared/revoke_share` |
| Folder | `artifact.create_folder/list_folders/rename_folder/delete_folder/move_to_folder` |
| Tag | `artifact.add_tag/remove_tag/list_tags` |
| Recycle | `artifact.list_recycle/restore/purge_expired` |
| Project KB | `artifact.move_to_project_kb` |
| Safety | `artifact.inject/check_safety` |
| Import/Export | `artifact.export/import/export_code/import_code` |

**Communication**: HTTP JSON-RPC 2.0 to `127.0.0.1:11451` (separate from UDS channel).

### 🤝 CoWork — Collaborative AI Spaces

Fusion Studio's CoWork module provides **real-time collaborative AI spaces** that surpass Claude CoWork with 8 differentiators: offline-first (D1), workflow co-execution (D2), local agent sharing (D3), KB-as-space (D4), computer use co-control (D5), local artifacts (D6), deep research (D7), workflow marketplace (D8).

| Feature | UI Location | Backend API |
|---------|------------|-------------|
| Space list with search & filters | `SpaceListView` | `desk.space.list` |
| Create space (mode/config/KB/agents) | `SpaceCreateDialog` | `desk.space.create` |
| 3-column main view (sidebar + chat + artifact preview) | `SpaceMainView` | `desk.space.get` |
| Shared chat with streaming replies + @agent mentions | `SpaceSharedChat` | `desk.space.chat.send/history/stream` |
| Markdown + code block rendering with copy | `MarkdownContentView` | — |
| Artifact dual-pane preview (code/doc/viz) | `ArtifactPreviewView` | `desk.space.artifact.list/get` |
| Comment threads on messages | `SpaceCommentThread` | `desk.space.comment.create/list` |
| Member management + invite links | `SpaceMemberPanel` | `desk.space.member.list/invite/remove/update_role` |
| Agent management (add/edit/permission) | `SpaceAgentPanel` | `desk.space.agent.list/add/remove/update` |
| Artifact management (kind filtering) | `SpaceArtifactPanel` | `desk.space.artifact.list/create` |
| Snapshot create/restore/fork | `SpaceSnapshotPanel` | `desk.space.snapshot.create/list/clone/restore` |
| Workflow collaboration + DAG canvas | `SpaceWorkflowPanel` + `WorkflowDagCanvas` | `desk.space.workflow.list/run/create` |
| Desktop sharing + control requests | `SpaceDesktopPanel` | `desk.space.desktop.share/control` |
| Deep research (multi-agent parallel, zero token) | `SpaceDeepResearchView` | `desk.space.research.start` + `spaceAgentCall/Relay` |
| LAN peer discovery | Member panel → scan | `desk.space.discovery.scan` |
| Space settings (config toggles) | `SpaceSettingsPanel` | `desk.space.update` |
| Knowledge Base bind/unbind/search/query/upload | `SpaceKnowledgePanel` | `spaceKnowledgeStatus/Bind/Unbind/Search/Query/Upload` |
| Notification bell + unread badge + popover | `SpaceNotificationPopover` | `spaceNotificationPush/List/MarkRead` |
| Multi-Agent relay chat (sequential handoff) | `SpaceSharedChat` relay button | `spaceAgentRelay` |
| Workflow/Artifact marketplace (D8) | `SpaceMarketplaceView` | `desk.space.artifact.list/share` |

**3 Collab Modes**: `local` (single machine), `p2p` (Bonjour LAN discovery), `gateway` (remote via fusion-gateway).

**4-Level Permissions**: Owner → Admin → Member → Viewer with fine-grained config toggles (web search, deep research, computer use, member upload/agent/workflow).

**V2.0 Differentiators vs Claude CoWork**:

| # | Differentiator | What It Does |
|---|---------------|--------------|
| D1 | Offline CoWork | Full collab works without internet — all inference local via MLX |
| D2 | Workflow CoWork | DAG-based workflow co-execution with `WorkflowDagCanvas` visual editor |
| D3 | Local Agent Orchestration | Share & compose agents (chat/code/research/workflow/custom) across space members |
| D4 | Knowledge Base as Space | Bind RAG KB to space; search/query/upload with `SpaceKnowledgePanel` |
| D5 | Computer Use Collaboration | Desktop share + approve/reject control handoff in `SpaceDesktopPanel` |
| D6 | Artifacts Local Engine | All artifact rendering runs locally — code, doc, viz previews |
| D7 | Deep Research Local | Multi-agent parallel research at zero token cost via `ResearchAgentTrack` |
| D8 | Workflow Marketplace | Browse & share workflow/artifact templates in `SpaceMarketplaceView` |

**Model Layer**: All types in `CoworkSpace.swift` use `fromDict()` pattern for parsing backend `[String: Any]` responses — CoworkSpace, SpaceMember, SpaceMessage, SpaceAttachment, SpaceComment, SpaceSnapshot, SpaceAgent (with `SpaceAgentType` enum: chat/code/research/workflow/custom), SpaceInviteLink, SpaceWorkflow, SpaceArtifact (with ownerId/version/shareCode/metadata/kindIcon), SpaceDiscoveryPeer, SpaceConfig, SpaceKnowledgeStatus, SpaceNotification (with typeIcon/typeColor). `CoworkSpaceManager` singleton manages activeKnowledge, activeNotifications, and 15+ IPC methods for KB/notification/agent/artifact operations.

**Communication**: JSON-RPC 2.0 over Unix Domain Socket `/tmp/fusion-cowork.sock` via `IPCClient.spaceCall()`. Streaming replies use `IPCClient.spaceChatStreamEvents()` with NDJSON long-connection parsing for real-time token-by-token output.

### 🏢 FSB — AI Workflow Automation for Small Business

Fusion Studio integrates with [fusion-smallbusiness](https://github.com/dahai80/fusion-smallbusiness) for AI-powered workflow automation — Connectors → Skills → Workflows with 7 LangGraph node types (START, CONNECTOR, SKILL, CONDITION, APPROVAL_GATE, OUTPUT, END).

**4 GUI Views**:

| View | File | Key Features |
|------|------|-------------|
| Workspace Manager | `FSBWorkspaceView` | CRUD + duplicate/export/import, template gallery, variable editor |
| Workbench | `FSBWorkbenchView` | 3-panel (connectors/skills/templates + workflow grid + approval/tasks), workflow editor, connector auth |
| Workflow Canvas | `FSBWorkflowCanvasView` | Visual DAG editor with 7 node types, edge wiring, config panels, test run, approval flow |
| Dialogs | `FSBDialogs` | Connector auth, skill test, approval approve/deny/edit, workflow import, schedule, variable, template CRUD |

**Backend API Coverage** (57 methods via `IPCClient`):

| Category | Methods |
|----------|---------|
| Workspace | `fsbListWorkspaces/fsbGetWorkspace/fsbCreateWorkspace/fsbUpdateWorkspace/fsbDuplicateWorkspace/fsbExportWorkspace/fsbImportWorkspace/fsbDeleteWorkspace` |
| Connector | `fsbCreateConnector/fsbListConnectors/fsbUpdateConnector/fsbDisconnectConnector/fsbRefreshConnector/fsbDeleteConnector/fsbListConnectorMeta/fsbGetConnectorMeta` |
| Skill | `fsbCreateSkill/fsbGetSkill/fsbListSkills/fsbUpdateSkill/fsbTestSkill/fsbDeleteSkill` |
| Workflow | `fsbCreateWorkflow/fsbGetWorkflow/fsbListWorkflows/fsbUpdateWorkflow/fsbRunWorkflow/fsbSetSchedule/fsbDeleteSchedule/fsbExportWorkflow/fsbImportWorkflow/fsbDeleteWorkflow` |
| Execution | `fsbExecutionHistory/fsbGetExecution/fsbExportExecutionLog/fsbListPendingTasks/fsbApproveTask/fsbDenyTask/fsbEditTask` |
| Variable | `fsbListVariables/fsbUpdateVariables` |
| Template | `fsbListTemplates/fsbCreateTemplate/fsbDeleteTemplate` |
| External | `fsbExternalStatus/fsbExternalTrigger/fsbPostEvent/fsbCreateSubscription/fsbListSubscriptions/fsbDeleteSubscription/fsbRegisterWebhook/fsbListWebhooks/fsbDeleteWebhook` |
| Integration | `fsbCreateArtifact/fsbSendToCanvas/fsbSyncToProject` |
| Health | `fsbHealth` |

**Communication**: HTTP REST to `127.0.0.1:11432/api/v1/fsb` (separate from JSON-RPC UDS channel), via `IPCClient.fsbRequest()`/`fsbRequestArray()`.

**E2E Test Status**: 54/54 IPC methods verified passing against backend (2026-08-01). 9 upstream issues filed and closed.

### 💻 Fusion Code — Local AI Coding Assistant

Fusion Studio integrates with [fusion-code](https://github.com/dahai80/fusion-code) for a Claude Code–competitive AI coding experience with **5 key differentiators**: MLX local offline inference, project KB (build/query/status), cross-session memory, workflow templates, and 3 execution modes.

**5-Panel Layout** (surpassing Claude Code's 4-panel):

```
┌──────────┬────────────────────────┬───────────────┐
│ FileTree │        Chat            │ Editor/Diff/   │
│  240pt   │   (streaming AI)       │ Terminal 480pt │
│          │                        │               │
│ Project  │  Tool call cards       │ Monaco Editor  │
│ Context  │  Permission approve/   │ Diff View      │
│ KB status│  deny buttons          │ PTY Terminal   │
│ Memory   │  Code apply buttons    │               │
│          │                        │               │
├──────────┴────────────────────────┴───────────────┤
│  InputBar: [Mode▼] [+] [Text field] [Send/Stop]  │
│  Mode: Ask Permissions / Auto Accept / Plan Only  │
│  /slash commands: /help /clear /kb /memory etc.   │
└──────────────────────────────────────────────────┘
```

**3 Execution Modes**:

| Mode | Behavior |
|------|----------|
| **Ask Permissions** | Default. Tier1 auto-approve (Read/Glob/Grep/Ls), Tier2 require approval (Edit/Write/Bash) |
| **Auto Accept** | Auto-approve all file edits. Bash still requires approval. |
| **Plan Only** | Read-only analysis. No edits or commands executed. |

**14 Slash Commands**: `/help` `/clear` `/compact` `/model` `/kb` `/memory` `/template` `/init` `/review` `/test` `/deploy` `/explain` `/refactor` `/debug`

**Backend API Coverage** (14 REST + WebSocket via `FusionCodeBridge`):

| Category | Methods |
|----------|---------|
| Project | `projectContext(cwd:)`, `projectContext(id:)`, `listProjects()` |
| Session | `listSessions()`, `getSession(id:)` |
| Code | `generateCode()`, `lspOperation()` |
| Memory | `getMemory()`, `writeMemory()` |
| Model | `modelStatus()` |
| KB | `buildKB()`, `queryKB()`, `kbStatus()` |
| Template | `listTemplates()` |
| Chat | `chatStream()` (WebSocket), `chatCancel()` |

**Communication**: HTTP REST + WebSocket to `127.0.0.1:11441` via `FusionCodeBridge` (singleton, `@StateObject` in FusionCodeView).

**Competitive Differentiators vs Claude Code**:

| Feature | Claude Code | Fusion Code |
|---------|------------|-------------|
| Inference | Cloud API | **MLX local offline** |
| Knowledge Base | None | **Project KB with RAG** (`/kb` command) |
| Memory | Session-only | **Cross-session memory** (`/memory` command) |
| Workflow | None | **Templates** (`/template` command) |
| Permission | Single mode | **3 execution modes** (Ask/Auto/Plan) |
| File diff | Side-by-side | **Monaco Diff View** with undo checkpoint |
| Git integration | CLI only | **Visual Git Panel** + URL detection bar |

---

### 🤖 Fusion Simulation - Physics + LLM Agent Simulation Workbench

Fusion Studio provides the GUI for [fusion-simulation](https://github.com/dahai80/fusion-simulation) - a 6-layer PyBullet physics + LLM-agent simulation engine. The integration is a 4-zone native SwiftUI workbench driven by `SimulationBridge` (HTTP client to the fusion-sim dashboard on `:11455`).

**Architecture**

```
fusion-studio (GUI)  ──HTTP REST──>  fusion-simulation (:11455 dashboard)
   SimulationBridge                    ├── :11447 gRPC (sim control)
                                       ├── :11456 metrics
                                       └── PolicyClient ──HTTP──> fusion-mlx (:11434, LLM agent decisions)
```

**4-Zone Workbench** (`Modules/Simulation/SimulationWorkbenchView.swift`)

| Zone | Content |
|------|---------|
| Banner | `UpstreamServiceStatusBanner` - fusion-simulation health (startOrder 12, `.httpGet` probe) |
| Left - Entities | Scene picker (default/pick/push) + Load; Agent builder (name/role/action_dim/entity/model + Add); Sensor builder (7 types + Add); live entity lists |
| Center - Monitor | Status grid (state/sim_time/frame_count/entity_count/RTF/initialized); timing bars (physics/sensor/agent/render vs total); observations summary |
| Right - Inspector | `FusionTabBar` (status/environment/snapshot): full status rows, env_check component dots, snapshot save/restore |
| Bottom - Transport | Init / Steps picker (1/10/100) / Step / Pause / Resume / Reset + lastError |

**REST API Contract** (all POSTs use query params; `JSONDecoder.sim` uses `.convertFromSnakeCase`)

| Endpoint | Method | Bridge DTO |
|----------|--------|-----------|
| `/api/health` | GET | `initialized:bool` |
| `/api/status` | GET | `SimStatusDTO` (state/sim_time/frame_count/entity_count/real_time_factor/paused) |
| `/api/init` `/api/reset` `/api/pause` `/api/resume` | POST | `SimActionResponseDTO` |
| `/api/step?num_steps=N` | POST | `SimStepResultDTO` (physics/sensor/agent/render/total ms) |
| `/api/load_scene?name=` | POST | `SimActionResponseDTO` |
| `/api/add_sensor?type=&name=&entity_id=` | POST | `SimActionResponseDTO` |
| `/api/add_agent?name=&role=&action_dim=&entity_id=&model_name=` | POST | `SimActionResponseDTO` |
| `/api/observations` | GET | `{sensor: {type,name,data,shape}}` |
| `/api/save_snapshot?name=` `/api/restore_snapshot?snapshot_id=` | POST | `{snapshot_id}` |
| `/api/env_check` | GET | `{pybullet,grpc,fusion_mlx,simulation_service}` |

**Running** (fusion-sim has no `start.sh`; start manually with fusion-mlx auth)

```bash
# 1. fusion-mlx with auth (api_key in ~/.fusion-mlx/settings.json auth.api_key)
~/claude-home/fusion-mlx/start.sh start

# 2. fusion-sim dashboard + gRPC, threading the mlx API key
cd ~/fusion/fusion-simulation
python -c "from fusion_simulation.cli import main; main()" service start \
  --gui --headless --host 127.0.0.1 \
  --api-key <key> --mlx-url http://localhost:11434/v1
```

**End-to-end verified**: init → load_scene(default) → add_sensor(rgb_camera) → add_agent(robot, Qwen3-0.6B-4bit) → step(3) → 3× LLM 200 OK, `agent_decide_ms ~324ms`, 0 crashes; env_check `fusion_mlx:available:true`; snapshot save/restore; pause/resume.

> **Upstream**: fusion-simulation `PolicyClient` lacked API-key auth (issue [#6](https://github.com/dahai80/fusion-simulation/issues/6), PR [#7](https://github.com/dahai80/fusion-simulation/pull/7)) - landed via the issue→PR→code flow. pybullet 3.2.7 on macOS arm64/Clang 21 needs a one-line `zutil.h` `fdopen` macro patch to build.

---


## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  📱 Application Layer — SwiftUI Native Desktop               │
│  Navigation (27 modules) · Settings · Health Check · Tasks   │
├──────────────────────────────────────────────────────────────┤
│  🛠️ Container Layer — WKWebView + Native Components          │
│  Design · Code · Simulation · MultiModal · Training · Data   │
├──────────────────────────────────────────────────────────────┤
│  🔗 Bridge Layer — Unix Domain Socket + JSON-RPC 2.0         │
├──────────────────────────────────────────────────────────────┤
│  ⚙️ Service Layer — Central Router (daemon_server.py)         │
│  env.* · hardware.metrics · memory · safety (Python)         │
├──────────────────────────────────────────────────────────────┤
│  🧠 Base Layer — fusion-mlx (Apple Silicon Native)           │
│  LLM · Image Generation · Speech · OCR · Video · Training   │
└──────────────────────────────────────────────────────────────┘
```

### UI Layout - 3-Column: Icon Rail + Workspace + Inspector (sidebar collapsible)

```
┌──────────────────┬─────────────────────────────┬──────────────┐
│ FusionSidebar    │        WorkspaceArea        │  Inspector   │
│  260pt (collaps) │         (flex)              │   280pt      │
│                  │                             │  (optional)  │
│ 🔍 Search  [◁]  │  ┌───────────────────────┐  │  Properties  │
│ ✚ New Chat      │  │   Module Content      │  │  Config      │
│ CHATS            │  │                       │  │  Metadata    │
│   💬 Chat 1      │  │                       │  │              │
│ PROJECTS         │  │                       │  │              │
│   📁 project     │  └───────────────────────┘  │              │
│ CODE             │  Toolbar: Title | Badge |⚡│  Close [⇧⌘I] │
│   </> Code        │                             │              │
│   ✏️ Design       │                             │              │
│ DESIGN           │                             │              │
│ RECENTS          │                             │              │
│ ⬇️ Get Apps      │                             │              │
│ ⚙️ Settings      │                             │              │
│ 👤 username [↓]  │                             │              │
└──────────────────┴─────────────────────────────┴──────────────┘
     .ultraThin         .ultraThin                  .ultraThin
      Material           Material                    Material
```

- **Default 3-column**: Icon Rail (52pt, narrow nav) | Workspace | Inspector. FusionSidebar (260pt) is collapsed by default, expand with ⌘\.
- **Dark-first (default on)**: Dark mode on launch; one-click ☀️/🌙 toggle in workspace toolbar; persisted via UserDefaults, overrides system via `preferredColorScheme` + `NSApp.appearance`.
- **Surfaces**: Window #1E1E20, Sidebar #1F2937 (auxiliary dark gray), Content #1C1C1E.
- **Accent**: #007AFF via `AccentColor` asset - unifies native `.accentColor`/`.tint` with `StudioTheme.accent`.
- **Vibrancy**: `.ultraThinMaterial` on icon rail/toolbar/inspector backgrounds.
- **Grid**: 8px rhythm (4px half-step), Apple HIG 4pt grid.
- **Sidebar**: Collapsible (⌘\), ChatGPT-style grouped navigation with search.
- **Inspector**: Toggle with ⇧⌘I, context-aware (agent/DAG node/task/settings); visible by default.
- **Sections**: Chats, Projects, Artifacts, Code, Customize, Design.
- **Bottom bar**: Get App & Extensions, Settings popup, User area

### Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| UI Framework | **SwiftUI** | macOS native, best performance, Apple Silicon optimized |
| Embedded Web | **WKWebView** | Reuse Fusion-Design canvas without rewrite |
| IPC | **Unix Socket + JSON-RPC 2.0** | Lightweight, zero-dependency, cross-language |
| Backend Services | **Rust** (primary) + **Python** (secondary) | Rust for performance/process mgmt, Python for MLX |
| Inference Engine | **fusion-mlx** | Apple Silicon MLX, multi-modal, quantization |
| Storage | **UserDefaults** (prefs) + **Keychain** (secrets) | Local-first; non-secret config in UserDefaults, API keys/tokens in macOS Keychain (kSecClassGenericPassword); file integrity via SHA256 |
| Packaging | **Xcode Archive + Notarization + DMG** | Standard macOS distribution |

---

## 🚀 Quick Start

### Prerequisites

- macOS 14+ (Sonoma or later)
- Apple Silicon (M1–M5)
- [Xcode CLI Tools](https://developer.apple.com/download/all/) (`xcode-select --install`)
- [Homebrew](https://brew.sh)

### One-Click Setup

```bash
git clone https://github.com/dahai80/fusion-studio.git
cd fusion-studio
./Scripts/setup.sh
```

### Manual Setup

```bash
# 1. Install dependencies
brew install cmake glfw glew
pip3 install mlx pybullet psutil

# 2. Build SwiftUI app (env.* implemented by central router daemon_server.py, no local Rust service)
swift build -c release

# 4. Start all services
./Scripts/start.sh
```

### Upstream Services (Auto-Start)

Fusion Studio depends on upstream ecosystem services. On launch it probes each
one and, for critical services, auto-starts them through the upstream repo's
`start.sh` (non-blocking - `IPCClient` auto-reconnects every 3s once the socket
comes up).

| Service | start.sh | Endpoint | Critical |
|---------|----------|----------|----------|
| fusion-mlx | `~/claude-home/fusion-mlx/start.sh` | `localhost:11432` | ✅ |
| fusion-agent-studio | `~/fusion/fusion-agent-studio/start.sh` | `/tmp/fusion-studio.sock` (UDS) | ✅ |
| fusion-artifacts-engine | `~/fusion/fusion-artifacts-engine/start.sh` | `127.0.0.1:11451` | ✅ |
| fusion-rag (RAG) | `~/fusion/fusion-rag/start.sh` | `127.0.0.1:11436` | optional |
| fusion-doc | `~/fusion/fusion-doc/start.sh` | `127.0.0.1:11449` | optional |
| fusion-multi-node | `~/fusion/fusion-multi-node/start.sh` | `127.0.0.1:11452` | optional |
| fusion-model-hub | `~/fusion/fusion-model-hub/start.sh` | `127.0.0.1:11444` | optional |
| fusion-design | (CLI tool, no start.sh) | - | n/a |

- Critical services auto-start in order: mlx -> agent-studio -> artifacts-engine.
- Optional services are detected only; start them manually from the UI.
- Each `start.sh` supports `start | stop | restart | status` (exit 0 = running).
- The Dashboard shows each service's status (running / not started / service
  not found / start failed) with start / stop / retry controls. A banner
  appears when a critical service is missing or failed to start.
- Upstream repo paths and the auto-start toggle live in Settings
  (`FusionConfig.upstream*Path`, `upstreamAutoStartCritical`, default on).

#### API Key Resolution (Gateway Inbound Auth)

fusion-studio connects to fusion-mlx via fusion-gateway (`:11432`) by default,
which uses its own inbound key (not the mlx `settings.json` key).
`FusionConfig.mlxResolvedApiKey` resolves the key with the following priority
(aligned with the upstream fusion-mlx `_resolve_api_key`):

1. User-set value in Settings (`mlxApiKey`, stored in macOS **Keychain**,
   service `com.fusion.studio`)
2. Process environment variable `FUSION_MLX_API_KEY` (injected by
   fusion-mlx / fusion-gateway at startup)
3. `~/.fusion-mlx/settings.json` → `auth.api_key`

The resolution source is logged to `os.log` (subsystem `com.fusion.studio`,
category `FusionConfig`). Export `FUSION_MLX_API_KEY` when starting
fusion-gateway / mlx so studio picks up the correct inbound key.

> **Secret storage (HIGH-2)**: `mlxApiKey` / `fusionRagApiKey` /
> `modelHubApiKey` are all stored in Keychain — no longer written to
> UserDefaults plist in plaintext. `fusionCodeApiKey` is a per-instance
> random token (generated on first use, stored in Keychain +
> `~/.fusion-studio/fusion-code.token` 0600); the old hardcoded
> `fg-admin-key` has been removed. The fusion-code server authToken defaults
> to empty, causing an auth fail-open — see upstream issue
> [dahai80/fusion-code#132](https://github.com/dahai80/fusion-code/issues/132).

### First-Run Onboarding (3-Tier Model Guide)

On first launch, if no small-model slot is set (`@AppStorage("mlxModelSmall")` empty),
Fusion Studio shows a 6-step onboarding wizard reused from fusion-mac's
`WelcomeWindow` and adapted to this app's architecture. It can be re-entered
anytime via Settings → General → "Re-select main model".

| Step | Purpose |
|------|---------|
| intro | Welcome + privacy (100% offline) |
| setup | fusion-mlx host/port + API key (reuses external mlx, no spawn) |
| hardwareDetect | Chip / cores / RAM / bandwidth / disk auto-detect |
| modelSource | HF source: huggingface / hf-mirror / modelscope |
| recommend | Configure 3 model slots (small / code / heavy) from existing local models |
| complete | Summary |

Key design points (fusion-studio reuses the **external** fusion-mlx, it does
**not** spawn its own):

- **HTTP, not IPC, for model ops.** `MlxHTTPClient` talks to the external
  fusion-mlx admin API (`/admin/api/*`, port 11432) with cookie-jar session +
  401 auto-relogin. Endpoints: `login`, `models`, `hf/recommended`,
  `hf/download`, `hf/tasks`, `hf/cancel`, `setup-api-key`.
- **Local-first slot configuration.** The recommend step lists the external
  mlx's already-downloaded models (via `listModels`) and lets the user assign
  one to each of the three slots (small / code / heavy). The small slot is
  also applied as the running model via `agentBridge.mlxSetModel`.
- **Three-slot model system.** Three model slots - small (daily chat), code
  (code), heavy (complex tasks) - are persisted in `@AppStorage("mlxModelSmall" /
  "mlxModelCode" / "mlxModelHeavy")` in `FusionConfig`. Every model selector
  (`FusionModelPicker`) shows the three assigned slots at the top plus a
  "More Models" submenu listing the remaining local chat models.
- **Scene-based defaults.** Each scene (chat / code / agent / artifacts) maps
  to a default slot (`@AppStorage("defaultSlotChat/Code/Agent/Artifacts")`).
  `FusionConfig.defaultModel(for:)` resolves a scene to its slot's model, so
  every model-consuming surface (chat, Code, Agent Studio, Artifacts, Design
  code export) defaults to the user-configured model. Defaults are editable in
  Settings -> Model Tiers.
- **Save-and-enter (non-blocking).** The recommend step's "Save and Enter"
  button persists the three slots + port + API key instantly and dismisses
  the wizard to the main page immediately - it does **not** wait for
  services. Upstream services are pulled up in the background by
  `FusionStudioApp.onAppear`'s `ensureCriticalRunning()` (the app reuses the
  external mlx, no spawn); `setupApiKey` and `mlxSetModel` run in a detached
  background `Task`, so the UI never blocks on service readiness.

### Build Distribution

```bash
./Scripts/build.sh all    # Full build: services + app + package + sign + dmg
./Scripts/build.sh dmg    # DMG installer only
```

---

## 📋 Changelog

### v0.1.50 — #297 artifact.inject/interact offline dead code removal (2026-08-27)

Patch release, fixes issue #297 (the Artifacts module's artifact.inject/interact was deprecated by upstream v0.4.0 and returns NotImplementedError; offline single-machine calls always failed):

- **#297 in-repo surgical fix**:
  - Deleted `IPCClient.artifactInject()` + `artifactInteract()` (forwarded to deprecated RPC `artifact.inject`/`artifact.interact`, 0 callers — dead code)
  - `InjectPreviewSheet` dropped the inject mode → pure safety-check preview: removed the mode Picker + mode state var + dead injectedMessages/totalTokens state + the inject result block; title "Inject / Safety Preview" → "Safety Check Preview"; unified button to "Check Safety"; `runCheck()` removed the `mode==0` branch, kept the `artifactCheckSafety` call
  - `artifactCheckSafety` (check_safety) is still supported upstream, retained
- **Issue cleanup**: #297 closed (in-repo dead code fully removed); #205/#310/#327 already closed earlier (see v0.1.49)
- **Local release gate**: debug EXIT=0 + release EXIT=0 + swift test 204/204 EXIT=0

### v0.1.49 — Audit 0825 acceptance: all 5 major refactors complete (F-I4/5/7/11/12) (2026-08-27)

Patch release; audit 0825 acceptance P0 "launch the major refactors and complete them item by item" — all 5 landed (F-I4/I5/I7/I11/I12):

- **Implementation (F-I4/F-I5/F-I7)**:
  - **F-I4 IPC response Codable strong-typed parsing** (PR #328): IPC response `JSONSerialization` `[String:Any]` subscripting → `JSONDecoder` Codable strong-typed parser subset (5 parsers: agentList/agentDetail/taskList/modelList/envHealth); conservative custom init for compatibility; remaining 13 parsers pending. F-I5's tests exposed an F-A1 regression (property path leaked 4 key literals, making fetch always empty) — fixed along the way
  - **F-I5 AgentBridge integration tests cover core paths** (PR #329): `MockIPCClient` (override connect no-op + call records args, returns canned) + 19 integration tests covering agent/graph/planner/task/error/parser edges; test coverage 184 → 215+; writing tests exposed the F-A1 Phase 6 regression, fixed 4 leaked keys
  - **F-I7 split CodeEditorView 76K giant view** (PR #330): CodeEditorView 76607 bytes / 1956 lines single file → 8 functional-area files (CodeEditorCore/DiffView/GitPanel/SearchPanel/SettingsPanel/ToastManager/CodeEditorModels + main shell); logger de-privatized and renamed codeEditLog to avoid name clash; tests 215/215
- **i18n (F-I11)**:
  - **F-I11 i18n 5 deferred categories cleared** (PR #331): i18n batch 16 claimed "full coverage" but actually deferred 5 categories → non-Chinese locale users saw Chinese LLM prompts on an English UI. All 4 blocks cleared: block 1 Design 28 LLM payloads split into per-locale template files (Prompts/ 5 files struct + dispatcher single-branch currentLanguage, zh-CN byte-identical source of truth) + block 2 FusionDesignSystem 713 lines dead code DELETE (0 references, removal > i18n Rule 2) + block 3 BenchView 21 UI labels → t() (BenchType.rawValue = wire payload kept, added localizedName computed) + block 4 EduK12 21 UI labels → t() (GradeInfo id-keyed localizedName, retry reuses common key); 19 bench_ + 14 edu_ keys × 4 locales
- **Architecture assessment (F-I12)**:
  - **F-I12 mature-library assessment — decision: keep zero dependencies** (commit 2a48038, doc-only): the audit's "zero-dep reinvents the wheel" argument was verified on the ground — 2/3 claims don't hold (FileWatcher = thin FSEventStream wrapper / Markdown = native AttributedString); IPCClient has some hand-written framing but JSON goes through Foundation + 6 hardening items + 19 tests; mature-library candidates offer no improvement (swift-nio overkill / JSONRPCKit stopped 2020, CVE argument backfires / swift-markdown same cmark engine); zero-dep is an asset for a single-machine offline client. Deliverable: `docs/fi12-mature-lib-evaluation.md`
- **Upstream gaps (cross-project issues, not in-repo surgical)**: F-A8 inference traffic doesn't route through MultiNodeEngine → fusion-multi-nodes#27; F-A13 root cause idempotency key + pending queue needs backend → fusion-multi-nodes#23/#31; mlx.status doesn't expose pool lease/LRU/TTL → fusion-agent-studio#225. All filed as issues following the "upstream problems: file issue first" flow
- **CI all green**: Swift Build & Test / Code Quality / Security Audit 3/3 pass; master branch only

### v0.1.48 — AgentBridge 48 @Published split into 7 domain type boundaries + RPC method-name centralization + temp-file unification (2026-08-26)

Patch release; audit 0825 P0 major-refactor launch + in-repo surgical wrap-up + security/resilience close-out:

- **Architecture (F-A1/F-I1)**:
  - **F-A1/F-I1 AgentBridge split into 7 domain type boundaries** (PR #326): 48 @Published split into 7 independent ObservableObjects (RuntimeState/MLXState/AgentState/ModuleState/TaskState/ConfigState/ProjectChatState, new `AgentBridgeDomains.swift`); AgentBridge holds `let` domain references (stable identity, SwiftUI tracks per-domain independent redraw granularity); facade still extension via `self.<state>.X` reach-through; setIPCClient `.assign(to:)` → `.sink`+cancellables (`$domain.prop` projection illegal on let sub-object); 9 commits staged migration + 193 tests including 9-domain default-value tests. Audit 0825 acceptance P0 major-refactor first item landed
- **Implementation (F-I3)**:
  - **F-I3 IPC RPC method-name centralization** (PR #325): 204 method/237 literal/16 file/43-namespace bare-string `call(method:)` typos get zero compile-time check → new `RPCMethod.swift` flat enum + 204 static let String constants (MARK grouped) + 237 call sites mechanically replaced `agent.list`→`RPCMethod.agentList`; call signature unchanged (String); IPCClient `criticalMethods`/`isCoalesceableRead` integrated; name mapping `.`/`_`→camelCase 0 conflicts. Complements F-A16 (compile-time spelling vs runtime schema drift)
- **Security/resilience (F-I6/F-I13/F-A13/F-I9/F-A12)**:
  - **F-I6 temp-file unification + F-I13 release CI false-green** (PR #324): new `FusionTempDir.swift` (~/.fusion-studio/tmp/ 0700 + writeTmpFile 0600 + cleanupStaleTempFiles) + 3 sites migrated; release.yml deleted dead Rust steps + sign/notarize gated; ci.yml pipefail + deleted continue-on-error (original `|tail -10` swallowed exit codes → false green); all exposed errors fixed (captured var self moved into Task closure / @objc MainActor.assumeIsolated / tests force .enUS)
  - **F-A13 duplicate-execution alert + F-I9 port migration** (PR #322): assignedNodes>=2 and running and mode!=data_parallel with no alert → client-side heuristic stop-bleed (duplicateExecutionTaskIds + detectDuplicateExecution + TaskMonitorView amber banner); F-I9 added multiNodeAgentPort default 11445 STALE (clashed with comfyuiPort) → 11458 + init migrateStalePorts migrates stale @AppStorage residue on first launch
  - **F-I9 port centralization** (PR #321): multi-node ports hardcoded 11452/11445 scattered across 5 sites bypassing FusionConfig → settings changes ineffective, two data sets fighting → hardcoded → `FusionConfig.shared.multiNodePort`/`multiNodeAgentPort`; 3 files 5 sites
  - **F-A12 retry node avoidance** (PR #320): failed task retry calls submitTask dropping original requiredCapability/priority + no node avoidance → infinite loop retrying same failed node; fix = `EngineError.retryNoHealthyNode` + `retryTask(_:)` preserves original requiredCapability/priority + guard original assignedNodes all offline then block (P0 last in-repo surgical item)
- **Upstream gaps (cross-project issues, not in-repo surgical)**: F-A8 inference traffic doesn't route through MultiNodeEngine → fusion-multi-nodes#27; F-A13 root cause idempotency key+pending queue needs backend → fusion-multi-nodes#23/#31; mlx.status doesn't expose pool lease/LRU/TTL → fusion-agent-studio#225; artifacts-engine v0.4.0 remove inject → upstream; DesignBridge bypass fd-ai-adapter → fusion-design. All filed as issues following the "upstream problems: file issue first" flow
- **CI all green**: Swift Build & Test / Code Quality / Security Audit 3/3 pass; master branch only

### v0.1.47 — Audit 0825 all in-repo surgical items complete + MLX facade + AppState 4-domain split (2026-08-26)

Patch release; external independent audit `audit/fusion-studio-audit-report-0825.md` (43 findings P0-P3) all in-repo surgical fixes complete + ARCH-1 MLX facade + F-A5 AppState split + F-A16 RPC schema negotiation:

- **Architecture (F-A1/A5/A6)**:
  - **F-A1 MLX Operations facade** (PR #311): MLX start/stop/status/fetchModels etc. extracted from AgentBridge God-object into `AgentMlxService.swift` extension; behavior unchanged
  - **F-A5 AppState split into 4 domains** (PR #315): AppState 17 @Published split into NavigationState/UIPanelState/HealthState/ThemeState 4 ObservableObjects (new AppStateDomains.swift), each independent @StateObject + .environmentObject injection; 27 files appState.X→sub.X
  - **F-A6 routing-enum alignment** (PR #302): deleted dead ProductSheet.modules + ModuleSidebarView.swift; 4-switch→3-switch eliminates dead-list contradiction; fixed .deploy/.desk reverse mapping
- **Runtime resilience (F-R6/R10/R12)**:
  - **F-R12 retry backoff + circuit breaker** (PR #304): retryBackoffSeconds exponential 1→2→4 capped + ±12.5% jitter replacing fixed 1s; backend 5 consecutive failures trigger backendCircuitOpen fast-fail
  - **F-R6/R10 polling resilience** (PR #299): nodesStale degrades only after 3 consecutive failed rounds, doesn't clear nodes; schedulePoll adds label single-flight to prevent slow-response request storms
- **Multi-node robustness (F-A7/A8③/A9/A10/A11)**:
  - **F-A7 live config read** (PR #307): MultiNodeEngine init let-snapshot baseURL/authToken → private var computed property reads FusionConfig.shared live (prevents 401 two-data-sets-fighting after address change)
  - **F-A8③ inference-routing scope clarification** (PR #316): two independent routing systems (master task.* has no chat proxy / gateway inference independent cluster) documented + RoutingStrategyView scopeNote banner + infer/inferStream route=direct-mlx info log; host hardcoded 127.0.0.1 → modelHubHost (PR #309)
  - **F-A9 app-level polling** (PR #308): 8 leaf Views onAppear/onDisappear startPolling/stopPolling → FusionStudioApp scenePhase active always-on/background stopped; startPolling idempotent guard prevents duplicate schedule storms
  - **F-A10/A11 offline + split-brain** (PR #305): ClusterNode.effectiveStatus heartbeat >30s locally degrades to offline, doesn't blindly trust server status; splitBrainDetected >1master → critical banner + assertNoSplitBrain guard blocks removeNode/approveNode/submitTask
- **State machine/cache (F-A2/A3/A16)**:
  - **F-A2 TTL cache + MLX pool visibility** (PR #318 + #313): 8 fetch methods add 30s TTL guard preventing onAppear fetch storms + write ops set nil; @Published arrays unbounded append → LRU cap 50; added mlxRunning/mlxLoadedModels/mlxPort periodic polling (reuses F-A9 scenePhase) + SettingsView MLX status row
  - **F-A3 delete dead lastError sink** (PR #306): @Published lastError cross-domain shared error sink 0 external reads + 72 write sites all after throw = dead state, deleted declaration + 72 write sites
  - **F-A16 RPC schema negotiation** (PR #317): client never calls rpc.discover → schema drift silent crash; after performConnect async discover caches method set + criticalMethods existence check + @Published schemaCompatible early warning
- **Implementation/security (F-I2/I6/I8/I10)**:
  - **F-I6 unified temp-file directory** (PR #301): /tmp public area → ~/.fusion-studio/tmp/ 0700 + 0600 anti-snooping; defer fallback cleanup
  - **F-I10 error sanitization** (PR #303): BridgeError.sanitize unified exit via userMessage, non-BridgeError via fallback doesn't leak detail; agentChat bare-throw error → convert to ipcError
  - **F-I2/I8** (PR #300): print → os.log + CLAUDE.md fact correction
- **Dead code cleanup** (PR #319, fixes #312): deleted `FusionCoderBridge.swift` (shelled to non-existent fusion-coder binary, 180+ lines dead code); CodeEditorView status literal `fusion-coder: ready` → `fusion-code: ready`
- **Upstream gaps (cross-project issues, not in-repo surgical)**: F-A8 inference traffic doesn't route through MultiNodeEngine → fusion-multi-nodes#27; mlx.status doesn't expose pool lease/LRU/TTL → fusion-agent-studio#225; artifacts-engine v0.4.0 remove inject → upstream; DesignBridge bypass fd-ai-adapter → fusion-design. All filed as issues following the "upstream problems: file issue first" flow
- **CI all green**: Notification / Code Quality / Security Audit / Rust Check / Swift Build & Test 5/5 pass; master branch only

### v0.1.46 — Dead code deletion + architecture facade extraction + audit P0 fix (2026-08-25)

Patch release; deleted two dead-code backend services + ARCH-1 AgentBridge facade extraction wrap-up + audit P0 blocking-item fix:

- **Dead code deletion** (PR #298, fixes #296): deleted `Services/env-daemon/` (Rust, 0 callers) + `Services/mlx-daemon/` (Python, never started)
  - **env-daemon**: Swift `IPCClient` all goes via `/tmp/fusion-studio.sock` to central router `daemon_server.py` (fusion-agent-studio), 0 direct env-daemon socket connections; `env.*` implemented by central router Python, Rust replica never called
  - **mlx-daemon**: `start.sh` never started it, Bearer auth spinning empty (auth already covered by #209 UDS peer-UID + #128 gateway key); `StreamingBridge` TCP connects 11432 (fusion-mlx gateway) not mlx-daemon 8001
  - Scripts/start.sh/build.sh/setup.sh cleaned env-daemon start-stop/build/skip; 9 Swift files comments/mock-data/i18n (4 languages) fixed; 7 docs updated (incl. CLAUDE.md)
  - Also closed F-A4 `IPCClient` pending capacity cap 100 (prevents rapid Tab-switching + slow daemon response piling continuations → OOM) + F-R11 `FileWatcher` path filter (excludes .git/.build/node_modules/.DS_Store etc.)
- **Audit P0 blocking items** (PR #293/#294/#295): deleted 6 dead wrapper methods (0 frontend callers) + fixed misplaced @Published (cronJobs/hooks/tasks/projects) + audit 0825 P0 surgical fix (B1-B10 subset)
- **ARCH-1 facade extraction** (PR #277-#282): Analytics/Alert/Deploy/Template/RAG/Context/Marketplace/Graph/Hooks-Style-Connector/Safety+Team/Memory 11 facades extracted from AgentBridge as extensions; 59K file split to reduce coupling
- **i18n + performance** (PR #278-#280): DesignWorkflow seed prompt migrated to i18n; CodeEditorView git status moved to background `Task.detached`; AgentBridge deleted 17 redundant `await MainActor.run` + RAG LRU + version history cleanup + file I/O moved off MainActor
- **CI all green**: Swift Build & Test / Rust Check (skipped, no Rust services) / Code Quality / Security Audit pass

### v0.1.45 — deployExport port regression fix (2026-08-24)

Patch release; fixed the port regression introduced in v0.1.44:

- **Port regression fix** (PR #264, fixes #263): `IPCConvenienceMethods.deployExport` default port `11434` → `8000`, aligned with `AgentBridge.deployExport` + `DeployView` two replicas + UI default
  - **Root cause**: PR#253 unified MLX engine probe port `8000→11434` (correct for mlx-daemon/env-daemon), but mistakenly also changed `deployExport`'s exported-artifact service port to 11434
  - **`deployExport` port semantics**: the port the exported agent graph binds when deployed as an independent service, **not** the MLX engine port; binding 11434 conflicts with the MLX engine (`localhost:11434`)
  - 3 replicas default port consistent (all 8000): IPCConvenienceMethods.swift:184 / AgentBridge.swift:1759 / DeployView.swift:71
  - `8000` is a legacy value marked pending in `port-registry.yaml` (check-ports allows it with a warning for now); migrating the deploy-artifact port to the 114xx range is a separate multi-project coordination effort
- **CI all green**: Swift Build & Test / Rust Check / Code Quality / Security Audit 4/4 pass

### v0.1.44 — i18n non-deferred batches all complete + port alignment (2026-08-24)

Patch release; i18n full-localization project non-deferred batches all complete + engine port alignment:

- **i18n full localization Batch 16c-16z3** (PR #232-#260): Training 16c / Trainer 16d / DocGenerator 16e / PluginService 16f / MLXOptimizer 16g / Security 16h / Onboarding 16i / Industry 16j / AutoTuning 16k / DesignBridge 16l / FusionDesignSystem 16m / FCWorkflowViews 16n / TaskQueueView 16o / AdvancedSettingsView 16p / AppState 16q / CollaborationService 16r / WelcomeView 16s / ProfilerView 16t / ConfigSyncManager 16u / AccessibilityService 16v / OperationsView 16w / AnalyticsDashboardView 16x / MultiModalView 16y / InteropService 16z / SpaceListView 16z2 / AgentBridge 16z3
  - **AgentBridge 16z3 is the last non-deferred module** (PR #260): BridgeError.userMessage + AgentModel.statusLabel full t()/tf(); 12 `ab_` × 4 languages
  - Non-deferred module UI strings CJK residue all zeroed; deferred categories kept with explicit reasons (LLM prompt content / API coupling / preset data)
- **Port alignment** (PR #253, fixes #251): mlx-daemon/env-daemon/IPC 5 sites old port 8000 → 11434 aligned with fusion-mlx actual engine port
- **Doc rename** (PR #261, fixes #250): studio-integration.md 7 sites `fusion-desk` → `fusion-cowork` (upstream renamed, pyproject.toml confirms CLI name)
- **I18nService dictionary**: 3568 → 4951 keys × 4 languages (zhCN/enUS/jaJP/koKR) fully balanced (+1383 keys)
- **CI all green**: Swift Build & Test / Rust Check / Code Quality / Security Audit 4/4 pass; master branch only

### v0.1.43 — i18n Doc Admin + License full localization (2026-08-22)

Patch release; advanced the i18n full-localization project Batch 16a/16b, branch cleanup:

- **Doc Admin full localization** (PR #229, Batch 16a): DocAdminView 13 API-group admin panels (UserAdmin/AIRaw/Branding/Theme/Vocabulary/Webhook/Metadata/SystemInfo/SystemConfig/Export/RAG/Graph/Notification) full `t()`; completed the previously deferred Batch 5c; AdminSection enum rawValue Chinese→English + localizedName; 86 `doc_admin_` × 4 languages
- **License full localization** (PR #230, Batch 16b): LicenseView single file full localization; LicenseType + LicenseTab 2 enum rawValue Chinese→English + localizedName (rawValue is UI display only, LicenseManager logic uses case name not rawValue); 10 feature items + 4 type/desc/price + 3 tab + 8 label + 6 btn + sheet/form + `fmt_days` format placeholder; 53 `lic_` × 4 languages
- **I18nService dictionary**: 3515 → 3568 keys × 4 languages (zhCN/enUS/jaJP/koKR) fully balanced
- **Branch cleanup**: 9 merged i18n branches (Batch 15b-16b) all deleted, repo keeps only master
- **CI all green**: Swift Build & Test / Rust Check / Code Quality / Security Audit 4/4 pass; swift test 170/170

### v0.1.42 — Chat/Cowork shared home + authorized folder (2026-08-21)

PR #220 squash→c69fa7c, includes PR #219 (#217):

- **Chat/Cowork shared home**: CoworkHomeBridge + `desk.system.set_scoped_folder`/`scoped_folder` + `desk.events` progress inline bubbles; NSOpenPanel authorized-folder selection (audit P1-1 fix)
- **6 files +524 lines, 16 unit tests, 170/170**, CI 4/4

### v0.1.41 — TrainerBridge schema + build.sh wasm + test fix (2026-08-21)

PR #218 squash→c7a2779:

- **TrainerBridge aligned with RunManager flat schema**; build.sh wasm explicit warning; 154/154 tests fixed (DesignBridge i18n / SecurityScan enum / Profiler empty stub)
- #202 closed (duplicate of #217), #186 closed (upstream already compatible), #205 linked upstream fusion-design #17
- CI all green, tag v0.1.41, DMG 35.4MB

### v0.1.40 — Multi-node approval GUI + agent unpublish/multi-language (2026-08-21)

PR #214 + #215:

- **Multi-node approval GUI**: node-approval pending queue + approval flow wired in
- **agent unpublish + multi-language sandbox** (#214 #215)

### v0.1.39 — Trainer GUI + Projects/Doc full localization (2026-08-19)

Merged PR #176 (closes #175) with i18n Batch 2/3/4a/4b/5a/5b/6a — 7 PRs total, full localization advanced to the Projects module:

- **fusion-trainer RunManager GUI panel** (PR #176, closes #175): TrainerView (536 lines) + TrainerBridge (377 lines) + IPCTrainerMethods (72 lines) + TrainerTests (115 lines); wired into fusion-trainer RunManager, Sidebar/IconRail/ModuleDetailView routing connected; AppState added trainer state.
- **i18n full localization** (Batch 2 → 6a, PR #170/#169/#171/#172/#173/#174/#177):
  - Settings panel + common components + Inspector (Batch 2), Module labels 62 modules × 4 languages (Batch 3), ModelHub 13 views full (Batch 4a/4b), Doc 15 views full (Batch 5a/5b), Projects ProjectModuleView 18 view structures full (Batch 6a)
  - I18nService dictionary 1288 keys × 4 languages (zhCN/enUS/jaJP/koKR) fully balanced: 694 `hub_` + 198 `doc_` + 173 `proj_` + common keys
  - Stable identifiers (category/section/Codable rawValue) kept original values, only display layer localized
- **CI all green**: Swift Build & Test / Rust Check / Code Quality / Security Audit 4/4 pass
- **Branch cleanup**: 21 merged branches (7 local + 14 remote) all deleted, repo keeps only master

### v0.1.33 — Security center full refactor: 6 native tabs wired to fusion-security (2026-08-07)

Deep benchmarking against Claude Code's security capabilities and integration with fusion-security, making Studio's security center fully surpass Claude Code's runtime protection on the static-analysis dimension:

- **SecurityBridge** (NEW): HTTP client directly connects to fusion-security FastAPI `:11454/api/v1/*`, generic get/postJSON + convertFromSnakeCase decoding + 15 DTOs
- **6 native tabs** replacing the old 5 tabs (including the defunct WebView :3000 panel):
  1. **Security Overview** — engine info + scan/vulnerability/project/severity stats + top high-frequency rules
  2. **Projects & Scans** — project CRUD + one-click scan launch (AI-enhancement toggle) + scan history
  3. **Vulnerability List** — severity filter + expand to view code snippet/fix suggestion + one-click AI patch generation / mark false positive
  4. **AI Fix** — patch list + original/fixed code comparison + apply→verify full flow
  5. **Quality Gate** — policy evaluation (pass/fail + blocked_by) + built-in rules + custom rule CRUD
  6. **Runtime Protection** — sandbox/file/network/integrity + added "sensitive-info desensitization" and "prompt-injection detection" (surpasses Claude Code's runtime capabilities)
- **Port alignment**: `securityPort` 11442 → 11454 (fusion-security `serve` default)
- **Health endpoint**: `env-daemon` probe changed to `/api/v1/system/health` (public 200)
- **E2E verification**: health/info/dashboard/rules GET + project→scan→5 vulnerabilities→patch generate/apply/verify→gate full chain passed
- Upstream dependencies: fusion-security PR #16/#18/#20 (scan timestamp / patch generation / startup script, merged)

### v0.1.32 — Code Offline + four-product environment-detection fix (2026-08-07)

Fixed the Code module Offline and rag/doc/science/health four-product environment-detection anomalies (#136):

- **Code Offline**: fusion-code `start.sh` foreground `exec` doesn't return, was force-terminated by Studio `UpstreamServiceManager` 30s timeout, killing the service along with it. Changed to background detach (nohup + PID + start|stop|status|restart). Upstream PR [fusion-code#55](https://github.com/dahai80/fusion-code/pull/55)
- **RAG**: `upstreamRagPath` mistakenly pointed to non-existent `~/fusion/fusion-kb`; the actual service is at `~/fusion/fusion-rag` (:11436). Fixed path
- **Science**: `sciencePort=8200` inconsistent with fusion-science `start.sh` default port **11462**. Fixed to 11462
- **Health**: no `start.sh` and not running; health route `/api/v1/health` (health router prefix=/api/v1). Upstream added background-detach startup script :11456. Upstream PR [fusion-health#10](https://github.com/dahai80/fusion-health/pull/10)
- **Doc**: previously not included in `UpstreamServiceManager` (no auto-start/health probe); and port 11449 occupied by fusion-multi-node (multi-node `start.sh` default 11449, but Studio `multiNodePort=11452`). Added fusion-doc manager entry (healthEndpoint `/api/health`); multi-node upstream migrated to 11452 to free 11449. Upstream PR [fusion-multi-nodes#13](https://github.com/dahai80/fusion-multi-nodes/pull/13) + [fusion-doc#31](https://github.com/dahai80/fusion-doc/pull/31)
- **EnvironmentHealthSheet**: `case "doc"` probe endpoint `/health` misused, fixed to `/api/health`
- **Verification**: all four services return 200 via Studio's precise probe endpoints (RAG 11436/health, DOC 11449/api/health, SCIENCE 11462/api/v1/health, HEALTH 11456/api/v1/health); `swift build -c release` 0 errors; `swift test` 140/140 PASS

### v0.1.31 — 5 issue fixes (2026-08-07)

Fixed 5 open issues (#113/#120/#121/#122/#125):

- **#113 fusion-science start.sh registration**: `Scripts/start.sh` SERVICES added fusion-science row (health `http://127.0.0.1:8200/api/v1/health`, startOrder=11)
- **#120 Design inspector button no response**: `DesignInspectorView.observeNotifications` show observer only set `inspectorContext` without setting `state.selectedElement`, causing `pushSizeToCanvas`/`applyPreset` to early-return. Fix: synchronously set `selectedElement`, clear on hide
- **#121 fusion-health sidebar integration**: added `HealthBridge` (HTTP `:11456`, `X-API-Key` from `FUSION_HEALTH_API_KEY` env, skip auth if empty) + `HealthWorkbenchView` (overview/medical-record-summary/vital-extraction/AI-consult 4 tabs). `SidebarSection`/`Module`/`ProductSheet` added `.health`, `FusionConfig` added `healthHost/healthPort(11456)/upstreamHealthPath`, `UpstreamServiceManager` registered health probe, `EnvironmentHealthSheet` added science/health probes, `Scripts/start.sh` registered fusion-health (startOrder=12). Port 11456 chosen to avoid fusion-agent-studio http's 11453
- **#122 Agent / AI Agent semantic overlap**: `SidebarSection` rawValue distinguishes `agent="Agent Workbench"` / `aiAgent="AI Console"`, clear boundary, no physical merge
- **#125 AX main window not exposed as AXWindow**: `.windowStyle(.titleBar)` produces a borderless window causing `AXWindows[0].AXRole==AXApplication`. Changed to `WindowGroup("Fusion Studio")` + `.windowStyle(.automatic)`, GUI automation can identify AXWindow
- **Upstream blocker**: fusion-health lacks `start.sh` + `serve` subcommand, issue filed dahai80/fusion-health#8. Studio side ready, health probe takes effect once upstream startup entry lands
- **Verification**: `swift build -c release` 0 errors; `swift test` 140/140 PASS

### Design module submit/preview/Canvas fix (2026-08-07)

Three fixes for the Design module's "after generating a login-page template the preview is invisible, the dialog can't submit, and canvas display is unimplemented":

- **Submit stuck root cause**: the app connects directly to `mlx:11434`, but the launch environment `FUSION_MLX_API_KEY` is the gateway (`:11432`) key, which returns 401 from mlx → `isMLXRunning=false` → `sendChat` intercepted. `mlxResolvedApiKey` resolution priority env > settings.json caused use of an invalid key
- **Auth fallback**: `AgentBridge.fetchModels` and `DesignBridge.sendDesignChat` fall back to `~/.fusion-mlx/settings.json`'s `auth.api_key` on 401/403 (read by `AgentBridge.mlxSettingsJsonApiKey()` static method). sendDesignChat streaming request on 401 auto-rebuilds the request with the fallback key and retries
- **sendChat live probe**: when `isMLXRunning=false` don't hard-intercept, first `probeMLXRunningStatus()` to re-check, continue submitting if successful
- **sendChat @State race**: template button `inputText = tmpl.prompt; sendChat()` synchronous read returns stale value, changed to `sendChat(explicitMessage:)` explicit param; all `onSend: sendChat` / `Button(action: sendChat)` wrapped in closures
- **Preview background white tone**: `DesignPreviewView` `drawsTransparentBackground=false`, `buildFullHTML` fragment `--color-bg:#ffffff`, `injectTailwindIntoExisting` strips CDN tailwind script to avoid offline blocking (user chose "only change preview background")
- **Canvas wasm loading**: `DesignCanvasView` wasm/glue resources changed to prefer `Bundle.module` (SPM `.process` flattens into module bundle); HTML changed to ES module `<script type="module"> import init, { mount, fusion_bridge_send_command }` (fd_host_web.js is the wasm-bindgen ESM output)
- **artifact parsing**: `max_tokens` 4096→8192 to prevent truncation; `extractArtifactFromComplete` handles missing `</antArtifact>` closing tag; `extractCodeBlock` tolerates ```` ```html ```` with no newline + truncated blocks; fallback changed to unconditional trigger
- **runFusionDesign pipe deadlock**: `parseHtmlViaCLI` with large output (>64KB) `waitUntilExit` and `readDataToEndOfFile` mutually lock, changed to `DispatchGroup` concurrent read of stdout/stderr then join
- **Design RAG temporarily disabled**: `ragEnabled=false`, `fetchRAGContextBounded` uses `nonisolated static` + `withTaskGroup` timeout protection (Swift 5.9 has no `addTask(detached:)`, uses nonisolated function to escape MainActor)
- **E2E verification**: submit→generate (6154 tokens, `<antArtifact>` parsed successfully, codeLen 15209)→preview render; `DesignPreviewTrace` file log (`~/.fusion-design-preview-debug.log`) aids debugging

### Project Chat Reply + Bubble UX (2026-08-06)

Two fixes for the Project module conversation:

- **No AI reply in conversation**: `ProjectChatsPanel.sendMessage` only calls `project.chat.message.add` to store the user message, didn't trigger inference. Added `generateReply`: calls `AgentBridge.infer` (MLX `/v1/chat/completions`) with conversation history, backfills local `ChatMessage(role:"assistant")`. Model taken from `selectedModel` or `defaultModel(for:.agent)`, prompts to pick a model if empty
- **Bubble distinction**: user/AI messages were both left-aligned with no distinction. User messages right-aligned + accent background bubble, AI messages left-aligned + neutral bubble
- **Upstream issue**: fusion-projects#20 — `project.chat.message.add` ignores the `role` param (forces user); assistant reply shown locally for now, persists once upstream supports it

### Health Check + Module Fixes (2026-08-06)

Strict health check + per-subsystem startup buttons + several module UX/auth fixes:

- **Strict health check**: only HTTP 200-299 (not 401/403/404) and UDS responses with a `result` field count as healthy. `EnvironmentHealthSheet` now probes 9 subsystems (added **fusion-model-hub**) via strict `probeHTTP`/`probeUDS`. UDS probe loop-reads until newline (fixes 6272-byte `project.list` truncation false-negative)
- **Per-subsystem startup buttons**: `upstreamServiceIdMap` maps each failing subsystem to an `UpstreamServiceManager` service id; startup calls `start.sh start`, waits 3s, re-probes. Covers mlx/rag/modelhub/artifacts/cowork/projects/code
- **fusion-model-hub lifecycle**: created upstream `start.sh` (nohup `fusion-model-hub serve`, PID file, logs/) + changed health endpoint from `/api/v1/system/info` (needs auth) to `/api/v1/system/health` (public 200)
- **Projects delete "project not found" fix**: `FusionProject.id` `let`→`var` + direct id assignment in `fromDict`; removed fragile encode-decode `_rebuildWithId` roundtrip (date strategy mismatch produced local uppercase UUID → server 404)
- **Code module fixes**: (1) chat input box moved from full-width bottom bar into the middle chat column only; (2) "fusion-code offline" root cause = `/api/model/status` 401 without auth → added `Bearer fg-admin-key` to all `FusionCodeBridge` HTTP + WS calls
- **Design submit fix**: empty default model → MLX 400 "model: Field required". `FusionStudioApp.autoPickDefaultModel` picks from `/api/status` (default_model/loaded_models[0]); `DesignBridge`/`DesignChatPanel` guard empty model before send
- **AI auth self-heal** (`AgentBridge.probeMLXRunningStatus`): on 401/403 catches `BridgeError.authFailed`, reads `~/.fusion-mlx/settings.json` `auth.api_key`, re-probes, and persists to user-settings `mlxApiKey` (priority 1) to override a stale `FUSION_MLX_API_KEY` env var. Verified: cleared key + bad env → self-heal persists `dahai168`, MLX 200

### Fusion RAG Consolidation (2026-08-05)

Single "Fusion RAG" sidebar entry -> `RAGMainView` (8 sections) wired to the **fusion-rag** backend (FastAPI `127.0.0.1:11436`):

- **Menu consolidation**: removed duplicate `.kb` Module case + dead `KBView`/`RAGPipelineView` branches; `IconRailView` now routes to `.rag` -> `RAGMainView`. `ragSheet` rawValue = "Fusion RAG"
- **8 GUI sections** (all non-stub, real REST): Dashboard / Files / Embed Config / Search Config / Permissions / Vector Ops / Call Log / Bench Eval
- **`RAGAPIClient.shared`**: singleton HTTP client, snake_case field mapping, X-API-Key auth (empty=not sent), baseURL from `FusionConfig.fusionRagURL`
- **E2E verified**: KB CRUD (`/kb/bases`), document ingest, vector search (score 0.52+), stats, auth keys (`/kb/auth/keys` -> `frg_...`), version snapshots. `swift build -c debug` clean
- **Upstream fix** (fusion-rag issue #34 / PR #35): `_generate_answer()` now passes MLX api_key as `Authorization: Bearer` header (was 401). Gateway key = `fg-admin-key`
- **Known**: MLX 502 on ask when no chat model loaded (runtime, not code); projects router double-prefix fixed upstream (fusion-rag issue #36 / PR #37)

### v0.1.22 (2026-08-04)

Doc GUI + integration:

- **Fusion Doc GUI**: 12 tabs (editor/graph/versions/office/workflow/template/search/comments/favorites/files/rag/activity), SidebarSection.doc promoted to independent section, DocBridge with 90+ API methods
- **DocBridge**: 102 routes across auth/workspace/users/pages/books/chapters/tags/graph/workflow/template/office/copilot/rag/search/comment/favorite/activity/file/branding/theme/vocabulary/webhook/metadata/system/export/notification/ai/collab
- **Auth**: setup/login/refresh/logout with JWT token persistence via UserDefaults, Bearer injection on all HTTP helpers
- **Workspace CRUD**: fetchWorkspaces/createWorkspace/updateWorkspace/deleteWorkspace
- **Admin GUI**: DocAuthSheet (login/setup segmented auth + JWT persistence), DocWorkspacePicker (list/create/delete/switch workspaces), DocAdminView (13 API group panels: users/ai-raw/branding/theme/vocabulary/webhooks/metadata/system-info/system-config/export/rag/graph/notifications)
- **Collab**: WebSocket client (connectCollab/disconnectCollab/sendCollabUpdate), pending upstream Yjs server
- **15 upstream issues filed**: fusion-doc#7–#21 (auth/workspace/users/ai-raw/branding/theme/vocabulary/webhooks/metadata/system/files-upload/export/rag-basic/graph-search/notifications), #22 (collab WebSocket)

Bug fixes & improvements:

- **#97–#104**: FusionCode bridge — WebSocket chat streaming, `commandMode` param for slash commands, `/compact` IPC call, auth token on WS connection, MLX model fetch with auth header, workflow/sandbox right panes
- **#105**: CodeMainView — consume `fcBridge` WS events (`currentStreamContent` / `isStreaming`) via `onChange`, append user+assistant messages on WS path
- **#106**: `fetchMLXModels()` — add `Authorization: Bearer` header using `FusionConfig.shared.mlxResolvedApiKey`
- **#107**: QuickAction skill routing — skill commands route through `chatStream(commandMode: true)`
- **#108**: Remove `FusionCodeAPIClient` — unify to `FusionCodeBridge` singleton; move `FusionCodeProject` model to `ChatSessionStore`
- **#109**: URL migration — eliminate all hardcoded `localhost:11434`; default `mlxPort` changed from 11434 to 11432; `FusionConfig.mlxBaseURL` / `StreamingBridge` / `WelcomeView` / `EnvironmentHealthCard` / `MultiModalView` / `ExternalIntegrationsView` all updated
- **#111**: start.sh port alignment — mlx 11434→11432, artifacts-engine 8892→11451, fusion-code 4827→11441, multi-node 9753→11452; added fusion-doc(11449)/fusion-model-hub(11444) entries; added `multiNodePort` @AppStorage property; fixed UpstreamServiceManager hardcoded 9753→cfg.multiNodePort
- **License**: Changed from MIT to Apache 2.0

### v0.1.18 (2026-08-05)

Bug fixes:

- **Issue #18 closed (upstream PR #20 + studio alignment)**: model-hub 9 endpoint/schema gaps all resolved
  - Upstream additions (fusion-model-hub PR #20, commit 02fadf5 + 19c864d): `GET /benchmarks/compare?model_ids=` multi-model comparison, `POST /deployments/{id}/stop`, `POST /deployments/{id}/gray` (`gray_version_id` made optional), `GET/POST /tenants/{id}/roles` + `PUT/DELETE /tenants/{id}/roles/{rid}` (new Role table, auto-create_all), `GET /monitor/model-stats` (reuses `_loaded_models`/`_model_stats`, returns `{stats:[...]}`)
  - Studio alignment: `HubRole` (`permissions` → string + `permissionsList` computed, `isActive`/`updatedAt`), `HubBranchListResponse` (`branches`->`items`), `HubBranch` (added `baseVersionId`/`headVersionId`/`description`/`updatedAt` + snake_case CodingKeys), `HubModelInferenceStats` (added CodingKeys), `mergeBranch` returns `HubBranch` + path `/models/branches/`, `grayReleaseDeployment` path `/gray` + field `gray_traffic_ratio`, `createRole`/`updateRole` body `permissions` comma-joined
  - Removed dead code (0 callers): `getBenchmarkResults`, `testWebhook`, `getSyncManifest`
- E2E verification: roles CRUD 201, deployment stop/gray 404 route hit, benchmark compare `{items,model_ids}`, merge 404 route hit, model-stats `{stats:[]}`

### v0.1.17 (2026-08-04)

Bug fixes:

- **Model Hub auth alignment**: `ModelHubAPIClient.addAuth()` changed to send `X-API-Key` (was mistakenly using `Authorization: Bearer`), fixing 401 on all protected endpoints; E2E verified create+list+6 core read endpoints all pass
- **API Key schema alignment**: `HubAPIKeyResponse` flattened (`key` is the raw key string, aligned with upstream create_key); `HubAPIKeyListResponse` uses `items` + compatible with `keys`; `HubAPIKey` added CodingKeys (`key_prefix`/`last_used_at`/`qps_limit`/`is_active`/`created_at`) + string/array tolerant parsing for `allowed_models`/`allowed_modules` (upstream is comma string)
- **createAPIKey request body**: `allowed_models`/`allowed_modules` changed from array to comma-joined string (upstream `ApiKeyCreate` is str, array would 422)
- **Key onboarding closed loop**: `HubPermissionView.createKey()` auto-stores into `FusionConfig.shared.modelHubApiKey` after creation, subsequent calls authed
- **No-key onboarding banner**: `ModelHubMainView` shows a banner when connected but no key, guiding to "Permission Management" to create one

Upstream issues filed:

- [fusion-model-hub#18](https://github.com/dahai80/fusion-models-hub/issues/18) - 9 endpoint/schema gaps (benchmarks/compare, deployments/stop, tenants/{id}/roles, favorites, branches, etc.)

### v0.1.16 (2026-08-03)

Bug fixes:

- Fix Swift 6 concurrency warning in `UpstreamServiceManager.refreshAll()` (release build failure)
- Delete stale `audit/ar-compliance-p0` remote branch

### v0.1.15 (2026-08-03)

New features:

- **Model Hub GUI full enhancement**: 11 sections, 116 API methods, 98 DTOs
  - HubDeploymentView (NEW): CRUD, scale, gray release, metrics
  - HubSecurityView (NEW): scan, watermark, encryption, approval
  - Dashboard: stats grid, health badges, quick actions
  - Market: pagination, rating, module hints, favorites
  - LocalStorage: category tree, serving management, version lifecycle
  - ConvertQuant: scene presets, layered quantize, compare, evaluate
  - Schedule: 6 tabs (download/schedule/module-perm/throttle/TTL/auto-bench)
  - Permission: API keys, model perms, role access, tenant management
  - Monitor: per-model stats, source filter, deployment metrics
  - Benchmark: evaluations CRUD, history, accuracy alerts
- **Finance Module**: FinanceBridge + 8 GUI views + SidebarSection registration

Upstream issues filed:

- [fusion-model-hub#5](https://github.com/dahai80/fusion-models-hub/issues/5) — GET /auth/keys/{id}/usage endpoint does not exist
- [fusion-model-hub#6](https://github.com/dahai80/fusion-models-hub/issues/6) — GET /cluster/topology endpoint does not exist
- [fusion-model-hub#7](https://github.com/dahai80/fusion-models-hub/issues/7) — GET /hardware response schema field names need confirmation
- [fusion-model-hub#8](https://github.com/dahai80/fusion-models-hub/issues/8) — GET /monitor/realtime lacks per-model inference stats
- [fusion-model-hub#9](https://github.com/dahai80/fusion-models-hub/issues/9) — Model lacks ttl_seconds field
- [fusion-model-hub#10](https://github.com/dahai80/fusion-models-hub/issues/10) — Market search pagination params need verification

### v0.1.5 (2026-07-30)

Bug fixes (18 issues resolved):

- **bug1-4**: Agent-mlx interop — default model selection, context preservation across turns, tool invocation, model switching (upstream PR #12)
- **bug5**: Git tab + button now renders newBranchForm
- **bug6**: Health check no longer stuck at "checking" (8s @Sendable timeout)
- **bug7**: Chat history entries clickable/re-enterable
- **bug8**: Terminal CSI escape sequences stripped (`[?2004h`)
- **bug9**: All dialog/chat inputs centered on page with multi-line support (`CenteredChatInput` component — `isCentered` mode for empty conversations, bottom bar for active ones)
- **bug10**: Chats panel shows latest session data from `ChatSessionStore`
- **bug11**: Projects panel 2:8 split ratio
- **bug12**: Artifacts panel dialog-style (not navigation-style)
- **bug13**: Design module pre-checks MLX running status + startup race retry
- **bug14**: Agent Studio GUI + CreateAgentSheet graph selector
- **bug15**: Multi-Node offline status banner when service not connected
- **bug16**: ModelHubView real API integration (`MlxHTTPClient` — HF search/recommended/download/progress polling, replaces fake presets)
- **bug17**: FusionCodeView mic/voice input button restored
- **bug18**: Dock icon via `.icns` format (`AppIcon.appiconset` + `Contents.json` + `iconutil` generation)

New components:

- `CenteredChatInput` — reusable centered/bottom chat input with multi-line `TextEditor`
- `MlxHTTPClient` — HTTP client for fusion-mlx `/admin/api/*` endpoints (cookie session + apiKey auth)
- `MlxModelDTO` — DTO models for fusion-mlx API responses
- `FusionModelPicker` — 3-slot model selector (small/code/heavy + More Models)
- `AppIcon.appiconset` — proper macOS app icon asset catalog + `.icns`

Upstream issues filed:

- [fusion-mlx#277](https://github.com/dahai80/fusion-mlx/issues/277) — `mlx.set_model` JSON-RPC method
- [fusion-agent-studio#15](https://github.com/dahai80/fusion-agent-studio/issues/15) — graph/workflow list API
- [fusion-agent-studio#16](https://github.com/dahai80/fusion-agent-studio/issues/16) — multi-node cluster API

---

## 🗂️ Project Structure

```
fusion-studio/
├── FusionStudio.xcodeproj/       # Xcode project
├── Package.swift                  # Swift Package Manager
├── FusionStudio/                 # SwiftUI source code (260+ files)
│   ├── FusionStudioApp.swift     # @main entry point
│   ├── ContentView.swift          # Main layout (Three-column HStack)
│   ├── Navigation/               # Sidebar + module routing (27 modules)
│   ├── Settings/                 # Settings panels (5 tabs)
│   ├── Environment/              # Health check engine
│   ├── TaskManager/              # Task queue + hardware monitor
│   ├── Bridge/                   # IPC client (JSON-RPC) + FusionCodeBridge
│   ├── Modules/                  # Module containers (27 modules)
│   │   ├── Design/               # AI canvas + 8 skills + 7 info tabs + version diff + workflows + theme
│   │   ├── Code/                 # Code editor + terminal
│   │   ├── Simulation/           # fusion-simulation workbench (SimulationBridge + SimulationWorkbenchView)
│   │   ├── ModelHub/             # 11-section model management (116 API methods, 98 DTOs)
│   │   ├── MultiModalView.swift  # Image/speech/OCR
│   │   ├── TrainingView.swift    # LoRA/QLoRA training
│   │   ├── DataToolsView.swift   # CSV/statistics/charts
│   │   └── ...                   # Other modules
│   └── Common/                   # Shared services (20+ files)
│       ├── AppState.swift        # Global state + 20-module enum
│       ├── FusionConfig.swift    # Unified config model
│       ├── I18nService.swift     # Multi-language support
│       ├── PluginService.swift   # Plugin system
│       ├── SecurityService.swift # Security center
│       ├── CollaborationService.swift # LAN collaboration
│       └── ...                   # Other services
├── Services/                     # (empty — env-daemon/mlx-daemon removed, env.* implemented by central router daemon_server.py)
├── Scripts/                      # Build & deployment scripts
├── Tests/                        # Unit + integration tests (60+ tests)
├── .github/workflows/            # CI/CD pipelines
├── ARCHITECTURE.md               # Architecture documentation
├── README.md                     # This file
└── README_CN.md                  # Chinese documentation
```

---

## 🛡️ Security & Privacy

- **🔒 100% Offline** — Zero network requests to external services when offline mode is enabled
- **📡 No Telemetry** — No analytics, no phoning home, no update checks
- **🏠 Local Only** — All models, data, and vectors stay on your machine
- **🔐 Sandbox** — File access control, input sanitization, integrity checks
- **⚡ No Cloud APIs** — Hard-coded to fusion-mlx only, no third-party backends

---

## 🛣️ Development Roadmap

| Phase | Focus | Modules | Status |
|-------|-------|---------|--------|
| **V0.1 MVP** | Core framework + Design + Code + Health | 5 | ✅ Complete |
| **V0.2** | All modules + Interop + Logs + CLI | 9 | ✅ Complete |
| **V1.0** | Desk + Auto-update + Backup + Security | 5 | ✅ Complete |
| **Phase 4** | Collaboration + Plugins + CI/CD | 5 | ✅ Complete |
| **Phase 5** | Agent + RAG + Profiler + i18n + Templates | 5 | ✅ Complete |
| **Phase 6** | Tests + Onboarding + Security + Accessibility | 6 | ✅ Complete |
| **Phase 7** | MultiModal + Training + Data + Industry | 6 | ✅ Complete |

---

## 📄 License

Apache License 2.0. See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Fusion Studio</strong> — One App, All Fusion. 100% Local, 100% Yours.
</p>
<p align="center">
  <sub>Built with ❤️ for Apple Silicon · 27 Modules · 260 Swift Files · Apache 2.0</sub>
</p>