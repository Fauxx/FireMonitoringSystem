# Architecture Decision Records (ADR) Index

This directory captures the structural decisions and technical trade-offs made during the development of the Fire Monitoring System.

## 📜 Active Decisions

- **[ADR-0001: Adoption of GitOps](./0001-adoption-of-gitops.md)**
    - *Rationale:* Automated state reconciliation, auditability, and reliable rollbacks via ArgoCD.
- **[ADR-0002: Zero-Trust Networking](./0002-zero-trust-networking.md)**
    - *Rationale:* Implementing a "Default Deny" posture using Kubernetes NetworkPolicies to prevent lateral movement.

## 🛠️ About ADRs
Architectural Decision Records are a standard industry practice for documenting the "Why" behind technical choices, ensuring long-term maintainability and providing context for future engineering teams.
