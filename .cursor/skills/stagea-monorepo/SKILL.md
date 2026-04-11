---
name: stagea-monorepo
description: >-
  Enforces that all Nissan Stagea project work stays inside the single git
  repository at /Users/Shared/dev/stagea-stuff. Use when adding apps, packages,
  scripts, docs, or dependencies; when scaffolding tools; or when the user
  mentions monorepo, workspace, or repo layout.
---

# Stagea monorepo

## Rule

- **Root**: `/Users/Shared/dev/stagea-stuff/` (this repo only).
- Do **not** create sibling directories or separate repos for Stagea apps, shared code, or docs.
- New deployable apps → typically `apps/<name>/`. Shared code → `packages/<name>/`. Planning and ADRs → `docs/`.

## Check before writing files

- Path must be under the repo root (no `../` escapes to arbitrary paths).
- Prefer workspace-local packages over instructing the user to clone elsewhere.

## If something suggests an external repo

- Default: vendor or subtree under this monorepo, or document a deliberate exception in `docs/` with rationale.
