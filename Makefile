# ==============================================================================
#                      FIRE MONITORING SYSTEM - DEV TOOLS
# ==============================================================================
KIND_CLUSTER_NAME ?= fire-monitoring

.PHONY: help \
        dev-up dev-down dev-logs \
        k8s-up k8s-down k8s-restart k8s-logs \
        gitops-bootstrap gitops-ui gitops-tunnel \
        clean-images build-local kind-load

# Default target: show help menu
help:
	@echo "======================================================================"
	@echo "                      AVAILABLE DEV TARGETS"
	@echo "======================================================================"
	@echo "TRACK 1: RAPID CONTAINER DEVELOPMENT (Direct Podman/Docker Compose)"
	@echo "  make dev-up            - Spin up Docker Compose local sandbox (hot-reload)"
	@echo "  make dev-down          - Spin down Docker Compose local sandbox"
	@echo "  make dev-logs          - View/tail Docker Compose application logs"
	@echo ""
	@echo "TRACK 2: LOCAL KUBERNETES TESTING (Kind Cluster)"
	@echo "  make k8s-up            - Build local images, load to Kind, & deploy local overlay"
	@echo "  make k8s-down          - Delete the local Kubernetes namespace & cleanup"
	@echo "  make k8s-restart       - Rollout restart local pods to pick up new image builds"
	@echo "  make k8s-logs          - Follow logs of API & Dashboard inside local namespace"
	@echo ""
	@echo "TRACK 3: LOCAL GITOPS SIMULATION (ArgoCD & Cloudflare Tunnel)"
	@echo "  make gitops-bootstrap  - Install ArgoCD, Dev/Prod namespaces, copy secrets"
	@echo "  make gitops-ui         - Port-forward to ArgoCD dashboard on https://localhost:8443"
	@echo "  make gitops-tunnel     - Start the Cloudflare Tunnel connection to the public"
	@echo "======================================================================"

# ==============================================================================
# TRACK 1: RAPID CONTAINER DEVELOPMENT (Docker Compose)
# ==============================================================================

# Spin up Docker Compose local sandbox (code folders are mounted directly for hot-reloading)
dev-up:
	docker compose -f docker-compose.local.yml up --build -d

# Spin down Docker Compose local sandbox (cleans volumes)
dev-down:
	docker compose -f docker-compose.local.yml down -v

# Tail Docker Compose logs
dev-logs:
	docker compose -f docker-compose.local.yml logs -f api dashboard etl-processor

# ==============================================================================
# TRACK 2: LOCAL KUBERNETES TESTING (Kind)
# ==============================================================================

# One-stop command to build, load, and deploy local Kubernetes overlay
k8s-up: kind-load
	kubectl create namespace fire-monitoring-local --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -k infrastructure/k8s/overlays/local

# Clean up local Kubernetes environment
k8s-down:
	kubectl delete namespace fire-monitoring-local --ignore-not-found=true

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

# Load local docker/podman images into Kind
kind-load: build-local
	kind load docker-image localhost/api:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/dashboard:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/etl-processor:local --name $(KIND_CLUSTER_NAME)

# Clean local docker images
clean-images:
	docker rmi localhost/api:local localhost/dashboard:local localhost/etl-processor:local || true

# ==============================================================================
# TRACK 3: LOCAL GITOPS SIMULATION (ArgoCD & Tunnel)
# ==============================================================================

# Bootstrap local GitOps setup (ArgoCD, Namespaces, Secrets replication, App-of-Apps)
gitops-bootstrap:
	bash infrastructure/scripts/local-gitops-bootstrap.sh

# Open access port to ArgoCD web interface
gitops-ui:
	@echo "ArgoCD UI starting... open https://localhost:8443 in your browser."
	kubectl port-forward -n argocd svc/argocd-server 8443:443

# Run the Cloudflare Tunnel connection
gitops-tunnel:
	@echo "Starting Cloudflare Tunnel connection..."
	cloudflared tunnel run local-k8s
