# Goals

## Project Objectives

This home lab project aims to build a functional Kubernetes platform that serves both operational needs and professional development goals.

### Operational Goals

- Provide a reliable platform for self-hosted services: each service meets the recovery bar (the minimum standard) of its class, learning or reliance ([Recovery Expectations](06-recovery-expectations.md#two-bars))
- Learn and practice infrastructure-as-code principles
- Gain hands-on experience with modern Kubernetes operations
- Build a foundation for future platform services
- Eventually, give selected people authenticated access to the lab's compute (Phase 7)

### Portfolio Goals

- Demonstrate DevOps and platform engineering skills
- Document a complete platform engineering journey
- Showcase GitOps and automation practices
- Create a reference architecture for future projects

## Learning Goals

### Primary Focus Areas

1. **Talos Linux** - Understand immutable OS design and cluster bootstrap
2. **Kubernetes Operations** - Master control plane management and troubleshooting
3. **GitOps** - Implement Flux for declarative cluster management
4. **Security** - Practice secret management and secure configuration
5. **Networking** - Learn CNI, ingress, and network policy concepts
6. **Storage** - Understand persistent storage and CSI drivers
7. **Observability** - Implement monitoring, logging, and alerting
8. **Local inference** - Serve models with vLLM on the GX10 and combine them with frontier models, for learning and testing

### Secondary Focus Areas

- Infrastructure as code patterns
- Documentation and runbook practices
- Disaster recovery and backup strategies
- Multi-node cluster operations

## Phases

The project is built in seven phases. They are defined here and nowhere else; other documents refer to them by number. Each phase lists its success criteria. The owner set the order of Phases 3 to 6 on 2026-10-14; Phase 7's position is proposed ([Phase 7](#phase-7-controlled-public-access)). How the later phases are built is mostly still open: the [Architecture Vision](04-architecture-vision.md) says what is decided, and the [open decisions](adr/README.md#open-decisions) list what is not.

"Milestone" is the GitHub term and is numbered separately. "Milestone 1" always means the GitHub milestone "Milestone 1: Talos Control Plane Foundation", which tracked Phase 1: the planning foundation, not a running cluster. A later milestone can cover only part of a phase, so milestone numbers do not match phase numbers; the [milestone list](https://github.com/Okja-Engineering/home-lab/milestones) on GitHub shows them. The table below maps them; Milestones 4 to 9 are proposed titles, and GitHub is the record of which exist.

| Phase | GitHub milestones |
|---|---|
| 1. Repository Foundation | Milestone 1: Talos Control Plane Foundation |
| 2. Three-Node Control Plane | Milestone 2: Ready to install cp-01, then Milestone 3: Three-node control plane |
| 3. Workers and Recoverable Platform Services | Milestone 4: Stateful and stateless workers, then Milestone 5: Recoverable platform services |
| 4. GitOps and Internal Source Control | Milestone 6: GitOps and internal source control |
| 5. Local Inference Experiments | Milestone 7: Local inference experiments |
| 6. Combined Local and Frontier Workflows | Milestone 8: Combined local and frontier workflows |
| 7. Controlled Public Access | Milestone 9: Controlled public access |

### Phase 1: Repository Foundation

- Repository is safe from accidental secret commits
- Hardware, network, and cluster design are documented
- Talos configuration structure is clear
- Runbooks exist for control plane bootstrap
- Topology is visualized

This phase is complete. It was tracked in the GitHub milestone "Milestone 1: Talos Control Plane Foundation" with 12 planning issues.

### Phase 2: Three-Node Control Plane

- All 3 control plane nodes are running Talos
- Cilium is installed as the CNI during bootstrap ([ADR-005](adr/005-use-cilium-with-kube-proxy-replacement.md))
- Kubernetes cluster is healthy
- etcd quorum is stable
- kubectl access is working from workstation
- An etcd and disk-latency baseline is recorded during the control plane's validation ([issue 26](https://github.com/Okja-Engineering/home-lab/issues/26)), before substantial workloads

### Phase 3: Workers and Recoverable Platform Services

Phase 3 adds the workers first (Milestone 4) and then the recoverable platform services (Milestone 5).

Workers, first ([Workload Placement](05-workload-placement.md)):

- Each candidate machine and the storage of about 8 TB have a recorded, non-destructive inventory, and each worker role has written workload requirements
- Each worker is installed only after the owner's go to erase that machine, recorded with a date ([no-erase rule](05-workload-placement.md#pre-placement-inventory))
- The stateful and the stateless/platform roles each have at least one Ready worker, labelled with its role, placed by a recorded decision that rests on those records, and the [access and exposure invariants](05-workload-placement.md#access-and-exposure-invariants) hold for it

Recoverable platform services, after the workers:

- Ingress controller is operational: a test app is reachable by hostname over HTTPS, with no certificate warning, from another device on the home network ([ADR-012](adr/012-use-cilium-gateway-api-for-ingress.md))
- Storage classes are configured
- Monitoring stack is collecting metrics from every node, with bounded retention ([ADR-008](adr/008-allow-workloads-on-control-plane-nodes.md))
- The "ready to hold important workloads" gate in [Recovery Expectations](06-recovery-expectations.md#gate-ready-to-hold-important-workloads) has passed, recorded with a date

### Phase 4: GitOps and Internal Source Control

- Flux is installed and syncing
- Infrastructure is managed via Git
- Apps are deployed via GitOps
- Drift detection is working
- Flux decrypts the secrets it applies ([ADR-010](adr/010-store-talos-secrets-with-sops-and-age.md) deferred this to Phase 4, to be revisited then)
- An internal source-control service runs, backed up as its class requires ([Recovery Expectations](06-recovery-expectations.md))
- With the internal source-control service stopped, the cluster's configuration and a repository kept in that service have been recovered from outside the cluster, recorded with a date

### Phase 5: Local Inference Experiments

- At the start of the phase, the GX10's supported operating system, drivers, vLLM deployment path, models and their terms have been checked, and its deployment path is recorded in an ADR
- vLLM ([ADR-015](adr/015-use-vllm-for-local-inference.md)) serves at least one model on the GX10, reachable from the cluster
- The GX10 and its inference endpoint meet the [access and exposure invariants](05-workload-placement.md#access-and-exposure-invariants), recorded with a date
- An evaluation of the model on a recorded set of requests (latency, throughput, memory use, notes on quality) is committed with the date and the versions
- The options for a second GX10 ([open decisions](adr/README.md#open-decisions)) are researched and written down

### Phase 6: Combined Local and Frontier Workflows

- A success measure is chosen (quality, latency, cost, privacy, or a mix), and a frontier-only baseline is measured
- A model gateway, separate from Gateway API ingress, routes one workflow between the local endpoint and a frontier model API, holds the API credentials, quotas and fallback, and meets the [access and exposure invariants](05-workload-placement.md#access-and-exposure-invariants)
- What data may be sent to frontier providers is decided in an ADR, and a request it forbids is refused where that ADR says it is enforced
- Fallback is tested with each side unavailable once, and the workflow is measured against the baseline

### Phase 7: Controlled Public Access

The lab starts private. This phase opens selected entry points to selected people. Commercial use is a possibility for later, not a promise of availability.

Its position after Phase 6 is proposed. The owner said public access should follow "a working private service and appropriate access controls", and "need not depend on completing every local/frontier experiment in M8" (Milestone 8, Phase 6). Proposed reading of appropriate access controls: the [access and exposure invariants](05-workload-placement.md#access-and-exposure-invariants) hold for what already runs.

- The domain (its spelling and ownership confirmed first), the account system, how public traffic reaches the lab, and the design of the authenticated API gateway are recorded in ADRs
- The public entry points meet the [access and exposure invariants](05-workload-placement.md#access-and-exposure-invariants) and serve only TLS with a publicly trusted certificate, recorded with a date
- An approved user is issued an API credential, and a revoked credential is refused, shown once
- Per-user permissions and usage limits are enforced, and each user's consumption is visible; a request over its limit is refused, shown once
- Phase 7's records are backed up as [Recovery Expectations](06-recovery-expectations.md#by-kind-of-service) sets out, and a restore has been exercised

## Non-Goals

### Out of Scope for Initial Phases

The initial phases are Phases 1 to 4.

- Public cloud integration. Phase 6 does call hosted frontier-model APIs; what data may be sent to them is an [open decision](adr/README.md#open-decisions)
- Multi-cluster management
- Advanced security features (initially)
- High-availability beyond 3-node control plane
- Complex service mesh (initially)
- GPU workloads (deferred to Phase 5; whether a GPU runs workloads inside the cluster is an [open decision](adr/README.md#open-decisions))

### Principles

- Start simple, add complexity incrementally
- Document before automating
- Prefer manual validation over premature automation
- Keep the cluster manageable for a single operator
- Focus on learning and understanding over tools
