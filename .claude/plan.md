// Callers: Plan mode exit, user review.
// Affected API: ChatSessionStore.sendMessage (project injection), UnifiedChatView.inputToolbar (+ menu), FusionSkillManager (new).
// Data schemas: FusionSkill, FusionSkillManager, ChatMode.research, OutputStyle in + menu.
// User instruction: "这个里面还有很多能力没有落地，你逐一排查，需要全面对标落地，对上下游有问题和需求就提issue和pr"

# PRD 对标落地计划（对标 claude-studio-prd.md）

## 差距分析

| 层级 | PRD 功能 | 当前状态 | 行动 |
|------|---------|---------|------|
| L1 | Code/Write/Create/Learn/Life 快捷按钮 | ✅ ChatPreset + UI 已有 | 无需修改 |
| L2 | Add files or photos | ✅ pickFiles() 已有 | 无需修改 |
| L2 | Take a screenshot | ✅ 已修复时序 | 无需修改 |
| L2 | Add to project | ⚠️ UI 有入口但 sendMessage 不注入 project 指令/知识 | **修复** |
| L2 | Skills | ❌ 不存在 | **新建** |
| L2 | Add connectors | ❌ 不存在 | **降级** — 国内网络限制，提 issue |
| L2 | Research | ❌ 不存在 | **新建** |
| L2 | Web search | ✅ toggle 已有 | 验证上游，不支持的提 issue |
| L2 | Use style | ⚠️ OutputStyle 有但入口不在 + 菜单 | **移入 + 菜单** |
| L3 | Project 持久知识库 | ⚠️ 数据模型完整但发送不注入 | **修复**（同 L2 project） |
| L4 | Skills 可复用 Agent | ❌ 不存在 | 同 L2 Skills |
| L4 | Connectors 云集成 | ❌ 不存在 | 降级，提 issue |

## 实施项

### 1. Project 指令+知识注入 sendMessage
- `ChatSessionStore.sendMessage` 构建 systemParts 时检查 `updated.projectId`
- 查找 `FusionProjectManager.shared.projects` 对应 project
- 注入 `project.customInstructions` 作为 system prompt
- 注入 `project.knowledgeFiles` 摘要（读文件内容前 8000 字符）
- 同步修 `resendAfterEdit`
- 文件: `ChatSessionStore.swift`

### 2. Use style 移入 + 菜单
- 当前 OutputStyle 在 toolbar 上独立 button，移入 + Menu
- 在 + Menu 的 Web search Divider 后加 Use style 子菜单
- toolbar 上保留 active style 小 indicator
- 文件: `UnifiedChatView.swift`

### 3. Skills 本地模板系统
- 新建 `FusionSkill` 模型: name, description, systemPrompt, icon, isBuiltin
- 新建 `FusionSkillManager`: CRUD + 持久化 `~/.fusion-studio/skills/`
- 预置内置 skill: 代码审查、周报生成、翻译、文档转换
- + 菜单加 Skills 子菜单
- 选中 skill 注入 systemPrompt 到当前会话（类似 ChatPreset 但可自定义）
- 文件: 新建 `FusionStudio/Common/FusionSkill.swift`, 修改 `UnifiedChatView.swift`, `ChatSessionStore.swift`

### 4. Research 深度研究模式
- 新增 ChatMode `.research`
- 实现多轮搜索逻辑: 拆分问题 → 多次调用 inferStream+web_search → 汇总
- UI: + 菜单加 Research toggle（类似 Web search）
- 依赖 MLX web_search 能力，需验证上游
- 文件: `ChatSessionStore.swift`, `UnifiedChatView.swift`, `AgentBridge.swift`

### 5. 上游 issue
- fusion-mlx: web_search 参数是否生效
- fusion-mlx: Research 多轮搜索支持
- fusion-mlx: 第三方连接器规划
