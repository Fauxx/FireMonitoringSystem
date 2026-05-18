# Credentials Required for terraform plan/apply

## Before running `terraform plan` or `terraform apply` in dev/02-platform:

### 1. DigitalOcean API Token
```bash
export TF_VAR_do_token="dop_v1_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```
- Get from: https://cloud.digitalocean.com/account/api/tokens
- Needs scope: read+write (for DigitalOcean DNS records)

### 2. GitHub PAT (Personal Access Token)
```bash
export TF_VAR_github_token="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```
- Get from: https://github.com/settings/tokens
- Needs scopes:
  - `repo` (full control)
  - `admin:org_hook` (for environment secrets)
  - `user:email` (read email)

### 3. (Optional) GitHub App Credentials for CI/CD Automation
Only needed if you want the Terraform apply to *also* sync GitHub App secrets to the environment.
```bash
export TF_VAR_github_app_id="1234567"
export TF_VAR_github_app_installation_id="98765432"
export TF_VAR_github_app_private_key="LS0tLS1CRUdJTi..." # base64-encoded PEM
```

## Quick Setup

```bash
# 1. Get your tokens from GitHub and DigitalOcean

# 2. Export them
export TF_VAR_do_token="dop_v1_..."
export TF_VAR_github_token="ghp_..."

# 3. Verify they're set
echo "DO Token: ${TF_VAR_do_token:0:10}..."
echo "GitHub Token: ${TF_VAR_github_token:0:10}..."

# 4. Now try terraform plan
cd infrastructure/terraform/environments/dev/02-platform
terraform init -reconfigure -backend-config=../../../backend-common.conf -backend-config=backend.conf
terraform plan
```

## Notes

- **DO Token** reads the remote state from Spaces and creates DNS records
- **GitHub Token** creates/updates the GitHub environment `dev` and syncs secrets
- These are **distinct** from the GitHub App credentials (which are *optional* and used by CI workflows)
- **Never commit** these tokens to git; always use environment variables or a secure secrets manager

## Troubleshooting

**Still getting "Unauthorized" on GitHub?**
- Verify PAT hasn't expired: https://github.com/settings/tokens
- Check scopes include `repo` and `admin:org_hook`
- Try a fresh token if unsure

**Still getting "Unauthorized" on Kubernetes?**
- This means the remote state from 01-infra is not readable or doesn't have valid cluster credentials
- Verify `TF_VAR_do_token` is correct (it's used to read remote state from Spaces)
- Verify 01-infra layer completed successfully and wrote valid kubeconfig to remote state
