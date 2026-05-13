# Progress Report (May 12, 2026)

## Status Summary
- Layered Terraform split is in place for dev/prod: 01-infra (hardware) and 02-k8s-config (software).
- GitHub App auth is now used for the GitHub provider and Argo CD repo credentials (inline token minting).
- CI contract/workflow inputs updated to remove github_token and require GitHub App credentials.
- Local dev 01-infra tfvars cleaned to infra-only values.
- Dev 02-k8s-config validates cleanly.

## Implemented Changes
- GitHub App inline token minting via github_app_token data source for Argo CD repo secret.
- Removed github_token usage from software-layer Terraform and CI wiring.
- Added remote_state_* in dev/prod 02-k8s-config tfvars; removed infra-only values there.
- Docs updated to reflect GitHub App credentials and GHCR token naming in examples.

## Validation Results
- dev 01-infra: terraform init (backend=false) previously showed warnings due to mixed tfvars; warnings resolved by cleaning tfvars.
- dev 02-k8s-config: terraform init/validate (backend=false) passes.
- dev 02-k8s-config plan: fails to read terraform_remote_state without DO Spaces credentials in environment (see Blockers).

## Blockers / Risks
- terraform_remote_state does not read backend.conf; it requires DO Spaces credentials via environment or shared credentials. Without AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY, plan fails when reading remote state.
- backend.conf files contain credentials; treat as sensitive and avoid committing or sharing.

## Files Touched (Key)
- infrastructure/terraform/environments/dev/02-k8s-config/main.tf
- infrastructure/terraform/environments/prod/02-k8s-config/main.tf
- infrastructure/terraform/environments/dev/02-k8s-config/variables.tf
- infrastructure/terraform/environments/prod/02-k8s-config/variables.tf
- infrastructure/terraform/environments/dev/02-k8s-config/terraform.tfvars
- infrastructure/terraform/environments/prod/02-k8s-config/terraform.tfvars
- .github/actions/terraform-contract/action.yml
- .github/workflows/terraform-infra.yml
- README.md
- OPERATIONAL_RUNBOOK.md
- apps/dashboard/README.md
- infrastructure/terraform/environments/dev/01-infra/terraform.tfvars

## Open Items
- Provide DO Spaces credentials in env to run dev/prod 02-k8s-config plan.
- Optionally update terraform_remote_state config to use endpoints.s3 to remove deprecation warning.
