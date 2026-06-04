# Application Architecture & Topology

The FireMonitoringSystem is built as a set of decoupled microservices designed for scalability, real-time data processing, and high visibility.

## 🛰️ System Data Flow

The system follows a reactive architecture for processing IoT sensor data:

1.  **Ingestion:** IoT Simulators (or physical MCUs) publish sensor data (Temperature, Smoke, CO levels) to the **Mosquitto MQTT Broker** via the `fire/sensors` topic.
2.  **Processing:** The **ETL Processor** (Python) subscribes to the MQTT broker, cleanses the data, and performs two actions:
    -   Writes high-resolution raw data to **InfluxDB** (Time-series).
    -   Persists state and metadata to **PostgreSQL**.
3.  **Serving:** The **Node.js API** provides a RESTful interface to query historical trends from InfluxDB and management data from PostgreSQL.
4.  **Visualization:** The **Nginx Dashboard** (Vanilla JS/CSS) communicates with the API to provide real-time alerts and interactive analytics to end-users.

## 📦 Service Breakdown

### 1. API Service (`apps/api`)
- **Runtime:** Node.js / Express
- **Advanced Instrumentation:** Built-in observability using `prom-client` to export custom metrics (e.g., `http_request_duration_seconds` histograms and `http_requests_total` counters) for Prometheus scraping.
- **Production-Ready Persistence:** Implements intelligent PostgreSQL connection pooling with automated SSL handling (`PGSSLMODE`), ensuring encrypted data transit in production environments.
- **Security Middleware:** Custom authentication middleware and session management to protect sensitive analytics endpoints.

### 2. Dashboard (`apps/dashboard`)
- **Runtime:** Nginx (serving static assets)
- **Real-time Interaction:** Leverages vanilla JavaScript with high-performance fetch patterns to communicate with the API backend.
- **Deployment Pattern:** Multi-stage Docker builds are used to keep the final production image lightweight and secure.

### 3. ETL Processor (`apps/etl-processor`)
- **Runtime:** Python
- **Data Wrangling:** Utilizes `pandas` for advanced time-series data manipulation, including pivoting wide-format data from InfluxDB and performing multi-dimensional data cleansing.
- **Resilience:** Implements a singleton database connection pattern with automatic reconnection logic to minimize TCP overhead and ensure high availability of the processing loop.
- **Configurable Thresholds:** Real-time anomaly detection based on environment-driven thresholds (e.g., `THRESHOLD_TEMP_RED`).

### 4. Simulators (`apps/simulators`)
- **Runtime:** Python
- **Functionality:** High-fidelity simulation of IoT sensor fleets, capable of generating varied environmental scenarios (Normal, Warning, Critical) to validate system-wide alerting logic.

## 🗄️ Data Strategy & Schema Management

- **Relational Data:** PostgreSQL stores users, device metadata, and incident logs. Schema changes are managed via **Flyway** migrations.
- **Time-Series Data:** InfluxDB is used for all sensor readings.
- **Persistence Strategy (Lab/Dev):** In the current exploration phase, services utilize **PersistentVolumes with local-path provisioners**. This design choice prioritizes high-performance disk I/O and simplifies the learning environment for exploring the IoT tech stack. 
- **Future Roadmap:** For a production-hardened environment, the architecture is designed to easily pivot to cloud-managed block storage (e.g., DigitalOcean Volumes) or external managed databases for automated backups and multi-zone availability.

## 🌐 Network Topology

- **Ingress Controller:** Manages external access to the `dashboard` and `api` via standard HTTP/HTTPS.
- **Internal Service Mesh:** Services communicate internally via Kubernetes ClusterIPs, ensuring that the database and MQTT broker are not exposed to the public internet.
