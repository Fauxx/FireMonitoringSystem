GitOps / CI-CD industry-grade setup (ArgoCD + GitHub App)
=========================================================

This document describes a secure, pull-based GitOps setup using:
- Terraform for infra (CI-run via GitHub Actions)
- A GitHub App for CI push/mutation rights (no long-lived PATs)
- A GitOps repo that ArgoCD watches (pull-based deployments)

Goals
- CI builds artifacts (images), updates manifests in the GitOps repo (PR flow), and merges.
- ArgoCD auto-syncs merged changes and deploys.
- Minimal sensitive exposure: DO tokens and state keys remain in CI secrets only.

Step 1 — Create GitHub App
1. Create a GitHub App (Settings → Developer settings → GitHub Apps).
2. Permissions: Repository: Contents (Read), Pull requests (Write); Actions: Read & write if you plan to trigger workflows.
3. Install the App on the infra and gitops repositories.
4. Save: App ID, Installation ID, and the private key PEM.

Step 2 — Store secrets in GitHub (org or repo secrets)
- `TF_VAR_github_app_id` = <app id> (Terraform bootstrap only)
- `TF_VAR_github_app_installation_id` = <installation id> (Terraform bootstrap only)
- `TF_VAR_github_app_private_key` = base64(PK.pem) (Terraform bootstrap only)
- `APP_ID` = <app id> (GitHub Actions environment secret for deployment workflows)
- `APP_INSTALLATION_ID` = <installation id> (GitHub Actions environment secret for deployment workflows)
- `APP_PRIVATE_KEY` = base64(PK.pem) (GitHub Actions environment secret for deployment workflows)
- `TF_VAR_do_token` = DigitalOcean API token (Terraform uses this)
- `TF_STATE_ACCESS_KEY` / `TF_STATE_SECRET_KEY` = DO Spaces keys
- `GHCR_PAT` = token to push images (or use OIDC to GHCR)
- `GITOPS_PUSH_TOKEN` = (optional) token for pushing PR branches (bot or App)

Step 3 — Use GitHub App tokens in CI (mint at runtime)
CI job flow (before terraform / push steps):
1. Create a JWT signed by the App private key.
2. POST to `https://api.github.com/app/installations/{installation_id}/access_tokens` to get `installation_token`.
3. Export `INSTALLATION_TOKEN` to the job environment and use it for GitHub API actions and Terraform's `github` provider.

Snippet (bash/python) to mint token inside a workflow step:
```bash
# set env: APP_ID, INSTALLATION_ID, APP_KEY_B64
python - <<'PY'
import os, time, jwt, base64
app_id=os.environ['APP_ID']; inst=os.environ['INSTALLATION_ID']
key=base64.b64decode(os.environ['APP_KEY_B64'])
now=int(time.time())
payload={"iat":now-60,"exp":now+540,"iss":str(app_id)}
print(jwt.encode(payload, key, algorithm='RS256'))
PY
# then curl to mint and export token
```

Step 4 — Pass token into Terraform
- In the workflow, set `GITHUB_TOKEN` or `TF_VAR_github_token` to the minted `installation_token` before running `terraform plan/apply` so the `github` provider uses the App identity.
- For deployment workflows that only mint a short-lived token to create PRs, read `APP_ID` and `APP_PRIVATE_KEY` from the GitHub Actions environment secrets.

Step 5 — Configure ArgoCD repo access (recommended: SSH deploy key)
Recommended flow: give ArgoCD a read-only SSH deploy key for the GitOps repo.
1. `ssh-keygen -t ed25519 -f argocd-deploy -N ''`
2. Add `argocd-deploy.pub` as a Deploy Key on the GitOps repo (read-only).
3. Store `argocd-deploy` private key as a Kubernetes secret in `argocd` namespace (created by Terraform or CI):
```bash
kubectl -n argocd create secret generic argocd-repo-ssh --from-file=sshPrivateKey=argocd-deploy
```
4. Configure ArgoCD to use that repo credential (argocd CLI or `Repository` resource).

Step 6 — App-of-Apps + automated sync
- Create an ArgoCD `Application` (app-of-apps) pointing at the GitOps repo and set `syncPolicy.automated`.

Example snippet:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/ORG/gitops-repo.git'
    targetRevision: main
    path: apps
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Step 7 — CI updates manifests via PR (recommended)
CI build flow:
1. Build image and push to registry (GHCR or DOCR).
2. Clone GitOps repo in CI, create a branch, update kustomization/helm values with the new image tag.
3. Commit and push branch, open a PR.
4. Merge PR via review/automation — ArgoCD will pull and deploy.

Step 8 — Secrets for workloads
- Use ExternalSecrets or SealedSecrets for runtime secrets, do not commit plaintext secrets in repo B.

Operational notes
- Protect the `main` branch in GitOps repo with required reviews and allow auto-merge from CI bot if desired.
- Limit workflow permissions and use short-lived tokens minted at runtime.
- Keep DO tokens and state access keys only in CI secrets; do not put them in ArgoCD environment secrets.

Files to add in this repo (suggested)
- `.github/GITOPS_SETUP.md` (this file)
- Terraform: add k8s/kubectl resource to create ArgoCD repo secret from a secret value (private key injected by CI), or document manual step.
- Workflow: update `.github/workflows/terraform-infra.yml` to mint App token and export it before Terraform steps.

If you want I can patch:
- the Terraform CI workflow to include minting the GitHub App installation token and passing it to Terraform, and
- add an `argocd/repo-secret.yaml` template that Terraform or CI can apply to create the ArgoCD SSH key secret.
