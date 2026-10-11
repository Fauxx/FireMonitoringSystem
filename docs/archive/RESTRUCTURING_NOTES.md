# 🏗️ Architecture & Restructuring Changelog

This document tracks major structural reorganizations, refactoring decisions, and operational audits in the **FireMonitoringSystem** repository.

---

## 📅 2026-10-11 — Application Packaging & Kubernetes Alignment

### 1. Context & Motivation
An end-to-end audit revealed that:
* Flyway migrations were stored under `infrastructure/k8s/base/sql`, requiring custom path filters in CI and mixing data schema code into Kubernetes cluster manifests.
* Custom Dockerfiles suffered from single-stage compilation bloat, deprecated npm arguments, unoptimized layer caches, and UID/GID mismatches with Kubernetes pod security contexts.
* Kubernetes base manifests contained hardcoded development database strings and dev Workload Identity GCP annotations.
* Deprecated Kustomize syntax (`commonLabels`, `patchesStrategicMerge`) generated warnings in modern tooling.

---

### 2. Changes Implemented

#### A. Applications & Container Images
* **New Application Module — [apps/db-migrations/](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/db-migrations/)**:
  * Moved all Flyway SQL scripts (`V1`–`V19` and `manual/`) to `apps/db-migrations/sql/`.
  * Added dedicated [Dockerfile](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/db-migrations/Dockerfile) and [.dockerignore](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/db-migrations/.dockerignore).
  * Removed obsolete `infrastructure/k8s/base/sql/` directory.
* **Multi-Stage Node & Python Builds**:
  * **[apps/api/Dockerfile](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/api/Dockerfile)**: Multi-stage build isolates `bcrypt` compilation tools (`python3`, `make`, `g++`) to the builder stage. Production runner uses standard `node:node` (UID 1000) and `npm ci --omit=dev`.
  * **[apps/etl-processor/Dockerfile](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/etl-processor/Dockerfile)**: Multi-stage wheel builder compiles dependencies in Stage 1; runtime stage installs `.whl` files with runtime `libpq`, eliminating heavy C-compilers (`gcc`, `build-base`) from the runtime image.
  * **[apps/simulators/Dockerfile](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/simulators/Dockerfile)**: Upgraded to Python 3.12-slim and created dedicated non-root user `simuser` (UID 1000).
* **Docker Context Hygiene**:
  * Added [.dockerignore](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/dashboard/.dockerignore) to `apps/dashboard/` to prevent sending 30,000+ local `node_modules` files to Docker during builds.
  * Added [.dockerignore](file:///home/zett/RiderProjects/FireMonitoringSystem/apps/simulators/.dockerignore) to `apps/simulators/`.

#### B. CI/CD & Local Tooling
* **[.github/workflows/app-pipeline.yml](file:///home/zett/RiderProjects/FireMonitoringSystem/.github/workflows/app-pipeline.yml)**:
  * Unified change detection to trigger on `apps/**`.
  * Simplified build context resolution: all 5 image targets now resolve cleanly to `./apps/${{ matrix.service }}`.
* **[Makefile](file:///home/zett/RiderProjects/FireMonitoringSystem/Makefile)** & **[docker-compose.local.yml](file:///home/zett/RiderProjects/FireMonitoringSystem/build/local/docker-compose.local.yml)**:
  * Updated local build commands and volume mounts to reference `./apps/db-migrations`.

#### C. Kubernetes (`infrastructure/k8s/`)
* **[api/deployment.yaml](file:///home/zett/RiderProjects/FireMonitoringSystem/infrastructure/k8s/base/api/deployment.yaml)**:
  * Aligned `runAsUser: 1000` / `runAsGroup: 1000` with the `node` user in the container image.
  * Upgraded liveness/readiness probes from `tcpSocket` to `httpGet` on `/health`.
* **[etl/deployment.yaml](file:///home/zett/RiderProjects/FireMonitoringSystem/infrastructure/k8s/base/etl/deployment.yaml)**:
  * Replaced hardcoded dev database connection string with dynamic `$(CLOUD_SQL_CONNECTION_NAME)` from `fire-monitoring-config`.
* **[overlays/prod/kustomization.yaml](file:///home/zett/RiderProjects/FireMonitoringSystem/infrastructure/k8s/overlays/prod/kustomization.yaml)**:
  * Migrated deprecated `commonLabels` to `labels`.
  * Migrated deprecated `patchesStrategicMerge` to `patches`.
* **Cleaned Artifacts**:
  * Removed unneeded snapshot files (`compiled_k8s.yaml`, `compiled_k8s_prod.yaml`) and transient test scripts.
