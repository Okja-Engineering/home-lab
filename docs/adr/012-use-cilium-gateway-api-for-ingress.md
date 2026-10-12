# ADR-012: Use Cilium Gateway API for Ingress (Phase 3)

Status: Accepted
Date: 2026-10-11

## Decision

Phase 3 ingress uses Cilium's Gateway API implementation. LB IPAM allocates application addresses from a dedicated pool. L2 announcements, or BGP if the router supports it, advertise them.

## Context

The community ingress-nginx controller was retired in March 2026. Cilium's Gateway API requires kube-proxy replacement ([ADR-005](005-use-cilium-with-kube-proxy-replacement.md)).

## Options Considered

- Cilium Gateway API (chosen)
- A separate controller such as Traefik, plus MetalLB
- ingress-nginx

## Impact

Phase 3 needs compatible Gateway API CRDs, TLS, DNS, and an advertisement method. Application addresses stay separate from the API VIP.

## Not Doing Yet

No ingress is set up before Phase 3.

## Review Notes

Revisit this decision if L2 announcements prove unreliable.
