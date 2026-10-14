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

Talos discovery is done on all three control-plane machines. The network interface, install disk and CPU it confirmed are recorded in [`platform/talos/clusters/home-prod/metadata.env`](platform/talos/clusters/home-prod/metadata.env). The current work in Phase 2 is Milestone 2 (Ready to install cp-01), tracked in [issue 14](https://github.com/Okja-Engineering/home-lab/issues/14).

**Stop point:** Do not generate the cluster's real Talos secrets until [issue 18](https://github.com/Okja-Engineering/home-lab/issues/18) is closed, and then only once, as [issue 19](https://github.com/Okja-Engineering/home-lab/issues/19) describes. Do not generate machine configs from them until [issue 20](https://github.com/Okja-Engineering/home-lab/issues/20) is closed.

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

The bootstrap runbooks are in [docs/runbooks/](docs/runbooks/). They have not been updated for ADR-005 to ADR-013 yet: where a runbook disagrees with an [ADR](docs/adr/README.md), the ADR is current. [Issue 22](https://github.com/Okja-Engineering/home-lab/issues/22) will rewrite them.

## Security

This repository follows strict security practices:

- **Never commit:** secrets, kubeconfigs, talosconfig, private keys, or generated configs
- **Always commit:** documentation, metadata, patches, and source configuration
- Root `.gitignore` protects sensitive file patterns

See [platform/talos/README.md](platform/talos/README.md) for detailed security policies.

### Secret scanning

[gitleaks](https://github.com/gitleaks/gitleaks) checks the text changes that get past `.gitignore`. `scripts/secret-scan.sh` runs it with two rule sets:

- `.gitleaks-talos.toml` holds the rules for what `talosctl` and `kubectl` write: base64-encoded PEM blocks, PEM private keys, bootstrap and trustd tokens, a 32-byte base64 secret (such as the cluster secret) as the value of a field, and files named `secrets.yaml`, `controlplane.yaml`, `worker.yaml`, `talosconfig` or `kubeconfig`. These rules have no allowlist: they apply to every path, the rules file included.
- `.gitleaks.toml` holds gitleaks' default rules. They come with gitleaks' default allowlist, which exempts some paths from them, such as the common lock files and `node_modules/`.

The scan runs in two places:

- **Before each commit:** a pre-commit hook scans the staged changes. Set it up once per clone: install [pre-commit](https://pre-commit.com/#install), then run `pre-commit install` in the repository root.
- **On every pull request and on pushes to `main`:** the `Secret scan` workflow (`.github/workflows/secret-scan.yml`) scans the commit history, including what a merge commit adds.

gitleaks scans only the lines that a text diff adds. It does not scan binary files and does not look inside archives, so an etcd snapshot is protected by the `*.snapshot` rule in `.gitignore` alone.

This repository is public. If the workflow's scan fails on a real secret, that secret is already published: treat it as compromised and regenerate it. Deleting the commit is not enough.

## GitHub Workflow

GitHub Milestone 1 (Talos Control Plane Foundation) and its issues were created using local bootstrap artifacts (`.github/milestones/`, `.github/issues/`, and `scripts/github/create-control-plane-foundation-issues.sh`). These files were used as temporary inputs to create the actual GitHub resources via the `gh` CLI and are not tracked in the repository.

## License

MIT License - Copyright (c) 2026 Okja-Engineering