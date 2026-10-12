# ADR-005: Use Cilium with kube-proxy Replacement from Bootstrap

Status: Accepted
Date: 2026-10-11

## Decision

Cilium is the CNI from the first boot, with kube-proxy replacement enabled. Talos's default CNI (Flannel) and kube-proxy are disabled in the machine config, and Cilium is installed as part of bootstrap.

## Context

Talos installs Flannel and kube-proxy by default when the config is generated. Switching CNI later is possible, but it is a potentially disruptive migration. Cilium's Gateway API ([ADR-012](012-use-cilium-gateway-api-for-ingress.md)) and L2 announcements require kube-proxy replacement.

## Options Considered

- Talos default (Flannel + kube-proxy)
- Cilium with kube-proxy replacement (chosen)
- Cilium keeping kube-proxy

## Impact

Nodes report `NotReady` until Cilium is running, which is expected. Cilium needs Talos-specific Helm values: the API server reached through KubePrism at `localhost:7445`, Talos cgroup settings, and no `SYS_MODULE` capability.

## Not Doing Yet

Gateway API, L2 announcements, and Hubble UI are deferred.

## Review Notes

Revisit this decision if Cilium blocks a Talos upgrade or a needed feature.
