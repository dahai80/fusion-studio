# Fusion Model Hub GUI Enhancement Plan

## Current State vs Target

**Existing**: 13 files, ~200K code, 9-section sidebar, 30 API client methods covering basic CRUD.
**Upstream**: ~102 REST endpoints, all real implementations, covering models/versions/quantize/deployments/evaluations/tenants/webhooks/security/watermark/encryption/approvals/ratings/favorites/branches/adapt/sync.

**Core Problem**: GUI covers ~30% of upstream capability. PRD wireframes demand competitive depth exceeding HF/ModelScope. Critical upstream features (deployments, evaluations, ratings, favorites, branches, adapt, security) have zero GUI coverage.

---

## Phase 1: API Client + Models Alignment (Foundation)

### ModelHubModels.swift — Add missing DTOs

1. **HubDeployment** + CRUD DTOs (DeploymentCreate, status: pending/running/stopped/failed, gray_release, scale)
2. **HubEvaluation** + CRUD DTOs (template, metrics, compare)
3. **HubTenant** + DTOs (name, role: admin/developer/viewer)
4. **HubWebhook** + DTOs (url, events, hmac_secret)
5. **HubRating** + DTOs (1-5 score, summary)
6. **HubFavorite** (user bookmark)
7. **HubBranch** + DTOs (name, status: active/merged/archived, merge)
8. **HubSecurityScan** + DTOs (source check results)
9. **HubWatermark** + DTOs (embed/verify)
10. **HubEncryption** + DTOs (encrypt/decrypt status)
11. **HubApproval** + DTOs (L1/L2/L3, approve/reject)
12. **HubRecommendResponse** (scored model list)
13. **HubAdaptResponse** (assess/plan/execute pipeline)
14. **HubModelInferenceStats** (per-model concurrent/tok-s/mem/node)
15. **HubVersionStatus** enum (draft/testing/published/deprecated/retired)
16. Add to HubModel: `modelType`, `modelModules`, `ttlSeconds`, `ratingAvg`, `favoriteCount`

### ModelHubAPIClient.swift — Add missing endpoints

1. **Serve**: `POST /models/{id}/serve`, `DELETE /models/{id}/serve`, `GET /models/{id}/serve`
2. **Pin/Unpin**: `DELETE /models/{id}/pin` (unpin — client only has pin)
3. **Modules**: Change PATCH → PUT for `PUT /models/{id}/modules` (match upstream)
4. **Versions**: Add `PUT /versions/{id}/status`, `PUT /versions/{id}/benchmark`, `PUT /versions/{id}/metrics`, `POST /versions/{id}/promote`, `POST /versions/{id}/deprecate`, `POST /versions/{id}/retire`
5. **Downloads**: Add `DELETE /downloads/{id}` (cancel download)
6. **Quantize**: Add `POST /quantize/layered`, `GET /quantize/layered/jobs/{id}`, `POST /quantize/evaluate`, `POST /quantize/presets/{name}/apply`, `GET /quantize/{id}/compare`
7. **Deployments**: Full CRUD + gray release + scale + metrics
8. **Evaluations**: Full CRUD + compare
9. **Tenants**: Full CRUD
10. **Webhooks**: Full CRUD
11. **Security**: scan + results
12. **Ratings**: CRUD + summary
13. **Favorites**: CRUD + my favorites list
14. **Branches**: CRUD + merge
15. **Recommend**: `POST /recommend`, `GET /recommend/quick`
16. **Adapt**: assess + plan + execute
17. **Sync**: push + pull + manifest
18. **Hardware**: Add `POST /hardware/refresh`
19. **Approvals**: submit + approve + reject
20. Remove non-existent: `GET /auth/keys/{id}/usage` (not in upstream), `GET /cluster/topology` (not in upstream)

---

## Phase 2: Dashboard Enhancement

### HubDashboardView.swift

1. **Add `onNavigate` closure** — wire from ModelHubMainView to enable section navigation from quick actions
2. **Add 3 status indicator badges** below stats grid:
   - MLX推理引擎: connected/disconnected (check via health API)
   - 集群模式: on/off (check cluster nodes > 0)
   - 自动量化: enabled (from AppStorage)
3. **Show module binding tags** on recent model rows (e.g., "Chat ☑", "RAG ☑")
4. **Add "常驻" badge** for pinned models in recent list
5. **Add serving status** column: which models are currently loaded in MLX

---

## Phase 3: Market Enhancement (Competitive Edge)

### HubMarketView.swift

1. **Add "私有仓库" source** option in filter bar
2. **Add "仅本地" toggle** checkbox to show only downloaded models
3. **Add fusionModuleHint** on model cards — auto-derive from task field:
   - text-generation → "Fusion Chat"
   - code → "Fusion Code"
   - embedding → "Fusion RAG"
   - multimodal/vision → "Fusion Design"
4. **Add "一键转MLX" button** in detail panel (calls createDownload with format=mlx)
5. **Add "加入评测" button** in detail panel (calls triggerBenchmark)
6. **Add pagination** — "加载更多" button + page tracking
7. **Add "高级筛选" collapsible** panel with category tabs (多模态/代码专用/轻量嵌入)
8. **Add rating display** on market cards (★ avg + count)
9. **Add favorite toggle** (♡/★) on detail panel

---

## Phase 4: LocalStorage Enhancement

### HubLocalStorageView.swift

1. **Add left-side category tree** — replace family filter with structured tree:
   - 通用对话模型 (task=chat/llm)
   - 代码专属模型 (task=code)
   - 向量嵌入模型 (task=embedding)
   - 图像多模态模型 (task=multimodal/vision/image)
   - 私有模型 (source=local/import)
2. **Add "导出路径" batch action** — copies all selected models' paths to clipboard
3. **Show format+quant tags** in model rows (e.g., "MLX 4bit", "GGUF 8bit")
4. **Add "兼容格式" section** in detail panel
5. **Add version lifecycle** controls: promote (draft→testing→published), deprecate, retire
6. **Add "启动推理服务"** button — calls POST /models/{id}/serve
7. **Add "停止推理服务"** button — calls DELETE /models/{id}/serve
8. **Add serving status indicator** per model (green dot = loaded in MLX)
9. **Add rating** display and edit in detail panel

---

## Phase 5: ConvertQuant Enhancement

### HubConvertQuantView.swift

1. **Replace presets with scene-specific** (upstream has chat/code/embedding presets):
   - 通用对话模型模板
   - 代码模型专项优化模板
   - Embedding轻量化模板
2. **Add "高级参数" collapsible** section:
   - KV Cache优化 toggle
   - 注意力层独立量化 toggle
   - Use `POST /quantize/layered` for advanced quantization
3. **Add "前台/后台" mode toggle** (foreground = wait, background = queue)
4. **Show source model info** (format, size, origin) above config area
5. **Add "对比" tab** — call `GET /quantize/{id}/compare` to show before/after
6. **Add "评估" button** after quantize complete — call `POST /quantize/evaluate`
7. **Add accuracy threshold alert** — if accuracy drops > 10%, show warning

---

## Phase 6: Schedule Enhancement

### HubScheduleView.swift

1. **Add "模块调用权限" tab** — summary view of model→module bindings
2. **Add "API限流配置" section** — default QPS, max concurrent per key
3. **Add "模型TTL配置"** — idle timeout per model with override capability
4. **Add "自动评测" config** — link to benchmark auto-trigger rules

---

## Phase 7: Permission Enhancement

### HubPermissionView.swift

1. **Add "新增角色" button + sheet** — create custom Tenant with role
2. **Add inline edit/delete** buttons on role cards
3. **Make roles dynamic** — load from `GET /tenants` API instead of hardcoded
4. **Add "审批流" tab** — show approval requests, approve/reject actions
5. **Add module access control display** — show X-Fusion-Module header enforcement status

---

## Phase 8: Monitor+Bench Enhancement

### HubMonitorView.swift

1. **Add "模型运行状态" table**: model name | concurrent | tok/s | memory | node | source
   - Data from `GET /monitor/realtime` (loaded_models section)
   - Or from `GET /models/{id}/serve` per model
2. **Add source filter** (Chat/Code/RAG/Design/Agent) on the table
3. **Add deployment metrics** section — call `GET /deployments/{id}/metrics`

### HubBenchmarkView.swift

1. **Add model-level detail expansion** in results table
2. **Add "评估" tab** — full evaluation CRUD (create evaluation with template, view results, compare)
3. **Add "历史报告" section** — list past benchmark runs with dates
4. **Add accuracy drop alert** — if quantize result accuracy drops > threshold, show warning with "重新量化" button

---

## Phase 9: New Sections (Competitive Advantages)

These features have NO equivalent in HF/ModelScope/Ollama:

### New: HubDeploymentView (部署管理)
- Create deployment (load model to MLX with config)
- List active deployments with status
- Canary/gray release management
- Scale replicas
- Per-deployment metrics
- Stop/delete deployments

### New: HubSecurityView (安全中心)
- Security scan trigger and results
- Watermark embed/verify
- Encryption status per model
- Approval workflow management

### ModelHubMainView — Add 2 new sidebar sections:
- `case deployment = "部署管理"`
- `case security = "安全中心"`

---

## Implementation Order (Task Breakdown)

| # | Task | Files | Est. Lines |
|---|------|-------|------------|
| 1 | API Client + DTOs | ModelHubAPIClient.swift, ModelHubModels.swift | ~400 |
| 2 | Dashboard enhancement | HubDashboardView.swift, ModelHubMainView.swift | ~120 |
| 3 | Market enhancement | HubMarketView.swift | ~200 |
| 4 | LocalStorage enhancement | HubLocalStorageView.swift | ~250 |
| 5 | ConvertQuant enhancement | HubConvertQuantView.swift | ~180 |
| 6 | Schedule enhancement | HubScheduleView.swift | ~100 |
| 7 | Permission enhancement | HubPermissionView.swift | ~150 |
| 8 | Monitor+Bench enhancement | HubMonitorView.swift, HubBenchmarkView.swift | ~200 |
| 9 | DeploymentView (new) | HubDeploymentView.swift | ~400 |
| 10 | SecurityView (new) | HubSecurityView.swift | ~350 |
| 11 | MainView wiring | ModelHubMainView.swift | ~30 |
| **Total** | | | ~2380 |

---

## Upstream Issues to File

After implementation, file these on fusion-model-hub:
1. `GET /auth/keys/{id}/usage` — not found, need for QPS monitoring
2. `GET /cluster/topology` — not found, need for cluster visualization
3. `GET /hardware` response schema — verify field names match GUI DTOs
4. `GET /monitor/realtime` — need per-model inference stats (concurrent, tok/s, memory, node)
5. Model `ttl_seconds` field — need for schedule config per model
6. Market search pagination — verify page/limit params work correctly
