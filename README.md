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
| 🔒 **Security Center** | SAST 扫描 + AI 修复 + 质量门禁 + 运行时防护（沙箱/脱敏/注入检测） |

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
| 16 | 🔒 **Security** | `shield.checkered` | ✅ Stable | 6 原生 tab：安全概览/项目与扫描/漏洞清单/AI 修复/质量门禁/运行时防护，直连 fusion-security :11454 |
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

# 2. Build SwiftUI app (env.* 由中央路由 daemon_server.py 实现, 无本地 Rust 服务)
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
- The Dashboard shows each service's status (运行中 / 未启动 / 服务不存在 /
  启动失败) with start / stop / retry controls. A banner appears when a critical
  service is missing or failed to start.
- Upstream repo paths and the auto-start toggle live in Settings
  (`FusionConfig.upstream*Path`, `upstreamAutoStartCritical`, default on).

#### API Key 解析（gateway 入站鉴权）

fusion-studio 默认通过 fusion-gateway(`:11432`) 连接 fusion-mlx，gateway 使用
自己的入站 key（非 mlx `settings.json` 的 key）。`FusionConfig.mlxResolvedApiKey`
按以下优先级解析（与上游 fusion-mlx `_resolve_api_key` 对齐）：

1. 用户在 Settings 显式设置（`mlxApiKey`，存 macOS **Keychain**，service `com.fusion.studio`）
2. 进程环境变量 `FUSION_MLX_API_KEY`（fusion-mlx/fusion-gateway 启动时注入）
3. `~/.fusion-mlx/settings.json` → `auth.api_key`

解析来源记录到 `os.log`（subsystem `com.fusion.studio`, category `FusionConfig`）。
启动 fusion-gateway/mlx 时导出 `FUSION_MLX_API_KEY` 即可让 studio 取到正确入站 key。

> **密钥存储 (HIGH-2)**：`mlxApiKey` / `fusionRagApiKey` / `modelHubApiKey` 均存 Keychain，
> 不再落 UserDefaults plist 明文。`fusionCodeApiKey` 为 per-instance 随机 token（首次生成落
> Keychain + `~/.fusion-studio/fusion-code.token` 0600），旧硬编码 `fg-admin-key` 已移除。
> fusion-code 服务端 authToken 默认空导致鉴权 fail-open，见上游 issue [dahai80/fusion-code#132](https://github.com/dahai80/fusion-code/issues/132)。

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

### v0.1.50 — #297 artifact.inject/interact 离线死代码删除 (2026-08-27)

补丁版本，修复 issue #297 (Artifacts 模块 artifact.inject/interact 上游 v0.4.0 已废弃返回 NotImplementedError，离线单机调用恒失败):

- **#297 仓内外科修复**：
  - 删 `IPCClient.artifactInject()` + `artifactInteract()` (转发至已废弃 RPC `artifact.inject`/`artifact.interact`，0 caller 死代码)
  - `InjectPreviewSheet` 去 inject 模式 → 纯 safety check 预览: 删 mode Picker + mode state var + injectedMessages/totalTokens 死 state + inject 结果块; 标题 "Inject / Safety Preview"→"Safety Check Preview"; 按钮统一 "Check Safety"; `runCheck()` 删 `mode==0` 分支保留 `artifactCheckSafety` 调用
  - `artifactCheckSafety` (check_safety) 上游仍支持, 保留
- **issue 清理**: #297 关闭 (repo 侧死代码删净); #205/#310/#327 前序已关闭 (见 v0.1.49)
- **本地 release gate**: debug EXIT=0 + release EXIT=0 + swift test 204/204 EXIT=0

### v0.1.49 — 审计 0825 验收 5 项重大重构全完 (F-I4/5/7/11/12) (2026-08-27)

补丁版本，审计 0825 验收 P0 "重大重构启动起来逐项完成" 5 项全部落地 (F-I4/I5/I7/I11/I12):

- **实现 (F-I4/F-I5/F-I7)**：
  - **F-I4 IPC 响应 Codable 强类型解析** (PR #328)：IPC 响应 `JSONSerialization` `[String:Any]` 下标 → `JSONDecoder` Codable 强类型 parser 子集 (5 parser: agentList/agentDetail/taskList/modelList/envHealth)；Conservative custom init 保兼容；其余 13 parser 待做。F-I5 写测试暴露 F-A1 regression (属性路径泄 4 key 字面量致 fetch 恒空) 顺手修
  - **F-I5 AgentBridge 集成测试覆盖核心路径** (PR #329)：`MockIPCClient` (override connect no-op + call 记 args返 canned) + 19 集成测试覆盖 agent/graph/planner/task/error/parser edge；测试覆盖 184→215+；写测试暴露 F-A1 Phase 6 regression 修 4 泄漏 key
  - **F-I7 拆 CodeEditorView 76K 巨型视图** (PR #330)：CodeEditorView 76607 bytes/1956 行单文件 → 8 功能区文件 (CodeEditorCore/DiffView/GitPanel/SearchPanel/SettingsPanel/ToastManager/CodeEditorModels + 主壳)；logger 去 private 撞名重命名 codeEditLog；test 215/215
- **i18n (F-I11)**：
  - **F-I11 i18n 延后 5 类清完** (PR #331)：i18n 16 批号称"全量"实 5 类延后 → 非中文 locale 用户英文界面冒中文 LLM prompt。4 块全清: 块1 Design 28 LLM payload 按.locale 分模板文件 (Prompts/ 5 文件 struct + dispatcher 单分支 currentLanguage, zh-CN byte-identical source of truth) + 块2 FusionDesignSystem 713 行死代码 DELETE (0 引用, 删>i18n Rule 2) + 块3 BenchView 21 UI label→t() (BenchType.rawValue=wire payload 保, 加 localizedName computed) + 块4 EduK12 21 UI label→t() (GradeInfo id-keyed localizedName, retry 复用通用 key)；19 bench_ + 14 edu_ key × 4 locale
- **架构评估 (F-I12)**：
  - **F-I12 成熟库评估 — 决策维持零依赖** (commit 2a48038, doc-only)：审计 "零依赖 reinvent 轮子" 论据实地复核 2/3 不成立 (FileWatcher=FSEventStream 薄封装 / Markdown=AttributedString 原生)；IPCClient 部分手写分帧但 JSON 走 Foundation + 6 项加固 + 19 测试；成熟库候选无更优 (swift-nio overkill / JSONRPCKit 2020 停维反噬 CVE 论点 / swift-markdown 同 cmark 引擎)；零依赖是单机离线客户端正资产。交付件 `docs/fi12-mature-lib-evaluation.md`
- **上游缺口 (跨工程 issue，非本仓可外科)**：F-A8 推理流量不经 MultiNodeEngine 路由 → fusion-multi-nodes#27；F-A13 真因 idempotency key+pending 队列需后端 → fusion-multi-nodes#23/#31；mlx.status 不暴露池 lease/LRU/TTL → fusion-agent-studio#225。均提 issue 遵 "上游问题先提 issue" 流程
- **CI 全绿**：Swift Build & Test / Code Quality / Security Audit 3/3 pass；master 仅 master 分支

### v0.1.48 — AgentBridge 48 @Published 拆 7 域类型边界 + RPC 方法名集中 + 临时文件统一 (2026-08-26)

补丁版本，审计 0825 P0 重大重构启动 + 仓内 surgical 收尾 + 安全/韧性收口:

- **架构 (F-A1/F-I1)**：
  - **F-A1/F-I1 AgentBridge 拆 7 域类型边界** (PR #326)：48 @Published 拆 7 独立 ObservableObject (RuntimeState/MLXState/AgentState/ModuleState/TaskState/ConfigState/ProjectChatState，新增 `AgentBridgeDomains.swift`)；AgentBridge 持 `let` 域引用 (稳定身份, SwiftUI 自动追踪每域独立重绘粒度)；facade 仍 extension 经 `self.<state>.X` reach-through；setIPCClient `.assign(to:)` 改 `.sink`+cancellables (`$domain.prop` projection 在 let 子对象非法)；9 commit 分阶段迁移 + 193 tests 含 9 域默认值测试。审计 0825 验收 P0 重大重构首项落地
- **实现 (F-I3)**：
  - **F-I3 IPC RPC 方法名集中** (PR #325)：204 method/237 literal/16 文件/43 命名空间 裸字符串 `call(method:)` 拼错零编译期检查 → 新 `RPCMethod.swift` flat enum + 204 static let String 常量 (MARK 分组) + 237 调用点机械替换 `agent.list`→`RPCMethod.agentList`；call 签名不变 (String)；IPCClient `criticalMethods`/`isCoalesceableRead` 整合；命名映射 `.`/`_`→camelCase 0 冲突。与 F-A16 互补 (编译期拼写 vs 运行时 schema 漂移)
- **安全/韧性 (F-I6/F-I13/F-A13/F-I9/F-A12)**：
  - **F-I6 临时文件统一 + F-I13 release CI 假绿** (PR #324)：`FusionTempDir.swift` 新增 (~/.fusion-studio/tmp/ 0700 + writeTmpFile 0600 + cleanupStaleTempFiles) + 3 处改走；release.yml 删死 Rust 步骤 + 签名/notarize gated；ci.yml pipefail + 删 continue-on-error (原 `|tail -10` 吞码假绿)；暴露错误全修 (captured var self 移入 Task 闭包 / @objc MainActor.assumeIsolated / 测试 force .enUS)
  - **F-A13 重复执行告警 + F-I9 端口迁移** (PR #322)：assignedNodes>=2 且 running 且 mode!=data_parallel 无告警 → 客户端启发式止血 (duplicateExecutionTaskIds + detectDuplicateExecution + TaskMonitorView amber banner)；F-I9 追加 multiNodeAgentPort 默认 11445 STALE (与 comfyuiPort 撞) → 11458 + init migrateStalePorts 首启迁移旧 @AppStorage 残留
  - **F-I9 端口集中** (PR #321)：multi-node 端口硬编码 11452/11445 散落 5 处绕 FusionConfig → 改设置不生效两套数据打架 → 硬编码改 `FusionConfig.shared.multiNodePort`/`multiNodeAgentPort`；3 文件 5 处
  - **F-A12 重试节点避让** (PR #320)：失败 task 重试调 submitTask 丢原 requiredCapability/priority + 无节点避让 → 死循环重试同一失败节点；修 = `EngineError.retryNoHealthyNode` + `retryTask(_:)` 保原 requiredCapability/priority + guard 原 assignedNodes 全 offline 则阻断 (P0 仓内最后可外科项)
- **上游缺口 (跨工程 issue，非本仓可外科)**：F-A8 推理流量不经 MultiNodeEngine 路由 → fusion-multi-nodes#27；F-A13 真因 idempotency key+pending 队列需后端 → fusion-multi-nodes#23/#31；mlx.status 不暴露池 lease/LRU/TTL → fusion-agent-studio#225；artifacts-engine v0.4.0 移除 inject → 上游；DesignBridge bypass fd-ai-adapter → fusion-design。均提 issue 遵 "上游问题先提 issue" 流程
- **CI 全绿**：Swift Build & Test / Code Quality / Security Audit 3/3 pass；master 仅 master 分支

### v0.1.47 — 审计 0825 仓内可外科项全完 + MLX facade + AppState 4 域拆 (2026-08-26)

补丁版本，外部独立审计 `audit/fusion-studio-audit-report-0825.md` (43 发现 P0-P3) 仓内可外科修复全部完成 + ARCH-1 MLX facade + F-A5 AppState 拆分 + F-A16 RPC schema 协商:

- **架构 (F-A1/A5/A6)**：
  - **F-A1 MLX Operations facade** (PR #311)：MLX start/stop/status/fetchModels 等从 AgentBridge God-object 抽 `AgentMlxService.swift` extension；行为零变
  - **F-A5 AppState 拆 4 域** (PR #315)：AppState 17 @Published 拆 NavigationState/UIPanelState/HealthState/ThemeState 4 ObservableObject (新增 AppStateDomains.swift)，各独立 @StateObject + .environmentObject 注入；27 文件 appState.X→sub.X
  - **F-A6 路由枚举对齐** (PR #302)：删死 ProductSheet.modules + ModuleSidebarView.swift；4-switch→3-switch 消死列表矛盾；修 .deploy/.desk 反向映射
- **运行时韧性 (F-R6/R10/R12)**：
  - **F-R12 重试退避+熔断** (PR #304)：retryBackoffSeconds 指数 1→2→4 封顶 + ±12.5% jitter 替固定 1s；后端连续失败达 5 触发 backendCircuitOpen fast-fail
  - **F-R6/R10 轮询韧性** (PR #299)：nodesStale 连续失败 3 轮才降级不清 nodes；schedulePoll 加 label 单飞防慢响应请求风暴
- **多节点健壮性 (F-A7/A8③/A9/A10/A11)**：
  - **F-A7 配置实时读** (PR #307)：MultiNodeEngine init let 快照 baseURL/authToken → private var 计算属性实时读 FusionConfig.shared (防改地址后 401 两套数据打架)
  - **F-A8③ 推理路由作用域澄清** (PR #316)：两套独立路由系统 (master task.* 无 chat 代理 / gateway 推理独立集群) 文档标注 + RoutingStrategyView scopeNote 横幅 + infer/inferStream route=direct-mlx info 日志；host 硬编码 127.0.0.1 改 modelHubHost (PR #309)
  - **F-A9 轮询 App 级** (PR #308)：8 叶子 View onAppear/onDisappear startPolling/stopPolling → FusionStudioApp scenePhase active 常驻/background 停；startPolling 幂等守卫防重复 schedule 风暴
  - **F-A10/A11 掉线+脑裂** (PR #305)：ClusterNode.effectiveStatus 心跳 >30s 本地降级 offline 不无条件信服务端 status；splitBrainDetected >1master → critical banner + assertNoSplitBrain 守卫阻断 removeNode/approveNode/submitTask
- **状态机/缓存 (F-A2/A3/A16)**：
  - **F-A2 TTL 缓存 + MLX 池可见性** (PR #318 + #313)：8 fetch 方法加 30s TTL 守卫防 onAppear fetch 风暴 + 写操作置 nil；@Published 数组无界 append 改 LRU cap 50；新增 mlxRunning/mlxLoadedModels/mlxPort 周期轮询 (复用 F-A9 scenePhase) + SettingsView MLX 状态行
  - **F-A3 删死 lastError sink** (PR #306)：@Published lastError 跨域共享错误 sink 0 外部读 + 72 写点全 throw 后 = 死状态，删声明 + 72 写点
  - **F-A16 RPC schema 协商** (PR #317)：客户端零调 rpc.discover 致 schema 漂移静默崩；performConnect 后异步 discover 缓存 method 集 + criticalMethods 存在性检查 + @Published schemaCompatible 预警
- **实现/安全 (F-I2/I6/I8/I10)**：
  - **F-I6 临时文件统一目录** (PR #301)：/tmp 公共区 → ~/.fusion-studio/tmp/ 0700 + 0600 防窥探；defer 兜底清理
  - **F-I10 错误脱敏** (PR #303)：BridgeError.sanitize 统一出口走 userMessage 非 BridgeError 走兜底不泄 detail；agentChat 裸抛 error → 转 ipcError
  - **F-I2/I8** (PR #300)：print → os.log + CLAUDE.md 事实修正
- **死代码清理** (PR #319, fixes #312)：删除 `FusionCoderBridge.swift` (shelled 到不存在的 fusion-coder 二进制，180+ 行死代码)；CodeEditorView status literal `fusion-coder: ready` → `fusion-code: ready`
- **上游缺口 (跨工程 issue，非本仓可外科)**：F-A8 推理流量不经 MultiNodeEngine 路由 → fusion-multi-nodes#27；mlx.status 不暴露池 lease/LRU/TTL → fusion-agent-studio#225；artifacts-engine v0.4.0 移除 inject → 上游；DesignBridge bypass fd-ai-adapter → fusion-design。均提 issue 遵 "上游问题先提 issue" 流程
- **CI 全绿**：Notification / Code Quality / Security Audit / Rust Check / Swift Build & Test 5/5 pass；master 仅 master 分支

### v0.1.46 — 死代码删除 + 架构 facade 抽取 + 审计 P0 修复 (2026-08-25)

补丁版本，删除两处死代码后台服务 + ARCH-1 AgentBridge facade 抽取收尾 + 审计 P0 阻断项修复:

- **死代码删除** (PR #298, fixes #296)：删除 `Services/env-daemon/` (Rust, 0 调用方) + `Services/mlx-daemon/` (Python, 从未启动)
  - **env-daemon**: Swift `IPCClient` 全走 `/tmp/fusion-studio.sock` 到中央路由 `daemon_server.py` (fusion-agent-studio), 0 直连 env-daemon socket; `env.*` 由中央路由 Python 实现, Rust 副本永不被调用
  - **mlx-daemon**: `start.sh` 从未拉起, Bearer 鉴权空转 (鉴权已由 #209 UDS peer-UID + #128 gateway key 覆盖); `StreamingBridge` TCP 连 11432 (fusion-mlx gateway) 非 mlx-daemon 8001
  - Scripts/start.sh/build.sh/setup.sh 清 env-daemon 启停/构建/skip; 9 Swift 文件注释/mock-data/i18n (4 语言) 修正; 7 文档更新 (含 CLAUDE.md)
  - 顺带闭合 F-A4 `IPCClient` pending 容量上限 100 (防狂切 Tab + daemon 慢响应堆续体致 OOM) + F-R11 `FileWatcher` 路径过滤 (排除 .git/.build/node_modules/.DS_Store 等)
- **审计 P0 阻断项** (PR #293/#294/#295)：删 6 dead wrapper method (0 前端调用方) + 修正错摆 @Published (cronJobs/hooks/tasks/projects) + 审计 0825 P0 外科式修复 (B1-B10 子集)
- **ARCH-1 facade 抽取** (PR #277-#282)：Analytics/Alert/Deploy/Template/RAG/Context/Marketplace/Graph/Hooks-Style-Connector/Safety+Team/Memory 11 facade 从 AgentBridge 抽出 extension; 59K 文件拆分降耦合
- **i18n + 性能** (PR #278-#280)：DesignWorkflow 种子 prompt 迁 i18n; CodeEditorView git status 移后台 `Task.detached`; AgentBridge 删 17 冗余 `await MainActor.run` + RAG LRU + version history 清理 + 文件 I/O 移出 MainActor
- **CI 全绿**：Swift Build & Test / Rust Check (skipped, 无 Rust 服务) / Code Quality / Security Audit pass

### v0.1.45 — deployExport 端口回归修复 (2026-08-24)

补丁版本，修复 v0.1.44 引入的端口回归：

- **端口回归修复** (PR #264, fixes #263)：`IPCConvenienceMethods.deployExport` 默认 port `11434` 回归 `8000`，对齐 `AgentBridge.deployExport` + `DeployView` 两副本 + UI 默认值
  - **根因**：PR#253 统一 MLX 引擎探测端口 `8000→11434`（mlx-daemon/env-daemon 正确），但误把 `deployExport` 的导出产物服务端口一并改 11434
  - **`deployExport` port 语义**：导出 agent graph 为独立可部署服务时该服务绑的端口，**非** MLX 引擎端口；绑 11434 会与 MLX 引擎（`localhost:11434`）抢端口冲突
  - 3 副本默认 port 一致（均 8000）：IPCConvenienceMethods.swift:184 / AgentBridge.swift:1759 / DeployView.swift:71
  - `8000` 是 `port-registry.yaml` 标 pending 的 legacy 值（check-ports 暂允许带 warning），deploy 产物端口迁 114xx 段属多项目协调另案
- **CI 全绿**：Swift Build & Test / Rust Check / Code Quality / Security Audit 4/4 pass

### v0.1.44 — i18n 非延后批次全量完成 + 端口对齐 (2026-08-24)

补丁版本，i18n 全量本地化工程非延后批次全部完成 + 引擎端口对齐：

- **i18n 全量本地化 Batch 16c-16z3**（PR #232-#260）：Training 16c / Trainer 16d / DocGenerator 16e / PluginService 16f / MLXOptimizer 16g / Security 16h / Onboarding 16i / Industry 16j / AutoTuning 16k / DesignBridge 16l / FusionDesignSystem 16m / FCWorkflowViews 16n / TaskQueueView 16o / AdvancedSettingsView 16p / AppState 16q / CollaborationService 16r / WelcomeView 16s / ProfilerView 16t / ConfigSyncManager 16u / AccessibilityService 16v / OperationsView 16w / AnalyticsDashboardView 16x / MultiModalView 16y / InteropService 16z / SpaceListView 16z2 / AgentBridge 16z3
  - **AgentBridge 16z3 是最后一个非延后模块**（PR #260）：BridgeError.userMessage + AgentModel.statusLabel 全量 t()/tf()；12 `ab_` × 4 语言
  - 非延后模块 UI 字符串 CJK 残留全部归零；延后类保留明确理由（LLM prompt 内容 / API 耦合 / 预设数据）
- **端口对齐** (PR #253, fixes #251)：mlx-daemon/env-daemon/IPC 5 处旧端口 8000 → 11434 对齐 fusion-mlx 实际引擎端口
- **文档改名** (PR #261, fixes #250)：studio-integration.md 7 处 `fusion-desk` → `fusion-cowork`（上游已改名，pyproject.toml 确认 CLI 名）
- **I18nService 字典**：3568 → 4951 keys × 4 语言（zhCN/enUS/jaJP/koKR）全量平衡（+1383 keys）
- **CI 全绿**：Swift Build & Test / Rust Check / Code Quality / Security Audit 4/4 pass；master 仅 master 分支

### v0.1.43 — i18n Doc Admin + License 全量本地化 (2026-08-22)

补丁版本，推进 i18n 全量本地化工程 Batch 16a/16b，分支清理：

- **Doc Admin 全量本地化** (PR #229, Batch 16a)：DocAdminView 13 API 组管理面板（UserAdmin/AIRaw/Branding/Theme/Vocabulary/Webhook/Metadata/SystemInfo/SystemConfig/Export/RAG/Graph/Notification）全量 `t()`；补完此前延后的 Batch 5c；AdminSection enum rawValue 中文→英文 + localizedName；86 `doc_admin_` × 4 语言
- **License 全量本地化** (PR #230, Batch 16b)：LicenseView 单文件全量本地化；LicenseType + LicenseTab 2 enum rawValue 中文→英文 + localizedName（rawValue 仅 UI 显示，LicenseManager 逻辑用 case 名非 rawValue）；10 feature 项 + 4 type/desc/price + 3 tab + 8 label + 6 btn + sheet/form + `fmt_days` 格式占位符；53 `lic_` × 4 语言
- **I18nService 字典**：3515 → 3568 keys × 4 语言（zhCN/enUS/jaJP/koKR）全量平衡
- **分支清理**：9 个已合并 i18n 分支（Batch 15b-16b）全部删除，仓库仅留 master
- **CI 全绿**：Swift Build & Test / Rust Check / Code Quality / Security Audit 4/4 pass；swift test 170/170

### v0.1.42 — Chat/Cowork 共用首页 + 授权文件夹 (2026-08-21)

PR #220 squash→c69fa7c，含 PR #219 (#217)：

- **Chat/Cowork 共用首页**：CoworkHomeBridge + `desk.system.set_scoped_folder`/`scoped_folder` + `desk.events` 进度内联气泡；NSOpenPanel 授权文件夹选择（审计 P1-1 修复）
- **6 文件 +524 行，16 单测，170/170**，CI 4/4

### v0.1.41 — TrainerBridge schema + build.sh wasm + 测试修复 (2026-08-21)

PR #218 squash→c7a2779：

- **TrainerBridge 对齐 RunManager 平铺 schema**；build.sh wasm 显式告警；154/154 测试修复（DesignBridge i18n / SecurityScan enum / Profiler 空桩）
- #202 关（重复 #217）、#186 关（上游已兼容）、#205 链上游 fusion-design #17
- CI 全绿，tag v0.1.41，DMG 35.4MB

### v0.1.40 — 多节点审批 GUI + agent 撤回发布/多语言 (2026-08-21)

PR #214 + #215：

- **多节点审批 GUI**：node-approval pending 队列 + approval 流程接入
- **agent 撤回发布 + 多语言沙箱**（#214 #215）

### v0.1.39 — Trainer GUI + Projects/Doc 全量本地化 (2026-08-19)

合并 PR #176 (closes #175) 与 i18n Batch 2/3/4a/4b/5a/5b/6a 共 7 个 PR，全量本地化推进至 Projects 模块：

- **fusion-trainer RunManager GUI 面板** (PR #176, closes #175)：TrainerView (536 行) + TrainerBridge (377 行) + IPCTrainerMethods (72 行) + TrainerTests (115 行)；接入 fusion-trainer RunManager，Sidebar/IconRail/ModuleDetailView 路由打通；AppState 新增 trainer 状态。
- **i18n 全量本地化** (Batch 2 → 6a，PR #170/#169/#171/#172/#173/#174/#177)：
  - 设置面板+通用组件+Inspector (Batch 2)、Module 标签 62 模块×4 语言 (Batch 3)、ModelHub 13 视图全量 (Batch 4a/4b)、Doc 15 视图全量 (Batch 5a/5b)、Projects ProjectModuleView 18 视图结构全量 (Batch 6a)
  - I18nService 字典 1288 keys × 4 语言（zhCN/enUS/jaJP/koKR）全量平衡：694 `hub_` + 198 `doc_` + 173 `proj_` + 通用键
  - 稳定标识符（category/section/Codable rawValue）保留原值，仅显示层本地化
- **CI 全绿**：Swift Build & Test / Rust Check / Code Quality / Security Audit 4/4 pass
- **分支清理**：21 个已合并分支（7 本地 + 14 远程）全部删除，仓库仅留 master

### v0.1.33 — Security 中心全量重构：6 原生 tab 接入 fusion-security (2026-08-07)

深度对标 Claude Code 安全能力并集成 fusion-security，使 Studio 安全中心在静态分析维度全面超越 Claude Code 的运行时防护：

- **SecurityBridge** (NEW): HTTP client 直连 fusion-security FastAPI `:11454/api/v1/*`，generic get/postJSON + convertFromSnakeCase 解码 + 15 DTO
- **6 原生 tab** 取代旧的 5 tab（含失效的 WebView :3000 面板）：
  1. **安全概览** — 引擎信息 + 扫描/漏洞/项目/严重度统计 + 高频规则 TOP
  2. **项目与扫描** — 项目 CRUD + 一键发起扫描（AI 增强开关）+ 扫描历史
  3. **漏洞清单** — 严重度过滤 + 展开看代码片段/修复建议 + 一键生成 AI 补丁 / 标记误报
  4. **AI 修复** — 补丁列表 + 原始/修复代码对比 + 应用→验证全流程
  5. **质量门禁** — 策略评估（pass/fail + blocked_by）+ 内置规则 + 自定义规则 CRUD
  6. **运行时防护** — 沙箱/文件/网络/完整性 + 新增「敏感信息脱敏」「Prompt 注入检测」（超越 Claude Code 的运行时能力）
- **端口对齐**: `securityPort` 11442 → 11454（fusion-security `serve` 默认）
- **健康端点**: `env-daemon` 探活改 `/api/v1/system/health`（公开 200）
- **E2E 验证**: health/info/dashboard/rules GET + 项目→扫描→5 漏洞→补丁 generate/apply/verify→门禁 全链路通过
- 上游依赖：fusion-security PR #16/#18/#20（scan 时间戳/补丁生成/启动脚本，已合并）

### v0.1.32 — Code Offline + 四产品环境检测修复 (2026-08-07)

修复 Code 模块 Offline 及 rag/doc/science/health 四个产品环境检测异常 (#136)：

- **Code Offline**: fusion-code `start.sh` 前台 `exec` 不返回，被 Studio `UpstreamServiceManager` 30s 超时强制 terminate 连同服务一起杀掉。改后台 detach（nohup + PID + start|stop|status|restart）。上游 PR [fusion-code#55](https://github.com/dahai80/fusion-code/pull/55)
- **RAG**: `upstreamRagPath` 误指不存在的 `~/fusion/fusion-kb`，实际服务在 `~/fusion/fusion-rag`（:11436）。修正路径
- **Science**: `sciencePort=8200` 与 fusion-science `start.sh` 默认端口 **11462** 不一致。修正为 11462
- **Health**: 无 `start.sh` 且未运行；健康路由 `/api/v1/health`（health router prefix=/api/v1）。上游新增后台 detach 启动脚本 :11456。上游 PR [fusion-health#10](https://github.com/dahai80/fusion-health/pull/10)
- **Doc**: 此前未纳入 `UpstreamServiceManager`（无自动启动/健康探测）；且端口 11449 被 fusion-multi-node 占用（multi-node `start.sh` 默认 11449，但 Studio `multiNodePort=11452`）。新增 fusion-doc 管理器条目（healthEndpoint `/api/health`）；multi-node 上游迁 11452 释放 11449。上游 PR [fusion-multi-nodes#13](https://github.com/dahai80/fusion-multi-nodes/pull/13) + [fusion-doc#31](https://github.com/dahai80/fusion-doc/pull/31)
- **EnvironmentHealthSheet**: `case "doc"` 探活端点 `/health` 误用，修正为 `/api/health`
- **验证**: 四服务经 Studio 精确探活端点均 200（RAG 11436/health、DOC 11449/api/health、SCIENCE 11462/api/v1/health、HEALTH 11456/api/v1/health）；`swift build -c release` 0 error；`swift test` 140/140 PASS

### v0.1.31 — 5 Issue 修复 (2026-08-07)

修复 5 个开放 issue (#113/#120/#121/#122/#125)：

- **#113 fusion-science start.sh 注册**: `Scripts/start.sh` SERVICES 补充 fusion-science 行（health `http://127.0.0.1:8200/api/v1/health`，startOrder=11）
- **#120 Design 检查器按钮无响应**: `DesignInspectorView.observeNotifications` 的 show observer 只设 `inspectorContext` 未设 `state.selectedElement`，导致 `pushSizeToCanvas`/`applyPreset` 提前 return。修复：同步设置 `selectedElement`，hide 时清空
- **#121 fusion-health 侧栏集成**: 新增 `HealthBridge`（HTTP `:11456`，`X-API-Key` 来自 `FUSION_HEALTH_API_KEY` env，空则跳过鉴权）+ `HealthWorkbenchView`（概览/病历摘要/体征提取/AI咨询 4 tab）。`SidebarSection`/`Module`/`ProductSheet` 新增 `.health`，`FusionConfig` 新增 `healthHost/healthPort(11456)/upstreamHealthPath`，`UpstreamServiceManager` 注册健康探针，`EnvironmentHealthSheet` 增加 science/health 探针，`Scripts/start.sh` 注册 fusion-health（startOrder=12）。端口选 11456 避开 fusion-agent-studio http 的 11453
- **#122 Agent / AI Agent 语义重叠**: `SidebarSection` rawValue 区分 `agent="Agent 工作台"` / `aiAgent="AI 控制台"`，边界清晰不物理合并
- **#125 AX 主窗口未暴露为 AXWindow**: `.windowStyle(.titleBar)` 产生无边框窗口致 `AXWindows[0].AXRole==AXApplication`。改为 `WindowGroup("Fusion Studio")` + `.windowStyle(.automatic)`，GUI 自动化可识别 AXWindow
- **上游阻塞**: fusion-health 缺 `start.sh` + `serve` 子命令，已提 issue dahai80/fusion-health#8。studio 侧已就绪，待上游启动入口后健康探针生效
- **验证**: `swift build -c release` 0 error；`swift test` 140/140 PASS

### Design 模块提交/预览/Canvas 修复 (2026-08-07)

Design 模块"生成登录页模板后预览不可见、对话框无法提交、canvas 显示功能未实现"三连修复：

- **提交卡死根因**: app 直连 `mlx:11434`，但启动环境 `FUSION_MLX_API_KEY` 是 gateway(`:11432`) 的 key，对 mlx 返回 401 → `isMLXRunning=false` → `sendChat` 拦截。`mlxResolvedApiKey` 解析优先级 env > settings.json，导致用了无效 key
- **鉴权回退**: `AgentBridge.fetchModels` 与 `DesignBridge.sendDesignChat` 在 401/403 时回退到 `~/.fusion-mlx/settings.json` 的 `auth.api_key`（`AgentBridge.mlxSettingsJsonApiKey()` 静态方法读取）。sendDesignChat 流式请求遇 401 自动用 fallback key 重建请求重试
- **sendChat 实时 probe**: `isMLXRunning=false` 时不硬拦截，先 `probeMLXRunningStatus()` 复核，成功则继续提交
- **sendChat @State 竞态**: 模板按钮 `inputText = tmpl.prompt; sendChat()` 的同步读返回旧值，改为 `sendChat(explicitMessage:)` 显式传参；所有 `onSend: sendChat` / `Button(action: sendChat)` 包闭包
- **预览背景白色调**: `DesignPreviewView` `drawsTransparentBackground=false`，`buildFullHTML` 片段 `--color-bg:#ffffff`，`injectTailwindIntoExisting` 剥离 CDN tailwind 脚本避免离线阻塞（用户选择"只改预览背景"）
- **Canvas wasm 加载**: `DesignCanvasView` wasm/glue 资源改用 `Bundle.module` 优先（SPM `.process` 扁平化到 module bundle）；HTML 改 ES module `<script type="module"> import init, { mount, fusion_bridge_send_command }`（fd_host_web.js 是 wasm-bindgen ESM 输出）
- **artifact 解析**: `max_tokens` 4096→8192 防截断；`extractArtifactFromComplete` 处理缺失 `</antArtifact>` 闭合标签；`extractCodeBlock` 兼容 ```` ```html ```` 无换行 + 截断块；fallback 改无条件触发
- **runFusionDesign 管道死锁**: `parseHtmlViaCLI` 大输出(>64KB)时 `waitUntilExit` 与 `readDataToEndOfFile` 互锁，改用 `DispatchGroup` 并发读 stdout/stderr 后再 join
- **Design RAG 暂禁**: `ragEnabled=false`，`fetchRAGContextBounded` 用 `nonisolated static` + `withTaskGroup` 超时保护（Swift 5.9 无 `addTask(detached:)`，用 nonisolated 函数脱离 MainActor）
- **E2E 验证**: 提交→生成(6154 tokens, `<antArtifact>` 解析成功, codeLen 15209)→预览渲染；`DesignPreviewTrace` 文件日志(`~/.fusion-design-preview-debug.log`)辅助定位

### Project Chat Reply + Bubble UX (2026-08-06)

Project module 会话两个问题修复：

- **会话无 AI 回复**: `ProjectChatsPanel.sendMessage` 只调 `project.chat.message.add` 存用户消息，未触发推理。新增 `generateReply`：用会话历史调 `AgentBridge.infer` (MLX `/v1/chat/completions`)，回填本地 `ChatMessage(role:"assistant")`。模型取 `selectedModel` 或 `defaultModel(for:.agent)`，空则提示选模型
- **气泡区分**: 用户/AI 消息此前都左对齐无区分。用户消息右对齐 + accent 背景气泡，AI 消息左对齐 + 中性气泡
- **上游 issue**: fusion-projects#20 — `project.chat.message.add` 忽略 `role` 参数（强制 user），assistant 回复暂本地展示，待上游支持后落库

### Health Check + Module Fixes (2026-08-06)

Strict health check + per-subsystem startup buttons + several module UX/auth fixes:

- **Strict health check**: only HTTP 200-299 (not 401/403/404) and UDS responses with `result` field count as healthy. `EnvironmentHealthSheet` now probes 9 subsystems (added **fusion-model-hub**) via strict `probeHTTP`/`probeUDS`. UDS probe loop-reads until newline (fixes 6272-byte `project.list` truncation false-negative)
- **Per-subsystem 启动 buttons**: `upstreamServiceIdMap` maps each failing subsystem to an `UpstreamServiceManager` service id; 启动 calls `start.sh start`, waits 3s, re-probes. Covers mlx/rag/modelhub/artifacts/cowork/projects/code
- **fusion-model-hub lifecycle**: created upstream `start.sh` (nohup `fusion-model-hub serve`, PID file, logs/) + changed health endpoint from `/api/v1/system/info` (needs auth) to `/api/v1/system/health` (public 200)
- **Projects delete "project not found" fix**: `FusionProject.id` `let`→`var` + direct id assignment in `fromDict`; removed fragile encode-decode `_rebuildWithId` roundtrip (date strategy mismatch produced local uppercase UUID → server 404)
- **Code module fixes**: (1) chat input box moved from full-width bottom bar into the middle chat column only; (2) "fusion-code offline" root cause = `/api/model/status` 401 without auth → added `Bearer fg-admin-key` to all `FusionCodeBridge` HTTP + WS calls
- **Design submit fix**: empty default model → MLX 400 "model: Field required". `FusionStudioApp.autoPickDefaultModel` picks from `/api/status` (default_model/loaded_models[0]); `DesignBridge`/`DesignChatPanel` guard empty model before send
- **AI auth self-heal** (`AgentBridge.probeMLXRunningStatus`): on 401/403 catches `BridgeError.authFailed`, reads `~/.fusion-mlx/settings.json` `auth.api_key`, re-probes, and persists to user-settings `mlxApiKey` (priority 1) to override a stale `FUSION_MLX_API_KEY` env var. Verified: cleared key + bad env → self-heal persists `dahai168`, MLX 200

### Fusion RAG Consolidation (2026-08-05)

Single "Fusion RAG" sidebar entry -> `RAGMainView` (8 sections) wired to **fusion-rag** backend (FastAPI `127.0.0.1:11436`):

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
├── Services/                     # (空 — env-daemon/mlx-daemon 已删除, env.* 由中央路由 daemon_server.py 实现)
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