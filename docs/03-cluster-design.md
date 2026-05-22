# Cluster Design

## Cluster Identity

- **Cluster Name:** home-prod
- **Domain:** lab.home.arpa (provisional)
- **Cluster Endpoint:** k8s.lab.home.arpa:6443
- **Environment:** Production home lab

## Control Plane Design

### Node Configuration

The control plane consists of 3 Talos Linux nodes:

| Node | Role | Planned IP | Hardware |
|---|---|---|---|
| cp-01 | Control plane | 192.168.1.21 | GMKtec mini PC |
| cp-02 | Control plane | 192.168.1.22 | GMKtec mini PC |
| cp-03 | Control plane | 192.168.1.23 | GMKtec mini PC |

### Control Plane Characteristics

- **Node Count:** 3 (for etcd quorum)
- **OS:** Talos Linux
- **Kubernetes Version:** v1.31.0 (planned)
- **Talos Version:** v1.8.0 (planned)
- **CNI:** Cilium (planned)
- **Etcd:** Embedded in control plane nodes

### High Availability

- 3-node control plane provides etcd quorum
- Single node failure tolerated
- Cluster remains operational with 2/3 nodes
- etcd requires majority for writes

## Current Scope

### In Scope (Phase 1)

- 3-node Talos Linux control plane
- Kubernetes cluster bootstrap
- Basic network connectivity (flat network)
- Control plane health validation
- Documentation and runbooks

### In Scope (Phase 2 - Planned)

- Cilium CNI installation
- Ingress controller
- Storage classes
- Basic monitoring
- GitOps with Flux

### Out of Scope (Deferred)

- Worker nodes (stateful and stateless)
- VLAN implementation
- Public DNS or external certificates
- Service mesh
- GPU workloads
- Multi-cluster management
- Advanced security features

## Worker Node Strategy (Future)

### Planned Worker Categories

1. **Stateful Workers**
   - Purpose: Databases, persistent storage workloads
   - Storage: Local storage or CSI
   - Count: TBD

2. **Stateless/Platform Workers**
   - Purpose: Ingress, monitoring, logging, platform services
   - Storage: Ephemeral
   - Count: TBD

3. **AI/GPU Worker (Deferred)**
   - Purpose: Machine learning workloads
   - Hardware: GPU-capable
   - Count: TBD

### Worker Node Timing

Worker nodes will be added after:
- Control plane is stable and healthy
- Cilium CNI is operational
- Storage classes are configured
- Monitoring is collecting metrics

## Cluster Components

### Control Plane Components

- **kube-apiserver:** Kubernetes API server
- **kube-scheduler:** Pod scheduling
- **kube-controller-manager:** Controller loops
- **etcd:** Distributed key-value store
- **kubelet:** Node agent
- **kube-proxy:** Network proxy

### Platform Components (Planned)

- **Cilium:** CNI, network policy, observability
- **cert-manager:** Certificate management
- **Ingress Controller:** NGINX or Gateway API
- **external-secrets:** Secret synchronization
- **Flux:** GitOps operator
- **Prometheus/Grafana:** Monitoring
- **Loki:** Logging

## Storage Design

### Current Phase

- No persistent storage in initial control plane phase
- Control plane uses local disk for etcd
- No CSI drivers initially

### Future Storage

- **Local-path-provisioner:** Simple local storage
- **Longhorn:** Distributed block storage (planned)
- **NAS integration:** NFS or iSCSI (deferred)

## Network Design

### Current Network

- Flat network (192.168.1.0/24)
- No VLANs initially
- Simple DHCP reservations
- DNS via router and public DNS

### Future Network

- VLAN segmentation (deferred)
- Network policies via Cilium
- Service mesh (deferred)
- Ingress with TLS (deferred)

## Security Design

### Current Security

- Talos immutable OS
- No SSH access to nodes
- API access restricted to local subnet
- Secrets not committed to Git

### Future Security

- RBAC policies
- Network policies
- Pod security policies
- Secret encryption at rest
- Certificate rotation

## Scalability Considerations

### Control Plane

- 3 nodes is sufficient for home lab
- Can scale to 5 nodes if needed
- etcd performance adequate for home lab workloads

### Worker Nodes

- Start with 0 workers
- Add workers based on workload needs
- Separate stateful and stateless workers
- Consider GPU worker for ML workloads

## Disaster Recovery

### Backup Strategy

- etcd snapshots (planned)
- Velero for cluster backup (deferred)
- Git as source of truth for configuration
- Secrets backed up offline

### Recovery Procedures

- Single control plane node recovery
- etcd quorum recovery
- Full cluster restore from backup

## Notes

- Cluster design is focused on control plane foundation
- Worker nodes and advanced features are explicitly deferred
- Design prioritizes learning and understanding over complexity
- Scope is bounded to enable incremental progress
