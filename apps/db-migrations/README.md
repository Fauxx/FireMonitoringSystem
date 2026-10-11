# 🗄️ Database Migrations (`db-migrations`)

Flyway database schema migration management for PostgreSQL.

---

## 📂 Structure

```text
apps/db-migrations/
├── Dockerfile           # Flyway 10 + gcloud IAM access token generator
├── .dockerignore        # Build context filter
└── sql/                 # Versioned migration scripts
    ├── V1__Initial_Schema.sql
    ├── ...
    ├── V19__Add_Coordinates_To_Simulators.sql
    └── manual/          # Ad-hoc maintenance scripts
```

---

## 🚀 How It Works

* **CI/CD Build**:
  Whenever files in `apps/db-migrations/**` change, GitHub Actions (`app-pipeline.yml`) builds and pushes the image:
  `ghcr.io/fauxx/firemonitoringsystem-v2/db-migrations:<tag>`
* **Kubernetes Execution**:
  Runs as a **Kubernetes Job** (`flyway-migrate`) managed by ArgoCD in **Sync Wave 5**. It applies all pending migrations against PostgreSQL before API/ETL services start in **Sync Wave 10**.
* **Local Development**:
  In `build/local/docker-compose.local.yml`, `./apps/db-migrations/sql` is mounted directly into the `flyway/flyway:10-alpine` service.

---

## 📝 Adding New Migrations

1. Create a new file in `sql/` following Flyway naming conventions:
   `V<NextNumber>__<Description>.sql` (e.g. `V20__Add_Device_Status.sql`).
2. Test locally:
   ```bash
   make up
   ```
3. Commit and push: The CI/CD pipeline builds the new migration image, updates GitOps overlays, and ArgoCD automatically executes the migration job.
