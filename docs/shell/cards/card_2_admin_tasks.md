# Sprint Card 2: Factor XII Administration Scripts

## 🎯 1. Overview & Business Case
Following the 12-factor spec (**Factor XII: Admin Processes**), any administrative or maintenance tasks (database backups, schema migrations, user seeding) must run in the exact same environment and against the exact same release builds as our long-running application processes, executed as one-off commands.

This card establishes the blueprint to create a central, version-controlled administration task harness for our database backends.

---

## 🛠 2. Technical Solution & Code Blueprint
We will introduce an isolated administration task script directory `/services/admin` in our monorepo. This directory will contain automated shell scripts designed to be executed via short-lived, transient Docker containers.

### Monorepo Administration Directory Structure
```
stagea-stuff/
└── services/
    └── admin/
        ├── db_backup.sh        # Performs hot pg_dump/mongodump SQL outputs
        ├── db_migrate.sh       # Triggers database migrations
        └── Dockerfile          # Admin runner containing database CLI packages
```

### Script Blueprint: PostgreSQL Backup (`services/admin/db_backup.sh`)
```bash
#!/bin/sh
set -e # Exit immediately if a command exits with a non-zero status

echo "=== [12-Factor Admin] Initializing PostgreSQL Hot Backup ==="

# Validate environmental backing parameters (Factor III)
if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL variable is not set."
    exit 1
fi

BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="${BACKUP_DIR}/stagea_backup_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "Streaming pg_dump from attached resource..."
# Stream hot dump and compress on-the-fly directly to our mounted volume
pg_dump "$DATABASE_URL" | gzip > "$FILENAME"

echo "=== Backup completed successfully: ${FILENAME} ==="
```

### Running the Script as a One-Off Container
Add an admin service to the root `compose.yaml` (without publishing any port, ensuring network isolation):
```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: stagea_db
      POSTGRES_PASSWORD: password

  # One-off admin task container (Factor XII)
  admin-task:
    image: postgres:16-alpine # Reuses the same image carrying pg_dump CLI
    entrypoint: ["/bin/sh", "/scripts/db_backup.sh"]
    environment:
      - DATABASE_URL=postgres://postgres:password@postgres/stagea_db
    volumes:
      - ./services/admin:/scripts:ro
      - ./backups:/backups
    depends_on:
      - postgres
```

Launch the one-off backup command using standard docker-compose CLI commands:
```bash
docker compose run --rm admin-task
```

---

## 📋 3. MVP Acceptance Criteria
1. Database backups are written as **version-controlled scripts** inside the repository.
2. The task container reuses environmental parameters (`DATABASE_URL`), ensuring 12-factor configuration parity.
3. Running the script launches a transient Docker process that completely cleans up after completion (`--rm`).
4. Script outputs SQL files to a persistent host-mounted volume directory.

---

## 🚦 4. 6-Step Feature Loop Checklist
- [ ] **1. Scaffold**: Create `services/admin/` folder and placeholder shell scripts.
- [ ] **2. Document**: Record database credentials and script options inside a local README.
- [ ] **3. MVP Spec**: Formulate target backup variables and file structure limits.
- [ ] **4. Test**: Run a local mock container to verify `pg_dump` exits cleanly under success.
- [ ] **5. Implement**: Write `db_backup.sh` and integrate into the main Docker Compose stacks.
- [ ] **6. Review**: Verify the generated SQL archive can be cleanly restored into a fresh PostgreSQL instance.
