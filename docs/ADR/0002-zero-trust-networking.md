# ADR 0002: Zero-Trust Networking Architecture

## Status
Accepted

## Context
The system processes critical IoT fire safety data. A security breach in one component (e.g., the public-facing Dashboard) should not grant lateral access to core data layers (PostgreSQL, InfluxDB) or the messaging broker (MQTT).

## Decision
We will implement a **Zero-Trust Architecture** at the networking layer using Kubernetes **NetworkPolicies**.

## Consequences
- **Default Deny:** All ingress and egress traffic is denied by default within the application namespaces.
- **Explicit Allow-Listing:** Traffic is only permitted between specific services that have a documented dependency (e.g., `api` -> `postgresql`).
- **Isolation:** The `dashboard` (public) is logically and network-isolated from the `mqtt` broker (edge ingestion).
- **Reduced Attack Surface:** Even if a container is compromised, the attacker is restricted by kernel-level firewall rules from scanning or attacking other cluster resources.
