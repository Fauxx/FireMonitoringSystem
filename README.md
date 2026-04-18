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
   - `.github/workflows/build-push.yml` builds and publishes container images to GHCR.
    - `.github/workflows/deploy.yml` auto-deploys on successful `main` image builds (and supports manual dispatch), then pulls/restarts remotely over SSH.

## Current CI/CD + Observability Flow (2026)

This is the current production-oriented structure in this repo:

- **Build pipeline:** `build-push.yml` runs on pushes and PRs, builds `api`, `dashboard`, and `etl` images, then publishes tags to GHCR (`latest` on `main`, sanitized branch tags, and `sha-*` tags).
- **Deploy pipeline:** `deploy.yml` runs automatically after a successful `Build and Push Images` run on `main`, and can also be run manually for controlled rollbacks/testing.
- **Production gate:** deploy job targets GitHub `production` environment for approval controls and secret scoping.
- **Infra pipeline:** `terraform-plan.yml` runs PR-safe checks (`fmt`, `init -backend=false`, `validate`) without secrets; manual `workflow_dispatch` runs strict plan mode.
- **Secret model:** Terraform uses `require_secrets=false` for PR checks and `require_secrets=true` for manual apply/plan runs. Production secrets come from GitHub Environment/Repository secrets.

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
