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
   ```powershell
   cd C:\Users\zet\Documents\GitHub\fire-monitoring-webapp
   Copy-Item .env.example .env
   ```
   Set secure values for database, JWT, and Influx tokens before running anything.

2. **Bootstrap the stack**
   ```powershell
   docker compose pull
   docker compose build
   docker compose up -d
   ```
   Services join the `fire-net` network automatically. The API listens on `:8000`, dashboard preview on `:8080`, and Nginx entrypoint exposes `:80/:443`.

3. **CI/CD**
   - `.github/workflows/build-push.yml` builds and publishes container images to GHCR.
   - `.github/workflows/deploy.yml` expects DigitalOcean SSH secrets to pull + restart the stack remotely.

## Next Steps

- Wire the ETL container into Telegraf/MQTT once real sensor feeds are available.
- Extend Terraform with firewalls, managed databases, and monitoring as infrastructure requirements solidify.
- Add automated test coverage under `api/tests` and a frontend build pipeline when the dashboard grows.
- [Practice safe secrets management]