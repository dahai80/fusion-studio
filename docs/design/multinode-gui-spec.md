# Fusion Multi-Node GUI 设计规范 v1.0

> UI/UX Pro Max — macOS 原生 SwiftUI | Apple HIG | 主色 #007AFF | 8px 栅格

---

## 1. 设计哲学

| 原则 | 释义 |
|------|------|
| **Native First** | 100% SwiftUI，零 Web 嵌入，控件全部使用 AppKit 原生渲染 |
| **Glass + Neumorph** | `.ultraThinMaterial` 玻璃态底板 + 轻微投影拟物，层次清晰但不喧宾夺主 |
| **Information Density** | 集群监控需要信息密度，用紧凑行高(36pt)和 8px 栅格，单屏展示尽可能多数据 |
| **Color as Signal** | 状态色是第一视觉语言：绿=在线 / 琥珀=忙碌 / 红=故障 / 蓝=信息 |
| **Progressive Disclosure** | 总览→详情→操作 三层递进，不一次暴露所有细节 |

---

## 2. 配色系统

### 2.1 语义色板 (双模式)

| Token | Light | Dark | 用途 |
|-------|-------|------|------|
| `accent` | `#007AFF` | `#007AFF` | 主色调，按钮/选中/链接 |
| `accentSoft` | `#007AFF·10%` | `#007AFF·15%` | 选中背景、Tinted按钮底 |
| `greenDot` | `#34C759` | `#4CD964` | 节点在线/健康/成功 |
| `amberDot` | `#FF9F0A` | `#FFCC00` | 节点忙碌/警告 |
| `redDot` | `#FF3B30` | `#FF6B6B` | 节点故障/错误/离线 |
| `blueDot` | `#007AFF` | `#5AC8FA` | 信息/进行中 |
| `purpleDot` | `#AF52DE` | `#BF5AF2` | Master 角色专属色 |
| `surfacePrimary` | `#FFFFFF` | `#1E1E24` | 主面板背景 |
| `surfaceSecondary` | `#F5F5F7` | `#2C2C34` | 卡片/分组背景 |
| `surfaceElevated` | `#FFFFFF·shadow` | `#38383F` | 悬浮层/弹窗 |
| `glassOverlay` | `.ultraThinMaterial` | `.ultraThinMaterial` | 工具栏/顶栏 |

### 2.2 节点状态色映射

| NodeStatus | 色值 | StatusPill样式 |
|-----------|------|---------------|
| `online` | `greenDot` | `StatusPill(.running)` |
| `busy` | `amberDot` | `StatusPill(.custom(amber, "Busy"))` |
| `offline` | `textTertiary` | `StatusPill(.stopped)` |
| `fault` | `redDot` | `StatusPill(.error)` |

### 2.3 任务状态色映射

| TaskStatus | 色值 | TagColor |
|-----------|------|----------|
| `pending` | `blueDot` | `.blue` |
| `running` | `greenDot` | `.green` |
| `completed` | `textSecondary` | `.gray` |
| `failed` | `redDot` | `.red` |
| `cancelled` | `textTertiary` | `.gray` |
| `degraded` | `amberDot` | `.orange` |

---

## 3. 字体系统

| Token | Size | Weight | 用途 |
|-------|------|--------|------|
| `display` | 30pt | Bold (Rounded) | 模块标题 |
| `headline` | 22pt | Bold (Rounded) | 页面标题 |
| `title` | 19pt | Semibold | 区块标题 |
| `body` | 16pt | Regular | 正文 |
| `text` | 15pt | Regular | 列表文字 |
| `caption` | 12pt | Medium | 标签/徽章 |
| `mono` | 13pt Monospaced | Medium | 数值/ID/代码 |

**所有数值显示使用 `.system(.body, design: .monospacedDigit)`** — 确保数字不跳动。

---

## 4. 8px 栅格间距系统

| Token | Value | 用途 |
|-------|-------|------|
| `xs` | 4pt | 图标与文字间距 |
| `s` | 8pt | 行内元素间距 |
| `m` | 12pt | 行间距 |
| `l` | 16pt | 卡片内边距 |
| `xl` | 24pt | 区块间距 |
| `2xl` | 32pt | 大区块间距 |
| `rowH` | 36pt | 列表行高 |
| `cardH` | 88pt | 指标卡片高度 |

---

## 5. 布局架构

### 5.1 三栏布局 (复用 ContentView 现有结构)

```
┌──────────┬──────────────────────────────┬─────────────┐
│  IconRail│     Workspace (Module)        │  Inspector  │
│   52pt   │     flex ∞                    │   280pt     │
│          │                              │             │
│  [集群]  │  ┌─ Toolbar ──────────────┐  │  Node/Task  │
│  [拓扑]  │  │ 集群总览  ●在线 5/8   │  │  Detail     │
│  [任务]  │  └───────────────────────┘  │             │
│  [告警]  │  ┌─ Metrics Strip ────────┐  │  ┌────────┐│
│          │  │ 🟢8  🟡3  🔴1  📊12  │  │  │Prop    ││
│          │  └───────────────────────┘  │  │Actions ││
│          │  ┌─ Node List ────────────┐  │  │Config  ││
│          │  │ M1-Mac ▸ Master  12%  │  │  └────────┘│
│          │  │ M2-Mac ▸ Worker   85% │  │             │
│          │  │ M3-Mac ▸ Worker   42% │  │             │
│          │  └───────────────────────┘  │             │
│          │                              │             │
└──────────┴──────────────────────────────┴─────────────┘
```

### 5.2 Multi-Node 侧边栏子模块

| 图标 | 名称 | Module枚举 | 视图 |
|------|------|-----------|------|
| `square.grid.2x2` | 集群总览 | `.clusterOverview` | ClusterOverviewView |
| `point.3.connected.trianglepath.dotted` | 拓扑图 | `.clusterTopology` | ClusterTopologyView |
| `list.bullet.clipboard` | 任务监控 | `.taskMonitor` | TaskMonitorView |
| `exclamationmark.triangle` | 告警通知 | `.alertCenter` | AlertCenterView |

---

## 6. 组件规范

### 6.1 MetricStripCard — 顶部指标卡片

```
┌──────────────────┐
│ ● 节点           │  icon + label (caption, textSecondary)
│   8 / 12        │  value (display, mono, text)
│   在线           │  subtitle (caption, textTertiary)
└──────────────────┘
尺寸: flex 1/4, 高 88pt
背景: surfaceSecondary + cornerRadius(12)
状态点: 8pt Circle, 颜色跟随状态
```

### 6.2 NodeRow — 节点列表行

```
┌────────────────────────────────────────────────────────┐
│ [●] M1-MacBook-Pro        Master   12.4/32GB  12% │ ▸ │
│     192.168.1.10:9756                  3 tasks      │   │
└────────────────────────────────────────────────────────┘
行高: 56pt (两行: 主行36pt + 辅行20pt)
主行: 状态点(8pt) + hostname(text,medium) + 角色Tag + 内存 + CPU进度条
辅行: IP:Port(caption,mono) + 活跃任务数
选中: selBg 填充
右键: ContextMenu { 移除节点, 查看指标, 手动调度 }
```

### 6.3 TaskRow — 任务列表行

```
┌────────────────────────────────────────────────────────┐
│ [🔵] task-a3f8   推理    Llama-70b   Running   ▓▓▓░░ │
│      Node: M2-Mac / 分片 2/4    降级: 70b→32b         │
└────────────────────────────────────────────────────────┘
行高: 56pt
主行: 状态点 + task_id(mono) + mode + model + StatusPill + 进度条
辅行: 分配节点 + 分片进度 + 降级信息
进度条: 6pt高, accent渐变填充
```

### 6.4 TopologyCanvas — 拓扑图

```
        ┌─────────┐
        │  Master │  purpleDot边框, 64pt Circle
        │  M1-Mac │
        └────┬────┘
       ┌─────┼─────┐
   ┌───┴──┐ ┌┴───┐ ┌┴───┐
   │W1    │ │W2  │ │W3  │  绿/琥珀/红 Circle 48pt
   │M2-Mac│ │M3  │ │M4  │
   └──────┘ └────┘ └────┘

连线: FMP连接, stroke 2pt, accent·30%
动效: 脉冲动画(2s循环)表示心跳
拖拽: 节点可拖拽重排
点击: 选中节点 → Inspector 详情
```

### 6.5 AlertBanner — 告警横幅

```
┌──────────────────────────────────────────────────────┐
│ ⚠️ 节点 M4-Mac 离线                     [确认] [详情] │
└──────────────────────────────────────────────────────┘
高度: 40pt, 固定在 Workspace 顶部
背景: warningBg / errorBg (按严重度)
入场: .move(edge: .top) + .opacity
自动消失: 8s后淡出 (可手动关闭)
```

### 6.6 AutoscalerConfigPanel — 弹性配置面板

```
┌─ Autoscaler ────────────────────┐
│  最小节点  [  2  ] ───────○     │  Slider(min:1, max:32)
│  最大节点  [  8  ] ────○────    │
│  扩容阈值  [ 0.80] ──────○──   │
│  缩容阈值  [ 0.30] ─○───────   │
│  冷却时间  [ 60s ]  ────○────   │
│  策略      [Threshold ▾]        │  Picker: threshold/queue_depth/cpu_memory
│                    [应用配置]    │  FusionButton(.primary)
└─────────────────────────────────┘
```

---

## 7. 页面蓝图

### 7.1 M7-01 集群总览 (ClusterOverviewView)

```
ScreenHeader("Multi-Node", "集群总览", "实时监控集群节点状态与资源")

┌─ MetricsStrip (4列) ──────────────────────────────────────┐
│ [MetricStripCard: 节点] [MetricStripCard: 在线] [活跃任务] [集群内存] │
└────────────────────────────────────────────────────────────┘

┌─ 快速操作栏 ─────────────────────────────────────────────┐
│ [🔗加入节点] [📋提交任务] [⚙️Autoscaler]     🔍搜索节点   │
└────────────────────────────────────────────────────────────┘

ListGroup {
    StudioSectionHeader("节点列表 (\(nodes.count))")
    ForEach(nodes) { node in
        NodeRow(node: node)
            .contextMenu { 移除; 指标; 调度 }
            .onTapGesture { inspectorContext = .node(node.id) }
    }
}
```

### 7.2 M7-02 集群拓扑 (ClusterTopologyView)

```
ScreenHeader("Multi-Node", "拓扑图", "可视化 Master-Worker 连接关系")

┌─ TopologyCanvas ────────────────────────────────────────┐
│                                                         │
│                  [Master]                                │
│                 /   |   \                                │
│            [W1]   [W2]  [W3]                            │
│                                                         │
│  图例: ●在线 ●忙碌 ●离线 ●故障  ───FMP连接              │
└─────────────────────────────────────────────────────────┘

底部信息栏: 节点数 | 在线率 | 平均负载
```

### 7.3 M7-03 任务监控 (TaskMonitorView)

```
ScreenHeader("Multi-Node", "任务监控", "实时跟踪任务执行状态与进度")

FusionTabBar: [全部 | 运行中 | 已完成 | 失败]

┌─ MetricsStrip (3列) ────────────────────────────┐
│ [总任务] [运行中] [平均耗时]                       │
└──────────────────────────────────────────────────┘

ListGroup {
    ForEach(filteredTasks) { task in
        TaskRow(task: task)
            .onTapGesture { inspectorContext = .task(task.id) }
    }
}
```

### 7.4 M7-05 告警中心 (AlertCenterView)

```
ScreenHeader("Multi-Node", "告警中心", "集群异常检测与智能建议")

FusionTabBar: [活跃告警 | 智能建议 | 告警历史]

┌─ 活跃告警 ──────────────────────────────────────┐
│ 🔴 M4-Mac 离线              2分钟前    [确认]    │
│ 🟡 M2-Mac 内存 >90%         5分钟前    [确认]    │
│ 🔴 task-b7c2 推理失败        12分钟前   [重试]    │
└──────────────────────────────────────────────────┘

┌─ 智能建议 ──────────────────────────────────────┐
│ 💡 节点 M3-Mac 长期低负载，建议缩容              │
│ 💡 模型 70b 频繁降级，建议增加 Worker GPU         │
└──────────────────────────────────────────────────┘
```

---

## 8. Inspector 面板规范

### 8.1 节点详情 Inspector

```
┌─ Node Detail ──────────────────┐
│  M1-MacBook-Pro                │  hostname (headline)
│  Master   ● Online             │  Role + StatusPill
│  ─────────────────────────     │
│  ▸ 硬件                        │
│    CPU: Apple M1 Pro           │
│    GPU: 16-core                │
│    UMA: 32 GB                  │
│  ▸ 资源                        │
│    CPU: ██░░░░ 12%             │  ProgressView
│    内存: ████░░ 12.4/32 GB     │
│    活跃任务: 3/8                │
│  ▸ 网络                        │
│    IP: 192.168.1.10            │  mono
│    Port: 9756                  │
│    心跳: 2s前                   │
│  ─────────────────────────     │
│  [移除节点]  [手动调度]         │  FusionButton
└────────────────────────────────┘
```

### 8.2 任务详情 Inspector

```
┌─ Task Detail ──────────────────┐
│  task-a3f8c2                   │  task_id (mono, headline)
│  推理 · Llama-70b              │  mode + model
│  Running   ▓▓▓░░ 75%           │  StatusPill + ProgressRing
│  ─────────────────────────     │
│  ▸ 执行                        │
│    分配: M2-Mac, M3-Mac        │
│    分片: 2/4 完成              │
│    降级: 70b → 32b             │
│    优先级: High                 │
│  ▸ 时间线                      │
│    10:30 创建                   │
│    10:31 调度 → M2             │
│    10:32 降级 70b→32b          │
│    10:33 分片2完成             │
│  ─────────────────────────     │
│  [降级] [迁移] [取消]          │  FusionButton
└────────────────────────────────┘
```

---

## 9. 动效规范

| 场景 | 动效 | 参数 |
|------|------|------|
| 数据刷新 | 数值变化 | `spring(response:0.35, damping:0.85)` |
| Tab切换 | 内容切换 | `.move(edge:.trailing) + .opacity` |
| 告警弹窗 | 入场 | `.move(edge:.top) + .opacity`, 8s后自动淡出 |
| 拓扑心跳 | 脉冲 | `@3s` 重复, Circle缩放0.8→1.2 + opacity 0.3→0 |
| 节点上线/离线 | 列表增删 | `.spring(response:0.4, damping:0.65)` |
| 进度条 | 填充 | `.animation(.linear(duration:0.3))` |
| Hover | 行高亮 | `hoverBg` 填充, 0.15s |

---

## 10. 数据流架构

```
┌───────────────┐    HTTP GET (2s poll)     ┌──────────────────────┐
│  MultiNodeEngine │ ◄────────────────────── │ fusion-multi-node     │
│  (ObservableObject)│                       │ Master Server         │
│               │    HTTP POST/PUT/DELETE    │ http://127.0.0.1:9753 │
│               │ ──────────────────────►   │                      │
└───────┬───────┘                           └──────────────────────┘
        │ @Published
        ▼
┌───────────────┐    @EnvironmentObject     ┌──────────────────────┐
│ ClusterOverview│ ◄─────────────────────── │ InspectorPanel       │
│ ClusterTopology│                          │ NodeDetail / TaskDtl │
│ TaskMonitor    │                          │ AutoscalerConfig     │
│ AlertCenter    │                          │                      │
└───────────────┘                          └──────────────────────┘
```

**轮询策略**:
- 集群状态 (`/api/v1/cluster/stats`): 2s
- 节点列表 (`/api/nodes`): 2s
- 任务列表 (`/api/tasks`): 3s
- 告警建议 (`/api/v1/observability/suggestions`): 10s
- 告警历史: 按需加载

---

## 11. 文件结构清单

```
FusionStudio/Modules/MultiNode/
├── MultiNodeModels.swift          # Codable 数据模型
├── MultiNodeEngine.swift          # ObservableObject 数据引擎
├── ClusterOverviewView.swift      # M7-01 集群总览
├── ClusterTopologyView.swift      # M7-02 拓扑图
├── TaskMonitorView.swift          # M7-03 任务监控
├── NodeActionsView.swift          # M7-04 节点操作 + AutoscalerConfigView
├── AlertCenterView.swift          # M7-05 告警中心 + AlertManager
└── Components/
    ├── MetricStripCard.swift      # 指标卡片组件
    ├── NodeRow.swift              # 节点行组件
    ├── TaskRow.swift              # 任务行组件
    └── TopologyCanvas.swift       # 拓扑画布组件
```

---

## 12. 响应式断点

| 宽度 | 行为 |
|------|------|
| ≥ 1200pt | 三栏全展开: IconRail + Sidebar + Workspace + Inspector |
| 900–1199pt | Inspector 自动收起, Sidebar 可折叠 |
| < 900pt | Sidebar 强制收起, Inspector 用 Sheet 覆盖 |

---

## 13. 无障碍 (Accessibility)

- 所有状态点需加 `.accessibilityLabel("节点在线")`
- 进度条需加 `.accessibilityValue("75%")`
- 拓扑图需提供等效的列表视图 (Toggle切换)
- 颜色不作为唯一信息载体，必须配合文字/图标
- 键盘导航: Tab 遍历节点/任务行, Space 展开操作菜单
