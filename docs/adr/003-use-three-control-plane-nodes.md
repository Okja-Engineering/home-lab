# ADR-003: Use Three Control Plane Nodes

Status: Accepted
Date: 2026-05-22

## Decision

Use three GMKtec mini PCs as Kubernetes control plane nodes.

## Context

The lab is intended to model a more production-like highly available Kubernetes control plane.

## Options Considered

- Three control plane nodes
- Single control plane node
- Five control plane nodes

## Impact

The first infrastructure milestone focuses on cp-01, cp-02, and cp-03 before workers, storage, applications, and GitOps.

## Not Doing Yet

Worker placement, stateful/stateless workload separation, and AI/GPU workloads are deferred.

## Review Notes

Revisit this decision if hardware constraints become an issue or if the three-node setup proves too complex for the learning objectives. Consider scaling to five nodes if higher availability is needed in the future.
