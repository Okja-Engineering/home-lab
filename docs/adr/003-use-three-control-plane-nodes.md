# ADR-003: Use Three Control Plane Nodes

Status: Accepted
Date: 2026-05-22

## Decision

Use three GMKtec mini PCs as Kubernetes control plane nodes.

## Context

The lab is intended to model a more production-like highly available control plane. A single-node control plane would be simpler but would not provide etcd quorum or high availability. Three nodes is the minimum for a production-like Kubernetes control plane with etcd quorum.

The lab has three GMKtec mini PCs available for this purpose. Using all three as control plane nodes provides a realistic HA setup while keeping the hardware footprint manageable for a home environment.

## Options Considered

- **Three control plane nodes:** Provides etcd quorum, tolerates single node failure, production-like HA
- **Single control plane node:** Simpler, but no HA, no etcd quorum, single point of failure
- **Five control plane nodes:** More resilient, but requires more hardware and complexity

## Impact

The first infrastructure milestone focuses on cp-01, cp-02, and cp-03 before workers and applications. The cluster will have etcd quorum and can tolerate a single control plane node failure. All three nodes will run Talos Linux and participate in the Kubernetes control plane.

## Not Doing Yet

Worker placement, stateful/stateless workload separation, and AI/GPU workloads are deferred. The lab will not add worker nodes until the control plane is stable and healthy.

## Review Notes

Revisit this decision if hardware constraints become an issue or if the three-node setup proves too complex for the learning objectives. Consider scaling to five nodes if higher availability is needed in the future.
