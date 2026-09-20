---
sidebar_position: 2
title: GCP & GKE Infrastructure
---

# Target GCP/GKE Architecture

> **STATUS: TARGET / PLANNED**  
> The resources described below represent the *target state* for the Google Cloud Platform migration. As of the current audit, Terraform modules are defined and GitHub Actions CI/CD workflows are configured, but the infrastructure is not yet fully provisioned. 
> 
> *Legacy Note: Historical architecture utilized DigitalOcean (DOKS) and Azure (AKS), which are being replaced by this GKE architecture.*

## 🏗️ Terraform Environment Structure

The Terraform implementation follows a strict 4-layer sequential deployment pattern. This prevents state lock bottlenecks and handles complex dependencies (e.g., installing Helm charts only after the Kubernetes API is fully available).

```text
infrastructure/terraform/environments/<env>/
├── 00-bootstrap/  # State buckets, locks, remote backend config
├── 01-infra/      # Network, DNS, GKE Cluster
├── 02-platform/   # Helm Charts (ArgoCD, Ingress-Nginx)
└── 03-argocd/     # GitOps application bootstrapping
```

### Layer 00: Bootstrap
Configures remote state storage. The CI/CD pipelines require a dedicated remote backend (assumed GCS, replacing the legacy DigitalOcean Spaces/AWS S3 implementations) to prevent concurrent modification risks.

### Layer 01: Infrastructure
Provisions the core Google Cloud resources:
- **VPC & Networking**: Dedicated VPC, Subnets, Pod/Service secondary IP ranges.
- **Google Cloud DNS**: Managed zones and A records.
- **GKE Cluster**: Uses the `infrastructure/terraform/modules/gke/cluster` module.

### Layer 02: Platform
Deploys cluster-level Helm charts prior to application workloads:
- **Ingress-Nginx**: The primary Kubernetes ingress controller (`ingress-nginx` chart v4.12.0). Configured with `externalTrafficPolicy: Local`.
- **ArgoCD**: The continuous delivery GitOps agent.

### Layer 03: ArgoCD GitOps
Orchestrates the GitHub App secrets synchronization and registers the root ArgoCD `App-of-Apps` application to trigger the GitOps pull cycle.

## ☸️ GKE Module Configuration

The target GKE cluster is defined in `infrastructure/terraform/modules/gke/cluster` with several specific platform decisions:

- **GKE Dataplane V2 (`ADVANCED_DATAPATH`)**: Replaces the legacy Azure CNI / Calico setup, providing built-in eBPF-based networking and strict NetworkPolicy enforcement.
- **Private Cluster Topology**:
  - `enable_private_nodes = true`
  - `enable_private_endpoint = false` (Public master endpoint restricted via `master_authorized_networks_config`).
- **Shielded Instances**: Secure boot and integrity monitoring enabled at the node pool level.
- **Maintenance Policy**: Forced weekly maintenance window (Sunday 02:00–06:00 UTC).

## 🔐 IAM & Workload Identity

To eliminate static service account keys, the architecture implements **GKE Workload Identity** (`workload_metadata_config { mode = "GKE_METADATA" }`).
- Kubernetes Service Accounts (KSAs) bind directly to Google Service Accounts (GSAs).
- Workload Pool: `${var.project_id}.svc.id.goog`

## 🌐 DNS & Edge Components

- **Google Cloud DNS** manages the zones.
- **Cloudflare Tunnels (`cloudflared`)** act as the primary edge ingress, rendering traditional public Load Balancers optional for standard web traffic. Tunnels proxy requests directly into the `ingress-nginx` controller inside the private GKE nodes.
