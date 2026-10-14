# Physical Topology

## Legend

Boxes:

- **Green:** In place now
- **Blue, dashed border:** Control-plane target, not built yet
- **Gray, dotted border:** Future / deferred

Lines:

- **Solid:** A cable
- **Long dashes, labelled Wi-Fi:** A Wi-Fi link
- **Dotted:** A future connection

## Current Physical Layout

```mermaid
graph TB
    Internet[Internet]
    Router[Router<br/>10.0.0.1<br/>Gateway/DHCP]
    Switch[Netgear GS308 Switch<br/>8-port gigabit<br/>Unmanaged]
    Workstation[Workstation<br/>macOS<br/>talosctl/kubectl]
    cp01[cp-01<br/>10.0.0.21<br/>GMKtec mini PC<br/>Control-plane target]
    cp02[cp-02<br/>10.0.0.22<br/>GMKtec mini PC<br/>Control-plane target]
    cp03[cp-03<br/>10.0.0.23<br/>GMKtec mini PC<br/>Control-plane target]
    FutureSwitching[Switching for later nodes<br/>Not chosen yet<br/>Deferred]
    FutureWorkers[Future Workers<br/>Stateful/Platform/GPU<br/>Deferred]
    FutureNAS[Future NAS<br/>Storage<br/>Deferred]

    Internet --- Router
    Router --- Switch
    Router ---|Wi-Fi| Workstation
    Switch --- cp01
    Switch --- cp02
    Switch --- cp03
    Router -.- FutureSwitching
    FutureSwitching -.- FutureWorkers
    FutureSwitching -.- FutureNAS

    %% Links are numbered from 0 in the order written above: link 2 is the Wi-Fi link
    linkStyle 2 stroke-dasharray: 10 5,stroke-width:2px

    classDef current fill:#90EE90,stroke:#228B22,stroke-width:2px,color:#000
    classDef target fill:#87CEEB,stroke:#4682B4,stroke-width:2px,stroke-dasharray: 5 5,color:#000
    classDef future fill:#D3D3D3,stroke:#808080,stroke-width:2px,stroke-dasharray: 2 2,color:#000

    class Internet,Router,Switch,Workstation current
    class cp01,cp02,cp03 target
    class FutureSwitching,FutureWorkers,FutureNAS future
```

**Network:** Flat 10.0.0.0/24 (no VLANs; [ADR-002](../docs/adr/002-start-with-flat-network.md))

## Components

### Workstation

- **Role:** Management workstation
- **OS:** macOS
- **Network:** 10.0.0.0/24 (DHCP)
- **Tools:** talosctl, kubectl, git

### Router

- **Role:** Default gateway, DHCP server (an ISP-supplied gateway)
- **IP:** 10.0.0.1
- **Management:** Web UI or SSH

### Switch

- **Model:** Netgear GS308, 8-port gigabit, unmanaged
- **Connection:** Plugged directly into a LAN port on the ISP-supplied gateway
- **Role:** Connects cp-01, cp-02 and cp-03 to the gateway on the flat network
- **Configuration:** None: it is unmanaged

### Spare Switch

- **Model:** TP-Link Omada 10-port Gigabit Smart PoE+ (exact model not verified)
- **Status:** A spare, not in the network path and not drawn above

### Control Plane Nodes

- **cp-01:** GMKtec mini PC, 10.0.0.21
- **cp-02:** GMKtec mini PC, 10.0.0.22
- **cp-03:** GMKtec mini PC, 10.0.0.23

### Future Components

- **Worker Nodes:** Stateful and stateless workers (deferred)
- **NAS:** Network-attached storage (deferred)
- **GPU Worker:** AI/ML workloads (deferred)

## Network Connections

### Current Connections

- Workstation ↔ Router (Wi-Fi)
- Router ↔ Switch (the GS308, plugged directly into a LAN port on the gateway)
- Switch ↔ cp-01, cp-02, cp-03 (cabled)

### Future Connections

- Worker nodes, the NAS and the GPU worker: the switching they connect through is not chosen yet (see [Notes](#notes))

## Port Mapping

The GS308 is unmanaged, and its ports are not mapped.

## Notes

- The GS308 needs no configuration for the initial Talos bootstrap
- Current topology is flat network (no VLANs)
- VLANs are deferred ([ADR-002](../docs/adr/002-start-with-flat-network.md)) and need a managed switch: managed switching is revisited when VLAN separation is decided
- Physical connections should be labeled for clarity
