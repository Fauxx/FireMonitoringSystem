# Fire Monitoring Infrastructure Monorepo

This repository centralizes every component of the IoT fire-monitoring stack into a single, DevOps-friendly layout. Application code now lives under `api/`, `dashboard/`, and `etl-processor/` while infrastructure-as-code, broker configs, and SQL migrations sit under `infrastructure/`.

## Repository Guide (Codebase Structure + Tech Stack)

### 1) What this repository does
This monorepo powers an IoT fire monitoring platform. Sensor readings flow through MQTT into time-series storage, are transformed by an ETL service, then exposed through an API and dashboard.

### 2) High-level data flow
`MCU/Sensor -> MQTT (Mosquitto) -> Telegraf -> InfluxDB -> ETL Processor -> PostgreSQL -> API -> Dashboard`

### 3) Core directories
- `.github/workflows/`: CI/CD pipelines (build, deploy, terraform checks)
- `api/`: Node.js + Express backend (auth, sensor, analytics, metrics, sessions)
- `dashboard/public/`: static frontend pages (login/signup/protected dashboard)
- `etl-processor/`: Python ETL worker that syncs InfluxDB data into PostgreSQL
- `simulators/`: sensor data simulator that publishes mock MQTT payloads
- `infrastructure/`: deployment/runtime configs (Nginx, MQTT, Telegraf, SQL, Terraform, Prometheus/Loki/Grafana/Alloy)
- `docker-compose*.yml`: local/dev/prod-style service orchestration

### 4) Key technologies used
- **Backend API:** Node.js, Express, `pg`, `express-session`, `prom-client`
- **ETL/Data Processing:** Python, pandas, psycopg2, influxdb-client, loguru
- **Messaging/Ingestion:** Mosquitto (MQTT), Telegraf
- **Datastores:** InfluxDB (time-series), PostgreSQL (reporting/relational)
- **Web/UI Delivery:** Nginx + static HTML/CSS/JS dashboard
- **Observability:** Prometheus, Loki, Grafana, Grafana Alloy, cAdvisor, node-exporter
- **Infrastructure/Automation:** Docker Compose, Flyway, Terraform, GitHub Actions

### 5) How code is organized
- **API app entrypoint:** `api/src/server.js`
  - wires middleware, sessions, auth-gated routes, metrics endpoint (`/metrics`), and Grafana proxy (`/grafana`)
- **API routes:** `api/src/routes/`
  - `auth.js`, `api.js`, `analytics.js`, `messages.js`, `finalSensors.js`
- **ETL entrypoint:** `etl-processor/src/main.py`
  - fetches from Influx, transforms records, writes to `final_sensor_events`, `sensor_data_aggregated`, and `system_metrics`
- **MQTT simulator:** `simulators/mcu_sim.py`
  - publishes mock fire sensor payloads for local testing
- **Infra config:** `infrastructure/**`
  - service configs, SQL migrations, dashboards, monitoring, and IaC

## Directory Overview

```
.
├── .github/workflows        # CI/CD pipelines (build + deploy)
├── api/                     # Node.js / Express backend
│   ├── src/                 # Application code (server, routes, middleware)
│   └── tests/               # Placeholder for API tests
├── dashboard/               # Static web UI served via Nginx
│   ├── public/              # HTML + JS (protected dashboard bundle)
│   └── styles/              # Shared CSS
├── etl-processor/           # Python data mover (InfluxDB -> Postgres)
│   ├── app/                 # `etl_influx_to_postgres.py` plus helpers
│   ├── requirements.txt     # Python dependencies
│   └── Dockerfile           # Worker image definition
├── infrastructure/          # DevOps hub (configs + IaC)
│   ├── terraform/           # DigitalOcean droplet + firewall boilerplate
│   ├── nginx/conf.d/        # Reverse proxy config
│   ├── mqtt/                # Mosquitto config/data/log directories
│   ├── telegraf/            # Agent configuration
│   └── sql/                 # Database migrations and seed scripts
├── iot-firmware/            # ESP32 / Arduino sketches (placeholder)
├── docker-compose.yml       # Local orchestration across all services
├── .env / .env.example      # Centralized environment variables
└── .dockerignore / .gitignore
```

## Getting Started

1. **Copy the environment template**
   ```bash
   cp .env.example .env
   ```
   Set secure values for database, JWT, and Influx tokens before running anything. Ensure `INFLUXDB_URL` points to `http://influxdb:8086` for local Docker networking (or your managed Influx endpoint in prod).

2. **Choose a compose stack**
   ```bash
   # Development: reopens internal ports for easy access
   docker compose -f docker-compose.yml -f docker-compose-dev.yml up -d

   # Production-like: only Nginx is exposed; all other services stay on the bridge network
   docker compose -f docker-compose.yml -f docker-compose-prod.yml up -d
   ```
   - Base/prod: exposes only Nginx on 80/443; everything else remains internal.
   - Dev override: adds Postgres 5432, InfluxDB 8086, Grafana 3000, API 8000, MQTT 1883/9001, plus Nginx 80/443. Hot-reloads API by mounting `./api` into the container.

3. **Network sanity checks**
   ```bash
   docker compose ps
   docker compose exec api getent hosts postgres influxdb mqtt-broker
   docker compose exec api curl -f http://postgres:5432 || true
   # If running dev overrides: curl -f http://localhost:8000/health
   curl -f http://localhost/health
   ```
   Verifies container DNS inside the bridge network and host reachability via Nginx (and API directly when using the dev override).

4. **CI/CD**
   - `.github/workflows/ci-pr.yml` validates API, ETL, and Terraform on pull requests to `main`.
   - `.github/workflows/cd-main.yml` builds API/ETL Docker images and validates compose config on pushes to `main`.
   - `.github/workflows/infra.yml` runs manual Terraform init/validate/plan only (no auto-apply).

## Terraform local first run (non-interactive backend init)

Use this when initializing Terraform locally for the first time so `terraform init` never prompts for backend values.

1. Create local backend env from template:
   ```bash
   cp infrastructure/terraform/backend.local.env.example infrastructure/terraform/backend.local.env
   ```

2. Fill required values in `infrastructure/terraform/backend.local.env`:
   - `TF_STATE_BUCKET`
   - `TF_STATE_REGION`
   - `TF_STATE_ENDPOINT`
   - `TF_STATE_ACCESS_KEY`
   - `TF_STATE_SECRET_KEY`
   - Optional: `TF_WORKSPACE` (default `local`), `TF_STATE_KEY_PREFIX` (default `terraform/fire-monitoring`), `TF_BACKEND_KEY` override.

3. Run first-time local bootstrap:
   ```bash
   bash infrastructure/terraform/init-local-backend.sh
   ```
   This runs:
   - `terraform init -reconfigure -input=false` with backend config (same flags/shape as CI shared contract)
   - `terraform workspace select <workspace> || terraform workspace new <workspace>`

### One-time local state migration (local backend -> remote backend)

Use this only when you already have an existing local workspace state and want to copy it to remote state.

1. Ensure `infrastructure/terraform/backend.local.env` is filled.
2. Set migration mode and target workspace:
   ```bash
   export TF_INIT_MODE=migrate
   export TF_WORKSPACE=prod
   ```
3. Run migration:
   ```bash
   bash infrastructure/terraform/init-local-backend.sh
   ```
   This performs `terraform init -migrate-state -force-copy -input=false` with the same backend contract used in CI.
4. Validate migration:
   ```bash
   cd infrastructure/terraform
   terraform plan -input=false
   ```
   Expect no-op/minimal drift if remote state matches reality.

Rollback check:
- Before migration, keep a backup of local state files (`terraform.tfstate` and `terraform.tfstate.d/`).
- To return to local backend state:
  1. `cd /home/runner/work/FireMonitoringSystem/FireMonitoringSystem/infrastructure/terraform`
  2. `rm -rf .terraform`
  3. Restore your backup `terraform.tfstate` / `terraform.tfstate.d/`
  4. `terraform init -backend=false -input=false`
  5. `terraform workspace select <workspace>`

4. Validate and plan:
   ```bash
   cd infrastructure/terraform
   terraform validate
   terraform plan -input=false
   ```

5. Clean-state re-test (optional):
   ```bash
   rm -rf infrastructure/terraform/.terraform
   bash infrastructure/terraform/init-local-backend.sh
   ```

Troubleshooting:
- If bootstrap fails with `Missing required backend setting(s)`, update `infrastructure/terraform/backend.local.env`.
- If authentication fails, verify `TF_STATE_ACCESS_KEY` / `TF_STATE_SECRET_KEY`.
- If endpoint/region errors occur, verify `TF_STATE_ENDPOINT` and `TF_STATE_REGION` match your Spaces bucket region.

## Current CI/CD + Observability Flow (2026)

This is the current CI/CD structure in this repo:

- **PR validation pipeline (`ci-pr.yml`)**
  - Runs only on pull requests targeting `main`.
  - Uses path filtering (`api/**`, `etl-processor/**`, `infrastructure/**`) to avoid unnecessary runs.
  - Validates Node API dependencies/scripts, ETL dependencies/source syntax, and Terraform `fmt/init/validate`.
  - Uses branch-scoped concurrency cancellation and 10-minute job timeouts.
- **Main build pipeline (`cd-main.yml`)**
  - Runs only on pushes to `main`.
  - Builds Docker images for `api` and `etl-processor`.
  - Validates Compose configuration using `docker compose config -q`.
  - Uses concurrency cancellation and 10-minute timeout.
- **Manual infrastructure pipeline (`infra.yml`)**
  - Runs only by `workflow_dispatch`.
  - Executes Terraform `fmt`, `init`, `workspace`, `validate`, and `plan` with required secrets.
  - Supports `plan-only`, `apply`, and `destroy-recreate` simulation execution modes.

## Clean-slate Infrastructure Simulation (Restart Cloud)

- A shared Terraform contract is used across `ci-pr.yml`, `cd-main.yml`, and `infra.yml` via:
  - `.github/actions/terraform-contract/action.yml`
- `ci-pr.yml` intentionally uses backendless Terraform init for static validation.
- `cd-main.yml` and `infra.yml` support remote-state workflows with execution modes:
  - `plan-only`
  - `apply`
  - `destroy-recreate` (simulation)
- Remote Terraform state is externalized via DigitalOcean Spaces backend (`backend "s3" {}` in Terraform, runtime backend config in workflows).

### Required secrets by phase

- **Bootstrap-required (hard fail if missing):**
  - `TF_VAR_do_token`
  - `TF_VAR_github_token`
  - `TF_VAR_github_owner`
  - `TF_VAR_github_repo`
  - `TF_VAR_ssh_key_ids`
  - `TF_VAR_do_ssh_host_fingerprint`
  - `TF_STATE_BUCKET`
  - `TF_STATE_REGION`
  - `TF_STATE_ENDPOINT`
  - `TF_STATE_ACCESS_KEY`
  - `TF_STATE_SECRET_KEY`
- **Post-provision/generated (warning-only if missing during clean-slate bootstrap):**
  - `DO_SSH_HOST`
  - `DO_SSH_PORT`
  - `DO_SSH_USER`

### Workspace and state key convention

- Workspace is explicitly selected/created in all Terraform workflows.
- State key format:
  - `${TF_STATE_KEY_PREFIX:-terraform/fire-monitoring}/{workspace}.tfstate`

### Service dependency map (single-host runtime)

- **API**: requires PostgreSQL and internal bridge connectivity.
- **Dashboard**: requires API routes and Grafana proxy path `/grafana`.
- **ETL-Processor**: requires InfluxDB and PostgreSQL reachability.
- **MQTT pipeline**: MQTT broker ingress + Telegraf -> InfluxDB chain.
- **Terraform intent alignment**: current droplet/firewall model keeps service-to-service traffic internal on Docker network while exposing ingress through Nginx.

### Restart simulation outcomes

- **blank-project:** new workspace or empty state should show full-create plan.
- **existing-state:** converged infra should plan to no-op/minimal delta.
- **recovery:** partial drift should produce targeted reconciliation plan.

### Observability stack in Compose

- **Prometheus** scrapes service and host/container metrics.
- **Loki** stores centralized logs.
- **Grafana Alloy** collects Docker logs and forwards them to Loki.
- **Grafana** provides dashboards with provisioned datasources/dashboards from `infrastructure/grafana/**`.
- The stack is wired in `docker-compose.yml` with configs under `infrastructure/prometheus/`, `infrastructure/loki/`, and `infrastructure/alloy/`.

## Next Steps

- Wire the ETL container into Telegraf/MQTT once real sensor feeds are available.
- Extend Terraform with firewalls, managed databases, and monitoring as infrastructure requirements solidify.
- Add automated test coverage under `api/tests` and a frontend build pipeline when the dashboard grows.
- [Practice safe secrets management]
- another practice

## Grafana dashboards (versioned)
- Dashboards are provisioned from `infrastructure/grafana/dashboards` via `infrastructure/grafana/provisioning/dashboards/fire-dashboards.yaml`. Any JSON you commit there is auto-loaded on container start.
- Export updates from a running Grafana with an API token:
  ```bash
  GRAFANA_URL=http://localhost:3000 \
  GRAFANA_TOKEN=<admin-or-editor-token> \
  ./infrastructure/grafana/export_dashboards.sh <dashboard_uid>
  ```
  Commit the resulting `infrastructure/grafana/dashboards/<uid>.json` so prod/dev stay in sync.
- The web app proxies Grafana at `/grafana`; in dev you can disable auth by setting `GRAFANA_PROXY_PROTECT=false` (now the default in `docker-compose.yml`). In prod, set it to `true` and require a logged-in session before embedding.
