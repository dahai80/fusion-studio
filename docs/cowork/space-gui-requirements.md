# Fusion-Cowork 协作空间 GUI 需求规格

> 来源: fusion-cowork V1.0 增强方案 (`~/fusion/architecture/fusion-cowork-enhance.md`)
> 优先级: P0 — M6-M12 里程碑逐步交付

## 1. SpaceView — 协作空间首页

### 功能

- 空间列表（活跃/已归档）
- 新建空间弹窗（名称、描述、知识库绑定、协作模式、Agent 预选）
- 局域网在线状态指示
- 快速操作：进入空间、创建快照、管理成员

### 布局

```
顶部导航: Agent工作室 | CoWork协作空间 | 知识库 | 设置
工具栏: +新建空间 | 搜索 | 筛选(全部/我创建的/我参与的/已归档/局域网在线)
卡片列表: 每个空间一张卡片，显示名称/所有者/成员数/知识库/Agent/局域网状态
```

### IPC 依赖

- `desk.space.list` — 获取空间列表
- `desk.space.create` — 创建空间
- `desk.space.get` — 获取空间详情
- `desk.space.archive` — 归档/恢复空间
- `desk.space.discovery.scan` — 局域网扫描

---

## 2. SpaceChatView — 共享对话视图

### 功能

- 共享对话消息流（多成员 + Agent 消息混排）
- 流式 AI 回复（Agent 推理实时输出）
- 消息附件（共享文件、临时附件、截图）
- 批注线程弹出面板
- Agent 切换、模式切换（对话/工作流/Computer Use）

### 布局

```
左栏: 成员列表 + 共享文件 + Agent列表 + 桌面共享 + 设置
中央: 对话消息流
底部: Agent选择 + 模式切换 + 附件菜单 + 输入框
```

### IPC 依赖

- `desk.space.chat.send` — 发送消息
- `desk.space.chat.history` — 获取历史
- `desk.space.chat.stream` — 订阅流式回复
- `desk.space.comment.create` — 创建批注
- `desk.space.comment.list` — 获取批注

---

## 3. SpaceMemberView — 成员管理面板

### 功能

- 成员列表（角色、在线状态、最后活跃时间）
- 邀请成员（本地账号/邀请链接/局域网发现）
- 角色修改（Owner/Admin/Member/Viewer）
- 移除成员
- 邀请链接生成与管理

### 布局

```
工具栏: +邀请成员 | 生成邀请链接 | 局域网发现
成员列表: 头像 + 名称 + 角色徽章 + 在线指示 + 操作(修改权限/移除)
邀请区: 本地账号输入 | 邀请链接 | 局域网扫描结果
```

### IPC 依赖

- `desk.space.member.list` — 成员列表
- `desk.space.member.invite` — 邀请成员
- `desk.space.member.remove` — 移除成员
- `desk.space.member.update_role` — 修改角色
- `desk.space.discovery.scan` — 局域网发现

---

## 4. SpaceAgentView — Agent 管理面板

### 功能

- 已添加至空间的 Agent 列表
- 搜索组织内已发布 Agent（来源：Agent Studio）
- 添加/移除 Agent
- Agent 调用权限设置（所有成员 / 仅管理员）
- Agent 执行位置指示（本地 fusion-mlx / 云端 gateway）

### 布局

```
上半: 已添加Agent列表（名称+权限+来源+移除按钮）
下半: 搜索可用Agent（搜索框+结果列表+添加按钮）
```

### IPC 依赖

- `desk.space.agent.list` — 空间 Agent 列表
- `desk.space.agent.add` — 添加 Agent
- `desk.space.agent.remove` — 移除 Agent

---

## 5. SpaceSnapshotView — 快照管理面板

### 功能

- 快照列表（名称、时间、内容统计）
- 创建快照
- 基于快照克隆新空间
- 删除快照
- 查看快照内容

### 布局

```
工具栏: +创建新快照
快照卡片列表: 名称+时间+统计(消息/文档/Agent数)+操作(克隆/查看/删除)
克隆策略说明
```

### IPC 依赖

- `desk.space.snapshot.create` — 创建快照
- `desk.space.snapshot.list` — 快照列表
- `desk.space.snapshot.clone` — 克隆空间

---

## 6. IPCClient 扩展

### 新增方法

需要在 `FusionStudio/Bridge/IPCClient.swift` 中新增以下方法调用：

```swift
// 空间管理
func spaceList() async throws -> [Space]
func spaceCreate(name: String, description: String?, kbBindMode: String, collabMode: String) async throws -> Space
func spaceGet(spaceId: String) async throws -> Space
func spaceUpdate(spaceId: String, config: SpaceConfig) async throws -> Space
func spaceArchive(spaceId: String, archive: Bool) async throws -> Space

// 成员管理
func spaceMemberList(spaceId: String) async throws -> [SpaceMember]
func spaceMemberInvite(spaceId: String, userId: String, role: String) async throws -> SpaceMember
func spaceMemberRemove(spaceId: String, userId: String) async throws -> Void
func spaceMemberUpdateRole(spaceId: String, userId: String, role: String) async throws -> Void

// 对话
func spaceChatSend(spaceId: String, content: String, agentId: String?) async throws -> SpaceMessage
func spaceChatHistory(spaceId: String, limit: Int) async throws -> [SpaceMessage]
func spaceChatStream(spaceId: String) -> AsyncThrowingStream<String, Error>

// Agent
func spaceAgentList(spaceId: String) async throws -> [SpaceAgent]
func spaceAgentAdd(spaceId: String, agentId: String, permission: String) async throws -> SpaceAgent
func spaceAgentRemove(spaceId: String, agentId: String) async throws -> Void

// 快照
func spaceSnapshotCreate(spaceId: String, name: String) async throws -> SpaceSnapshot
func spaceSnapshotList(spaceId: String) async throws -> [SpaceSnapshot]
func spaceSnapshotClone(snapshotId: String, name: String) async throws -> Space

// 批注
func spaceCommentCreate(spaceId: String, messageId: String, content: String) async throws -> SpaceComment
func spaceCommentList(spaceId: String, messageId: String) async throws -> [SpaceComment]

// 局域网发现
func spaceDiscoveryScan() async throws -> [PeerInfo]
```

---

## 交付计划

| 组件 | 里程碑 | 对应 fusion-cowork 版本 |
|------|--------|------------------------|
| SpaceView | M6 | V0.7 |
| SpaceMemberView | M6 | V0.7 |
| SpaceChatView | M7 | V0.8 |
| SpaceAgentView | M8 | V0.9 |
| SpaceSnapshotView | M9 | V0.10 |
| IPCClient 扩展 | M6+ | V0.7+ |

每个组件先实现基础版，随里程碑迭代增强。
