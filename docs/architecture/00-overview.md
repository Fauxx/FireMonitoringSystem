---
sidebar_position: 1
title: Overview
---

# Architecture Overview

This document outlines the architecture for the **Fire Monitoring System**, an IoT-based telemetry and analytics platform designed for Cloud-Native environments using a Zero-Trust security posture and GitOps deployment model.

## 🏗️ Overall System Architecture

The Fire Monitoring System follows a decoupled, microservices-based architecture:
- **Edge / Ingestion**: IoT sensors push telemetry via MQTT to Mosquitto and Telegraf.
- **Processing Layer**: A Python pandas ETL processor debounces alerts (30-min window) and downsamples metrics (5-min rollups).
- **Data Layer**: Cloud SQL PostgreSQL (relational logs, sessions, incidents) and InfluxDB v2 (time-series).
- **Application Layer**: A Node.js Express REST API serving real-time and analytical data to a React 19 + Vite + Tailwind CSS Command Center Dashboard.
- **Observability**: A robust Prometheus, Loki, Grafana Alloy, and Grafana stack with dynamic namespace discovery.

## 🔄 Cloud & Runtime Architecture

| Component | **Target / Production (GKE)** | **Staging / Dev (GKE Dev)** | **Local Sandbox (Kind / Docker Compose)** |
| :--- | :--- | :--- | :--- |
| **Cloud Provider** | **Google Cloud Platform (GCP)** | **Google Cloud Platform (GCP)** | Local Workstation (Kind / Podman / Docker) |
| **Cluster Engine** | **GKE Dataplane V2 (eBPF)** | **GKE Dataplane V2 (eBPF)** | Kind (Kubernetes-in-Docker) |
| **Ingress Network**| `cloudflared` Zero Trust Tunnels | `cloudflared` Zero Trust Tunnels | Nginx Ingress / Local Port-Forwarding |
| **State Storage**  | Google Cloud Storage (`gs://firemonitoring-tfstate`) | Google Cloud Storage (`gs://firemonitoring-tfstate`) | Local directory / `.env` config |
| **Relational Database** | Managed Google Cloud SQL (PostgreSQL 16) | Managed Google Cloud SQL (PostgreSQL 16) | In-cluster / Compose PostgreSQL |
| **Delivery Model** | GitOps via ArgoCD (Semver Release Tags) | GitOps via ArgoCD (Direct Main Merge) | Local Kustomize / Compose Reload |

## 🧩 Major Architectural Boundaries

- **Internet / Edge**: Traffic is routed securely via Cloudflare Tunnels (`cloudflared`) to bypass public IPs and DDoS threats.
- **Ingress Controller**: `ingress-nginx` acts as the cluster gateway and auth-proxy verifier.
- **Application Namespace**: Houses the API, Dashboard, and ETL workers (`fire-monitoring-dev` / `prod`).
- **Data & Observability Namespaces**: Segregated services adhering to Zero-Trust default-deny Network Policies.

## 🏛️ Source-of-Truth Model

We strictly enforce a declarative **GitOps** pipeline where the Git repository is the absolute source of truth:

1. **Terraform → GCP/GKE**:
   - Manages cloud infrastructure (VPCs, GKE clusters, DNS).
   - Applied via GitHub Actions (`gcp-terraform-deploy.yml`).
2. **Git/Kustomize → Kubernetes Desired State**:
   - Application configurations reside in `infrastructure/k8s/base` and `overlays`.
3. **ArgoCD → GitOps Reconciliation**:
   - ArgoCD runs in the cluster, pulling from the GitHub repository to continually reconcile live K8s state with the Git manifests.

## ⚙️ CI/CD Flow

The CI/CD pipeline (`app-pipeline.yml`) runs on GitHub Actions in 4 stages:
1. **Change Detection**: Uses `dorny/paths-filter` to only build changed services.
2. **Build & Scan**: Builds containers, runs Trivy security scans, and pushes to GHCR.
3. **Dev Deploy (Push)**: Commits the new image tag directly to the `dev` Kustomize overlay in Git. ArgoCD pulls this into the `gke-dev` environment.
4. **Prod Promote (Release Tag)**: Automatically opens a Pull Request to merge the new tag into the `prod` Kustomize overlay.

## 🌍 Major Environments

- **local**: Sandboxed `Kind` cluster. Disables cloudflared, uses `imagePullPolicy: Never` to test locally built images.
- **gke-dev**: Staging environment. Single replicas, 100 RPS limits, permissive CORS.
- **gke-prod**: Production environment. Scaled replicas, Let's Encrypt TLS, strict rate limits (50 RPS).
