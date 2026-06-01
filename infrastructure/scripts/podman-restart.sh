#!/bin/bash
# Restart Podman service with proper initialization time

echo "🔄 Restarting Podman service..."
systemctl --user restart podman.service

echo "⏳ Waiting for Podman to initialize (5s)..."
sleep 5

echo "✅ Checking container status..."
podman compose ps
