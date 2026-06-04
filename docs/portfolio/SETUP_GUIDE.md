# Infrastructure Setup & Local Credentials

This guide outlines the necessary credentials and environment variables required to execute Terraform plans and manage the infrastructure layers locally.

## 🔐 Required Environment Variables

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

### 3. DigitalOcean Spaces Keys (S3 Backend)
Required for Terraform to read/write the remote state file.
```bash
export AWS_ACCESS_KEY_ID="your_spaces_access_key"
export AWS_SECRET_ACCESS_KEY="your_spaces_secret_key"
# Optional: Disable metadata check to speed up init/plan
export AWS_EC2_METADATA_DISABLED=true
```

### 4. (Optional) GitHub App Credentials for CI/CD Automation
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
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."

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

**Error: InvalidClientTokenId or Retrieving AWS account details?**
- This usually means you have extraneous AWS environment variables set (like `AWS_SESSION_TOKEN` or `AWS_PROFILE`) that are expired or invalid for DigitalOcean Spaces.
- **Fix:** Run `unset AWS_SESSION_TOKEN AWS_PROFILE AWS_SECURITY_TOKEN` and try again.
- Ensure `AWS_EC2_METADATA_DISABLED=true` is set.

**Still getting "Unauthorized" on Kubernetes?**
- This means the remote state from 01-infra is not readable or doesn't have valid cluster credentials
- Verify `TF_VAR_do_token` is correct (it's used to read remote state from Spaces)
- Verify 01-infra layer completed successfully and wrote valid kubeconfig to remote state
