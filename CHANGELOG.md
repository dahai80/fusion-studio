---
doc_id: fusion-studio/changelog
product: fusion-studio
class: app
entry: guided-ui
doc_type: changelog
title: { zh: "Fusion Studio 变更记录", en: "Fusion Studio changelog" }
audience: engineer
status: draft
version: 0.1.66
updated: 2026-11-07
owner: @dahai
source_of_truth:
  - CHANGELOG.md
  - Scripts/build.sh
---

# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows the `VERSION` pin in `Scripts/build.sh` (signed tags `vX.Y.Z`, unsigned `vX.Y.Z-beta`). Historical release notes live in git tags and GitHub releases.

## Unreleased

### Added

- Adopted the fusion docs-system v1.1 contract (app x guided-ui): added `docs/product-page.md`, `docs/get-started.md`, `docs/troubleshooting.md`, `docs/img/`, this `CHANGELOG.md`, `ci/validate_docs.py`, and the `docs` GitHub Actions workflow; added 12-key frontmatter to all in-repo markdown docs.
