# Stagea Platform: Documentation Maintenance & Archiving Guide

This document defines the quality standards, architectural taxonomy, term-shift prevention rules, and archiving procedures for the Stagea platform documentation. 

Our goal is to treat documentation with the same engineering rigor as code, preventing technical drift, duplication, and rot as our services scale.

---

## 1. Documentation Directory Taxonomy

To prevent file bloat and clutter, we enforce a strict file layout inside `/docs`:

```
stagea-stuff/
└── docs/
    ├── shell/                  # Astro Shell specific designs, auth plans, and backlogs
    │   └── cards/              # active Sprint PRD Cards (strictly active sprint items)
    ├── deployment/             # installation, setups, and troubleshooting checklists
    │   ├── GO_LIVE.md          # operator production spin-up runbook
    │   ├── ci-cd.md            # path-filtered per-module CI/CD (GHCR + SSH)
    │   └── cards/              # production go-live vertical-slice sprint cards
    ├── archive/                # Retired blueprints, completed PRD cards, and expired plans
    │   ├── shell/              # Archived shell documents
    │   └── services/           # Archived microservice documents
    ├── 12_factor_compliance.md  # Master platform-wide architectural audit
    ├── EXECUTIVE_AUDIT_REPORT.md# Board-level findings and quality readiness scorecards
    ├── site-plan.md            # Overall target system map (single source of truth)
    ├── architecture.md         # Visibility-first map (request path, monorepo, live vs planned)
    ├── install-guides.md       # From-zero hub (production go-live vs local clone)
    └── DOCUMENTATION_GUIDE.md   # This maintenance and archiving guide
```

---

## 2. Preventing Duplication & Technical Term-Shift

As teams build out applications concurrently, they often introduce different names for the same core system components. This leads to **technical term-shift** and **source duplication**. We enforce these three strict guardrails:

### Guardrail 1: The Single Source of Truth (SSOT) Rule
* **Rule**: Never duplicate architectural, routing, or database schema descriptions across multiple files. 
* **Action**: Define a concept *once* in its designated taxonomy folder and reference it from other files using relative markdown links (e.g. `[See Auth Scopes](../shell/auth_plan.md#scopes)`). If you copy-paste paragraphs, they will inevitably rot out of sync.

### Guardrail 2: The Unified Glossary Contract
To prevent language drift, use these exact, standardized system terms in all documents and code comments:

| Term | Approved System Name | Prohibited Synonyms (Do Not Use) |
| :--- | :--- | :--- |
| **Shell Gateway** | `Astro Shell` or `Shell Edge` | frontend, home page app, wrapper site, chrome app |
| **Identity Core** | `Keycloak OIDC IdP` | authentication server, sso portal, login DB, keycloak service |
| **Parts Database** | `Directus Parts API` | parts catalgoue, catalogue DB, directus cms, parts-api |
| **Backing Nodes** | `Submodules` | sub-apps, sub-sites, external services, micro-frontend sites |

### Guardrail 3: Atomic Documentation Edits
* **Rule**: Documentation is code. When a code modification changes system behavior, endpoints, port bindings, or environment scopes, the related markdown guides **must be updated inside the exact same Git commit or Pull Request**.
* **Action**: A PR that changes code but leaves documentation out-of-date ("trailing edits") is blocked by the CI compiler and will fail review.

---

## 3. The Platform Archiving Program

To prevent our active, high-priority folders from bloating with completed PRD cards, expired research plans, and retired blueprints, we implement an **Active Archiving Program**.

```
[ Active Document ] ──(Completed / Superseded)──> [ Prepend Archive Metadata ] ──> [ Relocate to /docs/archive/ ]
```

### When to Archive a Document
Archive a document if:
1. It is a **Sprint PRD Card** that has been fully implemented, reviewed, and merged.
2. It is an **ADR / Architecture Blueprint** that has been superseded by a newer design.
3. It is a **Testing or Staging Plan** for a temporary, retired environment.

### The Archiving Workflow (3 Steps)

#### Step 1: Prepend the Standardized YAML Archive Metadata Header
Open the target document and insert this exact YAML block at the very top (above the main title). This guarantees that search engines and developers instantly recognize the historical nature of the file:

```yaml
---
status: archived
archived_at: YYYY-MM-DD
superseded_by: "../target_active_reference.md" # Relative link to active code/doc if applicable
author: "@github_username"
reason: "Implemented in Sprint 4; replaced by live code implementation in shell/src/lib/auth.ts."
---
```

#### Step 2: Relocate the File
Move the file into the corresponding `/docs/archive/` subfolder. 
* *Example (Archiving Sprint Card 1)*:
  ```bash
  git mv docs/shell/cards/card_1_jwks_auth.md docs/archive/shell/card_1_jwks_auth.md
  ```

#### Step 3: Prune Reference Indexes
Open the corresponding active backlog or reference index (such as `docs/shell/TODO.md` or `docs/site-plan.md`) and remove the link or mark it cleanly as archived.

---

## 4. Documentation Quality Checklist (PR Review)

Before approving any documentation pull request, auditors must verify:
* [ ] No system passwords, API keys, or raw JWT credentials are saved in the text.
* [ ] All relative links use clean markdown formats and point to valid, non-broken file paths.
* [ ] The terminology used perfectly conforms to the **Unified Glossary Contract**.
* [ ] No duplicate paragraphs or system descriptions were introduced (links were used instead).
* [ ] Archived documents carry the standard YAML metadata block at the top of the file.
