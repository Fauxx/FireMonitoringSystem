#!/usr/bin/env bash
# Local GitOps Bootstrapping Script
set -euo pipefail

echo "🔄 Step 1: Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Step 2: Waiting for ArgoCD deployments to initialize..."
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=90s

echo "📁 Step 3: Creating Dev & Prod Namespaces..."
kubectl create namespace fire-monitoring-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace fire-monitoring-prod --dry-run=client -o yaml | kubectl apply -f -

echo "🔑 Step 4: Replicating Secrets..."
if kubectl get secret fire-monitoring-secrets -n fire-monitoring-local >/dev/null 2>&1; then
  kubectl get secret fire-monitoring-secrets -n fire-monitoring-local -o yaml | \
    sed 's/namespace: fire-monitoring-local/namespace: fire-monitoring-dev/' | \
    kubectl apply -f -

  kubectl get secret fire-monitoring-secrets -n fire-monitoring-local -o yaml | \
    sed 's/namespace: fire-monitoring-local/namespace: fire-monitoring-prod/' | \
    kubectl apply -f -
  echo "✅ Secrets successfully replicated to dev and prod namespaces."
else
  echo "⚠️ Warning: fire-monitoring-secrets not found in fire-monitoring-local namespace."
  echo "Please deploy your local overlay first (make deploy-local) or manually create the secrets."
fi

echo "🚀 Step 5: Applying Root ArgoCD App-of-Apps..."
kubectl apply -f build/local/argocd-apps.yaml
kubectl apply -f build/local/argocd-apps-dev.yaml

echo "🎉 Local GitOps Bootstrap Complete!"
