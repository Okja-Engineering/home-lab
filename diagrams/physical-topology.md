# Physical Topology

## Legend

- **Solid lines:** Current / confirmed
- **Dashed lines:** Near-term control-plane target
- **Dotted lines:** Purchased but configuration deferred
- **Gray:** Future / deferred

## Current Physical Layout

```mermaid
graph TB
    Internet[Internet]
    Router[Router<br/>192.168.1.1<br/>Gateway/DHCP/DNS]
    Workstation[Workstation<br/>macOS<br/>talosctl/kubectl]
    Switch[TP-Link Omada Switch<br/>Purchased<br/>Config Deferred<br/>Unmanaged/flat use initially]
    cp01[cp-01<br/>192.168.1.21<br/>GMKtec mini PC<br/>Control-plane target]
    cp02[cp-02<br/>192.168.1.22<br/>GMKtec mini PC<br/>Control-plane target]
    cp03[cp-03<br/>192.168.1.23<br/>GMKtec mini PC<br/>Control-plane target]
    FutureWorkers[Future Workers<br/>Stateful/Platform/GPU<br/>Deferred]
    FutureNAS[Future NAS<br/>Storage<br/>Deferred]

    Internet --> Router
    Router --> Workstation
    Router -.-> Switch
    Switch --> cp01
    Switch --> cp02
    Switch --> cp03
    Switch -.-> FutureWorkers
    Switch -.-> FutureNAS

    classDef current fill:#90EE90,stroke:#228B22,stroke-width:2px
    classDef target fill:#87CEEB,stroke:#4682B4,stroke-width:2px,stroke-dasharray: 5 5
    classDef deferred fill:#FFD700,stroke:#DAA520,stroke-width:2px,stroke-dasharray: 2 2
    classDef future fill:#D3D3D3,stroke:#808080,stroke-width:2px,stroke-dasharray: 2 2

    class Internet,Router,Workstation current
    class cp01,cp02,cp03 target
    class Switch deferred
    class FutureWorkers,FutureNAS future
```

**Network:** Flat 192.168.1.0/24 (no VLANs - VLANs are not active)

## Components

### Workstation

- **Role:** Management workstation
- **OS:** macOS
- **Network:** 192.168.1.0/24 (DHCP)
- **Tools:** talosctl, kubectl, git

### Router

- **Role:** Default gateway, DHCP server, DNS forwarder
- **IP:** 192.168.1.1
- **Management:** Web UI or SSH

### Switch (Purchased, Configuration Deferred)

- **Model:** TP-Link Omada 10-port Gigabit Smart PoE+ (exact model TBD until verified)
- **Source:** Micro Center (~$114)
- **Status:** Purchased, configuration deferred
- **Capabilities:** Managed, PoE, VLAN-capable
- **Role:** Network aggregation, future VLAN support
- **Management:** Omada controller (planned)
- **Note:** Not required for initial Talos bootstrap

### Control Plane Nodes

- **cp-01:** GMKtec mini PC, 192.168.1.21
- **cp-02:** GMKtec mini PC, 192.168.1.22
- **cp-03:** GMKtec mini PC, 192.168.1.23

### Future Components

- **Worker Nodes:** Stateful and stateless workers (deferred)
- **NAS:** Network-attached storage (deferred)
- **GPU Worker:** AI/ML workloads (deferred)

## Network Connections

### Current Connections

- Workstation ↔ Router (WiFi or Ethernet)
- Router ↔ Switch (planned)
- Switch ↔ cp-01, cp-02, cp-03 (planned)

### Future Connections

- Switch ↔ Worker nodes
- Switch ↔ NAS
- Switch ↔ GPU worker

## Port Mapping (Future Planning Placeholder)

When Omada switch is configured, document physical port mapping:

| Port | Device | VLAN | Status |
|------|--------|------|--------|
| 1 | Router Uplink | Deferred | Planned |
| 2 | cp-01 | Deferred | Planned |
| 3 | cp-02 | Deferred | Planned |
| 4 | cp-03 | Deferred | Planned |
| 5 | Workstation | Deferred | Planned |
| 6-10 | Future | TBD | Planned |

**Note:** This table is a future planning placeholder. VLANs are not currently configured.

## Notes

- Switch is purchased but configuration is deferred
- Current topology is flat network (no VLANs)
- VLANs will be implemented after control plane is stable
- Switch configuration is not required for initial Talos bootstrap
- Physical connections should be labeled for clarity
