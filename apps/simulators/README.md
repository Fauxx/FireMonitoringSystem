# 🤖 IoT Fleet Simulator (MCU Simulator)

[![Runtime](https://img.shields.io/badge/Runtime-Python%203.10+-blue.svg)](#)
[![Protocol](https://img.shields.io/badge/Protocol-MQTT%20%28paho--mqtt%202.x%29-lightgrey.svg)](#)

A lightweight Python MQTT publisher that emulates physical ESP32 microcontrollers streaming real-world fire sensor telemetry. Designed as the **data generation engine** of the Fire Monitoring System — fully controllable in real-time from the Dashboard.

---

## 🏗️ Architecture

```
Dashboard Controller (MQTT publish fire/control/{h_id})
          │
          ▼  {"power":"on"} / {"status_code": 2}
  ┌─────────────────────┐
  │  mcu_sim.py (Python) │   ◄── subscribed to fire/control/{h_id}
  │  on_message callback │                and fire/control/all
  └─────────────────────┘
          │  publishes every 5s
          ▼
  fire/sensors/{device_id}
  {"h_id":"node-sim-01","status":2,"temp":68.3,"smoke":0.9,...}
          │
          ▼
  ETL Processor → PostgreSQL
```

---

## 📦 Payload Specification

```json
{
  "h_id": "node-sim-01",
  "status": 2,
  "temp": 68.3,
  "smoke": 0.91,
  "flame": 1,
  "_time": "2026-10-03T08:15:36Z"
}
```

| Field | Description |
|---|---|
| `h_id` | Unique device ID — must match a record in `device_registry` |
| `status` | `0` = Normal, `1` = Warning, `2` = Critical |
| `temp` | Temperature in °C (ranges by status) |
| `smoke` | Smoke density 0.0–1.0 |
| `flame` | Flame detected: `0` or `1` |
| `_time` | ISO 8601 UTC timestamp |

---

## 🎮 Real-time Control via Dashboard

The simulator subscribes to two MQTT control topics:

| Topic | Payload | Effect |
|---|---|---|
| `fire/control/{h_id}` | `{"power": "on"}` | Resume publishing |
| `fire/control/{h_id}` | `{"power": "off"}` | Pause publishing |
| `fire/control/{h_id}` | `{"status_code": 2}` | Force Critical readings |
| `fire/control/all` | `{"status_code": 0}` | Reset all simulators to Normal |

---

## 🏃 Kubernetes Fleet Mode

The simulator runs as a Kubernetes `Deployment` with a single pod that spawns 10 independent Python processes — one per registered `node-sim-*` device.

Each process:
1. Connects to the in-cluster MQTT broker (`mqtt:1883`)
2. Subscribes to its private control topic
3. Publishes telemetry every 5 seconds

```yaml
# infrastructure/k8s/base/simulator/deployment.yaml
command: ["/bin/bash", "./run_10.sh"]
```

---

## 🏃 Local Standalone Execution

```bash
cd apps/simulators
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Single device
python mcu_sim.py --device-id node-sim-01 --status 0 --host localhost --port 1883
```

### CLI Parameters

| Flag | Default | Description |
|---|---|---|
| `--device-id` | required | Device ID (must match `device_registry.h_id`) |
| `--host` | `localhost` | MQTT broker host |
| `--port` | `1883` | MQTT broker TCP port |
| `--status` | `0` | Initial status: `0` Normal, `1` Warning, `2` Critical |

---

## 🐳 Docker Build

```bash
docker build -t localhost/mcu-simulator:local .
```
