# ADR-016: Use IPv4-Only Pod and Service Networking Initially

Status: Accepted
Date: 2026-10-14

## Decision

The owner decided on 2026-10-14: "IPv4-only pod and Service networking initially, with future public IPv6 handled at a proxy/gateway in front of the private cluster." This closes the dual-stack question for this bootstrap. Host IPv6 remains a separate addressing and access-control concern.

## Context

- Public access, planned for Phase 7, is to serve IPv4 and IPv6 ([Architecture Vision](../04-architecture-vision.md#intended-services-by-layer)).
- The cluster configuration that [issue 20](https://github.com/Okja-Engineering/home-lab/issues/20) and [issue 21](https://github.com/Okja-Engineering/home-lab/issues/21) generate sets the pod and Service networks, so the question needed an answer first.

## Options Considered

- Dual-stack pod and Service networking from the start
- IPv4-only pod and Service networking, with public IPv6 handled at a proxy or gateway in front of the cluster (chosen)

## Impact

- Issues 20 and 21 generate IPv4-only pod and Service networks and record this decision.
- Which proxy or gateway serves public IPv6 in Phase 7 is an [open decision](README.md#open-decisions). The nodes keep host IPv6 for now, and the access policy is to cover every enabled scope (the owner, 2026-10-14; [access and exposure invariant 2](../05-workload-placement.md#access-and-exposure-invariants)).

## Not Doing Yet

Dual-stack pod and Service networking, and the choice of the proxy or gateway that serves public IPv6.

## Review Notes

Revisit if a workload needs IPv6 inside the cluster, or at Phase 7 if public IPv6 cannot be served well from in front of the cluster.
