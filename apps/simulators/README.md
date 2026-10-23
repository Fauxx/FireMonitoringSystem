# 🟣 FireMonitor — IoT Fleet Simulator (`apps/simulators/`)

[![Runtime](https://img.shields.io/badge/Runtime-Python%203.12-blue.svg)](https://www.python.org/)
[![Protocol](https://img.shields.io/badge/Protocol-MQTT%20%28paho--mqtt%202.x%29-lightgrey.svg)](https://eclipse.dev/paho/)
[![Security](https://img.shields.io/badge/User-UID%201000%20(simuser)-blueviolet.svg)](#)

The **IoT Fleet Simulator** is a lightweight, asynchronous Python service that emulates physical ESP32 edge microcontrollers streaming real-world fire telemetry over MQTT. It acts as the primary data generation engine for the Fire Monitoring Platform and features **sub-second bi-directional control** from the operator command center.

---

## 🏗️ Architecture & Control Loop

```mermaid
flowchart TD
    subgraph Dashboard ["Operator Command Center"]
        UI[Simulation Controller Modal]
    end

    subgraph MQTTBroker ["Mosquitto Broker"]
        ControlTopic[Control Topics<br/>fire/control/{h_id} & fire/control/all]
        SensorTopic[Telemetry Topic<br/>fire/sensors/{device_id}]
    end

    subgraph Simulator ["IoT Fleet Simulator (10 Pod Processes)"]
        Sub[on_message Callback<br/>Power Toggle / Status Override]
        Pub[Telemetry Generator Loop<br/>Every 5 Seconds]
    end

    UI -->|Publish ws://:9001| ControlTopic
    ControlTopic -->|Subscribe :1883| Sub
    Sub -->|Adjust Runtime State| Pub
    Pub -->|Publish :1883| SensorTopic
    SensorTopic -->|Telegraf Ingestion| Influx[(InfluxDB)]
```

---

## 📦 Payload Specification

Each telemetry payload represents a flat, structured JSON object:

```json
{
  "h_id": "node-sim-01",
  "status": 2,
  "temp": 68.3,
  "smoke": 0.91,
  "flame": 1,
  "_time": "2026-10-22T08:15:36Z"
}
```

| Field | Type | Description |
|---|---|---|
| `h_id` | `string` | Unique device identifier matching an entry in `device_registry` |
| `status` | `integer` | Alert severity code: `0` = Normal, `1` = Warning, `2` = Critical |
| `temp` | `float` | Ambient temperature in °C (dynamically calculated based on alert status) |
| `smoke` | `float` | Smoke concentration index between `0.0` and `1.0` |
| `flame` | `integer` | Optical flame sensor detection flag (`0` or `1`) |
| `_time` | `string` | ISO 8601 UTC timestamp |

---

## 🎮 Real-Time Bi-Directional Control via MQTT

The simulator listens for real-time control directives issued by the web dashboard:

| Control Topic | Payload Directive | Simulation Behavior |
|---|---|---|
| `fire/control/{h_id}` | `{"power": "off"}` | Pauses publishing loop; puts emulated MCU into sleep mode |
| `fire/control/{h_id}` | `{"power": "on"}` | Wakes MCU; resumes active telemetry streaming |
| `fire/control/{h_id}` | `{"status_code": 0}` | Forces reading state to **Normal** (25–35°C, low smoke) |
| `fire/control/{h_id}` | `{"status_code": 1}` | Forces reading state to **Warning** (40–55°C, elevated smoke) |
| `fire/control/{h_id}` | `{"status_code": 2}` | Forces reading state to **Critical** (65–95°C, optical flame active) |
| `fire/control/all` | `{"status_code": 0}` | Broadcast reset returning all fleet nodes to normal |

---

## 🏃 Kubernetes Fleet Mode (`run_10.sh`)

In staging and production clusters, the simulator deploys as a single Pod executing `run_10.sh`. The script forks 10 isolated background Python processes—one for each registered household in Metro Manila:
* `node-sim-01` (Intramuros, Commercial)
* `node-sim-02` (Ermita, Residential)
* `node-sim-03` (Malate, Residential)
* `node-sim-04` (Sampaloc, Commercial)
* `node-sim-05` (Tondo, Industrial)
* `node-sim-06` (Sampaloc, Residential)
* `node-sim-07` (Malate, Commercial)
* `node-sim-08` (Ermita, Residential)
* `node-sim-09` (Tondo, Commercial)
* `node-sim-10` (Pandacan, Industrial)

---

## 💻 Local Standalone Execution

```bash
cd apps/simulators
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run a single simulated device
python mcu_sim.py --device-id node-sim-01 --status 0 --host localhost --port 1883
```

### CLI Parameters
| Argument | Type | Default | Description |
|---|---|---|---|
| `--device-id` | `str` | *Required* | Device ID matching a database entry in `device_registry` |
| `--status` | `int` | `0` | Initial alert status (`0` Normal, `1` Warning, `2` Critical) |
| `--host` | `str` | `localhost` | MQTT broker hostname or IP address |
| `--port` | `int` | `1883` | MQTT broker port |
| `--interval` | `int` | `5` | Publication frequency in seconds |

---

## 🐳 Hardened Container Packaging

```bash
docker build -t localhost/simulators:local .
```
Built on `python:3.12-slim` and executes under a dedicated unprivileged user `simuser` (`UID 1000`) with no root privileges, complying with Kubernetes Restricted Pod Security Standards.
