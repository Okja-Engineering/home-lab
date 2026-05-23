# Home Lab

A GitHub-backed home lab repository that documents and eventually automates a local Kubernetes platform for learning and portfolio development.

## Purpose

This repository serves two goals:

1. **Operational home lab** - A functional Kubernetes platform for self-hosted services
2. **DevOps/platform engineering portfolio** - A documented learning journey showcasing infrastructure-as-code, GitOps, and platform engineering practices

## Current Status

**Phase: Documentation and Planning**

The repository is currently in the documentation and planning phase. No cluster is running yet. The focus is on:

- Establishing repository safety and structure
- Documenting hardware, network, and cluster design
- Preparing Talos configuration structure
- Creating runbooks for control plane bootstrap

## Current Milestone

**Milestone 1: Talos Control Plane Foundation**

The current milestone focuses on safely documenting and preparing the repo for bootstrapping a 3-node Talos Linux Kubernetes control plane on GMKtec mini PCs.

This milestone includes:
- Repository safety baseline (.gitignore, security documentation)
- Hardware inventory and network planning
- Cluster design and architecture decisions
- Talos configuration structure and bootstrap runbooks
- Topology diagrams

This milestone is focused on repository preparation, documentation, and runbooks. Actual Talos installation, generated configs, and application deployment are deferred until the repo plan is reviewed and the hardware/network assumptions are confirmed.

## Target Architecture

- **OS:** Talos Linux (immutable, minimal, Kubernetes-focused)
- **Orchestration:** Kubernetes
- **Control Plane:** 3x GMKtec mini PCs (cp-01, cp-02, cp-03)
- **Network:** Flat network initially, VLANs deferred
- **GitOps:** Flux (planned, after cluster is healthy)
- **CNI:** Cilium (planned)
- **Ingress:** TBD (planned)
- **Storage:** TBD (planned)
- **Monitoring:** TBD (planned)

## What's Deferred

The following are intentionally deferred until after the control plane is healthy and stable:

- **Worker nodes** - No worker nodes in initial milestone
- **Flux/GitOps** - Deferred until control plane is healthy
- **Cilium CNI** - Planned but not yet implemented
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
- Bootstrap runbooks
- Security documentation

See [platform/talos/README.md](platform/talos/README.md) for details.

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