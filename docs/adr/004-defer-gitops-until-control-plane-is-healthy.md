# ADR-004: Defer GitOps Until Control Plane is Healthy

Status: Accepted
Date: 2026-05-22

## Decision

Defer Flux/GitOps installation until the Kubernetes control plane is healthy.

## Context

GitOps is a major goal, but adding Flux before the base cluster is working would make troubleshooting harder.

## Options Considered

- Defer GitOps until control plane is healthy
- Install GitOps from the start
- Use GitOps for everything including bootstrap

## Impact

The repo can document GitOps plans now, but Flux manifests should wait until kubectl access, node health, and etcd health are validated.

## Not Doing Yet

No Flux bootstrap, HelmRelease structure, or application deployment manifests yet.

## Review Notes

Revisit this decision after the control plane is stable and kubectl access is working. Consider implementing GitOps when adding platform services or when the cluster needs to manage more complex configurations.
