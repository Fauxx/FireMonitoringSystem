---
sidebar_position: 1
title: Overview
---

# Architecture Overview

This document outlines the architecture for the **Fire Monitoring System**, an IoT-based telemetry and analytics platform designed for Cloud-Native environments using a Zero-Trust security posture and GitOps deployment model.

## 🏗️ Overall System Architecture

The Fire Monitoring System follows a decoupled, microservices-based architecture:
- **Edge / Ingestion**: IoT sensors push telemetry via MQTT.
- **Processing Layer**: A Python ETL processor debounces alerts and downsamples metrics.
- **Data Layer**: PostgreSQL (relational logs, sessions, incidents) and InfluxDB (time-series).
- **Application Layer**: A Node.js Express REST API serving data to an Nginx-backed web dashboard.
- **Observability**: A robust Prometheus, Loki, and Grafana stack.

## 🔄 Current vs. Target Architecture

| Component | **CURRENT (Implementation)** | **TARGET (Planned/GKE)** | **LEGACY (Deprecated)** |
| :--- | :--- | :--- | :--- |
| **Cloud Provider** | Local (Kind Kubernetes) | **Google Cloud Platform (GCP)** | DigitalOcean (DOKS), Azure (AKS) |
| **Cluster Engine** | Kind | **Google Kubernetes Engine (GKE)** | DigitalOcean Kubernetes |
| **Ingress Network**| `cloudflared` (dev/prod) | `cloudflared` over GKE Dataplane V2 | DO Load Balancers |
| **State Storage**  | DigitalOcean Spaces (S3 API)| GCS Bucket (assumed/pending setup) | DigitalOcean Spaces |

> **Note:** The GCP/GKE migration is currently in the **PLANNED** phase. Terraform modules (`infrastructure/terraform/modules/gke`) and CI/CD pipelines (`gcp-terraform-deploy.yml`) exist, but the live cloud deployment relies on local Kind emulation during this transition.

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
