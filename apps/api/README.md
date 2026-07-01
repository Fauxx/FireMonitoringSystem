# Express REST API Service

[![Runtime](https://img.shields.io/badge/Runtime-Node.js%20%7C%20Express-green.svg)](#)
[![Datastore](https://img.shields.io/badge/Datastores-PostgreSQL%20%7C%20InfluxDB-blue.svg)](#)
[![Metrics](https://img.shields.io/badge/Metrics-Prometheus%20Client-orange.svg)](#)

The **Express REST API** acts as the central serving layer for the Fire Monitoring Platform. It handles authentication, maps analytics queries, processes incident validation, and bridges time-series and relational databases.

---

## 🛠️ Key Architectural Features

*   **Connection Pooling:** Built-in connection pooling using the `pg` client, featuring automatic SSL handling (`rejectUnauthorized: false` in production mode) to guarantee encrypted transit.
*   **Persistent Sessions:** Leverages `express-session` with `connect-pg-simple` to persist session cookies directly in a PostgreSQL relational table. This prevents user session loss during server restarts or container scaling.
*   **Prometheus Metrics:** Integrated `prom-client` that automatically collects system diagnostics (heap size, memory, GC) and tracks HTTP duration histogram buckets via custom middleware (`http_request_duration_seconds`).
*   **Nginx Ingress Trust:** Configured with `trust proxy = 1` to correctly parse `X-Forwarded-For` and `X-Forwarded-Proto` headers when routed through the Ingress controller.

---

## 🛰️ API Endpoints Index

### 1. Authentication Router (`/auth`)
| Verb | Endpoint | Authentication | Description |
|:---|:---|:---|:---|
| `POST` | `/auth/signup` | Public | Registers a new user. Puts their state in `pending` by default, awaiting admin approval. |
| `POST` | `/auth/login` | Public | Authenticates credentials (username/email). Blocks logins if status is `pending` or `rejected`. |
| `POST` | `/auth/logout` | Session-Cookie | Destroys the active session and clears the cookie. |
| `GET` | `/auth/session` | Session-Cookie | Returns the active session user payload. |
| `GET` | `/auth/verify` | Nginx Subrequest | Ingress gate verification. Validates sessions and proxies roles to Grafana via headers (`x-user-role`, `x-webauth-user`). Reject direct Grafana document load if the user is not an `admin`. |

### 2. User Administration Router (`/api/users` - Admin Gated)
| Verb | Endpoint | Description |
|:---|:---|:---|
| `GET` | `/api/users` | Lists all registered users, their roles, and current statuses. |
| `POST` | `/api/users` | Directly registers an approved user. |
| `PUT` | `/api/users/:id` | Modifies user data (username, email, role, or password). |
| `PUT` | `/api/users/:id/role` | Updates user role (e.g. Responder to Admin) with admin re-verification credentials. |
| `DELETE` | `/api/users/:id` | Deletes a user (self-deletion blocked). |
| `GET` | `/api/users/pending` | Retrieves all users waiting in the registration approval queue. |
| `POST` | `/api/users/approve` | Approves a pending user registration. |
| `POST` | `/api/users/reject` | Rejects a pending user registration. |

### 3. Analytics & Stats Router (`/api/dashboard` & `/api/analytics`)
| Verb | Endpoint | Authentication | Description |
|:---|:---|:---|:---|
| `GET` | `/api/dashboard/stats` | Session-Cookie | Returns overall stats: active online devices, today's alerts count, and uptime percentage. |
| `GET` | `/api/dashboard/status` | Session-Cookie | Checks cluster operational levels. Flags system as "Critical", "Warning", or "No Live Data". |
| `GET` | `/api/devices/stats` | Session-Cookie | Returns counters for online, offline, and alerting devices. |
| `GET` | `/api/analytics/devices` | Session-Cookie | Returns a unique list of active device/household tags. |
| `GET` | `/api/analytics/hourly` | Session-Cookie | Returns average hourly status, temperature, and smoke metrics. |
| `GET` | `/api/analytics/heatmap` | Session-Cookie | Formats daily incident alerts based on Manila timezone boundaries. |

### 4. Incident Management Router (`/api/incidents`)
| Verb | Endpoint | Authentication | Description |
|:---|:---|:---|:---|
| `GET` | `/api/incidents` | Session-Cookie | Returns lists of pending active incident telemetry and verified logs. |
| `POST` | `/api/incidents/verify` | Admin Gated | Saves responder incident notes, locking telemetry to a verified record. |
| `POST` | `/api/official-incidents`| Session-Cookie | Creates official BFP reporting records (casualties, establishment, etc.). |
| `GET` | `/api/official-incidents` | Session-Cookie | Lists all submitted BFP records. |
| `GET` | `/api/official-incidents/export`| Session-Cookie | Exports Manila-timezone formatted CSV/Excel documents containing reporting logs. |

### 5. Telemetry Router (`/api/final-sensors`)
| Verb | Endpoint | Authentication | Description |
|:---|:---|:---|:---|
| `GET` | `/api/final-sensors/latest` | Session-Cookie | Returns the latest raw JSON payload for all devices. |
| `GET` | `/api/final-sensors/history` | Session-Cookie | Queries historical logs with time and limit bounds. |
| `POST`| `/api/final-sensors/events` | Admin Gated | Optional HTTP route for ingesting raw JSON telemetry. |

---

## 🏃 Local Execution

### 1. Requirements
Ensure you have Node.js 18+ and PostgreSQL running.

### 2. Setup Variables
Ensure the following variables are defined in your environment or root `.env` file:
```ini
DATABASE_URL=postgresql://fireuser:local-password@localhost:5432/fire_monitoring
SESSION_SECRET=a-secure-cookie-signing-key
COOKIE_SECURE=false
PGSSLMODE=disable
PORT=8000
```

### 3. Launch
```bash
# Navigate to the service directory
cd apps/api

# Install modules
npm install

# Run in development mode
npm run dev

# Run in production mode
npm start
```
The server will bind to `http://localhost:8000`. You can check health at `http://localhost:8000/health`.

---

## 📊 Observability / Prometheus Metrics
Prometheus scrapes system metrics on the `/metrics` endpoint. The HTTP duration statistics are tracked via custom middleware:
```javascript
const client = require('prom-client');
// Collects Node runtime diagnostics
client.collectDefaultMetrics();
```
To test metric collection:
```bash
curl http://localhost:8000/metrics
```
Look for metrics:
*   `http_request_duration_seconds_bucket` (Histogram)
*   `http_requests_total` (Counter)
*   `process_cpu_seconds_total` (Node CPU runtime)
