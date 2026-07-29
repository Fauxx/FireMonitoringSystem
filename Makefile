# ==============================================================================
#                      FIRE MONITORING SYSTEM - DEV TOOLS
# ==============================================================================
KIND_CLUSTER_NAME   ?= fire-monitoring
LOCAL_BUILD_DIR     := build/local
AKS_TF_BASE        := infrastructure/terraform/environments

.PHONY: help \
        dev-up dev-down dev-logs \
        k8s-up k8s-down k8s-restart k8s-logs \
        gitops-bootstrap gitops-ui gitops-tunnel \
        clean-images build-local kind-load \
        gitops-dev-only \
        aks-dev-bootstrap aks-dev-infra aks-dev-platform aks-dev-argocd aks-dev-plan-all aks-dev-destroy \
        aks-prod-bootstrap aks-prod-infra aks-prod-platform aks-prod-argocd aks-prod-plan-all aks-prod-destroy

# Default target: show help menu
help:
	@echo "==========================================================================="
	@echo "                      FIRE MONITORING SYSTEM — DEV TOOLS"
	@echo "==========================================================================="
	@echo ""
	@echo "[RETIRED — Local Only] TRACK 1: Docker Compose Sandbox"
	@echo "  Config: $(LOCAL_BUILD_DIR)/docker-compose.local.yml"
	@echo "  make dev-up            - Spin up Docker Compose sandbox (hot-reload)"
	@echo "  make dev-down          - Tear down Docker Compose sandbox"
	@echo "  make dev-logs          - Tail API / Dashboard / ETL logs"
	@echo ""
	@echo "[RETIRED — Local Only] TRACK 2: Kind Kubernetes Cluster"
	@echo "  Config: $(LOCAL_BUILD_DIR)/kind-config.yaml"
	@echo "  make k8s-up            - Build images → load to Kind → deploy local overlay"
	@echo "  make k8s-down          - Delete local namespace & Kind cluster"
	@echo "  make k8s-restart       - Rollout restart pods after image rebuild"
	@echo "  make k8s-logs          - Follow logs inside local namespace"
	@echo ""
	@echo "[RETIRED — Local Only] TRACK 3: Local GitOps Simulation (ArgoCD + Cloudflare)"
	@echo "  Config: $(LOCAL_BUILD_DIR)/argocd-apps*.yaml"
	@echo "  make gitops-bootstrap  - Install ArgoCD, namespaces, replicate secrets"
	@echo "  make gitops-ui         - Port-forward ArgoCD UI → https://localhost:8443"
	@echo "  make gitops-tunnel     - Start Cloudflare Tunnel (port-forward + cloudflared)"
	@echo "  make gitops-pause-dev  - Pause auto-sync + scale down dev pods"
	@echo "  make gitops-resume-dev - Restore auto-sync + scale up dev pods"
	@echo "  make gitops-pause-prod - Pause auto-sync + scale down prod pods"
	@echo "  make gitops-resume-prod- Restore auto-sync + scale up prod pods"
	@echo "  make gitops-dev-only   - Tear down local compose/kind, pause prod, resume dev"
	@echo ""
	@echo "[ACTIVE] TRACK 4: Azure AKS Terraform Operations"
	@echo "  --- Dev Environment (aks-dev) ---"
	@echo "  make aks-dev-bootstrap  - Layer 00: Create Azure Blob state backend"
	@echo "  make aks-dev-infra      - Layer 01: Provision VNet + AKS cluster"
	@echo "  make aks-dev-platform   - Layer 02: Deploy ArgoCD + Ingress + DNS"
	@echo "  make aks-dev-argocd     - Layer 03: Register App-of-Apps in ArgoCD"
	@echo "  make aks-dev-plan-all   - Dry-run plan across all aks-dev layers"
	@echo "  make aks-dev-destroy    - ⚠️  Destroy all aks-dev infrastructure"
	@echo "  --- Prod Environment (aks-prod) ---"
	@echo "  make aks-prod-bootstrap - Layer 00: Create Azure Blob state backend"
	@echo "  make aks-prod-infra     - Layer 01: Provision VNet + AKS cluster"
	@echo "  make aks-prod-platform  - Layer 02: Deploy ArgoCD + Ingress + DNS"
	@echo "  make aks-prod-argocd    - Layer 03: Register App-of-Apps in ArgoCD"
	@echo "  make aks-prod-plan-all  - Dry-run plan across all aks-prod layers"
	@echo "  make aks-prod-destroy   - ⚠️  PRODUCTION: Destroy all aks-prod infrastructure"
	@echo "==========================================================================="

# ==============================================================================
# TRACK 1: RAPID CONTAINER DEVELOPMENT (Docker Compose)
# [RETIRED] — Config lives in build/local/docker-compose.local.yml
# ==============================================================================

# Spin up Docker Compose local sandbox (code folders are mounted directly for hot-reloading)
dev-up:
	docker compose -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml up --build -d

# Spin down Docker Compose local sandbox (cleans volumes)
dev-down:
	docker compose -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml down -v

# Tail Docker Compose logs
dev-logs:
	docker compose -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml logs -f api dashboard etl-processor

# ==============================================================================
# TRACK 2: LOCAL KUBERNETES TESTING (Kind)
# [RETIRED] — Config lives in build/local/kind-config.yaml
# ==============================================================================

# One-stop command to build, load, and deploy local Kubernetes overlay
k8s-up: kind-load
	kind create cluster --name $(KIND_CLUSTER_NAME) --config $(LOCAL_BUILD_DIR)/kind-config.yaml --wait 60s || true
	kubectl create namespace fire-monitoring-local --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -k infrastructure/k8s/overlays/local

# Clean up local Kubernetes environment
k8s-down:
	kubectl delete namespace fire-monitoring-local --ignore-not-found=true
	kind delete cluster --name $(KIND_CLUSTER_NAME) || true

# Re-roll pods to pick up updated local images after running 'make kind-load'
k8s-restart:
	kubectl rollout restart deployment -n fire-monitoring-local api dashboard etl-processor

# Tail logs of local Kubernetes applications
k8s-logs:
	kubectl logs -n fire-monitoring-local -f -l deployment-type=local --max-log-requests=10

# Build local docker/podman images
build-local:
	docker build -t localhost/api:local ./apps/api
	docker build -t localhost/dashboard:local ./apps/dashboard
	docker build -t localhost/etl-processor:local ./apps/etl-processor

# Load local docker/podman images into Kind cluster
kind-load: build-local
	kind load docker-image localhost/api:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/dashboard:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/etl-processor:local --name $(KIND_CLUSTER_NAME)

# Clean local docker images
clean-images:
	docker rmi localhost/api:local localhost/dashboard:local localhost/etl-processor:local || true

# ==============================================================================
# TRACK 3: LOCAL GITOPS SIMULATION (ArgoCD & Cloudflare Tunnel)
# [RETIRED] — Manifests live in build/local/argocd-apps*.yaml
# ==============================================================================

# Bootstrap local GitOps setup (ArgoCD, Namespaces, Secrets replication, App-of-Apps)
gitops-bootstrap:
	bash infrastructure/scripts/local-gitops-bootstrap.sh

# Open access port to ArgoCD web interface
gitops-ui:
	@echo "ArgoCD UI starting... open https://localhost:8443 in your browser."
	kubectl port-forward -n argocd svc/argocd-server 8443:443

# Run the Cloudflare Tunnel connection
# Starts a background port-forward (localhost:8080 → ingress-nginx) so cloudflared
# has a live backend to proxy to, then launches the tunnel. Cleans up on exit.
gitops-tunnel:
	@echo "Port-forwarding Nginx Ingress to localhost:8080..."
	kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 &
	$(eval PF_PID := $$!)
	@echo "Waiting for port-forward to be ready..."
	@sleep 2
	@echo "Starting Cloudflare Tunnel connection..."
	cloudflared tunnel run local-k8s || true
	@echo "Cleaning up port-forward (PID: $(PF_PID))..."
	@kill $(PF_PID) 2>/dev/null || true

# Pause development environment (turns off auto-sync and scales down pods to 0)
gitops-pause-dev:
	@echo "Pausing dev namespace..."
	kubectl patch app apps-dev -n argocd -p '{"spec":{"syncPolicy":null}}' --type=merge
	kubectl scale deployment,statefulset --all --replicas=0 -n fire-monitoring-dev

# Resume development environment (restores auto-sync and scales up pods)
gitops-resume-dev:
	@echo "Resuming dev namespace..."
	kubectl patch app apps-dev -n argocd -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge

# Pause production environment (turns off auto-sync and scales down pods to 0)
gitops-pause-prod:
	@echo "Pausing prod namespace..."
	kubectl patch app apps -n argocd -p '{"spec":{"syncPolicy":null}}' --type=merge
	kubectl scale deployment,statefulset --all --replicas=0 -n fire-monitoring-prod

# Resume production environment (restores auto-sync and scales up pods)
gitops-resume-prod:
	@echo "Resuming prod namespace..."
	kubectl patch app apps -n argocd -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge

# Transition to Dev/Staging environment exclusively (teardown local sandbox, pause prod namespace, resume dev)
gitops-dev-only: dev-down k8s-down gitops-pause-prod gitops-resume-dev
	@echo "Dev/Staging environment active. Local Kind, Compose, and Prod are turned off."

# ==============================================================================
# TRACK 4: AZURE AKS TERRAFORM OPERATIONS
# ==============================================================================
AKS_TF_BASE = infrastructure/terraform/environments

# --- AKS DEV ---
aks-dev-bootstrap:
	cd $(AKS_TF_BASE)/aks-dev/00-bootstrap && terraform init -backend-config=backend.conf && terraform apply

aks-dev-infra:
	cd $(AKS_TF_BASE)/aks-dev/01-infra && terraform init -backend-config=backend.conf && terraform apply

aks-dev-platform:
	cd $(AKS_TF_BASE)/aks-dev/02-platform && terraform init -backend-config=backend.conf && terraform apply

aks-dev-argocd:
	cd $(AKS_TF_BASE)/aks-dev/03-argocd && terraform init -backend-config=backend.conf && terraform apply

aks-dev-plan-all:
	@echo "=== Plan: aks-dev/00-bootstrap ==="
	cd $(AKS_TF_BASE)/aks-dev/00-bootstrap && terraform init -backend-config=backend.conf && terraform plan
	@echo "=== Plan: aks-dev/01-infra ==="
	cd $(AKS_TF_BASE)/aks-dev/01-infra && terraform init -backend-config=backend.conf && terraform plan
	@echo "=== Plan: aks-dev/02-platform ==="
	cd $(AKS_TF_BASE)/aks-dev/02-platform && terraform init -backend-config=backend.conf && terraform plan
	@echo "=== Plan: aks-dev/03-argocd ==="
	cd $(AKS_TF_BASE)/aks-dev/03-argocd && terraform init -backend-config=backend.conf && terraform plan

aks-dev-destroy:
	@read -p "Destroy aks-dev? Type YES to confirm: " confirm && \
	if [ "$$confirm" = "YES" ]; then \
		cd $(AKS_TF_BASE)/aks-dev/03-argocd && terraform init -backend-config=backend.conf && terraform destroy -auto-approve; \
		cd $(AKS_TF_BASE)/aks-dev/02-platform && terraform init -backend-config=backend.conf && terraform destroy -auto-approve; \
		cd $(AKS_TF_BASE)/aks-dev/01-infra && terraform init -backend-config=backend.conf && terraform destroy -auto-approve; \
		cd $(AKS_TF_BASE)/aks-dev/00-bootstrap && terraform init -backend-config=backend.conf && terraform destroy -auto-approve; \
	else \
		echo "Destruction cancelled."; \
	fi

# --- AKS PROD ---
aks-prod-bootstrap:
	cd $(AKS_TF_BASE)/aks-prod/00-bootstrap && terraform init -backend-config=backend.conf && terraform apply

aks-prod-infra:
	cd $(AKS_TF_BASE)/aks-prod/01-infra && terraform init -backend-config=backend.conf && terraform apply

aks-prod-platform:
	cd $(AKS_TF_BASE)/aks-prod/02-platform && terraform init -backend-config=backend.conf && terraform apply

aks-prod-argocd:
	cd $(AKS_TF_BASE)/aks-prod/03-argocd && terraform init -backend-config=backend.conf && terraform apply

aks-prod-plan-all:
	@echo "=== Plan: aks-prod/00-bootstrap ==="
	cd $(AKS_TF_BASE)/aks-prod/00-bootstrap && terraform init -backend-config=backend.conf && terraform plan
	@echo "=== Plan: aks-prod/01-infra ==="
	cd $(AKS_TF_BASE)/aks-prod/01-infra && terraform init -backend-config=backend.conf && terraform plan
	@echo "=== Plan: aks-prod/02-platform ==="
	cd $(AKS_TF_BASE)/aks-prod/02-platform && terraform init -backend-config=backend.conf && terraform plan
	@echo "=== Plan: aks-prod/03-argocd ==="
	cd $(AKS_TF_BASE)/aks-prod/03-argocd && terraform init -backend-config=backend.conf && terraform plan

aks-prod-destroy:
	@read -p "⚠️  PRODUCTION: Destroy aks-prod? Type YES to confirm: " confirm && \
	if [ "$$confirm" = "YES" ]; then \
		cd $(AKS_TF_BASE)/aks-prod/03-argocd && terraform init -backend-config=backend.conf && terraform destroy -auto-approve; \
		cd $(AKS_TF_BASE)/aks-prod/02-platform && terraform init -backend-config=backend.conf && terraform destroy -auto-approve; \
		cd $(AKS_TF_BASE)/aks-prod/01-infra && terraform init -backend-config=backend.conf && terraform destroy -auto-approve; \
		cd $(AKS_TF_BASE)/aks-prod/00-bootstrap && terraform init -backend-config=backend.conf && terraform destroy -auto-approve; \
	else \
		echo "Destruction cancelled."; \
	fi
