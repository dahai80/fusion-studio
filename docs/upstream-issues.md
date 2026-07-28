<!--
Callers: Fusion Studio Design module, Phase 3 deferred tasks
Affected API: fusion-artifacts-engine artifact CRUD, fusion-mlx /v1/chat/completions (tool_use + multimodal)
Data schemas: artifact.project_id, artifact.metadata (design_tokens/component_name/framework), image_url content type
User instruction: "继续完成遗留和defer的任务" — file upstream issues for blocked Phase 3 items per project rule
-->

# Upstream Issues to File

> Generated: 2026-07-28
> Per project rule: "遇到上游问题，先提issue，再提pr，跟着提交落地code"

## 1. fusion-artifacts-engine: project_id scope for artifacts

**Repo**: dahai80/fusion-artifacts-engine
**Title**: feat: add project_id scope for artifacts

Current artifact has no project scope isolation. When Fusion Studio supports multiple projects, artifacts from different projects will interfere.

### Suggestion
1. `artifact.create` / `artifact.update` support `project_id` parameter
2. `artifact.list` supports `project_id` filtering
3. `artifact.get` / `artifact.delete` verify `project_id` ownership

### Use case
- Fusion Studio Design: each FusionProject has its own design artifact set
- Different projects can have artifacts with the same name

### Impact
- artifact CRUD APIs need project_id param
- DB schema needs project_id column
- Backward compatible: project_id optional, defaults to global scope

---

## 2. fusion-artifacts-engine: Design metadata extension

**Repo**: dahai80/fusion-artifacts-engine
**Title**: feat: design metadata extension for artifacts

artifact metadata lacks design-related structured fields. Fusion Design needs design_tokens, component_name, layout_type etc.

### Suggestion
1. artifact metadata supports free-form JSON extension
2. Common design fields: design_tokens, component_name, layout_type, framework
3. artifact.list supports filtering by metadata fields

---

## 3. fusion-mlx: Verify tool_use streaming completeness

**Repo**: dahai80/fusion-mlx (not local)
**Title**: verify: tool_use streaming completeness for create_artifact

Fusion Studio Design uses streaming mode with tool_use (create_artifact). Need to verify tool_use JSON is complete in streaming mode.

### Concern
- Streaming tool_use content may be truncated
- antArtifact XML parsing depends on complete output
- Need fallback to non-streaming if issues found

---

## 4. fusion-mlx: Multimodal input support (image)

**Repo**: dahai80/fusion-mlx (not local)
**Title**: feat: multimodal input support for chat completions

Design module needs screenshot-to-code, requiring image input in /v1/chat/completions.

### Suggestion
1. Support image_url content type in messages
2. Use vision model (llava, Qwen-VL) for image understanding
3. Return 422 if non-vision model used with image input

### Use case
- Screenshot import: screenshot → vision model → HTML
- Figma import: rendered frames → vision model → HTML
