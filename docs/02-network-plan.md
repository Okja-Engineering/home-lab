# Network Plan

## Current Network Overview

The home lab network starts with a simple flat network topology. VLANs are deferred until after the control plane is stable.

See [Physical Topology](../diagrams/physical-topology.md) for a visual representation of the network layout.

## Network Configuration

### Basic Network

- **Network Type:** Flat network (no VLANs initially)
- **Subnet:** 192.168.1.0/24
- **Gateway:** 192.168.1.1
- **DNS:** 192.168.1.1, 1.1.1.1
- **Domain:** lab.home.arpa (provisional)

### Control Plane IP Addresses (Planned)

Control plane IP addresses are planned but not yet confirmed via DHCP reservations:

| Node | Planned IP | Status |
|---|---|---|
| cp-01 | 192.168.1.21 | Planned / Unconfirmed |
| cp-02 | 192.168.1.22 | Planned / Unconfirmed |
| cp-03 | 192.168.1.23 | Planned / Unconfirmed |

**Action Required:** Reserve these IPs in the router or Omada controller before Talos installation.

### Cluster Endpoint

- **Cluster Endpoint DNS:** k8s.lab.home.arpa
- **Cluster Endpoint IP:** 192.168.1.21 (initially points to cp-01)
- **Port:** 6443

The cluster endpoint should be configured as a DNS A record. In the future, this may point to a VIP or load balancer.

## DHCP Reservations

### Required Reservations

Before Talos installation, configure DHCP reservations for:

- **cp-01:** 192.168.1.21
- **cp-02:** 192.168.1.22
- **cp-03:** 192.168.1.23

### Reservation Process

1. Identify MAC addresses of each GMKtec mini PC
2. Log into router or Omada controller
3. Create static DHCP reservations
4. Verify reservations are working (test with DHCP client)
5. Document MAC addresses in hardware inventory

## Network Equipment

### Router

- **Role:** Default gateway, DHCP server, DNS forwarder
- **IP:** 192.168.1.1
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
- **Network:** Connected to same 192.168.1.0/24 subnet
- **Access:** SSH to nodes, kubectl access via kubeconfig

## Network Topology

### Initial Flat Network

```
Internet
    |
Router (192.168.1.1)
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
   - `k8s.lab.home.arpa` → 192.168.1.21

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

- **Talos API:** Restricted to 192.168.1.0/24 initially
- **Kubernetes API:** Restricted to 192.168.1.0/24 initially
- **Future:** Consider VPN or bastion for remote access

### Firewall Rules

- Control plane nodes should only accept necessary traffic
- Document firewall rules as they are implemented
- Consider network policies in Kubernetes

## Notes

- Flat network is simpler for initial bootstrap
- VLANs add complexity and should be deferred
- DHCP reservations are critical for stable control plane operation
- Domain is internal only, no public DNS assumed
- Omada switch installation is pending but not blocking initial bootstrap
