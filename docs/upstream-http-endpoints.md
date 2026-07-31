# Upstream HTTP Endpoints — Fusion Studio Integration Reference

> Generated: 2026-07-31
> Repos: fusion-agent-studio, fusion-artifacts-engine, fusion-design
> Callers: IPCClient, DesignBridge, AgentBridge
> Affected API: IPCClient artifact.* / knowledge.*, fusion-agent-studio /v1/*, fusion-artifacts-engine JSON-RPC + REST + SSE

---

## 1. fusion-artifacts-engine (JSON-RPC 2.0 + REST + SSE)

Base URL: configured via FusionConfig.shared.artifactsEngineURL
Transport: HTTP POST (JSON-RPC 2.0), HTTP GET (REST), SSE (text/event-stream)

### IPCClient Methods — Core CRUD

| Method | IPCClient Method | Status |
|--------|------------------|--------|
| artifact.create | artifactCreate(sessionId:name:type:kind:content:summary:) | done |
| artifact.get | artifactGet(artifactId:) | done |
| artifact.get_content | artifactGetContent(artifactId:version:) | done |
| artifact.list | artifactList(sessionId:includeDeleted:) | done |
| artifact.delete | artifactDelete(artifactId:hard:) | done |
| artifact.update | artifactUpdate(artifactId:content:changeLog:projectId:metadata:expectedContentHash:) | done |
| artifact.version_list | artifactVersionList(artifactId:) | done |
| artifact.version_rollback | artifactVersionRollback(artifactId:targetVersion:) | done |
| artifact.inject | artifactInject(messages:outputBudget:) | done |
| artifact.check_safety | artifactCheckSafety(messages:outputBudget:) | done |
| artifact.export | artifactExport(artifactId:format:) | done |
| artifact.export_session | artifactExportSession(sessionId:format:) | done |
| artifact.import | artifactImport(data:) | done |
| ping | artifactPing() | done |

### IPCClient Methods — Extended (Issue #26-A)

| Method | IPCClient Method | Status |
|--------|------------------|--------|
| artifact.rename | artifactRename(artifactId:newName:) | done |
| artifact.star | artifactStar(artifactId:starred:) | done |
| artifact.pin | artifactPin(artifactId:chatId:pinned:) | done |
| artifact.duplicate | artifactDuplicate(artifactId:newName:) | done |
| artifact.create_snapshot | artifactCreateSnapshot(artifactId:label:author:) | done |
| artifact.list_snapshots | artifactListSnapshots(artifactId:) | done |
| artifact.list_all | artifactListAll(filters:sort:page:pageSize:) | done |
| artifact.create_share | artifactCreateShare(artifactId:createdBy:expiresAt:) | done |
| artifact.get_shared | artifactGetShared(shareId:) | done |
| artifact.revoke_share | artifactRevokeShare(shareId:) | done |
| artifact.list_recycle | artifactListRecycle(page:pageSize:) | done |
| artifact.restore | artifactRestore(artifactId:) | done |
| artifact.purge_expired | artifactPurgeExpired() | done |
| artifact.move_to_project_kb | artifactMoveToProjectKb(artifactId:projectId:) | done |
| artifact.create_folder | artifactCreateFolder(name:parentId:) | done |
| artifact.list_folders | artifactListFolders(parentId:) | done |
| artifact.rename_folder | artifactRenameFolder(folderId:newName:) | done |
| artifact.delete_folder | artifactDeleteFolder(folderId:) | done |
| artifact.move_to_folder | artifactMoveToFolder(artifactId:folderId:) | done |
| artifact.add_tag | artifactAddTag(artifactId:tag:) | done |
| artifact.remove_tag | artifactRemoveTag(artifactId:tag:) | done |
| artifact.list_tags | artifactListTags(artifactId:) | done |
| artifact.list_events | artifactListEvents(artifactId:limit:offset:) | done |
| artifact.interact | artifactInteract(artifactId:action:payload:sessionId:) | done |
| artifact.render | artifactRender(content:sessionId:langHint:projectId:) | done |
| artifact.sync | artifactSync(artifactId:filePath:direction:) | done |
| artifact.watch | artifactWatch(artifactId:action:) | done |
| artifact.export_code | artifactExportCode(artifactId:language:) | done |
| artifact.import_code | artifactImportCode(code:language:name:sessionId:) | done |

### artifact.update — Optimistic Locking

The `expected_content_hash` parameter enables optimistic concurrency:
- Client sends the SHA-256 hash of the content it last read
- Server rejects update if the current content hash differs (conflict)
- Returns error code `-32603` with message `"content_hash_mismatch"` on conflict
- Client should re-read content, merge changes, and retry

### artifact.list_events Parameters

- artifact_id (string): Artifact ID
- limit (int): Max events to return (default 50)
- offset (int): Skip offset events (default 0)
- Returns: `{ "events": [{ "id": string, "type": string, "timestamp": float, "data": object }] }`

### REST Endpoints (Issue #26-B)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/v1/share/{share_id} | None | Public share access (read-only render) |
| POST | /api/token-count | None | Count tokens for text |

#### GET /api/v1/share/{share_id}

No authentication required. Returns the shared artifact's read-only render data.

Response (200):
```json
{
    "share_id": "shr_abc123",
    "artifact": {
        "id": "art_xyz",
        "name": "Example Artifact",
        "type": "code",
        "content": "...",
        "rendered_html": "..."
    },
    "expires_at": "2026-08-01T00:00:00Z"
}
```

Error (404): `{ "error": "share not found or expired" }`

IPCClient method: `shareGet(shareId:)`

### SSE Event Streams (Issue #26-C)

| Path | Description | IPCClient Method |
|------|-------------|------------------|
| /api/v1/artifacts/{id}/events | Single artifact event stream | artifactEventStream(artifactId:lastEventId:) |
| /api/v1/sessions/{sid}/events | Session event stream | sessionEventStream(sessionId:lastEventId:) |

#### SSE Contract

Transport: HTTP GET, `Accept: text/event-stream`
Reconnect: Send `Last-Event-ID` header to resume from last received event

Stream format:
```
id: evt_001
data: {"type": "artifact.updated", "artifact_id": "art_xyz", "version": 5}

id: evt_002
data: {"type": "artifact.starred", "artifact_id": "art_xyz", "starred": true}
```

Each parsed event is delivered as `[String: Any]` via `AsyncStream<[String: Any]>`.
The `_sse_event_id` key is injected for reconnect tracking.

Event types (artifact):
- `artifact.updated` — content or metadata changed
- `artifact.starred` / `artifact.unstarred`
- `artifact.version_created` — new version saved
- `artifact.deleted`

Event types (session):
- `artifact.created` — new artifact in session
- `artifact.updated` — artifact content changed
- `artifact.deleted` — artifact removed

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
| IPCClient | fusion-artifacts-engine | Full artifact CRUD + sync + watch + REST share + SSE |
| IPCClient | fusion-agent-studio | Knowledge bases, MCP, providers |
| ArtifactShareDialog | fusion-artifacts-engine | REST /api/v1/share/{share_id} |
| ArtifactsPanel | fusion-artifacts-engine | SSE /api/v1/artifacts/{id}/events |
