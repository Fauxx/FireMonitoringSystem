---
sidebar_position: 5
title: Observability Stack
---

# Observability Stack

> **STATUS: CURRENT**  
> The observability stack leverages the Prometheus and Grafana ecosystem to monitor both infrastructure health and application performance. The current implementation operates via static file configurations (ConfigMaps), with the architecture designed to migrate smoothly to GKE.

## 📊 Core Components

The stack is divided into two primary telemetry pillars: **Metrics** (numerical time-series data) and **Logs** (timestamped text streams).

### 1. Prometheus (Metrics)
Acts as the central metrics scraper and aggregator, configured with a 15-second `scrape_interval`. It connects to multiple targets defined statically in `prometheus.yml`:
- **Infrastructure**:
  - `node-exporter`: Exposes hardware and OS metrics (CPU, Memory, Disk) running as a DaemonSet.
  - `cadvisor`: Exposes container resource utilization metrics running as a DaemonSet.
- **Application Services**:
  - `api`: Node.js Express server exposing custom business metrics (request duration, GC stats).
- **Data Layer Exporters**:
  - `postgres-exporter`: Exposes PostgreSQL connection and query metrics.
  - `mqtt-exporter`: Exposes Mosquitto broker active connections and throughput.

### 2. Loki & Grafana Alloy (Logs)
- **Grafana Alloy**: Deployed as a DaemonSet, acting as the primary log shipper. It mounts the host's `/var/log/pods` directory, parsing standard output from all containers.
- **Loki**: The log aggregation datastore. Configured with a 168-hour (7-day) retention policy using the local filesystem and boltdb-shipper.

### 3. Grafana (Visualization & Analytics)
The primary UI for all observability data.
- **Datasources**: Automatically provisioned to connect to Prometheus, Loki, and InfluxDB.
- **Auth-Proxy Integration**: Uses header-based SSO (`X-WEBAUTH-USER`, `X-USER-ROLE`) injected by the Nginx dashboard gateway to authenticate users securely.
- **Ops Ingress**: A standalone ingress (`ops.fires.systems/grafana`) provides direct access to Grafana using basic authentication, ensuring observability remains accessible even if the main application API goes down.

## 📈 Custom Dashboards

Grafana is provisioned with 6 custom dashboards via Kubernetes ConfigMaps, categorizing system health:

1. **Fire Main Telemetry (`fire-main.json`)**: IoT sensor fire detection status, temperature readings, battery alerts (backed by InfluxDB).
2. **Cluster Health (`cluster-health.json`)**: Node CPU/Memory saturation, disk I/O, pod restart frequency.
3. **API Performance (`api-performance.json`)**: Express API latency, status error rates, requests per second.
4. **Loki Error Logs (`loki-error-logs.json`)**: Real-time log streams and exception traps.
5. **PostgreSQL Health (`postgres-health.json`)**: Database connections, query locks, transaction rollbacks.
6. **MQTT Broker (`mqtt-broker.json`)**: Active IoT client connections and MQTT topic throughput.

## 🔮 Target Architecture Distinctions

While the current implementation uses static scrape configurations and hardcoded ConfigMaps for provisioning, the transition to **GKE** may eventually introduce the Prometheus Operator (CRDs like `ServiceMonitor`). 

However, the **current implementation** strictly avoids CRDs to minimize cluster footprint, maintaining raw Deployment and DaemonSet manifests for Prometheus and Loki.
