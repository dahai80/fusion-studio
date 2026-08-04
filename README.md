<div align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-brightgreen" alt="macOS">
  <img src="https://img.shields.io/badge/Apple%20Silicon-M1--M5-orange" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/Swift-5.9-red" alt="Swift">
  <img src="https://img.shields.io/badge/Rust-2021-purple" alt="Rust">
  <img src="https://img.shields.io/badge/license-Apache%202.0-blue" alt="License">
  <img src="https://img.shields.io/badge/status-V0.1.22-yellow" alt="V0.1.22">
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
| 📋 **Global Task Queue** | Background task management with persistence |
| 🔌 **Plugin System** | Third-party extension support |
| ♿ **Accessibility** | VoiceOver, keyboard navigation, reduce motion |
| 🌐 **i18n** | Chinese, English, Japanese, Korean |
| 🔒 **Security Center** | Sandbox, file access control, integrity check |

### 🧩 Module Overview

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
| 16 | 🔒 **Security** | `shield.checkered` | ✅ Stable | Security scan, event monitoring, config hardening |
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
| Right - Inspector | `FusionTabBar` (状态/环境/快照): full status rows, env_check component dots, snapshot save/restore |
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
│  ⚙️ Service Layer — Rust/Python Daemon Processes              │
│  env-daemon · mlx-daemon · supervisor                        │
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
│   </> 编码        │                             │              │
│   ✏️ 设计         │                             │              │
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
| Storage | **SQLite + UserDefaults** | Zero-config, local-first, encrypted |
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

# 2. Build Rust services
cd Services/env-daemon && cargo build --release && cd ../..

# 3. Build SwiftUI app
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
| fusion-kb (RAG) | `~/fusion/fusion-kb/start.sh` | `127.0.0.1:11436` | optional |
| fusion-doc | `~/fusion/fusion-doc/start.sh` | `127.0.0.1:11449` | optional |
| fusion-multi-node | `~/fusion/fusion-multi-node/start.sh` | `127.0.0.1:11452` | optional |
| fusion-model-hub | `~/fusion/fusion-model-hub/start.sh` | `127.0.0.1:11444` | optional |
| fusion-design | (CLI tool, no start.sh) | - | n/a |

- Critical services auto-start in order: mlx -> agent-studio -> artifacts-engine.
- Optional services are detected only; start them manually from the UI.
- Each `start.sh` supports `start | stop | restart | status` (exit 0 = running).
- The Dashboard shows each service's status (运行中 / 未启动 / 服务不存在 /
  启动失败) with start / stop / retry controls. A banner appears when a critical
  service is missing or failed to start.
- Upstream repo paths and the auto-start toggle live in Settings
  (`FusionConfig.upstream*Path`, `upstreamAutoStartCritical`, default on).

### First-Run Onboarding (三档模型引导)

On first launch, if no small-model slot is set (`@AppStorage("mlxModelSmall")` empty),
Fusion Studio shows a 6-step onboarding wizard reused from fusion-mac's
`WelcomeWindow` and adapted to this app's architecture. It can be re-entered
anytime via Settings → General → "重新选择主模型".

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
- **Three-slot model system.** Three model slots - small (日常对话), code
  (代码), heavy (复杂事务) - are persisted in `@AppStorage("mlxModelSmall" /
  "mlxModelCode" / "mlxModelHeavy")` in `FusionConfig`. Every model selector
  (`FusionModelPicker`) shows the three assigned slots at the top plus a
  "More Models" submenu listing the remaining local chat models.
- **Scene-based defaults.** Each scene (chat / code / agent / artifacts) maps
  to a default slot (`@AppStorage("defaultSlotChat/Code/Agent/Artifacts")`).
  `FusionConfig.defaultModel(for:)` resolves a scene to its slot's model, so
  every model-consuming surface (chat, Code, Agent Studio, Artifacts, Design
  code export) defaults to the user-configured model. Defaults are editable in
  Settings -> 模型档位.
- **Save-and-enter (non-blocking).** The recommend step's "保存并进入" button
  persists the three slots + port + API key instantly and dismisses the wizard
  to the main page immediately - it does **not** wait for services. Upstream
  services are pulled up in the background by `FusionStudioApp.onAppear`'s
  `ensureCriticalRunning()` (the app reuses the external mlx, no spawn);
  `setupApiKey` and `mlxSetModel` run in a detached background `Task`, so the UI
  never blocks on service readiness.

### Build Distribution

```bash
./Scripts/build.sh all    # Full build: services + app + package + sign + dmg
./Scripts/build.sh dmg    # DMG installer only
```

---

## 📋 Changelog

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

- **Issue #18 闭环（上游 PR #20 + studio 对齐）**: model-hub 9 端点/schema 缺口全部解决
  - 上游新增（fusion-model-hub PR #20, commit 02fadf5 + 19c864d）: `GET /benchmarks/compare?model_ids=` 多模型对比、`POST /deployments/{id}/stop`、`POST /deployments/{id}/gray`（`gray_version_id` 改可选）、`GET/POST /tenants/{id}/roles` + `PUT/DELETE /tenants/{id}/roles/{rid}`（新增 Role 表，auto-create_all）、`GET /monitor/model-stats`（复用 `_loaded_models`/`_model_stats`，返回 `{stats:[...]}`）
  - studio 对齐: `HubRole`（`permissions` 改字符串 + `permissionsList` 计算、`isActive`/`updatedAt`）、`HubBranchListResponse`（`branches`->`items`）、`HubBranch`（加 `baseVersionId`/`headVersionId`/`description`/`updatedAt` + snake_case CodingKeys）、`HubModelInferenceStats`（加 CodingKeys）、`mergeBranch` 返回 `HubBranch` + 路径 `/models/branches/`、`grayReleaseDeployment` 路径 `/gray` + 字段 `gray_traffic_ratio`、`createRole`/`updateRole` body `permissions` 逗号拼接
  - 移除死代码（0 调用）: `getBenchmarkResults`、`testWebhook`、`getSyncManifest`
- E2E 验证: roles CRUD 201、deployment stop/gray 404 路由命中、benchmark compare `{items,model_ids}`、merge 404 路由命中、model-stats `{stats:[]}`

### v0.1.17 (2026-08-04)

Bug fixes:

- **Model Hub auth 对齐**: `ModelHubAPIClient.addAuth()` 改发 `X-API-Key`（原误用 `Authorization: Bearer`），修复所有受保护端点 401；E2E 验证 create+list+6 核心读端点全通
- **API Key schema 对齐**: `HubAPIKeyResponse` 改扁平（`key` 为原始密钥字符串，对齐上游 create_key）；`HubAPIKeyListResponse` 用 `items` + 兼容 `keys`；`HubAPIKey` 加 CodingKeys（`key_prefix`/`last_used_at`/`qps_limit`/`is_active`/`created_at`）+ 字符串/数组兼容解析 `allowed_models`/`allowed_modules`（上游为逗号字符串）
- **createAPIKey 请求体**: `allowed_models`/`allowed_modules` 由数组改逗号拼接字符串（上游 `ApiKeyCreate` 为 str，数组会 422）
- **Key 引导闭环**: `HubPermissionView.createKey()` 创建后自动存入 `FusionConfig.shared.modelHubApiKey`，后续调用即鉴权
- **No-key 引导横幅**: `ModelHubMainView` 连接但无 key 时显示横幅，引导到「权限管控」创建

Upstream issues filed:

- [fusion-model-hub#18](https://github.com/dahai80/fusion-models-hub/issues/18) - 9 端点/schema 缺口（benchmarks/compare, deployments/stop, tenants/{id}/roles, favorites, branches 等）

### v0.1.16 (2026-08-03)

Bug fixes:

- Fix Swift 6 concurrency warning in `UpstreamServiceManager.refreshAll()` (release build failure)
- Delete stale `audit/ar-compliance-p0` remote branch

### v0.1.15 (2026-08-03)

New features:

- **Model Hub GUI 全量增强**: 11 sections, 116 API methods, 98 DTOs
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

- [fusion-model-hub#5](https://github.com/dahai80/fusion-models-hub/issues/5) — GET /auth/keys/{id}/usage 端点不存在
- [fusion-model-hub#6](https://github.com/dahai80/fusion-models-hub/issues/6) — GET /cluster/topology 端点不存在
- [fusion-model-hub#7](https://github.com/dahai80/fusion-models-hub/issues/7) — GET /hardware 响应 schema 字段名需确认
- [fusion-model-hub#8](https://github.com/dahai80/fusion-models-hub/issues/8) — GET /monitor/realtime 缺少模型级推理统计
- [fusion-model-hub#9](https://github.com/dahai80/fusion-models-hub/issues/9) — Model 缺少 ttl_seconds 字段
- [fusion-model-hub#10](https://github.com/dahai80/fusion-models-hub/issues/10) — Market 搜索分页参数需验证

### v0.1.5 (2026-07-30)

Bug fixes (18 issues resolved):

- **bug1-4**: Agent-mlx interop — default model selection, context preservation across turns, tool invocation, model switching (upstream PR #12)
- **bug5**: Git tab + button now renders newBranchForm
- **bug6**: Health check no longer stuck at "检测中" (8s @Sendable timeout)
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
├── Services/                     # Background daemon processes
│   ├── env-daemon/               # Rust — Health check + repair
│   └── mlx-daemon/               # Python — MLX service manager
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