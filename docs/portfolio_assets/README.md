# 📸 Fire Monitoring System — Portfolio Assets & Media Evidence

This directory contains high-fidelity visual evidence (screenshots, animated GIF demos, and MP4 video clips) captured directly from the live production deployment at `https://dev.fires.systems`.

---

## 📂 Asset Catalog

### 1. 🖼️ High-Resolution Screenshots (`docs/portfolio_assets/screenshots/`)

| File Name | Preview / Feature | Description |
|---|---|---|
| [`01_login_overlay.png`](./screenshots/01_login_overlay.png) | **Encrypted Session Authentication** | Shows the blurred background overlay gating access, secure credentials input, and role-based access control (RBAC). |
| [`02_live_command_center_map.png`](./screenshots/02_live_command_center_map.png) | **Live Spatial Command Center** | Full-screen interactive map displaying live sensor fleet nodes with dynamic status markers (Normal, Warning, Critical) across NCR. |
| [`03_sensor_telemetry_drawer.png`](./screenshots/03_sensor_telemetry_drawer.png) | **Edge Sensor Telemetry Drawer** | Detailed telemetry inspection panel showing real-time temperature, smoke density, flame alerts, and battery voltage. |
| [`04_command_center_modal.png`](./screenshots/04_command_center_modal.png) | **Interactive Simulation & Diagnostics** | Bi-directional simulation controller for triggering heat spikes, status overrides, and power toggles over MQTT WebSockets. |

---

### 2. 🎥 Video & Animated Demonstrations (`docs/portfolio_assets/videos/`)

| File Name | Format | Use Case |
|---|---|---|
| [`dashboard_live_telemetry.gif`](./videos/dashboard_live_telemetry.gif) | **Optimized Animated GIF** (937 KB) | Ideal for embedding in your GitHub profile README, portfolio blog posts, or project case studies without requiring a video player. |
| [`dashboard_live_telemetry.mp4`](./videos/dashboard_live_telemetry.mp4) | **1080p H.264 Video** (564 KB) | High-definition web video for LinkedIn posts, portfolio video embeds, or presentation decks. |

---

## 🎯 Suggested Markdown Snippet for Your Public Profile

You can copy and paste this directly into your GitHub profile `README.md` or portfolio website:

```markdown
### 🔥 IoT Fire Monitoring & Cloud-Native Analytics Command Center

> **Live Deployment:** [dev.fires.systems](https://dev.fires.systems)  
> **Tech Stack:** React 19, TypeScript, Vite, Tailwind CSS, MapLibre GL, Mosquitto MQTT, Python (pandas), InfluxDB, PostgreSQL, GKE, ArgoCD.

![Dashboard Live Telemetry](https://raw.githubusercontent.com/Fauxx/FireMonitoringSystem/main/docs/portfolio_assets/videos/dashboard_live_telemetry.gif)

#### 🚀 Key Capabilities Demonstrated:
- **Sub-Second Streaming Telemetry:** MQTT over WebSockets eliminates HTTP polling overhead.
- **Bi-Directional IoT Simulation:** Operators can trigger live heat spikes and power states directly from the command center.
- **30-Minute Debouncing & Rollup Engine:** Python ETL pipeline downsamples routine telemetry into PostgreSQL while preserving incident logs.
```
