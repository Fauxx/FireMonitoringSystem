# Dev 02-platform Terraform

This folder wires the platform layer (ArgoCD, DNS, GitHub secrets) and pulls remote state from the infra layer (`01-infra`).

Required environment variables for local validation:

- `AWS_ACCESS_KEY_ID` - DO Spaces access key
- `AWS_SECRET_ACCESS_KEY` - DO Spaces secret key
- `AWS_REGION` - region for S3 compatibility (e.g., `us-east-1`)
- `DO_TOKEN` (or pass `do_token` as `-var`) - DigitalOcean API token
- `GITHUB_TOKEN` (or pass `github_token` as `-var`) - GitHub PAT with repo permissions
 - `ARGOCD_AUTH_TOKEN` (optional) - set to create `ARGOCD_AUTH_TOKEN` GitHub environment secret

Quick validation steps:

```bash
export AWS_ACCESS_KEY_ID="<spaces-key>"
export AWS_SECRET_ACCESS_KEY="<spaces-secret>"
export AWS_REGION="us-east-1"
cd infrastructure/terraform/environments/dev/02-platform
terraform init -reconfigure \
	-backend-config=../../../backend-common.conf \
	-backend-config=backend.conf
terraform validate
terraform plan -var="do_token=<DO_API_TOKEN>" -var="github_token=<GH_TOKEN>" -var="remote_state_bucket=<space-name>" -var="infra_state_key=dev/01-infra/terraform.tfstate"
```

If your CI runs without Spaces credentials, consider using `terraform init -backend=false` for contract checks or provide ephemeral credentials to CI.

Backend file guidance:

- `backend.conf` (keeps only the `key` and non-sensitive options) should NOT contain your Spaces keys. Use the example file `backend.conf.example` as a template and keep your real credentials in environment variables (`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`) or an external credentials file.

ArgoCD: If you want the module to populate an `ARGOCD_AUTH_TOKEN` secret in the GitHub environment, export `ARGOCD_AUTH_TOKEN` or pass `-var="argocd_auth_token=<value>"` to `terraform plan`.

GitHub token scopes:

- For the module to create repository environments and environment secrets, the GitHub token must have `repo` scope and `workflow` permissions (or use a GitHub App with installation access to the repo). Prefer using a GitHub App when automating in CI for least privilege.


GitHub App secrets created by module:

- `APP_ID` - the numeric App ID (if provided)
- `APP_INSTALLATION_ID` - the installation id for the repo (if provided)
- `APP_PRIVATE_KEY` - the PEM private key for the GitHub App (sensitive)

When these values are present in runtime variables, the module will create corresponding GitHub Actions environment secrets so workflows can mint installation tokens at runtime.
