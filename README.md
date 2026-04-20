# Fire Monitoring Infrastructure Monorepo

This repository centralizes every component of the IoT fire-monitoring stack into a single, DevOps-friendly layout. Application code now lives under `api/`, `dashboard/`, and `etl-processor/` while infrastructure-as-code, broker configs, and SQL migrations sit under `infrastructure/`.

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
   - `.github/workflows/build-push.yml` builds and publishes container images to GHCR.
    - `.github/workflows/deploy.yml` auto-deploys on successful `main` image builds (and supports manual dispatch), then pulls/restarts remotely over SSH.

## Current CI/CD + Observability Flow (2026)

This is the current production-oriented structure in this repo:

- **Build pipeline:** `build-push.yml` runs on pushes and PRs, builds `api`, `dashboard`, and `etl` images, then publishes tags to GHCR (`latest` on `main`, sanitized branch tags, and `sha-*` tags).
- **Deploy pipeline:** `deploy.yml` runs automatically after a successful `Build and Push Images` run on `main`, and can also be run manually for controlled rollbacks/testing.
- **Production gate:** deploy job targets GitHub `production` environment for approval controls and secret scoping.
- **Infra pipeline:** `terraform-plan.yml` runs PR-safe checks (`fmt`, `init -backend=false`, `validate`) without secrets; manual `workflow_dispatch` runs strict plan mode.
- **Secret model:** Terraform uses `require_secrets=false` for PR checks and `require_secrets=true` for manual apply/plan runs. Production secrets come from GitHub Environment/Repository secrets.

### Terraform lifecycle (GitHub Actions)

- **PR validation (`terraform-plan.yml`, pull_request):**
  - Runs `terraform fmt -check`, `terraform init -backend=false`, and `terraform validate`.
  - Uses `require_secrets=false` and does not perform mutable cloud operations.
- **Manual plan (`terraform-plan.yml`, workflow_dispatch):**
  - Requires Terraform secrets, supports backend init via `use_backend`, and selects `terraform_workspace` (default: `prod`).
  - Produces `tfplan.binary` and uploads artifact `terraform-plan-<run_id>` for reviewed handoff.
- **Manual apply (`terraform-apply.yml`, workflow_dispatch):**
  - Environment-gated (`production`) and concurrency-controlled (`terraform-production`).
  - Can apply from a freshly generated local plan or from a reviewed plan artifact using `plan_run_id` + `plan_artifact_name`.
  - Always validates workspace selection and plan file presence before apply.
- **State/backend expectation:**
  - Use backend mode (`use_backend=true`) for team/shared state and locking.
  - Local backend mode is intended for controlled/manual use only.

### Deployment approvals and trigger behavior

- `deploy.yml` runs on successful `Build and Push Images` for `main` or manual dispatch.
- Deploy targets the `production` environment, so pending approvals can leave runs in `action_required` with no jobs executed yet.
- Deploy image checks must match GHCR publish names from `build-push.yml` (`api`, `etl-processor`).

### Deployment incident checklist (SSH timeout / action_required)

1. **If run shows `action_required` with no jobs:**
   - Open the workflow run and approve the `production` environment gate.
   - Re-run only if the run remains non-started after approval or if it was previously cancelled/failed.
2. **If deploy fails with SSH timeout (`dial tcp ... i/o timeout`):**
   - Verify `DO_SSH_HOST` points to the current droplet IP.
   - Verify `DO_SSH_PORT` (default `22`) matches host SSH configuration.
   - Verify droplet firewall allows inbound TCP/22 from runner source ranges or route via bastion/self-hosted runner.
   - Verify `DO_SSH_FINGERPRINT` matches current host key after reprovisioning.
3. **If image resolution fails before SSH:**
   - Confirm image tags exist in GHCR for `ghcr.io/<repo>/api:<tag>` and `ghcr.io/<repo>/etl-processor:<tag>`.
4. **After remediation:**
   - Re-run deploy with an explicit known-good `image_tag` (and optional fallback settings).

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

# 🔥 Fire Monitoring System

A robust IoT monitoring solution integrating real-time sensor data, automated ETL processes, and a secure web dashboard.

---

## 🏗️ Technical Architecture
The system is built using a micro-services approach to ensure scalability and ease of deployment:

* **Ingestion:** `Mosquitto (MQTT)` -> `Telegraf` -> `InfluxDB (Time-series)`
* **Processing:** `ETL-Processor (Python)` (Syncs InfluxDB to Postgres for long-term reporting)
* **API:** `Node.js (Express)` (Serves data from Postgres/InfluxDB)
* **Gateway:** `Nginx` (Reverse proxy handling Dashboard and API routing)
* **Orchestration:** `Docker Compose` with automated `Flyway` migrations.

---

## 🚀 Implementation Roadmap (The "Tight" Build)

This roadmap outlines the path to a production-ready CI/CD deployment on DigitalOcean.

### Phase 1: Configuration & Environment Standards
- [ ] **Unified Variable Mapping:** Create a master `.env.example` in the root.
- [ ] **Network Hardening:** Ensure `fire-net` isolates internal databases from public ports.
- [ ] **Dockerignore Optimization:** Strip `node_modules`, `venv`, and `.git` from build contexts.

### Phase 2: Optimized Containerization (Efficiency & Cost)
- [ ] **Multi-Stage Builds (Node/Python):** Implement multi-stage Dockerfiles to keep production images under 200MB.
- [ ] **Pip/Npm Cache Mounts:** Use `--mount=type=cache` in Dockerfiles to speed up cloud builds and save bandwidth costs.
- [ ] **Startup Logic:** Refine `healthcheck` dependencies (DB ➔ Flyway ➔ API) to prevent "Race Condition" crashes.

### Phase 3: Infrastructure & Data Integrity
- [ ] **Flyway Schema Management:** Finalize versioned SQL migrations (`V1`, `V2`, etc.) for zero-downtime updates.
- [ ] **Telegraf Bridging:** Configure Telegraf to automatically map MQTT topics to InfluxDB buckets.
- [ ] **Nginx Reverse Proxy:** Setup path-based routing (`/api` for Node, `/grafana` for dashboards).

### Phase 4: CI/CD & Cloud Deployment (DigitalOcean)
- [ ] **GitHub Actions Workflow:**
   - **Linter/Test:** Automated code quality checks on every push.
   - **Build & Push:** Push images to DigitalOcean Container Registry (DOCR).
- [ ] **Automated CD:** SSH-based "Pull and Restart" on the DO Droplet.
- [ ] **SSL Security:** Automate Let's Encrypt certificates using a Certbot container.

### Phase 5: Monitoring & Maintenance
- [ ] **Resource Cleanup:** Implement `docker system prune` in the CI/CD pipeline to save disk space.
- [ ] **Log Rotation:** Configure Docker log limits to prevent the Droplet from running out of storage.

---

## 🛠️ Local Development

1. **Setup Environment:** `cp .env.example .env`
2. **Build Stack:** `docker-compose build`
3. **Launch:** `docker-compose up -d`
4. **Simulate Data:** `python simulators/mcu_sim.py`
