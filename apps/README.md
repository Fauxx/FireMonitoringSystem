# Applications Hub (Microservices Layer)

This directory contains the core application services that power the Fire Monitoring Platform. Each service is containerized independently and communicates internally via Kubernetes or Docker networks.

---

## 📂 Services Directory Index

| Microservice | Location | Role | Key Technologies | Documentation |
|:---|:---|:---|:---|:---|
| **Express API** | [`api/`](./api/) | Serving REST API, authentication gating, user approvals, reporting. | Node.js, Express, `pg`, `prom-client` | [**API Setup Guide 📖**](./api/README.md) |
| **Nginx Dashboard** | [`dashboard/`](./dashboard/) | Frontend interface, interactive analytics charts, user profiles. | Nginx, HTML5, Vanilla CSS, JS | [**Dashboard Guide 📖**](./dashboard/README.md) |
| **Python ETL** | [`etl-processor/`](./etl-processor/) | Subscribes to time-series streams, debounces alerts, aggregates logs. | Python, `pandas`, `psycopg2`, InfluxDB | [**ETL Guide 📖**](./etl-processor/README.md) |
| **MCU Simulator** | [`simulators/`](./simulators/) | Generates edge sensor streams to test alerting thresholds and networks. | Python, `paho-mqtt` | [**Simulator Guide 📖**](./simulators/README.md) |

---

## 🛠️ System Routing & Ingress Interaction
All applications communicate through an integrated Ingress-Nginx layout in staging/production, and are proxied locally by Nginx:
*   Incoming HTTP/S requests target the Nginx Dashboard `/` or API `/api` endpoints.
*   Protected paths require session verification. The dashboard delegates check to the API's `/auth/verify` endpoint.
*   MQTT sensor streams are published directly to Mosquitto on port `1883` (dev `18830`), which are parsed by Telegraf and pushed to InfluxDB before the ETL processor transforms it for Postgres.
