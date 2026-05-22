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

## Documentation

- [Goals](docs/00-goals.md) - Project objectives and learning goals
- [Hardware Inventory](docs/01-hardware-inventory.md) - Control plane hardware specifications
- [Network Plan](docs/02-network-plan.md) - Network topology and IP addressing
- [Cluster Design](docs/03-cluster-design.md) - Architecture and scope boundaries
- [Architecture Decision Records](docs/adr/README.md) - Architectural decision records
- [Diagrams](diagrams/) - Physical and logical topology diagrams

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