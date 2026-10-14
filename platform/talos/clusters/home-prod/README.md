# home-prod

Talos Linux cluster configuration for home production environment.

## Cluster Details

- **Name**: home-prod
- **Domain**: lab.home.arpa
- **Control Plane Nodes**: 3
- **Endpoint**: A Talos shared virtual IP (VIP) on port 6443, not a DNS name ([ADR-006](../../../../docs/adr/006-use-talos-vip-for-kubernetes-api-endpoint.md))

## Node IPs

- cp-01: 10.0.0.21
- cp-02: 10.0.0.22
- cp-03: 10.0.0.23

## Configuration

- **Install Disk**: /dev/nvme0n1 (confirm with talosctl)
- **Metadata**: See `metadata.env`
- **Patches**: See `patches/` directory

## Bootstrap Plan

**Not yet updated for ADR-005 to ADR-013.** This section, parts of the [Notes](#notes) below and both runbooks still follow the original plan: DHCP reservations for the nodes, a DNS name pointing at cp-01 as the endpoint, and bootstrap after all three nodes are configured. Where any of them disagrees with an [ADR](../../../../docs/adr/README.md), the ADR is current. [Issue 22](https://github.com/Okja-Engineering/home-lab/issues/22) will rewrite this section and the runbooks. [Issue 24](https://github.com/Okja-Engineering/home-lab/issues/24) will then check that nothing else, the Notes included, contradicts the ADRs.

The bootstrap process transforms bare GMKtec mini PCs into a Talos Kubernetes control plane. This is a high-level plan; detailed execution steps are in the cp-01 runbook.

### Prerequisites

- Workstation has talosctl and kubectl installed
- 3x GMKtec mini PCs are available
- Netgear GS308 switch is plugged directly into the gateway (unmanaged: no configuration)
- Router access for DHCP reservations and DNS

### Step 1: Hardware Preparation

- Configure BIOS/UEFI settings on all 3 nodes (secure boot off, virtualization enabled)
- Create Talos bootable USB media
- Boot cp-01 from Talos ISO
- Confirm hardware (interface names, disk paths)

### Step 2: Network Preparation

- Create DHCP reservations for cp-01 (10.0.0.21), cp-02 (10.0.0.22), cp-03 (10.0.0.23)
- Create DNS A record: k8s.lab.home.arpa → 10.0.0.21
- Verify network connectivity from workstation to nodes

### Step 3: Configuration Generation

- Generate Talos secrets bundle (store securely, not in Git)
- Generate machine configs using talosctl gen config with patches
- Review generated configs for correctness

### Step 4: Config Application

- Apply machine config to cp-01
- Apply machine config to cp-02
- Apply machine config to cp-03
- Verify all nodes are in maintenance mode

### Step 5: Cluster Bootstrap

- Bootstrap cluster on cp-01 (run once)
- Retrieve kubeconfig (store securely, not in Git)
- Verify cluster health via kubectl

### Validation Gates

- After Step 1: Hardware confirmed on cp-01
- After Step 2: DHCP reservations working, DNS resolving
- After Step 3: Generated configs reviewed
- After Step 4: All nodes in maintenance mode
- After Step 5: kubectl can access cluster

See [docs/runbooks/cp-01-talos-bootstrap.md](../../../../docs/runbooks/cp-01-talos-bootstrap.md) for detailed cp-01 execution steps.

See [docs/runbooks/three-node-control-plane-bootstrap.md](../../../../docs/runbooks/three-node-control-plane-bootstrap.md) for the three-node control plane bootstrap runbook.

## Notes

- Run bootstrap only once after all control plane nodes are configured
- Store `kubeconfig` securely, do not commit to Git
- Regenerate machine configs after modifying `metadata.env` or patches
- MAC addresses are documented locally for DHCP reservations, not committed to Git
- Network interface names must be confirmed via Talos before config generation
- Versions are pinned in `metadata.env` - use those versions

## Patch Readiness Warning

**Do not generate Talos machine configs until the following are confirmed:**

- Network interface name is confirmed from Talos discovery (update `metadata.env`)
- Install disk path is confirmed from Talos discovery (update `metadata.env`)
- Talos version is confirmed and matches the ISO used for boot
- Patch template variables are resolved or documented as intentional placeholders
- Patches are reviewed for correctness before config generation

Patches in `patches/` may contain unresolved template variables (e.g., `${MAC_ADDRESS}`, `${NODE_IP}`). These must be validated before running `talosctl gen config`.
