# ==============================================================================
#                      FIRE MONITORING SYSTEM - DEV TOOLS
#   SDLC STAGES:
#   1. RAPID DEV        - make rapid-up        Docker Compose hot-reload
#   2. LOCAL MANIFESTS   - make local-up        Kind + port-forward (localhost)
#   3. STAGING (DEV)     - make staging-up      ArgoCD GitOps → dev.fires.systems
#   4. PRODUCTION        - make prod-up         ArgoCD GitOps → fires.systems
#   5. CLOUD (AZURE)     - make aks-dev-*       Terraform AKS pipelines
#   6. UTILITIES         - make status, clean   Hygiene & validation

.DEFAULT_GOAL := up
KIND_CLUSTER_NAME   ?= fire-monitoring
LOCAL_BUILD_DIR     := build/local
AKS_TF_BASE        := infrastructure/terraform/environments
.PHONY: help \
        up down logs \
        rapid-up rapid-down rapid-logs \
        local-up local-down local-stop local-restart local-logs local-port-forward \
        staging-up staging-down staging-sync staging-watch staging-pause staging-resume \
        prod-up prod-down prod-pause prod-resume \
        gitops-bootstrap gitops-ui status \
        build-local kind-load clean-images ci-validate clean \
        aks-dev-bootstrap aks-dev-infra aks-dev-platform aks-dev-argocd aks-dev-plan-all aks-dev-destroy \
        aks-prod-bootstrap aks-prod-infra aks-prod-platform aks-prod-argocd aks-prod-plan-all aks-prod-destroy
# HELP
help:
	@echo "==========================================================================="
	@echo "              FIRE MONITORING SYSTEM — SDLC DEV TOOLS"
	@echo ""
	@echo "🐳 [1] RAPID DEV (Docker Compose — hot-reload, no K8s)"
	@echo "  make up                - Start Compose sandbox (alias for rapid-up)"
	@echo "  make down              - Tear down Compose sandbox (alias for rapid-down)"
	@echo "  make logs              - Tail application logs (alias for rapid-logs)"
	@echo "  make rapid-up          - Start Compose sandbox"
	@echo "  make rapid-down        - Tear down Compose sandbox"
	@echo "  make rapid-logs        - Tail application logs"
	@echo "☸️  [2] LOCAL MANIFEST TESTING (Kind — port-forward only, no tunnel)"
	@echo "  make local-up          - Create Kind cluster, build images, deploy local overlay"
	@echo "  make local-down        - Stop Kind cluster & clean up port-forwards"
	@echo "  make local-restart     - Rebuild images & rollout restart pods"
	@echo "  make local-logs        - Tail local namespace logs"
	@echo "  make local-port-forward - Port-forward ingress → localhost:8080"
	@echo "🚀 [3] STAGING / DEV (ArgoCD GitOps → dev.fires.systems)"
	@echo "  make staging-up        - Bootstrap ArgoCD + deploy dev overlay (tunnel included)"
	@echo "  make staging-down      - Tear down dev environment via ArgoCD"
	@echo "  make staging-sync      - Force ArgoCD sync (skip 3-min poll)"
	@echo "  make staging-watch     - Live-watch pod rollout"
	@echo "  make staging-pause     - Pause auto-sync & scale down dev pods"
	@echo "  make staging-resume    - Restore auto-sync"
	@echo "🛠️  [3.1] DEV UTILITIES"
	@echo "  make dev-port-forward  - Port-forward Dev infrastructure to localhost (ArgoCD, UI, Prometheus, Influx)"
	@echo "  make dev-port-forward-stop - Stop Dev port-forwards"
	@echo "  make dev-logs-api      - Tail API logs in Dev"
	@echo "  make dev-logs-etl      - Tail ETL Processor logs in Dev"
	@echo "  make dev-logs-sim      - Tail MCU Simulator logs in Dev"
	@echo "  make dev-argocd-pass   - Print ArgoCD admin password"
	@echo "🔒 [4] PRODUCTION (ArgoCD GitOps → fires.systems)"
	@echo "  make prod-up           - Deploy prod overlay via ArgoCD"
	@echo "  make prod-down         - Tear down prod environment via ArgoCD"
	@echo "  make prod-pause        - Pause auto-sync & scale down prod pods"
	@echo "  make prod-resume       - Restore auto-sync"
	@echo "🔧 [SHARED] Cluster & GitOps Utilities"
	@echo "  make gitops-bootstrap  - Install ArgoCD, namespaces, secrets, GHCR creds"
	@echo "  make gitops-ui         - Port-forward ArgoCD UI → https://localhost:8443"
	@echo "  make status            - Show cluster context, nodes, pods across all namespaces"
	@echo "☁️  [5] AZURE AKS TERRAFORM (CI/CD)"
	@echo "  make aks-dev-plan-all  - Dry-run plan across all aks-dev layers"
	@echo "  make aks-dev-destroy   - Destroy all aks-dev infrastructure"
	@echo "  make aks-prod-plan-all - Dry-run plan across all aks-prod layers"
	@echo "  make aks-prod-destroy  - Destroy all aks-prod infrastructure"
	@echo "🧹 [6] UTILITIES"
	@echo "  make ci-validate       - Validate all Kustomize overlays"
	@echo "  make clean             - Kill background processes, remove dangling images"
# [1] RAPID DEV — Docker Compose
up: rapid-up
down: rapid-down
logs: rapid-logs
rapid-up:
	@echo "🐳 Starting Docker Compose sandbox..."
	docker compose --project-directory . --env-file $(LOCAL_BUILD_DIR)/.env -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml up --build -d
	@echo "✅ Rapid dev ready! API: localhost:8000 | Dashboard: localhost:8080"
rapid-down:
	docker compose --project-directory . --env-file $(LOCAL_BUILD_DIR)/.env -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml down -v
rapid-logs:
	docker compose --project-directory . --env-file $(LOCAL_BUILD_DIR)/.env -f $(LOCAL_BUILD_DIR)/docker-compose.local.yml logs -f api dashboard etl-processor
# [2] LOCAL MANIFEST TESTING — Kind + port-forward (NO cloudflared)
local-up:
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
	@echo "✅ Local manifest testing ready! Run: make local-port-forward"
local-stop:
	@echo "⏸️  Parking local environment (data preserved)..."
	@pkill -f "kubectl port-forward" 2>/dev/null || true
	@podman stop fire-monitoring-control-plane 2>/dev/null || true
	@echo "✅ Cluster paused. Run 'make local-up' to resume where you left off."

local-down:
	@echo "🛑 Destroying local environment (all data lost)..."
	@pkill -f "kubectl port-forward" 2>/dev/null || true
	kind delete cluster --name $(KIND_CLUSTER_NAME) || true
	@echo "✅ Local environment fully destroyed."
local-restart: build-local kind-load
	@echo "🔄 Rollout restarting local deployments..."
	kubectl --context kind-$(KIND_CLUSTER_NAME) rollout restart deployment -n fire-monitoring-local api dashboard etl-processor mcu-simulator-fleet || true
	kubectl --context kind-$(KIND_CLUSTER_NAME) delete job flyway-migrate -n fire-monitoring-local --ignore-not-found
	kubectl --context kind-$(KIND_CLUSTER_NAME) apply -k infrastructure/k8s/overlays/local
	@echo "✅ Local deployments restarted."
local-logs:
	kubectl --context kind-$(KIND_CLUSTER_NAME) logs -n fire-monitoring-local -f -l deployment-type=local --max-log-requests=50
local-port-forward:
	@echo "🌐 Starting background port-forwards..."
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
	@echo "✅ All services mapped to localhost!"
	@echo "======================================================"
	@echo "🖥️  Dashboard / API : http://localhost:8080"
	@echo "📈 InfluxDB UI     : http://localhost:8086 (user: admin, pass: adminpassword123)"
	@echo "📊 Prometheus UI   : http://localhost:9090"
	@echo "🗄️  PostgreSQL      : localhost:5432  (user: postgres, pass: localdevpassword)"
	@echo "📡 MQTT Broker     : localhost:1883"
	@echo "======================================================"
	@echo "(Run 'make local-down' to clean everything up)"

# [3] STAGING / DEV — ArgoCD GitOps (in-cluster cloudflared → dev.fires.systems)
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
	@kubectl --context dev patch app apps-dev -n argocd --type merge \
	  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD","prune":true}}}' \
	  2>/dev/null || echo "⚠️  Patch failed — ArgoCD may still be starting. Try: make gitops-ui"
	@echo "✅ Sync triggered. Watch progress: make staging-watch"
staging-watch:
	@echo "👀 Watching pod rollout in fire-monitoring-dev (Ctrl+C to stop)..."
	kubectl --context dev get pods -n fire-monitoring-dev -w
staging-pause:
	@echo "⏸️  Pausing staging (dev) namespace..."
	kubectl --context dev patch app apps-dev -n argocd -p '{"spec":{"syncPolicy":null}}' --type=merge
	kubectl --context dev scale deployment,statefulset --all --replicas=0 -n fire-monitoring-dev
staging-resume:
	@echo "▶️  Resuming staging (dev) namespace..."
	kubectl --context dev patch app apps-dev -n argocd -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge

# [3.1] STAGING / DEV — Utilities
dev-logs-api:
	@echo "📜 Tailing API logs in Dev..."
	kubectl --context dev logs -f -l app=api -n fire-monitoring-dev --all-containers=true --max-log-requests=10

dev-logs-etl:
	@echo "📜 Tailing ETL Processor logs in Dev..."
	kubectl --context dev logs -f -l app=etl-processor -n fire-monitoring-dev --all-containers=true --max-log-requests=10

dev-logs-sim:
	@echo "📜 Tailing MCU Simulator logs in Dev..."
	kubectl --context dev logs -f -l app=mcu-simulator-fleet -n fire-monitoring-dev --max-log-requests=10

dev-port-forward:
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
	@echo "   (Password: run 'make dev-argocd-pass')"
	@echo "🖥️  Dev Dashboard   : http://localhost:8080"
	@echo "📊 Dev Prometheus  : http://localhost:9090"
	@echo "📈 Dev InfluxDB    : http://localhost:8086"
	@echo "======================================================"
	@echo "(Run 'make dev-port-forward-stop' to stop)"

dev-port-forward-stop:
	@echo "🛑 Stopping Dev port-forwards..."
	@pkill -f "[k]ubectl --context dev port-forward" 2>/dev/null || true
	@echo "✅ Stopped!"

dev-argocd-pass:
	@echo "🐙 ArgoCD Admin Password:"
	@kubectl --context dev -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo ""

# [4] PRODUCTION — ArgoCD GitOps (in-cluster cloudflared → fires.systems)
prod-up:
	@echo "🔒 Deploying PRODUCTION environment via ArgoCD..."
	@echo "   Cloudflared runs in-cluster — fires.systems will go live automatically."
	kubectl --context prod apply -f build/local/argocd-apps.yaml
	@echo "✅ apps applied. ArgoCD will sync automatically."
prod-down:
	@echo "🛑 Tearing down PRODUCTION environment..."
	kubectl --context prod delete -f build/local/argocd-apps.yaml
	@echo "✅ apps deleted. ArgoCD is cleaning up fire-monitoring-prod resources."
prod-pause:
	@echo "⏸️  Pausing production namespace..."
	kubectl --context prod patch app apps -n argocd -p '{"spec":{"syncPolicy":null}}' --type=merge
	kubectl --context prod scale deployment,statefulset --all --replicas=0 -n fire-monitoring-prod
prod-resume:
	@echo "▶️  Resuming production namespace..."
	kubectl --context prod patch app apps -n argocd -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge
# SHARED — Cluster & GitOps Utilities
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
	docker build -t localhost/db-migrations:local ./infrastructure/k8s/base/sql
kind-load: build-local
	kind load docker-image localhost/api:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/dashboard:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/etl-processor:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/mcu-simulator:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image localhost/db-migrations:local --name $(KIND_CLUSTER_NAME)
clean-images:
	docker rmi localhost/api:local localhost/dashboard:local localhost/etl-processor:local localhost/mcu-simulator:local || true
# [5] GCP GKE TERRAFORM (CI/CD)
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
# [6] UTILITIES
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
	@echo "✅ Cleanup complete!"
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
