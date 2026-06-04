# ADR 0001: Adoption of GitOps for Automated State Reconciliation

## Status
Accepted

## Context
The Fire Monitoring System requires a reliable, auditable, and automated deployment process. Traditional CI/CD "push" models often lead to "configuration drift," where the actual state of the cluster diverges from the version-controlled manifests. Additionally, manual deployments introduce human error and make rollbacks complex.

## Decision
We will adopt a **GitOps** model using **ArgoCD** as the continuous delivery engine.

## Consequences
- **Single Source of Truth:** Git becomes the only source of truth for both infrastructure and application state.
- **Automated Reconciliation:** Any manual changes made to the cluster (drift) will be automatically overwritten by ArgoCD to match the Git state.
- **Improved Security:** The CI/CD pipeline no longer needs `cluster-admin` access to "push" changes; instead, a pull-based agent (ArgoCD) manages internal reconciliation.
- **Atomic Rollbacks:** Reverting a deployment is as simple as a `git revert`, providing instant and reliable recovery paths.
