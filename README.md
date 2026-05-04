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
│   ├── terraform/           # Modular DigitalOcean-first IaC (providers, variables, DO resources, GitHub secret sync)
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
   - `.github/workflows/terraform-infra.yml` is the only infrastructure workflow (PR validate + manual plan/apply/destroy-recreate).
   - `.github/workflows/app-ci-build.yml` builds images and publishes to GHCR.
   - `.github/workflows/app-cd-deploy.yml` is a manual Argo CD sync for dev/prod.

## Runbook (What You Need + How To Run)

### Prerequisites

- Docker Engine + Docker Compose plugin
- Terraform >= 1.5
- GitHub repository admin access (for Actions secrets and workflow runs)
- DigitalOcean account + API token + SSH key registered in DO

### Required configuration

1. Local app runtime (`.env`):
   - Copy `.env.example` to `.env`
   - Fill DB, JWT, and Influx values before starting containers

2. Terraform secrets (used by `.github/workflows/terraform-infra.yml`):
   - `TF_VAR_do_token`
   - `TF_VAR_github_token`
   - `TF_VAR_github_owner`
   - `TF_VAR_github_repo`
   - `TF_VAR_argocd_server`
   - `TF_VAR_argocd_auth_token`
   - `TF_VAR_ssh_key_ids` (must be HCL list string like `["fingerprint-or-id"]`)
   - `TF_VAR_do_ssh_host_fingerprint`
   - `TF_STATE_BUCKET`
   - `TF_STATE_REGION`
   - `TF_STATE_ENDPOINT`
   - `TF_STATE_ACCESS_KEY`
   - `TF_STATE_SECRET_KEY`
   - Optional key prefix override: `TF_STATE_KEY_PREFIX`

3. Deploy workflow secrets (used by `.github/workflows/app-cd-deploy.yml`):
   - Set these in GitHub Environment secrets (not repository-level only):
     - `development` for `deploy-dev`
     - `production` for `deploy-prod`
   - `ARGOCD_SERVER`
   - `ARGOCD_AUTH_TOKEN`

### Run locally

Development stack:

```bash
cp .env.example .env
docker compose -f docker-compose.yml -f docker-compose-dev.yml up -d
docker compose ps
```

Production-like local stack:

```bash
cp .env.example .env
docker compose -f docker-compose.yml -f docker-compose-prod.yml up -d
docker compose ps
```

Stop and clean local stack:

```bash
docker compose -f docker-compose.yml -f docker-compose-dev.yml down
docker compose -f docker-compose.yml -f docker-compose-prod.yml down
```

### Run Terraform (environment roots)

Validate `dev` without backend:

```bash
cd infrastructure/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init -backend=false -input=false
terraform validate
terraform plan -input=false
```

Validate `prod` without backend:

```bash
cd infrastructure/terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
terraform init -backend=false -input=false
terraform validate
terraform plan -input=false
```

Remote backend mode (per environment):

```bash
cd infrastructure/terraform/environments/dev
terraform init -reconfigure -backend-config=backend.conf -backend-config="key=environments/dev/terraform.tfstate"
terraform plan -input=false
```

Root shortcuts (recommended):

```bash
make tf-init-dev
make tf-init-prod
```

State migration details are in `infrastructure/terraform/MIGRATION.md`.

### Workflow usage

- `terraform-infra.yml`
  - PR to `main`: fmt + validate on Terraform changes
  - Manual run: choose `environment` (`dev`/`prod`) and mode (`plan-only`/`apply`/`destroy-recreate`)
- `app-ci-build.yml`
  - PR to `main`: build/validate only
  - Push to `main` or tag `v*`: build and push GHCR images
- `app-cd-deploy.yml`
  - Manual run: trigger Argo CD sync for `dev`/`prod`

## Terraform clean slate

Terraform now runs only from environment roots:

- `infrastructure/terraform/environments/dev`
- `infrastructure/terraform/environments/prod`

Quick local check:

```bash
cd infrastructure/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init -backend=false -input=false
terraform validate
terraform plan -input=false
```

Use the runbooks for backend/state work:

- `infrastructure/terraform/README.md`
- `infrastructure/terraform/MIGRATION.md`

## Current CI/CD + Observability Flow (2026)

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
  - `TF_VAR_argocd_server`
  - `TF_VAR_argocd_auth_token`

### State key convention

- Environment-only state split is used.
- State key format:
  - `${TF_STATE_KEY_PREFIX:-environments}/{environment}/terraform.tfstate`

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

## GHCR clean slate

If you want to purge existing container versions and Actions caches before rebuilding the pipeline:

```bash
chmod +x infrastructure/scripts/ghcr-clean-slate.sh
infrastructure/scripts/ghcr-clean-slate.sh <github_owner> FireMonitoringSystem
```

The script deletes package versions for `api`, `etl-processor`, and `dashboard`, then clears GitHub Actions caches for the repository.

## Terraform migration quick links

- Layout and local usage: `infrastructure/terraform/README.md`
- Safe state address migration: `infrastructure/terraform/MIGRATION.md`

