#!/usr/bin/env bash
set -euo pipefail

# Cloud-init friendly bootstrap for Ubuntu/Debian (Docker) and Fedora (Podman).
. /etc/os-release

case "${ID}" in
  fedora)
    if ! command -v podman >/dev/null 2>&1; then
      dnf -y install podman podman-compose podman-docker
    fi
    systemctl enable podman.socket
    systemctl start podman.socket
    echo "Bootstrap complete: Podman + Compose are ready."
    ;;
  ubuntu|debian)
    if ! command -v docker >/dev/null 2>&1; then
      apt-get update
      apt-get install -y ca-certificates curl gnupg
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/${ID}/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
        > /etc/apt/sources.list.d/docker.list
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    systemctl enable docker
    systemctl start docker
    echo "Bootstrap complete: Docker + Compose are ready."
    ;;
  *)
    echo "Unsupported distribution: ${ID}. Install Docker/Podman manually."
    exit 1
    ;;
esac
