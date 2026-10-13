# ADR-006: Use a Talos Shared VIP for the Kubernetes API Endpoint

Status: Accepted
Date: 2026-10-11

## Decision

The cluster endpoint is `https://10.0.0.20:6443`. That address is a Talos Layer 2 shared VIP held by one healthy control-plane node. `talosctl` endpoints are the individual node IPs, never the VIP.

## Context

The original plan pointed `k8s.lab.home.arpa` at cp-01 only, so losing cp-01 would cut off API access even with two healthy nodes. The endpoint is baked into every machine config, kubeconfig, and the API server certificate.

## Options Considered

- DNS record to cp-01
- Talos VIP (chosen)
- External HAProxy/keepalived
- DNS round-robin

## Impact

The VIP needs an unused address outside DHCP on the nodes' shared Layer 2 subnet. It only works once etcd has quorum. After an unexpected node failure, failover typically takes about a minute; that is not a guaranteed maximum. `k8s.lab.home.arpa` may be added as an extra API server certificate name.

## Not Doing Yet

An external load balancer is deferred.

## Review Notes

Revisit this decision if failover time becomes a problem.

## Clarifying Note

Added 2026-10-13. The accepted text above is unchanged except for the address under Decision, which was re-based on this date.

The endpoint under Decision was `https://192.168.1.20:6443`. The router check for [issue 16](https://github.com/Okja-Engineering/home-lab/issues/16) found that the home network is 10.0.0.0/24, not 192.168.1.0/24, so the planned VIP moved to the same host number on that subnet. [ADR-014](014-rebase-address-plan-onto-10-0-0-0-24.md) records the decision, and its Impact section says how far the new address has been checked.
