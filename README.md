# Home Lab

[![Validate](https://github.com/Okja-Engineering/home-lab/actions/workflows/validate.yml/badge.svg?branch=main&event=push)](https://github.com/Okja-Engineering/home-lab/actions/workflows/validate.yml)

A GitHub-backed home lab repository that documents and eventually automates a local Kubernetes platform for learning and portfolio development.

## Purpose

This repository serves two goals:

1. **Operational home lab** - A functional Kubernetes platform for self-hosted services
2. **DevOps/platform engineering portfolio** - A documented learning journey showcasing infrastructure-as-code, GitOps, and platform engineering practices

## Current Status

**Phase 2: Three-Node Control Plane** (the phases are defined in [Goals](docs/00-goals.md#phases))

Phase 1 is done: Milestone 1 (Talos Control Plane Foundation) is complete. The repo has planning docs, ADRs, diagrams, network plan, Talos source structure, and bootstrap runbooks.

The current work in Phase 2 is cp-01 Talos discovery:
- Physically boot cp-01 into Talos maintenance mode
- Confirm hardware and network facts
- Identify network interface and install disk
- Update metadata with confirmed values

**Stop point:** Do not generate Talos secrets or machine configs until discovery is complete.

## Target Architecture

- **OS:** Talos Linux (immutable, minimal, Kubernetes-focused)
- **Orchestration:** Kubernetes
- **Control Plane:** 3x GMKtec mini PCs (cp-01, cp-02, cp-03)
- **Network:** Flat network initially, VLANs deferred
- **GitOps:** Flux (planned, after cluster is healthy)
- **CNI:** Cilium with kube-proxy replacement, to be installed as part of bootstrap ([ADR-005](docs/adr/005-use-cilium-with-kube-proxy-replacement.md))
- **Ingress:** Cilium Gateway API, planned for Phase 3 ([ADR-012](docs/adr/012-use-cilium-gateway-api-for-ingress.md))
- **Storage:** TBD (planned)
- **Monitoring:** TBD (planned)

## What's Deferred

The following are intentionally deferred until after the control plane is healthy and stable:

- **Worker nodes** - No worker nodes in Phase 2
- **Flux/GitOps** - Deferred until control plane is healthy
- **Ingress controller** - Planned but not yet implemented
- **Storage classes** - Planned but not yet implemented
- **Monitoring/observability** - Planned but not yet implemented
- **VLANs** - Starting with flat network, VLANs deferred
- **Switch configuration** - Not required for initial Talos bootstrap

## Documentation

- [Goals](docs/00-goals.md) - Project objectives and learning goals
- [Hardware Inventory](docs/01-hardware-inventory.md) - Control plane hardware specifications
- [Network Plan](docs/02-network-plan.md) - Network topology and IP addressing
- [Cluster Design](docs/03-cluster-design.md) - Architecture and scope boundaries
- [Architecture Decision Records](docs/adr/README.md) - Architectural decision records
- [Diagrams](diagrams/) - Physical and logical topology diagrams
  - [Physical Topology](diagrams/physical-topology.md) - Hardware layout and network connections
  - [Logical Cluster Topology](diagrams/logical-cluster-topology.md) - Kubernetes control plane architecture

## Talos Configuration

Talos Linux configuration is located in `platform/talos/`. This includes:

- Cluster metadata and patches
- Security documentation

See [platform/talos/README.md](platform/talos/README.md) for details.

The bootstrap runbooks are in [docs/runbooks/](docs/runbooks/). They have not been updated for ADR-005 to ADR-013 yet: where a runbook disagrees with an [ADR](docs/adr/README.md), the ADR is current. [Issue 22](https://github.com/Okja-Engineering/home-lab/issues/22) rewrites them.

## Security

This repository follows strict security practices:

- **Never commit:** secrets, kubeconfigs, talosconfig, private keys, or generated configs
- **Always commit:** documentation, metadata, patches, and source configuration
- Root `.gitignore` protects sensitive file patterns

See [platform/talos/README.md](platform/talos/README.md) for detailed security policies.

## GitHub Workflow

The GitHub milestone and issues for this project were created using local bootstrap artifacts (`.github/milestones/`, `.github/issues/`, and `scripts/github/create-control-plane-foundation-issues.sh`). These files were used as temporary inputs to create the actual GitHub resources via the `gh` CLI and are not tracked in the repository.

## License

MIT License - Copyright (c) 2026 Okja-Engineering