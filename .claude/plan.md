// Callers: Plan mode exit, user review.
// Affected API: ContentView (three-column), StudioTheme (dark-first), SidebarView (icon rail + module list).
// Data schemas: InspectorContext, LayoutState.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏：侧边导航 + 主工作区 + 右侧属性 - 暗色模式优先 - 主色 #007AFF - 输出高保真设计 + React/Tailwind 代码" (user chose 纯 SwiftUI 重写)

# Fusion Studio GUI Redesign Plan

## Goal
Complete UI/UX redesign: three-column layout (sidebar + main workspace + right properties panel), dark-mode-first, primary color #007AFF, Apple HIG refined native SwiftUI.

## Current State
- 20,905 lines across ~60 Swift files
- Two-column NavigationSplitView (no right panel)
- StudioTheme token system exists (434 lines) but many views use hardcoded Color.*
- Sidebar: ProductSheet grouping in standard .sidebar List — visually flat
- 19 module views, mostly mock data, inconsistent theming
- Components: FusionButton/Card/Tag/TabBar/ProgressRing/Toast — need polish
- No inspector/properties panel

## Architecture Changes

### Phase 1: Core Layout Restructure
Files: ContentView.swift, FusionStudioApp.swift, AppState.swift

1. Replace NavigationSplitView with custom three-column HSplitView:
   - **IconRail (48pt)**: Product sheet icons, bottom: settings/avatar
   - **ModuleSidebar (220pt)**: Modules for selected sheet, search field
   - **WorkspaceArea (flex)**: Toolbar + main content
   - **InspectorPanel (280pt)**: Toggleable properties panel

2. Add selectedSheet, isInspectorVisible, inspectorContext to AppState
3. New LayoutContainer.swift for three-column split

### Phase 2: Visual System Upgrade
Files: StudioTheme.swift, new VibrancyLayer.swift

1. Dark-first palette rewrite:
   - windowBg: #1E1E20, sidebarBg: #2C2C2E + vibrancy, contentBg: #1C1C1E
   - accent: #007AFF hardcoded (not NSColor.controlAccentColor)
   - Re-tune all status colors for dark backgrounds

2. Vibrancy helpers: .ultraThinMaterial backgrounds
3. Update spacing/radius/shadow for three-column proportions

### Phase 3: Icon Rail + Module Sidebar
Files: SidebarView.swift (rewrite→delete), IconRailView.swift (new), ModuleSidebarView.swift (new)

1. **IconRailView** (48pt): Vertical SF Symbols, 3pt #007AFF active bar, tooltips, .ultraThinMaterial
2. **ModuleSidebarView** (220pt): Search + flat module list, active row #007AFF tint, .ultraThinMaterial

### Phase 4: Inspector Panel
Files: InspectorPanel.swift (new), AgentInspectorView.swift (new), DAGInspectorView.swift (new)

1. InspectorPanel: toggle with ⌘I, slide transition, ScrollView sections, .ultraThinMaterial
2. AgentInspectorView: agent properties, quick actions, recent tasks
3. DAGInspectorView: node properties, position, edges

### Phase 5: Module View Refactoring (Top 3)
1. DashboardView: stat cards grid + activity feed + health overview
2. AgentStudioView: remove HSplitView (inspector handles detail), cleaner list
3. LogPanelView: dark terminal aesthetic, theme colors

### Phase 6: Polish
1. Toolbar: breadcrumb + search + inspector toggle
2. Window chrome: .hiddenTitleBar + custom drag area
3. Consistent animations and empty states
4. Keyboard shortcuts: ⌘1-4, ⌘I

## File Changes

| File | Action | Description |
|------|--------|-------------|
| ContentView.swift | REWRITE | Three-column layout |
| FusionStudioApp.swift | MODIFY | Layout state, inspector |
| AppState.swift | MODIFY | New published properties |
| StudioTheme.swift | REWRITE | Dark-first #007AFF palette |
| SidebarView.swift | DELETE | Replaced by IconRail + ModuleSidebar |
| IconRailView.swift | NEW | 48pt icon strip |
| ModuleSidebarView.swift | NEW | 220pt module list |
| InspectorPanel.swift | NEW | Right-side properties |
| LayoutContainer.swift | NEW | Three-column split |
| AgentInspectorView.swift | NEW | Agent properties |
| DAGInspectorView.swift | NEW | DAG node properties |
| AgentStudioView.swift | REWRITE | Remove inline detail |
| DashboardView (in ModuleDetailView) | REWRITE | Stats grid |
| LogPanelView.swift | REWRITE | Theme-aware terminal |
| ProfilerView.swift | REWRITE | Apple HIG gauges |
| SettingsView.swift | REWRITE | Inspector-style |
| Components/*.swift | MODIFY | Dark-first polish |
| DAGCanvasView.swift | MODIFY | Inspector integration |

Execution order: Phase 1 → 2 → 3 → 4 → 5 (top 3) → 6
