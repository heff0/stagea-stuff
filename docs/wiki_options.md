# Wiki — MediaWiki Configuration Plan

The `wiki/` directory is a Git submodule pointing at `github.com/wikimedia/mediawiki`, tracking `master` and pinned to commit `a0a8c14`. This document records why MediaWiki was chosen and which extensions and custom modules the Stagea wiki will depend on. It replaces any earlier draft that used placeholder language.

## 1. Why MediaWiki

- **Proven at scale.** Powers Wikipedia and every Wikimedia project; no practical content ceiling for our traffic.
- **Extension ecosystem.** 900+ maintained extensions plus first-party skins, so we almost never need to fork.
- **Operational simplicity.** LAMP/LEMP stack, single PHP process, supports MariaDB 10.6 / MySQL 8 / PostgreSQL 10+.
- **Licensing.** GPL-2.0-or-later, compatible with the Stagea licensing policy.
- **Internationalisation.** 350+ locales out of the box — relevant because Nissan Stagea enthusiasts are concentrated in AU/NZ/JP/UK.

Considered and rejected: BookStack (PHP, MIT) lacks VisualEditor-grade WYSIWYG for structured pages; Wiki.js v2 (Node, AGPL) has a more modern UI but AGPL is off-limits; Outline (Node, BUSL) is source-available and therefore excluded.

## 2. Required Core Extensions (bundled with MediaWiki)

Enable these in `LocalSettings.php` before first public launch:

- `VisualEditor` — WYSIWYG editor. Non-negotiable for non-technical contributors.
- `Cite` — `<ref>` / `<references/>` markup for citations on technical pages.
- `ParserFunctions` — `#if`, `#switch`, `#time`. Needed by most infobox templates.
- `SyntaxHighlight_GeSHi` — Pygments-backed code blocks; required for parts firmware and tuning snippets.
- `CategoryTree` — dynamic category browsing.
- `CodeEditor` — syntax-highlighted wikitext editing in the source view.
- `Scribunto` — Lua modules; prerequisite for any serious templating.

## 3. Third-Party Extensions to Install

Pulled separately into `wiki/extensions/<Name>/`:

- `PageForms` + `PageSchemas` — structured data entry (e.g. Parts infoboxes with fields: part number, generation, year, condition). Replaces any hand-maintained HTML forms.
- `SemanticMediaWiki` + `SemanticResultFormats` — queryable facts on pages so parts and trim levels can be filtered with `#ask`.
- `Maps` (Maps extension) — geotag meets, scrapyards, and specialist workshops.
- `TemplateData` — required for VisualEditor to render template inputs as forms.
- `Gadgets` — per-user toggleable JS, used for the tuning-calculator gadget (see §4).
- **Do not install `BlueSpice`.** It has commercial-only modules and an incompatible distribution model for our repo.

## 4. Custom Extensions to Build

Each of these will live in `wiki/extensions/Stagea<Name>/` and follow the standard `extension.json` + `i18n/` layout.

### 4.1 `StageaPartsLink`

- **Purpose:** render `{{PartsLink|<partNumber>}}` on any wiki page as a live link to the corresponding record in the Directus parts API (`parts.stagea-stuff.com`).
- **Behaviour:** on save, the extension resolves the part number via `GET /items/parts?filter[number][_eq]=…` and caches the result in the wiki's object cache for 24 h.
- **Dependencies:** the `parts/` service must be live; until then this extension is deferred.

### 4.2 `StageaTuningCalc`

- **Purpose:** expose a MediaWiki gadget that computes injector duty cycle, MAF scaling, and boost targets from values entered in an infobox.
- **Behaviour:** pure client-side JS loaded via `Gadgets`; reads values from the rendered infobox and writes results into a `<div id="stagea-tuning-output">` slot.

### 4.3 `StageaSSO`

- **Purpose:** let Keycloak (once `auth/` exists) act as the wiki's identity provider via OIDC.
- **Behaviour:** thin wrapper around `PluggableAuth` + `OpenIDConnect` configured against `https://auth.stagea-stuff.com/realms/stagea`. No local passwords in production.

## 5. Content Population Playbook

This replaces the earlier "skills to help populate the wiki" section, which was written before it was clear what we actually had to ingest.

### 5.1 Document Importer

- **Input:** the PDF workshop manuals and Word-format FAQ documents already in the Stagea community archive.
- **Tool:** `pandoc --from=pdf --to=mediawiki` for simple documents; a Python script using `pypandoc` plus manual cleanup for anything with tables or images.
- **Output:** one wiki page per source document, filed under `Category:Imported` for triage. No auto-publish to main namespace.

### 5.2 Code Snippet Extractor

- **Input:** tuning maps, ECU pin-outs, and helper scripts stored in `github.com/<stagea-community>/*` repositories.
- **Tool:** a scheduled GitHub Action that runs `grep -nE '^## ' README.md` and pushes each snippet as a subpage under `Project:<repo-name>/Snippets/<heading>`.
- **Requirement:** `SyntaxHighlight_GeSHi` must be installed first.

### 5.3 Template Generator

- **Templates to create up front:** `Template:PartInfobox`, `Template:GenerationInfobox` (WGC34/WGNC34/M35), `Template:Meet`, `Template:Workshop`, `Template:HowTo`, `Template:TroubleshootingStep`.
- Each template must ship a `TemplateData` block so VisualEditor renders inputs as a form.

### 5.4 Link Checker

- **Tool:** `php maintenance/run.php checkExternalLinks.php` run weekly via cron.
- **Action on failure:** open an issue in this repo tagged `wiki-broken-link` with the page, old URL, and the HTTP status.

## 6. Rollout Order

1. Install MediaWiki with core + bundled extensions (§2). Run the web installer; commit `LocalSettings.php` only to a private ops repo, never to this monorepo.
2. Install third-party extensions (§3) in the order listed; Scribunto before SemanticMediaWiki.
3. Build `StageaTuningCalc` (no backend dependencies).
4. Build `StageaSSO` once `auth/` is live.
5. Build `StageaPartsLink` once `parts/` is live.
6. Start content population (§5) — document importer first, then templates, then semantic data.
