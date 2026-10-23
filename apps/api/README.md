# 🟢 FireMonitor — Backend REST API (`apps/api/`)

[![Runtime](https://img.shields.io/badge/Runtime-Node.js%2022-green.svg)](https://nodejs.org/)
[![Framework](https://img.shields.io/badge/Framework-Express.js-lightgrey.svg)](https://expressjs.com/)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%20%2F%20Cloud%20SQL-blue.svg)](https://www.postgresql.org/)
[![Metrics](https://img.shields.io/badge/Metrics-Prometheus-orange.svg)](https://prometheus.io/)
[![Security](https://img.shields.io/badge/User-UID%201000%20(node)-blueviolet.svg)](#)

The **FireMonitor REST API** is the central data orchestration and session controller service. Built with Express.js, it manages authenticated user sessions, interfaces with managed PostgreSQL (Google Cloud SQL), aggregates incident telemetry, and proxies in-cluster observability data (Prometheus and Loki) directly to the operator dashboard.

---

## 🏗️ Architecture & Integration

```mermaid
flowchart TD
    Client[Dashboard UI / Ingress] -->|HTTP / JSON Requests| API[Express REST API :8000]

    subgraph Core ["API Internal Services"]
        API --> Auth[Session & Auth Handler]
        API --> Telemetry[Device & Telemetry Router]
        API --> ObsProxy[Observability Proxy Router]
        API --> Health[Health Probes & Metrics]
    end

    subgraph Data ["Data & Storage"]
        Auth <-->|connect-pg-simple| PG[(PostgreSQL / Cloud SQL)]
        Telemetry <-->|Parameterized Queries| PG
    end

    subgraph Monitoring ["Cluster Observability"]
        ObsProxy <-->|PromQL Query API| Prom[Prometheus :9090]
        ObsProxy <-->|LogQL Query API| Loki[Loki :3100]
        Health -->|Scraped by| Prom
    end
```

---

## 📡 API Endpoint Reference

### 1. Authentication & Session (`/auth`)
| HTTP Verb | Endpoint | Access Level | Description |
|---|---|---|---|
| `POST` | `/auth/login` | Public | Authenticates credentials with `bcrypt`, initializes cookie session, and executes explicit `req.session.save()` to guarantee persistence. |
| `POST` | `/auth/logout` | Authenticated | Destroys current session and clears cookie. |
| `GET` | `/auth/me` | Authenticated | Returns currently authenticated user record and role. |
| `GET` | `/auth/verify` | Authenticated | Subrequest verification endpoint used by Nginx `auth_request` gateway; injects `X-WEBAUTH-USER` and `X-USER-ROLE` headers. |
| `POST` | `/auth/register` | Public | Submits registration request to the pending approval queue. |

### 2. Device Registry & Fleet (`/api/devices`)
| HTTP Verb | Endpoint | Access Level | Description |
|---|---|---|---|
| `GET` | `/api/devices` | Authenticated | Lists all registered IoT nodes (`h_id`, `lat`, `lon`, `barangay`, `structure_type`), joining real-time telemetry while preserving historical last-known states during disconnection. |

### 3. Sensor Telemetry (`/api/final-sensors` & `/api/telemetry`)
| HTTP Verb | Endpoint | Access Level | Description |
|---|---|---|---|
| `GET` | `/api/final-sensors/latest` | Authenticated | Fetches latest sensor readings per device from the normalized `final_sensor_latest` relational view. |
| `GET` | `/api/final-sensors/history` | Authenticated | Returns bounded historical telemetry with timestamp filtering. |
| `GET` | `/api/telemetry/active` | Authenticated | Summarizes active alerts and device states. |

### 4. Historical Analytics (`/api/analytics`)
| HTTP Verb | Endpoint | Access Level | Description |
|---|---|---|---|
| `GET` | `/api/analytics/devices` | Authenticated | Returns distinct active sensor identifiers. |
| `GET` | `/api/analytics/hourly` | Authenticated | Calculates hourly rollups of temperature, smoke, and flame metrics. |
| `GET` | `/api/analytics/heatmap` | Authenticated | Daily incident distribution heatmap aligned to Asia/Manila (PHT) timezone. |
| `GET` | `/api/analytics/stats` | Authenticated | High-level summary of active incidents, resolved emergencies, and total alerts. |

### 5. In-Cluster Observability Proxy (`/api/observability`)
| HTTP Verb | Endpoint | Access Level | Description |
|---|---|---|---|
| `GET` | `/api/observability/metrics` | Authenticated | Queries Prometheus directly for container CPU and resident memory usage. |
| `GET` | `/api/observability/logs` | Authenticated | Queries Loki via LogQL over dynamic namespaces (`CURRENT_NAMESPACE`). Automatically resolves container stream aliases (`fleet-runner`, `mosquitto`, `postgres|cloud-sql-proxy`, `influxdb`). |
| `GET` | `/api/observability/logs/errors` | Authenticated | Traps high-severity error logs across cluster workloads for rapid diagnostics. |

### 6. User Management & Administration (`/api/users`)
| HTTP Verb | Endpoint | Access Level | Description |
|---|---|---|---|
| `GET` | `/api/users` | Admin | Lists all user accounts. |
| `POST` | `/api/users` | Admin | Directly provisions a new user with assigned role. |
| `PUT` | `/api/users/:id` | Admin | Updates user information and role assignments. |
| `DELETE` | `/api/users/:id` | Admin | Deletes user record. |
| `GET` | `/api/users/pending` | Admin | Retrieves users waiting in the registration approval queue. |
| `POST` | `/api/users/approve` | Admin | Approves a pending user account. |

### 7. Health & Metrics
| HTTP Verb | Endpoint | Access Level | Description |
|---|---|---|---|
| `GET` | `/health` | Public | Deep health probe verifying active database pool connectivity for Kubernetes liveness/readiness checks. |
| `GET` | `/metrics` | Public | Standard Prometheus scraping endpoint instrumented via `prom-client` (`http_request_duration_seconds`, process CPU/RAM, event loop lag). |

---

## 🔒 Security & Reliability Engineering

*   **Session Persistence Race Conditions**: Eliminates `connect-pg-simple` login lost-session bugs by executing explicit asynchronous `req.session.save()` before returning response headers.
*   **Workload Identity & Cloud SQL Proxy**: Seamlessly connects to managed Google Cloud SQL instances either through direct Unix/TCP sockets via a local Cloud SQL Auth Proxy sidecar container or via standard parameterized connection strings.
*   **Dynamic Namespace Discovery**: Dynamically resolves in-cluster Prometheus and Loki service hostnames based on `K8S_NAMESPACE` / `POD_NAMESPACE` environment variables, avoiding hardcoded URLs across `dev` and `prod`.

---

## 🏃 Local Development

```bash
cd apps/api
npm install
npm run dev     # Hot-reloading development server via nodemon on http://localhost:8000
```

### Running Unit Tests
```bash
npm test        # Runs Jest unit test suites
```

### Environment Variables Reference
```ini
PORT=8000
NODE_ENV=development
DATABASE_URL=postgresql://postgres:localdevpassword@localhost:5432/fire_monitoring
SESSION_SECRET=supersecret-session-key
COOKIE_SECURE=false
PGSSLMODE=disable
PROMETHEUS_URL=http://localhost:9090
LOKI_URL=http://localhost:3100
K8S_NAMESPACE=fire-monitoring-local
```

---

## 🐳 Container Build

```bash
# Build multi-stage hardened image
docker build -t localhost/api:local .
```
* **Stage 1 (Builder)**: Installs build toolchain (`python3`, `make`, `g++`) to compile native modules (`bcrypt`).
* **Stage 2 (Runtime)**: Minimal `node:22-alpine` image running under non-root system user `node` (`UID 1000`).
