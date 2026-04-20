#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="${TF_WORKING_DIRECTORY:-$SCRIPT_DIR}"
ENV_FILE="${TF_LOCAL_BACKEND_ENV_FILE:-$SCRIPT_DIR/backend.local.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing local backend env file: ${ENV_FILE}"
  echo "Create it from: ${SCRIPT_DIR}/backend.local.env.example"
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

TF_WORKSPACE="${TF_WORKSPACE:-local}"
TF_STATE_KEY_PREFIX="${TF_STATE_KEY_PREFIX:-terraform/fire-monitoring}"
TF_BACKEND_KEY="${TF_BACKEND_KEY:-${TF_STATE_KEY_PREFIX}/${TF_WORKSPACE}.tfstate}"
TF_INIT_MODE="${TF_INIT_MODE:-bootstrap}"

required_vars=(
  TF_STATE_BUCKET
  TF_STATE_REGION
  TF_STATE_ENDPOINT
  TF_STATE_ACCESS_KEY
  TF_STATE_SECRET_KEY
)

missing=()
for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    missing+=("${var_name}")
  fi
done

if [[ "${#missing[@]}" -gt 0 ]]; then
  printf 'Missing required backend setting(s): %s\n' "${missing[*]}"
  echo "Fill ${ENV_FILE} and rerun."
  exit 1
fi

cd "${WORKING_DIR}"

case "${TF_INIT_MODE}" in
  bootstrap)
    terraform init -reconfigure -input=false \
      -backend-config="bucket=${TF_STATE_BUCKET}" \
      -backend-config="key=${TF_BACKEND_KEY}" \
      -backend-config="region=${TF_STATE_REGION}" \
      -backend-config="endpoint=${TF_STATE_ENDPOINT}" \
      -backend-config="access_key=${TF_STATE_ACCESS_KEY}" \
      -backend-config="secret_key=${TF_STATE_SECRET_KEY}" \
      -backend-config="skip_credentials_validation=true" \
      -backend-config="skip_metadata_api_check=true" \
      -backend-config="skip_region_validation=true" \
      -backend-config="skip_requesting_account_id=true" \
      -backend-config="use_path_style=true"

    terraform workspace select "${TF_WORKSPACE}" || terraform workspace new "${TF_WORKSPACE}"
    echo "Terraform backend initialized (bootstrap mode) and workspace ready: ${TF_WORKSPACE}"
    ;;
  migrate)
    terraform init -input=false
    terraform workspace select "${TF_WORKSPACE}" || {
      echo "Workspace '${TF_WORKSPACE}' does not exist in current backend; use TF_INIT_MODE=bootstrap for new workspaces."
      exit 1
    }

    terraform init -migrate-state -force-copy -input=false \
      -backend-config="bucket=${TF_STATE_BUCKET}" \
      -backend-config="key=${TF_BACKEND_KEY}" \
      -backend-config="region=${TF_STATE_REGION}" \
      -backend-config="endpoint=${TF_STATE_ENDPOINT}" \
      -backend-config="access_key=${TF_STATE_ACCESS_KEY}" \
      -backend-config="secret_key=${TF_STATE_SECRET_KEY}" \
      -backend-config="skip_credentials_validation=true" \
      -backend-config="skip_metadata_api_check=true" \
      -backend-config="skip_region_validation=true" \
      -backend-config="skip_requesting_account_id=true" \
      -backend-config="use_path_style=true"

    terraform workspace select "${TF_WORKSPACE}"
    echo "Terraform backend initialized (migrate mode) and state copied for workspace: ${TF_WORKSPACE}"
    ;;
  *)
    echo "Invalid TF_INIT_MODE='${TF_INIT_MODE}'. Supported values: bootstrap, migrate."
    exit 1
    ;;
esac
