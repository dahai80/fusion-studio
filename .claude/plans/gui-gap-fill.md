# Plan: Fill All GUI Gaps for Backend-Ready Features

## Audit Summary

**Backend DaemonServer** exposes 64 JSON-RPC methods across 12 domains.
**AgentBridge** wraps 45+ Swift async methods, exposing 20 @Published properties.
**GUI gaps** = bridge methods with zero callers + views using hardcoded data instead of bridge.

### Already Fully Wired (no changes needed)
- PlannerView ✅ (7 methods)
- MemoryView ✅ (6 methods)
- SafetyView ✅ (5 methods)
- DeployView ✅ (3 methods)

### Gaps to Fill (6 items)

#### 1. AgentStudioView — Skill/Soul Management (bridge has 5 methods, GUI calls 0)
- **Missing**: `fetchAgentSkills`, `agentAddSkill`, `agentDeleteSkill`, `fetchAgentSoul`, `agentUpdateSoul`
- **Current**: `BackendAgentDetailView` shows "Has Soul: Yes/No" and "Skills: x, y" as static text
- **Fix**: Add SkillManagementSection and SoulEditorSection inside `BackendAgentDetailView`

#### 2. AgentStudioView — Marketplace tab (bridge has 6 methods, GUI calls 0)
- **Missing**: `marketplaceSearch`, `marketplaceGet`, `marketplacePublish`, `marketplaceUnpublish`, `fetchMarketplaceCategories`, `marketplaceInstall`
- **Current**: No marketplace tab at all
- **Fix**: Add 5th tab "Marketplace" with search, category filter, publish, install/uninstall

#### 3. SafetyView — Evaluate Action (1 method unused)
- **Missing**: `safetyEvaluateAction(category:content:context:)`
- **Fix**: Add "Evaluate Action" section with category/content/context inputs

#### 4. PlannerView — Refresh detail after mutation (1 method unused)
- **Missing**: `plannerGetPlan(planId:)`
- **Fix**: After approve/reject/execute, call `bridge.plannerGetPlan()` and update view

#### 5. RAGPipelineView — Use bridge instead of hardcoded RAGEngine
- **Missing**: `ragRetrieve`, `ragResults` property never read
- **Fix**: Read `bridge.ragResults`, add retrieve mode, remove hardcoded sample docs

#### 6. TemplateMarketView — Use bridge marketplace API
- **Missing**: Full marketplace API (6 methods)
- **Fix**: Replace TemplateMarket singleton data with bridge marketplace methods

## Implementation Order

1. AgentStudioView Skill/Soul (high impact, small change)
2. AgentStudioView Marketplace tab (high impact, new tab)
3. SafetyView Evaluate Action (small)
4. PlannerView refresh (small fix)
5. RAGPipelineView bridge integration (medium refactor)
6. TemplateMarketView marketplace API (medium refactor)

## File Changes

| File | Change |
|------|--------|
| `AgentStudioView.swift` | Add SkillManagementSection, SoulEditorSheet, MarketplaceView tab |
| `SafetyView.swift` | Add SafetyEvaluateSection |
| `PlannerView.swift` | Add plan refresh after mutations |
| `RAGPipelineView.swift` | Replace RAGEngine with bridge calls, add retrieve mode |
| `TemplateMarketView.swift` | Replace TemplateMarket data with bridge marketplace API |
