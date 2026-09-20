#!/bin/bash
# Remove db/ and postgres-health.json from base
sed -i '/db\/statefulset.yaml/d' infrastructure/k8s/base/kustomization.yaml
sed -i '/db\/service.yaml/d' infrastructure/k8s/base/kustomization.yaml
sed -i '/db\/configmap.yaml/d' infrastructure/k8s/base/kustomization.yaml
sed -i '/db\/exporter.yaml/d' infrastructure/k8s/base/kustomization.yaml
sed -i '/postgres-health.json/d' infrastructure/k8s/base/kustomization.yaml

# Remove db patch from dev overlay
awk '
/target:/ { 
    if (in_db_patch) { in_db_patch = 0 }
}
/name: db/ && /kind: StatefulSet/ {
    in_db_patch = 1
    # We need to remove the previous "- target:" line as well.
    # Since we cannot easily look back, we will use sed below for the exact block.
}
!in_db_patch { print }
' infrastructure/k8s/overlays/dev/kustomization.yaml > tmp.yaml
