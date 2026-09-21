#!/bin/bash
set -e
echo "🔥 Destroying 03-argocd..."
cd infrastructure/terraform/environments/gke-dev/03-argocd
terraform destroy -auto-approve
cd ../../../../..

echo "🔥 Destroying 02-platform..."
cd infrastructure/terraform/environments/gke-dev/02-platform
terraform destroy -auto-approve
cd ../../../../..

echo "🔥 Destroying 01-infra..."
cd infrastructure/terraform/environments/gke-dev/01-infra
terraform destroy -auto-approve
cd ../../../../..

echo "✅ Environment completely destroyed and billing halted!"
