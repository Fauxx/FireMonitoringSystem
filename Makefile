TF_ROOT := infrastructure/terraform/environments

.PHONY: tf-init-dev tf-init-prod compose-up-dev compose-up-prod compose-down-dev compose-down-prod compose-validate-dev compose-validate-prod

# Initialize dev backend with an explicit environment-scoped state key.
tf-init-dev:
	terraform -chdir=$(TF_ROOT)/dev init -reconfigure -backend-config=backend.conf -backend-config="key=environments/dev/terraform.tfstate"

# Initialize prod backend with an explicit environment-scoped state key.
tf-init-prod:
	terraform -chdir=$(TF_ROOT)/prod init -reconfigure -backend-config=backend.conf -backend-config="key=environments/prod/terraform.tfstate"

compose-up-dev:
	docker compose -f docker-compose.yml -f build/compose/docker-compose.dev.yml up -d

compose-up-prod:
	docker compose -f docker-compose.yml -f build/compose/docker-compose.prod.yml up -d

compose-down-dev:
	docker compose -f docker-compose.yml -f build/compose/docker-compose.dev.yml down

compose-down-prod:
	docker compose -f docker-compose.yml -f build/compose/docker-compose.prod.yml down

compose-validate-dev:
	docker compose -f docker-compose.yml -f build/compose/docker-compose.dev.yml config -q

compose-validate-prod:
	docker compose -f docker-compose.yml -f build/compose/docker-compose.prod.yml config -q

