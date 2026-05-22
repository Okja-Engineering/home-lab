# Goals

## Project Objectives

This home lab project aims to build a functional Kubernetes platform that serves both operational needs and professional development goals.

### Operational Goals

- Provide a reliable platform for self-hosted services
- Learn and practice infrastructure-as-code principles
- Gain hands-on experience with modern Kubernetes operations
- Build a foundation for future platform services

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

### Secondary Focus Areas

- Infrastructure as code patterns
- Documentation and runbook practices
- Disaster recovery and backup strategies
- Multi-node cluster operations

## Success Criteria

### Phase 1: Control Plane Foundation

- Repository is safe from accidental secret commits
- Hardware, network, and cluster design are documented
- Talos configuration structure is clear
- Runbooks exist for control plane bootstrap
- Topology is visualized

This phase is tracked in the GitHub milestone "Milestone 1: Talos Control Plane Foundation" with 12 planning issues.

### Phase 2: Three-Node Control Plane

- All 3 control plane nodes are running Talos
- Kubernetes cluster is healthy
- etcd quorum is stable
- kubectl access is working from workstation

### Phase 3: Platform Services

- Cilium CNI is installed
- Ingress controller is operational
- Storage classes are configured
- Monitoring stack is collecting metrics

### Phase 4: GitOps

- Flux is installed and syncing
- Infrastructure is managed via Git
- Apps are deployed via GitOps
- Drift detection is working

## Non-Goals

### Out of Scope for Initial Phases

- Public cloud integration
- Multi-cluster management
- Advanced security features (initially)
- High-availability beyond 3-node control plane
- Complex service mesh (initially)
- GPU workloads (deferred to future)

### Principles

- Start simple, add complexity incrementally
- Document before automating
- Prefer manual validation over premature automation
- Keep the cluster manageable for a single operator
- Focus on learning and understanding over tools
