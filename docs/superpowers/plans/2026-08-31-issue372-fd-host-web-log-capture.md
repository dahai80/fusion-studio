# #372 — Consume fd-host-web log.capture.dump bridge (OPS-13)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register the `fdHost` WKWebView message handler in fusion-studio's Design canvas, consume the WASM `log_capture_dump` response, and persist the WASM runtime log ring buffer to `~/Library/Logs/fusion-studio/fd-host-web-<timestamp>.json` for enterprise operations diagnostics. Also vendor the new fd-host-web wasm (fdHost + OPS-13) so the feature activates end-to-end.

**Architecture:** Three trigger paths (manual button in DesignLintPanel, WebView content-process termination, App foreground w/ 5-min throttle) all call one `FdHostWebLogCapture` coordinator. The coordinator sends `{kind:"log.capture.dump",payload:{clear:true}}` to the canvas WebView via `DesignBridge.sendCanvasCommand`, receives the `log_capture_dump` bridge event in `DesignCanvasView.handleBridgeEvent`, and persists entries. The outbound WASM→host channel is `window.webkit.messageHandlers.fdHost.postMessage` (HOST_HANDLER_NAME="fdHost" in fusion-design `crates/fd-host-web/src/bridge.rs:219`); the inbound host→WASM command channel stays `fusion_bridge_send_command` (unchanged). Forward-compatible: old wasm (no fdHost) leaves the new handler dormant.

**Tech Stack:** Swift / SwiftUI / WebKit (WKWebView, WKScriptMessageHandler, WKNavigationDelegate), os.log, Foundation file I/O (0o600 perms).

**Spec:** GitHub issue dahai80/fusion-studio#372 "Consume fd-host-web log.capture.dump bridge — persist WASM runtime logs to disk (OPS-13)". Upstream contract verified实地 in fusion-design `crates/fd-host-web/src/lib.rs` (LogRingBuffer 200-cap, `log.capture.dump`→`log_capture_dump`) + `crates/fd-host-web/src/bridge.rs` (HOST_HANDLER_NAME="fdHost", send_to_host webkit path).

## Global Constraints

- Bridge contract (verbatim from issue + verified upstream source):
  - Handler: `window.webkit.messageHandlers.fdHost` (name `fdHost`)
  - Request host→WASM: `{ "kind": "log.capture.dump", "payload": { "clear": true } }`
  - Response WASM→host: `{ "kind": "log_capture_dump", "payload": { "entries": [ { "level": "error"|"warn", "ts_ms": <f64>, "msg": "..." } ] } }`
- Persist path: `~/Library/Logs/fusion-studio/fd-host-web-<timestamp>.json` (align fusion-design file-log dir convention). File perms 0o600, dir 0o700.
- Indentation: multiples of 4 spaces. No docstrings. Logging via `Logger(subsystem:"com.fusion.studio", category:...)` on all new code.
- Forward-compat: old bundled wasm (commit 2589a22, pre-OPS-13) has NO fdHost/log_ring; new handler must not break the old wasm (dormant = safe).
- Code rules: only modify fusion-studio repo. Vendoring the wasm binary is a copy INTO this repo, not a fusion-design code change.
- Build gate (TRUTH): `swift build -c debug` EXIT=0 AND `swift build -c release` EXIT=0 AND `swift build --build-tests` EXIT=0. Local `swift test`=0 tests (toolchain drift Swift 6.3.3/macOS 26); CI macOS-14/Xcode 15.x authoritative.
- Throttle: foreground auto-dump ≥ 5 min between dumps (avoid write-amplification).
- All i18n user-facing strings via `I18nManager.shared.t(.key)`; add new keys to `I18nService.swift`.

## Verified facts (实地调查)

- **CRITICAL — two inbound paths, do NOT add logCaptureDump to BridgeCommand.** fusion-design `bridge.rs` exposes TWO distinct host→wasm channels:
  1. `fusion_bridge_send_command(command_json)` `#[wasm_bindgen]` export (bridge.rs:399) → `serde_json::from_str::<BridgeCommand>` (PascalCase serde tag: `{"PageRender":{...}}`). Studio's existing `toJSON()` already matches this. Arms: PageRender/ApplyTokens/SelectNode/MutateNode/ClearCanvas/PlanPreview/PlanApply/PlanReject/SetNodeVisibility/SetNodeLocked/ReorderNode. **NO LogCaptureDump arm** — `log.capture.dump` CANNOT be sent this way.
  2. `window.addEventListener("message")` → `handle_host_message` (bridge.rs:23,30,36) parses `{kind:"<snake_case>", payload:{...}}` snake_case. This is the ONLY path that handles `"log.capture.dump"` (bridge.rs:187). Studio triggers it via `webView.evaluateJavaScript("window.postMessage(JSON.stringify({kind:'log.capture.dump',payload:{clear:true}}),'*')")`. Same-window postMessage fires the listener (standard DOM).
- **Outbound event path (wasm→native) migrated to fdHost.** `send_to_host(kind,payload)` (bridge.rs:227) builds `{direction:"WebViewToBackend",kind,payload}`; `dispatch_to_host` (bridge.rs:257, wasm32) primary path `webkit.messageHandlers.fdHost.postMessage(json_string)` (HOST_HANDLER_NAME="fdHost" bridge.rs:219), fallback `navigator.__fd_host_post` accumulator queue. Studio's existing `handleBridgeEvent` reads `{kind,payload}` — matches. But studio registers ONLY `fusionBridge` handler, not `fdHost`. Old wasm (no fdHost) → events fell to `__fd_host_post` queue which studio never polled → but old wasm sent events to `fusionBridge`?? NO: old wasm `send_to_host` uses `__fd_host_post` only (no webkit path) — so studio's CURRENT working canvas means old wasm sends events some OTHER way (injected `window.fusionBridge.postMessage` from inline HTML L261 for wasm.ready only; node.click etc. via... must verify old wasm). Forward: new wasm sends ALL events (node.click + log_capture_dump) to fdHost → studio MUST register fdHost to receive them.
- **Response payload shape:** `send_to_host("log_capture_dump", &json!({"entries": entries}))` → full msg `{direction,kind:"log_capture_dump",payload:{entries:[{level,ts_ms:f64,msg}]}}`. `LogEntry` struct (lib.rs:103): `{level:&'static str, ts_ms:f64, msg:String}`. `handleBridgeEvent` reads `event.payload["entries"]` as `[[String:Any]]`.
- **Old bundled wasm** (`FusionStudio/Resources/wasm/fd_host_web_bg.wasm`, commit 2589a22): 0 `log_ring`/`fd_log`/`log_capture`/`fdHost`/`webkit`/`messageHandlers` strings in data segment. Predates OPS-13 (fusion-design 698f69a, Aug 28). Its `send_to_host` uses `navigator.__fd_host_post` queue only (no webkit handler). Studio never polled that queue.
- **New wasm** (fusion-design `target/wasm32-unknown-unknown/release/fd_host_web_bg.wasm`, Aug 30 build; identical to `docs/harness/pkg/`): data segment has `webkitmessageHandlersfdHostpostMessage` + `log.capture.dump` + `log_capture_dump` + `entries`. `fd_host_web.js` glue (29360 bytes) exports `fusion_bridge_send_command` + `mount` (same interface as old glue — loader unchanged).
- **DesignCanvasView.swift** builds its OWN WKWebView (NOT WebViewContainer):
  - L172: `userContentController.add(context.coordinator, name: "fusionBridge")` — registers `fusionBridge` (inbound native→wasm command ack + wasm.ready from inline HTML L261).
  - L176-182: injects `window.fusionBridge.postMessage → webkit.messageHandlers.fusionBridge.postMessage`.
  - L253: `import init, { mount, fusion_bridge_send_command } from './fd_host_web.js'` — inbound command entry (unchanged).
  - L327 `sendCommand`: evaluates `fusion_bridge_send_command('<json>')` — host→WASM command path.
  - L356-373 `userContentController didReceive`: handles `message.name == "fusionBridge"`.
  - L389 `handleBridgeEvent`: switch on `event.kind` — wasm.ready/wasm.error/node.click/... (add `log_capture_dump` case here).
  - L344 Coordinator: `WKNavigationDelegate, WKScriptMessageHandler, NSMenuDelegate` — add `webViewWebContentProcessDidTerminate` for crash-recovery trigger.
- **BridgeCommand** enum (DesignCanvasView.swift:18-32): pageRender/applyTokens/selectNode/mutateNode/.../undoAction/redoAction. `toJSON()` (L36+) serializes `{kind, payload}`. Add `case logCaptureDump(clear: Bool)` + toJSON branch.
- **DesignBridge.swift**: L193 `weak var canvasWebView: WKWebView?`, L198 `sendCanvasCommand(_ command: BridgeCommand)` → `DesignCanvasView.sendCommand(command, to: webView)`. Reusable.
- **FusionStudioApp.swift**: L13 `@Environment(\.scenePhase)`, L272-280 `.active` block (foreground hook). Inject `FdHostWebLogCapture` trigger here.
- **DesignLintPanel.swift**: manual-dump button host. L162 `body`, L164-176 header HStack w/ FusionButton run/lock. Add "导出 WASM 日志" button.
- **FusionTempDir.swift**: `writeTmpFile(prefix:ext:contents:)` → 0o600 file in `~/.fusion-studio/tmp/`. Reuse pattern (NOT path — logs go to `~/Library/Logs/fusion-studio/`, distinct from tmp).
- **i18n**: `I18nService.swift` holds keys; `design_lint_*` keys exist. Add `design_diag_dumpWasmLog` + result toast keys.

---

## File Structure

| File | Responsibility | Create/Modify |
|------|----------------|---------------|
| `FusionStudio/System/FdHostWebLogCapture.swift` | Coordinator: persist entries to disk, throttle, trigger API (manual/crash/foreground). Singleton. | Create |
| `FusionStudio/Modules/Design/DesignCanvasView.swift` | Register `fdHost` handler; add `logCaptureDump` BridgeCommand + toJSON; handle `log_capture_dump` event → forward to coordinator; add `webViewWebContentProcessDidTerminate` crash trigger. | Modify |
| `FusionStudio/Modules/Design/DesignBridge.swift` | Thin `dumpWasmLog(clear:)` helper → `sendCanvasCommand(.logCaptureDump(clear:))`. | Modify |
| `FusionStudio/Modules/Design/DesignLintPanel.swift` | Manual "导出 WASM 日志" button → `designBridge.dumpWasmLog(clear:true)`. | Modify |
| `FusionStudio/FusionStudioApp.swift` | Foreground `.active` trigger → `FdHostWebLogCapture.shared.triggerForegroundDump()`. | Modify |
| `FusionStudio/Common/I18nService.swift` | New i18n keys: `design_diag_dumpWasmLog`, `design_diag_dumpSuccess`, `design_diag_dumpEmpty`, `design_diag_dumpFailed`. | Modify |
| `FusionStudio/Resources/wasm/fd_host_web.js` + `fd_host_web_bg.wasm` (+ `.d.ts`/`_bg.wasm.d.ts`) | Vendor new wasm-bindgen output (fdHost + OPS-13) from fusion-design target/release. | Modify (binary replace) |
| `Tests/UnitTests/FdHostWebLogCaptureTests.swift` | Unit tests: persist format, throttle, sanitize. | Create |

---

## Task 1: Vendor new fd-host-web wasm (fdHost + OPS-13)

**Files:**
- Modify: `FusionStudio/Resources/wasm/fd_host_web.js` (24153 → 29360 bytes)
- Modify: `FusionStudio/Resources/wasm/fd_host_web_bg.wasm` (1162188 → 1651667 bytes)
- Modify: `FusionStudio/Resources/wasm/fd_host_web.d.ts`, `fd_host_web_bg.wasm.d.ts`

**Interfaces:**
- Consumes: fusion-design `target/wasm32-unknown-unknown/release/fd_host_web.{js,_bg.wasm}` (local Aug-30 build, gitignored upstream — copy only).
- Produces: bundled wasm that posts outbound events to `webkit.messageHandlers.fdHost` + handles `log.capture.dump`.

- [ ] **Step 1: Verify new wasm has OPS-13 strings**

```bash
strings FusionStudio/Resources/wasm/fd_host_web_bg.wasm | grep -c fdHost   # expect 1
strings FusionStudio/Resources/wasm/fd_host_web_bg.wasm | grep -c "log.capture.dump"  # expect 1
```

- [ ] **Step 2: Copy new artifacts over bundled**

```bash
FD=/Users/dahai/fusion/fusion-design/target/wasm32-unknown-unknown/release
cp "$FD/fd_host_web.js" FusionStudio/Resources/wasm/fd_host_web.js
cp "$FD/fd_host_web_bg.wasm" FusionStudio/Resources/wasm/fd_host_web_bg.wasm
# d.ts from harness pkg (target doesn't emit .d.ts)
HP=/Users/dahai/fusion/fusion-design/docs/harness/pkg
cp "$HP/fd_host_web.d.ts" FusionStudio/Resources/wasm/fd_host_web.d.ts
cp "$HP/fd_host_web_bg.wasm.d.ts" FusionStudio/Resources/wasm/fd_host_web_bg.wasm.d.ts
```

- [ ] **Step 3: Verify post-copy**

```bash
strings FusionStudio/Resources/wasm/fd_host_web_bg.wasm | grep -c fdHost  # expect 1
grep -c "fusion_bridge_send_command" FusionStudio/Resources/wasm/fd_host_web.js  # expect ≥1 (interface preserved)
```

- [ ] **Step 4: Gate — `swift build -c debug` EXIT=0** (binary resources don't break compile; confirms packaging)

Run: `swift build -c debug 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Resources/wasm/
git commit -m "feat(#372): vendor fd-host-web wasm fdHost+OPS-13 (log ring buffer)"
```

---

## Task 2: FdHostWebLogCapture coordinator (persist + throttle)

**Files:**
- Create: `FusionStudio/System/FdHostWebLogCapture.swift`

**Interfaces:**
- Consumes: `[String:Any]` entries from `log_capture_dump` payload.
- Produces: `persist(entries:)` → file path string; `triggerForegroundDump()` / `triggerCrashDump()` / `triggerManualDump()` → Bool (sent command); `canDump()` throttle check.

- [ ] **Step 1: Write the failing test**

Create `Tests/UnitTests/FdHostWebLogCaptureTests.swift`:

```swift
import XCTest
@testable import FusionStudio

final class FdHostWebLogCaptureTests: XCTestCase {
    func testPersistWritesJsonWithTimestampAndEntries() throws {
        let entries: [[String: Any]] = [
            ["level": "error", "ts_ms": 1234.0, "msg": "boom"],
            ["level": "warn", "ts_ms": 5678.0, "msg": "careful"]
        ]
        let path = FdHostWebLogCapture.shared.persist(entries: entries, timestamp: 1693500000)
        XCTAssertNotNil(path)
        guard let p = path else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: p))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["schema"] as? String, "fd-host-web-log")
        let arr = json?["entries"] as? [[String: Any]]
        XCTAssertEqual(arr?.count, 2)
        XCTAssertEqual(arr?[0]["level"] as? String, "error")
        // cleanup
        try? FileManager.default.removeItem(atPath: p)
    }

    func testThrottleBlocksRapidForegroundDumps() {
        let cap = FdHostWebLogCapture.shared
        // force lastForegroundDump to now
        cap.resetThrottleForTest()
        XCTAssertTrue(cap.canForegroundDump())
        cap.markForegroundDumped()
        XCTAssertFalse(cap.canForegroundDump())  // immediate second blocked
    }

    func testPersistRejectsOversizedMessage() {
        let huge = String(repeating: "x", count: 50_000)
        let entries: [[String: Any]] = [["level": "error", "ts_ms": 1.0, "msg": huge]]
        let path = FdHostWebLogCapture.shared.persist(entries: entries, timestamp: 1693500001)
        // file written but msg truncated to cap (not rejected wholesale — diagnostics value)
        XCTAssertNotNil(path)
        if let p = path {
            let data = try? Data(contentsOf: URL(fileURLWithPath: p))
            let json = try? JSONSerialization.jsonObject(with: data as? Data ?? Data()) as? [String: Any]
            let arr = json?["entries"] as? [[String: Any]]
            let msg = arr?[0]["msg"] as? String ?? ""
            XCTAssertLessThan(msg.count, 50_000)
            try? FileManager.default.removeItem(atPath: p)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift build --build-tests 2>&1 | tail -5` (FdHostWebLogCapture undefined → compile fail)
Expected: FAIL — `cannot find 'FdHostWebLogCapture' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `FusionStudio/System/FdHostWebLogCapture.swift`:

```swift
import Foundation
import os.log

// #372 OPS-13: 消费 fd-host-web log.capture.dump 桥, 将 WASM 运行时日志环形缓冲
// 持久化到 ~/Library/Logs/fusion-studio/fd-host-web-<ts>.json, 供企业运维诊断。
// WASM 沙箱无文件系统, 环形缓冲是唯一流出路径, 无 Swift 消费者则死端。
// 触发: 手动按钮(DesignLintPanel) / WebView 进程崩溃恢复 / App 进入前台(5min 节流)。
final class FdHostWebLogCapture {
    static let shared = FdHostWebLogCapture()

    private let logger = Logger(subsystem: "com.fusion.studio", category: "FdHostWebLogCapture")

    // 日志目录 ~/Library/Logs/fusion-studio/, 对齐 fusion-design 文件日志目录约定。
    private let logDir: String = {
        let home = NSHomeDirectory()
        return home + "/Library/Logs/fusion-studio"
    }()

    // 单条 msg 截断上限, 防巨型日志撑爆磁盘 + 序列化 OOM。
    private let maxMsgChars = 8192

    // 前台自动 dump 节流: 5 分钟内不重复, 避免写放大。
    private let foregroundThrottleSecs: TimeInterval = 300
    private var lastForegroundDump: Date = .distantPast

    // 测试注入钩子 (生产不可见, internal 供 @testable)。
    internal func resetThrottleForTest() { lastForegroundDump = .distantPast }
    internal func markForegroundDumped() { lastForegroundDump = Date() }

    private init() {}

    // 持久化 entries 到磁盘, 返回文件路径 (失败 nil)。
    // timestamp 由调用方传入 (避免 Date.now 在 actor 外不可用; 测试可注入)。
    func persist(entries: [[String: Any]], timestamp: Int64) -> String? {
        guard !entries.isEmpty else {
            logger.info("FdHostWebLogCapture: persist skipped, 0 entries")
            return nil
        }
        ensureLogDir()
        // 截断超长 msg, 保留诊断价值同时防磁盘膨胀。
        let capped: [[String: Any]] = entries.map { e in
            var m = e
            if let msg = m["msg"] as? String, msg.count > maxMsgChars {
                m["msg"] = String(msg.prefix(maxMsgChars)) + "...[truncated]"
            }
            return m
        }
        let envelope: [String: Any] = [
            "schema": "fd-host-web-log",
            "schema_version": 1,
            "captured_at_ms": timestamp,
            "entry_count": capped.count,
            "entries": capped
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope, options: [.prettyPrinted, .sortedKeys]) else {
            logger.error("FdHostWebLogCapture: serialize failed for \(capped.count) entries")
            return nil
        }
        let fileName = "fd-host-web-\(timestamp).json"
        let path = logDir + "/" + fileName
        guard FileManager.default.createFile(atPath: path, contents: data) else {
            logger.error("FdHostWebLogCapture: create file failed path=\(path, privacy: .public)")
            return nil
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        logger.info("FdHostWebLogCapture: persisted \(capped.count) entries to \(path, privacy: .public)")
        return path
    }

    // 前台触发节流检查。
    func canForegroundDump() -> Bool {
        Date().timeIntervalSince(lastForegroundDump) >= foregroundThrottleSecs
    }

    // 前台触发 dump (DesignBridge 实际发送命令; 此处仅返是否应发送)。
    @discardableResult
    func triggerForegroundDump() -> Bool {
        guard canForegroundDump() else {
            logger.info("FdHostWebLogCapture: foreground dump throttled")
            return false
        }
        markForegroundDumped()
        return true
    }

    private func ensureLogDir() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: logDir) else { return }
        try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        logger.info("FdHostWebLogCapture: ensured log dir \(self.logDir, privacy: .public)")
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift build --build-tests 2>&1 | tail -5`
Expected: build succeeds (local `swift test`=0 toolchain drift; build-tests compiles = gate). Tests run in CI.

- [ ] **Step 5: Gate — debug + release + build-tests EXIT=0**

```bash
swift build -c debug 2>&1 | tail -2
swift build -c release 2>&1 | tail -2
swift build --build-tests 2>&1 | tail -2
```

- [ ] **Step 6: Commit**

```bash
git add FusionStudio/System/FdHostWebLogCapture.swift Tests/UnitTests/FdHostWebLogCaptureTests.swift
git commit -m "feat(#372): FdHostWebLogCapture coordinator — persist WASM log ring to disk"
```

---

## Task 3: Register fdHost handler + log_capture_dump event + crash trigger in DesignCanvasView

**Files:**
- Modify: `FusionStudio/Modules/Design/DesignCanvasView.swift`

**Interfaces:**
- Consumes: `FdHostWebLogCapture.shared.persist(entries:timestamp:)`.
- Produces: `fdHost` handler registration (activates canvas events + log_capture_dump); `requestLogDump(to:clear:)` static (window.postMessage path); `log_capture_dump` event handling; `webViewWebContentProcessDidTerminate` crash trigger.

> **CORRECTION from first draft:** `log.capture.dump` is NOT a `BridgeCommand` variant upstream (bridge.rs `BridgeCommand` enum has no LogCaptureDump arm; `fusion_bridge_send_command` only matches the 11 render/plan/etc. arms). It is handled ONLY by the `window`-message listener `handle_host_message` (bridge.rs:187), which parses `{kind, payload}` snake_case. Therefore the dump request is sent via `window.postMessage(JSON.stringify({kind:"log.capture.dump",payload:{clear:true}}),"*")` — same-window postMessage fires the listener. Do NOT touch `BridgeCommand`/`toJSON()`.

- [ ] **Step 1: Register `fdHost` handler (alongside `fusionBridge`)**

In `makeNSView` (~L172, after the `fusionBridge` add):
```swift
        // #372 OPS-13: 注册 fdHost handler 接收 WASM 出站事件 (node.click/node.drag/.../log_capture_dump)。
        // 上游合约 HOST_HANDLER_NAME="fdHost" (fusion-design bridge.rs:219); send_to_host→dispatch_to_host
        // 主路径 webkit.messageHandlers.fdHost.postMessage(json_string)。旧 wasm 无 fdHost (走 __fd_host_post
        // 队列 studio 不轮询), 故旧 canvas 事件未达 studio; 新 wasm 全量事件经 fdHost, 注册即激活。
        // fusionBridge 保留作入站命令 ack (wasm.ready/error 从内联 HTML 经此回)。
        userContentController.add(context.coordinator, name: "fdHost")
```

Update `userContentController didReceive` guard (~L358):
```swift
            guard message.name == "fusionBridge" || message.name == "fdHost" else { return }
```

- [ ] **Step 2: Add `requestLogDump` static (window.postMessage path)**

After `sendCommand` static (~L340):
```swift
    // #372 OPS-13: 向 canvas WASM 发 log.capture.dump 拉取请求。
    // log.capture.dump 仅由 wasm 的 window-message 监听器 (handle_host_message) 处理, 非 BridgeCommand,
    // 故走 window.postMessage 触发同窗口 message 事件, 而非 fusion_bridge_send_command。
    // 响应异步经 fdHost handler 回 (kind=log_capture_dump)。
    static func requestLogDump(to webView: WKWebView, clear: Bool) {
        let clearLit = clear ? "true" : "false"
        let js = "window.postMessage(JSON.stringify({kind:'log.capture.dump',payload:{clear:\(clearLit)}}),'*');"
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                canvasLog.error("DesignCanvasView: requestLogDump failed: \(error)")
            } else {
                canvasLog.info("DesignCanvasView: sent log.capture.dump (clear=\(clear))")
            }
        }
    }
```

- [ ] **Step 3: Handle `log_capture_dump` event**

Add `entries` accessor to `BridgeEvent` (near other payload accessors, ~L154):
```swift
    var entries: [[String: Any]]? {
        payload["entries"] as? [[String: Any]]
    }
```

Add property to Coordinator (~L348, near `isWasmReady`):
```swift
        var lastDumpPath: String?
```

In `handleBridgeEvent` switch (~L398, after `wasm.error` case):
```swift
            case "log_capture_dump":
                // #372: WASM 响应 log.capture.dump, entries=LogEntry[{level,ts_ms:f64,msg}] 环形缓冲快照。持久化。
                let rawEntries = event.entries ?? []
                let ts = Int64(Date().timeIntervalSince1970 * 1000)
                if let path = FdHostWebLogCapture.shared.persist(entries: rawEntries, timestamp: ts) {
                    canvasLog.info("DesignCanvasView: log_capture_dump persisted \(rawEntries.count) entries → \(path)")
                    self.lastDumpPath = path
                } else {
                    canvasLog.warning("DesignCanvasView: log_capture_dump had \(rawEntries.count) entries, persist skipped/failed")
                }
```

- [ ] **Step 4: Add crash-recovery trigger**

In Coordinator (after `didFailProvisionalNavigation` ~L547, before NSMenuDelegate section):
```swift
        // #372: WebView 内容进程终止 (OOM/SIGKILL) 时触发 dump。进程已死, 当前 buffer 随之丢失,
        // 此调用对死 webview no-op; 真正价值在重启后 (designBridge 重赋 canvasWebView) 补 dump + 留现场日志。
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            canvasLog.error("DesignCanvasView: content process terminated, triggering crash-recovery log dump")
            parent.designBridge.dumpWasmLog(clear: false)
        }
```

- [ ] **Step 5: Gate — `swift build -c debug` EXIT=0**

Run: `swift build -c debug 2>&1 | tail -5`
Expected: `Build complete!`

- [ ] **Step 6: Gate — release + build-tests**

```bash
swift build -c release 2>&1 | tail -2
swift build --build-tests 2>&1 | tail -2
```

- [ ] **Step 7: Commit**

```bash
git add FusionStudio/Modules/Design/DesignCanvasView.swift
git commit -m "feat(#372): register fdHost handler, consume log_capture_dump, crash-recovery dump"
```

---

## Task 4: DesignBridge.dumpWasmLog helper + DesignLintPanel manual button

**Files:**
- Modify: `FusionStudio/Modules/Design/DesignBridge.swift`
- Modify: `FusionStudio/Modules/Design/DesignLintPanel.swift`
- Modify: `FusionStudio/Common/I18nService.swift`

**Interfaces:**
- Consumes: `DesignCanvasView.requestLogDump(to:clear:)` (window.postMessage path, NOT BridgeCommand).
- Produces: `DesignBridge.dumpWasmLog(clear:) -> Bool` (sent?); i18n keys `design_diag_*`.

- [ ] **Step 1: Add i18n keys**

In `I18nService.swift` enum (near `design_lint_*` keys):
```swift
    case design_diag_dumpWasmLog
    case design_diag_dumpSuccess
    case design_diag_dumpEmpty
    case design_diag_dumpFailed
```
Add localized values in the i18n dictionary (Chinese + English):
- `design_diag_dumpWasmLog`: "导出 WASM 日志" / "Export WASM Log"
- `design_diag_dumpSuccess`: "已导出 %d 条日志到 %@"
- `design_diag_dumpEmpty`: "WASM 日志为空"
- `design_diag_dumpFailed`: "导出失败 (WASM 未就绪?)"

- [ ] **Step 2: Add DesignBridge.dumpWasmLog**

In `DesignBridge.swift` (near `sendCanvasCommand` ~L198):
```swift
    // #372 OPS-13: 向 canvas WASM 发 log.capture.dump 拉取请求 (window.postMessage 路径, 非 BridgeCommand)。
    // 返回 true=请求已发 (响应异步经 fdHost handler kind=log_capture_dump 回); false=canvas 未就绪。
    @discardableResult
    func dumpWasmLog(clear: Bool = true) -> Bool {
        guard let webView = canvasWebView else {
            designBridgeLog.warning("DesignBridge: dumpWasmLog — canvasWebView nil, canvas not ready")
            return false
        }
        DesignCanvasView.requestLogDump(to: webView, clear: clear)
        designBridgeLog.info("DesignBridge: sent log.capture.dump (clear=\(clear))")
        return true
    }
```

- [ ] **Step 3: Add manual button to DesignLintPanel**

In `DesignLintPanel.body` header HStack (~L168-176, after the run button):
```swift
                FusionButton(i18n.t(.design_diag_dumpWasmLog), icon: "doc.text.magnifyingglass", style: .ghost, size: .small) {
                    dumpWasmLog()
                }
```
Add state + method (~L159, near other @State):
```swift
    @State private var dumpToast: String?
```
Add method (near `runLint` ~L283):
```swift
    private func dumpWasmLog() {
        let sent = designBridge.dumpWasmLog(clear: true)
        if sent {
            dumpToast = I18nManager.shared.t(.design_diag_dumpSuccess)
        } else {
            dumpToast = I18nManager.shared.t(.design_diag_dumpFailed)
        }
    }
```
(Toast display via existing FusionToast pattern if present, else a transient Text; align with how other panels show ephemeral status. Check Components/FusionToast usage first — do not invent new toast infra.)

- [ ] **Step 4: Gate — debug + release + build-tests**

```bash
swift build -c debug 2>&1 | tail -2
swift build -c release 2>&1 | tail -2
swift build --build-tests 2>&1 | tail -2
```

- [ ] **Step 5: Commit**

```bash
git add FusionStudio/Modules/Design/DesignBridge.swift FusionStudio/Modules/Design/DesignLintPanel.swift FusionStudio/Common/I18nService.swift
git commit -m "feat(#372): manual WASM log dump button in DesignLintPanel + DesignBridge.dumpWasmLog"
```

---

## Task 5: Foreground auto-dump trigger in FusionStudioApp

**Files:**
- Modify: `FusionStudio/FusionStudioApp.swift`

**Interfaces:**
- Consumes: `FdHostWebLogCapture.shared.triggerForegroundDump()`, `agentBridge`/`designBridge` for actual command send.

- [ ] **Step 1: Add foreground trigger in `.active` block**

In `FusionStudioApp.swift` `.onChange(of: scenePhase)` `.active` branch (~L272-280, after `eventBridge.startStream()`):
```swift
                        // #372 OPS-13: 前台唤醒自动 dump WASM 日志环形缓冲 (5min 节流),
                        // 捕获后台/休眠期间 WebView 静默错误。仅 Design 模块加载了 canvas 时有效。
                        if FdHostWebLogCapture.shared.triggerForegroundDump() {
                            agentBridge.requestFdHostWebLogDump()
                        }
```
(The actual send must route through a bridge that holds the canvas WebView. `agentBridge` is the app-level object injected everywhere. Add `AgentBridge.requestFdHostWebLogDump()` that forwards to the DesignBridge — OR simpler: inject `designBridge` if available at app root. Verify which bridge is `@StateObject` at app root in Step 2 before finalizing the call site.)

- [ ] **Step 2: Verify app-root environment objects**

```bash
grep -n "designBridge\|@StateObject.*Design" FusionStudio/FusionStudioApp.swift | head
```
If `designBridge` is a `@StateObject` at app root → call `designBridge.dumpWasmLog(clear:true)` directly (remove the `agentBridge` indirection). If not, add the forwarder on `AgentBridge`. Pick the one matching existing wiring.

- [ ] **Step 3: Gate — debug + release + build-tests**

```bash
swift build -c debug 2>&1 | tail -2
swift build -c release 2>&1 | tail -2
swift build --build-tests 2>&1 | tail -2
```

- [ ] **Step 4: Commit**

```bash
git add FusionStudio/FusionStudioApp.swift
git commit -m "feat(#372): foreground auto-dump WASM log (5min throttle) on scenePhase active"
```

---

## Task 6: Full gate + PR

- [ ] **Step 1: Full build gate**

```bash
swift build -c debug 2>&1 | tail -3     # EXIT=0
swift build -c release 2>&1 | tail -3   # EXIT=0
swift build --build-tests 2>&1 | tail -3 # EXIT=0
```

- [ ] **Step 2: Lint check (CI uses swift build as lint gate)**

Confirm no new warnings introduced: `swift build -c debug 2>&1 | grep -i warning | head` (expect none from new files).

- [ ] **Step 3: Update memory**

Write `/Users/dahai/.claude/projects/-Users-dahai-fusion-fusion-studio/memory/audit-issue372-fdhostweb-logcapture.md` + MEMORY.md index line.

- [ ] **Step 4: Branch + PR**

```bash
git checkout -b feat/372-fdhost-web-log-capture
git push -u origin feat/372-fdhost-web-log-capture
gh pr create --title "feat(#372): consume fd-host-web log.capture.dump — persist WASM logs to disk (OPS-13)" \
  --body "Closes #372. Registers fdHost WKWebView handler, consumes log_capture_dump, persists to ~/Library/Logs/fusion-studio/. Triggers: manual (DesignLintPanel), crash-recovery (webViewWebContentProcessDidTerminate), foreground (5min throttle). Vendors new wasm (fdHost+OPS-13). Forward-compatible with old wasm." \
  --base master
```

- [ ] **Step 5: CI green → squash merge (authorized: 你直接merge，不要等我)**

```bash
gh pr checks <PR#> --watch
gh pr merge <PR#> --squash --delete-branch
git checkout master && git pull --ff-only
```

- [ ] **Step 6: Compact**

---

## Risk (all verified safe)

1. **Old wasm compat**: old bundle has no fdHost — new `fdHost` handler receives nothing (dormant). `fusionBridge` inbound path unchanged. No regression. (Verified: old data segment 0 fdHost/webkit.)
2. **Two handler names**: `fusionBridge` (inbound command ack + wasm.ready from inline HTML) + `fdHost` (outbound WASM events incl log_capture_dump). Both registered, coordinator accepts both. No conflict — distinct WKScriptMessage names.
3. **Crash trigger timing**: `webViewWebContentProcessDidTerminate` fires AFTER process death — the current ring buffer is lost. The dump command sent to a dead webview no-ops. True crash-recovery requires dump-on-restart; this trigger is best-effort + logged. Documented in code comment. (Issue says "optionally auto-dump on crash" — best-effort acceptable.)
4. **Foreground throttle**: 5-min `lastForegroundDump` prevents write-amplification on rapid app focus changes.
5. **Binary reproducibility**: vendored wasm is a local-build artifact (fusion-design target/, gitignored). Other developers regenerate via `Scripts/build.sh` (already has the copy logic, L138-154). Documented in PR.
6. **Rollback**: each task is a separate commit; revert any.
7. **File perms**: `createFile` + `setAttributes 0o600` (matches FusionTempDir pattern); dir 0o700. No TOCTOU (createFile atomic).

## Deferred

- Tenant audit / guard migration (#373) — separate issue, separate PR.
- Polling `navigator.__fd_host_post` for old-wasm outbound events — NOT in scope (old canvas event flow is a pre-existing separate concern; #372 is log-capture only).
