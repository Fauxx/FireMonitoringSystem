#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required."
  exit 1
fi

OWNER="${1:-}"
REPO="${2:-}"

if [[ -z "${OWNER}" || -z "${REPO}" ]]; then
  echo "Usage: $0 <owner> <repo>"
  echo "Example: $0 my-org FireMonitoringSystem"
  exit 1
fi

# Purge container package versions for expected services.
for pkg in api etl-processor dashboard; do
  echo "Deleting GHCR versions for ${OWNER}/${pkg}..."
  version_ids=$(gh api --paginate \
    "/users/${OWNER}/packages/container/${pkg}/versions" \
    --jq '.[].id' 2>/dev/null || true)

  if [[ -z "${version_ids}" ]]; then
    version_ids=$(gh api --paginate \
      "/orgs/${OWNER}/packages/container/${pkg}/versions" \
      --jq '.[].id' 2>/dev/null || true)
  fi

  if [[ -z "${version_ids}" ]]; then
    echo "No versions found for package ${pkg}."
    continue
  fi

  while read -r version_id; do
    [[ -z "${version_id}" ]] && continue
    gh api -X DELETE "/users/${OWNER}/packages/container/${pkg}/versions/${version_id}" >/dev/null 2>&1 || \
    gh api -X DELETE "/orgs/${OWNER}/packages/container/${pkg}/versions/${version_id}" >/dev/null 2>&1 || true
    echo "Deleted version ${version_id} from ${pkg}."
  done <<< "${version_ids}"
done

# Purge Actions caches for the repo.
echo "Deleting GitHub Actions caches for ${OWNER}/${REPO}..."
cache_ids=$(gh api --paginate \
  "/repos/${OWNER}/${REPO}/actions/caches" \
  --jq '.actions_caches[].id' 2>/dev/null || true)

while read -r cache_id; do
  [[ -z "${cache_id}" ]] && continue
  gh api -X DELETE "/repos/${OWNER}/${REPO}/actions/caches/${cache_id}" >/dev/null 2>&1 || true
  echo "Deleted cache ${cache_id}."
done <<< "${cache_ids}"

echo "GHCR + Actions cache clean slate completed."

