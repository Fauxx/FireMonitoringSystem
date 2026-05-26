# Workflow Trigger Remediation Plan

## Root Cause Analysis

You recently pushed configuration changes for the `fire-monitoring-config` (PR #103) to the `main` branch, but neither of the CI/CD pipelines (`app-pipeline.yml` or `terraform-deploy.yml`) triggered.

Here is why:

### 1. Application Pipeline (`app-pipeline.yml`)
The application pipeline is configured to trigger **only** when files inside the `apps/` directory or the workflow file itself change:
```yaml
  push:
    branches: [ main ]
    paths:
      - 'apps/**'
      - '.github/workflows/app-pipeline.yml'
```
Because your latest merge (PR #103) only modified files inside `infrastructure/k8s/` (specifically `infrastructure/k8s/base/db/secrets.yaml`, `infrastructure/k8s/overlays/dev/dev-public.env`, etc.), this workflow correctly ignored the push.

### 2. Infrastructure Pipeline (`terraform-deploy.yml`)
The infrastructure pipeline is configured to trigger **only** when Terraform configurations or Action definitions change:
```yaml
  push:
    branches: [ main ]
    paths:
      - "infrastructure/terraform/**"
      - ".github/workflows/terraform-deploy.yml"
      - ".github/workflows/terraform-reusable.yml"
      - ".github/actions/**"
```
Because your changes were in `infrastructure/k8s/` (Kubernetes manifests, not Terraform), this workflow also correctly ignored the push.

### 3. The Gap (No K8s Manifest Workflow)
Currently, there is no workflow specifically watching `infrastructure/k8s/**`. 
Because ArgoCD is designed to poll the repository every 3 minutes (or sync immediately via webhook), Kubernetes manifests typically do not *need* a GitHub Actions workflow unless you are validating the YAML (e.g., using `kubeval` or `kube-linter`) before they are merged.

However, as previously discovered, ArgoCD is currently **Degraded** and unable to talk to the Kubernetes API due to the restrictive `argocd-network-policy`, which is why the changes weren't pulled into the cluster.

---

## Remediation Plan

To fix this end-to-end, we must execute the following two steps. I recommend I handle Step 1 for you right now, and then you follow up with Step 2.

### Step 1: Fix the ArgoCD Network Policy (Cluster Connectivity)
ArgoCD is locked out of the cluster API. We need to loosen the egress rules in `infrastructure/k8s/base/argocd/networkpolicy.yaml` so ArgoCD can fetch secrets and configmaps from the `argocd` namespace and the `kube-apiserver`.

**Proposed Action:**
Modify `infrastructure/k8s/base/argocd/networkpolicy.yaml` to allow egress to the Kubernetes API server and internal Redis instances.

```yaml
  egress:
    # Allow all egress within the argocd namespace (Redis/Dex communication)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: argocd
              
    # Allow egress to the Kubernetes API Server (typically default namespace)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: default
      ports:
        - protocol: TCP
          port: 443
          
    # (Keep existing rules for github, DNS, and application namespaces)
```

### Step 2: Restart ArgoCD (Manual Recovery)
Because the network policy is preventing ArgoCD from reading Git or the cluster, it cannot self-heal the network policy that is blocking it. You must temporarily delete the policy manually in the cluster.

Run this against your DigitalOcean cluster:
```bash
kubectl delete networkpolicy argocd-network-policy -n argocd
```

### Step 3: Implement Manifest Validation (Optional but Recommended)
To prevent confusion in the future, we should add a `paths` trigger to the Application Pipeline (or create a new `manifest-validation.yml`) to at least run a linting check when `infrastructure/k8s/**` changes, providing immediate visual feedback in GitHub PRs.

**Proposed Action:**
Update `.github/workflows/app-pipeline.yml` (or create a new workflow) to trigger on `infrastructure/k8s/**` changes and run `kubectl kustomize` validation.
