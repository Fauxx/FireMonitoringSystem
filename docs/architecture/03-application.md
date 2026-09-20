---
sidebar_position: 4
title: Application Layer
---

# Application Layer Data Flow

> **STATUS: CURRENT**  
> The application architecture is decoupled into specialized microservices. It utilizes a "Smart Gateway" model, offloading authentication and static serving to Nginx, while maintaining distinct data paths for telemetry processing and REST API responses.

## 📦 Service Relationships

- **Dashboard (Nginx SPA)**: Serves static HTML/JS/CSS assets. Acts as a smart proxy gating protected resources.
- **API (Node.js/Express)**: "Headless" backend managing user sessions, querying relational data, and serving analytical API endpoints.
- **ETL Processor (Python/Pandas)**: Background worker converting raw high-volume telemetry into curated, relational alert records.
- **Simulators**: Standalone IoT edge emulators publishing synthetic MQTT payloads.

## 📡 MQTT Telemetry Flow

The core operational loop of the system begins at the Edge:
1. **Sensor Emulation**: The Python-based IoT Fleet Simulator publishes JSON telemetry (e.g., `h_id`, `lat`, `lon`, `status`) to the MQTT broker (`fire/sensors/#`).
2. **Mosquitto Broker**: Operates on `ClusterIP` port `1883` (internal MQTT) and `9001` (WebSocket for the frontend).
3. **Ingestion & Time-Series**:
   - `Telegraf` subscribes to the MQTT topic, parses the JSON payload, and writes the raw telemetry directly into **InfluxDB**.
   - **InfluxDB** stores raw, high-resolution time-series sensor data.

## ⚙️ ETL Processing Flow

To prevent the PostgreSQL database from bloating with millions of raw sensor pings, the **Python ETL Processor** operates as a mediator:
1. **Poll & Aggregate**: Regularly queries raw telemetry from InfluxDB using `pandas`.
2. **Debounce Logic (30-Minute Anomaly)**: 
   - Checks if an active incident exists for a household.
   - If active: Updates `last_seen_at` and upserts severity.
   - If resolved: Closes the incident.
   - Normal signals are downsampled into 5-minute rollups.
3. **Relational Storage**: Upserts the condensed incidents and analytics data into **PostgreSQL**.

## 🗄️ PostgreSQL Data Flow

**PostgreSQL** serves as the relational backbone and single source of truth for application state:
- **Database Migrations**: Handled by **Flyway**, executing on ArgoCD Sync Wave 5 before any code boots.
- **Session State**: The API utilizes `connect-pg-simple` to store active cookie sessions in PostgreSQL. This allows the API pods to restart statelessly without dropping user logins.
- **Application Queries**: The API queries PostgreSQL for user data, active incidents, and official fire reports. 

## 🛡️ Nginx Smart Gateway (Auth Flow)

Nginx is positioned at the frontend of the `dashboard` pod to reduce API load and enforce security.
- **Unprotected Routes**: (`/`, `/login.html`, `/auth/*`) hit Nginx and proxy to the API or serve from disk.
- **Protected Routes**: Protected endpoints use Nginx's `auth_request` module. Nginx halts the request, verifies the session cookie against the API's `/auth/verify` endpoint, and only forwards the request upon a `200 OK` response.
- **Grafana Embedding**: Proxies requests to Grafana, dynamically injecting authenticated `X-WEBAUTH-USER` and `X-USER-ROLE` headers, facilitating secure iframe dashboards without double-logins.
