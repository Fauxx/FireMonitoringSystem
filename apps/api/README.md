# 🟢 FireMonitor — REST API

[![Runtime](https://img.shields.io/badge/Runtime-Node.js%2022-green.svg)](#)
[![Framework](https://img.shields.io/badge/Framework-Express.js-lightgrey.svg)](#)
[![Database](https://img.shields.io/badge/Database-PostgreSQL-blue.svg)](#)
[![Metrics](https://img.shields.io/badge/Metrics-Prometheus-orange.svg)](#)

Express.js REST API serving the Fire Monitoring Dashboard. Handles authentication, sensor telemetry queries, device registry, and analytics.

---

## 🏗️ Architecture

```
Nginx (Dashboard) → proxy_pass → API :8000
                                    │
                          ┌─────────┼─────────┐
                          ▼         ▼         ▼
                       /auth   /api/*    /metrics
                          │         │
                     Session     PostgreSQL Pool
                     (PgStore)    (pg.Pool)
```

---

## 📡 API Reference

### Auth (`/auth`)
| Verb | Endpoint | Description |
|---|---|---|
| `POST` | `/auth/login` | Login with email + password, sets session cookie |
| `POST` | `/auth/logout` | Destroys session |
| `GET` | `/auth/me` | Returns current session user |

### Devices (`/api/devices`)
| Verb | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/api/devices` | None | Lists all registered devices (`h_id`, `lat`, `lon`, `barangay`) |

> Used by the Dashboard Simulator Controller to populate the device list.

### Telemetry (`/api/final-sensors`)
| Verb | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/api/final-sensors/latest` | Session | Latest reading per device from `final_sensor_latest` view |
| `GET` | `/api/final-sensors/history` | Session | Historical logs with time + limit bounds |

### Analytics (`/api/analytics`)
| Verb | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/api/analytics/devices` | Session | Unique active device tags |
| `GET` | `/api/analytics/hourly` | Session | Hourly status/temp/smoke averages |
| `GET` | `/api/analytics/heatmap` | Session | Daily alert heatmap (Manila timezone) |

### Users (`/api/users`)
| Verb | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/api/users` | Session | List all registered users |
| `POST` | `/api/users` | Admin | Register a user directly |
| `PUT` | `/api/users/:id` | Admin | Update user data |
| `DELETE` | `/api/users/:id` | Admin | Delete user |
| `GET` | `/api/users/pending` | Admin | Pending approval queue |
| `POST` | `/api/users/approve` | Admin | Approve pending registration |

---

## 📊 Observability

Prometheus metrics exposed at `GET /metrics`:

- `http_request_duration_seconds` (Histogram)
- `http_requests_total` (Counter)
- Node.js runtime defaults (`process_cpu_seconds_total`, etc.)

---

## 🏃 Local Development

```bash
cd apps/api
npm install
npm run dev   # nodemon hot-reload at http://localhost:8000
```

### Environment Variables

```ini
DATABASE_URL=postgresql://postgres:localdevpassword@localhost:5432/fire_monitoring
SESSION_SECRET=a-secure-cookie-signing-key
COOKIE_SECURE=false
PGSSLMODE=disable
PORT=8000
NODE_ENV=development
```

---

## 🐳 Docker Build

```bash
docker build -t localhost/api:local .
```

Built on Node.js 22 Alpine with a non-root `appuser` for security.
