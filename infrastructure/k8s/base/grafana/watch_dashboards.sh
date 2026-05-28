#!/usr/bin/env bash
set -euo pipefail

# Watch Grafana dashboard in UI and auto-export changes to local file
# Usage:
#   GRAFANA_URL=http://localhost:3000 \
#   GRAFANA_TOKEN=anonymous \
#   ./infrastructure/k8s/base/grafana/watch_dashboards.sh <uid> <local_filename>
#
# Example:
#   ./infrastructure/k8s/base/grafana/watch_dashboards.sh fire-main fire-main.json

GRAFANA_URL=${GRAFANA_URL:-http://localhost:3000}
GRAFANA_TOKEN=${GRAFANA_TOKEN:-anonymous}
UID_PARAM=${1:-fire-main}
FILE_NAME=${2:-fire-main.json}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_FILE="$SCRIPT_DIR/dashboards/$FILE_NAME"

echo -e "\033[1;34m=== Grafana Dashboard Auto-Sync Watcher ===\033[0m"
echo -e "Watching UID:  \033[1;36m$UID_PARAM\033[0m"
echo -e "Target File:   \033[1;32m$OUT_FILE\033[0m"
echo -e "Grafana URL:   \033[1;33m$GRAFANA_URL\033[0m"
echo -e "Polling every 2 seconds for changes..."
echo "Press [Ctrl+C] to stop."
echo "----------------------------------------"

last_version=0
if [ -f "$OUT_FILE" ] && [ -s "$OUT_FILE" ]; then
  last_version=$(jq -r '.version // 0' "$OUT_FILE" 2>/dev/null || echo 0)
  echo "Current local version: $last_version"
fi

while true; do
  # Fetch dashboard version from API (suppress curl errors if server is temporarily down)
  if response=$(curl -fsS -H "Authorization: Bearer $GRAFANA_TOKEN" \
                     -H "Content-Type: application/json" \
                     "$GRAFANA_URL/api/dashboards/uid/$UID_PARAM" 2>/dev/null); then
    
    api_version=$(echo "$response" | jq -r '.dashboard.version // 0' 2>/dev/null || echo 0)
    
    # Sync if API version is newer
    if [ "$api_version" -gt "$last_version" ]; then
      echo -e "\033[1;32m[Detected Change]\033[0m UI updated dashboard to version \033[1;36m$api_version\033[0m (local was $last_version)"
      echo "$response" | jq '.dashboard' > "$OUT_FILE"
      echo "Saved updated JSON to $OUT_FILE"
      last_version=$api_version
    elif [ "$api_version" -lt "$last_version" ] && [ "$last_version" -ne 0 ]; then
      # Handle case where local version is newer (e.g. manually updated or git checkout)
      current_local=$(jq -r '.version // 0' "$OUT_FILE" 2>/dev/null || echo 0)
      if [ "$current_local" -ne "$last_version" ]; then
        echo -e "\033[1;33m[Local Sync]\033[0m Local file version changed manually to $current_local."
        last_version=$current_local
      fi
    fi
  fi
  sleep 2
done
