# Blog node launch guide (slice 9)

Copy-paste operator steps for `blog.stagea-stuff.com` after slice 9 (`518497a`). **How**, not why.

Phase 1 (host, DNS for apex / `www` / `forum` / `wiki`, first `./infra/deploy.sh`, NodeBB and MediaWiki wizards) is [GO_LIVE.md](./GO_LIVE.md). This file is the remainder from the slice 9 completion report. Run every command from the clone (`/opt/stagea`). `deploy.sh`, `backup.sh`, and `restore.sh` resolve the repo root themselves.

- **Slice card**: [slice 09 — Blog Node Online](./cards/slice_09_blog_node_online.md)
- **Compose, pins, Ghost owner detail**: [infra/README.md](../../infra/README.md)
- **Pre-traffic order**: [BOOT_PLAN.md](./BOOT_PLAN.md) Phase C, then backup after the blog volumes exist
- **Where the restore drill runs**: [ROLLOUT_PLAN.md](./ROLLOUT_PLAN.md) V18 / P14–P16

Official images only (`ghost:6.72`, `mysql:8.4`). Do not build the `blog/` **Submodule**. Do not start Saleor, the **Keycloak OIDC IdP**, or the **Directus Parts API**.

---

## 1. Blog database keys

`./infra/deploy.sh` refuses to pull or start anything when `infra/.env` is missing `BLOG_DB_NAME`, `BLOG_DB_USER`, `BLOG_DB_PASSWORD`, or `BLOG_DB_ROOT_PASSWORD`, or when any of those values is empty. It prints the missing names and changes nothing. The same preflight also requires the Phase 1 keys already listed in `infra/.env.example`, including `GHOST_CONTENT_API_KEY` (the placeholder `change-me` is non-empty, so it passes preflight until §3).

`infra/.env` must stay mode `600` (or at most `0640`). A world-readable file, or a mode more permissive than `0640`, is also a refusal.

Generate a unique password for each password key. Do not reuse `WIKI_DB_PASSWORD` or `WIKI_DB_ROOT_PASSWORD`. `BLOG_DB_NAME` and `BLOG_DB_USER` may stay the example values `ghost` and `ghost`.

```bash
cd /opt/stagea
openssl rand -base64 32
```

Append to `infra/.env` (inventory is `infra/.env.example`):

```bash
BLOG_DB_NAME=ghost
BLOG_DB_USER=ghost
BLOG_DB_PASSWORD=<unique>
BLOG_DB_ROOT_PASSWORD=<unique>
```

```bash
chmod 600 infra/.env
./infra/deploy.sh --check
```

Exit check: the script prints `preflight ok`.

MySQL reads `BLOG_DB_NAME`, `BLOG_DB_USER`, `BLOG_DB_PASSWORD`, and `BLOG_DB_ROOT_PASSWORD` when the `blog_db_data` volume is first created. Set them before the first blog deploy.

---

## 2. DNS, then deploy

Create `A` and `AAAA` records for `blog.stagea-stuff.com` pointing at this host. TTL **300** while iterating. Confirm they resolve here before Caddy asks Let's Encrypt for that name.

```bash
dig +short blog.stagea-stuff.com
```

First Ghost boot often exceeds the 120s health-wait default (`blog` `start_period` is 60s, and MySQL must be healthy first):

```bash
DEPLOY_HEALTH_TIMEOUT=300 ./infra/deploy.sh
```

That full deploy health-waits `caddy`, `shell`, `forum`, `forum-redis`, `wiki`, `wiki-db`, `blog`, and `blog-db`. The summary row for `blog` is `https://blog.stagea-stuff.com`.

If Caddy was already running, a full `up` does not reload the bind-mounted `infra/Caddyfile`. Load `blog.stagea-stuff.com` with:

```bash
./infra/deploy.sh --skip-git-pull --module caddy
```

`--module caddy` runs `caddy reload` inside the existing container, or recreates `caddy` only when reload fails. It does not recreate Ghost.

```bash
curl -I https://blog.stagea-stuff.com
```

Exit check: HTTPS (a real certificate, not an ACME error page). Ghost admin is not created yet. Nothing on the host publishes `2368` or MySQL `3306`. Database host inside Compose is `blog-db`.

---

## 3. Ghost owner and Content API key

1. Open `https://blog.stagea-stuff.com/ghost/` and create the owner account.
2. In Ghost admin: **Settings → Integrations → custom integration**. Copy the Content API key.
3. In `infra/.env`, replace the placeholder:

```bash
GHOST_CONTENT_API_KEY=change-me
```

with the key from that integration (one line, no spaces). `change-me` is only the example value. An empty `GHOST_CONTENT_API_KEY` makes `./infra/deploy.sh` refuse.

4. Recreate the **Astro Shell** so it receives the key (`GHOST_CONTENT_API_KEY` is already in the `shell` service environment):

```bash
./infra/deploy.sh --module shell
```

`--module shell` pulls and runs `up -d --no-deps` for `shell` only. Forum, wiki, and blog stay up. `--with-db` is valid only with `--module wiki` or `--module blog`; do not pass it here.

Exit check: `https://blog.stagea-stuff.com/ghost/` opens the admin for the owner you created. A published post is still on the blog after a later `./infra/deploy.sh`.

---

## 4. Mail stays stubbed until you choose SMTP

Mail is off on purpose. `infra/compose.yaml` on the `blog` service sets:

| Key | Current value | Effect |
| :--- | :--- | :--- |
| `mail__transport` | `stub` | Nodemailer accepts the message and drops it |
| `security__staffDeviceVerification` | `"false"` | Owner setup does not wait for an email code |

Those keys are Compose environment on `blog`, not entries in `infra/.env`. `deploy.sh` does not read them.

The Ghost image has no sendmail. Keep `mail__transport` off `Direct` — that path calls sendmail and fails quietly.

To send mail later, edit the `blog` service environment in `infra/compose.yaml`:

1. Set `mail__transport` to `SMTP`.
2. Add `mail__options__*` for the provider in that same `environment:` block. This repo already uses `mail__options__host` and `mail__options__port` for SMTP (`blog/compose.dev.yaml`) and `mail__options__auth__api_key` / `mail__options__auth__domain` for Mailgun (`blog/compose.dev.mailgun.yaml`). Put the provider's auth fields under the same `mail__options__` prefix. Do not add them to `infra/.env`; nothing in `deploy.sh` forwards mail settings from that file.
3. Leave `security__staffDeviceVerification` at `"false"` until a test message is actually delivered. Then set it to `"true"`.

A local edit to `infra/compose.yaml` makes `git pull --ff-only` fail, so skip the pull and recreate blog only:

```bash
./infra/deploy.sh --skip-git-pull --module blog
```

`--module blog` leaves `blog-db` running when it is already healthy. Pass `--with-db` only when you intend to bounce MySQL too (`./infra/deploy.sh --skip-git-pull --module blog --with-db`).

---

## 5. Backup, then the restore drill

Checklist items **4** and **6** on the [slice 9 card](./cards/slice_09_blog_node_online.md) stay open. This section is the backup re-run and the restore drill, which are operator work after the volumes exist. It does not close those two boxes.

`./infra/backup.sh` refuses unless `restic` is on `PATH` and `infra/.env` has non-empty `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY`. Optional: `AWS_DEFAULT_REGION`, `RESTIC_KEEP_DAILY`, `RESTIC_KEEP_WEEKLY`, `RESTIC_KEEP_MONTHLY`. `RESTIC_PASSWORD` is not the object-storage secret. The bucket provider is not the VPS provider. `infra/.env` is not inside the snapshot.

After `blog` and `blog-db` are healthy, the named volumes `blog_content` and `blog_db_data` exist. Re-run the backup so the snapshot includes them. The script runs `mysqldump --single-transaction --no-tablespaces` as `BLOG_DB_USER` into `blog-mysql.sql`, and tars both volumes. The logical dump is the restore source; the `blog_db_data` tar is forensic only.

```bash
./infra/backup.sh
./infra/backup.sh --list
```

Exit check: `--list` shows a new `stagea` snapshot.

### Restore drill

Run the drill on Track P (or a throwaway host), not on the live VPS while production Caddy holds ports `80` and `443`. `./infra/restore.sh` finishes by starting the whole throwaway stack, including Caddy, with the restored production certificate material. See [ROLLOUT_PLAN.md](./ROLLOUT_PLAN.md) V18 and P14–P16. On Track P, point `RESTIC_*` and `AWS_*` at the production snapshot set for the drill, and comment those keys back out of the resident Track P `infra/.env` afterward — `restore.sh` sources `infra/.env` and that overwrites exported variables.

`STAGEA_BACKUP_STAGING` is the scratch directory for **both** scripts (backup default `/var/tmp/stagea-backup`, restore default `/var/tmp/stagea-restore`). Set it for one script at a time.

```bash
./infra/restore.sh --list
./infra/restore.sh <snapshot-id>
```

The script asks you to type the snapshot id again. Default Compose project is `stagea-restore` (`STAGEA_RESTORE_PROJECT`). It restores the `blog_content` volume and imports `blog-mysql.sql` into `blog-db`. It does not unpack `blog_db_data` over the data directory. It does not restore `infra/.env`.

Leave `STAGEA_RESTORE_PROJECT` at `stagea-restore`. Setting it to `stagea` targets production volume names; the script then requires the confirmation string `OVERWRITE-PRODUCTION`.

The script prints elapsed seconds. Record that wall-clock (RTO target is under 2 hours). Confirm a known forum post, a known wiki edit, and a known blog post from a snapshot taken after this launch.

Tear down the throwaway project without `-v`:

```bash
docker compose -p stagea-restore -f infra/compose.yaml --env-file infra/.env down
rm -rf /var/tmp/stagea-restore
```

`docker compose down -v` deletes named volumes. Do not use `-v` on the production project `stagea`.

### Still open on the slice 9 card

- **4. Test** — Publish a post, `docker compose -f infra/compose.yaml --env-file infra/.env down` (no `-v`), then `./infra/deploy.sh`, and confirm the post is still there. The Shell home-page summary half of that check waits on the gap below. Needs the VPS; not run in `518497a`.
- **6. Review** — Phase 2 content is complete only after this operator bootstrap and the persistence test.

---

## Known gap

The **Astro Shell** home page does not render post summaries. That still needs a Shell change.

Search already calls the Ghost Content API. It uses `GHOST_CONTENT_API_KEY` and `BLOG_URL` (`https://blog.stagea-stuff.com/`). After §3, search can read posts. While the key is still `change-me`, that call has no real credential.

---

## Related

* [GO_LIVE.md](./GO_LIVE.md) — Phase 1 operator paste
* [BOOT_PLAN.md](./BOOT_PLAN.md) — Phase C blog, Phase E backup after blog volumes exist
* [ROLLOUT_PLAN.md](./ROLLOUT_PLAN.md) — V14 blog boot; V18 restore drill off the live VPS
* [slice 09 card](./cards/slice_09_blog_node_online.md) — acceptance criteria; items 4 and 6 open
* [infra/README.md](../../infra/README.md) — Ghost owner, mail stub, backup commands
* [production_plan.md](./production_plan.md) — service map and backup floor
