# ==============================================================================
#                      FIRE MONITORING SYSTEM - DEV TOOLS
# ==============================================================================
#   SDLC STAGES:
#   1. RAPID DEV        - make rapid-up        Docker Compose hot-reload
#   2. LOCAL MANIFESTS   - make local-up        Kind + port-forward (localhost)
#   3. STAGING (DEV)     - make staging-up      ArgoCD GitOps → dev.fires.systems
#   4. PRODUCTION        - make prod-up         ArgoCD GitOps → fires.systems
#   5. CLOUD (AZURE)     - make aks-dev-*       Terraform AKS pipelines
#   6. UTILITIES         - make status, clean   Hygiene & validation
# ==============================================================================

KIND_CLUSTER_NAME   ?= fire-monitoring
LOCAL_BUILD_DIR     := build/local
AKS_TF_BASE        := infrastructure/terraform/environments

.PHONY: help \
        rapid-up rapid-down rapid-logs \
        local-up local-down local-restart local-logs local-port-forward \
        staging-up staging-down staging-sync staging-watch staging-pause staging-resume \
        prod-up prod-down prod-pause prod-resume \
        gitops-bootstrap gitops-ui status \
        build-local kind-load clean-images ci-validate clean \
        aks-dev-bootstrap aks-dev-infra aks-dev-platform aks-dev-argocd aks-dev-plan-all aks-dev-destroy \
        aks-prod-bootstrap aks-prod-infra aks-prod-platform aks-prod-argocd aks-prod-plan-all aks-prod-destroy

# ==============================================================================
# HELP
# ==============================================================================

help:
	@echo "==========================================================================="
	@echo "              FIRE MONITORING SYSTEM — SDLC DEV TOOLS"
	@echo "==========================================================================="
	@echo ""
	@echo "🐳 [1] RAPID DEV (Docker Compose — hot-reload, no K8s)"
	@echo "  make rapid-up          - Start Compose sandbox"
	@echo "  make rapid-down        - Tear down Compose sandbox"
	@echo "  make rapid-logs        - Tail application logs"
	@echo ""
	@echo "☸️  [2] LOCAL MANIFEST TESTING (Kind — port-forward only, no tunnel)"
	@echo "  make local-up          - Create Kind cluster, build images, deploy local overlay"
	@echo "  make local-down        - Stop Kind cluster & clean up port-forwards"
	@echo "  make local-restart     - Rebuild images & rollout restart pods"
	@echo "  make local-logs        - Tail local namespace logs"
	@echo "  make local-port-forward - Port-forward ingress → localhost:8080"
	@echo ""
	@echo "🚀 [3] STAGING / DEV (ArgoCD GitOps → dev.fires.systems)"
	@echo "  make staging-up        - Bootstrap ArgoCD + deploy dev overlay (tunnel included)"
	@echo "  make staging-down      - Tear down dev environment via ArgoCD"
	@echo "  make staging-sync      - Force ArgoCD sync (skip 3-min poll)"
	@echo "  make staging-watch     - Live-watch pod rollout"
	@echo "  make staging-pause     - Pause auto-sync & scale down dev pods"
	@echo "  make staging-resume    - Restore auto-sync"
	@echo ""
	@echo "🔒 [4] PRODUCTION (ArgoCD GitOps → fires.systems)"
	@echo "  make prod-up           - Deploy prod overlay via ArgoCD"
	@echo "  make prod-down         - Tear down prod environment via ArgoCD"
	@echo "  make prod-pause        - Pause auto-sync & scale down prod pods"
	@echo "  make prod-resume       - Restore auto-sync"
	@echo ""
	@echo "🔧 [SHARED] Cluster & GitOps Utilities"
	@echo "  make gitops-bootstrap  - Install ArgoCD, namespaces, secrets, GHCR creds"
	@echo "  make gitops-ui         - Port-forward ArgoCD UI → https://localhost:8443"
	@echo "  make status            - Show cluster context, nodes, pods across all namespaces"
	@echo ""
	@echo "☁️  [5] AZURE AKS TERRAFORM (CI/CD)"
	@echo "  make aks-dev-plan-all  - Dry-run plan across all aks-dev layers"
	@echo "  make aks-dev-destroy   - Destroy all aks-dev infrastructure"
	@echo "  make aks-prod-plan-all - Dry-run plan across all aks-prod layers"
	@echo "  make aks-prod-destroy  - Destroy all aks-prod infrastructure"
	@echo ""
	@echo "🧹 [6] UTILITIES"
	@echo "  make ci-validate       - Validate all Kustomize overlays"
	@echo "  make clean             - Kill background processes, remove dangling images"
	@echo "==========================================================================="

# ==============================================================================
# [1] RAPID DEV — Docker Compose
# ==============================================================================

rapid-up:
	@echo "🐳 Starting Docker Compose sandbox..."
	docker compose --project-directory . --env-file $(LOCAL_BUILD_DIR)/.env -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml up --build -d
	@echo "✅ Rapid dev ready! API: localhost:8000 | Dashboard: localhost:3000"

rapid-down:
	docker compose --project-directory . --env-file $(LOCAL_BUILD_DIR)/.env -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml down -v

rapid-logs:
	docker compose --project-directory . --env-file $(LOCAL_BUILD_DIR)/.env -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml logs -f api dashboard etl-processor

# ==============================================================================
# [2] LOCAL MANIFEST TESTING — Kind + port-forward (NO cloudflared)
# ==============================================================================

local-up:
	@echo "☸️  Starting Kind cluster for manifest testing..."
	@podman start fire-monitoring-control-plane 2>/dev/null || kind create cluster --name $(KIND_CLUSTER_NAME) --config $(LOCAL_BUILD_DIR)/kind-config.yaml --wait 60s || true
	@kubectl config use-context kind-$(KIND_CLUSTER_NAME)
	@echo "🔌 Installing NGINX Ingress Controller..."
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@echo "🩹 Patching ingress-nginx to remove hostPorts (for rootless Podman support)..."
	@kubectl patch deployment -n ingress-nginx ingress-nginx-controller --type json -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/ports/0/hostPort"}, {"op": "remove", "path": "/spec/template/spec/containers/0/ports/1/hostPort"}]' 2>/dev/null || true
	@echo "📦 Building & loading local images into Kind..."
	@$(MAKE) kind-load
	@echo "🚀 Applying local overlay..."
	@kubectl create namespace fire-monitoring-local --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -k infrastructure/k8s/overlays/local || true
	@echo "✅ Local manifest testing ready! Run: make local-port-forward"

local-down:
	@echo "🛑 Stopping local environment..."
	@pkill -f "kubectl port-forward.*808[0]" 2>/dev/null || true
	@podman stop fire-monitoring-control-plane 2>/dev/null || true
	@echo "✅ Local environment stopped."

local-restart: build-local kind-load
	@echo "🔄 Rollout restarting local deployments..."
	kubectl rollout restart deployment -n fire-monitoring-local api dashboard etl-processor || true
	@echo "✅ Local deployments restarted."

local-logs:
	kubectl logs -n fire-monitoring-local -f -l deployment-type=local --max-log-requests=10

local-port-forward:
	@echo "🌐 Port-forwarding ingress → localhost:8080 (Ctrl+C to stop)..."
	@pkill -f "kubectl port-forward.*8080" 2>/dev/null || true
	kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80

# ==============================================================================
# [3] STAGING / DEV — ArgoCD GitOps (in-cluster cloudflared → dev.fires.systems)
# ==============================================================================

staging-up:
	@echo "🚀 Deploying STAGING (dev) environment via ArgoCD..."
	@echo "   Cloudflared runs in-cluster — dev.fires.systems will go live automatically."
	kubectl apply -f build/local/argocd-apps-dev.yaml
	@echo "✅ apps-dev applied. ArgoCD will sync automatically."
	@echo "   Watch progress: make staging-watch"

staging-down:
	@echo "🛑 Tearing down STAGING (dev) environment..."
	kubectl delete -f build/local/argocd-apps-dev.yaml
	@echo "✅ apps-dev deleted. ArgoCD is cleaning up fire-monitoring-dev resources."

staging-sync:
	@echo "⚡ Forcing ArgoCD to sync apps-dev immediately..."
	@kubectl patch app apps-dev -n argocd --type merge \
	  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD","prune":true}}}' \
	  2>/dev/null || echo "⚠️  Patch failed — ArgoCD may still be starting. Try: make gitops-ui"
	@echo "✅ Sync triggered. Watch progress: make staging-watch"

staging-watch:
	@echo "👀 Watching pod rollout in fire-monitoring-dev (Ctrl+C to stop)..."
	kubectl get pods -n fire-monitoring-dev -w

staging-pause:
	@echo "⏸️  Pausing staging (dev) namespace..."
	kubectl patch app apps-dev -n argocd -p '{"spec":{"syncPolicy":null}}' --type=merge
	kubectl scale deployment,statefulset --all --replicas=0 -n fire-monitoring-dev

staging-resume:
	@echo "▶️  Resuming staging (dev) namespace..."
	kubectl patch app apps-dev -n argocd -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge

# ==============================================================================
# [4] PRODUCTION — ArgoCD GitOps (in-cluster cloudflared → fires.systems)
# ==============================================================================

prod-up:
	@echo "🔒 Deploying PRODUCTION environment via ArgoCD..."
	@echo "   Cloudflared runs in-cluster — fires.systems will go live automatically."
	kubectl apply -f build/local/argocd-apps.yaml
	@echo "✅ apps applied. ArgoCD will sync automatically."

prod-down:
	@echo "🛑 Tearing down PRODUCTION environment..."
	kubectl delete -f build/local/argocd-apps.yaml
	@echo "✅ apps deleted. ArgoCD is cleaning up fire-monitoring-prod resources."

prod-pause:
	@echo "⏸️  Pausing production namespace..."
	kubectl patch app apps -n argocd -p '{"spec":{"syncPolicy":null}}' --type=merge
	kubectl scale deployment,statefulset --all --replicas=0 -n fire-monitoring-prod

prod-resume:
	@echo "▶️  Resuming production namespace..."
	kubectl patch app apps -n argocd -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge

# ==============================================================================
# SHARED — Cluster & GitOps Utilities
# ==============================================================================

gitops-bootstrap:
	bash infrastructure/scripts/local-gitops-bootstrap.sh

gitops-ui:
	@echo "ArgoCD UI starting... open https://localhost:8443 in your browser."
	kubectl port-forward -n argocd svc/argocd-server 8443:443

status:
	@echo "=== KUBECTL CONTEXT ==="
	@kubectl config current-context 2>/dev/null || echo "No active context."
	@echo ""
	@echo "=== KUBERNETES NODES ==="
	@kubectl get nodes 2>/dev/null || echo "Cluster is stopped."
	@echo ""
	@echo "=== LOCAL NAMESPACE ==="
	@kubectl get pods -n fire-monitoring-local 2>/dev/null || true
	@echo ""
	@echo "=== DEV (STAGING) NAMESPACE ==="
	@kubectl get pods -n fire-monitoring-dev 2>/dev/null || true
	@echo ""
	@echo "=== PROD NAMESPACE ==="
	@kubectl get pods -n fire-monitoring-prod 2>/dev/null || true
	@echo ""
	@echo "=== ARGOCD APPS ==="
	@kubectl get apps -n argocd -o wide 2>/dev/null || echo "ArgoCD not running."

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

# ==============================================================================
# [5] AZURE AKS TERRAFORM (CI/CD)
# ==============================================================================

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
# [6] UTILITIES
# ==============================================================================

ci-validate:
	@echo "🔍 Validating Kubernetes Kustomize overlays..."
	kubectl kustomize infrastructure/k8s/overlays/dev > /dev/null
	kubectl kustomize infrastructure/k8s/overlays/prod > /dev/null
	kubectl kustomize infrastructure/k8s/overlays/local > /dev/null
	@echo "✅ All Kubernetes Kustomize manifests are valid!"

clean:
	@echo "🧹 Cleaning background processes & logs..."
	-@pkill -f "kubectl port-forward" 2>/dev/null || true
	@rm -f /tmp/pf.log
	@echo "🧹 Cleaning dangling containers & images..."
	-@make clean-images 2>/dev/null || true
	@echo "✅ Cleanup complete!"
