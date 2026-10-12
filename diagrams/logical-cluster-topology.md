# Logical Cluster Topology

## Legend

- **Solid lines:** Phase 2 target (three-node control plane)
- **Dashed lines:** Planned after control plane is healthy
- **Gray:** Future / deferred

The phases are defined in [Goals](../docs/00-goals.md#phases).

## Phase 2 Target

```mermaid
graph TB
    Workstation[Workstation<br/>talosctl/kubectl]
    VIP[Kubernetes API endpoint<br/>Talos shared VIP<br/>192.168.1.20:6443<br/>Held by one node at a time]
    cp01[cp-01<br/>192.168.1.21<br/>Talos + kubelet + etcd<br/>Target]
    cp02[cp-02<br/>192.168.1.22<br/>Talos + kubelet + etcd<br/>Target]
    cp03[cp-03<br/>192.168.1.23<br/>Talos + kubelet + etcd<br/>Target]
    etcd[etcd Cluster<br/>Target: 3 members]
    k8s[Kubernetes<br/>Control Plane<br/>Target]
    apiserver[kube-apiserver]
    scheduler[kube-scheduler]
    controller[kube-controller-manager]
    Cilium[Cilium CNI<br/>Pod and Service networking<br/>Target]
    Flux[Flux GitOps<br/>Planned<br/>Deferred until control-plane healthy]
    Platform[Platform Services<br/>Ingress/Monitoring<br/>Planned/Deferred]
    Apps[Applications<br/>Planned/Deferred]
    Workers[Worker Nodes<br/>Stateful/Platform/GPU<br/>Deferred]

    Workstation -->|kubectl| VIP
    Workstation -->|talosctl| cp01
    Workstation -->|talosctl| cp02
    Workstation -->|talosctl| cp03
    VIP --> cp01
    cp01 --> k8s
    cp02 --> k8s
    cp03 --> k8s
    k8s --> apiserver
    k8s --> scheduler
    k8s --> controller
    apiserver --> etcd
    apiserver --> Cilium
    apiserver -.-> Flux
    apiserver -.-> Platform
    Platform -.-> Apps
    apiserver -.-> Workers

    classDef target fill:#87CEEB,stroke:#4682B4,stroke-width:2px
    classDef planned fill:#FFD700,stroke:#DAA520,stroke-width:2px,stroke-dasharray: 5 5
    classDef future fill:#D3D3D3,stroke:#808080,stroke-width:2px,stroke-dasharray: 2 2

    class Workstation,VIP,cp01,cp02,cp03,etcd,k8s,apiserver,scheduler,controller,Cilium target
    class Flux,Platform,Apps planned
    class Workers future
```

**Phase 2 Target:** Three-node Talos control plane with etcd quorum (not yet built)

Reading the diagram:

- **Endpoint:** The edge labelled kubectl goes to the Kubernetes API endpoint, a Talos shared VIP that one healthy control-plane node holds at a time. The diagram draws the VIP on cp-01 as an example; cp-02 or cp-03 can hold it instead. The edges labelled talosctl go to each node's own address: talosctl never uses the VIP ([ADR-006](../docs/adr/006-use-talos-vip-for-kubernetes-api-endpoint.md)).
- **State:** Each node runs the control plane components and one etcd member. kube-apiserver reads and writes cluster state in etcd.
- **CNI:** Cilium is installed during bootstrap and replaces kube-proxy ([ADR-005](../docs/adr/005-use-cilium-with-kube-proxy-replacement.md)).
- **Addresses:** The VIP and node addresses are the planned values from ADR-006 and [ADR-007](../docs/adr/007-configure-static-node-addresses.md). They are not yet confirmed on the router.

## Control Plane Components

### Node Components (on each cp-01, cp-02, cp-03)

- **Talos Linux:** Immutable OS
- **kubelet:** Kubernetes node agent
- **Cilium:** CNI and kube-proxy replacement; kube-proxy is not deployed ([ADR-005](../docs/adr/005-use-cilium-with-kube-proxy-replacement.md))
- **etcd:** Distributed key-value store (clustered across 3 nodes)

### Control Plane Components

- **kube-apiserver:** Kubernetes API server
- **kube-scheduler:** Pod scheduling
- **kube-controller-manager:** Controller loops
- **cloud-controller-manager:** (not used in bare metal)

### CNI (Part of Bootstrap)

```
                +-------+
                | Cilium|
                |  CNI  |
                +-------+
                    |
        +-----------+-----------+
        |           |           |
    +---+---+   +---+---+   +---+---+
    | cp-01 |   | cp-02 |   | cp-03 |
    +---+---+   +---+---+   +---+---+
```

## Future Components

### Platform Services (Planned)

```
                +-------+-------+
                |  Ingress      |
                |  Controller   |
                +-------+-------+
                        |
                +-------+-------+
                |  cert-manager |
                +-------+-------+
                        |
                +-------+-------+
                | external-secrets|
                +-------+-------+
```

### Monitoring (Planned)

```
                +-------+-------+
                | Prometheus    |
                +-------+-------+
                        |
                +-------+-------+
                |   Grafana     |
                +-------+-------+
                        |
                +-------+-------+
                |     Loki      |
                +-------+-------+
```

### Worker Nodes (Deferred)

```
                +-------+-------+
                |  kube-apiserver|
                +-------+-------+
                        |
        +---------------+---------------+
        |               |               |
    +---+---+       +---+---+       +---+---+
    |Worker-1|       |Worker-2|       |Worker-3|
    |Stateful|       |Platform |       |GPU     |
    +---+---+       +---+---+       +---+---+
```

## Data Flow

### Management Flow

1. Workstation → talosctl → Talos API (nodes)
2. Workstation → kubectl → Kubernetes API (cluster endpoint)
3. Kubernetes API → etcd (cluster state)
4. Kubernetes API → kubelet (node scheduling)

### Pod Flow

1. User creates pod via kubectl
2. kube-apiserver validates request
3. kube-scheduler assigns node
4. kubelet on node creates pod
5. Cilium provides pod networking and Service proxying; there is no kube-proxy ([ADR-005](../docs/adr/005-use-cilium-with-kube-proxy-replacement.md))

## Network Layers

These groups are informal. They are not OSI layer numbers.

### Physical

- Ethernet connections between devices
- Switch aggregation
- Router gateway

### Logical

- Talos API (port 50000)
- Kubernetes API (port 6443)
- Cilium CNI (VXLAN or Geneve)
- Service networking (ClusterIP, NodePort, LoadBalancer)

### Services

- Ingress controller (HTTP/HTTPS)
- Service discovery (DNS)
- Network policies (Cilium)

## Notes

- Current topology is control plane only
- No worker nodes yet
- Cilium is part of the Phase 2 target ([ADR-005](../docs/adr/005-use-cilium-with-kube-proxy-replacement.md)); like the rest of the target, it is not yet built
- Platform services are planned but not installed
- Monitoring stack is planned but not installed
- Worker nodes are deferred until control plane is stable
