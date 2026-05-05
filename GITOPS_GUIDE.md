# Fire Monitoring System - GitOps Deployment Guide

## Overview

The Fire Monitoring System now uses a **fully automated GitOps approach** with Argo CD for deployments. This guide explains how deployments work and how to manage them.

## Key Concepts

### What is GitOps?

GitOps is a deployment methodology where:
- **Git is the single source of truth** for your infrastructure and application state
- **Everything is declarative** - all configuration lives in Git
- **Deployments are automatic** - Argo CD continuously synchronizes Git with your cluster
- **Changes are auditable** - all deployments are Git commits with history

### How the Fire Monitoring System Uses GitOps

```
Developer commits code
    ↓
GitHub Actions builds container images
    ↓
Images pushed to GHCR (GitHub Container Registry)
    ↓
Argo CD detects new images
    ↓
Argo CD syncs cluster state to match Git
    ↓
New version running in Kubernetes
```

## Deployment Workflow

### 1. Code Changes (Normal Development)

**When you:** Push code changes to the `main` branch (or merge a PR)

**What happens:**
1. GitHub Actions workflow `app-ci-build.yml` is triggered
2. Docker images are built for changed services
3. Images are pushed to GHCR with SHA-based tags: `sha-<first-12-chars>`
4. Argo CD detects new images (via Image Updater)
5. Argo CD automatically deploys the new version

**Timeline:** ~5-10 minutes total (build + deploy)

**Example:**
```bash
git commit -am "Add new API endpoint"
git push origin main

# → CI builds images: api:sha-a1b2c3d4e5f6, dashboard:sha-a1b2c3d4e5f6
# → Argo CD detects and deploys automatically
# → New version live in ~5 minutes
```

### 2. Manifest Changes (Kubernetes Configuration)

**When you:** Modify files in `infrastructure/k8s/` on the `main` branch

**What happens:**
1. GitHub Actions workflow `app-cd-manifest-trigger.yml` is triggered
2. Kustomization is validated
3. Argo CD triggers an immediate sync
4. Kubernetes cluster is updated to match the manifest

**Timeline:** ~1-2 minutes total (validation + sync)

**Example:**
```bash
# Update resource limits in overlays/dev/kustomization.yaml
git commit -am "Increase memory limit for API"
git push origin main

# → Kustomization validated
# → Argo CD syncs cluster
# → New resource limits applied in ~1 minute
```

### 3. Image Tag Updates (Image Updater)

**When:** Argo CD Image Updater detects a new image in the registry

**What happens:**
1. Image Updater scans GHCR for new images matching the pattern
2. When new image found, Argo Application is updated with new tag
3. Argo auto-sync detects the change
4. Cluster is updated to deploy the new image

**Timeline:** ~2-3 minutes total (detection + deploy)

**Note:** This is automatic - no manual intervention needed!

## How to Deploy

### Option 1: Automatic (Recommended)

Just push to main. Everything happens automatically:
```bash
# Make your changes
git commit -am "Your change"
git push origin main

# That's it! Argo CD handles the rest.
```

### Option 2: Manual Sync (If Needed)

If you need to manually trigger a deployment:

```bash
# For dev environment
argocd app sync fire-monitoring-dev --server <ARGO_SERVER> --auth-token <TOKEN>

# For prod environment
argocd app sync fire-monitoring-prod --server <ARGO_SERVER> --auth-token <TOKEN>
```

Available via the manual sync GitHub Actions workflow: **App CD Deploy (Argo CD Manual Sync)**

## Checking Deployment Status

### Via Argo CD UI

1. Access Argo CD server (ask your infrastructure team for the URL)
2. Click on the application (`fire-monitoring-dev` or `fire-monitoring-prod`)
3. View real-time sync status and resource health

### Via CLI

```bash
# Check application status
argocd app get fire-monitoring-dev

# Check sync history
argocd app history fire-monitoring-dev

# View live logs
argocd app logs fire-monitoring-dev
```

### Via kubectl

```bash
# Check Argo Application resource
kubectl get applications -n argocd fire-monitoring-dev -o yaml

# Check pod status
kubectl get pods -n fire-monitoring-dev

# View pod logs
kubectl logs -n fire-monitoring-dev deployment/api -f
```

## Understanding the Infrastructure

### Directory Structure

```
infrastructure/
├── k8s/                          # Kubernetes manifests
│   ├── base/                    # Shared resources
│   │   ├── api/                # API deployment & service
│   │   ├── dashboard/          # Dashboard deployment & service
│   │   ├── etl/                # ETL processor deployment
│   │   ├── db/                 # PostgreSQL
│   │   ├── influx/             # InfluxDB
│   │   ├── mqtt/               # MQTT broker
│   │   ├── argocd/             # Argo CD specific configs (NetworkPolicy)
│   │   └── kustomization.yaml  # Base kustomization
│   └── overlays/               # Environment-specific overrides
│       ├── dev/                # Dev environment
│       │   └── kustomization.yaml
│       └── prod/               # Production environment
│           └── kustomization.yaml
└── terraform/                  # Infrastructure as Code
    └── environments/
        ├── dev/main.tf         # Dev cluster setup + Argo CD config
        └── prod/main.tf        # Prod cluster setup + Argo CD config
```

### Key Components

1. **Kustomize Overlays** - Define environment-specific settings
   - Dev uses 1 replica, lowest resource limits
   - Prod uses multiple replicas, higher resource limits

2. **Argo Application** - Defined in Terraform
   - Points to `infrastructure/k8s/overlays/<env>`
   - Auto-sync enabled: watches Git for changes
   - Image Updater annotations: detects new images in registry

3. **Argo CD** - GitOps engine
   - Installed via Helm chart (in Terraform)
   - Continuously syncs cluster to Git state
   - Detects image updates and syncs automatically

## Making Configuration Changes

### Updating Resource Limits

```bash
# Edit the overlay for your environment
vim infrastructure/k8s/overlays/dev/kustomization.yaml

# Add/modify patches section for resource limits
patches:
  - target:
      kind: Deployment
      name: api
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources
        value:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"

# Commit and push
git add infrastructure/k8s/overlays/dev/kustomization.yaml
git commit -m "Increase API resource limits"
git push origin main

# Argo CD automatically applies the changes within 1-2 minutes
```

### Adding a New Environment Variable

```bash
# Edit the ConfigMap in base or overlay
vim infrastructure/k8s/base/api/configmap.yaml

# Add your variable
data:
  NEW_VAR: "value"

# Commit and push
git add infrastructure/k8s/base/api/configmap.yaml
git commit -m "Add new environment variable"
git push origin main

# Argo CD automatically applies within 1-2 minutes
```

### Scaling Replicas

```bash
# Edit overlay
vim infrastructure/k8s/overlays/dev/kustomization.yaml

# Add replicas patch
patches:
  - target:
      kind: Deployment
      name: api
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3

git add infrastructure/k8s/overlays/dev/kustomization.yaml
git commit -m "Scale API to 3 replicas"
git push origin main
```

## Troubleshooting

### Application is Out of Sync

**Symptom:** Argo CD shows "OutOfSync" status

**Causes:**
- Manual changes were made in the cluster (kubectl apply, etc.)
- Git was updated but Argo CD hasn't synced yet

**Solution:**
1. Never make manual kubectl changes - always use Git
2. Force a sync: `argocd app sync fire-monitoring-dev --force`
3. Or wait 3-5 minutes for automatic sync

### Pod is in CrashLoopBackOff

**Symptom:** Pod keeps restarting

**Check logs:**
```bash
kubectl logs -n fire-monitoring-dev deployment/api --previous
```

**Common causes:**
- Missing environment variables - check ConfigMap/Secrets
- Resource limits too low - check logs for OOMKilled
- Image tag doesn't exist - check Image Updater logs

**Fix:**
- Update Git manifest with correct config
- Push to main
- Argo CD automatically redeploys

### Image Updater Not Working

**Symptoms:**
- New images built but not deployed
- Argo CD stays on old image tags

**Check logs:**
```bash
kubectl logs -n argocd deployment/argocd-image-updater -f
```

**Common issues:**
- Registry credentials incorrect
- Image tag pattern doesn't match (`sha-<12-hex-chars>`)
- Argo auth token expired

**Fix:**
- Verify secrets: `kubectl get secrets -n argocd`
- Check annotations on Application manifest
- Check Image Updater logs for specific errors

## Best Practices

### ✅ DO:
- Push all changes to Git
- Use meaningful commit messages: `"Add health check probe to API"`
- Test changes locally first
- Review diffs before pushing
- Use feature branches for major changes, then merge to main

### ❌ DON'T:
- Make manual kubectl changes to the cluster
- Commit secrets to Git (use Terraform secrets module)
- Bypass GitOps by directly deploying images
- Edit manifests without testing locally

## Automation Features

### Auto-Sync
- Enabled: Argo CD automatically syncs cluster to Git every 5 minutes
- Prune: Removes resources deleted from Git
- Self-Heal: Restores resources if accidentally modified

### Image Updater
- Automatically detects new images in GHCR
- Updates Argo Application with new tags
- Works 24/7 without manual intervention

### Cost Optimization
- Code changes only trigger image builds (no unnecessary validation)
- Manifest changes skip builds (only kustomize validation)
- Auto-sync eliminates manual sync workflow overhead

## Getting Help

### Logs & Diagnostics

```bash
# Argo CD server logs
kubectl logs -n argocd deployment/argocd-server -f

# Argo CD application controller
kubectl logs -n argocd deployment/argocd-application-controller -f

# Image Updater logs
kubectl logs -n argocd deployment/argocd-image-updater -f

# Repo server (Git operations)
kubectl logs -n argocd deployment/argocd-repo-server -f
```

### Common Commands

```bash
# Describe application status
kubectl describe application fire-monitoring-dev -n argocd

# Refresh Git state
argocd app refresh fire-monitoring-dev

# Sync with specific revision
argocd app sync fire-monitoring-dev --revision main

# View sync progress
argocd app wait fire-monitoring-dev --timeout 300s
```

### Resources

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Best Practices](https://codefresh.io/gitops/)
- [Kustomize Documentation](https://kustomize.io/)
- [Fire Monitoring System Infrastructure Code](../../infrastructure/)

## Migration from Manual Syncs

Previously, deployments required manual GitHub Actions triggers. Now everything is automatic:

**Before (Manual):**
1. Build image via GitHub Actions
2. Manually trigger `App CD Deploy` workflow
3. Wait for sync to complete
4. Verify in cluster

**Now (Automatic):**
1. Push code to main
2. CI builds image automatically
3. Argo CD automatically detects and deploys
4. Done!

**No action required** - everything works automatically once code is merged to main.

---

**Last Updated:** 2026-05-05
