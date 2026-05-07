# Support and Ownership

Use this matrix for triage and escalation.

## Contact matrix

1. Platform/GitOps: Argo CD sync, Kustomize paths, cluster manifests.
2. Terraform/IaC: state backend, provider config, infra provisioning.
3. API service: backend routes, auth/session, DB integration.
4. Dashboard service: frontend pages, static assets, API consumption.
5. ETL service: Influx->PostgreSQL sync and aggregation pipelines.
6. CI/CD: GitHub Actions failures, path-trigger behavior, release gates.

## Incident routing

1. Open an issue with label `incident` and include failing file paths.
2. If deployment is blocked, include workflow run URL and failing job.
3. If GitOps is out of sync, include Application health/sync status.

## Escalation

1. P1 production outage: notify platform and service owner immediately.
2. P2 degraded feature: assign to owning team and notify DevOps.
3. P3 docs/tooling issue: assign to tech leads.
