# Contributing to the Stagea Wiki

This guide is for people editing content on `wiki.stagea-stuff.com` (the MediaWiki instance at `wiki/`). For code and infra changes to this monorepo, see the repo-root [`CONTRIBUTING.md`](../CONTRIBUTING.md).

## 1. What You Can Contribute

- **New pages** for vehicles, parts, procedures, events, or people that are not yet documented.
- **Edits** to existing pages for accuracy, clarity, missing citations, or outdated part numbers/prices.
- **Structured data** — filling in the `Template:PartInfobox` / `Template:GenerationInfobox` fields on existing pages (see `docs/wiki_options.md` §4 for the infobox roadmap).
- **Media** — photos of real cars, parts, and receipts. Upload via `Special:Upload`; see §3.3 for licensing.
- **Issue reports** for broken links, wrong facts, or pages that should be merged or split.

## 2. Getting an Account

- **Read access** is public and does not require an account.
- **Edit access** requires an account. Self-registration is enabled; accounts become auto-confirmed after 4 days and 10 edits, at which point you can also create new pages and upload files.
- **Sysop / interface-admin rights** are granted by the wiki administrator listed in `Project:Administrators` on the wiki itself. Do not request them in this repo's issue tracker.

Once the `auth/` Keycloak service is live (see `docs/site-plan.md` §3), local wiki accounts will be phased out in favour of SSO; existing accounts will be migrated by email address.

## 3. Content Rules

### 3.1 Style

- **Heading levels:** page title is `H1` (auto-generated). Top-level sections start at `==` (H2). Do not use `=` for section headings inside page body.
- **Lists:** `*` for unordered, `#` for ordered. Indent sub-items with `**` / `##`; do not mix.
- **Code:** use `<syntaxhighlight lang="…">` with one of: `bash`, `javascript`, `php`, `python`, `ini`, `yaml`, `diff`, `text`. Raw `<pre>` is only for fixed-width non-code output.
- **Internal links:** `[[Page Name]]` or `[[Page Name|display text]]`. Do not use full URLs for pages that live on the same wiki.
- **Units:** metric first, imperial in parentheses where relevant. Nissan part numbers verbatim, no added dashes.

### 3.2 Accuracy

- Cite every factual claim about a car, part, or procedure using `<ref>` and the `{{Cite}}` template. Service-manual citations must include the manual title, publication year, and page or section number.
- Do not copy paragraphs from forums, Facebook groups, or other wikis. Summarise in your own words, then cite the source.
- If you cannot verify a claim, mark it with `{{citation needed}}` rather than deleting it.

### 3.3 Media Licensing

Uploaded images must be one of:

- Your own photo, released under CC BY-SA 4.0 (default when you click "own work" at upload).
- A photo with a compatible free license — CC BY, CC BY-SA, or public domain. Record the source URL and author in the upload summary.
- An official Nissan technical diagram used under fair dealing / fair use — tag with `{{Fair use}}` and keep the image resolution low.

Do not upload screenshots of copyrighted PDFs or paid workshop manuals.

## 4. Templates

Before creating a new page, check whether a template already covers the content type. As of the current roadmap (`docs/wiki_options.md` §4), the following are planned:

- `Template:PartInfobox` — single parts (fields: number, name, generation, OEM/aftermarket, price range, supersession).
- `Template:GenerationInfobox` — WGC34, WGNC34, M35 summary blocks.
- `Template:Meet` — community events (date, location, host, report link).
- `Template:Workshop` — specialist workshops (name, address, services, ratings).
- `Template:HowTo` — step-by-step procedures with required tools and difficulty rating.
- `Template:TroubleshootingStep` — used inside diagnostic flowcharts.

When a template exists and fits, use it; do not duplicate its fields as freeform prose.

## 5. Version Control

Every save writes a new revision. Use the "Summary" field on every edit — minimum useful content is a verb phrase ("fix part number for WGNC34 turbo", "add photo of engine bay"). Revisions can be reverted by sysops; bulk vandalism is handled via `Special:Nuke`.

## 6. Reporting Issues

- **Typo or small factual fix:** fix it yourself, no issue needed.
- **Broken internal link:** fix the link inline.
- **Broken external link:** replace with archive.org if possible; otherwise comment out with `<!-- -->` and tag the page for attention.
- **Disputed content or vandalism:** use the page's `Talk:` tab; do not edit-war on the main page.
- **Extension/infra bug** (e.g. VisualEditor crashes, SSO redirect loop): open an issue on this monorepo with the `wiki` label.

## 7. Code of Conduct

Be useful, be accurate, be civil. Personal attacks, harassment, and off-topic politics get a single warning and then a block. The wiki administrator listed in `Project:Administrators` has final say.

## 8. Contact

- **Day-to-day questions:** post on the relevant page's `Talk:` tab.
- **Account, permissions, extension requests:** see `Project:Administrators` on the wiki.
- **Repo- or infra-level issues:** open an issue on this monorepo and tag it `wiki`.
