# GitOps + Terraform CI/CD Implementation Plan
**Date:** May 15, 2026  
**Status:** Ready for Implementation

---

## Current State Analysis

### ✅ What You Already Have
- **Terraform layers:** `01-infra` (cluster), `02-platform` (ArgoCD install, GitHub secrets)
- **K8s manifests:** `infrastructure/k8s/base/` + overlays using Kustomize
- **App build pipeline:** `app-ci-build.yml` builds 3 services (api, dashboard, etl-processor) and updates dev overlay
- **Modules:** argocd, github-secrets, cert-manager, cluster, dns, ingress-controller
- **State backend:** Remote state in DO Spaces (configured)
- **GitHub secrets:** TF_VAR_github_app_id, TF_VAR_github_app_installation_id, TF_VAR_github_app_private_key (exists)

### ⚠️ Gaps to Close
1. **No GitHub App token minting in CI** — workflows don't use GitHub App for Terraform apply
2. **No separate terraform-validate workflow** — need to split PR validation from main deployment
3. **No 03-argocd layer** — App-of-Apps and ArgoCD repo credentials not in Terraform
4. **No GitOps automation** — manifests updated locally in overlays, not from CI via GitOps repo
5. **No ArgoCD repo credential** — ArgoCD doesn't have secure SSH access to GitOps repo configured

---

## Implementation Plan (4 Phase Rollout)

### Phase 1: GitHub App Token Minting in CI (Low Risk)
**Goal:** Wire GitHub App auth into Terraform workflows so `terraform apply` uses the App identity (no long-lived PAT).

**Files to Create/Patch:**
- **`.github/workflows/terraform-validate.yml`** (NEW)
  - Triggered on PR to `infrastructure/terraform/**`
  - Runs: format check, init (no backend), validate, plan
  - No apply, no image push
  - Permissions: contents:read

- **`.github/workflows/terraform-deploy.yml`** (NEW)
  - Triggered on push to `main` in `infrastructure/terraform/**`
  - Mint GitHub App installation token (Python JWT + curl to GitHub API)
  - Export `INSTALLATION_TOKEN` to env
  - Run: terraform init, plan, apply (with minted token as `GITHUB_TOKEN`)
  - Permissions: contents:write

- **`.github/scripts/mint-app-token.sh`** (NEW)
  - Helper to create JWT and mint installation token
  - Called by both workflows

**Estimated effort:** 2-3 hours  
**Risk:** Low (validate workflow is safe; deploy is only on main)

---

### Phase 2: Create ArgoCD Layer (03-argocd)
**Goal:** Terraform manages ArgoCD App-of-Apps, SSH deploy key k8s secret, and auto-sync policy.

**Files to Create:**
- **`infrastructure/terraform/environments/dev/03-argocd/`** (NEW directory)
  - `main.tf`: Kubernetes `Application` resource (app-of-apps), k8s secret for SSH key
  - `variables.tf`: gitops_repo_url, gitops_repo_ssh_key (base64), etc.
  - `outputs.tf`: app_status, sync_status
  - `README.md`: docs on how to seed SSH key
  - `backend.conf`: state key for 03-argocd layer
  - `terraform.tfvars.example`: example inputs

**Terraform resources:**
```hcl
# kubernetes_manifest for Application (app-of-apps)
resource "kubernetes_manifest" "argocd_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind = "Application"
    metadata = { name = "apps", namespace = "argocd" }
    spec = {
      project = "default"
      source = {
        repoURL = var.gitops_repo_url
        targetRevision = "main"
        path = "apps"
      }
      destination = { server = "https://kubernetes.default.svc" }
      syncPolicy = {
        automated = { prune = true, selfHeal = true }
      }
    }
  }
}

# kubernetes_secret for SSH deploy key (used by ArgoCD repo cred)
resource "kubernetes_secret" "argocd_repo_ssh" {
  metadata {
    name = "argocd-repo-ssh"
    namespace = "argocd"
  }
  data = {
    sshPrivateKey = var.gitops_repo_ssh_key
  }
  type = "Opaque"
}
```

**Estimated effort:** 3-4 hours  
**Risk:** Medium (requires SSH key generation and k8s secret creation, but safe to test locally)

---

### Phase 3: Update Terraform CI Workflow to Support Layer Selection
**Goal:** Allow terraform-deploy.yml to run specific layers or all layers.

**File to Patch:**
- **`.github/workflows/terraform-deploy.yml`**
  - Add input: `layer` (choices: 01-infra, 02-platform, 03-argocd, all)
  - Loop through selected layers and run init/plan/apply

**Estimated effort:** 1-2 hours  
**Risk:** Low

---

### Phase 4: Document and Harden
**Goal:** Add docs for the complete flow and move secrets to repo-only (not environment).

**Files to Create/Patch:**
- **`.github/GITOPS_INFRASTRUCTURE_GUIDE.md`** (NEW)
  - Step-by-step: how to generate SSH deploy key, how to wire GitHub App, how to test locally
  
- **`.github/SECRETS.md`** (PATCH)
  - List all required secrets and where they live
  - Mark which secrets are for Terraform only (don't expose to ArgoCD)

- **GitHub Settings → Secrets → Actions** (USER ACTION)
  - Move `DIGITALOCEAN_TOKEN` from environment `dev` to repo secrets (restrict to terraform-deploy job)
  - Verify `TF_STATE_ACCESS_KEY` and `TF_STATE_SECRET_KEY` are in repo secrets

**Estimated effort:** 2-3 hours  
**Risk:** None (docs + admin actions)

---

## Workflow After Implementation

**Developer Flow:**
```
1. Developer commits infra changes → branches off main
2. Opens PR to main
3. GitHub triggers terraform-validate.yml:
   - Checks formatting, runs terraform plan (read-only)
   - Posts results to PR
4. Code review + approval
5. PR merges to main
6. terraform-deploy.yml triggers automatically:
   - Mints GitHub App installation token
   - Runs terraform init/plan/apply (01-infra, 02-platform, 03-argocd)
   - Creates/updates ArgoCD Application and SSH secret
7. ArgoCD detects new manifests in GitOps repo (via SSH key)
8. ArgoCD auto-syncs and deploys
```

**App Deployment Flow** (unchanged, uses existing app-ci-build.yml):
```
1. Developer commits app changes → opens PR
2. app-ci-build.yml runs: build images, validate compose (no push)
3. PR approved & merged to main
4. app-ci-build.yml: builds images, pushes to GHCR
5. Updates kustomization.yaml in `infrastructure/k8s/overlays/dev` with new image tag
6. Commits to main
7. ArgoCD detects change and syncs (if overlays live in GitOps repo)
   OR manually trigger ArgoCD sync via UI/CLI
```

---

## Implementation Order (Recommended)

**Week 1:**
- Phase 1: Create terraform-validate.yml and terraform-deploy.yml with GitHub App minting
- Test locally: run new workflows manually against dev environment
- Verify Terraform apply works with minted token

**Week 2:**
- Phase 2: Create 03-argocd Terraform layer
- Generate SSH deploy key and populate as variable
- Test: `terraform init`, `terraform plan`, `terraform apply` for 03-argocd layer
- Verify ArgoCD Application created and SSH secret accessible

**Week 3:**
- Phase 3: Update terraform-deploy.yml to support layer selection
- Add GitHub Actions UI to choose layers
- Test: dispatch workflow with different layer combinations

**Week 4:**
- Phase 4: Document and harden secrets
- Update `.github/SECRETS.md` and add new guide
- Verify GitHub repo secrets are set correctly
- Move sensitive tokens from env secrets to repo secrets

---

## Success Criteria

- ✅ terraform-validate.yml runs on PR and reports plan
- ✅ terraform-deploy.yml runs on main merge and applies Terraform using minted GitHub App token
- ✅ 03-argocd layer creates App-of-Apps Application resource
- ✅ ArgoCD SSH secret is created and used by ArgoCD repo credential
- ✅ ArgoCD auto-syncs when manifests in GitOps repo change
- ✅ All secrets are in repo secrets; DO tokens not exposed to ArgoCD env
- ✅ No long-lived PATs in use; only short-lived minted tokens

---

## Known Considerations

1. **SSH Deploy Key:** Must be generated once and stored securely. Will be passed as TF_VAR to terraform via workflow secrets.
2. **GitOps Repo:** Separate repo (e.g., `gitops-repo`) or same repo subdirectory? Plan assumes separate repo.
3. **App Builds:** Current `app-ci-build.yml` updates `infrastructure/k8s/overlays/dev` directly. For full GitOps, should this also push to GitOps repo? (Optional enhancement.)
4. **Rollback:** If ArgoCD sync fails, use `argocd app rollback` CLI or ArgoCD UI to revert to previous commit.

---

## Next Steps

Confirm:
1. Should I start with **Phase 1** (GitHub App token minting)?
2. Should GitOps repo be **separate** or **same repo subdirectory**?
3. Any specific **image tagging strategy** (commit SHA, semver, latest)?

Reply with confirmations and I'll begin implementation.
