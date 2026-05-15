#!/usr/bin/env bash
# Simple helper to init/validate/plan the dev 02-platform layer. Edit vars before running.
set -euo pipefail

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
  echo "Please export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (DigitalOcean Spaces keys)"
  exit 1
fi

HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"
export AWS_EC2_METADATA_DISABLED=true

terraform init -reconfigure \
  -backend-config=../../../backend-common.conf \
  -backend-config=backend.conf
terraform validate

echo "Running terraform plan (provide DO and GH token via -var or env)..."
terraform plan \
  -var="do_token=${DO_TOKEN:-}" \
  -var="github_token=${GITHUB_TOKEN:-}" \
  -var="remote_state_bucket=${REMOTE_STATE_BUCKET:-}" \
  -var="infra_state_key=${INFRA_STATE_KEY:-dev/01-infra/terraform.tfstate}" \
  -var="remote_state_endpoint=${REMOTE_STATE_ENDPOINT:-sgp1.digitaloceanspaces.com}" \
  -var="remote_state_region=${REMOTE_STATE_REGION:-us-east-1}" \
  -var="argocd_auth_token=${ARGOCD_AUTH_TOKEN:-}"
