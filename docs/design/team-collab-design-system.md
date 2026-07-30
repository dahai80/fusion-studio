# 团队协作 GUI 设计系统

> fusion-studio · Module.teamCollab · macOS 原生 SwiftUI
> 主色调 `#007AFF` · 8px 栅格 · 玻璃态 + 轻微拟物 · 符合 Apple Human Interface Guidelines

本规范是 `Module.teamCollab`（团队协作）模块的设计令牌与组件规范。所有令牌均落地于 `StudioTheme`（`Theme/StudioTheme.swift`），组件实现于 `Modules/TeamCollab/TeamCollabView.swift` 与 `Modules/TeamCollab/TeamCollabModels.swift`。

---

## 1. 设计原则

1. **原生优先**：使用 SwiftUI 原生控件 + `.ultraThinMaterial` 玻璃态，不引入外部依赖。
2. **8px 栅格**：所有间距、尺寸为 4 的倍数，基础单元 8px。
3. **令牌驱动**：颜色/字体/间距/圆角/图标尺寸全部经 `@Environment(\.studioTheme)` 读取，不硬编码。
4. **暗亮双模**：通过 `StudioTheme.light` / `StudioTheme.dark` 切换，`ContentView` 按 `appState.isDarkMode` 选择。
5. **语义化状态色**：在线/繁忙/熔断/离线各有固定色相，跨组件一致。

---

## 2. 颜色系统

### 2.1 主色与强调色

| 令牌 | 亮色 | 暗色 | 用途 |
|------|------|------|------|
| `accent` | `#007AFF` | `#0A84FF` | 主色调，选中态/链接/进度条 |
| `accentSoft` | `#007AFF` @ 12% | `#0A84FF` @ 16% | 选中行背景/胶囊底 |
| `accentText` | `#FFFFFF` | `#FFFFFF` | 主色填充上的文字 |
| `accentSecondary` | `#5AC8FA` | `#64D2FF` | 次级强调 |

`#007AFF` 即 Apple System Blue，符合 HIG 默认强调色约定。

### 2.2 语义状态色（Agent 状态）

| 状态 | 令牌映射 | 色值 | 含义 |
|------|----------|------|------|
| 在线 online | `greenDot` | `#34C759` / `#30D158` | 可用 |
| 繁忙 busy | auxiliary orange | `#FF9500` / `#FF9F0A` | 任务执行中 |
| 熔断 tripped | `redDot` | `#FF3B30` / `#FF453A` | 熔断开启 |
| 离线 offline | `textTertiary` | `#8E8E93` / `#8E8E93` | 不可达 |

胶囊组件统一用 `状态色 @ 12%` 作底 + 状态色文字/圆点。

### 2.3 表面与文本（主题相关）

| 令牌 | 亮色 | 暗色 |
|------|------|------|
| `windowBg` | `#F5F5F7` | `#1C1C1E` |
| `sidebarBg` | `#E8E8EC` | `#2C2C2E` |
| `contentBg` | `#FFFFFF` | `#1C1C1E` |
| `surfacePrimary` | `#FFFFFF` | `#2C2C2E` |
| `surfaceSecondary` | `#F2F2F7` | `#242426` |
| `surfaceElevated` | `#FFFFFF` | `#2C2C2E`（+ 0.5 border） |
| `groupBorder` | `#3A3A3C @ 12%` | `#FFFFFF @ 12%` |
| `text` | `#1C1C1E` | `#FFFFFF` |
| `textSecondary` | `#3A3A3C` | `#AEAEB2` |
| `textTertiary` | `#8E8E93` | `#636366` |
| `separator` | `#3A3A3C @ 20%` | `#FFFFFF @ 20%` |

玻璃态：导航列与频道列表用 `.ultraThinMaterial`，叠加在 `windowBg` 上形成层次。

### 2.4 Agent 身份色（固定，跨暗亮模式一致）

`Planner` blue / `Coder` orange / `Reviewer` green / `Writer` purple / `Executor` teal / `Researcher` pink。头像底色 = 身份色 @ 18%，文字 = 身份色。

---

## 3. 字体系统（Apple HIG 字阶）

全部用 `.system` + `design: .rounded`（数字/统计）或默认（正文）。字号直接取 `StudioTheme` 令牌：

| 令牌 | 字号 | 字重 | 用途 |
|------|------|------|------|
| `captionSize` | 12 | regular/medium | 标签、元数据、时间戳 |
| `footnoteSize` | 13 | regular/medium | 列表次行、消息正文 |
| `smallTextSize` | 14 | medium/semibold | 卡片标题、导航项 |
| `textSize` | 15 | regular | 正文 |
| `bodySize` | 16 | semibold | 统计数值 |
| `titleSize` | 19 | semibold/bold | 区块标题、详情名 |
| `headlineSize` | 22 | bold | StatTile 数值 |
| `largeTitleSize` | 30 | bold | （预留）页面大标题 |

等宽（ID/实现路径/hop 计数）用 `design: .monospaced`。

---

## 4. 间距系统（8px 栅格）

| 令牌 | 值 | 用途 |
|------|----|------|
| `spacingXS` | 4 | 紧凑内距、胶囊内距 |
| `spacingS` | 8 | 图标-文字间距、行内间距 |
| `spacingM` | 12 | 卡片内距、列表行间距 |
| `spacingL` | 16 | 区块内距、列间距 |
| `spacingXL` | 24 | 区块间距 |
| `spacing2XL` | 32 | 大区块分隔 |

圆角：`cornerRadiusSmall` 8（导航项）/ `cornerRadius` 12（卡片）/ `cornerRadiusLarge` 16（大容器）。
分隔线：`separator` 1px 竖向分栏；`rowSep` 0.5px 行分隔。

---

## 5. 三栏布局

```
┌──────────────────────────────────────────────────────────┐
│ IconRail(52) │ Sidebar(collapsible) │ WorkspaceArea      │
│              │                      │ ┌────────┬───────┐ │
│  智能体       │  • 团队协作           │ │areaRail│content│ │
│  Fusion-MLX  │    Agents            │ │ 200px  │       │ │
│  ...         │    编排模式           │ │glass   │       │ │
│              │    协作频道           │ │        │       │ │
│              │    ...               │ └────────┴───────┘ │
└──────────────────────────────────────────────────────────┘
```

`TeamCollabView` 内部为「区域导航(200px, .ultraThinMaterial) | 1px 分隔 | 区域内容」。
- 选中区域：左侧 3px accent 竖条 + `accent @ 12%` 底。
- 切换动画：`theme.springSnappy`。
- AgentsArea / ChannelsArea 内部再分「列表 | 1px | 详情/消息」二级三栏，详情面板固定 320px / 频道列表 240px。

---

## 6. 组件规范

### 6.1 ScreenHeader
`ScreenHeader(eyebrow:title:subtitle:)` - 区块页眉。eyebrow 小号大写英文，title `titleSize` semibold，subtitle `footnoteSize` secondary。

### 6.2 FusionCard
`FusionCard(style:.elevated, header:, headerIcon:) { content }` - 主卡片容器。`surfaceElevated` 底 + 0.5 `groupBorder` 描边 + 12 圆角。`header` 行：图标 `iconM` accent + 标题 `smallTextSize` semibold。

### 6.3 StatTile
图标(`iconM`, tint) + 数值(`headlineSize` bold rounded) + 标签(`captionSize` tertiary)。`surfaceElevated` + 0.5 border + 12 圆角。用于总览/监控/健康的 KPI。

### 6.4 AgentAvatar
圆形 + 身份色 @ 18% 底 + 首字母（字号 = size × 0.45, semibold, 身份色）。尺寸 32/36/40/56。

### 6.5 StatusPill
6px 圆点 + `captionSize` medium 标签，胶囊底 = 状态色 @ 12%。

### 6.6 CircuitBar
两行：标题(isOpen ? 熔断开启:熔断关闭, 红/绿) + `failures/threshold`；进度条 `GeometryReader`，宽 = `progress × 全宽`，色 = isOpen ? redDot : accent。`progress ∈ [0,1]`。

### 6.7 PatternCard
可选卡片。激活态：`accent` 实底 + `accentText` 图标 + `accent` 1.5 描边 + 右上 `checkmark.circle.fill`。未激活：`surfaceElevated` + 0.5 border。

### 6.8 FlowChips
水平排列胶囊：文字(tint, captionSize medium) + 底 tint @ 12%。用于能力/交接目标。

### 6.9 消息行（频道）
头像(32) + 发送者(`footnoteSize` semibold) + 时间戳 + `R{round}` 胶囊(accent @ 12%)。正文 `mentionText` 将 `@name` 高亮为 accent semibold。

---

## 7. 暗色/亮色切换

- `ContentView`：`theme = appState.isDarkMode ? StudioTheme.dark : StudioTheme.light`，`.preferredColorScheme(appState.isDarkMode ? .dark : .light)`，`.environment(\.studioTheme, theme)`。
- 所有子视图通过 `@Environment(\.studioTheme) private var theme` 读取，无需自行判断模式。
- Agent 身份色跨模式一致；语义状态色按上表亮/暗分别取值。

---

## 8. 可访问性（HIG）

- 最小点击区域 ≥ 32×32（导航项 padding `spacingS` + 图标 `iconL`）。
- 文本对比度：正文 `text`/`textSecondary` 在两种模式下均 ≥ 4.5:1；`textTertiary` 仅用于非关键元数据。
- 状态不仅靠颜色：`StatusPill` 同时有圆点 + 文字标签；熔断卡片额外有 `exclamationmark` 图标 + 文案。
- 动画提供 `springSnappy` 反馈，时长受系统「减少动态效果」设置约束（SwiftUI 自动遵循）。

---

## 9. 与上游数据结构的映射

GUI 用静态样例数据（`TeamCollabStore`）可视化 fusion-agent-studio 的真实协作后端 schema：

| GUI 模型 | 上游 schema (agent_runtime/) |
|----------|------------------------------|
| `SwarmAgent` | `swarm_router.SwarmAgent` |
| `TaskDelegation` | `swarm_router.TaskDelegation` |
| `HandoffRecord` | `swarm_router.HandoffContext` |
| `PlazaChannel` / `PlazaMessage` | `plaza.Plaza` channel/message |
| `FMStats` | `fmp_router.FMProtocol` stats |
| `OrchestrationPattern`(6) | `orchestrator.MultiAgentOrchestrator` 6 模式 |
| `SubGraphInfo` | `sub_graph.SubGraphRegistry` |
| `CircuitBreakerState` | `fmp_router.AgentCircuitBreaker` |

后续接通实时数据时，将 `TeamCollabStore` 的 `@Published` 数组改为从 IPC/HTTP 拉取即可，视图层无需改动。
