#!/usr/bin/env bash
set -euo pipefail

# Export Grafana dashboards by UID into the versioned dashboards directory.
# Usage:
#   GRAFANA_URL=http://localhost:3000 \
#   GRAFANA_TOKEN=eyJ... \
#   ./infrastructure/grafana/export_dashboards.sh <uid1> <uid2> ...
#
# GRAFANA_TOKEN: API token with "Admin" or "Editor" role.
# GRAFANA_URL:   Grafana base URL (default http://localhost:3000).
# Output files are written to infrastructure/grafana/dashboards/<uid>.json

GRAFANA_URL=${GRAFANA_URL:-http://localhost:3000}
GRAFANA_TOKEN=${GRAFANA_TOKEN:-}
OUT_DIR="$(dirname "$0")/dashboards"

if [ -z "$GRAFANA_TOKEN" ]; then
  echo "GRAFANA_TOKEN is required" >&2
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "Provide at least one dashboard UID" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

for uid in "$@"; do
  echo "Exporting dashboard UID: $uid"
  curl -fsS -H "Authorization: Bearer $GRAFANA_TOKEN" \
       -H "Content-Type: application/json" \
       "$GRAFANA_URL/api/dashboards/uid/$uid" \
       > "$OUT_DIR/$uid.json"
  echo "Saved to $OUT_DIR/$uid.json"
done

echo "Done. Commit the updated JSON files to version dashboards."

