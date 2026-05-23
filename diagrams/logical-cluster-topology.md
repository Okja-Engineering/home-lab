# Logical Cluster Topology

## Legend

- **Solid lines:** Control-plane milestone target
- **Dashed lines:** Planned after control plane is healthy
- **Gray:** Future / deferred

## Control Plane Milestone Target

```mermaid
graph TB
    Workstation[Workstation<br/>talosctl/kubectl]
    Endpoint[k8s.lab.home.arpa:6443<br/>Cluster Endpoint<br/>192.168.1.21]
    cp01[cp-01<br/>192.168.1.21<br/>Talos + kubelet + etcd<br/>Target]
    cp02[cp-02<br/>192.168.1.22<br/>Talos + kubelet + etcd<br/>Target]
    cp03[cp-03<br/>192.168.1.23<br/>Talos + kubelet + etcd<br/>Target]
    etcd[etcd Cluster<br/>Target: 3 members]
    k8s[Kubernetes<br/>Control Plane<br/>Target]
    apiserver[kube-apiserver]
    scheduler[kube-scheduler]
    controller[kube-controller-manager]
    Cilium[Cilium CNI<br/>Planned<br/>Not installed]
    Flux[Flux GitOps<br/>Planned<br/>Deferred until control-plane healthy]
    Platform[Platform Services<br/>Ingress/Monitoring<br/>Planned/Deferred]
    Apps[Applications<br/>Planned/Deferred]
    Workers[Worker Nodes<br/>Stateful/Platform/GPU<br/>Deferred]

    Workstation --> Endpoint
    Endpoint --> cp01
    Endpoint --> cp02
    Endpoint --> cp03
    cp01 --> etcd
    cp02 --> etcd
    cp03 --> etcd
    etcd --> k8s
    k8s --> apiserver
    k8s --> scheduler
    k8s --> controller
    apiserver -.-> Cilium
    apiserver -.-> Flux
    apiserver -.-> Platform
    Platform -.-> Apps
    apiserver -.-> Workers

    classDef target fill:#87CEEB,stroke:#4682B4,stroke-width:2px
    classDef planned fill:#FFD700,stroke:#DAA520,stroke-width:2px,stroke-dasharray: 5 5
    classDef future fill:#D3D3D3,stroke:#808080,stroke-width:2px,stroke-dasharray: 2 2

    class Workstation,Endpoint,cp01,cp02,cp03,etcd,k8s,apiserver,scheduler,controller target
    class Cilium,Flux,Platform,Apps planned
    class Workers future
```

**Milestone 1 Target:** Three-node Talos control plane with etcd quorum (not yet built)

## Control Plane Components

### Node Components (on each cp-01, cp-02, cp-03)

- **Talos Linux:** Immutable OS
- **kubelet:** Kubernetes node agent
- **kube-proxy:** Network proxy
- **etcd:** Distributed key-value store (clustered across 3 nodes)

### Control Plane Components

- **kube-apiserver:** Kubernetes API server
- **kube-scheduler:** Pod scheduling
- **kube-controller-manager:** Controller loops
- **cloud-controller-manager:** (not used in bare metal)

## Future Components

### CNI (Planned)

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
5. Cilium provides networking
6. kube-proxy provides service proxying

## Network Layers

### Layer 1: Physical

- Ethernet connections between devices
- Switch aggregation
- Router gateway

### Layer 2: Logical

- Talos API (port 50000)
- Kubernetes API (port 6443)
- Cilium CNI (VXLAN or Geneve)
- Service networking (ClusterIP, NodePort, LoadBalancer)

### Layer 3: Services

- Ingress controller (HTTP/HTTPS)
- Service discovery (DNS)
- Network policies (Cilium)

## Notes

- Current topology is control plane only
- No worker nodes yet
- Cilium CNI is planned but not installed
- Platform services are planned but not installed
- Monitoring stack is planned but not installed
- Worker nodes are deferred until control plane is stable
