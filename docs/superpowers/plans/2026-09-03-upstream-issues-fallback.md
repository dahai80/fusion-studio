# Upstream Issues + Local Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** File 6 upstream issues + hide 3 deprecated modules from enterprise sidebar + add client-side idempotency key, clearing the audit's upstream-blocked defects and the module-catalog question.

**Architecture:** No new subsystems. File issues via `gh` against other repos (per project rule: issue first, don't edit other repos). In-repo: gate `SidebarSection` listing behind `showDeprecatedModules` flag (default false), add `X-Idempotency-Key` header on MultiNode submit/retry, document `exclude_nodes`/artifacts gaps inline.

**Tech Stack:** Swift / SwiftUI, SPM, XCTest. `gh` CLI for issues.

**Spec:** `docs/superpowers/specs/2026-09-03-upstream-issues-fallback-design.md`

## Global Constraints

- 4-space multiples indent, no docstrings, clean code, logging on every non-trivial path.
- Only modify fusion-studio repo. Upstream problems → file issue (gh), never edit other repos here.
- Local `swift test`=0 (toolchain drift Swift 6.3.3/macOS 26); CI macOS-14/Xcode 15.x authoritative. Build gate = `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0.
- i18n: add keys to all 4 lang JSON (`Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json`), NO-INDENT format (one key per line, `": "` separator), load via `Bundle.module`.
- GitHub operations in English.
- Never print api_key/token to stdout/transcript.
- Deprecated `SidebarSection` cases (confirmed in `AppState.swift:380-406`): `simulation` (L400), `trainer` (L406). `Module` enum deprecated cases (confirmed): `simulation` (L120), `training` (L123), `eduK12` (L154), `trainer` (L184). The 3 modules to hide = **simulation, trainer, + the training/eduK12 which route via `Module` not `SidebarSection`** — confirm exact sidebar visibility during implementation; the filter target set = `{ simulation, trainer }` for SidebarSection (the two deprecated L5 sections in the sidebar enum). training/eduK12 are `Module` cases reachable via ModuleDetailView, not direct sidebar sections — handle via the same flag in ModuleDetailView dead-arms.
- `KeychainStore` (`FusionStudio/Common/KeychainStore.swift`) has `get(_:)/set(_:_:)/delete(_:)` static methods using account-string keys — Track C does NOT touch Keychain (that's Track B); Track C only adds the sidebar flag + idempotency header + issue filing.

---

### Task 1: File 6 upstream issues via gh

**Files:**
- Create: `docs/superpowers/specs/2026-09-03-upstream-issues-filed.md` (index of issue URLs)

**Interfaces:**
- Consumes: audit finding IDs from `audit/fusion-studio-audit-result-product-0902.md`
- Produces: 6 filed issue URLs recorded in index file

- [ ] **Step 1: File fusion-mlx Keychain issue**

Run:
```bash
gh issue create --repo <fusion-mlx-owner>/fusion-mlx \
  --title "feat: store API key in Keychain instead of settings.json plaintext" \
  --body "## Problem
\`settings.json\` currently stores \`auth.api_key\` in plaintext on disk. Enterprise secret-management requires Keychain (or env-only).

## Context
Found in fusion-studio enterprise production audit (F-sec-5). fusion-studio already prefers Keychain for its own keys (#266) but cannot read fusion-mlx's Keychain entry — fusion-mlx needs to write the key there itself.

## Proposal
- On startup, if API key exists in settings.json, migrate it to macOS Keychain (or env var) and remove the plaintext copy.
- New installs: read key only from env / Keychain, never write to settings.json.

## Acceptance
- No API key in any plaintext file under \`~/.fusion-mlx/\` after first run.
- Existing settings.json keys migrated automatically."
```
Record the returned issue URL.

NOTE: replace `<fusion-mlx-owner>/fusion-mlx` with the actual repo path — check `git remote -v` or the monorepo layout. If fusion-mlx has no GitHub remote (it's `~/claude-home/fusion-mlx` symlinked), skip filing and record "no remote — documented locally" in the index instead. Do not fabricate a repo.

- [ ] **Step 2: File fusion-artifacts-engine REST #38 issue**

Run:
```bash
gh issue create --repo <fusion-artifacts-owner>/fusion-artifacts-engine \
  --title "feat: implement REST endpoints referenced as #38" \
  --body "## Problem
fusion-studio's artifacts bridge expects REST endpoints that currently return 404. A local 404 fallback exists in studio but the full feature requires these endpoints implemented.

## Context
fusion-studio enterprise production audit (F-func-5). The studio bridge calls endpoints under the artifacts-engine API surface that are unimplemented (#38).

## Acceptance
- Endpoints return expected schemas (not 404).
- studio local fallback remains as graceful degradation for older backends."
```
Record URL. Same remote-check caveat as Step 1.

- [ ] **Step 3: File fusion-multi-node exclude_nodes issue**

Run:
```bash
gh issue create --repo <fusion-multi-node-owner>/fusion-multi-node \
  --title "feat: honor exclude_nodes on task submit endpoint" \
  --body "## Problem
The task submit endpoint ignores the \`exclude_nodes\` field. Retry blacklisting (avoiding the node that failed) is currently client-side-only in fusion-studio.

## Context
fusion-studio \`MultiNodeEngine.swift\` sends \`exclude_nodes\` but notes the backend may ignore it (upstream gap #23/#31). Client-side retry avoidance is a stopgap; the backend must honor the field for correct retry routing.

## Acceptance
- \`exclude_nodes\` in the submit payload is respected: the scheduler does not assign the task to any listed node.
- Documented in the endpoint's OpenAPI schema."
```
Record URL. Remote-check caveat.

- [ ] **Step 4: File fusion-multi-node idempotency key issue**

Run:
```bash
gh issue create --repo <fusion-multi-node-owner>/fusion-multi-node \
  --title "feat: server-side idempotency key on submit/retry" \
  --body "## Problem
No idempotency key is accepted on submit/retry. Duplicate submission (e.g. client retry after network blip) is only detected post-hoc client-side via a heuristic that misses data_parallel duplicates.

## Context
fusion-studio upstream gap #23/#31. fusion-studio will send an \`X-Idempotency-Key\` header on submit/retry (Track C) — the backend should dedup on it: same key + uncompleted task → return the existing task id instead of creating a duplicate.

## Acceptance
- \`X-Idempotency-Key\` header accepted on submit/retry.
- Same key within a TTL window returns the original task id (no duplicate execution).
- Different keys (or no key) behave as today."
```
Record URL.

- [ ] **Step 5: File fusion-multi-node consensus issue**

Run:
```bash
gh issue create --repo <fusion-multi-node-owner>/fusion-multi-node \
  --title "feat: real consensus / quorum / leader election for split-brain" \
  --body "## Problem
The client (fusion-studio) can only see one master's \`/api/nodes\` snapshot. Real partition detection, consensus, quorum, leader election, and fencing need to live server-side. The client's \`>1 master\` heuristic is a stale-read detector, not a partition detector — two genuinely partitioned masters each report themselves as sole.

## Context
fusion-studio enterprise production audit (MultiNode HA). Studio will global-write-disable on the heuristic (Track B) but that is not consensus.

## Acceptance
- Multi-master deployments elect a single leader via quorum.
- Fencing tokens prevent a stale master from acting after a partition heals.
- \`/api/nodes\` reports authoritative cluster membership, not a single master's local view."
```
Record URL.

- [ ] **Step 6: File fusion-studio bundling design issue**

Run:
```bash
gh issue create --repo <fusion-studio-owner>/fusion-studio \
  --title "design: bundling strategy for Python backend runtime in DMG" \
  --body "## Problem
The DMG currently ships zero Python — the backend (\`daemon_server.py\`, \`fusion-agent-studio\`, \`fusion-mlx\`, ~14 upstream services) is assumed present at \`~/fusion/*\` and \`~/claude-home/fusion-mlx\` with pre-built venvs. A fresh Mac with only the DMG is dead-on-arrival (\`IPCClient\` never connects \`/tmp/fusion-studio.sock\`).

## Context
fusion-studio enterprise production audit (F-func-1/F-ops-5). \`build.sh:59\` creates an empty \`Contents/Services\` directory — bundling was started but not finished.

## Proposal (design questions)
- Embed a relocatable Python (python-build-standalone / PyInstaller / shiv) under \`Contents/Services\`?
- Bundle the full monorepo or a minimal subset (agent-studio + mlx)?
- First-run installer step vs fully self-contained bundle?
- Path strategy: bundle-relative defaults instead of hardcoded \`~/fusion\`.

Tracks as a design issue for the Track A implementation effort."
```
Record URL. This one IS this repo — use the repo's own remote (`git remote -v`).

- [ ] **Step 7: Write the filed-issues index**

Create `docs/superpowers/specs/2026-09-03-upstream-issues-filed.md` with each issue's title + URL (or "no remote — documented locally" where a repo lacks a GitHub remote). Commit.

```bash
git add docs/superpowers/specs/2026-09-03-upstream-issues-filed.md
git commit -m "docs(enterprise): index filed upstream issues (Track C)"
```

---

### Task 2: Sidebar deprecated-module filter

**Files:**
- Modify: `FusionStudio/Navigation/FusionSidebarView.swift` (L38 `ForEach(SidebarSection.allCases)`)
- Modify: `FusionStudio/Navigation/IconRailView.swift` (L30 `ForEach(SidebarSection.allCases)`)
- Modify: `FusionStudio/Common/AppState.swift` (add `SidebarSection.isDeprecated` computed + `visibleSections(showDeprecated:)` filter)
- Test: `Tests/UnitTests/UpstreamFallbackTests.swift`

**Interfaces:**
- Consumes: `SidebarSection` enum (`AppState.swift:380`)
- Produces: `SidebarSection.isDeprecated: Bool` (true for `.simulation`, `.trainer`), `static func visibleSections(showDeprecated: Bool) -> [SidebarSection]`

- [ ] **Step 1: Write the failing test**

Create `Tests/UnitTests/UpstreamFallbackTests.swift`:
```swift
import XCTest
@testable import FusionStudio

@MainActor
final class UpstreamFallbackTests: XCTestCase {

    // MARK: - Deprecated module sidebar filter

    func test_upstream_deprecatedModulesHiddenByDefault() {
        let visible = SidebarSection.visibleSections(showDeprecated: false)
        XCTAssertFalse(visible.contains(.simulation), "simulation hidden when showDeprecated=false")
        XCTAssertFalse(visible.contains(.trainer), "trainer hidden when showDeprecated=false")
    }

    func test_upstream_deprecatedModulesShownWhenFlagTrue() {
        let visible = SidebarSection.visibleSections(showDeprecated: true)
        XCTAssertTrue(visible.contains(.simulation), "simulation shown when showDeprecated=true")
        XCTAssertTrue(visible.contains(.trainer), "trainer shown when showDeprecated=true")
    }

    func test_upstream_isDeprecatedClassification() {
        XCTAssertTrue(SidebarSection.simulation.isDeprecated, "simulation is deprecated")
        XCTAssertTrue(SidebarSection.trainer.isDeprecated, "trainer is deprecated")
        XCTAssertFalse(SidebarSection.code.isDeprecated, "code is not deprecated")
        XCTAssertFalse(SidebarSection.multiNode.isDeprecated, "multiNode is not deprecated")
    }

    // MARK: - Idempotency key

    func test_upstream_idempotencyKeyGeneratedPerSubmit() {
        let key1 = MultiNodeEngine.generateIdempotencyKey()
        let key2 = MultiNodeEngine.generateIdempotencyKey()
        XCTAssertFalse(key1.isEmpty, "key non-empty")
        XCTAssertFalse(key2.isEmpty, "key non-empty")
        XCTAssertNotEqual(key1, key2, "two calls differ")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift build --build-tests 2>&1 | tail -20`
Expected: FAIL — `visibleSections` / `isDeprecated` / `generateIdempotencyKey` undefined.

- [ ] **Step 3: Add `isDeprecated` + `visibleSections` to SidebarSection**

In `FusionStudio/Common/AppState.swift`, after the `SidebarSection` enum's `id` property (~L408), add:
```swift
    /// Track C: L5 domain modules not enterprise-ship-grade. Hidden from sidebar
    /// when showDeprecatedModules=false (enterprise default). Enum case kept — removal
    /// breaks routing switch arms + i18n. Dead arms render EmptyView.
    var isDeprecated: Bool {
        switch self {
        case .simulation, .trainer: return true
        default: return false
        }
    }

    static func visibleSections(showDeprecated: Bool) -> [SidebarSection] {
        showDeprecated ? Array(allCases) : allCases.filter { !$0.isDeprecated }
    }
```

- [ ] **Step 4: Wire the filter into FusionSidebarView**

In `FusionStudio/Navigation/FusionSidebarView.swift` L38, replace:
```swift
ForEach(SidebarSection.allCases) { section in
```
with:
```swift
@AppStorage("showDeprecatedModules") private var showDeprecatedModules: Bool = false
...
ForEach(SidebarSection.visibleSections(showDeprecated: showDeprecatedModules)) { section in
```
(Add the `@AppStorage` property near the other `@State`/`@AppStorage` at the top of the struct, ~L23.)

- [ ] **Step 5: Wire the filter into IconRailView**

In `FusionStudio/Navigation/IconRailView.swift` L30, same replacement: `SidebarSection.allCases` → `SidebarSection.visibleSections(showDeprecated: showDeprecatedModules)` + add the `@AppStorage("showDeprecatedModules")` property.

- [ ] **Step 6: Dead-arm safety in ModuleDetailView (training/eduK12)**

In `FusionStudio/Navigation/ModuleDetailView.swift` L24 (`case .training:`) and L85 (`case .eduK12:`), ensure each arm renders a placeholder, not a broken module view. If they currently route to a real view, wrap with a `showDeprecatedModules` gate:
```swift
case .training:
    if showDeprecatedModules {
        TrainingModuleView()  // existing
    } else {
        EmptyView()  // hidden from enterprise catalog; unreachable when flag false
    }
```
(Confirm exact existing content by reading the file first; apply the gate only if the arm currently renders a real view. If it already renders a placeholder/coming-soon, leave as-is.)

- [ ] **Step 7: Run test to verify it passes**

Run: `swift build --build-tests 2>&1 | tail -20`
Expected: PASS (builds clean; local `swift test`=0 toolchain drift, CI authoritative).

- [ ] **Step 8: Commit**

```bash
git add FusionStudio/Common/AppState.swift FusionStudio/Navigation/FusionSidebarView.swift FusionStudio/Navigation/IconRailView.swift FusionStudio/Navigation/ModuleDetailView.swift Tests/UnitTests/UpstreamFallbackTests.swift
git commit -m "fix(enterprise): hide deprecated simulation/trainer modules from sidebar (showDeprecatedModules gate)"
```

---

### Task 3: Settings toggle + i18n

**Files:**
- Modify: `FusionStudio/Settings/SettingsView.swift` (advanced section)
- Modify: `Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json`

**Interfaces:**
- Consumes: `@AppStorage("showDeprecatedModules")`
- Produces: visible toggle in Settings advanced

- [ ] **Step 1: Add the toggle to SettingsView advanced section**

Read `FusionStudio/Settings/SettingsView.swift` to locate the advanced section. Add a `Toggle` bound to `@AppStorage("showDeprecatedModules")`:
```swift
@AppStorage("showDeprecatedModules") private var showDeprecatedModules: Bool = false
...
Toggle(isOn: $showDeprecatedModules) {
    Text(i18n(.settings_showDeprecatedModules))
}
```
Place in the advanced/developer section. 4-space indent.

- [ ] **Step 2: Add i18n keys to all 4 lang JSON**

Add to each of `Resources/i18n/zh-CN.json`, `en-US.json`, `ja-JP.json`, `ko-KR.json` (NO-INDENT, one key per line, `": "` separator):
- zh-CN: `"settings_showDeprecatedModules": "显示未完成模块 (simulation/trainer)"`
- en-US: `"settings_showDeprecatedModules": "Show unfinished modules (simulation/trainer)"`
- ja-JP: `"settings_showDeprecatedModules": "未完成モジュールを表示 (simulation/trainer)"`
- ko-KR: `"settings_showDeprecatedModules": "미완성 모듈 표시 (simulation/trainer)"`

- [ ] **Step 3: Register the key in I18nService enum**

In `FusionStudio/Common/I18nService.swift`, add to the `I18nKey` enum:
```swift
case settings_showDeprecatedModules = "settings_showDeprecatedModules"
```
(Match the enum's existing `case x = "x"` rawValue pattern.)

- [ ] **Step 4: Build + commit**

Run: `swift build -c debug 2>&1 | tail -5`
Expected: EXIT=0.

```bash
git add FusionStudio/Settings/SettingsView.swift FusionStudio/Common/I18nService.swift Resources/i18n/zh-CN.json Resources/i18n/en-US.json Resources/i18n/ja-JP.json Resources/i18n/ko-KR.json
git commit -m "feat(enterprise): add showDeprecatedModules toggle to Settings + 4-lang i18n"
```

---

### Task 4: Client-side idempotency key on MultiNode submit/retry

**Files:**
- Modify: `FusionStudio/Modules/MultiNode/MultiNodeEngine.swift` (L438 `submitTask`, L454 `retryTask`)
- Modify: `FusionStudio/Bridge/IPCMultiNodeMethods.swift` (`mnRequest` L17 — add optional header param)
- Test: `Tests/UnitTests/UpstreamFallbackTests.swift` (test written in Task 2 Step 1)

**Interfaces:**
- Consumes: `mnRequest(_:path:body:timeout:)` (`IPCMultiNodeMethods.swift:17`)
- Produces: `static func generateIdempotencyKey() -> String` (UUID), `X-Idempotency-Key` header on submit/retry

- [ ] **Step 1: Add `generateIdempotencyKey` to MultiNodeEngine**

In `MultiNodeEngine.swift`, add a static helper near the top of the class (after the `init`, ~L90):
```swift
    /// Track C: 客户端幂等键。上游 fusion-multi-node #23/#31 暂忽略 X-Idempotency-Key header;
    /// 上游采纳后自动启用服务端去重。每次 submit/retry 生成新 UUID。
    static func generateIdempotencyKey() -> String {
        UUID().uuidString
    }
```

- [ ] **Step 2: Thread the key through `mnRequest`**

In `FusionStudio/Bridge/IPCMultiNodeMethods.swift` L17, add an optional header parameter:
```swift
    private func mnRequest(_ method: String, path: String, body: [String: Any]? = nil, timeout: TimeInterval = 15, idempotencyKey: String? = nil) async throws -> [String: Any] {
```
After the `Authorization` header set (~L27), add:
```swift
        if let key = idempotencyKey {
            request.setValue(key, forHTTPHeaderField: "X-Idempotency-Key")
        }
```

- [ ] **Step 3: Pass the key from submitTask/retryTask**

Read `MultiNodeEngine.swift:438-472` (`submitTask` + `retryTask`). At each call site that invokes the submit/retry HTTP request, generate the key and pass it. Pattern:
```swift
        let idemKey = Self.generateIdempotencyKey()
        // ... existing request build ...
        request.setValue(idemKey, forHTTPHeaderField: "X-Idempotency-Key")
        engineLog.info("submitTask idempotencyKey=\(idemKey, privacy: .public)")
```
(If submit/retry go through `mnRequest`, pass `idempotencyKey: idemKey`. If they build their own `URLRequest` inline, set the header directly. Confirm by reading the method bodies first.)

- [ ] **Step 4: Add the exclude_nodes / artifacts gap comments**

In `MultiNodeEngine.swift` near L443/L452 (existing `exclude_nodes` notes), ensure the comment references the filed upstream issue URL (from Task 1 index). Update the comment to point to the issue rather than just "#23/#31":
```swift
        // exclude_nodes: 上游 fusion-multi-node 暂忽略 (见 upstream issue <URL>), 客户端传递为前置。
```
In the artifacts bridge, add a comment referencing the artifacts-engine issue URL where the 404 fallback lives.

- [ ] **Step 5: Run tests to verify**

Run: `swift build --build-tests 2>&1 | tail -20`
Expected: PASS — `generateIdempotencyKey` test passes, build clean.

- [ ] **Step 6: Commit**

```bash
git add FusionStudio/Modules/MultiNode/MultiNodeEngine.swift FusionStudio/Bridge/IPCMultiNodeMethods.swift
git commit -m "feat(enterprise): client-side X-Idempotency-Key on MultiNode submit/retry (upstream #23/#31 stopgap)"
```

---

### Task 5: Final build gate + structural test sweep

**Files:**
- Test: `Tests/UnitTests/UpstreamFallbackTests.swift`

**Interfaces:**
- Consumes: all prior tasks

- [ ] **Step 1: Add structural tests**

Append to `Tests/UnitTests/UpstreamFallbackTests.swift`:
```swift
    // MARK: - Structural

    func test_upstream_submitTaskSendsIdempotencyHeader() {
        let srcPath = (#file as NSString).deletingLastPathComponent
            + "/../../FusionStudio/Bridge/IPCMultiNodeMethods.swift"
        guard let src = try? String(contentsOfFile: srcPath, encoding: .utf8) else {
            XCTFail("cannot read IPCMultiNodeMethods source"); return
        }
        XCTAssertTrue(src.contains("X-Idempotency-Key"), "mnRequest must set X-Idempotency-Key header")
        XCTAssertTrue(src.contains("idempotencyKey"), "mnRequest must accept idempotencyKey param")
    }

    func test_upstream_sidebarUsesVisibleSectionsFilter() {
        let path = (#file as NSString).deletingLastPathComponent
            + "/../../FusionStudio/Navigation/FusionSidebarView.swift"
        guard let src = try? String(contentsOfFile: path, encoding: .utf8) else {
            XCTFail("cannot read FusionSidebarView source"); return
        }
        XCTAssertTrue(src.contains("visibleSections"), "sidebar must use visibleSections filter")
        XCTAssertFalse(src.contains("ForEach(SidebarSection.allCases)"), "sidebar must not iterate allCases directly")
    }
```

- [ ] **Step 2: Build gate**

Run:
```bash
swift build -c debug 2>&1 | tail -5
swift build --build-tests 2>&1 | tail -5
```
Expected: both EXIT=0.

- [ ] **Step 3: Commit + push branch**

```bash
git add Tests/UnitTests/UpstreamFallbackTests.swift
git commit -m "test(enterprise): structural tests for sidebar filter + idempotency header"
```

---

## Verification

**Build gate (TRUTH):** `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0. Local `swift test`=0 (toolchain drift); CI macOS-14/Xcode 15.x authoritative (~276 cases).

**Manual / e2e (after merge, user re-验收):**
1. Fresh launch → sidebar does NOT show "Fusion Simulation" / "Fusion Trainer".
2. Settings → advanced → toggle "Show unfinished modules" ON → sidebar shows them; OFF → hidden.
3. MultiNode submit task → logs show `idempotencyKey=<uuid>` (no token leaked).
4. `docs/superpowers/specs/2026-09-03-upstream-issues-filed.md` lists 6 issue URLs (or "no remote" notes).
5. CI 3 green.

## Branch / PR

Branch: `fix/enterprise-track-c-upstream-fallback`. PR title EN: `fix(enterprise): hide deprecated modules + upstream issue filing + client idempotency (Track C)`. Merge direct (authorized). Memory + compact after.

## Risks

- **Repo remote unknown** — fusion-mlx / fusion-artifacts-engine / fusion-multi-node may lack GitHub remotes (symlinked / local). Mitigation: `git remote -v` check per repo before `gh issue create`; record "no remote — documented locally" if absent. Do not fabricate repos.
- **training/eduK12 routing** — these are `Module` cases (ModuleDetailView L24/L85), not direct `SidebarSection` cases. If they're reachable via a non-sidebar path while hidden, the `EmptyView` gate in ModuleDetailView covers it. Confirm reachability during Task 2 Step 6.
- **i18n key format** — must be NO-INDENT one-key-per-line `": "` separator matching existing files (E6 lesson). Verify by reading one existing key before editing.
