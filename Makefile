# ==============================================================================
#                      FIRE MONITORING SYSTEM - DEV TOOLS
# ==============================================================================
# 1. LOCAL DEVOPS CONTROLS   - make local-up, local-down, local-status, local-tunnel
# 2. DOCKER COMPOSE SANDBOX  - make dev-up, dev-down, dev-logs
# 3. KIND KUBERNETES & GITOPS - make k8s-up, k8s-down, gitops-ui, gitops-tunnel
# 4. AZURE TERRAFORM PIPELINE- make aks-dev-plan-all, aks-dev-infra, aks-prod-*
# 5. CI/CD & HYGIENE         - make ci-validate, clean
# ==============================================================================

KIND_CLUSTER_NAME   ?= fire-monitoring
LOCAL_BUILD_DIR     := build/local
AKS_TF_BASE        := infrastructure/terraform/environments

.PHONY: help \
        local-up local-start local-down local-stop local-status local-tunnel local-restart local-logs \
        dev-up dev-down dev-logs \
        k8s-up k8s-down k8s-restart k8s-logs \
        gitops-bootstrap gitops-ui gitops-tunnel gitops-pause-dev gitops-resume-dev gitops-pause-prod gitops-resume-prod gitops-dev-only \
        argocd-sync-dev argocd-status argocd-watch \
        clean-images build-local kind-load ci-validate clean \
        aks-dev-bootstrap aks-dev-infra aks-dev-platform aks-dev-argocd aks-dev-plan-all aks-dev-destroy \
        aks-prod-bootstrap aks-prod-infra aks-prod-platform aks-prod-argocd aks-prod-plan-all aks-prod-destroy

# Default target: show help menu
help:
	@echo "==========================================================================="
	@echo "                      FIRE MONITORING SYSTEM — DEV TOOLS"
	@echo "==========================================================================="
	@echo ""
	@echo "🚀 [SECTION 1] RECOMMENDED LOCAL / INTERNAL DEVOPS COMMANDS"
	@echo "  make local-up          - Spin up local K8s cluster, build/load images & launch apps"
	@echo "  make local-down        - Stop local cluster, kill background tunnels & clean up"
	@echo "  make local-status      - Check local K8s pods, nodes & tunnel status"
	@echo "  make local-tunnel      - Launch Cloudflare Tunnel + Nginx Ingress port-forward"
	@echo "  make local-restart     - Rebuild images & restart local K8s app deployments"
	@echo "  make local-logs        - Tail live logs of local K8s application pods"
	@echo ""
	@echo "🐳 [SECTION 2] DOCKER COMPOSE SANDBOX (RAPID CONTAINER DEV)"
	@echo "  Config: $(LOCAL_BUILD_DIR)/docker-compose.local.yml"
	@echo "  make dev-up            - Spin up Docker Compose sandbox (hot-reload)"
	@echo "  make dev-down          - Tear down Docker Compose sandbox"
	@echo "  make dev-logs          - Tail API / Dashboard / ETL logs"
	@echo ""
	@echo "☸️  [SECTION 3] KIND KUBERNETES & GITOPS SIMULATION"
	@echo "  Config: $(LOCAL_BUILD_DIR)/kind-config.yaml & $(LOCAL_BUILD_DIR)/argocd-apps*.yaml"
	@echo "  make k8s-up            - Build images → load to Kind → deploy local overlay"
	@echo "  make k8s-down          - Delete local namespace & Kind cluster"
	@echo "  make k8s-restart       - Rollout restart pods after image rebuild"
	@echo "  make k8s-logs          - Follow logs inside local namespace"
	@echo "  make gitops-bootstrap  - Install ArgoCD, namespaces, replicate secrets"
	@echo "  make gitops-dev-up     - Deploy ONLY the DEV environment via ArgoCD"
	@echo "  make gitops-dev-down   - Tear down ONLY the DEV environment via ArgoCD"
	@echo "  make gitops-prod-up    - Deploy ONLY the PROD environment via ArgoCD"
	@echo "  make gitops-prod-down  - Tear down ONLY the PROD environment via ArgoCD"
	@echo "  make gitops-ui         - Port-forward ArgoCD UI → https://localhost:8443"
	@echo "  make gitops-tunnel     - Start Cloudflare Tunnel (port-forward + cloudflared)"
	@echo "  make gitops-pause-dev  - Pause auto-sync + scale down dev pods"
	@echo "  make gitops-resume-dev - Restore auto-sync + scale up dev pods"
	@echo ""
	@echo "🔄 [SECTION 3b] ARGOCD DEVELOPER OPERATIONS (POST-PUSH CONTROL)"
	@echo "  make argocd-sync-dev   - Force immediate ArgoCD sync (skip 3-min poll)"
	@echo "  make argocd-status     - Show ArgoCD app sync + health + pod status"
	@echo "  make argocd-watch      - Live-watch pod rollout after a GitOps push"
	@echo ""
	@echo "☁️  [SECTION 4] AZURE AKS TERRAFORM & CLOUD OPERATIONS (CI/CD RETAINED)"
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
	@echo ""
	@echo "🧹 [SECTION 5] CI/CD & CODE HYGIENE"
	@echo "  make ci-validate       - Validate K8s manifests & Terraform syntax locally"
	@echo "  make clean             - Clean temporary logs, dangling images & background processes"
	@echo "==========================================================================="

# ==============================================================================
# SECTION 1: RECOMMENDED LOCAL / INTERNAL DEVOPS COMMANDS
# ==============================================================================

# Spin up local Kind cluster, build images, load them, and deploy local/dev overlays
local-up: local-start
local-start:
	@echo "🚀 Starting local Kind cluster..."
	@podman start fire-monitoring-control-plane 2>/dev/null || kind create cluster --name $(KIND_CLUSTER_NAME) --config $(LOCAL_BUILD_DIR)/kind-config.yaml --wait 60s || true
	@kubectl config use-context kind-$(KIND_CLUSTER_NAME)
	@echo "📦 Building & loading local images into Kind..."
	@make kind-load
	@echo "🚀 Applying Kubernetes manifests..."
	@kubectl create namespace fire-monitoring-dev --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create namespace fire-monitoring-local --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -k infrastructure/k8s/overlays/dev || true
	@kubectl apply -k infrastructure/k8s/overlays/local || true
	@echo "✅ Local environment ready!"

# Bootstrap local GitOps setup with ArgoCD
local-gitops: gitops-bootstrap


# Completely stop local cluster container, background tunnels, and port-forwards
local-down: local-stop
local-stop:
	@echo "🛑 Killing cloudflared & port-forward processes..."
	@pkill -f "cloudflared tunnel run" 2>/dev/null || true
	@pkill -f "kubectl port-forward.*8080" 2>/dev/null || true
	@echo "🛑 Stopping Kind control-plane container..."
	@podman stop fire-monitoring-control-plane 2>/dev/null || true
	@echo "✅ Local environment stopped."

# Start Cloudflare Tunnel and port-forward Ingress
local-tunnel:
	@echo "🌐 Starting port-forward (127.0.0.1:8080 -> ingress-nginx)..."
	@pkill -f "kubectl port-forward.*8080" 2>/dev/null || true
	@kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 > /tmp/pf.log 2>&1 &
	@sleep 2
	@echo "⚡ Starting Cloudflare Tunnel (local-k8s)..."
	cloudflared tunnel run local-k8s

# Check status of local cluster context, nodes, pods, and tunnel daemon
local-status:
	@echo "=== KUBECTL CONTEXT ==="
	@kubectl config current-context 2>/dev/null || echo "No active context."
	@echo ""
	@echo "=== KUBERNETES NODES ==="
	@kubectl get nodes 2>/dev/null || echo "Cluster is stopped."
	@echo ""
	@echo "=== POD STATUS (fire-monitoring-dev & local) ==="
	@kubectl get pods -n fire-monitoring-dev 2>/dev/null || true
	@kubectl get pods -n fire-monitoring-local 2>/dev/null || true
	@echo ""
	@echo "=== CLOUDFLARED TUNNEL PROCESS ==="
	@pgrep -a cloudflared || echo "No cloudflared tunnel process currently running."

# Re-build local images, load them into Kind, and rollout restart deployments
local-restart: build-local kind-load
	@echo "🔄 Rollout restarting local deployments..."
	kubectl rollout restart deployment -n fire-monitoring-dev api dashboard etl-processor || true
	kubectl rollout restart deployment -n fire-monitoring-local api dashboard etl-processor || true
	@echo "✅ Local deployments restarted."

# Follow live logs of local application pods
local-logs:
	kubectl logs -n fire-monitoring-dev -f -l deployment-type=development --max-log-requests=10 2>/dev/null || \
	kubectl logs -n fire-monitoring-local -f -l deployment-type=local --max-log-requests=10

# ==============================================================================
# SECTION 2: DOCKER COMPOSE SANDBOX (RAPID CONTAINER DEV)
# ==============================================================================

dev-up:
	docker compose --project-directory . --env-file $(LOCAL_BUILD_DIR)/.env -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml up --build -d

dev-down:
	docker compose --project-directory . --env-file $(LOCAL_BUILD_DIR)/.env -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml down -v

dev-logs:
	docker compose --project-directory . --env-file $(LOCAL_BUILD_DIR)/.env -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml logs -f api dashboard etl-processor

# ==============================================================================
# SECTION 3: KIND KUBERNETES & GITOPS SIMULATION
# ==============================================================================

k8s-up: kind-load
	kind create cluster --name $(KIND_CLUSTER_NAME) --config $(LOCAL_BUILD_DIR)/kind-config.yaml --wait 60s || true
	kubectl create namespace fire-monitoring-local --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -k infrastructure/k8s/overlays/local

k8s-down:
	kubectl delete namespace fire-monitoring-local --ignore-not-found=true
	kind delete cluster --name $(KIND_CLUSTER_NAME) || true

k8s-restart:
	kubectl rollout restart deployment -n fire-monitoring-local api dashboard etl-processor

k8s-logs:
	kubectl logs -n fire-monitoring-local -f -l deployment-type=local --max-log-requests=10

build-local:
	docker build -t localhost/api:local ./apps/api
	docker build -t localhost/dashboard:local ./apps/dashboard
	docker build -t localhost/etl-processor:local ./apps/etl-processor

kind-load: build-local
	kind load docker-image localhost/api:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/dashboard:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/etl-processor:local --name $(KIND_CLUSTER_NAME)

clean-images:
	docker rmi localhost/api:local localhost/dashboard:local localhost/etl-processor:local || true

gitops-bootstrap:
	bash infrastructure/scripts/local-gitops-bootstrap.sh

gitops-dev-up:
	@echo "🚀 Deploying DEV environment to Kind cluster via ArgoCD..."
	kubectl apply -f build/local/argocd-apps-dev.yaml
	@echo "✅ apps-dev applied. It will sync automatically."

gitops-dev-down:
	@echo "🛑 Tearing down DEV environment..."
	kubectl delete -f build/local/argocd-apps-dev.yaml
	@echo "✅ apps-dev deleted. ArgoCD is cleaning up fire-monitoring-dev resources."

gitops-prod-up:
	@echo "🚀 Deploying PROD environment to Kind cluster via ArgoCD..."
	kubectl apply -f build/local/argocd-apps.yaml
	@echo "✅ apps applied. It will sync automatically."

gitops-prod-down:
	@echo "🛑 Tearing down PROD environment..."
	kubectl delete -f build/local/argocd-apps.yaml
	@echo "✅ apps deleted. ArgoCD is cleaning up fire-monitoring-prod resources."

gitops-ui:
	@echo "ArgoCD UI starting... open https://localhost:8443 in your browser."
	kubectl port-forward -n argocd svc/argocd-server 8443:443

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

aks-dev-cloudflared-secret:
	@echo "🔐 Pushing Cloudflare Tunnel credentials to AKS (fire-monitoring-dev)..."
	kubectl create namespace fire-monitoring-dev --dry-run=client -o yaml | kubectl apply -f -
	kubectl create secret generic cloudflare-tunnel-credentials \
		--from-file=credentials.json=$(HOME)/.cloudflared/8a14c96d-85ef-4623-bad8-c95b57aefe14.json \
		--namespace=fire-monitoring-dev \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✅ Secret applied to fire-monitoring-dev."

gitops-pause-dev:
	@echo "Pausing dev namespace..."
	kubectl patch app apps-dev -n argocd -p '{"spec":{"syncPolicy":null}}' --type=merge
	kubectl scale deployment,statefulset --all --replicas=0 -n fire-monitoring-dev

gitops-resume-dev:
	@echo "Resuming dev namespace..."
	kubectl patch app apps-dev -n argocd -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge

gitops-pause-prod:
	@echo "Pausing prod namespace..."
	kubectl patch app apps -n argocd -p '{"spec":{"syncPolicy":null}}' --type=merge
	kubectl scale deployment,statefulset --all --replicas=0 -n fire-monitoring-prod

gitops-resume-prod:
	@echo "Resuming prod namespace..."
	kubectl patch app apps -n argocd -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge

gitops-dev-only: dev-down k8s-down gitops-pause-prod gitops-resume-dev
	@echo "Dev/Staging environment active. Local Kind, Compose, and Prod are turned off."

# ─────────────────────────────────────────────────────────────
# ArgoCD Developer Operations (Local GitOps Control)
# ─────────────────────────────────────────────────────────────

## Force ArgoCD to immediately pull from GitHub and apply (skip the 3-min poll interval)
## Use this right after pushing a commit or bumping image tags to see changes instantly.
argocd-sync-dev:
	@echo "⚡ Forcing ArgoCD to sync apps-dev immediately..."
	@kubectl patch app apps-dev -n argocd --type merge \
	  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD","prune":true}}}' \
	  2>/dev/null || echo "⚠️  Patch failed — ArgoCD may still be starting. Try: make gitops-ui"
	@echo "✅ Sync triggered. Watch progress: make argocd-watch"

## Show current ArgoCD app sync + health status (quick dashboard in terminal)
argocd-status:
	@echo "=== ARGOCD APPLICATION STATUS ==="
	@kubectl get apps -n argocd -o wide 2>/dev/null || echo "ArgoCD not running."
	@echo ""
	@echo "=== DEV NAMESPACE PODS ==="
	@kubectl get pods -n fire-monitoring-dev 2>/dev/null || echo "fire-monitoring-dev namespace not found."

## Live-watch pod rollout in fire-monitoring-dev (use after a GitOps push / image bump)
argocd-watch:
	@echo "👀 Watching pod rollout in fire-monitoring-dev (Ctrl+C to stop)..."
	kubectl get pods -n fire-monitoring-dev -w

# ==============================================================================
# SECTION 4: AZURE AKS TERRAFORM OPERATIONS (CI/CD RETAINED)
# ==============================================================================

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

# ==============================================================================
# SECTION 5: CI/CD & CODE HYGIENE
# ==============================================================================

# Validate K8s manifests & dry-run Kustomize builds locally
ci-validate:
	@echo "🔍 Validating Kubernetes Kustomize overlays..."
	kubectl kustomize infrastructure/k8s/overlays/dev > /dev/null
	kubectl kustomize infrastructure/k8s/overlays/prod > /dev/null
	kubectl kustomize infrastructure/k8s/overlays/local > /dev/null
	@echo "✅ All Kubernetes Kustomize manifests are valid!"

# Clean temporary log files, dangling background processes & unused docker images
clean:
	@echo "🧹 Cleaning background processes & logs..."
	-@killall cloudflared 2>/dev/null || true
	-@killall kubectl 2>/dev/null || true
	@rm -f /tmp/pf.log
	@echo "🧹 Cleaning dangling containers & images..."
	-@make clean-images 2>/dev/null || true
	@echo "✅ Cleanup complete!"
