# Upstream HTTP Endpoints — Fusion Studio Integration Reference

> Generated: 2026-07-28
> Repos: fusion-agent-studio, fusion-artifacts-engine, fusion-design
> Callers: IPCClient, DesignBridge, AgentBridge
> Affected API: IPCClient artifact.* / knowledge.*, fusion-agent-studio /v1/*, fusion-artifacts-engine JSON-RPC

---

## 1. fusion-artifacts-engine (JSON-RPC 2.0)

Base URL: configured via FusionConfig.shared.artifactsEngineURL
Transport: HTTP POST, JSON-RPC 2.0

### IPCClient Methods (implemented)

| Method | IPCClient Method | Status |
|--------|------------------|--------|
| artifact.create | artifactCreate(sessionId:name:type:kind:content:summary:) | done |
| artifact.get | artifactGet(artifactId:) | done |
| artifact.get_content | artifactGetContent(artifactId:version:) | done |
| artifact.list | artifactList(sessionId:includeDeleted:) | done |
| artifact.delete | artifactDelete(artifactId:hard:) | done |
| artifact.update | artifactUpdate(artifactId:content:changeLog:) | done |
| artifact.version_list | artifactVersionList(artifactId:) | done |
| artifact.version_rollback | artifactVersionRollback(artifactId:targetVersion:) | done |
| artifact.inject | artifactInject(messages:outputBudget:) | done |
| artifact.check_safety | artifactCheckSafety(messages:outputBudget:) | done |
| artifact.export | artifactExport(artifactId:format:) | done |
| artifact.export_session | artifactExportSession(sessionId:format:) | done |
| artifact.import | artifactImport(data:) | done |
| ping | artifactPing() | done |

### IPCClient Methods (NEW - added 2026-07-28)

| Method | IPCClient Method | Status |
|--------|------------------|--------|
| artifact.sync | artifactSync(artifactId:filePath:direction:) | NEW |
| artifact.watch | artifactWatch(artifactId:action:) | NEW |
| artifact.export_code | artifactExportCode(artifactId:language:) | NEW |
| artifact.import_code | artifactImportCode(code:language:name:sessionId:) | NEW |

### artifact.sync Parameters
- artifact_id (string): Artifact ID
- file_path (string): Local file path to sync with
- direction (string): "artifact_to_file" | "file_to_artifact" | "bidirectional"
- Returns: { "synced": bool, "content": string?, "version": int? }

### artifact.watch Parameters
- artifact_id (string): Artifact ID
- action (string): "register" | "unregister" | "poll"
- Returns: { "watching": bool, "changed": bool, "latest_version": int? }

### Upstream Issues to File
1. project_id scope — artifact CRUD needs project_id parameter for multi-project isolation
2. Design metadata — artifact metadata needs structured design fields (tokens, component_name, framework)

---

## 2. fusion-agent-studio (OpenWorker Coworker Server)

Base URL: typically http://localhost:8192
Transport: HTTP REST (FastAPI)

### Key Endpoints for Fusion Studio

#### Chat and Sessions
| Method | Path | Description |
|--------|------|-------------|
| POST | /v1/chat/completions | OpenAI-compatible chat proxy |
| GET | /v1/sessions | List sessions |
| GET | /v1/sessions/{id}/messages | Get session messages |
| PATCH | /v1/sessions/{id} | Update session (rename/pin) |
| DELETE | /v1/sessions/{id} | Delete session |
| WS | /ws/session/{id} | WebSocket real-time interaction |

#### Knowledge and Memory
| Method | Path | Description |
|--------|------|-------------|
| POST | /api/v1/knowledge_bases | Create knowledge base |
| POST | /api/v1/knowledge_bases/{name}/ingest | Ingest data into KB |
| GET | /api/v1/knowledge_bases | List knowledge bases |
| GET | /api/v1/knowledge_bases/{name}/chunks | List KB chunks |
| DELETE | /api/v1/knowledge_bases/{name} | Delete KB |
| GET | /v1/memory | List memory entries |
| POST | /v1/memory | Add memory entry |

#### Models and Providers
| Method | Path | Description |
|--------|------|-------------|
| GET | /v1/providers | List model providers |
| POST | /v1/providers | Add/update provider |
| DELETE | /v1/providers/{name} | Remove provider |
| POST | /v1/providers/verify | Verify provider credentials |
| GET | /v1/models | List models |
| POST | /v1/settings/default-model | Set default model |

#### Artifacts (via Langflow)
| Method | Path | Description |
|--------|------|-------------|
| GET | /v1/sessions/{id}/artifacts | List session artifacts |
| GET | /v1/sessions/{id}/artifacts/read | Read artifact content |
| POST | /v1/sessions/{id}/artifacts/reveal | Reveal in Finder |

#### MCP and Connectors
| Method | Path | Description |
|--------|------|-------------|
| GET | /v1/mcp | List MCP servers |
| POST | /v1/mcp | Add MCP server |
| GET | /v1/mcp/{name}/tools | List MCP tools |
| POST | /v1/mcp/{name}/connect | Connect MCP server |
| GET | /v1/connectors | List connectors |
| POST | /v1/connectors/{name}/connect | Connect connector |

#### Health and Settings
| Method | Path | Description |
|--------|------|-------------|
| GET | /v1/health | Health check |
| GET | /v1/settings | Get all settings |

### Full Langflow Backend (~120 endpoints)
Complete API at /api/v1 and /api/v2 including:
- Flows CRUD, building, execution
- Knowledge bases (ingest, search, chunks)
- Files upload/download
- Users, auth, roles, teams
- Folders, projects
- MCP management
- Deployments
- Agentic execution

---

## 3. Integration Map: Fusion Studio to Upstream

| Fusion Studio Component | Upstream Service | API Used |
|------------------------|------------------|----------|
| DesignBridge | fusion-mlx | /v1/chat/completions (streaming) |
| DesignBridge | fusion-artifacts-engine | artifact.* (JSON-RPC) |
| DesignBridge (RAG) | fusion-artifacts-engine | artifact.* for ingest/search via agent-studio |
| AgentBridge | fusion-agent-studio | /v1/chat/completions, sessions, memory |
| IPCClient | fusion-artifacts-engine | Full artifact CRUD + sync + watch |
| IPCClient | fusion-agent-studio | Knowledge bases, MCP, providers |
