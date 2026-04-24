# Contributing to Stagea

Thanks for helping build the Stagea community platform. This repo is a monorepo that bundles several upstream applications (NodeBB, MediaWiki, Ghost, Saleor storefront) under a single Stagea-specific layout. These rules cover contributions to **this monorepo only** — for contributions to individual upstream projects, follow their own `CONTRIBUTING.md` and push your change there first.

## 1. Scope of This Repo

You should change files in this repo when you are:

- Adding or updating the glue that wires services together: docs, `.cursor/skills/`, planned `infra/`, planned `packages/`, planned `apps/`, planned `services/`.
- Bumping the pinned commit of any of the four submodules (`forum/`, `wiki/`, `blog/`, `shop/`) to a newer upstream revision; document the upstream SHA range in the PR.
- Writing or refining skills under `.cursor/skills/` and updating `skills-lock.json`.

You should **not** use this repo to:

- Fix bugs inside NodeBB, MediaWiki, Ghost, or the Saleor storefront. Those belong upstream; a patch committed directly into a submodule checkout here will be lost on the next bump.
- Create sibling repositories for Stagea-related code. The `stagea-monorepo` skill enforces that all Stagea work lives under `/Users/Shared/dev/stagea-stuff/` (and its GitHub mirror at `heff0/stagea-stuff`).

## 2. Branching and Commits

- Default branch: `main`. All PRs target `main`. There is no `develop` branch.
- Branch naming: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`, `chore/<slug>`, `infra/<slug>`.
- Commit messages follow **Conventional Commits**, enforced by the `caveman-commit` skill (see `.cursor/skills/caveman-commit/SKILL.md`):
  - Subject: `<type>(<scope>): <imperative summary>`, ≤50 chars preferred, hard cap 72.
  - Body only when the "why" is non-obvious or there's a breaking change.
  - No AI attribution lines in commit messages.

## 3. Pull Requests

Every PR must:

1. Target `main` on `heff0/stagea-stuff`.
2. Keep the diff to a single concern. Split "bump upstream" and "configure upstream" into separate PRs.
3. Update the relevant doc in `docs/` in the same PR. If you scaffold `auth/`, update `docs/site-plan.md` §2 and `docs/app_test_plan.md` §2.5. If you change a setup step, update the `README.md`.
4. For any submodule bump, include the upstream commit range in the PR body: `saleor/storefront be64a69…<new-sha> (N commits)`.
5. Pass the per-app smoke tests in `docs/app_test_plan.md` for the apps you touched. Paste the `pass/fail` matrix into the PR description.

## 4. Code Style

- **Markdown:** wrap at 100 characters where it doesn't harm tables. Use ATX headings (`#`). No trailing spaces.
- **Shell:** POSIX `sh` for anything in `infra/`; Bash only when you use Bash features, and start with `#!/usr/bin/env bash` plus `set -euo pipefail`.
- **TypeScript / JavaScript** (once `packages/` and `apps/` exist): match the upstream config where we copy conventions from (Ghost's ESLint for `apps/`, Saleor's config for shop adapters).
- **PHP** (if you add a custom MediaWiki extension under `wiki/extensions/Stagea*`): follow MediaWiki's `.phpcs.xml` (already present at `wiki/.phpcs.xml`).

## 5. Reviewing PRs

If you're reviewing, use the `caveman-review` skill style: one line per finding, `L<line>: <problem>. <fix>.`, with severity prefixes `🔴 bug`, `🟡 risk`, `🔵 nit`, `❓ q`. Drop the terse format for security findings and architectural disagreements.

## 6. Reporting Bugs

Open an issue on `heff0/stagea-stuff`. Include:

- Affected path (`forum/`, `wiki/`, `blog/`, `shop/`, `docs/`, `.cursor/skills/`, or `infra/`).
- Exact command that failed and its output (last 50 lines).
- Versions: `git --version`, `node -v`, `pnpm -v`, `php -v`, `docker version --format '{{.Server.Version}}'`.
- Whether it reproduces on a clean `git clone --recurse-submodules`.

Bugs that reproduce inside an upstream project and not in our glue should be filed upstream; link the upstream issue from ours so we can track it.

## 7. Feature Requests

Open an issue with the label `proposal`. The proposal should say which subdomain / service it targets (from `docs/site-plan.md` §2) and whether it requires any of the still-empty directories (`auth/`, `parts/`, `services/`, `infra/`, `packages/`) to be scaffolded first.

## 8. Code of Conduct

Be useful, be accurate, be civil. Personal attacks, harassment, and off-topic politics get a single warning and then a block.
