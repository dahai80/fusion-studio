# Upstream Issues + Local Fallback — Design

> **Status:** Approved 2026-09-03. Implements the enterprise production upstream track (Track C). Brainstorming → spec → plan → implementation. Runs in parallel with Track B (MultiNode TLS+HA).

## Context

Enterprise production audit flagged several defects whose root fix lives in **other repos** (fusion-mlx, fusion-artifacts-engine, fusion-multi-node) — per project rules (`只能修改所在的目录和工程的代码，不能修改别的工程代码，遇到上游问题，先提issue，在提pr`) we file upstream issues and add local degradation/fallback in fusion-studio only. Also: simulation/training/eduK12 modules are not enterprise-ship-grade; user decision (2026-09-03) = **hide from sidebar entirely** for enterprise catalog clarity.

This track is small + low-risk: file upstream issues via `gh` (English), hide 3 modules, add client-side idempotency-key + fallback guards. Does not move the enterprise needle alone but clears the audit's upstream-blocked items and the module-catalog question.

## Scope

In scope:
- File 6 upstream issues via `gh` (English), linking audit findings.
- Hide simulation/training/eduK12 from sidebar (gate behind `showDeprecatedModules` flag, default false); dead switch arms → `EmptyView`.
- Client-side idempotency key on `submitTask`/`retryTask` (UUID → `X-Idempotency-Key` header; harmless if upstream ignores, enables dedup when upstream adopts).
- Track B dependency note: the `exclude_nodes` upstream gap + split-brain consensus gap are filed here, handled client-side in Track B.

Out of scope:
- Editing other repos' code (never).
- Implementing the upstream fixes (their maintainers / separate PRs).
- Full module removal (enum case removal breaks routing + i18n switch arms — deferred).

## Upstream issues to file (gh, English)

All filed against respective repos with `--body` linking the audit finding ID. Titles + repos:

1. **fusion-mlx** — `feat: store API key in Keychain instead of settings.json plaintext` (F-sec-5). Body: settings.json currently stores `auth.api_key` in plaintext on disk; enterprise secret-management requires Keychain (or env-only). Reference fusion-studio already prefers Keychain (#266) but cannot read fusion-mlx's Keychain entry — needs fusion-mlx to write there.
2. **fusion-artifacts-engine** — `feat: implement REST endpoints referenced as #38` (F-func-5). Body: studio's artifacts bridge expects REST endpoints that return 404; local fallback exists but full feature needs endpoints implemented.
3. **fusion-multi-node** — `feat: honor exclude_nodes on task submit endpoint` (#23/#31, MultiNodeEngine.swift:443,452). Body: submit endpoint ignores `exclude_nodes` field; retry blacklisting is client-side-only stopgap.
4. **fusion-multi-node** — `feat: server-side idempotency key on submit/retry` (#23/#31). Body: no idempotency key accepted; duplicate submission only detected post-hoc client-side. Studio will send `X-Idempotency-Key` header (Track C) — backend should dedup on it.
5. **fusion-multi-node** — `feat: real consensus / quorum / leader election for split-brain` (Track B client-stopgap references this). Body: client can only see one master's `/api/nodes`; real partition detection / consensus / fencing needs server-side. Studio will global-write-disable on `>1 master` heuristic (Track B) but that's not consensus.
6. **fusion-studio (this repo)** — `design: bundling strategy for Python backend runtime in DMG` (F-func-1/F-ops-5). Body: DMG currently ships zero Python; enterprise needs out-of-box. Seeds Track A. (Filed against this repo as a design issue to track, not a code PR.)

Filing order: 1-5 against other repos first (per rule: issue first), 6 against this repo. Each issue body references `audit/fusion-studio-audit-result-product-0902.md` finding ID where applicable.

After filing: record issue URLs in a `docs/superpowers/specs/2026-09-03-upstream-issues-filed.md` index (so Track B/A can reference them).

## Components (in-repo local work)

### 1. Sidebar module hiding (modify FusionSidebarView + SectionContentView)

- New `@AppStorage("showDeprecatedModules") var showDeprecatedModules: Bool = false` (default false — enterprise catalog clean).
- `FusionSidebarView`: filter `SidebarSection.allCases` to exclude `simulation`, `training`, `k12Teacher` (the 3 deprecated) when `!showDeprecatedModules`. (Identify exact section enum cases by reading `SidebarSection` — confirm names in implementation.)
- `SectionContentView` (ContentView.swift:158): the switch arms for those 3 sections → render `EmptyView()` (defensive; if somehow routed, blank not broken). Left as no-op, not removed (enum removal breaks routing + i18n).
- Settings: advanced section adds toggle "显示未完成模块 (simulation/training/eduK12)" bound to `showDeprecatedModules`. i18n 4 lang.
- i18n: new key `settings_showDeprecatedModules` + label.

### 2. Client-side idempotency key (modify MultiNodeEngine)

- `submitTask` + `retryTask`: generate `let key = UUID().uuidString`, add header `X-Idempotency-Key: <key>` to the HTTP request (existing `mnRequest`/`URLSession` call).
- Pass `key` to `ClusterAuditor` (Track B) when recording the submit/retry audit entry.
- Comment: "上游 fusion-multi-node #23/#31 暂忽略此 header; 上游采纳后自动启用服务端去重."
- No behavioral change if upstream ignores header (harmless additive header).

### 3. exclude_nodes / artifacts fallback (no code change, documented)

- `exclude_nodes`: already sent by `MultiNodeEngine.submitTask`; no code change. Add inline comment pointing to upstream issue #3 (filed above) so future readers know it's a known gap.
- artifacts-engine 404: existing local fallback retained (no change); comment updated to reference upstream issue #2.

## Testing

`Tests/UnitTests/UpstreamFallbackTests.swift` (new):

- `test_deprecatedModulesHiddenByDefault` — `showDeprecatedModules=false` → filtered sidebar list excludes the 3 sections. (Test the pure filter function: extract `func filterSidebarSections(_ all: [SidebarSection], showDeprecated: Bool) -> [SidebarSection]` and test it directly — avoids needing the full view hierarchy.)
- `test_deprecatedModulesShownWhenFlagTrue` — `showDeprecatedModules=true` → all sections present.
- `test_idempotencyKeyGeneratedPerSubmit` — `generateIdempotencyKey()` returns non-empty UUID; two calls differ. (Pure helper test.)
- Structural: `test_submitTaskSendsIdempotencyHeader` — grep `MultiNodeEngine.swift` for `X-Idempotency-Key` presence.

Build gate: `swift build -c debug` EXIT=0 AND `swift build --build-tests` EXIT=0. CI authoritative.

## Files

| File | Action | Responsibility |
|------|--------|----------------|
| `FusionStudio/Navigation/FusionSidebarView.swift` | modify | filter deprecated sections by flag |
| `FusionStudio/ContentView.swift` | modify | SectionContentView dead arms → `EmptyView` |
| `FusionStudio/Settings/SettingsView.swift` | modify | `showDeprecatedModules` toggle (advanced) |
| `FusionStudio/Modules/MultiNode/MultiNodeEngine.swift` | modify | idempotency key on submit/retry + comments |
| `Resources/i18n/{zh-CN,en-US,ja-JP,ko-KR}.json` | modify | new keys |
| `Tests/UnitTests/UpstreamFallbackTests.swift` | new | tests above |
| `docs/superpowers/specs/2026-09-03-upstream-issues-filed.md` | new | index of filed issue URLs |

## Risks

- **Sidebar filter breaks navigation** — if a deprecated module is reachable via another path (IconRail, search, deep link) while hidden, routing hits the `EmptyView` arm. Mitigation: `EmptyView` is safe (blank screen, no crash); the toggle lets devs still access. Acceptable for enterprise catalog.
- **Upstream issues ignored** — filed issues may sit unaddressed. Mitigation: local fallbacks (idempotency header harmless, exclude_nodes comment, 404 fallback) mean studio degrades gracefully regardless; the issues are tracked, not blocking.
- **`showDeprecatedModules` default false changes existing dev UX** — devs who used those modules now need the toggle. Mitigation: toggle is in Settings advanced, documented in commit + memory. Low friction.
