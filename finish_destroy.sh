#!/bin/bash
echo "Waiting for gcloud to finish..."
# We will just run terraform destroy again.
# First, remove the cluster from terraform state since gcloud is deleting it.
cd infrastructure/terraform/environments/gke-dev/01-infra
terraform state rm module.cluster.google_container_cluster.main || true
terraform destroy -auto-approve
