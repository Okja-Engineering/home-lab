# Hardware Inventory

## Control Plane Nodes

The control plane consists of three identical GMKtec mini PCs. Talos read their hardware on 2026-10-13 ([issue 13](https://github.com/Okja-Engineering/home-lab/issues/13)), and the facts it found are recorded in [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env), one set for all three.

| Node | Role | Hardware | Planned IP | Status |
|---|---|---|---|---|
| cp-01 | Control plane | GMKtec mini PC | 10.0.0.21 | Planned |
| cp-02 | Control plane | GMKtec mini PC | 10.0.0.22 | Planned |
| cp-03 | Control plane | GMKtec mini PC | 10.0.0.23 | Planned |

Where each hardware fact is recorded:

| Fact | In `metadata.env` |
|---|---|
| Model | The hardware notes comment |
| CPU vendor and model | `CPU_VENDOR`, `CPU_MODEL` |
| CPU cores and threads | The hardware notes comment |
| RAM | The hardware notes comment |
| Install disk | `INSTALL_DISK`, `INSTALL_DISK_MODEL`, `INSTALL_DISK_SIZE`, `INSTALL_DISK_TRANSPORT` |
| Ethernet ports | `ETHERNET_PORT_COUNT` |
| Network interface | `NETWORK_INTERFACE`, `NETWORK_INTERFACE_BUS_PATH` |

## Planned IP Addresses

Control plane IP addresses are planned static addresses ([ADR-007](adr/007-configure-static-node-addresses.md)), outside the gateway's DHCP pool; what was checked is under [Router check](02-network-plan.md#router-check):

- **cp-01:** 10.0.0.21
- **cp-02:** 10.0.0.22
- **cp-03:** 10.0.0.23

Each address will be set in the node's Talos machine config, not reserved in DHCP.

## Hardware Details to Collect

For each node, document:

- **CPU:** Model, core count, architecture
- **RAM:** Total capacity, type (DDR4/DDR5)
- **Storage:** Disk size, type (NVMe/SATA), device path
- **Network:** Interface names. Do not record MAC addresses (see [Notes](#notes))
- **BIOS/UEFI:** Version, secure boot status, virtualization support
- **Serial Number:** Optional, for warranty tracking

## Workstation

The management workstation used for cluster operations:

- **OS:** macOS
- **Tools:** talosctl, kubectl, git

## Network Equipment

- **Router:** ISP-supplied gateway (10.0.0.1)
- **Switch:** Netgear GS308, 8-port gigabit, unmanaged
  - **Connection:** Plugged directly into a LAN port on the gateway; cp-01, cp-02 and cp-03 are cabled to it
- **Spare switch:** TP-Link Omada 10-port Gigabit Smart PoE+
  - **Source:** Micro Center (~$114)
  - **Model:** Exact model not verified
  - **Capabilities:** Managed, PoE, VLAN-capable
  - **Status:** A spare, not in the network path

## Future Hardware

### Worker Nodes (Planned)

Worker nodes will be added after the control plane is stable. Categories:

- **Stateful workers:** For databases and persistent storage workloads
- **Stateless/platform workers:** For ingress, monitoring, logging
- **AI/GPU worker:** For machine learning workloads (deferred)

### Storage (Planned)

- **NAS:** Network-attached storage for persistent data (deferred)

## Notes

- The control-plane hardware facts are in [`metadata.env`](../platform/talos/clusters/home-prod/metadata.env), and this page names where each one is. Of those facts, it repeats only the maker label, GMKtec mini PC, which matches `metadata.env`
- MAC addresses are not needed: under [ADR-007](adr/007-configure-static-node-addresses.md), node addresses will be static and network ports will be selected without MAC addresses
- Serial numbers are optional but useful for warranty tracking
- Do not commit sensitive hardware details (e.g., MAC addresses): this repository is public
