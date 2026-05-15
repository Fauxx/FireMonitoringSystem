#!/usr/bin/env bash
# Mint a GitHub App installation access token using JWT
# Environment variables required:
#   APP_ID - GitHub App ID
#   INSTALLATION_ID - GitHub App installation ID for target repo/org
#   APP_KEY_B64 - base64-encoded PEM private key

set -euo pipefail

if [ -z "${APP_ID:-}" ] || [ -z "${INSTALLATION_ID:-}" ] || [ -z "${APP_KEY_B64:-}" ]; then
  echo "Error: APP_ID, INSTALLATION_ID, and APP_KEY_B64 are required" >&2
  exit 1
fi

# Decode the private key
PRIVATE_KEY=$(echo "$APP_KEY_B64" | base64 -d)

# Create JWT payload
NOW=$(date +%s)
EXP=$((NOW + 600))  # 10 minutes expiration

PAYLOAD=$(cat <<EOF
{
  "iat": $NOW,
  "exp": $EXP,
  "iss": "$APP_ID"
}
EOF
)

# Sign JWT with private key
JWT=$(echo -n "$PAYLOAD" | \
  openssl dgst -sha256 -sign <(echo -n "$PRIVATE_KEY") | \
  openssl base64 -A | \
  tr '+/' '-_' | tr -d '=')

HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | \
  openssl base64 -A | \
  tr '+/' '-_' | tr -d '=')

APP_JWT="${HEADER}.$(echo -n "$PAYLOAD" | openssl base64 -A | tr '+/' '-_' | tr -d '=').${JWT}"

# Mint installation token
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $APP_JWT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens")

# Extract token
INSTALLATION_TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$INSTALLATION_TOKEN" ]; then
  echo "Failed to mint installation token. Response: $RESPONSE" >&2
  exit 1
fi

# Output token to GitHub Actions env file
echo "installation_token=${INSTALLATION_TOKEN}" >> "$GITHUB_OUTPUT"
echo "Installation token minted successfully"
