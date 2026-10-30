# ==============================================================================
#                      FIRE MONITORING SYSTEM - DEV TOOLS
#   SDLC STAGES:
#   1. DEV (LOCAL)       - make dev-up          Docker Compose sandbox
#   2. KIND (LOCAL K8S)  - make kind-up-debug   Kind cluster (DEPRECATED: CI automated)
#   3. STAGING (GKE DEV) - make staging-up      ArgoCD GitOps → dev.fires.systems
#   4. PRODUCTION        - make prod-up         Guarded placeholder (GitOps only)
#   5. CLOUD INFRA       - make gke-dev-*       Terraform GKE pipelines
#   6. OBSERVABILITY     - make query-backend   Prometheus backend telemetry
#   7. UTILITIES         - make status, clean   Hygiene & validation
# ==============================================================================

.DEFAULT_GOAL := dev-up
KIND_CLUSTER_NAME   ?= fire-monitoring
LOCAL_BUILD_DIR     := build/local
AKS_TF_BASE         := infrastructure/terraform/environments
COMPOSE_FILE        ?= docker-compose.yml
ENV_FILE            ?= .env

.PHONY: help \
        dev dev-up dev-down dev-stop dev-restart dev-logs dev-ps dev-build \
        up down stop restart logs ps build \
        rapid-up rapid-down rapid-logs \
        dev-query-backend query-backend health \
        kind kind-up kind-up-debug kind-down kind-stop kind-restart kind-logs kind-port-forward kind-query-backend \
        local-up local-down local-stop local-restart local-logs local-port-forward \
        staging-up staging-down staging-sync staging-watch staging-pause staging-resume \
        staging-port-forward staging-port-forward-stop staging-logs-api staging-logs-etl staging-logs-sim \
        staging-argocd-pass staging-query-backend \
        dev-port-forward dev-port-forward-stop dev-logs-api dev-logs-etl dev-logs-sim dev-argocd-pass \
        prod-up prod-down prod-pause prod-resume \
        gitops-bootstrap gitops-ui status \
        build-local kind-load clean-images ci-validate clean \
        gke-dev-bootstrap-plan gke-dev-bootstrap-apply gke-dev-infra-plan gke-dev-infra-apply \
        gke-dev-platform-plan gke-dev-platform-apply gke-dev-argocd-plan gke-dev-argocd-apply \
        gke-dev-all-apply gke-dev-get-creds gke-dev-destroy-argocd gke-dev-destroy-platform gke-dev-destroy-infra \
        gke-prod-bootstrap-plan gke-prod-bootstrap-apply gke-prod-infra-plan gke-prod-infra-apply \
        gke-prod-platform-plan gke-prod-platform-apply gke-prod-argocd-plan gke-prod-argocd-apply \
        gke-prod-all-apply gke-prod-get-creds gke-prod-destroy-argocd gke-prod-destroy-platform gke-prod-destroy-infra \
        aks-dev-bootstrap aks-dev-infra aks-dev-platform aks-dev-argocd aks-dev-plan-all aks-dev-destroy \
        aks-prod-bootstrap aks-prod-infra aks-prod-platform aks-prod-argocd aks-prod-plan-all aks-prod-destroy

# ------------------------------------------------------------------------------
# 📖 HELP
# ------------------------------------------------------------------------------
help:
	@echo "==========================================================================="
	@echo "              FIRE MONITORING SYSTEM — SDLC DEV TOOLS"
	@echo "==========================================================================="
	@echo ""
	@echo "🐳 [1] DEV (Docker Compose — fast local sandbox, no K8s)"
	@echo "  make dev-up            - Start local development environment (alias: make dev, make up)"
	@echo "  make dev-down          - Stop and remove containers & volumes (alias: make down)"
	@echo "  make dev-stop          - Pause running containers (preserves volume data)"
	@echo "  make dev-restart       - Restart all development services"
	@echo "  make dev-logs          - Tail Compose application logs (alias: make logs)"
	@echo "  make dev-ps            - List running development containers (alias: make ps)"
	@echo "  make dev-build         - Rebuild development images without cache"
	@echo "  make dev-query-backend - Query local backend health & metrics (alias: make health)"
	@echo ""
	@echo "☸️  [2] KIND (Local Kubernetes — DEPRECATED: Validation moved to CI)"
	@echo "  make kind-up-debug     - Start minimal Kind cluster for manual debugging"
	@echo "  make kind-down         - Stop & destroy Kind cluster"
	@echo "  make kind-up           - [DEPRECATED] Use 'make dev-up' or 'make kind-up-debug'"
	@echo "  make kind-restart      - [DEPRECATED] Rebuild & rollout restart in Kind"
	@echo "  make kind-load         - [DEPRECATED] Build & load local images into Kind"
	@echo "  make kind-port-forward - [DEPRECATED] Port-forward Kind ingress & services"
	@echo "  make kind-stop         - Pause Kind cluster container (preserves state)"
	@echo "  make kind-logs         - Tail local namespace pod logs"
	@echo "  make kind-query-backend- Query Prometheus in Kind for backend API metrics"
	@echo ""
	@echo "🚀 [3] STAGING (GKE Dev — ArgoCD GitOps → dev.fires.systems)"
	@echo "  make staging-up        - Apply apps-dev to ArgoCD (triggers automated GitOps)"
	@echo "  make staging-down      - Tear down staging environment via ArgoCD"
	@echo "  make staging-sync      - Force ArgoCD to sync immediately"
	@echo "  make staging-watch     - Live-watch staging pod rollouts"
	@echo "  make staging-pause     - Pause auto-sync & scale pods to 0 (cost saver)"
	@echo "  make staging-resume    - Restore auto-sync and replicas"
	@echo "  make staging-port-forward - Forward Staging Prometheus, ArgoCD, Influx to localhost"
	@echo "  make staging-logs-api  - Tail live API logs in GKE Dev"
	@echo "  make staging-argocd-pass - Get ArgoCD admin password"
	@echo "  make staging-query-backend - Query Prometheus in GKE Dev for backend API metrics"
	@echo ""
	@echo "🔒 [4] PRODUCTION (fires.systems — Guarded Placeholders)"
	@echo "  make prod-up           - [PROTECTED] GitOps placeholder (deploy via CI/CD)"
	@echo "  make prod-down         - [PROTECTED] Teardown placeholder (manual approval required)"
	@echo ""
	@echo "📊 [5] OBSERVABILITY SHORTCUTS"
	@echo "  make query-backend     - Query backend metrics from active cluster Prometheus"
	@echo ""
	@echo "🔧 [6] CLUSTER & GITOPS UTILITIES"
	@echo "  make status            - Show cluster context, nodes, and pods across namespaces"
	@echo "  make ci-validate       - Validate all Kustomize overlays locally"
	@echo "  make clean             - Prune stopped containers, dangling images, and processes"

# ------------------------------------------------------------------------------
# [1] DEV — Docker Compose (Fast Local Sandbox)
# ------------------------------------------------------------------------------
dev: dev-up
dev-up:
	@echo "🐳 Starting Rapid Dev Docker Compose environment..."
	docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up --build -d
	@echo ""
	@echo "======================================================"
	@echo "✅ Rapid Dev environment is live!"
	@echo "======================================================"
	@echo "🖥️  Dashboard UI  : http://localhost:8080"
	@echo "🔌 REST API       : http://localhost:8000"
	@echo "📈 InfluxDB UI    : http://localhost:8086"
	@echo "📊 Prometheus UI  : http://localhost:9090"
	@echo "📡 Mosquitto MQTT : localhost:1883"
	@echo "======================================================"
	@echo "Tip: Run 'make dev-logs' to follow logs, or 'make dev-down' to stop."

dev-down:
	@echo "🛑 Stopping Rapid Dev sandbox..."
	docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) down -v

dev-stop:
	@echo "⏸️  Stopping containers (preserving volumes)..."
	docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) stop

dev-restart:
	@echo "🔄 Restarting Rapid Dev services..."
	docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) restart

dev-logs:
	docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) logs -f api dashboard etl-processor simulator

dev-ps:
	docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) ps

dev-build:
	@echo "🔨 Rebuilding all service images..."
	docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) build

# Convenience & backwards compatibility aliases
up: dev-up
down: dev-down
stop: dev-stop
restart: dev-restart
logs: dev-logs
ps: dev-ps
build: dev-build
rapid-up: dev-up
rapid-down: dev-down
rapid-logs: dev-logs

dev-query-backend:
	@echo "📊 Querying local backend API /health and /metrics..."
	@curl -s http://localhost:8000/health || echo "API not reachable on :8000"
	@echo ""
	@curl -s http://localhost:8000/metrics | head -n 25 || true

health: dev-query-backend

# ------------------------------------------------------------------------------
# [2] KIND — Local Kubernetes Manifests (DEPRECATED: Validation moved to CI)
# ------------------------------------------------------------------------------
kind-up-debug:
	@echo "⚠️  Starting Kind for LOCAL DEBUGGING ONLY (use 'make dev-up' for daily work)..."
	@echo "    Kind validation now runs automatically in CI on every PR."
	kind create cluster --name $(KIND_CLUSTER_NAME) --config $(LOCAL_BUILD_DIR)/kind-config.yaml --wait 60s
	kubectl config use-context kind-$(KIND_CLUSTER_NAME)
	@echo "✅ Kind cluster ready for manual debugging."

kind: kind-up
kind-up:
	@echo "⚠️  Kind validation has moved to CI. Use 'make dev-up' for local development. To run Kind locally for debugging, use 'make kind-up-debug'."
	@echo "☸️  Starting Kind cluster for manifest testing..."
	@podman start fire-monitoring-control-plane 2>/dev/null || kind create cluster --name $(KIND_CLUSTER_NAME) --config $(LOCAL_BUILD_DIR)/kind-config.yaml --wait 60s || true
	@kubectl config use-context kind-$(KIND_CLUSTER_NAME)
	@echo "🔌 Installing NGINX Ingress Controller..."
	@kubectl --context kind-$(KIND_CLUSTER_NAME) apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml --validate=false
	@echo "🩹 Patching ingress-nginx to remove hostPorts (for rootless Podman support)..."
	@kubectl --context kind-$(KIND_CLUSTER_NAME) patch deployment -n ingress-nginx ingress-nginx-controller --type json -p='[{"op": "remove", "path": "/spec/template/spec/containers/0/ports/0/hostPort"}, {"op": "remove", "path": "/spec/template/spec/containers/0/ports/1/hostPort"}]' 2>/dev/null || true
	@echo "📦 Building & loading local images into Kind..."
	@$(MAKE) kind-load
	@echo "🚀 Applying local overlay..."
	@kubectl --context kind-$(KIND_CLUSTER_NAME) create namespace fire-monitoring-local --dry-run=client -o yaml | kubectl --context kind-$(KIND_CLUSTER_NAME) apply -f -
	@kubectl --context kind-$(KIND_CLUSTER_NAME) apply -k infrastructure/k8s/overlays/local
	@echo "✅ Kind manifest testing ready! Run: make kind-port-forward"

kind-stop:
	@echo "⏸️  Parking Kind environment (data preserved)..."
	@pkill -f "kubectl port-forward" 2>/dev/null || true
	@podman stop fire-monitoring-control-plane 2>/dev/null || true
	@echo "✅ Cluster paused. Run 'make kind-up' to resume where you left off."

kind-down:
	@echo "🛑 Destroying Kind environment (all data lost)..."
	@pkill -f "kubectl port-forward" 2>/dev/null || true
	kind delete cluster --name $(KIND_CLUSTER_NAME) || true
	@echo "✅ Kind environment fully destroyed."

kind-restart: build-local kind-load
	@echo "⚠️  Kind validation has moved to CI. Use 'make dev-restart' for local development. To run Kind locally for debugging, use 'make kind-up-debug'."
	@echo "🔄 Rollout restarting local deployments in Kind..."
	kubectl --context kind-$(KIND_CLUSTER_NAME) rollout restart deployment -n fire-monitoring-local api dashboard etl-processor mcu-simulator-fleet || true
	kubectl --context kind-$(KIND_CLUSTER_NAME) delete job flyway-migrate -n fire-monitoring-local --ignore-not-found
	kubectl --context kind-$(KIND_CLUSTER_NAME) apply -k infrastructure/k8s/overlays/local
	@echo "✅ Kind deployments restarted."

kind-logs:
	kubectl --context kind-$(KIND_CLUSTER_NAME) logs -n fire-monitoring-local -f -l deployment-type=local --max-log-requests=50

kind-port-forward:
	@echo "⚠️  Kind validation has moved to CI. Use 'make dev-up' for local development. To run Kind locally for debugging, use 'make kind-up-debug'."
	@echo "🌐 Starting background port-forwards for Kind..."
	@killall kubectl 2>/dev/null || true
	@echo "🔍 Checking for port conflicts..."
	@for port in 8080 5432 8086 9090 1883 9001; do \
		if ss -tuln | grep -qE ":$$port\b"; then \
			echo "❌ Error: Port $$port is in use by another project! Please stop it and try again."; \
			exit 1; \
		fi \
	done
	@nohup kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 > /dev/null 2>&1 &
	@nohup kubectl port-forward -n fire-monitoring-local svc/db 5432:5432 > /dev/null 2>&1 &
	@nohup kubectl port-forward -n fire-monitoring-local svc/influx 8086:8086 > /dev/null 2>&1 &
	@nohup kubectl port-forward -n fire-monitoring-local svc/prometheus 9090:9090 > /dev/null 2>&1 &
	@nohup kubectl port-forward -n fire-monitoring-local svc/mqtt 1883:1883 > /dev/null 2>&1 &
	@nohup kubectl port-forward -n fire-monitoring-local svc/mqtt 9001:9001 > /dev/null 2>&1 &
	@sleep 2
	@echo "✅ All Kind services mapped to localhost!"
	@echo "======================================================"
	@echo "🖥️  Dashboard / API : http://localhost:8080"
	@echo "📈 InfluxDB UI     : http://localhost:8086 (user: admin, pass: adminpassword123)"
	@echo "📊 Prometheus UI   : http://localhost:9090"
	@echo "🗄️  PostgreSQL      : localhost:5432  (user: postgres, pass: localdevpassword)"
	@echo "📡 MQTT Broker     : localhost:1883"
	@echo "======================================================"
	@echo "(Run 'make kind-down' to clean everything up)"

kind-query-backend:
	@echo "📊 Querying Kind Prometheus for backend API metrics (http_requests_total)..."
	@kubectl --context kind-$(KIND_CLUSTER_NAME) exec -n fire-monitoring-local deploy/prometheus -- wget -qO- 'http://localhost:9090/api/v1/query?query=http_requests_total{app="fire-api"}'

# Backwards compatibility aliases
local-up: kind-up
local-down: kind-down
local-stop: kind-stop
local-restart: kind-restart
local-logs: kind-logs
local-port-forward: kind-port-forward

# ------------------------------------------------------------------------------
# [3] STAGING — GKE Dev ArgoCD GitOps (dev.fires.systems)
# ------------------------------------------------------------------------------
staging-up:
	@echo "🚀 Deploying STAGING (dev) environment via ArgoCD..."
	@echo "   Cloudflared runs in-cluster — dev.fires.systems will go live automatically."
	kubectl --context dev apply -f build/local/argocd-apps-dev.yaml
	@echo "✅ apps-dev applied. ArgoCD will sync automatically."
	@echo "   Watch progress: make staging-watch"

staging-down:
	@echo "🛑 Tearing down STAGING (dev) environment..."
	kubectl --context dev delete -f build/local/argocd-apps-dev.yaml
	@echo "✅ apps-dev deleted. ArgoCD is cleaning up fire-monitoring-dev resources."

staging-sync:
	@echo "⚡ Forcing ArgoCD to sync apps-dev immediately..."
	@kubectl --context dev patch app fire-monitoring-dev -n argocd --type merge \
	  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD","prune":true}}}' \
	  2>/dev/null || echo "⚠️  Patch failed — ArgoCD may still be starting. Try: make gitops-ui"
	@echo "✅ Sync triggered. Watch progress: make staging-watch"

staging-watch:
	@echo "👀 Watching pod rollout in fire-monitoring-dev (Ctrl+C to stop)..."
	kubectl --context dev get pods -n fire-monitoring-dev -w

staging-pause:
	@echo "⏸️  Pausing staging (dev) namespace..."
	kubectl --context dev patch app fire-monitoring-dev -n argocd -p '{"spec":{"syncPolicy":null}}' --type=merge
	kubectl --context dev scale deployment,statefulset --all --replicas=0 -n fire-monitoring-dev

staging-resume:
	@echo "▶️  Resuming staging (dev) namespace..."
	kubectl --context dev patch app fire-monitoring-dev -n argocd -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge

staging-logs-api:
	@echo "📜 Tailing API logs in Dev..."
	kubectl --context dev logs -f -l app=api -n fire-monitoring-dev --all-containers=true --max-log-requests=10

staging-logs-etl:
	@echo "📜 Tailing ETL Processor logs in Dev..."
	kubectl --context dev logs -f -l app=etl-processor -n fire-monitoring-dev --all-containers=true --max-log-requests=10

staging-logs-sim:
	@echo "📜 Tailing MCU Simulator logs in Dev..."
	kubectl --context dev logs -f -l app=mcu-simulator-fleet -n fire-monitoring-dev --max-log-requests=10

staging-port-forward:
	@echo "🌐 Starting background port-forwards for Dev infrastructure..."
	@pkill -f "[k]ubectl --context dev port-forward" 2>/dev/null || true
	@echo "🔍 Checking for port conflicts..."
	@for port in 8081 8080 9090 8086; do \
		if ss -tuln | grep -qE ":$$port\b"; then \
			echo "❌ Error: Port $$port is in use by another project! Please stop it and try again."; \
			exit 1; \
		fi \
	done
	@nohup kubectl --context dev port-forward -n argocd svc/argocd-server 8081:80 > /dev/null 2>&1 &
	@nohup kubectl --context dev port-forward -n fire-monitoring-dev svc/dashboard 8080:80 > /dev/null 2>&1 &
	@nohup kubectl --context dev port-forward -n fire-monitoring-dev svc/prometheus 9090:9090 > /dev/null 2>&1 &
	@nohup kubectl --context dev port-forward -n fire-monitoring-dev svc/influx 8086:8086 > /dev/null 2>&1 &
	@sleep 2
	@echo "✅ Dev infrastructure mapped to localhost!"
	@echo "======================================================"
	@echo "🐙 ArgoCD UI       : https://localhost:8081"
	@echo "   (Password: run 'make staging-argocd-pass')"
	@echo "🖥️  Dev Dashboard   : http://localhost:8080"
	@echo "📊 Dev Prometheus  : http://localhost:9090"
	@echo "📈 Dev InfluxDB    : http://localhost:8086"
	@echo "======================================================"
	@echo "(Run 'make staging-port-forward-stop' to stop)"

staging-port-forward-stop:
	@echo "🛑 Stopping Dev port-forwards..."
	@pkill -f "[k]ubectl --context dev port-forward" 2>/dev/null || true
	@echo "✅ Stopped!"

staging-argocd-pass:
	@echo "🐙 ArgoCD Admin Password:"
	@kubectl --context dev -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo ""

staging-query-backend:
	@echo "📊 Querying Staging (GKE Dev) Prometheus for backend API metrics (http_requests_total)..."
	@kubectl --context dev exec -n fire-monitoring-dev deploy/prometheus -- wget -qO- 'http://localhost:9090/api/v1/query?query=http_requests_total{app="fire-api"}'

# Staging aliases
dev-port-forward: staging-port-forward
dev-port-forward-stop: staging-port-forward-stop
dev-logs-api: staging-logs-api
dev-logs-etl: staging-logs-etl
dev-logs-sim: staging-logs-sim
dev-argocd-pass: staging-argocd-pass

# ------------------------------------------------------------------------------
# [4] PRODUCTION — Guarded Placeholders (fires.systems)
# ------------------------------------------------------------------------------
prod-up:
	@echo "⚠️  [PRODUCTION GUARD] Direct 'make prod-up' is disabled as a placeholder."
	@echo "   Production deployment is strictly managed via CI/CD GitOps promotion."
	@echo "   Pipeline: .github/workflows/app-pipeline.yml"
	@echo "   Target overlay: infrastructure/k8s/overlays/prod"

prod-down:
	@echo "⚠️  [PRODUCTION GUARD] Direct 'make prod-down' is disabled as a placeholder."
	@echo "   Production teardown requires explicit multi-party approval and manual change order."

prod-pause:
	@echo "⚠️  [PRODUCTION GUARD] Direct 'make prod-pause' is disabled as a placeholder."

prod-resume:
	@echo "⚠️  [PRODUCTION GUARD] Direct 'make prod-resume' is disabled as a placeholder."

# ------------------------------------------------------------------------------
# [5] OBSERVABILITY SHORTCUTS & CLUSTER UTILITIES
# ------------------------------------------------------------------------------
query-backend: staging-query-backend

gitops-bootstrap:
	bash infrastructure/scripts/local-gitops-bootstrap.sh

gitops-ui:
	@echo "ArgoCD UI starting... open https://localhost:8443 in your browser."
	kubectl port-forward -n argocd svc/argocd-server 8443:443

status:
	@echo "=== KUBECTL CONTEXT ==="
	@kubectl config current-context 2>/dev/null || echo "No active context."
	@echo "=== KUBERNETES NODES ==="
	@kubectl get nodes 2>/dev/null || echo "Cluster is stopped."
	@echo "=== LOCAL NAMESPACE ==="
	@kubectl --context kind-$(KIND_CLUSTER_NAME) get pods -n fire-monitoring-local 2>/dev/null || true
	@echo "=== DEV (STAGING) NAMESPACE ==="
	@kubectl --context dev get pods -n fire-monitoring-dev 2>/dev/null || true
	@echo "=== PROD NAMESPACE ==="
	@kubectl get pods -n fire-monitoring-prod 2>/dev/null || true
	@echo "=== ARGOCD APPS ==="
	@kubectl get apps -n argocd -o wide 2>/dev/null || echo "ArgoCD not running."

build-local:
	docker build -t localhost/api:local ./apps/api
	docker build -t localhost/dashboard:local ./apps/dashboard
	docker build -t localhost/etl-processor:local ./apps/etl-processor
	docker build -t localhost/mcu-simulator:local ./apps/simulators
	docker build -t localhost/db-migrations:local ./apps/db-migrations

kind-load: build-local
	@echo "⚠️  Kind validation has moved to CI. Use 'make dev-build' for local development. To run Kind locally for debugging, use 'make kind-up-debug'."
	kind load docker-image localhost/api:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/dashboard:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/etl-processor:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/mcu-simulator:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/db-migrations:local --name $(KIND_CLUSTER_NAME)

clean-images:
	docker rmi localhost/api:local localhost/dashboard:local localhost/etl-processor:local localhost/mcu-simulator:local || true

# ------------------------------------------------------------------------------
# [6] GCP GKE TERRAFORM (CI/CD)
# ------------------------------------------------------------------------------
GKE_ENV  := gke-dev
GKE_BASE := infrastructure/terraform/environments/$(GKE_ENV)

gke-dev-bootstrap-plan:
	@cd $(GKE_BASE)/00-bootstrap && terraform init -backend-config=backend.conf && terraform plan -var-file=terraform.tfvars

gke-dev-bootstrap-apply:
	@cd $(GKE_BASE)/00-bootstrap && terraform init -backend-config=backend.conf && terraform apply -var-file=terraform.tfvars

gke-dev-infra-plan:
	@cd $(GKE_BASE)/01-infra && terraform init -backend-config=backend.conf && terraform plan -var-file=terraform.tfvars

gke-dev-infra-apply:
	@cd $(GKE_BASE)/01-infra && terraform init -backend-config=backend.conf && terraform apply -var-file=terraform.tfvars

gke-dev-platform-plan:
	@cd $(GKE_BASE)/02-platform && terraform init -backend-config=backend.conf && terraform plan -var-file=terraform.tfvars

gke-dev-platform-apply:
	@cd $(GKE_BASE)/02-platform && terraform init -backend-config=backend.conf && terraform apply -var-file=terraform.tfvars

gke-dev-argocd-plan:
	@cd $(GKE_BASE)/03-argocd && terraform init -backend-config=backend.conf && terraform plan -var-file=terraform.tfvars

gke-dev-argocd-apply:
	@cd $(GKE_BASE)/03-argocd && terraform init -backend-config=backend.conf && terraform apply -var-file=terraform.tfvars

gke-dev-all-apply: gke-dev-bootstrap-apply gke-dev-infra-apply gke-dev-platform-apply gke-dev-argocd-apply

gke-dev-get-creds:
	gcloud container clusters get-credentials gke-firemonitoring-dev-01 \
	  --region $$(cd $(GKE_BASE)/01-infra && terraform output -raw region) \
	  --project $$(cd $(GKE_BASE)/01-infra && terraform output -raw project_id)

gke-dev-destroy-argocd:
	@cd $(GKE_BASE)/03-argocd && terraform destroy -var-file=terraform.tfvars

gke-dev-destroy-platform:
	@cd $(GKE_BASE)/02-platform && terraform destroy -var-file=terraform.tfvars

gke-dev-destroy-infra:
	@cd $(GKE_BASE)/01-infra && terraform destroy -var-file=terraform.tfvars

GKE_PROD_ENV  := gke-prod
GKE_PROD_BASE := infrastructure/terraform/environments/$(GKE_PROD_ENV)

gke-prod-bootstrap-plan:
	@cd $(GKE_PROD_BASE)/00-bootstrap && terraform init -backend-config=backend.conf && terraform plan -var-file=terraform.tfvars

gke-prod-bootstrap-apply:
	@cd $(GKE_PROD_BASE)/00-bootstrap && terraform init -backend-config=backend.conf && terraform apply -var-file=terraform.tfvars

gke-prod-infra-plan:
	@cd $(GKE_PROD_BASE)/01-infra && terraform init -backend-config=backend.conf && terraform plan -var-file=terraform.tfvars

gke-prod-infra-apply:
	@cd $(GKE_PROD_BASE)/01-infra && terraform init -backend-config=backend.conf && terraform apply -var-file=terraform.tfvars

gke-prod-platform-plan:
	@cd $(GKE_PROD_BASE)/02-platform && terraform init -backend-config=backend.conf && terraform plan -var-file=terraform.tfvars

gke-prod-platform-apply:
	@cd $(GKE_PROD_BASE)/02-platform && terraform init -backend-config=backend.conf && terraform apply -var-file=terraform.tfvars

gke-prod-argocd-plan:
	@cd $(GKE_PROD_BASE)/03-argocd && terraform init -backend-config=backend.conf && terraform plan -var-file=terraform.tfvars

gke-prod-argocd-apply:
	@cd $(GKE_PROD_BASE)/03-argocd && terraform init -backend-config=backend.conf && terraform apply -var-file=terraform.tfvars

gke-prod-all-apply: gke-prod-bootstrap-apply gke-prod-infra-apply gke-prod-platform-apply gke-prod-argocd-apply

gke-prod-get-creds:
	gcloud container clusters get-credentials gke-firemonitoring-prod-01 \
	  --region $$(cd $(GKE_PROD_BASE)/01-infra && terraform output -raw region) \
	  --project $$(cd $(GKE_PROD_BASE)/01-infra && terraform output -raw project_id)

gke-prod-destroy-argocd:
	@cd $(GKE_PROD_BASE)/03-argocd && terraform destroy -var-file=terraform.tfvars

gke-prod-destroy-platform:
	@cd $(GKE_PROD_BASE)/02-platform && terraform destroy -var-file=terraform.tfvars

gke-prod-destroy-infra:
	@cd $(GKE_PROD_BASE)/01-infra && terraform destroy -var-file=terraform.tfvars

# ------------------------------------------------------------------------------
# [7] UTILITIES
# ------------------------------------------------------------------------------
ci-validate:
	@echo "🔍 Validating Kubernetes Kustomize overlays..."
	kubectl kustomize infrastructure/k8s/overlays/dev > /dev/null
	kubectl kustomize infrastructure/k8s/overlays/prod > /dev/null
	kubectl kustomize infrastructure/k8s/overlays/local > /dev/null
	@echo "✅ All Kubernetes Kustomize manifests are valid!"

clean:
	@echo "🧹 Cleaning background processes & logs..."
	-@killall kubectl 2>/dev/null || true
	@rm -f /tmp/pf.log
	@echo "🧹 Cleaning dangling containers & images..."
	-@make clean-images 2>/dev/null || true
	-podman container prune -f 2>/dev/null || true
	-podman volume prune -f 2>/dev/null || true
	-podman image prune -f 2>/dev/null || true
	@echo "✅ Cleanup complete!"
