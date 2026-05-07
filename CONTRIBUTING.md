# Contributing Guide

This repository is migrating to a clearer GitOps-oriented structure in phased PRs.

## Branch and PR rules

1. Use one focused PR per migration phase.
2. Do not mix path migration, feature code, and infra behavior changes in one PR.
3. Include a rollback note in every migration PR description.
4. Keep commits reversible and avoid force-moving unrelated files.

## Review requirements

1. Infrastructure path changes require a DevOps reviewer.
2. Workflow path-filter changes require a CI/CD reviewer.
3. Manifest path changes require a GitOps reviewer.
4. Docs/index updates require a tech-lead reviewer.

## Migration safety checklist

1. Kustomize build passes for dev and prod overlays.
2. Compose config validation passes.
3. Terraform validate passes if Terraform paths were touched.
4. No stale path references remain in edited files.

## Scope boundaries

1. Keep runtime data paths out of declarative config folders.
2. Avoid changing app logic while moving directories.
3. Keep public API behavior unchanged during structure-only phases.
