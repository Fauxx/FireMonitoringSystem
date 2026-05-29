# Fire Monitoring System: Infrastructure Handshake Trace

This document explains where each automation boundary starts and ends across Terraform, Kubernetes/ArgoCD, and GitHub Actions. It focuses on code-level data flow and dependency order.

## 1. Terraform State and Variables Trace

### 1.1 Variable Inheritance: `*.tfvars` -> `variables.tf` -> resources/modules

Entry point (per environment):
- [infrastructure/terraform/environments/dev/terraform.tfvars](infrastructure/terraform/environments/dev/terraform.tfvars)
- [infrastructure/terraform/environments/dev/variables.tf](infrastructure/terraform/environments/dev/variables.tf)
- [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf)

Flow:
1. Environment values are loaded from `terraform.tfvars` or generated CI values in `runtime.auto.tfvars`.
2. Variables are declared with defaults and sensitivity in [infrastructure/terraform/environments/dev/variables.tf](infrastructure/terraform/environments/dev/variables.tf).
3. Those values directly feed cluster resources and Kubernetes objects in [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L83) and beyond.
4. A subset is forwarded into child module `github_secrets` in [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L382).

Example trace (end-to-end):
- `argocd_auth_token` from tfvars -> variable declaration -> Terraform creates Kubernetes secret key `argocd.token` for image updater in [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L224) -> the same value is also passed into module `github_secrets` in [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L393) -> module publishes GitHub Environment secret `ARGOCD_AUTH_TOKEN` in [infrastructure/terraform/modules/github-secrets/main.tf](infrastructure/terraform/modules/github-secrets/main.tf#L117).

### 1.2 Backend and State Locking Contract

Terraform backend declaration is intentionally empty in code and populated at init:
- Backend block: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L4)
- Local backend template: [infrastructure/terraform/environments/dev/backend.conf](infrastructure/terraform/environments/dev/backend.conf)
- CI backend injection + init logic: [.github/actions/terraform-contract/action.yml](.github/actions/terraform-contract/action.yml)

CI runtime behavior:
1. Workflow computes `backend_key` (`<prefix>/<env>/terraform.tfstate`) in [.github/workflows/terraform-infra.yml](.github/workflows/terraform-infra.yml#L78).
2. Composite action validates required backend inputs and runs `terraform init -reconfigure` with S3-compatible options in [.github/actions/terraform-contract/action.yml](.github/actions/terraform-contract/action.yml#L189).
3. Plan/apply uses lock timeout `-lock-timeout=300s` in [.github/workflows/terraform-infra.yml](.github/workflows/terraform-infra.yml#L104).
4. Workflow-level concurrency prevents overlapping runs per ref/environment in [.github/workflows/terraform-infra.yml](.github/workflows/terraform-infra.yml#L27).

### 1.3 Provider Logic Used to Bootstrap Cluster and GitOps

Provider versions are pinned in [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L7):
- `digitalocean >= 2.40.0`
- `github ~> 6.0`
- `kubernetes ~> 2.30`
- `helm ~> 2.13`

Bootstrap sequence in code:
1. Create DOKS cluster: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L83)
2. Configure Kubernetes and Helm providers from the created cluster endpoint/token/CA: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L101)
3. Create app namespace and `argocd` namespace: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L115)
4. Create app runtime Secret/ConfigMap and GHCR pull secret: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L127)
5. Install Argo CD Helm chart: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L237)
6. Install `argocd-image-updater` chart: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L277)
7. Create Argo CD `Application` object to watch overlay path: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L323)
8. Sync selected values to GitHub Environment secrets via module: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L382)

### 1.4 Output Mapping and Current Gaps

Published outputs are in [infrastructure/terraform/environments/dev/outputs.tf](infrastructure/terraform/environments/dev/outputs.tf):
- `kubernetes_cluster_name`
- `kubernetes_namespace`
- `kubeconfig` (sensitive)

Workflow exports these outputs to artifact only in [.github/workflows/terraform-infra.yml](.github/workflows/terraform-infra.yml#L161).

Important handshake observation:
- There is no downstream workflow consuming `terraform-outputs.json` currently.
- Runtime pod config is primarily wired via Kubernetes Secret/ConfigMap resources created in Terraform, not Terraform outputs.

## 2. ArgoCD GitOps Loop

### 2.1 Bootstrap Mechanism (Where Terraform Hands Off to Argo CD)

Argo CD is installed by Terraform Helm release, not by manual kubectl:
- [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L237)

Repository access is bootstrapped with an Argo CD repository secret:
- [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L190)

Then Terraform creates the initial Argo CD `Application`:
- [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L323)

This is the effective root app in this repo (single-app bootstrap). There is no separate app-of-apps manifest file.

### 2.2 What Argo CD Watches

Application source is configured in Terraform:
- `repoURL = https://github.com/<owner>/<repo>.git`
- `path = infrastructure/k8s/overlays/dev`
- `targetRevision = main`

Reference: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L349)

Overlay structure:
- Base manifests: [infrastructure/k8s/base/kustomization.yaml](infrastructure/k8s/base/kustomization.yaml)
- Dev overlay: [infrastructure/k8s/overlays/dev/kustomization.yaml](infrastructure/k8s/overlays/dev/kustomization.yaml)
- Prod overlay: [infrastructure/k8s/overlays/prod/kustomization.yaml](infrastructure/k8s/overlays/prod/kustomization.yaml)

### 2.3 Value Overrides and Merge Behavior

This repo uses Kustomize overlays (not Helm values files for app workloads):
1. `base` defines shared resources/config generators.
2. Overlay sets namespace and image substitutions.
3. Argo CD applies rendered overlay for destination namespace.

Image updater annotations on the `Application` control automated tag updates for Kustomize image names:
- [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L333)

### 2.4 Sync Policy and Drift Handling

Argo CD app is configured with automated sync:
- `prune: true`
- `selfHeal: true`
- `allowEmpty: false`
- retry backoff configured

Reference: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L358)

Operationally, there are two sync triggers:
1. Continuous Argo reconciliation from `syncPolicy.automated`.
2. Explicit CLI sync in workflow for manual/forced synchronization:
   - [.github/workflows/app-cd-deploy.yml](.github/workflows/app-cd-deploy.yml)
   - [.github/workflows/app-cd-manifest-trigger.yml](.github/workflows/app-cd-manifest-trigger.yml)

## 3. GitHub Actions CI/CD Pipeline

### 3.1 Path Filters and Trigger Boundaries

Terraform workflow (infra changes only):
- [.github/workflows/terraform-infra.yml](.github/workflows/terraform-infra.yml)
- Triggers on `infrastructure/terraform/**`, workflow file, and terraform-contract action path.

App CI image build workflow:
- [.github/workflows/app-ci-build.yml](.github/workflows/app-ci-build.yml)
- Triggers on `apps/api/**`, `apps/dashboard/**`, `apps/etl-processor/**`, compose files, and workflow file.

Manifest-to-sync workflow:
- [.github/workflows/app-cd-manifest-trigger.yml](.github/workflows/app-cd-manifest-trigger.yml)
- Triggers on `infrastructure/k8s/**` and its own workflow file.

### 3.2 Jobs and Secret Injection Points

Terraform jobs:
- Shared contract action injects `TF_VAR_*` values via generated `runtime.auto.tfvars` in [.github/actions/terraform-contract/action.yml](.github/actions/terraform-contract/action.yml#L151).
- Backend secrets are passed as action inputs and consumed only during `terraform init`.

Argo CD sync jobs:
- Requires `ARGOCD_SERVER` and `ARGOCD_AUTH_TOKEN` environment secrets.
- Used as environment variables when running `argocd app sync`.

References:
- [.github/workflows/terraform-infra.yml](.github/workflows/terraform-infra.yml)
- [.github/workflows/app-cd-deploy.yml](.github/workflows/app-cd-deploy.yml)
- [.github/workflows/app-cd-manifest-trigger.yml](.github/workflows/app-cd-manifest-trigger.yml)

### 3.3 State Corruption Controls

Controls present:
1. Workflow concurrency grouping in Terraform workflow.
2. Terraform CLI lock timeout (`-lock-timeout=300s`) on plan/apply/destroy.
3. Plan/apply split with explicit artifact generation.

Limitation:
- There is no cross-workflow dependency that forces Terraform apply completion before Argo CD sync workflows run. They are decoupled by trigger path and manual dispatch.

## 4. The Connection: How Terraform Data Becomes Runtime in Pods/ArgoCD

### 4.1 Terraform -> Kubernetes Runtime (Implemented)

Implemented handshake:
1. Terraform creates `fire-monitoring-config` ConfigMap and `fire-monitoring-secrets` Secret in app namespace.
2. Base manifests mount them using `envFrom` in deployments/statefulsets/jobs.

Examples:
- API consumes both in [infrastructure/k8s/base/api/deployment.yaml](infrastructure/k8s/base/api/deployment.yaml#L25)
- ETL consumes both in [infrastructure/k8s/base/etl/deployment.yaml](infrastructure/k8s/base/etl/deployment.yaml#L23)
- DB consumes both in [infrastructure/k8s/base/db/statefulset.yaml](infrastructure/k8s/base/db/statefulset.yaml#L24)

Terraform also creates GHCR pull secret `ghcr-credentials`, consumed via `imagePullSecrets`:
- Created in [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L176)
- Consumed by API in [infrastructure/k8s/base/api/deployment.yaml](infrastructure/k8s/base/api/deployment.yaml#L17)

### 4.2 Terraform -> Argo CD Config (Implemented)

Implemented handshake:
1. Terraform installs Argo CD.
2. Terraform injects repo credential secret and image updater token/registry secrets in Argo namespace.
3. Terraform creates Argo CD `Application` that points to Kustomize overlay path.

Key resources:
- Argo CD Helm release: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L237)
- Repo credential secret: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L190)
- Image updater resources: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L277)
- Application object: [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L323)

### 4.3 Terraform Outputs -> Downstream Consumers (Partially Implemented)

Current state:
- Terraform outputs are produced and archived, but no automated consumer workflow reads `terraform-outputs.json`.
- Practical runtime propagation is done via in-cluster resources (Secret/ConfigMap) and GitHub environment secrets managed by module `github_secrets`.

## 5. Kubernetes Connection Graph

This repo’s Kubernetes wiring is mostly service-name based inside one namespace. The important handshake is not a Terraform output feeding a manifest, but a set of cluster-local names that every workload resolves at runtime.

### 5.1 Namespace and Service Boundary

Terraform creates the runtime namespace `fire-monitoring-dev` in [infrastructure/terraform/environments/dev/main.tf](infrastructure/terraform/environments/dev/main.tf#L115). The Kustomize dev overlay then pins all app resources into that namespace in [infrastructure/k8s/overlays/dev/kustomization.yaml](infrastructure/k8s/overlays/dev/kustomization.yaml).

Inside that namespace, the core ClusterIP services are:
- `api` on port 8000 in [infrastructure/k8s/base/api/service.yaml](infrastructure/k8s/base/api/service.yaml)
- `dashboard` on port 80 in [infrastructure/k8s/base/dashboard/service.yaml](infrastructure/k8s/base/dashboard/service.yaml)
- `db` on port 5432 in [infrastructure/k8s/base/db/service.yaml](infrastructure/k8s/base/db/service.yaml)
- `mqtt` on port 1883 in [infrastructure/k8s/base/mqtt/service.yaml](infrastructure/k8s/base/mqtt/service.yaml)
- `influx` on port 8086 in [infrastructure/k8s/base/influx/service.yaml](infrastructure/k8s/base/influx/service.yaml)

These names are the in-cluster DNS anchors. Any pod in the namespace can reach them as `service-name` or `service-name.namespace.svc.cluster.local`.

### 5.2 Ingress as the Public Entry Point

The ingress controller fronts the web UI and API from one external endpoint in [infrastructure/k8s/base/ingress/ingress.yaml](infrastructure/k8s/base/ingress/ingress.yaml):
- `/` -> `dashboard:80`
- `/api` -> `api:8000`
- `/grafana` -> `grafana:3000`

This means the browser-facing connection is path-based, not host-splitting. The dashboard UI can call API routes on the same origin with `/api/...`, and Grafana is embedded or linked at `/grafana/...`.

### 5.3 Workload-to-Workload Links

The explicit runtime links are encoded in each pod spec via `envFrom`, `imagePullSecrets`, and shared ingress paths:

- `api` consumes `fire-monitoring-config` and `fire-monitoring-secrets` in [infrastructure/k8s/base/api/deployment.yaml](infrastructure/k8s/base/api/deployment.yaml). Those values include DB, Influx, and MQTT coordinates from Terraform.
- `etl-processor` consumes the same config and secret objects in [infrastructure/k8s/base/etl/deployment.yaml](infrastructure/k8s/base/etl/deployment.yaml), so it gets the same database and telemetry endpoints as the API.
- `db` also consumes the shared config and secret objects in [infrastructure/k8s/base/db/statefulset.yaml](infrastructure/k8s/base/db/statefulset.yaml), which keeps the runtime contract consistent even though the database is itself one of the backends.
- `telegraf` loads the same config/secret pair in [infrastructure/k8s/base/telegraf/deployment.yaml](infrastructure/k8s/base/telegraf/deployment.yaml), which ties metrics shipping to the same environment settings.
- `flyway` uses the same config/secret pair plus SQL from config maps in [infrastructure/k8s/base/flyway/job.yaml](infrastructure/k8s/base/flyway/job.yaml), so migrations run with the same database endpoint and credentials as the app.

### 5.4 Runtime Traffic Pattern

The practical traffic flow is:
1. User opens the dashboard through the ingress route `/`.
2. Dashboard pages call `/api/...` on the same origin, so requests are routed by ingress to the `api` service.
3. API reads database and telemetry settings from the Terraform-created Secret/ConfigMap.
4. API talks to backend services by the Kubernetes service names `db`, `mqtt`, and `influx`.
5. Grafana is exposed on `/grafana` and can be embedded in the dashboard via the iframe URLs in [apps/dashboard/public/protected/dashboard.html](apps/dashboard/public/protected/dashboard.html).

### 5.5 What Is Connected and What Is Not

Connected in code:
- Terraform -> Kubernetes Secret/ConfigMap
- Kubernetes Service -> pod selector -> in-namespace DNS
- Ingress path -> service backend
- Dashboard browser fetch -> `/api/...` path
- Dashboard iframe -> `/grafana/...` path

Not explicitly connected in manifests:
- The dashboard deployment itself does not receive an API URL env var; it relies on same-origin path routing.
- Terraform outputs are not directly fed into Kubernetes manifests.

## 6. Dependency Graph at a Glance

1. GitHub Actions `terraform-infra` prepares backend + runtime tfvars.
2. Terraform creates DOKS cluster.
3. Kubernetes/Helm providers attach to that cluster.
4. Terraform creates namespaces and runtime secrets/config.
5. Terraform installs Argo CD and Argo CD Image Updater.
6. Terraform creates Argo CD Application watching Kustomize overlay path.
7. Argo CD continuously reconciles base+overlay manifests to app namespace.
8. App pods start using Terraform-provisioned Secret/ConfigMap and GHCR credentials.

## 7. Handshake Risks and Tightening Opportunities

1. There is no enforced orchestration edge from `terraform apply` completion to Argo sync workflows. Consider `workflow_run` or artifact/commit contract before sync.
2. `terraform-outputs.json` is not consumed; either wire a consumer workflow or remove artifact to avoid confusion.
3. The effective root app is created via Terraform `kubernetes_manifest`; if app-of-apps is desired, introduce explicit root `Application`/`AppProject` manifests under `infrastructure/k8s` and point Terraform only to that root.
4. Backend/secrets examples currently resemble live credentials in environment files. Move all sensitive values to secret stores and keep only placeholders in repo-tracked files.
