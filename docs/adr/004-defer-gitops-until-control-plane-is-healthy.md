# ADR-004: Defer GitOps Until Control Plane is Healthy

Status: Accepted
Date: 2026-05-22

## Decision

Defer Flux/GitOps installation until the Kubernetes control plane is healthy and stable.

## Context

GitOps is a major goal for this lab, but adding Flux before the base cluster is working would make troubleshooting harder. If the control plane has issues, introducing GitOps automation would add another layer of complexity to debug. It's better to establish a working control plane first, validate basic operations, then layer on GitOps.

The lab can document GitOps plans now, but Flux manifests should wait until kubectl access and node health are validated. This approach follows the principle of validating each layer before adding the next.

## Options Considered

- **Defer GitOps until control plane is healthy:** Validate cluster first, then add Flux
- **Install GitOps from the start:** Bootstrap Flux alongside Talos/Kubernetes
- **Use GitOps for everything including bootstrap:** Use Flux to manage Talos configs from day one

## Impact

The repo can document GitOps plans now, but Flux manifests should wait until kubectl access and node health are validated. The initial milestone focuses on manual control plane bootstrap and validation. GitOps will be introduced as a later phase after the cluster is stable.

## Not Doing Yet

No Flux bootstrap, HelmRelease structure, or application deployment manifests yet. The lab will not install Flux or any GitOps tooling until the control plane is healthy and basic Kubernetes operations are validated.

## Review Notes

Revisit this decision after the control plane is stable and kubectl access is working. Consider implementing GitOps when adding platform services or when the cluster needs to manage more complex configurations.
