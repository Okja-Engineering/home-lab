# Network Plan

## Current Network Overview

The home lab network starts with a simple flat network topology. VLANs are deferred until after the control plane is stable.

See [Physical Topology](../diagrams/physical-topology.md) for a visual representation of the network layout.

## Network Configuration

### Basic Network

- **Network Type:** Flat network (no VLANs initially)
- **Subnet:** 10.0.0.0/24
- **Gateway:** 10.0.0.1
- **DNS:** Public resolvers: `DNS_SERVERS` in [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env). The gateway is not one of them
- **Domain:** lab.home.arpa (provisional)

### Control Plane IP Addresses (Planned)

Control plane IP addresses are planned static addresses ([ADR-007](adr/007-configure-static-node-addresses.md)), outside the gateway's DHCP pool; what was checked is under [Router check](#router-check). Each is recorded in [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env):

| Node | Address in `metadata.env` | Status |
|---|---|---|
| cp-01 | `CP_01_IP` | Planned |
| cp-02 | `CP_02_IP` | Planned |
| cp-03 | `CP_03_IP` | Planned |

### Cluster Endpoint

- **Cluster Endpoint:** A Talos shared virtual IP (VIP), not a DNS record pointing at cp-01 ([ADR-006](adr/006-use-talos-vip-for-kubernetes-api-endpoint.md))
- **Port:** 6443

The VIP is `CLUSTER_VIP` in [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env), and the endpoint is `CLUSTER_ENDPOINT`. Like the node addresses, the VIP is planned and outside the gateway's DHCP pool; what was checked is under [Router check](#router-check).

## Node Addressing

The nodes will not use DHCP reservations. Each node's address will be set in its Talos machine config ([ADR-007](adr/007-configure-static-node-addresses.md)).

### Router Check

The planned addresses are in [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env): `CLUSTER_VIP`, `CP_01_IP` to `CP_03_IP`, `WORKER_RANGE` and `LB_POOL`. What has been checked against the ISP-supplied gateway so far:

- On 2026-10-13 the gateway's DHCP pool was set to `DHCP_POOL` and the saved values were read back. Every planned address is outside it.
- On 2026-10-13 a ping and ARP check from the workstation got no reply from any of the twenty planned addresses. A silent ping is not proof: a device that is asleep or switched off does not reply.

Still to check ([issue 16](https://github.com/Okja-Engineering/home-lab/issues/16)): the gateway's device list, online and offline, its leases and its reservations; then the ping and ARP check and the leases again, after any old lease could have expired.

Later checks:

- During installation, a final conflict check right before the addresses are assigned ([issue 22](https://github.com/Okja-Engineering/home-lab/issues/22)).
- After the gateway is reset or replaced, the whole check again: its DHCP pool may no longer exclude the planned addresses ([ADR-014](adr/014-rebase-address-plan-onto-10-0-0-0-24.md)).

Do not record MAC addresses in this repository. ADR-007 selects network ports without them.

## Network Equipment

### Router

- **Role:** Default gateway, DHCP server (an ISP-supplied gateway). Not a DNS server for the nodes: theirs are `DNS_SERVERS` in [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env)
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
   - None: the endpoint is the VIP, an IP address (`CLUSTER_ENDPOINT` in [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env)). The name `k8s.lab.home.arpa`, which [ADR-006](adr/006-use-talos-vip-for-kubernetes-api-endpoint.md) allowed as an extra API server certificate name, is not used: it was dropped on 2026-10-13, and `API_DNS_NAME` is empty.

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
