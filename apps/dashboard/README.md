# 🔴 FireMonitor — React Dashboard

[![Runtime](https://img.shields.io/badge/Runtime-React%2018%20+%20TypeScript-blue.svg)](#)
[![Build](https://img.shields.io/badge/Build-Vite-purple.svg)](#)
[![Styling](https://img.shields.io/badge/Styling-Tailwind%20CSS-teal.svg)](#)
[![Maps](https://img.shields.io/badge/Maps-React--Leaflet%20%2B%20OpenStreetMap-green.svg)](#)

Real-time fire monitoring dashboard. Displays live sensor telemetry from IoT edge devices on an interactive map, with bi-directional device simulation control.

---

## 🏗️ Architecture

```
MQTT Broker (ws://localhost:9001)
       │ fire/sensors/# (live telemetry)
       ▼
  useLiveSensors.ts ──► React State ──► MapLibreCanvas.tsx (OpenStreetMap)
       │                                      ▼
       │ fire/control/{h_id}          FloatingTopBar.tsx (stats + nav)
       ◄──────────────────────────────────────┤
                                    SimulatorModal.tsx (controller)
```

---

## ✨ Key Features

| Feature | Implementation |
|---|---|
| **Live Map** | React-Leaflet + OpenStreetMap tiles (no API key required) |
| **Real-time Telemetry** | MQTT over WebSockets (`paho-mqtt` / `mqtt.js`) |
| **Bi-directional Control** | Dashboard publishes MQTT commands to `fire/control/{h_id}` |
| **Device Simulator Controller** | Fetches registered devices from DB, toggles ON/OFF + status |
| **Status Highlighting** | Buttons reflect live MCU state (green/orange/red) |
| **Alert Popups** | Critical event modal triggers on status 2 escalation |
| **Session Auth** | Cookie-based login gated via `/auth/login` |

---

## 🎮 Simulation Controller

The dashboard includes a built-in **Device Simulator Controller** (accessible via Settings → Simulation Controller). It:

1. Fetches all `node-sim-*` devices from the `device_registry` via `GET /api/devices`
2. Displays live temperature and current status for each device
3. Publishes MQTT commands directly to the broker over WebSockets:
   - `{"power": "on"}` / `{"power": "off"}` → pauses/resumes the Python MCU
   - `{"status_code": 0|1|2}` → forces Normal / Warning / Critical readings

---

## 🏃 Local Development

```bash
cd apps/dashboard
npm install
npm run dev     # Vite dev server at http://localhost:5173
```

> **Note:** The Vite dev server proxies `/api` and `/auth` to `http://localhost:8000`.

---

## 📡 MQTT Topics

| Topic | Direction | Description |
|---|---|---|
| `fire/sensors/#` | Subscribe | Live telemetry from all MCU simulators |
| `fire/control/{h_id}` | Publish | Send ON/OFF and status override commands |
| `fire/control/all` | Publish | Broadcast command to all simulators at once |

---

## 🐳 Docker Build

```bash
docker build -t localhost/dashboard:local .
```

Built as a multi-stage image: Node 20 Alpine (build) → Nginx Alpine (serve).
