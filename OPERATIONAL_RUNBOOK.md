# Fire Monitoring System - Operational Runbooks

Emergency procedures, troubleshooting, and common operational tasks.

## Table of Contents

1. [Emergency Manual Sync](#emergency-manual-sync)
2. [Rollback Procedure](#rollback-procedure)
3. [Troubleshooting Argo CD Sync Failures](#troubleshooting-argo-cd-sync-failures)
4. [Scaling and Resource Management](#scaling-and-resource-management)
5. [Health Checks](#health-checks)
6. [Common Issues](#common-issues)

---

## Emergency Manual Sync

Use this when you need immediate deployment without waiting for automatic sync.

### Prerequisites
- Argo CD CLI installed: `argocd login <server>`
- Authentication token available: `$ARGOCD_AUTH_TOKEN`

### Procedure

```bash
# 1. Validate your changes are committed to Git
git log --oneline -5  # Verify your commit is on main

# 2. Check current application status
argocd app get fire-monitoring-dev

# 3. Trigger immediate sync
argocd app sync fire-monitoring-dev --server $ARGOCD_SERVER --auth-token $ARGOCD_AUTH_TOKEN --grpc-web

# 4. Wait for completion (optional: set timeout)
argocd app wait fire-monitoring-dev --server $ARGOCD_SERVER --auth-token $ARGOCD_AUTH_TOKEN --grpc-web --timeout 300

# 5. Verify deployment
kubectl get pods -n fire-monitoring-dev
kubectl get deployment -n fire-monitoring-dev -o wide
```

### Forced Sync (If Stuck)

If sync seems stuck or has conflicts:

```bash
# Force sync with pruning (removes manually added resources)
argocd app sync fire-monitoring-dev --force --prune

# Monitor progress
watch -n 5 "argocd app get fire-monitoring-dev"
```

---

## Rollback Procedure

Revert to a previous deployment version.

### Option 1: Git Rollback (Recommended)

Leverages Git history as the source of truth.

```bash
# 1. View sync history
argocd app history fire-monitoring-dev

# 2. Identify the revision to rollback to (by revision ID)
# Example output:
#   REVISION  DEPLOYED AT             DURATION  PHASE     SOURCE
#   abc123d   2026-05-05 10:15:00 UTC 2m        Succeeded main
#   def456e   2026-05-05 09:00:00 UTC 3m        Succeeded main

# 3. Rollback to previous revision
argocd app rollback fire-monitoring-dev <REVISION_ID>

# 4. Wait for rollback to complete
argocd app wait fire-monitoring-dev --timeout 300

# 5. Verify
kubectl get pods -n fire-monitoring-dev -o wide
```

### Option 2: Git Revert (For Code Rollbacks)

When you need to revert code changes:

```bash
# 1. Identify the bad commit
git log --oneline | head -10

# 2. Create a new commit that reverts the change
git revert <COMMIT_ID>

# 3. Push to main
git push origin main

# 4. Argo CD will automatically deploy the reverted state
# Monitor via:
argocd app wait fire-monitoring-dev --timeout 300
```

### Option 3: Manual Cluster Cleanup (Last Resort)

If Git state is too complex:

```bash
# 1. Delete the problematic resources
kubectl delete pods -n fire-monitoring-dev <POD_NAME>
# or
kubectl delete deployment -n fire-monitoring-dev <DEPLOYMENT_NAME>

# 2. Argo will recreate them from Git
argocd app sync fire-monitoring-dev --force

# 3. Verify
kubectl get pods -n fire-monitoring-dev
```

---

## Troubleshooting Argo CD Sync Failures

### Symptom: Application Shows "OutOfSync"

**Step 1: Identify the changes**
```bash
argocd app diff fire-monitoring-dev
```

**Step 2: Check Git logs**
```bash
git log --oneline | head -10
```

**Step 3: Determine if changes are intentional**
- If yes → Force sync: `argocd app sync fire-monitoring-dev --force`
- If no → Git revert the changes

**Step 4: Monitor sync**
```bash
argocd app wait fire-monitoring-dev --timeout 300
```

---

### Symptom: Sync Fails with "Resource already exists"

**Cause:** Manual kubectl commands were used

**Fix:**
```bash
# 1. Identify the conflicting resource
argocd app get fire-monitoring-dev --refresh  # Shows detailed error

# 2. Delete the manually created resource
kubectl delete <resource_type> -n <namespace> <resource_name>

# 3. Let Argo recreate it from Git
argocd app sync fire-monitoring-dev --force
```

---

### Symptom: Image Not Updating

**Step 1: Check Image Updater logs**
```bash
kubectl logs -n argocd deployment/argocd-image-updater --tail=100
```

**Step 2: Verify image exists in registry**
```bash
# Check what images are available
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://ghcr.io/v2/fauxx/fire-monitoring-system/api/tags/list
```

**Step 3: Check Argo Application annotations**
```bash
kubectl get application -n argocd fire-monitoring-dev -o yaml | grep -A5 "image-list"
```

**Step 4: Manual image update (if necessary)**
```bash
# Edit the kustomization overlay directly
vim infrastructure/k8s/overlays/dev/kustomization.yaml

# Update the image tag
# images:
#   - name: api
#     newTag: sha-a1b2c3d4e5f6

git add infrastructure/k8s/overlays/dev/kustomization.yaml
git commit -m "Manually update image tag"
git push origin main

# Argo will auto-sync within 3-5 minutes
```

---

### Symptom: Pods in CrashLoopBackOff

**Step 1: Check pod logs**
```bash
kubectl logs -n fire-monitoring-dev deployment/api -f  # Last log
kubectl logs -n fire-monitoring-dev deployment/api --previous  # Previous attempt
```

**Step 2: Common causes and fixes**

**Cause: Missing environment variable**
```bash
# Check what's in the configmap/secret
kubectl get configmap -n fire-monitoring-dev fire-monitoring-config -o yaml
kubectl get secret -n fire-monitoring-dev fire-monitoring-secrets -o yaml

# Update via Git
vim infrastructure/k8s/base/api/configmap.yaml
# or
vim infrastructure/terraform/environments/dev/main.tf  # For Terraform-managed secrets

git commit -am "Add missing env var"
git push origin main
```

**Cause: Resource limits exceeded**
```bash
# Check OOMKilled
kubectl describe pod -n fire-monitoring-dev <POD_NAME> | grep -A5 "Last State"

# Increase memory limit
vim infrastructure/k8s/overlays/dev/kustomization.yaml
# Add patch to increase memory

git commit -am "Increase memory limit"
git push origin main
```

**Cause: Image doesn't exist**
```bash
# Verify image in registry
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://ghcr.io/v2/fauxx/fire-monitoring-system/api/manifests/sha-abc123

# If missing, trigger a rebuild
git commit --allow-empty -m "Trigger CI rebuild"
git push origin main
```

---

## Scaling and Resource Management

### Horizontal Scaling (More Pods)

```bash
# 1. Edit the overlay
vim infrastructure/k8s/overlays/dev/kustomization.yaml

# 2. Add or update replicas patch
patches:
  - target:
      kind: Deployment
      name: api
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3  # Increase from 1 to 3

# 3. Commit and push
git add infrastructure/k8s/overlays/dev/kustomization.yaml
git commit -m "Scale API to 3 replicas for load testing"
git push origin main

# 4. Monitor rollout
kubectl rollout status deployment/api -n fire-monitoring-dev --timeout=5m

# 5. Verify
kubectl get pods -n fire-monitoring-dev | grep api
```

### Vertical Scaling (More Resources Per Pod)

```bash
# 1. Edit the overlay
vim infrastructure/k8s/overlays/dev/kustomization.yaml

# 2. Update resource limits
patches:
  - target:
      kind: Deployment
      name: api
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources
        value:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"

# 3. Commit and push
git add infrastructure/k8s/overlays/dev/kustomization.yaml
git commit -m "Increase API resource limits"
git push origin main

# 4. Wait for Argo to sync and pods to restart
kubectl rollout status deployment/api -n fire-monitoring-dev
```

---

## Health Checks

### Verify All Components Healthy

```bash
# 1. Check Argo CD Application status
argocd app get fire-monitoring-dev

# Expected output:
#   NAMESPACE            NAME
#   fire-monitoring-dev  api
#   fire-monitoring-dev  dashboard
#   fire-monitoring-dev  etl
#   ...
#   STATUS: Synced
#   HEALTH: Healthy

# 2. Check all pods running
kubectl get pods -n fire-monitoring-dev
# All should show STATUS: Running

# 3. Check deployments
kubectl get deployments -n fire-monitoring-dev -o wide
# All should show Ready: 1/1 (or your desired count)

# 4. Check services
kubectl get svc -n fire-monitoring-dev
# All should show TYPE and CLUSTER-IP

# 5. Check database connectivity
kubectl exec -it deployment/api -n fire-monitoring-dev -- \
  psql -h postgresql -U postgres -c "SELECT 1"
# Should return: 1

# 6. Check API endpoint
kubectl port-forward svc/api 8080:8080 -n fire-monitoring-dev &
curl http://localhost:8080/health
# Should return: 200 OK or your app's health endpoint
```

### Check Argo CD System Health

```bash
# Check Argo CD pods
kubectl get pods -n argocd

# Check Argo CD server
kubectl logs -n argocd deployment/argocd-server | tail -20

# Check Argo CD application controller
kubectl logs -n argocd deployment/argocd-application-controller | tail -20

# Check Image Updater
kubectl logs -n argocd deployment/argocd-image-updater | tail -20
```

---

## Common Issues

### Issue: "permission denied" when running argocd commands

**Solution:**
```bash
# Login to Argo CD
argocd login <ARGO_SERVER> --username admin --password <PASSWORD>

# Or use token
export ARGOCD_AUTH_TOKEN=<YOUR_TOKEN>
argocd app get fire-monitoring-dev --server <ARGO_SERVER>
```

---

### Issue: "couldn't authenticate with the server"

**Solution:**
```bash
# Check authentication configuration
argocd account get-user-info

# Refresh login
argocd logout
argocd login <ARGO_SERVER>

# Or regenerate token in GitHub Actions secrets
# Update ARGOCD_AUTH_TOKEN in GitHub Environment secrets
```

---

### Issue: Git push doesn't trigger deployment

**Solution:**
```bash
# 1. Check workflow is enabled
git ls-remote --get-url origin  # Verify repo URL

# 2. Check GitHub Actions logs
# Go to: https://github.com/Fauxx/FireMonitoringSystem/actions

# 3. Manually trigger Argo sync
argocd app sync fire-monitoring-dev --force

# 4. Check Git polling interval
# Argo polls every 5 minutes by default
# If urgent, use manual sync
```

---

### Issue: "Cluster resource not accessible"

**Solution:**
```bash
# Verify Kubernetes connection
kubectl cluster-info

# Check Argo CD cluster connection
argocd cluster list

# Verify kubeconfig in Terraform secrets
kubectl config get-clusters
```

---

## Contact & Escalation

For issues beyond these runbooks:
1. Check Argo CD application logs: `kubectl logs -n argocd deployment/argocd-<component>`
2. Review recent Git commits: `git log --oneline | head -20`
3. Check cluster events: `kubectl get events -n fire-monitoring-dev --sort-by='.lastTimestamp'`
4. Contact the infrastructure team with logs and error messages

---

**Last Updated:** 2026-05-05
**Document Version:** 1.0
