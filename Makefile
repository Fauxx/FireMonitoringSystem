TF_ROOT := infrastructure/terraform/environments
KIND_CLUSTER_NAME ?= fire-monitoring

.PHONY: tf-init-dev tf-init-prod local-up local-down build-local kind-load deploy-local clean-images

# Initialize dev backend with an explicit environment-scoped state key.
tf-init-dev:
	terraform -chdir=$(TF_ROOT)/dev init -reconfigure -backend-config=backend.conf -backend-config="key=environments/dev/terraform.tfstate"

# Initialize prod backend with an explicit environment-scoped state key.
tf-init-prod:
	terraform -chdir=$(TF_ROOT)/prod init -reconfigure -backend-config=backend.conf -backend-config="key=environments/prod/terraform.tfstate"

# Spin up Docker Compose local sandbox
local-up:
	docker compose -f docker-compose.local.yml up --build -d

# Spin down Docker Compose local sandbox (and clean volumes)
local-down:
	docker compose -f docker-compose.local.yml down -v

# Clean local docker images
clean-images:
	docker rmi api:local dashboard:local etl-processor:local || true

# Build local docker images
build-local:
	docker build -t api:local ./apps/api
	docker build -t dashboard:local ./apps/dashboard
	docker build -t etl-processor:local ./apps/etl-processor

# Load local docker images into Kind
kind-load: build-local
	kind load docker-image api:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image dashboard:local --name $(KIND_CLUSTER_NAME)
	kind load docker-image etl-processor:local --name $(KIND_CLUSTER_NAME)

# Deploy local kustomize overlay to Kind
deploy-local:
	kubectl create namespace fire-monitoring-local --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -k infrastructure/k8s/overlays/local
