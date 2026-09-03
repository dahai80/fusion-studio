# Upstream Issues Filed — Track C

Plan: `Upstream Issues + Local Fallback` (2026-09-03)
Audit source: `audit/fusion-studio-audit-result-product-0902.md`

All 6 issues filed via `gh issue create` on 2026-09-03. Every repo had a GitHub remote — none skipped.

## Filed Issues

| # | Title | Repo | URL |
|---|-------|------|-----|
| 1 | feat: store API key in Keychain instead of settings.json plaintext | dahai80/fusion-mlx | https://github.com/dahai80/fusion-mlx/issues/770 |
| 2 | feat: implement REST endpoints referenced as #38 | dahai80/fusion-artifacts-engine | https://github.com/dahai80/fusion-artifacts-engine/issues/55 |
| 3 | feat: honor exclude_nodes on task submit endpoint | dahai80/fusion-multi-nodes | https://github.com/dahai80/fusion-multi-nodes/issues/70 |
| 4 | feat: server-side idempotency key on submit/retry | dahai80/fusion-multi-nodes | https://github.com/dahai80/fusion-multi-nodes/issues/71 |
| 5 | feat: real consensus / quorum / leader election for split-brain | dahai80/fusion-multi-nodes | https://github.com/dahai80/fusion-multi-nodes/issues/72 |
| 6 | design: bundling strategy for Python backend runtime in DMG | dahai80/fusion-studio | https://github.com/dahai80/fusion-studio/issues/393 |

## Notes

- **Repo path discovery**: `fusion-multi-node` (directory) maps to GitHub repo `dahai80/fusion-multi-nodes` (plural). All others match directory name.
- **fusion-mlx**: lives at `~/claude-home/fusion-mlx` (symlinked from the monorepo) and DOES have a GitHub remote — filed normally.
- **No-remote repos**: none. All 4 repos had an `origin` remote pointing to `github.com:dahai80/*`.
- Issue bodies reference audit finding IDs (F-sec-5, F-func-5, F-func-1/F-ops-5, upstream gaps #23/#31, MultiNode HA) as required.
