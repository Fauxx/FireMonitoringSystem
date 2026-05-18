# Dev 02-Platform: Argo CD + GitHub Secrets Setup

This layer installs Argo CD, sets up a DNS record, and syncs GitHub Actions environment secrets via Terraform.

## Provisioning Checklist

### Prerequisites (from 01-infra)
- ✅ DOKS cluster created and running  
- ✅ Remote state available in DO Spaces  
- ✅ `do_token` available  

### GitHub App Setup (one-time)

If you want CI/CD automation (GitHub App for secure token minting):

1. **Create a GitHub App** (Settings → Developer settings → GitHub Apps)
   - Permissions: `Contents: Read`, `Pull requests: Write`
   - Install on your repo
   - Save: **App ID**, **Installation ID**, **Private key**

2. **Encode the private key**
   ```bash
   base64 -w0 < your-app-private-key.pem
   ```

3. **Add secrets to GitHub repo**
   - Go to Settings → Environments → Create new environment `dev`
   - Add secrets:
     - `APP_ID` = your App ID (numeric string)
     - `APP_INSTALLATION_ID` = your Installation ID
     - `APP_PRIVATE_KEY` = base64-encoded private key

### Terraform Inputs (for `terraform apply`)

Required:
- `do_token` (GitHub Actions or local: `$TF_VAR_do_token`)
- `github_token` (GitHub PAT for Terraform to create Environment)
- `github_repository` (e.g., `FireMonitoringSystem`)
- `github_owner` (e.g., `Fauxx`)

Optional (but recommended for CI/CD):
- `github_app_id` (base64-encoded, or injected via CI)
- `github_app_installation_id`
- `github_app_private_key` (base64-encoded)
- `ghcr_deploy_username` (for container registry)
- `ghcr_deploy_token`

### Local Apply Example

```bash
export TF_VAR_do_token="dop_v1_..."
export TF_VAR_github_token="ghp_..."
export TF_VAR_github_app_id="1234567"
export TF_VAR_github_app_installation_id="98765432"
export TF_VAR_github_app_private_key="base64_encoded_key_here"

cd infrastructure/terraform/environments/dev/02-platform
terraform init -reconfigure \
  -backend-config=../../../backend-common.conf \
  -backend-config=backend.conf
terraform plan
terraform apply
```

### CI/CD Apply (GitHub Actions)

The `.github/workflows/terraform-infra.yml` workflow:
1. Reads secrets from GitHub repo/org context
2. Injects via `TF_VAR_*` environment variables
3. Runs `terraform apply` with the github_secrets module enabled

**Result:** GitHub Actions environment `dev` secrets are automatically synced:
- `KUBECONFIG_DATA`
- `DIGITALOCEAN_TOKEN`
- `ARGOCD_SERVER`
- `ARGOCD_AUTH_TOKEN`
- `APP_ID`, `APP_INSTALLATION_ID`, `APP_PRIVATE_KEY` (if provided)
- `GHCR_DEPLOY_USERNAME`, `GHCR_DEPLOY_TOKEN` (if provided)

### Verification

After `terraform apply`:

1. Check GitHub environment `dev` → Secrets tab → confirm all secrets present
2. Check Argo CD is running:
   ```bash
   kubectl -n argocd get pods
   kubectl -n argocd get service argocd-server
   ```
3. Verify DNS record:
   ```bash
   nslookup argocd.fires.systems
   ```

## Outputs

- `argocd_namespace` = `argocd`
- `argocd_url` = `https://argocd.fires.systems` (or your configured FQDN)
- `argocd_loadbalancer_ip` = external IP of Argo CD service

## Next Step

Once 02-platform is applied successfully, proceed to [03-argocd](../03-argocd) to set up the Argo CD Application resource that watches your GitOps repo.
