TF_ROOT := infrastructure/terraform/environments

.PHONY: tf-init-dev tf-init-prod

# Initialize dev backend with an explicit environment-scoped state key.
tf-init-dev:
	terraform -chdir=$(TF_ROOT)/dev init -reconfigure -backend-config=backend.conf -backend-config="key=environments/dev/terraform.tfstate"

# Initialize prod backend with an explicit environment-scoped state key.
tf-init-prod:
	terraform -chdir=$(TF_ROOT)/prod init -reconfigure -backend-config=backend.conf -backend-config="key=environments/prod/terraform.tfstate"

