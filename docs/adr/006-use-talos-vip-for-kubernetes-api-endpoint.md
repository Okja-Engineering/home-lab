# ADR-006: Use a Talos Shared VIP for the Kubernetes API Endpoint

Status: Accepted
Date: 2026-10-11

## Decision

The cluster endpoint is `https://192.168.1.20:6443`. That address is a Talos Layer 2 shared VIP held by one healthy control-plane node. `talosctl` endpoints are the individual node IPs, never the VIP.

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
