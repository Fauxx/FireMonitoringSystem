# IoT Sensor Telemetry Simulator

[![Runtime](https://img.shields.io/badge/Runtime-Python%203-blue.svg)](#)
[![Protocol](https://img.shields.io/badge/Protocol-MQTT-lightgrey.svg)](#)

A high-fidelity Python simulator designed to emulate ESP32 edge MCU networks for the Fire Monitoring Platform. It generates varied environmental and state telemetry and publishes payloads over MQTT.

---

## 🛠️ Payload Specification
The simulator publishes flat JSON payloads structured to match the Telegraf parser setup:
```json
{
  "h_id": "REYES_P",
  "lat": 14.5995,
  "lon": 121.0365,
  "status": 0
}
```
*   `h_id`: Unique Household/Device identifier.
*   `lat` / `lon`: Coordinates for geographic mapping.
*   `status`: Edge state indicator where:
    *   `0`: Normal
    *   `1`: Warning
    *   `2`: Critical

---

## 🏃 Local Execution

### 1. Requirements
*   Python 3.10+
*   MQTT Broker running (e.g. Mosquitto on port 1883 or 18830)

### 2. Quickstart Setup
```bash
# Navigate to the simulators directory
cd apps/simulators

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start default simulation (stream random telemetry to localhost)
python mcu_sim.py
```

### 3. Advanced CLI Configuration
You can pass flags to customize the simulation behaviour:
```bash
python mcu_sim.py \
  --host localhost \
  --port 18830 \
  --topic fire/sensors/REYES_P \
  --h-id REYES_P \
  --status 0 \
  --lat 14.5995 \
  --lon 121.0365 \
  --interval 5.0
```

#### CLI Parameters:
*   `--host`: Host address of the MQTT Broker (default: `localhost`).
*   `--port`: TCP port of the MQTT Broker (default: `18830`).
*   `--topic`: MQTT topic to publish payloads to (default: `fire/sensors/REYES_P`).
*   `--interval`: Speed of transmission in seconds (default: `5.0`).
*   `--h-id`: Identifies the device tag.
*   `--status`: Force a static alert level (`0` = Normal, `1` = Warning, `2` = Critical). If omitted, the script executes a state engine generating 85% normal, 12% warning, and 3% critical payloads.
*   `--lat` / `--lon`: Sets custom geographic coordinates.
*   `--transport`: Protocol type (`tcp` or `websockets`).
*   `--insecure`: Set to bypass SSL validations when connecting via port `443`.
