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
**Tech Stack:** Google Kubernetes Engine (GKE), Docker, Helm, Ingress-Nginx, Cert-Manager
* "Deployed and managed a highly available Google Kubernetes Engine (GKE) cluster, utilizing custom node pools and auto-scaling to optimize compute resources."
* "Engineered a robust public traffic routing layer using `ingress-nginx` as a Kubernetes LoadBalancer, configured with custom Helm overrides for optimized external traffic policies."
* "Automated SSL/TLS certificate provisioning and renewal by deploying `cert-manager` to the GKE cluster, ensuring end-to-end encryption for all public-facing endpoints."
* "Containerized a multi-service architecture (Node.js API, Python ETL, NGINX Frontend) using optimized, multi-stage Dockerfiles to minimize image bloat and attack surface."

## 🏷️ CATEGORY: GITOPS, CI/CD, & DEVOPS
**Tech Stack:** ArgoCD, GitHub Actions, Kustomize, GitHub Environments
* "Transitioned legacy push-based deployment models to a highly secure, Pull-based GitOps architecture using ArgoCD, completely isolating the production Kubernetes cluster from the CI server."
* "Designed a trunk-based deployment strategy using Kustomize (`base` and `overlays`), enabling safe, independent deployment configurations for Development and Production environments from a single repository branch."
* "Built a continuous integration (CI) pipeline using GitHub Actions to automatically lint, test, and build Docker images, pushing secure artifacts directly to GCP Artifact Registry."
* "Enforced strict CI/CD security boundaries by utilizing GitHub Environments, scoping sensitive infrastructure secrets and deployment approval gates specifically to 'dev' and 'prod' contexts."
* "Implemented self-healing Kubernetes deployments via ArgoCD automated sync policies, ensuring zero configuration drift between the Git repository and live cluster state."

## 🏷️ CATEGORY: ZERO-TRUST SECURITY & IAM
**Tech Stack:** GCP Workload Identity Federation (WIF), Cloudflare Tunnels (`cloudflared`)
* "Architected a passwordless, Zero-Trust CI/CD pipeline by replacing long-lived JSON service account keys with ephemeral OIDC Workload Identity Federation (WIF) for GitHub Actions."
* "Eliminated hardcoded database credentials by binding Kubernetes Service Accounts directly to Cloud SQL via IAM Workload Identity, allowing pods to authenticate securely via short-lived Google tokens."
* "Secured Kubernetes public ingress by implementing Cloudflare Zero Trust Tunnels (`cloudflared`), entirely bypassing the need for open inbound firewall ports and hiding the cluster behind Cloudflare's edge."
* "Automated dynamic DNS provisioning by configuring in-cluster Cloudflare Tunnels to route environment-specific subdomains dynamically to internal Kubernetes services."

## 🏷️ CATEGORY: DATA ENGINEERING, IoT & ETL (THE PIPELINE)
**Tech Stack:** Python, Pandas, InfluxDB, MQTT (Paho), Telegraf, Loguru
* "Architected an end-to-end IoT data pipeline: capturing simulated MCU sensor telemetry via MQTT, routing it through Telegraf, and storing high-frequency time-series data in InfluxDB."
* "Engineered a multi-stage data synchronization strategy where raw time-series data in InfluxDB is continuously evaluated by a Python ETL processor to identify anomalies and sync critical alerts into PostgreSQL."
* "Developed a high-throughput Python ETL script utilizing `pandas` and `numpy` for data aggregation, ensuring overlapping telemetry windows are deduplicated before writing to the relational database."
* "Designed a dual-visualization observability layer: utilizing Grafana for real-time telemetry analytics directly from InfluxDB, and a custom Node.js frontend dashboard for historical incident reporting from PostgreSQL."
* "Implemented structured, asynchronous application logging across the Python ETL stack using the `loguru` library to facilitate efficient debugging and log aggregation."

## 🏷️ CATEGORY: BACKEND DEVELOPMENT & DATABASE MANAGEMENT
**Tech Stack:** Node.js, Express.js, PostgreSQL (Cloud SQL), Flyway, REST API
* "Built a scalable, RESTful JSON API using Node.js and Express.js, providing secure, authenticated endpoints for dashboard analytics and user management."
* "Implemented secure user authentication with `bcrypt` password hashing and persistent session management stored directly in PostgreSQL via `express-session`."
* "Provisioned a fully managed, highly available PostgreSQL database via Google Cloud SQL, optimizing connection pooling in the Node.js backend to handle concurrent analytical queries."
* "Automated PostgreSQL schema evolution by deploying Flyway database migrations as ephemeral Kubernetes Jobs, ensuring zero-downtime schema upgrades prior to API pod initialization."
* "Architected relational database schemas prioritizing data integrity, utilizing advanced PostgreSQL features like unique telemetry constraints and standardized timezone structures."

## 🏷️ CATEGORY: OBSERVABILITY & MONITORING
**Tech Stack:** Grafana, Grafana Alloy, Prometheus (prom-client), NGINX Reverse Proxy
* "Deployed Grafana Alloy as a centralized OpenTelemetry collector pipeline to efficiently gather, process, and route backend observability data to visualization endpoints."
* "Implemented 'Observability as Code' by exporting Grafana dashboard JSON configurations and strictly version-controlling them in Git, ensuring rapid disaster recovery and peer-reviewed UI changes."
* "Instrumented the Node.js API with custom Prometheus metrics (`prom-client`) to monitor API latency, error rates, and active database connection pools."
* "Secured internal observability infrastructure by configuring NGINX as a reverse proxy, safely exposing the Grafana dashboard via custom subdomains (`ops.fires.systems`) without opening direct public ports."
* "Integrated Kubernetes Ingress routing with Cloudflare Tunnels to provide encrypted, Zero-Trust access to administrative Grafana dashboards for remote operations."
