# F-I12 — 成熟库评估 (Batch 17e)

> 审计 0825 F-I12 (`~/fusion/audit/fusion-studio-audit-report-0825.md` L516-524): "零 Swift 外部依赖自认优势, 实则 reinvent 轮子 + 难审计"。3 月债: "评估引入成熟库 (IPC/JSON/Markdown), 至少安全关键组件"。
>
> 本文档 = 评估交付件 (非代码改动)。评估结论 + 推荐决策, 落地与否待用户审批。

## 评估结论 (TL;DR)

**审计 F-I12 前提部分不成立。** 3 类 "reinvent 轮子" 实地复核:

| 轮子 | LOC | 实地实现 | 审计判断 | 复核结论 |
|------|-----|---------|---------|---------|
| IPCClient | 566 | 手写 UDS + 换行分帧 + JSON-RPC envelope | reinvent 轮子 | **部分成立** — 仅分帧循环手写, JSON 走 Foundation `JSONSerialization`, 非手写解析 |
| FileWatcher | 214 | 包装 Apple CoreServices `FSEventStreamCreate` | reinvent 轮子 | **不成立** — 薄封装成熟 Apple API, 非 reinvent |
| Markdown | — | Foundation `AttributedString(markdown:)` (CommonMark, macOS 12+) | reinvent 轮子 | **不成立** — Apple 原生 CommonMark, 非 reinvent |

**推荐: 不引入外部依赖。** 维持零依赖现状。理由:

1. 2/3 "轮子" 已是 Apple 原生成熟 API (FSEventStream / AttributedString), 无 reinvent 可言。
2. 唯一手写部分 (IPCClient 分帧循环) 已有健壮性加固 (PERF-1/2 块读+原子 id, F-R4 去重, F-R5 malformed 帧日志, F-A4 pending cap, F-A16 schema 协商, 8s 超时续体兜底), 且成熟库候选无明确更优解:
   - `swift-nio` (2.101.3, apple, 活跃) — 异步网络框架, 面向 server, 引单 UDS client 重武器打蚊, 拉入 NIO/NIOCore/NIOFoundationCompat 多模块依赖, 违零依赖设计且收益边际。
   - `ChimeHQ/JSONRPC` (42★, LSP 场景) — LSP-oriented, 非通用 RPC, star 低, 非安全关键审计级库。
   - `bricklife/JSONRPCKit` (175★, 2020 最后提交) — **已停维 5+ 年**, 无 CVE 跟踪, 引入反而负收益 (审计核心论点反噬)。
   - `swift-markdown` (apple, cmark-gfm) — 若 Markdown 已用 Foundation AttributedString, 无需; 仅需完整 AST 解析 (本仓无此需求) 时才考虑。
3. **"零依赖" 对本仓是正资产非负收益**: 单机桌面客户端, 无供应链攻击面 (无第三方代码执行), 无 transitive dep 冲突, build 可重现, 0 依赖审计成本。审计论点 "为零依赖 reinvent 安全轮子是负收益" 在 2/3 不成立 (非 reinvent) + 1/3 无更优成熟库的前提下, 不成立。

**唯一可后续改进 (非引入依赖)**: IPCClient 分帧循环的边角 case 加针对性测试 (F-I5 已铺 19 集成测试, 可补畸形帧 fuzz), 把 "靠自审" 补成 "靠测试"。属 F-I5 范畴, 非 F-I12 引库。

## 1. 审计前提复核

审计 F-I12 原文 (L516-524) 核心 3 论点:

1. "自己实现 IPC 帧 (IPCClient)、自己实现 JSON-RPC、自己实现文件监听 (FileWatcher)、自己实现 Markdown 渲染" — 4 项 reinvent。
2. "这些轮子质量不如成熟库, 无社区审计, 无 CVE 跟踪, 无测试覆盖" — 质量论。
3. "对比用成熟库 (如 Starscream/Swifter) 有社区安全审计" — 成熟库对比。

**复核方法**: 逐项读源码 (非据审计描述), 确认实际实现是否 reinvent (自研解析逻辑) vs 薄封装成熟 API (调 Apple framework)。成熟库候选查 GitHub API release/tag/push 时间验活跃度。

**复核发现**:
- 论点 1: 4 项中 **2 项 (FileWatcher/Markdown) 非 reinvent** (Apple framework 薄封装/原生), 1 项 (IPCClient) 部分手写 (分帧), JSON-RPC envelope 本身是 `JSONSerialization` 序列化 dict 非手写协议栈。审计描述与实地不符。
- 论点 2: IPCClient 已有测试覆盖 (F-I5 PR#329 19 集成测试 + MockIPCClient), 边角 case 有针对性加固 (PERF-1/2, F-R4/R5, F-A4/A16, 8s 超时)。"无测试覆盖" 在 IPC 维度已被 F-I5 部分推翻 (审计 0825 基线是 F-I5 之前)。FileWatcher/Markdown 属 Apple API 调用, 测试责任在 Apple 不在仓内。
- 论点 3: 举的对比库 (Starscream WebSocket / Swifter HTTP) 与本仓场景 (UDS + JSON-RPC, 非 WebSocket/HTTP) 不匹配 — 举例失焦。实际 JSON-RPC Swift 库生态见 §3.1, 无明确更优解。

**结论**: 审计 F-I12 触发评估的动作正确 (零依赖应被审视), 但具体论据 2/3 不成立。评估照做 (本文档), 但推荐 "不引入" 而非审计暗示的 "引入"。

## 2. 轮子盘点 (3 类)

实地读源码, 拆 "手写部分" vs "调成熟 API 部分"。

### 2.1 IPCClient (566 LOC)

**文件**: `FusionStudio/Bridge/IPCClient.swift` (+ 9 IPC*Methods.swift 共 3953 LOC, 但那些是 method 命名空间封装, 非协议逻辑)。

**手写部分** (reinvent 候选):
- UDS 连接: `socket(AF_UNIX, SOCK_STREAM)` + `sockaddr_un` + `Darwin.connect` (L61-90)。低层 POSIX, Swift 无官方 UDS 客户端 API, 此为常规手法。
- 换行分帧 (newline-delimited): `writeBuf.append(0x0A)` (L247/302), 读循环 `0x0A` 切分 (L352-360)。非长度前缀帧, 是与上游 daemon 协商的协议 (daemon 也按换行分帧), 换库无法改协议。
- 续体管理: `pendingRequests: [Int: CheckedContinuation]` + 8s 超时 resume (L232-243) + F-R4 in-flight 去重 + F-A4 pending cap 100。并发逻辑, 非协议逻辑。

**非手写部分** (调成熟 API):
- JSON 序列化/解析: `JSONSerialization.data(withJSONObject:)` / `JSONSerialization.jsonObject(with:)` (L297/319/33)。Foundation, 非手写。
- JSON-RPC envelope: 拼 `[String:Any]` dict (`"jsonrpc":"2.0", "id", "method", "params"`) 再序列化。envelope 是 4 个 key 的 dict, 非 "实现 JSON-RPC 协议栈"; 任何库调法都是拼这 4 字段。
- 错误归一化: `json["error"]`/`json["result"]` 下标 + type switch (L324-338, handleResponse L61+)。dict 访问, 非解析器。

**已有健壮性加固** (审计基线 0825 之前/之后):
- PERF-1/2 (PR#276): 4KB 块读替单字节 read + `nextRequestId()` 原子 id 锁保护。
- F-R4 (PR#299): 方法级 in-flight 读去重 (幂等读合并, 变更类不合并)。
- F-R5 (PR#295): malformed 帧日志 (非 try? 静默丢), `handleResponse` L33/41/45/53 四 guard + error 日志。
- F-A4: pending 容量 cap 100 防续体 OOM。
- F-A16 (PR#317): connect 后 `rpc.discover` 缓存 method 集, `schemaCompatible` 标志暴露 schema 漂移。
- 8s 超时 (L232): 续体不泄露, daemon 不回包时 fast-fail。

**测试覆盖**: F-I5 (PR#329) 19 集成测试 + `MockIPCClient` (override connect no-op + call 记 args返 canned)。覆盖 agent/graph/planner/task/error/parser edge。审计基线 "184 用例" 已在 F-I5 后升至 215+。

**判断**: 分帧循环手写, 但 (a) 是与上游协议绑定的换行帧非通用可替换层, (b) 已有 6 项针对性加固 + 测试。**部分 reinvent, 但非 "无审计裸奔"。**

### 2.2 FileWatcher (214 LOC)

**文件**: `FusionStudio/System/FileWatcher.swift`。

**实现**: 包装 Apple CoreServices `FSEventStreamCreate` (L119) + `FSEventStreamScheduleWithRunLoop` (L132) + `FSEventStreamStart` (L133)。回调 `FSEventStreamCallback` (L39-44) 转 `[FileEvent]`。stop 时 `FSEventStreamStop/Invalidate/Release` (L173-175)。

**手写部分**: 0 解析逻辑, 0 事件算法。纯 Apple C API 包装 + Swift 友好类型 (`FileEvent` struct, `[FileEvent]` 数组, `ObservableObject` Combine 集成)。

**判断**: **非 reinvent。** Apple FSEventStream 是 macOS 文件监听官方 API (Finder/Time Machine/Xcode 同源), 本身成熟 + Apple 审计 + CVE 跟踪。薄封装 214 LOC = 惯常 Swift wrapping 手法 (Swift 不能直接用 C callback 上下文, 须包装层)。引入第三方文件监听库 = 再包一层 FSEventStream, 负收益。

### 2.3 Markdown 渲染

**位置**: `FusionStudio/Components/UnifiedChatView.swift:888`, `FusionStudio/Modules/Design/DesignChatPanel.swift:653`。

**实现**: Foundation `AttributedString(markdown:options:)` + `AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)`。Apple 原生 CommonMark 解析 (macOS 12+ / iOS 15+ 内置), 非 "自己实现 Markdown 渲染"。

**手写部分**: 仅 `renderArtifactRefs` (UnifiedChatView:1240) — `NSRegularExpression` 替换 `[[artifact:xxx]]` 引用为 Markdown 链接。是业务标记语法 (非 Markdown 标准), 任何库都不覆盖, 须自写。

**判断**: **非 reinvert。** Apple `AttributedString(markdown:)` 底层是 cmark-gfm (Apple 维护, swift-markdown 同源)。审计 "自己实现 Markdown 渲染" 与实地不符 — 仓内用 Apple 原生, 唯一手写是业务 artifact-ref 正则。

## 3. 成熟库候选评估

GitHub API 实查活跃度 (2026-08-27 取数)。

### 3.1 JSON-RPC / IPC 候选

| 库 | star | 最后活跃 | 判断 |
|----|------|---------|------|
| `apple/swift-nio` | — | 2.101.3 (2026-07-15) | 异步事件驱动网络框架, 面向 server (HTTP/2/gRPC)。引单 UDS 客户端 = 拉入 NIO/NIOCore/NIOFoundationCompat 多模块 + `EventLoopFuture` 并发模型重写续体管理。**重武器打蚊**, 违零依赖设计, 收益边际 (现有续体管理已健壮)。 |
| `ChimeHQ/JSONRPC` | 42 | 2025-05-08 | LSP (Language Server Protocol) 场景 JSON-RPC, 非通用。LSP-oriented 假设 (消息传输层 stream framing, LSP 语义), 与本仓 UDS + 业务 RPC 不完全匹配。star 低, 非 CVE 审计级库。 |
| `bricklife/JSONRPCKit` | 175 | **2020-08-29 (5+ 年停维)** | 已停维。审计核心论点 "成熟库有 CVE 跟踪" 此库反噬 — 停维库 0 CVE 跟踪, 引入 = 负收益。 |
| `web3swift-team/web3swift` | 890 | 2025-09-24 | Ethereum/区块链场景 JSON-RPC, 非 IPC。场景不符。 |
| `kolyasev/SwiftJSONRPC` | 21 | 2022-07-11 | 低 star, 3+ 年低活跃。 |

**结论 (3.1)**: 无明确更优解。swift-nio 活跃但 over-engineered; JSONRPCKit 停维; 余者低 star/场景不符。现有 IPCClient 手写分帧 + Foundation JSON + 6 项加固 + 19 测试, 比引上述任一库更可控。

### 3.2 Markdown 候选

| 库 | star | 最后活跃 | 判断 |
|----|------|---------|------|
| `apple/swift-markdown` | — | Apple 官方, cmark-gfm wrapper | 提供 Block/Document AST 解析 (Markdown 语法树)。本仓需求 = UI 显示 (AttributedString), 非 AST 操作。AttributedString(markdown:) 已满足, 无需 AST。仅当需遍历/变换 Markdown 结构 (本仓无) 才引。 |
| Foundation `AttributedString(markdown:)` | — | Apple 内置 (macOS 12+) | **现用**。Apple 原生 CommonMark, 0 依赖, 0 额外审计面。 |

**结论 (3.2)**: 现用 Apple 原生已是最优。swift-markdown 同源 cmark-gfm, 引入仅换 API 形态不换解析内核, 负收益 (多一依赖, 同解析器)。

### 3.3 文件监听候选

| 库 | star | 最后活跃 | 判断 |
|----|------|---------|------|
| (无成熟独立库) | — | — | GitHub 搜 "swift file watcher fsevents" 仅返 0-★ hobby 项目 (Sidewatch/swift-file-tools 等)。**无成熟独立 Swift 文件监听库** — 业界共识: 直接调 CoreServices FSEventStream (本仓现做法)。 |

**结论 (3.3)**: 无候选。FSEventStream 是 macOS 唯一成熟文件监听 API, 所有人薄封装它 (含本仓)。引入第三方 = 再包一层, 负收益。

## 4. 推荐决策

**决策: 不引入外部 Swift 依赖。维持零依赖现状。**

理由汇总:
1. **2/3 "轮子" 非 reinvent**: FileWatcher = FSEventStream 薄封装, Markdown = AttributedString 原生。审计论据与实地不符。
2. **1/3 (IPCClient) 无更优成熟库**: JSON-RPC Swift 生态碎片 (停维/低 star/场景不符), swift-nio over-engineered。
3. **零依赖是本仓正资产**: 单机桌面客户端, 0 供应链攻击面, 0 transitive 冲突, build 可重现, 0 依赖审计成本。审计 "零依赖负收益" 论点在 reinvent 不成立前提下不成立。
4. **IPCClient 已非 "裸奔"**: 6 项健壮性加固 + 19 集成测试 (F-I5) + MockIPCClient。审计基线 "无测试覆盖" 已被 F-I5 推翻。

**后续改进 (非 F-I12, 归 F-I5 范畴)**:
- IPCClient 分帧循环补畸形帧 fuzz 测试 (半包/超大包/无换行/非 UTF-8/中断 read)。扩 MockIPCClient 让 socket fd 喂构造字节流。属测试覆盖深化, 非引库。

## 5. 风险与成本

| 维度 | 引入依赖 (反例) | 维持零依赖 (推荐) |
|------|---------------|-----------------|
| 供应链攻击 | 第三方代码执行面 (build 时拉源, 依赖维护者可信度) | 0 (无第三方代码) |
| CVE 跟踪 | 依赖上游响应速度 (JSONRPCKit 停维 = 0 响应) | N/A (Apple framework CVE 由 Apple 跟踪) |
| build 可重现 | transitive dep 版本漂移, lock 文件维护成本 | 0 (Package.swift `dependencies: []`) |
| 审计成本 | 第三方代码须纳入审计范围 | 0 (仅审仓内) |
| 协议匹配 | swift-nio 异步模型须重写续体 (改造大) | 现有续体管理已健壮 |
| 实际收益 | 2/3 无 reinvent 可替换; 1/3 无更优库 | — |

**维持零依赖的风险**: IPCClient 分帧循环边角 case 靠自审 + 测试 (非社区审计)。**缓解**: F-I5 测试深化 + F-R5 malformed 帧日志已部署。此风险可接受 (单机客户端, daemon 同源可信, 非 internet-facing)。

## 关联

- 审计: `~/fusion/audit/fusion-studio-audit-report-0825.md` F-I12 (L516-524)
- 5 重大重构进度: F-I4✓ PR#328 + F-I5✓ PR#329 + F-I7✓ PR#330 + F-I11✓ PR#331 + **F-I12 本评估 (非代码, 决策: 不引库)**
- 相关加固: PERF-1/2 PR#276 (IPCClient 块读+原子 id) / F-R4 PR#299 (去重) / F-R5 PR#295 (malformed 日志) / F-A16 PR#317 (schema 协商) / F-I5 PR#329 (集成测试)
- 下版 v0.1.49 含 (本评估为文档, 无代码改动, 不影响 build)
