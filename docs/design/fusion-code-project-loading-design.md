# Fusion Code — 项目加载深度设计

> UI/UX Pro Max · macOS Native · 暗色优先 · 主色 #007AFF

---

## 1. 设计目标

在 Fusion Studio 左侧 `<>` Code 模块中，实现**项目代码加载**的完整交互体验：
- **零门槛**：首次进入即引导用户打开代码
- **多来源**：本地文件夹 / 本地单文件 / GitHub 仓库
- **上下文感知**：加载后自动建立代码上下文，AI 对话可直接引用
- **状态可追溯**：加载进度、错误、结果全程可见

---

## 2. 交互架构

### 2.1 整体布局（保持现有三栏，增强 Files Tab）

```
┌──────────────────────────────────────────────────────────────┐
│  [IconRail] │  [Sidebar]  │         [Workspace]             │
│      48pt   │   220-300pt │                                 │
│             │             │                                 │
│    <> Code  │ ┌─────────┐ │  ┌───────────────────────────┐  │
│             │ │Chat│Files│Git│  │  CodeContentView         │  │
│             │ │    │     │  │  │                           │  │
│             │ │    │ 📂  │  │  │  (对话 or 欢迎页)         │  │
│             │ │    │ 📂  │  │  │                           │  │
│             │ │    │ 📂  │  │  └───────────────────────────┘  │
│             │ │    │     │  │  ┌───────────────────────────┐  │
│             │ │    │[+]  │  │  │ [📎] [输入框...] [↑发送] │  │
│             │ └─────────┘ │  └───────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 项目加载的 4 个入口

| # | 入口 | 触发方式 | 优先级 |
|---|------|---------|--------|
| 1 | **Files Tab 底部 [+ Open]** | 点击按钮 → NSOpenPanel | ⭐⭐⭐ 主入口 |
| 2 | **欢迎页快捷卡片** | 首次进入 → "Open Project" 卡片 | ⭐⭐⭐ 零门槛 |
| 3 | **底部输入栏 📎 paperclip** | 点击 → 弹出附加菜单 | ⭐⭐ 补充入口 |
| 4 | **URL 粘贴自动识别** | 粘贴 github.com URL → 自动 clone | ⭐⭐ 智能入口 |

---

## 3. 详细交互设计

### 3.1 欢迎页 — 首次进入（无项目时）

当 `files.isEmpty && agent.conversation.isEmpty` 时，主区域显示欢迎页：

```
┌─────────────────────────────────────────────────┐
│                                                 │
│                  ✨ (sparkles)                   │
│           Fusion Code — AI Coding Assistant      │
│       Claude Code compatible · Powered by MLX    │
│                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │  📂      │ │  🔍      │ │  🐛      │        │
│  │ Open     │ │ Explain  │ │ Review   │        │
│  │ Project  │ │ Code     │ │ Code     │        │
│  │          │ │          │ │          │        │
│  │ 本地/Git │ │ 解释代码 │ │ 查找缺陷 │        │
│  └──────────┘ └──────────┘ └──────────┘        │
│  ┌──────────┐ ┌──────────┐                     │
│  │  🧪      │ │  ⚡      │                     │
│  │ Test     │ │ Optimize │                     │
│  │ Code     │ │ Code     │                     │
│  │          │ │          │                     │
│  │ 生成测试 │ │ 性能优化 │                     │
│  └──────────┘ └──────────┘                     │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  最近打开                                │    │
│  │  📁 fusion-agent-studio    2小时前       │    │
│  │  📁 fusion-code            昨天          │    │
│  │  📁 my-app                  3天前        │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
└─────────────────────────────────────────────────┘
```

**交互细节：**
- "Open Project" 卡片点击 → 触发 `openProjectSheet` 弹窗
- "最近打开" 列表点击 → 直接加载该目录
- 其余卡片保持现有 AI 提示逻辑

### 3.2 Open Project 弹窗（核心交互）

点击 "Open Project" 或 Files Tab 的 [+ Open] 后，弹出 Sheet：

```
┌──────────────────────────────────────────────┐
│  Open Project                          [✕]   │
│                                              │
│  ┌──────────────────────────────────────────┐│
│  │  📂 Local Folder                         ││
│  │  ─────────────────────────────────────── ││
│  │  选择本地文件夹，自动扫描代码文件           ││
│  │                                          ││
│  │  [  Choose Folder...  ]                  ││
│  └──────────────────────────────────────────┘│
│                                              │
│  ┌──────────────────────────────────────────┐│
│  │  📄 Single File                          ││
│  │  ─────────────────────────────────────── ││
│  │  打开单个文件进行编辑和 AI 辅助            ││
│  │                                          ││
│  │  [  Choose File...  ]                    ││
│  └──────────────────────────────────────────┘│
│                                              │
│  ┌──────────────────────────────────────────┐│
│  │  🔗 GitHub Repository                    ││
│  │  ─────────────────────────────────────── ││
│  │  克隆远程仓库到本地工作区                  ││
│  │                                          ││
│  │  URL  [ github.com/user/repo        ]    ││
│  │  Branch  [ main ▾ ]                       ││
│  │                                          ││
│  │  [  Clone & Open  ]                      ││
│  └──────────────────────────────────────────┘│
│                                              │
│  ─────────────── 或 ───────────────          │
│                                              │
│  拖拽文件或文件夹到此处                         │
│                                              │
└──────────────────────────────────────────────┘
```

**视觉规格：**
- Sheet 宽度 520pt，居中
- 3 个选项卡片使用 `FusionCard(style: .bordered)`
- 每个卡片内含：图标 + 标题 + 描述 + 操作按钮
- GitHub 区域 URL 输入框实时校验 URL 格式
- 底部拖拽区域：虚线边框 + drop handler

### 3.3 加载进度状态

项目加载期间，Files Tab 和主区域显示进度：

**Files Tab 状态：**
```
┌─────────────────────┐
│ Files          [×]  │
│ ─────────────────── │
│ 🔄 Loading...       │
│ ████████░░░ 67%     │
│                     │
│ Scanning 34/51...   │
│ • src/              │
│ • lib/              │
└─────────────────────┘
```

**主区域 Toast 提示：**
- 加载开始：`FusionToast(.info, "Opening project...")`
- 加载完成：`FusionToast(.success, "Loaded 47 files from my-project")`
- 加载失败：`FusionToast(.error, "Failed to clone: ...")`

**GitHub Clone 特殊状态：**
```
┌─────────────────────────────────────────┐
│  🔄 Cloning repository...               │
│                                         │
│  git clone https://github.com/...       │
│  Receiving objects:  78% (1234/1580)    │
│  ████████████░░░░░░░                    │
│                                         │
│  [ Cancel ]                             │
└─────────────────────────────────────────┘
```

### 3.4 加载完成后的 Files Tab

```
┌─────────────────────────┐
│ my-project        [⚙][+]│
│ main · 47 files         │
│ ─────────────────────── │
│ 🔍 搜索文件...          │
│ ─────────────────────── │
│ ▼ 📁 src/               │
│   ▼ 📁 components/      │
│     📄 App.swift     ●  │
│     📄 Button.swift     │
│   ▼ 📁 models/          │
│     📄 User.swift       │
│   📄 main.swift         │
│ 📁 tests/               │
│ 📄 README.md            │
│ 📄 Package.swift        │
└─────────────────────────┘
```

**交互细节：**
- 顶部项目名 + Git 分支 + 文件计数 + [⚙ 设置] [+ 新建]
- 搜索框实时过滤
- 文件夹可展开/折叠，带动画 `theme.springSnappy`
- 修改未保存文件显示橙色圆点 `●`
- 单击文件 → 在 Chat 上下文中附加该文件内容
- 右键文件 → 上下文菜单（在 Finder 中显示 / 复制路径 / 从列表移除）

### 3.5 底部输入栏 — 📎 附加菜单

点击 paperclip 按钮后，弹出 Popover 菜单：

```
┌──────────────────────────┐
│ 📂  Add Folder...        │
│ 📄  Add File...          │
│ 🔗  Add GitHub Repo...   │
│ ─────────────────────── │
│ 📋  Paste from Clipboard │
└──────────────────────────┘
```

### 3.6 URL 智能识别 — 输入栏粘贴

在底部输入栏粘贴 GitHub URL 时：

1. 检测到 `github.com` 或 `gitlab.com` 等 URL
2. 输入框下方出现蓝色提示条：
```
┌──────────────────────────────────────────────────┐
│ 🔗 检测到 Git 仓库 URL                            │
│ https://github.com/user/repo                      │
│                                                   │
│ [ Clone & Open ]  [ 作为文本发送 → ]              │
└──────────────────────────────────────────────────┘
```
3. 用户选择 "Clone & Open" → 触发 clone 流程
4. 用户选择 "作为文本发送" → 普通聊天消息

---

## 4. 数据模型设计

### 4.1 ProjectWorkspace（新增）

```swift
class ProjectWorkspace: ObservableObject {
    @Published var projectRoot: URL?
    @Published var projectName: String = ""
    @Published var gitBranch: String = ""
    @Published var files: [CodeFile] = []
    @Published var isLoading: Bool = false
    @Published var loadProgress: Double = 0
    @Published var loadMessage: String = ""
    @Published var recentProjects: [RecentProject] = []

    struct RecentProject: Identifiable, Codable {
        let id: UUID
        let name: String
        let path: String
        let gitURL: String?
        let lastOpened: Date
    }
}
```

### 4.2 CodeFile（增强）

现有模型增加字段：
```swift
struct CodeFile: Identifiable, Hashable {
    let id: String
    var name: String
    var path: String
    var content: String
    var language: String
    var isModified: Bool
    var isDirectory: Bool
    var children: [CodeFile]?      // 新增：子文件/文件夹
    var isExpanded: Bool           // 新增：展开状态
    var relativePath: String       // 新增：相对项目根的路径
    var fileSize: Int64            // 新增：文件大小
}
```

---

## 5. 服务层设计

### 5.1 ProjectLoader（新增服务类）

```swift
class ProjectLoader {
    /// 打开本地文件夹 — 调用 NSOpenPanel
    func openLocalFolder() async throws -> ProjectWorkspace

    /// 打开单个文件 — 调用 NSOpenPanel
    func openSingleFile() async throws -> ProjectWorkspace

    /// 克隆 GitHub 仓库 — git subprocess
    func cloneGitHubRepo(url: String, branch: String) async throws -> ProjectWorkspace

    /// 递归扫描目录构建文件树
    func scanDirectory(_ url: URL, maxDepth: Int = 6) async -> [CodeFile]

    /// 保存/读取最近打开列表 (UserDefaults)
    func saveRecentProject(_ project: ProjectWorkspace.RecentProject)
    func loadRecentProjects() -> [ProjectWorkspace.RecentProject]

    /// 取消当前加载
    func cancelLoading()
}
```

### 5.2 文件类型识别

```swift
extension CodeFile {
    static func languageForPath(_ path: String) -> String
    static func iconForLanguage(_ lang: String) -> String
    static func shouldSkipDirectory(_ name: String) -> Bool
}
```

### 5.3 忽略规则

扫描目录时跳过：
- `.git/`, `.svn/`, `.hg/`
- `__pycache__/`, `node_modules/`, `.venv/`, `build/`, `dist/`
- `.DS_Store`, `*.pyc`, `*.pyo`
- 大文件（> 1MB 默认跳过，可配置）

---

## 6. 动效规格

| 交互 | 动效 | Token |
|------|------|-------|
| 文件夹展开/折叠 | springSnappy | `response: 0.25, damping: 0.9` |
| 项目加载进度 | 线性 + pulse | `animationNormal: 0.25` |
| Sheet 弹出 | springBouncy | `response: 0.4, damping: 0.65` |
| Toast 出现/消失 | transitionSlide | `move(edge: .trailing) + opacity` |
| URL 检测提示条 | transitionScale | `scale(0.96) + opacity` |
| 文件选中高亮 | springDefault | `response: 0.35, damping: 0.85` |

---

## 7. 键盘快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌘O` | 打开项目（触发 openProjectSheet） |
| `⌘⇧O` | 快速打开文件（搜索文件名） |
| `⌘⇧P` | 切换 Files Tab |
| `⌘⇧G` | 切换 Git Tab |

---

## 8. 错误处理

| 场景 | 处理 |
|------|------|
| 文件夹无权限 | Toast error + 提示修改权限 |
| GitHub clone 失败 | 内联错误 + 重试按钮 |
| 文件过大（>1MB） | 跳过 + 文件树中灰显 + hover 提示 "File too large" |
| 非代码项目（图片目录等） | 正常加载但提示 "No code files detected" |
| git 未安装 | GitHub 选项灰显 + 提示安装 Xcode CLI Tools |

---

## 9. 实现分阶段

### Phase 1 — 核心加载（本次）
1. 新增 `ProjectWorkspace` ObservableObject
2. 新增 `ProjectLoader` 服务类（本地文件夹/单文件）
3. 重写 `FileTreeView`（树状展示 + 搜索 + 展开/折叠）
4. 实现 "Open Project" Sheet 弹窗
5. 欢迎页增加 "Open Project" 卡片 + 最近打开列表
6. 最近打开列表持久化 (UserDefaults)
7. 文件点击 → 附加到 AI 上下文

### Phase 2 — GitHub 集成
1. GitHub clone 流程（git 子进程）
2. Clone 进度 UI
3. URL 智能识别（输入栏粘贴检测）

### Phase 3 — 增强交互
1. 📎 paperclip Popover 菜单
2. 拖拽打开文件/文件夹
3. 快速打开文件（⌘⇧O）
4. 右键上下文菜单
5. 多项目切换（项目标签页）

---

## 10. 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `Modules/Code/CodeEditorView.swift` | **重写** | 新增 OpenProjectSheet / ProjectWorkspace / ProjectLoader / 重写 FileTreeView |
| `Common/AppState.swift` | 小改 | 新增 keyboard shortcut 注册 |
| `Bridge/FusionCoderBridge.swift` | 小改 | askAI 支持传入文件上下文 |
