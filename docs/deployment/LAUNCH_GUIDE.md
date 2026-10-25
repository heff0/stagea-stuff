# Blog node launch guide (slice 9)

Copy-paste operator steps for `blog.stagea-stuff.com` after slice 9 (`518497a`). **How**, not why.

Phase 1 (host, DNS for apex / `www` / `forum` / `wiki`, first `./infra/deploy.sh`, NodeBB and MediaWiki wizards) is [GO_LIVE.md](./GO_LIVE.md). This file is the remainder from the slice 9 completion report. Run every command from the clone (`/opt/stagea`). `deploy.sh`, `backup.sh`, and `restore.sh` resolve the repo root themselves.

- **Slice card**: [slice 09 — Blog Node Online](./cards/slice_09_blog_node_online.md)
- **Compose, pins, Ghost owner detail**: [infra/README.md](../../infra/README.md)
- **Pre-traffic order**: [BOOT_PLAN.md](./BOOT_PLAN.md) Phase C, then backup after the blog volumes exist
- **Where the restore drill runs**: [ROLLOUT_PLAN.md](./ROLLOUT_PLAN.md) V18 / P14–P16

Official images only (`ghost:6.72`, `mysql:8.4`). Do not build the `blog/` **Submodule**. Do not start Saleor, the **Keycloak OIDC IdP**, or the **Directus Parts API**.

---

## 1. Deployment options

Three targets. Option A is the host that already serves `stagea-stuff.com`. Option B is a separate public VPS ([ROLLOUT_PLAN.md](./ROLLOUT_PLAN.md) Track V). Run Option C on a Proxmox KVM guest, then bring Option B up. §2–§6 are the same commands on the target you picked.

### Option A — Co-host on the existing host

Same `infra/compose.yaml` and same Caddy. The `blog.stagea-stuff.com` block in `infra/Caddyfile` reverse-proxies `blog:2368`. Caddy remains the only process on host ports `80` and `443`.

Finish §2 so `infra/.env` contains the blog keys and stays mode `600`. Create `A` and `AAAA` records for `blog.stagea-stuff.com` pointing at this host. TTL **300**. Confirm they resolve here before Caddy asks Let's Encrypt for that name:

```bash
dig +short blog.stagea-stuff.com
```

Phase 1 is already up, so start Ghost and MySQL only:

```bash
DEPLOY_HEALTH_TIMEOUT=300 ./infra/deploy.sh --module blog --with-db
```

`--module blog` pulls and starts `blog`. `--with-db` is valid only with `--module wiki` or `--module blog`. With `--module blog` it always includes `blog-db` and recreates that container (`up -d --no-deps --force-recreate --remove-orphans`) even when `blog-db` is already healthy. The script prints `blog-db included (--with-db)`. Without `--with-db`, `blog-db` is included only when it is missing or not healthy. The health-wait default is 120s; `DEPLOY_HEALTH_TIMEOUT` overrides it. `blog` `start_period` is 60s, and MySQL must be healthy first.

When Caddy is already running, that module deploy does not reload the bind-mounted `infra/Caddyfile`. Load the blog site block with:

```bash
./infra/deploy.sh --skip-git-pull --module caddy
```

Ghost and MySQL add about 1 GB of idle RAM (the planning model in [scaling_plan.md](./scaling_plan.md#2-idle-ram-budget) lists them at +0.9 GB). That is unsuitable on a 2 GB host that is already running forum and wiki. On the 8 GB Phase 1 host in [GO_LIVE.md](./GO_LIVE.md), Phase 2 still fits that budget.

### Option B — Dedicated VPS (Track V)

Any public Linux VPS. The provider is undecided (Track V). Clone at `/opt/stagea`. This host gets its own `infra/.env` and its own restic repository. First boot is the full-stack health-wait from §3. `--module blog` does not start Caddy, so it is not the first command on an empty host.

Create `A` and `AAAA` records for `blog.stagea-stuff.com` pointing at this VPS. TTL **300**. `dig +short` must show this host before Caddy starts:

```bash
dig +short blog.stagea-stuff.com
```

`infra/Caddyfile` also has site blocks for `stagea-stuff.com`, `www.stagea-stuff.com`, `app.stagea-stuff.com`, `forum.stagea-stuff.com`, and `wiki.stagea-stuff.com`. Those names stay on the Option A host. Comment those blocks out on this VPS before the first Caddy start (Track V step V6). Leave the `blog.stagea-stuff.com` block, and leave the global `acme_ca` line commented so issuance uses the production Let's Encrypt directory. A local edit to `infra/Caddyfile` makes `git pull --ff-only` fail, so skip the pull on deploy (command below).

Own env file. `./infra/deploy.sh` refuses a missing `infra/.env`, a world-readable file, or a mode more permissive than `0640`, and it refuses any empty required key. Copy the example, mode `600`, and fill every key that file lists, including `ACME_EMAIL`, `GHOST_CONTENT_API_KEY`, `BLOG_DB_NAME`, `BLOG_DB_USER`, `BLOG_DB_PASSWORD`, and `BLOG_DB_ROOT_PASSWORD`. New passwords (§2). This file is not the co-host's `infra/.env`. `SHELL_IMAGE` defaults to `ghcr.io/heff0/stagea-shell:main`; `deploy.sh` pulls images and does not build them (Track V step V7).

```bash
cp infra/.env.example infra/.env
chmod 600 infra/.env
```

Fill the keys, then:

```bash
./infra/deploy.sh --check
```

Exit check: the script prints `preflight ok`.

```bash
DEPLOY_HEALTH_TIMEOUT=300 ./infra/deploy.sh --skip-git-pull
```

Exit check: the health-wait covers `caddy`, `shell`, `forum`, `forum-redis`, `wiki`, `wiki-db`, `blog`, and `blog-db`. The `blog` summary row is `https://blog.stagea-stuff.com`.

Own restic repository. `./infra/backup.sh` runs `restic forget --prune` for tag `stagea`, so `RESTIC_REPOSITORY` is a bucket only this host writes. Required non-empty keys: `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`. Optional: `AWS_DEFAULT_REGION`, `RESTIC_KEEP_DAILY`, `RESTIC_KEEP_WEEKLY`, `RESTIC_KEEP_MONTHLY`. `RESTIC_PASSWORD` is not the object-storage secret. The bucket provider is not the VPS provider. `restic` must be on `PATH`. `infra/.env` is not inside the snapshot.

```bash
./infra/backup.sh --init
```

`--init` is once per repository, then the script exits. Snapshots after `blog_content` and `blog_db_data` exist are §6 (`./infra/backup.sh` with no flag). That path also `exec`s `wiki-db` and `forum-redis`. `set -euo pipefail` aborts the script when those commands fail, which is why the full deploy above has to leave those containers up.

### Option C — Proxmox KVM dry-run (Track P)

Run this before Option B goes live. Track P is a Proxmox **KVM** guest ([ROLLOUT_PLAN.md](./ROLLOUT_PLAN.md) §4). Nested Docker-in-LXC is forbidden. No public DNS: do not publish `A` or `AAAA` records for `blog.stagea-stuff.com` or the other Caddy names pointing at this guest.

Use the Let's Encrypt staging ACME endpoint. In `infra/Caddyfile`, uncomment the line that is already there:

```
acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
```

That directory is staging. On Option A and Option B the line stays commented (production directory). Comment it out again on any host that should receive a public certificate.

Own Track P `infra/.env` (new passwords from §2, not the Option B file). A local Caddyfile edit skips the pull:

```bash
cp infra/.env.example infra/.env
chmod 600 infra/.env
```

Fill the keys, then:

```bash
./infra/deploy.sh --check
DEPLOY_HEALTH_TIMEOUT=300 ./infra/deploy.sh --skip-git-pull
```

Exit check for `--check`: `preflight ok`.

Caddy's health check is `wget` against `http://127.0.0.1:2019/config/`. A healthy `caddy` row means the admin API answered. It does not mean a certificate was issued. With no public DNS, staging HTTP-01 for `blog.stagea-stuff.com` does not complete. The script proof below still runs: `deploy.sh` waits on container health, not on ACME.

Prove `backup.sh` against a lab-only repository. Fill non-empty `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY`. Both scripts `source` `infra/.env` with `set -a`, which overwrites exported `RESTIC_*` and `AWS_*`. Keep this repository off the Option B bucket (`backup.sh` would `forget --prune` anything else in a shared repo).

```bash
./infra/backup.sh --init
./infra/backup.sh
./infra/backup.sh --list
```

`STAGEA_BACKUP_STAGING` is the scratch directory for **both** scripts (backup default `/var/tmp/stagea-backup`, restore default `/var/tmp/stagea-restore`). The scripts read it before they source `infra/.env`, so export it for one invocation at a time.

The resident Caddy holds ports `80` and `443`. `restore.sh` finishes by starting project `stagea-restore`, including Caddy, on those ports. Stop the resident Caddy without deleting volumes, then drill:

```bash
docker compose -f infra/compose.yaml --env-file infra/.env stop caddy
./infra/restore.sh --list
./infra/restore.sh <snapshot-id>
```

Leave `STAGEA_RESTORE_PROJECT` unset. The script reads it before sourcing `infra/.env` and defaults to `stagea-restore`. It asks you to type the snapshot id again. Setting `STAGEA_RESTORE_PROJECT=stagea` in the environment targets production volume names; the script then requires the confirmation string `OVERWRITE-PRODUCTION`.

`down` removes the throwaway containers and leaves named volumes. A stopped container still holds its volume, so remove the containers before dropping the throwaway certificate volume. Then bring the resident Caddy back:

```bash
docker compose -p stagea-restore -f infra/compose.yaml --env-file infra/.env down
docker volume rm stagea-restore_caddy_data
rm -rf /var/tmp/stagea-restore
./infra/deploy.sh --skip-git-pull --module caddy
```

`docker compose down -v` deletes named volumes. Do not pass `-v`.

Exit check: `./infra/backup.sh --list` shows a `stagea` snapshot, and `restore.sh` prints `restore ok` plus elapsed seconds (RTO target is under 2 hours). Then proceed to Option B. The later drill that restores an Option B snapshot on Track P is §6 and [ROLLOUT_PLAN.md](./ROLLOUT_PLAN.md) V18 / P14–P16. For that drill, put the Option B `RESTIC_*` and `AWS_*` into the Track P `infra/.env` first (`restore.sh` overwrites exported variables), and comment those keys back out afterward.

---

## 2. Blog database keys

`./infra/deploy.sh` refuses to pull or start anything when `infra/.env` is missing `BLOG_DB_NAME`, `BLOG_DB_USER`, `BLOG_DB_PASSWORD`, or `BLOG_DB_ROOT_PASSWORD`, or when any of those values is empty. It prints the missing names and changes nothing. The same preflight also requires the Phase 1 keys already listed in `infra/.env.example`, including `GHOST_CONTENT_API_KEY` (the placeholder `change-me` is non-empty, so it passes preflight until §4).

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

## 3. DNS, then deploy

Option A, when Phase 1 is already up, uses `--module blog --with-db` from §1. This section is the full-stack deploy. Option B runs it with `--skip-git-pull` after the local Caddyfile edit in §1.

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

## 4. Ghost owner and Content API key

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

## 5. Mail stays stubbed until you choose SMTP

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

## 6. Backup, then the restore drill

Option C in §1 is the script dry-run on Track P before Option B has a public name. This section is the later drill: a snapshot taken after this launch, restored on Track P (or a throwaway host).

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

Search already calls the Ghost Content API. It uses `GHOST_CONTENT_API_KEY` and `BLOG_URL` (`https://blog.stagea-stuff.com/`). After §4, search can read posts. While the key is still `change-me`, that call has no real credential.

---

## Related

* [GO_LIVE.md](./GO_LIVE.md) — Phase 1 operator paste
* [BOOT_PLAN.md](./BOOT_PLAN.md) — Phase C blog, Phase E backup after blog volumes exist
* [ROLLOUT_PLAN.md](./ROLLOUT_PLAN.md) — V14 blog boot; V18 restore drill off the live VPS
* [slice 09 card](./cards/slice_09_blog_node_online.md) — acceptance criteria; items 4 and 6 open
* [infra/README.md](../../infra/README.md) — Ghost owner, mail stub, backup commands
* [production_plan.md](./production_plan.md) — service map and backup floor
