# Kubernetes manifests

This directory contains the Kubernetes manifests for the Fire Monitoring System using Kustomize overlays.

## Layout

- `base/` contains shared manifests for all environments.
- `overlays/dev` and `overlays/prod` apply namespace and image overrides.

## Apply (example)

```bash
kubectl apply -k infrastructure/k8s/overlays/dev
```

## Notes

- Secrets and app config are created by Terraform in each namespace.
- The `app-cd-deploy.yml` workflow updates image tags in overlays and applies them.

