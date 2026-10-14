# Fire Monitoring System - Master Resume Dataset
*This file contains an exhaustive list of technical accomplishments, architecture decisions, and technologies used in the Fire Monitoring System project. It is structured specifically to be parsed by your Python Resume-Matcher script.*

## 🏷️ CATEGORY: CLOUD ENGINEERING & INFRASTRUCTURE AS CODE (IaC)
**Tech Stack:** Google Cloud Platform (GCP), Azure, DigitalOcean, Terraform, VPC, Cloud NAT, Artifact Registry
* "Architected and provisioned a scalable, multi-tier cloud infrastructure on Google Cloud Platform (GCP) using Terraform, ensuring 100% immutable and reproducible environments."
* "Demonstrated multi-cloud adaptability by successfully provisioning and deploying the entire Kubernetes architecture across Google Kubernetes Engine (GKE), Azure Kubernetes Service (AKS), and DigitalOcean Kubernetes (DOKS)."
* "Designed a secure virtual network topology with GCP Virtual Private Cloud (VPC), private subnets, and Cloud NAT, enabling secure outbound internet access for private GKE nodes."
* "Developed a modular, 4-stage Terraform architecture (Bootstrap, Infra, Platform, GitOps) to strictly isolate state and minimize blast radius during infrastructure teardowns and updates."
* "Configured Google Artifact Registry as the centralized, secure container image repository, seamlessly integrating it with GKE and GitHub Actions via IAM role bindings."

## 🏷️ CATEGORY: KUBERNETES & CONTAINER ORCHESTRATION
**Tech Stack:** Google Kubernetes Engine (GKE), Docker (Multi-Stage), Helm, Ingress-Nginx, Cert-Manager, Cloud SQL Proxy, Kustomize
* "Deployed and managed a highly available Google Kubernetes Engine (GKE) cluster, utilizing custom node pools and auto-scaling to optimize compute resources."
* "Engineered a robust public traffic routing layer using `ingress-nginx` as a Kubernetes LoadBalancer, configured with custom Helm overrides for optimized external traffic policies."
* "Automated SSL/TLS certificate provisioning and renewal by deploying `cert-manager` to the GKE cluster, ensuring end-to-end encryption for all public-facing endpoints."
* "Containerized a multi-service architecture (Node.js API, Python ETL, React Dashboard, Simulators) using optimized, multi-stage Dockerfiles to eliminate build toolchains from production images and minimize attack surfaces."
* "Refactored monolithic Kubernetes manifests into decoupled, domain-driven Kustomize layers (`apps`, `data`, `networking`, `observability`), standardizing modern Kustomize v5 declarative syntax and eliminating deprecation warnings."
* "Orchestrated Cloud SQL Auth Proxy sidecar containers across application and migration workloads, eliminating startup race conditions and blocking initContainers to ensure reliable, concurrent local socket connectivity to managed PostgreSQL."
* "Hardened Kubernetes Pod Security Standards by aligning `runAsUser: 1000` / `runAsGroup: 1000` with container non-root users, and upgraded pod probes from basic `tcpSocket` checks to deep HTTP application health endpoints (`/health`)."

## 🏷️ CATEGORY: GITOPS, CI/CD, & DEVOPS
**Tech Stack:** ArgoCD, GitHub Actions, Kustomize, GitHub Environments, Trivy, Artifact Registry (GAR), GHCR
* "Transitioned legacy push-based deployment models to a highly secure, Pull-based GitOps architecture using ArgoCD, completely isolating the production Kubernetes cluster from the CI server."
* "Designed a trunk-based deployment strategy using Kustomize (`base` and `overlays`), enabling safe, independent deployment configurations for Development and Production environments from a single repository branch."
* "Built a continuous integration (CI) pipeline using GitHub Actions to automatically lint, test, and build Docker images, pushing secure artifacts directly to GCP Artifact Registry."
* "Orchestrated zero-downtime database migrations via ArgoCD Sync Waves and Hooks (`argocd.argoproj.io/hook: Sync`, `BeforeHookCreation`), guaranteeing Flyway schema migrations execute to completion before initiating application rollouts."
* "Integrated automated container vulnerability scanning into the CI/CD pipeline using Trivy, scanning OS base images and application dependencies for CVEs prior to publishing to Artifact Registry."
* "Enforced strict CI/CD security boundaries by utilizing GitHub Environments, scoping sensitive infrastructure secrets and deployment approval gates specifically to 'dev' and 'prod' contexts."
* "Enforced strict GitOps discipline separating CI automated image tagging from cluster state mutations, maintaining an immutable audit log and zero configuration drift via automated ArgoCD self-healing."

## 🏷️ CATEGORY: ZERO-TRUST SECURITY & IAM
**Tech Stack:** GCP Workload Identity Federation (WIF), Cloudflare Tunnels (`cloudflared`), Pod Security Standards (PSS)
* "Architected a passwordless, Zero-Trust CI/CD pipeline by replacing long-lived JSON service account keys with ephemeral OIDC Workload Identity Federation (WIF) for GitHub Actions."
* "Eliminated hardcoded database credentials by binding Kubernetes Service Accounts directly to Cloud SQL via IAM Workload Identity, allowing pods to authenticate securely via short-lived Google tokens."
* "Secured Kubernetes public ingress by implementing Cloudflare Zero Trust Tunnels (`cloudflared`), entirely bypassing the need for open inbound firewall ports and hiding the cluster behind Cloudflare's edge."
* "Automated dynamic DNS provisioning by configuring in-cluster Cloudflare Tunnels to route environment-specific subdomains dynamically to internal Kubernetes services."
* "Hardened container runtime security across all microservices by replacing root execution with dedicated, unprivileged system users (UID 1000 `node:node`, `simuser`) aligned with Kubernetes Pod Security Standards."

## 🏷️ CATEGORY: DATA ENGINEERING, IoT & ETL (THE PIPELINE)
**Tech Stack:** Python, Pandas, InfluxDB, MQTT (Paho), Telegraf, Loguru, Wheel Compilers
* "Architected an end-to-end IoT data pipeline: capturing simulated MCU sensor telemetry via MQTT, routing it through Telegraf, and storing high-frequency time-series data in InfluxDB."
* "Engineered a multi-stage data synchronization strategy where raw time-series data in InfluxDB is continuously evaluated by a Python ETL processor to identify anomalies and sync critical alerts into PostgreSQL."
* "Developed a high-throughput Python ETL script utilizing `pandas` and `numpy` for data aggregation, ensuring overlapping telemetry windows are deduplicated before writing to the relational database."
* "Designed a dual-visualization observability layer: utilizing Grafana for real-time telemetry analytics directly from InfluxDB, and a custom Node.js frontend dashboard for historical incident reporting from PostgreSQL."
* "Optimized Python ETL packaging using a multi-stage wheel builder Docker architecture, isolating C-compilers and build headers from runtime images and slashing production image size."
* "Implemented dynamic telemetry node status tracking (`online`, `warning`, `offline`) based on MQTT heartbeat timeouts, isolating disconnected sensor streams without discarding historical readings."
* "Implemented structured, asynchronous application logging across the Python ETL stack using the `loguru` library to facilitate efficient debugging and log aggregation."

## 🏷️ CATEGORY: BACKEND DEVELOPMENT & DATABASE MANAGEMENT
**Tech Stack:** Node.js, Express.js, PostgreSQL (Cloud SQL), Flyway, REST API, connect-pg-simple
* "Built a scalable, RESTful JSON API using Node.js and Express.js, providing secure, authenticated endpoints for dashboard analytics and user management."
* "Implemented secure user authentication with `bcrypt` password hashing and persistent session management stored directly in PostgreSQL via `express-session`."
* "Eliminated `connect-pg-simple` session startup race conditions by standardizing pre-verified PostgreSQL session tables and enforcing explicit asynchronous session persistence (`req.session.save()`) on login, preventing lost sessions under rapid client navigation."
* "Provisioned a fully managed, highly available PostgreSQL database via Google Cloud SQL, optimizing connection pooling in the Node.js backend to handle concurrent analytical queries."
* "Authored and managed 19+ Flyway schema migrations, normalizing incident records, decoupling geographic metadata into a dedicated `device_registry`, and seeding high-precision NCR coordinates for spatial telemetry."
* "Automated PostgreSQL schema evolution by deploying Flyway database migrations as ephemeral Kubernetes Jobs, ensuring zero-downtime schema upgrades prior to API pod initialization."
* "Redesigned `/api/latest` and `/api/devices` endpoints to join active telemetry with registered sensor nodes, preserving historical last-known telemetry during disconnections to prevent false `0.0` readings."

## 🏷️ CATEGORY: OBSERVABILITY & MONITORING
**Tech Stack:** Grafana, Grafana Alloy, Prometheus (prom-client), Loki, cAdvisor, Node Exporter, postgres-exporter, NGINX Reverse Proxy
* "Deployed a full-stack Kubernetes observability ecosystem combining Prometheus, Grafana, Grafana Alloy (DaemonSet log collector), Loki, Node Exporter, and cAdvisor."
* "Tuned cAdvisor metric collection to essential subsystems (`cpu`, `memory`, `network`, `oom_event`) and adjusted Prometheus scrape timeouts to 20 seconds, resolving scrape timeouts and node OOM thrashing."
* "Engineered dynamic multi-environment namespace discovery in the API observability layer, automatically querying in-cluster Prometheus and Loki services across dynamic dev/prod deployments without hardcoded hostnames."
* "Implemented container stream alias mapping in Loki log aggregation, unifying Cloud SQL Auth Proxy sidecar logs with PostgreSQL application queries over configurable 24-hour lookback windows."
* "Implemented 'Observability as Code' by exporting Grafana dashboard JSON configurations and strictly version-controlling them in Git, ensuring rapid disaster recovery and peer-reviewed UI changes."
* "Instrumented the Node.js API with custom Prometheus metrics (`prom-client`) to monitor API latency, error rates, and active database connection pools."
* "Secured internal observability infrastructure by configuring NGINX as a reverse proxy, safely exposing the Grafana dashboard via custom subdomains (`ops.fires.systems`) without opening direct public ports."

## 🏷️ CATEGORY: FRONTEND ENGINEERING & COMMAND CENTER UI
**Tech Stack:** React 19, TypeScript, Vite, Tailwind CSS, MapLibre GL, WebGL, Recharts, Lucide Icons
* "Architected a high-performance, real-time command center dashboard in React and TypeScript, leveraging MapLibre GL and WebGL for interactive 3D spatial telemetry visualization."
* "Restructured modal views into a unified `CommandCenterModal` and System Diagnostics suite with segmented navigation controls across Diagnostics, Performance Metrics, and Infrastructure Data views."
* "Achieved a true zero-placeholder architecture by replacing mock components with live, queried telemetry directly from PostgreSQL, Prometheus, and InfluxDB backend endpoints."
* "Eliminated WebGL canvas crashes and UI projection thrashing under rapid MQTT telemetry ingestion through React component memoization (`React.memo`) and frame throttling."
* "Engineered real-time anomaly indicators featuring animated pulsing markers and auto-framing bounding boxes over active sensor clusters in the National Capital Region (NCR)."
* "Implemented dynamic telemetry node status tracking (`online`, `warning`, `offline`) in custom React hooks (`useLiveSensors`, `useDashboardData`), evaluating heartbeat expirations against real-time MQTT message streams."

## 🏷️ CATEGORY: DEVELOPER TOOLING, AUTOMATION & SRE
**Tech Stack:** GNU Make, Bash, Kind (Kubernetes in Docker), Podman/Docker Compose, Kubectl Contexts
* "Engineered a full-lifecycle Developer CLI via an advanced GNU Makefile supporting 5 SDLC environments: local Docker Compose, Kind Kubernetes, Staging (GKE Dev via ArgoCD), and guarded Production."
* "Built automated pre-flight port conflict detection (`lsof`/`nc`) and background daemon management (`dev-port-forward`), preventing orphaned proxy collisions and shell lockups."
* "Enforced explicit `kubectl` context validation across all automation targets, eliminating accidental configuration drift or destructive commands across cloud clusters."
* "Streamlined local Kubernetes development by configuring automated Kind cluster initialization, rootless container patches, and live image hot-reloading."
