# Sidebar Redesign — ChatGPT-style Collapsible Navigation

## Current Architecture

```
IconRailView(48pt) | ModuleSidebarView(220pt) | Workspace | Inspector
```

Two-level: ProductSheet (IconRail) → Module (ModuleSidebar). Rigid, always-visible, wastes horizontal space.

## Target Architecture

```
CollapsibleSidebar(0/260pt) | Workspace | Inspector
```

Single collapsible sidebar inspired by ChatGPT/Claude.ai. Icon+text on same row. Groups with section headers. Fold to icon-only rail.

## Sidebar Layout (top to bottom)

```
┌─────────────────────────────┐
│ 🔍  Search...        [◁]   │  ← search bar + collapse button
├─────────────────────────────┤
│  ✚  New Chat                │  ← primary action
├─────────────────────────────┤
│  CHATS                      │  ← section header
│    💬 Chat 1                │
│    💬 Chat 2                │
├─────────────────────────────┤
│  PROJECTS                   │
│    📁 fusion-agent-studio   │  ← from ProjectWorkspace.recentProjects
│    📁 fusion-studio         │
├─────────────────────────────┤
│  ARTIFACTS                  │
│    📦 Build Output          │
├─────────────────────────────┤
│  CODE                       │
│    </> 编码                  │  ← Module.code (active = blue bg)
│    ✏️ 设计                   │  ← Module.design
│    📄 文档                   │  ← Module.doc
│    📋 文档生成               │  ← Module.docgen
│    ⌨️ 命令行                 │  ← Module.cli
├─────────────────────────────┤
│  CUSTOMIZE                  │
│    🎨 Customize             │
├─────────────────────────────┤
│  DESIGN                     │
│    ✏️ Fusion Design         │
├─────────────────────────────┤
│                             │
│          (spacer)           │
│                             │
├─────────────────────────────┤
│  RECENTS                    │  ← recent projects/files
│    📁 agent-studio   2小时前 │
│    📄 config.yaml    3天前   │
├─────────────────────────────┤
│  ⬇️  Get App & Extensions   │
│  ⚙️  Settings               │  ← popup menu: Settings/Language/Help/Upgrade/Get Apps/Learn More/Logout
│  👤  username    [↓]        │  ← bottom area
└─────────────────────────────┘
```

## Collapsed State (icon-only rail, 48pt)

```
┌──────┐
│ [▷]  │  ← expand button
├──────┤
│  ✚   │
├──────┤
│  💬  │  ← Chats section
│  📁  │  ← Projects section
│  📦  │  ← Artifacts
│  </> │  ← Code section (active indicator bar)
│  🎨  │  ← Customize
│  ✏️  │  ← Design
├──────┤
│      │
│(spc) │
│      │
├──────┤
│  ⬇️  │
│  ⚙️  │
│  👤  │
└──────┘
```

## Navigation Model Changes

### SidebarSection (new enum)

```swift
enum SidebarSection: String, CaseIterable {
    case chats = "Chats"
    case projects = "Projects"
    case artifacts = "Artifacts"
    case code = "Code"
    case customize = "Customize"
    case design = "Design"
}
```

### SidebarItem (new struct)

```swift
struct SidebarItem: Identifiable {
    let id: String
    let section: SidebarSection
    let icon: String
    let title: String
    let module: Module?
    let badge: String?
}
```

### AppState additions

```swift
@Published var isSidebarCollapsed: Bool = false
@Published var sidebarWidth: CGFloat = 260
```

## Key Behaviors

1. **Collapse/Expand**: [◁] button or Cmd+\ toggles. Animates width 260→48.
2. **Collapsed**: Shows section icons only. Tapping icon expands sidebar to that section.
3. **New Chat**: Creates new conversation, switches to chat view.
4. **Chats**: Lists recent conversations from CodeAgent.
5. **Projects**: Lists from `ProjectWorkspace.recentProjects`. Click opens project.
6. **Code section**: Module rows for .code/.design/.doc/.docgen/.cli — grouped under "Code" header.
7. **Recents**: Shown at bottom of expanded sidebar. Recent projects from ProjectWorkspace.
8. **Settings popup**: Gear icon opens NSMenu with: Settings, Language, Get Help, Upgrade Plan, Get Apps & Extensions, Learn More, Logout.
9. **User area**: Bottom-left avatar + username + download button.
10. **Active state**: Blue left indicator bar + blue icon + light blue bg.
11. **Search**: Filters across all sections (chats, projects, modules).

## Files to Modify

1. **`AppState.swift`** — Add SidebarSection, SidebarItem, isSidebarCollapsed, sidebarWidth
2. **`IconRailView.swift`** — Remove from ContentView (keep file for reference)
3. **`ModuleSidebarView.swift`** — Remove from ContentView (keep file for reference)
4. **NEW: `FusionSidebarView.swift`** — Main collapsible sidebar component
5. **`ContentView.swift`** — Replace IconRail+ModuleSidebar with FusionSidebarView
6. **`CodeEditorView.swift`** — No changes needed (already has ProjectWorkspace integration)

## Animation

- Width transition: `.animation(theme.springSnappy, value: appState.isSidebarCollapsed)`
- Section expand/collapse: `.animation(theme.springDefault)`
- Active indicator: slides via `.transition(.move(edge: .leading))`
