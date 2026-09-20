#!/bin/bash
sed -i 's/- behavior: replace/- name: fire-monitoring-config/g' infrastructure/k8s/overlays/prod/kustomization.yaml
sed -i '/name: fire-monitoring-config/d' infrastructure/k8s/overlays/prod/kustomization.yaml
sed -i 's/- behavior: replace/- name: fire-monitoring-config/g' infrastructure/k8s/overlays/prod/kustomization.yaml

awk '
/target:/ { 
    if (in_db_patch) { in_db_patch = 0 }
}
/name: db/ && /kind: StatefulSet/ {
    in_db_patch = 1
}
!in_db_patch { print }
' infrastructure/k8s/overlays/prod/kustomization.yaml > tmp.yaml
# We actually just want to manually edit prod and local.
