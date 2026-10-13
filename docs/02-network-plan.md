# Network Plan

## Current Network Overview

The home lab network starts with a simple flat network topology. VLANs are deferred until after the control plane is stable.

See [Physical Topology](../diagrams/physical-topology.md) for a visual representation of the network layout.

## Network Configuration

### Basic Network

- **Network Type:** Flat network (no VLANs initially)
- **Subnet:** 10.0.0.0/24
- **Gateway:** 10.0.0.1
- **DNS:** To be confirmed in [issue 16](https://github.com/Okja-Engineering/home-lab/issues/16), step 4. The gateway is not assumed to be a DNS server for the nodes
- **Domain:** lab.home.arpa (provisional)

### Control Plane IP Addresses (Planned)

Control plane IP addresses are planned static addresses ([ADR-007](adr/007-configure-static-node-addresses.md)). They are not yet confirmed on the router:

| Node | Planned IP | Status |
|---|---|---|
| cp-01 | 10.0.0.21 | Planned / Unconfirmed |
| cp-02 | 10.0.0.22 | Planned / Unconfirmed |
| cp-03 | 10.0.0.23 | Planned / Unconfirmed |

**Action Required:** Complete the router check under [Node Addressing](#node-addressing) before Talos installation.

### Cluster Endpoint

- **Cluster Endpoint:** A Talos shared virtual IP (VIP), not a DNS record pointing at cp-01 ([ADR-006](adr/006-use-talos-vip-for-kubernetes-api-endpoint.md))
- **Port:** 6443

The VIP address is given in ADR-006. Like the node addresses, it is planned and not yet confirmed on the router.

## Node Addressing

The nodes will not use DHCP reservations. Each node's address will be set in its Talos machine config ([ADR-007](adr/007-configure-static-node-addresses.md)).

### Router Check Before Talos Installation

The address plan has not been checked against the router yet. Before Talos installation:

1. Log into router or Omada controller
2. Confirm the DHCP pool does not include the node addresses or the cluster VIP
3. Confirm no other device is using those addresses

Do not record MAC addresses in this repository. ADR-007 selects network ports without them.

## Network Equipment

### Router

- **Role:** Default gateway, DHCP server (an ISP-supplied gateway). Not confirmed as a DNS forwarder: see [issue 16](https://github.com/Okja-Engineering/home-lab/issues/16), step 4
- **IP:** 10.0.0.1
- **Management:** Web UI or SSH

### Switch (Purchased, Configuration Deferred)

- **Model:** TP-Link Omada 10-port Gigabit Smart PoE+ (exact model TBD until verified)
- **Source:** Micro Center (~$114)
- **Status:** Purchased, configuration deferred
- **Capabilities:** Managed, PoE, VLAN-capable
- **Role:** Future network foundation, VLAN support
- **Management:** Omada controller (planned)
- **Note:** Not required for initial Talos bootstrap

### Workstation

- **Role:** Management workstation for cluster operations
- **Network:** Connected to same 10.0.0.0/24 subnet
- **Access:** talosctl to the nodes, not SSH ([ADR-001](adr/001-use-talos-linux.md)); kubectl access via kubeconfig

## Network Topology

### Initial Flat Network

```
Internet
    |
Router (10.0.0.1)
    |
Switch (Omada, purchased, configuration deferred)
    |
+---+---+---+
|   |   |   |
cp-01 cp-02 cp-03 Workstation
.21   .22   .23   DHCP
```

## DNS Configuration

### Internal Domain

- **Domain:** lab.home.arpa
- **Purpose:** Internal cluster and service resolution
- **Status:** Provisional, no public DNS assumed

### DNS Records to Create

1. **Cluster Endpoint:**
   - None required: the endpoint is the VIP, an IP address. [ADR-006](adr/006-use-talos-vip-for-kubernetes-api-endpoint.md) says what the `k8s.lab.home.arpa` name may still be used for.

2. **Future Service Records:**
   - Service DNS will be configured after cluster bootstrap
   - May use CoreDNS or external DNS

## Future Network Plans

### VLAN Implementation (Deferred)

VLANs will be implemented after the control plane is stable. Potential VLANs:

- **VLAN 10:** Control plane
- **VLAN 20:** Worker nodes
- **VLAN 30:** Storage
- **VLAN 40:** Management

### Omada Switch Integration (Deferred)

- Switch is purchased but configuration is deferred
- Install and configure TP-Link Omada switch (deferred)
- Set up Omada controller for management (deferred)
- Configure port-based VLANs (deferred)
- Document physical port mapping (deferred)
- **Note:** Switch configuration is not required for initial Talos bootstrap

## Network Security

### API Access

- **Talos API:** Restricted to 10.0.0.0/24 initially
- **Kubernetes API:** Restricted to 10.0.0.0/24 initially
- **Future:** Consider VPN or bastion for remote access

### Firewall Rules

- Control plane nodes should only accept necessary traffic
- Document firewall rules as they are implemented
- Consider network policies in Kubernetes

## Notes

- Flat network is simpler for initial bootstrap
- VLANs add complexity and should be deferred
- Stable node addresses are critical for control plane operation; [ADR-007](adr/007-configure-static-node-addresses.md) says why, and how the addresses are assigned
- Domain is internal only, no public DNS assumed
- Omada switch installation is pending but not blocking initial bootstrap
