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

# Progress Report (May 13, 2026)

## Status Summary
- The `fire-monitoring-dev` namespace is now live on the **do-sgp1** cluster.
- Local Fedora environment is successfully "pushing" authenticated secrets to GitHub Environment Secrets.
- RBAC elevation is complete; the `argocd-manager` ServiceAccount is now a `cluster-admin`.
- Kubernetes provider logic is refined to use direct tokens, bypassing previous structural mismatches in `kubeconfig`.

## Implemented Changes
- Migrated from static Secret-based tokens to the `kubectl create token` method (valid for 1 year).
- Successfully ran `terraform apply` to modify 4 environment secrets: `KUBECONFIG_DATA`, `GH_APP_ID`, `GH_APP_INSTALLATION_ID`, and `GH_APP_PRIVATE_KEY`.
- Updated `environments/dev/03-k8s-apps/main.tf` to use `var.argocd_auth_token` directly for authentication.
- Applied `terraform-argo-admin` ClusterRoleBinding to allow management of cluster-scoped resources.

## Validation Results
- `kubernetes_namespace.fire_monitoring`: Creation confirmed complete.
- `github_actions_environment_secret`: Modification of all 4 secrets confirmed complete.
- Namespace isolation verified; `fire-monitoring-dev` is active in the cluster context.

## Blockers / Risks
- **Argo CD Auth**: Provider currently reports `invalid session` (SSO error) because it is not yet explicitly using the bearer token.
- **Network Path**: The current `server_addr` is set to `localhost`, which will prevent GitHub Actions runners from reaching the cluster.
- **Credential Sensitivity**: Kubeconfig data and tokens are now stored in GitHub; ensure environment protection rules are active.

## Files Touched (Key)
- `infrastructure/terraform/environments/dev/03-k8s-apps/main.tf`
- GitHub Repository Environment Secrets (development)

## Open Items
- Update Argo CD `server_addr` from `localhost` to the public LoadBalancer IP/DNS.
- Add `auth_token` and `insecure = true` to the Argo CD provider block.
- Finalize `.github/workflows/terraform-infra.yml` to mount the new environment secrets.