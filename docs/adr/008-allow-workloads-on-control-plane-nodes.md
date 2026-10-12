# ADR-008: Allow Workloads on Control-Plane Nodes

Status: Accepted
Date: 2026-10-11

## Decision

Workloads may be scheduled on the three control-plane nodes.

## Context

There are no worker nodes, so Phase 3 services (monitoring, ingress, storage) would otherwise have nowhere to run.

## Options Considered

- Allow scheduling (chosen)
- Keep the taint and add a worker first
- Keep the taint and add tolerations per app

## Impact

etcd shares CPU, memory, and disk I/O with workloads. Monitoring and storage can slow etcd even when CPU and memory look fine. Workloads need resource requests and limits, monitoring retention must be bounded, and the control plane keeps headroom.

A compromised workload sits closer to control-plane credentials. Three members tolerate one failure, but application availability also depends on replicas, placement, storage, and spare capacity.

## Not Doing Yet

Dedicated worker nodes are deferred.

## Review Notes

Revisit this decision when the first worker node is added.
