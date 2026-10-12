# Hardware Inventory

## Control Plane Nodes

The control plane consists of 3 GMKtec mini PCs. Exact specifications will be filled in as hardware is inspected.

| Node | Role | Hardware | CPU | RAM | Storage | Planned IP | Status |
|---|---|---|---|---|---|---|---|
| cp-01 | Control plane | GMKtec mini PC | TBD | TBD | TBD | 192.168.1.21 | Planned |
| cp-02 | Control plane | GMKtec mini PC | TBD | TBD | TBD | 192.168.1.22 | Planned |
| cp-03 | Control plane | GMKtec mini PC | TBD | TBD | TBD | 192.168.1.23 | Planned |

## Planned IP Addresses

Control plane IP addresses are planned static addresses ([ADR-007](adr/007-configure-static-node-addresses.md)). They are not yet confirmed on the router:

- **cp-01:** 192.168.1.21
- **cp-02:** 192.168.1.22
- **cp-03:** 192.168.1.23

Each address will be set in the node's Talos machine config, not reserved in DHCP. The router check to do before Talos installation is in the [Network Plan](02-network-plan.md#node-addressing).

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

- **Router:** Home router (192.168.1.1)
- **Switch:** TP-Link Omada 10-port Gigabit Smart PoE+ (purchased, configuration deferred)
  - **Source:** Micro Center (~$114)
  - **Model:** Exact model TBD until verified
  - **Capabilities:** Managed, PoE, VLAN-capable
  - **Status:** Purchased, configuration deferred
  - **Note:** Not required for initial Talos bootstrap

## Future Hardware

### Worker Nodes (Planned)

Worker nodes will be added after the control plane is stable. Categories:

- **Stateful workers:** For databases and persistent storage workloads
- **Stateless/platform workers:** For ingress, monitoring, logging
- **AI/GPU worker:** For machine learning workloads (deferred)

### Storage (Planned)

- **NAS:** Network-attached storage for persistent data (deferred)

## Notes

- Hardware specifications are placeholders until physically inspected
- MAC addresses are not needed: under [ADR-007](adr/007-configure-static-node-addresses.md), node addresses will be static and network ports will be selected without MAC addresses
- Serial numbers are optional but useful for warranty tracking
- Do not commit sensitive hardware details (e.g., MAC addresses): this repository is public
