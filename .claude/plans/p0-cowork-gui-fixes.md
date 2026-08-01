# P0 CoWork GUI 修复计划

Importers/callers: SpaceSharedChat, SpaceMainView (SwiftUI views consuming IPCClient + CoworkSpace)
Affected API: IPCClient.spaceChatStreamEvents (new), SpaceArtifact.content/filePath (new), MarkdownContentView (new component)
Data schemas: StreamChatEvent (reuse existing), SpaceArtifact adds content+filePath fields
User instruction: "开始按优先级修复"

## 修改范围：3 个文件

### 1. IPCClient.swift — 新增 `spaceChatStreamEvents` 流式方法

**现状**: `spaceChatStream` 用 `udsCall` 做请求-响应，无法流式接收 token。

**方案**: 新增 `spaceChatStreamEvents(spaceId:content:senderId:) -> AsyncThrowingStream<StreamChatEvent, Error>`，复用已有 `StreamChatEvent` 模型。底层用 UDS 长连接 + NDJSON 逐行读取，每行解析为 `chat_event` / `chat_done` / `error`，yield `StreamChatEvent`。

流程：
1. 建立 UDS 连接到 `/tmp/fusion-cowork.sock`
2. 发送 `desk.space.chat.stream` JSON-RPC 请求（+ `\n`）
3. 循环 read，按 `\n` 分行解析
4. 每行 → yield StreamChatEvent
5. 收到 `chat_done` 或 error → close + finish

### 2. SpaceListView.swift — 三大 P0 修复

#### P0-A: 流式回复
- `SpaceSharedChat` 新增 `@State private var streamingContent: String?`、`@State private var isStreaming = false`、`@State private var streamingAgentName: String?`
- `sendMessage()` 改用 `spaceChatStreamEvents` 替代 `spaceChatSend`
- 发送时设置 `isStreaming = true`，遍历 stream：
  - `isToken` → 追加到 `streamingContent`
  - `isDone` → 将 streamingContent 转为 SpaceMessage 追加到 messages，清空 streaming
  - `isError` → 显示错误
- `messageList` 在 ForEach 后增加 `streamingBubble` — 显示 Agent 头像 + "思考中..." + 逐字追加内容
- `streamingBubble` 用 MarkdownContentView 渲染

#### P0-B: Markdown/代码渲染
- `messageBubble` 中将 `Text(msg.content)` 替换为 `MarkdownContentView(content:)` — 新建轻量 SwiftUI View
- `MarkdownContentView` 内部用 `AttributedString(markdown:)` 渲染内联 Markdown
- 代码块检测：用正则 `` `\`\`\`(\w*)\n([\s\S]*?)\`\`\`` `` 拆分 → 代码块用 `Text` + monospace font + 复制按钮、普通文本用 AttributedString
- 颜色：代码块背景 `theme.surfaceElevated`，普通文本 `theme.text`

#### P0-C: Artifacts 预览双栏
- `SpaceMainView` 改为可选双栏：左侧对话 + 右侧 Artifact 预览
- 新增 `@State private var previewArtifact: SpaceArtifact?`
- 当 `previewArtifact != nil` 时，右侧显示 `ArtifactPreviewView(artifact:)`
- `SpaceArtifactPanel` 中点击 artifact 行 → 设置 `previewArtifact`
- `ArtifactPreviewView`：根据 kind 渲染
  - `code` → 代码文本 + 语法高亮
  - `doc` → Markdown 渲染
  - `visualization` → 图片/HTML placeholder
  - `data` → 表格 placeholder
- 关闭按钮 → `previewArtifact = nil`

#### P1: 消息操作(随 P0 一起实现)
- 每条消息底部增加操作栏：复制、重新生成(Agent 消息)、评论(已有)
- 复制用 NSPasteboard
- 重新生成：对 Agent 消息重新调用 spaceChatStreamEvents

### 3. CoworkSpace.swift — SpaceArtifact 增加内容字段

- `SpaceArtifact` 新增 `var content: String` (文件内容文本) 和 `var filePath: String`
- `fromDict` 解析 `content` / `file_path` 字段
- 供 `ArtifactPreviewView` 渲染

## 实现顺序

1. IPCClient — `spaceChatStreamEvents` 方法
2. CoworkSpace — SpaceArtifact 增字段
3. SpaceListView — MarkdownContentView 组件
4. SpaceListView — SpaceSharedChat 流式回复 + streamingBubble
5. SpaceListView — 消息操作(复制/重试)
6. SpaceListView — ArtifactPreviewView + 双栏布局
7. build 验证
8. 更新 README.md
