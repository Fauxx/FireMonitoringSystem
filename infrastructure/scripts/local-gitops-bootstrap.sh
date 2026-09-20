#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# Local GitOps Bootstrapping Script
#
# Mirrors the Terraform 03-argocd cloud layer for local Kind clusters:
#   • Installs ArgoCD
#   • Configures ArgoCD to use the GitHub App for private repo access
#     (same App ID / PEM as set in infrastructure/terraform/.../00-bootstrap)
#   • Creates the GHCR image pull secret using a GitHub App installation token
#   • Replicates the Cloudflare tunnel credentials secret
#   • Applies the root App-of-Apps
#
# Prerequisites:
#   - kubectl pointing to kind-fire-monitoring context
#   - python3 with 'cryptography' library: pip install cryptography
#   - GitHub App PEM key at: ~/Downloads/zet-infra-manager.2026-05-18.private-key.pem
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
GITHUB_APP_ID="${GITHUB_APP_ID:-3682870}"
GITHUB_APP_INSTALLATION_ID="${GITHUB_APP_INSTALLATION_ID:-131567407}"
GITHUB_APP_PEM="${GITHUB_APP_PEM:-$HOME/Downloads/zet-infra-manager.2026-05-18.private-key.pem}"
GITOPS_REPO_URL="https://github.com/Fauxx/FireMonitoringSystem"
CLOUDFLARE_CREDS="${CLOUDFLARE_CREDS:-$HOME/.cloudflared/8a14c96d-85ef-4623-bad8-c95b57aefe14.json}"
# ──────────────────────────────────────────────────────────────────────────────

echo "🔄 Step 1: Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Step 2: Waiting for ArgoCD repo-server to initialize..."
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=120s

echo "📁 Step 3: Creating Dev & Prod Namespaces..."
kubectl create namespace fire-monitoring-dev  --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace fire-monitoring-prod --dry-run=client -o yaml | kubectl apply -f -

echo "🔑 Step 4: Replicating App Secrets..."
if kubectl get secret fire-monitoring-secrets -n fire-monitoring-local >/dev/null 2>&1; then
  kubectl get secret fire-monitoring-secrets -n fire-monitoring-local -o json | \
    jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.managedFields, .metadata.namespace)' | \
    kubectl apply -n fire-monitoring-dev -f -

  kubectl get secret fire-monitoring-secrets -n fire-monitoring-local -o json | \
    jq 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.managedFields, .metadata.namespace)' | \
    kubectl apply -n fire-monitoring-prod -f -
  echo "  ✅ fire-monitoring-secrets replicated to dev and prod."
else
  echo "  ⚠️  fire-monitoring-secrets not found in fire-monitoring-local. Run 'make local-up' first."
fi

echo "🚀 Step 5: Applying Root ArgoCD App-of-Apps..."
kubectl apply -f build/local/argocd-apps.yaml
kubectl apply -f build/local/argocd-apps-dev.yaml

with open("${GITHUB_APP_PEM}", "rb") as f:
    pem = f.read()

try:
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import padding
    from cryptography.hazmat.backends import default_backend

    header  = base64.urlsafe_b64encode(json.dumps({"alg":"RS256","typ":"JWT"}).encode()).rstrip(b"=")
    now     = int(time.time())
    payload = base64.urlsafe_b64encode(
        json.dumps({"iat": now - 60, "exp": now + 540, "iss": "${GITHUB_APP_ID}"}).encode()
    ).rstrip(b"=")
    msg = header + b"." + payload
    key = serialization.load_pem_private_key(pem, password=None, backend=default_backend())
    sig = key.sign(msg, padding.PKCS1v15(), hashes.SHA256())
    jwt = (msg + b"." + base64.urlsafe_b64encode(sig).rstrip(b"=")).decode()

    req = urllib.request.Request(
        "https://api.github.com/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens",
        method="POST",
        headers={
            "Accept":               "application/vnd.github+json",
            "Authorization":        f"Bearer {jwt}",
            "X-GitHub-Api-Version": "2022-11-28",
        }
    )
    with urllib.request.urlopen(req) as resp:
        print(json.loads(resp.read())["token"])
except ImportError:
    print("ERROR: missing 'cryptography' library. Run: pip install cryptography", flush=True)
    exit(1)
PYEOF
)

if [[ "$INSTALL_TOKEN" == ERROR* ]]; then
  echo "  ❌ Failed to generate GitHub App token: $INSTALL_TOKEN"
  exit 1
fi
echo "  ✅ Installation token generated (prefix: ${INSTALL_TOKEN:0:7}...)"

echo "🔐 Step 6: ArgoCD GitHub App Repository Credentials (mirrors Terraform 03-argocd)..."
APP_PRIVATE_KEY=$(cat "${GITHUB_APP_PEM}")
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: repo-github-app-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: "${GITOPS_REPO_URL}"
  githubAppID: "${GITHUB_APP_ID}"
  githubAppIDInstallationID: "${GITHUB_APP_INSTALLATION_ID}"
  githubAppPrivateKey: |
$(echo "$APP_PRIVATE_KEY" | sed 's/^/    /')
EOF
echo "  ✅ ArgoCD repo-github-app-creds secret applied."

echo "🐳 Step 7: GHCR Image Pull Secret (using GitHub App token)..."
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username="Fauxx" \
  --docker-password="${INSTALL_TOKEN}" \
  --docker-email="fauxx@users.noreply.github.com" \
  --namespace=fire-monitoring-dev \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username="Fauxx" \
  --docker-password="${INSTALL_TOKEN}" \
  --docker-email="fauxx@users.noreply.github.com" \
  --namespace=fire-monitoring-prod \
  --dry-run=client -o yaml | kubectl apply -f -
echo "  ✅ ghcr-credentials image pull secret applied to dev and prod namespaces."

echo "☁️  Step 8: Cloudflare Tunnel Credentials Secret..."
if [ -f "${CLOUDFLARE_CREDS}" ]; then
  kubectl create secret generic cloudflare-tunnel-credentials \
    --from-file=credentials.json="${CLOUDFLARE_CREDS}" \
    --namespace=fire-monitoring-dev \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "  ✅ cloudflare-tunnel-credentials applied to fire-monitoring-dev."
else
  echo "  ⚠️  Cloudflare credentials not found at: ${CLOUDFLARE_CREDS}"
fi

echo ""
echo "🎉 Local GitOps Foundation Complete!"
echo "   ArgoCD is installed and authenticated to GitHub/GHCR."
echo ""
echo "   ▶️  To deploy the DEV environment:  make gitops-dev-up"
echo "   ▶️  To deploy the PROD environment: make gitops-prod-up"
echo ""
echo "   Open ArgoCD UI at:  make gitops-ui  → https://localhost:8443"
