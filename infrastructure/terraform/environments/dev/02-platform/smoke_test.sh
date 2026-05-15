#!/usr/bin/env bash
# Smoke test for dev/02-platform
# Runs terraform plan (and optional apply), verifies outputs, DNS, and GitHub environment secrets.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

export AWS_EC2_METADATA_DISABLED=true

usage() {
  cat <<EOF
Usage: $0 [--apply]
Requires environment variables:
  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
  DO_TOKEN, GITHUB_TOKEN (or set up GitHub App credentials as TF_VAR_...)
  REMOTE_STATE_BUCKET, INFRA_STATE_KEY
Optional:
  ARGOCD_AUTH_TOKEN
  REMOTE_STATE_ENDPOINT (defaults to sgp1.digitaloceanspaces.com)
  REMOTE_STATE_REGION (defaults to us-east-1)
EOF
}

APPLY=false
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=true
fi

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
  echo "Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (DigitalOcean Spaces keys)"
  exit 1
fi

if [ -z "${DO_TOKEN:-}" ]; then
  echo "Please set DO_TOKEN"
  exit 1
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Warning: GITHUB_TOKEN not set; GitHub secret checks will be skipped"
  SKIP_GH=true
else
  SKIP_GH=false
fi

REMOTE_STATE_ENDPOINT=${REMOTE_STATE_ENDPOINT:-sgp1.digitaloceanspaces.com}
REMOTE_STATE_REGION=${REMOTE_STATE_REGION:-us-east-1}

echo "Initializing Terraform (backend.conf must exist or use -backend-config)..."
terraform init -reconfigure \
  -backend-config=../../../backend-common.conf \
  -backend-config=backend.conf

echo "Validating Terraform..."
terraform validate

echo "Planning..."
set +e
terraform plan -var="do_token=${DO_TOKEN}" -var="github_token=${GITHUB_TOKEN:-}" -var="remote_state_bucket=${REMOTE_STATE_BUCKET:-}" -var="infra_state_key=${INFRA_STATE_KEY:-dev/01-infra/terraform.tfstate}" -var="remote_state_endpoint=${REMOTE_STATE_ENDPOINT}" -var="remote_state_region=${REMOTE_STATE_REGION}" -var="argocd_auth_token=${ARGOCD_AUTH_TOKEN:-}" -out=tfplan.binary
plan_exit=$?
set -e

if [ $plan_exit -ne 0 ]; then
  echo "Terraform plan failed (exit ${plan_exit}). Inspect the output above."
  exit $plan_exit
fi

if [ "$APPLY" = true ]; then
  echo "Applying plan..."
  terraform apply -auto-approve tfplan.binary
fi

echo "Collecting outputs..."
terraform output -json > outputs.json

ARGOCD_URL=$(jq -r '.argocd_url.value // empty' outputs.json || true)
ARGOCD_IP=$(jq -r '.argocd_loadbalancer_ip.value // empty' outputs.json || true)

echo "Argocd URL: ${ARGOCD_URL:-<none>}"
echo "Argocd LB IP: ${ARGOCD_IP:-<none>}"

if [ -n "$ARGOCD_URL" ]; then
  HOSTNAME=${ARGOCD_URL#https://}
  echo "Checking DNS for ${HOSTNAME}..."
  if command -v dig >/dev/null 2>&1; then
    DIG_IP=$(dig +short "$HOSTNAME" | head -n1)
  else
    DIG_IP=$(getent hosts "$HOSTNAME" | awk '{print $1}' || true)
  fi
  echo "DNS resolved IP: ${DIG_IP:-<none>}"
  if [ -n "$ARGOCD_IP" ] && [ -n "$DIG_IP" ]; then
    if [ "$ARGOCD_IP" = "$DIG_IP" ]; then
      echo "DNS matches loadbalancer IP: OK"
    else
      echo "Warning: DNS IP ($DIG_IP) does not match LB IP ($ARGOCD_IP)"
    fi
  fi
fi

if [ "$SKIP_GH" = false ]; then
  echo "Checking GitHub environment secrets..."
  OWNER=${TF_VAR_github_owner:-$(jq -r '.github_owner.value // empty' outputs.json || true)}
  REPO=${TF_VAR_github_repo:-$(jq -r '.github_repository.value // empty' outputs.json || true)}
  ENV_NAME=dev
  if [ -z "$OWNER" ] || [ -z "$REPO" ]; then
    echo "Owner or repo not set in env or outputs; please set TF_VAR_github_owner and TF_VAR_github_repo or check outputs.json"
  else
    echo "Querying GitHub API for environment secrets in ${OWNER}/${REPO} environment '${ENV_NAME}'"
    resp=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/${OWNER}/${REPO}/environments/${ENV_NAME}/secrets")
    if echo "$resp" | jq -e .names >/dev/null 2>&1; then
      echo "Secrets present:"
      echo "$resp" | jq -r '.names[]'
    else
      echo "Unable to list environment secrets. Response:"
      echo "$resp" | jq -C .
    fi
  fi
fi

echo "Smoke test completed. Review messages above for status."
