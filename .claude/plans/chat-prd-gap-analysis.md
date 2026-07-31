# Chat 功能对标 Claude.ai PRD 差距分析与实施计划

// Callers: UnifiedChatView, ChatSessionStore. Affected API: ChatPreset, AttachmentData, inputToolbar, sendMessage. Data: ChatSessionData.preset, ChatMessageData.attachments, multimodal message format.
// User instruction: "深度精读PRD文件，对标claude实现Chat的所有功能，需要上下游支持的分别给它们提issue和pr，不要去改他们的代码"

## 一、现状 vs PRD 对比

### L1 — 输入框下方横向快捷按钮

| PRD 功能 | 现状 | 差距 | 归属 |
|---------|------|------|------|
| Code 模式预置 Prompt | `quickCard("Code") { inputText = "Help me write code" }` — 仅填充文本 | 不注入 system prompt，不调整输出偏好 | studio |
| Write 模式预置 Prompt | `quickCard("Write") { inputText = "Help me write something" }` — 仅填充文本 | 同上 | studio |
| Create 模式 | 无（有 "Choice" 替代） | 缺 Create，多 Choice | studio |
| Learn 模式 | `quickCard("Learn")` — 仅填充文本 | 同 Code | studio |
| Life stuff 模式 | `quickCard("Life")` — 仅填充文本 | 同 Code | studio |

**结论**：快捷按钮目前只是占位文本填充，需要改为真正的预置 system prompt 注入，且对齐 PRD 的 5 个分类（Code/Write/Create/Learn/Life stuff）。

### L2 — + 菜单（单条消息临时增强）

| PRD 功能 | 现状 | 差距 | 归属 |
|---------|------|------|------|
| Add files or photos (⌘U) | 无 | 完全缺失 | studio UI + mlx 上游 |
| Take a screenshot | 无（CodeMainView 有，Chat 无） | Chat 模块缺失 | studio |
| Web search 开关 | 有 `isWebSearchEnabled` Toggle | 仅 UI 开关，无实际联网检索逻辑 | studio + mlx 上游 |
| Research (Deep Research) | 无 | 完全缺失 | 远期 |
| Use style | 无 | 完全缺失 | studio |

**关键差距**：
- **文件/图片附件**：`ChatMessageData` 无附件字段；`AgentBridge.inferStream` 的 messages 是 `[[String: String]]`，不支持 OpenAI vision 格式
- **截图**：CodeMainView 已有 `takeScreenshot()` 实现，需移植到 Chat
- **Web Search**：`isWebSearchEnabled` 是空开关，mlx 上游无 web search API

### L3 — Project (持久知识库)

| PRD 功能 | 现状 | 差距 | 归属 |
|---------|------|------|------|
| Add to project | 无 | Chat 不关联 Project | studio + fusion-code |
| Project 级别统一 system prompt | 无 | 完全缺失 | studio |
| Project 文件永久共享 | 无 | 完全缺失 | studio + fusion-code |

### L4 — Skills + Connectors

| PRD 功能 | 现状 | 差距 | 归属 |
|---------|------|------|------|
| Skills | 无 | 完全缺失 | 远期 |
| Connectors | 无 | 完全缺失 | 远期 |

---

## 二、实施计划（按优先级排序）

### Phase 1: L1 快捷模式预置 Prompt（studio 本地可完成）

1. **新增 `ChatPreset` 枚举**，对齐 PRD 5 分类，每项带 systemPrompt + placeholder + icon
2. **改造 `quickCard`**：点击时注入 preset system prompt 到当前 session，而非仅填充 inputText
3. **`ChatSessionData` 新增 `preset: String?` 字段**，持久化当前模式
4. **`ChatSessionStore.sendMessage`**：发送时根据 preset 自动前置 system prompt
5. **`inputToolbar` 展示当前 preset 标签**，可点击切换

### Phase 2: L2 + 菜单增强

#### 2a. 截图功能（studio 本地）
1. 移植 `CodeMainView.takeScreenshot()` 到 UnifiedChatView
2. 新增 `AttachmentData` 数据模型（id/name/type/data）
3. `ChatMessageData` 新增 `attachments: [AttachmentData]?` 字段
4. 截图作为附件绑定到当前消息

#### 2b. 文件/图片附件（studio UI + mlx 上游 issue）
1. studio 侧：
   - `+` 菜单增加 "Add files or photos" 项 + ⌘U 快捷键
   - `NSOpenPanel` 选择文件 → 读取内容 → 存入 `AttachmentData`
   - 输入框上方展示附件缩略图/文件名条（可删除）
   - `ChatMessageData` attachments 持久化
2. **mlx 上游（提 issue）**：messages 参数需从 `[[String: String]]` 扩展为 `[[String: Any]]`，支持 vision 格式

#### 2c. Web Search 开关实际化（studio + mlx 上游 issue）
1. studio 侧：传递 `web_search: true` 参数到 API
2. **mlx 上游（提 issue）**：`/v1/chat/completions` 增加 `web_search` 参数

### Phase 3: L2 Use Style 输出风格（studio 本地）

1. 新增 `OutputStyle` 枚举：正式/极简/技术文档/学术
2. `+` 菜单增加 "Use style" 项
3. 选中后追加 style prompt 到 system prompt

### Phase 4: L3 Project 关联（studio + fusion-code 上游 issue）— 远期

1. `ChatSessionData` 新增 `projectId: String?` 字段
2. `+` 菜单增加 "Add to project"，列出已有 project
3. **fusion-code 上游（提 issue）**：session 关联 project 后自动注入知识库

---

## 三、需要向上游提 Issue 的清单

### fusion-mlx

| # | 标题 | 描述 |
|---|------|------|
| 1 | 支持 Multimodal 消息格式 | `/v1/chat/completions` messages 需支持 `content: [{type:"text"}, {type:"image_url"}]`，当前仅支持纯文本 |
| 2 | 支持 web_search 参数 | `/v1/chat/completions` 增加可选 `web_search: bool`，开启后模型可联网检索 |

### fusion-code

| # | 标题 | 描述 |
|---|------|------|
| 3 | Chat Session 关联 Project | session 增加 `project_id`，关联后 project 知识库文件自动注入 session 上下文 |

---

## 四、本期实施范围

**先做 Phase 1 + Phase 2a + Phase 2b(studio侧) + Phase 3** — studio 本地可完成。
Phase 2b 的 mlx 上游改动和 Phase 4 通过提 issue 推进。

实施顺序：
1. `ChatPreset` 枚举 + 改造快捷按钮为真正预置 Prompt
2. `AttachmentData` 数据模型 + 截图功能
3. `+` 菜单完整化（Add files + Screenshot + Web Search toggle + Use style）
4. 文件选择 + 附件 UI（输入框上方附件条）
5. 向上游提 issue（fusion-mlx multimodal + web_search, fusion-code project 关联）
